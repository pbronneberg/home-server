# Longhorn USB Backups

Longhorn uses a dedicated USB SSD as an NFSv4 backupstore. The backup device is
separate from `/data/longhorn`, so loss of the Longhorn data SSD can be recovered
without depending on its replicas. It is still attached to the same physical
host and therefore is not an off-site or host-loss backup.

The real target URL is kept in
`private/flux/home/longhorn-backup-values.sops.yaml`. The public example is
`private/flux/home/longhorn-backup-values.example.yaml`.

## Backup policy

- `daily-volume-backup` runs at 02:17 UTC, retains 14 backups per volume, and
  performs a full block refresh after seven incremental backups.
- The `default` recurring-job group covers volumes that do not have an explicit
  recurring-job selector.
- Detached volumes are temporarily attached for their scheduled backup.
- `weekly-system-backup` runs Sundays at 03:47 UTC and retains eight Longhorn
  system-resource bundles. It creates a volume backup only when the latest one
  is absent or stale.
- Backups are crash-consistent Longhorn snapshots. Databases that require
  transaction-aware recovery still need application-level backup procedures.

Longhorn owns backup retention. Do not add filesystem-level deletion or rotation
inside the backupstore.

## Host preparation

Inventory the target before formatting it. Confirm the device model, byte size,
partition layout, mount state, and existing contents. Replace placeholders below
with the observed stable UUID and cluster networks; never copy a device name from
another machine blindly.

The host baseline is:

```text
package: nfs-kernel-server
filesystem: ext4, label longhorn-backup, zero reserved blocks
mount: UUID=<backup-filesystem-uuid> /srv/longhorn-backup ext4 defaults,nofail,noatime,x-systemd.device-timeout=30s,x-systemd.required-by=nfs-server.service 0 2
owner/mode: nobody:nogroup 0770
export: /srv/longhorn-backup <node-address>(rw,sync,no_subtree_check,root_squash) <pod-cidr>(rw,sync,no_subtree_check,root_squash)
```

After editing host configuration, validate before enabling Longhorn:

```bash
sudo findmnt --verify --verbose
sudo mount /srv/longhorn-backup
sudo exportfs -rav
sudo systemctl enable --now nfs-server
findmnt /srv/longhorn-backup
df -hT /srv/longhorn-backup
sudo exportfs -v
```

## Verification

Check the target, schedules, and latest backup timestamps:

```bash
kubectl -n longhorn-system get backuptarget default
kubectl -n longhorn-system get recurringjobs.longhorn.io
kubectl -n longhorn-system get backups.longhorn.io
kubectl -n longhorn-system get systembackups.longhorn.io
kubectl get --raw \
  /api/v1/namespaces/longhorn-system/services/http:longhorn-backend:9500/proxy/metrics \
  | grep longhorn_volume_last_backup_at
```

On the host, confirm the backupstore is on the USB filesystem rather than the
Longhorn data disk:

```bash
findmnt -T /srv/longhorn-backup
findmnt -T /data/longhorn
sudo du -sh /srv/longhorn-backup
```

## Restore drill

Run this after initial setup, Longhorn upgrades, backup-target changes, and at
least quarterly:

1. Select a current backup of a non-critical small volume.
2. Restore it under a temporary, unique Longhorn volume name; never overwrite the
   source volume.
3. Attach the restored volume to a disposable pod or maintenance workload and
   verify that the filesystem mounts and expected data can be read.
4. Record the backup URL, restore duration, validation performed, and result in
   private operational notes.
5. Delete only the temporary pod, PVC, PV, and restored Longhorn volume after
   proving they are not the source objects.

For full recovery, install Longhorn, restore the encrypted target values, wait
for the target to become available, and then restore volumes before starting
stateful workloads. A Longhorn system backup restores Longhorn-managed resources,
not arbitrary workload Deployments, cluster secrets, the K3s datastore, or the
node's host configuration.

## Failure and rollback

If the USB device is absent, the `nofail` mount keeps the node bootable while the
explicit systemd dependency prevents NFS from exporting the empty mountpoint on
the root filesystem. The missing-mount and stale-backup alerts should fire. Stop
NFS until the device is mounted:

```bash
sudo systemctl stop nfs-server
findmnt /srv/longhorn-backup
```

To disable backup scheduling without deleting existing backups, suspend or remove
the recurring jobs and clear the Longhorn backup target. To retire the host
target, stop NFS, remove its export, unmount the filesystem, and remove only the
matching `/etc/fstab` entry. Do not format either `/data/longhorn` or the backup
SSD during rollback.
