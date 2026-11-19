#!/usr/bin/env bash
# Apply the Amutable-style server hardening. This is the final build step:
# it removes the very shell that is executing it, so nothing may follow it.
set -euo pipefail

echo "::group::Harden Athena"

if [[ "${WITH_TEST_TOOLS:-false}" == "true" ]]; then
    echo "::warning::building debug variant: shells and SSH are retained for boot tests"
    rm -rf /tmp/* /var/cache/pacman/pkg/* /athena-scripts /hera-scripts
    echo "::endgroup::"
    exit 0
fi

# 1. No shell, no SSH, no language interpreters.
for bin in \
    bash dash zsh fish csh tcsh ksh \
    sh \
    python python2 python3 perl ruby php lua node \
    ssh sshd scp sftp \
    yay paru makepkg sudo; do
    rm -f "/usr/bin/${bin}" "/bin/${bin}"
done

# Keep only symlinks that point at real, non-shell binaries (systemd uses
# /bin -> /usr/bin already on Arch).
systemctl mask sshd.service sshd.socket 2>/dev/null || true

# 2. No SUID/SGID bits or file capabilities anywhere in the immutable rootfs.
find /usr /etc -xdev -perm /6000 -exec chmod a-s {} + 2>/dev/null || true
while IFS= read -r -d '' capfile; do
    setcap -r "$capfile" 2>/dev/null || true
done < <(getcap -r /usr 2>/dev/null | cut -d' ' -f1 | tr '\n' '\0')
# Privileges are granted to units with AmbientCapabilities= instead.

# 3. W^X-friendly mounts and a read-only /usr are provided by the sealed base;
#    ensure no executable accidentally lives in a writable directory.
find /var /etc -xdev -type f -perm /111 -delete 2>/dev/null || true

# 4. Factory reset: systemd-factory-reset restores /etc and /var on request.
mkdir -p /usr/lib/systemd/factory-reset
systemctl enable systemd-factory-reset.target 2>/dev/null || true

# 5. Clean up build residue.
rm -rf /tmp/* /tmp/.* /var/cache/pacman/pkg/* /athena-scripts /hera-scripts
find /etc -name '*.pacnew' -type f -delete

echo "::endgroup::"
