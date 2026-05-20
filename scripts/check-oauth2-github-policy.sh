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

check_grafana_auth_proxy() {
  local path="clusters/home/infrastructure/monitoring/values.yaml"

  if grep -Eq '^[[:space:]]*enable_login_token:[[:space:]]*true[[:space:]]*$' "$path"; then
    printf '[fail] %s must keep Grafana auth.proxy enable_login_token disabled behind oauth2-proxy\n' "$path"
    printf '[hint] Login tokens make Grafana call /api/user/auth-tokens/rotate, which can re-enter the edge auth flow.\n'
    status=1
    return
  fi

  if grep -Eq '^[[:space:]]*enable_login_token:[[:space:]]*false[[:space:]]*$' "$path"; then
    printf '[ok] %s keeps Grafana auth.proxy login tokens disabled\n' "$path"
  else
    printf '[fail] %s must explicitly set Grafana auth.proxy enable_login_token: false\n' "$path"
    status=1
  fi

  if grep -Eq '^[[:space:]]*login_cookie_name:[[:space:]]*grafana_auth_proxy_session[[:space:]]*$' "$path"; then
    printf '[ok] %s keeps Grafana on the auth-proxy cookie name\n' "$path"
  elif grep -Eq '^[[:space:]]*login_cookie_name:' "$path"; then
    printf '[fail] %s must keep Grafana login_cookie_name at grafana_auth_proxy_session\n' "$path"
    status=1
  else
    printf '[fail] %s must set Grafana login_cookie_name to grafana_auth_proxy_session\n' "$path"
    status=1
  fi

  if awk '
    /^[[:space:]]*name:[[:space:]]*grafana-auth-token-rotate[[:space:]]*$/ { in_route=1 }
    in_route && /traefik.ingress.kubernetes.io\/router.middlewares:/ {
      if ($0 ~ /auth-github-oauth-forward-auth@kubernetescrd/ && $0 !~ /auth-github-oauth@kubernetescrd/) {
        found=1
      } else {
        bad=1
      }
    }
    in_route && /^[[:space:]]*\{\{- end \}\}/ { in_route=0 }
    END { exit found && !bad ? 0 : 1 }
  ' "$path"; then
    printf '[ok] %s keeps Grafana token rotation on forward auth only\n' "$path"
  else
    printf '[fail] %s must route Grafana /api/user/auth-tokens/rotate through forward auth without the OAuth error middleware\n' "$path"
    status=1
  fi
}

printf '%s\n' 'OAuth2 GitHub authorization policy check'

check_traefik_error_middleware
check_grafana_auth_proxy
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
