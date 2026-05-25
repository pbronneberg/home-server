# Kairos Node OS Pilot Decision

## Status

Adopt for staging VMs and home-owned Kairos hardware definitions only.

## Context

The current supported home-cluster node baseline is Ubuntu plus K3s. That path
is familiar and repairable, but it leaves OS drift, release upgrades, and node
rebuilds as host-level maintenance outside GitOps.

Kairos is a candidate immutable node OS for reducing drift and making
install/reinstall/upgrade behavior more repeatable. It must be evaluated away
from production control-plane nodes because node identity, recovery material,
storage, and management access are sensitive parts of the home-lab recovery
contract.

## Decision

Use Kairos for the KubeVirt staging cluster and keep real-hardware Kairos
definitions as first-class `home` configuration until the following are proven:

- A node can install, reboot, and run K3s from sanitized configuration.
- A node can be wiped or reset and rejoin without preserving hidden local state.
- OS upgrade and rollback behavior are understood without relying on a healthy
  production cluster.
- Flux bootstrap, SOPS recovery, backups, and K3s API recovery remain viable
  when a Kairos node or its management path is unavailable.

No production `home` control-plane node is migrated by this decision. Kairos
hardware is allowed to become a future replacement candidate only after Flux,
SOPS recovery, backups, ingress, storage, and workload promotion have their own
acceptance checks.

## Consequences

- The repository carries a home-owned KubeVirt staging substrate, a separate
  `clusters/staging` Flux root for the nested VM cluster, and public-safe
  Kairos bootstrap and KubeVirt staging overlays under `clusters/home/bootstrap/kairos`.
- Real K3s tokens, kubeconfigs, SSH private keys, local hostnames, and LAN
  addresses remain local-only or encrypted.
- The decision should move back to defer if staging or Kairos hardware cannot
  complete install, rejoin, upgrade, rollback, Flux bootstrap, or
  management-path failure tests.
