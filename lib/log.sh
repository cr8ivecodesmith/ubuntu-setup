#!/usr/bin/env bash
set -euo pipefail

LOG_FILE_LIVE="/tmp/ubuntu-auto-install.log"

log_timestamp() {
  date +"%Y-%m-%d %H:%M:%S"
}

log_level() {
  local level="$1"
  local msg="$2"
  local step="${CURRENT_STEP:-unknown}"
  printf '%s [%s] %s: %s
' "$(log_timestamp)" "$step" "$level" "$msg" | tee -a "$LOG_FILE_LIVE" >&2
}

log_info() {
  log_level "INFO" "$1"
}

log_warn() {
  log_level "WARN" "$1"
}

log_error() {
  log_level "ERROR" "$1"
}

log_fatal() {
  log_level "FATAL" "$1"
  exit 1
}

init_logging() {
  exec > >(tee -a "$LOG_FILE_LIVE") 2>&1
}

run_or_echo() {
  if [[ "${DRY_RUN:-false}" == true ]]; then
    log_info "DRY-RUN: $*"
  else
    "$@"
  fi
}
