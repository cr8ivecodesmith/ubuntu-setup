#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/config.sh"
source "${ROOT_DIR}/lib/disk.sh"
source "${ROOT_DIR}/lib/chroot.sh"

export CURRENT_STEP="60-grub.sh"

SENTINEL="${STATE_DIR}/60-grub.done"

if [[ -f "$SENTINEL" ]]; then
  log_info "Boot configuration already completed; skipping."
  exit 0
fi

if [[ "${DRY_RUN:-false}" == true ]]; then
  log_info "DRY-RUN: would configure fstab, crypttab, initramfs, GRUB, and recovery menu entry."
  exit 0
fi

# shellcheck source=/dev/null
source "${STATE_DIR}/partitions.env"
# shellcheck source=/dev/null
source "${STATE_DIR}/luks.env"

get_partition_uuids
ROOTFS_UUID="$(blkid -s UUID -o value "${LUKS_MAPPER}")"

log_info "Writing /etc/fstab and /etc/crypttab"

cat > /mnt/etc/fstab <<EOF
UUID=${ROOTFS_UUID} / btrfs ${BTRFS_MOUNT_OPTS},subvol=@ 0 1
UUID=${ROOTFS_UUID} /home btrfs ${BTRFS_MOUNT_OPTS},subvol=@home 0 2
UUID=${BOOT_UUID} /boot ext4 defaults 0 2
UUID=${ESP_UUID} /boot/efi vfat umask=0077 0 1
UUID=${RECOVERY_UUID} /recovery ext4 defaults 0 2
EOF

CRYPTROOT_UUID="${CRYPTROOT_UUID}"
cat > /mnt/etc/crypttab <<EOF
${LUKS_NAME} UUID=${CRYPTROOT_UUID} none luks
EOF

if (( SWAPFILE_GIB > 0 )); then
  log_info "Creating swapfile of ${SWAPFILE_GIB} GiB on BTRFS (simple configuration; no hibernate)."
  run_or_echo chroot /mnt bash -c "mkdir -p /swap && chattr +C /swap || true"
  run_or_echo chroot /mnt fallocate -l "${SWAPFILE_GIB}G" /swap/swapfile
  run_or_echo chroot /mnt chmod 600 /swap/swapfile
  run_or_echo chroot /mnt mkswap /swap/swapfile
  cat >> /mnt/etc/fstab <<EOF2
/swap/swapfile none swap sw 0 0
EOF2
fi

setup_chroot_mounts /mnt

log_info "Updating initramfs"
run_or_echo chroot /mnt update-initramfs -u -k all

log_info "Installing GRUB to ESP"
BOOTLOADER_ID="${BOOTLOADER_ID:-ubuntu}"
run_or_echo chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="${BOOTLOADER_ID}"

log_info "Installing recovery GRUB script"
get_partition_uuids
RECOVERY_UUID_VALUE="${RECOVERY_UUID}"
mkdir -p /mnt/etc/grub.d
sed "s/@RECOVERY_UUID@/${RECOVERY_UUID_VALUE}/g" "${ROOT_DIR}/assets/grub/06_recovery_iso" > /mnt/etc/grub.d/06_recovery_iso
chmod +x /mnt/etc/grub.d/06_recovery_iso

log_info "Running update-grub"
run_or_echo chroot /mnt update-grub

run_or_echo touch "$SENTINEL"
