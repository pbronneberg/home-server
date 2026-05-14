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
can reconcile.
