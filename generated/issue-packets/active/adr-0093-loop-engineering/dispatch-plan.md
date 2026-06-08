# Dispatch Plan — ADR-0093 Loop Engineering (Substrate / Tier A)

**Initiative:** `adr-0093-loop-engineering`
**Governing ADR:** [ADR-0093](../../../../adrs/ADR-0093-loop-engineering-closed-loop-agent-orchestration.md) — Loop Engineering — Closed-Loop Agent Orchestration (Proposed)
**Scope:** Implements **only the buildable-now substrate (Tier A)** per ADR-0093 § Prerequisites and Sequencing. Higher autonomy tiers (B eval-gated, C self-tuning), concurrent/write loops, the fleet orchestrator, and the HoneyHub Loop Console are **gated** behind their named prerequisites and are explicitly **out of scope** for this initiative.
**Target repo:** HoneyDrunkStudios/HoneyDrunk.Architecture (single-repo initiative)
**Site sync:** No.

## Trigger

Operator-directed acceptance of ADR-0093. This initiative lands the loop-engineering substrate so the discipline is real and the LDR shape is proven against existing loops; it does not stand up any new autonomy.

## What is in scope

The substrate that ADR-0093 D1/D2/D3/D6/D7 makes buildable today, all in the Architecture repo:

- the doctrine doc (`constitution/loop-engineering.md`),
- the `loops/` + `loops/proposed/` directories and the LDR template,
- backfilled LDRs for the loops the Grid already runs,
- wiring loop engineering into existing surfaces (runner job-spec convention, HoneyHub program phase row, capability matrix note).

## What is explicitly NOT in scope (gated — see ADR-0093 § Prerequisites)

- Tier B eval-gated loops — blocked on ADR-0023 Evals Node scaffolding.
- Autonomous Build Loop `still-true` gate — blocked on ADR-0032 coverage gate.
- Autonomy routing — blocked on ADR-0087 enforce posture.
- Concurrent/write loops + fleet leasing — blocked on ADR-0042 / ADR-0051.
- HoneyHub Loop Console — blocked on HoneyHub v1 (ADR-0091/0092). This initiative only **registers** it as a future program phase.
- The fleet orchestrator — named, not built (no trigger yet).

## Wave Diagram

### Wave 1 (No Dependencies)
- [ ] 01: Architecture — author `constitution/loop-engineering.md` doctrine
- [ ] 02: Architecture — create `loops/` + `loops/proposed/` + LDR template

### Wave 2 (Depends on Wave 1)
- [ ] 03: Architecture — backfill LDRs for existing loops
  - Blocked by: Wave 1 — 02 (template)
- [ ] 04: Architecture — wire loop engineering into existing surfaces
  - Blocked by: Wave 1 — 01 (doctrine)

### Wave 3 (Depends on Wave 2)
- [ ] 05: Architecture — implementation notes (as-built reconciliation)
  - Blocked by: 01, 02, 03, 04

## Rollback Plan

All packets are additive documentation/scaffold in the Architecture repo, landed via PR (`WriteMode = pr`). Rollback is reverting the PR(s). No code-Node, catalog cascade, or runtime change; no invariant added (ADR-0089 precedent). ADR-0093 stays Proposed until the implementing packets close, at which point `hive-sync` auto-flips it (the packets carry `accepts: ["ADR-0093"]`).

## Issue Creation Batch

```bash
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "ADR-0093 P01: Author the loop-engineering doctrine" --body-file "generated/issue-packets/active/adr-0093-loop-engineering/01-architecture-loop-engineering-doctrine.md" --label "documentation,meta,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "ADR-0093 P02: Create loops/ directory and the LDR template" --body-file "generated/issue-packets/active/adr-0093-loop-engineering/02-architecture-loops-dir-and-ldr-template.md" --label "documentation,meta,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "ADR-0093 P03: Backfill LDRs for the Grid's existing loops" --body-file "generated/issue-packets/active/adr-0093-loop-engineering/03-architecture-backfill-existing-loop-ldrs.md" --label "documentation,meta,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "ADR-0093 P04: Wire loop engineering into existing surfaces" --body-file "generated/issue-packets/active/adr-0093-loop-engineering/04-architecture-wire-loop-engineering-into-existing-surfaces.md" --label "documentation,meta,tier-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "ADR-0093 P05: Implementation notes (as-built reconciliation)" --body-file "generated/issue-packets/active/adr-0093-loop-engineering/05-architecture-implementation-notes.md" --label "documentation,meta,tier-1"
```
