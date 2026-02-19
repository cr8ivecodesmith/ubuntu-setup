#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/disk.sh"
source "${ROOT_DIR}/lib/config.sh"

export CURRENT_STEP="30-mount.sh"

SENTINEL="${STATE_DIR}/30-mount.done"

if [[ -f "$SENTINEL" ]]; then
  log_info "Mounts already completed; skipping."
  exit 0
fi

# shellcheck source=/dev/null
source "${STATE_DIR}/partitions.env"
# shellcheck source=/dev/null
source "${STATE_DIR}/luks.env"

run_or_echo mkdir -p /mnt
run_or_echo mount -o "${BTRFS_MOUNT_OPTS},subvol=@" "$LUKS_MAPPER" /mnt
run_or_echo mkdir -p /mnt/home
run_or_echo mount -o "${BTRFS_MOUNT_OPTS},subvol=@home" "$LUKS_MAPPER" /mnt/home
run_or_echo mkdir -p /mnt/boot/efi /mnt/recovery
run_or_echo mount "$BOOT_PART" /mnt/boot
run_or_echo mount "$ESP_PART" /mnt/boot/efi
run_or_echo mount "$RECOVERY_PART" /mnt/recovery

run_or_echo touch "$SENTINEL"
