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
organization or team, auth callback hostname, and cookie domain. The committed
placeholder keeps `replicaCount: 0`; set it to `1` only after replacing the
example values with real private values.

After restoring the age identity on a workstation, run `make
sops-recovery-drill` from the repository root before relying on a fresh Flux
bootstrap. The drill is documented in
`docs/sops-age-recovery-drill.md`.
