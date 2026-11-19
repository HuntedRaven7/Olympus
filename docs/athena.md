# Athena

Athena is the server image. It derives from Hera and adds a single-node
**kubeadm** control plane plus **KubeStellar** (KubeFlex, ITS/WDS control planes,
the KubeStellar Console and the OCM transport controller), following the design
of [projectbluefin/server](https://github.com/projectbluefin/server) but adapted
to an Arch bootc image.

## Hardening

Athena applies the Amutable server principles aggressively:

| Principle | Implementation |
| --------- | -------------- |
| No shell | `/bin/sh`, `/bin/bash`, `dash`, `zsh` removed in `03-harden.sh` |
| No SSH | `openssh` never installed; `sshd.socket`/`sshd.service` masked |
| No interpreters | `python`, `python3`, `perl`, `ruby`, `php`, `lua`, `jq` removed (Go binaries kept) |
| No SUID/SGID/caps | `find / -perm /6000` bits cleared in `03-harden.sh`; capabilities stripped from files |
| Signed images only | cosign via `projectbluefin/actions` `sign-and-publish`, legacy `.sig` tags |
| W^X | all executables live under `/usr`; `/var`, `/etc` mounted `noexec` where possible |
| Everything measured | SLSA provenance + SPDX SBOM attestations |
| Integrity | sealed Hera base + dm-verity + signed UKI |
| Factory reset | `systemd-factory-reset` enabled, `athena-reset.service` provided |

Because there is no shell, **all** runtime logic is expressed as systemd units
with absolute `ExecStart=` binaries — no `ExecStartPre=/bin/sh -c …`, no
`RunExecutable` scripts written in shell. KubeStellar manifests are applied by
`kubectl`/`helm` directly from unit directives.

> The boot-test workflow builds a *debug variant* (`tests/boot/Containerfile.athena-debug`)
> that adds `bash` and `openssh` purely so the test harness can run `systemctl
> --failed`. That variant is never published. Static tests assert the real
> image has no shell or SSH.

## Kubernetes layout

- `kubeadm`, `kubelet`, `kubectl`, `containerd`, `cni-plugins`, `cri-tools`, `etcd`
  are installed through a temporary AUR build stage; the helper is deleted afterwards.
- `athena-kubeadm-init.service` runs `kubeadm init` once using
  `config/etc/kubernetes/kubeadm-init.yaml`, then installs `admin.conf` into
  `/etc/kubernetes` with the `install` binary.
- `athena-kubestellar-apply.service` waits for the API, applies the KubeFlex
  CRDs, then `helm upgrade --install`s the pinned KubeStellar core and console
  charts from `config/usr/share/athena/kubestellar/`.
- Chart/container references are pinned by digest, as in Bluefin Server.

Set the cluster domain via `/etc/athena/kubestellar.conf` (a confext in a
production deployment). No cluster-specific state is baked into the image.

## Verification

```sh
just test-kubestellar      # boots the debug variant, checks units + CRDs + pods
./scripts/verify-hardening.sh images/athena/config   # static assertions
```
