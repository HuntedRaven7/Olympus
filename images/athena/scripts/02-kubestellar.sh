#!/usr/bin/env bash
# Install the pinned KubeStellar chart values applied by systemd units.
set -euo pipefail

echo "::group::Install KubeStellar manifests"

mkdir -p /usr/share/athena/kubestellar /etc/athena
chmod 0755 /usr/share/athena/kubestellar

# The systemd unit reads these values; no shell is needed at runtime. The
# version pins are commented for Renovate (see renovate.json5).
cat > /usr/share/athena/kubestellar/versions.env <<'EOF'
# renovate: datasource=helm depName=core-chart registryUrl=https://ghcr.io/kubestellar/kubestellar
KUBESTELLAR_CORE_VERSION=0.30.0
# renovate: datasource=helm depName=kubestellar-console registryUrl=https://ghcr.io/kubestellar/charts
KUBESTELLAR_CONSOLE_VERSION=0.3.42
EOF
chmod 0444 /usr/share/athena/kubestellar/versions.env

echo "::endgroup::"
