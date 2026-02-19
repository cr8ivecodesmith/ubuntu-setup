#!/usr/bin/env bash
set -euo pipefail

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    log_fatal "This installer must be run as root."
  fi
}

ensure_uefi() {
  if [[ ! -d /sys/firmware/efi ]]; then
    log_fatal "System is not booted in UEFI mode."
  fi
}

ensure_not_live_disk() {
  local live_device
  live_device="$(findmnt -n -o SOURCE /)"
  if [[ -n "$live_device" && "$TARGET_DISK" == "$live_device"* ]]; then
    log_fatal "TARGET_DISK appears to be the live system device ($live_device)."
  fi
}

ensure_disk_unused() {
  if findmnt -rn -S "$TARGET_DISK" >/dev/null 2>&1; then
    log_fatal "TARGET_DISK is currently in use."
  fi
}

ensure_tools_available() {
  local tools=(parted cryptsetup mkfs.fat mkfs.ext4 btrfs-progs blkid)
  local missing=()
  for t in "${tools[@]}"; do
    if ! command -v "$t" >/dev/null 2>&1; then
      missing+=("$t")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    log_info "Installing missing tools: ${missing[*]}"
    if ! run_or_echo apt-get update; then
      log_fatal "Failed to run apt-get update."
    fi
    if ! run_or_echo apt-get install -y "${missing[@]}" debootstrap mmdebstrap arch-install-scripts grub-efi-amd64 shim-signed; then
      log_fatal "Failed to install required tools."
    fi
  fi
}

ensure_internet() {
  if [[ "${SKIP_INTERNET_CHECK:-false}" == true ]]; then
    log_info "Skipping internet connectivity check."
    return
  fi
  if ! ping -c1 -W2 archive.ubuntu.com >/dev/null 2>&1; then
    log_fatal "Internet connectivity check failed. Use --skip-internet-check to bypass."
  fi
}
