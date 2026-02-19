#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/disk.sh"

export CURRENT_STEP="10-partition.sh"

SENTINEL="${STATE_DIR}/10-partition.done"

if [[ -f "$SENTINEL" ]]; then
  log_info "Partitioning already completed; skipping."
  exit 0
fi

partition_disk
format_partitions

run_or_echo touch "$SENTINEL"
