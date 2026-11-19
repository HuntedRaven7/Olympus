#!/usr/bin/env bash
# Install the minimal TTY OS for Hera. No desktop, no SSH.
# shellcheck source=/dev/null
source /hera-scripts/lib.sh
set -euo pipefail

echo "::group::Install system packages"

retry pacman -S --noconfirm --needed \
    base \
    systemd \
    systemd-sysvcompat \
    shadow \
    linux \
    linux-firmware \
    linux-headers \
    dracut \
    ostree \
    bubblewrap \
    skopeo \
    podman \
    efibootmgr \
    mokutil \
    openssl \
    openssl-3 \
    erofs-utils \
    pkgconf \
    dbus \
    dbus-glib \
    glib2 \
    btrfs-progs \
    e2fsprogs \
    xfsprogs \
    dosfstools \
    iproute2 \
    less \
    man-db \
    nano \
    vi

# The boot-test debug variant needs an SSH server so bcvk can exec into it.
if [[ "${WITH_TEST_TOOLS:-false}" == "true" ]]; then
    retry pacman -S --noconfirm --needed openssh
    systemctl enable sshd.service
fi

# bootc and uupd come from the vendored repository configured in 00-base.sh.
retry pacman -S --noconfirm --needed bootc/bootc bootc/uupd

# shim-signed is required for the sealed Secure Boot chain. It is built from
# the vendored PKGBUILD in packages/ and published with the bootc repo.
if pacman -Si bootc/shim-signed >/dev/null 2>&1; then
    retry pacman -S --noconfirm --needed bootc/shim-signed
else
    echo "::warning::shim-signed not found in the configured repo; sealed builds need it"
fi

# Remove build-only packages and any leftover cache/PACNEW files.
pacman -Rns --noconfirm linux-headers pkgconf || true
find /etc -name '*.pacnew' -type f -delete
rm -rf /var/cache/pacman/pkg/*

# Pre-configure first boot: no interactive prompts, DHCP on ethernet.
echo "uninitialized" > /etc/machine-id
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
mkdir -p /etc/systemd/network
printf '[Match]\nType=ether\n\n[Network]\nDHCP=yes\n' \
    > /usr/lib/systemd/network/20-wired.network
printf 'L! /etc/resolv.conf - - - - /run/systemd/resolve/stub-resolv.conf\n' \
    > /usr/lib/tmpfiles.d/resolv-conf.conf

systemctl enable \
    systemd-networkd.service \
    systemd-resolved.service \
    systemd-timesyncd.service \
    getty@tty1.service
systemctl mask systemd-firstboot.service

echo "::endgroup::"
