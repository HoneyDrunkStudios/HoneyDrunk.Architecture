---
name: Architecture Decision
type: architecture-decision
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-1", "meta", "adr-0043", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0043"]
accepts: ["ADR-0043"]
wave: 1
initiative: adr-0043-continuous-backlog-generation
node: honeydrunk-architecture
---

# Author initiatives/audit-rotation.md with the 12-Node quarterly rotation order

## Summary
Author the new `initiatives/audit-rotation.md` file recording the rotation order for the ADR-0043 Tactical source — the 12 live Nodes covered one-per-week over a quarter, then the cycle repeats — with the rule for how Seed Nodes enter the rotation as they scaffold.

## Context
ADR-0043 D4 Tactical specifies a rotating Node-of-the-week audit: `node-audit` runs against one Node per week, 12 live Nodes covered per quarter, then the cycle repeats. The rotation order is recorded in `initiatives/audit-rotation.md` — a new file. ADR-0043's Follow-up Work lists "Author `initiatives/audit-rotation.md` with the initial 12-Node rotation order." Without this file, the Tactical source has no schedule and Phase 2 cannot begin.

This is a docs-only packet. No code, no workflow, no .NET project.

## Scope
- `initiatives/audit-rotation.md` (new) — the rotation order and the rotation rules.

## Proposed Implementation
Author `initiatives/audit-rotation.md` containing:

**The rotation list.** An ordered list of the 12 live Nodes, week 1 through week 12. The execution agent must read `catalogs/nodes.json` to enumerate the current 12 live Nodes (Nodes whose status is live, not Seed) and order them. A defensible default order is the canonical Core Node order first (Kernel → Transport → Vault → Auth → Web.Rest → Data) followed by the remaining live Nodes (Pulse, Notify, Communications, and the rest) — but the execution agent must reconcile against `catalogs/nodes.json` ground truth and record any deviation. If `nodes.json` shows a count other than 12 live Nodes at execution time, list exactly the live Nodes present and note the actual count in the file and the PR body.

**Per-Node row contents.** For each rotation slot: week number, Node name, repo, and a "last audited" date column (initially blank — `hive-sync` or the briefing fills it as audits run).

**Rotation rules**, stated verbatim from ADR-0043 D4 Tactical:
- One Node per week; 12 live Nodes → one quarterly cycle; then the cycle repeats.
- Seed Nodes enter the rotation as they scaffold (i.e. when a Seed Node becomes live, it is appended to the rotation and the cycle lengthens).
- Each audit's output is committed to `generated/audits/{node}-{YYYY-MM-DD}.md` regardless of whether any packets graduate.
- `node-audit` output is always triaged to `proposed/`; the human picks which findings become `active/`.

**Phase note.** Record that per ADR-0043 D9, the Tactical rotation begins in Phase 2 (Week 3), weekly thereafter. The first audit Node is rotation slot 1.

**Cross-reference** ADR-0043 D4 Tactical and D9.

## Affected Files
- `initiatives/audit-rotation.md` (new)

## NuGet Dependencies
None. This packet creates a Markdown tracking file; no .NET project is created or modified.

## Boundary Check
- [x] `initiatives/` is the Architecture repo's tracking surface. Correct repo per routing.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `initiatives/audit-rotation.md` exists with an ordered 12-slot rotation (or the actual live-Node count, reconciled against `catalogs/nodes.json`)
- [ ] Each rotation row carries week number, Node name, repo, and a "last audited" date column
- [ ] The file states the one-per-week / quarterly-cycle / cycle-repeats rule verbatim
- [ ] The file states the Seed-Node-enters-on-scaffold rule
- [ ] The file states that audit output is committed to `generated/audits/{node}-{YYYY-MM-DD}.md` and always triaged to `proposed/`
- [ ] The file records that the rotation begins Phase 2 / Week 3 per ADR-0043 D9
- [ ] The PR body notes the actual live-Node count if it differs from 12

## Human Prerequisites
- [ ] Confirm the rotation order — the agent proposes a defensible order from `catalogs/nodes.json`, but the operator may want a specific Node first (e.g. the Node most overdue for an audit). Adjust before merge if desired.

## Dependencies
- `work-item:01` — ADR-0043 must be Accepted so the file is authored against a live decision.

## Referenced ADR Decisions

**ADR-0043 D4 Tactical** — Rotating Node-of-the-week; 12 live Nodes covered per quarter, then repeat; Seed Nodes enter as they scaffold. `node-audit` output always triaged to `proposed/`; the audit report is committed to `generated/audits/{node}-{YYYY-MM-DD}.md` even if no packets graduate.
**ADR-0043 D9** — Staged rollout: the Tactical rotation begins in Phase 2 (Week 3), weekly cadence thereafter; the weekly briefing also begins Week 3.

## Constraints
- Reconcile the Node list against `catalogs/nodes.json` ground truth — do not hardcode a count of 12 if the catalog disagrees.
- The "last audited" column ships blank; it is filled as audits run, not pre-populated.

## Labels
`docs`, `tier-1`, `meta`, `adr-0043`, `wave-1`

## Agent Handoff

**Objective:** Author `initiatives/audit-rotation.md` with the 12-Node quarterly rotation and the rotation rules.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the ADR-0043 Tactical source a documented schedule so Phase 2 can begin.
- Feature: ADR-0043 Continuous Backlog Generation rollout, Phase 1 (file authored now; rotation runs in Phase 2).
- ADRs: ADR-0043 (D4 Tactical, D9).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0043 Accepted.

**Constraints:**
- Reconcile the Node list against `catalogs/nodes.json`.
- "Last audited" column ships blank.

**Key Files:**
- `initiatives/audit-rotation.md` (new)
- `catalogs/nodes.json` (read-only, to enumerate live Nodes)

**Contracts:** None.
