---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ci-cd", "ops", "adr-0047", "wave-4"]
dependencies: ["packet:06"]
adrs: ["ADR-0047", "ADR-0011"]
accepts: ["ADR-0047"]
wave: 4
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-actions
---

# Author `job-e2e-web.yml` reusable workflow for Playwright (.NET) E2E tests

## Summary
Add a new reusable workflow `job-e2e-web.yml` in `HoneyDrunk.Actions` that runs Playwright (.NET binding) browser-driven E2E tests (`dotnet test` against `*.Tests.E2E` projects), installs and caches the Playwright browser binaries, retains traces for failed runs, and is invoked nightly against `dev` and on `staging` tag deploy — not on every PR. This closes ADR-0011 Gap 3's E2E-web slot per ADR-0047 D11.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0047 D11 commits E2E web to "`dotnet test` in `job-e2e-web.yml`; runs nightly on `dev` and on `staging` tag deploy", and D14 Phase 4 schedules it: "Author `job-e2e-web.yml`. Pilot against `HoneyDrunk.Studios.Tests.E2E`. Wire nightly schedule against `dev`." ADR-0047 D12 confirms this fills ADR-0011 Gap 3 (E2E web). D5 commits the Playwright .NET binding.

This packet ships the workflow only. The Studios pilot (packet 13) authors the actual E2E tests and wires the nightly schedule. Per ADR-0047 D5, E2E is **not** a per-PR check — it runs nightly and on tag deploy for cost discipline, so this workflow is never wired into `pr-core.yml`.

## Proposed Change
Create `.github/workflows/job-e2e-web.yml` following the `job-*.yml` reusable-workflow conventions.

### Workflow shape
- `workflow_call` with inputs: `dotnet-version` (default `10.0.x`), `runs-on` (default `ubuntu-latest`), `working-directory`, `project-path`, and a `base-url` input (the deployed environment the E2E suite targets — e.g. the `dev` Studios URL); plus a `test-filter` input defaulting to a filter selecting `*.Tests.E2E` projects.
- Steps: checkout, `actions/setup-dotnet`, restore, build `--configuration Release`, then:
  - Install Playwright browsers: run the Playwright install script the .NET binding ships (`pwsh bin/.../playwright.ps1 install --with-deps` after build, or `dotnet tool` + `playwright install` — use whichever the `Microsoft.Playwright` .NET binding documents for CI).
  - Cache the Playwright browser binaries across runs (ADR-0047 D5: "Browser binaries cached across CI runs") — key the cache on the `Microsoft.Playwright` package version.
  - `dotnet test --filter "FullyQualifiedName~Tests.E2E" --configuration Release`, passing the `base-url` to the test run via an environment variable the test fixtures read.
  - On failure, upload Playwright trace files as a workflow artifact (ADR-0047 D5: "trace files retained for failed runs per ADR-0011 Gap 3's contract") — use `actions/upload-artifact` with `if: failure()`.
- Runtime budget per ADR-0047 D1: E2E suite target `< 30min`, `< 60s` per test.
- **Not a PR check.** The header documents that callers invoke this on `schedule` (nightly against `dev`) and on `push` of a `staging` tag — never on `pull_request`. Add a job-level `if:` guard refusing `pull_request` events as defence-in-depth (mirrors the SonarCloud-workflow precedent's trigger guard), so a misconfigured caller produces a skipped no-op rather than running a costly E2E suite on every PR.
- Header comment block documents the E2E tier, the trigger contract (nightly `dev` / `staging` tag deploy only), the browser-cache step, and the trace-retention step.

### Wiring
Do **not** wire this into `pr-core.yml`. The Studios pilot (packet 13) adds the nightly-schedule caller workflow in the Studios repo.

## Consumer Impact
- No consumer impact until a web-surface repo adds a `*.Tests.E2E` project and a nightly-schedule caller workflow (pilot: packet 13, Studios).

## Breaking Change?
- [x] No — new workflow, opt-in per web surface, never on the PR path.

## NuGet Dependencies
None. The workflow invokes `dotnet test` and the Playwright browser-install script; no project-level `<PackageReference>` is added by this packet. The `Microsoft.Playwright` package is added by the pilot packet (13) in the E2E test project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Routing rule "workflow, CI, GitHub Actions → HoneyDrunk.Actions" maps exactly.
- [x] No code change in any consuming repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `.github/workflows/job-e2e-web.yml` exists, `workflow_call`-exposed, with the inputs and steps above
- [ ] The workflow installs Playwright browsers and caches the binaries across runs, keyed on the `Microsoft.Playwright` version
- [ ] The `dotnet test` filter selects `*.Tests.E2E` projects; the `base-url` input is passed to the test run via environment variable
- [ ] On failure, Playwright trace files are uploaded as a workflow artifact (`if: failure()`)
- [ ] A job-level `if:` guard refuses `pull_request` events (defence-in-depth — E2E never runs on the PR path)
- [ ] The workflow is **not** wired into `pr-core.yml`
- [ ] Header comment documents the E2E tier, the nightly-`dev` / `staging`-tag trigger contract, the browser-cache step, and trace retention
- [ ] `docs/CHANGELOG.md` updated; `docs/consumer-usage.md` updated to document the E2E-web workflow and its trigger contract
- [ ] `README.md` workflow-list section updated if one exists
- [ ] `.github/workflows/job-e2e-web.yml` lints clean under `actionlint`

## Human Prerequisites
- [ ] The target deployed environment must exist for the workflow to run successfully against it. ADR-0047 Consequences: "Phase 4's Playwright pilot requires the Studios marketing site deployed to `dev`. Ahead of that being live, Phase 4 can't start." This workflow can be merged before the `dev` environment exists, but it cannot run green until the Studios `dev` deployment is live — that deployment is a prerequisite for the pilot packet (13), not for merging this workflow.

## Referenced ADR Decisions
**ADR-0047 D1 — Tier 3 (E2E).** Full deployed environment, real Azure resources, real network paths, browser-driven. `< 60s` per test, suite `< 30min`. "On `staging`-tag deploy and on nightly schedule against `dev`; not on every PR (cost)."

**ADR-0047 D5 — E2E web is Playwright (.NET binding).** `Microsoft.Playwright`, chosen for language consistency (one C# stack, shared xUnit runner and AwesomeAssertions). E2E projects named `HoneyDrunk.<Surface>.Tests.E2E`. "Browser binaries cached across CI runs; trace files retained for failed runs."

**ADR-0047 D11 — CI integration.** E2E web: `dotnet test` in `job-e2e-web.yml`; runs nightly on `dev` and on `staging` tag deploy; "Yes on `staging` tag; advisory on nightly `dev`."

**ADR-0047 D12 — Closes ADR-0011 Gap 3.** D5 commits Playwright; D11 commits this CI job.

## Constraints
- **Never on `pull_request`.** E2E is nightly + tag-deploy only per ADR-0047 D1/D5 cost discipline. The job-level `if:` guard enforces this as defence-in-depth.
- **Do not wire into `pr-core.yml`.**
- **Browser-binary caching is required** — Playwright browser downloads are large; caching is in the ADR-0047 D5 contract.
- **Trace retention on failure is required** — ADR-0047 D5 / ADR-0011 Gap 3 contract.
- **Reusable workflow lives in HoneyDrunk.Actions** per ADR-0012.

## Labels
`feature`, `tier-2`, `ci-cd`, `ops`, `adr-0047`, `wave-4`

## Agent Handoff

**Objective:** Ship `job-e2e-web.yml` as a reusable workflow in `HoneyDrunk.Actions` running Playwright (.NET) E2E tests — browser-binary caching, trace retention on failure, nightly/tag-deploy triggers only, never on PRs.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Close ADR-0011 Gap 3 (E2E web) with a real CI job; the Studios pilot wires it in.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 4.
- ADRs: ADR-0047 (D1, D5, D11, D12), ADR-0011 (Gap 3), ADR-0012 (reusable workflows live in Actions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:06 — `job-integration-tests.yml` establishes the test-workflow pattern this mirrors; sequence after 06.

**Constraints:**
- Never on `pull_request` — job-level `if:` guard enforces it.
- Not wired into `pr-core.yml`.
- Browser-binary caching + failure-trace retention are required (ADR-0047 D5 contract).

**Key Files:**
- `.github/workflows/job-e2e-web.yml` (new)
- `.github/workflows/job-integration-tests.yml` (packet 06 — style reference)
- `docs/CHANGELOG.md`, `docs/consumer-usage.md`, `README.md`

**Contracts:** None changed.
