#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/config.sh"
source "${ROOT_DIR}/lib/checks.sh"
source "${ROOT_DIR}/lib/disk.sh"

export CURRENT_STEP="00-preflight.sh"

SENTINEL="${STATE_DIR}/00-preflight.done"

if [[ -f "$SENTINEL" ]]; then
  log_info "Preflight already completed; skipping."
  exit 0
fi

require_root
ensure_uefi
ensure_tools_available
ensure_not_live_disk
ensure_disk_unused
ensure_internet

print_config_summary

run_or_echo touch "$SENTINEL"
