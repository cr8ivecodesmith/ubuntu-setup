#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

get_part_prefix() {
  if [[ "$TARGET_DISK" == *nvme* || "$TARGET_DISK" == *mmcblk* ]]; then
    echo "${TARGET_DISK}p"
  else
    echo "${TARGET_DISK}"
  fi
}

partition_disk() {
  log_info "Partitioning disk ${TARGET_DISK}"
  run_or_echo parted -s "$TARGET_DISK" mklabel gpt
  local esp_start=1
  local esp_end=$((esp_start + ESP_SIZE_MIB))
  local boot_end=$((esp_end + BOOT_SIZE_MIB))
  local rec_end=$((boot_end + RECOVERY_SIZE_MIB))
  run_or_echo parted -s "$TARGET_DISK" mkpart ESP fat32 "${esp_start}MiB" "${esp_end}MiB"
  run_or_echo parted -s "$TARGET_DISK" set 1 esp on
  run_or_echo parted -s "$TARGET_DISK" mkpart BOOT ext4 "${esp_end}MiB" "${boot_end}MiB"
  run_or_echo parted -s "$TARGET_DISK" mkpart RECOVERY ext4 "${boot_end}MiB" "${rec_end}MiB"
  run_or_echo parted -s "$TARGET_DISK" mkpart CRYPTROOT ext4 "${rec_end}MiB" 100%

  local prefix
  prefix="$(get_part_prefix)"
  ESP_PART="${prefix}1"
  BOOT_PART="${prefix}2"
  RECOVERY_PART="${prefix}3"
  CRYPTROOT_PART="${prefix}4"

  cat >"${STATE_DIR}/partitions.env" <<EOF
ESP_PART="$ESP_PART"
BOOT_PART="$BOOT_PART"
RECOVERY_PART="$RECOVERY_PART"
CRYPTROOT_PART="$CRYPTROOT_PART"
EOF
}

format_partitions() {
  # shellcheck source=/dev/null
  source "${STATE_DIR}/partitions.env"
  log_info "Formatting partitions"
  run_or_echo mkfs.fat -F32 "$ESP_PART"
  run_or_echo mkfs.ext4 -F "$BOOT_PART"
  run_or_echo mkfs.ext4 -F "$RECOVERY_PART"
}

get_partition_uuids() {
  # shellcheck source=/dev/null
  source "${STATE_DIR}/partitions.env"
  ESP_UUID="$(blkid -s UUID -o value "$ESP_PART")"
  BOOT_UUID="$(blkid -s UUID -o value "$BOOT_PART")"
  RECOVERY_UUID="$(blkid -s UUID -o value "$RECOVERY_PART")"
  CRYPTROOT_UUID="$(blkid -s UUID -o value "$CRYPTROOT_PART")"
}
