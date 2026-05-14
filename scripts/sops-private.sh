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
  drill        Validate restored age key, Flux SOPS secret shape, and private overlay rendering.

Environment:
  KUBECTL              kubectl-compatible binary. Default: kubectl.
  KUSTOMIZE           kustomize binary. Used before KUBECTL kustomize when available.
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

build_kustomization() {
  dir="$1"
  kustomize_bin="${KUSTOMIZE:-kustomize}"
  kubectl_bin="${KUBECTL:-kubectl}"

  if command -v "$kustomize_bin" >/dev/null 2>&1; then
    "$kustomize_bin" build "$dir" >/dev/null
  else
    "$kubectl_bin" kustomize "$dir" >/dev/null
  fi
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
  drill)
    require_key
    kubectl_bin="${KUBECTL:-kubectl}"
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT

    printf '%s\n' 'Checking Flux SOPS age secret can be recreated from the restored key.'
    "$kubectl_bin" create namespace flux-system --dry-run=client -o yaml >/dev/null
    "$kubectl_bin" create secret generic sops-age \
      -n flux-system \
      --from-file=age.agekey="$age_key" \
      --dry-run=client \
      -o yaml >/dev/null

    printf '%s\n' 'Decrypting private SOPS overlays into an isolated temporary directory.'
    list_files | while IFS= read -r file; do
      output="$tmp_dir/$file"
      mkdir -p "$(dirname "$output")"
      SOPS_AGE_KEY_FILE="$age_key" "$sops_bin" decrypt "$file" > "$output"
    done

    if [ -f "$root/flux/home/kustomization.yaml" ]; then
      mkdir -p "$tmp_dir/$root/flux/home"
      cp "$root/flux/home/kustomization.yaml" "$tmp_dir/$root/flux/home/kustomization.yaml"
      printf '%s\n' 'Rendering decrypted private Flux overlay.'
      build_kustomization "$tmp_dir/$root/flux/home"
    fi

    printf '%s\n' 'SOPS recovery drill passed.'
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$command" >&2
    usage >&2
    exit 1
    ;;
esac
