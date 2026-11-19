#!/usr/bin/env bash
# Generate throwaway Secure Boot + cosign keys for local sealed builds.
# NEVER use these keys in production.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
outdir="${root}/.drift"
mkdir -p "$outdir"

if [[ -f "$outdir/secureboot.key" ]]; then
    echo "development keys already exist in $outdir" >&2
    exit 1
fi

openssl req -new -x509 -newkey rsa:2048 -nodes \
    -keyout "$outdir/secureboot.key" \
    -out "$outdir/secureboot.crt" \
    -days 365 -subj "/CN=Olympus Dev Secure Boot/"

if command -v cosign >/dev/null 2>&1; then
    (
        cd "$outdir"
        export COSIGN_PASSWORD=""
        cosign generate-key-pair
    )
fi

cat <<EOF
Development keys written to ${outdir} (git-ignored).
Use them with:

    SECUREBOOT_KEY=${outdir}/secureboot.key \\
    SECUREBOOT_CERT=${outdir}/secureboot.crt \\
    just build-sealed hera
EOF
