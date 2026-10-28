#!/usr/bin/env bash
set -euo pipefail
node="${1:?usage: worker-upgrade.sh NODE}"; kubectl_bin="${KUBECTL:-kubectl}"
$kubectl_bin wait --for=condition=Ready "node/$node" --timeout=15m
$kubectl_bin label node "$node" home-server.dev/k3s-upgrade=enabled --overwrite
printf '%s is opted in to the next K3S agent maintenance window; remove the label after Plan completion.\n' "$node"
