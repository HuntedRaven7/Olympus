#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2094  # literal backticks in markdown + section file reuse
# Compare vendored build patterns against their upstream sources.
# Detects both upstream commits that moved past the pinned SHA and content
# differences against the local copy. In CI (GITHUB_TOKEN set) creates or
# updates an issue describing the drift.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
pins="${root}/scripts/upstream-pins.env"
report="${TMPDIR:-/tmp}/olympus-drift-report.md"
check_only=0

usage() { echo "usage: $0 [--check-only] [--report FILE]" >&2; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check-only) check_only=1; shift ;;
        --report) report="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage; exit 2 ;;
    esac
done

mapfile -t entries < <(grep -vE '^[[:space:]]*(#|$)' "$pins" || true)
if (( ${#entries[@]} == 0 )); then
    echo "no drift entries found in $pins" >&2
    exit 1
fi

# Validate the pins file and that every local copy exists.
for entry in "${entries[@]}"; do
    IFS='|' read -r local_path url pinned note <<<"$entry"
    if [[ -z "$local_path" || -z "$url" || ! "$pinned" =~ ^[0-9a-f]{40}$ ]]; then
        echo "malformed drift entry: $entry" >&2
        exit 1
    fi
    if [[ ! -f "${root}/${local_path}" ]]; then
        echo "missing vendored file: $local_path" >&2
        exit 1
    fi
done

if (( check_only )); then
    echo "OK: ${#entries[@]} vendored file(s) pinned and present"
    exit 0
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

api_headers=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    api_headers=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

# Extract owner/repo/path from a raw.githubusercontent.com URL.
parse_url() {
    local url="$1"
    local rest="${url#https://raw.githubusercontent.com/}"
    owner="${rest%%/*}"
    rest="${rest#*/}"
    repo="${rest%%/*}"
    rest="${rest#*/}"
    # Drop the branch component (main, master, …).
    path="${rest#*/}"
}

drift=0
: > "$report"

for entry in "${entries[@]}"; do
    IFS='|' read -r local_path url pinned note <<<"$entry"
    parse_url "$url"
    api="https://api.github.com/repos/${owner}/${repo}/commits?path=${path}&per_page=1"
    api_response="${tmpdir}/commits.json"
    if ! curl --no-progress-meter -fsSL --retry 3 "${api_headers[@]}" "$api" \
            -o "$api_response"; then
        echo "::warning::could not query $api"
        api_response=""
    fi
    latest=""
    if [[ -n "$api_response" ]]; then
        latest=$(grep -m1 -oP '"sha":\s*"\K[0-9a-f]{40}' "$api_response" || true)
    fi

    section="${tmpdir}/section.md"
    : > "$section"
    moved=0
    if [[ -n "$latest" && "$latest" != "$pinned" ]]; then
        moved=1
        printf '## `%s`\n\nUpstream moved from `%s` to `%s` (%s).\n\n' \
            "$local_path" "$pinned" "$latest" "$note" >> "$section"
    fi

    upstream="${tmpdir}/$(echo "${local_path}" | tr '/' '_')"
    if [[ -n "$latest" ]]; then
        raw="https://raw.githubusercontent.com/${owner}/${repo}/${latest}/${path}"
    else
        raw="$url"
    fi
    if ! curl --no-progress-meter -fsSL --retry 3 "$raw" -o "$upstream"; then
        echo "::warning::could not fetch $raw"
        continue
    fi
    if ! diff -u "$upstream" "${root}/${local_path}" > "${tmpdir}/diff" 2>&1; then
        moved=1
        {
            [[ -s "$section" ]] || printf '## `%s`\n\nSource: %s (%s)\n\n' \
                "$local_path" "$raw" "$note" >> "$section"
            echo '```diff'
            cat "${tmpdir}/diff"
            echo '```'
            echo
        } >> "$section"
    fi

    if (( moved )); then
        drift=1
        cat "$section" >> "$report"
    fi
done

if (( drift == 0 )); then
    rm -f "$report"
    echo "OK: vendored files match pinned upstream sources"
    exit 0
fi

{
    echo "# Vendored build patterns have drifted from upstream"
    echo
    echo "Compare the copies in \`build/\` and \`packages/\` with the current"
    echo "upstream content recorded in \`scripts/upstream-pins.env\` before"
    echo "accepting any Renovate update."
    echo
    cat "$report"
} > "${report}.final"
mv "${report}.final" "$report"
cat "$report"

if [[ -n "${GITHUB_TOKEN:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
    export GH_TOKEN="${GITHUB_TOKEN}"
    issue=$(gh issue list --repo "$GITHUB_REPOSITORY" --label upstream-drift \
        --state open --limit 1 --json number --jq '.[0].number' 2>/dev/null || true)
    if [[ -n "$issue" ]]; then
        gh issue edit "$issue" --repo "$GITHUB_REPOSITORY" --body-file "$report"
        echo "updated issue #${issue}"
    else
        gh issue create --repo "$GITHUB_REPOSITORY" --label upstream-drift \
            --title "Vendored build patterns drifted from upstream" \
            --body-file "$report"
    fi
fi

exit 1
