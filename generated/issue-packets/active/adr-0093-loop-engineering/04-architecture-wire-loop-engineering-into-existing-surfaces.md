---
title: Wire loop engineering into existing surfaces
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
initiative: adr-0093-loop-engineering
wave: 2
tier: 2
adrs: ["ADR-0093"]
accepts: ["ADR-0093"]
source: human
generator: human
labels: ["documentation", "meta", "tier-2"]
dependencies: ["01-architecture-loop-engineering-doctrine"]
---

# ADR-0093 P04 — Wire loop engineering into existing surfaces

## Summary

Connect the new loop-engineering substrate to the Grid's existing governance surfaces so it is discoverable and the gated future phases are tracked: a loop→runner-job convention for the ADR-0086 runner, a Loop Console future-phase row in the HoneyHub program, and a capability-matrix note for loop-owning agents.

## Context

ADR-0093 D7 runs loops on the ADR-0086 runner; D9 homes the operator surface in HoneyHub (gated on v1). The substrate (P01–P03) is inert unless the surrounding surfaces point at it. This packet does the wiring — all small, additive edits to existing Architecture files. It does **not** build the Loop Console or any runner code; it documents the convention and registers the future phase.

## Scope

1. **Runner loop-job convention.** In the ADR-0086 runner job-spec documentation (under `infrastructure/` or wherever the runner job specs are documented), add a short convention section: how an LDR maps to a runner job (the LDR `id` names the job; `trigger`/`budget`/`kill_switch` map to the job's schedule/caps; `WriteMode = "pr"` is the default per ADR-0093 D4). Cross-reference, don't duplicate, the LDR fields.
2. **HoneyHub program phase.** In `initiatives/programs/honeyhub.md`, add the **Loop Console** as a future phase / dependency-map row, marked `gated` on HoneyHub v1 (ADR-0091/0092), citing ADR-0093 D9. Keep it consistent with the existing program table shape and `[Firm]` boundary language (artifacts-as-write-boundary; BYOK-only cloud; honest capability flags).
3. **Capability matrix note.** In `constitution/agent-capability-matrix.md`, add a note (or column annotation) identifying which agents own/participate-in loops (`hive-sync`, `scope`, `node-audit`, `product-strategist`), pointing at the relevant LDRs in `loops/`.
4. **Optional discovery links.** Add `loops/` and `constitution/loop-engineering.md` to any constitution/README discovery index and to CLAUDE.md's context-load guidance if appropriate.

## Acceptance Criteria

- [ ] The runner job-spec docs contain a loop→job convention section cross-linking the LDR field set (no duplication of the LDR schema).
- [ ] `initiatives/programs/honeyhub.md` has a Loop Console row/phase marked `gated`, citing ADR-0093 D9 and the HoneyHub v1 prerequisites, consistent with the program's existing table shape.
- [ ] `constitution/agent-capability-matrix.md` identifies loop-owning agents and links `loops/`.
- [ ] No behavioral change to the runner, any agent, or HoneyHub — documentation/registration only.
- [ ] Edits are additive and do not contradict ADR-0086, ADR-0090, ADR-0091, or ADR-0092.

## Human Prerequisites

None.

## Dependencies

- P01 (doctrine) must merge first (the surfaces link to it).

## Agent Handoff

**Objective:** Make loop engineering discoverable from existing surfaces and register the gated Loop Console phase.
**Target:** HoneyDrunk.Architecture, branch from `main`.
**Context:** ADR-0093 D7 (runner substrate), D9 (HoneyHub Loop Console, gated on v1). The HoneyHub program tracker (`initiatives/programs/honeyhub.md`) is the live cross-ADR map per ADR-0089 — match its existing row shape and status legend (`needed → drafting → accepted → implemented`, or `gated`).
**Constraints:**
- Additive edits only; do not restructure the HoneyHub program table or the capability matrix.
- The Loop Console is `gated` — do not imply it is being built now.
- Respect ADR-0090's `[Firm]` boundaries when describing the Console (artifacts-as-write-boundary; cloud BYOK-only, never subscription token; honest capability flags; state-only notifications).
- Conventional commits (`docs:`), present tense, ≤ 50-char first line.
**Key Files:**
- `initiatives/programs/honeyhub.md`, `constitution/agent-capability-matrix.md` (edit)
- the ADR-0086 runner job-spec docs under `infrastructure/` (edit)
- `adrs/ADR-0093-*.md`, `adrs/ADR-0086-*.md`, `adrs/ADR-0090-*.md` (read)
