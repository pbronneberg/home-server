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
curl -L https://github.com/Praqma/helmsman/releases/download/v3.4.2/helmsman_3.4.2_linux_amd64.tar.gz | tar zx
```

## Installing Longhorn distributed filesystem

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
```

Create storageclass for longhorn
```bash
kubectl apply -f ./infra/longhorn/storageclass-longhorn.yaml
```
