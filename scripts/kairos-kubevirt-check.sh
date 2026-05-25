#!/usr/bin/env bash
set -euo pipefail

mode="${1:-all}"
namespace="${KAIROS_NAMESPACE:-vms}"
ssh_user="${KAIROS_SSH_USER:-kairos}"
known_hosts="${KAIROS_SSH_KNOWN_HOSTS:-.local/kairos/known_hosts}"
identity_file="${KAIROS_SSH_IDENTITY_FILE:-}"
staging_kubeconfig="${KAIROS_STAGING_KUBECONFIG:-.local/kairos/staging-kubeconfig}"
kubectl_bin="${KUBECTL:-kubectl}"
virtctl_bin="${VIRTCTL:-virtctl}"

if ! command -v "$virtctl_bin" >/dev/null 2>&1; then
  if [ -x /tmp/virtctl ]; then
    virtctl_bin=/tmp/virtctl
  fi
fi

log() {
  printf '[kairos-check] %s\n' "$*"
}

fail() {
  printf '[kairos-check] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

require_kubectl() {
  require_command "$kubectl_bin"
  "$kubectl_bin" version --client >/dev/null
}

require_virtctl() {
  if ! command -v "$virtctl_bin" >/dev/null 2>&1; then
    fail "missing virtctl; set VIRTCTL=/path/to/virtctl"
  fi
  "$virtctl_bin" version --client >/dev/null
}

jsonpath() {
  local resource="$1"
  local name="$2"
  local path="$3"
  "$kubectl_bin" -n "$namespace" get "$resource" "$name" -o "jsonpath=$path"
}

wait_jsonpath() {
  local resource="$1"
  local name="$2"
  local path="$3"
  local expected="$4"
  local timeout_seconds="$5"
  local interval_seconds="${6:-5}"
  local elapsed=0
  local value=""

  while [ "$elapsed" -le "$timeout_seconds" ]; do
    value="$(jsonpath "$resource" "$name" "$path" 2>/dev/null || true)"
    if [ "$value" = "$expected" ]; then
      log "$resource/$name reached $path=$expected"
      return 0
    fi
    sleep "$interval_seconds"
    elapsed=$((elapsed + interval_seconds))
  done

  fail "$resource/$name did not reach $path=$expected within ${timeout_seconds}s; last value: ${value:-<empty>}"
}

wait_datavolumes() {
  local dv
  for dv in kairos-server-installer kairos-server-root kairos-agent-installer kairos-agent-root; do
    "$kubectl_bin" -n "$namespace" get datavolume "$dv" >/dev/null || fail "missing DataVolume $namespace/$dv"
    wait_jsonpath datavolume "$dv" '{.status.phase}' Succeeded 900 10
  done
}

wait_vmi_running() {
  local vm="$1"
  local vm_status=""

  if ! "$kubectl_bin" -n "$namespace" get virtualmachineinstance "$vm" >/dev/null 2>&1; then
    vm_status="$($kubectl_bin -n "$namespace" get vm "$vm" -o jsonpath='{.status.printableStatus}' 2>/dev/null || true)"
    case "$vm_status" in
      Stopped|Stopped*)
        fail "VM $namespace/$vm is stopped; start it before running live SSH/K3s verification"
        ;;
    esac
  fi

  wait_jsonpath virtualmachineinstance "$vm" '{.status.phase}' Running 600 10
}

virt_ssh() {
  local vm="$1"
  local command="$2"
  local args=(
    ssh
    "--namespace=$namespace"
    "--username=$ssh_user"
    "--known-hosts=$known_hosts"
    '--local-ssh-opts=-o BatchMode=yes'
    '--local-ssh-opts=-o ConnectTimeout=10'
    '--local-ssh-opts=-o StrictHostKeyChecking=no'
    "--local-ssh-opts=-o UserKnownHostsFile=$known_hosts"
  )

  if [ -n "$identity_file" ]; then
    args+=("--identity-file=$identity_file")
  elif [ -z "${SSH_AUTH_SOCK:-}" ]; then
    fail "no SSH agent found; set SSH_AUTH_SOCK or KAIROS_SSH_IDENTITY_FILE before running live SSH checks"
  fi

  args+=("$ssh_user@vm/$vm" "--command=$command")
  "$virtctl_bin" "${args[@]}"
}

wait_virt_ssh() {
  local vm="$1"
  local command="$2"
  local timeout_seconds="${3:-600}"
  local interval_seconds="${4:-10}"
  local elapsed=0
  local output=""

  while [ "$elapsed" -le "$timeout_seconds" ]; do
    if output="$(virt_ssh "$vm" "$command" 2>&1)"; then
      return 0
    fi
    sleep "$interval_seconds"
    elapsed=$((elapsed + interval_seconds))
  done

  printf '%s
' "$output" >&2
  fail "SSH command on $namespace/$vm did not succeed within ${timeout_seconds}s"
}

check_kubevirt_ready() {
  local phase
  phase="$($kubectl_bin -n kubevirt get kubevirt kubevirt -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [ "$phase" = Deployed ] || fail "KubeVirt is not Deployed; phase=${phase:-<missing>}"
  log 'KubeVirt is Deployed'
}

check_cdi_ready() {
  local phase
  phase="$($kubectl_bin -n cdi get cdi cdi -o jsonpath='{.status.phase}' 2>/dev/null || true)"
  [ "$phase" = Deployed ] || fail "CDI is not Deployed; phase=${phase:-<missing>}"
  log 'CDI is Deployed'
}

check_kvm_allocatable() {
  local found=false
  local values=()
  local value
  while IFS= read -r value; do
    case "$value" in
      ''|'0'|'<none>') ;;
      *)
        found=true
        values+=("$value")
        ;;
    esac
  done < <("$kubectl_bin" get nodes -o jsonpath='{range .items[*]}{.status.allocatable.devices\.kubevirt\.io/kvm}{"\n"}{end}')

  [ "$found" = true ] || fail 'no allocatable KVM devices found on cluster nodes'
  log "KVM devices allocatable: ${values[*]}"
}

check_static_resources() {
  local name
  "$kubectl_bin" get namespace "$namespace" >/dev/null
  "$kubectl_bin" get storageclass longhorn-virtualization-test >/dev/null

  for name in kairos-server-user-data kairos-agent-user-data; do
    "$kubectl_bin" -n "$namespace" get secret "$name" >/dev/null || fail "missing Secret $namespace/$name"
  done

  for name in kairos-server kairos-agent; do
    "$kubectl_bin" -n "$namespace" get vm "$name" >/dev/null || fail "missing VM $namespace/$name"
  done

  log 'Kairos namespace, test StorageClass, user-data Secrets, and VMs exist'
}


patch_boot_order() {
  local vm="$1"
  local installer_order="$2"
  local root_order="$3"
  "$kubectl_bin" -n "$namespace" patch vm "$vm" --type=json -p "[{"op":"replace","path":"/spec/template/spec/domain/devices/disks/0/bootOrder","value":${installer_order}},{"op":"replace","path":"/spec/template/spec/domain/devices/disks/1/bootOrder","value":${root_order}}]" >/dev/null
}

wait_vm_stopped() {
  local vm="$1"
  wait_jsonpath virtualmachine "$vm" '{.status.printableStatus}' Stopped 1200 10
}

install_vm() {
  local vm="$1"
  require_kubectl
  require_virtctl
  wait_datavolumes

  log "booting $vm from installer media"
  if "$kubectl_bin" -n "$namespace" get virtualmachineinstance "$vm" >/dev/null 2>&1; then
    "$virtctl_bin" -n "$namespace" stop "$vm" >/dev/null || true
    wait_vm_stopped "$vm"
  fi

  patch_boot_order "$vm" 1 2
  "$virtctl_bin" -n "$namespace" start "$vm" >/dev/null
  wait_vm_stopped "$vm"

  log "switching $vm to installed root disk"
  patch_boot_order "$vm" 2 1
  "$virtctl_bin" -n "$namespace" start "$vm" >/dev/null || true
}

check_preflight() {
  require_kubectl
  require_virtctl
  check_kubevirt_ready
  check_cdi_ready
  check_kvm_allocatable
  check_static_resources
  wait_datavolumes
}

check_server() {
  require_kubectl
  require_virtctl
  mkdir -p "$(dirname "$known_hosts")"
  wait_vmi_running kairos-server

  log 'checking non-interactive SSH to kairos-server'
  wait_virt_ssh kairos-server 'true' 900 10 >/dev/null

  log 'checking kairos-server SSH key material and hostname'
  wait_virt_ssh kairos-server 'test "$(hostname)" = kairos-server && test -s /home/kairos/.ssh/authorized_keys' 600 10 >/dev/null

  log 'checking kairos-server K3s service and API readiness'
  wait_virt_ssh kairos-server 'systemctl is-active --quiet k3s.service && sudo -n k3s kubectl get --raw=/readyz >/dev/null && sudo -n k3s kubectl get node kairos-server >/dev/null' 900 10

  log 'kairos-server passed SSH and K3s readiness checks'
}

check_agent() {
  require_kubectl
  require_virtctl
  mkdir -p "$(dirname "$known_hosts")"
  wait_vmi_running kairos-agent

  log 'checking non-interactive SSH to kairos-agent'
  wait_virt_ssh kairos-agent 'true' 900 10 >/dev/null

  log 'checking kairos-agent SSH key material and K3s agent service'
  wait_virt_ssh kairos-agent 'test "$(hostname)" = kairos-agent && test -s /home/kairos/.ssh/authorized_keys && systemctl is-active --quiet k3s-agent.service' 900 10 >/dev/null

  log 'checking kairos-agent node readiness from kairos-server'
  wait_virt_ssh kairos-server 'for i in $(seq 1 60); do status=$(sudo -n k3s kubectl get node kairos-agent -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}" 2>/dev/null || true); [ "$status" = True ] && exit 0; sleep 10; done; sudo -n k3s kubectl get nodes -o wide; exit 1' 900 10

  log 'kairos-agent passed SSH, service, and nested-node readiness checks'
}

check_staging_flux() {
  require_kubectl
  [ -f "$staging_kubeconfig" ] || fail "missing staging kubeconfig: $staging_kubeconfig"

  local timeout="${KAIROS_STAGING_FLUX_TIMEOUT:-15m}"
  local expected_kustomizations=(
    flux-system
    infrastructure-namespaces
    infrastructure-sources
    infrastructure-private-secrets
    infrastructure-cert-manager
    infrastructure-cert-manager-issuers
    infrastructure-longhorn
    infrastructure-longhorn-storageclasses
    infrastructure-oauth2-proxy
    infrastructure-dex
    infrastructure-traefik-middlewares
    infrastructure-monitoring
    workload-bronneberg-org
    workload-cluster-status
    workload-home-assistant
    workload-photobooth
    workload-tls-proxies
    workload-longhorn-admin
  )

  log "checking Flux readiness in staging cluster using $staging_kubeconfig"
  "$kubectl_bin" --kubeconfig "$staging_kubeconfig" -n flux-system rollout status deployment/source-controller --timeout=120s
  "$kubectl_bin" --kubeconfig "$staging_kubeconfig" -n flux-system rollout status deployment/kustomize-controller --timeout=120s
  "$kubectl_bin" --kubeconfig "$staging_kubeconfig" -n flux-system get gitrepository flux-system >/dev/null
  "$kubectl_bin" --kubeconfig "$staging_kubeconfig" -n flux-system get kustomization "${expected_kustomizations[@]}" >/dev/null
  "$kubectl_bin" --kubeconfig "$staging_kubeconfig" -n flux-system wait kustomization "${expected_kustomizations[@]}" --for=condition=Ready --timeout="$timeout"

  log 'staging Flux controllers and home rehearsal Kustomizations are ready'
}

case "$mode" in
  preflight)
    check_preflight
    ;;
  server)
    check_server
    ;;
  agent)
    check_agent
    ;;
  install-server)
    install_vm kairos-server
    ;;
  install-agent)
    install_vm kairos-agent
    ;;
  staging-flux)
    check_staging_flux
    ;;
  staging)
    check_preflight
    check_server
    check_agent
    check_staging_flux
    ;;
  all)
    check_preflight
    check_server
    check_agent
    ;;
  *)
    fail "unknown mode '$mode'; expected preflight, install-server, install-agent, server, agent, staging-flux, staging, or all"
    ;;
esac
