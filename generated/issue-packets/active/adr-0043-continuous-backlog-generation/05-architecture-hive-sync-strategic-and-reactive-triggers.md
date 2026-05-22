---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0043", "wave-2"]
dependencies: ["packet:02", "packet:03"]
adrs: ["ADR-0043", "ADR-0014", "ADR-0009"]
accepts: ["ADR-0043"]
wave: 2
initiative: adr-0043-continuous-backlog-generation
node: honeydrunk-architecture
---

# Amend the hive-sync agent with the Strategic acceptance trigger and the Reactive drift-to-packet conversion

## Summary
Amend the `hive-sync` agent definition with two new responsibilities ADR-0043 D4/D8 assign it: (1) the Strategic-source trigger — when `hive-sync` flips an ADR/PDR to Accepted, it records that a `scope` pass is owed for that decision; (2) the Reactive-source drift-to-packet conversion — drift items at severity ≥ medium become packets in `generated/issue-packets/proposed/`, with deduplication against existing `proposed/`/`active/` packets.

## Context
ADR-0043 D8 states: "ADR-0014 (hive-sync) already runs on a schedule. It gains two new responsibilities: detecting ADR/PDR acceptance to trigger Strategic scope (D4); generating Reactive packets from drift/incidents/scans (D4)." Both are amendments to the existing `hive-sync` run loop, permitted under ADR-0014's mandate without an agent re-design. `hive-sync` already does Step 9 (ADR/PDR acceptance reconciliation, including auto-flips) and Step 12 (drift detection → `initiatives/drift-report.md`) — this packet wires the output of those steps into the ADR-0043 backlog pipeline.

ADR-0043's Follow-up Work lists "Amend `hive-sync` for the ADR-acceptance trigger and drift-to-packet conversion (per D8)."

This is an agent-definition (Markdown) packet. No code, no workflow, no .NET project. The `.claude/agents/` directory is the agent source of truth per ADR-0007.

## Scope
- `.claude/agents/hive-sync.md` — add the Strategic-trigger responsibility and the Reactive drift-to-packet responsibility.

## Proposed Implementation

### Strategic-source trigger (ADR-0043 D4 Strategic)
`hive-sync` Step 9 already auto-flips eligible Proposed ADRs/PDRs to Accepted (capped at `MAX_FLIPS_PER_RUN=3`). Amend the agent definition so that for every ADR/PDR `hive-sync` flips to Accepted in a run — and for any ADR/PDR flipped to Accepted by a human since the last run, detected by comparing current status against the prior-run frontmatter — `hive-sync` records a **Strategic scope owed** entry. Implementation guidance for the agent definition:
- Surface the owed `scope` pass in the PR summary comment and in `initiatives/proposed-adrs.md` (the "Flipped This Run" section is the natural place) as an explicit "→ Strategic source: `scope` pass owed for ADR-XXXX" line.
- State that `hive-sync` does **not** itself run `scope` — it detects and records the trigger; the actual `scope` invocation is a separate agent run (manual on the documented cadence until ADR-0043 D7's execution-surface ADR lands).
- Add the secondary 14-day age-out: a Proposed ADR/PDR whose `**Date:**` is more than 14 days old is surfaced in `proposed-adrs.md` as "stale — accept or kill," distinct from the acceptance trigger (this surfaces stale decisions, it does not scope unaccepted work).

### Reactive-source drift-to-packet conversion (ADR-0043 D4 Reactive)
`hive-sync` Step 12 already produces `initiatives/drift-report.md`. Amend the agent definition so that drift findings at **severity ≥ medium** additionally become packets written to `generated/issue-packets/proposed/`. Implementation guidance:
- Each generated packet uses the `{YYYY-MM-DD}-{repo}-{description}.md` naming and carries the mandatory `source: reactive` and `generator: hive-sync` frontmatter (per packet 03's amended `issue-authoring-rules.md`).
- **Deduplication is mandatory** — before creating a packet, `hive-sync` checks `generated/issue-packets/proposed/` and `generated/issue-packets/active/` for an existing packet covering the same finding. ADR-0043 D4 calls deduplication "the single most important quality control" for reactive sources. State the dedupe key explicitly: the (drift category, item identity) pair, the same identity `hive-sync` already uses for First Surfaced date stickiness.
- Low-severity drift remains in `initiatives/drift-report.md` only — no packet.
- Note for future expansion (ADR-0043 D9 Phase 3): the same mechanism extends to security-CVE findings (ADR-0009 nightly scan, high+ CVE → `priority: urgent` packet) and `generated/incidents/` entries. This packet wires **drift only** — the lowest-cost reactive sub-source, "already 80% built into hive-sync" per ADR-0043 D9 Phase 1. The CVE and incident sub-sources are explicitly out of scope here and are a Phase-3 follow-up.

### Constraint to preserve
`hive-sync` writing packets to `proposed/` is new authority. State clearly that this authority is bounded to `proposed/` — `hive-sync` never writes to `active/`, never self-promotes, and never files GitHub issues (the human triages `proposed/` → `active/`; `file-issues` files). This is consistent with `hive-sync`'s existing constraint "Never create GitHub issues — that's `scope` and `file-issues`."

## Affected Files
- `.claude/agents/hive-sync.md`

## NuGet Dependencies
None. This packet edits a Markdown agent-definition file; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.
- [x] New authority (`hive-sync` writes to `proposed/`) is explicitly bounded; no `active/` write, no issue creation.

## Acceptance Criteria
- [ ] `hive-sync.md` documents the Strategic trigger: every ADR/PDR flipped to Accepted records a "`scope` pass owed" entry surfaced in the PR summary and `proposed-adrs.md`
- [ ] `hive-sync.md` states `hive-sync` detects/records the Strategic trigger but does not itself run `scope`
- [ ] `hive-sync.md` documents the 14-day age-out for stale Proposed decisions as a distinct "accept or kill" surface
- [ ] `hive-sync.md` documents the Reactive drift-to-packet conversion: drift at severity ≥ medium becomes a `source: reactive`, `generator: hive-sync` packet in `proposed/`
- [ ] The dedupe rule is documented with the explicit (drift category, item identity) key, citing ADR-0043 D4's "single most important quality control"
- [ ] Low-severity drift is documented as report-only, no packet
- [ ] The CVE and incident reactive sub-sources are documented as Phase-3 out-of-scope follow-ups
- [ ] The new `proposed/`-write authority is documented as bounded — no `active/` write, no self-promotion, no GitHub issue creation
- [ ] The amendment cross-references ADR-0043 D4/D8, ADR-0014, and ADR-0009

## Human Prerequisites
None. Pure Architecture-repo agent-definition edit.

## Dependencies
- `packet:02` — the `generated/issue-packets/proposed/` directory must exist before `hive-sync` is told to write packets into it.
- `packet:03` — the `source`/`generator` frontmatter contract must be documented in `issue-authoring-rules.md` before `hive-sync` is told to emit those fields.

## Referenced ADR Decisions

**ADR-0043 D4 Strategic** — Trigger: `hive-sync` detects an ADR/PDR status change to Accepted; `scope` runs once per acceptance. 14-day age-out on Proposed decisions is a secondary "accept or kill" trigger.
**ADR-0043 D4 Reactive** — Drift items at severity ≥ medium become packets in `proposed/`; low-severity drift stays in the report. Deduplication is "the single most important quality control."
**ADR-0043 D8** — `hive-sync` gains the acceptance trigger and the drift-to-packet conversion; both are amendments to its existing run loop permitted under ADR-0014.
**ADR-0043 D9 Phase 1/Phase 3** — Reactive-for-drift is Phase 1 ("already 80% built into hive-sync"); CVE and incident sub-sources expand in Phase 3.
**ADR-0014** — `hive-sync`'s reconciliation mandate and existing Step 9 (acceptance) / Step 12 (drift) responsibilities.
**ADR-0009** — Nightly security scan; high+ CVE feeds the Reactive source in the Phase-3 expansion.

## Constraints
- **Amend, do not re-architect.** `hive-sync`'s Steps 9 and 12 already produce the inputs; this packet wires their outputs into the backlog pipeline. Do not restructure the run loop.
- **`proposed/` only.** `hive-sync`'s new write authority stops at `proposed/`. No `active/` write, no self-promotion, no GitHub issue creation.
- **Drift only in this packet.** CVE and incident reactive sub-sources are a Phase-3 follow-up, explicitly out of scope.

## Labels
`docs`, `tier-2`, `meta`, `adr-0043`, `wave-2`

## Agent Handoff

**Objective:** Amend `hive-sync` with the Strategic acceptance trigger and the Reactive drift-to-packet conversion.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Wire the outputs of `hive-sync`'s existing acceptance-reconciliation and drift-detection steps into the ADR-0043 backlog pipeline.
- Feature: ADR-0043 Continuous Backlog Generation rollout, Phase 1 (Strategic + Reactive-for-drift).
- ADRs: ADR-0043 (D4/D8/D9), ADR-0014 (hive-sync mandate), ADR-0009 (CVE source, Phase-3).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — `proposed/` directory exists.
- `packet:03` — `source`/`generator` frontmatter contract documented.

**Constraints:**
- Amend, do not re-architect; `proposed/` only; drift only (no CVE/incident in this packet).

**Key Files:**
- `.claude/agents/hive-sync.md`

**Contracts:** None changed.
