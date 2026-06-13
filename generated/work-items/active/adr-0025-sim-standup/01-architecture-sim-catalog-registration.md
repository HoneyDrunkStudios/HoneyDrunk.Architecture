---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0025"]
dependencies: []
adrs: ["ADR-0025", "ADR-0024"]
accepts: ADR-0025
wave: 1
initiative: adr-0025-sim-standup
node: honeydrunk-sim
---

# Chore: Register HoneyDrunk.Sim's standup decisions in Architecture catalogs + reconcile three-way drift

## Summary

Reflect ADR-0025 in catalogs. **Reconcile three-way drift** across `contracts.json` (two interfaces — `ISimulator`, `ISimulationResult`), `relationships.json` `exposes.contracts` (four interfaces — `ISimulator`, `IScenario`, `IRiskAssessment`, `IPlanValidator`), and `repos/HoneyDrunk.Sim/overview.md` (same four). Land the D3 six-surface definitive set: three interfaces (`ISimulator`, `IPlanValidator`, `ISimulationTarget`) + three records (`Scenario`, `RiskAssessment`, `SimulationResult`).

Widen `consumes` to add Kernel + Flow + Memory + Operator (four missing edges per D4). Widen AI `consumes_detail` per D8. Update `roadmap_focus` prose to drop the "Optional for initial AI sector delivery" framing and reflect Sim as the closing Node. Align `repos/HoneyDrunk.Sim/` docs and AI sector doc. Add `integration-points.md` and `active-work.md`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

Drift items:

1. **`contracts.json`** lists two interfaces. Missing four surfaces vs D3.
2. **`relationships.json` `exposes.contracts`** lists four — but `IScenario`, `IRiskAssessment` should be records (`Scenario`, `RiskAssessment`); `ISimulationTarget` is missing.
3. **`relationships.json` `consumes`** lists `["honeydrunk-ai", "honeydrunk-knowledge", "honeydrunk-agents"]`. Missing Kernel, Flow, Memory, Operator.
4. **`nodes.json roadmap_focus`** says "Optional for initial AI sector delivery" — wrong framing per D1 (closing Node of the wave).
5. **Repo docs** drift.

## Proposed Implementation

### `catalogs/contracts.json` — `honeydrunk-sim` block

Replace existing two-interface seed with six surfaces:

```json
{
  "node": "honeydrunk-sim",
  "node_name": "HoneyDrunk.Sim",
  "package": "HoneyDrunk.Sim.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "ISimulator", "kind": "interface", "description": "Run a Scenario against an ISimulationTarget, collect the projected outcome, produce a SimulationResult. The top-level orchestration surface. ADR-0025 D3." },
    { "name": "IPlanValidator", "kind": "interface", "description": "Validate a proposed plan (a Scenario paired with a candidate execution shape) before real execution. Composes ISimulator internally; returns a RiskAssessment plus a go/no-go verdict. ADR-0025 D3." },
    { "name": "ISimulationTarget", "kind": "interface", "description": "The thing being simulated — a chat model, a workflow definition, an agent, a retrieval pipeline. Abstracts over what the scenario is run against. Parallel in shape to Evals's IEvalTarget per ADR-0023 D3 but does NOT share the type — Sim owns ISimulationTarget to avoid creating a Sim → Evals runtime edge. Router-bypass boundary per ADR-0025 D8." },
    { "name": "Scenario", "kind": "type", "description": "Record. A single simulation scenario — initial state fixture, proposed actions or workflow under test, constraints, per-scenario metadata. Replaces the previous prose-level IScenario. ADR-0025 D3." },
    { "name": "RiskAssessment", "kind": "type", "description": "Record. Structured risk evaluation — identified failure modes, per-mode probability, per-mode mitigation, confidence level, aggregate severity. Replaces the previous prose-level IRiskAssessment. ADR-0025 D3." },
    { "name": "SimulationResult", "kind": "type", "description": "Record. Structured simulation results — projected outcome payload, per-step trace, observed Operator-primitive firings (per ADR-0025 D9), a RiskAssessment, run provenance (target identity, ModelCapabilityDeclaration identity when pinned, scenario version, timestamps, reproducibility seed per ADR-0025 D7). Replaces the previous ISimulationResult interface. ADR-0025 D3 / D12." }
  ]
}
```

### `catalogs/relationships.json` — `honeydrunk-sim` block

**(a) `consumes` widening.** Replace with:

```json
"consumes": ["honeydrunk-kernel", "honeydrunk-ai", "honeydrunk-knowledge", "honeydrunk-agents", "honeydrunk-flow", "honeydrunk-memory", "honeydrunk-operator"]
```

**(b) `consumes_detail`.** Add per-edge entries:

```json
"honeydrunk-kernel": ["IGridContext", "IOperationContext", "ITelemetryActivityFactory", "HoneyDrunk.Kernel.Abstractions"],
"honeydrunk-ai": ["IChatClient", "IModelProvider", "ModelCapabilityDeclaration", "HoneyDrunk.AI.Abstractions"],
"honeydrunk-knowledge": ["HoneyDrunk.Knowledge.Abstractions", "HoneyDrunk.Knowledge.Providers.InMemory"],
"honeydrunk-agents": ["IAgent", "HoneyDrunk.Agents.Abstractions"],
"honeydrunk-flow": ["IWorkflow", "IWorkflowStep", "HoneyDrunk.Flow.Abstractions"],
"honeydrunk-memory": ["IMemoryStore", "IMemoryScope", "HoneyDrunk.Memory.Abstractions", "HoneyDrunk.Memory.Providers.InMemory"],
"honeydrunk-operator": ["ICostGuard", "ISafetyFilter", "IApprovalGate", "HoneyDrunk.Operator.Abstractions"]
```

**(c) `exposes.contracts`.** Replace with D3 set:

```json
"contracts": ["ISimulator", "IPlanValidator", "ISimulationTarget", "Scenario", "RiskAssessment", "SimulationResult"]
```

**(d) `exposes.packages`.** Replace with:

```json
"packages": ["HoneyDrunk.Sim.Abstractions", "HoneyDrunk.Sim", "HoneyDrunk.Sim.Providers.InMemory"]
```

### `catalogs/grid-health.json` — `honeydrunk-sim` block

Standup block naming D3 six surfaces; scaffold packet as blocker; closing-of-the-wave note.

### `catalogs/nodes.json` — `honeydrunk-sim` block

**(a) `roadmap_focus`.** Drop "Optional for initial AI sector delivery." Replace with text naming Sim as the closing Node of the AI-sector stand-up wave and naming the D3 six surfaces.

**(b) `grid_relationship`.** Replace to reflect D4 — explicitly name Flow + Memory + Operator + Knowledge edges, and the parallel-but-distinct relationship to Evals's `IEvalTarget` per D8.

### `constitution/ai-sector-architecture.md` — Sim section

Update Key Contracts to D3 six surfaces. Depends-on / Emits-to split:

> `**Depends on:** Kernel, AI (IChatClient, IModelProvider, ModelCapabilityDeclaration for ChatTarget + model pinning per D8), Flow (IWorkflow, IWorkflowStep — read-only per D5), Agents (IAgent — for AgentTarget when scaffolded), Knowledge (Providers.InMemory for fixture composition per D11), Memory (Providers.InMemory for fixture composition per D11), Operator (ICostGuard, ISafetyFilter, IApprovalGate — observation-only per D9 — runtime edge).`
>
> `**Emits to (no runtime dependency):** Pulse (simulation lifecycle, step-trace, risk-assessment telemetry — metadata only per D10, following the Memory/Knowledge no-content rule rather than Evals's carve-out).`

Note the side-effect-freedom rule (D6) and the router-bypass via `ISimulationTarget` (D8 — parallel to Evals's `IEvalTarget` but distinct types).

### `repos/HoneyDrunk.Sim/overview.md`

Replace `IScenario`, `IRiskAssessment`, `ISimulationResult` references with the records `Scenario`, `RiskAssessment`, `SimulationResult`. Add `IPlanValidator` and `ISimulationTarget` to Key Contracts. Add `HoneyDrunk.Sim.Providers.InMemory` to Packages table. Note the side-effect-freedom rule (D6) and the router-bypass primitive (D8).

### `repos/HoneyDrunk.Sim/boundaries.md`

Align to D4 boundary decision test. Note Sim-vs-Evals (side-effect-freedom per D6), Sim-vs-Flow (read-only consumption per D5), Sim-vs-Operator (observation-only per D9), Sim-vs-Memory (fixture composition only per D11).

### `repos/HoneyDrunk.Sim/invariants.md`

Update to align with the new D3 contract names. Confirm item 2 (no side effects), item 3 (confidence level), item 5 (GridContext flagging) are still consistent.

### `repos/HoneyDrunk.Sim/integration-points.md` — new file

Standard template; reflect D4 + D5 + D6 + D8 + D9 + D10 + D11.

### `repos/HoneyDrunk.Sim/active-work.md` — new file

### `initiatives/active-initiatives.md` — new entry

Standard format. Note Sim as the closing Node of the AI-sector wave.

### `CHANGELOG.md` (Architecture repo)

Append standard entry naming the three-way drift reconciliation and the closing-of-the-wave milestone.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`
- `catalogs/nodes.json`
- `constitution/ai-sector-architecture.md`
- `repos/HoneyDrunk.Sim/overview.md`
- `repos/HoneyDrunk.Sim/boundaries.md`
- `repos/HoneyDrunk.Sim/invariants.md`
- `repos/HoneyDrunk.Sim/integration-points.md` (new)
- `repos/HoneyDrunk.Sim/active-work.md` (new)
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] D3 six-surface set canonical (three interfaces + three records).
- [x] Three-way drift reconciled in single PR.
- [x] Records drop `I`; interfaces keep it.
- [x] `ISimulationTarget` is distinct from `IEvalTarget` — no Sim→Evals edge in `consumes`.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-sim` lists exactly the D3 six surfaces — three interfaces + three records. No `ISimulationResult`, no `IScenario`, no `IRiskAssessment`.
- [ ] Records use `kind: "type"`.
- [ ] `relationships.json` `consumes` includes Kernel + AI + Knowledge + Agents + Flow + Memory + Operator. Does NOT include `honeydrunk-evals` (per D8 — no Sim→Evals edge).
- [ ] `consumes_detail` per edge.
- [ ] `exposes.contracts` matches D3 six-set.
- [ ] `exposes.packages` includes `HoneyDrunk.Sim.Providers.InMemory`.
- [ ] `grid-health.json` reflects standup + closing-of-the-wave note.
- [ ] `nodes.json roadmap_focus` does NOT say "Optional"; names Sim as closing Node.
- [ ] `nodes.json grid_relationship` reflects D4/D5/D8/D9/D11.
- [ ] `ai-sector-architecture.md` Sim section reads D3 six surfaces; Depends-on / Emits-to split present; side-effect-freedom and router-bypass noted.
- [ ] `repos/HoneyDrunk.Sim/overview.md`, `boundaries.md`, `invariants.md` aligned to D3 + D4.
- [ ] `integration-points.md` and `active-work.md` exist.
- [ ] `initiatives/active-initiatives.md` includes new entry, notes Sim as closing Node.
- [ ] `CHANGELOG.md` updated.
- [ ] `grep -rn "IScenario\|IRiskAssessment\|ISimulationResult" catalogs/ repos/HoneyDrunk.Sim/ constitution/` returns zero matches (the records `Scenario`, `RiskAssessment`, `SimulationResult` should appear; their interface-prefix versions should not).
- [ ] ADR-0025 NOT modified — Status stays Proposed.

## Human Prerequisites
None.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.

> **Invariant 11:** One repo per Node.

## Referenced ADR Decisions

**ADR-0025 D3:** Six surfaces — three interfaces + three records.

**ADR-0025 D4:** Boundary decision test against every adjacent Node.

**ADR-0025 D5:** Flow consumption is compile-time, read-only.

**ADR-0025 D6:** Side-effect-freedom is the Sim-Evals boundary primitive.

**ADR-0025 D8:** Router bypass via `ISimulationTarget`; distinct from `IEvalTarget`.

**ADR-0025 D9:** Operator composition is observation-only — runtime edge.

**ADR-0025 D10:** Telemetry metadata-only (Memory/Knowledge rule, not Evals's carve-out).

**ADR-0025 D11:** Fixture composition via `Providers.InMemory` of Memory + Knowledge.

**ADR-0024 D4/D6 (referenced):** Flow-side reciprocal — Sim consumes `IWorkflow` read-only.

## Dependencies
None.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0025`

## Agent Handoff

**Objective:** Reconcile three-way drift. Land D3 six-surface set + new consumes edges. No Sim→Evals edge.

**Constraints:**
- **D3 is canonical.** Six surfaces — three interfaces, three records.
- **Records use `kind: "type"`.**
- **No Sim→Evals edge.** `ISimulationTarget` is parallel-but-distinct from `IEvalTarget` per D8.
- **No code; catalog + docs only.**
- **No ADR Status flip.**

**Key Files:** All listed above.

**Contracts:** None authored.
