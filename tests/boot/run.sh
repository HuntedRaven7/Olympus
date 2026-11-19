#!/usr/bin/env bash
# Boot an image with bcvk and assert that no systemd units failed.
# Requires root, podman, just and bcvk with KVM access.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

image=${1:-hera}
case "$image" in
    hera|athena|apollo) ;;
    *) echo "unknown image: $image" >&2; exit 2 ;;
esac

if ! command -v bcvk >/dev/null 2>&1; then
    echo "bcvk is required for boot tests" >&2
    exit 1
fi

ref="localhost/${image}:latest"

# Build a debug variant with SSH + shell when not already present. The
# published images deliberately omit both (see docs/testing.md).
if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    sudo -E env WITH_TEST_TOOLS=true "$(command -v just)" build "$image"
fi

echo "==> booting ${ref}"
failed=$(bcvk ephemeral run-ssh "$ref" -- systemctl --failed --no-pager --no-legend)
printf '%s\n' "$failed"
if [[ -n "$failed" ]]; then
    echo "FAIL: failed units in ${image}" >&2
    exit 1
fi

case "$image" in
    hera)
        bcvk ephemeral run-ssh "$ref" -- systemctl is-active getty@tty1.service
        ;;
    apollo)
        bcvk ephemeral run-ssh "$ref" -- systemctl is-active greetd.service
        bcvk ephemeral run-ssh "$ref" -- systemctl is-active seatd.service
        ;;
    athena)
        bcvk ephemeral run-ssh "$ref" -- systemctl is-active containerd.service
        bcvk ephemeral run-ssh "$ref" -- systemctl is-active kubelet.service
        ;;
esac

echo "OK: ${image} booted with no failed units"
