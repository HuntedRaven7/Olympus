#!/usr/bin/env bash
# Install Kubernetes/KubeStellar tooling from the official Arch repositories.
# shellcheck source=/dev/null
source /hera-scripts/lib.sh
set -euo pipefail

mkdir -p /sysroot
ln -sT sysroot/ostree /ostree

echo "::group::Install Athena packages"

retry pacman -Syu --noconfirm --needed

retry pacman -S --noconfirm --needed \
    containerd \
    etcd \
    kubeadm \
    kubelet \
    kubectl \
    cni-plugins \
    helm \
    socat \
    conntrack-tools \
    ebtables \
    ipset \
    bash-completion \
    curl \
    jq \
    openssl

find /etc -name '*.pacnew' -type f -delete

echo "::endgroup::"
