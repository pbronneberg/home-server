# Home-Lab Bootstrap And Recovery Contract

This document defines the minimum contract for rebuilding the home lab from
bare hardware or a fresh OS install without depending on workloads that already
run inside the Kubernetes cluster.

It is intentionally documentation-only. It does not change live cluster
behavior, create GitOps resources, rename workloads, rotate secrets, or migrate
storage.

## Recovery Principles

- Git is the desired-state record for public-safe configuration, Helm charts,
  infrastructure declarations, runbooks, and CI validation.
- SOPS-encrypted files under `private/*.sops.yaml` are the versioned place for
  real private values that must be tracked.
- Ignored local files are the place for private material that must not be
  committed, such as `.sops/age/keys.txt`, kubeconfigs, node tokens, decrypted
  overlays, and local denylist values.
- A NAS or management box may hold recovery material, backups, and optional
  mirrors, but the Kubernetes cluster must not be required to be healthy before
  those materials are reachable.
- In-cluster services such as Flux, Rancher, Longhorn, cert-manager, and
  monitoring are recovery targets. They are not bootstrap prerequisites.
- Public documentation uses reserved example domains, repositories, and IP
  ranges. Real hostnames, LAN addresses, tokens, and provider details belong in
  SOPS-encrypted overlays or ignored local notes.

## Source Of Truth

| Area | Source of truth | Privacy level | Notes |
| --- | --- | --- | --- |
| Repository desired state | GitHub `main` plus reviewed pull requests | Public-safe | This repo records the intended platform shape. |
| Infrastructure reconciler | `clusters/home/` | Public-safe plus SOPS | Flux reconciles the committed cluster entrypoint. |
| Application charts | `application/*` Helm charts | Public-safe with placeholders | Preserve release names, namespaces, PVC names, hostnames, and secrets unless a migration plan says otherwise. |
| Public example topology | `private/home.example.yaml` | Public-safe | Uses reserved example values only. |
| Private topology and secrets | `private/*.sops.yaml` | Encrypted private | Must stay encrypted before commit. |
| Local decryption identity | `.sops/age/keys.txt` | Ignored private | Back up outside the repository before relying on encrypted overlays. |
| Publication safety checks | `make public-check` | Public-safe | Run before changing repository visibility or touching redaction-sensitive files. |

## Recovery Material

Keep this material outside the cluster, preferably on a NAS or management box
with its own backup. Do not rely on Longhorn, Flux, Rancher, or other
in-cluster services to access it.

| Material | Required for | Suggested storage | Commit status |
| --- | --- | --- | --- |
| SOPS age identity for `.sops/age/keys.txt` | Decrypting `private/*.sops.yaml` | Password manager, offline backup, and management box | Never commit |
| K3s server token | Rejoining servers or agents, preserving cluster identity during recovery | Management box secret store or encrypted backup | Never commit |
| Admin kubeconfig | Initial API access after reinstall or restore | Management box, encrypted at rest | Never commit |
| K3s datastore backup | Restoring cluster state when keeping the same cluster identity | NAS backup target outside Kubernetes | Never commit |
| Longhorn backup target and restore notes | Restoring PVC-backed workloads | NAS NFS export or S3-compatible NAS service | Store real target details in SOPS or ignored notes |
| DNS provider and local DNS assumptions | Restoring ingress reachability and certificate challenges | Password manager and SOPS-encrypted private overlay | No plaintext real topology |
| TLS issuer assumptions | Restoring cert-manager behavior | Repo placeholders plus SOPS private values | Public placeholders only |
| Repository clone or mirror | Recovering when GitHub or internet access is unavailable | Management box mirror or NAS bare clone | Public-safe, but avoid decrypted private files |
| Helm chart and container image cache | Optional offline rebuild acceleration | NAS cache or management box | Public-safe metadata only |
| Hardware and OS notes | Rebuilding the node before Kubernetes exists | Ignored local notes or sanitized docs | No real topology in plaintext |

The K3s datastore backup procedure depends on the selected cluster topology.
The current README documents a simple K3s install. The K3s lifecycle work should
decide whether the supported recovery path is single-server, HA embedded etcd,
or another topology before broadening automated upgrades.

## Bare-Node Bootstrap Path

This is the minimum manual path from blank node to a reachable Kubernetes API
and then to repository-driven reconciliation.

1. Prepare a management workstation or NAS that is outside the cluster.

   It must have this repository, the local SOPS age identity, admin access to
   the backup location, and the tools needed for the selected recovery path.
   Decrypt private overlays only when needed, and write plaintext only to
   ignored files such as `*.decrypted.yaml` or `*.local.yaml`.

2. Install the base OS and private network configuration.

   Use local-only notes for real hostnames, LAN addresses, storage mounts, and
   DNS details. Public docs should continue to use reserved example values such
   as `home.example` and `192.0.2.0/24`.

3. Install K3s and make the Kubernetes API reachable.

   The current bootstrap command lives in the README. After install, immediately
   copy the server token and admin kubeconfig into the external recovery store.
   Verify the API from the management workstation before installing
   higher-level services.

4. Restore or initialize cluster state deliberately.

   If restoring an existing cluster identity, restore the K3s datastore before
   reconciling workloads. If creating a fresh cluster, treat this as a new
   identity and document any workload-level restore steps that follow.

5. Reconcile platform infrastructure.

   Bootstrap Flux only after the API is reachable, create the Flux SOPS
   decryption secret from the restored age identity, and let Flux reconcile the
   committed cluster entrypoint under `clusters/home/`. Validate the restored
   identity with `make sops-recovery-drill`; the drill is documented in
   `docs/sops-age-recovery-drill.md`.

6. Restore persistent workload data.

   Restore Longhorn volumes or other PVC data only after the storage layer and
   backup target are available. Use non-critical workloads for restore drills
   before relying on broad recovery.

7. Restore ingress, DNS, and TLS reachability.

   Confirm DNS points at the intended ingress path, cert-manager issuers are
   healthy, and certificates are issued before considering user-facing workloads
   recovered.

8. Record the recovery result.

   Capture the date, cluster identity decision, restored backup versions, manual
   commands, failures, and any follow-up issues. Do not commit private values in
   the drill notes.

## Private And Public Boundaries

- Safe to commit: runbooks, placeholder values, Helm chart templates,
  public-safe defaults, CI checks, and SOPS-encrypted private overlays.
- Safe only when encrypted with SOPS: real domains, LAN ranges, backup target
  URLs, provider account identifiers, and operational private values that must
  be versioned.
- Never commit: age identities, kubeconfigs, K3s tokens, plaintext decrypted
  overlays, passwords, API tokens, private keys, real local denylist values, and
  local machine exports.

## Follow-Up Work

- Define the NAS-backed backup baseline, including K3s datastore and Longhorn
  backup procedures.
- Modernize the K3s lifecycle and decide the supported topology before changing
  OS or automated upgrade strategy.
- Keep SOPS and age recovery tested for in-cluster GitOps decryption.
- Keep Flux bootstrap and rollback validation current with the live cluster.

## Acceptance Checklist

- A bare-node path exists from OS install to reachable K3s API to repository
  reconciliation.
- Recovery material is listed explicitly and kept outside the cluster.
- Public examples are separated from encrypted and ignored private details.
- The contract avoids circular dependencies on Flux, Rancher, Longhorn, or any
  other in-cluster workload.
- No live cluster behavior changes are part of this document.
