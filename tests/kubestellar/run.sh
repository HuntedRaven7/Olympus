#!/usr/bin/env bash
# Verify the KubeStellar control plane in a booted Athena debug image.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$root"

ref="localhost/athena:latest"

if ! command -v bcvk >/dev/null 2>&1; then
    echo "bcvk is required for KubeStellar checks" >&2
    exit 1
fi

run() {
    bcvk ephemeral run-ssh "$ref" -- env KUBECONFIG=/var/lib/athena/admin.conf "$@"
}

echo "==> checking systemd units"
run systemctl is-active athena-kubeadm-init.service
run systemctl is-active athena-kubestellar-apply.service

echo "==> checking KubeFlex CRDs"
run kubectl wait --for=condition=Established \
    crd/controlplanes.tenancy.kflex.kubestellar.org --timeout=5m

echo "==> checking namespaces"
run kubectl get namespace kubeflex-system
run kubectl get namespace kubestellar-console

echo "==> checking deployments"
run kubectl rollout status -n kubeflex-system deployment/kubeflex-controller-manager --timeout=5m
run kubectl rollout status -n kubestellar-console deployment/kubestellar-console --timeout=5m

echo "OK: KubeStellar checks passed"
