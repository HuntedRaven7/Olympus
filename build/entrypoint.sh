#!/bin/bash
# Copied build pattern from hecknt/makepkg-action @ 6efd785524d744425796e65971a0c5db1b54c9ef
# GitHub Docker actions expose inputs as INPUT_<NAME> (uppercased).
set -oeux pipefail

# Reproducibility.
export SOURCE_DATE_EPOCH=1760000000

if [ -n "${INPUT_GPG_KEY_DATA-}" ]; then
    if [ -z "${INPUT_GPG_KEY_ID-}" ]; then
        echo 'GPG_KEY_ID is not set, but GPG_KEY_DATA is set.' >&2
        exit 1
    fi
    gpg --import /dev/stdin <<<"${INPUT_GPG_KEY_DATA}"
fi

if [ -n "${INPUT_GPG_KEY_ID-}" ] && ! gpg --list-keys "${INPUT_GPG_KEY_ID}" >/dev/null 2>&1; then
    gpg --recv-keys "${INPUT_GPG_KEY_ID}"
fi

for dir in /github/workspace /github/home; do
    if [ -d "$dir" ]; then
        sudo chown -R build "$dir"
    fi
done

mkdir -p repo
sudo pacman -Syu --noconfirm
MAKEFLAGS="-j$(nproc)"
export MAKEFLAGS

for pkgdir in pkgs/*; do
    pushd "$pkgdir"
    namcap PKGBUILD
    su build -c "makepkg --sync --clean --rmdeps --noconfirm"
    mv ./*.pkg.tar.zst ../../repo
    popd
done

tree repo

if [ -n "${INPUT_GPG_KEY_ID-}" ]; then
    find repo -type f -iname '*.pkg.tar*' -not -iname '*.sig' -print \
        -exec gpg --batch --yes --detach-sign --use-agent -u "${INPUT_GPG_KEY_ID}" {} \;
    find repo -type f -iname '*.pkg.tar*' -not -iname '*.sig' -print0 | \
        xargs -0 repo-add -k "${INPUT_GPG_KEY_ID}" -s -v "repo/${INPUT_REPO_NAME}.db.tar.zst"
fi
