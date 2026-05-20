---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0025", "constitution"]
dependencies: ["packet:01"]
adrs: ["ADR-0025"]
accepts: ADR-0025
wave: 1
initiative: adr-0025-sim-standup
node: honeydrunk-sim
---

# Chore: Add ADR-0025's ten new invariants to the Grid constitution

## Summary

Add ten new invariants from ADR-0025: downstream-coupling (D2), side-effect-freedom (D6), Flow-read-only consumption (D5), Operator-observation-only (D9), router-bypass-via-ISimulationTarget (D8), `SimulationResult` provenance (D12), fixture-composition-via-Providers.InMemory (D11), telemetry-metadata-only-no-carve-out (D10), Sim-Abstractions-no-Operator-or-Memory deps (D2+D9+D11), contract-shape canary on four hot-path surfaces (D13).

Default numbers **83-92** (assumes all prior AI-sector initiatives landed claiming 44-82; collision check decides).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Proposed Implementation

### `constitution/invariants.md` — append ten new entries

```markdown
## AI Sector — Sim Invariants

83. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Sim.Abstractions`.**
    Composition against `HoneyDrunk.Sim` and any `HoneyDrunk.Sim.Providers.*` package is a host-time concern. See ADR-0025 D2 (Proposed — this invariant takes effect when ADR-0025 is accepted).

84. **Side-effect-freedom is the Sim–Evals boundary primitive.**
    If it writes to any Grid-durable surface, it is not Sim. Evals reads what the target actually did; Sim substitutes for that real behavior to predict what would happen. Sim's `ISimulator.SimulateAsync` does not take writer surfaces as parameters and does not compose writer surfaces in its default runtime path. This extends `repos/HoneyDrunk.Sim/invariants.md` item 2 to the Grid level. See ADR-0025 D6 (Proposed — this invariant takes effect when ADR-0025 is accepted).

85. **Sim consumes `IWorkflow` and `IWorkflowStep` as read-only authoring surfaces, never `IWorkflowEngine`.**
    This is the reciprocal of ADR-0024 D4/D6's Flow-side pin. A simulation of a workflow is a walk over the definition with substituted target behavior, not an execution of the engine. See ADR-0025 D5 (Proposed — this invariant takes effect when ADR-0025 is accepted).

86. **Sim composes Operator primitives as observation-only prediction inputs.**
    `ISafetyFilter`, `ICostGuard`, `IApprovalGate` are called to predict what Operator would do; Sim never enforces. Sim never writes to `IAuditLog`. The observes-vs-enforces distinction mirrors ADR-0023 D7 (Evals-style) with a shift in framing — Sim predicts, Evals observes. See ADR-0025 D9 (Proposed — this invariant takes effect when ADR-0025 is accepted).

87. **Router bypass is permitted only through `ISimulationTarget`.**
    Parallel to Evals's `IEvalTarget` bypass per ADR-0023 D6, but `ISimulationTarget` does NOT share the `IEvalTarget` type — Sim and Evals do not compose, so coupling the types would create a runtime edge neither Node needs. Every bypass is recorded on `SimulationResult.ModelCapabilityDeclarationIdentifier` per D12. See ADR-0025 D8 (Proposed — this invariant takes effect when ADR-0025 is accepted).

88. **Every `SimulationResult` records the full run provenance — scenario identity and version, `ISimulationTarget` identity, `ModelCapabilityDeclaration` identity (when a model was pinned), reproducibility seed (per D7), timestamps.**
    `SimulationResult` without provenance is not a valid result. A risk assessment is a decision input — without the provenance fields, the consumer cannot reproduce or audit the projection. See ADR-0025 D7, D12 (Proposed — this invariant takes effect when ADR-0025 is accepted).

89. **Sim seeds Memory and Knowledge state via `Providers.InMemory`, never production backends.**
    The production Memory and Knowledge stores are not on Sim's runtime edge. Scenario seeds compose the in-memory provider with the fixture state at simulation-start and discard it at simulation-end. See ADR-0025 D11 (Proposed — this invariant takes effect when ADR-0025 is accepted).

90. **Simulation telemetry is metadata-only and follows the Memory/Knowledge content-in-telemetry rule, not the Evals carve-out.**
    Scenario inputs and predicted outputs are not carried in Pulse signals; they are recoverable through `SimulationResult` if an investigator needs them. The actionable information in a Pulse signal is the identity, score, and confidence — not the payload. Stripping content from simulation telemetry does not degrade actionability the way it would degrade eval triage. See ADR-0025 D10 (Proposed — this invariant takes effect when ADR-0025 is accepted).

91. **`HoneyDrunk.Sim.Abstractions` does not take compile-time dependencies on `HoneyDrunk.Operator.Abstractions` or `HoneyDrunk.Memory.Abstractions`.**
    Both are runtime-only edges consumed inside the default `HoneyDrunk.Sim` package. The compile-time `HoneyDrunk.Sim.Abstractions` → `HoneyDrunk.Flow.Abstractions` edge IS permitted because Flow shapes legitimately need to be readable on member signatures (D5). The split between "Flow shape in Abstractions" and "Operator / Memory composition in runtime" is deliberate and load-bearing for the downstream coupling rule. See ADR-0025 D2, D9, D11 (Proposed — this invariant takes effect when ADR-0025 is accepted).

92. **The HoneyDrunk.Sim Node CI must include a contract-shape canary that fails the build on shape drift to `ISimulator`, `IPlanValidator`, `ISimulationTarget`, or `SimulationResult` without a corresponding version bump.**
    These four are the hot path for every real consumer (Flow workflow-dry-run, Agents agent-plan, Lore wiki-plan validation, HoneyHub when live, application Nodes with commit-to-real gates). `Scenario` and `RiskAssessment` are not in the stand-up canary because their shapes are expected to evolve modestly as concrete `ISimulationTarget` shapes land at scaffold; they become canary candidates once scaffold lands and shapes settle. See ADR-0025 D13 (Proposed — this invariant takes effect when ADR-0025 is accepted).
```

### Collision check

Default 83-92. Shift on collision; update ADR-0025 + packet 04 source in lockstep. `rg` only.

### `CHANGELOG.md`

Append: `Architecture: Add invariants 83-92 (Sim downstream coupling, side-effect-freedom Sim-Evals boundary, Sim consumes IWorkflow read-only, Sim observes Operator without enforcing, router-bypass via ISimulationTarget only, SimulationResult full provenance, fixture composition via Providers.InMemory of Memory + Knowledge, telemetry metadata-only following Memory/Knowledge rule, Sim Abstractions stays Operator/Memory-free, Sim contract-shape canary) per ADR-0025. **Closes the AI-sector standup invariant wave at 92.**`

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0025-stand-up-honeydrunk-sim-node.md` (only on shift)
- `generated/issue-packets/active/adr-0025-sim-standup/04-sim-node-scaffold.md` (only on shift)
- `CHANGELOG.md`

## Acceptance Criteria
- [ ] Ten invariants present matching ADR-0025.
- [ ] Numbers verified; default 83-92.
- [ ] `(Proposed — this invariant takes effect when ADR-0025 is accepted)` qualifier on each.
- [ ] On shift, ADR-0025 + packet 04 updated lockstep.
- [ ] `CHANGELOG.md` updated.

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0025 D2, D5, D6, D7, D8, D9, D10, D11, D12, D13.** Sources for invariants 83-92.

## Dependencies
- `packet:01`

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0025`, `constitution`

## Agent Handoff

**Objective:** Ten new invariants. Default 83-92. Closes AI-sector standup invariant wave.

**Constraints:** `(Proposed)` qualifier each. `rg` only.

**Key Files:** `constitution/invariants.md`; conditional ADR-0025 + packet 04; `CHANGELOG.md`.

**Contracts:** None.
