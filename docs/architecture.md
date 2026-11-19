# Architecture

Olympus is a three-image bootc stack. Every image is an OCI image whose rootfs
is a bootable, immutable Linux system; updates are delivered by pulling a new
image and rebooting into it.

```
archlinux:base
      │
      ▼
   Hera  ──────────────────────────┐   sealed Arch TTY base (composefs + verity + signed UKI)
      │                           │
      ├── Athena                  │   hardened kubeadm + KubeStellar server
      │                           │
      └── Apollo                  │   QuickShell + MangoWC Wayland workstation
                                  │
                                  └── multi-stage build → rechunk → seal → cosign → GHCR
```

## Why a shared base?

Hera owns all of the difficult, distribution-specific work:

- pacman's `/var` state is relocated to `/usr/lib/sysimage` so that the system
  survives `bootc usroverlay` (the pattern from `bootcrew/mono` and
  `tartaria-dev/tartaria`).
- The bootc filesystem layout (`/ostree -> /sysroot/ostree`, empty `/var`,
  symlinked `/home`, `/root`, `/opt`, …) is applied once.
- dracut builds a reproducible, host-independent initramfs with the `ostree`
  and `bootc` modules.
- composefs is enabled in `/usr/lib/ostree/prepare-root.conf` and the sysroot is
  declared read-only.

Athena and Apollo therefore only add their own packages, units and config.

## Sealed vs. unsealed builds

Both are produced from the same Containerfiles:

| Mode | Secrets required | Result | Rebaseable? |
| ---- | ---------------- | ------ | ----------- |
| unsealed (`build`) | none | normal bootc image, `bootc switch` works | yes |
| sealed (`build-sealed`) | `secureboot_key`, `secureboot_cert`, cosign key | verity-sealed composefs rootfs + signed UKI | no (ISO/disk install only) |

CI builds the sealed variant only when `SECUREBOOT_KEY`, `SECUREBOOT_CERT` and
`SIGNING_SECRET` are present; otherwise it builds and signs the unsealed variant
and records a note in the workflow summary. See [sealed-composefs.md](sealed-composefs.md).

## Hardening model

Athena follows the seven properties from the
[Amutable Foundations technical overview](https://amutable.com/blog/amutable-foundations-technical-overview)
as far as an Arch-derived bootc image allows:

1. **No shell / SSH / interpreters** — `bash`, `sh`, `python`, `perl`, `sshd`
   and AUR helpers are removed from the final rootfs. All runtime work is done
   by systemd units invoking binaries directly (`ExecStart=` never uses a
   shell). See [athena.md](athena.md).
2. **Signed images only** — cosign signatures use the legacy `.sig` tag so
   `podman`/`bootc`/containers-image policy can verify them.
3. **W^X** — nothing is executed from writable locations; `/usr` is the only
   source of code and is verity-protected in sealed builds.
4. **Everything measured** — SLSA provenance and SPDX SBOM attestations are
   produced for every published image.
5. **No SUID/SGID or file capabilities** — cleared in the final build stage;
   privileges are granted to units via `AmbientCapabilities=` instead.
6. **Integrity is mandatory** — composefs + dm-verity + signed UKI in sealed
   builds, SBOM/vulnerability scanning in all builds.
7. **Factory reset built in** — `systemd-factory-reset` is enabled with a
   reset service that restores `/etc` and `/var` from the image.

Some of these (TPM measurement, remote attestation, confext encryption) are
properties of the Amutable control plane and are out of scope for an OS image;
they are documented as deliberate non-goals rather than silently omitted.

## Dependency policy

`packages/` and `build/` are **copies** of the build patterns from
[hecknt/arch-bootc-pkgs](https://github.com/hecknt/arch-bootc-pkgs). They are
not git submodules and are not fetched at build time. A scheduled workflow
compares them against pinned upstream commits and opens/updates an issue when
they drift. Renovate is configured to leave these directories alone unless a
human reviews the change.

## CI overview

| Workflow | Purpose |
| -------- | ------- |
| `build-{hera,athena,apollo}.yml` | thin per-image callers |
| `reusable-bootc-build.yml` | build → rechunk → optional seal → push → sign → SBOM |
| `reusable-pacman-cache.yml` | reusable pacman package cache |
| `reusable-static-tests.yml` | shellcheck, yamllint, actionlint, config checks |
| `reusable-boot-test.yml` | bcvk/QEMU boot test of a debug variant |
| `upstream-drift.yml` | vendored-pattern drift check + issue |
| `security.yml` | Scorecard, dependency review, Trivy/Grype |
| `tests.yml` | PR gate aggregating the test workflows |

All third-party actions are pinned to full commit SHAs; composite actions from
`projectbluefin/actions` are referenced at `@v1` as recommended by their
consumer guide, with Renovate managing bumps.
