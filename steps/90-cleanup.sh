#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/chroot.sh"
source "${ROOT_DIR}/lib/disk.sh"

export CURRENT_STEP="90-cleanup.sh"

SENTINEL="${STATE_DIR}/90-cleanup.done"

if [[ -f "$SENTINEL" ]]; then
  log_info "Cleanup already completed; skipping."
  exit 0
fi

log_info "Copying logs and config into recovery partition"
TIMESTAMP="$(date +%Y%m%d-%H%M)"
run_or_echo mkdir -p /mnt/recovery/install-logs
if [[ -f "${LOG_FILE_LIVE}" ]]; then
  run_or_echo cp "${LOG_FILE_LIVE}" "/mnt/recovery/install-logs/${TIMESTAMP}.log"
fi
run_or_echo mkdir -p /mnt/recovery/install-config
if [[ -f "${ROOT_DIR}/config/default.env" ]]; then
  run_or_echo cp "${ROOT_DIR}/config/default.env" /mnt/recovery/install-config/default.env
fi
if [[ -f "${ROOT_DIR}/config/user.env" ]]; then
  run_or_echo cp "${ROOT_DIR}/config/user.env" /mnt/recovery/install-config/user.env
fi

log_info "Tearing down chroot mounts"
teardown_chroot_mounts /mnt

log_info "Closing LUKS mapping and unmounting filesystems"
# shellcheck source=/dev/null
if [[ -f "${STATE_DIR}/luks.env" ]]; then
  source "${STATE_DIR}/luks.env"
fi

for mp in /mnt/recovery /mnt/boot/efi /mnt/boot /mnt/home /mnt; do
  if mountpoint -q "$mp"; then
    run_or_echo umount "$mp"
  fi
done

if [[ -n "${LUKS_MAPPER:-}" && -b "${LUKS_MAPPER}" ]]; then
  run_or_echo cryptsetup close "${LUKS_NAME}"
fi

run_or_echo touch "$SENTINEL"

log_info "Installation complete. You can reboot and remove the live media."
