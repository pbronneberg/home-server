#!/usr/bin/env bash
set -euo pipefail

node="${1:-${KAIROS_NODE:-}}"
if [ -z "$node" ]; then
  printf 'usage: %s <node>\n' "$0" >&2
  printf 'or: KAIROS_NODE=<node> make kairos-render-node\n' >&2
  exit 2
fi

inventory="${KAIROS_HARDWARE_NODES:-clusters/home/bootstrap/kairos/hardware/nodes.yaml}"
template="${KAIROS_HARDWARE_TEMPLATE:-clusters/home/bootstrap/kairos/hardware/user-data.agent.yaml}"
secrets_file="${KAIROS_BOOTSTRAP_SOPS_FILE:-private/flux/home/kairos-bootstrap-values.sops.yaml}"
out_dir="${KAIROS_RENDER_OUT_DIR:-.local/kairos}/${node}"
sops_bin="${SOPS:-sops}"
yq_bin="${YQ:-yq}"
sops_age_key_file="${SOPS_AGE_KEY_FILE:-.sops/age/keys.txt}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_command "$sops_bin"
require_command "$yq_bin"
require_command perl

if [ ! -f "$inventory" ]; then
  printf 'missing Kairos hardware inventory: %s\n' "$inventory" >&2
  exit 1
fi

if [ ! -f "$template" ]; then
  printf 'missing Kairos hardware template: %s\n' "$template" >&2
  exit 1
fi

if [ ! -f "$sops_age_key_file" ]; then
  printf 'missing SOPS age key: %s\n' "$sops_age_key_file" >&2
  exit 1
fi

node_value() {
  local expression="$1"
  KAIROS_NODE="$node" "$yq_bin" e -r ".nodes[strenv(KAIROS_NODE)]${expression}" "$inventory"
}

hostname="$(node_value '.hostname // ""')"
if [ -z "$hostname" ] || [ "$hostname" = "null" ]; then
  printf 'node %s is not defined in %s\n' "$node" "$inventory" >&2
  exit 1
fi

node_name="$(node_value '.nodeName // .hostname')"
install_device="$(node_value '.installDevice // ""')"
k3s_url="$(node_value '.k3sUrl // ""')"
ssh_github_user="$(node_value '.sshGithubUser // ""')"
data_disk_enabled="$(node_value '.dataDisk.enabled // false')"
data_disk_device=""
data_disk_label="kairos-data"
data_mount_point="/data"
data_longhorn_path=""

if [ -z "$install_device" ] || [ "$install_device" = "null" ]; then
  printf 'node %s is missing installDevice\n' "$node" >&2
  exit 1
fi

if [ -z "$k3s_url" ] || [ "$k3s_url" = "null" ]; then
  printf 'node %s is missing k3sUrl\n' "$node" >&2
  exit 1
fi

if [ -z "$ssh_github_user" ] || [ "$ssh_github_user" = "null" ]; then
  printf 'node %s is missing sshGithubUser\n' "$node" >&2
  exit 1
fi

if [ "$data_disk_enabled" = "true" ]; then
  data_disk_device="$(node_value '.dataDisk.device // ""')"
  data_disk_label="$(node_value '.dataDisk.fsLabel // "kairos-data"')"
  data_mount_point="$(node_value '.dataDisk.mountPoint // "/data"')"
  data_longhorn_path="$(node_value '.dataDisk.longhornPath // ""')"

  if [ -z "$data_disk_device" ] || [ "$data_disk_device" = "null" ]; then
    printf 'node %s enables dataDisk but does not set dataDisk.device\n' "$node" >&2
    exit 1
  fi
fi

k3s_token="$(
  SOPS_AGE_KEY_FILE="$sops_age_key_file" \
    "$sops_bin" --decrypt --extract '["stringData"]["KAIROS_K3S_TOKEN"]' "$secrets_file"
)"

if [ -z "$k3s_token" ]; then
  printf 'KAIROS_K3S_TOKEN is empty in %s\n' "$secrets_file" >&2
  exit 1
fi

mkdir -p "$out_dir/cidata"
chmod 700 "$out_dir" "$out_dir/cidata"

rendered="$out_dir/user-data"
cp "$template" "$rendered"
chmod 600 "$rendered"

replace_placeholder() {
  local key="$1"
  local value="$2"
  PLACEHOLDER="$key" REPLACEMENT="$value" perl -0pi -e '
    my $placeholder = $ENV{PLACEHOLDER};
    my $replacement = $ENV{REPLACEMENT};
    s/\{\{\s*\Q$placeholder\E\s*\}\}/$replacement/g;
  ' "$rendered"
}

replace_placeholder KAIROS_HOSTNAME "$hostname"
replace_placeholder KAIROS_INSTALL_DEVICE "$install_device"
replace_placeholder KAIROS_K3S_TOKEN "$k3s_token"
replace_placeholder KAIROS_K3S_URL "$k3s_url"
replace_placeholder KAIROS_NODE_NAME "$node_name"
replace_placeholder KAIROS_SSH_GITHUB_USER "$ssh_github_user"
replace_placeholder KAIROS_DATA_DISK_ENABLED "$data_disk_enabled"
replace_placeholder KAIROS_DATA_DISK_DEVICE "$data_disk_device"
replace_placeholder KAIROS_DATA_DISK_LABEL "$data_disk_label"
replace_placeholder KAIROS_DATA_MOUNT_POINT "$data_mount_point"
replace_placeholder KAIROS_DATA_LONGHORN_PATH "$data_longhorn_path"

if grep -q '{{ ' "$rendered"; then
  printf 'unrendered placeholders remain in %s\n' "$rendered" >&2
  grep '{{ ' "$rendered" >&2
  exit 1
fi

"$yq_bin" e '.' "$rendered" >/dev/null

cp "$rendered" "$out_dir/cidata/user-data"
chmod 600 "$out_dir/cidata/user-data"
printf 'instance-id: %s\nlocal-hostname: %s\n' "$node" "$hostname" > "$out_dir/cidata/meta-data"
chmod 600 "$out_dir/cidata/meta-data"

if [ "${KAIROS_BUILD_CIDATA:-true}" = "true" ]; then
  iso_tmp="$(mktemp -u "$out_dir/${node}-cidata.XXXXXX.iso")"
  iso_out="$out_dir/${node}-cidata.iso"

  if command -v hdiutil >/dev/null 2>&1; then
    hdiutil makehybrid -iso -joliet -default-volume-name cidata -o "$iso_tmp" "$out_dir/cidata" >/dev/null
  elif command -v xorriso >/dev/null 2>&1; then
    xorriso -as mkisofs -volid cidata -joliet -output "$iso_tmp" "$out_dir/cidata" >/dev/null
  elif command -v genisoimage >/dev/null 2>&1; then
    genisoimage -volid cidata -joliet -output "$iso_tmp" "$out_dir/cidata" >/dev/null
  elif command -v mkisofs >/dev/null 2>&1; then
    mkisofs -volid cidata -joliet -output "$iso_tmp" "$out_dir/cidata" >/dev/null
  else
    printf 'rendered %s, but no ISO creation tool was found\n' "$rendered" >&2
    printf 'install hdiutil, xorriso, genisoimage, or mkisofs to build cidata ISO\n' >&2
    exit 1
  fi

  mv "$iso_tmp" "$iso_out"
  chmod 600 "$iso_out"
  printf 'rendered %s and %s\n' "$rendered" "$iso_out"
else
  printf 'rendered %s\n' "$rendered"
fi
