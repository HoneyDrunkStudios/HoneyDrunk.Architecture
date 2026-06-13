---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0074", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0074", "ADR-0047"]
accepts: ["ADR-0074"]
wave: 2
initiative: adr-0074-testing-stack
node: honeydrunk-architecture
---

# Author the testing-stack stewardship-event watchlist in business/context

## Summary
Add an operator-facing watchlist note to `business/context/` capturing the four ADR-0074 Follow-up Work items: (1) xUnit v3 stabilization as a future migration trigger, (2) AwesomeAssertions stewardship trajectory monitoring, (3) NSubstitute stewardship trajectory monitoring, (4) the next .NET test-library stewardship event evaluated under ADR-0074's frame rather than from scratch. The note is the operator-readable surface where a stewardship event lands when it next happens — without it, the next event re-derives the rationale from scratch instead of consulting a citable Grid record.

## Context
ADR-0074 Follow-up Work names a watch list:

> Watch list: xUnit v3 stabilization (migration target when ready); AwesomeAssertions stewardship trajectory (continues to be MIT-licensed and maintained); NSubstitute stewardship trajectory (no concerns today); the next .NET test-library stewardship event (evaluated under this ADR).

ADR-0074's Operational Consequences names the same purpose differently:

> The Moq SponsorLink and FluentAssertions licensing events have a citable Grid record. Future stewardship events are evaluated under this ADR's frame rather than from scratch.

The Grid pattern for operator-facing context lives in `business/context/`. Today the folder carries only `entity.md` and `operating-costs.md` — no existing testing-tooling or stewardship-event note. This packet is the first stewardship-watchlist note in this folder; it establishes the convention for future stewardship/event watchlist notes to follow.

This is a docs-only packet. No code, no workflow, no .NET project. It depends only on packet 00 (ADR-0074 Accepted) so the watch note cites an Accepted ADR.

## Scope
- A new note in `business/context/` documenting the four watch-list items, each with the current state, the trigger condition, and the response. This is the first stewardship-watchlist note in this folder.

## Proposed Implementation
1. **Create the note.** Today `business/context/` contains only `entity.md` and `operating-costs.md` — no existing testing-tooling or stewardship-event note exists. Create a new file. Suggested name: `testing-stack-watchlist.md` (or `testing-library-stewardship.md`). This packet establishes the stewardship-watchlist convention in this folder; pick a clear, durable name that future stewardship-watchlist notes can mirror.
2. **Document the four watch-list items, each in this shape:**
   - **xUnit v3 stabilization.**
     - *Current state (2026-05):* xUnit v2.x is pinned per ADR-0074 D1. xUnit v3 is in development.
     - *Trigger condition:* xUnit v3 ships a stable major release **and** the v2→v3 migration cost across the Grid's test corpus is bounded (rough proxy: most third-party xUnit-aware tooling — Test SDK, runner, coverage collectors, AI-assistance pattern recognition — supports v3 without friction).
     - *Response:* Author a follow-up ADR amending ADR-0074 D1 to repin to v3. The shared `Directory.Build.props` fragment in `HoneyDrunk.Standards` bumps as part of that ADR's first packet; per-Node migration follows opportunistically per ADR-0074 D6.
   - **AwesomeAssertions stewardship trajectory.**
     - *Current state (2026-05):* MIT-licensed; actively maintained; community-driven; no current license-trajectory or stewardship concerns.
     - *Trigger condition:* Any stewardship event of the SponsorLink / FluentAssertions-v8 class — undisclosed build-time telemetry, license relicensing announcement, maintainer-departure with successor risk, or a similar trust event.
     - *Response:* Evaluate under ADR-0074's stewardship-trust framework (the Moq / FluentAssertions reasoning is the precedent). Two paths: (a) author an amending ADR moving the assertion library (likely candidates: Shouldly per ADR-0074's Alternatives Considered; xUnit native assertions per the ADR's "Why not xUnit native" rejection), (b) pin to the last unaffected version and document the freeze if no credible replacement exists. The decision lives in the amending ADR, not in this note.
   - **NSubstitute stewardship trajectory.**
     - *Current state (2026-05):* Clean stewardship history; active maintenance; permissive license; the .NET-community pragmatic answer post-SponsorLink.
     - *Trigger condition:* Same class of event as AwesomeAssertions.
     - *Response:* Same shape — evaluate under ADR-0074's framework; an amending ADR moves the mocking library (likely candidate: FakeItEasy per ADR-0074's Alternatives Considered) or pins-and-freezes.
   - **Next .NET test-library stewardship event (generic).**
     - *Current state (2026-05):* No known event.
     - *Trigger condition:* A stewardship/licensing event in any library named by ADR-0074 D1–D4 (xUnit, NSubstitute, AwesomeAssertions, coverlet) **or** in any test-tier library named by ADR-0047 (Playwright, Testcontainers, WebApplicationFactory, Maestro, BenchmarkDotNet, Azure Load Testing).
     - *Response:* Evaluate under ADR-0074's stewardship-trust frame. Outcomes: (a) amending ADR moves the library, (b) pin-and-freeze, (c) no action if the event resolves without trust damage.
3. **Cross-link the note to ADR-0074.** The note's header (or first paragraph) cites ADR-0074 as the source of the stewardship-trust framework; a reader following the citation lands on the rationale ADR.
4. **Operator-facing tone.** This is operator context, not invariant text. Match the operator-facing prose register already used in `business/context/entity.md` and `business/context/operating-costs.md`. Goal: the operator reads this in 90 seconds and knows what to look at and what to do.

## Affected Files
- A new note in `business/context/` (suggested name: `testing-stack-watchlist.md`).

## NuGet Dependencies
None. This packet touches only a Markdown operator note; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. `business/context/` is the operator-context surface; the testing-stack watchlist is operator-facing.
- [x] No code change in any other repo.
- [x] First stewardship-watchlist note in `business/context/` — establishes the convention; today the folder carries only `entity.md` and `operating-costs.md`.

## Acceptance Criteria
- [ ] `business/context/` contains a new testing-stack stewardship watchlist note
- [ ] The note documents the four watch-list items (xUnit v3 stabilization; AwesomeAssertions trajectory; NSubstitute trajectory; next .NET test-library stewardship event) each with current state, trigger, and response
- [ ] The note cites ADR-0074 as the source of the stewardship-trust framework
- [ ] The prose register is operator-facing and 90-second readable, matching `entity.md` and `operating-costs.md`
- [ ] No invariant change; no catalog change; no code change

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0074 Follow-up Work — the watch list.** xUnit v3 stabilization (migration target when ready); AwesomeAssertions stewardship trajectory (continues to be MIT-licensed and maintained); NSubstitute stewardship trajectory (no concerns today); the next .NET test-library stewardship event (evaluated under this ADR).

**ADR-0074 Operational Consequences — stewardship-trust principle documented.** Future stewardship events are evaluated under this ADR's frame rather than from scratch. The watch list is the operator-readable surface where the next event lands.

**ADR-0074 D1 — xUnit v2.x today, v3 when stable.** The v3 migration trigger needs an explicit watch-line so the operator knows the wait-condition.

**ADR-0074 D2 — NSubstitute (post-SponsorLink choice).** The pattern: stewardship damage is evaluated holistically, technical revert does not close the trust event.

**ADR-0074 D3 — AwesomeAssertions (post-FluentAssertions-v8 choice).** The pattern: commercial-license trajectory is a substrate-hostile signal regardless of price.

**ADR-0074 D4 — coverlet (no current concerns).** The coverlet line in the generic-event watch entry covers the unlikely-but-possible stewardship event.

## Constraints
- **Operator-facing language.** `business/context/` is read by the operator; the watch note must let the operator recognize a trigger and know the response is "author an amending ADR" or "pin-and-freeze."
- **Do not pre-commit a replacement library.** The "likely candidate" alternative library names (Shouldly, FakeItEasy, xUnit native) are *named* per ADR-0074's Alternatives Considered as candidates the amending ADR would weigh — they are not committed defaults. The amending ADR makes the call.
- **No invariant or catalog change here.** Those are not the right surface for an operator watch list.
- **Match the operator-facing tone of `entity.md` / `operating-costs.md`.** This packet establishes the stewardship-watchlist convention in `business/context/`; pick a clear shape future stewardship notes can mirror.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0074`, `wave-2`

## Agent Handoff

**Objective:** Author (or extend) an operator-facing watch list note in `business/context/` documenting the four ADR-0074 Follow-up Work watch items — xUnit v3, AwesomeAssertions trajectory, NSubstitute trajectory, generic next-event — each with current state, trigger condition, and response.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make ADR-0074's watch list operator-readable. Without the note, the next stewardship event re-derives the rationale from scratch instead of consulting the citable record ADR-0074 establishes.
- Feature: ADR-0074 Testing Library Stack rollout, Wave 2.
- ADRs: ADR-0074 (primary). No prior stewardship-watchlist precedent exists in `business/context/` — this packet establishes the convention.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0074 should be Accepted before its watch list lands as an operator note.

**Constraints:**
- Operator-facing prose — match the tone of `business/context/entity.md` and `business/context/operating-costs.md` (the only two files in that folder today).
- First stewardship-watchlist note in `business/context/` — establishes the convention. Pick a clear, durable file name.
- Do not pre-commit a replacement library. Name candidates from ADR-0074's Alternatives Considered, not commitments.
- No invariant or catalog change.

**Key Files:**
- A new note in `business/context/` (suggested name: `testing-stack-watchlist.md`).

**Contracts:** None changed.
