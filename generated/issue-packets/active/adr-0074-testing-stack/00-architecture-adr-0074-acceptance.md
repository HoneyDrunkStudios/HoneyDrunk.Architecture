---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0074", "wave-1"]
dependencies: []
adrs: ["ADR-0074", "ADR-0047"]
accepts: ["ADR-0074"]
wave: 1
initiative: adr-0074-testing-stack
node: honeydrunk-architecture
---

# Accept ADR-0074 — flip status, record the ADR-0047 D2 amendment, register the initiative

## Summary
Flip ADR-0074 (Testing Library Stack — xUnit + NSubstitute + AwesomeAssertions) from Proposed to Accepted: update the ADR header, add the ADR-0074 row to `adrs/README.md`, append an "Amended by ADR-0074" note to ADR-0047 recording that ADR-0074 specifies ADR-0047 D2 by promoting the library-pick rationale to a standalone-citable ADR, and register the `adr-0074-testing-stack` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0074 is an **amendment / specification** ADR: it does not change the library picks committed by ADR-0047 D2 (xUnit + NSubstitute + AwesomeAssertions + coverlet) — it promotes the rationale behind those picks (Moq's 2023 SponsorLink stewardship incident, FluentAssertions v8's October 2024 commercial relicensing, xUnit's `IClassFixture` model and parallel-test posture) from prose inside ADR-0047 D2 into a standalone, frontmatter-citable decision. The amendment posture matches the ADR-0044 → ADR-0011 precedent that ADR-0074 explicitly cites.

ADR-0074 decides:
- **D1** — xUnit (v2.x today; v3 when stable) is the canonical test framework for every Grid test project.
- **D2** — NSubstitute is the canonical mocking library; Moq is not used for new work; existing Moq migrates opportunistically (per D6).
- **D3** — AwesomeAssertions (the MIT community fork of FluentAssertions v7) is the canonical assertion library; FluentAssertions v8+ is not used.
- **D4** — coverlet (`coverlet.collector`, Cobertura output, `coverlet.runsettings` for per-Node thresholds) is the canonical coverage tool.
- **D5** — the combined stack ships via per-repo `Directory.Build.props`, already shipped Grid-wide by ADR-0047 packet 01.
- **D6** — migration discipline: new tests use the canonical stack; existing Moq/FluentAssertions migrates opportunistically, not by cross-cutting campaign. FluentAssertions v7 pinning and SponsorLink-free Moq pinning are permitted alternatives to migration.
- **D7** — out of scope: E2E framework (per ADR-0047 D5/D6), snapshot/approval testing, load/performance testing, mutation testing, BDD/SpecFlow, property-based testing — all are per-Node permissions, not Grid-wide commits.

**ADR-0074's Consequences/Invariants section commits no new invariants.** The rules it enforces (new tests use the canonical stack; no new Moq; no new FluentAssertions v8+; test-project naming per ADR-0047 D4) are already covered by the review-agent's testing-quality category (ADR-0044 D3 category 11) and by the existing testing invariants 50 and 51 from ADR-0047. The ADR's Invariants section says explicitly: "If the scope agent judges any of these invariant-class at acceptance time, numbering is added then. The numbering interacts with the proposed Invariants 50-51 framing from [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) (test-discipline invariants); coordination at acceptance." **This packet judges no new invariant is needed** — the rules are repeats of ADR-0047 already-invariant-coded enforcement, are enforced through the review-agent rubric, and adding parallel invariants would duplicate. The next ADR-0074-derived rule that needs invariant-class enforcement can land as a separate packet.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0074-testing-library-stack.md` — flip `**Status:** Proposed` to `**Status:** Accepted`; refresh two now-stale phrasings about invariants 50/51 (see Proposed Implementation step 6).
- `adrs/README.md` — add the ADR-0074 row to the ADR index (the row is currently missing).
- `adrs/ADR-0047-testing-patterns-and-tooling.md` — append an "Amended by ADR-0074" section recording the D2 specification.
- `initiatives/active-initiatives.md` — register the `adr-0074-testing-stack` initiative with the wave structure and packet checklist for this folder.
- `initiatives/proposed-adrs.md` — remove the ADR-0074 row from the proposed table (currently at line 73) now that the ADR is Accepted; the ADR remains tracked in `adrs/README.md`.
- `constitution/invariants.md` — **no change.** ADR-0074 commits no new invariants (see Context above for the judgment).

## Proposed Implementation
1. Edit the ADR-0074 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Add the ADR-0074 row to `adrs/README.md`. Follow the existing row format (file link, title, status, date, sector, one-paragraph summary). Insert in numerical order (after the ADR-0073 row). Suggested summary phrasing: *"Specifies ADR-0047 D2 by promoting the testing-library picks to a standalone-citable ADR. **xUnit + NSubstitute + AwesomeAssertions + coverlet** are committed as the canonical stack with first-class citation of the stewardship-and-licensing rationale (Moq's 2023 SponsorLink incident, FluentAssertions v8's October 2024 commercial relicensing). Migration is opportunistic per D6; pinning to SponsorLink-free Moq or to FluentAssertions v7 is permitted as an alternative. xUnit v3 named as a future migration target when stable. Out-of-scope items (E2E framework, snapshot testing, load testing, mutation testing, BDD, property-based testing) explicitly remain per-Node permissions, not Grid-wide commits."*
3. Append a `## Amended by ADR-0074` section to `adrs/ADR-0047-testing-patterns-and-tooling.md`, mirroring the precedent set by ADR-0011's "Amended by ADR-0047" and "Amended by ADR-0044" sections. The note should:
   - State that ADR-0074 specifies ADR-0047 D2 by promoting the library-pick rationale to a standalone-citable decision without changing the picks themselves.
   - State that ADR-0047's Status is unchanged — it remains Accepted; the amendment is additive.
   - List the four D-decisions ADR-0074 binds (D1 xUnit, D2 NSubstitute, D3 AwesomeAssertions, D4 coverlet) and note that ADR-0074 D5 explicitly references ADR-0047 D10's `Directory.Build.props` distribution mechanism (shipped via ADR-0047 packet 01).
   - State that ADR-0074 D6 (migration discipline) and ADR-0047 packets 04/05 (the FluentAssertions→AwesomeAssertions and Moq→NSubstitute migration packets) describe the same opportunistic-migration posture from two angles.
4. Register the initiative in `initiatives/active-initiatives.md` with the four-packet checklist for this folder (00 acceptance; 01 review.md citation; 02 Standards README/props citation; 03 stewardship-event watchlist note).
5. `constitution/invariants.md`: no edit.
6. **Refresh ADR-0074's two now-stale 50/51 phrasings.** Invariants 50 and 51 were Proposed when ADR-0074 was drafted; they are Accepted today. Two inline phrases in `adrs/ADR-0074-testing-library-stack.md` still read as if 50/51 were Proposed — update both:
   - **Line 153** — *"The numbering interacts with the proposed Invariants 50-51 framing from [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) (test-discipline invariants); coordination at acceptance."* → *"The numbering interacts with Invariants 50 and 51 from [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) (test-discipline invariants, Accepted); coordination at acceptance."*
   - **Line 225** — *"[`constitution/invariants.md`](../constitution/invariants.md) — invariant 15 (in-memory providers for tests), proposed invariants 50/51 (test-discipline framing)"* → *"[`constitution/invariants.md`](../constitution/invariants.md) — invariant 15 (in-memory providers for tests), invariants 50 and 51 (test-discipline framing)"*.
   These are mechanical staleness refreshes — no semantic change.
7. **Remove the ADR-0074 row from `initiatives/proposed-adrs.md`** (currently at line 73). The ADR is Accepted and lives in `adrs/README.md`; the proposed-adrs table is for ADRs that have not yet flipped. Delete the row only; do not touch surrounding rows.

## Affected Files
- `adrs/ADR-0074-testing-library-stack.md`
- `adrs/README.md`
- `adrs/ADR-0047-testing-patterns-and-tooling.md`
- `initiatives/active-initiatives.md`
- `initiatives/proposed-adrs.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0074 header reads `**Status:** Accepted`
- [ ] ADR-0074's line-153 "proposed Invariants 50-51 framing" phrasing is updated to reference invariants 50/51 as Accepted
- [ ] ADR-0074's line-225 References-section "proposed invariants 50/51 (test-discipline framing)" phrasing drops the "proposed" qualifier
- [ ] `adrs/README.md` carries an ADR-0074 row (the row is currently absent — added in numerical order)
- [ ] `adrs/ADR-0047-testing-patterns-and-tooling.md` carries an `## Amended by ADR-0074` section recording the D2 specification, ADR-0047's Status unchanged
- [ ] `initiatives/active-initiatives.md` registers the `adr-0074-testing-stack` initiative with a packet checklist
- [ ] `initiatives/proposed-adrs.md` no longer lists ADR-0074 (the row at line 73 is removed; surrounding rows untouched)
- [ ] `constitution/invariants.md` is unchanged (no new invariant added — see Context)
- [ ] No catalog schema change in this packet

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0074 D1 — xUnit is the canonical test framework.** xUnit v2.x today (v3 when stable); test-project naming per ADR-0047 D4; `IClassFixture<T>`/`ICollectionFixture<T>` for shared state; parallel execution on by default; `Theory` + `MemberData`/`InlineData` for data-driven tests. Why xUnit: already in use; best parallel-test story among .NET frameworks; fixture model maps onto Grid canary patterns; deep AI-assistance pattern recognition; long support runway.

**ADR-0074 D2 — NSubstitute is the canonical mocking library.** Standard `Substitute.For<T>()` / `.Returns()` / `.Received()` / `.DidNotReceive()` syntax. Per-test substitutes, not shared via static state. Why NSubstitute, not Moq: the August 2023 SponsorLink incident was a stewardship-trust event — Moq's maintainer shipped undisclosed build-time telemetry that scraped git-config emails and phoned home to GitHub Sponsors; the behavior was reverted under backlash but the stewardship-history concern is not closed by the technical revert. Why not FakeItEasy: NSubstitute has wider ecosystem mindshare and deeper AI-assistance pattern recognition in 2026.

**ADR-0074 D3 — AwesomeAssertions is the canonical assertion library.** Drop-in compatible with FluentAssertions v7 API. Standard fluent patterns — `Should().Be()`, `Should().NotBeNull()`, `Should().HaveCount()`, `Should().Throw<T>()`. Why AwesomeAssertions, not FluentAssertions: v8 (October 2024) moved to a paid commercial license; the Grid's many-decade horizon makes commercial-license dependencies hostile by default regardless of price. AwesomeAssertions is the MIT community fork of v7. Why not Shouldly: continuity — the Grid's existing tests use FluentAssertions v7 patterns; AwesomeAssertions is drop-in, Shouldly is not. Why not xUnit's native assertions: fluent assertions are markedly easier to read in failure messages and easier to chain.

**ADR-0074 D4 — coverlet is the canonical coverage tool.** `coverlet.collector` test-project package; `coverlet.runsettings` per Node for threshold and format configuration; Cobertura XML as the output format consumed by CI per ADR-0011 / ADR-0032.

**ADR-0074 D5 — Default test-project template via `Directory.Build.props`.** The combined stack ships via per-repo `Directory.Build.props` per ADR-0047 D10; the shared fragment landed via ADR-0047 packet 01 (in `HoneyDrunk.Standards`).

**ADR-0074 D6 — Migration discipline.** New tests use the canonical stack; existing Moq/FluentAssertions migrates opportunistically when a test file is touched for other reasons. FluentAssertions v7 pinning and SponsorLink-free Moq pinning are permitted alternatives. ADR-0047 packets 04 and 05 are the campaign-style migrations; outside those packets the rule reverts to opportunistic.

**ADR-0074 Consequences — Invariants.** The ADR defers invariant numbering to scope-agent judgment at acceptance. This packet's judgment: no new invariant. The ADR-0074 rules are repeats of ADR-0047 invariants 50/51 enforcement and the review-agent rubric (ADR-0044 D3 category 11); duplicating them as parallel invariant entries would add noise without enforcement gain.

## Constraints
- **Acceptance precedes flip.** ADR-0074 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Do not add new invariants.** ADR-0074's Consequences/Invariants section explicitly defers numbering to the scope agent at acceptance; the scope-agent judgment is no new invariant. Rules are enforced through invariants 50/51 (ADR-0047) and the review-agent rubric (ADR-0044 D3 category 11).
- **Do not change ADR-0047's Status.** ADR-0047 is Accepted; ADR-0074 amends it but does not re-accept or supersede it.
- **Do not edit ADR-0074's `Status:` field anywhere except this packet's PR.** Other packets in this initiative may *reference* ADR-0074 as Accepted, but the flip lands here.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0074`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0074 to Accepted, add the missing ADR index row, record the ADR-0047 D2 amendment, and register the testing-library-stack initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0074 so the remaining packets in this initiative can reference its decisions as live rules, and so future Node-standup ADRs and the review-agent rubric can cite ADR-0074 directly for the library-pick rationale.
- Feature: ADR-0074 Testing Library Stack rollout, Wave 1.
- ADRs: ADR-0074 (primary), ADR-0047 (amended — D2 specified), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0074 stays Proposed until this PR merges.
- Do not edit `constitution/invariants.md`. ADR-0074 commits no new invariants; the rules are enforced through invariants 50/51 (ADR-0047) and the review-agent rubric (ADR-0044 D3 category 11).
- Do not change ADR-0047's Status — it remains Accepted; the amendment is additive.
- ADR row insertion into `adrs/README.md` follows numerical order; match the existing row format.

**Key Files:**
- `adrs/ADR-0074-testing-library-stack.md` (status flip + lines 153/225 staleness refresh)
- `adrs/README.md`
- `adrs/ADR-0047-testing-patterns-and-tooling.md`
- `initiatives/active-initiatives.md`
- `initiatives/proposed-adrs.md` (remove ADR-0074 row at line 73)

**Contracts:** None changed.
