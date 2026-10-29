#!/usr/bin/env bash
set -euo pipefail
node="${1:?usage: worker-shutdown.sh NODE}"; kubectl_bin="${KUBECTL:-kubectl}"
[[ "$($kubectl_bin get node "$node" -o jsonpath='{.metadata.labels.home-server\.dev/power-policy}')" == "manual-start" ]] || { echo "$node is not a manual-start worker" >&2; exit 2; }
node_json="$($kubectl_bin get node "$node" -o json)"
if grep -q '"node-role.kubernetes.io/control-plane"[[:space:]]*:' <<<"$node_json"; then
  echo "refusing shutdown request for control-plane node $node" >&2
  exit 2
fi
request="$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}"; $kubectl_bin cordon "$node"
$kubectl_bin annotate node "$node" "home-server.dev/shutdown-request=$request" "home-server.dev/shutdown-requested-at=$(date -u +%Y-%m-%dT%H:%M:%SZ)" home-server.dev/shutdown-phase=requested home-server.dev/shutdown-reason=requested --overwrite
printf 'shutdown request %s accepted for %s; use make worker-shutdown-status NODE=%s\n' "$request" "$node" "$node"
