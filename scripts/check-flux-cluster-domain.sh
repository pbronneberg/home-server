#!/usr/bin/env bash
set -euo pipefail

expected_domain="home-server.bronneberg.local"
flux_components="clusters/home/flux-system/gotk-components.yaml"

bad_refs="$(rg -n 'svc\.cluster\.local' "$flux_components" || true)"
if [ -n "$bad_refs" ]; then
  printf '%s\n' '[error] Flux controller service addresses must use the K3s cluster domain.' >&2
  printf '%s\n' "Expected service suffix: svc.${expected_domain}" >&2
  printf '%s\n' "$bad_refs" >&2
  exit 1
fi

missing_refs="$(rg -n "svc\.${expected_domain//./\.}" "$flux_components" || true)"
if [ -z "$missing_refs" ]; then
  printf '%s\n' "[error] Flux controller service addresses do not reference svc.${expected_domain}." >&2
  exit 1
fi

printf '%s\n' "[ok] Flux controller service addresses use svc.${expected_domain}"
