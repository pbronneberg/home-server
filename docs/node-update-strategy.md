# Node Update Strategy

This cluster keeps Kubernetes, node package updates, and reboots as separate
maintenance loops.

## K3s

K3s is upgraded by Rancher's System Upgrade Controller using
[`infra/system-upgrader/upgrade-plans.yml`](../infra/system-upgrader/upgrade-plans.yml).
The server plan runs before the agent plan, both use `concurrency: 1`, and both
are restricted to weekday UTC maintenance windows.

Install or refresh the controller from a trusted workstation with cluster admin
access:

```bash
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/crd.yaml
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/system-upgrade-controller.yaml
kubectl apply -f infra/system-upgrader/upgrade-plans.yml
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
