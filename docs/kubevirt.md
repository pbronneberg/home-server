# Kairos Evaluation With KubeVirt

This runbook evaluates Kairos as an immutable K3s node OS without placing the
main home cluster on the critical path. It uses the existing KubeVirt and CDI
installation to run disposable VMs in the `vms` namespace.

The durable staging workflow is documented in [kairos-staging.md](kairos-staging.md).

The Flux Kustomization `staging-kairos-kubevirt` is committed suspended by
default and does not wait for VM readiness, because the staging VMs are
intentionally created halted. Resuming it is a live-cluster action that imports
VM media and creates Longhorn volumes; starting disposable VMs remains an
explicit `virtctl start` step after the cloud-init Secrets exist.

## Staging VM Scope

- Target namespace: `vms`
- Resource label: `home-server.dev/evaluation=kairos`
- VMs: `kairos-server` and `kairos-agent`
- Nested K3s API Service: `kairos-k3s-api.vms.svc.home-server.bronneberg.local:6443`
- StorageClass: `longhorn-virtualization-test`
- Kairos artifact:
  `v0.2.0-standard-amd64-generic-v4.1.0-k3sv1.35.4-k3s1`

This staging VM path uses the standard Kairos ISO path and does not enable Kairos Trusted
Boot by default. Trusted Boot requires signed UKI media plus Secure Boot and TPM
support in the VM firmware. Keep that as an explicit opt-in track and use
the [trusted boot VM options example][trusted-boot-vm-options-example] only when
you are testing Trusted Boot media.

The selected artifact keeps staging on the K3s `v1.35` minor used by the
home-cluster lifecycle at the time this evaluation path was added. Verify the
artifact before use:

```bash
# renovate: datasource=docker depName=quay.io/kairos/hadron versioning=docker
KAIROS_HADRON_TAG=v0.2.0-standard-amd64-generic-v4.1.0-k3sv1.35.4-k3s1
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

If either verification fails, do not resume the staging VM Kustomization.

## Public And Private Boundaries

Committed Kairos templates are reviewable and use Flux substitutions for live
values. Do not commit generated user-data, K3s tokens, kubeconfigs, SSH private
keys, real hostnames, LAN IPs, or console logs that include private values.

The home private overlay supplies only encrypted VM bootstrap values for the
staging K3s token, external Dex issuer URL, and GitHub username:

- `private/flux/home/kairos-staging-values.sops.yaml`
- `private/flux/home/dex-substitutions.sops.yaml`

Public staging values such as app name, namespace, `/dev/vda`, node names,
internal API URL, CIDRs, OIDC claims, OIDC prefixes, and Dex subject live in
`clusters/home/infrastructure.yaml`. The separate `private/flux/staging` overlay
is reserved for runtime Secrets applied inside the nested PR staging cluster.

Edit the staging values before a clean evaluation run:

```bash
make sops-edit SOPS_FILE=private/flux/home/kairos-staging-values.sops.yaml
flux reconcile kustomization infrastructure-private-secrets -n flux-system --with-source
```

`KAIROS_K3S_TOKEN` is the hard secret. `${GITHUB_USERNAME}` selects the GitHub
account whose public SSH keys Kairos should fetch at provisioning time, and it
stays encrypted as an external account identifier. `${GITHUB_DEX_SUBJECT}` is
the stable Dex `sub` claim granted admin access inside the disposable nested
cluster; it is public in the Flux substitution block. Disk choices, node names,
internal API endpoints, CIDRs, OIDC claims, and OIDC prefixes are operational
configuration, not secrets.

The user-data keeps the standard `users.ssh_authorized_keys` form, an explicit
Kairos `network` stage `authorized_keys` entry, and a retrying systemd oneshot
that fetches `https://github.com/${GITHUB_USERNAME}.keys` after
`network-online.target`. Clean installs need outbound HTTPS access to GitHub for
SSH bootstrap; installed nodes keep their previously fetched authorized keys if
that path is unavailable later.

The nested K3s server pins non-overlapping public staging ranges
`--cluster-cidr=198.18.0.0/16`, `--service-cidr=198.19.0.0/16`, and
`--cluster-dns=198.19.0.10` in the public Flux substitution block.

The nested staging cluster intentionally keeps K3s' bundled `traefik` and `servicelb`
components enabled. This evaluation doubles as the recipe for future node
upgrades, so those defaults should stay visible unless a later production plan
explicitly disables them.

The nested K3s server also enables OIDC authentication against the shared Dex
service in `clusters/home/infrastructure/dex`. GitHub OAuth is not itself
an OIDC issuer for Kubernetes, so Dex re-exposes the existing GitHub OAuth app
as OIDC under a callback subpath of the existing auth host. The public example
issuer is `https://auth.home.example/oauth2/callback/dex`; the private
Flux substitution Secret supplies the live auth host and issuer.

The Dex bridge reads `client-id` and `client-secret` from the existing
`auth/oauth2-proxy-private-values` Secret instead of copying GitHub OAuth
credentials. Its GitHub redirect URI is the issuer plus `/callback`, for example
`https://auth.home.example/oauth2/callback/dex/callback`. GitHub OAuth
allows redirect URIs below the configured callback path, which lets staging
reuse the OAuth app already used by the Traefik middleware when that app's
registered callback is `https://auth.home.example/oauth2/callback`.

Kairos grants staging admin access to the OIDC username
`github:${GITHUB_DEX_SUBJECT}` through a bootstrap `ClusterRoleBinding`.
For this GitHub-backed Dex client, Kubernetes uses the signed Dex `sub` claim
instead of `preferred_username`, because only `sub` is guaranteed to be present
in the ID token. Keep this binding limited to the disposable nested cluster;
production clusters should use a narrower role and group-based authorization.

## Preflight

Run these checks from the devcontainer or another trusted workstation with the
local kubeconfig:

```bash
kubectl -n kubevirt get kubevirt kubevirt
kubectl -n cdi get cdi cdi
kubectl get node -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.devices\.kubevirt\.io/kvm}{"\t"}{.status.allocatable.cpu}{"\t"}{.status.allocatable.memory}{"\n"}{end}'
kubectl -n vms get vm,vmi,dv,pvc
kubectl -n auth get secret oauth2-proxy-private-values
kubectl -n flux-system get secret dex-substitutions
virtctl version --client
kubectl oidc-login version
kustomize build clusters/home/bootstrap/kairos/overlays/kubevirt-staging
```

Expected result: KubeVirt and CDI are deployed, at least one node advertises
KVM, no existing `kairos-*` evaluation resources are present, `virtctl` and
`kubectl oidc-login` are available, and the private OAuth/substitution Secrets
exist.

## First Boot And Install

Reconcile the private SOPS overlay so the VM cloud-init Secrets exist, then
reconcile shared Dex before starting either VM:

```bash
flux reconcile kustomization infrastructure-private-secrets -n flux-system --with-source
kubectl -n vms get secret kairos-server-user-data kairos-agent-user-data
kubectl -n flux-system get secret dex-substitutions
flux reconcile kustomization infrastructure-dex -n flux-system --with-source
```

For a persistent GitOps staging VM deployment, change `staging-kairos-kubevirt` to
`suspend: false` in `clusters/home/infrastructure.yaml`, commit and push that
change, then reconcile the root and staging VM Kustomizations:

```bash
flux reconcile kustomization flux-system -n flux-system --with-source
flux reconcile kustomization staging-kairos-kubevirt -n flux-system
```

For a temporary live staging deployment without committing `suspend: false`, patch the child
Kustomization after the root `flux-system` Kustomization has reconciled. The
root Kustomization manages this child object and can restore the committed
`suspend: true` value on its next run:

```bash
kubectl -n flux-system patch kustomization staging-kairos-kubevirt --type=merge -p '{"spec":{"suspend":false,"wait":false}}'
flux reconcile kustomization staging-kairos-kubevirt -n flux-system
```

If a VM was started first, the launcher pod will stay pending with
`MountVolume.SetUp failed ... secret "kairos-*-user-data" not found`. Create the
missing Secret, then stop and start the affected VM so KubeVirt creates a fresh
launcher pod with the cloud-init disk mounted.

Watch imports and VM state:

```bash
kubectl -n vms get dv,pvc,vm,vmi -l home-server.dev/evaluation=kairos -w
```

Install and start the server VM after the DataVolumes are ready:

```bash
make kairos-install-server
```

The install helper temporarily boots the installer media first, waits for
Kairos to power off after installing to the persistent root disk, switches the
VM back to root-disk-first boot, and starts the installed node.

The committed manifests keep the persistent root disk as the steady-state boot
device. A clean blank disk may not reliably fall through to the installer on
all KubeVirt firmware paths, so use the install helper for disposable clean
boots instead of starting a fresh VM directly.

Install and start the agent only after the server API is reachable:

```bash
make kairos-install-agent
```

After the server API is reachable, confirm OIDC discovery through the public
auth host. Use the live issuer URL from the private substitution Secret; the
example below is public-safe:

```bash
curl -fsS https://auth.home.example/oauth2/callback/dex/.well-known/openid-configuration
```

For a disposable local connection, forward the Kairos API with `virtctl` and use
an OIDC kubeconfig that does not contain nested admin client certificates. The
staging uses `--insecure-skip-tls-verify` only because the forwarded K3s API uses
the nested cluster's private serving CA; replace this with a trusted API endpoint
before carrying the pattern beyond evaluation.

```bash
virtctl -n vms port-forward vm/kairos-server 16443:6443

kubectl config --kubeconfig .local/kairos/oidc-kubeconfig set-cluster kairos-staging \
  --server=https://127.0.0.1:16443 \
  --insecure-skip-tls-verify=true
kubectl config --kubeconfig .local/kairos/oidc-kubeconfig set-credentials github \
  --exec-api-version=client.authentication.k8s.io/v1 \
  --exec-interactive-mode=Always \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg=--grant-type=device-code \
  --exec-arg=--oidc-issuer-url=https://auth.home.example/oauth2/callback/dex \
  --exec-arg=--oidc-client-id=kairos-kubernetes \
  --exec-arg=--oidc-extra-scope=groups \
  --exec-arg=--token-cache-storage=disk \
  --exec-arg=--token-cache-dir=.local/kairos/oidc-cache
kubectl config --kubeconfig .local/kairos/oidc-kubeconfig set-context kairos-staging \
  --cluster=kairos-staging \
  --user=github

# If Dex was restarted while using memory storage, clear stale cached tokens first.
kubectl oidc-login clean --token-cache-dir .local/kairos/oidc-cache || true
kubectl --kubeconfig .local/kairos/oidc-kubeconfig --context kairos-staging get nodes -o wide
```

## Reinstall And Rejoin

Record current state before destructive testing:

```bash
kubectl -n vms get vm,dv,pvc -l home-server.dev/evaluation=kairos -o wide
sudo k3s kubectl get nodes -o wide
```

For agent rejoin testing, stop the agent, delete only its root DataVolume/PVC,
let Flux recreate it, then start the agent again. The committed root disk
DataVolumes use filesystem PVCs so CDI does not need block-device access while
creating the blank disk image:

```bash
virtctl -n vms stop kairos-agent
kubectl -n vms delete dv kairos-agent-root
flux reconcile kustomization staging-kairos-kubevirt -n flux-system
virtctl -n vms start kairos-agent
```

The agent should reinstall and rejoin the nested server using the same local
token.

## Upgrade And Rollback

Snapshot before upgrade when the KubeVirt snapshot API is available:

```bash
kubectl -n vms apply -f - <<'EOF'
apiVersion: snapshot.kubevirt.io/v1beta1
kind: VirtualMachineSnapshot
metadata:
  labels:
    home-server.dev/evaluation: kairos
  name: kairos-server-before-upgrade
spec:
  source:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: kairos-server
EOF
```

Run the Kairos upgrade flow from inside the guest. For staging, upgrade the
active system first and only upgrade recovery after the new active system is
healthy:

```bash
# renovate: datasource=docker depName=quay.io/kairos/hadron versioning=docker
KAIROS_HADRON_TAG=v0.2.0-standard-amd64-generic-v4.1.0-k3sv1.35.4-k3s1
sudo kairos-agent upgrade --source "oci:quay.io/kairos/hadron:${KAIROS_HADRON_TAG}"
sudo reboot
```

Confirm the VM boots, K3s is healthy, and the previous boot entry or KubeVirt
snapshot can recover staging if the guest does not become healthy.

## Management Path Unavailable

Apply the example deny-egress policy only for the failure test:

```bash
kubectl apply -f clusters/home/bootstrap/kairos/overlays/kubevirt-staging/examples/management-path-deny-egress.example.yaml
```

Reboot one VM from the console. The installed node should still boot locally,
but remote image pulls, upgrade checks, and rejoin paths that require cluster
or internet access should fail predictably. If the cluster CNI does not enforce
NetworkPolicy, record that and repeat this test by blocking egress at the host,
router, or test namespace firewall layer.

Remove the policy after the test:

```bash
kubectl -n vms delete networkpolicy kairos-evaluation-deny-egress
```

## Cleanup

Suspend reconciliation first:

```bash
flux suspend kustomization staging-kairos-kubevirt -n flux-system
```

Stop and remove only the labeled evaluation resources:

```bash
virtctl -n vms stop kairos-server
virtctl -n vms stop kairos-agent
kubectl -n vms delete vm,dv,pvc,svc,virtualmachinesnapshot -l home-server.dev/evaluation=kairos
kubectl -n vms delete secret kairos-server-user-data kairos-agent-user-data
```

The evaluation uses `longhorn-virtualization-test`, which has one replica and
`reclaimPolicy: Delete`; deleting the evaluation PVCs should release the
Longhorn volumes. Still verify that no old retained PVs, `prime-*` PVCs, or
Longhorn volumes remain from earlier runs that used `longhorn-virtualization-test`.

## Pilot Log

Current status as of 2026-05-23:

- Pinned Kairos ISO URL returned HTTP 302 to a release asset.
- Checksum file returned
  `0bbc4bf00b4b149d15dd3cc9a281cc58590c03c5bb9dd253372cb0a46ae1d27f`.
- Temporary `virtctl v1.8.2` client worked from the devcontainer session.
- KubeVirt phase: `Deployed`.
- CDI phase: `Deployed`.
- `vms` namespace had no `vm`, `vmi`, `dv`, or `pvc` resources.
- At least one node reported allocatable KVM; node name and capacity are
  intentionally omitted from committed notes.
- No production node was migrated and no evaluation VM was created during this
  read-only preflight.

Sanitized observations still to capture during the live staging run:

- Install media checksum result.
- First boot and post-install boot result.
- Nested `kubectl get nodes` output with private addresses redacted if needed.
- Agent wipe/rejoin result.
- Upgrade and rollback result.
- Management-path unavailable behavior.

Current status as of 2026-05-24:

- Clean root DataVolumes for `kairos-server` and `kairos-agent` imported
  successfully after removing retained Longhorn/CDI evaluation volumes from
  earlier failed attempts.
- The server initially became unreachable after K3s CNI startup when nested
  K3s used the default pod and Service ranges. Pinning the nested cluster to
  non-overlapping private-overlay pod and Service ranges kept the KubeVirt
  bridge path reachable after reboot.
- The live cloud-init Secret uses GitHub public SSH key import with
  `github:<operator>`, an explicit Kairos `network` stage, and a retrying
  `kairos-github-ssh-keys.service` oneshot; no SSH public key material is
  copied into the user-data template.
- OIDC has been added for the next clean server install through the shared Dex
  infrastructure service that reuses the existing GitHub OAuth app credentials
  from oauth2-proxy.
- The nested API answered `/ping` after the post-CNI settle period.
- `kairos-server` and `kairos-agent` both appeared in the nested API with
  `Ready=True`; private node addresses are intentionally omitted.

Still to capture after this baseline:

- Agent wipe/rejoin result.
- Upgrade and rollback result.
- Management-path unavailable behavior.

[trusted-boot-vm-options-example]: ../clusters/home/bootstrap/kairos/overlays/kubevirt-staging/examples/trusted-boot-vm-options.example.yaml
