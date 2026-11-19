#!/usr/bin/env bash
# Enable the display manager, seat and user services.
set -euo pipefail

echo "::group::Configure Apollo desktop"

getent group greeter >/dev/null || groupadd greeter
id greeter >/dev/null 2>&1 || useradd -M -g greeter -s /usr/bin/nologin greeter

systemctl enable greetd.service seatd.service
systemctl set-default graphical.target

# The user-level services ship in /etc/skel so they are created for every new
# account. Quickshell config is intentionally NOT installed here.
systemctl --global enable quickshell.service

echo "::endgroup::"
