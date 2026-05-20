---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0024"]
dependencies: []
adrs: ["ADR-0024", "ADR-0019"]
accepts: ADR-0024
wave: 1
initiative: adr-0024-flow-standup
node: honeydrunk-flow
---

# Chore: Register HoneyDrunk.Flow's standup decisions in Architecture catalogs + reconcile three-way drift

## Summary

Reflect ADR-0024 in catalogs. **Reconcile three-way drift** between `contracts.json` (three interfaces: `IWorkflow`, `IWorkflowEngine`, `IWorkflowStep`), `relationships.json` `exposes.contracts` (five interfaces), and repo overview (five interfaces). Land the D3 five-interface definitive set: `IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, `IWorkflowState`, `ICompensation`. No records at stand-up.

Add `honeydrunk-operator` and `honeydrunk-communications` to `consumes` per D7 / D8 (runtime-only edges; `Abstractions` does not transit them — D2). Add `honeydrunk-sim` and `honeydrunk-evals` to `consumed_by_planned` per D4. Coordinate bidirectional Flow ↔ Communications edge with ADR-0019 D10. Update `grid-health.json`. Align `repos/HoneyDrunk.Flow/{overview,boundaries,invariants}.md` and AI sector doc to D3 + D4. Add `integration-points.md` and `active-work.md`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

Drift items:

1. **`contracts.json`** lists `IWorkflow`, `IWorkflowEngine`, `IWorkflowStep`. Add `IWorkflowState`, `ICompensation` per D3.
2. **`relationships.json` `consumes`** lists `["honeydrunk-kernel", "honeydrunk-agents", "honeydrunk-data", "honeydrunk-transport"]`. Add `honeydrunk-operator`, `honeydrunk-communications` per D7 / D8.
2a. **`relationships.json` `consumes_detail.honeydrunk-kernel`** currently reads `["IGridContext", "IStartupHook", "HoneyDrunk.Kernel"]` (line 287) — drift. Correct the package suffix to `HoneyDrunk.Kernel.Abstractions` per ADR-0024 D2, which explicitly permits Kernel Abstractions on Flow's Abstractions edge.
3. **`relationships.json` `consumed_by_planned`** missing `honeydrunk-sim` and `honeydrunk-evals`.
4. **ADR-0019 D10** pinned Communications-side "Communications planned as consumed by Flow." This ADR pins Flow's reciprocal at the runtime level. Both sides of the edge must be coherent.
5. **`grid-health.json`** stub. Refresh.
6. **Repo docs** may have minor drift; align to D3 + D4.

## Proposed Implementation

### `catalogs/contracts.json` — `honeydrunk-flow` block

Replace existing three-interface seed with five interfaces:

```json
{
  "node": "honeydrunk-flow",
  "node_name": "HoneyDrunk.Flow",
  "package": "HoneyDrunk.Flow.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "IWorkflowEngine", "kind": "interface", "description": "Top-level orchestration surface — start, pause, resume, cancel, compensate, query workflow instance status. The per-instance engine lifecycle entry point. ADR-0024 D3." },
    { "name": "IWorkflow", "kind": "interface", "description": "A named, versioned workflow definition — its steps, transitions, compensation mapping, metadata. Declarative; describes the pipeline shape. ADR-0024 D3." },
    { "name": "IWorkflowStep", "kind": "interface", "description": "A single unit of work — execute, compensate, retry-policy declaration. Steps may invoke agents, call tools, wait for external events, or emit messages. ADR-0024 D3." },
    { "name": "IWorkflowState", "kind": "interface", "description": "Persistent state for a running workflow instance — current step, step outputs carried forward, checkpoints, compensation log, correlation identity, causation chain. The durable between-step data. ADR-0024 D3 / D12 (durable per principle; storage substrate deferred to scaffold)." },
    { "name": "ICompensation", "kind": "interface", "description": "Rollback logic for a failed step — declared alongside a step's forward execution and invoked in reverse order when the workflow fails or is cancelled after the step completed. ADR-0024 D3 / D6 (orchestration-based)." }
  ]
}
```

No records at stand-up per D3.

### `catalogs/relationships.json` — `honeydrunk-flow` block

**(a) `consumes`.** Add `honeydrunk-operator` and `honeydrunk-communications`:

```json
"consumes": ["honeydrunk-kernel", "honeydrunk-agents", "honeydrunk-data", "honeydrunk-transport", "honeydrunk-operator", "honeydrunk-communications"]
```

**(b) `consumes_detail`.** Correct the existing Kernel entry (drift fix) and add new edges:

```json
"honeydrunk-kernel": ["IGridContext", "IStartupHook", "HoneyDrunk.Kernel.Abstractions"],
"honeydrunk-operator": ["IApprovalGate", "ICircuitBreaker", "ICostGuard", "IAuditLog", "HoneyDrunk.Operator.Abstractions"],
"honeydrunk-communications": ["ICommunicationOrchestrator", "HoneyDrunk.Communications.Abstractions"]
```

(`honeydrunk-kernel` previously read `HoneyDrunk.Kernel`; corrected to `HoneyDrunk.Kernel.Abstractions` per ADR-0024 D2. `honeydrunk-agents`, `honeydrunk-data`, `honeydrunk-transport` keep current detail.)

(Note: `IAuditLog` is a **transitional Operator binding** at v0.1.0. Rotates to `HoneyDrunk.Audit.Abstractions` after Audit Node stand-up ships per ADR-0031 — separate follow-up packet against Flow. The catalog edge stays on `honeydrunk-operator` for v0.1.0; a future packet flips it.)

**(c) `consumed_by_planned`.** Add `honeydrunk-sim` and `honeydrunk-evals`:

```json
"consumed_by_planned": ["honeydrunk-lore", "honeydrunk-sim", "honeydrunk-evals", "honeydrunk-honeyhub"]
```

`consumed_by_planned` is a list of node names only — the existing schema convention does NOT carry `consumes_detail` reverse-records under `consumed_by_planned`. Typed-edge detail (which contracts Sim / Evals / HoneyHub will consume) lives in each consumer's own forward `consumes_detail` block when that consumer's stand-up ADR pins the edge.

**(d) `exposes.contracts`.** Replace with:

```json
"contracts": ["IWorkflowEngine", "IWorkflow", "IWorkflowStep", "IWorkflowState", "ICompensation"]
```

**(e) `exposes.packages`.** Replace with:

```json
"packages": ["HoneyDrunk.Flow.Abstractions", "HoneyDrunk.Flow", "HoneyDrunk.Flow.Providers.InMemory"]
```

### Bidirectional Flow ↔ Communications edge coordination

Verify `catalogs/relationships.json` `honeydrunk-communications.consumed_by_planned` contains `honeydrunk-flow` per ADR-0019 D10. That single check is the entire bidirectional reconciliation on the Communications side — the existing schema convention does NOT carry `consumes_detail` reverse-records under `consumed_by_planned`. If `honeydrunk-flow` is missing from `honeydrunk-communications.consumed_by_planned`, add it; do not add a reverse `consumes_detail` block.

The Flow-side `consumes_detail.honeydrunk-communications` entry above (`["ICommunicationOrchestrator", "HoneyDrunk.Communications.Abstractions"]`) is the only typed-edge detail; it lives on the Flow side only.

### `catalogs/grid-health.json` — `honeydrunk-flow` block

Standup-aware block naming D3 contracts, scaffold packet as blocker.

### `catalogs/nodes.json` — `honeydrunk-flow` block

Update `grid_relationship` to reflect D4 — explicitly note: no direct `honeydrunk-flow` → `honeydrunk-memory` edge per D9; Memory access flows indirectly through Agents.

### `constitution/ai-sector-architecture.md` — Flow section

Update Key Contracts to five D3 interfaces. Depends-on / Emits-to split:

> `**Depends on:** Kernel (HoneyDrunk.Kernel.Abstractions — IGridContext, IStartupHook), Agents (IAgent from HoneyDrunk.Agents.Abstractions — agent-step composition), Operator (IApprovalGate, ICircuitBreaker, ICostGuard, IAuditLog — synchronous on critical path per D7; IAuditLog is transitional Operator binding pending ADR-0031 Audit relocation), Communications (ICommunicationOrchestrator — runtime-only edge; Abstractions stays clean per D2/D8), Data (IRepository from HoneyDrunk.Data.Abstractions for state persistence), Transport (event-out resume mechanism per D7).`
>
> `**Emits to (no runtime dependency):** Pulse (workflow lifecycle, step, compensation, state-persistence telemetry — metadata only per D10).`

Note "No direct Flow → Memory edge" per D9.

### `repos/HoneyDrunk.Flow/{overview,boundaries,invariants}.md`

Align to D3 five-interface set and D4 boundary test. Update any references to absent surfaces. Add Packages-table row for `HoneyDrunk.Flow.Providers.InMemory`.

### `repos/HoneyDrunk.Flow/integration-points.md` — new file

Standard template; reflect D4 (boundary against Agents/Operator/Communications/Memory/Knowledge/Evals/Sim/Lore/Pulse/HoneyHub), D7 (event-out resume), D8 (Communications runtime-only edge), D9 (state boundary including no direct Memory edge).

### `repos/HoneyDrunk.Flow/active-work.md` — new file

### `initiatives/active-initiatives.md` — new entry

Standard format. Note the bidirectional Flow ↔ Communications edge coordination.

### `CHANGELOG.md` (Architecture repo)

Append standard entry naming the drift reconciliation and the new edges.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`
- `catalogs/nodes.json`
- `constitution/ai-sector-architecture.md`
- `repos/HoneyDrunk.Flow/overview.md`
- `repos/HoneyDrunk.Flow/boundaries.md`
- `repos/HoneyDrunk.Flow/invariants.md`
- `repos/HoneyDrunk.Flow/integration-points.md` (new)
- `repos/HoneyDrunk.Flow/active-work.md` (new)
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] D3 five-interface set canonical.
- [x] No `honeydrunk-flow → honeydrunk-memory` edge in `consumes` per D9.
- [x] Communications edge marked as runtime-only (does not transit through Abstractions per D2 / D8).
- [x] Three-way drift reconciled in single PR.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-flow` lists exactly five D3 interfaces.
- [ ] `catalogs/relationships.json` `honeydrunk-flow.consumes` includes `honeydrunk-operator` and `honeydrunk-communications`. Does NOT include `honeydrunk-memory` per D9.
- [ ] `consumes_detail` entries per edge.
- [ ] `consumed_by_planned` includes `honeydrunk-sim` and `honeydrunk-evals`.
- [ ] `exposes.contracts` matches D3 five-set.
- [ ] `exposes.packages` includes `HoneyDrunk.Flow.Providers.InMemory`.
- [ ] Communications-side reciprocal edge is coherent with Flow-side.
- [ ] `grid-health.json` reflects standup.
- [ ] `nodes.json` `grid_relationship` reflects D4/D7/D8/D9.
- [ ] `ai-sector-architecture.md` Flow section reads D3 + D9 (no direct Memory edge).
- [ ] `repos/HoneyDrunk.Flow/` docs aligned to D3.
- [ ] `integration-points.md` and `active-work.md` exist.
- [ ] `initiatives/active-initiatives.md` includes new entry.
- [ ] `CHANGELOG.md` updated.
- [ ] ADR-0024 NOT modified — Status stays Proposed.

## Human Prerequisites
None.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.

> **Invariant 11:** One repo per Node.

## Referenced ADR Decisions

**ADR-0024 D3:** Five interfaces; no records at stand-up.

**ADR-0024 D4:** Boundary decision test.

**ADR-0024 D7:** Operator composition synchronous on critical path; approval-resume event-out.

**ADR-0024 D8:** Communications runtime-only edge; `Abstractions` stays clean.

**ADR-0024 D9:** No direct Flow → Memory edge.

**ADR-0019 D10 (referenced):** Communications-side reciprocal of the Flow ↔ Communications edge.

## Dependencies
None.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0024`

## Agent Handoff

**Objective:** Reconcile three-way drift. Land D3 five-interface set + new consumes / consumed_by_planned edges. Coordinate Flow ↔ Communications bidirectional edge.

**Constraints:**
- **D3 is canonical.** Five interfaces, no records at stand-up.
- **No direct `honeydrunk-flow → honeydrunk-memory` edge.** Per D9, Memory access flows indirectly through Agents.
- **Communications edge is runtime-only.** Documented in `consumes_detail` but `HoneyDrunk.Flow.Abstractions` does not take a compile-time dependency on `HoneyDrunk.Communications.Abstractions`.
- **No ADR Status flip.**

**Key Files:** All listed above.

**Contracts:** None authored.
