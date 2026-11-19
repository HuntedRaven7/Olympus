#!/usr/bin/env bash
# Final Apollo cleanup; keeps the bootc layout inherited from Hera intact.
set -euo pipefail

rm -rf /tmp/* /tmp/.* /var/cache/pacman/pkg/* /apollo-scripts
find /etc -name '*.pacnew' -type f -delete
