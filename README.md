# home-server

Configuration for my home server.

## Maintenance Workflow

This repository is maintained through small pull requests, GitHub-hosted
Actions, and repo-local agent instructions.

Run the same checks locally that CI runs on GitHub public runners:

```bash
make ci
```

Before changing repository visibility to public, run:

```bash
make public-check
```

The CI workflow in [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
checks GitHub Actions syntax, YAML files, Helm dependencies, Helm linting, and
Helm rendering. It also scans the current working tree with Gitleaks and checks
for public-unsafe topology. Dependabot is configured in
[`.github/dependabot.yml`](.github/dependabot.yml) for GitHub Actions and Helm
chart dependencies.

Agent instructions live in [AGENTS.md](AGENTS.md) and
[`.github/instructions/repository.instructions.md`](.github/instructions/repository.instructions.md).
Publication steps live in [docs/publication-runbook.md](docs/publication-runbook.md).

### Local maintenance tooling

GitHub Actions installs the lint tooling automatically. To run `make ci`
locally, install these tools on your workstation:

```bash
python3 -m pip install --user yamllint==1.38.0
go install github.com/rhysd/actionlint/cmd/actionlint@v1.7.12
go install github.com/zricethezav/gitleaks/v8@v8.30.1
```

For SOPS/age private overlays, install `sops` and `age`. The local private age
identity is stored in `.sops/age/keys.txt`, is ignored by git, and must be
backed up outside this repository.

`HomeAssistentConfig.yaml` and `HomeAssistantConfig.yaml` are local-only exports
and must remain ignored.

### First follow-up candidates

The new Helm checks pass, but they report a couple of modernization candidates:

* migrate the Pi-hole ingress from `networking.k8s.io/v1beta1` to
  `networking.k8s.io/v1`
* replace the TLS proxy chart's legacy `Endpoints` resource with
  `EndpointSlice`
* decide whether to remove the legacy self-hosted runner manifests entirely

## Server Pre-requisites

* Ubuntu server

## Installing K3s

Instructions from [k3s.io](https://k3s.io/)

```bash
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
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

## Installing Helm-Diff

```bash
helm plugin install https://github.com/databus23/helm-diff
```

## Installing Helmsman

```bash
mkdir tmp
curl -L https://github.com/Praqma/helmsman/releases/download/v3.7.7/helmsman_3.7.7_linux_amd64.tar.gz | tar zx --directory tmp
sudo mv ./tmp/helmsman /usr/local/bin/helmsman
rm -rf ./tmp
```

## Install infrastructure services in cluster

```bash
helmsman -apply -f ./infra/home-server.helmsman.toml
```

Create Traefik proxy middlewares

```bash
kubectl apply -f infra/traefik-https.yaml
kubectl apply -f infra/traefik-basicauth.yaml
```

## GitHub Actions

Repository maintenance CI runs on GitHub-hosted public runners via
`.github/workflows/ci.yml`.

The Action Runner Controller configuration in `infra/home-server.helmsman.toml`
and `application/runners/runners.yaml` is legacy self-hosted runner
configuration. Keep it only if the cluster should still host runners for other
repositories.

If the legacy [Action Runner Controller](https://github.com/actions-runner-controller/actions-runner-controller)
is used, a GitHub PAT is required. First
[create](https://github.com/settings/tokens) this PAT, then create a secret
containing this token.

```
kubectl create namespace  actions-runner-system
kubectl create secret generic controller-manager -n actions-runner-system --from-literal=github_token=<TOKEN>
```

Install the [K3S system upgrader](https://rancher.com/docs/k3s/latest/en/upgrades/automated/) to automatically upgrade all nodes in the cluster to the newest K3S versions.

```
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/system-upgrade-controller.yaml
kubectl apply -f infra/system-upgrader/upgrade-plans.yml
```

### argo

```
kubectl create ns argo
kubectl apply -n argo -f https://raw.githubusercontent.com/argoproj/argo-workflows/stable/manifests/install.yaml
```

```
kubectl apply -n argo -f ./infra/argo/k8sapi-executor.yml
```

## Installing Workloads

### TLS Proxies
```
helm dep up ./application/tls-proxies
helm install tls-proxies ./application/tls-proxies --namespace websites
```

### Longhorn admin
```
helm install longhorn-admin ./application/longhorn-admin --namespace longhorn-system
```

### GitHub Action runners
```
kubectl create namespace self-hosted-runners
kubectl apply -f application/runners/runners.yaml --namespace self-hosted-runners
```

To ensure scheduling is not done on remote/spoke nodes add taints to the given nodes
```
kubectl taint nodes <NODE> spoke=true:NoSchedule
```
