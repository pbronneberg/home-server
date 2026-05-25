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

## Clean VM Install

Review or rotate the small home-owned VM bootstrap value Secret, then reconcile
the home-side substrate. Flux combines the encrypted values with public
substitutions from `clusters/home/infrastructure.yaml`:

```bash
make sops-edit SOPS_FILE=private/flux/home/kairos-staging-values.sops.yaml
flux reconcile kustomization flux-system -n flux-system --with-source
flux reconcile kustomization infrastructure-private-secrets -n flux-system --with-source
flux reconcile kustomization staging-kairos-kubevirt -n flux-system
make staging-preflight
```

For a clean staging run, delete only the staging root DataVolumes after stopping
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

## PR Flux Bootstrap

After the staging K3s API is reachable, bootstrap Flux to `clusters/staging` on
the PR branch being tested. Keep the bootstrap kubeconfig outside git.

```bash
mkdir -p .local/kairos
virtctl -n vms port-forward vm/kairos-server 16443:6443

flux bootstrap github   --owner=pbronneberg   --repository=home-server   --branch=<pr-branch>   --path=clusters/staging   --personal   --kubeconfig=.local/kairos/staging-kubeconfig
```

Create the `sops-age` Secret in the staging cluster before expecting
`private/flux/staging` to reconcile. That overlay must contain staging-safe
runtime Secrets with the same names expected by the home manifests.

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
