# SOPS Age Recovery Drill

Use this drill after restoring `.sops/age/keys.txt` on a fresh management
workstation or before trusting a fresh cluster bootstrap. It validates that the
restored age identity can recreate the Flux decryption secret shape, decrypt
all committed private SOPS files, and render the decrypted private Flux overlay
without writing plaintext into the repository.

## Prerequisites

- Restore the age identity to `.sops/age/keys.txt`.
- Use the devcontainer or install `sops`, `kubectl`, and either `kustomize` or
  `kubectl kustomize`.
- Do not run this from inside a shared directory that syncs temporary files to a
  cloud service.

## Local Drill

```bash
make sops-recovery-drill
```

The target performs these checks:

- verifies `.sops/age/keys.txt` exists
- runs a client-side dry run for the `flux-system/sops-age` Secret that Flux
  expects
- decrypts every committed `private/**/*.sops.yaml` file into a temporary
  directory
- renders the decrypted `private/flux/home` Kustomize overlay
- removes the temporary plaintext directory before exiting

## Fresh Cluster Confirmation

After a fresh K3s API is reachable, recreate the same Flux decryption Secret
from the restored age identity:

```bash
kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic sops-age \
  -n flux-system \
  --from-file=age.agekey=.sops/age/keys.txt \
  --dry-run=client \
  -o yaml | kubectl apply -f -
```

Bootstrap or reconcile Flux, then confirm the private overlay is healthy:

```bash
flux reconcile kustomization infrastructure-private-secrets -n flux-system --with-source
flux get kustomization infrastructure-private-secrets -n flux-system
kubectl get secrets -n websites tls-proxies-values
kubectl get secrets -n longhorn-system longhorn-admin-values
```

Record the date, restored key source, cluster identity decision, and command
results in an ignored local note or a sanitized follow-up issue. Do not commit
the age identity, decrypted overlays, kubeconfig, token, or real hostnames.

## Recorded Drill

- 2026-05-14: `make sops-recovery-drill` passed from the restored local age
  identity in the devcontainer workspace. No live cluster resources were
  changed.
