---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["chore", "tier-2", "meta", "adr-0039", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0039", "ADR-0034"]
accepts: ["ADR-0039"]
wave: 2
initiative: adr-0039-license-policy
node: honeydrunk-standards
---

# Add the `<PackageLicenseExpression>MIT</PackageLicenseExpression>` default to the Standards packaging fragment (ADR-0039 D1)

## Summary
Add `<PackageLicenseExpression>MIT</PackageLicenseExpression>` as the Grid-wide default license expression in the shared `HoneyDrunk.Standards` packaging-metadata `Directory.Build.props` fragment (the same fragment ADR-0034's rollout introduces), so every package-producing Node inherits MIT without a per-repo declaration, and a revenue Node can override it with one explicit line.

## Context
ADR-0039 D1 states: "`<PackageLicenseExpression>MIT</PackageLicenseExpression>` becomes the `Directory.Build.props` default per ADR-0034 D3." ADR-0034's initiative (`adr-0034-public-package-distribution`) ships a shared packaging-metadata + SourceLink `Directory.Build.props` fragment in `HoneyDrunk.Standards` (its packet 02). ADR-0039 D1 explicitly defers the *license slot* of that fragment to this ADR — ADR-0034's own packet 05 says only "if the Node is on a non-default license — `PackageLicenseExpression` ... default is `MIT` per ADR-0039."

This packet sets that default value. It is small and additive: a single MSBuild property in the shared fragment, conditioned so a per-project or per-repo override wins.

**Coordination with the sibling initiatives that touch Standards build fragments.** Three initiatives in the current ADR batch edit `HoneyDrunk.Standards` build/packaging fragments: **ADR-0034** (public package distribution — introduces the shared packaging-metadata + SourceLink fragment), **ADR-0035**, and **ADR-0039** (this initiative). To avoid a version-bump collision, ownership is fixed: **ADR-0034 packet 02 is the SOLE `HoneyDrunk.Standards` solution-version bumper across this batch.** This ADR-0039 packet 02 adds its `<PackageLicenseExpression>` / license metadata to the Standards fragment and appends to the in-progress `CHANGELOG.md` entry, but **MUST NOT bump the `HoneyDrunk.Standards` solution/package version** — unconditionally, regardless of merge order. If ADR-0034 packet 02 has not yet landed when this packet runs, this packet still does not bump; the version bump rides ADR-0034's packet whenever it lands.

Two situations for the fragment file itself:
- If the ADR-0034 packaging-metadata fragment **already exists** when this packet runs, edit it: add the `<PackageLicenseExpression>` property to the fragment's metadata block, made overridable.
- If the ADR-0034 fragment **does not yet exist** (its initiative has not reached its packet 02), this packet still adds the license-default property in whatever `Directory.Build.props` or `.props` fragment `HoneyDrunk.Standards` ships for packaging metadata. The three initiatives' fragments are the same family of files — if multiple initiatives are in flight, the implementing agent merges into the existing file rather than creating a competing one. Record the chosen file in the PR. Still no version bump.

## Scope
- The `HoneyDrunk.Standards` packaging-metadata `Directory.Build.props` fragment (the file ADR-0034's initiative introduces / the existing packaging `.props` `HoneyDrunk.Standards` ships). Add the `<PackageLicenseExpression>` default property.
- `HoneyDrunk.Standards` repo-level `CHANGELOG.md` — append the license-default addition to the in-progress (current dated, versioned) entry. Do NOT open a new version section and do NOT bump the Standards version (ADR-0034 packet 02 owns the batch version bump).
- The fragment's `README.md` / usage doc, if one exists — note the `PackageLicenseExpression` default and how to override it.

## Proposed Implementation
Add the license-expression property to the fragment's `<PropertyGroup>`, conditioned so it does not clobber a per-project override:

```xml
<!-- ADR-0039 D1: MIT is the Grid default license. A revenue Node (FSL) or
     an SDK project under an FSL engine (MIT) overrides this in its own .csproj. -->
<PropertyGroup>
  <PackageLicenseExpression Condition="'$(PackageLicenseExpression)' == ''">MIT</PackageLicenseExpression>
</PropertyGroup>
```

The `Condition="'$(PackageLicenseExpression)' == ''"` is load-bearing: it makes the value a *default*, not a mandate. A revenue Node's repo-root `Directory.Build.props` sets `<PackageLicenseExpression>FSL-1.1-MIT</PackageLicenseExpression>` (packet 03 does this for Notify and Communications), and a revenue Node's SDK `.csproj` sets `<PackageLicenseExpression>MIT</PackageLicenseExpression>` to override the FSL repo default back to MIT (ADR-0039 D3). Both override paths require the property here to be conditional.

Do **not** set `<PackageLicenseFile>` in the shared fragment — `PackageLicenseExpression` (an SPDX identifier) and `PackageLicenseFile` (a packed file) are mutually exclusive in a nupkg. FSL is custom text and uses `LICENSE.md` as a packed file (`PackageLicenseFile`); ADR-0039 D2 notes "the SPDX identifier alone is insufficient because FSL is custom-text per project." Packet 03 handles the FSL `PackageLicenseFile` wiring per-repo. The shared fragment carries only the `PackageLicenseExpression` default for the MIT majority.

Match the existing fragment's MSBuild style and the placement convention ADR-0034's packet 02 established (if that fragment exists).

## Affected Files
- the `HoneyDrunk.Standards` packaging-metadata `Directory.Build.props` fragment
- `HoneyDrunk.Standards` `CHANGELOG.md`
- the fragment's usage doc / `README.md`, if one exists

## NuGet Dependencies
None. This packet adds one MSBuild property to an existing `.props` fragment. No `PackageReference` is added or removed; no new .NET project is created.

## Boundary Check
- [x] The shared packaging fragment lives in `HoneyDrunk.Standards`. Build-tooling and shared MSBuild conventions are Standards' domain.
- [x] No code change in any other repo — consuming repos pick up the default transitively when they import the fragment (ADR-0034's fan-out, and packet 05 here).
- [x] No new cross-Node runtime dependency — `PackageLicenseExpression` is package metadata, not a reference.

## Acceptance Criteria
- [ ] The `HoneyDrunk.Standards` packaging-metadata fragment sets `<PackageLicenseExpression>MIT</PackageLicenseExpression>`
- [ ] The property is conditioned `Condition="'$(PackageLicenseExpression)' == ''"` so a per-repo or per-project value overrides it
- [ ] The shared fragment does NOT set `<PackageLicenseFile>` (mutually exclusive with `PackageLicenseExpression`; FSL's `PackageLicenseFile` is wired per-repo in packet 03)
- [ ] A test/sample packable project that sets no license still packs as MIT; a sample project that sets `FSL-1.1-MIT` packs as FSL — verify with `dotnet pack` and inspecting the `.nuspec`, or by the fragment's existing test harness if one exists
- [ ] `HoneyDrunk.Standards` repo-level `CHANGELOG.md` has the license-default addition **appended to the in-progress (current dated, versioned) entry** — this packet does NOT open a new version section
- [ ] This packet does NOT bump the `HoneyDrunk.Standards` solution/package version — ADR-0034 packet 02 is the sole version bumper across the ADR-0034 / ADR-0035 / ADR-0039 batch
- [ ] If the fragment has a usage doc, it documents the `PackageLicenseExpression` default and the override path
- [ ] The PR records which file the property landed in (the ADR-0034 fragment if it exists, else the existing packaging `.props`)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0039 D1 — Default license: MIT.** "`<PackageLicenseExpression>MIT</PackageLicenseExpression>` becomes the `Directory.Build.props` default per ADR-0034 D3." Every Grid Node defaults to MIT unless D2 (revenue → FSL) or D3 (SDK → MIT override) applies.

**ADR-0039 D2 — Revenue Nodes: FSL-1.1-MIT.** FSL Nodes use `<PackageLicenseExpression>FSL-1.1-MIT</PackageLicenseExpression>` and include the FSL text as a packed `LICENSE.md` ("the SPDX identifier alone is insufficient because FSL is custom-text per project"). Packet 03 wires this for Notify and Communications.

**ADR-0039 D3 — SDKs: MIT regardless of engine license.** An SDK project under an FSL engine carries a per-project `<PackageLicenseExpression>MIT</PackageLicenseExpression>` that overrides the repo's FSL default. This override is only possible if the shared default is conditional.

**ADR-0034 D3 — Package identity.** The repo-root `Directory.Build.props` (importing the shared `HoneyDrunk.Standards` fragment) is the metadata enforcement point; per-project overrides are permitted for a small set of properties. The license expression is one of the values the fragment supplies as a default.

## Constraints
- **The default must be conditional.** `Condition="'$(PackageLicenseExpression)' == ''"` — without it, revenue-Node FSL overrides (packet 03) and SDK MIT-over-FSL overrides (ADR-0039 D3) silently fail.
- **`PackageLicenseExpression` and `PackageLicenseFile` are mutually exclusive** in a nupkg. The shared fragment sets only the expression; FSL repos use the file form, wired per-repo in packet 03.
- **One fragment, not two.** If the ADR-0034 packaging-metadata fragment already exists, merge into it — do not create a competing license-only fragment. The ADR-0034, ADR-0035, and ADR-0039 fragments are the same family of physical files.
- **No `HoneyDrunk.Standards` version bump — unconditionally.** ADR-0034 packet 02 is the sole solution-version bumper across the ADR-0034 / ADR-0035 / ADR-0039 batch that touches Standards build fragments. This packet adds the MSBuild property and appends to the in-progress `CHANGELOG.md` entry only. Append to the current dated/versioned entry; do not open a new version section. Agents never push tags (invariant 27).

## Labels
`chore`, `tier-2`, `meta`, `adr-0039`, `wave-2`

## Agent Handoff

**Objective:** Add the conditional `<PackageLicenseExpression>MIT</PackageLicenseExpression>` default to the shared `HoneyDrunk.Standards` packaging-metadata fragment.

**Target:** `HoneyDrunk.Standards`, branch from `main`.

**Context:**
- Goal: Every package-producing Node inherits MIT by default; revenue Nodes and SDKs override with one explicit line.
- Feature: ADR-0039 Grid Open Source License Policy rollout, Wave 2.
- ADRs: ADR-0039 (D1, D2, D3), ADR-0034 (D3 — the shared fragment this property lands in).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0039 acceptance (soft — references ADR-0039 D1 as a live rule).

**Constraints:**
- The default MUST be conditional (`Condition="'$(PackageLicenseExpression)' == ''"`).
- Do not set `<PackageLicenseFile>` in the shared fragment — mutually exclusive with the expression.
- Merge into the ADR-0034 packaging fragment if it exists; do not create a second fragment. ADR-0034, ADR-0035, and ADR-0039 all touch the Standards build fragments.
- **No `HoneyDrunk.Standards` version bump — unconditionally.** ADR-0034 packet 02 is the sole version bumper across the batch. Append to the in-progress CHANGELOG entry; do not open a new version section. No tag push.

**Key Files:**
- the `HoneyDrunk.Standards` packaging-metadata `Directory.Build.props` fragment
- `HoneyDrunk.Standards` `CHANGELOG.md`
- the fragment's usage doc, if one exists

**Contracts:** No runtime contract. Establishes the `PackageLicenseExpression` MSBuild default consumed by every Node that imports the fragment (the ADR-0034 fan-out, and packet 05 here for the per-repo license-expression overrides).
