---
name: Wire up CI workflows and dynamic release notes
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Auth
labels: ["chore", "tier-1", "adr-0009"]
dependencies: []
adrs: ["ADR-0009"]
wave: "N/A"
initiative: adr-0009-package-scanning-rollout
node: honeydrunk-auth
version_bump: false
---

# Chore: Wire up CI workflows and dynamic release notes

## Summary

Create CI workflow files and migrate GitHub Release notes from static templates to changelog-driven generation in `HoneyDrunk.Auth`. No application code changes. No version bump.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Auth`

## Motivation

ADR-0009 establishes the package scanning policy for the Grid. `HoneyDrunk.Actions` already provides the reusable workflows (`pr-core.yml`, `nightly-security.yml`, `nightly-deps.yml`) and the `release/generate-notes` composite action. This packet wires them up in `HoneyDrunk.Auth` and replaces the static release-note template in `publish.yml` with auto-discovered changelog extraction.

## Files to Create

### `.github/workflows/pr.yml`

```yaml
name: PR

on:
  pull_request:
    branches: [ main ]

jobs:
  pr-core:
    name: PR Core
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/pr-core.yml@main
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

### `.github/workflows/nightly-security.yml`

```yaml
name: Nightly Security

on:
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:

jobs:
  nightly-security:
    name: Nightly Security
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/nightly-security.yml@main
    with:
      enable-sast: true
      enable-iac-scan: true
      enable-secret-scan: true
      create-issues: true
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

### `.github/workflows/nightly-deps.yml`

```yaml
name: Nightly Dependencies

on:
  schedule:
    - cron: '0 3 * * 1'
  workflow_dispatch:

jobs:
  nightly-deps:
    name: Nightly Dependencies
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/nightly-deps.yml@main
    with:
      check-dotnet-deps: true
      create-update-prs: false
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

### `.github/workflows/hive-field-mirror.yml`

```yaml
name: Hive Field Mirror

on:
  issues:
    types: [opened, labeled, unlabeled, edited]

jobs:
  mirror:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/hive-field-mirror.yml@main
    secrets:
      hive-field-mirror-token: ${{ secrets.HIVE_FIELD_MIRROR_TOKEN }}
```

## Files to Modify

### `.github/workflows/publish.yml` — Replace static release body with `generate-notes`

Replace the `github-release` job steps with changelog-driven generation. The `generate-notes` action auto-discovers the repo-level `CHANGELOG.md` next to the `.slnx` file and produces release notes with changelog entries, NuGet install blocks, and comparison links.

**Replace the `github-release` job steps with:**

```yaml
  github-release:
    name: Create GitHub Release
    needs: [prepare, release]
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Checkout Actions
        uses: actions/checkout@v4
        with:
          repository: HoneyDrunkStudios/HoneyDrunk.Actions
          ref: main
          path: .actions

      - name: Generate Release Notes
        id: notes
        uses: ./.actions/.github/actions/release/generate-notes
        with:
          version: ${{ needs.prepare.outputs.version }}
          product-name: HoneyDrunk.Auth
          product-description: 'Authentication and authorization library for .NET with JWT validation and policy-based authorization.'
          nuget-packages: |
            HoneyDrunk.Auth.Abstractions
            HoneyDrunk.Auth
            HoneyDrunk.Auth.AspNetCore
          docs-url: 'https://github.com/HoneyDrunkStudios/HoneyDrunk.Auth#readme'

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ needs.prepare.outputs.version-tag }}
          name: HoneyDrunk.Auth ${{ needs.prepare.outputs.version-tag }}
          body: ${{ steps.notes.outputs.body }}
          generate_release_notes: ${{ steps.notes.outputs.has-changelog == 'false' }}
          draft: false
          prerelease: false
```

## Acceptance Criteria

- [ ] `.github/workflows/pr.yml` exists and calls `pr-core.yml@main`
- [ ] `.github/workflows/nightly-security.yml` exists and calls `nightly-security.yml@main`
- [ ] `.github/workflows/nightly-deps.yml` exists and calls `nightly-deps.yml@main`
- [ ] `.github/workflows/hive-field-mirror.yml` exists and calls `hive-field-mirror.yml@main`
- [ ] `.github/workflows/publish.yml` `github-release` job uses `generate-notes` action instead of static body
- [ ] All workflow files are valid YAML (no syntax errors)
- [ ] Repo-level `CHANGELOG.md` exists next to the `.slnx` file (already created)

## Dependencies

None.

## Agent Handoff

**Objective:** Create four GitHub Actions workflow files and update `publish.yml` release notes generation. No application code changes required.
**Target:** HoneyDrunk.Auth, branch from `main`
**ADRs:** ADR-0009

**Constraints:**
- Create the four new workflow files
- Modify only the `github-release` job in `publish.yml` — do not change build/pack/publish jobs
- Do not add any NuGet packages or project references
- Do not bump the version

**Key Files:**
- New: `.github/workflows/pr.yml`
- New: `.github/workflows/nightly-security.yml`
- New: `.github/workflows/nightly-deps.yml`
- New: `.github/workflows/hive-field-mirror.yml`
- Modified: `.github/workflows/publish.yml`