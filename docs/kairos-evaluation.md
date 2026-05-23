# Kairos Evaluation With KubeVirt

This runbook evaluates Kairos as an immutable K3s node OS without placing the
main home cluster on the critical path. It uses the existing KubeVirt and CDI
installation to run disposable VMs in the `vms` namespace.

The Flux Kustomization `evaluation-kairos-kubevirt` is committed suspended by
default. Resuming it is a live-cluster action that imports VM media, creates
Longhorn volumes, and can start disposable VMs only after local-only Secrets are
created.

## Pilot Scope

- Target namespace: `vms`
- Resource label: `example.com/evaluation=kairos`
- VMs: `kairos-server` and `kairos-agent`
- Nested K3s API Service: `kairos-k3s-api.vms.svc:6443`
- StorageClass: `longhorn-virtualization`
- Kairos artifact:
  `kairos-hadron-v0.0.4-standard-amd64-generic-v4.0.3-k3sv1.35.2+k3s1.iso`

The selected artifact keeps the pilot on the K3s `v1.35` minor used by the
home-cluster lifecycle at the time this evaluation path was added. Verify the
artifact before use:

```bash
curl -LO https://github.com/kairos-io/kairos/releases/download/v4.0.3/kairos-hadron-v0.0.4-standard-amd64-generic-v4.0.3-k3sv1.35.2+k3s1.iso
curl -LO https://github.com/kairos-io/kairos/releases/download/v4.0.3/kairos-hadron-v0.0.4-standard-amd64-generic-v4.0.3-k3sv1.35.2+k3s1.iso.sha256
sha256sum -c kairos-hadron-v0.0.4-standard-amd64-generic-v4.0.3-k3sv1.35.2+k3s1.iso.sha256
```

The upstream Kairos release also publishes signature material for the checksum
file. Use `cosign verify-blob` when validating install media outside CDI.

## Public And Private Boundaries

Committed examples use placeholders only. Do not commit generated user-data,
K3s tokens, kubeconfigs, SSH private keys, real hostnames, LAN IPs, or console
logs that include private values.

Create real pilot Secrets from the examples into ignored local files or apply
them directly from a private shell session:

```bash
cp clusters/home/evaluation/kairos-kubevirt/examples/kairos-server-user-data.example.yaml /tmp/kairos-server-user-data.yaml
cp clusters/home/evaluation/kairos-kubevirt/examples/kairos-agent-user-data.example.yaml /tmp/kairos-agent-user-data.yaml
```

Replace `${KAIROS_K3S_TOKEN}` with a temporary token and `${PUBLIC_SSH_KEY}`
with a public SSH key. Keep the rendered files outside the repository.

## Preflight

Run these checks from the devcontainer or another trusted workstation with the
local kubeconfig:

```bash
kubectl -n kubevirt get kubevirt kubevirt
kubectl -n cdi get cdi cdi
kubectl get node -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.devices\.kubevirt\.io/kvm}{"\t"}{.status.allocatable.cpu}{"\t"}{.status.allocatable.memory}{"\n"}{end}'
kubectl -n vms get vm,vmi,dv,pvc
virtctl version --client
kustomize build clusters/home/evaluation/kairos-kubevirt
```

Expected result: KubeVirt and CDI are deployed, at least one node advertises
KVM, no existing `kairos-*` evaluation resources are present, and `virtctl` is
available.

## First Boot And Install

Apply the local-only Secrets, then resume the suspended Flux Kustomization:

```bash
kubectl apply -f /tmp/kairos-server-user-data.yaml
kubectl apply -f /tmp/kairos-agent-user-data.yaml
flux resume kustomization evaluation-kairos-kubevirt -n flux-system
flux reconcile kustomization evaluation-kairos-kubevirt -n flux-system --with-source
```

Watch imports and VM state:

```bash
kubectl -n vms get dv,pvc,vm,vmi -l example.com/evaluation=kairos -w
```

Start the server VM after the DataVolumes are ready:

```bash
virtctl -n vms start kairos-server
virtctl -n vms console kairos-server
```

Kairos should install to `/dev/vda`, reboot, and then boot from the persistent
root disk. If it keeps returning to the installer, stop the VM and remove the
installer disk or lower its boot priority in a local test overlay before
continuing.

Start the agent only after the server API is reachable:

```bash
virtctl -n vms start kairos-agent
virtctl -n vms console kairos-agent
```

From the server console, confirm the nested cluster:

```bash
sudo k3s kubectl get nodes -o wide
```

## Reinstall And Rejoin

Record current state before destructive testing:

```bash
kubectl -n vms get vm,dv,pvc -l example.com/evaluation=kairos -o wide
sudo k3s kubectl get nodes -o wide
```

For agent rejoin testing, stop the agent, delete only its root DataVolume/PVC,
let Flux recreate it, then start the agent again. The committed root disk
DataVolumes use filesystem PVCs so CDI does not need block-device access while
creating the blank disk image:

```bash
virtctl -n vms stop kairos-agent
kubectl -n vms delete dv kairos-agent-root
flux reconcile kustomization evaluation-kairos-kubevirt -n flux-system
virtctl -n vms start kairos-agent
```

The agent should reinstall and rejoin the nested server using the same local
token.

## Upgrade And Rollback

Snapshot before upgrade when the KubeVirt snapshot API is available:

```bash
kubectl -n vms apply -f - <<'EOF'
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineSnapshot
metadata:
  labels:
    example.com/evaluation: kairos
  name: kairos-server-before-upgrade
spec:
  source:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: kairos-server
EOF
```

Run the Kairos upgrade flow from inside the guest. For this pilot, upgrade the
active system first and only upgrade recovery after the new active system is
healthy:

```bash
sudo kairos-agent upgrade --source oci:quay.io/kairos/hadron:v0.0.4-standard-amd64-generic-v4.0.3-k3sv1.35.2-k3s1
sudo reboot
```

Confirm the VM boots, K3s is healthy, and the previous boot entry or KubeVirt
snapshot can recover the pilot if the guest does not become healthy.

## Management Path Unavailable

Apply the example deny-egress policy only for the failure test:

```bash
kubectl apply -f clusters/home/evaluation/kairos-kubevirt/examples/management-path-deny-egress.example.yaml
```

Reboot one VM from the console. The installed node should still boot locally,
but remote image pulls, upgrade checks, and rejoin paths that require cluster
or internet access should fail predictably. If the cluster CNI does not enforce
NetworkPolicy, record that and repeat this test by blocking egress at the host,
router, or test namespace firewall layer.

Remove the policy after the test:

```bash
kubectl -n vms delete networkpolicy kairos-evaluation-deny-egress
```

## Cleanup

Suspend reconciliation first:

```bash
flux suspend kustomization evaluation-kairos-kubevirt -n flux-system
```

Stop and remove only the labeled evaluation resources:

```bash
virtctl -n vms stop kairos-server
virtctl -n vms stop kairos-agent
kubectl -n vms delete vm,dv,pvc,svc,virtualmachinesnapshot -l example.com/evaluation=kairos
kubectl -n vms delete secret kairos-server-user-data kairos-agent-user-data
```

Because `longhorn-virtualization` retains volumes, verify that no retained PVs
or Longhorn volumes remain for the evaluation PVCs before considering cleanup
complete. If the earlier block-mode root DataVolumes were created, delete the
failed `kairos-*-root` DataVolumes and their `prime-*` PVCs before reconciling
this fixed manifest.

## Pilot Log

Current status as of 2026-05-23:

- Pinned Kairos ISO URL returned HTTP 302 to a release asset.
- Checksum file returned
  `0bbc4bf00b4b149d15dd3cc9a281cc58590c03c5bb9dd253372cb0a46ae1d27f`.
- Temporary `virtctl v1.8.2` client worked from the devcontainer session.
- KubeVirt phase: `Deployed`.
- CDI phase: `Deployed`.
- `vms` namespace had no `vm`, `vmi`, `dv`, or `pvc` resources.
- At least one node reported allocatable KVM; node name and capacity are
  intentionally omitted from committed notes.
- No production node was migrated and no evaluation VM was created during this
  read-only preflight.

Sanitized observations still to capture during the live pilot:

- Install media checksum result.
- First boot and post-install boot result.
- Nested `kubectl get nodes` output with private addresses redacted if needed.
- Agent wipe/rejoin result.
- Upgrade and rollback result.
- Management-path unavailable behavior.
