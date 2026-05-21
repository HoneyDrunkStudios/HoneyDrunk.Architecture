---
title: "Consolidate Architecture packet and guidance rules"
repo: "HoneyDrunkStudios/HoneyDrunk.Architecture"
target_repo: "HoneyDrunkStudios/HoneyDrunk.Architecture"
node: "HoneyDrunk.Architecture"
request_type: "repo-feature"
tier: "tier-2"
sector: "meta"
wave: 1
initiative: "standalone"
adrs: []
accepts: []
dependencies: []
labels: ["chore", "tier-2", "meta"]
actor: "Agent"
---

# Consolidate Architecture packet and guidance rules

## Summary

Centralize duplicated Architecture packet naming, structure, dependency, handoff, site-sync, agent-source, and reusable-guidance rules.

## Context

A cross-repo reusable-code hygiene audit found repeated helper, mapper, validator, factory, extension, or orchestration logic in this repo. Oleg added a standing rule that agents should scan for existing reusable behavior before adding one-off helpers and should consolidate repeated logic when the same shape appears twice or becomes a policy boundary.

This packet is standalone and repo-scoped. It should not introduce cross-repo contract changes unless the implementation discovers that consolidation cannot be done safely within the target repo.

## Scope

Target repo: `HoneyDrunkStudios/HoneyDrunk.Architecture`

Audit findings to address:
- Issue packet naming is duplicated and drifted across scope agent, generated packet README, Copilot instructions, CLAUDE.md, and issue-authoring rules.
- Packet structure/checklists repeat across scope, issue rules, and templates.
- Dependency source-of-truth conflicts between frontmatter and body `## Dependencies` guidance.
- Claude to Codex handoff format is duplicated and stale.
- Site sync triggers/schema repeat with drift.
- Copilot instructions still mention `.github/agents/` despite ADR-0007 establishing `.claude/agents/`.
- Reusable-code/reusable-guidance rule now appears in multiple active instruction surfaces.

Likely key files:
- `.claude/agents/scope.md`
- `generated/issue-packets/README.md`
- `.github/copilot-instructions.md`
- `CLAUDE.md`
- `copilot/issue-authoring-rules.md`
- `.claude/agents/file-issues.md`
- `routing/sdlc.md`
- `routing/site-sync-rules.md`
- `.claude/agents/site-sync.md`
- `issues/templates/*.md`
- `AGENTS.md`
- `copilot/global-instructions.md`

## Acceptance Criteria

- [ ] One canonical packet naming/lifecycle location chosen and all other docs reference it.
- [ ] One canonical packet contract/checklist chosen and templates/agents stop restating divergent copies.
- [ ] Dependency guidance consistently treats frontmatter `dependencies:` as machine-readable source of truth.
- [ ] Canonical handoff schema moved to or confirmed in `routing/sdlc.md`, with surface docs referencing it.
- [ ] Site sync trigger/schema guidance centralized.
- [ ] Stale `.github/agents/` guidance corrected to ADR-0007 `.claude/agents/` source of truth.
- [ ] Reusable-code guidance has one Architecture-local canonical source with references from other instruction surfaces.
- [ ] No historical generated packets are rewritten unless they are active templates/rules.
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
- `meta`

## Agent Handoff

**Objective:** Consolidate duplicated reusable-code patterns in `HoneyDrunk.Architecture` without changing public behavior.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Apply the new reusable-code hygiene rule to existing AI-generated or near-duplicate helper/orchestration code.
- Feature: Reduce drift risk by centralizing repeated behavior inside the owning repo.
- ADRs: None required unless implementation needs a public contract or repo-boundary change.

**Acceptance Criteria:**
- [ ] One canonical packet naming/lifecycle location chosen and all other docs reference it.
- [ ] One canonical packet contract/checklist chosen and templates/agents stop restating divergent copies.
- [ ] Dependency guidance consistently treats frontmatter `dependencies:` as machine-readable source of truth.
- [ ] Canonical handoff schema moved to or confirmed in `routing/sdlc.md`, with surface docs referencing it.
- [ ] Site sync trigger/schema guidance centralized.
- [ ] Stale `.github/agents/` guidance corrected to ADR-0007 `.claude/agents/` source of truth.
- [ ] Reusable-code guidance has one Architecture-local canonical source with references from other instruction surfaces.
- [ ] No historical generated packets are rewritten unless they are active templates/rules.
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
- `.claude/agents/scope.md`
- `generated/issue-packets/README.md`
- `.github/copilot-instructions.md`
- `CLAUDE.md`
- `copilot/issue-authoring-rules.md`
- `.claude/agents/file-issues.md`
- `routing/sdlc.md`
- `routing/site-sync-rules.md`
- `.claude/agents/site-sync.md`
- `issues/templates/*.md`
- `AGENTS.md`
- `copilot/global-instructions.md`

**Contracts:**
- Prefer internal/private consolidation. Do not change public contracts unless the PR explicitly justifies the compatibility impact.
