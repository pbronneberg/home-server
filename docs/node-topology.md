# Node Topology

This repository keeps public topology role-based. Do not commit real MAC
addresses, LAN IP addresses, SSH endpoints, host keys, disk serials, or
broadcast addresses. Put those values in SOPS-encrypted private overlays.

## Nodes

### deepthought

- Role: K3s server/control-plane.
- Power policy: always on.
- Storage role: permanent Longhorn storage.
- Workload role: default target for durable services such as Home Assistant and
  Grafana.
- Autoscaler policy: excluded from all autoscaler node groups.

Expected live labels and annotations:

```yaml
metadata:
  labels:
    home-server.dev/node-role: core
    home-server.dev/storage: permanent
    home-server.dev/autoscaled: "false"
  annotations:
    cluster-autoscaler.kubernetes.io/scale-down-disabled: "true"
```

Expected Longhorn tags:

- Node tag: `deepthought`
- Disk tag: `permanent-ssd`

### milliard

- Role: K3s agent.
- Power policy: manual or autoscaler-managed only when no local Longhorn volumes
  are attached.
- Storage role: optional node-local SSD Longhorn storage.
- Workload role: workloads intentionally tied to `milliard`, such as scratch
  workloads, experiments, or VMs.

Expected Longhorn tags when local storage is enabled:

- Node tag: `milliard`
- Disk tag: `local-ssd`

### marvin

- Role: K3s agent.
- Power policy: upstream homelab-autoscaler pilot worker candidate.
- Storage role: compute-only for the active autoscaler pilot. Optional
  node-local Longhorn storage on the node's single SSD using `/data/longhorn`
  can be enabled later, but that should opt the node out of routine
  autoscale-down while local volumes exist.
- Workload role: stateless workloads, intentionally ephemeral workloads, or
  workloads deliberately using `longhorn-local` with affinity for `marvin`.

Expected Longhorn tags when local storage is enabled:

- Node tag: `marvin`
- Disk tag: `local-ssd`

## Storage Tiers

- `longhorn`: current durable/default storage class for services that must remain
  available when workers are powered off.
- `longhorn-permanent`: future deepthought-only durable storage class. Do not use
  it for existing workloads until a backup/restore migration has been planned
  and the `permanent-ssd` Longhorn disk tag exists on the intended disk.
- `longhorn-local`: single-replica local SSD storage for any node tagged with a
  `local-ssd` Longhorn disk. This class uses `strict-local` data locality and
  `WaitForFirstConsumer`, so Kubernetes chooses the node first and Longhorn keeps
  the only replica local to the attached workload.

Autoscaling must not trigger Longhorn replica evacuation or rebuilds. Any node
with Longhorn replicas or attached Longhorn volumes is outside routine
scale-down.

## Autoscaler Topology

The autoscaler control plane runs on `deepthought` through the
`infrastructure-homelab-autoscaler` Kustomization. It installs the upstream
`homecluster-dev/homelab-autoscaler` operator in
`homelab-autoscaler-system`.

Only worker nodes should be represented by upstream autoscaler `Node` CRs.
`deepthought` must remain outside all autoscaler `Group` resources and must keep
the `cluster-autoscaler.kubernetes.io/scale-down-disabled: "true"` annotation.
