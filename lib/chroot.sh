#!/usr/bin/env bash
set -euo pipefail

setup_chroot_mounts() {
  local target="$1"
  if ! mountpoint -q "${target}/dev"; then
    run_or_echo mount --bind /dev "${target}/dev"
  fi
  if ! mountpoint -q "${target}/proc"; then
    run_or_echo mount --bind /proc "${target}/proc"
  fi
  if ! mountpoint -q "${target}/sys"; then
    run_or_echo mount --bind /sys "${target}/sys"
  fi
  if ! mountpoint -q "${target}/run"; then
    run_or_echo mount --bind /run "${target}/run"
  fi
  if [[ -e "${target}/etc/resolv.conf" && ! -e "${target}/etc/resolv.conf.bak" ]]; then
    run_or_echo mv "${target}/etc/resolv.conf" "${target}/etc/resolv.conf.bak"
  fi
  run_or_echo cp /etc/resolv.conf "${target}/etc/resolv.conf"
}

teardown_chroot_mounts() {
  local target="$1"
  for m in dev proc sys run; do
    if mountpoint -q "${target}/${m}"; then
      run_or_echo umount "${target}/${m}"
    fi
  done
}

in_chroot() {
  local target="$1"
  shift
  chroot "$target" /bin/bash -c "$*"
}
