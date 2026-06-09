# HoneyDrunk.Evals — Integration Points

How Evals connects to the rest of the Grid. Every cross-Node boundary here requires a canary test.

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `TenantId` | Strong-typed multi-tenant identity on `EvalCase` / `EvalReport` (ADR-0026 / I3). Defaults to `TenantId.Internal`. |
| **Kernel** | `ITelemetryActivityFactory` | `EvalsTelemetry` emits per-suite / per-case / per-regression activities (D10). |
| **AI** | `IChatClient` | `ChatTarget` invocation and the model-as-judge scorer. Evals never calls a provider directly. |
| **AI** | `IModelProvider`, `ModelCapabilityDeclaration` | D6 router-bypass: a pinned `ChatTarget` resolves `IModelProvider` for a specific declaration and records it on `EvalReport`. |
| **AI** | `IEmbeddingGenerator` | Embedding-centric targets/scorers. |
| **Operator** | `ISafetyFilter`, `ICostGuard` | **Observation-only** scoring signals (D7) — Evals records what the primitive *would* do; it never enforces. |
| **Audit** | `IAuditLog` | **Observation-only** (D7/D9) — Evals reads/correlates audit; `AuditLogObserver` never appends. |
| **Agents / Capabilities / Knowledge / Memory** | `IAgent` / `ICapabilityInvoker` / `IRetrievalPipeline` / `IMemoryStore` | Contract-level support for `AgentTarget` / `RetrievalTarget` / `MemoryTarget`. Concrete targets deferred to a scaffold follow-up per D3. |

> `HoneyDrunk.Evals.Abstractions` references only `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.AI.Abstractions` (ADR-0023 D2). The runtime references peer Nodes' `.Abstractions` packages only (invariants 1/2/58).

## Exposes

| Contract | Consumer | Notes |
|----------|---------|-------|
| `IEvaluator` | Agents, Knowledge, Memory, Flow, Sim, Lore, HoneyHub (when live) | Suite-running entry point. |
| `IEvalScorer` | All consumers | Injection surface for custom scoring. |
| `IEvalSuite` | All consumers | Consumers author their own suites/cases/rubrics. |
| `IEvalTarget` | All consumers | Injection surface for custom targets; the only sanctioned router-bypass primitive (invariant 125). |
| `EvalCase`, `EvalReport` | All consumers | Case input and durable report artifact (D12/D13). |
| `HoneyDrunk.Evals.Providers.InMemory` | Test/local composition | First-wave report store + suite fixtures. Never in production composition (invariant 120). |

Eval signals are emitted to **Pulse** one-way (no runtime edge).

## Canary Coverage Required

- `api-compatibility.yml` scoped to `src/HoneyDrunk.Evals.Abstractions/**` — contract-shape canary on `IEvaluator`, `IEvalScorer`, `IEvalTarget`, `EvalReport`, and `IEvalSuite` (invariant 126). Baseline set on the scaffold PR merge.
