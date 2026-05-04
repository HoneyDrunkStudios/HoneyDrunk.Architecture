---
title: "Consolidate Vault.Rotation placeholder rotators"
repo: "HoneyDrunkStudios/HoneyDrunk.Vault.Rotation"
target_repo: "HoneyDrunkStudios/HoneyDrunk.Vault.Rotation"
node: "HoneyDrunk.Vault.Rotation"
request_type: "repo-feature"
tier: "tier-2"
sector: "core"
wave: 1
initiative: "standalone"
adrs: []
accepts: []
dependencies: []
labels: ["chore", "tier-2", "core"]
actor: "Agent"
---

# Consolidate Vault.Rotation placeholder rotators

## Summary

Replace copy/paste placeholder provider rotators with one reusable scaffold/base until real rotations land.

## Context

A cross-repo reusable-code hygiene audit found repeated helper, mapper, validator, factory, extension, or orchestration logic in this repo. Oleg added a standing rule that agents should scan for existing reusable behavior before adding one-off helpers and should consolidate repeated logic when the same shape appears twice or becomes a policy boundary.

This packet is standalone and repo-scoped. It should not introduce cross-repo contract changes unless the implementation discovers that consolidation cannot be done safely within the target repo.

## Scope

Target repo: `HoneyDrunkStudios/HoneyDrunk.Vault.Rotation`

Audit findings to address:
- OpenAI, Resend, and Twilio placeholder rotators duplicate `ProviderName`, `RotateAsync`, context/cancellation validation, and skipped-result behavior with only provider names/messages differing.

Likely key files:
- `HoneyDrunk.Vault.Rotation.Providers/OpenAI/OpenAIRotator.cs`
- `HoneyDrunk.Vault.Rotation.Providers/Resend/ResendRotator.cs`
- `HoneyDrunk.Vault.Rotation.Providers/Twilio/TwilioRotator.cs`

## Acceptance Criteria

- [ ] Placeholder provider behavior consolidated into a configurable placeholder rotator or abstract scaffold base.
- [ ] Provider registrations still expose distinct provider names for OpenAI, Resend, and Twilio.
- [ ] Tests cover skipped placeholder behavior for each provider registration.
- [ ] No real provider rotation behavior is implied until separately scoped.
- [ ] Repo-level and affected package changelogs updated under `Unreleased`.
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
- `core`

## Agent Handoff

**Objective:** Consolidate duplicated reusable-code patterns in `HoneyDrunk.Vault.Rotation` without changing public behavior.

**Target:** `HoneyDrunk.Vault.Rotation`, branch from `main`.

**Context:**
- Goal: Apply the new reusable-code hygiene rule to existing AI-generated or near-duplicate helper/orchestration code.
- Feature: Reduce drift risk by centralizing repeated behavior inside the owning repo.
- ADRs: None required unless implementation needs a public contract or repo-boundary change.

**Acceptance Criteria:**
- [ ] Placeholder provider behavior consolidated into a configurable placeholder rotator or abstract scaffold base.
- [ ] Provider registrations still expose distinct provider names for OpenAI, Resend, and Twilio.
- [ ] Tests cover skipped placeholder behavior for each provider registration.
- [ ] No real provider rotation behavior is implied until separately scoped.
- [ ] Repo-level and affected package changelogs updated under `Unreleased`.
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
- `HoneyDrunk.Vault.Rotation.Providers/OpenAI/OpenAIRotator.cs`
- `HoneyDrunk.Vault.Rotation.Providers/Resend/ResendRotator.cs`
- `HoneyDrunk.Vault.Rotation.Providers/Twilio/TwilioRotator.cs`

**Contracts:**
- Prefer internal/private consolidation. Do not change public contracts unless the PR explicitly justifies the compatibility impact.
