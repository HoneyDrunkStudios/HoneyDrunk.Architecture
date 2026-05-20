---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Sim
labels: ["feature", "tier-2", "ai", "scaffold", "adr-0025", "new-node"]
dependencies: ["packet:01", "packet:02", "packet:03"]
adrs: ["ADR-0025", "ADR-0016", "ADR-0024", "ADR-0023"]
accepts: ADR-0025
wave: 3
initiative: adr-0025-sim-standup
node: honeydrunk-sim
---

# Feature: Stand up the HoneyDrunk.Sim repo — solution, three packages, six surfaces, CI, InMemory provider

## Summary

Bring the newly-created `HoneyDrunk.Sim` repo from zero to first-shippable per ADR-0025. Land solution, three packages (`Abstractions`, runtime, `Providers.InMemory` scenario-execution backend), six D3 surfaces in Abstractions (three interfaces + three records), default `ISimulator` + `IPlanValidator` + `ISimulationTarget` chat-backed shape with router-bypass per D8, reproducibility primitives per D7 (seed, deterministic-vs-non-deterministic flag), observation-only Operator composition per D9, fixture composition with Memory + Knowledge `Providers.InMemory` per D11, `Providers.InMemory` scenario-execution backend, standard CI, contract-shape canary scoped to Abstractions per D13 (number assigned by packet 02).

**Closes the AI-sector stand-up wave** — Sim is the ninth and final standup of the wave.

Unblocks Flow (workflow-dry-run scenarios), Agents (agent-plan scenarios), Lore, HoneyHub when live, application Nodes with commit-to-real-execution gates.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Sim`

## Motivation

ADR-0025 establishes Sim's contract surface. Repo created in packet 03 (LICENSE + README only).

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Sim/
├── HoneyDrunk.Sim.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── .editorconfig
├── .gitignore
├── .github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml
├── src/
│   ├── HoneyDrunk.Sim.Abstractions/
│   │   ├── HoneyDrunk.Sim.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ISimulator.cs
│   │   ├── IPlanValidator.cs
│   │   ├── ISimulationTarget.cs
│   │   ├── Scenario.cs
│   │   ├── RiskAssessment.cs
│   │   └── SimulationResult.cs
│   ├── HoneyDrunk.Sim/
│   │   ├── HoneyDrunk.Sim.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs
│   │   ├── Orchestration/DefaultSimulator.cs
│   │   ├── Validation/DefaultPlanValidator.cs
│   │   ├── Targets/ChatTarget.cs                       (D8 router-bypass)
│   │   ├── ObserverPrediction/SafetyFilterPredictor.cs (D9 observation-only)
│   │   ├── ObserverPrediction/CostGuardPredictor.cs    (D9 observation-only)
│   │   ├── ObserverPrediction/ApprovalGatePredictor.cs (D9 observation-only)
│   │   ├── FixtureComposition/MemoryFixtureLoader.cs    (D11 — composes Memory.Providers.InMemory)
│   │   ├── FixtureComposition/KnowledgeFixtureLoader.cs (D11 — composes Knowledge.Providers.InMemory)
│   │   ├── Reproducibility/SeededRng.cs                 (D7)
│   │   └── Telemetry/SimTelemetry.cs                    (D10 metadata-only)
│   └── HoneyDrunk.Sim.Providers.InMemory/
│       ├── HoneyDrunk.Sim.Providers.InMemory.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       └── InMemoryScenarioExecutor.cs
└── tests/
    ├── HoneyDrunk.Sim.Abstractions.Tests/
    ├── HoneyDrunk.Sim.Tests/
    └── HoneyDrunk.Sim.Providers.InMemory.Tests/
```

### Contract details — `HoneyDrunk.Sim.Abstractions`

```csharp
// ISimulator.cs
namespace HoneyDrunk.Sim.Abstractions;

public interface ISimulator
{
    Task<SimulationResult> SimulateAsync(Scenario scenario, ISimulationTarget target, CancellationToken cancellationToken = default);
}
```

```csharp
// IPlanValidator.cs
public interface IPlanValidator
{
    Task<PlanValidationResult> ValidateAsync(Scenario scenario, ISimulationTarget target, CancellationToken cancellationToken = default);
}

public sealed record PlanValidationResult(SimulationResult Simulation, RiskAssessment RiskAssessment, PlanVerdict Verdict);
public enum PlanVerdict { Go = 0, NoGo = 1, RequiresApproval = 2 }
```

```csharp
// ISimulationTarget.cs (D8 router-bypass)
public interface ISimulationTarget
{
    string TargetId { get; }
    string TargetKind { get; }                              // "chat", "workflow", "agent", "retrieval", "transcript-replay"
    string? PinnedModelCapabilityIdentifier { get; }        // D8 — non-null when target pins a model
    bool IsDeterministic { get; }                            // D7 — non-deterministic targets flagged
    Task<TargetInvocationResult> InvokeAsync(SimulationStepInput input, CancellationToken cancellationToken = default);
}

public sealed record SimulationStepInput(string ScenarioId, string StepId, string InputJson, long Seed);
public sealed record TargetInvocationResult(string OutputJson, IReadOnlyDictionary<string, string> Metadata);
```

```csharp
// Scenario.cs (record — no I prefix)
public sealed record Scenario(
    string ScenarioId,
    string ScenarioVersion,
    string InitialStateFixtureJson,
    IReadOnlyList<ProposedAction> ProposedActions,
    IReadOnlyDictionary<string, string> Constraints,
    IReadOnlyDictionary<string, string> Tags);

public sealed record ProposedAction(string ActionId, string ActionKind, string PayloadJson);
```

```csharp
// RiskAssessment.cs (record — no I prefix)
public sealed record RiskAssessment(
    IReadOnlyList<RiskFailureMode> IdentifiedFailureModes,
    double ConfidenceLevel,
    double AggregateSeverity);

public sealed record RiskFailureMode(string ModeId, string Description, double Probability, string? Mitigation);
```

```csharp
// SimulationResult.cs (record — no I prefix; D12)
public sealed record SimulationResult(
    string ResultId,
    string ScenarioId,
    string ScenarioVersion,
    string TargetId,
    string? PinnedModelCapabilityIdentifier,
    long ReproducibilitySeed,                          // D7
    DateTimeOffset StartedAt,
    DateTimeOffset CompletedAt,
    string ProjectedOutcomeJson,
    IReadOnlyList<SimulationStepTrace> StepTrace,
    ObservedOperatorPredictions OperatorObservations,   // D9
    RiskAssessment RiskAssessment,
    bool ContainsNonDeterministicSteps);

public sealed record SimulationStepTrace(string StepId, string TargetId, string OutputJson, TimeSpan Duration, bool IsDeterministic);

public sealed record ObservedOperatorPredictions(
    bool? PredictedSafetyFilterFiring,
    string? PredictedSafetyFilterRule,
    decimal? PredictedCostMarker,
    bool? PredictedCostThresholdCrossing,
    bool? PredictedApprovalRequired,
    string? PredictedPauseLocation);
```

`HoneyDrunk.Sim.Abstractions` references **`HoneyDrunk.Flow.Abstractions`** per D5 (compile-time, accepted for read-only consumption of `IWorkflow`/`IWorkflowStep` shapes in concrete `WorkflowTarget` when scaffolded — first-pass shape may not actually need this if `WorkflowTarget` is deferred). If the executing agent can keep Flow out of Abstractions surface signatures (defer `WorkflowTarget` shape), prefer that. **Does NOT** reference `HoneyDrunk.Operator.Abstractions` or `HoneyDrunk.Memory.Abstractions` per D2 — those are runtime-only edges per the Sim Abstractions-stays-clean invariant (default 91).

**Strict Abstractions stance.** Identity / capability / correlation fields are `string`. Records first-pass.

**Deliberate stand-up simplification — stringly-typed JSON payloads.** `SimulationStepInput.InputJson`, `TargetInvocationResult.OutputJson`, `Scenario.InitialStateFixtureJson`, `SimulationResult.ProjectedOutcomeJson`, and `SimulationStepTrace.OutputJson` are all `string` (raw JSON) at stand-up. This is intentional — the structure of these payloads depends on the concrete `ISimulationTarget` shape (chat, workflow, agent, retrieval), none of which exist beyond `ChatTarget` at stand-up. Once `WorkflowTarget`, `AgentTarget`, and `RetrievalTarget` crystallize, a follow-up packet introduces structured payload records and a generic discriminator on the interface. Do not bake structured payload types in at stand-up.

### Runtime details — `HoneyDrunk.Sim`

`HoneyDrunk.Sim` references (Abstractions only per ADR-0025 D2 and `consumes_detail` in catalog packet 01 — never runtime packages of other Nodes):
- `HoneyDrunk.Sim.Abstractions` (project)
- `HoneyDrunk.Kernel.Abstractions` (telemetry, context)
- `HoneyDrunk.AI.Abstractions` (`IChatClient`, `IModelProvider`, `ModelCapabilityDeclaration` for `ChatTarget` per D8)
- `HoneyDrunk.Flow.Abstractions` (runtime — only if scaffolding agent ships a `WorkflowTarget`; otherwise defer; read-only `IWorkflow`/`IWorkflowStep` per D5)
- `HoneyDrunk.Operator.Abstractions` (`ISafetyFilter`, `ICostGuard`, `IApprovalGate` per D9 — observation-only)
- `HoneyDrunk.Memory.Abstractions` + `HoneyDrunk.Memory.Providers.InMemory` (Abstractions for typing, `Providers.InMemory` for fixture composition per D11)
- `HoneyDrunk.Knowledge.Abstractions` + `HoneyDrunk.Knowledge.Providers.InMemory` (Abstractions for typing, `Providers.InMemory` for fixture composition per D11)
- `Microsoft.Extensions.*`

Implementations:

- **`DefaultSimulator`** — orchestrates: loads scenario fixtures via `MemoryFixtureLoader` + `KnowledgeFixtureLoader` (D11), invokes target per step, predicts Operator behavior via the three predictor classes (D9), builds `SimulationResult` with full provenance (D12) and reproducibility seed (D7).
- **`DefaultPlanValidator`** — composes `DefaultSimulator` internally, runs simulation, evaluates risk via aggregating failure modes, returns `PlanValidationResult` with go/no-go/requires-approval verdict.
- **`ChatTarget`** — wraps `IChatClient`. When `PinnedModelCapabilityIdentifier` non-null, resolves `IModelProvider` directly for that capability (router-bypass per D8). Pinning recorded on `SimulationResult`.
- **`SafetyFilterPredictor` / `CostGuardPredictor` / `ApprovalGatePredictor`** — invoke the respective Operator primitive in a way that records *what it would do* without producing enforcement-side effects. Implementation note: predictor classes call the primitive's read/check method (e.g. `ISafetyFilter.CheckAsync`) which is by nature non-mutating; the prediction is just observing the result and recording it on `ObservedOperatorPredictions`.
- **`MemoryFixtureLoader` / `KnowledgeFixtureLoader`** — at simulation start, composes `Providers.InMemory` with the scenario's fixture state. Discards at simulation end. Per D11, never touches production backends.
- **`SeededRng`** — deterministic RNG instance keyed by `SimulationResult.ReproducibilitySeed`. Used everywhere randomness is needed (target selection, scenario-step ordering when applicable). When a target is non-deterministic (e.g. live `IChatClient` without seed), the simulation marks `ContainsNonDeterministicSteps: true`.
- **`SimTelemetry`** — emits per-lifecycle / per-step-trace / per-risk-aggregate activities. **Metadata only** per D10 — no scenario input, target output, or projected payload content in tags.

### Providers.InMemory details

`InMemoryScenarioExecutor` — in-process scenario-execution backend. Direct implementation of `ISimulator` (and optionally `IPlanValidator`) against `HoneyDrunk.Sim.Abstractions` only. It does NOT reference or compose the `HoneyDrunk.Sim` runtime package — that would create a `Providers.InMemory` → runtime edge in violation of the layout (line 245 below). Implementation reproduces the minimum mechanics needed for a deterministic, in-memory scenario walk: iterate over `Scenario.ProposedActions`, invoke `ISimulationTarget.InvokeAsync` per step against a seeded RNG, accumulate `SimulationStepTrace` entries, build a `SimulationResult`. Side-effect-free by construction. The full-featured `DefaultSimulator` (with Operator-observation predictors, Memory + Knowledge fixture composition, etc.) lives in `HoneyDrunk.Sim`; `InMemoryScenarioExecutor` is a smaller, Abstractions-only alternative suitable for tests and seed runs.

### CI workflows

Five files; `api-compatibility.yml` path-filtered to `src/HoneyDrunk.Sim.Abstractions/**`.

### `HoneyDrunk.Standards`

Per invariant 26.

### Documentation

Repo README — purpose, package matrix, "How to consume" snippet with `AddHoneyDrunkSim()` + `AddChatTarget()` example, link to ADR-0025. Note side-effect-freedom (D6), router-bypass via `ISimulationTarget` (D8 — and the parallel-but-distinct relationship to `IEvalTarget`), closing-of-the-wave milestone. Per-package README + CHANGELOG.

## Affected Files
Entire repo. See layout.

## NuGet Dependencies

### `HoneyDrunk.Sim.Abstractions.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Flow.Abstractions` | **Conditional** — only if `WorkflowTarget` lands in this packet and needs `IWorkflow`/`IWorkflowStep` shapes on a public member signature. Prefer deferring. |

**No** `HoneyDrunk.Operator.Abstractions`. **No** `HoneyDrunk.Memory.Abstractions`. Per the Sim Abstractions-stays-clean invariant (default 91).

### `HoneyDrunk.Sim.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | Telemetry, context |
| `HoneyDrunk.AI.Abstractions` | `IChatClient`, `IModelProvider`, `ModelCapabilityDeclaration` for ChatTarget per D8 |
| `HoneyDrunk.Flow.Abstractions` | Only if `WorkflowTarget` ships in this packet — read-only `IWorkflow` / `IWorkflowStep` per D5 |
| `HoneyDrunk.Operator.Abstractions` | `ISafetyFilter`, `ICostGuard`, `IApprovalGate` per D9 — observation-only |
| `HoneyDrunk.Memory.Abstractions` + `HoneyDrunk.Memory.Providers.InMemory` | Abstractions for typing, `Providers.InMemory` for fixture composition per D11 |
| `HoneyDrunk.Knowledge.Abstractions` + `HoneyDrunk.Knowledge.Providers.InMemory` | Abstractions for typing, `Providers.InMemory` for fixture composition per D11 |
| `Microsoft.Extensions.*` | |

Project reference: `HoneyDrunk.Sim.Abstractions`.

### `HoneyDrunk.Sim.Providers.InMemory.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

Project reference: `HoneyDrunk.Sim.Abstractions`. **No reference to runtime / Kernel / AI / Operator / Memory / Knowledge.**

### Test projects: standard + NSubstitute.

## Boundary Check
- [x] `HoneyDrunk.Sim.Abstractions` references at most `HoneyDrunk.Flow.Abstractions` (and only conditionally per WorkflowTarget). No Operator, no Memory references. Sim Abstractions-stays-clean invariant (default 91).
- [x] `Providers.InMemory` references only Abstractions.
- [x] Side-effect-freedom: `ISimulator.SimulateAsync` does not take writer surfaces; runtime composes `Providers.InMemory` not production stores. Sim side-effect-freedom invariant (default 84).
- [x] Sim consumes `IWorkflow` read-only — no `IWorkflowEngine.StartAsync` invocation. Sim read-only-IWorkflow invariant (default 85).
- [x] Operator primitives observation-only — never trip a breaker, write to `IAuditLog`, or block a real output. Sim observation-only invariant (default 86).
- [x] Router-bypass only via `ISimulationTarget`. Sim router-bypass invariant (default 87).
- [x] `SimulationResult` provenance fields populated on every report. Sim provenance invariant (default 88).
- [x] Memory + Knowledge fixture composition via `Providers.InMemory` only. Sim fixture-composition invariant (default 89).
- [x] Telemetry metadata-only — no content payloads. Sim telemetry-metadata-only invariant (default 90).
- [x] Records drop `I`; interfaces keep it.
- [x] `ISimulationTarget` does NOT extend or share `IEvalTarget` from Evals.
- [x] Verify `IModelProvider` exposes a public capability-resolution method usable from `HoneyDrunk.Sim` outside `HoneyDrunk.AI` runtime — `ChatTarget` is the first cross-Node consumer of `IModelProvider`. If `HoneyDrunk.AI.Abstractions` does not expose a public capability-resolution surface usable by `ChatTarget`, file a follow-up packet against `HoneyDrunk.AI` to widen the public surface before completing this packet's `ChatTarget` implementation.

## Acceptance Criteria
- [ ] `HoneyDrunk.Sim.slnx` builds clean.
- [ ] Six D3 surfaces present with XML docs.
- [ ] `HoneyDrunk.Sim.Abstractions` has zero `HoneyDrunk.Operator.Abstractions` and zero `HoneyDrunk.Memory.Abstractions` PackageReference. `HoneyDrunk.Flow.Abstractions` reference is conditional (only if `WorkflowTarget` ships here). `grep -rn` over `.csproj` verifies.
- [ ] `Providers.InMemory` references only `HoneyDrunk.Sim.Abstractions`.
- [ ] `AddHoneyDrunkSim()` resolves `ISimulator`, `IPlanValidator`, the three predictors, the two fixture loaders.
- [ ] `DefaultSimulator.SimulateAsync` produces a `SimulationResult` with all provenance fields populated (`ScenarioId`, `ScenarioVersion`, `TargetId`, `PinnedModelCapabilityIdentifier` if applicable, `ReproducibilitySeed`, `StartedAt`/`CompletedAt`, `OperatorObservations`). Unit test verifies all fields non-null/non-default.
- [ ] **`ISimulator.SimulateAsync` does NOT take `IMemoryStore`, `ICommunicationOrchestrator`, `IWorkflowEngine`, or `IAuditLog` as parameters.** Verified by inspecting the interface signature.
- [ ] `ChatTarget` with non-null `PinnedModelCapabilityIdentifier` resolves `IModelProvider` directly (router-bypass per D8) and the identifier is recorded on `SimulationResult`. Unit test verifies.
- [ ] Predictor classes call only Operator surfaces documented as non-mutating per ADR-0018 — verify by reading Operator's contract XML docs or runtime behavior. If any Operator surface used by a predictor is mutating (writes to `IAuditLog`, trips a breaker, or otherwise alters Operator state as part of its `CheckAsync` / equivalent), file a follow-up packet against `HoneyDrunk.Operator` to add a non-mutating predicate variant (e.g., `WouldBlock` / `WouldHalt` / `WouldRequireApproval`) before completing the predictor implementation.
- [ ] `SafetyFilterPredictor`, `CostGuardPredictor`, `ApprovalGatePredictor` produce observation results without modifying Operator state (no writes to `IAuditLog`, no breaker trips, no actual safety blocks). Unit tests verify observation-only via mocks that assert no mutating calls were made.
- [ ] `MemoryFixtureLoader` and `KnowledgeFixtureLoader` compose `Providers.InMemory` only — verified by mocking + ensuring no production-store interface is touched. Unit tests verify.
- [ ] `SeededRng` produces deterministic output given the same seed. Unit test runs same scenario+seed twice and confirms identical `SimulationResult.ProjectedOutcomeJson`.
- [ ] `SimTelemetry` emits per-lifecycle / per-step / per-risk activities. **Activity tags / attributes contain only metadata.** Unit test asserts no scenario/target/projection payload content in any activity.
- [ ] `InMemoryScenarioExecutor` produces deterministic simulation results given a seeded scenario. Unit test verifies.
- [ ] All five `.github/workflows/*.yml` files present.
- [ ] `api-compatibility.yml` path-filtered; scaffolding PR reports `status: skipped`.
- [ ] `pr-core.yml` passes.
- [ ] Repo + per-package `CHANGELOG.md` + `README.md` present. Repo README notes Sim closes the AI-sector wave.
- [ ] All `src/*.csproj` Version 0.1.0.
- [ ] Manual confirmation `v0.1.0` tag triggers `release.yml`.
- [ ] **No concrete `WorkflowTarget`, `AgentTarget`, `RetrievalTarget`, `MemoryTarget` in this packet** unless trivially decidable. `ChatTarget` only. Concrete others ship in follow-up packets.
- [ ] **No Monte Carlo / N-trial distribution surface.**
- [ ] **No production scenario-execution backend.**
- [ ] **`ISimulationTarget` does NOT extend or share `IEvalTarget`.** `grep -rn "IEvalTarget" src/` returns zero matches.

## Human Prerequisites
- [ ] Packet 03 complete — repo exists, cloned, settings verified.
- [ ] After merge, push tag `v0.1.0`.
- [ ] **Upstream Abstractions check.** AI mandatory; Flow conditional (only if `WorkflowTarget` ships); Operator + Memory + Knowledge runtime-mandatory. Placeholder no-ops + follow-up packets for any missing.
- [ ] **Branch protection sequencing.** Add `api-compatibility / abstractions-shape` to required checks post-merge.
- [ ] No Azure provisioning required.
- [ ] After merge + tag, file SonarCloud onboarding follow-up.
- [ ] File concrete `ISimulationTarget` shape packets (`WorkflowTarget`, `AgentTarget`, `RetrievalTarget`, transcript-replay) as downstream consumers drive shape.
- [ ] **After this packet ships**, complete the wave-closing housekeeping board item tracked in `dispatch-plan.md` — update `initiatives/active-initiatives.md`, update `constitution/ai-sector-architecture.md`, run the AI-sector-wide site sync covering ADR-0016 through ADR-0025, and file the structured-payload-records follow-up packet plus the concrete `ISimulationTarget` shape packets. These are explicitly out of scope for the scaffold packet itself — the executing agent in `HoneyDrunk.Sim` does not touch the Architecture repo.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages, except where another `*.Abstractions` package is the cleanest way to type a member signature (Flow Abstractions permitted conditionally).

> **Invariant 3:** Providers reference parent Node's contracts, not internal implementation details.

> **Invariant 11:** One repo per Node.

> **Invariant 12, 13, 26, 27.** Standard.

> **Sim downstream-coupling invariant (default 83):** Runtime-depend only on Abstractions.

> **Sim side-effect-freedom invariant (default 84):** If it writes to any Grid-durable surface, it is not Sim.

> **Sim read-only-IWorkflow invariant (default 85):** Sim consumes `IWorkflow`/`IWorkflowStep` read-only; never `IWorkflowEngine`.

> **Sim observation-only invariant (default 86):** Operator primitives composed observation-only.

> **Sim router-bypass invariant (default 87):** Bypass only via `ISimulationTarget`.

> **Sim provenance invariant (default 88):** Every `SimulationResult` records full provenance.

> **Sim fixture-composition invariant (default 89):** Memory + Knowledge fixtures via `Providers.InMemory` only.

> **Sim telemetry-metadata-only invariant (default 90):** Memory/Knowledge rule, not Evals's carve-out.

> **Sim Abstractions-stays-clean invariant (default 91):** No Operator / Memory deps in Abstractions.

> **Sim contract-shape canary invariant (default 92):** Canary on `ISimulator`, `IPlanValidator`, `ISimulationTarget`, `SimulationResult`.

## Referenced ADR Decisions

**ADR-0025 D1:** Simulation + plan-evaluation substrate. Closing Node of the AI-sector standup wave.

**ADR-0025 D2:** Three packages — Abstractions + runtime + Providers.InMemory.

**ADR-0025 D3:** Six surfaces — three interfaces + three records.

**ADR-0025 D5:** Flow consumption is compile-time, read-only of `IWorkflow`/`IWorkflowStep`.

**ADR-0025 D6:** Side-effect-freedom is the Sim-Evals boundary primitive.

**ADR-0025 D7:** Reproducibility seed on every `SimulationResult`.

**ADR-0025 D8:** Router bypass via `ISimulationTarget`. Parallel to Evals's `IEvalTarget` but distinct type.

**ADR-0025 D9:** Operator composition as observation-only prediction inputs.

**ADR-0025 D10:** Telemetry metadata-only (no Evals-style carve-out).

**ADR-0025 D11:** Fixture composition via Memory + Knowledge `Providers.InMemory`.

**ADR-0025 D12:** `SimulationResult` full provenance.

**ADR-0025 D13:** Canary on four hot-path surfaces.

**ADR-0023 D6 (referenced, parallel pattern):** Evals's `IEvalTarget` is the analog of `ISimulationTarget` — same shape, different types.

**ADR-0024 D4/D6 (referenced):** Flow's side of "Sim consumes IWorkflow read-only" edge.

**ADR-0016 D3 (referenced):** `IChatClient`, `IModelProvider`, `ModelCapabilityDeclaration` from AI.

## Dependencies
- `packet:01`, `packet:02`, `packet:03`

## Labels
`feature`, `tier-2`, `ai`, `scaffold`, `adr-0025`, `new-node`

## Agent Handoff

**Objective:** Ship `HoneyDrunk.Sim 0.1.0` with the six D3 surfaces, default runtime composing AI / Flow / Operator / Memory / Knowledge runtime edges (Memory + Knowledge via Providers.InMemory only), `Providers.InMemory` scenario-execution backend, CI, canary. **Close the AI-sector standup wave.**

**Target:** HoneyDrunk.Sim, branch from `main`.

**Constraints:**
- **`HoneyDrunk.Sim.Abstractions` does NOT reference `HoneyDrunk.Operator.Abstractions` or `HoneyDrunk.Memory.Abstractions`.** Sim Abstractions-stays-clean invariant (default 91).
- **Conditional Flow Abstractions reference.** Only if `WorkflowTarget` ships in this packet. Prefer to defer WorkflowTarget to follow-up — keep Sim Abstractions HoneyDrunk-free.
- **Side-effect-freedom is non-negotiable.** `ISimulator.SimulateAsync` does not take writer parameters. Runtime composes `Providers.InMemory` of Memory + Knowledge, never production backends. Operator primitives invoked observation-only.
- **`ISimulationTarget` does NOT extend or share `IEvalTarget`.** Parallel shape, distinct type, no Sim→Evals coupling.
- **Provenance fields on every `SimulationResult`.** ScenarioId, ScenarioVersion, TargetId, PinnedModelCapabilityIdentifier (if applicable), ReproducibilitySeed, timestamps.
- **Reproducibility:** every simulation uses `SeededRng` keyed by `SimulationResult.ReproducibilitySeed`. Non-deterministic targets flagged on `ContainsNonDeterministicSteps`.
- **Telemetry metadata-only.** No content payloads.
- **Records drop `I`; interfaces keep it.** `Scenario`, `RiskAssessment`, `SimulationResult`, `SimulationStepInput`, `TargetInvocationResult`, `ObservedOperatorPredictions`, `RiskFailureMode`, `ProposedAction`, `PlanValidationResult`, `SimulationStepTrace` are records.
- **Strict Abstractions stance.** `string` identifiers throughout.
- **Stringly-typed JSON payloads are deliberate.** `*Json` fields (`InputJson`, `OutputJson`, `InitialStateFixtureJson`, `ProjectedOutcomeJson` on records) stay `string` at stand-up. Structured payload records land in a follow-up packet once concrete `ISimulationTarget` shapes crystallize. Do not introduce structured payload types in this packet.
- **First cross-Node `IModelProvider` consumer.** `ChatTarget` is the first consumer of `IModelProvider` from outside `HoneyDrunk.AI`. If `HoneyDrunk.AI.Abstractions` does not expose a public capability-resolution surface usable by `ChatTarget`, file a follow-up packet against `HoneyDrunk.AI` to widen the public surface before completing `ChatTarget`.
- **Predictors call only non-mutating Operator surfaces.** If any Operator surface used by a predictor turns out to be mutating in practice (writes to `IAuditLog`, trips a breaker), file a follow-up packet against `HoneyDrunk.Operator` to add a non-mutating predicate variant (`WouldBlock` / `WouldHalt` / `WouldRequireApproval`) before completing the predictor implementation.
- **`InMemoryScenarioExecutor` implements `ISimulator` directly against Abstractions.** It does NOT reference or compose the `HoneyDrunk.Sim` runtime package — `Providers.InMemory` is Abstractions-only by layout rule.
- **Canary skip on scaffolding PR expected.**
- **Upstream conditional.** AI mandatory; others placeholder if missing.
- **Closing-of-the-wave note in repo README.**

**Key Files:**
- `HoneyDrunk.Sim.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Sim.Abstractions/` — 3 interfaces + 3 records + supporting records
- `src/HoneyDrunk.Sim/` — `DefaultSimulator`, `DefaultPlanValidator`, `ChatTarget`, predictor classes, fixture loaders, `SeededRng`, `SimTelemetry`, `ServiceCollectionExtensions`
- `src/HoneyDrunk.Sim.Providers.InMemory/` — `InMemoryScenarioExecutor`
- `.github/workflows/*.yml`
- `README.md`, `CHANGELOG.md`
- `tests/`

**Contracts:** Six D3 surfaces authored fresh. Closes the AI-sector wave.
