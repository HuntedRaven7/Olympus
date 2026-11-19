#!/usr/bin/env bash
# Static assertions for Athena's no-shell / no-SSH / no-interpreter policy.
# The image config lives under images/athena/config/, which mirrors the rootfs.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config="${1:-${root}/images/athena/config}"
fail=0

check_absent() {
    local file="$1" desc="$2"
    if [[ -e "$config$file" ]]; then
        echo "FAIL: $desc found at $file" >&2
        fail=1
    fi
}

check_absent /usr/bin/bash "a shell"
check_absent /bin/bash "a shell"
check_absent /usr/bin/sh "a shell"
check_absent /bin/sh "a shell"
check_absent /usr/bin/dash "a shell"
check_absent /usr/bin/python3 "a language interpreter"
check_absent /usr/bin/python "a language interpreter"
check_absent /usr/bin/perl "a language interpreter"
check_absent /usr/bin/ruby "a language interpreter"
check_absent /usr/bin/php "a language interpreter"
check_absent /usr/lib/systemd/system/sshd.service "SSH"
check_absent /usr/lib/systemd/system/sshd.socket "SSH"

# No unit may invoke a shell or interpreter.
if grep -RInE 'ExecStart(Pre|Post)?=.*(/bin/(ba)?sh|/usr/bin/(ba)?sh|python|perl|ruby|php)' \
        "$config/usr/lib/systemd" 2>/dev/null; then
    echo "FAIL: a systemd unit invokes a shell or interpreter" >&2
    fail=1
fi

# The hardening script must clear SUID/SGID bits.
if ! grep -q 'chmod' "${root}/images/athena/scripts/03-harden.sh" 2>/dev/null; then
    echo "FAIL: 03-harden.sh does not clear SUID/SGID bits" >&2
    fail=1
fi

if (( fail )); then
    echo "hardening verification FAILED" >&2
    exit 1
fi
echo "OK: Athena hardening assertions passed"
