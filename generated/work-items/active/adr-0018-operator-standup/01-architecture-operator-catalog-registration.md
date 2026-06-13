---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0018"]
dependencies: []
adrs: ["ADR-0018", "ADR-0030", "ADR-0031"]
accepts: ADR-0018
wave: 1
initiative: adr-0018-operator-standup
node: honeydrunk-operator
---

# Chore: Register HoneyDrunk.Operator's standup decisions in Architecture catalogs

## Summary

Reflect ADR-0018's stand-up decisions in the canonical Architecture catalogs and the AI sector architecture doc. Reconcile `contracts.json` to drop the placeholder `ICostController`, add `ICostGuard` and the missing `IDecisionPolicy` + `ISafetyFilter` interfaces, and add three Operator-owned governance records (`CostEvent`, `ApprovalRequest`, `ApprovalDecision`) — leaving the eight Operator-owned contracts (five interfaces + three records) net of the `IAuditLog`/`AuditEntry` relocation. Update `catalogs/relationships.json` `consumes`, `exposes.contracts`, `exposes.packages`, and `consumed_by_planned` for `honeydrunk-operator`. Refresh `catalogs/grid-health.json` and `catalogs/nodes.json`. Add `repos/HoneyDrunk.Operator/integration-points.md` and `active-work.md`.

**Critical amendment:** per the 2026-05-16 ADR-0030/0031 amendment to ADR-0018, `IAuditLog` and `AuditEntry` are **relocated** out of `HoneyDrunk.Operator.Abstractions` into the new `HoneyDrunk.Audit.Abstractions`. Operator becomes a consumer of those two contracts, not their owner. The catalog edits in this packet reflect the relocation by marking the two contracts as relocated to `honeydrunk-audit` (or removing them from the `honeydrunk-operator` block, depending on the catalog schema's relocation convention at edit time).

ADR-0018 stays at `Status: Proposed` for this packet — the Status flip is a separate post-merge housekeeping step the scope agent handles after the entire initiative completes.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0018 establishes the Operator Node's exposed contracts, package families, downstream-coupling rule, and four invariants the scope agent finalizes at acceptance. None of that has reached the catalogs yet. Until it does, every downstream consumer (Agents, Flow, AI, Capabilities, Evals) reads stale or inconsistent metadata when scoping their own work.

Specific drift items to resolve in this work-item:

1. **`contracts.json` lists the old four-interface set** (`IApprovalGate`, `ICircuitBreaker`, `ICostController`, `IAuditLog`). ADR-0018 D3 supersedes that set with six interfaces (renaming `ICostController` → `ICostGuard`, adding `IDecisionPolicy` and `ISafetyFilter`) plus four records (`CostEvent`, `AuditEntry`, `ApprovalRequest`, `ApprovalDecision`). The 2026-05-16 ADR-0030/0031 amendment then relocates `IAuditLog` and `AuditEntry` to `honeydrunk-audit`, leaving **eight Operator-owned** contracts (five interfaces + three records).
2. **`relationships.json` `honeydrunk-operator.exposes.contracts`** (line 300) currently reads `["IApprovalGate", "ICircuitBreaker", "ICostGuard", "IAuditLog", "IDecisionPolicy", "ISafetyFilter"]`. It already has `ICostGuard` (the rename half landed early) and already has `IDecisionPolicy` + `ISafetyFilter`, but it still lists `IAuditLog` and is missing the three records (`CostEvent`, `ApprovalRequest`, `ApprovalDecision`). Drop `IAuditLog` (relocated per amendment) and add the three records.
3. **`relationships.json` `honeydrunk-operator.consumed_by_planned`** (line 297) currently reads `["honeydrunk-audit"]` — incomplete. Under ADR-0018 D11 and the Unblocks section, the consumer list is Agents, Flow, AI, Capabilities, Evals, Sim. (`honeydrunk-audit` is not a downstream consumer of Operator; remove it from the list. Audit is an upstream dependency of Operator under the amendment, not a downstream consumer.)
4. **`relationships.json` `honeydrunk-operator.exposes.packages`** (line 301) lists only `["HoneyDrunk.Operator.Abstractions", "HoneyDrunk.Operator"]`. Add `HoneyDrunk.Operator.Testing` per ADR-0018 D2.
5. **`relationships.json` `honeydrunk-operator.consumes`** (line 295) is `["honeydrunk-kernel", "honeydrunk-auth", "honeydrunk-data"]` — missing `honeydrunk-audit` (added per the amendment, since Operator now consumes `IAuditLog` from Audit). Add it.
6. **Amendment from ADR-0030/0031:** `IAuditLog` and `AuditEntry` relocate to `honeydrunk-audit`. Operator consumes them rather than owning them. This affects `contracts.json` (drop entries), `relationships.json` `exposes.contracts` (drop `IAuditLog`) and `relationships.json` `consumes` (add `honeydrunk-audit`).
7. **`grid-health.json`** has `honeydrunk-operator` only as a stub. It should reflect the standup ADR with the scaffold packet as the active blocker.
8. **Prose drift for `ICostController`** appears in `repos/HoneyDrunk.Operator/overview.md`, `repos/HoneyDrunk.Operator/boundaries.md`, and `constitution/ai-sector-architecture.md` (note: `relationships.json` itself already uses `ICostGuard`). All `ICostController` references in prose must change to `ICostGuard`.

## Proposed Implementation

### `catalogs/contracts.json` — `honeydrunk-operator` block

Replace the current four-interface seed with the **eight Operator-owned contracts** per D3 as amended — five interfaces (`IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter`) and three records (`CostEvent`, `ApprovalRequest`, `ApprovalDecision`). The original D3 set was six interfaces + four records (ten total); the 2026-05-16 ADR-0030 D5 amendment relocates `IAuditLog` and `AuditEntry` to `honeydrunk-audit`, leaving the eight here. Records drop the `I` prefix and use `kind: "type"`; interfaces keep the prefix and use `kind: "interface"`.

```json
{
  "node": "honeydrunk-operator",
  "node_name": "HoneyDrunk.Operator",
  "package": "HoneyDrunk.Operator.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "IApprovalGate", "kind": "interface", "description": "Raise an approval request, check status, consume a decision. Blocks the calling workflow until resolved or timed out. ADR-0018 D3." },
    { "name": "ICircuitBreaker", "kind": "interface", "description": "Trip, reset, and query the state of a named breaker. Halts agent, workflow, or inference execution when safety thresholds are breached. ADR-0018 D3." },
    { "name": "ICostGuard", "kind": "interface", "description": "Check and record spend against per-agent, per-tenant, and per-window budgets. Enforces hard limits; no soft warnings. ADR-0018 D3. Renamed from the previous placeholder ICostController." },
    { "name": "IDecisionPolicy", "kind": "interface", "description": "Evaluate a declarative rule set to produce allow / deny / require-approval against a given action context. ADR-0018 D3." },
    { "name": "ISafetyFilter", "kind": "interface", "description": "Validate an outbound content or action payload; rejections block the output, no log-and-continue path. ADR-0018 D3." },
    { "name": "CostEvent", "kind": "type", "description": "Record. Records a spend event — agent, tenant, window, amount, unit, source. Written by ICostGuard, read by the audit log. ADR-0018 D3." },
    { "name": "ApprovalRequest", "kind": "type", "description": "Record. Machine-readable approval ask — subject, context, requested scope, expiry. ADR-0018 D3." },
    { "name": "ApprovalDecision", "kind": "type", "description": "Record. Approval outcome — decision, approver identity, timestamp, reason. ADR-0018 D3." }
  ]
}
```

Changes vs current state:

- **Drop** `ICostController` placeholder.
- **Rename concept** → `ICostGuard` lands as a new entry per D3.
- **Add** `IDecisionPolicy` and `ISafetyFilter`.
- **Add** `CostEvent`, `ApprovalRequest`, `ApprovalDecision` records.
- **Remove** the existing `IAuditLog` entry from `honeydrunk-operator` per the 2026-05-16 ADR-0030/0031 amendment. `IAuditLog` and `AuditEntry` will be added under `honeydrunk-audit` by the HoneyDrunk.Audit Node standup initiative (out of scope here).

If the catalog schema supports a "relocated to" annotation, add a one-line note on the `honeydrunk-operator` block explaining the audit contracts relocated to `honeydrunk-audit`. Otherwise, the PR body explicitly notes the relocation.

### `catalogs/relationships.json` — `honeydrunk-operator` block

Five edits to the block at lines 293-308.

**(a) `consumes` array** (line 295). Add `honeydrunk-audit` per the 2026-05-16 ADR-0030/0031 amendment — Operator now consumes `IAuditLog` from Audit:

```json
"consumes": ["honeydrunk-kernel", "honeydrunk-auth", "honeydrunk-data", "honeydrunk-audit"]
```

**(b) `exposes.contracts` array** (line 300). Replace with the eight Operator-owned contracts (drop `IAuditLog`, add three records):

```json
"contracts": ["IApprovalGate", "ICircuitBreaker", "ICostGuard", "IDecisionPolicy", "ISafetyFilter", "CostEvent", "ApprovalRequest", "ApprovalDecision"]
```

**(c) `exposes.packages` array** (line 301). Add `HoneyDrunk.Operator.Testing` per ADR-0018 D2:

```json
"packages": ["HoneyDrunk.Operator.Abstractions", "HoneyDrunk.Operator", "HoneyDrunk.Operator.Testing"]
```

**(d) `consumed_by_planned` array** (line 297). Replace the current incomplete `["honeydrunk-audit"]` entry with the six AI-sector downstream consumers:

```json
"consumed_by_planned": ["honeydrunk-agents", "honeydrunk-flow", "honeydrunk-ai", "honeydrunk-capabilities", "honeydrunk-evals", "honeydrunk-sim"]
```

**Note on `honeydrunk-sim` addition.** ADR-0018's original Unblocks section enumerated five consumer Nodes (Agents, Flow, AI, Capabilities, Evals). `honeydrunk-sim` is added here per **ADR-0025 D9** (Sim's standup ADR) which lists Operator's `ICostGuard`, `ISafetyFilter`, and `IApprovalGate` as compile-time prerequisites for the observation-only prediction composition Sim uses. This is a justified expansion of ADR-0018's "Required Follow-Up Work" set, not a scope override — Sim was either underspecified at ADR-0018 authoring time or added between ADR-0018 and ADR-0025. The catalog needs to reflect the full consumer set; ADR-0018 itself stays Proposed unchanged in this packet.

**Note on removing `honeydrunk-audit` from `consumed_by_planned`.** The current entry treats Audit as a downstream consumer of Operator — that is no longer correct under the amendment. Audit is an **upstream** dependency of Operator (Operator consumes `IAuditLog`). Move `honeydrunk-audit` from `consumed_by_planned` into `consumes` (see edit (a) above).

**(e) `consumes_detail`** (lines 303-307). Add an upstream `honeydrunk-audit` entry, and add downstream `consumes_detail` reverse-edge entries for each `consumed_by_planned` consumer:

- Add to existing block: `"honeydrunk-audit": ["IAuditLog", "AuditEntry", "HoneyDrunk.Audit.Abstractions"]` per the 2026-05-16 amendment.
- Per-downstream-edge `consumes_detail` (these are reverse-edges; whether they live in a sibling block in `relationships.json` schema is a judgment call for the executing agent — if the schema only carries upstream `consumes_detail`, capture the downstream detail in the consumer Node blocks instead):
  - Agents: `["IApprovalGate", "ICircuitBreaker", "HoneyDrunk.Operator.Abstractions"]` (ADR-0020 D7)
  - Flow: `["IApprovalGate", "ICircuitBreaker", "ICostGuard", "HoneyDrunk.Operator.Abstractions"]` (ADR-0024 D7)
  - AI: `["ICostGuard", "ISafetyFilter", "ICircuitBreaker", "HoneyDrunk.Operator.Abstractions"]` (ADR-0018 Unblocks)
  - Capabilities: `["IDecisionPolicy", "HoneyDrunk.Operator.Abstractions"]` (ADR-0018 Unblocks — chained above `ICapabilityGuard`)
  - Evals: `["ISafetyFilter", "ICostGuard", "HoneyDrunk.Operator.Abstractions"]` (ADR-0023 D7)
  - Sim: `["ICostGuard", "ISafetyFilter", "IApprovalGate", "HoneyDrunk.Operator.Abstractions"]` (ADR-0025 D9 — justified expansion of ADR-0018's original Unblocks set)

### `catalogs/grid-health.json` — `honeydrunk-operator` block

Replace the existing stub with one that reflects ADR-0018 acceptance:

```json
{
  "id": "honeydrunk-operator",
  "name": "HoneyDrunk.Operator",
  "sector": "AI",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": ["Scaffold packet (Operator#NN — packet 03 of adr-0018-operator-standup) not yet executed"],
  "notes": "ADR-0018 standup ADR Proposed 2026-04-19 (Status flip is post-merge housekeeping). Catalog surface registered (8 Operator-owned contracts per D3 minus IAuditLog/AuditEntry which relocate to honeydrunk-audit per 2026-05-16 ADR-0030/0031 amendment). Awaiting scaffold: HoneyDrunk.Operator.Abstractions, HoneyDrunk.Operator runtime, HoneyDrunk.Operator.Testing fixture, Standards wiring, CI with contract-shape canary scoped to four hot-path interfaces (IApprovalGate, ICircuitBreaker, ICostGuard, ISafetyFilter)."
}
```

### `catalogs/nodes.json` — `honeydrunk-operator` block

Locate the `honeydrunk-operator` block and:

**(a) `grid_relationship` field.** Replace with text reflecting D11 + D12:

> `"grid_relationship": "Consumes Kernel (context, identity, lifecycle, telemetry), Auth (authorization policy for IDecisionPolicy / IApprovalGate's default), Data (IRepository / IUnitOfWork for the spend ledger), and Audit (IAuditLog consumed per ADR-0030/0031 amendment). Emits gate, breaker, cost, and audit-decision telemetry consumed by Pulse — no runtime dependency on Pulse. Emits approval-needed events consumed by Communications via event-out — no runtime dependency on Communications. Consumed by Agents, Flow, AI, Capabilities, Evals, Sim."`

**(b) `tags`.** Ensure tags reflect the contract surface: include `approval`, `circuit-breaker`, `cost-guard`, `decision-policy`, `safety-filter`. Drop any `cost-controller` tag if present.

**(c) `value_props`.** Replace any reference to `ICostController` with `ICostGuard`. Add a value-prop string for `IDecisionPolicy` and `ISafetyFilter` if not already present.

### `constitution/ai-sector-architecture.md` — Operator section

Locate the Operator section. Apply these edits:

**(a) Key Contracts list.** Replace the current contract list with:

```
- `IApprovalGate` — Raise an approval request; consume a decision
- `ICircuitBreaker` — Trip, reset, query state
- `ICostGuard` — Per-agent/tenant/window budget enforcement
- `IDecisionPolicy` — Declarative rule evaluation → allow/deny/require-approval
- `ISafetyFilter` — Validate outbound content or action payloads
- `CostEvent` — Record. Spend-event metadata
- `ApprovalRequest` / `ApprovalDecision` — Records. Approval ask + outcome
- `IAuditLog` / `AuditEntry` — relocated to `HoneyDrunk.Audit` per ADR-0030/0031 amendment; Operator consumes
```

**(b) Depends-on phrasing.** Split into:

> `**Depends on:** Kernel (context, lifecycle, telemetry), Auth (IAuthorizationPolicy for IDecisionPolicy and IApprovalGate's default), Data (IRepository, IUnitOfWork for the spend ledger), Audit (IAuditLog consumed per ADR-0030/0031 amendment)`
>
> `**Emits to (no runtime dependency):** Pulse (gate / breaker / cost / decision telemetry per call via Kernel's ITelemetryActivityFactory); Communications (approval-needed events via event-out per ADR-0018 D8)`

### `repos/HoneyDrunk.Operator/overview.md`

Replace `ICostController` with `ICostGuard` in the Key Interfaces list. Add `IDecisionPolicy` and `ISafetyFilter` if not already present. The current overview already lists six interfaces matching D3 except for the `ICostController` → `ICostGuard` rename.

Add a Packages-table row for `HoneyDrunk.Operator.Testing`:

```
| `HoneyDrunk.Operator.Testing` | Testing fixture | Opt-in NuGet package — in-memory implementations of every exposed interface for deterministic unit and integration tests. Never composed into production hosts. |
```

Add a note immediately below the Key Interfaces list:

> `**Note:** `IAuditLog` and `AuditEntry` are relocated to `HoneyDrunk.Audit.Abstractions` per the 2026-05-16 ADR-0030/0031 amendment. Operator consumes those two contracts; it does not own them. The other eight contracts above stay Operator-owned.`

### `repos/HoneyDrunk.Operator/boundaries.md`

Replace any `ICostController` reference with `ICostGuard`. Add a "What Operator does not own" subsection clarifying that audit ownership transferred to HoneyDrunk.Audit per the ADR-0030/0031 amendment.

### `repos/HoneyDrunk.Operator/integration-points.md` — new file

Create this file matching the template used by `repos/HoneyDrunk.Agents/integration-points.md`:

```markdown
# HoneyDrunk.Operator — Integration Points

How Operator connects to the rest of the Grid. Every item here represents a cross-Node boundary that requires a canary test.

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `IGridContext`, `IOperationContext`, `INodeContext` | Every gate, breaker, cost, and decision operation runs inside a Grid context. CorrelationId flows through every decision. |
| **Kernel** | `IStartupHook`, `IShutdownHook` | Breaker / gate state initialization at startup; graceful drain on shutdown. |
| **Kernel** | `ITelemetryActivityFactory` | Emits per-call activities for gate outcomes, breaker state changes, cost events, decision evaluations, safety-filter decisions. Pulse consumes these — see Emits below. |
| **Auth** | `IAuthorizationPolicy`, `AuthorizationDecision` | The default `IDecisionPolicy` and the `IApprovalGate` permissions-check delegate to Auth. Operator does not maintain an independent permission model (ADR-0018 D5). |
| **Data** | `IRepository`, `IUnitOfWork` | Spend ledger persistence for `ICostGuard`; breaker state persistence (when non-volatile); approval request/decision persistence (when the runtime decides to outlive an in-memory store). ADR-0018 D12. |
| **Audit** | `IAuditLog`, `AuditEntry` | Per the ADR-0030/0031 amendment, the audit-log surface is owned by the HoneyDrunk.Audit Node. Operator emits AuditEntry records through IAuditLog for every gate / breaker / cost / approval / safety-filter decision.

## Exposes

| Contract | Consumer | Notes |
|----------|---------|-------|
| `IApprovalGate` | Agents, Flow, AI | Synchronous on the hot path; raises ApprovalRequest events emitted via event-out for Communications to deliver. |
| `ICircuitBreaker` | Agents, Flow, AI, Capabilities | Trip-and-halt semantics; consumers consult before dispatching expensive or safety-critical work. |
| `ICostGuard` | Agents, Flow, AI, Evals, Sim | Per-agent / per-tenant / per-window budget enforcement. Hard limits, no soft warnings. |
| `IDecisionPolicy` | Capabilities (chained above `ICapabilityGuard`), Agents, Flow | Declarative rule evaluation → allow / deny / require-approval. |
| `ISafetyFilter` | AI, Evals, Sim | Output-side content validation; rejections block the output, no log-and-continue. |
| `CostEvent`, `ApprovalRequest`, `ApprovalDecision` | All consumers | Records carrying cost / approval metadata; travel through ICostGuard / IApprovalGate / IAuditLog. |

## Emits (no runtime dependency)

| Signal | Consumer | Notes |
|--------|----------|-------|
| Gate / breaker / cost / decision / safety-filter activities | **Pulse** | Emitted via Kernel's ITelemetryActivityFactory. One-way by contract. |
| `ApprovalRequest`-needed events | **Communications** | Event-out per ADR-0018 D8. Operator does not call ICommunicationOrchestrator directly. Transport mechanism deferred to scaffold. |
| `AuditEntry` writes | **Audit** | Per the ADR-0030/0031 amendment, the audit surface is owned by HoneyDrunk.Audit. Operator emits, Audit owns the durable log.

## Canary Coverage Required

Before any Operator code can be considered production-ready:

- `Operator.Canary` → Kernel: verifies `IGridContext` flows through every gate / breaker / cost / decision operation, CorrelationId is propagated.
- `Operator.Canary` → Auth: verifies `IDecisionPolicy` default returns allow / deny / require-approval according to Auth policy.
- `Operator.Canary` → Data: verifies cost ledger writes round-trip through `IRepository` and `IUnitOfWork`.
- `Operator.Canary` → Audit: verifies that every gate / breaker / cost / approval / safety-filter decision produces an `AuditEntry` written via `IAuditLog` (consumed from Audit per ADR-0030/0031).
- `Operator.Canary` → contract-shape: contract-shape canary in CI fails the build if `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, or `ISafetyFilter` change shape without a version bump (ADR-0018 D10 / Operator canary invariant — number assigned at acceptance).

## Dependency Order for Bring-Up

Operator cannot be scaffolded until these Nodes have published their Abstractions packages:

1. Kernel (already Live — `HoneyDrunk.Kernel.Abstractions` stable)
2. Auth (already Live — `HoneyDrunk.Auth.Abstractions` stable)
3. Data (already Live — Repository / UnitOfWork stable)
4. Audit (must publish `HoneyDrunk.Audit.Abstractions` for `IAuditLog`/`AuditEntry` consumption per ADR-0030/0031 amendment — if not yet published at Operator's scaffold time, Operator's runtime can ship without writing audit and add the Audit dependency in a follow-up packet)

Operator is itself a hard prerequisite for:

1. Agents (`HoneyDrunk.Agents.Abstractions` — Seed, blocked on Operator for `IApprovalGate`, `ICircuitBreaker` consumption per ADR-0020 D7)
2. Flow (`HoneyDrunk.Flow.Abstractions` — Seed, blocked on Operator for synchronous in-loop composition per ADR-0024 D7)
3. AI (currently Seed — needs `ICostGuard`, `ISafetyFilter`, `ICircuitBreaker` for the inference-bounding path)
4. Capabilities (currently Seed — chains `IDecisionPolicy` above `ICapabilityGuard`)
5. Evals (`HoneyDrunk.Evals.Abstractions` — Seed, blocked on Operator for observation-only composition per ADR-0023 D7)
6. Sim (`HoneyDrunk.Sim.Abstractions` — Seed, blocked on Operator for observation-only prediction composition per ADR-0025 D9)
```

### `repos/HoneyDrunk.Operator/active-work.md` — new file

Create this file matching the template used by `repos/HoneyDrunk.Agents/active-work.md`. Include the scaffold packet as the active work item.

### `initiatives/active-initiatives.md` — new entry

Add a new entry under `## In Progress`:

```markdown
### ADR-0018 HoneyDrunk.Operator Standup
**Status:** In Progress
**Scope:** Architecture, HoneyDrunk.Operator
**Initiative:** `adr-0018-operator-standup`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Stand up `HoneyDrunk.Operator` as the AI sector's human-policy-enforcement substrate per ADR-0018. Catalog reconciliation (rename ICostController → ICostGuard; add IDecisionPolicy, ISafetyFilter, three Operator-owned records — CostEvent, ApprovalRequest, ApprovalDecision; reflect 2026-05-16 ADR-0030 D5 amendment relocating IAuditLog / AuditEntry to honeydrunk-audit), four new invariants for D11 / D6 / D8 / D10 (default numbers 47/48/49/50), human-only repo verification + clone confirmation, and the scaffold packet (three packages: Abstractions, runtime, Testing fixture). Unblocks Agents, Flow, AI, Capabilities, Evals, Sim.

**Tracking:**
- [ ] Architecture#NN: Catalog registration + integration-points (packet 01)
- [ ] Architecture#NN: Add four new invariants for D11 / D6 / D8 / D10 (packet 02)
- [ ] Architecture#NN: Verify HoneyDrunk.Operator repo + clone (human-only — packet 02b)
- [ ] Operator#NN: Scaffold HoneyDrunk.Operator (packet 03)

> **Sync (2026-MM-DD):** Initiative scoped today. Packets 01/02/02b ready to file in Wave 1/2; packet 03 (Operator scaffold) parked on packets 02 + 02b landing.
```

### `CHANGELOG.md` (Architecture repo)

Append to the Unreleased section:

`Architecture: Register ADR-0018 standup decisions in catalogs (contracts.json drops ICostController and adds the eight Operator-owned D3 contracts; relationships.json reconciles consumes, exposes.contracts/packages, consumed_by_planned, and consumes_detail; grid-health.json gets the standup block; nodes.json grid_relationship reflects D11/D12; ai-sector-architecture.md and Operator overview/boundaries adopt ICostGuard rename; new repos/HoneyDrunk.Operator/integration-points.md and active-work.md filed; active-initiatives.md gets the new initiative block). Reflects the 2026-05-16 ADR-0030 D5 amendment relocating IAuditLog / AuditEntry to honeydrunk-audit. ADR-0018 stays Proposed in this packet — the Status flip is a separate post-merge housekeeping step.`

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`
- `catalogs/nodes.json`
- `constitution/ai-sector-architecture.md`
- `repos/HoneyDrunk.Operator/overview.md`
- `repos/HoneyDrunk.Operator/boundaries.md`
- `repos/HoneyDrunk.Operator/integration-points.md` (new)
- `repos/HoneyDrunk.Operator/active-work.md` (new)
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

## NuGet Dependencies
None. Architecture is a knowledge repo.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No code changes; metadata + docs only.
- [x] D3 contract surface (eight Operator-owned contracts) authored verbatim per ADR-0018.
- [x] `IAuditLog` / `AuditEntry` relocation respects the 2026-05-16 ADR-0030/0031 amendment.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-operator` block lists exactly the eight Operator-owned D3 contracts: `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter`, `CostEvent`, `ApprovalRequest`, `ApprovalDecision`. No `ICostController`. No `IAuditLog` / `AuditEntry` (relocated).
- [ ] Records use `kind: "type"` (not `kind: "record"` and not `kind: "interface"`).
- [ ] `catalogs/relationships.json` `honeydrunk-operator` `exposes.contracts` array matches the same eight-contract surface.
- [ ] `catalogs/relationships.json` `honeydrunk-operator` `exposes.packages` includes `HoneyDrunk.Operator.Testing` as third entry.
- [ ] `catalogs/relationships.json` `honeydrunk-operator` `consumed_by_planned` lists `honeydrunk-agents`, `honeydrunk-flow`, `honeydrunk-ai`, `honeydrunk-capabilities`, `honeydrunk-evals`, `honeydrunk-sim`, each with `consumes_detail` per the table above.
- [ ] `catalogs/grid-health.json` `honeydrunk-operator` block reflects the standup ADR with the scaffold packet noted as the active blocker; `notes` field names the eight D3 contracts and the ADR-0030/0031 amendment.
- [ ] `catalogs/nodes.json` `honeydrunk-operator.grid_relationship` field reflects D11/D12; one-way emission to Pulse and Communications per D7/D8.
- [ ] `catalogs/nodes.json` `honeydrunk-operator.tags` includes `cost-guard`, `decision-policy`, `safety-filter`; no `cost-controller` token.
- [ ] `constitution/ai-sector-architecture.md` Operator section Key Contracts list updated with the eight D3 contracts + amendment note; Depends-on phrasing split into "Depends on" and "Emits to (no runtime dependency)" lines.
- [ ] `repos/HoneyDrunk.Operator/overview.md` Key Interfaces list reads `ICostGuard` not `ICostController`; Packages table includes `HoneyDrunk.Operator.Testing` row; amendment note added.
- [ ] `repos/HoneyDrunk.Operator/boundaries.md` no `ICostController` references; "What Operator does not own" subsection clarifies audit relocation per ADR-0030/0031.
- [ ] `repos/HoneyDrunk.Operator/integration-points.md` exists and matches the structure of `repos/HoneyDrunk.Agents/integration-points.md`.
- [ ] `repos/HoneyDrunk.Operator/active-work.md` exists.
- [ ] `grep -nr "ICostController" catalogs/ repos/HoneyDrunk.Operator/ constitution/` returns zero matches.
- [ ] `adrs/ADR-0018-stand-up-honeydrunk-operator-node.md` is **not** modified by this packet. ADR-0018 stays at `Status: Proposed`.
- [ ] `initiatives/active-initiatives.md` includes a new "ADR-0018 HoneyDrunk.Operator Standup" block under `## In Progress`.
- [ ] `CHANGELOG.md` Unreleased section updated.

## Human Prerequisites
None. The 2026-05-16 ADR-0030/0031 amendment text is already present in ADR-0018 (Amendment section). This packet reflects it in the catalogs.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Reinforces why `HoneyDrunk.Operator.Abstractions` is the only thing downstream Nodes compile against, and why the package field on the `honeydrunk-operator` `contracts.json` entry stays at that name.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.

## Referenced ADR Decisions

**ADR-0018 D3 (Exposed contracts), as amended by ADR-0030 D5:** Originally six interfaces + four records (ten total); after the 2026-05-16 ADR-0030 D5 relocation of `IAuditLog`/`AuditEntry` to `honeydrunk-audit`, the Operator-owned set is **eight** — five interfaces (`IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter`) + three records (`CostEvent`, `ApprovalRequest`, `ApprovalDecision`). `ICostController` superseded by `ICostGuard`. Records drop `I` prefix; interfaces keep it.

**ADR-0018 D5 (Authorization through Auth):** Operator runs on top of Auth's decision. The default `IDecisionPolicy` and `IApprovalGate` delegate to Auth's policy.

**ADR-0018 D7 (Telemetry direction):** Operator emits via Kernel's `ITelemetryActivityFactory`; Pulse consumes. No runtime dependency on Pulse.

**ADR-0018 D8 (Approval event-out):** Operator emits `ApprovalRequest`-needed events that Communications consumes. No runtime dependency on Communications.

**ADR-0018 D11 (Downstream coupling):** Downstream Nodes compile only against `HoneyDrunk.Operator.Abstractions`.

**ADR-0018 D12 (Kernel, Auth, Data first-class):** Operator takes first-class runtime dependencies on Kernel, Auth, and Data.

**ADR-0018 Amendment (2026-05-16, driven by ADR-0030 D5 with ADR-0031 standup):** `IAuditLog` and `AuditEntry` are relocated to `HoneyDrunk.Audit.Abstractions` per ADR-0030 D5 ("Contract reconciliation — `IAuditLog`/`AuditEntry` are promoted; Operator becomes a consumer"). ADR-0031 is the corresponding Audit Node standup that ships those contracts. Operator becomes a consumer of those two contracts per the recorder-must-not-be-the-actor structural rule. The other eight Operator contracts remain Operator-owned and are unaffected.

## Dependencies
None. Packet 01 is the foundation of the initiative.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0018`

## Agent Handoff

**Objective:** Bring `HoneyDrunk.Architecture` catalogs into alignment with ADR-0018 D3, D7, D8, D11, D12 — and reflect the 2026-05-16 ADR-0030/0031 amendment relocating `IAuditLog`/`AuditEntry`.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Catalog drift blocks downstream Operator consumers (Agents, Flow, AI, Capabilities, Evals, Sim) from scoping their own work. This packet removes the drift.
- Feature: ADR-0018 standup initiative, Wave 1, Packet 01.
- ADRs: ADR-0018 (sole standup); ADR-0030 + ADR-0031 (amendment relocating audit).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.
- **D3 (as amended by ADR-0030 D5) is canonical.** Drop `ICostController` (placeholder superseded). Add `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter`. Add three Operator-owned records (`CostEvent`, `ApprovalRequest`, `ApprovalDecision`). Do not add `AuditEntry` to the `honeydrunk-operator` block — it relocates to `honeydrunk-audit` under the amendment.
- **Records drop `I` prefix; interfaces keep it.** `CostEvent`, `ApprovalRequest`, `ApprovalDecision` are records. The five other surfaces are interfaces.
- **Audit relocation is mandatory.** Per the 2026-05-16 ADR-0030/0031 amendment, `IAuditLog` and `AuditEntry` are no longer Operator-owned. Drop them from `honeydrunk-operator` blocks. The `honeydrunk-audit` Node will register them under its own standup initiative.
- **Pulse is one-way; Communications is event-out, not a runtime edge.** Edit `grid_relationship` and `ai-sector-architecture.md` accordingly. Do not add Pulse or Communications to `consumes` on `honeydrunk-operator`.
- **No ADR Status flip in this packet.** ADR-0018 stays Proposed.

**Key Files:**
- `catalogs/contracts.json` — replace `honeydrunk-operator` block's interfaces array
- `catalogs/relationships.json` — `honeydrunk-operator.exposes.contracts/packages` + `consumed_by_planned` + `consumes_detail`
- `catalogs/grid-health.json` — replace the `honeydrunk-operator` block
- `catalogs/nodes.json` — edit `grid_relationship`, `tags`, `value_props`
- `constitution/ai-sector-architecture.md` — Operator section
- `repos/HoneyDrunk.Operator/overview.md`, `boundaries.md` — rename + amendment note
- `repos/HoneyDrunk.Operator/integration-points.md` and `active-work.md` — new files
- `initiatives/active-initiatives.md` — new entry
- `CHANGELOG.md`

**Contracts:** This packet does not author `.cs` files. Catalog-only.
