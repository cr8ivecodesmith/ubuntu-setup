#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/disk.sh"
source "${ROOT_DIR}/lib/config.sh"

export CURRENT_STEP="20-encrypt-btrfs.sh"

SENTINEL="${STATE_DIR}/20-encrypt-btrfs.done"

if [[ -f "$SENTINEL" ]]; then
  log_info "Encryption and BTRFS setup already completed; skipping."
  exit 0
fi

# shellcheck source=/dev/null
source "${STATE_DIR}/partitions.env"

if [[ "${DRY_RUN:-false}" == true ]]; then
  log_info "DRY-RUN: would create LUKS on ${CRYPTROOT_PART} and BTRFS on /dev/mapper/${LUKS_NAME}"
  exit 0
fi

get_luks_passphrase() {
  if [[ -n "${LUKS_PASSPHRASE:-}" ]]; then
    echo -n "$LUKS_PASSPHRASE"
    return
  fi
  case "${LUKS_PASSPHRASE_SOURCE:-prompt}" in
    file)
      if [[ -z "${LUKS_PASSPHRASE_FILE:-}" || ! -f "$LUKS_PASSPHRASE_FILE" ]]; then
        log_fatal "LUKS passphrase file not found: ${LUKS_PASSPHRASE_FILE:-<unset>}"
      fi
      cat "$LUKS_PASSPHRASE_FILE"
      ;;
    stdin)
      # Read from stdin
      cat
      ;;
    *)
      read -r -s -p "Enter LUKS passphrase: " pass
      echo
      read -r -s -p "Confirm LUKS passphrase: " pass2
      echo
      if [[ "$pass" != "$pass2" ]]; then
        log_fatal "Passphrases do not match."
      fi
      echo -n "$pass"
      ;;
  esac
}

PASS="$(get_luks_passphrase)"

echo -n "$PASS" | cryptsetup luksFormat \
  --type luks2 \
  --cipher "$LUKS_CIPHER" \
  --key-size "$LUKS_KEYSIZE" \
  --hash "$LUKS_HASH" \
  --pbkdf "$LUKS_PBKDF" \
  "$CRYPTROOT_PART" -

echo -n "$PASS" | cryptsetup open "$CRYPTROOT_PART" "$LUKS_NAME" -

run_or_echo mkfs.btrfs -L "$BTRFS_LABEL" "/dev/mapper/${LUKS_NAME}"

run_or_echo mount "/dev/mapper/${LUKS_NAME}" /mnt

# Create subvolumes based on SUBVOLS mapping
for entry in $SUBVOLS; do
  name="${entry%%:*}"
  run_or_echo btrfs subvolume create "/mnt/${name}"
done

run_or_echo umount /mnt

cat >"${STATE_DIR}/luks.env" <<EOF
LUKS_MAPPER="/dev/mapper/${LUKS_NAME}"
EOF

run_or_echo touch "$SENTINEL"
