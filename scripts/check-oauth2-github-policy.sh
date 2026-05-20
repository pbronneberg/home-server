#!/usr/bin/env bash
set -euo pipefail

SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-.sops/age/keys.txt}"

status=0

check_stream() {
  local label="$1"

  awk -v label="$label" '
    /^[[:space:]]*#/ {
      next
    }

    /^[[:space:]]*provider[[:space:]]*=[[:space:]]*"github"/ {
      github_provider = 1
    }

    /^[[:space:]]*github_(org|users)[[:space:]]*=/ {
      value = $0
      sub(/^[^=]*=[[:space:]]*/, "", value)
      if (value !~ /^""$/ && value !~ /^\[[[:space:]]*\]$/) {
        github_gate = 1
      }
    }

    END {
      if (github_provider && !github_gate) {
        printf "[fail] %s uses the GitHub provider without github_org or github_users\n", label
        exit 1
      }

      if (github_provider) {
        printf "[ok] %s has a GitHub org/user allowlist\n", label
      } else {
        printf "[skip] %s does not configure the GitHub provider\n", label
      }
    }
  '
}

check_file() {
  local path="$1"

  if ! check_stream "$path" <"$path"; then
    status=1
  fi
}

check_traefik_error_middleware() {
  local path="clusters/home/infrastructure/oauth2-proxy/github-oauth.yaml"

  if grep -Eq '^[[:space:]]*query:[[:space:]]*/oauth2/start\?rd=\{url\}[[:space:]]*$' "$path"; then
    printf '[fail] %s must not use /oauth2/start as the Traefik error middleware query\n' "$path"
    printf '[hint] Keep github-oauth-errors on /oauth2/sign_in?rd={url}; /oauth2/start returns a redirect body under Traefik-preserved 401/403 responses.\n'
    status=1
    return
  fi

  if grep -Eq '^[[:space:]]*query:[[:space:]]*/oauth2/sign_in\?rd=\{url\}[[:space:]]*$' "$path"; then
    printf '[ok] %s keeps Traefik OAuth errors on /oauth2/sign_in\n' "$path"
  else
    printf '[fail] %s must keep github-oauth-errors query at /oauth2/sign_in?rd={url}\n' "$path"
    status=1
  fi
}

printf '%s\n' 'OAuth2 GitHub authorization policy check'

check_traefik_error_middleware
check_file clusters/home/infrastructure/oauth2-proxy/values.yaml
check_file private/flux/home/oauth2-proxy-values.example.yaml

if [ -f private/flux/home/oauth2-proxy-values.sops.yaml ]; then
  if [ -f "$SOPS_AGE_KEY_FILE" ] && command -v sops >/dev/null 2>&1; then
    if ! SOPS_AGE_KEY_FILE="$SOPS_AGE_KEY_FILE" sops -d --extract '["stringData"]["values.yaml"]' private/flux/home/oauth2-proxy-values.sops.yaml |
      check_stream private/flux/home/oauth2-proxy-values.sops.yaml; then
      status=1
    fi
  else
    printf '[skip] private/flux/home/oauth2-proxy-values.sops.yaml requires SOPS and %s to validate locally\n' "$SOPS_AGE_KEY_FILE"
  fi
fi

exit "$status"
