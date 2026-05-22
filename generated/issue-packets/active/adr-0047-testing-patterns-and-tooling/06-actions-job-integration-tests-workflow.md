---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ci-cd", "ops", "adr-0047", "wave-2"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0047", "ADR-0011"]
accepts: ["ADR-0047"]
wave: 2
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-actions
---

# Author `job-integration-tests.yml` (Tier 2a) reusable workflow and wire it into `pr-core.yml`

## Summary
Add a new reusable workflow `job-integration-tests.yml` in `HoneyDrunk.Actions` that runs Tier 2a in-process integration tests (`dotnet test --filter "FullyQualifiedName~Tests.Integration"`, excluding `Tests.Integration.Containers`), and wire it into `pr-core.yml` as a required tier-2 PR check. This closes ADR-0011 Gap 1's integration-test slot per ADR-0047 D11.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0047 D11 commits Tier 2a integration tests to "a new `job-integration-tests.yml` (closes ADR-0011 Gap 1)" wired into `pr-core.yml`, and D14 Phase 2 schedules it: "Author `job-integration-tests.yml` (Tier 2a) in HoneyDrunk.Actions. Wire it into `pr-core.yml`. Each Node opts in by adding a `*.Tests.Integration` project; the CI job auto-discovers." ADR-0047 D12 confirms this fills ADR-0011 Gap 1. Today there is a defined slot in `pr-core.yml` tier 2 and no implementation; this packet ships it.

This packet ships the workflow AND the `pr-core.yml` wiring — unlike the SonarCloud precedent, ADR-0047 D14 Phase 2 explicitly bundles "author + wire" because the job auto-discovers (`*.Tests.Integration` projects) and is a no-op in repos that have none, so wiring it Grid-wide is safe.

## Proposed Change
Create `.github/workflows/job-integration-tests.yml` following the structure of the existing `job-*.yml` reusable workflows (`job-build-and-test.yml`, etc. — `.github/workflows/`, exposed via `workflow_call`).

### Workflow shape
- `workflow_call` with inputs mirroring `job-build-and-test.yml`: `dotnet-version` (default `10.0.x`), `runs-on` (default `ubuntu-latest`), `working-directory`, `project-path` (auto-detect if blank).
- Steps: checkout, `actions/setup-dotnet`, restore, build `--configuration Release`, then:
  - `dotnet test --filter "FullyQualifiedName~Tests.Integration&FullyQualifiedName!~Tests.Integration.Containers" --configuration Release` — the filter selects Tier 2a (`*.Tests.Integration`) and **excludes** Tier 2b (`*.Tests.Integration.Containers`), which has its own workflow (packet 09).
  - The job uses `coverlet` collection via the packet-02 `coverlet.runsettings` if present at the repo root (`--settings coverlet.runsettings`); coverage is informational for Tier 2a (the hard coverage gate is Tier 1's, per ADR-0047 D3 — do not add a second gate here).
- **Auto-discovery / no-op behavior:** if the repo has zero `*.Tests.Integration` projects, the filtered `dotnet test` finds no matching tests and the job succeeds as a no-op. The job must not fail a repo that has not yet opted in. Verify the `dotnet test` exit code for "no tests matched" is treated as success (use `--filter` against the solution; if `dotnet test` returns non-zero for an empty filter on the runtime in use, add an explicit guard step that detects the absence of `*.Tests.Integration` projects and skips).
- Runtime budget per ADR-0047 D1: Tier 2a suite target `< 5min`. No special runner needed (in-process fakes, no Docker).
- Header comment block documents the tier, the filter contract, and the no-op-on-no-opt-in behavior.

### `pr-core.yml` wiring
Add a job that calls `job-integration-tests.yml` to `pr-core.yml`, parallel with the existing tier-2 jobs. Per ADR-0047 D11 the Tier 2a check is "Yes (branch protection)" — blocking — but because it is a no-op in non-opted-in repos, wiring it Grid-wide is safe. Document in the `pr-core.yml` header / `docs/consumer-usage.md` that the job auto-discovers `*.Tests.Integration` projects.

## Consumer Impact
- Every repo consuming `pr-core.yml` gains the integration-test job. Repos with no `*.Tests.Integration` project see a passing no-op job — no action required.
- Repos that later add a `*.Tests.Integration` project are auto-discovered with no caller-workflow change.

## Breaking Change?
- [x] No — backward compatible. The job is a no-op in repos without `*.Tests.Integration` projects.

## NuGet Dependencies
None. The workflow invokes `dotnet test`; no project-level `<PackageReference>` is added by this packet.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Routing rule "workflow, CI, GitHub Actions, pipeline, PR check → HoneyDrunk.Actions" maps exactly.
- [x] No code change in any consuming repo — the job auto-discovers.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `.github/workflows/job-integration-tests.yml` exists, `workflow_call`-exposed, with the inputs and steps above
- [ ] The `dotnet test` filter selects `*.Tests.Integration` and **excludes** `*.Tests.Integration.Containers`
- [ ] The job is a passing no-op in a repo with zero `*.Tests.Integration` projects (verified)
- [ ] `pr-core.yml` invokes `job-integration-tests.yml` as a tier-2 job, parallel with existing tier-2 jobs
- [ ] The job uses `coverlet.runsettings` if present but does NOT add a second coverage gate (Tier 1 owns the gate per ADR-0047 D3)
- [ ] Header comment documents the tier, the filter contract, and the no-op behavior
- [ ] `docs/CHANGELOG.md` updated; `docs/consumer-usage.md` updated to document the auto-discovery contract
- [ ] `README.md` workflow-list section updated if one exists
- [ ] `.github/workflows/job-integration-tests.yml` lints clean under `actionlint`

## Human Prerequisites
None. (No portal step — Tier 2a runs on standard `ubuntu-latest` runners with no Docker.)

## Referenced ADR Decisions
**ADR-0047 D1 — Tier 2a.** Integration — in-process: multiple components composed within one Node; internal Grid seams use contract-compatible fakes per invariant 15; external boundaries faked. Runtime budget `< 1s` per test, suite `< 5min`. Run every PR.

**ADR-0047 D4 — Tier 2a is `WebApplicationFactory` + fakes.** Built on `Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<T>` for HTTP-fronted Nodes; a test-host bootstrapper for non-HTTP Nodes. Project naming: `HoneyDrunk.<Node>.Tests.Integration`.

**ADR-0047 D11 — CI integration.** Tier 2a: `dotnet test --filter "FullyQualifiedName~Tests.Integration"` in a new `job-integration-tests.yml`, blocking branch-protection check. The new reusable workflows live in HoneyDrunk.Actions per ADR-0012's control-plane invariant.

**ADR-0047 D12 — Closes ADR-0011 Gap 1.** This workflow + the `pr-core.yml` wiring fill ADR-0011's integration-test slot.

## Constraints
- **Exclude Tier 2b.** The filter must exclude `*.Tests.Integration.Containers` — that tier has its own workflow (packet 09) with Docker requirements. A naive `~Tests.Integration` filter would catch both.
- **No-op-safe.** The job must pass cleanly in repos with no `*.Tests.Integration` project — wiring it into `pr-core.yml` Grid-wide depends on this.
- **Do not add a second coverage gate.** Tier 1 owns the hard coverage gate per ADR-0047 D3; Tier 2a coverage is informational.
- **Reusable workflows live in HoneyDrunk.Actions** per ADR-0012 — do not inline this into consumer repos.

## Labels
`feature`, `tier-2`, `ci-cd`, `ops`, `adr-0047`, `wave-2`

## Agent Handoff

**Objective:** Ship `job-integration-tests.yml` (Tier 2a) as a reusable workflow in `HoneyDrunk.Actions` and wire it into `pr-core.yml` as a no-op-safe, auto-discovering tier-2 PR check.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Close ADR-0011 Gap 1 — fill the integration-test slot with a real CI job.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 2.
- ADRs: ADR-0047 (D1, D4, D11, D12), ADR-0011 (Gap 1), ADR-0012 (reusable workflows live in Actions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:00 — ADR-0047 acceptance (so D-decision references are live rules).
- packet:01 — the shared test-stack props fragment exists (Nodes consuming it produce `*.Tests.Integration` projects the job discovers).

**Constraints:**
- Filter excludes `*.Tests.Integration.Containers` (Tier 2b — packet 09 owns it).
- No-op-safe in repos without `*.Tests.Integration` projects.
- No second coverage gate — Tier 1 owns it.

**Key Files:**
- `.github/workflows/job-integration-tests.yml` (new)
- `.github/workflows/pr-core.yml` (wire the new job)
- `.github/workflows/job-build-and-test.yml` (style + input reference)
- `docs/CHANGELOG.md`, `docs/consumer-usage.md`, `README.md`

**Contracts:** None changed.
