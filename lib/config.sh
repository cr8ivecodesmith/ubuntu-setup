#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_config() {
  local config_path="$1"
  local profile="$2"

  # shellcheck source=/dev/null
  source "${ROOT_DIR}/config/default.env"

  if [[ -n "$config_path" && -f "$config_path" ]]; then
    # shellcheck source=/dev/null
    source "$config_path"
  fi

  if [[ -n "$profile" ]]; then
    case "$profile" in
      noble-desktop)
        UBUNTU_RELEASE="noble"
        DESKTOP_PACKAGES="ubuntu-desktop"
        ;;
      *)
        ;;
    esac
  fi

  validate_required_env
}

validate_required_env() {
  local missing=()
  for var in TARGET_DISK UBUNTU_RELEASE UBUNTU_MIRROR HOSTNAME USERNAME TIMEZONE ESP_SIZE_MIB BOOT_SIZE_MIB RECOVERY_SIZE_MIB LUKS_NAME BTRFS_LABEL BTRFS_MOUNT_OPTS RECOVERY_ISO_PATH; do
    if [[ -z "${!var-}" ]]; then
      missing+=("$var")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_fatal "Missing required env vars: ${missing[*]}"
  fi
}

print_config_summary() {
  log_info "Configuration summary:"
  log_info "  TARGET_DISK=${TARGET_DISK}"
  log_info "  UBUNTU_RELEASE=${UBUNTU_RELEASE}"
  log_info "  UBUNTU_MIRROR=${UBUNTU_MIRROR}"
  log_info "  HOSTNAME=${HOSTNAME}"
  log_info "  USERNAME=${USERNAME}"
  log_info "  TIMEZONE=${TIMEZONE}"
  log_info "  ESP_SIZE_MIB=${ESP_SIZE_MIB}"
  log_info "  BOOT_SIZE_MIB=${BOOT_SIZE_MIB}"
  log_info "  RECOVERY_SIZE_MIB=${RECOVERY_SIZE_MIB}"
  log_info "  LUKS_NAME=${LUKS_NAME}"
  log_info "  BTRFS_LABEL=${BTRFS_LABEL}"
  log_info "  RECOVERY_ISO_PATH=${RECOVERY_ISO_PATH}"
}
