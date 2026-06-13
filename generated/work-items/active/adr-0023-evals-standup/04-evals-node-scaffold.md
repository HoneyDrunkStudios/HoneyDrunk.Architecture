---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Evals
labels: ["feature", "tier-2", "ai", "scaffold", "adr-0023", "new-node"]
dependencies: ["work-item:01", "work-item:02", "work-item:03"]
adrs: ["ADR-0023", "ADR-0016", "ADR-0018"]
accepts: ADR-0023
wave: 3
initiative: adr-0023-evals-standup
node: honeydrunk-evals
---

# Feature: Stand up the HoneyDrunk.Evals repo — solution, three packages, six surfaces, CI, InMemory provider

## Summary

Bring the newly-created `HoneyDrunk.Evals` repo from zero to first-shippable per ADR-0023. Land the solution, three packages (`Abstractions`, runtime, `Providers.InMemory`), six D3 surfaces in `HoneyDrunk.Evals.Abstractions` (four interfaces + two records), default runtime implementations including a `ChatTarget` shape with the router-bypass primitive per D6, a default `IEvalScorer` set (rubric scorers + model-as-judge scorer composing `IChatClient`), Operator-composition observation-only scoring per D7, `Providers.InMemory` backend for `EvalReport` persistence + suite fixtures, the standard CI pipeline, and the contract-shape canary scoped to Abstractions per D14 (number assigned by packet 02).

Unblocks Agents (agent-behavior suites), Knowledge (retrieval-quality suites), Memory (memory-workflow suites), Flow (workflow-level suites), Sim, Lore, HoneyHub when live.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Evals`

## Motivation

ADR-0023 establishes Evals's contract surface. Repo created in packet 03 (LICENSE + README only). Seven downstream consumers blocked.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Evals/
├── HoneyDrunk.Evals.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── .editorconfig
├── .gitignore
├── .github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml
├── src/
│   ├── HoneyDrunk.Evals.Abstractions/
│   │   ├── HoneyDrunk.Evals.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IEvaluator.cs
│   │   ├── IEvalScorer.cs
│   │   ├── IEvalSuite.cs
│   │   ├── IEvalTarget.cs
│   │   ├── EvalCase.cs
│   │   └── EvalReport.cs
│   ├── HoneyDrunk.Evals/
│   │   ├── HoneyDrunk.Evals.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs
│   │   ├── Orchestration/DefaultEvaluator.cs
│   │   ├── Targets/ChatTarget.cs              (D6 router-bypass primitive)
│   │   ├── Scoring/AutomatedRubricScorer.cs
│   │   ├── Scoring/ModelAsJudgeScorer.cs       (composes IChatClient)
│   │   ├── ObserverScoring/SafetyFilterObserver.cs    (D7 observation-only)
│   │   ├── ObserverScoring/CostGuardObserver.cs       (D7 observation-only)
│   │   ├── ObserverScoring/AuditLogObserver.cs        (D7 observation-only)
│   │   └── Telemetry/EvalsTelemetry.cs                 (D10 content carve-out)
│   └── HoneyDrunk.Evals.Providers.InMemory/
│       ├── HoneyDrunk.Evals.Providers.InMemory.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── InMemoryReportStore.cs                       (EvalReport persistence)
│       └── InMemorySuiteRepository.cs                   (suite fixture persistence)
└── tests/
    ├── HoneyDrunk.Evals.Abstractions.Tests/
    ├── HoneyDrunk.Evals.Tests/
    └── HoneyDrunk.Evals.Providers.InMemory.Tests/
```

### Contract details — `HoneyDrunk.Evals.Abstractions`

```csharp
// IEvaluator.cs
namespace HoneyDrunk.Evals.Abstractions;

public interface IEvaluator
{
    Task<EvalReport> RunAsync(IEvalSuite suite, IEvalTarget target, IReadOnlyList<IEvalScorer> scorers, CancellationToken cancellationToken = default);
}
```

```csharp
// IEvalScorer.cs
public interface IEvalScorer
{
    string ScorerName { get; }
    bool IsDeterministic { get; }
    Task<EvalScore> ScoreAsync(EvalCase testCase, string targetOutput, CancellationToken cancellationToken = default);
}

public sealed record EvalScore(string ScorerName, double Score, string? Detail, IReadOnlyDictionary<string, string> Tags);
```

```csharp
// IEvalSuite.cs
public interface IEvalSuite
{
    string SuiteId { get; }
    string SuiteVersion { get; }

    /// <summary>
    /// D10 carve-out flag. <c>true</c> means eval-signal telemetry strips content (metadata only);
    /// <c>false</c> means content (case inputs, target outputs) MAY ride on telemetry payloads.
    /// </summary>
    /// <remarks>
    /// Follow-up: this boolean is intentionally first-pass (S1). It is expected to evolve to an enum
    /// (e.g. <c>SensitivityClassification</c> with values None / PII / Regulated / Internal-Only) once a
    /// downstream consumer drives a concrete need for graded sensitivity. The contract-shape canary
    /// scoped to <c>IEvalSuite</c> per D14 will catch the shape drift on that evolution and require a
    /// version bump.
    /// </remarks>
    bool IsSensitive { get; }
    Task<IReadOnlyList<EvalCase>> GetCasesAsync(CancellationToken cancellationToken = default);
    Task<RubricSpec> GetRubricAsync(CancellationToken cancellationToken = default);
}

public sealed record RubricSpec(IReadOnlyList<string> RequiredScorers, IReadOnlyDictionary<string, double> ScorerWeights);
```

```csharp
// IEvalTarget.cs (D6 router-bypass)
using HoneyDrunk.AI.Abstractions;        // ModelCapabilityDeclaration — per ADR-0023 D2 / D5

public interface IEvalTarget
{
    string TargetId { get; }
    ModelCapabilityDeclaration? PinnedModelCapability { get; }    // D6 — non-null when target pins a model. Typed reference into AI's contract.
    Task<string> InvokeAsync(EvalCase testCase, CancellationToken cancellationToken = default);
}
```

```csharp
// EvalCase.cs (record)
using HoneyDrunk.Kernel.Abstractions;      // TenantId strong type — per ADR-0026 multi-tenant alignment

public sealed record EvalCase
{
    public required string CaseId { get; init; }
    public required string SuiteVersion { get; init; }
    public required string InputJson { get; init; }
    public string? ExpectedOutputJson { get; init; }
    public string? RubricCriteriaJson { get; init; }
    public required IReadOnlyDictionary<string, string> Tags { get; init; }

    // I3 — strong-typed multi-tenant identity per ADR-0026. Defaults to TenantId.Internal so a single-tenant suite
    // does not need to plumb it. Carried onto the case so per-tenant regression analysis (e.g. "did model X regress
    // on tenant Y's suite but not tenant Z's") is expressible without rebinding cases between tenants.
    public TenantId TenantId { get; init; } = TenantId.Internal;
}
```

```csharp
// EvalReport.cs (record — D12 / D13)
using HoneyDrunk.AI.Abstractions;          // ModelCapabilityDeclaration — per ADR-0023 D2 / D5
using HoneyDrunk.Kernel.Abstractions;      // TenantId strong type — per ADR-0026 multi-tenant alignment

public sealed record EvalReport
{
    public required string ReportId { get; init; }
    public required string SuiteId { get; init; }
    public required string SuiteVersion { get; init; }
    public required string TargetId { get; init; }

    // D6 — when the target pinned a model, capture the typed declaration on the report. Null when no pin was applied.
    public ModelCapabilityDeclaration? PinnedModelCapability { get; init; }

    // I3 — strong-typed multi-tenant identity per ADR-0026. Defaults to TenantId.Internal so single-tenant callers do not need to plumb it.
    public TenantId TenantId { get; init; } = TenantId.Internal;

    public required DateTimeOffset StartedAt { get; init; }
    public required DateTimeOffset CompletedAt { get; init; }
    public required IReadOnlyList<string> ScorerSet { get; init; }
    public required IReadOnlyList<EvalCaseResult> CaseResults { get; init; }
    public required EvalReportSummary Summary { get; init; }
}

public sealed record EvalCaseResult(string CaseId, string TargetOutput, IReadOnlyList<EvalScore> Scores, ObservedOperatorPrediction? OperatorObservations);

public sealed record EvalReportSummary(double AggregateScore, int CaseCount, int PassedCount, int FailedCount);

/// <summary>
/// Observation-only Operator signals captured during a case run (D7).
/// Each property is nullable to distinguish two distinct states:
///   - <c>null</c> means the corresponding observer was not wired into the host's composition (e.g. Operator unavailable, observer not registered, or this target did not flow through that signal path).
///   - non-null means the observer ran and recorded the value (including <c>false</c> / <c>0</c> as a meaningful observation).
/// </summary>
/// <param name="SafetyFilterFired">
/// <c>true</c> when <see cref="ISafetyFilter"/> would have fired on the target output; <c>false</c> when it ran and did not fire; <c>null</c> when the safety-filter observer was not wired.
/// </param>
public sealed record ObservedOperatorPrediction(bool? SafetyFilterFired, decimal? CostMarker, bool? ApprovalWouldBeRequired);
```

`HoneyDrunk.Evals.Abstractions` references `Microsoft.Extensions.*` abstractions plus two Abstractions packages that ADR-0023 D2 explicitly permits: `HoneyDrunk.Kernel.Abstractions` (for the `TenantId` strong type per I3 / ADR-0026) and `HoneyDrunk.AI.Abstractions` (for `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, and `ModelCapabilityDeclaration` — see D2 line 59 and D5). The transitive compile-time edge into `HoneyDrunk.AI.Abstractions` is accepted and matches the pattern ADR-0020 D5 / ADR-0021 D5 / ADR-0022 D5 established for prior AI-sector stand-ups. Invariant 1 (no runtime dependencies on non-Abstractions HoneyDrunk packages) is satisfied — only the upstream `Abstractions` siblings are referenced, never `HoneyDrunk.Kernel`, `HoneyDrunk.AI`, or any runtime package.

**Typed identity stance.** `IEvalTarget.PinnedModelCapability` is typed (`ModelCapabilityDeclaration?`) per D6. `EvalReport.PinnedModelCapability` is typed (`ModelCapabilityDeclaration?`) per D12 + D6. Multi-tenant fields on `EvalReport` and `EvalCase` use the strong `TenantId` from Kernel.Abstractions per ADR-0026 — string-typing those would cost the cross-Node strong-typing pattern.

**First-pass shape.** Member sets subject to evolution before v0.2.0 baseline lock. Canary catches breaking changes.

### Runtime details — `HoneyDrunk.Evals`

`HoneyDrunk.Evals` references:
- `HoneyDrunk.Evals.Abstractions` (project)
- `HoneyDrunk.Kernel` (telemetry, context)
- `HoneyDrunk.AI` (`IChatClient` for `ChatTarget` + model-as-judge scorer; `IModelProvider` + `ModelCapabilityDeclaration` for `ChatTarget` pinning per D6)
- `HoneyDrunk.Operator` (`ISafetyFilter`, `ICostGuard`, `IAuditLog` per D7 — conditional on the ADR-0030/0031 audit relocation)
- `Microsoft.Extensions.*` (DI, Hosting, Logging)

Default implementations:

- **`DefaultEvaluator`** — orchestrates: gets cases from suite, invokes target per case, runs scorer set, builds `EvalReport` with full provenance (D12). Persists via `Providers.InMemory` at stand-up.
- **`ChatTarget`** — wraps `IChatClient`. Pins a `ModelCapabilityDeclaration` (or null for router-managed). Per D6, when pinned, the target resolves `IModelProvider` (from `HoneyDrunk.AI.Abstractions`, sourced through the host's DI container the same way AI's runtime package resolves providers) for the specific declaration and bypasses the router. The boundary check is intact: `IModelProvider` is an AI-Abstractions surface, `HoneyDrunk.Evals` runtime references `HoneyDrunk.AI` per the table below, and `HoneyDrunk.Evals.Abstractions` references `HoneyDrunk.AI.Abstractions` (where `ModelCapabilityDeclaration` lives) per D2. Pinning is recorded on every `EvalReport`.
- **`AutomatedRubricScorer`** — regex, schema validation, exact-match scoring against `EvalCase.ExpectedOutputJson` / `RubricCriteriaJson`. Marked `IsDeterministic: true`.
- **`ModelAsJudgeScorer`** — composes `IChatClient` to evaluate output against rubric. Marked `IsDeterministic: false`.
- **`SafetyFilterObserver` / `CostGuardObserver` / `AuditLogObserver`** — per D7, composes Operator primitives as observation-only inputs. Records what the filter would do, what the cost would be, whether approval would be required — without invoking Operator's enforcement path.
- **`EvalsTelemetry`** — emits per-suite-run / per-case-result / per-regression activities. **Content carve-out per D10:** if `suite.IsSensitive` is `false`, activity payloads MAY include the case input, target output, expected output. If `suite.IsSensitive` is `true`, payloads contain metadata only.

### Providers.InMemory details

- `InMemoryReportStore` — in-memory dictionary of `EvalReport` keyed by `ReportId`. Persists for the lifetime of the process. **`EvalReport` durability principle** (D13) — production hosts swap in a real store; in-memory satisfies the contract.
- `InMemorySuiteRepository` — in-memory dictionary of `IEvalSuite` for tests / fixtures.

### CI workflows

Five files; `api-compatibility.yml` path-filtered to `src/HoneyDrunk.Evals.Abstractions/**`.

### `HoneyDrunk.Standards`

Per invariant 26.

### Documentation

Repo README — purpose, package matrix, "How to consume" snippet with `AddHoneyDrunkEvals()` + `AddChatTarget()` example, link to ADR-0023. Note the eval-signal content carve-out (D10) and the router-bypass primitive (D6). Per-package README + CHANGELOG.

## Affected Files
Entire repo. See layout.

## NuGet Dependencies

### `HoneyDrunk.Evals.Abstractions.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | `TenantId` strong type per ADR-0026 / I3. |
| `HoneyDrunk.AI.Abstractions` | `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `ModelCapabilityDeclaration` — per ADR-0023 D2 (line 59) and D5. Transitive compile-time edge accepted, matches ADR-0020 / 0021 / 0022 D5 pattern. |
| `Microsoft.Extensions.*` abstractions | Standard. |

(No runtime HoneyDrunk packages. Invariant 1 satisfied — only upstream `Abstractions` siblings referenced.)

### `HoneyDrunk.Evals.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel` | Telemetry, context |
| `HoneyDrunk.AI` | `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `ModelCapabilityDeclaration` |
| `HoneyDrunk.Operator` | `ISafetyFilter`, `ICostGuard`, `IAuditLog` — conditional |
| `Microsoft.Extensions.*` (DI/Hosting/Logging) | |

Project reference: `HoneyDrunk.Evals.Abstractions`.

### `HoneyDrunk.Evals.Providers.InMemory.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

Project reference: `HoneyDrunk.Evals.Abstractions`. **No reference to runtime / Kernel / AI / Operator.**

### Test projects: standard + NSubstitute.

## Boundary Check
- [x] `HoneyDrunk.Evals.Abstractions` references only Abstractions-level packages: `HoneyDrunk.Standards`, `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.AI.Abstractions`, and `Microsoft.Extensions.*` — no runtime HoneyDrunk packages (invariant 1; explicitly permitted by ADR-0023 D2 line 59 and D5).
- [x] `Providers.InMemory` references only `HoneyDrunk.Evals.Abstractions` plus `HoneyDrunk.Standards` (invariant 3).
- [x] `IEvalTarget` is the router-bypass boundary — no other Node may compose `IModelProvider` directly outside this surface (invariant 72). `ChatTarget` legitimately composes `IModelProvider` through the host DI container because it implements `IEvalTarget` — this is exactly the sanctioned bypass (D6); `HoneyDrunk.Evals` runtime references `HoneyDrunk.AI` (table above) and `IModelProvider` is resolvable, so the path is intact.
- [x] Operator primitives composed observation-only (invariant 68).
- [x] `EvalReport` provenance fields populated on every report including typed `PinnedModelCapability` (invariant 69).
- [x] `EvalReport` is durable (invariant 70 — at stand-up via `Providers.InMemory`).
- [x] Content-carve-out flag honored (invariant 71).
- [x] Multi-tenant identity uses Kernel's `TenantId` strong type per ADR-0026 (I3 cross-cutting alignment with Memory).
- [x] Records drop `I`; interfaces keep it.

## Acceptance Criteria
- [ ] `HoneyDrunk.Evals.slnx` builds clean.
- [ ] Six D3 surfaces present in Abstractions with XML docs.
- [ ] `HoneyDrunk.Evals.Abstractions` PackageReference set is exactly: `HoneyDrunk.Standards`, `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.AI.Abstractions`, `Microsoft.Extensions.*` abstractions. No runtime HoneyDrunk package referenced. `IEvalTarget.PinnedModelCapability` is typed (`ModelCapabilityDeclaration?`). `EvalReport.PinnedModelCapability` is typed (`ModelCapabilityDeclaration?`). `EvalReport.TenantId` and `EvalCase.TenantId` are the `TenantId` strong type from `HoneyDrunk.Kernel.Abstractions` and default to `TenantId.Internal`.
- [ ] `Providers.InMemory` references only `HoneyDrunk.Evals.Abstractions` plus `HoneyDrunk.Standards`.
- [ ] `AddHoneyDrunkEvals()` resolves the four interfaces + default scorer set.
- [ ] `DefaultEvaluator.RunAsync` builds an `EvalReport` with `SuiteId`, `SuiteVersion`, `TargetId`, `PinnedModelCapability` (the typed declaration when target pins one; null otherwise), `TenantId` (the ambient tenant from the operation context, falling back to `TenantId.Internal`), `StartedAt`/`CompletedAt`, `ScorerSet`. Unit test verifies provenance fields including typed pin and tenant carry-through.
- [ ] `ChatTarget` wraps `IChatClient`. When `PinnedModelCapability` is non-null, it resolves `IModelProvider` for that capability declaration (router-bypass per D6) and the typed declaration is recorded on the resulting `EvalReport`. Unit test verifies pinning end-to-end and asserts on `report.PinnedModelCapability` equality with the input declaration.
- [ ] `ModelAsJudgeScorer` composes `IChatClient` and is marked `IsDeterministic: false`. `AutomatedRubricScorer` is marked `IsDeterministic: true`. Unit test verifies.
- [ ] `SafetyFilterObserver`, `CostGuardObserver`, `AuditLogObserver` each call the corresponding Operator primitive **observation-only** — they record what the primitive *would* do without invoking enforcement. Unit tests verify observation does not produce side effects on Operator's state.
- [ ] `EvalsTelemetry` emits per-suite / per-case / per-regression activities. **When `suite.IsSensitive == false`, activity payloads MAY include case content** (deliberate carve-out per D10 / invariant 71). **When `suite.IsSensitive == true`, payloads contain only metadata.** Unit test verifies both modes.
- [ ] `InMemoryReportStore` persists `EvalReport` for the process lifetime; cross-test isolation provided. Unit test verifies round-trip.
- [ ] `InMemorySuiteRepository` provides suite fixture access. Unit test verifies.
- [ ] All five `.github/workflows/*.yml` files present.
- [ ] `api-compatibility.yml` path-filtered to Abstractions; scaffolding PR reports `status: skipped`.
- [ ] `pr-core.yml` passes.
- [ ] Repo + per-package `CHANGELOG.md` + `README.md` present.
- [ ] All `src/*.csproj` Version 0.1.0.
- [ ] Manual confirmation `v0.1.0` tag triggers `release.yml`.
- [ ] **No concrete `AgentTarget`, `RetrievalTarget`, `MemoryTarget` in this packet** — deferred per D3.
- [ ] **No Monte Carlo / N-trial distribution surface** — deferred per D3 / D14.
- [ ] **No production report store** — only `Providers.InMemory` per D13.

## Human Prerequisites
- [ ] Packet 03 complete — repo exists, cloned, settings verified.
- [ ] After merge, push tag `v0.1.0`.
- [ ] **Upstream Abstractions check.** AI must be available (mandatory — `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `ModelCapabilityDeclaration`). Operator's `ISafetyFilter`/`ICostGuard`/`IAuditLog` are optional — placeholder no-ops + warnings if missing.
- [ ] **Branch protection sequencing.** Add `api-compatibility / abstractions-shape` to required checks post-merge.
- [ ] No Azure provisioning required.
- [ ] After merge + tag, file SonarCloud onboarding follow-up.
- [ ] File `AgentTarget`, `RetrievalTarget`, `MemoryTarget` follow-up packets when downstream consumers drive the shape.
- [ ] File production-report-store follow-up packet (Data, dedicated provider, Pulse-backed) when HoneyHub or a production workflow needs durable storage beyond `Providers.InMemory`.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions plus upstream `*.Abstractions` siblings are permitted. ADR-0023 D2 (line 59) and D5 explicitly permit `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.AI.Abstractions` as runtime references of `HoneyDrunk.Evals.Abstractions`.

> **Invariant 3:** Providers reference parent Node's contracts, not internal implementation details.

> **Invariant 11:** One repo per Node.

> **Invariant 12, 13, 26, 27.** Standard.

> **Evals downstream-coupling invariant (default 67):** Downstream Nodes runtime-depend only on Abstractions.

> **Evals read-only-observer invariant (default 68):** No target mutation from harness side.

> **Evals provenance invariant (default 69):** `EvalReport` records full provenance.

> **Evals durable-not-ephemeral invariant (default 70):** `EvalReport` is durable; Pulse signals are complements, not substitutes.

> **Evals content-carve-out invariant (default 71):** Eval-signal telemetry may carry content unless `IEvalSuite.IsSensitive == true`.

> **Evals router-bypass invariant (default 72):** Bypass permitted only through `IEvalTarget`.

> **Evals contract-shape canary invariant (default 73):** Canary on `IEvaluator`, `IEvalScorer`, `IEvalTarget`, `EvalReport`, and `IEvalSuite` (S1 — `IEvalSuite.IsSensitive` boolean is intentionally first-pass and expected to evolve to an enum; canary catches that drift).

## Referenced ADR Decisions

**ADR-0023 D1:** Evaluation and quality substrate.

**ADR-0023 D2:** Three packages — Abstractions + runtime + Providers.InMemory.

**ADR-0023 D3:** Six surfaces — four interfaces + two records.

**ADR-0023 D5:** AI composition for `ChatTarget` + model-as-judge scorer.

**ADR-0023 D6:** Router bypass via `IEvalTarget`. Pinning recorded on `EvalReport`.

**ADR-0023 D7:** Operator primitives as observation-only scoring signals.

**ADR-0023 D10:** Content carve-out — eval signals MAY carry content unless suite declares sensitive.

**ADR-0023 D12:** `EvalReport` full provenance.

**ADR-0023 D13:** `EvalReport` durable; storage substrate deferred.

**ADR-0023 D14:** Canary on four hot-path surfaces.

**ADR-0016 D3 (referenced):** `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `ModelCapabilityDeclaration` from AI.

**ADR-0018 D3 (referenced):** `ISafetyFilter`, `ICostGuard`, `IAuditLog` from Operator (the last per ADR-0030/0031 amendment lives in Audit Node).

## Dependencies
- `work-item:01`, `work-item:02`, `work-item:03`

## Labels
`feature`, `tier-2`, `ai`, `scaffold`, `adr-0023`, `new-node`

## Agent Handoff

**Objective:** Ship `HoneyDrunk.Evals 0.1.0` with the six D3 surfaces, default runtime composing AI + Operator, `Providers.InMemory`, CI, canary.

**Target:** HoneyDrunk.Evals, branch from `main`.

**Constraints:**
- **Invariant 1:** `HoneyDrunk.Evals.Abstractions` may reference `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.AI.Abstractions` per ADR-0023 D2 (line 59) and D5 — those are the upstream Abstractions siblings the contract surface is built on. No runtime HoneyDrunk packages (`HoneyDrunk.Kernel`, `HoneyDrunk.AI`, `HoneyDrunk.Operator`, etc.) may be referenced from `HoneyDrunk.Evals.Abstractions`.
- **Invariant 3 applied to Providers.InMemory:** References only `HoneyDrunk.Evals.Abstractions` (plus `HoneyDrunk.Standards`).
- **Invariant 71 (default):** Honor `IEvalSuite.IsSensitive` flag in telemetry — content carved out when sensitive, content included when not. Boolean is intentionally first-pass; an enum evolution is the canary-protected follow-up per S1.
- **Invariant 72 (default):** `IEvalTarget` is the only router-bypass primitive in the Grid. Sim has a parallel-but-distinct `ISimulationTarget` per ADR-0025 D8; the two do not share types. `ChatTarget` composing `IModelProvider` directly is the sanctioned implementation of this bypass — `IModelProvider` is resolvable because `HoneyDrunk.Evals` runtime references `HoneyDrunk.AI` and `HoneyDrunk.AI.Abstractions`.
- **Typed identity stance.** `IEvalTarget.PinnedModelCapability` is `ModelCapabilityDeclaration?` (typed; AI-Abstractions surface). `EvalReport.PinnedModelCapability` is `ModelCapabilityDeclaration?`. `EvalReport.TenantId` and `EvalCase.TenantId` are the Kernel-Abstractions `TenantId` strong type, defaulting to `TenantId.Internal` per ADR-0026.
- **Records drop `I`; interfaces keep it.** `EvalCase`, `EvalReport`, `EvalScore`, `EvalCaseResult`, `EvalReportSummary`, `ObservedOperatorPrediction`, `RubricSpec` are records.
- **Operator composition is observation-only.** Never call Operator primitives to enforce. `ObservedOperatorPrediction` properties default to `null` to distinguish "observer not wired" from "observer ran and recorded a value" (S2).
- **No concrete `AgentTarget` / `RetrievalTarget` / `MemoryTarget` in this packet.** `ChatTarget` only.
- **No Monte Carlo distribution surface.**
- **Canary skip on scaffolding PR expected.** Canary scope per D14 includes `IEvalSuite` (S1 — to catch the future `IsSensitive` enum evolution) alongside `IEvaluator`, `IEvalScorer`, `IEvalTarget`, and `EvalReport`.
- **Upstream conditional.** AI Abstractions is mandatory. Kernel Abstractions is mandatory (for `TenantId`). Operator Abstractions optional — placeholder no-ops if missing.

**Key Files:**
- `HoneyDrunk.Evals.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Evals.Abstractions/` — 4 interfaces + 2 records + supporting records
- `src/HoneyDrunk.Evals/` — `DefaultEvaluator`, `ChatTarget`, scorers, observers, `EvalsTelemetry`, `ServiceCollectionExtensions`
- `src/HoneyDrunk.Evals.Providers.InMemory/` — `InMemoryReportStore`, `InMemorySuiteRepository`
- `.github/workflows/*.yml`
- `README.md`, `CHANGELOG.md` (repo + per-package)
- `tests/`

**Contracts:** Six D3 surfaces authored fresh.
