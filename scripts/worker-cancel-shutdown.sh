#!/usr/bin/env bash
set -euo pipefail
node="${1:?usage: worker-cancel-shutdown.sh NODE}"; kubectl_bin="${KUBECTL:-kubectl}"
[[ "$("$kubectl_bin" get node "$node" -o jsonpath='{.metadata.labels.home-server\.dev/power-policy}')" == "manual-start" ]] || { echo "$node is not a manual-start worker" >&2; exit 2; }
$kubectl_bin annotate node "$node" home-server.dev/shutdown-request- home-server.dev/shutdown-requested-at- home-server.dev/shutdown-phase- home-server.dev/shutdown-reason- 2>/dev/null || true
$kubectl_bin patch nodes.longhorn.io -n longhorn-system "$node" --type merge -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}' 2>/dev/null || true
$kubectl_bin uncordon "$node"
