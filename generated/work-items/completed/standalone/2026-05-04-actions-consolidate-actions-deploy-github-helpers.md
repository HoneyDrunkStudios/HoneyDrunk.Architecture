---
title: "Consolidate Actions deploy and GitHub helpers"
repo: "HoneyDrunkStudios/HoneyDrunk.Actions"
target_repo: "HoneyDrunkStudios/HoneyDrunk.Actions"
node: "HoneyDrunk.Actions"
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

# Consolidate Actions deploy and GitHub helpers

## Summary

Consolidate repeated GitHub Actions deploy orchestration, Key Vault secret parsing, actions-ref resolution, and `gh_retry` shell helpers.

## Context

A cross-repo reusable-code hygiene audit found repeated helper, mapper, validator, factory, extension, or orchestration logic in this repo. Oleg added a standing rule that agents should scan for existing reusable behavior before adding one-off helpers and should consolidate repeated logic when the same shape appears twice or becomes a policy boundary.

This packet is standalone and repo-scoped. It should not introduce cross-repo contract changes unless the implementation discovers that consolidation cannot be done safely within the target repo.

## Scope

Target repo: `HoneyDrunkStudios/HoneyDrunk.Actions`

Audit findings to address:
- App Service and Function deploy composite actions repeat URL resolution, startup wait, health-check loops, slot swap, post-swap URL, and final status logic.
- Key Vault secret mapping/parsing appears in `keyvault-fetch` and multiple deploy workflows.
- `actions-ref` checkout fallback is repeated despite an existing `common/checkout-actions-repo` consolidation target.
- `gh_retry` is duplicated in `scripts/file-work-items.sh` and `scripts/hive-project-mirror.sh`.

Likely key files:
- `.github/actions/azure/deploy-app-service/action.yml`
- `.github/actions/azure/deploy-function/action.yml`
- `.github/actions/azure/keyvault-fetch/action.yml`
- `.github/workflows/job-deploy-*.yml`
- `.github/actions/common/checkout-actions-repo/action.yml`
- `scripts/file-work-items.sh`
- `scripts/hive-project-mirror.sh`

## Acceptance Criteria

- [ ] Shared Azure deploy helper/composite/script owns URL resolution, health checks, slot swap, and deployment status where behavior is common.
- [ ] Key Vault secret mapping parser is centralized and consumed by deploy workflows/actions.
- [ ] `actions-ref` fallback resolution is owned by a common action/helper.
- [ ] `gh_retry` moved to a shared shell library and sourced by both scripts.
- [ ] Workflow/action documentation and tests/examples updated where behavior changes.
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

**Objective:** Consolidate duplicated reusable-code patterns in `HoneyDrunk.Actions` without changing public behavior.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Apply the new reusable-code hygiene rule to existing AI-generated or near-duplicate helper/orchestration code.
- Feature: Reduce drift risk by centralizing repeated behavior inside the owning repo.
- ADRs: None required unless implementation needs a public contract or repo-boundary change.

**Acceptance Criteria:**
- [ ] Shared Azure deploy helper/composite/script owns URL resolution, health checks, slot swap, and deployment status where behavior is common.
- [ ] Key Vault secret mapping parser is centralized and consumed by deploy workflows/actions.
- [ ] `actions-ref` fallback resolution is owned by a common action/helper.
- [ ] `gh_retry` moved to a shared shell library and sourced by both scripts.
- [ ] Workflow/action documentation and tests/examples updated where behavior changes.
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
- Work items are immutable once filed as a GitHub Issue; if requirements change materially after filing, write a follow-up packet rather than editing the filed packet.
- All projects in a solution share one version and move together when a version bump is warranted; do not bump versions unless this cleanup intentionally cuts a release.
- Agent-authored PRs must link to their packet in the PR body.

**Key Files:**
- `.github/actions/azure/deploy-app-service/action.yml`
- `.github/actions/azure/deploy-function/action.yml`
- `.github/actions/azure/keyvault-fetch/action.yml`
- `.github/workflows/job-deploy-*.yml`
- `.github/actions/common/checkout-actions-repo/action.yml`
- `scripts/file-work-items.sh`
- `scripts/hive-project-mirror.sh`

**Contracts:**
- Prefer internal/private consolidation. Do not change public contracts unless the PR explicitly justifies the compatibility impact.
