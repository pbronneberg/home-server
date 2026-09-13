#!/usr/bin/env bash
set -euo pipefail

domain_source="clusters/home/infrastructure.yaml"
search_roots=(
  "application"
  "clusters/home"
  "private/flux/home"
)
existing_search_roots=()
bad_refs=()
for root in "${search_roots[@]}"; do
  if [ -d "$root" ]; then
    existing_search_roots+=("$root")
  fi
done

if [ "${#existing_search_roots[@]}" -gt 0 ]; then
  while IFS= read -r -d '' path; do
    while IFS= read -r match; do
      if [ -n "$match" ]; then
        bad_refs+=("$match")
      fi
    done < <(grep -HnE 'svc\.cluster\.local\.?' "$path" || true)
  done < <(
    find "${existing_search_roots[@]}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0
  )
fi

if [ "${#bad_refs[@]}" -gt 0 ]; then
  printf '%s\n' '[error] Home cluster service addresses must not use svc.cluster.local.' >&2
  printf '%s\n' "Source: $domain_source" >&2
  printf '%s\n' "${bad_refs[@]}" >&2
  exit 1
fi

printf '%s\n' '[ok] Home cluster service addresses do not use svc.cluster.local'
