---
title: Backfill LDRs for the Grid's existing loops
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
initiative: adr-0093-loop-engineering
wave: 2
tier: 2
adrs: ["ADR-0093"]
accepts: ["ADR-0093"]
source: human
generator: human
labels: ["documentation", "meta", "tier-2"]
dependencies: ["02-architecture-loops-dir-and-ldr-template"]
---

# ADR-0093 P03 — Backfill LDRs for the Grid's existing loops

## Summary

Write Loop Definition Records for the loops the Grid already runs, using the P02 template. This pressure-tests the LDR shape against reality and instantly makes existing automation legible — the second loop authored against the template is what proves the template is right.

## Context

ADR-0093 § Context observes that loop design is tribal knowledge smeared across ADRs, runner job specs, and agent files. Backfilling LDRs for the real loops collapses that into one reviewable record per loop. These are all currently **Tier A** (human-gated or human-triaged) loops; record them as-is — this packet does not change any loop's behavior or autonomy.

## Scope

Author one LDR in `loops/` per existing loop (human-authored, so they land directly in `loops/`, not `loops/proposed/`):

1. **`hive-sync` reconciliation loop** (ADR-0014) — trigger: Mon/Thu schedule + manual; inputs: `filed-work-items.json`, GitHub/Hive issue state, ADR/PDR frontmatter, catalogs; synthesizer: the `hive-sync` agent; gate: PR review (human); feedback_sink: initiative tracking files, `board-items.md`, `proposed-adrs.md`, `drift-report.md`; stop: PR merged; autonomy_tier: A.
2. **ADR-0043 Strategic source** — trigger: ADR/PDR → Accepted or aged Proposed; synthesizer: `scope`; gate: human triage (`proposed/ → active/`); feedback_sink: `proposed/` packets + run report; autonomy_tier: A.
3. **ADR-0043 Tactical source** — rotating `node-audit`; gate: human triage; feedback_sink: `generated/audits/` + proposed packets; autonomy_tier: A.
4. **ADR-0043 Opportunistic source** — monthly `product-strategist` Scout; gate: human triage; feedback_sink: `generated/scout-reports/` + proposed packets/PDR drafts; autonomy_tier: A.
5. **ADR-0043 Reactive source** — drift/CVE/incident/canary; synthesizer: `hive-sync`/`scope`; gate: human triage (severity-gated delay); feedback_sink: `proposed/` packets + `briefings/urgent.md`; autonomy_tier: A.
6. **PR-activity autofix loop** — trigger: `github-webhook-activity` (CI fail / review comment); synthesizer: the subscribed session; gate: CI green + human review; feedback_sink: pushed fixes + status checklist; stop: PR merged/closed; autonomy_tier: A.

For each, fill the template honestly: where a field does not yet exist (e.g., a formal `budget` or `idempotency` key), record it as `none at v1` rather than inventing one — surfacing the gap is the value.

## Acceptance Criteria

- [ ] Six LDRs exist in `loops/`, one per loop above, each valid against the P02 template.
- [ ] Each LDR's Success Definition names the loop's *actual* current gate (mostly human triage / PR review) — no aspirational autonomy.
- [ ] Each LDR's Cost & Token Accounting section records current fidelity honestly (most will be `estimated`/`none` today; ADR-0092 honesty rule).
- [ ] Fields with no current mechanism are recorded as `none at v1`, not fabricated.
- [ ] No existing loop's behavior, schedule, or autonomy is changed by this packet (documentation only).
- [ ] Each LDR cross-links its governing ADR (0014 / 0043) and ADR-0093.

## Human Prerequisites

None.

## Dependencies

- P02 (the LDR template) must merge first.

## Agent Handoff

**Objective:** Backfill LDRs for the six existing Grid loops.
**Target:** HoneyDrunk.Architecture, branch from `main`.
**Context:** Use the P02 template. Source material: ADR-0014 (`hive-sync`), ADR-0043 (four sources + lifecycle), and the PR-activity subscription model described in the runner/operator docs. All are readable in this repo.
**Constraints:**
- Record reality, not aspiration — every backfilled loop is Tier A today.
- Do not change any agent definition, schedule, or behavior; this is pure documentation.
- `none at v1` is the correct value for a missing mechanism; do not invent budgets, idempotency keys, or eval gates that don't exist.
- Conventional commits (`docs:`), present tense, ≤ 50-char first line.
**Key Files:**
- `loops/LDR-TEMPLATE.md` (read), `loops/loop-*.md` (new, six files)
- `adrs/ADR-0014-*.md`, `adrs/ADR-0043-*.md`, `.claude/agents/hive-sync.md`, `.claude/agents/scope.md`, `.claude/agents/node-audit.md`, `.claude/agents/product-strategist.md` (read)
