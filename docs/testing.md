# Testing

Tests are split into three tiers. All are run in CI; the first two also run
locally.

## 1. Static tests (`just test-static`)

`tests/static/run.sh` checks:

- every workflow and action YAML parses and passes `actionlint`
- every shell script passes `shellcheck` and `bash -n`
- every Containerfile references only files that exist and uses pinned base images
- `renovate.json5` parses as JSON5
- the vendored `packages/` and `build/` files match the pinned upstream hashes
  recorded in `scripts/upstream-pins.env`
- Hera's `prepare-root.conf`, dracut configs and kargs are present
- Athena's config contains **no** shell interpreters, SSH units, or
  `ExecStart` lines invoking `/bin/sh` (`scripts/verify-hardening.sh`)
- Apollo contains **no** Quickshell QML configuration files
- each image's Containerfile is based on Hera where required

## 2. Boot tests (`just test-boot <image>`)

Uses [bcvk](https://github.com/bootc-dev/bcvk) to install an image to an
ephemeral VM and verify that no systemd units fail. Because Athena has no shell
or SSH, the test builds a debug variant with `bash` + `openssh` added (never
published) and asserts:

- the VM boots to `multi-user.target`
- `systemctl --failed` is empty
- Hera has a getty on `tty1` and no `sshd`
- Apollo reaches `graphical.target` with greetd and MangoWC units active

Requires root, KVM, podman and `bcvk`.

## 3. KubeStellar checks (`just test-kubestellar`)

Boots the Athena debug variant and verifies:

- `athena-kubeadm-init.service` and `athena-kubestellar-apply.service` are active
- the KubeFlex CRDs are established
- the `kubestellar-console` and `kubeflex-system` namespaces exist
- required deployments are available

These run on a scheduled workflow (`tests.yml`, `workflow_dispatch` + nightly)
because they need a nested container runtime and take several minutes.

## CI gates

Pull requests must pass `tests.yml` (static + boot for all three images).
Pushes to `main` additionally build, sign and publish the images via
`reusable-bootc-build.yml`, then run the `security.yml` scans.

## Adding a test

1. Put the check in the appropriate `tests/<tier>/` directory.
2. Export a function or a standalone script with a non-zero exit on failure.
3. Wire it into `tests/static/run.sh` / `tests/boot/run.sh` /
   `tests/kubestellar/run.sh` and add a `just` recipe if users need it locally.
