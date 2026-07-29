#!/usr/bin/env bash
set -euo pipefail

SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-.sops/age/keys.txt}"

status=0

check_stream() {
  local label="$1"

  awk -v label="$label" '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*provider[[:space:]]*=[[:space:]]*"github"/ { github_provider = 1 }
    /^[[:space:]]*github_(org|users)[[:space:]]*=/ {
      value = $0
      sub(/^[^=]*=[[:space:]]*/, "", value)
      if (value !~ /^""$/ && value !~ /^\[[[:space:]]*\]$/) github_gate = 1
    }
    END {
      if (github_provider && !github_gate) {
        printf "[fail] %s uses the GitHub provider without github_org or github_users\n", label
        exit 1
      }
      if (github_provider) printf "[ok] %s has a GitHub org/user allowlist\n", label
      else printf "[skip] %s does not configure the GitHub provider\n", label
    }
  '
}

check_file() {
  local path="$1"
  if ! check_stream "$path" <"$path"; then status=1; fi
}

check_traefik_error_middleware() {
  local path="clusters/home/infrastructure/oauth2-proxy/github-oauth.yaml"

  if grep -Eq '^[[:space:]]*query:[[:space:]]*/oauth2/start\?rd=\{url\}[[:space:]]*$' "$path"; then
    printf '[fail] %s must not use /oauth2/start as the Traefik error middleware query\n' "$path"
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
  local base="clusters/home/infrastructure/monitoring/values.yaml"
  local runtime="clusters/home/infrastructure/monitoring/grafana-runtime-values.yaml"
  local release="clusters/home/infrastructure/monitoring/helmrelease.yaml"

  if grep -Eq '^[[:space:]]*enable_login_token:[[:space:]]*false[[:space:]]*$' "$base"; then
    printf '[ok] %s keeps Grafana auth.proxy login tokens disabled\n' "$base"
  else
    printf '[fail] %s must explicitly keep enable_login_token: false\n' "$base"
    status=1
  fi

  if grep -Eq '^[[:space:]]*login_cookie_name:[[:space:]]*grafana_auth_proxy_session[[:space:]]*$' "$base"; then
    printf '[ok] %s keeps the dedicated Grafana auth-proxy cookie name\n' "$base"
  else
    printf '[fail] %s must keep login_cookie_name: grafana_auth_proxy_session\n' "$base"
    status=1
  fi

  if awk '
    /^[[:space:]]*name:[[:space:]]*grafana-api[[:space:]]*$/ { in_route=1 }
    in_route && /traefik.ingress.kubernetes.io\/router.middlewares:/ {
      if ($0 ~ /auth-github-oauth-forward-auth@kubernetescrd/ && $0 !~ /auth-github-oauth@kubernetescrd/) found_auth=1
      else bad=1
    }
    in_route && /^[[:space:]]*-[[:space:]]*path:[[:space:]]*\/api[[:space:]]*$/ { found_path=1 }
    in_route && /^[[:space:]]*pathType:[[:space:]]*Prefix[[:space:]]*$/ { found_prefix=1 }
    END { exit found_auth && found_path && found_prefix && !bad ? 0 : 1 }
  ' "$runtime"; then
    printf '[ok] %s routes all Grafana API traffic through forward auth only\n' "$runtime"
  else
    printf '[fail] %s must define a /api Prefix route using forward auth without the OAuth error middleware\n' "$runtime"
    status=1
  fi

  if awk '
    /^[[:space:]]*persistence:[[:space:]]*$/ { in_persistence=1; next }
    in_persistence && /^[[:space:]]*enabled:[[:space:]]*true[[:space:]]*$/ { enabled=1 }
    in_persistence && /^[[:space:]]*storageClassName:[[:space:]]*longhorn[[:space:]]*$/ { storage=1 }
    END { exit enabled && storage ? 0 : 1 }
  ' "$runtime"; then
    printf '[ok] %s persists the Grafana database on Longhorn\n' "$runtime"
  else
    printf '[fail] %s must enable Longhorn-backed Grafana persistence\n' "$runtime"
    status=1
  fi

  if awk '
    /name:[[:space:]]*prometheus-stack-private-values/ { private_line=NR }
    /name:[[:space:]]*prometheus-stack-grafana-runtime-values/ { runtime_line=NR }
    END { exit private_line && runtime_line && runtime_line > private_line ? 0 : 1 }
  ' "$release"; then
    printf '[ok] %s applies Grafana runtime values after private values\n' "$release"
  else
    printf '[fail] %s must apply prometheus-stack-grafana-runtime-values last\n' "$release"
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
