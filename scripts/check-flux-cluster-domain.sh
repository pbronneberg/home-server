#!/usr/bin/env bash
set -euo pipefail

domain_source="clusters/home/infrastructure.yaml"
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
service_address_files=()
while IFS= read -r path; do
  service_address_files+=("$path")
done < <(
  find clusters/home -type f \( -name '*.yaml' -o -name '*.yml' \) -print0 \
    | xargs -0 -r grep -l 'svc\.' \
    | sort
)

if [ -z "$expected_domain" ]; then
  printf '%s\n' '[error] Unable to determine the home cluster domain.' >&2
  printf '%s\n' "Source: $domain_source" >&2
  exit 1
fi

if [ "${#service_address_files[@]}" -eq 0 ]; then
  printf '%s\n' '[error] No home cluster service address manifests found.' >&2
  exit 1
fi

bad_refs="$(
  grep -nE 'svc\.cluster\.local' "${service_address_files[@]}" || true
)"

if [ -n "$bad_refs" ]; then
  printf '%s\n' '[error] Home cluster service addresses must use the configured K3s cluster domain.' >&2
  printf '%s\n' "Source: $domain_source" >&2
  printf '%s\n' "Expected service suffix: svc.${expected_domain}" >&2
  printf '%s\n' "$bad_refs" >&2
  exit 1
fi

printf '%s\n' "[ok] Home cluster service addresses use svc.${expected_domain}"
