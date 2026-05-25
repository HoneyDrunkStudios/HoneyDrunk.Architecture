---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0074", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0074", "ADR-0047", "ADR-0044"]
accepts: ["ADR-0074"]
wave: 2
initiative: adr-0074-testing-stack
node: honeydrunk-architecture
---

# Cite ADR-0074 in the review-agent testing-quality category for the library-pick rationale

## Summary
Update `.claude/agents/review.md`'s Testing Quality category so it cites **ADR-0074** alongside ADR-0047 as the canonical source for the test-library stack — making the Moq/SponsorLink and FluentAssertions/v8 license rationale recoverable from the rubric instead of buried inside ADR-0047 D2 prose. No rule change, no severity-tag change — purely a citation update so future reviewer/scope agents land on the standalone-citable ADR when they pull rationale.

## Context
ADR-0074 promotes the library-pick rationale from ADR-0047 D2's prose into a standalone, frontmatter-citable decision. The Context section names the review-agent's testing-quality category as a primary consumer:

> The `review` agent's testing-quality category per ADR-0044 D3 category 11 checks for the committed stack at PR time. Pinning the libraries as a citable ADR makes the reviewer's check unambiguous.

The current `.claude/agents/review.md` Testing Quality category (established by ADR-0044 packet 04 and refined by ADR-0047 packet 08) already cites the canonical stack and flags Moq / FluentAssertions reintroductions:

> **Framework and package regressions:**
> - Unit and integration tests use xUnit v2.x, NSubstitute, AwesomeAssertions, coverlet, and Microsoft.NET.Test.Sdk via the shared test-stack props when available.
> - Flag new or reintroduced `Moq` package references/usages. NSubstitute is the Grid standard.
> - Flag new or reintroduced `FluentAssertions` package references/usages. AwesomeAssertions is the Grid standard.

And the category header reads:

> Apply this checklist to every PR that adds or changes code, test projects, CI test workflows, or public contracts. ADR-0047 makes these the concrete standards behind ADR-0044 D3 category 11.

The rule text is right; the **citation** is incomplete. A review agent (or a scope agent inheriting the rubric) reading these lines lands on ADR-0047 — and once there, must wade through D2's prose to find the SponsorLink / FluentAssertions-v8 reasoning. ADR-0074 is the standalone home of that reasoning; the rubric should point there.

This packet is a citation update only — no rule change, no severity-tag change, no anti-pattern added, no new sub-rubric. It depends on packet 00 (ADR-0074 Accepted) so the rubric cites an Accepted ADR rather than a Proposed one.

## Scope
- `.claude/agents/review.md` — Testing Quality category — update the header and the "Framework and package regressions" subsection to cite ADR-0074 alongside ADR-0047 for the library-pick rationale.

## Proposed Implementation
1. **Category header.** Change the testing-quality category header from:
   > Apply this checklist to every PR that adds or changes code, test projects, CI test workflows, or public contracts. ADR-0047 makes these the concrete standards behind ADR-0044 D3 category 11.
   to:
   > Apply this checklist to every PR that adds or changes code, test projects, CI test workflows, or public contracts. **ADR-0047** (testing patterns and tooling) and **ADR-0074** (testing library stack — xUnit + NSubstitute + AwesomeAssertions + coverlet) make these the concrete standards behind ADR-0044 D3 category 11.
2. **"Framework and package regressions" subsection.** Add an ADR-0074 citation to the "Flag new or reintroduced `Moq`" and "Flag new or reintroduced `FluentAssertions`" lines so the reviewer (and any operator reading the rubric) can navigate to the standalone rationale ADR:
   - **Moq flag-line:** append "(see ADR-0074 D2 — the 2023 SponsorLink stewardship incident is the standalone rationale)."
   - **FluentAssertions flag-line:** append "(see ADR-0074 D3 — FluentAssertions v8's October 2024 commercial relicensing is the standalone rationale)."
3. **xUnit v3 note.** Add a single line to the same subsection capturing ADR-0074 D1's xUnit-v3-when-stable posture, so the reviewer flags a PR proposing an xUnit v3 jump without a corresponding ADR amendment:
   - "xUnit is pinned to v2.x per ADR-0074 D1. Flag any PR introducing `xunit.v3.*` packages, or bumping an existing `xunit` / `xunit.runner.visualstudio` / `XunitVersion` reference from a 2.x version range to a 3.x version range, without an ADR-0074-amending decision. Do not flag `XunitVersion` matches on their own — only when the bound version range crosses the 2.x → 3.x major boundary."
4. **Match the existing rubric format.** Keep the severity-tagging convention from ADR-0044 D3 — these are "Flag" lines (the existing convention for the testing-quality category's package-regression rules); do not invent a parallel severity term. Do not fork the category into a new subsection; the additions sit alongside the existing rules.

## Affected Files
- `.claude/agents/review.md`

## NuGet Dependencies
None. This packet touches only the review-agent rubric (Markdown); no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` — `.claude/agents/review.md` lives here. Routing rule "architecture, ADR, agent, sector → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] The review-agent rubric is the ADR-0044-established surface; this packet extends a citation in it, consistent with ADR-0074's stated consumer pattern.

## Acceptance Criteria
- [ ] Testing Quality category header cites both ADR-0047 (testing patterns) **and** ADR-0074 (testing library stack)
- [ ] "Flag new or reintroduced `Moq`" line carries a parenthetical citation to ADR-0074 D2 + SponsorLink rationale
- [ ] "Flag new or reintroduced `FluentAssertions`" line carries a parenthetical citation to ADR-0074 D3 + FluentAssertions v8 license rationale
- [ ] A new line exists under "Framework and package regressions" flagging `xunit.v3.*` package introductions or 2.x → 3.x version-range bumps without an ADR-0074-amending decision (the rule explicitly excludes generic `XunitVersion` mentions that stay within the 2.x range)
- [ ] Severity-tagging matches the existing rubric ("Flag" lines, not "Request Changes" — this is the established convention for package-regression rules in this category)
- [ ] No other rule, category, or sub-rubric in `review.md` is changed by this packet
- [ ] No invariant change; no catalog change; no code change

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0074 D1 — xUnit pinned to v2.x.** xUnit v2.x today; v3 when stable and migration cost is bounded. New PRs jumping to xUnit v3 without a corresponding ADR amendment are out of policy and the review agent should flag them.

**ADR-0074 D2 — NSubstitute, not Moq.** Moq's August 2023 SponsorLink incident is the load-bearing rationale: the maintainer shipped undisclosed build-time telemetry that scraped developer git-config emails, hashed them, and phoned home to GitHub Sponsors at every build. The behavior was reverted under backlash but stewardship-trust did not recover; the Grid's many-decade horizon weights stewardship-history heavily. New Moq introductions are flagged.

**ADR-0074 D3 — AwesomeAssertions, not FluentAssertions.** FluentAssertions v8 (October 2024) moved to a paid commercial license; the Grid is a commercial entity, so the use is commercial. Beyond the price, the principle: commercial-license dependencies are hostile by default on a many-decade horizon. AwesomeAssertions is the MIT community fork of FluentAssertions v7, drop-in compatible. New FluentAssertions introductions are flagged.

**ADR-0044 D3 — The review-agent rubric and category 11.** `.claude/agents/review.md` carries the multi-category review rubric; category 11 is testing quality. ADR-0074 D's enforcement target is the testing-quality category at PR time; this packet adds the standalone-citable ADR to the existing citation.

**ADR-0047 D2 — Testing-library picks (the prose form ADR-0074 specifies).** The library-pick rationale lived inside ADR-0047 D2 prose until ADR-0074 promoted it. ADR-0047 D2 remains the testing-tooling ADR; ADR-0074 is the library-stack ADR sub-decision. Both citations apply.

## Constraints
- **Citation update only.** Do not change any rule text beyond appending the ADR-0074 parentheticals and adding the single xUnit-v3 flag-line. The rubric's behavior is unchanged; only the citation surface improves.
- **Extend, do not fork, the testing-quality category.** No new subsection; no parallel severity terminology. The additions sit alongside the existing rules.
- **Match the established severity tag.** Package-regression rules in this category use "Flag" — keep it; do not escalate to "Request Changes."
- **Do not edit any other category.** Performance, Security, AI-Safety, etc. are out of scope here.
- **Coordinate with `hive-sync` for rubric drift.** Per the ADR-0044 D3 / packet 17 mechanism, the review-rubric drift detector reconciles agent-file ↔ catalog drift; the additions here should not introduce drift in that mechanism (the citations name existing ADRs).

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0074`, `wave-2`

## Agent Handoff

**Objective:** Update the Testing Quality category header and the "Framework and package regressions" subsection of `.claude/agents/review.md` to cite ADR-0074 alongside ADR-0047 for the library-pick rationale, and add a one-line flag for xUnit v3 introductions without an ADR-0074-amending decision.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make ADR-0074's standalone library-pick rationale citable from the review-agent rubric so the SponsorLink / FluentAssertions-v8 reasoning is recoverable in one click rather than buried in ADR-0047 D2 prose.
- Feature: ADR-0074 Testing Library Stack rollout, Wave 2.
- ADRs: ADR-0074 D1/D2/D3 (primary), ADR-0044 D3 category 11 (the rubric this edits), ADR-0047 D2 (the prose form ADR-0074 specifies — co-cited).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0074 should be Accepted before its citation lands in the rubric so the rubric cites an Accepted ADR.

**Constraints:**
- Citation update only — no rule-text change, no severity escalation.
- Extend the existing Testing Quality category — do not fork into a new category or subsection.
- Match the existing "Flag" severity tag for package-regression rules.
- Do not touch any other category in `review.md`.

**Key Files:**
- `.claude/agents/review.md`

**Contracts:** None changed.
