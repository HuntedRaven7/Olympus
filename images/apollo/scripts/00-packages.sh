#!/usr/bin/env bash
# Install the Wayland desktop stack. AUR helpers are transient build tools.
# shellcheck source=/dev/null
source /hera-scripts/lib.sh
set -euo pipefail

echo "::group::Install Apollo packages"

retry pacman -Syu --noconfirm --needed

retry pacman -S --noconfirm --needed \
    base-devel git \
    greetd \
    seatd \
    dbus \
    polkit \
    pipewire \
    pipewire-pulse \
    wireplumber \
    alsa-lib \
    mesa \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-utils \
    xorg-xwayland \
    wl-clipboard \
    gtk3 \
    qt6-base \
    qt6-wayland \
    noto-fonts \
    noto-fonts-emoji

if [[ "${WITH_TEST_TOOLS:-false}" == "true" ]]; then
    retry pacman -S --noconfirm --needed openssh
    systemctl enable sshd.service
fi

# quickshell and mangowm are AUR-only. Build them in a transient user.
useradd -m builder
mkdir -p /etc/sudoers.d
printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder
retry runuser -u builder -- bash -c \
    'git clone https://aur.archlinux.org/yay-bin.git /home/builder/yay-bin'
retry runuser -u builder -- bash -c \
    'cd /home/builder/yay-bin && makepkg -si --noconfirm'
retry runuser -u builder -- bash -c \
    'yay -S --noconfirm --needed mangowm-git quickshell-git'

userdel -r builder
rm -rf /home/builder /etc/sudoers.d/builder
pacman -Rns --noconfirm base-devel || true
find /etc -name '*.pacnew' -type f -delete

echo "::endgroup::"
