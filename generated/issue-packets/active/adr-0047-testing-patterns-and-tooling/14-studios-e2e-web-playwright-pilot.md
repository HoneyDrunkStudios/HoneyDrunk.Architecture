---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Studios
labels: ["feature", "tier-2", "meta", "adr-0047", "wave-4"]
dependencies: ["packet:01", "packet:12"]
adrs: ["ADR-0047", "ADR-0029"]
accepts: ["ADR-0047"]
wave: 4
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-studios
---

# Pilot E2E web on Studios — `HoneyDrunk.Studios.Tests.E2E` with Playwright (.NET) and nightly schedule

## Summary
Stand up the Grid's first E2E web test project — `HoneyDrunk.Studios.Tests.E2E` — using the Playwright .NET binding to drive a browser against the deployed Studios marketing site, covering the critical paths (home, key landing pages, blog index, navigation), and add the nightly-schedule caller workflow that invokes `job-e2e-web.yml` (packet 12) against the `dev` environment.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Studios`

## Motivation
ADR-0047 D14 Phase 4: "Author `job-e2e-web.yml`. Pilot against `HoneyDrunk.Studios.Tests.E2E` (lowest-risk first surface). Wire nightly schedule against `dev`." ADR-0047 D5 names Studios as the first E2E surface: "HoneyDrunk.Studios.Tests.E2E — marketing site (per ADR-0029)." Studios is the lowest-risk first surface — a marketing site with no tenant data, no auth-critical paths — so it is the right place to prove the Playwright pattern before the higher-stakes surfaces (HoneyHub UI, Notify Cloud portal) land.

## Proposed Implementation
1. Create `tests/HoneyDrunk.Studios.Tests.E2E/` per the ADR-0047 D10 project layout (note: Studios is a Next.js repo, but the E2E tests are a .NET project per ADR-0047 D5's language-consistency decision — the test project sits alongside the site source).
2. Adopt the shared test-stack props fragment from packet 01 (xUnit runner + AwesomeAssertions — D5: "reuses the same test runner (xUnit) and assertion library (AwesomeAssertions) as the rest of the pyramid").
3. Add `Microsoft.Playwright` (the .NET binding).
4. Author the pilot critical-path E2E suite — keep it small (ADR-0047 D5 cost discipline; the `prod` smoke subset is "5-10 critical-path tests"). Cover:
   - The home page loads and renders the primary hero/nav.
   - Key marketing landing pages load without error.
   - The blog index loads and lists posts.
   - Primary navigation works (clicking nav links reaches the expected pages).
   - No console errors / no 404s on the critical paths.
5. Test fixtures read the target URL from an environment variable (the `base-url` the `job-e2e-web.yml` workflow passes — packet 12), so the same suite runs against `dev`, `staging`, or `prod`.
6. Add a **nightly-schedule caller workflow** in `HoneyDrunk.Studios` (`.github/workflows/e2e-nightly.yml` or repo-convention name) that invokes `job-e2e-web.yml` (packet 12) on a `schedule` cron against the `dev` Studios URL. Per ADR-0047 D11 the nightly `dev` run is **advisory** (not blocking). Optionally also wire a `staging`-tag-deploy trigger where the nightly run is blocking on `staging` — include it if Studios already has a `staging` tag-deploy flow; otherwise scope this packet to the nightly `dev` schedule and note the `staging` wiring as deferred.
7. Use the packet-07 integration-test scaffold conventions for naming/structure (the D10 conventions apply to E2E projects too).

## Affected Packages
- New test project `HoneyDrunk.Studios.Tests.E2E` — test-only addition.

## NuGet Dependencies
New test project `HoneyDrunk.Studios.Tests.E2E` `PackageReference` set:
- `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`, `NSubstitute`, `AwesomeAssertions`, `coverlet.collector` — inherited from the packet-01 test-stack props fragment (xUnit pinned v2.x).
- `Microsoft.Playwright` — current stable (the .NET Playwright binding).
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26 — mandatory on every new .NET project).

No runtime `.csproj` is touched. If `HoneyDrunk.Studios` (a Next.js repo) has no existing .NET solution, the E2E project is a standalone .NET project — the agent records in the PR how it is built in CI (the `job-e2e-web.yml` workflow's `project-path` input points at it).

## Boundary Check
- [x] The Studios marketing site is `HoneyDrunk.Studios`'s own surface (routing keyword map: "website, Studios, Next.js, pages, blog → HoneyDrunk.Studios").
- [x] Test-only addition — no change to the marketing site itself.
- [x] No new cross-Node runtime dependency — Playwright is a test-time dependency (invariant 16).

## Acceptance Criteria
- [ ] `tests/HoneyDrunk.Studios.Tests.E2E/` exists, named per ADR-0047 D10
- [ ] The project consumes the packet-01 test-stack props fragment and references `Microsoft.Playwright`
- [ ] A small critical-path E2E suite covers home page, key landing pages, blog index, primary navigation, and console-error/404 checks
- [ ] Test fixtures read the target URL from an environment variable so the suite runs against `dev` / `staging` / `prod`
- [ ] A nightly-schedule caller workflow invokes `job-e2e-web.yml` (packet 12) against the `dev` Studios URL on a cron; the nightly `dev` run is advisory per ADR-0047 D11
- [ ] (If Studios has a `staging` tag-deploy flow) a `staging`-tag trigger invokes the E2E suite as a blocking check; otherwise the `staging` wiring is explicitly noted as deferred in the PR
- [ ] No `Thread.Sleep` in the E2E test code (invariant 51) — use Playwright's built-in auto-waiting and explicit `await` for navigation/locator readiness
- [ ] `HoneyDrunk.Standards` analyzers referenced on the new project with `PrivateAssets: all` (invariant 26)
- [ ] Repo-level `CHANGELOG.md`: a tooling/test entry (invariant 12) — test-only, no site version bump
- [ ] The new test project has a `README.md` describing its scope and how to run it locally (invariant 12)
- [ ] The E2E suite passes against the deployed Studios `dev` site

## Human Prerequisites
- [ ] **The Studios marketing site must be deployed to the `dev` environment** before the nightly E2E run can pass. ADR-0047 Consequences: "Phase 4's Playwright pilot requires the Studios marketing site deployed to `dev`. Ahead of that being live, Phase 4 can't start." If the `dev` deployment is not yet live, this packet can land the test project and the caller workflow, but the first green nightly run is gated on the deployment. Confirm the `dev` Studios URL and supply it as the workflow's `base-url`.

## Referenced ADR Decisions
**ADR-0047 D5 — E2E web is Playwright (.NET binding).** `Microsoft.Playwright`, language-consistency rationale. "HoneyDrunk.Studios.Tests.E2E — marketing site (per ADR-0029)." Execution: nightly against `dev`, on `staging` tag deploy, `prod` post-deploy smoke (5-10 critical-path tests).

**ADR-0047 D1 — Tier 3 (E2E).** Full deployed environment, browser-driven; `< 60s` per test, suite `< 30min`; not on every PR.

**ADR-0047 D11 — CI integration.** E2E web nightly on `dev` is advisory; on `staging` tag deploy it is blocking.

**ADR-0047 D14 Phase 4.** "Pilot against `HoneyDrunk.Studios.Tests.E2E` (lowest-risk first surface). Wire nightly schedule against `dev`."

**ADR-0029** — the Studios marketing site decision; Studios is the surface under test.

## Referenced Invariants
> **Invariant 16 — No test code in runtime packages.** The Playwright E2E project is a dedicated `*.Tests.E2E` project; Playwright never enters the site's runtime build.

> **Invariant 26 — `## NuGet Dependencies` + `HoneyDrunk.Standards` (`PrivateAssets: all`) on every new .NET project.**

> **Invariant 51 — Test code contains no `Thread.Sleep`.** Playwright's auto-waiting and explicit `await` replace any need for sleeps in E2E.

## Constraints
- **Keep the suite small.** ADR-0047 D5 cost discipline — E2E is expensive; the `prod` smoke subset is 5-10 tests. The pilot suite should be of that order, not exhaustive.
- **No `Thread.Sleep`** (invariant 51) — Playwright auto-waits; use locator/navigation `await`, never a sleep.
- **Never wire E2E into the PR path** — nightly + tag-deploy only.
- **Test-only** — no change to the marketing site.
- **The E2E project is a .NET project** per ADR-0047 D5's language-consistency decision, even though Studios is a Next.js repo.

## Labels
`feature`, `tier-2`, `meta`, `adr-0047`, `wave-4`

## Agent Handoff

**Objective:** Stand up `HoneyDrunk.Studios.Tests.E2E` (Playwright .NET) covering the marketing site's critical paths, and wire a nightly-schedule caller workflow that runs `job-e2e-web.yml` against `dev`.

**Target:** `HoneyDrunk.Studios`, branch from `main`.

**Context:**
- Goal: Prove the Playwright E2E pattern on the lowest-risk first web surface.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 4 pilot.
- ADRs: ADR-0047 (D1, D5, D11, D14 Phase 4), ADR-0029 (the Studios marketing site).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:01 — the shared test-stack props fragment.
- packet:12 — `job-e2e-web.yml` must exist to be invoked by Studios' nightly caller workflow.

**Constraints:**
- Keep the suite small (E2E cost discipline) — ~5-10 critical-path tests.
- No `Thread.Sleep` (invariant 51) — Playwright auto-waits.
- Never on the PR path — nightly + tag-deploy only.
- Test-only; the E2E project is a .NET project per ADR-0047 D5.
- `HoneyDrunk.Standards` analyzers `PrivateAssets: all` (invariant 26).

**Key Files:**
- `tests/HoneyDrunk.Studios.Tests.E2E/` (new project)
- `.github/workflows/e2e-nightly.yml` (new caller workflow — repo-convention name)
- `CHANGELOG.md` (repo-level — tooling/test entry)

**Contracts:** None changed — test-only.
