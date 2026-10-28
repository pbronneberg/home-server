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

annotate() { kubectl annotate node "$1" "$2=$3" --overwrite; }
event() { kubectl -n "$event_namespace" create event "manual-worker-lifecycle-$1-$(date +%s)" --type="$3" --reason="$2" --message="$4" --for="node/$1" 2>/dev/null || true; }
block() { annotate "$1" "$phase_annotation" "blocked"; annotate "$1" "$reason_annotation" "$2"; event "$1" "ManualWorkerLifecycleBlocked" "Warning" "$2"; printf 'manual worker %s blocked: %s\n' "$1" "$2" >&2; }
active_upgrade() { kubectl get pods -n system-upgrade -o jsonpath='{range .items[*]}{.spec.nodeName}{" "}{.status.phase}{"\n"}{end}' | awk -v node="$1" '$1 == node && ($2 == "Pending" || $2 == "Running") { found=1 } END { exit !found }'; }
has_replicas() { kubectl get replicas.longhorn.io -n "$namespace" -o jsonpath='{range .items[*]}{.spec.nodeID}{"\n"}{end}' | grep -qx "$1"; }
has_attachments() { kubectl get volumes.longhorn.io -n "$namespace" -o jsonpath='{range .items[*]}{.status.currentNodeID}{"\n"}{end}' | grep -qx "$1"; }
strict_local_replica() {
  for volume in $(kubectl get replicas.longhorn.io -n "$namespace" -o jsonpath='{range .items[?(@.spec.nodeID=="'"$1"'")]}{.spec.volumeName}{"\n"}{end}'); do
    [ "$(kubectl get volumes.longhorn.io -n "$namespace" "$volume" -o jsonpath='{.spec.dataLocality}')" = "strict-local" ] && return 0
  done
  return 1
}
request_age_seconds() {
  requested_at="$(kubectl get node "$1" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-requested-at}')"
  [ -n "$requested_at" ] || { printf '0\n'; return; }
  printf '%s\n' $(( $(date +%s) - $(date -d "$requested_at" +%s 2>/dev/null || printf 0) ))
}
restore_after_manual_start() {
  node="$1"; phase="$(kubectl get node "$node" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-phase}')"; ready="$(kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')"
  [ "$phase" = "powered-off" ] && [ "$ready" = "True" ] || return 0
  kubectl patch nodes.longhorn.io -n "$namespace" "$node" --type merge -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}' 2>/dev/null || true
  kubectl uncordon "$node"
  kubectl annotate node "$node" "$request_annotation"- "$requested_at_annotation"- "$phase_annotation"- "$reason_annotation"- 2>/dev/null || true
}
shutdown() {
  node="$1"
  [ "$(kubectl get node "$node" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-phase}')" != "blocked" ] || return 0
  [ "$(kubectl get node "$node" -o jsonpath='{.spec.unschedulable}')" = "true" ] || { block "$node" "shutdown-request-requires-cordon"; return; }
  node_json="$(kubectl get node "$node" -o json)" || { block "$node" "node-inspection-failed"; return; }
  if printf '%s\n' "$node_json" | grep -q '"node-role.kubernetes.io/control-plane"[[:space:]]*:'; then block "$node" "control-plane-node"; return; fi
  if active_upgrade "$node"; then block "$node" "k3s-upgrade-active"; return; fi
  if strict_local_replica "$node"; then block "$node" "strict-local-volume"; return; fi
  kubectl patch nodes.longhorn.io -n "$namespace" "$node" --type merge -p '{"spec":{"allowScheduling":false,"evictionRequested":true}}' 2>/dev/null || true
  if has_replicas "$node" || has_attachments "$node"; then
    if [ "$(request_age_seconds "$node")" -ge 7200 ]; then block "$node" "longhorn-evacuation-timeout"; else annotate "$node" "$phase_annotation" "evacuating"; annotate "$node" "$reason_annotation" "waiting-for-longhorn-evacuation"; fi
    return
  fi
  annotate "$node" "$phase_annotation" "draining"
  if ! kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=10m; then block "$node" "drain-blocked"; return; fi
  if has_replicas "$node" || has_attachments "$node"; then block "$node" "longhorn-state-changed-during-drain"; return; fi
  if ! command -v ssh >/dev/null 2>&1 && ! apk add --no-cache openssh-client; then block "$node" "poweroff-client-unavailable"; return; fi
  config="/etc/manual-worker-power/nodes.env"; key_prefix="$(printf '%s' "$node" | tr '[:lower:]-' '[:upper:]_')"
  ssh_host="$(awk -F= -v key="${key_prefix}_SSH_HOST" '$1 == key {gsub(/^"|"$/, "", $2); print $2}' "$config")"; ssh_user="$(awk -F= -v key="${key_prefix}_SSH_USER" '$1 == key {gsub(/^"|"$/, "", $2); print $2}' "$config")"; ssh_key="$(awk -F= -v key="${key_prefix}_SSH_HOST_KEY" '$1 == key {gsub(/^"|"$/, "", $2); print $2}' "$config")"
  [ -n "$ssh_host" ] && [ -n "$ssh_user" ] && [ -n "$ssh_key" ] || { block "$node" "power-credential-missing"; return; }
  mkdir -p /root/.ssh; cp /etc/manual-worker-power/ssh_private_key /root/.ssh/id_ed25519; chmod 0600 /root/.ssh/id_ed25519; printf '%s\n' "$ssh_key" > /root/.ssh/known_hosts
  if ! ssh -i /root/.ssh/id_ed25519 -o BatchMode=yes -o UserKnownHostsFile=/root/.ssh/known_hosts "${ssh_user}@${ssh_host}" "sudo /sbin/poweroff"; then block "$node" "poweroff-failed"; return; fi
  annotate "$node" "$phase_annotation" "powered-off"; annotate "$node" "$reason_annotation" "shutdown-complete"
  event "$node" "ManualWorkerLifecyclePoweroff" "Normal" "shutdown-complete"
}

for node in $(kubectl get nodes -l "${policy_label}=${policy_value}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'); do
  restore_after_manual_start "$node"
  request="$(kubectl get node "$node" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-request}')"
  [ -n "$request" ] && shutdown "$node"
done
