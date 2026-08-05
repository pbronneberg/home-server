#!/usr/bin/env bash
set -euo pipefail

plans_file="clusters/home/infrastructure/system-upgrade-plans/plans.yaml"

if grep -Eq '^[[:space:]]+channel:' "$plans_file"; then
  printf '%s\n' 'K3s upgrade plans must pin version; floating channels bypass pull-request review.' >&2
  exit 1
fi

versions="$(awk '/^[[:space:]]+version:/ {gsub(/["'\'' ]/, "", $2); print $2}' "$plans_file")"
version_count="$(printf '%s\n' "$versions" | awk 'NF {count++} END {print count + 0}')"
unique_count="$(printf '%s\n' "$versions" | awk 'NF' | sort -u | wc -l | tr -d ' ')"
version="$(printf '%s\n' "$versions" | awk 'NF {print; exit}')"

if [ "$version_count" -ne 2 ] || [ "$unique_count" -ne 1 ]; then
  printf '%s\n' 'Server and agent plans must pin the same explicit K3s version.' >&2
  exit 1
fi

if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$ ]]; then
  printf 'Invalid pinned K3s version: %s\n' "$version" >&2
  exit 1
fi

printf 'K3s upgrade plans pin reviewed version %s.\n' "$version"
