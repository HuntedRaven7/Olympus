#!/usr/bin/env bash
# Static test entry point. Safe to run from anywhere.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

echo "==> lint"
./scripts/lint.sh

echo "==> hardening assertions"
./scripts/verify-hardening.sh

echo "==> upstream pin checks"
./scripts/check-upstream-drift.sh --check-only

echo "==> python assertions"
if python3 -c 'import pytest, yaml' 2>/dev/null; then
    python3 -m pytest -q tests/static
else
    python3 tests/static/test_repo.py
fi

echo "OK: static tests passed"
