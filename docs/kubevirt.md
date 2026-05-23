# KubeVirt

KubeVirt is installed through Flux from pinned upstream release manifests:

- KubeVirt `v1.8.2`
- Containerized Data Importer (CDI) `v1.65.0`

KubeVirt `v1.8` is built for Kubernetes `v1.35` and supports Kubernetes
`v1.33` through `v1.35`. This matches the K3s stable channel used by the
System Upgrade Controller plans at the time this was added.

## Storage

VM disk imports use Longhorn by default through the
`longhorn-virtualization` StorageClass. It is annotated with
`storageclass.kubevirt.io/is-default-virt-class: "true"`, which makes it the
default virtualization storage class without changing the Kubernetes-wide
default StorageClass.

The class sets `migratable: "true"` and selects the `longhorn-data` disk tag so
VM DataVolumes use the standard `/data/longhorn` Longhorn disk. CDI's Longhorn
storage profile defaults those DataVolumes to `ReadWriteMany` block volumes.
That is the Longhorn mode intended for KubeVirt live migration and future
multi-node maintenance.

Use the `vms` namespace for guest workloads. It is privileged because KubeVirt
launcher pods need access to host virtualization devices such as `/dev/kvm`.

## Node Requirements

Every physical node expected to run VMs needs hardware virtualization enabled
in firmware and exposed to Linux:

```bash
ls -l /dev/kvm
```

KubeVirt can schedule VMs only onto nodes that expose KVM. New nodes do not
need a repository change if they join the K3s cluster normally, run Linux, have
compatible CPU virtualization enabled, and can attach Longhorn volumes.

For live migration between physical nodes, keep CPU models reasonably
compatible across the migration pool. If you later mix very different CPU
generations, add node labels and VM node selectors so each VM family stays on
compatible hosts.

## Staging K3s VMs

For a multi-VM K3s staging cluster, create the VMs in the `vms` namespace and
use DataVolumes without an explicit `storageClassName` so they land on
`longhorn-virtualization`.

The simplest networking model is KubeVirt's default pod network with masquerade
interfaces and Kubernetes Services for the K3s API endpoint. If the guest K3s
nodes need to look like first-class LAN machines, add Multus later and attach a
bridge or macvlan network; that is intentionally not enabled by default here.

For Windows guests, use virtio storage and network drivers during installation.
