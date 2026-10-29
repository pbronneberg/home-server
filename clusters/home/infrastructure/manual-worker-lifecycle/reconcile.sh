#!/bin/sh
set -eu

namespace="longhorn-system"
event_namespace="manual-worker-lifecycle-system"
policy_label="home-server.dev/power-policy"
policy_value="manual-start"
request_annotation="home-server.dev/shutdown-request"
requested_at_annotation="home-server.dev/shutdown-requested-at"
phase_annotation="home-server.dev/shutdown-phase"
reason_annotation="home-server.dev/shutdown-reason"
boot_id_annotation="home-server.dev/shutdown-boot-id"
poweroff_started_annotation="home-server.dev/shutdown-poweroff-started-at"

annotate() { kubectl annotate node "$1" "$2=$3" --overwrite; }
event() { kubectl -n "$event_namespace" create event "manual-worker-lifecycle-$1-$(date +%s)" --type="$3" --reason="$2" --message="$4" --for="node/$1" 2>/dev/null || true; }
record_reason() { annotate "$1" "$reason_annotation" "$2" || true; }
restart_phase() {
  case "$1" in powered-off|poweroff-starting|poweroff-uncertain) return 0 ;; esac
  return 1
}
block() {
  node="$1"; reason="$2"
  current_phase=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-phase}') || current_phase=""
  current_request=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-request}') || current_request=""
  if [ -n "$current_request" ] && [ "$current_request" = "$active_request" ] && [ "$current_phase" != "cancel-requested" ] && ! restart_phase "$current_phase"; then
    kubectl patch node "$node" --type=json -p="[{\"op\":\"test\",\"path\":\"/metadata/annotations/home-server.dev~1shutdown-request\",\"value\":\"$active_request\"},{\"op\":\"test\",\"path\":\"/metadata/annotations/home-server.dev~1shutdown-phase\",\"value\":\"$current_phase\"},{\"op\":\"replace\",\"path\":\"/metadata/annotations/home-server.dev~1shutdown-phase\",\"value\":\"blocked\"}]" >/dev/null || true
  fi
  record_reason "$node" "$reason"
  event "$node" "ManualWorkerLifecycleBlocked" "Warning" "$reason"
  printf 'manual worker %s blocked: %s\n' "$node" "$reason" >&2
}
transition_phase() {
  node="$1"; request_id="$2"; expected="$3"; next="$4"
  case "$request_id" in *[!a-zA-Z0-9._-]*) record_reason "$node" "invalid-shutdown-request"; return 2 ;; esac
  if kubectl patch node "$node" --type=json -p="[{\"op\":\"test\",\"path\":\"/metadata/annotations/home-server.dev~1shutdown-request\",\"value\":\"$request_id\"},{\"op\":\"test\",\"path\":\"/metadata/annotations/home-server.dev~1shutdown-phase\",\"value\":\"$expected\"},{\"op\":\"test\",\"path\":\"/spec/unschedulable\",\"value\":true},{\"op\":\"replace\",\"path\":\"/metadata/annotations/home-server.dev~1shutdown-phase\",\"value\":\"$next\"}]" >/dev/null; then
    active_phase="$next"
    return 0
  fi
  if ! current_phase=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-phase}') ||
     ! current_request=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-request}'); then
    record_reason "$node" "phase-transition-read-failed"
    return 2
  fi
  if [ "$current_request" != "$request_id" ] || [ "$current_phase" = "cancel-requested" ]; then
    active_phase="$current_phase"
    return 1
  fi
  record_reason "$node" "phase-transition-failed"
  return 2
}

# Return 0 when a blocker exists, 1 when clear, and 2 when the API state is unknown.
active_upgrade() {
  if ! items=$(kubectl get pods -n system-upgrade -o jsonpath='{range .items[*]}{.spec.nodeName}{" "}{.status.phase}{"\n"}{end}'); then return 2; fi
  printf '%s\n' "$items" | awk -v node="$1" '$1 == node && ($2 == "Pending" || $2 == "Running") { found=1 } END { exit !found }'
}
has_replicas() {
  if ! items=$(kubectl get replicas.longhorn.io -n "$namespace" -o jsonpath='{range .items[*]}{.spec.nodeID}{"\n"}{end}'); then return 2; fi
  printf '%s\n' "$items" | grep -Fqx "$1"
}
has_attachments() {
  if ! items=$(kubectl get volumes.longhorn.io -n "$namespace" -o jsonpath='{range .items[*]}{.status.currentNodeID}{"\n"}{end}'); then return 2; fi
  printf '%s\n' "$items" | grep -Fqx "$1"
}
strict_local_replica() {
  if ! volumes=$(kubectl get replicas.longhorn.io -n "$namespace" -o jsonpath='{range .items[?(@.spec.nodeID=="'"$1"'")]}{.spec.volumeName}{"\n"}{end}'); then return 2; fi
  for volume in $volumes; do
    if ! locality=$(kubectl get volumes.longhorn.io -n "$namespace" "$volume" -o jsonpath='{.spec.dataLocality}'); then return 2; fi
    [ "$locality" = "strict-local" ] && return 0
  done
  return 1
}
request_age_seconds() {
  if ! requested_at=$(kubectl get node "$1" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-requested-at}'); then return 1; fi
  [ -n "$requested_at" ] || { printf '0\n'; return; }
  parsed="$(date -d "$requested_at" +%s 2>/dev/null)" || return 1
  printf '%s\n' $(( $(date +%s) - parsed ))
}
node_field() { kubectl get node "$1" -o jsonpath="$2"; }
longhorn_state() {
  if ! kubectl patch nodes.longhorn.io -n "$namespace" "$1" --type merge -p "$2" >/dev/null; then
    block "$1" "longhorn-evacuation-state-failed"
    return 1
  fi
}
restore_after_manual_start() {
  node="$1"
  if ! phase=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-phase}') ||
     ! saved_boot=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-boot-id}') ||
     ! current_boot=$(node_field "$node" '{.status.nodeInfo.bootID}') ||
     ! ready=$(node_field "$node" '{.status.conditions[?(@.type=="Ready")].status}'); then
    record_reason "$node" "restart-state-read-failed"
    return 1
  fi
  restart_phase "$phase" || return 0
  # Ready can remain True until kubelet notices a shutdown. Require a new boot.
  [ -n "$saved_boot" ] && [ "$current_boot" != "$saved_boot" ] && [ "$ready" = "True" ] || return 0
  if ! kubectl patch nodes.longhorn.io -n "$namespace" "$node" --type merge -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}' >/dev/null; then
    record_reason "$node" "restart-longhorn-restore-failed"
    return 1
  fi
  if ! kubectl uncordon "$node"; then
    record_reason "$node" "uncordon-after-restart-failed"
    return 1
  fi
  if ! kubectl annotate node "$node" "$request_annotation-" "$requested_at_annotation-" "$phase_annotation-" "$reason_annotation-" "$boot_id_annotation-" "$poweroff_started_annotation-"; then
    record_reason "$node" "restart-marker-clear-failed"
    return 1
  fi
}
check_inventory() {
  node="$1"
  if active_upgrade "$node"; then result=0; else result=$?; fi
  [ "$result" -eq 1 ] || { [ "$result" -eq 0 ] && { block "$node" "k3s-upgrade-active"; return 1; }; block "$node" "upgrade-state-read-failed"; return 1; }
  if strict_local_replica "$node"; then result=0; else result=$?; fi
  [ "$result" -eq 1 ] || { [ "$result" -eq 0 ] && { block "$node" "strict-local-volume"; return 1; }; block "$node" "longhorn-replica-read-failed"; return 1; }
}
cancel_shutdown() {
  node="$1"
  if ! kubectl patch nodes.longhorn.io -n "$namespace" "$node" --type merge -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}' >/dev/null; then
    annotate "$node" "$reason_annotation" "cancel-longhorn-restore-failed"
    return 1
  fi
  if ! kubectl uncordon "$node"; then
    annotate "$node" "$reason_annotation" "cancel-uncordon-failed"
    return 1
  fi
  kubectl annotate node "$node" "$request_annotation-" "$requested_at_annotation-" "$phase_annotation-" "$reason_annotation-" "$boot_id_annotation-" "$poweroff_started_annotation-"
}
shutdown() {
  node="$1"
  if ! phase=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-phase}') ||
     ! request=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-request}'); then
    record_reason "$node" "node-inspection-failed"
    return 1
  fi
  active_phase="$phase"
  [ "$request" = "$active_request" ] || return 0
  if [ "$phase" = "cancel-requested" ]; then cancel_shutdown "$node"; return $?; fi
  # powered-off is terminal until restart restoration; do not retry SSH.
  case "$phase" in blocked|powered-off|cancel-requested|cancelled|poweroff-starting|poweroff-uncertain) return 0 ;; esac
  if ! unschedulable=$(node_field "$node" '{.spec.unschedulable}'); then block "$node" "node-inspection-failed"; return 1; fi
  [ "$unschedulable" = "true" ] || { block "$node" "shutdown-request-requires-cordon"; return 1; }
  if ! node_json=$(kubectl get node "$node" -o json); then block "$node" "node-inspection-failed"; return 1; fi
  if printf '%s\n' "$node_json" | grep -q '"node-role.kubernetes.io/control-plane"[[:space:]]*:'; then block "$node" "control-plane-node"; return 1; fi
  check_inventory "$node" || return 1
  longhorn_state "$node" '{"spec":{"allowScheduling":false,"evictionRequested":true}}' || return 1

  # First evacuate replicas while workloads remain available. Drain is what releases
  # attachments held by running Pods, so attachment checks happen after the drain.
  while :; do
    if has_replicas "$node"; then result=0; else result=$?; fi
    [ "$result" -eq 1 ] && break
    [ "$result" -eq 0 ] || { block "$node" "longhorn-replica-read-failed"; return 1; }
    if ! age=$(request_age_seconds "$node"); then block "$node" "shutdown-request-time-read-failed"; return 1; fi
    if [ "$age" -ge 7200 ]; then block "$node" "longhorn-evacuation-timeout"; return 1; fi
    transition_phase "$node" "$active_request" "$active_phase" "evacuating"; transition_result=$?
    [ "$transition_result" -eq 0 ] || { [ "$transition_result" -eq 1 ] && return 0; block "$node" "evacuation-phase-transition-failed"; return 1; }
    if ! annotate "$node" "$reason_annotation" "waiting-for-longhorn-replica-evacuation"; then record_reason "$node" "evacuation-reason-write-failed"; return 1; fi
    return 0
  done
  transition_phase "$node" "$active_request" "$active_phase" "draining"; transition_result=$?
  [ "$transition_result" -eq 0 ] || { [ "$transition_result" -eq 1 ] && return 0; block "$node" "drain-phase-transition-failed"; return 1; }
  if ! annotate "$node" "$reason_annotation" "draining"; then record_reason "$node" "drain-reason-write-failed"; return 1; fi
  if ! kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=10m; then block "$node" "drain-blocked"; return 1; fi

  deadline=$(( $(date +%s) + 600 ))
  while :; do
    if has_replicas "$node"; then replicas_result=0; else replicas_result=$?; fi
    if has_attachments "$node"; then attachments_result=0; else attachments_result=$?; fi
    [ "$replicas_result" -le 1 ] && [ "$attachments_result" -le 1 ] || { block "$node" "longhorn-state-read-failed"; return 1; }
    [ "$replicas_result" -eq 1 ] && [ "$attachments_result" -eq 1 ] && break
    [ "$(date +%s)" -lt "$deadline" ] || { block "$node" "longhorn-detachment-timeout"; return 1; }
    sleep 10
  done
  check_inventory "$node" || return 1
  # Re-read the request and cordon immediately before the poweroff claim.
  if ! request=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-request}') ||
     ! unschedulable=$(node_field "$node" '{.spec.unschedulable}') ||
     ! phase=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-phase}'); then block "$node" "shutdown-preflight-read-failed"; return 1; fi
  [ -n "$request" ] && [ "$request" = "$active_request" ] || return 0
  [ "$phase" = "cancel-requested" ] && { cancel_shutdown "$node"; return $?; }
  [ "$unschedulable" = "true" ] || { block "$node" "shutdown-request-no-longer-cordoned"; return 1; }
  if ! boot_id=$(node_field "$node" '{.status.nodeInfo.bootID}'); then block "$node" "shutdown-boot-id-read-failed"; return 1; fi
  [ -n "$boot_id" ] || { block "$node" "shutdown-boot-id-missing"; return 1; }
  if ! command -v ssh >/dev/null 2>&1 && ! apk add --no-cache openssh-client; then block "$node" "poweroff-client-unavailable"; return 1; fi
  config="/etc/manual-worker-power/nodes.env"; key_prefix="$(printf '%s' "$node" | tr '[:lower:]-' '[:upper:]_')"
  if [ ! -r "$config" ] || [ ! -r /etc/manual-worker-power/ssh_private_key ]; then block "$node" "power-credential-missing"; return 1; fi
  ssh_host=$(awk -F= -v key="${key_prefix}_SSH_HOST" '$1 == key {gsub(/^"|"$/, "", $2); print $2}' "$config")
  ssh_user=$(awk -F= -v key="${key_prefix}_SSH_USER" '$1 == key {gsub(/^"|"$/, "", $2); print $2}' "$config")
  ssh_key=$(awk -F= -v key="${key_prefix}_SSH_HOST_KEY" '$1 == key {gsub(/^"|"$/, "", $2); print $2}' "$config")
  [ -n "$ssh_host" ] && [ -n "$ssh_user" ] && [ -n "$ssh_key" ] || { block "$node" "power-credential-missing"; return 1; }
  if ! mkdir -p /root/.ssh || ! cp /etc/manual-worker-power/ssh_private_key /root/.ssh/id_ed25519 || ! chmod 0600 /root/.ssh/id_ed25519 || ! printf '%s\n' "$ssh_key" > /root/.ssh/known_hosts; then
    block "$node" "power-credential-setup-failed"
    return 1
  fi
  annotate "$node" "$boot_id_annotation" "$boot_id" || { block "$node" "shutdown-boot-id-persist-failed"; return 1; }
  annotate "$node" "$poweroff_started_annotation" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" || { block "$node" "shutdown-start-time-persist-failed"; return 1; }
  # The final claim tests the same request, phase, and cordon seen at preflight.
  transition_phase "$node" "$active_request" "$phase" "poweroff-starting"; transition_result=$?
  [ "$transition_result" -eq 0 ] || { [ "$transition_result" -eq 1 ] && return 0; block "$node" "poweroff-claim-failed"; return 1; }
  if ! annotate "$node" "$reason_annotation" "poweroff-requested"; then record_reason "$node" "poweroff-reason-write-failed"; return 1; fi
  # Cancellation is acknowledged only by the reconciler. The operator command
  # refuses while this bounded poweroff request can still be in flight.
  if ! timeout 60 ssh -i /root/.ssh/id_ed25519 -o BatchMode=yes -o ConnectTimeout=10 -o UserKnownHostsFile=/root/.ssh/known_hosts "${ssh_user}@${ssh_host}" "sudo /sbin/poweroff"; then
    if ! annotate "$node" "$phase_annotation" "poweroff-uncertain"; then record_reason "$node" "poweroff-result-unknown"; return 1; fi
    active_phase="poweroff-uncertain"
    if ! annotate "$node" "$reason_annotation" "poweroff-result-unknown"; then record_reason "$node" "poweroff-result-unknown"; return 1; fi
    event "$node" "ManualWorkerLifecyclePoweroffUncertain" "Warning" "poweroff-result-unknown"
    return 1
  fi
  if ! annotate "$node" "$phase_annotation" "powered-off"; then record_reason "$node" "shutdown-state-write-failed"; return 1; fi
  active_phase="powered-off"
  if ! annotate "$node" "$reason_annotation" "shutdown-complete"; then record_reason "$node" "shutdown-state-write-failed"; return 1; fi
  event "$node" "ManualWorkerLifecyclePoweroff" "Normal" "shutdown-complete"
}

if ! selected=$(kubectl get nodes -l "${policy_label}=${policy_value}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); then
  printf '%s\n' 'manual worker inventory read failed' >&2
  exit 1
fi
failures=0
for node in $selected; do
  active_request=""
  if ! restore_after_manual_start "$node"; then
    failures=$((failures + 1))
    continue
  fi
  if ! request=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-request}'); then
    record_reason "$node" "shutdown-request-read-failed"
    failures=$((failures + 1))
    continue
  fi
  if [ -z "$request" ]; then
    if ! phase=$(node_field "$node" '{.metadata.annotations.home-server\.dev/shutdown-phase}'); then
      record_reason "$node" "shutdown-phase-read-failed"
      failures=$((failures + 1))
      continue
    fi
    [ "$phase" = "cancel-requested" ] || continue
  fi
  active_request="$request"
  if ! shutdown "$node"; then failures=$((failures + 1)); fi
done
[ "$failures" -eq 0 ] || exit 1
