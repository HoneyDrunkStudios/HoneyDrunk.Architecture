# Dispatch Plan — ADR-0024 HoneyDrunk.Flow Standup

**Initiative:** `adr-0024-flow-standup`
**Sector:** AI
**Governing ADR:** [ADR-0024 — Stand Up the HoneyDrunk.Flow Node](../../../../adrs/ADR-0024-stand-up-honeydrunk-flow-node.md) (Proposed 2026-04-19; flips to Accepted after merge).
**Trigger:** ADR-0024 in the Proposed queue. Lore (already declares `consumes` Flow for wiki-compilation workflow), Sim (read-only `IWorkflow`/`IWorkflowStep` per ADR-0025 D5), Evals (`IWorkflowEngine` as `IEvalTarget`), HoneyHub when live, application Nodes with domain pipelines blocked on `HoneyDrunk.Flow.Abstractions`.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Flow`)
**Site sync required:** No.
**Rollback plan:** Pre-tag revert; post-tag fix-forward.

## Summary

ADR-0024 is the standup ADR for `HoneyDrunk.Flow`. The first Node above the AI-sector foundation — composes Agents (single-agent execution), Operator (policy gates synchronously per D7), Communications (outbound message steps per D8, **runtime-only edge — Abstractions stays clean**), Memory (indirectly via Agents — **no direct Flow → Memory edge** per D9).

Owns workflow-orchestration primitives — five interfaces (`IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, `IWorkflowState`, `ICompensation`). Three packages (`Abstractions`, runtime, `Providers.InMemory` for state). Orchestration-based compensation per D6. Event-out resume mechanism for approval-pause workflows per D7 — paused workflows are durable; no synchronous block on `IApprovalGate`. Communications composition is runtime-only — `HoneyDrunk.Flow.Abstractions` does NOT take a compile-time dependency on `HoneyDrunk.Communications.Abstractions` per D2 / D8. In-process engine at stand-up per D14; cross-host distributed engine deferred. Workflow-definition authoring shape deferred to scaffold per D13. `IWorkflowState` durable per D12; storage substrate deferred. Canary on four hot-path surfaces per D11.

Catalog drift: three-way between `contracts.json` (three interfaces), `relationships.json` (five interfaces), repo overview (five interfaces). D3 pins the five-interface definitive set.

Four packets land the work:

1. **Architecture catalog registration + integration-points + drift reconciliation** — bring `contracts.json` to the five-interface D3 set; add Operator + Communications to `consumes`; add Sim + Evals to `consumed_by_planned`; coordinate the bidirectional Flow ↔ Communications edge with ADR-0019; align repo docs + AI sector doc; add `integration-points.md` and `active-work.md`.
2. **Constitution invariants** — nine new invariants from D2/D8, D1/D4, D9, D9, D8, D7, D12, D2+D8 (Abstractions-stays-clean), D11.
2b. **Verify `HoneyDrunk.Flow` repo + local clone (human-only)**.
3. **HoneyDrunk.Flow scaffold** — empty repo to first-shippable. Solution, three packages (`Abstractions`, runtime, `Providers.InMemory` for state), five interfaces in Abstractions, default `IWorkflowEngine` with in-process coordination, default `IWorkflowStep` adapters (agent-step composing Agents, message-step composing Communications at the **runtime** layer), retry + orchestration-based compensation, event-out approval-resume mechanism, `Providers.InMemory` backend, five CI workflow files with canary scoped to Abstractions.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates (parallel)
   ├─ Architecture: 01-architecture-flow-catalog-registration
   └─ Architecture: 02-architecture-flow-invariants
       Blocked by: 01

Wave 2: Verify repo + clone (human)
   └─ Architecture: 02b-architecture-verify-flow-repo
       Blocked by: 01

Wave 3: Flow repo scaffold
   └─ HoneyDrunk.Flow: 03-flow-node-scaffold
       Blocked by: 01, 02, 02b
```

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Catalog registration + drift reconciliation + integration-points](./01-architecture-flow-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add nine new invariants for D2/D8 / D1+D4 / D9 / D9 / D8 / D7 / D12 / D2+D8 / D11](./02-architecture-flow-invariants.md) | Architecture | 1 | Agent | 01 |
| 02b | [Verify HoneyDrunk.Flow repo + clone (human-only)](./02b-architecture-verify-flow-repo.md) | Architecture | 2 | Human | 01 |
| 03 | [Stand up `HoneyDrunk.Flow` — solution, three packages, five interfaces, CI, InMemory state provider](./03-flow-node-scaffold.md) | HoneyDrunk.Flow | 3 | Agent | 01, 02, 02b |

## Filing-order rule

Packet 03 hard-codes invariant numbers. Packet 02 merges first; collision-shift packet 03 source pre-filing under invariant 24.

## What This Initiative Does **NOT** Deliver

- Downstream consumers (Lore wiki workflow, HoneyHub dispatch workflows, application pipelines) not delivered.
- Choreography-based saga primitives deferred per D6 (orchestration-based at stand-up).
- Cross-host distributed engine deferred per D14 (in-process at stand-up).
- Workflow-definition authoring shape decided **inside packet 03** per D13 — fluent builder / config-bound record graph / declarative YAML / attribute-based: scaffold agent picks one.
- Event-out **transport mechanism** deferred to follow-up packet per D7 (principle pinned; wire shape next).
- `IWorkflowState` production storage substrate deferred per D12.
- Pulse signal ingress deferred (emit-only per D10).
- No separate `HoneyDrunk.Flow.Testing` — `Providers.InMemory` plays that role per D2.

### Explicit follow-up packets to file against `HoneyDrunk.Flow`

- **Rotate `IAuditLog` consumption to `HoneyDrunk.Audit.Abstractions`** after Audit Node stand-up (ADR-0031) ships. Transitional Operator binding at v0.1.0 — flip to Audit Abstractions in a v0.1.x patch packet. Update Flow runtime composition + the `consumes_detail` edge in `relationships.json` (move `IAuditLog` off `honeydrunk-operator` onto `honeydrunk-audit`).
- **Rotate string-typed identifiers to strong types at v0.2.0.** `string InstanceId`, `string WorkflowId`, `string StepId`, `string CorrelationId` are deliberate v0.1.0 simplifications. Follow-up packet introduces strong-typed identity records (consistent with the cross-cutting decision applied across the Grid).
- **Event-out transport-mechanism wire-shape packet** (per D7 — `ApprovalResumeEmitter` + `WaitEventStepAdapter` ship with `ITransportPublisher`-backed defaults + extension seams; wire shape pinned in follow-up).
- **`Providers.SqlServer` / `Providers.CosmosDB` / `Providers.Data` state-store packet** (per D12 — durable substrate driven by first production consumer's shape).
- **`IWorkflowState` canary-promotion packet** — fold `IWorkflowState` into the contract-shape canary once the production state store lands per D11.

## AI-sector standup wave sequencing

Flow requires `HoneyDrunk.Agents.Abstractions` (mandatory — agent-step composition), `HoneyDrunk.Operator.Abstractions` (mandatory — gate composition), `HoneyDrunk.Communications.Abstractions` (mandatory — outbound message steps). Recommended order: AI → Capabilities → Operator → Knowledge + Memory → Agents → Evals → **Flow** + Communications → Sim.

## Status flip

ADR-0024 stays Proposed for duration.

## Filing

`file-packets.yml` auto-files.

## Archival

Per ADR-0008 D10, archive post-completion.
