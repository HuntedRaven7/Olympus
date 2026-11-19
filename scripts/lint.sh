#!/usr/bin/env bash
# Lint all scripts, workflows and Containerfiles in the repository.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
rc=0

if command -v shellcheck >/dev/null 2>&1; then
    while IFS= read -r -d '' script; do
        if ! shellcheck -x "$script"; then rc=1; fi
    done < <(find . -path ./.git -prune -o -type f -name '*.sh' -print0)
else
    echo "::warning::shellcheck not installed — skipping" >&2
fi

while IFS= read -r -d '' script; do
    if ! bash -n "$script"; then rc=1; fi
done < <(find . -path ./.git -prune -o -type f -name '*.sh' -print0)

if command -v yamllint >/dev/null 2>&1; then
    if [[ -f .yamllint.yml ]]; then
        yamllint -c .yamllint.yml .github images || rc=1
    else
        yamllint .github images || rc=1
    fi
else
    echo "::warning::yamllint not installed — skipping" >&2
fi

if command -v actionlint >/dev/null 2>&1; then
    actionlint -color || rc=1
else
    echo "::warning::actionlint not installed — skipping" >&2
fi

echo "lint result: ${rc}"
exit "$rc"
