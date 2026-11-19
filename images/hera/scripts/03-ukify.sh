#!/usr/bin/env bash
# Seal the chunked composefs rootfs into a signed UKI.
# Copied from tartaria-dev/tartaria build_files/scripts/06-ukify.sh.
# shellcheck source=/dev/null
source /hera-scripts/lib.sh
set -euo pipefail

echo "::group::Create signed UKI"

mkdir -p /out/uki /out/boot /var/tmp
kver=$(find /kernel -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | head -n1)

retry pacman -S --noconfirm --needed systemd-ukify sbsigntools

bootc container ukify \
    --rootfs /target \
    --kernel-dir "/kernel/${kver}" \
    -- \
    --output "/out/uki/${kver}.efi" \
    --signtool sbsign \
    --secureboot-private-key /run/secrets/secureboot_key \
    --secureboot-certificate /run/secrets/secureboot_cert

sbsign \
    --key /run/secrets/secureboot_key \
    --cert /run/secrets/secureboot_cert \
    --output /out/boot/grubx64.efi \
    /target/usr/lib/systemd/boot/efi/systemd-bootx64.efi

# Export the public certificate into the image for first-boot MOK enrollment.
mkdir -p /target/usr/share/olympus/certs
openssl x509 -in /run/secrets/secureboot_cert -outform DER \
    -out /target/usr/share/olympus/certs/secureboot.der

rm -rf /var/tmp
echo "::endgroup::"
