---
title: Reconcile Kernel 0.8.0 catalog drift
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
node: HoneyDrunk.Kernel
type: chore
tier: tier-1
sector: Meta
wave: standalone
initiative: tactical-node-audit
dependencies: []
labels: ["chore", "tier-1", "sector-meta"]
adrs: ["ADR-0043"]
source: tactical
generator: node-audit
---

## Summary

Update Architecture's Kernel version metadata so it matches the audited Kernel repo's `0.8.0` package state.

## Context

The ADR-0043 tactical audit report at `generated/audits/HoneyDrunk.Kernel-2026-06-09.md` found that the local Kernel repo has both `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions` set to `<Version>0.8.0</Version>`, while Architecture still advertises Kernel `0.7.0` in `repos/HoneyDrunk.Kernel/overview.md` and `catalogs/compatibility.json`.

Kernel is the Grid root dependency. Stale Kernel version metadata misleads downstream compatibility checks and release planning.

## Scope

- `repos/HoneyDrunk.Kernel/overview.md`
- `catalogs/compatibility.json`
- Any directly related Kernel version metadata found during implementation

Do not modify the audited Kernel repo.

## Acceptance Criteria

- [ ] Architecture context identifies HoneyDrunk.Kernel as `0.8.0` wherever it declares the current Kernel package version.
- [ ] `catalogs/compatibility.json` has `honeydrunk-kernel.currentVersion` set to `0.8.0`.
- [ ] Compatibility notes summarize the `0.8.0` breaking contract cleanup accurately enough for downstream maintainers.
- [ ] No unrelated Node versions, compatibility rows, or packet state directories are changed.
- [ ] The audit report path is cited in the PR body.

## Human Prerequisites

None.

## Dependencies

None.

## Constraints

- Architecture is the Grid command center for ADRs, routing, catalogs, and repo context. This packet updates Architecture metadata only; it does not implement code in the Kernel repo.
- Agent-generated work items land in `generated/work-items/proposed/`, never directly in `active/`. Every agent-generated packet authored after ADR-0043 acceptance lands in `generated/work-items/proposed/`, not `generated/work-items/active/`. Agents do not self-promote; a human is the only authority for the `proposed/` to `active/` transition.
- Work items carry `source` and `generator` frontmatter. Every work item authored after ADR-0043 acceptance carries `source` and `generator` frontmatter fields before it is eligible for filing.
- One repo per Node or tightly coupled Node family. Each repo has its own solution, CI pipeline, and versioning.

## Agent Handoff

**Objective:** Reconcile Architecture's Kernel version metadata with the audited Kernel `0.8.0` repo state.
**Target:** HoneyDrunk.Architecture, branch from `main`
**Context:**
- Goal: ADR-0043 tactical node audit follow-up
- Feature: Kernel audit finding remediation
- ADRs: ADR-0043

**Acceptance Criteria:**
- [ ] Architecture Kernel version metadata matches `0.8.0`.
- [ ] No non-Kernel catalog rows are changed.
- [ ] PR body cites `generated/audits/HoneyDrunk.Kernel-2026-06-09.md`.

**Dependencies:**
- None.

**Constraints:**
- Do not edit `generated/work-items/active/` or `completed/`.
- Do not edit the Kernel repo.
- Keep changes narrowly scoped to Architecture metadata drift.

**Key Files:**
- `repos/HoneyDrunk.Kernel/overview.md`
- `catalogs/compatibility.json`

**Contracts:**
- None.
