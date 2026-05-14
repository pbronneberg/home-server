#!/usr/bin/env bash
set -euo pipefail

command="${1:-help}"
root="${SOPS_PRIVATE_ROOT:-private}"
out_dir="${SOPS_OUT_DIR:-private-decrypted}"
sops_bin="${SOPS:-sops}"
age_key="${SOPS_AGE_KEY_FILE:-.sops/age/keys.txt}"

usage() {
  cat <<'USAGE'
Usage: scripts/sops-private.sh <command>

Commands:
  list         List SOPS-encrypted private files.
  decrypt     Decrypt SOPS_FILE to stdout.
  decrypt-dir Decrypt all private SOPS files into SOPS_OUT_DIR.

Environment:
  SOPS_FILE            File to decrypt with the decrypt command.
  SOPS_PRIVATE_ROOT    Root to scan for *.sops.yaml files. Default: private.
  SOPS_OUT_DIR         Output directory for decrypt-dir. Default: private-decrypted.
  SOPS_AGE_KEY_FILE    Age identity file. Default: .sops/age/keys.txt.
USAGE
}

require_key() {
  if [ ! -f "$age_key" ]; then
    printf 'Missing SOPS age key: %s\n' "$age_key" >&2
    printf 'Create or restore it before decrypting private overlays.\n' >&2
    exit 1
  fi
}

list_files() {
  find "$root" -type f \( -name '*.sops.yaml' -o -name '*.sops.yml' \) | sort
}

case "$command" in
  help|-h|--help)
    usage
    ;;
  list)
    list_files
    ;;
  decrypt)
    require_key
    file="${SOPS_FILE:-}"
    if [ -z "$file" ]; then
      printf 'Set SOPS_FILE to decrypt a specific file.\n' >&2
      exit 1
    fi
    SOPS_AGE_KEY_FILE="$age_key" "$sops_bin" decrypt "$file"
    ;;
  decrypt-dir)
    require_key
    umask 077
    mkdir -p "$out_dir"
    list_files | while IFS= read -r file; do
      relative="${file#"$root"/}"
      output="$out_dir/$relative"
      case "$output" in
        *.sops.yaml) output="${output%.sops.yaml}.decrypted.yaml" ;;
        *.sops.yml) output="${output%.sops.yml}.decrypted.yml" ;;
      esac
      mkdir -p "$(dirname "$output")"
      printf 'Decrypting %s -> %s\n' "$file" "$output" >&2
      SOPS_AGE_KEY_FILE="$age_key" "$sops_bin" decrypt "$file" > "$output"
    done
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$command" >&2
    usage >&2
    exit 1
    ;;
esac
