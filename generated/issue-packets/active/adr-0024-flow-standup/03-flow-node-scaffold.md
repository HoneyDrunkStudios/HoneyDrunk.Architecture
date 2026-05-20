---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Flow
labels: ["feature", "tier-2", "ai", "scaffold", "adr-0024"]
dependencies: ["packet:01", "packet:02", "packet:02b"]
adrs: ["ADR-0024", "ADR-0020", "ADR-0018", "ADR-0019"]
accepts: ADR-0024
wave: 3
initiative: adr-0024-flow-standup
node: honeydrunk-flow
---

# Feature: Stand up the HoneyDrunk.Flow repo — solution, three packages, five interfaces, CI, InMemory state provider

## Summary

Bring `HoneyDrunk.Flow` from zero to first-shippable per ADR-0024. Land solution, three packages (`Abstractions`, runtime, `Providers.InMemory` for state), five D3 interfaces in Abstractions, default `IWorkflowEngine` with in-process coordination per D14, default `IWorkflowStep` adapters (agent-step composing Agents per D5; message-step composing Communications at **runtime** per D8), orchestration-based compensation per D6, event-out approval-resume mechanism per D7, the workflow-definition authoring shape (scaffold-agent decides — see Constraints), `Providers.InMemory` state backend, standard CI, contract-shape canary scoped to Abstractions per D11 (number assigned by packet 02).

Unblocks Lore (already declares Flow consumer), HoneyHub when live, application Nodes, Sim (read-only consumer), Evals (workflow-target).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Flow`

## Motivation

ADR-0024 establishes Flow's contract surface. Repo cloned (LICENSE + README only). Lore's `consumes` edge already declares `IWorkflowEngine`; standing Flow up unblocks it.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Flow/
├── HoneyDrunk.Flow.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── .editorconfig
├── .gitignore
├── .github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml
├── src/
│   ├── HoneyDrunk.Flow.Abstractions/
│   │   ├── HoneyDrunk.Flow.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IWorkflowEngine.cs
│   │   ├── IWorkflow.cs
│   │   ├── IWorkflowStep.cs
│   │   ├── IWorkflowState.cs
│   │   ├── ICompensation.cs
│   │   └── (request/response/result records — minimum needed)
│   ├── HoneyDrunk.Flow/
│   │   ├── HoneyDrunk.Flow.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs
│   │   ├── Engine/DefaultWorkflowEngine.cs        (in-process coordination per D14)
│   │   ├── Steps/AgentStepAdapter.cs               (composes IAgent per D5)
│   │   ├── Steps/MessageStepAdapter.cs             (composes ICommunicationOrchestrator per D8)
│   │   ├── Steps/WaitEventStepAdapter.cs           (human-in-the-loop event-out resume target per D7)
│   │   ├── Compensation/CompensationWalker.cs     (orchestration-based per D6)
│   │   ├── Approval/ApprovalResumeEmitter.cs       (event-out per D7)
│   │   ├── Approval/ApprovalDecisionSubscriber.cs  (subscribes to Operator approval-decision events)
│   │   ├── Authoring/WorkflowBuilder.cs            (D13 — fluent C# builder; scaffold agent's choice)
│   │   └── Telemetry/FlowTelemetry.cs
│   └── HoneyDrunk.Flow.Providers.InMemory/
│       ├── HoneyDrunk.Flow.Providers.InMemory.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       └── InMemoryWorkflowStateStore.cs
└── tests/
    ├── HoneyDrunk.Flow.Abstractions.Tests/
    ├── HoneyDrunk.Flow.Tests/
    └── HoneyDrunk.Flow.Providers.InMemory.Tests/
```

### Contract details — `HoneyDrunk.Flow.Abstractions`

```csharp
// IWorkflowEngine.cs
namespace HoneyDrunk.Flow.Abstractions;

public interface IWorkflowEngine
{
    Task<WorkflowHandle> StartAsync(IWorkflow workflow, WorkflowStartRequest request, CancellationToken cancellationToken = default);
    Task PauseAsync(string instanceId, CancellationToken cancellationToken = default);
    Task ResumeAsync(string instanceId, ResumeRequest? request = null, CancellationToken cancellationToken = default);
    Task CancelAsync(string instanceId, string reason, CancellationToken cancellationToken = default);
    Task CompensateAsync(string instanceId, CancellationToken cancellationToken = default);
    Task<WorkflowStatus> GetStatusAsync(string instanceId, CancellationToken cancellationToken = default);
}

public sealed record WorkflowHandle(string InstanceId, string CorrelationId, WorkflowStatus InitialStatus);
public sealed record WorkflowStartRequest(string InitialPayloadJson, IReadOnlyDictionary<string, string> Metadata);
public sealed record ResumeRequest(string EventTypeId, string PayloadJson);
public sealed record WorkflowStatus(string InstanceId, WorkflowPhase Phase, string? CurrentStepId, string? PauseReason);

public enum WorkflowPhase { NotStarted = 0, Running = 1, PausedAwaitingApproval = 2, PausedAwaitingEvent = 3, Compensating = 4, Completed = 5, Failed = 6, Cancelled = 7 }
```

```csharp
// IWorkflow.cs
public interface IWorkflow
{
    string WorkflowId { get; }
    string WorkflowVersion { get; }
    IReadOnlyList<IWorkflowStep> Steps { get; }
    IReadOnlyDictionary<string, string> Metadata { get; }
}
```

```csharp
// IWorkflowStep.cs
public interface IWorkflowStep
{
    string StepId { get; }
    string StepKind { get; }                    // "agent", "message", "wait-event", "custom"
    RetryPolicy RetryPolicy { get; }
    Task<StepResult> ExecuteAsync(StepContext context, CancellationToken cancellationToken = default);
    ICompensation? Compensation { get; }         // null if step is not compensable
}

public sealed record StepContext(string InstanceId, string CorrelationId, string? PreviousStepOutputJson, IReadOnlyDictionary<string, string> WorkflowBag);
public sealed record StepResult(StepOutcome Outcome, string? OutputJson, string? FailureReason, bool ShouldPause, string? PauseReason);
public enum StepOutcome { Succeeded = 0, Failed = 1, Paused = 2, Skipped = 3 }
public sealed record RetryPolicy(int MaxAttempts, TimeSpan InitialBackoff, double BackoffMultiplier);
```

```csharp
// IWorkflowState.cs
public interface IWorkflowState
{
    string InstanceId { get; }
    string WorkflowId { get; }
    string WorkflowVersion { get; }
    WorkflowPhase Phase { get; }
    string? CurrentStepId { get; }
    IReadOnlyList<CompletedStepRecord> CompletedSteps { get; }
    IReadOnlyList<CompensationRecord> CompensationLog { get; }
    string CorrelationId { get; }
    string? CausationChain { get; }
    DateTimeOffset StartedAt { get; }
    DateTimeOffset LastUpdatedAt { get; }

    Task<IWorkflowState> AppendCompletedStepAsync(CompletedStepRecord record, CancellationToken cancellationToken = default);
    Task<IWorkflowState> AppendCompensationAsync(CompensationRecord record, CancellationToken cancellationToken = default);
    Task<IWorkflowState> TransitionAsync(WorkflowPhase nextPhase, string? currentStepId, CancellationToken cancellationToken = default);
}

public sealed record CompletedStepRecord(string StepId, string OutputJson, DateTimeOffset CompletedAt, int Attempts);
public sealed record CompensationRecord(string StepId, bool Succeeded, string? FailureReason, DateTimeOffset CompletedAt);
```

```csharp
// ICompensation.cs
public interface ICompensation
{
    Task<CompensationResult> CompensateAsync(CompensationContext context, CancellationToken cancellationToken = default);
}

public sealed record CompensationContext(string InstanceId, string StepId, string? StepOutputJson, string FailureReason);
public sealed record CompensationResult(bool Succeeded, string? FailureReason);
```

`HoneyDrunk.Flow.Abstractions` references **`HoneyDrunk.Kernel.Abstractions`** (for `IGridContext`-style scoped operations — explicitly permitted per ADR-0024 D2) and **`HoneyDrunk.Agents.Abstractions`** (for `IAgent` references in agent-step shapes per D5). **Does NOT** reference `HoneyDrunk.Operator.Abstractions` or `HoneyDrunk.Communications.Abstractions` per D2 / D8 — those are runtime-only edges (invariant 81).

**Strict Abstractions stance.** Identity / correlation fields are `string` at v0.1.0 (deliberate stand-up simplification — follow-up packet at v0.2.0 rotates to strong types per the cross-cutting decision). Workflow-record shapes are first-pass; subject to evolution before v0.2.0.

### Runtime details — `HoneyDrunk.Flow`

`HoneyDrunk.Flow` references:
- `HoneyDrunk.Flow.Abstractions` (project)
- `HoneyDrunk.Kernel` (telemetry, context)
- `HoneyDrunk.Agents` (composition target for agent steps per D5)
- `HoneyDrunk.Operator` (composition for `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IAuditLog` per D7 — `IAuditLog` is a **transitional Operator binding** at v0.1.0; rotates to `HoneyDrunk.Audit.Abstractions` after Audit Node stand-up per ADR-0031 ships, separate follow-up packet)
- `HoneyDrunk.Communications` (composition for `ICommunicationOrchestrator` per D8)
- `HoneyDrunk.Data` (for `IRepository` / `IUnitOfWork` — non-in-memory state persistence)
- `HoneyDrunk.Transport` (for event-out approval-resume per D7 — pub/sub of approval-decision events)
- `Microsoft.Extensions.*`

Implementations:

- **`DefaultWorkflowEngine`** — in-process coordination per D14. Orchestrates the step sequence: load `IWorkflowState` (or create), iterate `IWorkflow.Steps`, for each step (a) run `ICostGuard.CheckBudgetAsync` + `ICircuitBreaker.IsAllowedAsync` per D7, (b) execute step, (c) if step returns `ShouldPause: true` and `PauseReason` indicates approval — record pause, release thread, exit. Resume on `ApprovalDecisionSubscriber` event landing.
- **`AgentStepAdapter`** — wraps `IAgent.ExecuteAsync` as an `IWorkflowStep`. Marshals step input → `AgentRequest`; agent result → `StepResult.OutputJson`.
- **`MessageStepAdapter`** — wraps `ICommunicationOrchestrator` as an `IWorkflowStep`. Step input → `MessageIntent`; orchestrator result → `StepResult`. Per D8 / invariant 78, no direct `INotificationSender` invocation.
- **`WaitEventStepAdapter`** — wraps the event-out wait-and-resume pattern as an `IWorkflowStep`. Returns `StepResult` with `ShouldPause: true` and `PauseReason` indicating event-wait; the actual event-landing → resume is wired through `ApprovalDecisionSubscriber`-style transport subscribers. This is the human-in-the-loop event-out target per D7. The wire shape is deferred to a follow-up packet (same as `ApprovalResumeEmitter` — leave a TODO + extension seam).
- **`CompensationWalker`** — orchestration-based per D6. On step failure (post-retry-exhaustion), walks `IWorkflowState.CompletedSteps` in reverse order, invokes each step's `ICompensation`. Idempotent — already-compensated steps skip.
- **`ApprovalResumeEmitter`** — emits an approval-needed marker (via the configured transport — D7 mechanism deferred; this scaffold supplies an `ITransportPublisher`-backed default with the wire shape to be revised in a follow-up).
- **`ApprovalDecisionSubscriber`** — subscribes to Operator's approval-decision events. On event landing, looks up the paused workflow by correlation, rehydrates `IWorkflowState`, calls `IWorkflowEngine.ResumeAsync`.
- **`WorkflowBuilder`** — fluent C# builder for authoring `IWorkflow` instances per D13. The scaffold agent picks the fluent-builder shape; alternatives (config-bound, YAML, attribute-based) deferred to follow-up packets.
- **`FlowTelemetry`** — emits per-lifecycle / per-step / per-compensation / per-state-persistence activities. **Metadata only** per D10 (workflow content not carried).

**`IAuditLog` provenance — TODO at every call site.** At v0.1.0, `IAuditLog` is sourced from `HoneyDrunk.Operator.Abstractions` (transitional Operator binding). Every `IAuditLog` call site in `DefaultWorkflowEngine`, `CompensationWalker`, `ApprovalResumeEmitter`, and `ApprovalDecisionSubscriber` MUST carry an inline comment:

```csharp
// TODO(audit-relocation): IAuditLog consumed from Operator.Abstractions transitionally.
// Rotate to HoneyDrunk.Audit.Abstractions once Audit Node stand-up ships (ADR-0031).
// Tracked in follow-up packet against HoneyDrunk.Flow.
```

### Providers.InMemory details

`InMemoryWorkflowStateStore` — in-process dictionary keyed by `instanceId`. Persistence within process lifetime; `Providers.SqlServer` / `Providers.CosmosDB` (or `Providers.Data`-backed) ship in follow-up packets.

### CI workflows

Five files; `api-compatibility.yml` path-filtered to `src/HoneyDrunk.Flow.Abstractions/**`.

### `HoneyDrunk.Standards`

Per invariant 26.

### Documentation

Repo README — purpose, package matrix, "How to consume" snippet with `AddHoneyDrunkFlow()` + a simple two-step workflow example, link to ADR-0024. Note that `HoneyDrunk.Flow.Abstractions` does NOT transit Operator or Communications — those are runtime-only edges. Per-package README + CHANGELOG.

## Affected Files
Entire repo. See layout.

## NuGet Dependencies

### `HoneyDrunk.Flow.Abstractions.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `IGridContext`-style scoped operations — explicitly permitted per ADR-0024 D2 |
| `HoneyDrunk.Agents.Abstractions` | For `IAgent` references in agent-step shapes per D5 — accepted compile-time transitive reference per invariant 81 |

**No** `HoneyDrunk.Operator.Abstractions`. **No** `HoneyDrunk.Communications.Abstractions`. Kernel + Agents Abstractions are the only HoneyDrunk family references per ADR-0024 D2.

### `HoneyDrunk.Flow.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel` | Telemetry, context |
| `HoneyDrunk.Agents` | Composition (agent-step) |
| `HoneyDrunk.Operator` | Composition (gates, breakers, audit) |
| `HoneyDrunk.Communications` | Composition (message-step) |
| `HoneyDrunk.Data` | State persistence (non-in-memory) |
| `HoneyDrunk.Transport` | Event-out approval-resume |
| `Microsoft.Extensions.*` | |

Project reference: `HoneyDrunk.Flow.Abstractions`.

### `HoneyDrunk.Flow.Providers.InMemory.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

Project reference: `HoneyDrunk.Flow.Abstractions`. No reference to runtime, no reference to Agents / Operator / Communications.

### Test projects: standard + NSubstitute.

## Boundary Check
- [x] `HoneyDrunk.Flow.Abstractions` references only `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Agents.Abstractions` from the HoneyDrunk family (plus `HoneyDrunk.Standards`). No Operator, no Communications — invariant 81 (ADR-0024 D2).
- [x] `Providers.InMemory` references only `HoneyDrunk.Flow.Abstractions`.
- [x] No direct Flow → Memory edge anywhere (invariant 77).
- [x] No `INotificationSender` invocation anywhere; messaging goes through `ICommunicationOrchestrator` (invariant 78).
- [x] No synchronous block on `IApprovalGate` for long-running approvals (invariant 79).
- [x] `IWorkflowState` durable through `Providers.InMemory` (invariant 80; production substrate follow-up).
- [x] Multi-step coordination loop lives only here (invariant 75).
- [x] Records drop `I`; interfaces keep it.

## Acceptance Criteria
- [ ] `HoneyDrunk.Flow.slnx` builds clean.
- [ ] Five D3 interfaces present with XML docs.
- [ ] `HoneyDrunk.Flow.Abstractions` has zero `HoneyDrunk.Operator.Abstractions` or `HoneyDrunk.Communications.Abstractions` PackageReference. `rg` over `.csproj` verifies.
- [ ] `HoneyDrunk.Flow.Abstractions` references exactly `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Agents.Abstractions` from the HoneyDrunk family (plus `HoneyDrunk.Standards`) — per ADR-0024 D2.
- [ ] `Providers.InMemory` references only `HoneyDrunk.Flow.Abstractions`.
- [ ] `AddHoneyDrunkFlow()` resolves `IWorkflowEngine` and the three step adapters (`AgentStepAdapter`, `MessageStepAdapter`, `WaitEventStepAdapter`) from DI.
- [ ] `DefaultWorkflowEngine.StartAsync` orchestrates a multi-step workflow end-to-end with `AgentStepAdapter` and `MessageStepAdapter`. Unit test covers happy-path two-step workflow.
- [ ] `WaitEventStepAdapter` returns `StepResult { Outcome: Paused, ShouldPause: true, PauseReason: "wait-event:..." }` and the engine releases the thread without blocking. Unit test verifies non-blocking pause for the `wait-event` StepKind. Wire-shape TODO + extension seam present.
- [ ] `MessageIntent` shape from `HoneyDrunk.Communications.Abstractions` is verified stable (record with `kind: "type"`, not interface) at scaffold time. If `MessageIntent` is missing or has shifted to an interface, ship `MessageStepAdapter` as a placeholder no-op with structured warning and file follow-up.
- [ ] `DefaultWorkflowEngine` consults `ICostGuard` and `ICircuitBreaker` before each step per D7. Unit test verifies — `Unauthorized` cost or `Open` breaker short-circuits.
- [ ] Approval-pause path: when a step returns `ShouldPause: true` with approval reason, `DefaultWorkflowEngine` (a) persists pause via `IWorkflowState`, (b) emits via `ApprovalResumeEmitter`, (c) releases the thread without blocking. Unit test verifies non-blocking pause.
- [ ] `ApprovalDecisionSubscriber` rehydrates and resumes on event landing. Unit test verifies resume from a persisted paused state.
- [ ] `CompensationWalker` walks completed steps in reverse and invokes each step's `ICompensation`. Idempotent on already-compensated. Unit test verifies a 3-step workflow's compensation order on third-step failure.
- [ ] `MessageStepAdapter` invokes `ICommunicationOrchestrator`. **No invocation of `INotificationSender` anywhere.** Unit test verifies via mock and `rg "INotificationSender" src/` returning zero matches.
- [ ] Every `IAuditLog` call site carries a `TODO(audit-relocation):` comment referencing ADR-0031 / follow-up packet (transitional Operator binding at v0.1.0). `rg "TODO\(audit-relocation\)" src/` returns at least one match per file that consumes `IAuditLog`.
- [ ] `FlowTelemetry` emits per-lifecycle / per-step / per-compensation activities. Metadata only — no step input/output payloads in tags.
- [ ] `WorkflowBuilder` fluent API builds an `IWorkflow` instance. Unit test verifies builder produces a valid two-step workflow.
- [ ] `InMemoryWorkflowStateStore` persists and rehydrates `IWorkflowState` across simulated process restarts (in-process: just dispose and recreate the store + verify state survives via a new engine instance over the same store). Unit test verifies.
- [ ] All five `.github/workflows/*.yml` present.
- [ ] `api-compatibility.yml` path-filtered to Abstractions; scaffolding PR reports `status: skipped`.
- [ ] `pr-core.yml` passes.
- [ ] Repo + per-package `CHANGELOG.md` + `README.md` present.
- [ ] All `src/*.csproj` Version 0.1.0.
- [ ] Manual confirmation `v0.1.0` tag triggers `release.yml`.
- [ ] **No `IWorkflowState` in the contract-shape canary** per D11 — only `IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, `ICompensation`. `IWorkflowState` becomes canary later.
- [ ] **No production state store** in this packet — only `Providers.InMemory` per D12.

## Human Prerequisites
- [ ] Packet 02b complete.
- [ ] After merge, push tag `v0.1.0`.
- [ ] **Upstream Abstractions check.** Agents Abstractions mandatory (compile-time); Operator + Communications + Transport runtime-mandatory. If any is missing at edit time, ship placeholder no-op step adapters with structured warnings.
- [ ] **Branch protection sequencing.** Add `api-compatibility / abstractions-shape` to required checks post-merge.
- [ ] No Azure provisioning required at stand-up. Future production state-store packet may add a deployable component.
- [ ] After merge + tag, file SonarCloud onboarding follow-up.
- [ ] File event-out transport-mechanism follow-up packet to make the wire shape concrete (per D7 — wire-shape deferred to follow-up).
- [ ] File `Providers.SqlServer` / `Providers.CosmosDB` / `Providers.Data` follow-ups once production workflow consumers drive shape.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages, except where another `*.Abstractions` package is the cleanest way to type a member signature (Agents Abstractions is permitted here for `IAgent` shape).

> **Invariant 3:** Providers reference parent Node's contracts, not internal implementation details.

> **Invariant 11:** One repo per Node.

> **Invariant 12, 13, 26, 27.** Standard.

> **Flow downstream-coupling invariant (default 74):** Runtime-depend only on Abstractions.

> **Flow loop-lives-here invariant (default 75):** Multi-step coordination loop lives only in Flow.

> **Flow coordination-state-only invariant (default 76):** Flow holds only coordination state.

> **Flow no-direct-Memory invariant (default 77):** No `honeydrunk-flow → honeydrunk-memory` edge.

> **Flow delegates-to-Communications invariant (default 78):** No direct `INotificationSender` invocation.

> **Flow approval-pause-durable invariant (default 79):** No synchronous block on `IApprovalGate`.

> **Flow IWorkflowState-durable invariant (default 80):** State survives process restart.

> **Flow Abstractions-stays-clean invariant (default 81):** No `Operator.Abstractions` / `Communications.Abstractions` compile-time deps in Flow Abstractions.

> **Flow contract-shape canary invariant (default 82):** Canary on `IWorkflowEngine`, `IWorkflow`, `IWorkflowStep`, `ICompensation`.

## Referenced ADR Decisions

**ADR-0024 D1:** First Node above the foundation — workflow-orchestration substrate.

**ADR-0024 D2:** Three packages; runtime is the **only** package that takes Operator and Communications deps.

**ADR-0024 D3:** Five interfaces; no records at stand-up.

**ADR-0024 D5:** Agent-step composes `IAgent`.

**ADR-0024 D6:** Orchestration-based compensation (saga-style deferred).

**ADR-0024 D7:** Approval-pause via event-out; no synchronous block.

**ADR-0024 D8:** Communications composition is runtime-only; `Abstractions` does not transit it.

**ADR-0024 D9:** No direct Flow → Memory edge.

**ADR-0024 D10:** Metadata-only telemetry.

**ADR-0024 D11:** Canary on four hot-path surfaces.

**ADR-0024 D12:** `IWorkflowState` durable; storage substrate deferred.

**ADR-0024 D13:** Authoring shape decided at scaffold; this packet picks fluent C# builder.

**ADR-0024 D14:** In-process coordination at stand-up.

**ADR-0020 D3 (referenced):** `IAgent` from Agents.

**ADR-0018 D3 (referenced):** Operator primitives.

**ADR-0019 D3 (referenced):** `ICommunicationOrchestrator`.

## Dependencies
- `packet:01`, `packet:02`, `packet:02b`

## Labels
`feature`, `tier-2`, `ai`, `scaffold`, `adr-0024`

## Agent Handoff

**Objective:** Ship `HoneyDrunk.Flow 0.1.0` with five D3 interfaces, default in-process engine, three step adapters (agent / message / wait-event), orchestration-based compensation, event-out approval-resume, `Providers.InMemory` state, fluent `WorkflowBuilder`, CI, canary.

**Target:** HoneyDrunk.Flow, branch from `main`.

**Constraints:**
- **`HoneyDrunk.Flow.Abstractions` references only `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Agents.Abstractions`** from the HoneyDrunk family (plus `HoneyDrunk.Standards`). No Operator, no Communications, no Data, no Transport in Abstractions. Invariant 81 (ADR-0024 D2).
- **`Providers.InMemory` references only Abstractions.**
- **String-typed IDs at v0.1.0.** `string InstanceId`, `string WorkflowId`, `string StepId`, `string CorrelationId` are deliberate stand-up simplifications. Follow-up packet at v0.2.0 rotates to strong types per the cross-cutting decision.
- **No direct Flow → Memory edge anywhere.** Memory access is indirect through Agents. Invariant 77.
- **No `INotificationSender` invocation anywhere.** Messaging through `ICommunicationOrchestrator` only. Invariant 78.
- **No synchronous block on `IApprovalGate`.** Approval-pause flow records state, releases thread, subscribes to event. Invariant 79.
- **`DefaultWorkflowEngine` consults Operator before every step:** `ICostGuard.CheckBudgetAsync`, `ICircuitBreaker.IsAllowedAsync` per D7.
- **Compensation is orchestration-based, not choreography-based.** No saga-style event publishing for compensation in this packet. Invariant — orchestration-based per D6.
- **In-process coordination only.** No distributed-engine code paths. Invariant — D14.
- **Authoring shape: fluent C# builder (`WorkflowBuilder`).** YAML / attribute / config-bound deferred to follow-up packets.
- **Transport mechanism for event-out:** the scaffold supplies an `ITransportPublisher`-backed default. The wire shape is deferred to a follow-up packet — leave a TODO + a clear extension seam.
- **Records drop `I`; interfaces keep it.** All step / state / compensation records drop `I`.
- **Canary skip on scaffolding PR expected.**
- **Upstream conditional.** Agents Abstractions mandatory; Operator + Communications + Transport runtime — placeholder no-ops if any is missing at edit time.

**Key Files:**
- `HoneyDrunk.Flow.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Flow.Abstractions/` — 5 interfaces + supporting records
- `src/HoneyDrunk.Flow/` — `DefaultWorkflowEngine`, `AgentStepAdapter`, `MessageStepAdapter`, `WaitEventStepAdapter`, `CompensationWalker`, `ApprovalResumeEmitter`, `ApprovalDecisionSubscriber`, `WorkflowBuilder`, `FlowTelemetry`, `ServiceCollectionExtensions`
- `src/HoneyDrunk.Flow.Providers.InMemory/` — `InMemoryWorkflowStateStore`
- `.github/workflows/*.yml`
- `README.md`, `CHANGELOG.md`
- `tests/`

**Contracts:** Five D3 interfaces authored fresh.
