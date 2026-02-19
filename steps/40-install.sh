#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${ROOT_DIR}/state"
mkdir -p "$STATE_DIR"

source "${ROOT_DIR}/lib/log.sh"
source "${ROOT_DIR}/lib/config.sh"
source "${ROOT_DIR}/lib/chroot.sh"

export CURRENT_STEP="40-install.sh"

SENTINEL="${STATE_DIR}/40-install.done"

if [[ -f "$SENTINEL" ]]; then
  log_info "Base system already installed; skipping."
  exit 0
fi

if [[ "${DRY_RUN:-false}" == true ]]; then
  log_info "DRY-RUN: would bootstrap Ubuntu ${UBUNTU_RELEASE} into /mnt using ${UBUNTU_MIRROR}."
  exit 0
fi

log_info "Bootstrapping base system into /mnt"

if command -v mmdebstrap >/dev/null 2>&1; then
  run_or_echo mmdebstrap \
    --variant=apt \
    --include="${BASE_PACKAGES} ${DESKTOP_PACKAGES:-} ${EXTRA_PACKAGES:-}" \
    "${UBUNTU_RELEASE}" /mnt "${UBUNTU_MIRROR}"
else
  run_or_echo debootstrap "${UBUNTU_RELEASE}" /mnt "${UBUNTU_MIRROR}"
  setup_chroot_mounts /mnt
  in_chroot /mnt apt-get update
  in_chroot /mnt apt-get install -y ${BASE_PACKAGES} ${DESKTOP_PACKAGES:-} ${EXTRA_PACKAGES:-}
fi

# Ensure sources.list is configured
cat > /mnt/etc/apt/sources.list <<EOF
deb ${UBUNTU_MIRROR} ${UBUNTU_RELEASE} main universe multiverse
deb ${UBUNTU_MIRROR} ${UBUNTU_RELEASE}-updates main universe multiverse
deb ${UBUNTU_MIRROR} ${UBUNTU_RELEASE}-security main universe multiverse
EOF

setup_chroot_mounts /mnt

run_or_echo touch "$SENTINEL"
