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
- Lifecycle policy: excluded from manual-worker shutdown control.

Expected live labels and annotations:

```yaml
metadata:
  labels:
    home-server.dev/node-role: core
    home-server.dev/storage: permanent
```

Expected Longhorn tags:

- Node tag: `deepthought`
- Disk tag: `permanent-ssd`

The only registered Longhorn disk on `deepthought` is the permanent SSD at
`/data/longhorn`. Do not re-add `/var/lib/longhorn` as a Longhorn disk; keeping
replicas off the OS filesystem isolates durable volume growth from kubelet and
container-runtime storage.

A separate USB SSD is mounted at `/srv/longhorn-backup` and exported over NFSv4
as Longhorn's backupstore. It is a backup target only: never register this path
as a Longhorn replica disk. The encrypted private values contain the real target
URL; see [Longhorn backups](longhorn-backups.md) for operations and recovery.

### milliard

- Role: K3s agent.
- Power policy: manual-start worker; an operator uses the physical power button.
- Storage role: optional node-local SSD Longhorn storage.
- Workload role: workloads intentionally tied to `milliard`, such as scratch
  workloads, experiments, or VMs.

Expected Longhorn tags when local storage is enabled:

- Node tag: `milliard`
- Disk tag: `local-ssd`

### marvin

- Role: K3s agent.
- Power policy: manual-start worker; an operator uses the physical power button
  before workloads requiring `marvin` can schedule.
- Storage role: compute-only unless local Longhorn storage is explicitly
  enabled later.
- Workload role: workloads that explicitly require `marvin`.

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

Manual shutdown requests use Longhorn's explicit eviction workflow before drain
and poweroff. Strict-local volumes and failed or timed-out evacuation block the
request and leave the node powered on.

## Manual Worker Lifecycle

The `infrastructure-manual-worker-lifecycle` Kustomization runs a
single-concurrency reconciler on `deepthought`. It responds only to explicit
shutdown requests; ordinary cordons, including K3s upgrades, never power off a
worker. See [Manual worker lifecycle](manual-worker-lifecycle.md).
