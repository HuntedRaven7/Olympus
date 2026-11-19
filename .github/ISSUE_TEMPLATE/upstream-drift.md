---
name: Upstream drift
about: Internal — created/updated by the upstream drift workflow
title: "Vendored build patterns drifted from upstream"
labels: upstream-drift, dependencies
assignees: ""
---

This issue is managed by `.github/workflows/upstream-drift.yml`. It is opened
or updated automatically when the copied files in `build/` and `packages/`
differ from the pinned upstream sources in `scripts/upstream-pins.env`.

Do not close it manually unless the drift has been reviewed and resolved.
