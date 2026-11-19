#!/usr/bin/env python3
"""Structural assertions for the Olympus repository.

Runs under pytest when available, otherwise as a plain script
(`python3 tests/static/test_repo.py`). No external dependencies are required.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMAGES = ("hera", "athena", "apollo")


def _read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def _exists(path: str) -> bool:
    return (ROOT / path).exists()


def test_every_workflow_is_valid_yaml_and_has_jobs() -> None:
    try:
        import yaml  # type: ignore
    except ImportError:
        print("SKIP: PyYAML not installed")
        return
    for workflow in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
        with workflow.open(encoding="utf-8") as fh:
            data = yaml.safe_load(fh)
        assert isinstance(data, dict), workflow
        assert "name" in data, workflow
        assert "on" in data or True in data, workflow
        assert "jobs" in data, workflow


def test_local_action_references_exist() -> None:
    for workflow in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
        for match in re.finditer(r"uses:\s*(\./[^\s]+)", workflow.read_text()):
            ref = match.group(1).split("@")[0]
            assert _exists(ref[2:] if ref.startswith("./") else ref), (
                f"{workflow}: missing local action {ref}"
            )


def test_no_secret_in_if_expression() -> None:
    for workflow in sorted((ROOT / ".github" / "workflows").glob("*.yml")):
        for number, line in enumerate(workflow.read_text().splitlines(), 1):
            if "if:" in line and "secrets." in line:
                raise AssertionError(f"{workflow}:{number}: secret in if: condition")


def test_containerfiles_present() -> None:
    for image in IMAGES:
        assert _exists(f"images/{image}/Containerfile"), image
        content = _read(f"images/{image}/Containerfile")
        assert "FROM" in content, image
        assert "bootc container lint" in content, image
    assert _exists("images/hera/Containerfile.seal-finalize")


def test_hera_seal_pipeline() -> None:
    content = _read("images/hera/Containerfile")
    assert "--target base" not in content  # stages are named, not targeted here
    assert "FROM base AS split-kernel" in content
    assert "split-kernel-and-rootfs" in content
    assert "FROM quay.io/coreos/chunkah" in content
    finalize = _read("images/hera/Containerfile.seal-finalize")
    assert "secureboot_key" in finalize and "secureboot_cert" in finalize
    assert "bootc container ukify" in _read("images/hera/scripts/03-ukify.sh")


def test_hera_composefs_config() -> None:
    content = _read("images/hera/config/usr/lib/ostree/prepare-root.conf")
    assert "[composefs]" in content and "enabled = yes" in content
    assert "[sysroot]" in content and "readonly = true" in content


def test_athena_derives_from_hera() -> None:
    for image in ("athena", "apollo"):
        content = _read(f"images/{image}/Containerfile")
        assert "ARG BASE_IMAGE=localhost/hera:latest" in content


def test_athena_hardening() -> None:
    script = _read("images/athena/scripts/03-harden.sh")
    for binary in ("bash", "sh", "python3", "perl", "sshd"):
        assert binary in script, binary
    assert "chmod a-s" in script
    assert "setcap -r" in script
    unit = _read(
        "images/athena/config/usr/lib/systemd/system/athena-kubestellar-apply.service"
    )
    assert "helm upgrade --install" in unit
    assert "kubestellar" in unit


def test_apollo_has_no_quickshell_config() -> None:
    qml = list((ROOT / "images/apollo").rglob("*.qml"))
    assert not qml, qml
    assert _exists("images/apollo/config/usr/lib/systemd/user/quickshell.service")
    assert "ExecStart=/usr/bin/quickshell" in _read(
        "images/apollo/config/usr/lib/systemd/user/quickshell.service"
    )


def test_vendored_patterns_pinned() -> None:
    lines = [
        line for line in _read("scripts/upstream-pins.env").splitlines()
        if line and not line.startswith("#")
    ]
    assert len(lines) >= 6
    for line in lines:
        parts = line.split("|")
        assert len(parts) == 4, line
        assert _exists(parts[0]), parts[0]
        assert parts[1].startswith("https://raw.githubusercontent.com/")
        assert re.fullmatch(r"[0-9a-f]{40}", parts[2]), line


def test_bluefin_actions_used() -> None:
    build = _read(".github/workflows/reusable-bootc-build.yml")
    for action in ("chunka", "sign-and-publish", "scan-image"):
        assert f"projectbluefin/actions/bootc-build/{action}@v1" in build, action
    security = _read(".github/workflows/security.yml")
    assert "reusable-pinned-fetches.yml@v1" in security
    assert "reusable-vulnerability-scan.yml@v1" in security


def test_renovate_config_basics() -> None:
    text = _read("renovate.json5")
    assert "$schema" in text
    assert "customManagers" in text
    assert "PKGBUILD" in text


def test_build_workflows_wire_everything_together() -> None:
    for image in IMAGES:
        workflow = _read(f".github/workflows/build-{image}.yml")
        assert "reusable-pacman-cache.yml" in workflow, image
        assert "mode: restore" in workflow and "mode: save" in workflow, image
        assert "reusable-bootc-build.yml" in workflow, image
        assert "reusable-boot-test.yml" in workflow, image
        assert "secrets: inherit" in workflow, image

    cache = _read(".github/workflows/reusable-pacman-cache.yml")
    assert "actions/cache/restore" in cache
    assert "actions/cache/save" in cache
    build = _read(".github/workflows/reusable-bootc-build.yml")
    assert "pacman-cache-updated-" in build


def test_security_workflows() -> None:
    security = _read(".github/workflows/security.yml")
    assert "scorecard-action" in security
    assert "dependency-review-action" in security


def test_scripts_are_executable() -> None:
    import os
    import stat
    for path in (
        "tests/static/run.sh",
        "tests/boot/run.sh",
        "tests/kubestellar/run.sh",
        "scripts/check-upstream-drift.sh",
        "scripts/lint.sh",
        "scripts/verify-hardening.sh",
    ):
        mode = os.stat(ROOT / path).st_mode
        assert mode & stat.S_IXUSR, path


def test_readme_overview() -> None:
    readme = _read("README.md")
    for image in ("Hera", "Athena", "Apollo"):
        assert image in readme


def main() -> int:
    tests = [value for key, value in sorted(globals().items()) if key.startswith("test_")]
    failed = 0
    for test in tests:
        try:
            test()
            print(f"PASS {test.__name__}")
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"FAIL {test.__name__}: {exc}", file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
