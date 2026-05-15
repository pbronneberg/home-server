#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

fail=0

scan_globs=(
  "--hidden"
  "--glob" "!.git/**"
  "--glob" "!HomeAssistentConfig.yaml"
  "--glob" "!HomeAssistantConfig.yaml"
  "--glob" "!application/myenglishplayground-nl/values.default.yaml"
  "--glob" "!private/*.sops.yaml"
  "--glob" "!scripts/check-public-redactions.sh"
)

report_matches() {
  local description="$1"
  local pattern="$2"

  if rg -n -I "${scan_globs[@]}" -- "$pattern" .; then
    printf '\nPublic-readiness check failed: %s\n\n' "$description" >&2
    fail=1
  fi
}

report_matches \
  "private RFC1918 network ranges must not be committed" \
  '(^|[^0-9])((10|192\.168|172\.(1[6-9]|2[0-9]|3[0-1]))\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)'

report_matches \
  "personal email providers must be replaced with user@example.com" \
  '[[:alnum:]._%+-]+@(gmail|hotmail|outlook|icloud|me)\.(com|nl|org)'

admin_password_matches="$(
  rg -n -I "${scan_globs[@]}" -- 'adminPassword:[[:space:]]*[^[:space:]#]+' . \
    | grep -Ev 'change-me-use-sops|example|PLACEHOLDER|\{\{' || true
)"

if [ -n "$admin_password_matches" ]; then
  printf '%s\n' "$admin_password_matches"
  printf '\nPublic-readiness check failed: adminPassword values must be placeholders or encrypted overlays.\n\n' >&2
  fail=1
fi

domain_pattern='([[:alnum:]-]+\.)+(com|org|nl|net|dev|io)([^[:alnum:]-]|$)'
domain_matches="$(
  rg -n -I --hidden --glob '!.git/**' --glob '!private/*.sops.yaml' --glob '!application/myenglishplayground-nl/values.default.yaml' -- "$domain_pattern" application clusters README.md .github AGENTS.md private \
    | grep -Ev 'example\.com|home\.example|github\.com|githubusercontent\.com|github\.io|ghcr\.io|k3s\.io|k8s\.io|helm\.sh|semver\.org|kubernetes\.io|docker\.io|hub\.docker\.com|charts\.|cert-manager\.io|traefik\.io|prometheus\.io|letsencrypt\.org|fluxcd\.io|kubebuilder\.io|git-scm\.com|users\.noreply\.github\.com|databus23|Praqma|rancher|argoproj|bitnami|elastic\.co|cattle\.io|longhorn\.io|amazonaws\.com|summerwind\.dev|dhi\.io|nip\.io' || true
)"

if [ -n "$domain_matches" ]; then
  printf '%s\n' "$domain_matches"
  printf '\nPublic-readiness check failed: replace real public domains with example values.\n\n' >&2
  fail=1
fi

if [ -f .public-denylist.local ]; then
  while IFS= read -r pattern; do
    case "$pattern" in
      ""|\#*) continue ;;
    esac

    report_matches \
      "local private denylist pattern matched: ${pattern}" \
      "$pattern"
  done < .public-denylist.local
fi

exit "$fail"
