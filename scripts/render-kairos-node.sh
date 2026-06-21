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
autoscaler_nodes_file="${HOMELAB_AUTOSCALER_NODES_SOPS_FILE:-private/flux/home/homelab-autoscaler-nodes.sops.yaml}"
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
data_mount_point="$(node_value '.dataDisk.mountPoint // "/usr/local/data"')"
data_longhorn_path="$(node_value '.dataDisk.longhornPath // ""')"
data_local_path="$(node_value '.dataDisk.localPath // ""')"
wake_on_lan_enabled="$(node_value '.wakeOnLan.enabled // false')"
enable_wake_on_lan_network_stage=""
autoscaler_shutdown_public_key=""
autoscaler_shutdown_user_block=""
autoscaler_shutdown_boot_stage=""
k3s_args="$(
  printf '    - "--node-name=%s"\n' "$node_name"
  KAIROS_NODE="$node" "$yq_bin" e -r '
    [
      (.nodes[strenv(KAIROS_NODE)].nodeLabels // {} | to_entries[] | "--node-label=" + .key + "=" + (.value | tostring)),
      (.nodes[strenv(KAIROS_NODE)].nodeTaints // [] | .[] | "--node-taint=" + .key + "=" + ((.value // "") | tostring) + ":" + .effect)
    ] | .[]
  ' "$inventory" | while IFS= read -r arg; do
    [ -n "$arg" ] || continue
    printf '    - "%s"\n' "$arg"
  done
  printf '    - "--kubelet-arg=anonymous-auth=false"\n'
  printf '    - "--kubelet-arg=read-only-port=0"\n'
)"

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

  if [ -z "$data_disk_device" ] || [ "$data_disk_device" = "null" ]; then
    printf 'node %s enables dataDisk but does not set dataDisk.device\n' "$node" >&2
    exit 1
  fi
fi

if [ "$wake_on_lan_enabled" = "true" ]; then
  enable_wake_on_lan_network_stage="$(
    printf '    - name: Enable Wake-on-LAN with systemd-networkd\n'
    printf '      commands:\n'
    printf '        - |\n'
    printf '          set -eu\n'
    printf '          mkdir -p /etc/systemd/network\n'
    printf '          cat > /etc/systemd/network/20-kairos-wake-on-lan.link <<'"'"'EOF'"'"'\n'
    printf '          [Match]\n'
    printf '          OriginalName=en* eth*\n'
    printf '\n'
    printf '          [Link]\n'
    printf '          WakeOnLan=magic\n'
    printf '          EOF\n'
    printf '\n'
    printf '          if ! command -v networkctl >/dev/null 2>&1; then\n'
    printf '            echo "warning: networkctl not available; Wake-on-LAN link config written only" >&2\n'
    printf '            exit 0\n'
    printf '          fi\n'
    printf '\n'
    printf '          udevadm control --reload || true\n'
    printf '          udevadm trigger --subsystem-match=net --action=add || true\n'
    printf '\n'
    printf '          networkctl reload || true\n'
    printf '          networkctl list --no-legend --no-pager | awk '"'"'$2 != "lo" && $3 == "ether" { print $2 }'"'"' | while IFS= read -r link; do\n'
    printf '            [ -n "$link" ] || continue\n'
    printf '            networkctl reconfigure "$link" || true\n'
    printf '            networkctl status "$link" --no-pager | grep -F "Wake On LAN:" || true\n'
    printf '          done\n'
  )"
fi

k3s_token="$(
  SOPS_AGE_KEY_FILE="$sops_age_key_file" \
    "$sops_bin" --decrypt --extract '["stringData"]["KAIROS_K3S_TOKEN"]' "$secrets_file"
)"

if [ -z "$k3s_token" ]; then
  printf 'KAIROS_K3S_TOKEN is empty in %s\n' "$secrets_file" >&2
  exit 1
fi

if [ -f "$autoscaler_nodes_file" ]; then
  autoscaler_shutdown_public_key="$(
    SOPS_AGE_KEY_FILE="$sops_age_key_file" \
      "$sops_bin" --decrypt --extract '["stringData"]["ssh_public_key"]' "$autoscaler_nodes_file" 2>/dev/null || true
  )"
  autoscaler_shutdown_public_key="${autoscaler_shutdown_public_key//$'\r'/}"
fi

if [ -n "$autoscaler_shutdown_public_key" ] && [ "$autoscaler_shutdown_public_key" != "null" ]; then
  autoscaler_shutdown_user_block="$(
    printf '  - name: autoscaler-shutdown\n'
    printf '    lock_passwd: true\n'
    printf '    shell: /bin/sh\n'
    printf '    ssh_authorized_keys:\n'
    printf '      - %s\n' "$autoscaler_shutdown_public_key"
  )"
  autoscaler_shutdown_boot_stage="$(
    printf '    - name: Configure autoscaler shutdown user\n'
    printf '      commands:\n'
    printf '        - |\n'
    printf '          set -eu\n'
    printf '          cat > /etc/sudoers.d/autoscaler-shutdown <<'"'"'EOF'"'"'\n'
    printf '          autoscaler-shutdown ALL=(root) NOPASSWD: /sbin/poweroff, /usr/sbin/poweroff, /usr/bin/systemctl poweroff, /bin/systemctl poweroff\n'
    printf '          EOF\n'
    printf '          chmod 0440 /etc/sudoers.d/autoscaler-shutdown\n'
  )"
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

replace_line_placeholder() {
  local key="$1"
  local value="$2"
  PLACEHOLDER="$key" REPLACEMENT="$value" perl -0pi -e '
    my $placeholder = $ENV{PLACEHOLDER};
    my $replacement = $ENV{REPLACEMENT};
    s/^[ \t]*\#\s*\Q$placeholder\E\s*$/$replacement/mg;
  ' "$rendered"
}

replace_placeholder KAIROS_HOSTNAME "$hostname"
replace_placeholder KAIROS_INSTALL_DEVICE "$install_device"
replace_placeholder KAIROS_K3S_TOKEN "$k3s_token"
replace_placeholder KAIROS_K3S_URL "$k3s_url"
replace_placeholder KAIROS_NODE_NAME "$node_name"
replace_placeholder KAIROS_SSH_GITHUB_USER "$ssh_github_user"
replace_line_placeholder KAIROS_AUTOSCALER_SHUTDOWN_USER "$autoscaler_shutdown_user_block"
replace_line_placeholder KAIROS_AUTOSCALER_SHUTDOWN_BOOT_STAGE "$autoscaler_shutdown_boot_stage"
replace_line_placeholder KAIROS_WAKE_ON_LAN_NETWORK_STAGE "$enable_wake_on_lan_network_stage"
replace_line_placeholder KAIROS_K3S_ARGS "$k3s_args"
replace_placeholder KAIROS_DATA_DISK_ENABLED "$data_disk_enabled"
replace_placeholder KAIROS_DATA_DISK_DEVICE "$data_disk_device"
replace_placeholder KAIROS_DATA_DISK_LABEL "$data_disk_label"
replace_placeholder KAIROS_DATA_MOUNT_POINT "$data_mount_point"
replace_placeholder KAIROS_DATA_LONGHORN_PATH "$data_longhorn_path"
replace_placeholder KAIROS_DATA_LOCAL_PATH "$data_local_path"

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
