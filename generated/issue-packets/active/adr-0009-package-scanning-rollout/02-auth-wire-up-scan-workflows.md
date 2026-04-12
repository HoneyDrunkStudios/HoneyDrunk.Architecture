---
name: Wire up PR validation and nightly scan workflows
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

# Chore: Wire up PR validation and nightly scan workflows

## Summary

Create three GitHub Actions consumer workflow files in `HoneyDrunk.Auth`. No code changes. No version bump.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Auth`

## Motivation

ADR-0009 establishes the package scanning policy for the Grid. `HoneyDrunk.Actions` already provides all the reusable workflows; this packet wires them up in `HoneyDrunk.Auth`. Until these files exist, no PR validation runs and no vulnerability or outdated-package scans run for this repo.

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

## Acceptance Criteria

- [ ] `.github/workflows/pr.yml` exists and calls `pr-core.yml@main`
- [ ] `.github/workflows/nightly-security.yml` exists and calls `nightly-security.yml@main`
- [ ] `.github/workflows/nightly-deps.yml` exists and calls `nightly-deps.yml@main`
- [ ] `.github/workflows/hive-field-mirror.yml` exists and calls `hive-field-mirror.yml@main`
- [ ] All four workflows are valid YAML (no syntax errors)
- [ ] No other files are modified

## Dependencies

None.

## Agent Handoff

**Objective:** Create four GitHub Actions workflow files. No code changes required.
**Target:** HoneyDrunk.Auth, branch from `main`
**ADRs:** ADR-0009

**Constraints:**
- Create files only — do not modify any existing source files
- Do not add any NuGet packages or project references
- Do not bump the version

**Key Files:**
- New: `.github/workflows/pr.yml`
- New: `.github/workflows/nightly-security.yml`
- New: `.github/workflows/nightly-deps.yml`
- New: `.github/workflows/hive-field-mirror.yml`
