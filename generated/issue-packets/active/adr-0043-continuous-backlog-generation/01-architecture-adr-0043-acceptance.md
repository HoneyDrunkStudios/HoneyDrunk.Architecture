---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0043", "wave-1"]
dependencies: []
adrs: ["ADR-0043", "ADR-0008", "ADR-0014"]
accepts: ["ADR-0043"]
wave: 1
initiative: adr-0043-continuous-backlog-generation
node: honeydrunk-architecture
---

# Accept ADR-0043 — flip status, finalize the two new invariants, register the backlog-generation initiative

## Summary
Flip ADR-0043 (Continuous Backlog Generation Strategy) from Proposed to Accepted: update the ADR header, update the ADR index, record the two new backlog-generation invariants in `constitution/invariants.md`, and register the `adr-0043-continuous-backlog-generation` initiative in the tracking files.

## Context
ADR-0043 is `initiatives/current-focus.md` priority #5 ("Land ADR-0043 — Backlog Generation"). It commits the Grid to four named backlog-source streams (Strategic, Tactical, Opportunistic, Reactive) plus a weekly triage briefing, a three-state packet lifecycle (`proposed/` → `active/` → `completed/`), and a packet-handoff contract. Every other packet in this initiative references ADR-0043's decisions as live rules, so the flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project. It is `Actor=Agent`. The two new invariants take the **pre-reserved numbers 78 and 79** (see Proposed Implementation) — they are not scanned for at landing time.

## Scope
- `adrs/ADR-0043-continuous-backlog-generation-strategy.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- The ADR index (`adrs/README.md` or equivalent index file) — update the ADR-0043 row to Accepted.
- `constitution/invariants.md` — append the two new invariants ADR-0043 introduces (see below).
- `initiatives/active-initiatives.md` — register the `adr-0043-continuous-backlog-generation` initiative with a packet checklist.
- `initiatives/proposed-adrs.md` — ADR-0043 moves from "Awaiting" to "In Progress" once packets are filed; the `hive-sync` agent maintains this surface, so this packet only needs to ensure the initiative is registered in `active-initiatives.md`.

**`current-focus.md` priority bookkeeping.** ADR-0043 is `current-focus.md` priority #5. This acceptance packet flipping ADR-0043 to Accepted satisfies the "ADR-0043 Accepted" half of priority #5's exit signal; the "`generated/issue-packets/proposed/` directory + Strategic source live" half is satisfied by packets 02 (directory) and 05 (the `hive-sync` Strategic trigger) plus packet 08 (first Strategic run). When the initiative reaches completion (all 8 packets `Done`), priority #5 should be marked complete and dropped from the ranked list at the next ADR-0043 weekly briefing. This packet does not edit `current-focus.md` priority status itself (the briefing owns that surface); it is noted here and in the dispatch plan so the bookkeeping is not lost.

## Proposed Implementation

### The two new invariants
ADR-0043's Consequences/Invariants section adds exactly two. They are assigned the **hard-reserved numbers 78 and 79**.

**Invariant numbers are pre-reserved — use 78 and 79, do not scan.** `constitution/invariants.md` is topic-grouped and NOT contiguously numbered; its true highest invariant number is **51** (verified). ADR-0043 sits in a 12-ADR batch and its invariant block is **pre-reserved as numbers 78 and 79** to avoid a collision with sibling ADRs (notably ADR-0044) racing for 52/53. The execution agent must assign **invariant 78** and **invariant 79** literally — do not scan for "next free" and do not reuse 52/53.

> **Invariant numbers 78-79 are pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.**

Invariant text to add (verbatim intent from ADR-0043 Consequences) — the wording itself is **forward-only / non-retroactive**; existing already-filed packets are not rewritten:

> **78. Every agent-generated packet authored after ADR-0043 acceptance lands in `generated/issue-packets/proposed/`, never directly in `active/`.** Agents do not self-promote work; a human is the only authority for the `proposed/` → `active/` transition. The `active/` directory holds only packets a human has explicitly elected to file. This invariant is forward-only: packets authored before ADR-0043 acceptance are not retroactively moved or rewritten. See ADR-0043 D3.

> **79. Every issue packet authored after ADR-0043 acceptance carries `source` and `generator` frontmatter fields.** `source` is one of `strategic` | `tactical` | `opportunistic` | `reactive` and names which backlog stream produced the packet. `generator` names the agent that authored it (or `human` for human-authored packets). Auditability of agent-generated work is non-negotiable. This invariant is forward-only: the ~25 sibling initiative folders already filed without these fields are valid as-authored and are not retroactively rewritten — invariant 24 (filed packets are immutable) governs them. See ADR-0043 D2.

A new "Backlog Generation Invariants" topic group is the natural home, or append to an existing Work Tracking group — the execution agent chooses placement consistent with the file's topic-grouped structure and records the choice in the PR body.

## Affected Files
- `adrs/ADR-0043-continuous-backlog-generation-strategy.md`
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
- [ ] ADR-0043 header reads `**Status:** Accepted`
- [ ] ADR index row for ADR-0043 reflects Accepted
- [ ] `constitution/invariants.md` carries the two new invariants as numbers **78 and 79**, with no "(Proposed)" qualifier, and each invariant's text carries the forward-only / non-retroactive carve-out verbatim
- [ ] `initiatives/active-initiatives.md` registers the `adr-0043-continuous-backlog-generation` initiative with a packet checklist (8 packets)
- [ ] The PR body confirms invariants 78/79 were used and notes the `hive-sync` reconciliation expectation
- [ ] No directory creation, agent edit, or `issue-authoring-rules.md` change in this packet (those land in packets 02, 03, 05, 06, 07)

## Human Prerequisites
- [ ] Confirm before merge that no invariant above 51 has landed from **outside** the 12-ADR batch (which would force this block to shift upward from 78/79). If only batch ADRs have landed, 78/79 stand as reserved. Never reuse a number.

## Dependencies
None. This is the first packet in the initiative.

## Referenced ADR Decisions

**ADR-0043 D1** — Four backlog-source streams (Strategic, Tactical, Opportunistic, Reactive) plus one weekly-briefing triage surface owned by `netrunner`.
**ADR-0043 D2** — The issue packet is the canonical output of every source; new `source` and `generator` frontmatter fields are mandatory.
**ADR-0043 D3** — Three-state packet lifecycle: `proposed/` (agent-generated, awaiting triage) → `active/` (human-promoted, filed) → `completed/`. The `proposed/` → `active/` transition is the only human-decision gate.
**ADR-0043 D8** — No code-Node changes; entirely a Meta-sector decision. `hive-sync` gains two new responsibilities (Strategic acceptance trigger, Reactive drift-to-packet conversion), permitted under ADR-0014's existing mandate.
**ADR-0008** — Defines the packet → issue → board → PR pipeline this ADR fills the upstream slot of.

## Constraints
- **Acceptance precedes flip.** ADR-0043 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Use the pre-reserved invariant numbers 78 and 79.** They are part of a 12-ADR batch reservation. Do not scan for "next free" and do not take 52/53 — that range is being raced for by sibling ADRs. If any invariant above 51 lands from outside this batch before merge, shift this block upward; never reuse a number.
- **The two new invariants are forward-only.** Their text must explicitly carve out existing already-filed packets — the ~25 sibling initiative folders authored before ADR-0043 are not retroactively rewritten (invariant 24 governs them). The carve-out lives in the invariant wording itself, not only here.
- **Do not create directories or amend agents in this packet.** Those are scoped to packets 02–07; this packet is the governance flip only.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0043`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0043 to Accepted, record its two new invariants in `constitution/invariants.md`, and register the initiative in the trackers.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0043 so the backlog-generation build packets can reference its decisions as live rules.
- Feature: ADR-0043 Continuous Backlog Generation rollout, Phase 1.
- ADRs: ADR-0043 (primary), ADR-0008 (packet/initiative conventions), ADR-0014 (hive-sync mandate).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- Acceptance precedes flip — ADR-0043 stays Proposed until this PR merges.
- Use the pre-reserved invariant numbers 78 and 79; do not scan for next-free, do not take 52/53.
- Both new invariants must carry the forward-only / non-retroactive carve-out in their own text.
- No directory creation or agent edits in this packet.

**Key Files:**
- `adrs/ADR-0043-continuous-backlog-generation-strategy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
