---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0046", "wave-1"]
dependencies: []
adrs: ["ADR-0046", "ADR-0044", "ADR-0011", "ADR-0007"]
accepts: ["ADR-0046"]
wave: 1
initiative: adr-0046-specialist-review-agents
node: honeydrunk-architecture
---

# Accept ADR-0046 — flip status, finalize the new invariant, register the specialist-review-agents initiative

## Summary
Flip ADR-0046 (Specialist Review Agents) from Proposed to Accepted: update the ADR header, update the ADR index, record the one new specialist-review invariant in `constitution/invariants.md`, and register the `adr-0046-specialist-review-agents` initiative in the tracking files.

## Context
ADR-0046 codifies the **pattern** of specialist review agents — narrow-lens, deeper-rigor agents (`cfo`, `security`, `performance`, `ai-safety`, `a11y`) that complement the generalist `review` agent's twenty-category rubric from ADR-0044. It layers above ADR-0044 (does not amend it) and names an initial roster of five agents whose definition files land as follow-up packets in this same initiative. Every other packet here references ADR-0046's decisions (D2 roster, D4 file structure, D5 upstream-awareness, D8 priority order, D10 phasing) as live rules, so the flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project. It is `Actor=Agent`, but the human should sanity-check the final invariant number before merge (see Constraints).

## Scope
- `adrs/ADR-0046-specialist-review-agents.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- The ADR index (`adrs/README.md` or equivalent index file) — update the ADR-0046 row to Accepted.
- `constitution/invariants.md` — append the one new invariant ADR-0046 introduces (see below).
- `initiatives/active-initiatives.md` — register the `adr-0046-specialist-review-agents` initiative with a packet checklist (8 packets).
- `initiatives/proposed-adrs.md` — ADR-0046 moves from "Awaiting" to "In Progress" once packets are filed; the `hive-sync` agent maintains this surface, so this packet only needs to ensure the initiative is registered in `active-initiatives.md`.

## Proposed Implementation

### The one new invariant
ADR-0046's Consequences/Invariants section adds exactly one. **Its reserved number is 81.**

**Why 81 and not the file's apparent next-free number.** Invariant 81 is pre-reserved as part of a 12-ADR batch — each ADR in that batch gets a reserved invariant number, allocated up front to avoid cross-ADR numbering races. The true current maximum invariant number in `constitution/invariants.md` is **51** (verified 2026-05-22); the gap between 51 and 81 is intentional reservation headroom for the batch, not an error. Assign **81** to this invariant.

**If a number above 51 lands from outside the batch before merge.** `constitution/invariants.md` is topic-grouped and NOT contiguously numbered, so always scan the whole file for the true maximum before assigning. If, at flip time, any invariant above 51 has landed from an ADR *outside* this 12-ADR batch, shift the batch's reserved numbers upward — never reuse a number. In that case assign the next free number above the batch's adjusted floor and note the shift in the PR body. The `hive-sync` agent reconciles final numbering.

Invariant text to add (verbatim intent from ADR-0046 Consequences):

> **Specialist review agents are advisory and complementary to the `review` agent.** A specialist's findings do not gate merge any more than the generalist `review` agent's do — the advisory posture of ADR-0011 D5 is preserved. The `review` agent remains the baseline reviewer with the full twenty-category rubric and runs on every PR; specialists run only when their lens specifically applies and are invoked manually at v1. The human is the final arbiter of which findings warrant action. See ADR-0046 D1, D3.

This invariant belongs in the **Code Review Invariants** topic group (alongside invariants 31–33), since it governs the review surface. The execution agent records the placement and the assigned number (81, unless a batch-external shift applies) in the PR body.

## Affected Files
- `adrs/ADR-0046-specialist-review-agents.md`
- `adrs/README.md` (or the ADR index file in use)
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0046 header reads `**Status:** Accepted`
- [ ] ADR index row for ADR-0046 reflects Accepted
- [ ] `constitution/invariants.md` carries the one new invariant numbered **81** (or batch-shifted upward if a number above 51 landed from outside the 12-ADR batch), with no "(Proposed)" qualifier, placed in the Code Review Invariants group
- [ ] `initiatives/active-initiatives.md` registers the `adr-0046-specialist-review-agents` initiative with a packet checklist (8 packets)
- [ ] The PR body records which invariant number was assigned and notes the `hive-sync` reconciliation expectation
- [ ] No agent file is created and no `agent-capability-matrix.md` change in this packet (those land in packets 02–07)

## Human Prerequisites
- [ ] Confirm the invariant number before merge. The reserved number is **81** — pre-allocated as part of a 12-ADR batch; the true current maximum invariant number in `constitution/invariants.md` is 51 (verified 2026-05-22), and the 51→81 gap is intentional batch-reservation headroom, not an error. The file is topic-grouped and NOT contiguously numbered, so scan the whole file for the true maximum. If any invariant above 51 has landed from an ADR *outside* this batch before merge, shift the batch's reserved numbers upward — never reuse a number — and confirm the adjusted assignment.

## Dependencies
None. This is the first packet in the initiative.

## Referenced ADR Decisions

**ADR-0046 D1** — Specialist agents complement, do not replace, the `review` agent. `review` remains the baseline reviewer running the full twenty-category rubric on every PR; specialists are depth-on-demand, invoked selectively when their lens applies. Specialist findings do not displace `review` findings — both are advisory.
**ADR-0046 D2** — Initial roster of five specialist agents: `cfo` (cost + AI-cost), `security`, `performance`, `ai-safety`, `a11y`.
**ADR-0046 D3** — Manual invocation only at v1. No CI triggers; the operator decides when a lens applies.
**ADR-0046 D7** — This ADR layers above ADR-0044, does not amend it. The twenty-category rubric stays the baseline; specialists deepen five of the twenty categories.
**ADR-0046 D8 / D10** — Per-agent definition files land as follow-up packets in priority order (`cfo` → `security` → `performance` → `ai-safety` → `a11y`), each in a phased go/no-go rollout.
**ADR-0044** — Establishes the generalist `review` agent and its twenty-category rubric; the baseline this ADR layers on. Not amended.
**ADR-0011 D5** — The review agent is advisory; findings do not gate merge. ADR-0046's new invariant preserves this posture for specialists.

## Constraints
- **Acceptance precedes flip.** ADR-0046 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **The reserved invariant number is 81.** Invariant 81 is pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift upward, never reuse a number. Do not write a specific number into the ADR text itself — the ADR delegates numbering; the number is recorded only in `constitution/invariants.md` and the PR body.
- **Do not amend ADR-0044.** ADR-0046 layers above it (D7). No edit to ADR-0044's text, status, or rubric in this packet.
- **Do not create agent files in this packet.** The five agent definitions are scoped to packets 03–07; the pattern doc and matrix registration are in packet 02. This packet is the governance flip only.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0046`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0046 to Accepted, record its one new invariant in `constitution/invariants.md`, and register the initiative in the trackers.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0046 so the specialist-agent build packets can reference its decisions as live rules.
- Feature: ADR-0046 Specialist Review Agents rollout, Phase 1.
- ADRs: ADR-0046 (primary), ADR-0044 (baseline, not amended), ADR-0011 (advisory posture preserved), ADR-0007 (agent-definition source of truth).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- Acceptance precedes flip — ADR-0046 stays Proposed until this PR merges.
- Assign the next free invariant number; do not reserve a number in ADR text.
- Do not amend ADR-0044; do not create agent files.

**Key Files:**
- `adrs/ADR-0046-specialist-review-agents.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
