# Node Update Strategy

This cluster keeps Kubernetes, node package updates, and reboots as separate
maintenance loops.

## K3s

K3s is upgraded by Rancher's System Upgrade Controller using
[`clusters/home/infrastructure/system-upgrade-plans/plans.yaml`](../clusters/home/infrastructure/system-upgrade-plans/plans.yaml).
The controller and CRD are reconciled from
[`clusters/home/infrastructure/system-upgrade-controller`](../clusters/home/infrastructure/system-upgrade-controller).
The server plan runs before the agent plan, both use `concurrency: 1`, and both
are restricted to weekday UTC maintenance windows. Both plans pin the same K3s
release. Renovate proposes version changes as approval-gated pull requests; do
not restore the floating `stable` channel because that bypasses review and can
pull a new control-plane binary during an otherwise unrelated maintenance
window.

Flux installs and refreshes the controller automatically. To force a reconcile
after changing the controller or plans:

```bash
flux reconcile kustomization infrastructure-system-upgrade-controller -n flux-system
flux reconcile kustomization infrastructure-system-upgrade-plans -n flux-system
```

Monitor progress with:

```bash
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs
kubectl get nodes -o wide
```

Do not skip unsupported Kubernetes minor-version upgrade paths. If the cluster
has fallen far behind the current stable channel, temporarily pin `version:` in
each plan and walk one supported minor version at a time.

Before approving a K3s or infrastructure image upgrade, verify that the
always-on node has at least 15% free on `/` and that terminated pods are not
accumulating:

```bash
kubectl get --raw /api/v1/nodes/deepthought/proxy/stats/summary \
  | jq '.node.fs | {availableBytes, capacityBytes, usedBytes}'
kubectl get pods -A --field-selector=status.phase=Failed --no-headers | wc -l
kubectl get pods -A --field-selector=status.phase=Succeeded --no-headers | wc -l
```

The `infrastructure-pod-gc` CronJob removes only terminal pods every six hours,
with bounded retry passes. It does not delete running pods, Jobs, PVCs, or
volumes. Monitoring warns below 15% root free space and when more than 500
terminal pods accumulate. For emergency recovery from a kubelet eviction loop,
run the same terminal-only cleanup manually:

```bash
kubectl delete pods -A --field-selector=status.phase=Failed --wait=false
kubectl delete pods -A --field-selector=status.phase=Succeeded --wait=false
```

## Ubuntu Packages

Ubuntu package updates are host-level state and are not reconciled by Flux.
Configure `unattended-upgrades` on each node to install OS security updates,
but leave automatic reboots disabled so Kubernetes can drain the node first.

Recommended host settings:

```text
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
```

Enable the periodic job with:

```text
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
```

Treat Ubuntu release upgrades, such as `22.04` to `24.04`, as planned node
maintenance or rebuild-and-rejoin work instead of unattended upgrades.

## Reboots

Kured is deployed by Flux from
[`clusters/home/infrastructure/kured`](../clusters/home/infrastructure/kured).
It watches for Ubuntu's `/var/run/reboot-required` sentinel, takes a cluster
lock, cordons and drains one node at a time, reboots it inside the configured
maintenance window, and then uncordons it.

The current kured window is Monday through Thursday, `03:00` to `06:00` UTC,
with `concurrency: 1`.

To pause automatic reboots:

```bash
kubectl -n kube-system annotate ds kured weave.works/kured-node-lock='{"nodeID":"manual"}'
```

To resume:

```bash
kubectl -n kube-system annotate ds kured weave.works/kured-node-lock-
```
