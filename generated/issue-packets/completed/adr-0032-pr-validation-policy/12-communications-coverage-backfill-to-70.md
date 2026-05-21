---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["chore", "tier-2", "testing", "comms", "adr-0032", "wave-2"]
dependencies: ["packet:01"]
adrs: ["ADR-0032"]
wave: 2
initiative: adr-0032-pr-validation-policy
node: honeydrunk-communications
---

# Coverage backfill: bring `HoneyDrunk.Communications` total line coverage to ≥ 70% (clear the absolute floor)

## Summary
Add unit tests to `HoneyDrunk.Communications` until total solution line coverage is **≥ 70%**, clearing the Grid-wide absolute coverage floor (D3) so the new PR coverage gate stops blocking normal PR flow in this repo. 70% is the target for this packet; the higher patch ≥ 75% gate (D1) takes over for new code once the floor is cleared.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Communications`

## Motivation
Packet 01 of this initiative ships a blocking coverage gate in the Actions control plane. Its absolute-floor condition (D3) fails any test-bearing PR whose **total** solution line coverage is below 70% — flat, Grid-wide, no per-repo exemption, by design. `HoneyDrunk.Communications` has a `.Tests` project (`HoneyDrunk.Communications.Tests`), so the gate **applies** to it. Until total coverage crosses 70%, **every** PR to this repo fails the required `PR Core` check on D3 regardless of that PR's own patch coverage — the patch gate's signal is masked by the floor (this is the intended forcing function, flagged so it is not mistaken for a CI defect). This packet is the work that crosses the floor and unblocks normal PR flow for `HoneyDrunk.Communications`.

## Why current coverage is not stated here (scope-time assumption)
The coverage gate and the `.github/coverage-baseline.json` mechanism do not exist yet (they ship in packet 01), and no committed coverage artifact (`Summary.json`, baseline file) exists in any workspace repo today. Therefore the **exact current coverage of this repo could not be measured at scope time**. The first authoritative measurement is the first run of the new gate on a PR in this repo (or a local `dotnet test --collect:"XPlat Code Coverage"` + ReportGenerator pass). **Step 1 of this packet is to measure; the size of the backfill is whatever the measured gap to 70% is.** If the measured total is already ≥ 70%, this packet's deliverable collapses to "confirm green and seed the baseline" (see Acceptance Criteria) — it does not become a no-op because the baseline file still must be seeded for D2 to become live.

## Architecture decisions this packet implements (executor has no ADR access)
- **D3 absolute floor = 70%, flat Grid-wide, not per-repo, not ramping.** The target is exactly 70% total line coverage. Do not argue for a lower starting number or a per-repo floor — the flat floor with intended red states is the mechanism.
- **D1 patch gate = 75%** takes over for new/changed code once the floor is cleared. This packet's own added test code is not exempt — but test code is generally excluded from the coverage denominator by the `-assemblyfilters:+*;-*.Tests` filter, so adding tests raises the numerator without inflating the denominator.
- **D2 no-regress** becomes live for this repo the moment `.github/coverage-baseline.json` is seeded (first post-merge run after packet 01, or seeded explicitly by this packet's PR — see below). After seeding, coverage may never regress below the recorded value without a deliberate, reviewed baseline edit in the same PR.
- **Tests live only in `.Tests`/`.Canary` projects** (Grid testing invariant). All new tests go in the existing `HoneyDrunk.Communications.Tests` project (and/or the `.Canary` project for cross-Node boundary assertions — but coverage backfill is unit-test work, so prefer `.Tests`).

## Proposed Implementation
1. **Measure.** Run the solution's tests with coverage locally (`dotnet test --collect:"XPlat Code Coverage"`), run ReportGenerator with the Grid filter `-assemblyfilters:+*;-*.Tests`, and record the current total line coverage. This is the baseline number and the gap to 70%.
2. **Prioritize by uncovered surface.** From the ReportGenerator HTML/JsonSummary, identify the largest uncovered runtime types/methods (orchestration decision logic, preference enforcement, cadence/suppression rules, decision-log recording, recipient resolution — whatever the report shows as the biggest red blocks). Write unit tests against public behavior, not implementation details.
3. **Respect test invariants.** Tests must not depend on external services — use in-memory/fake collaborators. No test code in runtime packages. New test files go in `HoneyDrunk.Communications.Tests`.
4. **Iterate to ≥ 70%.** Add tests until the measured total line coverage (same ReportGenerator filter) is ≥ 70%. Aim for a small margin above 70% (e.g. land at ≥ 72%) so trivial later churn does not immediately re-trip D3.
5. **Seed the baseline file.** Add/commit `.github/coverage-baseline.json` in this repo with the achieved total: `{ "totalLineCoverage": <measured>, "commit": "<this PR's merge sha or a placeholder updated by the post-merge ratchet>", "measuredAtUtc": "<iso8601>" }`. Note: packet 01's post-merge ratchet will rewrite this file with the authoritative number on merge to the default branch; seeding it here ensures D2 is live immediately and the file exists as a reviewable artifact from day one. If packet 01 has already merged and run once on this repo's default branch, the file may already exist — in that case, update it only if this PR's measured total is higher (never hand-lower it without it being a deliberate reviewed regression).
6. **No version bump for test-only changes.** Adding tests does not change shipped runtime behavior; per Grid versioning rules a test-only change does not warrant a solution version bump. Do **not** bump `.csproj` versions. Do update the repo-level `CHANGELOG.md` under an `### Internal` / `Unreleased` note ("Test coverage backfilled to ≥70% to satisfy the Grid PR coverage gate") since this is a tracked change, but no new shipped version entry is required (no runtime behavior changed).

## Affected Files
- `HoneyDrunk.Communications.Tests/**` (new/expanded test files)
- `.github/coverage-baseline.json` (new — seeded)
- `CHANGELOG.md` (repo root — Unreleased/Internal note; no version bump)

## NuGet Dependencies
No new runtime `PackageReference`s. Test-project dependencies (xUnit/NUnit, FluentAssertions, Moq/NSubstitute, `coverlet.collector`, `HoneyDrunk.Standards`) are already present in `HoneyDrunk.Communications.Tests` — confirm `coverlet.collector` is referenced (required for `--collect:"XPlat Code Coverage"`); if absent, add it as a test-only `PackageReference` (`PrivateAssets: all`). `HoneyDrunk.Standards` must remain referenced on the test project (StyleCop + EditorConfig analyzers, `PrivateAssets: all`).

## Boundary Check
- [x] Work is entirely within `HoneyDrunk.Communications`'s own test project — no cross-Node surface touched.
- [x] No runtime code change (test-only) — no contract, no version bump, no downstream cascade.
- [x] `.github/coverage-baseline.json` is a repo-local CI artifact consumed by the reusable gate.

## Acceptance Criteria
- [ ] Current total line coverage measured and recorded in the PR description (with the ReportGenerator filter `-assemblyfilters:+*;-*.Tests`).
- [ ] Total solution line coverage is **≥ 70%** (target: land with a small margin, ≥ 72%, to avoid immediate re-trip).
- [ ] New tests live only in `HoneyDrunk.Communications.Tests`; none in runtime packages.
- [ ] No test depends on an external service (in-memory/fake collaborators only).
- [ ] `.github/coverage-baseline.json` exists in the repo with `totalLineCoverage` = the achieved total, `commit`, `measuredAtUtc`.
- [ ] No `.csproj` version bump (test-only change); repo-level `CHANGELOG.md` carries an Unreleased/Internal note describing the backfill.
- [ ] The `PR Core` required check passes on this PR (D3 satisfied; D1 satisfied for the PR's own diff — added test code generally excluded from the denominator by the assembly filter).
- [ ] If the repo was already ≥ 70% at measurement: the packet still seeds `.github/coverage-baseline.json` and confirms the gate is green; it is not closed as a no-op.

## Human Prerequisites
- [ ] **None.** Measurement and test authoring are fully delegable. The baseline file is committed as part of the PR; no portal action and no secret are required (the post-merge ratchet uses the default token, scoped in packet 01).

Actor=Agent.

## Dependencies
- **Blocked by packet 01** (`packet:01`) — the coverage gate, the `patch-coverage-threshold`/`absolute-coverage-floor` inputs, and the `.github/coverage-baseline.json` mechanism must exist before "go green against the gate" and "seed the baseline" are meaningful. Sequencing: floor-crossing work runs after the gate exists (so the measurement uses the same ReportGenerator filter the gate uses) and is the work that unblocks normal PR flow per repo.

## Labels
`chore`, `tier-2`, `testing`, `comms`, `adr-0032`, `wave-2`

## Agent Handoff

**Objective:** Raise `HoneyDrunk.Communications` total line coverage to ≥ 70% and seed `.github/coverage-baseline.json` so the new PR coverage gate stops blocking this repo.
**Target:** HoneyDrunk.Communications, branch from `main`

**Context:**
- Goal: Cross the Grid-wide 70% absolute floor (D3) so normal PR flow is unblocked for this repo; the patch ≥ 75% gate (D1) governs new code thereafter.
- Feature: Grid-wide PR Validation Policy (runtime packet-data id `adr-0032`), Part 1 D3 backfill.
- ADRs: ADR-0032 (metadata only — binding decisions inlined above).

**Acceptance Criteria:** As listed above.

**Dependencies:** Blocked by packet 01 (the gate + baseline mechanism + threshold inputs must exist first).

**Constraints:**
- **D3 floor is exactly 70%, flat, not per-repo, not ramping.** Target ≥ 70% (land ≥ 72% for margin). Do not seek a lower bar.
- **Grid testing invariant (inlined):** "No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only." and "Tests never depend on external services. Use InMemory providers for isolation." New tests go only in `HoneyDrunk.Communications.Tests` with in-memory collaborators.
- **Grid packaging invariant (inlined):** new/changed test projects must reference `HoneyDrunk.Standards` (`PrivateAssets: all`). No `.csproj` version bump for a test-only change; repo-level `CHANGELOG.md` still gets an Unreleased/Internal note.
- **Measure first.** Current coverage is unknown at scope time — the first deliverable is the measured number and the gap.

**Key Files:**
- `HoneyDrunk.Communications.Tests/` — the only place new tests may live.
- `.github/coverage-baseline.json` — seed this; packet 01's post-merge ratchet keeps it current thereafter.
- ReportGenerator HTML/JsonSummary output — the prioritization map for which uncovered types to test first.

**Contracts:** No code/NuGet contract. Behavioral target: measured total line coverage ≥ 70% under the `-assemblyfilters:+*;-*.Tests` filter; `.github/coverage-baseline.json` present.
