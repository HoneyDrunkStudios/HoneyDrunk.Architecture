---
title: Create loops/ directory and the LDR template
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

# ADR-0093 P02 — Create the `loops/` directory and the LDR template

## Summary

Stand up the `loops/` first-class-artifact surface: the active `loops/` home, the `loops/proposed/` agent-authored landing zone, a `loops/README.md`, and `loops/LDR-TEMPLATE.md` — the Loop Definition Record template that makes a loop reviewable in one place. This is the structural analog of `adrs/`, `pdrs/`, and `business/decisions/`.

## Context

ADR-0093 D1 makes a loop a first-class artifact. D6 makes loop authorship gated: agents may write candidates into `loops/proposed/`; only a human promotes a candidate into `loops/`. The directory shape encodes that discipline structurally, exactly as ADR-0043's `proposed/ → active/` packet lifecycle does. P03 (backfill) and all future loops consume the template authored here.

## Scope

1. Create `loops/` and `loops/proposed/`.
2. Author `loops/README.md`: what an LDR is, the `proposed/ → loops/` (human-promoted) lifecycle (ADR-0093 D6), and a pointer to `constitution/loop-engineering.md` (P01) for the doctrine.
3. Author `loops/LDR-TEMPLATE.md` with YAML frontmatter for the full field set from ADR-0093 D1 and the body sections:
   - Frontmatter: `id` (loop-NNNN-{slug}), `trigger`, `inputs`, `synthesizer`, `gate`, `feedback_sink`, `stop`, `budget`, `kill_switch`, `owner`, `autonomy_tier` (A/B/C), `idempotency`, `status` (proposed/active/retired).
   - Body: **Success Definition** (the four parts — done-when / still-true / out-of-bounds / escalate-when — as executable checks, ADR-0093 D3); **Cost & Token Accounting** (declared fidelity per ADR-0092, per-run ceiling, cost-per-outcome target, ADR-0093 D11); **Heartbeat & Health** (metrics + re-validation cadence, ADR-0093 D10); **Escalation** (what/when/how, digest vs interrupt); **Composed Primitives** (which of ADR-0052/0051/0042/0030/0044/0079/0087/0023 this loop uses); **Change Log**.
4. Keep `loops/proposed/` non-empty-by-convention with a `.gitkeep` or a `README` note so the directory exists in git.

## Acceptance Criteria

- [ ] `loops/`, `loops/proposed/`, `loops/README.md`, and `loops/LDR-TEMPLATE.md` exist.
- [ ] The template's frontmatter contains every field in ADR-0093 D1's table.
- [ ] The template body includes the Success Definition four-part section with placeholder *executable* examples (commands + expected outcomes), not prose bullets.
- [ ] The template includes the Cost & Token Accounting section enforcing the ADR-0092 "never render an estimate as exact" honesty rule.
- [ ] `loops/README.md` states the `proposed/ → loops/` human-promotion rule and links the doctrine.
- [ ] `loops/proposed/` is tracked in git (placeholder file).

## Human Prerequisites

None.

## Dependencies

None (Wave 1). Logically pairs with P01 but does not block on it; cross-links resolve once both land.

## Agent Handoff

**Objective:** Create the `loops/` catalog surface and the LDR template.
**Target:** HoneyDrunk.Architecture, branch from `main`.
**Context:** ADR-0093 D1 (LDR fields), D3 (Success Definition), D6 (authorship gate / lifecycle), D10 (health), D11 (cost). Read the ADR directly.
**Constraints:**
- Markdown + structured frontmatter only; mirror the conventions used by `adrs/` and `pdrs/`.
- The `proposed/ → active` human-promotion gate is `[Firm]` (ADR-0093 D6) — the template and README must not imply an agent can self-promote a loop.
- Conventional commits (`feat:` for the new surface, or `docs:`), present tense, ≤ 50-char first line.
**Key Files:**
- `loops/README.md`, `loops/LDR-TEMPLATE.md`, `loops/proposed/.gitkeep` (new)
- `adrs/ADR-0093-loop-engineering-closed-loop-agent-orchestration.md` (read)
- `adrs/README.md`, `pdrs/README.md` (shape reference)
