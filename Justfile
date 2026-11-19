# Olympus — bootc image build recipes
#
# Requires: podman (rootful), just, shellcheck, yamllint (see docs/testing.md).
# All recipes are safe to run from the repository root.

set shell := ["bash", "-euo", "pipefail", "-c"]

repo_root := justfile_directory()
images_dir := repo_root + "/images"
registry := env("REGISTRY", "ghcr.io/" + env("GITHUB_REPOSITORY_OWNER", "huntedraven7"))
image_tag := env("IMAGE_TAG", "latest")
base_image := env("BASE_IMAGE", "localhost/hera:latest")
bootc_repo_url := env("BOOTC_REPO_URL", "https://github.com/hecknt/arch-bootc-pkgs/releases/download/$repo")
bootc_repo_key := env("BOOTC_REPO_KEY", "5DE6BF3EBC86402E7A5C5D241FA48C960F9604CB")

# List available recipes
default:
    @just --list

# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

# Build the base rootfs of an image (hera, athena or apollo)
build image="hera":
    #!/usr/bin/env bash
    set -euo pipefail
    cf="{{ images_dir }}/{{ image }}/Containerfile"
    test -f "$cf" || { echo "no Containerfile at $cf" >&2; exit 1; }
    mkdir -p "{{ repo_root }}/.cache/pacman"
    sudo podman build \
        --target base \
        --build-arg BOOTC_REPO_URL='{{ bootc_repo_url }}' \
        --build-arg BOOTC_REPO_KEY='{{ bootc_repo_key }}' \
        --build-arg BASE_IMAGE='{{ base_image }}' \
        --build-arg IMAGE_NAME='{{ image }}' \
        --build-arg IMAGE_VARIANT='{{ image_tag }}' \
        --build-arg WITH_TEST_TOOLS='{{ if env("WITH_TEST_TOOLS", "") != "" { env("WITH_TEST_TOOLS") } else { "false" } }}' \
        --security-opt label=disable \
        -f "$cf" \
        -t "localhost/{{ image }}:{{ image_tag }}" .

# Build the sealed (split kernel + verity + signed UKI) variant of Hera.
# Requires SECUREBOOT_KEY / SECUREBOOT_CERT env vars pointing at PEM files.
build-sealed image="hera":
    #!/usr/bin/env bash
    set -euo pipefail
    : "${SECUREBOOT_KEY:?SECUREBOOT_KEY must point to a PEM private key}"
    : "${SECUREBOOT_CERT:?SECUREBOOT_CERT must point to a PEM certificate}"
    just build "{{ image }}"
    sudo podman build \
        --target split-kernel \
        --build-arg BOOTC_REPO_URL='{{ bootc_repo_url }}' \
        --build-arg BOOTC_REPO_KEY='{{ bootc_repo_key }}' \
        -f "{{ images_dir }}/{{ image }}/Containerfile" \
        -t "localhost/{{ image }}-split:{{ image_tag }}" .
    sudo podman build \
        --target chunkah \
        --build-arg BOOTC_REPO_URL='{{ bootc_repo_url }}' \
        --build-arg BOOTC_REPO_KEY='{{ bootc_repo_key }}' \
        -v "{{ repo_root }}:/src" \
        --security-opt label=disable \
        -f "{{ images_dir }}/{{ image }}/Containerfile" \
        -t "localhost/{{ image }}-chunked:{{ image_tag }}" .
    sudo podman build \
        -f "{{ images_dir }}/{{ image }}/Containerfile.seal-finalize" \
        --build-arg BASE_IMAGE="localhost/{{ image }}:{{ image_tag }}" \
        --build-arg SPLITKERNEL_IMAGE="localhost/{{ image }}-split:{{ image_tag }}" \
        --secret id=secureboot_key,src="${SECUREBOOT_KEY}" \
        --secret id=secureboot_cert,src="${SECUREBOOT_CERT}" \
        --security-opt label=disable \
        -t "localhost/{{ image }}:{{ image_tag }}-sealed" .

# Rechunk an image using chunkah (OCI-native, like projectbluefin/actions chunka)
rechunk image="hera":
    #!/usr/bin/env bash
    set -euo pipefail
    cfg=$(sudo podman inspect "localhost/{{ image }}:{{ image_tag }}" | jq -c '.[0].Config')
    sudo podman run --rm \
        --mount="type=image,src=localhost/{{ image }}:{{ image_tag }},target=/chunkah" \
        -e "CHUNKAH_CONFIG_STR=${cfg}" \
        quay.io/coreos/chunkah:v0.6.0 \
        build --max-layers 128 --prune /ostree --prune /sysroot/ostree \
        | sudo podman load

# Run a bootc subcommand inside an image (e.g. `just bootc hera install to-disk …`)
bootc image="hera" *args:
    sudo podman run \
        --rm --privileged --pid=host -it \
        -v /dev:/dev \
        -v /var/lib/containers:/var/lib/containers \
        -v "{{ repo_root }}:/data" \
        --security-opt label=disable \
        "localhost/{{ image }}:{{ image_tag }}" bootc {{ args }}

# Run `bootc container lint` against a built image
lint-container image="hera":
    sudo podman run --rm "localhost/{{ image }}:{{ image_tag }}" bootc container lint

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

# Static checks: shellcheck, yamllint, actionlint, config and hardening assertions
test-static:
    ./tests/static/run.sh

# Boot tests via bcvk (requires root and KVM)
test-boot image="hera":
    ./tests/boot/run.sh "{{ image }}"

# KubeStellar service checks against a booted Athena debug image
test-kubestellar:
    ./tests/kubestellar/run.sh

# Everything that can run without a VM
check: lint test-static

# ---------------------------------------------------------------------------
# Linting & upstream drift
# ---------------------------------------------------------------------------

# Lint all shell scripts, workflows and Containerfiles
lint:
    ./scripts/lint.sh

# Compare copied build patterns with upstream and report drift
drift-check:
    ./scripts/check-upstream-drift.sh --check-only

# Generate throwaway Secure Boot keys for local sealed builds (NOT for production)
gen-dev-keys:
    ./scripts/gen-dev-keys.sh
