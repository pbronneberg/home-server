#!/usr/bin/env bash
set -euo pipefail
node="${1:?usage: worker-cancel-shutdown.sh NODE}"
kubectl_bin="${KUBECTL:-kubectl}"

[[ "$("$kubectl_bin" get node "$node" -o jsonpath='{.metadata.labels.home-server\.dev/power-policy}')" == "manual-start" ]] || { echo "$node is not a manual-start worker" >&2; exit 2; }
phase="$("$kubectl_bin" get node "$node" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-phase}')"
case "$phase" in
  powered-off)
    echo "$node has reached $phase; cancellation is too late" >&2
    exit 1
    ;;
  poweroff-starting)
    started_at="$($kubectl_bin get node "$node" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-poweroff-started-at}')"
    started_epoch="$(python3 -c 'import datetime,sys; print(int(datetime.datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00")).timestamp()))' "$started_at" 2>/dev/null)" || { echo "$node poweroff start time is unknown; refusing cancellation" >&2; exit 1; }
    (( $(date +%s) - started_epoch >= 120 )) || { echo "$node may still be processing poweroff; retry cancellation after two minutes" >&2; exit 1; }
    ;;
esac
[[ -n "$("$kubectl_bin" get node "$node" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-request}')" ]] || { echo "$node has no shutdown request" >&2; exit 1; }

# The JSON Patch test makes the transition conditional on the phase we inspected.
# If the reconciler claimed poweroff meanwhile, the API rejects this patch.
"$kubectl_bin" patch node "$node" --type=json -p="[{\"op\":\"test\",\"path\":\"/metadata/annotations/home-server.dev~1shutdown-phase\",\"value\":\"$phase\"},{\"op\":\"replace\",\"path\":\"/metadata/annotations/home-server.dev~1shutdown-phase\",\"value\":\"cancel-requested\"}]"
for _ in {1..24}; do
  phase="$("$kubectl_bin" get node "$node" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-phase}')"
  request="$("$kubectl_bin" get node "$node" -o jsonpath='{.metadata.annotations.home-server\.dev/shutdown-request}')"
  [[ -n "$request" ]] || { echo "shutdown cancelled for $node; scheduling restored"; exit 0; }
  [[ "$phase" != "poweroff-starting" && "$phase" != "powered-off" ]] || { echo "$node reached $phase before cancellation completed" >&2; exit 1; }
  sleep 5
done
echo "cancellation remains pending for $node; the reconciler will retry restoration" >&2
exit 1
