#!/usr/bin/env bash
set -euo pipefail

nodes=("$@")
if [ "${#nodes[@]}" -eq 0 ]; then
  nodes=(marvin milliard)
fi

sops_bin="${SOPS:-sops}"
sops_age_key_file="${SOPS_AGE_KEY_FILE:-.sops/age/keys.txt}"
secret_file="${HOMELAB_AUTOSCALER_NODES_SOPS_FILE:-private/flux/home/homelab-autoscaler-nodes.sops.yaml}"
ssh_source_user="${AUTOSCALER_BOOTSTRAP_SSH_USER:-kairos}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$1" >&2
    exit 1
  fi
}

require_command "$sops_bin"
require_command ssh
require_command scp
require_command ssh-keyscan

if [ ! -f "$sops_age_key_file" ]; then
  printf 'missing SOPS age key: %s\n' "$sops_age_key_file" >&2
  exit 1
fi

if [ ! -f "$secret_file" ]; then
  printf 'missing autoscaler node secret: %s\n' "$secret_file" >&2
  exit 1
fi

workdir="$(mktemp -d /private/tmp/autoscaler-bootstrap.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

public_key_file="$workdir/shutdown_id_ed25519.pub"
private_key_file="$workdir/shutdown_id_ed25519"
remote_script="$workdir/bootstrap-autoscaler-shutdown.sh"

SOPS_AGE_KEY_FILE="$sops_age_key_file" \
  "$sops_bin" --decrypt --extract '["stringData"]["ssh_public_key"]' "$secret_file" > "$public_key_file"
SOPS_AGE_KEY_FILE="$sops_age_key_file" \
  "$sops_bin" --decrypt --extract '["stringData"]["ssh_private_key"]' "$secret_file" > "$private_key_file"
chmod 0600 "$private_key_file"

cat > "$remote_script" <<'REMOTE'
#!/bin/sh
set -eu

user=autoscaler-shutdown

if ! id "$user" >/dev/null 2>&1; then
  if command -v useradd >/dev/null 2>&1; then
    useradd -m -s /bin/sh "$user"
  elif command -v adduser >/dev/null 2>&1; then
    adduser -D -s /bin/sh "$user" || adduser -S -h "/home/$user" -s /bin/sh "$user"
  else
    echo "no useradd/adduser available" >&2
    exit 1
  fi
fi

home="$(awk -F: -v u="$user" '$1 == u { print $6 }' /etc/passwd)"
if [ -z "$home" ]; then
  echo "could not determine home for $user" >&2
  exit 1
fi

group="$(id -gn "$user")"
install -d -m 0700 -o "$user" -g "$group" "$home/.ssh"
install -m 0600 -o "$user" -g "$group" /tmp/autoscaler-shutdown.pub "$home/.ssh/authorized_keys"

cat > /etc/sudoers.d/autoscaler-shutdown <<'EOF'
autoscaler-shutdown ALL=(root) NOPASSWD: /sbin/poweroff, /usr/sbin/poweroff, /usr/bin/systemctl poweroff, /bin/systemctl poweroff
EOF

chmod 0440 /etc/sudoers.d/autoscaler-shutdown
if command -v visudo >/dev/null 2>&1; then
  visudo -cf /etc/sudoers.d/autoscaler-shutdown >/dev/null
fi

rm -f /tmp/autoscaler-shutdown.pub /tmp/bootstrap-autoscaler-shutdown.sh
REMOTE
chmod 0700 "$remote_script"

for node in "${nodes[@]}"; do
  known_hosts="$workdir/${node}.known_hosts"
  ssh-keyscan -T 5 -t ed25519 "$node" 2>/dev/null > "$known_hosts"
  if [ ! -s "$known_hosts" ]; then
    printf 'failed to scan SSH host key for %s\n' "$node" >&2
    exit 1
  fi

  scp -q \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    "$public_key_file" "$ssh_source_user@$node:/tmp/autoscaler-shutdown.pub"
  scp -q \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    "$remote_script" "$ssh_source_user@$node:/tmp/bootstrap-autoscaler-shutdown.sh"
  ssh \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    "$ssh_source_user@$node" 'sudo /bin/sh /tmp/bootstrap-autoscaler-shutdown.sh'

  printf '%s bootstrapped\n' "$node"

  ssh \
    -i "$private_key_file" \
    -o BatchMode=yes \
    -o ConnectTimeout=5 \
    -o UserKnownHostsFile="$known_hosts" \
    -o StrictHostKeyChecking=yes \
    "autoscaler-shutdown@$node" 'id -un && sudo -n -l /sbin/poweroff >/dev/null && echo sudo-poweroff-listed'
done
