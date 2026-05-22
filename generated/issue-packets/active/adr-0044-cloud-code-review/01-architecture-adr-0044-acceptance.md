---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0044", "wave-1"]
dependencies: []
adrs: ["ADR-0044", "ADR-0011"]
accepts: ["ADR-0044"]
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Accept ADR-0044 — flip status, finalize the two new invariants, register the cloud-code-review initiative

## Summary
Flip ADR-0044 from Proposed to Accepted: update the ADR header, the ADR index, record the two new code-review invariants in `constitution/invariants.md`, record the ADR-0011 amendment (D10 of ADR-0044 amends ADR-0011 D5/D10/D11), and register the cloud-code-review initiative in the tracking files.

## Context
ADR-0044 (Grid-Aware Cloud Code Review and AI-Authored PR Discipline) is priority #3 on `initiatives/current-focus.md`. It amends ADR-0011 by reversing the local-only review-agent posture (D10), rendering the CodeRabbit rejection moot (D11), and adding AI-authored PR discipline (D6-D9). This packet is the acceptance gate — every other packet in this initiative references ADR-0044's decisions as live rules, so the flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project. It is `Actor=Agent` but the human must confirm the final invariant numbers because the 34+ invariant range is contested (see Constraints).

## Scope
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- The ADR index (`adrs/README.md` or equivalent index file) — update the ADR-0044 row to Accepted.
- `constitution/invariants.md` — append the two new invariants ADR-0044 introduces (see below).
- `adrs/ADR-0011-code-review-and-merge-flow.md` — append an amendment note recording that ADR-0044 D10 amends ADR-0011 D5 (preserved), D10 (reversed), D11 (rendered moot). Do not change ADR-0011's Status.
- `initiatives/active-initiatives.md` — register the `adr-0044-cloud-code-review` initiative.
- `initiatives/proposed-adrs.md` — ADR-0044 moves from "Awaiting" to "In Progress" once packets are filed (the `hive-sync` agent maintains this; this packet only needs to ensure the initiative is registered).

**`current-focus.md` priority bookkeeping.** ADR-0044 is `current-focus.md` priority #3 ("Land ADR-0044 — Cloud Code Review") and priority #7 ("ADR-0044 D3 rubric rollout", gated on #3). This acceptance packet flipping ADR-0044 to Accepted satisfies the "ADR-0044 Accepted" half of priority #3's exit signal; the `job-review-agent.yml` MVP half is satisfied by packets 03+06. Priority #7's exit signal is satisfied by packets 04 and 09. When the initiative reaches completion (all 17 packets `Done`, all four phase exit criteria met — see the dispatch plan's Archival section), priorities #3 and #7 should be marked complete and dropped from the ranked list at the next ADR-0043 weekly briefing. This packet does not edit `current-focus.md` priority status itself (the briefing owns that surface); it is noted here and in the dispatch plan so the bookkeeping is not lost.

## Proposed Implementation

### The two new invariants
ADR-0044's Consequences/Invariants section adds exactly two. The ADR deliberately does not reserve numbers because the 34+ range is contested between ADR-0012 (34-38) and ADR-0015 (34-36).

**How to find the next free numbers — read carefully.** `constitution/invariants.md` is **topic-grouped and NOT contiguously numbered**. Its *physical tail* is invariant 49 (the Audit Invariants section), but the *highest invariant number* in the file is **51** — invariants 50 and 51 were added by ADR-0047 and sit mid-file in the Testing Invariants section, not at the end. The execution agent must **scan the entire file for the highest invariant number anywhere in it** — never assume the last invariant physically in the file is the maximum. Concretely: `grep` every `^NN.` invariant heading across the whole file, sort numerically, take the max (51 as of 2026-05-22), and assign the next free pair.

So ADR-0044's two new invariants are **52 and 53** (51 is the current max; 50/51 from ADR-0047 are already landed). If a later edit to `invariants.md` has pushed the max higher by flip time, assign the next free pair after whatever the true max is and note the assignment in the PR body. The `hive-sync` agent reconciles final numbering.

Invariant text to add (verbatim intent from ADR-0044 Consequences):

> **Every non-draft PR on an `enabled` repo runs the cloud-wired `review` agent.** A repo is `enabled` when it carries a `.honeydrunk-review.yaml` with `enabled: true`. Skip is via the `skip-review` PR label or `enabled: false` config — both explicit, both visible. See ADR-0044 D1, D11.

> **Agent-authored PRs touching a high-risk Node receive two independent LLM-review perspectives before merge.** The catalog of high-risk Nodes lives in `catalogs/grid-health.json` under the `review_risk_class` field. The second perspective is a contrarian-prompt pass by default; `/ultrareview` or a `refine` pass are alternative escalation paths the human may invoke. See ADR-0044 D8.

### ADR-0011 amendment note
Append to ADR-0011 a short "Amended by ADR-0044" section recording:
- D5 (review agent advisory) — **preserved** by ADR-0044.
- D10 (review agent local-only, human-invoked) — **reversed** by ADR-0044 D10; the agent now runs automatically in the cloud. The local Claude Code invocation path remains available.
- D11 (CodeRabbit rejected) — **rendered moot** by ADR-0044 D10; the Grid builds the reviewer rather than buying one.

## Affected Files
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md`
- `adrs/README.md` (or the ADR index file in use)
- `constitution/invariants.md`
- `adrs/ADR-0011-code-review-and-merge-flow.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0044 header reads `**Status:** Accepted`
- [ ] ADR index row for ADR-0044 reflects Accepted
- [ ] `constitution/invariants.md` carries the two new invariants with final numbers assigned and no "(Proposed)" qualifier
- [ ] ADR-0011 carries an "Amended by ADR-0044" note recording the D5/D10/D11 dispositions; ADR-0011's own Status is unchanged
- [ ] `initiatives/active-initiatives.md` registers the `adr-0044-cloud-code-review` initiative with a packet checklist
- [ ] The PR body records which invariant numbers were assigned and notes the `hive-sync` reconciliation expectation
- [ ] No catalog schema change in this packet (`review_risk_class` lands in packet 13, the `generated/post-merge-audits/` directory in packet 15)

## Human Prerequisites
- [ ] Confirm the final invariant numbers before merge — the human should sanity-check the assigned pair (expected 52/53) against the **highest invariant number anywhere in `constitution/invariants.md`**, not against the file's physical tail. The file is topic-grouped: its tail is invariant 49 but its max number is 51 (ADR-0047's 50/51 sit mid-file in the Testing Invariants section).

## Dependencies
None. This is the first packet in the initiative.

## Referenced ADR Decisions

**ADR-0044 D1** — Build `job-review-agent.yml` in HoneyDrunk.Actions as a reusable workflow following `pr-core.yml` factoring; advisory non-required check.
**ADR-0044 D10** — Amends ADR-0011: D5 preserved (advisory), D10 reversed (no longer local-only), D11 moot (build not buy).
**ADR-0044 D11** — Four-phase rollout: Phase 1 MVP on Architecture repo only; Phase 2 rollout to the live Nodes (D11 says "all 12 live Nodes"; in practice the Phase-2 fan-out is the 10 not already piloted — Architecture is Phase 1, Studios is TypeScript and onboarded separately); Phase 3 discipline tightening; Phase 4 sampling audit + polish.

## Constraints
- **Acceptance precedes flip.** ADR-0044 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Do not reserve specific invariant numbers in the ADR text.** Assign the next free pair; the ADR explicitly delegates numbering to landing time.
- **Do not change ADR-0011's Status.** ADR-0011 is itself still Proposed; ADR-0044 amends it but does not accept it.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0044`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0044 to Accepted, record its two new invariants in `constitution/invariants.md`, append the ADR-0011 amendment note, and register the initiative in the trackers.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0044 so the cloud-code-review build packets can reference its decisions as live rules.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 1.
- ADRs: ADR-0044 (primary), ADR-0011 (amended), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- Acceptance precedes flip — ADR-0044 stays Proposed until this PR merges.
- Assign the next free invariant numbers; do not reserve numbers in ADR text.
- Do not change ADR-0011's Status.

**Key Files:**
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `adrs/ADR-0011-code-review-and-merge-flow.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
