#!/usr/bin/env bash
set -euo pipefail

expected_domain="home-server.bronneberg.local"
mapfile -t flux_components < <(find clusters -path '*/flux-system/gotk-components.yaml' -type f | sort)

if [ "${#flux_components[@]}" -eq 0 ]; then
  printf '%s\n' '[error] No Flux controller component manifests found.' >&2
  exit 1
fi

for components in "${flux_components[@]}"; do
  bad_refs="$(rg -n 'svc\.cluster\.local' "$components" || true)"
  if [ -n "$bad_refs" ]; then
    printf '%s\n' '[error] Flux controller service addresses must use the K3s cluster domain.' >&2
    printf '%s\n' "File: $components" >&2
    printf '%s\n' "Expected service suffix: svc.${expected_domain}" >&2
    printf '%s\n' "$bad_refs" >&2
    exit 1
  fi

  missing_refs="$(rg -n "svc\.${expected_domain//./\.}" "$components" || true)"
  if [ -z "$missing_refs" ]; then
    printf '%s\n' "[error] Flux controller service addresses do not reference svc.${expected_domain}: $components" >&2
    exit 1
  fi
done

printf '%s\n' "[ok] Flux controller service addresses use svc.${expected_domain} in ${#flux_components[@]} bundle(s)"
