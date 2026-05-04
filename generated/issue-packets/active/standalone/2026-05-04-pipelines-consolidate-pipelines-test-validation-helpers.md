---
title: "Consolidate Pipelines test validation helpers"
repo: "HoneyDrunkStudios/HoneyDrunk.Pipelines"
node: "HoneyDrunk.Pipelines"
request_type: "repo-feature"
tier: "tier-2"
sector: "ops"
wave: 1
initiative: "standalone"
adrs: []
accepts: []
dependencies: []
labels: ["chore", "tier-2", "ops"]
actor: "Agent"
---

# Consolidate Pipelines test validation helpers

## Summary

Extract common PowerShell helper logic from test naming and display-name validation tasks.

## Context

A cross-repo reusable-code hygiene audit found repeated helper, mapper, validator, factory, extension, or orchestration logic in this repo. Oleg added a standing rule that agents should scan for existing reusable behavior before adding one-off helpers and should consolidate repeated logic when the same shape appears twice or becomes a policy boundary.

This packet is standalone and repo-scoped. It should not introduce cross-repo contract changes unless the implementation discovers that consolidation cannot be done safely within the target repo.

## Scope

Target repo: `HoneyDrunkStudios/HoneyDrunk.Pipelines`

Audit findings to address:
- `validate-test-naming.ps1` and `validate-test-displayname.ps1` repeat recursive test-file discovery, bin/obj exclusion, summary/violation counters, warning/no-files handling, and catch/error/exit patterns.

Likely key files:
- `tasks/dotnet/validate-test-naming.ps1`
- `tasks/dotnet/validate-test-displayname.ps1`
- `tasks/common/*.ps1`

## Acceptance Criteria

- [ ] Common test discovery and Azure logging/error helpers extracted under `tasks/common/` or equivalent.
- [ ] Both validation tasks consume shared helpers while keeping their rule-specific checks clear.
- [ ] Existing task outputs and exit-code behavior remain compatible.
- [ ] Add or update script-level tests/examples if this repo has a validation harness.
- [ ] Repo changelog or release notes updated if tasks are shipped.
- [ ] Implementation scans local sibling/shared locations before adding any new helper and documents intentional duplication in the PR if behavior should diverge.
- [ ] Repo validation passes using the repo's normal tier-1 gate: build, tests, analyzers/static analysis, secret scan, and dependency/vulnerability scan where configured.

## NuGet Dependencies

No new `PackageReference` entries are expected. If implementation discovers a package reference is required, update this packet before filing or document the package explicitly in the filed issue/PR body before execution.

## Human Prerequisites

None.

## Dependencies

None. This is a standalone cleanup packet.

## Labels

- `chore`
- `tier-2`
- `ops`

## Agent Handoff

**Objective:** Consolidate duplicated reusable-code patterns in `HoneyDrunk.Pipelines` without changing public behavior.

**Target:** `HoneyDrunk.Pipelines`, branch from `main`.

**Context:**
- Goal: Apply the new reusable-code hygiene rule to existing AI-generated or near-duplicate helper/orchestration code.
- Feature: Reduce drift risk by centralizing repeated behavior inside the owning repo.
- ADRs: None required unless implementation needs a public contract or repo-boundary change.

**Acceptance Criteria:**
- [ ] Common test discovery and Azure logging/error helpers extracted under `tasks/common/` or equivalent.
- [ ] Both validation tasks consume shared helpers while keeping their rule-specific checks clear.
- [ ] Existing task outputs and exit-code behavior remain compatible.
- [ ] Add or update script-level tests/examples if this repo has a validation harness.
- [ ] Repo changelog or release notes updated if tasks are shipped.
- [ ] Normal repo validation passes.

**Dependencies:**
- None.

**Constraints:**
- Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.
- Runtime packages depend on Abstractions, never on other runtime packages at the same layer.
- Provider packages depend on their parent Node's contracts, not internal implementation details; providers must only consume exported interfaces, never internal types, caches, or resilience plumbing.
- No circular dependencies. The dependency graph is a DAG. Kernel is always at the root.
- Semantic versioning with CHANGELOG and README: update repo-level `CHANGELOG.md` for shipped behavior changes and per-package changelogs only for packages with actual functional changes.
- All public APIs have XML documentation.
- Tests never depend on external services; use in-memory/fake providers for isolation.
- Issue packets are immutable once filed as a GitHub Issue; if requirements change materially after filing, write a follow-up packet rather than editing the filed packet.
- All projects in a solution share one version and move together when a version bump is warranted; do not bump versions unless this cleanup intentionally cuts a release.
- Agent-authored PRs must link to their packet in the PR body.

**Key Files:**
- `tasks/dotnet/validate-test-naming.ps1`
- `tasks/dotnet/validate-test-displayname.ps1`
- `tasks/common/*.ps1`

**Contracts:**
- Prefer internal/private consolidation. Do not change public contracts unless the PR explicitly justifies the compatibility impact.
