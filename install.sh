#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CURRENT_STEP="install"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/config.sh"
source "${ROOT_DIR}/lib/checks.sh"
source "${ROOT_DIR}/lib/disk.sh"
source "${ROOT_DIR}/lib/chroot.sh"

DRY_RUN=false
CONFIG_PATH="${ROOT_DIR}/config/user.env"
PROFILE=""
LUKS_PASSPHRASE_SOURCE=""
LUKS_PASSPHRASE_FILE=""
SKIP_INTERNET_CHECK=false
SKIP_ISO_VERIFY=false

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --disk DEVICE                 Target disk (e.g. /dev/nvme0n1)
  --profile NAME                Profile (e.g. noble-desktop)
  --luks-passphrase-stdin       Read LUKS passphrase from stdin
  --luks-passphrase-file PATH   Read LUKS passphrase from file
  --dry-run                     Print actions without modifying disk
  --config PATH                 Path to user config env file
  --skip-internet-check         Do not fail if internet is unreachable
  --skip-iso-verify             Skip SHA256 verification for recovery ISO
  -h, --help                    Show this help
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --disk)
        TARGET_DISK="$2"
        export TARGET_DISK
        shift 2
        ;;
      --profile)
        PROFILE="$2"
        shift 2
        ;;
      --luks-passphrase-stdin)
        LUKS_PASSPHRASE_SOURCE="stdin"
        shift 1
        ;;
      --luks-passphrase-file)
        LUKS_PASSPHRASE_SOURCE="file"
        LUKS_PASSPHRASE_FILE="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=true
        shift 1
        ;;
      --config)
        CONFIG_PATH="$2"
        shift 2
        ;;
      --skip-internet-check)
        SKIP_INTERNET_CHECK=true
        shift 1
        ;;
      --skip-iso-verify)
        SKIP_ISO_VERIFY=true
        shift 1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

confirm_wipe() {
  echo "\nTarget disk: ${TARGET_DISK:-<unset>}"
  echo "This will WIPE all data on the target disk."
  read -r -p "Type 'WIPE' to continue: " answer
  if [[ "$answer" != "WIPE" ]]; then
    log_error "Confirmation not given, aborting."
    exit 1
  fi
}

run_step() {
  local step_script="$1"
  CURRENT_STEP="$(basename "$step_script")"
  export CURRENT_STEP
  log_info "Running step ${CURRENT_STEP}"
  "${step_script}"
}

main() {
  parse_args "$@"

  init_logging

  load_config "${CONFIG_PATH}" "${PROFILE}"

  export DRY_RUN SKIP_INTERNET_CHECK SKIP_ISO_VERIFY LUKS_PASSPHRASE_SOURCE LUKS_PASSPHRASE_FILE

  print_config_summary

  if [[ "$DRY_RUN" == true ]]; then
    log_info "Dry-run mode enabled; no changes will be made."
    exit 0
  fi

  confirm_wipe

  require_root

  for step in \
    "${ROOT_DIR}/steps/00-preflight.sh" \
    "${ROOT_DIR}/steps/10-partition.sh" \
    "${ROOT_DIR}/steps/20-encrypt-btrfs.sh" \
    "${ROOT_DIR}/steps/30-mount.sh" \
    "${ROOT_DIR}/steps/40-install.sh" \
    "${ROOT_DIR}/steps/50-configure.sh" \
    "${ROOT_DIR}/steps/60-grub.sh" \
    "${ROOT_DIR}/steps/70-recovery-iso.sh" \
    "${ROOT_DIR}/steps/90-cleanup.sh"; do
    if [[ -f "$step" ]]; then
      run_step "$step"
    else
      log_error "Missing step script: $step"
      exit 1
    fi
  done

  log_info "Installation steps completed successfully."
}

main "$@"
