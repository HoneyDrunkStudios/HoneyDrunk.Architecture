---
title: Author the loop-engineering doctrine
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
initiative: adr-0093-loop-engineering
wave: 1
tier: 2
adrs: ["ADR-0093"]
accepts: ["ADR-0093"]
source: human
generator: human
labels: ["documentation", "meta", "tier-2"]
---

# ADR-0093 P01 — Author the loop-engineering doctrine

## Summary

Author `constitution/loop-engineering.md`, the canonical doctrine for loop engineering on the Grid: the discipline of designing the loops that prompt agents rather than prompting agents by hand. This is the load-bearing prose artifact ADR-0093 introduces; the `loops/` catalog (P02) and backfilled LDRs (P03) reference it.

## Context

ADR-0093 names a discipline the Grid already practiced unnamed (ADR-0043 backlog loops, ADR-0014 `hive-sync`, the PR-activity autofix loop). The doctrine doc is where the *why* and the *rules* live, so future LDR authors and the `scope`/`refine`/`adr-composer` agents share one definition. The executing agent is in the Architecture repo and can read ADR-0093 directly — treat the ADR as the source of truth and the doctrine as its readable, operator-facing expansion.

## Scope

Create `constitution/loop-engineering.md` covering, at minimum:

1. **The frame** — prompting → loop design; the operator as control engineer (charter §"The AI multiplier" tie-in). A loop is a feedback control system.
2. **Open-loop vs closed-loop** — every registered loop must close (a `gate` and a `feedback_sink` are required, ADR-0093 D2). Cron-without-a-gate is not a loop and stays on GitHub Actions cron (ADR-0068).
3. **The seven-part anatomy** + the governance envelope (the full LDR field set, ADR-0093 D1).
4. **The Success Definition** — the four parts (done-when / still-true / out-of-bounds / escalate-when), executable not prose, authored separately from the worker, rigor scales with autonomy (ADR-0093 D3). This is the centerpiece — give it the most space.
5. **The autonomy ladder** — A human-gated → B eval-gated → C self-tuning, bounded by blast radius (ADR-0087), `WriteMode=pr` / artifacts-as-write-boundary floor (ADR-0090 D9). (ADR-0093 D4)
6. **The autonomous Build Loop** — three exits (done / stuck / over-budget), gates outside the worker's write scope, test-maturity coupling. (ADR-0093 D5)
7. **The loop-authorship gate** — agents propose, humans promote (ADR-0093 D6); the load-bearing fleet-safety rule.
8. **Fleet posture** — forward-compatible-now vs gated-later; named-not-built orchestrator (ADR-0093 D8).
9. **Cost/token economics** — first-class signal: per-run accounting at declared fidelity (never an estimate rendered as exact, ADR-0092), attribution, cost-as-success-criterion / loop ROI, right-sizing + caching, anomaly detection, cost-triggered stop-the-world. (ADR-0093 D11)
10. **Loop observability** — heartbeat metrics, loop-health vs output-health, attention-as-scarce-resource, escalation quality, re-validation cadence. (ADR-0093 D10)

## Acceptance Criteria

- [ ] `constitution/loop-engineering.md` exists and covers all ten sections above.
- [ ] The Success Definition section presents the four parts as a table/list and states the two binding rules (separately-authored; rigor-scales-with-autonomy).
- [ ] Every claim that restates an ADR-0093 decision cross-links the relevant `Dn`.
- [ ] No new invariant is asserted (ADR-0089 precedent); the doctrine names the promotion path for autonomy invariants instead.
- [ ] Prose follows the charter voice (workshop, not startup); no kill-clock / MRR framing.
- [ ] Linked from `constitution/` discovery surfaces where the constitution lists its docs (if such an index exists), and from CLAUDE.md's "Before Any Work" context-load list if appropriate.

## Human Prerequisites

None.

## Dependencies

None (Wave 1).

## Agent Handoff

**Objective:** Author the canonical loop-engineering doctrine doc.
**Target:** HoneyDrunk.Architecture, branch from `main`.
**Context:** Governing decision is ADR-0093 (same repo — read it directly). This is a Meta-sector documentation artifact; no code.
**Constraints:**
- This repo is the organizational brain — Markdown + structured artifacts only, no application code.
- The charter (`constitution/charter.md`) is the tiebreaker doc; when framing tone, defer to it. Never drift into startup-pitch language.
- Do not assert new invariants; ADR-0093 deliberately adds none at v1.
- Conventional commits (`docs:`), present tense, ≤ 50-char first line.
**Key Files:**
- `constitution/loop-engineering.md` (new)
- `adrs/ADR-0093-loop-engineering-closed-loop-agent-orchestration.md` (read)
- `constitution/charter.md`, `constitution/manifesto.md` (voice reference)
