# Vendored bootc packages

These PKGBUILDs are **copies** of the build patterns in
[hecknt/arch-bootc-pkgs](https://github.com/hecknt/arch-bootc-pkgs) (pinned in
`../scripts/upstream-pins.env`). They are deliberately vendored, not pulled in
as a submodule, so this repository is self-contained and reproducible.

`../build/` contains the copied `makepkg` → signed pacman repository build
action that consumes `pkgs/` (here: `packages/`). Its output is published as a
GitHub Release named `bootc`, exactly as upstream does. Hera can then consume
it with:

```ini
[bootc]
SigLevel = Required
Server = https://github.com/HuntedRaven7/Olympus/releases/download/bootc
```

## Files

| Package | Origin | Notes |
| ------- | ------ | ----- |
| `bootc/` | upstream `pkgs/bootc` | `cargo` build with `--no-default-features --features install-to-disk` (Arch has no libselinux) |
| `bootupd/` | upstream `pkgs/bootupd` | `prepare()` applies the Fedora→Arch GRUB path fixes inline with `sed` |
| `uupd/` | upstream `pkgs/uupd` | Go binary + systemd unit/timer + polkit rule |
| `shim-signed/` | upstream AUR submodule | vendored PKGBUILD that builds shim from source; keep in sync with the AUR package |

## Drift tracking

`../scripts/check-upstream-drift.sh` compares these files to the pinned upstream
commits and opens/updates a GitHub issue when they differ. Never run Renovate
automerge on changes here — a human must review the diff first.
