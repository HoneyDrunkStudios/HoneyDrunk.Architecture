---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["chore", "tier-2", "ops", "docs", "adr-0074", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0074", "ADR-0047"]
accepts: ["ADR-0074"]
wave: 2
initiative: adr-0074-testing-stack
node: honeydrunk-standards
---

# Cite ADR-0074 alongside ADR-0047 in HoneyDrunk.Standards README and the test-stack props fragment header

## Summary
Update `HoneyDrunk.Standards`'s `README.md` test-stack section and the shared test-stack `Directory.Build.props` fragment's header comment to cite **ADR-0074** alongside ADR-0047. Today both surfaces cite only ADR-0047 D2 — once ADR-0074 lands, the standalone-citable library-pick ADR is the better navigation target for any consumer (operator, scope agent, future Node-standup ADR) trying to reach the library-pick rationale (Moq/SponsorLink, FluentAssertions/v8 license, xUnit-v2-pinning, AwesomeAssertions/Shouldly/native-xUnit alternatives). No version bump on consumed packages, no semantic change to the props fragment — citation update only.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Standards`

## Motivation
ADR-0074's Context section names every new Node-standup packet as a consumer of the testing-library stack via `Directory.Build.props`:

> Every new Node scaffold packet (HoneyDrunk.Identity per ADR-0060, HoneyDrunk.Files per ADR-0061, HoneyDrunk.Cache per ADR-0059, HoneyDrunk.Web.UI per ADR-0071) cites the testing-library stack in its `Directory.Build.props`. A canonical ADR is the right citation target.

The shared test-stack props fragment landed via ADR-0047 packet 01 in `HoneyDrunk.Standards`. Its README and any header comment on the fragment file itself currently cite ADR-0047 D2 (e.g. `README.md` line 113: *"Moq and FluentAssertions are intentionally absent per ADR-0047 D2."*). ADR-0074 is the standalone home of that reasoning — the citation surface should point there directly so a consumer reading the README lands on the standalone ADR with the SponsorLink + FluentAssertions-v8 rationale in plain view, instead of having to dig into ADR-0047 D2's prose.

This is a docs-only edit in `HoneyDrunk.Standards`. It does not change the packages declared by the fragment, does not change any pinned version, and does not change the fragment's scoping rule (`*.Tests.*` only). It does not bump the package's API surface — it is a metadata/citation refresh.

## Proposed Implementation
1. **`HoneyDrunk.Standards/README.md` — Test Stack section.** Three concrete citation surfaces exist today (line numbers per repo HEAD at packet authorship):
   - **Line 19** — top-of-README feature bullet: *"✅ **ADR-0047 Test Stack** - xUnit v2, NSubstitute, AwesomeAssertions, and coverlet for `*.Tests.*` projects"*. Update to dual-cite: *"✅ **ADR-0047 / ADR-0074 Test Stack** - xUnit v2, NSubstitute, AwesomeAssertions, and coverlet for `*.Tests.*` projects"*. The picks ADR is ADR-0074; the patterns ADR is ADR-0047.
   - **Line 91** — section heading `### 🧪 ADR-0047 Test Defaults`. Update to `### 🧪 ADR-0047 / ADR-0074 Test Defaults` (or equivalent dual-cite phrasing — match the README's existing emoji-prefixed heading convention).
   - **Line 113** — *"Moq and FluentAssertions are intentionally absent per ADR-0047 D2."* Update to *"Moq and FluentAssertions are intentionally absent per ADR-0074 D2 / D3 (Moq's 2023 SponsorLink stewardship incident; FluentAssertions v8's October 2024 commercial relicensing) — ratified into ADR-0047 D2."* Match the README's existing prose style.
   - Add one line under the same Test Defaults section noting xUnit's v2.x pinning: *"xUnit is pinned to v2.x per ADR-0074 D1; v3 is the migration target once stabilization and migration cost are bounded."*
   - Add one line documenting the migration-discipline posture for consumers who find existing Moq or FluentAssertions in their downstream repos: *"Existing Moq and FluentAssertions usage migrates opportunistically per ADR-0074 D6; ADR-0047 packets 04 and 05 are the campaign-style migrations."*
2. **Shared test-stack props fragment header comment.** The shared test-stack defaults live at `HoneyDrunk.Standards/HoneyDrunk.Standards/buildTransitive/HoneyDrunk.Tests.props` (the file shipped by ADR-0047 packet 01 inside the `HoneyDrunk.Standards` analyzer package's `buildTransitive` assets). Its current header comment reads:
   ```xml
   <!--
     HoneyDrunk.Tests.props - ADR-0047 test-stack defaults
     Applies only to test projects matching HoneyDrunk *.Tests.* naming conventions.
   -->
   ```
   Replace it with:
   ```xml
   <!--
     HoneyDrunk.Tests.props - shared test-stack defaults.
     Canonical stack: xUnit v2.x + NSubstitute + AwesomeAssertions + coverlet.
     Patterns: ADR-0047 D2 (testing patterns and tooling).
     Library picks + stewardship/licensing rationale: ADR-0074 D1-D4 (testing library stack).
     Migration discipline: ADR-0074 D6 (opportunistic; ADR-0047 packets 04/05 are the campaign migrations).
     Applies only to test projects matching HoneyDrunk *.Tests.* naming conventions.
   -->
   ```
   Also update the sibling marker file at `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards.Tests/buildTransitive/HoneyDrunk.Standards.Tests.props` (current header: *"HoneyDrunk.Standards.Tests - ADR-0047 test-stack marker. / Package dependencies provide xUnit v2, NSubstitute, AwesomeAssertions, and coverlet."*) to dual-cite: *"HoneyDrunk.Standards.Tests - ADR-0047 / ADR-0074 test-stack marker. / Package dependencies provide xUnit v2, NSubstitute, AwesomeAssertions, and coverlet per ADR-0074 D1-D4."*
3. **CHANGELOG.** Repo-level `CHANGELOG.md` — append a docs/chore entry under the in-progress version section (or open a new version section if none is in progress). Per-package `CHANGELOG.md` — **only if the props fragment is shipped inside a versioned package** (e.g. the `HoneyDrunk.Standards` analyzer build-assets package per ADR-0047 packet 01's chosen mechanism), append a docs/chore entry to that package's CHANGELOG. No public-API change → no semantic-version bump triggered by this packet.

## Affected Packages
- `HoneyDrunk.Standards` — README + the test-stack props fragment header comment.

## NuGet Dependencies
None. This packet adds/changes no `PackageReference` entries — the canonical stack declared by the fragment (xunit, xunit.runner.visualstudio, Microsoft.NET.Test.Sdk, NSubstitute, AwesomeAssertions, coverlet.collector) is unchanged. Per invariant 26: this packet creates no new `.csproj`; no analyzer-reference rule is triggered.

## Boundary Check
- [x] All edits in `HoneyDrunk.Standards`. The repo owns the shared Grid-wide analyzer/EditorConfig/build-tooling set, including the ADR-0047 test-stack props fragment — the citation/README update belongs here.
- [x] No Node-runtime behavior change; consumers see no `PackageReference` shift.
- [x] No cross-repo coordination needed beyond ADR-0074 having landed Accepted (packet 00).

## Acceptance Criteria
- [ ] `HoneyDrunk.Standards/README.md` line 19 (top-of-README feature bullet) cites both ADR-0047 and ADR-0074 for the test stack
- [ ] `HoneyDrunk.Standards/README.md` line 91 (the `### 🧪 ADR-0047 Test Defaults` heading) is updated to dual-cite ADR-0047 / ADR-0074
- [ ] `HoneyDrunk.Standards/README.md` line 113 ("Moq and FluentAssertions are intentionally absent") cites ADR-0074 D2 / D3 with the SponsorLink + FluentAssertions-v8 rationale named in-line, and notes ratification into ADR-0047 D2
- [ ] A line on xUnit's v2.x pinning (per ADR-0074 D1) is present in the Test Defaults section
- [ ] A line on opportunistic-migration discipline (per ADR-0074 D6) is present in the Test Defaults section
- [ ] `HoneyDrunk.Standards/HoneyDrunk.Standards/buildTransitive/HoneyDrunk.Tests.props` carries an updated header comment citing both ADR-0047 D2 and ADR-0074 D1–D4 (and D6 for migration)
- [ ] `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards.Tests/buildTransitive/HoneyDrunk.Standards.Tests.props` marker comment is updated to dual-cite ADR-0047 / ADR-0074
- [ ] No `PackageReference` is added, removed, or version-shifted
- [ ] No semantic-version bump triggered (docs change, invariant 27 unaffected); repo-level `CHANGELOG.md` carries a docs/chore line under the in-progress version
- [ ] Per-package CHANGELOG updated only if the props fragment ships inside a versioned package; otherwise omitted (no noise entry)
- [ ] Build green; existing consumers unaffected

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0074 D1 — xUnit v2.x pinning.** The Grid pins xUnit at v2.x for consumption stability; v3 is the migration target when stabilization and migration cost are bounded.

**ADR-0074 D2 — NSubstitute, not Moq (stewardship rationale).** Moq's August 2023 SponsorLink incident: the maintainer shipped undisclosed build-time telemetry that scraped git-config emails and phoned home to GitHub Sponsors. Technically reverted; trust event not closed. The Grid's many-decade horizon weights stewardship-history heavily.

**ADR-0074 D3 — AwesomeAssertions, not FluentAssertions (licensing rationale).** FluentAssertions v8 (October 2024) moved to a paid commercial license. The Grid is commercial; the use is commercial. Beyond the price, the principle: commercial-license dependencies are hostile by default on a many-decade horizon. AwesomeAssertions is the MIT community fork of v7, drop-in compatible.

**ADR-0074 D4 — coverlet as the coverage tool.** `coverlet.collector` test-project package; Cobertura output; per-Node `coverlet.runsettings` for thresholds. The .NET standard; already in use; integrates with `dotnet test`.

**ADR-0074 D5 — `Directory.Build.props` is the distribution mechanism.** The shared fragment, shipped from `HoneyDrunk.Standards` via ADR-0047 packet 01, is the consumption surface this packet updates.

**ADR-0074 D6 — Migration discipline.** New tests use the canonical stack. Existing Moq / FluentAssertions code migrates opportunistically when touched, not by cross-cutting campaign. ADR-0047 packets 04 (FluentAssertions→AwesomeAssertions) and 05 (Moq→NSubstitute) are the explicit campaign migrations; outside those packets the rule reverts to opportunistic.

**ADR-0047 D2 — Testing-library picks (the patterns-ADR side).** ADR-0074 specifies ADR-0047 D2; both ADRs cite the same picks but ADR-0074 is the standalone home of the rationale.

## Dependencies
- `work-item:00` — ADR-0074 should be Accepted before its citation lands in the `HoneyDrunk.Standards` README, so the README cites an Accepted ADR.

## Labels
`chore`, `tier-2`, `ops`, `docs`, `adr-0074`, `wave-2`

## Agent Handoff

**Objective:** Update `HoneyDrunk.Standards/README.md` and the shared test-stack `Directory.Build.props` fragment header to cite ADR-0074 alongside ADR-0047 for the library-pick rationale, the xUnit-v2 pinning, and the opportunistic-migration discipline.

**Target:** `HoneyDrunk.Standards`, branch from `main`.

**Context:**
- Goal: Make the standalone library-pick ADR reachable from `HoneyDrunk.Standards`'s consumption surface so consumers (every Node-standup ADR per ADR-0074 Context) navigate to the rationale ADR directly.
- Feature: ADR-0074 Testing Library Stack rollout, Wave 2.
- ADRs: ADR-0074 (primary), ADR-0047 D2 (the prose form ADR-0074 specifies).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0074 should be Accepted before its citation lands in `HoneyDrunk.Standards`.

**Constraints:**
- **Citation update only.** No `PackageReference` added, removed, or version-shifted. The shared stack — xUnit v2.x, NSubstitute, AwesomeAssertions, coverlet.collector — is unchanged.
- **No semantic-version bump.** Docs change; invariant 27 (solution version moves on public-API change) is unaffected. Repo-level `CHANGELOG.md` carries a docs/chore line; per-package CHANGELOG only if the props fragment ships inside a versioned package — no noise entries for alignment bumps.
- **Invariant 16 — No test code in runtime packages.** The props fragment's `*.Tests.*` scoping rule is unchanged; do not loosen it.
- **Invariant 12 — Per-package CHANGELOG only for packages with actual changes.** This packet changes the props-fragment header comment only; if that fragment ships inside a versioned package, update that package's CHANGELOG; otherwise omit per-package CHANGELOG entries.
- **Invariant 27 — All projects in a solution share one version, excluding test projects.** Docs-only change does not move the solution version.

**Key Files:**
- `HoneyDrunk.Standards/README.md` (three concrete citation surfaces: line 19, line 91, line 113)
- `HoneyDrunk.Standards/HoneyDrunk.Standards/buildTransitive/HoneyDrunk.Tests.props` (shared test-stack defaults header comment)
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards.Tests/buildTransitive/HoneyDrunk.Standards.Tests.props` (sibling marker file header comment)
- `CHANGELOG.md` (repo-level docs/chore line)

**Contracts:** None changed. This is build tooling + docs, not a runtime contract. No `catalogs/contracts.json` change.
