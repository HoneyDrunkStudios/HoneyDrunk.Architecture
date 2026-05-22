---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["feature", "tier-2", "ops", "adr-0047", "wave-1"]
dependencies: []
adrs: ["ADR-0047"]
accepts: ["ADR-0047"]
wave: 1
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-standards
---

# Author the shared unit-test stack `Directory.Build.props` defaults for test projects

## Summary
Create a shared, importable `Directory.Build.props` fragment in `HoneyDrunk.Standards` that establishes the ADR-0047 D2 unit-test stack — xUnit (v2.x) + NSubstitute + AwesomeAssertions + coverlet — as the default `PackageReference` set and MSBuild property block for any project matching the `*.Tests.*` naming convention, so every Node consumes one canonical test-stack definition instead of drifting per-repo.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Standards`

## Motivation
ADR-0047 D2 commits the Grid to a single unit-test stack and D10 states that stack is the **default unit-test configuration in `Directory.Build.props`**. Today each Node declares its own test-package versions ad hoc — different xUnit minor versions, Moq vs. (in places) nothing, FluentAssertions where it appears. That drift is exactly what ADR-0047 closes. `HoneyDrunk.Standards` is the existing home for shared analyzers and EditorConfig already consumed Grid-wide (invariant 26 mandates it on every new .NET project), so it is the correct owner for a shared test-stack props fragment. Centralizing it means the Moq→NSubstitute and FluentAssertions→AwesomeAssertions migrations (packets 06–0N) only need each Node to delete its local package declarations and import the shared fragment.

This packet does **not** migrate any Node — it only authors the shared definition. Per-Node adoption happens in the migration packets.

## Proposed Implementation
ADR-0047 D2 — the committed unit-test stack:
- **xUnit v2.x** as the test framework (v3 is in development; adopt when stable — pin to a v2.x range).
- **NSubstitute** as the mocking library — **not Moq** (the 2023 SponsorLink stewardship incident; see D2).
- **AwesomeAssertions** as the assertion library — **not FluentAssertions** (v8 moved to a paid commercial license October 2024; AwesomeAssertions is the MIT community fork of the v7 API, drop-in compatible).
- **coverlet** as the coverage tool (`coverlet.collector`), integrates with `dotnet test`.

Approach:
1. Add a `props/HoneyDrunk.Tests.props` (or repo-convention-equivalent path) fragment to `HoneyDrunk.Standards` containing the test-stack `PackageReference` block: `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`, `NSubstitute`, `AwesomeAssertions`, `coverlet.collector`. Pin each to a current stable version (xUnit pinned to a v2.x range).
2. The fragment also sets the standard test-project MSBuild properties: `IsPackable=false`, `IsTestProject=true`, and the test-project exclusion from invariant 27's solution-version rule (test projects do not share the solution version — see invariant 27 "excluding test projects").
3. Document in the repo `README.md` how a Node test project imports the fragment (either via the package's MSBuild targets if `HoneyDrunk.Standards` ships as a package with build assets, or via an explicit `<Import>` — match the existing `HoneyDrunk.Standards` consumption mechanism).
4. Ship the fragment so it is consumed only by projects whose name matches `*.Tests.Unit`, `*.Tests.Integration`, `*.Tests.Integration.Containers`, `*.Tests.E2E`, `*.Tests.Benchmarks` — i.e. it must not leak test-package references into runtime projects (invariant 16: no test code in runtime packages; the same spirit forbids test packages in runtime `.csproj`).

## Affected Packages
- `HoneyDrunk.Standards` — gains the test-stack props fragment and its packaging/targets wiring.

## NuGet Dependencies
This packet authors a props fragment that **declares** the following `PackageReference` entries for consuming test projects (it does not add them to `HoneyDrunk.Standards`'s own runtime projects):

- `xunit` — pinned to a stable v2.x version (ADR-0047 D2 pins xUnit v2.x for consumption stability).
- `xunit.runner.visualstudio` — matching v2.x runner.
- `Microsoft.NET.Test.Sdk` — current stable.
- `NSubstitute` — current stable.
- `AwesomeAssertions` — current stable (the MIT fork of FluentAssertions v7).
- `coverlet.collector` — current stable.

`HoneyDrunk.Standards` is modeled in `repos/HoneyDrunk.Standards/` (overview + boundaries) and `catalogs/nodes.json` (id `honeydrunk-standards`) as the Grid's shared analyzer / EditorConfig / build-tooling repo — a library-only, no-vault Meta Node whose packages are consumed at compile time with `PrivateAssets: all` (invariant 26). It already ships at least one analyzer package (the StyleCop + EditorConfig set referenced Grid-wide); the test-stack props fragment is the same class of artifact — a packaged MSBuild build asset, not a runtime project. Preferred mechanism: ship the fragment as static MSBuild `build/` content inside the **existing** `HoneyDrunk.Standards` build-assets package, so no new `.csproj` is created and no new analyzer reference is needed. Only if the repo's current packaging cannot carry an additional build asset should a new build-assets `.csproj` be added — and that project must then reference the `HoneyDrunk.Standards` analyzers with `PrivateAssets: all` per invariant 26. Record the chosen mechanism in the PR.

## Boundary Check
- [x] Shared build-tooling defaults belong in `HoneyDrunk.Standards` — it already owns the Grid-wide analyzer + EditorConfig set consumed by every .NET repo (invariant 26).
- [x] No Node behavior changes; this packet only publishes a definition. Per-Node adoption is separate (packets 06–0N).
- [x] Does not duplicate any other Node's responsibility.

## Acceptance Criteria
- [ ] `HoneyDrunk.Standards` contains a test-stack `Directory.Build.props` fragment declaring exactly the ADR-0047 D2 stack: xUnit v2.x, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`, NSubstitute, AwesomeAssertions, `coverlet.collector`.
- [ ] The fragment sets `IsPackable=false` and `IsTestProject=true` on consuming projects.
- [ ] The fragment is scoped so it applies only to `*.Tests.*` projects and never leaks test packages into runtime `.csproj` files.
- [ ] No Moq and no FluentAssertions reference appears anywhere in the fragment.
- [ ] xUnit is pinned to a v2.x range (not v3).
- [ ] Repo `README.md` documents how a Node test project consumes the fragment.
- [ ] Repo-level `CHANGELOG.md` updated — new version entry (this is the bumping packet for `HoneyDrunk.Standards` in this initiative); per-package `CHANGELOG.md` updated for the package that gained the fragment.
- [ ] Build green; existing `HoneyDrunk.Standards` consumers unaffected (analyzer/EditorConfig behavior unchanged).

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0047 D2 — Unit-test stack.** The committed unit-test stack is xUnit (v2.x, for consumption stability — v3 is in development, adopt when stable) + NSubstitute (not Moq — the 2023 SponsorLink incident damaged Moq's stewardship trust) + AwesomeAssertions (not FluentAssertions — v8 moved to a paid commercial license; AwesomeAssertions is the MIT community fork of the v7 API, drop-in compatible) + coverlet. This combined stack is the default unit-test configuration in `Directory.Build.props` per D10.

**ADR-0047 D10 — Structure conventions.** Test projects follow the naming convention `HoneyDrunk.<Node>.Tests.Unit` / `.Tests.Integration` / `.Tests.Integration.Containers` / `.Tests.E2E` / `.Tests.Benchmarks`. The shared props fragment keys off this convention.

## Dependencies
None. This is the foundational packet of Wave 1 — the migration packets (06–0N) depend on it.

## Labels
`feature`, `tier-2`, `ops`, `adr-0047`, `wave-1`

## Agent Handoff

**Objective:** Author a shared `Directory.Build.props` test-stack fragment in `HoneyDrunk.Standards` defining the ADR-0047 D2 unit-test stack (xUnit v2.x + NSubstitute + AwesomeAssertions + coverlet) for Grid-wide consumption by `*.Tests.*` projects.

**Target:** HoneyDrunk.Standards, branch from `main`.

**Context:**
- Goal: One canonical test-stack definition; eliminate per-Node test-package drift.
- Feature: ADR-0047 Testing Patterns and Tooling initiative (`adr-0047-testing-patterns-and-tooling`).
- ADRs: ADR-0047 (this decision).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- **Invariant 16 — No test code in runtime packages.** "Tests live in dedicated `.Tests` or `.Canary` projects only." The props fragment must be scoped so it never adds test packages (xUnit, NSubstitute, AwesomeAssertions, coverlet) to a runtime `.csproj`. Scope it to the `*.Tests.*` naming convention.
- **Invariant 26 — Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section.** "`HoneyDrunk.Standards` must be explicitly listed on every new .NET project (StyleCop + EditorConfig analyzers, `PrivateAssets: all`)." If this packet creates a new `.csproj` in `HoneyDrunk.Standards` to host the fragment as build assets, that project must reference `HoneyDrunk.Standards` analyzers with `PrivateAssets: all`.
- **Invariant 27 — All projects in a solution share one version, excluding test projects.** The fragment must set `IsTestProject=true` so consuming test projects are correctly excluded from solution-version moves.
- **xUnit v2.x only** — do not adopt xUnit v3; ADR-0047 D2 explicitly pins v2.x.
- **No Moq, no FluentAssertions** anywhere in the fragment — those are exactly the libraries ADR-0047 D2 replaces.

**Key Files:**
- New props fragment under `HoneyDrunk.Standards` (path per repo convention, e.g. `props/HoneyDrunk.Tests.props`).
- `README.md` — consumption documentation.
- `CHANGELOG.md` (repo-level + per-package).

**Contracts:** None — this is build tooling, not a runtime contract. No `catalogs/contracts.json` change.
