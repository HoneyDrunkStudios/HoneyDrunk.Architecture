---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Cache
labels: ["feature", "tier-2", "cache", "scaffold", "adr-0059"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0059", "ADR-0058", "ADR-0009", "ADR-0012"]
accepts: ADR-0059
wave: 3
initiative: adr-0059-cache-standup
node: honeydrunk-cache
---

# Feature: Stand up the HoneyDrunk.Cache repo — solution, single placeholder project, Standards wiring, CI without contract-shape canary, README + CHANGELOG + LICENSE

## Summary
Bring the empty `HoneyDrunk.Cache` repo from zero to first-shippable state per ADR-0059 D3 + D8. Land the solution layout (`HoneyDrunk.Cache.slnx`), a single placeholder project (`HoneyDrunk.Cache.Adapters`) carrying the .NET version, analyzers, and CI wiring, `HoneyDrunk.Standards` wiring on the placeholder project, the standard CI pipeline (PR core + release + nightly deps + nightly security — **no `api-compatibility.yml`**, since Cache owns no contracts to canary at stand-up), repo-level `README.md` describing the Node's purpose and the empty-on-day-one stance, repo-level `CHANGELOG.md` starting at `0.0.1` with the stand-up entry, LICENSE confirmation. No backing implementations.

This is the bring-up from "empty Git repo" to "CI green on an empty solution." After this packet merges, the Cache Node is ready for its first feature packet (the first distributed backing implementation — Redis-class, Cosmos-with-TTL, or Postgres-with-TTL) whenever the first real consumer (likely Notify Cloud multi-replica or Communications shared cache) pulls on a distributed cache.

**No invariant numbers to substitute.** Per ADR-0059 §New invariants ("None at stand-up"), this initiative introduces no new constitutional invariants. The repo-local `repos/HoneyDrunk.Cache/invariants.md` (authored by packet 01) is the home for Cache-specific rules.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Cache`

## Motivation
ADR-0059 D3 + D8 specify the first-PR scaffold for HoneyDrunk.Cache. Packet 02 created the GitHub repo and cloned the local tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Cache/` (`.gitignore`, `LICENSE`, possibly a placeholder `README.md` only). Catalogs and the `repos/HoneyDrunk.Cache/` context folder are already in place (packet 01). This packet ships the code-side scaffold that proves the repo exists, CI runs green on the empty solution, and the Node is ready for the first feature packet.

ADR-0059's intentional scope at stand-up is **deliberately lean**:

- **No `ICacheStore<T>` contract authored here.** That lives in `HoneyDrunk.Kernel.Abstractions` per ADR-0058 D2. The scaffold does not invent it, does not reference it (the placeholder project is empty enough not to need it), and does not add any "draft contract" types.
- **No backing implementations.** No Redis adapter, no Cosmos adapter, no Postgres adapter. The first backing arrives in a separate feature packet when the first real consumer activates it. The choice between Redis-class vs Cosmos-with-TTL vs Postgres-with-TTL is deferred to the first feature packet — pre-deciding it now would freeze a choice without a real workload to validate against.
- **No `HoneyDrunk.Cache.Abstractions` package.** Cache declares no abstractions. The contract it implements lives in `HoneyDrunk.Kernel.Abstractions`. Inventing a `Cache.Abstractions` would be a deliberate departure from ADR-0059 D6 + ADR-0058 D2; this packet does not do that.
- **No contract-shape canary in CI.** Cache owns no contracts to freeze at stand-up. The `api-compatibility.yml` workflow that ships in AI / Capabilities / Audit / Communications scaffolds is **explicitly omitted** from this scaffold's `.github/workflows/`. If a future backing introduces its own public surface, that backing's packet adds the canary in the same edit as the backing implementation.

The scaffold is "the empty room with the right lighting" — solution, placeholder project, Standards wiring, CI to confirm the room exists, README to explain what it's for, CHANGELOG to record the stand-up. The furniture arrives later.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Cache/
├── HoneyDrunk.Cache.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── LICENSE                          (placed by packet 02; verify content matches Grid LICENSE)
├── .editorconfig                    (from HoneyDrunk.Standards)
├── .gitignore                       (from packet 02; extend as needed)
├── .github/
│   └── workflows/
│       ├── pr-core.yml              (calls Actions/pr-core.yml)
│       ├── release.yml              (calls Actions/release.yml; trigger ready but no tag pushed at stand-up)
│       ├── nightly-deps.yml         (calls Actions/nightly-deps.yml)
│       └── nightly-security.yml     (calls Actions/nightly-security.yml)
│       (NO api-compatibility.yml — Cache owns no contracts at stand-up)
└── src/
    └── HoneyDrunk.Cache.Adapters/
        ├── HoneyDrunk.Cache.Adapters.csproj
        ├── README.md
        └── CHANGELOG.md
        (no .cs files — the placeholder project is empty; HoneyDrunk.Standards wiring + CI build is the proof-of-life)
```

**No `tests/` directory at stand-up.** There is no production code to test on day one. When the first backing implementation lands, that packet adds the appropriate `tests/HoneyDrunk.Cache.Adapters.{Backing}.Tests/` project alongside the backing's source. Per ADR-0059 D8 ("No tests beyond an empty unit-test project — there's no production code to test on day one. Test invariants 14, 15, 16, 50, 51 still apply once the first backing lands"). At the executing agent's discretion: if `HoneyDrunk.Standards` or solution-build behavior requires at least one test project to satisfy a `Tests.Unit` expectation, add a single empty `tests/HoneyDrunk.Cache.Adapters.Tests.Unit/` xUnit project with one trivial test (`Assert.True(true)`) just so the solution structure matches the Grid's per-Node test layout convention. If `Standards` does not require it, skip the test project entirely. Note which path was taken in the PR body.

### Solution

`HoneyDrunk.Cache.slnx` references the single `src/HoneyDrunk.Cache.Adapters/` project (and the optional empty test project, if added per the note above). Solution-level `Directory.Build.props`:

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <Version>0.0.1</Version>
    <Authors>HoneyDrunk Studios</Authors>
    <PackageProjectUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Cache</PackageProjectUrl>
    <RepositoryUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Cache</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
    <PublishRepositoryUrl>true</PublishRepositoryUrl>
    <IncludeSymbols>true</IncludeSymbols>
    <SymbolPackageFormat>snupkg</SymbolPackageFormat>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
  </PropertyGroup>
</Project>
```

Per invariant 27 (all projects in a solution share one version and move together), the placeholder project carries `Version: 0.0.1` matching the solution-level `Directory.Build.props`. The version is `0.0.1` (not `0.1.0`) because the scaffold ships no production code — `0.0.x` reflects the empty-on-day-one stance. The first backing implementation packet will bump to `0.1.0` when there's real code to ship.

### Placeholder project — `HoneyDrunk.Cache.Adapters`

The `.csproj` is minimal:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <Description>Distributed-cache backing host for the Grid. Day-one placeholder — no backing implementations yet. Future backings (Redis, Cosmos-with-TTL, Postgres-with-TTL) ship as sibling adapter packages when their feature packets land.</Description>
    <PackageTags>cache;distributed-cache;backing;substrate;honeydrunk</PackageTags>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="HoneyDrunk.Standards" Version="*" PrivateAssets="all" />
  </ItemGroup>
</Project>
```

**No `.cs` files in the project.** The Standards wiring is the proof-of-life — analyzers and EditorConfig pull in, CI builds the empty assembly. If the C# compiler refuses to build a project with zero source files, add a single empty marker file at `src/HoneyDrunk.Cache.Adapters/Properties/AssemblyInfo.cs` containing only a documentation comment explaining that the file exists to satisfy the C# compiler for an intentionally-empty placeholder project. Note in the PR body which path was taken.

**No `HoneyDrunk.Kernel.Abstractions` reference at this stage.** The placeholder has no code that uses `ICacheStore<T>`, so adding the Kernel.Abstractions PackageReference would be dead weight. The first backing implementation packet adds it when there's actually code calling it.

### Documentation

- **Repo `README.md`** — purpose statement, what the Node owns and does not own, day-one empty-on-purpose stance, link to ADR-0059 in **runtime metadata reference fashion only** (not in narrative — per memory `feedback_no_adr_in_docs`). The exact narrative is up to the executing agent, but it must include:
  1. A purpose statement matching the `repos/HoneyDrunk.Cache/overview.md` framing: "Distributed-cache backing host for the Grid. Implements `ICacheStore<T>` (declared in `HoneyDrunk.Kernel.Abstractions`)."
  2. A "What this Node owns / does not own" section matching `repos/HoneyDrunk.Cache/boundaries.md`.
  3. A "Phase-1 honest limitation" section stating: "No backing implementations on day one. The first backing arrives when the first real consumer pulls on a distributed cache; the choice between Redis-class, Cosmos-with-TTL, and Postgres-with-TTL is deferred to the first feature packet."
  4. A "For downstream consumers" section showing copy-pasteable composition once a backing exists — but explicitly stating that no backing is available yet at `v0.0.1`. Example placeholder text: `// When the first backing ships, downstream hosts will compose it like: services.AddHoneyDrunkCacheAdapters{Backing}(...);  // No backings shipped at v0.0.1.`
  5. **Per memory `feedback_no_adr_in_docs`, the README narrative does NOT cite "ADR-0059" or "ADR-0058" by ADR number.** It can describe the Node's role and rationale in plain English without ADR citations.

- **Repo `CHANGELOG.md`** — `## [0.0.1] - YYYY-MM-DD` entry covering the scaffold. No `## Unreleased` block at commit time (per memory `feedback_no_unreleased_commits`). Entry text describes: solution + placeholder project created, Standards wiring applied, CI wired (build/test/security/package scans; no contract-shape canary), README and LICENSE in place. The version is `0.0.1` to reflect the empty-on-day-one stance.

- **Per-package `README.md`** + **`CHANGELOG.md`** for the placeholder project per invariant 12 (every package gets a README and CHANGELOG; new packages include creation of both in acceptance criteria). The per-package README explains that this project is the day-one placeholder for the backing-axis family and that future backings ship as sibling packages.

### CI workflows

All four workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows.

- **`pr-core.yml`** — calls `pr-core.yml@main`, `dotnet-version: '10.0.x'`. Standard PR gate.

- **`release.yml`** — `on: push: tags: [v*.*.*]`, calls `release.yml@main` with `enable-nuget-publish: true` and:

```yaml
    secrets:
      nuget-api-key: ${{ secrets.NUGET_API_KEY }}
```

The trigger is wired so the moment a tag is pushed (which won't happen at stand-up — see Human Prerequisites), the workflow runs. ACR auth is OIDC. Tags are human-pushed per invariant 27.

- **`nightly-deps.yml` / `nightly-security.yml`** — thin callers; copy `with:`/`secrets:` blocks verbatim from `HoneyDrunk.Audit` or `HoneyDrunk.Auth`.

- **NO `api-compatibility.yml`.** Per ADR-0059 D3 + D8 + §Negative, Cache owns no contracts to freeze at stand-up. The contract Cache implements (`ICacheStore<T>`) lives in `HoneyDrunk.Kernel.Abstractions` and is canaried by Kernel's surface. When the first backing implementation introduces its own public surface (configuration records, extension methods), that backing's packet adds `api-compatibility.yml` scoped to that backing's assembly in the same edit. This is the deliberate asymmetry vs AI / Capabilities / Audit / Communications standup scaffolds.

### `HoneyDrunk.Standards` wiring

The placeholder `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets="all"` per invariant 26:

```xml
<ItemGroup>
  <PackageReference Include="HoneyDrunk.Standards" Version="*" PrivateAssets="all" />
</ItemGroup>
```

This pulls in the StyleCop ruleset, `.editorconfig`, and analyzer suite that every Grid repo uses. The optional test project, if added per the note above, carries the same reference.

## Affected Files
Entire repo is created from this packet. Notable new files:
- `HoneyDrunk.Cache.slnx`, `Directory.Build.props`, `README.md`, `CHANGELOG.md`, `.editorconfig`
- `src/HoneyDrunk.Cache.Adapters/` — `.csproj`, `README.md`, `CHANGELOG.md` (no `.cs` files, OR a single empty `Properties/AssemblyInfo.cs` if the compiler requires it)
- `.github/workflows/` — 4 workflow files (`pr-core.yml`, `release.yml`, `nightly-deps.yml`, `nightly-security.yml`). **NO `api-compatibility.yml`.**
- Optional (only if Standards or solution-build requires): `tests/HoneyDrunk.Cache.Adapters.Tests.Unit/` — `.csproj`, single trivial xUnit test

## NuGet Dependencies

Every new `.csproj` lists `HoneyDrunk.Standards` (`PrivateAssets="all"`) per invariant 26.

### `HoneyDrunk.Cache.Adapters.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` — pulls in analyzers + EditorConfig + StyleCop ruleset |

**No `HoneyDrunk.Kernel.Abstractions` reference at stand-up.** The placeholder has no code calling `ICacheStore<T>`, so the reference would be dead weight. The first backing implementation packet adds the Kernel.Abstractions PackageReference when there's actual code consuming it.

### Optional test project (only if added)

`HoneyDrunk.Standards` (`PrivateAssets="all"`), `Microsoft.NET.Test.Sdk`, `xunit`, `xunit.runner.visualstudio`. No project reference to the placeholder (there's no code to test); the trivial `Assert.True(true)` test exists only to satisfy the Grid's per-Node test layout convention if `Standards` enforces it.

## Boundary Check

- [x] All work inside `HoneyDrunk.Cache`. No other Grid repos edited.
- [x] **No `HoneyDrunk.Cache.Abstractions` package authored.** Cache declares no abstractions. Inventing one would be a deliberate departure from ADR-0059 D6 + ADR-0058 D2; this scaffold does not do that.
- [x] **No `ICacheStore<T>` contract authored.** The contract lives in `HoneyDrunk.Kernel.Abstractions` per ADR-0058 D2. The scaffold does not invent it.
- [x] **No `InMemoryCacheStore<T>` reference implementation.** That lives in `HoneyDrunk.Kernel` per ADR-0058 D4. Not in Cache.
- [x] **No backing implementation** (Redis, Cosmos, Postgres, or otherwise). Per ADR-0059 D3 + D8.
- [x] **No `HoneyDrunk.Kernel.Abstractions` PackageReference.** The placeholder has no code that uses Kernel types; the reference would be dead weight.
- [x] **No `api-compatibility.yml` workflow.** Cache owns no contracts to freeze at stand-up.
- [x] **No `HoneyDrunk.Pulse` reference anywhere.** Pulse is one-way from Cache's perspective (telemetry will flow there via Kernel's `ITelemetryActivityFactory` when backings exist). The scaffold has no telemetry-emitting code, so no reference is needed at stand-up.
- [x] No tests beyond an optional empty `Tests.Unit` project (only if Standards or solution-build requires it). Per ADR-0059 D8.
- [x] No Azure resource provisioning required for this packet (HoneyDrunk.Cache is a library Node at Phase 1, not a deployable). Per ADR-0059 D2 + D3 + §Consequences.

## Acceptance Criteria

- [ ] `HoneyDrunk.Cache.slnx` builds clean from a fresh clone via `dotnet build` with no warnings (warnings-as-errors). Empty placeholder builds; if the C# compiler complains about zero source files in `HoneyDrunk.Cache.Adapters`, the single empty `Properties/AssemblyInfo.cs` marker file is added (PR body notes the decision).
- [ ] **`HoneyDrunk.Cache.Adapters` is the only `src/*` project.** No `src/HoneyDrunk.Cache.Abstractions/`, no `src/HoneyDrunk.Cache.{Backing}/`, no `src/HoneyDrunk.Cache/` runtime — exactly one placeholder project.
- [ ] **`HoneyDrunk.Cache.Adapters` has no `.cs` source files (or exactly one empty marker file `Properties/AssemblyInfo.cs` if the compiler requires it).** The project is a placeholder; production code arrives with the first backing.
- [ ] **`HoneyDrunk.Cache.Adapters.csproj` carries no `HoneyDrunk.*` PackageReference other than `HoneyDrunk.Standards` (with `PrivateAssets="all"`).** No `HoneyDrunk.Kernel`, no `HoneyDrunk.Kernel.Abstractions`, no other Grid package. The placeholder has no code consuming any Grid type.
- [ ] **No `HoneyDrunk.Cache.Abstractions` project exists.** Verify with `dotnet sln list` and with a grep for the string across the repo — zero matches expected. Cache declares no abstractions.
- [ ] **No `ICacheStore<T>` type defined anywhere in the repo.** Verify with grep — zero matches. The contract lives in `HoneyDrunk.Kernel.Abstractions` (ADR-0058 D2); the scaffold does not re-declare it.
- [ ] **No `InMemoryCacheStore<T>` type defined anywhere.** That lives in `HoneyDrunk.Kernel` (ADR-0058 D4).
- [ ] **No backing implementation present.** No `RedisCacheStore`, no `CosmosCacheStore`, no `PostgresCacheStore`, no `*CacheBacking`, no any-other-named-backing type. Verify with grep across the entire repo for these strings; zero matches expected.
- [ ] **No `api-compatibility.yml` workflow.** `.github/workflows/` contains exactly four files: `pr-core.yml`, `release.yml`, `nightly-deps.yml`, `nightly-security.yml`. Verify with `ls`.
- [ ] All four `.github/workflows/*.yml` files reference `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/*@main`.
- [ ] `pr-core.yml` passes on the initial scaffolding PR (build + tests + analyzers + dependency scan + secret scan). If a test project was added per the optional path, the trivial test passes.
- [ ] `release.yml` workflow exists and is configured to trigger on `tags: [v*.*.*]` — but **no tag is pushed as part of this packet**. The first tag-push waits until the first backing implementation lands. (Verify the trigger configuration; do not actually push a tag.)
- [ ] Repo-level `CHANGELOG.md` has a `## [0.0.1] - YYYY-MM-DD` entry covering the scaffold (per invariants 12, 27, and memory `feedback_no_unreleased_commits` — no `## Unreleased` block at commit time). The version is `0.0.1` (not `0.1.0`) to reflect the empty-on-day-one stance.
- [ ] Per-package `CHANGELOG.md` for `HoneyDrunk.Cache.Adapters` has its own `## [0.0.1]` entry naming the package's day-one placeholder role (per invariants 12 and 27).
- [ ] Repo-level `README.md` and `src/HoneyDrunk.Cache.Adapters/README.md` both present per invariant 12. Repo-level README includes (a) purpose statement matching `repos/HoneyDrunk.Cache/overview.md`, (b) "What this Node owns / does not own" section matching `repos/HoneyDrunk.Cache/boundaries.md`, (c) "Phase-1 honest limitation" section stating no backing implementations on day one, (d) "For downstream consumers" section explicitly noting no backings shipped at `v0.0.1`.
- [ ] **The repo-level README does NOT cite "ADR-0059" or "ADR-0058" by ADR number in narrative paragraphs.** Per memory `feedback_no_adr_in_docs`. (Runtime metadata references — CHANGELOG entries, frontmatter on filed packets — are fine; the README is user-facing narrative.)
- [ ] `LICENSE` file matches the Grid's existing LICENSE choice on `HoneyDrunk.Audit`, `HoneyDrunk.Kernel`, and other public Grid repos (likely MIT — confirm at scaffold time and note in PR body).
- [ ] The placeholder project in the solution carries `Version: 0.0.1` (excluding test projects if any added per the optional path; invariant 27 applies).
- [ ] Manual confirmation that pushing a tag (e.g., `v0.0.2` if/when a small follow-up arrives) would trigger `release.yml` — do not actually push the tag at this time. Verify the workflow exists and a tag-push trigger is configured.
- [ ] **No `.github/dependabot.yml` file exists.** Per ADR-0009, dependency-scanning lives in the nightly workflows; no Dependabot config file is committed.
- [ ] **No `tests/` directory** (or only an optional empty `tests/HoneyDrunk.Cache.Adapters.Tests.Unit/` xUnit project with a single trivial `Assert.True(true)` test if `Standards` or solution-build requires it). The PR body notes which path was taken and why.

## Human Prerequisites

- [ ] Packet 02 of this initiative complete — `HoneyDrunkStudios/HoneyDrunk.Cache` repo exists on GitHub with org-default branch protection, labels seeded, OIDC federated credential wired, and the local working tree cloned at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Cache/`.
- [ ] Packet 01 of this initiative merged — the `repos/HoneyDrunk.Cache/` context folder exists in the Architecture repo, the four catalogs (nodes/relationships/grid-health/modules) carry the `honeydrunk-cache` entries, `constitution/sectors.md` Core table includes Cache, and the tech-stack and roadmap reference docs are reconciled. This packet's README cross-references `repos/HoneyDrunk.Cache/overview.md` and `boundaries.md`.
- [ ] **No tag-push as part of this packet.** The scaffold has no production code to publish — `0.0.1` is a placeholder version for an empty solution. The first tag-push waits until the first backing implementation lands (separate feature packet, separate human prerequisite at that time).
- [ ] **`NUGET_API_KEY` repository (or org-level) secret is available to the `HoneyDrunk.Cache` repo before any tag is ever pushed.** Not blocking for this packet (no tag-push here), but verify the secret is bound to this repo as part of packet 02's repo-creation chore — see packet 02 Step 4 / 6. Org-level `NUGET_API_KEY` (shared with other HoneyDrunk repos publishing to nuget.org) is the standard approach.
- [ ] **Branch protection sequencing.** Branch protection on `main` was set by packet 02 requiring only `pr-core / core`. **`api-compatibility` is NOT required** because Cache owns no contracts at stand-up. When a future backing introduces its own public surface and adds an `api-compatibility.yml` workflow, that backing's packet updates branch protection in the same edit.
- [ ] **No Azure resource provisioning required for this packet.** HoneyDrunk.Cache is a library Node at Phase 1, not a deployable. Managed identity, Container App, App Configuration keys for backing configuration, Azure Cache for Redis instance — all deferred until the first deployable host composes a Cache backing. Cross-link: [`infrastructure/walkthroughs/azure-provisioning-guide.md`](../../../../infrastructure/walkthroughs/azure-provisioning-guide.md) for when that work lands.
- [ ] After this packet's PR merges, file a small follow-up to add `HoneyDrunk.Cache` to the grid-health aggregator's watched-repos list in `HoneyDrunk.Actions` — only if the aggregator does not auto-discover from `catalogs/nodes.json`. Verify which behavior is in place at the time this prereq is being checked. (If auto-discovery is wired, packet 01's `grid-health.json` edit is sufficient and this prereq is satisfied automatically.)
- [ ] After this packet's PR merges, file a SonarCloud onboarding follow-up packet for `HoneyDrunk.Cache` modeled on the closest-matching prior onboarding packet (likely `generated/issue-packets/active/adr-0011-code-review-pipeline/06-kernel-sonarcloud-onboarding.md` or a more recent equivalent). Note: with an empty placeholder project, SonarCloud has little to analyze — the onboarding can be deferred until the first backing implementation ships actual code, if that fits the user's preference. Confirm at follow-up time.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Cache does not ship an Abstractions package. This packet does not author one. The contract Cache implements (`ICacheStore<T>`) lives in `HoneyDrunk.Kernel.Abstractions` where Grid-wide primitives live.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — At stand-up, Cache has no code consuming any Grid package, so no PackageReference to `HoneyDrunk.*` (other than Standards). When the first backing implementation lands, it adds `HoneyDrunk.Kernel.Abstractions` as a one-way edge.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — This scaffold establishes the solution, CI, and versioning for the Cache Node.

> **Invariant 12:** Every shipped package has a CHANGELOG.md and README.md. New packages and new repos include their creation in acceptance criteria. — This scaffold creates `CHANGELOG.md` and `README.md` at the repo root and per-package for `HoneyDrunk.Cache.Adapters`.

> **Invariant 26:** Every project consumes `HoneyDrunk.Standards` via `PackageReference` with `PrivateAssets="all"`. — The placeholder project's `.csproj` carries this reference.

> **Invariant 27:** All projects in a solution share one version and move together. The optional empty test project (if added) is excluded from version-bump scope. — The placeholder carries `Version: 0.0.1` matching the solution `Directory.Build.props`.

## Referenced ADR Decisions

**ADR-0059 D1 (Cache Node ownership):** HoneyDrunk.Cache is the Core sector's single Node owning distributed-cache backing implementations of `ICacheStore<T>`. The scaffold establishes the repo home; it does not author any backing.

**ADR-0059 D3 (Initial scaffolding boundary):** First PR produces an empty solution with a single placeholder project (`HoneyDrunk.Cache.Adapters`). HoneyDrunk.Standards wiring, CI pipeline consuming HoneyDrunk.Actions shared workflows, README, CHANGELOG, LICENSE. **No implementations.** The scaffold is the empty room with the right lighting; the furniture arrives with the first feature packet. This packet executes exactly that.

**ADR-0059 D6 (Boundaries — Cache declares no abstractions of its own):** Cache implements `ICacheStore<T>` (which lives in `HoneyDrunk.Kernel.Abstractions`); it does not declare it. This packet does not invent a `HoneyDrunk.Cache.Abstractions` package or any draft contracts.

**ADR-0059 D8 (Standup checklist — what scaffolds in the first PR):** Solution with single placeholder project, Standards wiring, CI pipeline (PR core + release + nightly deps + nightly security; **NO contract-shape canary** — Cache owns no Cache-owned contracts to canary against; the contract lives in Kernel and is guarded by Kernel's canary surface), README, CHANGELOG at `0.0.1`, LICENSE, no tests beyond an empty unit-test project. This packet's acceptance criteria mirror this checklist line-by-line.

**ADR-0058 D2 (paired context — `ICacheStore<T>` lives in `HoneyDrunk.Kernel.Abstractions`):** The contract Cache implements is committed to Kernel's surface by ADR-0058. This packet does NOT author the contract — that work belongs to ADR-0058's acceptance initiative. Cache's first backing implementation packet adds the `HoneyDrunk.Kernel.Abstractions` PackageReference when there's actual code consuming the contract.

**ADR-0058 D4 (paired context — `InMemoryCacheStore<T>` lives in `HoneyDrunk.Kernel`):** The reference in-memory implementation is committed to Kernel by ADR-0058. This packet does NOT author it. Cache hosts distributed backings only.

**ADR-0009 (Dependabot stance):** Dependabot alerts on, auto-PRs off. The nightly-deps and nightly-security workflows replace per-package Dependabot PRs. This scaffold does NOT include a `.github/dependabot.yml` file.

**ADR-0012 (Grid CI/CD control plane — HoneyDrunk.Actions reusable workflows):** All four CI workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows. No bespoke YAML; the caller files declare `with:` and `secrets:` inputs.

## Dependencies

- `packet:01` — packet 01 of this initiative must be merged so `repos/HoneyDrunk.Cache/` exists in the Architecture repo (the scaffold's README cross-references `overview.md` and `boundaries.md`) and the catalog rows for `honeydrunk-cache` are in place (the scaffold's CHANGELOG and per-package README narrative align with the catalog framing).
- `packet:02` — packet 02 of this initiative must be Done so the GitHub repo `HoneyDrunkStudios/HoneyDrunk.Cache` exists, branch protection is applied, labels are seeded, OIDC is wired, and the local working tree is cloned. `file-packets.sh` cannot file this packet's issue against a repo that does not exist.

## Labels

`feature`, `tier-2`, `cache`, `scaffold`, `adr-0059`

## Agent Handoff

**Objective:** Bring the empty `HoneyDrunk.Cache` repo from zero to first-shippable state per ADR-0059 D3 + D8. Solution with single placeholder project (`HoneyDrunk.Cache.Adapters`), Standards wiring, four CI workflows (no contract-shape canary), README + CHANGELOG + LICENSE. **No backing implementations. No `Abstractions` package. No `ICacheStore<T>` re-declaration.**

**Target:** HoneyDrunk.Cache, branch from `main`.

**Context:**
- Goal: Stand up the repo to first-shippable empty state so the first distributed-cache backing implementation packet has a Node home to land in. The scaffold is intentionally lean per ADR-0059 D3 + D8 — the room is built, no furniture moved in.
- Feature: ADR-0059 standup initiative, Wave 3, Packet 03.
- ADRs: ADR-0059 (this packet implements the code-side half of its "If Accepted" checklist). ADR-0058 (the paired Grid-wide caching strategy ADR that commits the `ICacheStore<T>` contract Cache implements — also Proposed at this packet's filing time; the contract lives in `HoneyDrunk.Kernel.Abstractions`, NOT in Cache).

**Acceptance Criteria:** As listed above.

**Dependencies:** `packet:01` (Architecture-side catalog and context-folder registration must be in place) and `packet:02` (GitHub repo must exist and be cloned locally).

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Cache does not ship an Abstractions package. Do NOT invent `HoneyDrunk.Cache.Abstractions`.
- **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Cache will consume Kernel (one-way) when the first backing implementation lands; nothing in this scaffold references Kernel because the placeholder has no code consuming any Kernel type.
- **Invariant 11:** One repo per Node. — Cache is a separate Node and gets its own repo. Packet 02 created it.
- **Invariant 12:** Every shipped package has a CHANGELOG.md and README.md. — Both at repo level and per-package for the placeholder.
- **Invariant 26:** Every project consumes `HoneyDrunk.Standards` via `PackageReference` with `PrivateAssets="all"`. — Applied to the placeholder `.csproj`.
- **Invariant 27:** All projects in a solution share one version and move together. — Placeholder carries `Version: 0.0.1`.
- **No `ICacheStore<T>` declaration in this repo.** The contract lives in `HoneyDrunk.Kernel.Abstractions` per ADR-0058 D2. Do NOT invent it, do NOT reference it (the placeholder has no code that would call it).
- **No `InMemoryCacheStore<T>` here.** It lives in `HoneyDrunk.Kernel` per ADR-0058 D4. Not in Cache.
- **No backing implementation.** Per ADR-0059 D3 + D8. No Redis adapter, no Cosmos adapter, no Postgres adapter. The first backing's choice is deferred to the first feature packet when a real consumer activates it.
- **No `api-compatibility.yml` workflow.** Per ADR-0059 D3 + D8. Cache owns no contracts to canary at stand-up. The contract Cache implements is canaried by Kernel.
- **No `HoneyDrunk.Pulse` reference.** Pulse is one-way from Cache's perspective; the scaffold has no telemetry-emitting code so no reference is needed.
- **Version is `0.0.1`, not `0.1.0`.** The scaffold ships no production code; `0.0.x` reflects the empty-on-day-one stance. The first backing implementation packet bumps to `0.1.0`.
- **No `.github/dependabot.yml`.** Per ADR-0009 + memory `project_adr_0009_dependabot_stance`. Dependency scanning lives in `nightly-deps.yml`.
- **No tag-push at scaffold time.** The first tag-push waits until the first backing implementation lands. `release.yml` is wired so the trigger is ready, but no tag is pushed by this packet.
- **No tests beyond an optional empty `Tests.Unit` project.** Per ADR-0059 D8. Only add the optional project if `Standards` or solution-build requires it; if added, it carries a single trivial `Assert.True(true)` test. Note the decision in the PR body.
- **README does NOT cite ADR numbers in narrative.** Per memory `feedback_no_adr_in_docs`. Explain the Node's role in plain English; ADR citations are fine in CHANGELOG entries and frontmatter.
- **No `## Unreleased` block in CHANGELOG at commit time.** Per memory `feedback_no_unreleased_commits`. First commit lands under `## [0.0.1] - YYYY-MM-DD`.

**Key Files:**
- `HoneyDrunk.Cache.slnx` — solution file referencing the single placeholder project
- `Directory.Build.props` — solution-level common properties (TargetFramework: net10.0, Version: 0.0.1, etc.)
- `.editorconfig` — pulled in by Standards
- `src/HoneyDrunk.Cache.Adapters/HoneyDrunk.Cache.Adapters.csproj` — placeholder project, Standards reference only, no `.cs` files (or single empty marker `Properties/AssemblyInfo.cs` if compiler requires)
- `src/HoneyDrunk.Cache.Adapters/README.md` — per-package README explaining the placeholder role
- `src/HoneyDrunk.Cache.Adapters/CHANGELOG.md` — per-package CHANGELOG at `0.0.1`
- `README.md` (repo root) — purpose, what Cache owns/does not own, Phase-1 honest limitation (no backings), for-downstream-consumers section (no backings shipped at v0.0.1)
- `CHANGELOG.md` (repo root) — `## [0.0.1] - YYYY-MM-DD` covering the scaffold
- `LICENSE` — verify matches Grid's standard (MIT unless otherwise)
- `.github/workflows/pr-core.yml`, `release.yml`, `nightly-deps.yml`, `nightly-security.yml` — four thin callers; **NO `api-compatibility.yml`**
- Optional: `tests/HoneyDrunk.Cache.Adapters.Tests.Unit/` — only if Standards or solution-build requires; trivial test

**Contracts:**

This packet does not author any contracts. The `ICacheStore<T>` contract that Cache will eventually implement lives in `HoneyDrunk.Kernel.Abstractions` and is the work of ADR-0058's acceptance initiative — a separate scoping run. This scaffold's placeholder project carries no `HoneyDrunk.*` PackageReference other than `HoneyDrunk.Standards`, no `.cs` files (or a single empty marker file), and no consumed contracts. The scaffold proves the repo, solution, CI, and Standards wiring all line up; it does not invent any caching surface.
