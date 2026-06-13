---
title: Add Kernel repo changelog 0.8.0 entry
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
node: HoneyDrunk.Kernel
type: chore
tier: tier-1
sector: Core
wave: standalone
initiative: tactical-node-audit
dependencies: []
labels: ["chore", "tier-1", "sector-core"]
adrs: ["ADR-0043"]
source: tactical
generator: node-audit
---

## Summary

Move Kernel's `0.8.0` release notes out of the repo-level `Unreleased` section into a proper released `## [0.8.0] - 2026-05-26` entry.

## Context

The ADR-0043 tactical audit report at `generated/audits/HoneyDrunk.Kernel-2026-06-09.md` found that the Kernel package changelogs have released `0.8.0` headings, and both package projects set `<Version>0.8.0</Version>`, but the repo-level `HoneyDrunk.Kernel/CHANGELOG.md` keeps the `v0.8.0` material under `## [Unreleased]`.

The repo-level changelog is the source for generated release notes. It should have a released entry for every shipped version.

## Scope

- `HoneyDrunk.Kernel/CHANGELOG.md`

Do not change code, package versions, package changelogs, or workflows unless implementation discovers the repo-level changelog is already corrected on the latest `main`.

## Acceptance Criteria

- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` contains `## [0.8.0] - 2026-05-26`.
- [ ] The existing `v0.8.0` release notes are preserved under the `0.8.0` heading.
- [ ] `## [Unreleased]` contains only truly unreleased future work or an explicit empty placeholder.
- [ ] No package version bump is performed for this docs-only release-hygiene change.
- [ ] No unrelated changelog entries are rewritten.

## Human Prerequisites

None.

## Dependencies

None.

## NuGet Dependencies

No NuGet dependency changes.

## Constraints

- Semantic versioning with CHANGELOG and README. Repo-level `CHANGELOG.md`, next to the `.slnx` file, is mandatory. Every repo must have one. It covers the full release holistically. Every version that ships must have an entry here. This is the source for auto-generated release notes.
- Every package directory must also contain a `README.md` describing the package purpose, installation, and public API surface. New projects must have both files from the first commit.
- Do not fabricate package-level change bullets for alignment-only bumps. This packet does not touch package-level changelogs.

## Agent Handoff

**Objective:** Correct the repo-level Kernel changelog so released `0.8.0` notes are under a released heading.
**Target:** HoneyDrunk.Kernel, branch from `main`
**Context:**
- Goal: ADR-0043 tactical node audit follow-up
- Feature: Kernel release hygiene
- ADRs: ADR-0043

**Acceptance Criteria:**
- [ ] Root changelog has a `0.8.0` heading dated `2026-05-26`.
- [ ] Unreleased no longer contains already-shipped `0.8.0` release notes.
- [ ] No code or dependency changes are made.

**Dependencies:**
- None.

**Constraints:**
- Keep this packet docs-only.
- Do not change package versions.
- Do not edit Architecture repo files from the Kernel execution PR.

**Key Files:**
- `HoneyDrunk.Kernel/CHANGELOG.md`

**Contracts:**
- None.
