#!/usr/bin/env bash
set -euo pipefail

policy_file="clusters/home/infrastructure/longhorn/backup-recurring-jobs.yaml"
home_assistant_pvc="application/home-assistant/templates/pvc.yaml"
backup_alerts="clusters/home/infrastructure/monitoring/rules/longhorn-backup-rules.yaml"

if grep -q 'name: weekly-system-backup' "$policy_file"; then
  printf '%s\n' 'Longhorn system backups must remain disabled.' >&2
  exit 1
fi

if grep -A12 'name: daily-volume-backup' "$policy_file" | grep -q 'groups:'; then
  printf '%s\n' 'Daily volume backups must not select a recurring-job group.' >&2
  exit 1
fi

for label in \
  'recurring-job.longhorn.io/source: "enabled"' \
  'recurring-job.longhorn.io/daily-volume-backup: "enabled"'; do
  grep -Fq "$label" "$home_assistant_pvc" || {
    printf 'Home Assistant PVC is missing the required label: %s\n' "$label" >&2
    exit 1
  }
done

grep -A10 'name: prometheus-snapshot-prune' "$policy_file" | grep -Eq '^[[:space:]]*retain:[[:space:]]*2[[:space:]]*$' || {
  printf '%s\n' 'Prometheus snapshot pruning must retain two snapshots.' >&2
  exit 1
}
grep -Fq 'task: snapshot-delete' "$policy_file" || {
  printf '%s\n' 'Prometheus snapshot pruning must use Longhorn snapshot-delete.' >&2
  exit 1
}
grep -Fq 'pvc_namespace="homeassistant"' "$backup_alerts" || {
  printf '%s\n' 'Backup freshness alert must be scoped to Home Assistant.' >&2
  exit 1
}

printf '%s\n' 'Longhorn backups are limited to Home Assistant; Prometheus local snapshots retain two.'
