# Flux Migration Parity

This note records the current parity point for replacing legacy
Helmsman-style infrastructure handling with pull-based Flux reconciliation.

## Flux-Owned Infrastructure

Flux reconciles the cluster entrypoint under `clusters/home`.

| Capability | Flux path | Notes |
| --- | --- | --- |
| Namespaces | `clusters/home/infrastructure/namespaces` | Preserves existing namespaces and adds `monitoring` for kube-prometheus-stack. |
| Helm sources | `clusters/home/infrastructure/sources` | Defines Jetstack, Longhorn, and Prometheus Community repositories. |
| Private values | `private/flux/home` | SOPS-encrypted Kubernetes Secrets are decrypted by Flux with `flux-system/sops-age`. |
| cert-manager | `clusters/home/infrastructure/cert-manager` | Installs CRDs through the Flux `HelmRelease`. |
| cert-manager issuers | `clusters/home/infrastructure/cert-manager-issuers` | Uses public-safe example contact values in committed files. |
| Longhorn | `clusters/home/infrastructure/longhorn` | Preserves the `longhorn` release in `longhorn-system`. |
| Longhorn storage class | `clusters/home/infrastructure/longhorn-storageclasses` | Preserves `longhorn-retain`. |
| Monitoring | `clusters/home/infrastructure/monitoring` | Installs `kube-prometheus-stack` as release `prometheus-stack` in `monitoring`. |
| Traefik middlewares | `clusters/home/infrastructure/traefik-middlewares` | Preserves `redirect-https` and `basic-auth` middleware names. |
| Workloads | `clusters/home/workloads.yaml` | Reconciles TLS proxies and Longhorn admin after their dependencies are ready. |

## Ordering

`clusters/home/infrastructure.yaml` keeps ordering explicit:

1. namespaces
2. Helm repositories
3. SOPS private values
4. cert-manager
5. cert-manager issuers
6. Longhorn
7. retained Longhorn storage class
8. Traefik middlewares
9. monitoring

Workloads in `clusters/home/workloads.yaml` depend on the infrastructure pieces
they consume, including private values and Traefik middlewares.

## Validation

Run these checks before merging Flux migration changes:

```bash
make ci
make sops-recovery-drill
```

`make ci` validates YAML, Helm charts, rendered local application charts, and
all Flux/Kustomize overlays. `make sops-recovery-drill` proves that the restored
age identity can decrypt and render private Flux overlays without committing
plaintext.

## Rollback

Flux is pull-based and runs inside the cluster. GitHub-hosted Actions do not
receive kubeconfig or cluster credentials.

If a Flux-managed infrastructure change needs rollback:

1. Revert the Git commit or merge a corrective pull request.
2. Let Flux reconcile `main`, or from a trusted workstation run:

```bash
flux reconcile source git flux-system -n flux-system
flux reconcile kustomization flux-system -n flux-system --with-source
```

3. If a specific Kustomization must be paused during investigation, suspend it
   from a trusted workstation:

```bash
flux suspend kustomization <name> -n flux-system
```

4. Resume it after the corrective commit is ready:

```bash
flux resume kustomization <name> -n flux-system
```

Legacy files under `infra/` remain rollback references only. They are not the
steady-state reconciler path; `clusters/home` is the desired state.
