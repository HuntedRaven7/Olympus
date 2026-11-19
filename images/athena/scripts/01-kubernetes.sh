#!/usr/bin/env bash
# Configure containerd, kernel settings and the one-shot kubeadm init unit.
set -euo pipefail

echo "::group::Configure Kubernetes"

# containerd must use systemd cgroup driver to match kubelet.
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Required sysctls and modules for kube-proxy / CNI.
mkdir -p /usr/lib/sysctl.d /usr/lib/modules-load.d
cat > /usr/lib/sysctl.d/99-kubernetes.conf <<'EOF'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
cat > /usr/lib/modules-load.d/kubeadm.conf <<'EOF'
br_netfilter
overlay
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack
EOF

systemctl enable containerd.service kubelet.service
systemctl enable athena-kubeadm-init.service
systemctl enable athena-kubestellar-apply.service
systemctl enable athena-reset.service

echo "::endgroup::"
