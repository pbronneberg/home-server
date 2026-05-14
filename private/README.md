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
