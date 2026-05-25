#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

fail=0

report_history_matches() {
  local description="$1"
  local pattern="$2"
  local exclude_pattern="${3:-}"
  local matches=""
  local commit
  local lines
  local summary

  while IFS= read -r commit; do
    [ -n "$commit" ] || continue

    lines="$(git show --format= --unified=0 "$commit" -- . \
      | grep -E -- "$pattern" || true)"

    if [ -n "$exclude_pattern" ]; then
      lines="$(printf '%s\n' "$lines" | grep -Ev -- "$exclude_pattern" || true)"
    fi

    if [ -n "$lines" ]; then
      summary="$(git log -1 --format='%h %s' "$commit")"
      matches="${matches}${summary}\n"
    fi
  done < <(git log --all --format='%H' -G "$pattern" -- . || true)

  if [ -n "$matches" ]; then
    printf '%b' "$matches"
    printf '\nHistory public-readiness check failed: %s\n\n' "$description" >&2
    fail=1
  fi
}

report_history_matches \
  "private RFC1918 network ranges exist in Git history" \
  '(^|[^0-9])((10|192\.168|172\.(1[6-9]|2[0-9]|3[0-1]))\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})([^0-9]|$)' \
  'KAIROS_(CLUSTER_CIDR|SERVICE_CIDR|CLUSTER_DNS):'

report_history_matches \
  "personal email providers exist in Git history" \
  '[[:alnum:]._%+-]+@(gmail|hotmail|outlook|icloud|me)\.(com|nl|org)'

if [ -f .public-denylist.local ]; then
  while IFS= read -r pattern; do
    case "$pattern" in
      ""|\#*) continue ;;
    esac

    report_history_matches \
      "local private denylist pattern exists in Git history: ${pattern}" \
      "$pattern"
  done < .public-denylist.local
fi

exit "$fail"
