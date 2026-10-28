#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; inventory="$root/clusters/home/bootstrap/kairos/hardware/nodes.yaml"; plans="$root/clusters/home/infrastructure/system-upgrade-plans/plans.yaml"; lifecycle="$root/clusters/home/infrastructure/manual-worker-lifecycle"
rg -q 'home-server.dev/power-policy: manual-start' "$inventory" || { echo 'manual workers must declare manual-start policy' >&2; exit 1; }
! rg -q 'home-server.dev/autoscaled' "$inventory" || { echo 'autoscaled node labels must be removed' >&2; exit 1; }
! rg -q 'wakeOnLan' "$inventory" || { echo 'manual workers must not retain Wake-on-LAN start authority' >&2; exit 1; }
rg -q 'home-server.dev/k3s-upgrade' "$plans" || { echo 'agent plan must require explicit upgrade opt-in' >&2; exit 1; }
rg -q 'manual-start' "$root/scripts/worker-shutdown.sh" || { echo 'shutdown command must validate manual-worker policy' >&2; exit 1; }
rg -q 'manual-start' "$root/scripts/worker-cancel-shutdown.sh" || { echo 'cancel command must validate manual-worker policy' >&2; exit 1; }
for token in 'shutdown-request' shutdown-request-requires-cordon control-plane-node k3s-upgrade-active strict-local-volume longhorn-evacuation-timeout poweroff-failed; do rg -q "$token" "$lifecycle/reconcile.sh" || { echo "missing lifecycle guard: $token" >&2; exit 1; }; done
rg -q '\[ -n "\$request" \] && shutdown' "$lifecycle/reconcile.sh" || { echo 'raw cordons must be ignored without a request marker' >&2; exit 1; }
rg -q 'restore_after_manual_start' "$lifecycle/reconcile.sh" || { echo 'manually started workers must be restored when Ready' >&2; exit 1; }
eviction_line="$(rg -n 'evictionRequested.:true' "$lifecycle/reconcile.sh" | cut -d: -f1 | head -1)"; drain_line="$(rg -n 'kubectl drain' "$lifecycle/reconcile.sh" | cut -d: -f1 | head -1)"
[ -n "$eviction_line" ] && [ -n "$drain_line" ] && [ "$eviction_line" -lt "$drain_line" ] || { echo 'Longhorn eviction must be requested before drain' >&2; exit 1; }
! find "$root/clusters/home/infrastructure/homelab-autoscaler" -type f -print -quit 2>/dev/null | grep -q . || { echo 'retired autoscaler resources must be removed' >&2; exit 1; }
! rg -q 'homelab-autoscaler' "$root/clusters/home/infrastructure.yaml" || { echo 'active upstream autoscaler Kustomization must be removed' >&2; exit 1; }
echo 'Manual worker lifecycle policy is valid.'
