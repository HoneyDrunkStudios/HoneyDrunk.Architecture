---
title: Tier-B loop-gate pilot — eval-gate the ADR-0043 Strategic backlog loop
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
tier: 3
labels: ["documentation", "meta", "ai", "tier-3", "loop-engineering"]
adrs: ["ADR-0093", "ADR-0023", "ADR-0043"]
dependencies:
  - "adr-0093-loop-engineering/02-architecture-loops-dir-and-ldr-template"
  - "adr-0093-loop-engineering/03-architecture-backfill-existing-loop-ldrs"
  - "adr-0023-evals-standup/04-evals-node-scaffold"
source: human
generator: human
wave: 1
initiative: standalone
---

# Tier-B loop-gate pilot — eval-gate the ADR-0043 Strategic backlog loop

## Summary

Build the Grid's **first Tier-B (eval-gated) loop** per ADR-0093 D4 by promoting the ADR-0043 **Strategic** backlog-generation loop from Tier A (the operator triages every generated packet) to Tier B (an Evals suite scores each generated packet; sub-threshold candidates are auto-rejected with their `EvalReport`; only passing candidates reach the operator's `proposed/` queue). This is the first concrete consumer of `HoneyDrunk.Evals` and the proof that an automated gate reduces per-item triage load **without removing the human promotion gate** — the actual mechanism behind running more product loops in parallel.

## Context

ADR-0093 D4 defines Tier B (eval-gated) as the rung that lets a loop run without the operator as the per-step bottleneck, and D5 requires the load-bearing gate checks to live **outside the worker's write scope** — which is why the gate is Evals (a Node the generating worker cannot edit), not a self-check. The ADR-0043 Strategic loop is the right first pilot because:

- its **output is semantic text** (work items) that a model-as-judge + schema scorer can evaluate — unlike the autonomous Build Loop (ADR-0093 D5), whose gate is tests/coverage (ADR-0032), not Evals; the first *Evals* gate belongs on semantic output;
- it **directly attacks the bottleneck** the charter's AI-multiplier bet cares about — operator triage of agent-generated work;
- it is **low blast radius** — candidates land in `proposed/`; the operator still performs the `proposed/ → active/` promotion (ADR-0043 D3), which this gate does **not** replace.

## Gate behavior (Tier B)

After the ADR-0086 `backlog-strategic-scope` job generates a candidate work-item:

1. Run an Evals **packet-quality suite** against the candidate.
   - **Deterministic scorer** (`IEvalScorer`, marked deterministic): does the packet carry every required section per `copilot/issue-authoring-rules.md` — frontmatter fields (`source`/`generator`/`adrs`/`accepts`/labels), acceptance criteria, `## Human Prerequisites`, the Agent Handoff block, inlined invariant text?
   - **Model-as-judge scorer** (`IEvalScorer` composing `IChatClient` per ADR-0023 D5, marked non-deterministic): are the acceptance criteria specific and testable, is the scope one logical change, are referenced invariants inlined rather than cited by number?
2. **Threshold:** candidates scoring ≥ threshold land in `proposed/` for human triage; sub-threshold candidates are written to a `generated/work-items/rejects/` log **with their `EvalReport`** — culled work is auditable, never silently dropped.
3. The operator's `proposed/ → active/` promotion gate (ADR-0043 D3) is **unchanged**. This gate is a *pre-filter* that raises the quality of what reaches the operator, not a replacement for human promotion.
4. Record the `EvalReport` per run with full provenance and cost (ADR-0093 D11; ADR-0023 D12). Packet content is non-sensitive, so eval signals may carry the candidate text for diagnosis (ADR-0023 D10 carve-out; the suite does **not** declare itself sensitive).
5. Update the ADR-0043 Strategic loop's **LDR** (backfilled in ADR-0093 P03) to `autonomy_tier: B`, naming the gate, the threshold, and the `rejects/` `EvalReport` sink.

## OPEN DECISION (BLOCKING) — gate-implementation substrate

This pilot forces one architectural choice that must be resolved **before execution** — do not pick it silently:

- **Option A — Full Evals C# suite.** Implement the packet-quality suite as an `IEvalSuite` + `IEvalScorer` set in a host project, run by the ADR-0086 runner as a build step. This is the proper Grid shape (ADR-0023 D1: consumers own suites) and hard-depends on `HoneyDrunk.Evals` being scaffolded (ADR-0023 P04). **Sub-question:** Architecture is doc-only — the suite **code cannot live here**; a host repo must be chosen (the ADR-0086 runner's home, or a new small grid-suites project).
- **Option B — Runner-orchestrated model-as-judge (lighter v1).** The runner invokes a judge prompt via the CLI it already drives; it scores the candidate against the rubric and emits an `EvalReport`-shaped JSON record, using the Evals contracts as the conceptual model but **without** a C# Node dependency yet. Faster to ship and defers the suite-code-home question, but diverges from the ADR-0023 "the gate goes through Evals" shape and risks a parallel judge path the Grid later has to reconcile.

This is an **adr-composer-level decision** (it determines whether the first loop gate hard-depends on the Evals scaffold or ships ahead of it, and where suite code lives). Delegate it to `adr-composer` / confirm with the operator before building. The recommendation on file: **Option A** if Evals P04 is close (keeps one gate shape); **Option B** only if the operator wants a loop-gate proof before the Evals scaffold lands.

## Scope (once the decision is made)

Per the chosen option: author the packet-quality suite (or judge prompt), wire it into the `backlog-strategic-scope` runner job as the post-generation gate, add the `generated/work-items/rejects/` sink, and update the loop's LDR to Tier B. Keep the change additive — the loop still produces `proposed/` candidates; the gate only changes *which* candidates reach the operator.

## Acceptance Criteria

- [ ] The gate-substrate decision (Option A vs B) is recorded with rationale before any build.
- [ ] The ADR-0043 Strategic loop's LDR is `autonomy_tier: B` with a named Evals gate, threshold, and `rejects/` `EvalReport` sink.
- [ ] Generated candidates are scored before landing; sub-threshold candidates go to `generated/work-items/rejects/` with their `EvalReport`, not to `proposed/`.
- [ ] The operator `proposed/ → active/` promotion gate is unchanged (ADR-0043 D3 preserved) — verify the gate does not auto-promote.
- [ ] Each run records an `EvalReport` with provenance + cost (ADR-0093 D11; ADR-0023 D12); cost-per-accepted-candidate is reportable (loop ROI, ADR-0093 D11).
- [ ] A short doc records the chosen substrate and the pilot's first-week pass/reject rates for tuning.

## Human Prerequisites

- [ ] **BLOCKING — resolve the gate-substrate decision (Option A vs B)** via `adr-composer` / operator before build.
- [ ] (Option A) `HoneyDrunk.Evals` scaffolded (ADR-0023 P04) **and** a suite-code host repo chosen.
- [ ] Set the initial score threshold (operator judgment; start conservative — favor false-accepts the operator filters over false-rejects that hide good work).

## Dependencies

- ADR-0093 P02 (LDR template) and P03 (the Strategic loop's LDR backfilled) — the LDR this packet promotes to Tier B must exist.
- (Option A only) ADR-0023 P04 (Evals scaffold).

## Agent Handoff

**Objective:** Promote the ADR-0043 Strategic backlog loop to Tier B with an Evals quality gate (after the substrate decision is made).
**Target:** HoneyDrunk.Architecture (the loop's LDR + runner job wiring + rejects sink); suite-code host TBD by the Option A/B decision.
**Context:** ADR-0093 D4 (autonomy ladder), D5 (gates outside worker reach), D11 (cost as first-class); ADR-0023 D3/D5/D10/D12 (contracts, model-as-judge, telemetry carve-out, provenance); ADR-0043 D1/D3 (Strategic source, `proposed/→active/` human gate). All readable in this repo.
**Constraints:**
- The human `proposed/ → active/` promotion gate (ADR-0043 D3) is `[Firm]` — this gate pre-filters, it never auto-promotes.
- The gate must live outside the generating worker's write scope (ADR-0093 D5) — the worker that wrote the candidate cannot also be its scorer.
- Never render an estimated cost/score as exact (ADR-0093 D11; ADR-0092 honesty rule).
- Do not begin the build until the OPEN DECISION is resolved; if unresolved, stop and route to `adr-composer`.
**Key Files:**
- the ADR-0043 Strategic loop's LDR under `loops/` (read/update)
- `copilot/issue-authoring-rules.md` (the rubric source for the scorers)
- the ADR-0086 `backlog-strategic-scope` runner job spec (wire the gate)
