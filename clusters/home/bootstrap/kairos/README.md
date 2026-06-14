# Kairos Bootstrap

This directory contains the public, non-secret Kairos bootstrap structure for
home-owned hardware and KubeVirt staging. The committed base templates are the
canonical Kairos user-data definitions; Flux fills their private values with
`postBuild.substituteFrom`.

The `hardware/` subdirectory contains the Git-backed physical install-media
scaffold. It renders ignored `.local/kairos/<node>/` artifacts from a shared
agent user-data template, public per-node hardware values, and the encrypted
K3s join token in the home bootstrap SOPS file.

Public cluster-specific values live inline in the Flux Kustomizations in
`clusters/home/infrastructure.yaml`. That includes app names, namespaces, disk
IDs, node names, internal API URLs, CIDRs, OIDC claim names, OIDC prefixes, and
Dex subjects.

Encrypted values are intentionally small:

- `private/flux/home/kairos-bootstrap-values.sops.yaml` supplies home hardware
  secrets and external identity values.
- `private/flux/home/kairos-staging-values.sops.yaml` supplies home-owned
  KubeVirt staging VM secrets and external identity values.

`KAIROS_K3S_TOKEN` is the hard secret. The current encrypted value set also
keeps the external Dex issuer URL and GitHub username out of public git. The
cloud-config itself stays reviewable in the public templates.

The VM overlay owns only KubeVirt-specific resources: the in-cluster K3s API
Service, `VirtualMachine` definitions, VM storage and network choices, and the
staging substitution source. It does not duplicate Kairos cloud-config. Runtime
Secrets for workloads inside the nested PR staging cluster belong under
`private/flux/staging`, not in this VM bootstrap path.
