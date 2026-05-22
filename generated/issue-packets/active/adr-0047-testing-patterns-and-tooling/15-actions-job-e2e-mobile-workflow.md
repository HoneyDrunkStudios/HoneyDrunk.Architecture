---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ci-cd", "ops", "adr-0047", "wave-5"]
dependencies: ["packet:13"]
adrs: ["ADR-0047"]
accepts: ["ADR-0047"]
wave: 5
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-actions
---

# Author `job-e2e-mobile.yml` reusable workflow for Maestro mobile E2E tests

## Summary
Add a new reusable workflow `job-e2e-mobile.yml` in `HoneyDrunk.Actions` that runs Maestro mobile E2E flows (`maestro test`) against an iOS simulator (macOS runner) and/or an Android emulator (Linux runner), invoked on tag deploy for mobile apps and nightly against test builds. This closes ADR-0047 D11's E2E-mobile slot and completes the four-workflow set the ADR commits.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## PARKED — gating note
**ADR-0047 D14 Phase 5 states: "When first mobile app ships … Zero work until then."** This packet is scoped now so the workflow exists the moment the first consumer mobile app needs it, but it should **not be filed as a GitHub Issue until the first mobile app repo exists**. The `file-issues` agent must hold this packet until the mobile-platform ADR (currently in the backlog) lands and the first consumer app (per PDR-0003 Lately / PDR-0004 Wayside / PDR-0005-0008) is scaffolded. Filing it earlier produces a CI workflow with zero consumers and zero way to validate it. The dispatch plan records this packet as parked in Wave 5.

## Motivation
ADR-0047 D11 commits E2E mobile to "`maestro test` in `job-e2e-mobile.yml`; runs on tag deploy for mobile apps; nightly against test builds." D6 commits Maestro as the mobile E2E tool — declarative YAML, cross-platform, platform-agnostic (works with .NET MAUI, Expo, native, React Native), which matters because the mobile-platform ADR is still in the backlog. Authoring the workflow ahead of the first app means the first mobile-app PR does not re-litigate the CI shape under deadline pressure.

## Proposed Change
Create `.github/workflows/job-e2e-mobile.yml` following the `job-*.yml` reusable-workflow conventions.

### Workflow shape
- `workflow_call` with inputs: `platform` (`ios` | `android` | `both`), `runs-on` (defaults: `macos-latest` for iOS simulator, `ubuntu-latest` for Android emulator — Maestro per ADR-0047 D6 "runs on iOS simulator on macOS runners and Android emulator on Linux runners"), `app-artifact` (the built app binary to install), `flows-path` (directory of Maestro YAML flows, default per the ADR-0047 D6 convention — `HoneyDrunk.<App>.Tests.Mobile`).
- Steps: checkout, download the built app artifact, set up the simulator/emulator (`ios`: Xcode simulator boot; `android`: an Android emulator action), install Maestro CLI, install the app on the simulator/emulator, run `maestro test {flows-path}`.
- On failure, upload Maestro's run output / screenshots as a workflow artifact (`if: failure()`).
- **Not a PR check.** Per ADR-0047 D6/D11: tag deploy for mobile apps + nightly against test builds. Header documents the trigger contract; a job-level `if:` guard refuses `pull_request` events as defence-in-depth.
- Header comment block documents the E2E-mobile tier, the trigger contract, the platform matrix, and that Maestro flows are YAML (not C#) — the one place in the testing pyramid that is not a .NET project (ADR-0047 D6).

### Wiring
Do **not** wire this anywhere. No mobile app exists. The first mobile-app repo's caller workflow wires it when that app ships.

## Consumer Impact
- None at authoring time — no mobile app exists. The first mobile-app repo consumes it on tag deploy.

## Breaking Change?
- [x] No — new workflow, zero consumers until the first mobile app ships.

## NuGet Dependencies
None. Maestro is a standalone CLI; the flows are YAML, not a .NET project (ADR-0047 D6). No `<PackageReference>` is added by this packet.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Routing rule "workflow, CI, GitHub Actions → HoneyDrunk.Actions" maps exactly.
- [x] No code change in any consuming repo (none exists).
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `.github/workflows/job-e2e-mobile.yml` exists, `workflow_call`-exposed, with the inputs and steps above
- [ ] The workflow supports `ios` (macOS runner, iOS simulator), `android` (Linux runner, Android emulator), and `both`
- [ ] The workflow installs the Maestro CLI and runs `maestro test` against the `flows-path` directory
- [ ] On failure, Maestro run output / screenshots are uploaded as a workflow artifact
- [ ] A job-level `if:` guard refuses `pull_request` events
- [ ] The workflow is not wired into any caller workflow
- [ ] Header comment documents the E2E-mobile tier, the tag-deploy/nightly trigger contract, the platform matrix, and the YAML-flows note
- [ ] `docs/CHANGELOG.md` updated; `docs/consumer-usage.md` updated to document the E2E-mobile workflow
- [ ] `README.md` workflow-list section updated if one exists
- [ ] `.github/workflows/job-e2e-mobile.yml` lints clean under `actionlint`

## Human Prerequisites
- [ ] **The first consumer mobile app must exist** before this packet is filed as a GitHub Issue (see the PARKED gating note). The mobile-platform ADR must land first. Until then, this packet stays in `active/` as a parked draft.
- [ ] macOS runner minutes — GitHub-hosted `macos-latest` runners are billed at a higher multiplier than Linux runners. The first time the iOS leg runs, confirm the Actions billing impact is acceptable; this is a cost-awareness check, not a blocker.

## Referenced ADR Decisions
**ADR-0047 D6 — E2E mobile is Maestro.** Declarative YAML, cross-platform (iOS + Android), works with native / React Native / Flutter / .NET MAUI — platform-agnostic, which matters because the mobile-platform ADR is still in the backlog. "Runs on iOS simulator on macOS runners and Android emulator on Linux runners." Mobile E2E tests live in `HoneyDrunk.<App>.Tests.Mobile` projects/directories. "Initial scope: zero until the first consumer app actually exists; the tooling commitment is recorded so the first app doesn't re-litigate it."

**ADR-0047 D11 — CI integration.** E2E mobile: `maestro test` in `job-e2e-mobile.yml`; runs on tag deploy for mobile apps and nightly against test builds; "Yes on tag deploy; advisory on nightly."

**ADR-0047 D14 Phase 5.** "When first mobile app ships — Author `job-e2e-mobile.yml` with Maestro. Zero work until then."

## Constraints
- **Do not file this packet as a GitHub Issue until the first mobile app exists.** Per ADR-0047 D14 Phase 5 — the `file-issues` agent holds it.
- **Never on `pull_request`** — tag-deploy + nightly only.
- **Maestro flows are YAML, not C#** — this is the one workflow in the set that does not run `dotnet test`.
- **Reusable workflow lives in HoneyDrunk.Actions** per ADR-0012.

## Labels
`feature`, `tier-2`, `ci-cd`, `ops`, `adr-0047`, `wave-5`

## Agent Handoff

**Objective:** Ship `job-e2e-mobile.yml` as a reusable workflow in `HoneyDrunk.Actions` running Maestro mobile E2E flows on iOS simulator / Android emulator, tag-deploy and nightly triggers only.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Record the Maestro CI shape so the first mobile-app PR does not re-litigate it.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 5 (PARKED until the first mobile app ships).
- ADRs: ADR-0047 (D6, D11, D14 Phase 5), ADR-0012 (reusable workflows live in Actions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:13 — `job-e2e-web.yml` establishes the E2E reusable-workflow pattern (trigger guard, failure-artifact upload) this mirrors.

**Constraints:**
- PARKED — not filed until the first mobile app exists (ADR-0047 D14 Phase 5).
- Never on `pull_request`.
- Maestro flows are YAML, not a .NET project.

**Key Files:**
- `.github/workflows/job-e2e-mobile.yml` (new)
- `.github/workflows/job-e2e-web.yml` (packet 13 — style + trigger-guard reference)
- `docs/CHANGELOG.md`, `docs/consumer-usage.md`, `README.md`

**Contracts:** None changed.
