---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["feature", "tier-2", "ops", "adr-0034", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0034", "ADR-0039"]
accepts: ["ADR-0034"]
wave: 1
initiative: adr-0034-public-package-distribution
node: honeydrunk-standards
---

# Author the shared package-metadata + SourceLink Directory.Build.props fragment (ADR-0034 D3/D4)

## Summary
Create a shared, importable `Directory.Build.props` fragment in `HoneyDrunk.Standards` that establishes the ADR-0034 D3 required package-metadata block and the ADR-0034 D4 SourceLink + deterministic-build block as one canonical definition, plus a CI-enforceable check that fails the build when a packable project is missing a required metadata field — so every public Node consumes one fragment instead of drifting per-repo.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Standards`

## Motivation
ADR-0034 D3 lists thirteen metadata fields "required in each project file or `Directory.Build.props` and CI-enforced (build fails if missing)." D4 lists six SourceLink / determinism properties that are "non-negotiable for any public package." ADR-0034's Context section records the current state as fragmented: package metadata (`Authors`, `Company`, `RepositoryUrl`, `PackageLicenseExpression`, icons) is inconsistent across Nodes and signing is unset.

`HoneyDrunk.Standards` is the existing Grid-wide home for shared analyzers and EditorConfig consumed by every .NET repo (invariant 26 mandates `HoneyDrunk.Standards` on every new .NET project). It is the correct owner for a shared packaging-metadata props fragment — exactly as it owns the unit-test-stack fragment authored under the ADR-0047 initiative. Centralizing it means each public Node's adoption (packet 05, the fan-out) is a thin "import the fragment, set the three per-project overrides" change rather than thirteen-field hand-authoring per repo.

This packet does **not** adopt the fragment into any Node — it only authors the shared definition and the enforcement check. Per-Node adoption is packet 05.

## Proposed Implementation

### Metadata block (ADR-0034 D3)
The fragment sets these thirteen fields. The first ten are fixed Grid-wide values; the last three are per-project overrides D3 explicitly permits (`PackageId`, `Description`, `PackageTags`):

- `<Authors>HoneyDrunk Studios</Authors>`
- `<Company>HoneyDrunk Studios</Company>`
- `<Product>HoneyDrunk Grid</Product>`
- `<RepositoryUrl>` — the canonical GitHub repo URL. Set this from a Node-supplied property (e.g. `$(HoneyDrunkRepositoryUrl)`) or derive it; the fragment provides the slot, the consuming repo supplies the value.
- `<RepositoryType>git</RepositoryType>`
- `<PackageProjectUrl>` — Studios product page or repo readme; Node-supplied slot.
- `<PackageLicenseExpression>` — an SPDX expression. ADR-0034 D3 says this is "set by ADR-0039 (license policy); never `<PackageLicenseFile>` for public packages, to avoid stale embedded text." ADR-0039 (Proposed) sets MIT as the Grid default. The fragment defaults `<PackageLicenseExpression>` to `MIT` and leaves it overridable per repo (a revenue Node on FSL overrides it). Never emit `<PackageLicenseFile>` for a packable project.
- `<PackageReadmeFile>` — points to a per-package `README.md` packed into the nupkg. The fragment wires the `<None Include="README.md" Pack="true" PackagePath="\" />` item; the consuming package supplies the README content.
- `<PackageIcon>` — the Studios mark, a single shared asset packed per-project. Ship the icon asset inside `HoneyDrunk.Standards` and have the fragment reference + pack it so no Node copies the binary.
- `<PackageTags>` — per-project override; D3 minimum content is `honeydrunk`, the sector tag, and the slot kind (`abstractions` / `backing` / `sdk`).
- `<Description>` — per-project override, one paragraph.
- `<RepositoryCommit>` — set by CI from `$GITHUB_SHA`. The fragment reads an MSBuild property fed from the `GITHUB_SHA` environment variable when `$(CI)` is true.

ADR-0034 D3: "`Directory.Build.props` at the repo root is the enforcement point; per-project overrides are limited to `<PackageId>`, `<Description>`, and `<PackageTags>`."

### SourceLink + determinism block (ADR-0034 D4)
The fragment sets, for all packable projects:
- `<PublishRepositoryUrl>true</PublishRepositoryUrl>`
- `<EmbedUntrackedSources>true</EmbedUntrackedSources>`
- `<IncludeSymbols>true</IncludeSymbols>`
- `<SymbolPackageFormat>snupkg</SymbolPackageFormat>`
- `<ContinuousIntegrationBuild>true</ContinuousIntegrationBuild>` — conditioned on `$(CI) == 'true'`.
- `<Deterministic>true</Deterministic>`
- A `<PackageReference Include="Microsoft.SourceLink.GitHub" />` with `PrivateAssets="all"` — D4: "`Microsoft.SourceLink.GitHub` is referenced from `Directory.Build.props`."

### CI metadata-enforcement check (ADR-0034 D3 "build fails if missing")
Add an MSBuild target (in the fragment, or as a `.targets` companion shipped alongside it) that runs before pack/publish and fails the build with a clear diagnostic if any of the thirteen required fields is empty on a packable project (`IsPackable != false`). The target keys off `IsPackable` so it never fires on test projects or non-packable internal projects.

### Scoping
The fragment must apply only to packable projects — never inject `PackageReadmeFile`, `PackageIcon`, or the SourceLink reference into test projects (`*.Tests.*`) or non-packable runtime helpers. Key the conditions on `$(IsPackable)` (default-true for library projects, false on test projects per the ADR-0047 test-stack fragment).

### Mechanism
Preferred: ship the fragment + the Studios icon asset + the enforcement `.targets` as static MSBuild `build/` content inside the **existing** `HoneyDrunk.Standards` build-assets package, so no new `.csproj` is created. Only if the current packaging cannot carry an additional build asset should a new build-assets `.csproj` be added — and that project must then reference `HoneyDrunk.Standards` analyzers with `PrivateAssets: all` per invariant 26. Record the chosen mechanism in the PR.

## Affected Packages
- `HoneyDrunk.Standards` — gains the packaging-metadata props fragment, the SourceLink block, the enforcement target, and the packed Studios icon asset.

## NuGet Dependencies
This packet authors a props fragment that **declares** the following `PackageReference` for consuming packable projects (it does not add a runtime reference to `HoneyDrunk.Standards`'s own projects):

- `Microsoft.SourceLink.GitHub` — current stable; `PrivateAssets="all"` (it is a build-time-only source-indexer, not a runtime dependency).

If a new build-assets `.csproj` is created in `HoneyDrunk.Standards` to host the fragment, that project additionally references:
- `HoneyDrunk.Standards` analyzers — `PrivateAssets: all` (invariant 26: every new .NET project explicitly references the `HoneyDrunk.Standards` StyleCop + EditorConfig analyzers with `PrivateAssets: all`).

`HoneyDrunk.Standards` is modeled in `catalogs/nodes.json` (id `honeydrunk-standards`) as the Grid's shared analyzer / EditorConfig / build-tooling Meta Node — a library-only, no-vault repo whose packages are consumed at compile time. The packaging-metadata fragment is the same class of artifact as the existing analyzer set and the ADR-0047 test-stack fragment: a packaged MSBuild build asset, not a runtime project.

## Boundary Check
- [x] Shared build-tooling defaults belong in `HoneyDrunk.Standards` — it already owns the Grid-wide analyzer + EditorConfig set (invariant 26) and the ADR-0047 test-stack fragment.
- [x] No Node behavior changes; this packet only publishes a definition. Per-Node adoption is packet 05.
- [x] Does not duplicate any other Node's responsibility — the publish *workflow* (D6) is HoneyDrunk.Actions' (packet 03); this is build-time metadata only.

## Acceptance Criteria
- [ ] `HoneyDrunk.Standards` ships a `Directory.Build.props` fragment setting the thirteen ADR-0034 D3 metadata fields, with `PackageId` / `Description` / `PackageTags` as per-project overrides and the other ten as Grid-wide / Node-supplied-slot values
- [ ] `<PackageLicenseExpression>` defaults to `MIT` (ADR-0039) and is overridable; `<PackageLicenseFile>` is never emitted for a packable project
- [ ] The fragment sets the six ADR-0034 D4 properties (`PublishRepositoryUrl`, `EmbedUntrackedSources`, `IncludeSymbols`, `SymbolPackageFormat=snupkg`, `ContinuousIntegrationBuild` gated on `$(CI)`, `Deterministic`) and references `Microsoft.SourceLink.GitHub` with `PrivateAssets="all"`
- [ ] The Studios icon asset is packed inside `HoneyDrunk.Standards` and referenced by the fragment via `<PackageIcon>` — no Node copies the binary
- [ ] An MSBuild enforcement target fails the build with a clear diagnostic when any required D3 field is empty on a packable project; it never fires on `IsPackable=false` projects
- [ ] The fragment applies only to packable projects — no `PackageReadmeFile` / `PackageIcon` / SourceLink leakage into `*.Tests.*` projects
- [ ] Repo `README.md` documents how a Node package consumes the fragment and which three fields the Node overrides
- [ ] Repo-level `CHANGELOG.md` updated — new version entry (this is the bumping packet for `HoneyDrunk.Standards` in this initiative); per-package `CHANGELOG.md` updated for the package that gained the fragment
- [ ] Build green; existing `HoneyDrunk.Standards` consumers unaffected (analyzer / EditorConfig / test-stack-fragment behavior unchanged)

## Human Prerequisites
- [ ] Provide the Studios mark icon asset (PNG, the size nuget.org expects — 128x128 recommended) if one is not already in the repo. The agent packs whatever asset the human supplies; it does not create artwork.

## Referenced ADR Decisions
**ADR-0034 D3 — Package identity.** Thirteen metadata fields required in each project file or `Directory.Build.props`, CI-enforced (build fails if missing): `Authors`, `Company`, `Product`, `RepositoryUrl`, `RepositoryType`, `PackageProjectUrl`, `PackageLicenseExpression` (SPDX, never `PackageLicenseFile`), `PackageReadmeFile`, `PackageIcon`, `PackageTags`, `Description`, `RepositoryCommit`. `Directory.Build.props` at the repo root is the enforcement point; per-project overrides limited to `PackageId`, `Description`, `PackageTags`.

**ADR-0034 D4 — SourceLink and deterministic builds.** All public packages enable `PublishRepositoryUrl`, `EmbedUntrackedSources`, `IncludeSymbols`, `SymbolPackageFormat=snupkg`, `ContinuousIntegrationBuild` (when `$CI=true`), `Deterministic`. `Microsoft.SourceLink.GitHub` referenced from `Directory.Build.props`. `.snupkg` symbol packages publish alongside the main package. "Non-negotiable for any public package."

**ADR-0039 — license policy.** MIT is the Grid default; the SPDX expression for `PackageLicenseExpression` comes from ADR-0039. Revenue Nodes use FSL and override.

## Constraints
> **Invariant 26 — Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section.** "`HoneyDrunk.Standards` must be explicitly listed on every new .NET project (StyleCop + EditorConfig analyzers, `PrivateAssets: all`)." If this packet creates a new `.csproj` in `HoneyDrunk.Standards` to host the fragment as build assets, that project must reference `HoneyDrunk.Standards` analyzers with `PrivateAssets: all`.

> **Invariant 16 — No test code in runtime packages.** The same spirit forbids leaking packaging metadata (`PackageReadmeFile`, `PackageIcon`, SourceLink) into test projects. Scope the fragment to `$(IsPackable)`.

> **Invariant 12 — Semantic versioning with CHANGELOG and README.** Every package directory must contain a `README.md`. The fragment's `PackageReadmeFile` wiring depends on each consuming package having a README — packet 05's per-Node adoption ensures it.

- **Never `<PackageLicenseFile>` for public packages** — ADR-0034 D3 explicitly forbids it to avoid stale embedded license text. Always the SPDX `<PackageLicenseExpression>`.
- **The fragment is build-metadata only** — it does not push packages. The publish workflow is HoneyDrunk.Actions' job (packet 03). Do not add `dotnet nuget push` logic here.
- **One shared icon asset** — packed from `HoneyDrunk.Standards`, never copied per-Node.

## Labels
`feature`, `tier-2`, `ops`, `adr-0034`, `wave-1`

## Agent Handoff

**Objective:** Author a shared `Directory.Build.props` fragment in `HoneyDrunk.Standards` for the ADR-0034 D3 package-metadata block + D4 SourceLink/determinism block, plus a build-failing enforcement target for the required D3 fields, for Grid-wide consumption by packable Node projects.

**Target:** HoneyDrunk.Standards, branch from `main`.

**Context:**
- Goal: One canonical packaging-metadata + SourceLink definition; eliminate per-Node metadata drift.
- Feature: ADR-0034 Public Package Distribution initiative, Wave 1.
- ADRs: ADR-0034 (D3, D4), ADR-0039 (license SPDX expression).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0034 acceptance (soft — references ADR-0034 D3/D4 as live rules).

**Constraints:**
- See "Constraints" — inlined for agent consumption.
- Never `<PackageLicenseFile>` for public packages; always SPDX `<PackageLicenseExpression>`.
- Build-metadata only — no `dotnet nuget push` logic.
- One shared icon asset, packed from `HoneyDrunk.Standards`.
- Scope to `$(IsPackable)` — no metadata leakage into test projects.

**Key Files:**
- New props fragment + `.targets` under `HoneyDrunk.Standards` (path per repo convention).
- The packed Studios icon asset.
- `README.md` — consumption documentation.
- `CHANGELOG.md` (repo-level + per-package).

**Contracts:** None — this is build tooling, not a runtime contract. No `catalogs/contracts.json` change.
