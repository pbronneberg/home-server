#!/usr/bin/env bash
set -euo pipefail

policy_file="clusters/home/infrastructure/longhorn/backup-recurring-jobs.yaml"
expected_group="durable-volumes"

if grep -Eq '(^|[[:space:]\[,])default([[:space:]\],#]|$)' "$policy_file"; then
  printf '%s\n' 'Longhorn backup jobs must not use the implicit default recurring-job group.' >&2
  exit 1
fi

if ! grep -Eq "^[[:space:]]+- ${expected_group}[[:space:]]*$" "$policy_file"; then
  printf 'Longhorn backup policy must use the explicit %s group.\n' "$expected_group" >&2
  exit 1
fi

printf 'Longhorn backups use explicit opt-in group %s.\n' "$expected_group"
