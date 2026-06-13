# Dispatch Plan — ADR-0025 HoneyDrunk.Sim Standup

**Initiative:** `adr-0025-sim-standup`
**Sector:** AI
**Governing ADR:** [ADR-0025 — Stand Up the HoneyDrunk.Sim Node](../../../../adrs/ADR-0025-stand-up-honeydrunk-sim-node.md) (Proposed 2026-04-19; flips to Accepted after merge).
**Trigger:** ADR-0025 in the Proposed queue. **Closes the AI-sector stand-up wave.** Flow (workflow-dry-run scenarios), Agents (agent-plan scenarios), Lore (wiki-compilation plan validation), HoneyHub when live, application Nodes with commit-to-real-execution gates blocked on `HoneyDrunk.Sim.Abstractions`.
**Type:** Multi-repo (3 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Sim` creation chore + `HoneyDrunk.Sim` scaffold)
**Site sync required:** Deferred — see "What This Initiative Does NOT Deliver" below. Sim closes the AI-sector stand-up wave; a single AI-sector-wide site-sync (covering ADR-0016 through ADR-0025) is the cleaner unit of work than a per-stand-up sync, and lands as wave-closing housekeeping rather than inside this initiative.
**Rollback plan:** Pre-tag revert; post-tag fix-forward.

## Summary

ADR-0025 is the standup ADR for `HoneyDrunk.Sim`. The **closing Node** of the AI-sector stand-up wave (ADR-0016 + 0017 + 0018 + 0020-0025 = 9 stand-ups complete).

Owns simulation primitives — three interfaces (`ISimulator`, `IPlanValidator`, `ISimulationTarget`) + three records (`Scenario`, `RiskAssessment`, `SimulationResult`). **Reconciles three-way drift** between `contracts.json` (two interfaces — `ISimulator`, `ISimulationResult`), `relationships.json` (four interfaces), repo overview (four interfaces). D3 pins the six-surface definitive set.

Three packages (`Abstractions`, runtime, `Providers.InMemory` scenario-execution backend). Composes Flow's `IWorkflow`/`IWorkflowStep` at Abstractions level (compile-time, read-only per D5). Composes AI (chat-backed targets + model pinning per D8). Composes Operator (observation-only prediction per D9 — runtime only). Composes Memory + Knowledge `Providers.InMemory` for fixtures per D11 (runtime only). Side-effect-freedom is the Sim-Evals boundary primitive per D6. `ISimulationTarget` is parallel-but-distinct from `IEvalTarget` per D8 — no Sim→Evals runtime edge. Content-in-telemetry follows the Memory/Knowledge no-content rule per D10 (different from Evals's carve-out — Sim's payloads have no regression-diagnosis pressure). Reproducibility via `SimulationResult.Seed` per D7. Provenance fields on every `SimulationResult` per D12. Canary on four hot-path surfaces per D13.

**The `HoneyDrunk.Sim` repo does NOT exist on GitHub yet.** A human-only **create + clone** chore is required.

Four packets land the work:

1. **Architecture catalog registration + three-way drift reconciliation + integration-points** — RECONCILE: rename `ISimulationResult` → `SimulationResult` record; promote `IScenario` → `Scenario` record; promote `IRiskAssessment` → `RiskAssessment` record; add `IPlanValidator` (currently in relationships.json + overview, missing from contracts.json); add `ISimulationTarget` interface. Widen `consumes` to add Kernel + Flow + Memory + Operator; widen AI `consumes_detail`. Update `roadmap_focus` prose (drop "Optional for initial AI sector delivery" framing). Align `repos/HoneyDrunk.Sim/{overview,boundaries,invariants}.md` and Sim section of AI sector doc. Add `integration-points.md` and `active-work.md`.
2. **Constitution invariants** — ten new invariants from D2, D6, D5, D9, D8, D12, D11, D10, D2+D9+D11, D13.
3. **Create `HoneyDrunk.Sim` GitHub repo + clone locally (human-only)** — same pattern as ADR-0023 packet 03.
4. **HoneyDrunk.Sim scaffold** — empty repo to first-shippable. Solution, three packages (`Abstractions`, runtime, `Providers.InMemory` scenario-execution backend), three interfaces + three records in Abstractions, default `ISimulator` + `IPlanValidator` + `ISimulationTarget` chat-backed shape per D8, reproducibility primitives per D7, observation-only Operator composition per D9, fixture composition with Memory + Knowledge `Providers.InMemory` per D11, five CI workflow files with canary scoped to Abstractions.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates (parallel)
   ├─ Architecture: 01-architecture-sim-catalog-registration
   └─ Architecture: 02-architecture-sim-invariants
       Blocked by: 01

Wave 2: Create + clone repo (human)
   └─ Architecture: 03-architecture-create-sim-repo
       Blocked by: 01

Wave 3: Sim repo scaffold
   └─ HoneyDrunk.Sim: 04-sim-node-scaffold
       Blocked by: 01, 02, 03
```

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Catalog registration + three-way drift reconciliation + integration-points](./01-architecture-sim-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add ten new invariants for D2 / D6 / D5 / D9 / D8 / D12 / D11 / D10 / D2+D9+D11 / D13](./02-architecture-sim-invariants.md) | Architecture | 1 | Agent | 01 |
| 03 | [Create `HoneyDrunk.Sim` GitHub repo + clone (human-only)](./03-architecture-create-sim-repo.md) | Architecture | 2 | Human | 01 |
| 04 | [Stand up `HoneyDrunk.Sim` — solution, three packages, six surfaces, CI, InMemory provider](./04-sim-node-scaffold.md) | HoneyDrunk.Sim | 3 | Agent | 01, 02, 03 |

## Filing-order rule

Packet 04 hard-codes invariant numbers. **Packet 02 must merge first.** Packet 03 must close (repo exists) before packet 04 can be filed.

## What This Initiative Does **NOT** Deliver

- Concrete `ISimulationTarget` shapes (`WorkflowTarget`, `AgentTarget`, `RetrievalTarget`, transcript-replay) deferred to scaffold or follow-up packets per D3.
- Monte Carlo / N-trial distribution surfaces deferred per D3 / D14.
- Production scenario-execution backend (rule-based, model-backed, replay-transcript) deferred — `Providers.InMemory` only at stand-up per D2.
- Pulse signal ingress into Sim deferred (emit-only per D10).
- No separate `HoneyDrunk.Sim.Testing` — `Providers.InMemory` plays that role per D2.
- **Structured payload records.** Stand-up uses stringly-typed JSON for `SimulationStepInput.InputJson`, `TargetInvocationResult.OutputJson`, `Scenario.InitialStateFixtureJson`, `SimulationResult.ProjectedOutcomeJson`, `SimulationStepTrace.OutputJson`. Follow-up packet introduces structured payload records once concrete `ISimulationTarget` shapes (`WorkflowTarget`, `AgentTarget`, `RetrievalTarget`) crystallize and the per-target payload structure can be designed coherently.
- **AI-sector-wide site sync.** Single sync covering ADR-0016 through ADR-0025 lands as wave-closing housekeeping after packet 04 merges and ADR-0025 flips to Accepted. Tracked in the wave-closing housekeeping board item below, not inside this initiative.
- **`active-initiatives.md` + `ai-sector-architecture.md` post-merge updates.** Tracked as the wave-closing housekeeping board item; not a packet in this initiative's filing pipeline.

## AI-sector standup wave sequencing

Sim is the closing Node. Requires Flow Abstractions (mandatory — compile-time per D5), AI Abstractions (mandatory — chat-backed target per D8), Operator + Memory + Knowledge Abstractions (runtime per D9/D11). Land Sim last in the wave: AI → Capabilities → Operator → Memory + Knowledge → Agents → Evals → Flow → **Sim**.

## Status flip

ADR-0025 stays Proposed for duration. Closing-the-wave note: when Sim's status flips to Accepted (post-completion), the AI sector's stand-up wave is closed and `initiatives/active-initiatives.md` should reflect that milestone.

## Wave-closing housekeeping (board-item, post-merge)

Tracked as a single follow-up board item on The Hive once packet 04 merges and ADR-0025 flips to Accepted. NOT a packet in this initiative — these are post-completion housekeeping steps that touch shared index files outside the scope agent's allowed surface for this initiative:

- [ ] Update `initiatives/active-initiatives.md` — mark Sim standup complete, mark AI-sector stand-up wave (ADR-0016 + 0017 + 0018 + 0020-0025) closed.
- [ ] Update `constitution/ai-sector-architecture.md` — Sim section reflects shipped surface (six D3 surfaces), wave-closing milestone called out.
- [ ] AI-sector-wide site sync — single sync run covering ADR-0016 through ADR-0025 wave-closing state.
- [ ] File follow-up work-item: "Introduce structured payload records on Sim Abstractions once concrete `ISimulationTarget` shapes (`WorkflowTarget`, `AgentTarget`, `RetrievalTarget`) crystallize" — replaces stringly-typed JSON payloads with structured records per the deliberate stand-up simplification noted in packet 04.
- [ ] File concrete `ISimulationTarget` shape packets (`WorkflowTarget`, `AgentTarget`, `RetrievalTarget`, transcript-replay) as downstream consumers drive shape.

## Filing

`file-work-items.yml` auto-files. Packet 04 filing gated on packet 03's repo creation.

## Archival

Per ADR-0008 D10, archive post-completion.
