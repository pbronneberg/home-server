# Private Overlay Convention

This directory contains public examples and SOPS-encrypted private overlays.

- `*.example.yaml` files are safe to commit and use only reserved example
  domains, IP ranges, and placeholder secrets.
- `*.sops.yaml` files may contain real operational values, but must be encrypted
  with SOPS before commit.
- Decrypted files such as `*.plain.yaml`, `*.decrypted.yaml`, and
  `*.local.yaml` are ignored and must never be committed.

The local age identity is stored at `.sops/age/keys.txt` and is ignored by git.
Back it up outside this repository before adding real encrypted values.

Flux reconciles Kubernetes Secret manifests from `private/flux/home` with SOPS
decryption enabled. The cluster needs the matching age identity as a Kubernetes
Secret named `sops-age` in the `flux-system` namespace before those manifests
can reconcile. Workload Helm values that contain real hostnames or LAN
addresses belong here as encrypted Kubernetes Secrets.

Kairos user-data templates live in `clusters/home/bootstrap/kairos`. Public
cluster-specific substitutions live in `clusters/home/infrastructure.yaml`.
The private overlays hold only the encrypted Kairos values that are actually
secret or externally identifying: `KAIROS_K3S_TOKEN`, the external Dex issuer
URL, and the GitHub username used for SSH key import. Use
`private/flux/home/kairos-bootstrap-values.sops.yaml` for home hardware and
`private/flux/home/kairos-staging-values.sops.yaml` for the home-owned KubeVirt
staging VMs. Rotate staging and hardware K3s tokens separately.

`private/flux/staging` is reserved for runtime Secrets applied inside the
ephemeral PR staging cluster. Those Secrets should use the same object names as
home workloads, but with disposable credentials and staging endpoints.

Kairos PR staging uses Flux Operator's GitHub Pull Request ResourceSet pattern.
Store the GitHub App credentials for the `ResourceSetInputProvider`, generated
PR `GitRepository` sources, and Flux GitHub webhook Receiver as a SOPS-encrypted
Secret named `github-app-auth` in the `flux-system` namespace before resuming
`staging-kairos-prs`. The Secret also carries the Receiver HMAC `token` and
`FLUX_WEBHOOK_HOST` substitution value. The app should have read-only repository
contents and pull request metadata access for this repository only.

Home Assistant is captured with two private Secrets:

- `home-assistant-config.sops.yaml` stores `configuration.yaml`, generated from
  the live `homeassistant/homeassist-config` Secret.
- `home-assistant-values.sops.yaml` stores Helm values such as ingress and
  config Secret wiring.

Monitoring uses `monitoring-values.sops.yaml` for real ingress hostnames. The
public kube-prometheus-stack values keep ingresses disabled so placeholder
example domains never request public ACME certificates.

My English Playground can use an optional
`myenglishplayground-nl-private-values` Secret for WordPress, MariaDB, and
Memcached credentials. Start from
`private/flux/home/myenglishplayground-nl-values.example.yaml`, encrypt the real
Secret as SOPS, and add it to this overlay only after replacing every
placeholder.

Photobooth API private values should override the public placeholder MongoDB
and MinIO credentials. Start from
`private/flux/home/photobooth-api-values.example.yaml` when rotating those
secrets.

The shared Traefik basic-auth fallback expects a default namespace Secret named
`authorized-users`. Start from
`private/flux/home/authorized-users.example.yaml`, store only htpasswd hashes,
and commit the real Secret only as a SOPS-encrypted file.

GitHub-backed ingress authentication uses
`oauth2-proxy-values.sops.yaml` for the OAuth app credentials, allowed GitHub
organization, team, or user allowlist, auth callback hostname, and cookie
domain. Keep `github_org` or `github_users` configured, and use `github_team`
only to narrow a configured organization, so wildcard email domains cannot
authenticate every GitHub account.
The committed example keeps `replicaCount: 0`; cluster runtime values enable one replica
because protected ingresses depend on oauth2-proxy being available.

Shared Dex OIDC federation uses `dex-substitutions.sops.yaml` for the live
auth host, issuer URL, and GitHub redirect URI. Dex reuses the GitHub OAuth
client ID and secret from `oauth2-proxy-values.sops.yaml`; do not duplicate
those credentials into Dex-specific Secrets.

After restoring the age identity on a workstation, run `make
sops-recovery-drill` from the repository root before relying on a fresh Flux
bootstrap. The drill is documented in
`docs/sops-age-recovery-drill.md`.
