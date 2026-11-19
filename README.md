# Olympus

Mount Olympus is my home for Bootc images.

Olympus is a monorepo of three [bootc](https://github.com/bootc-dev/bootc) images built on Arch Linux:

| Image | Role | Base |
| ----- | ---- | ---- |
| **Hera** | Minimal, sealed Arch base image (TTY only, no desktop) | `archlinux:latest` |
| **Athena** | Hardened Kubernetes/KubeStellar server image | `hera` |
| **Apollo** | QuickShell + MangoWC Wayland workstation image | `hera` |

## Design goals

- **Image-based, drift-free builds.** Packages are installed once at build time, the
  root filesystem is re-chunked, and (when signing secrets are configured) the
  composefs rootfs is verity-sealed into a Secure-Boot-signed UKI, following the
  pattern used by [Tartaria](https://github.com/tartaria-dev/tartaria).
- **Reproducible Arch packaging.** The package build patterns are copied from
  [hecknt/arch-bootc-pkgs](https://github.com/hecknt/arch-bootc-pkgs) into this
  repository (see [`packages/`](packages/)), not pulled in as a runtime dependency.
  A scheduled drift check opens an issue when those copies diverge from upstream.
- **No shell on the server.** Athena follows the
  [Amutable Foundations](https://amutable.com/blog/amutable-foundations-technical-overview)
  security principles: no shell, no SSH, no language interpreters, no SUID/SGID
  binaries, signed images only, W^X-friendly `/usr`, and factory-reset support.
- **Automated everything.** Renovate keeps dependencies fresh; reusable GitHub
  Actions workflows handle builds, chunking, signing, pacman caching, static
  tests, boot tests, and KubeStellar checks.

> **Note:** Quickshell configuration is intentionally *not* included yet. Apollo
> ships the Quickshell binary and a launch hook only; a personal config will be
> ported in later.

## Repository layout

```
.
├── images/                 # Containerfiles, configs and scripts per image
│   ├── hera/               # sealed Arch TTY base
│   ├── athena/             # KubeStellar server (hardened, shell-less)
│   └── apollo/             # QuickShell + MangoWC workstation
├── packages/               # copied arch-bootc-pkgs PKGBUILD build patterns
├── build/                  # vendored makepkg/signed-repo build action
├── scripts/                # build, verification and drift-check helpers
├── tests/                  # static, boot and KubeStellar test suites
└── .github/
    ├── actions/            # local composite actions
    └── workflows/          # reusable + image-specific workflows
```

## Quick start

```sh
just --list                       # all available recipes
just build hera                   # build an image locally (podman)
just test-static                  # run the static test suite
just test-boot hera               # boot test via bcvk (needs root + KVM)
just lint                         # shellcheck, yamllint, bootc container lint
```

See [`docs/`](docs/) for the architecture, sealing model, and testing details.

## License

Apache-2.0. See [LICENSE](LICENSE).
