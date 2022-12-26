# home-server

Configuration for my home server

## Pre-requisites

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

For the [Action Runner Controller](https://github.com/actions-runner-controller/actions-runner-controller), a Github PAT is required.
First [Create](https://github.com/settings/tokens) this PAT, then create a secret containing this token.

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

### Github Action runners
```
kubectl create namespace self-hosted-runners
kubectl apply -f application/runners/runners.yaml --namespace self-hosted-runners
```

To ensure scheduling is not done on remote/spoke nodes add taints to the given nodes
```
kubectl taint nodes <NODE> spoke=true:NoSchedule
```