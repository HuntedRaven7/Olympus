#!/usr/bin/env bash
# Prepare pacman and add the (vendored) bootc package repository.
# Pattern copied from tartaria-dev/tartaria build_files/scripts/00-base.sh.
# shellcheck source=/dev/null
source /hera-scripts/lib.sh
set -euo pipefail

echo "::group::Prepare image build"

mkdir -p /tmp/build /var/cache/pacman/pkg \
    /usr/lib/sysimage/lib/pacman \
    /usr/lib/sysimage/log \
    /usr/lib/sysimage/etc/pacman.d/gnupg \
    /usr/lib/sysimage/etc/pacman.d/hooks

# Move pacman's mutable state into /usr/lib/sysimage so it survives
# `bootc usroverlay`. The package cache stays in /var (it is build-time only
# and is mounted from the runner's pacman cache).
# The base image already has a local package database: copy it first, otherwise
# pacman would think none of the base packages are installed and report file
# conflicts for every package we install below.
cp -a /var/lib/pacman/. /usr/lib/sysimage/lib/pacman/

sed -i \
    -e 's|^#\?DBPath * =.*|DBPath      = /usr/lib/sysimage/lib/pacman|' \
    -e 's|^#\?LogFile * =.*|LogFile     = /usr/lib/sysimage/log/pacman.log|' \
    -e 's|^#\?GPGDir * =.*|GPGDir      = /usr/lib/sysimage/etc/pacman.d/gnupg|' \
    -e 's|^#\?HookDir * =.*|HookDir     = /usr/lib/sysimage/etc/pacman.d/hooks|' \
    -e '/DownloadUser/d' \
    -e 's/^#\?DisableSandbox/DisableSandbox/' \
    /etc/pacman.conf
grep -q '^DisableSandbox' /etc/pacman.conf || sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf

pacman-key --init
pacman-key --populate archlinux

# The composefs-capable bootc binary comes from the vendored repo pattern.
# BOOTC_REPO_KEY / BOOTC_REPO_URL are Containerfile build arguments.
if [[ -n "${BOOTC_REPO_KEY:-}" ]]; then
    retry pacman-key --recv-key "$BOOTC_REPO_KEY" --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key "$BOOTC_REPO_KEY"
fi
if [[ -n "${BOOTC_REPO_URL:-}" ]]; then
    printf '\n[bootc]\nSigLevel = Required\nServer = %s\n' "$BOOTC_REPO_URL" \
        >> /etc/pacman.conf
fi

retry pacman -Syu --noconfirm --needed

echo "::endgroup::"
