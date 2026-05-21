---
title: "Clarify Standards ownership versus Builds defaults"
repo: "HoneyDrunkStudios/HoneyDrunk.Standards"
target_repo: "HoneyDrunkStudios/HoneyDrunk.Standards"
node: "HoneyDrunk.Standards"
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

# Clarify Standards ownership versus Builds defaults

## Summary

Clarify Standards as the owner of analyzer/code-quality policy and remove ambiguity with HoneyDrunk.Builds.

## Context

A cross-repo reusable-code hygiene audit found repeated helper, mapper, validator, factory, extension, or orchestration logic in this repo. Oleg added a standing rule that agents should scan for existing reusable behavior before adding one-off helpers and should consolidate repeated logic when the same shape appears twice or becomes a policy boundary.

This packet is standalone and repo-scoped. It should not introduce cross-repo contract changes unless the implementation discovers that consolidation cannot be done safely within the target repo.

## Scope

Target repo: `HoneyDrunkStudios/HoneyDrunk.Standards`

Audit findings to address:
- Standards props/targets overlap with Builds props for nullable/latest LangVersion/deterministic settings, analyzer/code-style enforcement, StyleCop/editorconfig/globalconfig wiring, and warnings-as-errors policy.

Likely key files:
- `**/buildTransitive/HoneyDrunk.Standards.props`
- `**/HoneyDrunk.Standards.targets`
- `README.md`
- `CHANGELOG.md`

## Acceptance Criteria

- [ ] Document Standards ownership of analyzer/code-quality policy and the intended relationship to HoneyDrunk.Builds.
- [ ] Consolidate or remove overlapping policy where appropriate, in dependency order with the Builds issue if both need code changes.
- [ ] Validation covers a representative consuming project.
- [ ] No analyzer enforcement is weakened.
- [ ] Repo changelog updated under `Unreleased`.
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

**Objective:** Consolidate duplicated reusable-code patterns in `HoneyDrunk.Standards` without changing public behavior.

**Target:** `HoneyDrunk.Standards`, branch from `main`.

**Context:**
- Goal: Apply the new reusable-code hygiene rule to existing AI-generated or near-duplicate helper/orchestration code.
- Feature: Reduce drift risk by centralizing repeated behavior inside the owning repo.
- ADRs: None required unless implementation needs a public contract or repo-boundary change.

**Acceptance Criteria:**
- [ ] Document Standards ownership of analyzer/code-quality policy and the intended relationship to HoneyDrunk.Builds.
- [ ] Consolidate or remove overlapping policy where appropriate, in dependency order with the Builds issue if both need code changes.
- [ ] Validation covers a representative consuming project.
- [ ] No analyzer enforcement is weakened.
- [ ] Repo changelog updated under `Unreleased`.
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
- `**/buildTransitive/HoneyDrunk.Standards.props`
- `**/HoneyDrunk.Standards.targets`
- `README.md`
- `CHANGELOG.md`

**Contracts:**
- Prefer internal/private consolidation. Do not change public contracts unless the PR explicitly justifies the compatibility impact.
