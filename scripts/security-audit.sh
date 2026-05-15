#!/usr/bin/env bash
set -euo pipefail

warn_count=0

search() {
  local pattern="$1"
  shift

  if command -v rg >/dev/null 2>&1; then
    rg -n --hidden --glob '!.git' --glob '!private/**/*.sops.yaml' "$pattern" "$@" || true
  else
    grep -RInE --exclude-dir=.git --exclude='*.sops.yaml' "$pattern" "$@" || true
  fi
}

check_pattern() {
  local title="$1"
  local pattern="$2"
  shift 2
  local output

  output="$(search "$pattern" "$@" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)"
  if [ -n "$output" ]; then
    warn_count=$((warn_count + 1))
    printf '\n[warn] %s\n%s\n' "$title" "$output"
  else
    printf '[ok] %s\n' "$title"
  fi
}

printf '%s\n' 'Security audit report (report-only)'

check_pattern \
  'No mutable latest image tags in committed manifests' \
  '(^|[[:space:]])tag:[[:space:]]*"?latest"?($|[[:space:]])|image:[^[:space:]]+:latest($|[[:space:]])' \
  application clusters .github

check_pattern \
  'No legacy Traefik ingress annotations in chart defaults' \
  'traefik\.ingress\.kubernetes\.io/(redirect-entry-point|redirect-permanent|frontend-entry-points|whitelist-source-range)|ingress\.kubernetes\.io/auth-|kubernetes\.io/(tls-acme|ingress\.class)' \
  application clusters

check_pattern \
  'No intentionally empty password mode in workload defaults' \
  'allowEmptyPassword:[[:space:]]*true|automountServiceAccountToken:[[:space:]]*true' \
  application clusters

check_pattern \
  'No empty pod/container security context maps in workload defaults' \
  '^[[:space:]]*(podSecurityContext|securityContext):[[:space:]]*\{\}[[:space:]]*$' \
  application clusters

tracked_private="$(git ls-files | grep -E '(^|/)(private-decrypted|\.sops/age)(/|$)|\.(decrypted|plain|local)\.ya?ml$' || true)"
if [ -n "$tracked_private" ]; then
  warn_count=$((warn_count + 1))
  printf '\n[warn] Ignored private/plaintext files are tracked\n%s\n' "$tracked_private"
else
  printf '[ok] Ignored private/plaintext files are not tracked\n'
fi

if command -v kubectl >/dev/null 2>&1 && kubectl config current-context >/dev/null 2>&1; then
  printf '\nLive cluster read-only hints:\n'
  kubectl get namespaces --show-labels 2>/dev/null | grep -E '(^NAME|pod-security\.kubernetes\.io)' || true
  kubectl get networkpolicy -A 2>/dev/null || true
else
  printf '\nLive cluster read-only hints skipped: kubectl context unavailable.\n'
fi

printf '\nSecurity audit completed with %s warning group(s). Report-only target exits 0.\n' "$warn_count"
