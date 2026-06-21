# Homelab Autoscaling

Autoscaling in this cluster is for compute capacity only. Storage is split into
explicit tiers so scale-down does not copy large Longhorn replicas between SSDs.

## Architecture

- `deepthought` is the always-on K3s server and permanent Longhorn storage node.
- Worker nodes are woken with Wake-on-LAN only when schedulable stateless or
  explicitly local workloads need capacity.
- The upstream `homecluster-dev/homelab-autoscaler` operator owns physical node
  state, Wake-on-LAN startup jobs, SSH shutdown jobs, and the Cluster Autoscaler
  external gRPC endpoint.
- Cluster Autoscaler owns scheduler simulation and the one-hour idle delay once
  its chart-managed deployment is explicitly enabled.
- Shutdown jobs own the final Longhorn safety checks before SSH poweroff.

The autoscaler integration is intentionally a gated pilot. The active
Kustomization installs only the upstream operator HelmRelease, CRDs, and
namespace. Group and Node CR examples live under
`clusters/home/infrastructure/homelab-autoscaler/examples/` and must not be
included until the operator CRDs have been installed and the manual power-state
tests have passed.

The shutdown path must refuse to power off:

- `deepthought`
- unknown nodes
- nodes labeled `home-server.dev/storage=permanent`
- nodes with Longhorn replicas
- nodes with attached Longhorn volumes

Cluster Autoscaler also has to pass its scheduler simulation before it will call
the shutdown job. Longhorn instance-manager pods are not DaemonSets and are not
replicated, so Cluster Autoscaler treats them as blockers unless they are
explicitly marked safe to evict. The
`homelab-autoscaler-longhorn-safe-to-evict` CronJob annotates instance-manager
pods on autoscaled nodes only when that node has no Longhorn replicas and no
attached Longhorn volumes. If storage appears on the node, the annotation is
removed again. The shutdown job still performs the final Longhorn replica and
attachment checks immediately before SSH poweroff.

## Upstream Autoscaler

Use `homecluster-dev/homelab-autoscaler` instead of a repo-owned provider
binary. It gives this repository a smaller maintenance surface: Flux installs
the upstream Helm chart, while this repository owns only node inventory, SOPS
secrets, storage policy, and shutdown safety.

The chart is pinned in
`clusters/home/infrastructure/homelab-autoscaler/helmrelease.yaml`. Cluster
Autoscaler is enabled for the active pilot after these checks passed:

1. The controller manager, webhooks, and gRPC service reconcile cleanly.
2. A `Node` CR can wake a powered-off worker with its `startupPodSpec`.
3. The worker rejoins K3s with the expected labels and taints.
4. The `shutdownPodSpec` refuses shutdown while Longhorn replicas or attached
   Longhorn volumes exist on the node.
5. The same shutdown job drains and powers off the node when only drainable
   stateless workloads are present.

The active Helm values keep Cluster Autoscaler on with:

```yaml
clusterAutoscaler:
  enabled: true
  scaleDownDelay: 1h
  scaleDownUnneededTime: 1h
  scaleDownUtilizationThreshold: 0.1
  skipNodesWithLocalStorage: true
  skipNodesWithSystemPods: true
```

The upstream project is still young. Installing the operator is only the first
pilot step. Expect manual recovery for failed jobs or stuck power-state
transitions.

The 2026-06-20 WOL checks showed two useful constraints:

- `milliard`: integrated Ethernet WOL works after BIOS WOL was enabled.
- `marvin`: USB-network WOL reports `Wake-on: g`, but powered-off wake has not
  succeeded through the relay. A manual `systemctl suspend` test also entered
  suspend, but relay WOL did not resume the node within the validation window.
  Keep it as a manual-wake autoscaler node: workloads must explicitly target it,
  and an operator must press the power button during the scale-up window.
- Normal pod-network WOL is not reliable for this LAN. WOL packets are sent
  through a small host-network relay pinned to `deepthought`.

The autoscaler `Node` CRs use the Flux server-side apply policy
`kustomize.toolkit.fluxcd.io/ssa: IfNotPresent`. Flux creates the inventory
objects, but the autoscaler is allowed to mutate `spec.powerState` afterward.
Without that policy, Git reconciliation would fight scale-up and scale-down
decisions.

`marvin` is created with `spec.powerState: "off"` so it remains demand-driven
while no workload needs it. Because the resource uses `IfNotPresent`, Cluster
Autoscaler can mutate `spec.powerState` to `on` for a pending Marvin workload
and later back to `off` after the idle window without Flux reverting it. The
expected workflow is:

1. Apply a workload that explicitly requires `marvin`.
2. Cluster Autoscaler marks `marvin` needed and the startup job sends WOL.
3. Because USB WOL is unreliable, manually press `marvin`'s power button before
   `maxNodeProvisionTime` expires.
4. The startup job waits for the Kubernetes node to become Ready and uncordons
   it.
5. After the workload is removed, Cluster Autoscaler waits
   `scaleDownUnneededTime: 1h`, then runs the normal Longhorn-safe shutdown job.

If an idle worker does not scale down, check the Cluster Autoscaler logs for a
message like `Node <name> cannot be removed:
longhorn-system/instance-manager-... is not replicated`. That means the
safe-to-evict helper has not annotated the Longhorn instance-manager pod, or the
node still has Longhorn replicas or attached volumes.

Do not manually power on `marvin` before applying the workload that requires it.
If the autoscaler still sees desired state `off`, it is allowed to shut the node
down again.

The upstream 0.1.14 CRDs are the source of truth for pilot manifests. Some
upstream documentation examples mention fields such as `maxSize` and
`nodeSelector`, but those fields are not present in the published 0.1.14
`Group` CRD. Keep local examples aligned with the rendered chart schema and
re-check the CRDs before enabling a newer chart version.

The pinned 0.1.14 chart also renders `ClusterRole/manager-role` while its
bindings reference `ClusterRole/homelab-autoscaler-manager-role`. The
HelmRelease uses a Flux post-render patch to rename that role. Remove the patch
only after rendering a newer chart version and confirming the upstream RBAC
names match.

## Implementation Sequence

Land the change in small commits:

1. Storage tiers: keep `longhorn` as the active durable class, add
   `longhorn-permanent` as a future migration target, and add `longhorn-local`
   for explicit local SSD workloads.
2. Node topology: document `deepthought`, `milliard`, `marvin`, expected labels,
   taints, and Longhorn tags.
3. Autoscaler source: add the upstream HelmRepository and the
   `homelab-autoscaler` HelmRelease.
4. Power config: add the SOPS Secret example and keep real WOL/SSH values in the
   private overlay.
5. Pilot examples: add the upstream `Group` and `Node` CR examples, but leave
   them outside the active Kustomization until CRDs are installed.
6. Manual pilot: install only the operator, keep Cluster Autoscaler disabled,
   and test worker power-state transitions by patching upstream `Node` CRs.
7. Autoscaling pilot: enable chart-managed Cluster Autoscaler only after manual
   WOL, drain, Longhorn refusal, and SSH poweroff checks pass.

## Storage Scheduling

Durable workloads continue to use `longhorn` and prefer `deepthought`:

```yaml
storageClassName: longhorn
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - deepthought
```

Node-local workloads use the generic local class. The scheduler chooses the node
first; Longhorn `strict-local` keeps the single replica on the node where the
volume is attached. Add affinity only when a workload should favor or require a
specific node.

```yaml
storageClassName: longhorn-local
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - milliard
```

Example manifests for local Longhorn workloads live under
`clusters/home/infrastructure/longhorn-storageclasses/examples/`. They are not
included in the Flux Kustomization.

Ephemeral workloads can run anywhere and may opt in to autoscaled workers.
Permanent workloads should stay on `longhorn` unless they deliberately bind to a
local storage tier. `longhorn-permanent` is a future migration target, not the
current default.

### Longhorn Runtime Tags

Longhorn `Node` resources are runtime objects managed by Longhorn, so this
repository does not commit full `nodes.longhorn.io` manifests. After Longhorn is
installed and the `deepthought` data disk exists, apply the permanent-storage
tags as an explicit bootstrap step:

```bash
kubectl patch nodes.longhorn.io -n longhorn-system deepthought --type merge -p \
  '{"spec":{"tags":["deepthought"],"disks":{"data-longhorn":{"tags":["longhorn-data","permanent-ssd"]}}}}'
```

Verify the live tags before creating PVCs that use `longhorn-permanent`:

```bash
kubectl get nodes.longhorn.io -n longhorn-system deepthought -o jsonpath='{.spec.tags}{"\n"}{.spec.disks.data-longhorn.tags}{"\n"}'
```

This tag-only patch does not move existing PVCs, replicas, or Longhorn volumes.
Do not delete Longhorn disks or volumes while applying tags.

## Autoscaled Worker Scheduling

Autoscaled workers should be tainted so workloads opt in explicitly:

```yaml
metadata:
  labels:
    home-server.dev/node-role: autoscaled-worker
    home-server.dev/storage: local
    home-server.dev/autoscaled: "true"
spec:
  taints:
    - key: home-server.dev/autoscaled
      value: "true"
      effect: NoSchedule
```

Workloads that may use autoscaled workers need a matching toleration:

```yaml
tolerations:
  - key: home-server.dev/autoscaled
    operator: Equal
    value: "true"
    effect: NoSchedule
```

General autoscaled workloads should not tolerate `marvin`'s manual-wake taint.
That keeps `milliard` as the normal autoscaled target. Workloads that really
need `marvin` must opt in with the extra toleration and a required node
affinity:

```yaml
tolerations:
  - key: home-server.dev/autoscaled
    operator: Equal
    value: "true"
    effect: NoSchedule
  - key: home-server.dev/manual-wake
    operator: Equal
    value: "true"
    effect: NoSchedule
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - marvin
```

## Wake-on-LAN And Poweroff

Real power-management data belongs in a SOPS-encrypted Secret in the upstream
operator namespace, not public YAML. The private schema should match
`private/flux/home/homelab-autoscaler-nodes.example.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: homelab-autoscaler-nodes
  namespace: homelab-autoscaler-system
type: Opaque
stringData:
  nodes.env: |
    MARVIN_MAC_ADDRESS="00:00:00:00:00:00"
    MARVIN_WAKE_BROADCAST="192.0.2.255"
    MARVIN_SSH_HOST="marvin.home.example"
    MARVIN_SSH_USER="autoscaler-shutdown"
    MARVIN_SSH_HOST_KEY="marvin.example ssh-ed25519 AAAA..."
  ssh_public_key: |
    ssh-ed25519 AAAA... homelab-autoscaler-shutdown
  ssh_private_key: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    example
    -----END OPENSSH PRIVATE KEY-----
```

Before enabling worker `Group` or `Node` CRs, create
`private/flux/home/homelab-autoscaler-nodes.sops.yaml` from
`private/flux/home/homelab-autoscaler-nodes.example.yaml`, encrypt it with SOPS,
and add it to `private/flux/home/kustomization.yaml`.

The SSH key should be dedicated to autoscaler shutdown and should not be an
operator's personal key. The matching public key is also stored in the SOPS
Secret so the Kairos hardware renderer can inject a restricted
`autoscaler-shutdown` user into rebuilt agent nodes. That user may only run the
host poweroff command through sudo.

### Kairos Reinstall Workflow

Kairos worker nodes can be reinstalled freely, so treat autoscaler SSH as
install-time configuration plus post-install inventory:

1. Keep `private/flux/home/homelab-autoscaler-nodes.sops.yaml` encrypted and in
   the private Flux overlay.
2. Render Kairos hardware media after the autoscaler secret exists:

   ```bash
   make kairos-render-node KAIROS_NODE=marvin
   ```

   The rendered user-data includes the `autoscaler-shutdown` user only when the
   encrypted autoscaler secret contains `stringData.ssh_public_key`.
3. Reinstall or boot the Kairos node.
4. Confirm the restricted user exists before enabling autoscaler shutdown:

   ```bash
   ssh autoscaler-shutdown@marvin 'id -un && sudo -n -l /sbin/poweroff >/dev/null'
   ```

5. Refresh the pinned SSH host key in
   `private/flux/home/homelab-autoscaler-nodes.sops.yaml` after every reinstall:

   ```bash
   ssh-keyscan -T 5 -t ed25519 marvin
   make sops-edit SOPS_FILE=private/flux/home/homelab-autoscaler-nodes.sops.yaml
   ```

6. Reconcile `infrastructure-private-secrets` before testing autoscaler
   shutdown.

Host keys are expected to change after a full Kairos reinstall unless host keys
are deliberately preserved. Do not work around this with
`StrictHostKeyChecking=no` in the shutdown job; update the SOPS secret and keep
the job pinned to the current host key.

For already-installed nodes that were rendered before the autoscaler shutdown
user existed, bootstrap the restricted user in place:

```bash
scripts/bootstrap-autoscaler-shutdown-user.sh marvin milliard
```

The script reads the dedicated keypair from the encrypted autoscaler SOPS
Secret, uses a temporary pinned host-key file, installs only the
`autoscaler-shutdown` account and sudoers drop-in, and verifies SSH login with
the dedicated key.

The upstream `Node` CR `startupPodSpec` calls the
`homelab-autoscaler-wol-relay` Service and then waits for the Kubernetes `Node`
to become Ready before it exits. The relay runs as a host-network pod on
`deepthought` so WOL packets leave through the LAN interface. Treat a startup
job that only sends a packet as insufficient: it proves only that the packet was
attempted, not that the machine powered on. If manual power-on is needed, the
WOL test failed even if the autoscaler later reports the node Ready.

The `shutdownPodSpec` should:

1. Refuse protected nodes and permanent-storage nodes.
2. Refuse nodes with Longhorn replicas.
3. Refuse nodes with attached Longhorn volumes.
4. Drain the node with a bounded timeout.
5. Power off the host over SSH using `BatchMode=yes` and a pinned host key.

If upstream drain behavior is improved later, keep the Longhorn refusal checks
in the shutdown job as defense in depth.

If WOL does not wake a node, verify the encrypted MAC address and broadcast
address, BIOS/firmware WOL settings, NIC power-management settings, switch/VLAN
broadcast behavior, and whether the node supports wake from the shutdown state
used by the OS.

## Test Plan

1. Confirm existing `longhorn` PVCs remain bound and healthy.
2. Confirm `longhorn-local` provisions on the node selected by scheduling.
3. Confirm a `longhorn-local` workload with preferred affinity favors the
   requested local SSD node.
4. Confirm Home Assistant and monitoring PVCs continue to use `longhorn`.
5. Confirm the `homelab-autoscaler-wol-relay` pod is Ready on `deepthought`.
6. Wake an autoscaled worker without touching the physical power button and
   confirm it joins with local-storage labels and autoscaled taints.
7. Create or enable the `Group` and `Node` CRs for one worker at a time.
8. Patch that `Node` CR from `off` to `on` and verify WOL, K3s join, labels,
   taints, and status progression. The startup job must not complete until the
   Kubernetes node is Ready.
9. Create a temporary Longhorn local PVC on the worker and verify the shutdown
   job refuses to power off while the replica or attachment exists.
10. Run a stateless test Deployment that tolerates autoscaled workers.
11. Temporarily reduce scale-down delay, delete the test workload, and verify
    drain and poweroff.
12. Confirm Longhorn reports no replica rebuild or migration during scale-down.

## PVC Migration

`longhorn-permanent` is reserved for a future deepthought-only storage migration;
it is not the current default and current workloads should not be switched to it
by normal reconciliation. Existing PVCs do not move automatically when a new
StorageClass is added. For durable workloads such as Home Assistant and
monitoring data, migrate with a maintenance-window backup and restore:

1. Stop or scale down the workload.
2. Take an application-consistent backup or Longhorn backup of the existing PVC.
3. Create a replacement PVC using `storageClassName: longhorn-permanent`.
4. Restore the data into the replacement PVC.
5. Start the workload and verify application health.
6. Keep the old PVC until the restored workload has been checked.

## Rollback

Suspend the autoscaler Kustomization, set `clusterAutoscaler.enabled: false`,
delete or patch autoscaler `Node` CRs back to manual control, manually wake
needed workers, and uncordon them. Do not delete PVCs, PVs, Longhorn volumes, or
Longhorn disks. Reverting a StorageClass only affects future PVCs; existing PVCs
remain bound to their original class.
