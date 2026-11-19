# Hera

Hera is the Arch Linux base image: a minimal TTY system with no desktop, no
SSH server, and no language interpreters beyond what the bootc tooling itself
needs at build time.

## Contents

- `base`, `systemd`, `shadow`, `linux`, `linux-firmware`, `dracut`, `ostree`,
  `bootc` (from the vendored repo pattern), `uupd`, `skopeo`, `efibootmgr`,
  `mokutil`, `shim-signed`, `erofs-utils`
- `systemd-networkd` + `systemd-resolved` + `systemd-timesyncd` with a
  type-based DHCP `.network` file
- getty on `tty1` (no graphical login)
- composefs prepared in `usr/lib/ostree/prepare-root.conf`
- host-independent, reproducible dracut initramfs

Explicitly *not* included: greetd, a compositor, a shell-based user environment,
OpenSSH, Podman/Docker, Homebrew, Flatpak.

## Build

```sh
just build hera                 # base image
just build-sealed hera          # full sealed pipeline (needs Secure Boot keys)
just lint-container hera
```

The Containerfiles are:

- `images/hera/Containerfile` — `base`, `split-kernel`, `chunkah` stages
- `images/hera/Containerfile.seal-finalize` — signed UKI stage

Scripts, in execution order:

1. `images/hera/scripts/00-base.sh` — pacman/keyring/bootc repo setup
2. `images/hera/scripts/01-packages.sh` — OS packages
3. `images/hera/scripts/02-finalize.sh` — initramfs and bootc layout
4. `images/hera/scripts/03-ukify.sh` — sealing (seal-finalize stage only)

`BOOTC_REPO_URL` / `BOOTC_REPO_KEY` are build args so a downstream build can use
the repository produced from `packages/` instead of the upstream one.

## Installation

```sh
# unsalted / development
just bootc hera install to-disk --via-loopback /data/bootable.img --wipe --bootloader systemd

# sealed (composefs backend)
just bootc hera install to-disk --composefs-backend --via-loopback /data/bootable.img \
    --filesystem ext4 --wipe --bootloader systemd
```
