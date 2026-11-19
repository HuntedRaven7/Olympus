#!/usr/bin/env bash
# Build the initramfs and lay out the bootc filesystem.
# Pattern copied from tartaria-dev/tartaria build_files/scripts/05-finalize.sh.
set -euo pipefail

echo "::group::Finalize image build"

kver=$(basename "$(find /usr/lib/modules -maxdepth 1 -type d \
    ! -name 'modules' ! -name 'kernel' | grep -E '[0-9]' | tail -n 1)")
if [[ -z "$kver" ]]; then
    echo "could not determine kernel version" >&2
    exit 1
fi

DRACUT_NO_XATTR=1 dracut --force --no-hostonly --reproducible --zstd \
    --verbose --kver "$kver" "/usr/lib/modules/${kver}/initramfs.img"

# bootc filesystem layout: everything immutable lives in /usr, /var is empty.
# /var/cache/pacman/pkg is a bind mount from the runner cache and cannot be
# removed; leave it in place (its contents are discarded when the layer ends).
# shellcheck disable=SC2114
rm -rf /boot /home /root /srv /mnt /opt
find /var -mindepth 1 -maxdepth 1 ! -name cache -exec rm -rf {} +
find /var/cache -mindepth 1 -maxdepth 1 ! -name pacman -exec rm -rf {} +
find /var/cache/pacman -mindepth 1 -maxdepth 1 ! -name pkg -exec rm -rf {} +
rm -rf /usr/lib/sysimage/log /usr/lib/sysimage/cache/pacman/pkg

mkdir -p /sysroot /boot /usr/lib/ostree /var /home /root /opt /mnt /srv
ln -sT sysroot/ostree /ostree

# os-release is templated so CI can stamp the variant at build time.
sed -i \
    -e "s/placeholder_name/Hera ${IMAGE_VARIANT:-latest}/g" \
    -e "s/placeholder_date/$(date +%F.%H%M%S%N)/g" \
    /usr/lib/os-release
[[ -e /etc/os-release ]] || ln -sT /usr/lib/os-release /etc/os-release

echo "::endgroup::"
