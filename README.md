# Ubuntu LUKS+BTRFS Installer with Recovery ISO

This project provides a **bash-based installer** you run from an Ubuntu 24.04 live session to provision a machine with:

- UEFI boot
- Separate ESP + unencrypted `/boot`
- Encrypted LUKS2 container with BTRFS subvolumes (`@` on `/`, `@home` on `/home`)
- A `/recovery` partition containing an Ubuntu Desktop ISO
- A GRUB menu entry that boots the recovery ISO via loopback

> **WARNING**: Running this installer will **irrevocably wipe the target disk**. Use only on the disk you intend to reimage.

## Quick Start

1. **Boot Live ISO**
   - Boot an Ubuntu 24.04 (Noble) live ISO in **UEFI mode**.
   - Choose "Try Ubuntu".

2. **Get the project**
   - Clone or copy this repository into the live session, e.g.:
     ```bash
     git clone <your-fork-url> ubuntu-setup
     cd ubuntu-setup
     ```

3. **Configure your machine**
   - Copy the example config and edit it:
     ```bash
     cp config/user.env.example config/user.env
     $EDITOR config/user.env
     ```
   - At minimum, set:
     - `TARGET_DISK` (e.g. `/dev/nvme0n1`)
     - `HOSTNAME`
     - `USERNAME`
     - `TIMEZONE`
     - `RECOVERY_ISO_URL` and `RECOVERY_ISO_SHA256`

4. **Dry-run (recommended)**
   - See what the installer intends to do without touching the disk:
     ```bash
     sudo ./install.sh --disk /dev/nvme0n1 --profile noble-desktop --dry-run
     ```

5. **Run the installer**
   - When ready:
     ```bash
     sudo ./install.sh --disk /dev/nvme0n1 --profile noble-desktop
     ```
   - The script will:
     - Print a configuration summary
     - Ask you to type `WIPE` before partitioning
     - Prompt for a LUKS passphrase (unless provided via file/stdin/env)

6. **Reboot into the new system**
   - After all steps complete and you see the "Installation complete" message:
     - Reboot
     - Remove the live media
   - GRUB should present the normal Ubuntu entry plus a **"Ubuntu Recovery ISO"** entry that boots the ISO stored in `/recovery`.

## Configuration Overview

Configuration lives in **env files** under `config/`:

- `config/default.env`
  - Project defaults. Safe to leave as-is in most cases.
- `config/user.env` (ignored by git; create from `user.env.example`)
  - Machine-specific overrides.

### Required keys

From `config/user.env` you should set:

- **Target & OS**
  - `TARGET_DISK` – whole disk device to wipe (e.g. `/dev/nvme0n1`).
  - `UBUNTU_RELEASE` – Ubuntu codename (default `noble`).
  - `UBUNTU_MIRROR` – APT mirror (default `http://archive.ubuntu.com/ubuntu`).
- **Identity**
  - `HOSTNAME` – system hostname.
  - `USERNAME` – primary user.
  - `TIMEZONE` – e.g. `Europe/Berlin`, `Asia/Manila`.
- **Partition sizes (MiB)**
  - `ESP_SIZE_MIB` – EFI system partition (default 1024).
  - `BOOT_SIZE_MIB` – unencrypted `/boot` (default 2048).
  - `RECOVERY_SIZE_MIB` – `/recovery` (default 10240).
- **Encryption**
  - `LUKS_NAME` – name of the opened mapper device (default `cryptroot`).
  - `LUKS_CIPHER`, `LUKS_KEYSIZE`, `LUKS_HASH`, `LUKS_PBKDF` – LUKS2 parameters with sensible defaults.
- **BTRFS**
  - `BTRFS_LABEL` – label for the BTRFS filesystem (default `UBUNTU`).
  - `BTRFS_MOUNT_OPTS` – mount options, including compression.
  - `SUBVOLS` – mapping of subvolumes to mountpoints (default `@:/ @home:/home`).
- **Recovery ISO**
  - `RECOVERY_ISO_URL` – URL of the Ubuntu recovery ISO.
  - `RECOVERY_ISO_SHA256` – expected SHA256 (required unless `--skip-iso-verify`).
  - `RECOVERY_ISO_PATH` – path inside the installed system (default `/recovery/ubuntu-recovery.iso`).

### Optional configuration

- **Packages** (in `config/default.env`)
  - `BASE_PACKAGES` – kernel + base system + networking; should include `linux-generic`, `ubuntu-standard`, `network-manager`, `sudo`, etc.
  - `DESKTOP_PACKAGES` – desktop metapackage(s) (default `ubuntu-desktop ubuntu-restricted-extras` for multimedia codecs).
  - `EXTRA_PACKAGES` – tools like `btrfs-progs`, `cryptsetup`, `grub-efi-amd64`, `shim-signed`, etc.

- **Swap**
  - `SWAPFILE_GIB` – if `>0`, creates a simple swapfile on BTRFS inside the encrypted root (no hibernate support by default).

- **Recovery ISO timer**
  - `ENABLE_TIMER` – if `true`, installs and enables a weekly `update-recovery-iso.timer` inside the installed system.

- **User credentials** (optional, otherwise prompted)
  - `USER_PASSWORD_HASH` – pre-hashed password for the user (used directly by `useradd`).
  - `USER_PASSWORD` – plain password to avoid interactive prompts (use with care).

- **LUKS passphrase input**
  - `LUKS_PASSPHRASE` – passphrase as env var (discouraged; use only in controlled environments).
  - CLI flags:
    - `--luks-passphrase-file PATH`
    - `--luks-passphrase-stdin`

## Threat Model Notes

- **Unencrypted `/boot`**
  - `/boot` is left **unencrypted** to avoid early passphrase prompts and reduce complexity.
  - This means a local attacker with physical access could tamper with kernel/initramfs unless mitigated.

- **Secure Boot recommended**
  - The installer **does not implement a full custom Secure Boot policy**, but it installs signed shim/GRUB packages.
  - The intended model is:
    - Install with Secure Boot **disabled** for simplicity.
    - After installation, **re-enable Secure Boot in firmware** so only signed boot chain components can run.

- **Encrypted root**
  - Root filesystem (including `/home`) lives on a LUKS2-encrypted BTRFS volume.
  - Swap, if configured, is also inside the encrypted container.

> This trades **evil‑maid resistance** for usability: `/boot` is readable, but the bulk of data (root + home + swap) is encrypted.

## BTRFS subvolumes: practical guide

You start with two subvolumes by default: `@` (root) and `@home` (user data). You can add more for workloads that benefit from separate snapshots, backup policies, or CoW settings.

- **How to add a new subvolume** (example: `@games` mounted at `/games`)
  1. Boot into the installed system (or from live media with the root BTRFS mounted).
  2. Mount the BTRFS volume at its *top level* (not a subvolume), e.g.:
     ```bash
     sudo mount -o subvol=/ /dev/mapper/cryptroot /mnt
     ```
  3. Create a new subvolume:
     ```bash
     sudo btrfs subvolume create /mnt/@games
     ```
  4. Add an entry to `/etc/fstab` so it mounts automatically:
     ```bash
     sudo mkdir -p /games
     echo "UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot) /games btrfs ${BTRFS_MOUNT_OPTS},subvol=@games 0 2" | sudo tee -a /etc/fstab
     ```
  5. Mount it:
     ```bash
     sudo mount /games
     ```

- **Good candidates for separate subvolumes**
  - **Docker containers / images** (e.g. `/var/lib/docker`)
  - **Virtual machines** (e.g. `/var/lib/libvirt/images`, `/vm`)
  - **LLM model caches / weights** (e.g. `/opt/models`)
  - **Game / Steam libraries** (e.g. `/games`, `~/.steam/steamapps`)
  - **Large build trees** or project workspaces that you snapshot/rollback independently

  Separating these lets you snapshot, backup, or exclude them from snapshots without affecting the rest of the system.

- **When disabling CoW (no-CoW) makes sense**
  - Good use-cases for `chattr +C` (no CoW on a directory):
    - VM disk images (qcow2/raw) that see heavy random writes
    - Large databases with frequent in-place updates
    - Docker overlay storage or other write-heavy container layers
    - Large, constantly updated files where fragmentation and metadata churn matter more than snapshot-friendly history
  - **Avoid** no-CoW for:
    - Normal user data, `/home`, configuration files
    - Anything you want consistent snapshots of

- **Example: VM images on a no-CoW subvolume**
  1. Mount the top-level BTRFS and create a dedicated subvolume, e.g. `@vm`:
     ```bash
     sudo mount -o subvol=/ /dev/mapper/cryptroot /mnt
     sudo btrfs subvolume create /mnt/@vm
     ```
  2. Create a mountpoint and mark it no-CoW *before* creating files:
     ```bash
     sudo mkdir -p /vm
     sudo chattr +C /vm
     ```
  3. Add to `/etc/fstab` (similar to above, but for `/vm`):
     ```bash
     VM_UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot)
     echo "UUID=${VM_UUID} /vm btrfs ${BTRFS_MOUNT_OPTS},subvol=@vm 0 2" | sudo tee -a /etc/fstab
     sudo mount /vm
     ```
  4. Create or move VM disk images into `/vm`.

  Remember that BTRFS cannot retroactively disable CoW: you must set `chattr +C` on an *empty* directory before creating files that should be no-CoW.

## Troubleshooting

- **Installer refuses to run**
  - Check you’re running as **root**:
    ```bash
    sudo ./install.sh ...
    ```
  - Ensure you are booted in **UEFI mode** (`/sys/firmware/efi` must exist).

- **`TARGET_DISK` rejected or in use**
  - The preflight step will abort if the disk appears to be the live medium or has mounted partitions.
  - Use `lsblk` / `findmnt` to confirm the correct device, and unmount anything you manually mounted.

- **Missing tools / package install failures**
  - The preflight step attempts to `apt-get install` any missing utilities.
  - If network is flaky, you can rerun with `--skip-internet-check`, but installs will still fail if apt cannot reach the mirror.

- **Boot issues after install**
  - From the live environment, you can chroot into the installed system:
    ```bash
    # mount LUKS + BTRFS as needed, then:
    sudo mount --bind /dev /mnt/dev
    sudo mount --bind /proc /mnt/proc
    sudo mount --bind /sys /mnt/sys
    sudo chroot /mnt
    ```
  - Inside chroot, verify:
    - `/etc/crypttab` and `/etc/fstab` UUIDs match the actual devices (`blkid`).
    - `update-initramfs -u -k all` and `update-grub` succeed.

- **Recovery ISO problems**
  - Check that `/recovery/ubuntu-recovery.iso` exists and is readable.
  - Re-run `/usr/local/sbin/update-recovery-iso` inside the installed system to refresh the ISO.
  - Verify that GRUB’s "Ubuntu Recovery ISO" entry appears after `sudo update-grub`.
