# home-server

Configuration for my home server.

## Maintenance Workflow

This repository is maintained through small pull requests, GitHub-hosted
Actions, and repo-local agent instructions.

The home lab modernization strategy starts with the bootstrap and recovery
contract in [docs/bootstrap-recovery-contract.md](docs/bootstrap-recovery-contract.md).
It defines the minimum path from bare OS to reachable K3s API to repository
reconciliation without depending on in-cluster services that may be down during
recovery.

Run the same checks inside the devcontainer that CI runs on GitHub public
runners:

```bash
make ci
```

To run only the report-only security posture checks:

```bash
make security-audit
```

`make ci` configures the Helm chart repositories it needs in a temporary cache
under `/tmp/home-server-helm-repositories`, so a fresh Helm install does not
need a manual `helm repo add` first. It also builds the Flux/Kustomize cluster
entrypoints under `clusters/`, `private/flux/`, and application paths
referenced by Flux.

It also fails if the generated Flux controller manifests regress to the default
`svc.cluster.local` service suffix instead of the K3s cluster domain
`svc.home-server.bronneberg.local`.

To check only the Flux and Kustomize cluster overlays, run:

```bash
make flux-build
```

Before changing repository visibility to public, run:

```bash
make public-check
```

The CI workflow in [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
checks GitHub Actions syntax, YAML files, Helm dependencies, Helm linting, and
Helm rendering. It also scans the current working tree with Gitleaks. Public
redaction checks stay in `make public-check` because they are intended for
repository publication readiness.

Dependency maintenance is split between GitHub-native Dependabot and Renovate:

* Dependabot is configured in
  [`.github/dependabot.yml`](.github/dependabot.yml) for GitHub Actions and
  Helm chart dependencies.
* Renovate is configured in [`renovate.json`](renovate.json) for Flux
  `HelmRelease` versions, Flux controller manifests, Helm values image tags,
  Dockerfile base images, repo-local tool version pins, and Kairos/Hadron
  install media tags.

Enable the Renovate GitHub App for this repository so it can open dependency
PRs. Minor and patch updates for repository maintenance tooling can automerge
after CI passes. Cluster-facing Flux, Helm values, and deployed workload updates
remain PR-reviewed before Flux reconciles them from `main`. Review Flux
controller update PRs for preserved bootstrap settings, especially the cluster
domain.

Node updates are split into explicit maintenance loops: K3s upgrades through
Rancher's System Upgrade Controller, Ubuntu package updates through host
`unattended-upgrades`, and Kubernetes-aware reboots through kured. The runbook
is [docs/node-update-strategy.md](docs/node-update-strategy.md).

KubeVirt is managed as cluster infrastructure for Linux, Windows, and staging
K3s VMs. The version choice, Longhorn virtualization storage default, node
requirements, and staging guidance are documented in
[docs/kubevirt.md](docs/kubevirt.md). Kairos staging and home hardware
operations are documented in [docs/kairos-staging.md](docs/kairos-staging.md)
and [docs/kairos-hardware.md](docs/kairos-hardware.md).

Agent instructions live in [AGENTS.md](AGENTS.md) and
[`.github/instructions/repository.instructions.md`](.github/instructions/repository.instructions.md).
Publication steps live in [docs/publication-runbook.md](docs/publication-runbook.md).

### Devcontainer Tooling

The recommended local workflow is to use the devcontainer so repository tooling
does not install or upgrade anything on your host machine. Open this repository
with VS Code Dev Containers or run it from the Dev Containers CLI, then run:

```bash
make ci
make public-check
```

The devcontainer installs the same tools used by the Makefile. Version pins live
in [`.devcontainer/Dockerfile`](.devcontainer/Dockerfile) so Renovate can keep
them current:

* `helm`
* `kubectl`
* `flux`
* `cosign`
* `kustomize`
* `virtctl`
* `kubectl virt`
* `kubectl oidc-login`
* `yamllint`
* `actionlint`
* `gitleaks`
* `gh`
* `sops`
* `age`
* `git-filter-repo`
* `codex`

It also recommends the OpenAI VS Code extension (`openai.chatgpt`) so Codex can
run in the container-attached editor, and Runme (`stateful.runme`) so Markdown
runbooks such as [docs/publication-runbook.md](docs/publication-runbook.md) can
be opened as runnable notebooks. Authenticate inside the devcontainer with your
preferred Codex flow, or provide `OPENAI_API_KEY` through your local shell, VS
Code secrets, or another non-repository secret store. Do not commit Codex
tokens, API keys, or generated plaintext credentials.

To use `kubectl` from the devcontainer, configure Kubernetes access on the host
at `~/.kube/config`, then rebuild or reopen the container. The devcontainer
mounts host `~/.kube` read-only at `/home/vscode/.kube-host` and sets
`KUBECONFIG=/home/vscode/.kube-host/config`, so the host kubeconfig remains the
source of truth and credentials are not copied into the repository.

```bash
kubectl get nodes
```

Host-side installs are optional. If you do not use the devcontainer, install
equivalent versions on your workstation:

```bash
python3 -m pip install --user yamllint==1.38.0
go install github.com/fluxcd/flux2/v2/cmd/flux@v2.8.6
go install github.com/sigstore/cosign/v3/cmd/cosign@v3.0.2
go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
go install github.com/zricethezav/gitleaks/v8@v8.30.1
go install github.com/cli/cli/v2/cmd/gh@v2.92.0
go install github.com/int128/kubelogin@v1.36.1
go install sigs.k8s.io/kustomize/kustomize/v5@v5.8.1
npm install -g @openai/codex@0.130.0
```

Install `virtctl` from the KubeVirt release that matches the cluster KubeVirt
manifests when running VM console or start/stop commands outside the
devcontainer.

For SOPS/age private overlays, the local private age identity is stored in
`.sops/age/keys.txt`, is ignored by git, and must be backed up outside this
repository.

Use the Makefile SOPS targets for common private overlay tasks:

```bash
make sops-keygen
make sops-decrypt
make sops-list
make sops-edit
make sops-encrypt
make sops-decrypt-file
make sops-decrypt-dir
make sops-updatekeys
make sops-recovery-drill
```

`make sops-keygen` creates `.sops/age/keys.txt` only if it does not already
exist. `make sops-decrypt` prints `private/home.sops.yaml` to stdout.
`make sops-edit` opens the encrypted file through SOPS and writes it back
encrypted. `make sops-encrypt` encrypts `private/home.sops.yaml` in place.
`make sops-decrypt-file` writes `private/home.decrypted.yaml`, which is ignored
by git. Override `SOPS_FILE` for a different encrypted file.
`make sops-list` lists all encrypted private files, and `make sops-decrypt-dir`
writes all decrypted private files under the ignored `private-decrypted/`
directory. Override `SOPS_OUT_DIR` to use a different output directory.
`make sops-recovery-drill` validates that a restored age identity can recreate
the Flux `sops-age` Secret shape, decrypt private overlays, and render the
private Flux Kustomize overlay without writing plaintext into the repository.
The drill procedure is documented in
[docs/sops-age-recovery-drill.md](docs/sops-age-recovery-drill.md).

`HomeAssistentConfig.yaml` and `HomeAssistantConfig.yaml` are local-only exports
and must remain ignored.

### First follow-up candidates

The new Helm checks pass, but they report a couple of modernization candidates:

* decide whether to remove the legacy self-hosted runner manifests entirely
* replace the TLS proxy chart's legacy `Endpoints` resource with
  `EndpointSlice`
* enable NetworkPolicy enforcement workload by workload after audit findings
  are clean

## Server Pre-requisites

* Ubuntu server

## Installing K3s

Instructions from [k3s.io](https://k3s.io/)

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 600
```

After installation, get the `Kubeconfig` from
```bash
 cat /etc/rancher/k3s/k3s.yaml
```

Note that this installation automatically routes all port `80` and `443` traffic to the K3s node, therefore locally installed apache etc will no longer function

## Installing Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

## Install infrastructure services in cluster

### Flux GitOps

Flux is the intended pull-based reconciler for infrastructure under
[`clusters/home`](clusters/home). The home Flux `GitRepository` uses Flux
GitHub App authentication (`spec.provider: github`) with credentials stored in
the SOPS-encrypted `flux-system/github-app-auth` Secret. GitHub-hosted Actions
must not receive kubeconfig or cluster credentials.

Flux also decrypts SOPS-encrypted Kubernetes Secret manifests from
[`private/flux/home`](private/flux/home). Store the local age identity and the
GitHub App Secret in the cluster before or immediately after installing the Flux
controllers. The GitHub App Secret is required before `GitRepository/flux-system`
can clone this private repository; without it, source-controller cannot recover
from a fresh bootstrap or auth migration.

```bash
kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic sops-age \
  -n flux-system \
  --from-file=age.agekey=.sops/age/keys.txt \
  --dry-run=client \
  -o yaml | kubectl apply -f -
SOPS_AGE_KEY_FILE=.sops/age/keys.txt \
  sops -d private/flux/home/github-app-auth.sops.yaml | kubectl apply -f -
```

The `github-app-auth` Secret contains the GitHub App ID, exactly one installation
selector (`githubAppInstallationOwner` in this repo), the private key, and
`FLUX_WEBHOOK_HOST` for the webhook Ingress hostname. Keep the Receiver HMAC in
`github-webhook-token`; Flux GitHub notification providers treat a `token` key as
PAT auth, so the GitHub App auth Secret must stay free of webhook tokens. The app needs
read-only repository contents, pull request read/write, commit status read/write,
and the default metadata permission for
`pbronneberg/home-server`. Pull request write is used only for Flux PR status
comments; commit status write is used for the `kairos/pr-staging` status check.

Flux exposes a GitHub webhook bridge at `/github/pr-events`. Configure the
GitHub App webhook URL as `https://<FLUX_WEBHOOK_HOST>/github/pr-events`, using
the `token` value from the `github-webhook-token` Secret. Subscribe the app
webhook to push and pull request events; `ping` is only needed to validate
delivery. The bridge forwards `push` and `ping` payloads to
`Receiver/github-webhook` and annotates the Kairos `ResourceSetInputProvider`
when the `deploy/kairos-staging` label is added or removed.

After bootstrap, inspect reconciliation from your kubeconfig:

```bash
flux get sources git -n flux-system
flux get kustomizations -n flux-system
flux get helmreleases --all-namespaces
```

If the SOPS age key was added after bootstrap, ask Flux to retry the private
secret overlay:

```bash
flux reconcile kustomization infrastructure-private-secrets -n flux-system --with-source
```

The Flux desired state keeps ordering explicit with Flux `Kustomization`
dependencies in
[`clusters/home/infrastructure.yaml`](clusters/home/infrastructure.yaml):

* namespaces and Helm repositories
* SOPS-encrypted private Kubernetes Secrets
* cert-manager and cert-manager issuers
* Rancher System Upgrade Controller and K3s upgrade plans
* kured node reboot orchestration
* Longhorn and the Longhorn storage classes
* kube-prometheus-stack monitoring
* oauth2-proxy for opt-in GitHub-backed ingress authentication
* Traefik middlewares used by existing ingresses
* Home Assistant, Bronneberg, Photobooth, My English Playground, TLS proxy, and
  Longhorn admin workload releases

### Longhorn data disk preparation

The node topology and storage tiers are documented in
[`docs/node-topology.md`](docs/node-topology.md). The autoscaling operating
model is documented in [`docs/homelab-autoscaling.md`](docs/homelab-autoscaling.md).
Longhorn permanent storage uses `deepthought`; node-local storage uses
`/data/longhorn` on the selected worker. Prepare that directory on the node
before adding or tagging the disk in Longhorn:

```bash
findmnt /data
df -hT /data
mountpoint /data
sudo mkdir -p /data/longhorn
sudo chown root:root /data/longhorn
sudo chmod 700 /data/longhorn
sudo touch /data/longhorn/.longhorn-write-test
sudo rm /data/longhorn/.longhorn-write-test
findmnt -T /data/longhorn
```

In Longhorn, tag storage deliberately:

- `deepthought`: node tag `deepthought`, disk tag `permanent-ssd`
- `milliard`: node tag `milliard`, disk tag `local-ssd`
- `marvin`: node tag `marvin`, disk tag `local-ssd`

Keep the existing OS-disk Longhorn path in place and tag it `longhorn-osdisk`
so existing volumes remain available and an explicit OS-disk StorageClass is
available when needed.
Do not delete PVCs, PVs, Longhorn volumes, or Longhorn disks as part of this
change.

`longhorn` remains the current durable/default StorageClass. `longhorn-permanent`
is reserved for a future explicit migration to deepthought-only durable storage,
and `longhorn-local` is the generic local SSD tier for workloads that should
keep their only replica on the node selected by scheduling. Existing PVCs do not
migrate automatically when StorageClasses are added. Migrate Home Assistant,
Grafana, Prometheus, or Alertmanager data with an application backup/restore or
Longhorn backup/restore during a maintenance window. Existing PVs/PVCs are not
deleted by changing or removing StorageClass objects, but new PVC provisioning
should wait until Flux has reconciled the intended StorageClasses.

### GitHub-backed ingress authentication

The `infrastructure-oauth2-proxy` release provides a shared auth endpoint for
ingresses that opt in to the `auth-github-oauth@kubernetescrd` Traefik
middleware. It uses oauth2-proxy's GitHub provider rather than GitHub as a
general-purpose OpenID Connect identity provider.

Before protecting any ingress, create a GitHub OAuth app with an authorization
callback URL that matches the private auth host:

```text
https://auth.home.example/oauth2/callback
```

Then edit the encrypted private values:

```bash
make sops-edit SOPS_FILE=private/flux/home/oauth2-proxy-values.sops.yaml
```

Replace the placeholder client ID, client secret, generated cookie secret,
GitHub organization, team, or user allowlist, auth callback host, and
cookie domain. Keep `github_org` or `github_users` in the oauth2-proxy
config; use `github_team` only to narrow a configured organization. With
`email_domains = [ "*" ]` and no GitHub allowlist, any GitHub account could
authenticate. Generate
the cookie secret with:

```bash
openssl rand -base64 32 | tr -- '+/' '-_'
```

Set `replicaCount: 1` only after those values are real. To protect an ingress,
include the OAuth middleware after the HTTPS redirect middleware:

```yaml
traefik.ingress.kubernetes.io/router.middlewares: default-redirect-https@kubernetescrd,auth-github-oauth@kubernetescrd
```

The middleware forward-auth URL is an in-cluster Kubernetes service address
called by Traefik, not a browser-facing redirect target. When authentication
fails, Traefik's error middleware serves oauth2-proxy's `/oauth2/sign_in` page.
Keep the error middleware on `/oauth2/sign_in`: Traefik preserves the original
401 status for error responses, so using `/oauth2/start` surfaces oauth2-proxy's
small `Found` body instead of a browser-followed redirect.

Protected hosts must be covered by the oauth2-proxy `cookie_domains` and
`whitelist_domains` values. Apps can log out through the auth host:

```text
https://auth.home.example/oauth2/sign_out?rd=https%3A%2F%2Fstatus.home.example%2F
```

Apps that expose the same-host oauth2-proxy path can use the same path on their
protected host instead.

That clears the oauth2-proxy session cookie for the configured cookie domain and
returns the browser to an unprotected page. The `rd` target must be URL-encoded
and allowed by `whitelist_domains`; use the real public status or landing host
from the private overlay. Do not redirect back to `/oauth2/sign_in` while
`skip_provider_button = true`, because that can immediately start the GitHub
OAuth flow again.

This does not sign the browser out of GitHub itself. Apps with their own logout
redirect, such as Grafana, should point that redirect at the same sign-out URL
with an unprotected `rd` target.

The security hardening runbook is
[docs/security-hardening.md](docs/security-hardening.md). It records the
audit-first rollout order, sensitive-ingress tiering, storage checks, and drift
cleanup queue.

Flux migration parity and rollback notes live in
[docs/flux-migration-parity.md](docs/flux-migration-parity.md).

## GitHub Actions

Repository maintenance CI runs on GitHub-hosted public runners via
`.github/workflows/ci.yml`.

The Action Runner Controller configuration in `application/runners/runners.yaml`
is legacy self-hosted runner configuration. Keep it only if the cluster should
still host runners for other repositories.

The [K3s system upgrader](https://docs.k3s.io/upgrades/automated/) is deployed
by Flux from `clusters/home/infrastructure/system-upgrade-controller`, and K3s
upgrade plans are reconciled from
`clusters/home/infrastructure/system-upgrade-plans`. The server plan runs before
the agent plan during the configured maintenance windows.

```bash
kubectl -n system-upgrade get plans -o wide
kubectl -n system-upgrade get jobs
```
