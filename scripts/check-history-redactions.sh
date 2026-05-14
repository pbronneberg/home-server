#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

fail=0

report_history_matches() {
  local description="$1"
  local pattern="$2"
  local matches

  matches="$(git log --all --format='%h %s' -G "$pattern" -- . || true)"

  if [ -n "$matches" ]; then
    printf '%s\n' "$matches"
    printf '\nHistory public-readiness check failed: %s\n\n' "$description" >&2
    fail=1
  fi
}

report_history_matches \
  "private RFC1918 network ranges exist in Git history" \
  '(^|[^0-9])(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)'

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
