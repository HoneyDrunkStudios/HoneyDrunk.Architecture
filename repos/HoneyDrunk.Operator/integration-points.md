# HoneyDrunk.Operator — Integration Points

How Operator connects to the rest of the Grid. Every cross-Node boundary here requires a canary test.

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `ITelemetryActivityFactory`, `IGridContext` | `OperatorTelemetry` emits per-call activities for every gate / breaker / cost / decision / safety-filter call (D7). One-way to Pulse. |
| **Vault** | `IConfigProvider` | Cost-rate tables, breaker thresholds, decision-policy rule sets, and safety-filter config are sourced from App Configuration (D6 / invariant 117). |
| **Audit** | `IAuditLog`, `AuditEntry` | Operator emits an `AuditEntry` for every decision (ADR-0030/0031 relocation — Operator consumes, does not own, the audit contract). Graceful no-op when Audit is not composed. |
| **Auth** | `IAuthorizationPolicy` | `AuthBackedDecisionPolicy` delegates authorization (D5). **v0.1.0:** config-sourced with a `TODO(auth)` — delegation lands in a follow-up packet. |
| **Data** | `IRepository`, `IUnitOfWork` | Durable persistence of cost/approval state (D12). **v0.1.0:** in-process with a `TODO(data)` — durability lands in a follow-up packet. |

> `HoneyDrunk.Operator.Abstractions` carries **zero** `HoneyDrunk.*` references (invariant 1). The runtime references peer Nodes' `.Abstractions` packages only (invariant 2).

## Exposes

| Contract | Consumer | Notes |
|----------|---------|-------|
| `IApprovalGate` | Agents, Flow, Evals, Sim | Human sign-off before constrained actions. |
| `ICircuitBreaker` | Agents, Flow, AI, Sim | Emergency stop for agents/inference/workflows. |
| `ICostGuard` | AI, Agents, Flow, Evals | Per-scope budget enforcement (renamed from `ICostController`). |
| `IDecisionPolicy` | Agents, Flow | Allow / deny / require-approval evaluation. |
| `ISafetyFilter` | AI, Agents, Evals | Output content validation. |
| `HoneyDrunk.Operator.Testing` | Test composition | In-memory fixtures. Never in production composition (invariant 116). |

**Event-out (D8):** approval-needed events are emitted via `IApprovalEventSink`; **Communications** subscribes and owns delivery. Operator has no runtime dependency on Communications (invariant 118).

## Canary Coverage Required

- `api-compatibility.yml` scoped to `src/HoneyDrunk.Operator.Abstractions/**` — contract-shape canary on `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `ISafetyFilter` (invariant 119). Baseline set on the scaffold PR merge.
