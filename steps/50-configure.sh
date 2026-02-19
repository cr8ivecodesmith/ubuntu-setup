#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/config.sh"
source "${ROOT_DIR}/lib/chroot.sh"

export CURRENT_STEP="50-configure.sh"

SENTINEL="${STATE_DIR}/50-configure.done"

if [[ -f "$SENTINEL" ]]; then
  log_info "System identity already configured; skipping."
  exit 0
fi

if [[ "${DRY_RUN:-false}" == true ]]; then
  log_info "DRY-RUN: would configure hostname, timezone, locale, and user in /mnt."
  exit 0
fi

setup_chroot_mounts /mnt

log_info "Configuring hostname and hosts"
run_or_echo bash -c "echo '${HOSTNAME}' > /mnt/etc/hostname"
run_or_echo bash -c "grep -q '127.0.1.1' /mnt/etc/hosts || echo '127.0.1.1 ${HOSTNAME}' >> /mnt/etc/hosts"

log_info "Configuring timezone ${TIMEZONE}"
run_or_echo ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /mnt/etc/localtime
run_or_echo bash -c "echo '${TIMEZONE}' > /mnt/etc/timezone"
run_or_echo chroot /mnt dpkg-reconfigure -f noninteractive tzdata

LOCALE_VALUE="${LOCALE:-en_US.UTF-8}"
log_info "Configuring locale ${LOCALE_VALUE}"
run_or_echo chroot /mnt bash -c "echo '${LOCALE_VALUE} UTF-8' >> /etc/locale.gen && locale-gen"
run_or_echo chroot /mnt update-locale "LANG=${LOCALE_VALUE}"

log_info "Creating user ${USERNAME}"
create_user() {
  if [[ -n "${USER_PASSWORD_HASH:-}" ]]; then
    chroot /mnt useradd -m -s /bin/bash -G sudo "${USERNAME}" -p "${USER_PASSWORD_HASH}"
    return
  fi
  local pw
  if [[ -n "${USER_PASSWORD:-}" ]]; then
    pw="${USER_PASSWORD}"
  else
    read -r -s -p "Enter password for user ${USERNAME}: " pw
    echo
    read -r -s -p "Confirm password for user ${USERNAME}: " pw2
    echo
    if [[ "$pw" != "$pw2" ]]; then
      log_fatal "User passwords do not match."
    fi
  fi
  echo "${USERNAME}:${pw}" | chroot /mnt chpasswd
  chroot /mnt usermod -aG sudo "${USERNAME}"
}

create_user

log_info "Enabling systemd-timesyncd (best-effort)"
run_or_echo chroot /mnt bash -c "systemctl enable systemd-timesyncd.service || true"

run_or_echo touch "$SENTINEL"
