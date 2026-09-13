#!/usr/bin/env bash
set -euo pipefail

domain_source="clusters/home/infrastructure.yaml"
expected_domain="$(
  awk '/KAIROS_CLUSTER_DOMAIN:/ { print $2; exit }' "$domain_source"
)"
expected_domain="${expected_domain#\"}"
expected_domain="${expected_domain%\"}"
expected_domain="${expected_domain#\'}"
expected_domain="${expected_domain%\'}"
service_address_files=(
  "clusters/home/flux-system/gotk-components.yaml"
  "clusters/home/infrastructure.yaml"
  "clusters/home/infrastructure/flux-webhook/github-pr-event-bridge.yaml"
  "clusters/home/infrastructure/monitoring/monitors/grafana-probe.yaml"
)

if [ -z "$expected_domain" ]; then
  printf '%s\n' '[error] Unable to determine the home cluster domain.' >&2
  printf '%s\n' "Source: $domain_source" >&2
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
