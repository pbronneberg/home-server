#!/usr/bin/env bash
set -euo pipefail

domain_source="clusters/home/infrastructure.yaml"
search_roots=(
  "application"
  "clusters/home"
  "private/flux/home"
)
existing_search_roots=()
service_address_files=()
bad_refs=()
expected_domain="$(
  python3 - "$domain_source" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as handle:
    for document in yaml.safe_load_all(handle):
        if not isinstance(document, dict):
            continue
        value = (
            document.get("spec", {})
            .get("postBuild", {})
            .get("substitute", {})
            .get("KAIROS_CLUSTER_DOMAIN")
        )
        if value:
            print(value)
            break
PY
)"

if [ -z "$expected_domain" ]; then
  printf '%s\n' '[error] Unable to determine the home cluster domain.' >&2
  printf '%s\n' "Source: $domain_source" >&2
  exit 1
fi

for root in "${search_roots[@]}"; do
  if [ -d "$root" ]; then
    existing_search_roots+=("$root")
  fi
done

if [ "${#existing_search_roots[@]}" -gt 0 ]; then
  while IFS= read -r -d '' path; do
    if grep -q 'svc\.' "$path"; then
      service_address_files+=("$path")
      while IFS= read -r match; do
        if [ -n "$match" ]; then
          bad_refs+=("$match")
        fi
      done < <(grep -HnE 'svc\.cluster\.local' "$path" || true)
    fi
  done < <(
    find "${existing_search_roots[@]}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print0
  )
fi

if [ "${#bad_refs[@]}" -gt 0 ]; then
  printf '%s\n' '[error] Home cluster service addresses must use the configured K3s cluster domain.' >&2
  printf '%s\n' "Source: $domain_source" >&2
  printf '%s\n' "Expected service suffix: svc.${expected_domain}" >&2
  printf '%s\n' "${bad_refs[@]}" >&2
  exit 1
fi

printf '%s\n' "[ok] Home cluster service addresses use svc.${expected_domain}"
