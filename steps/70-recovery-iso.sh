#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/config.sh"

export CURRENT_STEP="70-recovery-iso.sh"

SENTINEL="${STATE_DIR}/70-recovery-iso.done"

if [[ -f "$SENTINEL" ]]; then
  log_info "Recovery ISO already installed; skipping."
  exit 0
fi

if [[ "${DRY_RUN:-false}" == true ]]; then
  log_info "DRY-RUN: would download and install recovery ISO at ${RECOVERY_ISO_PATH} in target system."
  exit 0
fi

if [[ -z "${RECOVERY_ISO_URL}" ]]; then
  log_fatal "RECOVERY_ISO_URL is not set."
fi

TARGET_ROOT="/mnt"
FINAL_PATH="${TARGET_ROOT}${RECOVERY_ISO_PATH}"
FINAL_DIR="$(dirname "${FINAL_PATH}")"
TMP_PATH="${FINAL_DIR}/.ubuntu-recovery.iso.new"
BAK_PATH="${FINAL_PATH}.bak"

run_or_echo mkdir -p "${FINAL_DIR}"

log_info "Downloading recovery ISO from ${RECOVERY_ISO_URL}"
run_or_echo curl -fL "${RECOVERY_ISO_URL}" -o "${TMP_PATH}"

if [[ "${SKIP_ISO_VERIFY:-false}" != true ]]; then
  if [[ -z "${RECOVERY_ISO_SHA256}" ]]; then
    log_fatal "RECOVERY_ISO_SHA256 must be set unless --skip-iso-verify is used."
  fi
  log_info "Verifying recovery ISO checksum"
  echo "${RECOVERY_ISO_SHA256}  ${TMP_PATH}" | sha256sum --check -
fi

if [[ -f "${FINAL_PATH}" ]]; then
  run_or_echo mv "${FINAL_PATH}" "${BAK_PATH}"
fi
run_or_echo mv "${TMP_PATH}" "${FINAL_PATH}"

# Install update-recovery-iso script into target
run_or_echo mkdir -p "${TARGET_ROOT}/usr/local/sbin"
run_or_echo install -m 0755 "${ROOT_DIR}/assets/update-recovery-iso" "${TARGET_ROOT}/usr/local/sbin/update-recovery-iso"

# Write config file for update-recovery-iso inside target
run_or_echo mkdir -p "${TARGET_ROOT}/etc"
cat > "${TARGET_ROOT}/etc/ubuntu-recovery.conf" <<EOF
RECOVERY_ISO_URL="${RECOVERY_ISO_URL}"
RECOVERY_ISO_SHA256="${RECOVERY_ISO_SHA256}"
RECOVERY_ISO_PATH="${RECOVERY_ISO_PATH}"
EOF

# Install systemd service and timer (disabled by default unless ENABLE_TIMER=true)
run_or_echo mkdir -p "${TARGET_ROOT}/etc/systemd/system"
run_or_echo install -m 0644 "${ROOT_DIR}/assets/systemd/update-recovery-iso.service" "${TARGET_ROOT}/etc/systemd/system/update-recovery-iso.service"
run_or_echo install -m 0644 "${ROOT_DIR}/assets/systemd/update-recovery-iso.timer" "${TARGET_ROOT}/etc/systemd/system/update-recovery-iso.timer"

if [[ "${ENABLE_TIMER}" == true ]]; then
  run_or_echo chroot "${TARGET_ROOT}" bash -c "systemctl enable update-recovery-iso.timer || true"
fi

run_or_echo touch "$SENTINEL"
