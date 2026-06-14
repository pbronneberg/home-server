# Kairos Home Hardware

Kairos hardware definitions are first-class home configuration. The public
bootstrap templates live under `clusters/home/bootstrap/kairos`, and the small
encrypted hardware substitution Secret lives in the normal home private overlay,
`private/flux/home`.

This hardware path is still an adoption gate for replacing existing Ubuntu
nodes. It is not a separate Flux root and it does not require maintaining a
separate Kairos hardware tree.

## Boundaries

- Flux root: `clusters/home`.
- Bootstrap structure and VM overlays: `clusters/home/bootstrap/kairos`.
- Public hardware substitutions: `clusters/home/infrastructure.yaml`.
- Encrypted hardware values: `private/flux/home/kairos-bootstrap-values.sops.yaml`.
- Home-owned namespace for rendered user-data Secrets: `kairos-system`.

Do not reuse staging K3s tokens. Do not commit admin kubeconfigs, SSH private
keys, passwords, or token material. Keep the full cloud-config reviewable in the
public templates; encrypt only the values that are secret or externally
identifying.

## Install Media Verification

Renovate manages the `KAIROS_HADRON_TAG` values in the Kairos runbooks and the
KubeVirt staging installer URLs. The Renovate rule intentionally permits only
standard `amd64` K3s `v1.35.x` media; widen that rule deliberately when the
hardware track is ready for a Kubernetes minor upgrade.

Verify the Kairos artifact before writing USB media or booting hardware:

```bash
# renovate: datasource=docker depName=quay.io/kairos/hadron versioning=docker
KAIROS_HADRON_TAG=v0.0.4-standard-amd64-generic-v4.0.3-k3sv1.35.2-k3s1
KAIROS_VERSION="v${KAIROS_HADRON_TAG#*-generic-v}"
KAIROS_VERSION="${KAIROS_VERSION%%-k3s*}"
ISO="kairos-hadron-${KAIROS_HADRON_TAG/-k3s1/+k3s1}.iso"
BASE=https://github.com/kairos-io/kairos/releases/download/${KAIROS_VERSION}

curl -fLO "${BASE}/${ISO}"
curl -fLO "${BASE}/${ISO}.sha256"
curl -fLO "${BASE}/${ISO}.sha256.bundle"

cosign verify-blob \
  --bundle "${ISO}.sha256.bundle" \
  --certificate-identity-regexp '^https://github\.com/kairos-io/kairos-factory-action/\.github/workflows/reusable-factory\.yaml@.*$' \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "${ISO}.sha256"

sha256sum -c "${ISO}.sha256"
```

If either verification fails, stop. Do not install the hardware nodes.

## Configure User-Data Values

Edit the encrypted home bootstrap values directly:

```bash
make sops-edit SOPS_FILE=private/flux/home/kairos-bootstrap-values.sops.yaml
flux reconcile kustomization infrastructure-private-secrets -n flux-system --with-source
flux reconcile kustomization bootstrap-kairos -n flux-system --with-source
```

The encrypted file contains the K3s token, external Dex issuer URL, and GitHub
username used for SSH key import. Public hardware values such as install disk
ID, node names, internal API endpoint, CIDRs, OIDC claims, OIDC prefixes, and
Dex `sub` subject live in `clusters/home/infrastructure.yaml`. Prefer stable
disk IDs such as `/dev/disk/by-id/...`; do not use a mutable `/dev/sdX` path in
real hardware values.

## First Boot

Install the server first. After Kairos powers off, boot the installed disk and
verify SSH plus K3s:

```bash
ssh kairos@<server-address> 'hostname && systemctl is-active k3s.service'
ssh kairos@<server-address> 'sudo k3s kubectl get nodes -o wide'
```

Install the agent only after the server API is healthy and reachable at the
endpoint used in `K3S_URL`.

```bash
ssh kairos@<agent-address> 'hostname && systemctl is-active k3s-agent.service'
ssh kairos@<server-address> 'sudo k3s kubectl get nodes -o wide'
```

## Flux Bootstrap

Copy the admin kubeconfig into an ignored local path and update its server URL
to the hardware API endpoint. Bootstrap Flux to the home root only when the
hardware nodes are intentionally taking the home desired state:

```bash
flux bootstrap github \
  --owner=pbronneberg \
  --repository=home-server \
  --branch=main \
  --path=clusters/home \
  --personal \
  --kubeconfig=.local/home-kairos/kubeconfig
```

Create the `sops-age` Secret in `flux-system` before expecting
`private/flux/home` to reconcile.

## Acceptance

```bash
kubectl --kubeconfig .local/home-kairos/kubeconfig get nodes -o wide
kubectl --kubeconfig .local/home-kairos/kubeconfig -n flux-system get kustomizations
kubectl --kubeconfig .local/home-kairos/kubeconfig -n kairos-system get secret kairos-server-user-data kairos-agent-user-data
```

Confirm K3s hardening and that bundled `traefik`/`servicelb` remain enabled:

```bash
ssh kairos@<server-address> "sudo systemctl cat k3s.service | grep -E 'cluster-domain=home-server.bronneberg.local|secrets-encryption|anonymous-auth=false|profiling=false|read-only-port=0'"
ssh kairos@<server-address> "sudo systemctl cat k3s.service | grep -- '--disable=traefik,servicelb' && echo 'unexpected disable flag' || echo 'bundled traefik/servicelb kept enabled'"
```

## Rollback Or Reinstall

The Kairos hardware remains disposable until promoted by a later decision
record. If an install or join fails, fix the SOPS input and reinstall the
affected node from the verified media. Do not migrate production storage or
control-plane membership until the home replacement checks are explicitly run.
