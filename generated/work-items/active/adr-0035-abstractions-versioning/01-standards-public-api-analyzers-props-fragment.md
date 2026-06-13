---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["feature", "tier-2", "ops", "adr-0035", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0035"]
accepts: ["ADR-0035"]
wave: 1
initiative: adr-0035-abstractions-versioning
node: honeydrunk-standards
---

# Author the public-API-analyzer + record-evolution Directory.Build.props fragment (ADR-0035 D3/D4/D9)

## Summary
Create a shared, importable `Directory.Build.props` fragment in `HoneyDrunk.Standards` that enables `Microsoft.CodeAnalysis.PublicApiAnalyzers` (`RS0016`/`RS0017` family) on every packable project, wires the `PublicAPI.Shipped.txt` / `PublicAPI.Unshipped.txt` tracked-file convention, and turns on the analyzer rules that enforce ADR-0035 D3 (no default-interface-member additions on shipped interfaces) and D4 (records use `init` members, enums include a default switch arm) — so every public Node consumes one canonical surface-stability tooling definition instead of drifting per-repo.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Standards`

## Motivation
ADR-0035 D9 commits three CI gates; the first is: "`Microsoft.CodeAnalysis.PublicApiAnalyzers` is enabled on every public package. `PublicAPI.Shipped.txt` and `PublicAPI.Unshipped.txt` are tracked in-repo; PRs that touch the public surface must update `Unshipped.txt`, and CI fails if the file is stale." That analyzer must be turned on identically across every public Node — exactly the kind of shared build-tooling default `HoneyDrunk.Standards` already owns (the Grid-wide StyleCop + EditorConfig analyzer set per invariant 26, the ADR-0047 test-stack fragment, the ADR-0034 packaging-metadata fragment).

Centralizing it means each public Node's adoption (packet 04, the fan-out) is a thin "import the fragment, commit the baseline `PublicAPI.Shipped.txt`" change rather than per-repo analyzer hand-wiring. This packet authors the shared definition only; per-Node adoption — including the one-time `PublicAPI.Shipped.txt` baseline commit at each Node's current published surface — is packet 04.

This packet sits in the same `HoneyDrunk.Standards` family as the ADR-0034 packaging-metadata fragment (`adr-0034-public-package-distribution/02`). The two are independent build-asset fragments; this one carries surface-stability tooling, that one carries packaging metadata. They do not conflict and do not share a fragment file. **ADR-0034 packet 02 is the sole `HoneyDrunk.Standards` solution-version bumper across this 12-ADR batch — this packet (ADR-0035 packet 01) MUST NOT bump the `HoneyDrunk.Standards` solution version.** This packet adds its fragment content and appends to the existing in-progress `CHANGELOG.md` entry only. See Constraints.

## Proposed Implementation

### Public API analyzer block (ADR-0035 D9 gate 1)
The fragment, scoped to packable projects (`$(IsPackable)`):
- References `Microsoft.CodeAnalysis.PublicApiAnalyzers` with `PrivateAssets="all"` (a build-time analyzer, never a runtime dependency).
- Wires `<AdditionalFiles Include="PublicAPI.Shipped.txt" />` and `<AdditionalFiles Include="PublicAPI.Unshipped.txt" />` so the analyzer reads the tracked surface files. The fragment provides the *wiring*; the two `.txt` files themselves are per-project content the consuming Node supplies (packet 04 commits each Node's baseline).
- Sets the relevant analyzer rules to `error` severity (via `.editorconfig` shipped alongside the fragment, or `<WarningsAsErrors>` for the `RS00xx` IDs) so a stale `Unshipped.txt` or an undeclared public-surface change fails the build, not just warns — D9: "CI fails if the file is stale."
- Provides a documented way for a Node to opt a project out only when it is genuinely non-packable (test projects, samples) — keyed on `$(IsPackable)`, never an arbitrary per-project flag.

### Record / enum evolution analyzer config (ADR-0035 D3/D4)
ADR-0035 D3 forbids adding members to shipped public interfaces (new behavior lands on a new interface) and forbids default-interface-member additions. D4 requires public records use `init` named members not positional syntax, requires new record members be non-required, and requires exhaustive `switch` over a non-`<closed/>` enum to carry a default arm. The `PublicApiAnalyzers` set covers the surface-tracking half; the D3/D4 *shape* rules are partly analyzer-enforceable:
- Enable the Roslyn switch-exhaustiveness rule (`IDE0010` / `CS8509` family) at `warning` or `error` for packable projects so a `switch` over an open enum without a default arm is flagged — D4: "an enum that is not extensible is annotated with an XML doc tag (`<closed/>`) and a Roslyn analyzer warning on switch exhaustiveness flips on."
- ADR-0035 D4's "all public records use `init` members, not positional syntax" and D3's "no default-interface-member additions" are **not fully expressible as an out-of-the-box analyzer rule**. The fragment ships what is enforceable now (the `PublicApiAnalyzers` diff catches a positional-parameter add as a surface change; switch-exhaustiveness catches the enum case). For the parts no shipped analyzer covers, ship an `.editorconfig` documentation block and a `README.md` section stating the D3/D4 rules so they are reviewable; a future custom analyzer is recorded as out-of-scope follow-up. Record in the PR exactly which D3/D4 rules are analyzer-enforced vs review-enforced.

### Mechanism
Preferred: ship the fragment + the accompanying `.editorconfig` rule block as static MSBuild `build/` content inside the **existing** `HoneyDrunk.Standards` build-assets package, so no new `.csproj` is created — the same mechanism the ADR-0047 test-stack fragment and the ADR-0034 packaging-metadata fragment use. Only if the current packaging cannot carry an additional build asset should a new build-assets `.csproj` be added — and that project must then reference `HoneyDrunk.Standards` analyzers with `PrivateAssets: all` per invariant 26. Record the chosen mechanism in the PR.

### Scoping
The fragment must apply only to packable projects — never enable `PublicApiAnalyzers` or the `PublicAPI.*.txt` `AdditionalFiles` wiring on test projects (`*.Tests.*`) or non-packable internal projects. Key all conditions on `$(IsPackable)` (default-true for library projects, false on test projects per the ADR-0047 test-stack fragment).

## Affected Packages
- `HoneyDrunk.Standards` — gains the public-API-analyzer + record/enum-evolution props fragment and the accompanying `.editorconfig` rule block.

## NuGet Dependencies
This packet authors a props fragment that **declares** the following `PackageReference` for consuming packable projects (it does not add a runtime reference to `HoneyDrunk.Standards`'s own projects):

- `Microsoft.CodeAnalysis.PublicApiAnalyzers` — current stable; `PrivateAssets="all"` (a build-time Roslyn analyzer, not a runtime dependency).

If a new build-assets `.csproj` is created in `HoneyDrunk.Standards` to host the fragment, that project additionally references:
- `HoneyDrunk.Standards` analyzers — `PrivateAssets: all` (invariant 26: every new .NET project explicitly references the `HoneyDrunk.Standards` StyleCop + EditorConfig analyzers with `PrivateAssets: all`).

`HoneyDrunk.Standards` is modeled in `catalogs/nodes.json` (id `honeydrunk-standards`) as the Grid's shared analyzer / EditorConfig / build-tooling Meta Node — a library-only, no-vault repo whose packages are consumed at compile time. The public-API-analyzer fragment is the same class of artifact as the existing analyzer set and the ADR-0047 / ADR-0034 fragments: a packaged MSBuild build asset, not a runtime project.

## Boundary Check
- [x] Shared build-tooling defaults belong in `HoneyDrunk.Standards` — it already owns the Grid-wide analyzer + EditorConfig set (invariant 26), the ADR-0047 test-stack fragment, and the ADR-0034 packaging-metadata fragment.
- [x] No Node behavior changes; this packet only publishes a definition. Per-Node adoption — including the `PublicAPI.Shipped.txt` baseline commit — is packet 04.
- [x] Does not duplicate any other Node's responsibility — the API-diff *workflow* (D9 gate 2) is HoneyDrunk.Actions' (packet 03); this is build-time analyzer config only.

## Acceptance Criteria
- [ ] `HoneyDrunk.Standards` ships a `Directory.Build.props` fragment that references `Microsoft.CodeAnalysis.PublicApiAnalyzers` with `PrivateAssets="all"` on packable projects
- [ ] The fragment wires `PublicAPI.Shipped.txt` and `PublicAPI.Unshipped.txt` as `AdditionalFiles` so the analyzer reads them
- [ ] The `RS00xx` public-API analyzer rules are set to `error` severity so a stale `Unshipped.txt` / an undeclared public-surface change fails the build (ADR-0035 D9: "CI fails if the file is stale")
- [ ] The fragment enables the switch-exhaustiveness rule at warning-or-error on packable projects (ADR-0035 D4 enum rule)
- [ ] The fragment applies only to packable projects — no `PublicApiAnalyzers` / `PublicAPI.*.txt` wiring leaks into `*.Tests.*` projects (keyed on `$(IsPackable)`)
- [ ] An `.editorconfig` / `README.md` block documents the D3/D4 rules that are review-enforced rather than analyzer-enforced (no positional records on public surface; no default-interface-member additions); the PR records which D3/D4 rules are analyzer-enforced vs review-enforced
- [ ] Repo `README.md` documents how a Node package consumes the fragment and the obligation to commit a baseline `PublicAPI.Shipped.txt` per packable project
- [ ] Repo-level `CHANGELOG.md` updated by **appending to the existing in-progress entry** — this packet does NOT create a new version entry and does NOT bump the `HoneyDrunk.Standards` solution version (ADR-0034 packet 02 is the sole Standards version bumper across this batch); per-package `CHANGELOG.md` updated for the package that gained the fragment
- [ ] Build green; existing `HoneyDrunk.Standards` consumers unaffected (analyzer / EditorConfig / test-stack / packaging-metadata fragment behavior unchanged)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0035 D9 — Enforcement.** Three CI gates land in HoneyDrunk.Actions. Gate 1 (this packet's Standards side): `Microsoft.CodeAnalysis.PublicApiAnalyzers` is enabled on every public package; `PublicAPI.Shipped.txt` and `PublicAPI.Unshipped.txt` are tracked in-repo; PRs that touch the public surface must update `Unshipped.txt`, and CI fails if the file is stale. (Gate 2, the API-diff job, and gate 3, the `[Obsolete]` audit, are HoneyDrunk.Actions' — packet 03.)

**ADR-0035 D3 — Interface evolution rule.** No default-interface-member additions (the TFM matrix includes targets where DIM is unsupported — `netstandard2.0`, AOT). New behavior on an existing surface lands on a new, intention-revealing interface; consumers opt in by taking the new dependency. The original interface gets `[Obsolete]` with a `DiagnosticId` only after the successor has shipped at the same major and the deprecation window has elapsed.

**ADR-0035 D4 — Record and DTO evolution.** All public records use property initializers (`init`) with named members, not positional syntax — so adding a member is non-breaking at the call site. New members on a record are non-required. Enums are extensible by default; consumers `switch` exhaustively at their own risk and must include a default arm. An enum that is *not* extensible is annotated `<closed/>` and the switch-exhaustiveness analyzer warning flips on.

## Constraints
> **Invariant 26 — Work items for .NET code work must include an explicit `## NuGet Dependencies` section.** "`HoneyDrunk.Standards` must be explicitly listed on every new .NET project (StyleCop + EditorConfig analyzers, `PrivateAssets: all`)." If this packet creates a new `.csproj` in `HoneyDrunk.Standards` to host the fragment as build assets, that project must reference `HoneyDrunk.Standards` analyzers with `PrivateAssets: all`.

> **Invariant 16 — No test code in runtime packages.** The same spirit forbids leaking the `PublicApiAnalyzers` reference and the `PublicAPI.*.txt` `AdditionalFiles` wiring into test projects. Scope the fragment to `$(IsPackable)`.

> **Invariant 12 — Semantic versioning with CHANGELOG and README.** Every package directory must contain a `README.md`; the repo-level and per-package CHANGELOGs are updated per invariant 27. This packet appends to the existing in-progress `CHANGELOG.md` entry — it does not open a new version entry.

- **`Microsoft.CodeAnalysis.PublicApiAnalyzers` is `PrivateAssets="all"`** — a build-time analyzer. It must never appear as a runtime dependency on an `.Abstractions` package (invariant 1: Abstractions packages have zero runtime HoneyDrunk dependencies — and analyzers must not become transitive runtime deps).
- **The fragment is analyzer/build-tooling only** — it does not run the API-diff check. The API-diff *workflow* is HoneyDrunk.Actions' job (packet 03). Do not add diff logic here.
- **Scope to `$(IsPackable)`** — no analyzer or `PublicAPI.*.txt` wiring on test projects.
- **This packet never bumps the `HoneyDrunk.Standards` solution version.** ADR-0034 packet 02 (`adr-0034-public-package-distribution/02`, the packaging-metadata fragment) is the **sole `HoneyDrunk.Standards` version bumper** across this 12-ADR batch. Regardless of merge order, this packet only adds its fragment content and appends a line to the existing in-progress `CHANGELOG.md` entry. If this packet lands before ADR-0034 packet 02, the in-progress entry already exists from prior work or is opened by ADR-0034 packet 02 — this packet does not open it and does not bump the version itself.

## Labels
`feature`, `tier-2`, `ops`, `adr-0035`, `wave-1`

## Agent Handoff

**Objective:** Author a shared `Directory.Build.props` fragment in `HoneyDrunk.Standards` that enables `Microsoft.CodeAnalysis.PublicApiAnalyzers` + the `PublicAPI.{Shipped,Unshipped}.txt` convention on every packable project and turns on the switch-exhaustiveness rule, for Grid-wide consumption.

**Target:** HoneyDrunk.Standards, branch from `main`.

**Context:**
- Goal: One canonical public-API-surface-stability tooling definition; eliminate per-Node analyzer drift.
- Feature: ADR-0035 Abstractions Versioning and Deprecation Policy initiative, Wave 1.
- ADRs: ADR-0035 (D9 gate 1, D3, D4).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0035 acceptance (soft — references ADR-0035 D3/D4/D9 as live rules).

**Constraints:**
- See "Constraints" — inlined for agent consumption.
- `Microsoft.CodeAnalysis.PublicApiAnalyzers` is `PrivateAssets="all"` — build-time analyzer, never a runtime dependency.
- Analyzer/build-tooling only — no API-diff logic (that is packet 03).
- Scope to `$(IsPackable)` — no analyzer wiring on test projects.
- This packet never bumps the `HoneyDrunk.Standards` solution version — ADR-0034 packet 02 is the sole Standards version bumper across the batch. Append to the existing in-progress CHANGELOG entry only.

**Key Files:**
- New props fragment + `.editorconfig` block under `HoneyDrunk.Standards` (path per repo convention).
- `README.md` — consumption documentation.
- `CHANGELOG.md` (repo-level + per-package).

**Contracts:** None — this is build tooling, not a runtime contract. No `catalogs/contracts.json` change.
