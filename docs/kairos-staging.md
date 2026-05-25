# Kairos PR Staging Cluster

The staging cluster is the Kairos K3s pair that runs as KubeVirt VMs in the
home cluster. Its job is to rehearse important PRs against a disposable VM-based
cluster, using the home workload definitions from the PR branch.

## Shape

- Home cluster owns: KubeVirt, CDI, Longhorn VM volumes, VM Services, the public
  Kairos templates in `clusters/home/bootstrap/kairos`, and the small home-side
  VM bootstrap Secret `private/flux/home/kairos-staging-values.sops.yaml`.
- Staging cluster owns: Flux bootstrapped at `clusters/staging`, thin workload
  Kustomizations that point at `clusters/home/workloads/*`, and staging-safe
  runtime Secrets from `private/flux/staging`.
- The staging Flux root deliberately excludes node-lifecycle and substrate
  pieces such as Kured, system-upgrade plans, KubeVirt, and Kairos bootstrap.

Do not copy workload manifests into `clusters/staging`. The point is to test the
home definitions from the PR branch with staging-safe values.

## PR Rehearsal Trigger

The intended trigger is the Flux Operator GitHub Pull Request ResourceSet
pattern. The home cluster runs Flux Operator, scans this repository for PRs with
the `deploy/kairos-staging` label, and generates a PR-specific VM Kustomization
plus installer Job inside the cluster. CI does not need a kubeconfig; it can
build artifacts and, eventually, add or remove the PR label.

Before enabling the trigger, create the GitHub App auth Secret expected by the
`ResourceSetInputProvider` and generated PR `GitRepository` sources. Download the
GitHub App private key to an ignored local path, then generate a SOPS-encrypted
Secret:

```bash
mkdir -p .local/github-app
# Save the downloaded GitHub App PEM as:
# .local/github-app/home-server-flux-staging.private-key.pem

flux create secret githubapp github-app-auth \
  --namespace=flux-system \
  --app-id="${GITHUB_APP_ID}" \
  --app-installation-owner=pbronneberg \
  --app-private-key=.local/github-app/home-server-flux-staging.private-key.pem \
  --export > private/flux/home/github-app-auth.sops.yaml

sops --encrypt --encrypted-regex '^(data|stringData)$' \
  --in-place private/flux/home/github-app-auth.sops.yaml
```

Add `github-app-auth.sops.yaml` to `private/flux/home/kustomization.yaml` before
reconciling `infrastructure-private-secrets`. The app needs read-only repository
contents and pull request metadata permissions for `pbronneberg/home-server`.

Enable the controller path explicitly:

```bash
flux resume kustomization staging-kairos-prs -n flux-system
flux reconcile kustomization infrastructure-flux-operator -n flux-system --with-source
flux reconcile kustomization staging-kairos-prs -n flux-system --with-source
```

Then label one PR at a time with `deploy/kairos-staging`. The generated Job
removes stale Kairos staging VMs/DataVolumes/PVCs, waits for Flux to recreate
the VM substrate from the PR commit, installs the server and agent, and lets the
server user-data bootstrap Flux inside the nested cluster against the PR branch.

Keep the normal `staging-kairos-kubevirt` Kustomization suspended while using
this PR trigger; both paths own the same fixed VM names.

## Manual VM Install

The manual path remains useful while debugging the VM substrate itself. Review
or rotate the small home-owned VM bootstrap value Secret, then reconcile the
home-side substrate. Flux combines the encrypted values with public
substitutions from `clusters/home/infrastructure.yaml`:

```bash
make sops-edit SOPS_FILE=private/flux/home/kairos-staging-values.sops.yaml
flux reconcile kustomization flux-system -n flux-system --with-source
flux reconcile kustomization infrastructure-private-secrets -n flux-system --with-source
flux reconcile kustomization staging-kairos-kubevirt -n flux-system
make staging-preflight
```

For a clean manual run, delete only the staging root DataVolumes after stopping
both VMs. The installer and root disks are disposable for this cluster:

```bash
virtctl -n vms stop kairos-agent || true
virtctl -n vms stop kairos-server || true
kubectl -n vms delete dv kairos-agent-root kairos-server-root
flux reconcile kustomization staging-kairos-kubevirt -n flux-system
make staging-preflight
make staging-install-server
make staging-verify-server
make staging-install-agent
make staging-verify-agent
```

## Nested Flux

The Kairos server user-data can bootstrap Flux inside the nested cluster when
`KAIROS_STAGING_FLUX_BOOTSTRAP` is set to `true` by the PR ResourceSet. The
bootstrap downloads the Flux manifests from the PR branch and patches the nested
Flux `GitRepository` to follow that branch.

Create the `sops-age` Secret in the staging cluster before expecting
`private/flux/staging` to reconcile. That overlay must contain staging-safe
runtime Secrets with the same names expected by the home manifests. A later
hardening step should inject a staging-only age key declaratively instead of
using a manual kubeconfig.

## Acceptance

```bash
KAIROS_STAGING_KUBECONFIG=.local/kairos/staging-kubeconfig make staging-verify
kubectl --kubeconfig .local/kairos/staging-kubeconfig -n flux-system get kustomizations
```

The staging verification checks that the Flux controllers are running and that
the home infrastructure/workload rehearsal Kustomizations exist and report
`Ready=True`. Reachability checks should be added per PR for the workloads that
made the VM rehearsal worthwhile.

On `kairos-server`, confirm the node shape still matches the future hardware
recipe:

```bash
sudo systemctl cat k3s.service | grep -E 'cluster-domain=home-server.bronneberg.local|secrets-encryption|anonymous-auth=false|profiling=false|read-only-port=0'
sudo systemctl cat k3s.service | grep -- '--disable=traefik,servicelb' && echo 'unexpected disable flag' || echo 'bundled traefik/servicelb kept enabled'
sudo k3s kubectl get nodes -o wide
```

## Cleanup

Suspend only the home-side VM Kustomization when parking staging:

```bash
flux suspend kustomization staging-kairos-kubevirt -n flux-system
```

For a full PR rehearsal cleanup, delete the disposable VMs/DataVolumes and any
retained Longhorn volumes labeled `home-server.dev/evaluation=kairos`. Do not
reuse staging runtime Secrets for production.
