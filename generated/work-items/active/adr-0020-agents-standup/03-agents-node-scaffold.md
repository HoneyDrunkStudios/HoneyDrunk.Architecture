---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Agents
labels: ["feature", "tier-2", "ai", "scaffold", "adr-0020"]
dependencies: ["work-item:01", "work-item:02", "work-item:02b", "adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold", "adr-0017-capabilities-standup/04-capabilities-node-scaffold", "adr-0018-operator-standup/03-operator-node-scaffold"]
adrs: ["ADR-0020", "ADR-0016", "ADR-0017", "ADR-0018", "ADR-0022"]
accepts: ADR-0020
wave: 3
initiative: adr-0020-agents-standup
node: honeydrunk-agents
---

# Feature: Stand up the HoneyDrunk.Agents repo — solution, three packages, five contracts, function-calling adapter, CI, in-memory testing fixture

## Summary

Bring the near-empty `HoneyDrunk.Agents` repo from zero to first-shippable state per ADR-0020. Land the solution layout, the three package families (`Abstractions`, runtime, `Testing` fixture), the five D3 interfaces inside `HoneyDrunk.Agents.Abstractions`, default runtime implementations (`DefaultAgent` harness, `DefaultAgentLifecycle` with in-process registry, `DefaultToolInvoker` composing Capabilities, `DefaultAgentMemory` composing Memory), the function-calling adapter per D12, the in-memory testing fixture, the standard CI pipeline, and the contract-shape canary scoped to `HoneyDrunk.Agents.Abstractions` per D10 and the canary invariant (number assigned by packet 02).

This is the unblocker for Flow, Sim, Lore, the HoneyDrunk.Actions cloud-agent trigger path, HoneyHub (when live), and Evals.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Agents`

## Motivation

ADR-0020 establishes what HoneyDrunk.Agents is. The repo is cloned (LICENSE + README only) but otherwise empty. Six downstream consumers are blocked.

This packet is intentionally larger than typical bring-up packets because:

- Five contracts must all land in the first commit for the contract-shape canary baseline.
- Four default runtime implementations compose four upstream Nodes (AI + Capabilities + Operator + Memory).
- The function-calling adapter (D12) is a new substrate piece authored here for the first time in the Grid.
- The in-memory testing fixture is required for downstream Nodes (Flow, Sim, Evals) to write deterministic tests.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Agents/
├── HoneyDrunk.Agents.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── .editorconfig
├── .gitignore
├── .github/
│   └── workflows/
│       ├── pr-core.yml
│       ├── release.yml
│       ├── nightly-deps.yml
│       ├── nightly-security.yml
│       └── api-compatibility.yml
├── src/
│   ├── HoneyDrunk.Agents.Abstractions/
│   │   ├── HoneyDrunk.Agents.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IAgent.cs
│   │   ├── IAgentExecutionContext.cs
│   │   ├── IAgentLifecycle.cs
│   │   ├── IToolInvoker.cs
│   │   ├── IAgentMemory.cs
│   │   └── (request/response records — minimum needed; deeper shape ADRs land later)
│   ├── HoneyDrunk.Agents/
│   │   ├── HoneyDrunk.Agents.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs    (AddHoneyDrunkAgents)
│   │   ├── Execution/DefaultAgent.cs
│   │   ├── Lifecycle/DefaultAgentLifecycle.cs   (in-process registry)
│   │   ├── Tools/DefaultToolInvoker.cs           (composes Capabilities)
│   │   ├── Memory/DefaultAgentMemory.cs          (composes Memory)
│   │   ├── FunctionCalling/FunctionCallAdapter.cs (D12 — see "Function-calling adapter shape" below)
│   │   └── Telemetry/AgentTelemetry.cs
│   └── HoneyDrunk.Agents.Testing/
│       ├── HoneyDrunk.Agents.Testing.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── InMemoryAgent.cs
│       ├── InMemoryAgentLifecycle.cs
│       ├── InMemoryToolInvoker.cs
│       ├── InMemoryAgentMemory.cs
│       ├── DeterministicClock.cs
│       └── RecordingExecutionLogger.cs
└── tests/
    ├── HoneyDrunk.Agents.Abstractions.Tests/
    ├── HoneyDrunk.Agents.Tests/
    └── HoneyDrunk.Agents.Testing.Tests/
```

### Solution

`HoneyDrunk.Agents.slnx` references three `src/*` projects and three `tests/*` projects. `Directory.Build.props` sets `net10.0`, nullable, warnings-as-errors, `Version` 0.1.0 (test projects excluded via `IsTestProject`).

### Contract details — `HoneyDrunk.Agents.Abstractions`

Five interfaces per D3. Minimum supporting records.

```csharp
// IAgent.cs
namespace HoneyDrunk.Agents.Abstractions;

public interface IAgent
{
    string AgentId { get; }
    Task<AgentResult> ExecuteAsync(AgentRequest request, IAgentExecutionContext context, CancellationToken cancellationToken = default);
}

public sealed record AgentRequest(string InputJson, IReadOnlyDictionary<string, string> Metadata, string CallerCorrelationId);
public sealed record AgentResult(bool Success, string? OutputJson, AgentExecutionError? Error, IReadOnlyList<AgentTraceEntry> Trace);
public sealed record AgentExecutionError(AgentErrorCode Code, string Message, string? DetailsJson);
public sealed record AgentTraceEntry(string Kind, string Payload, DateTimeOffset At);
// Observation: `Kind` is `string` at v0.1.0. A typed `AgentTraceKind` enum (e.g.
// LifecycleStarted, InferenceCalled, ToolDispatched, MemoryWritten, GateChecked,
// LifecycleCompleted) would be more discoverable and canary-friendly. No change at
// stand-up — the trace surface is the most likely to grow, and a flexible string
// keeps the door open for v0.2 + the contract-shape canary catches the eventual
// shape commitment. Flag for review when the next consumer (Flow / Sim / Evals)
// starts asserting on trace shapes.

public enum AgentErrorCode
{
    NotInitialized = 0,
    InferenceFailed = 1,
    ToolDispatchFailed = 2,
    ApprovalDenied = 3,
    BreakerOpen = 4,
    MemoryAccessDenied = 5,
    Cancelled = 6,
    ExecutionFailed = 7,
}
```

```csharp
// IAgentExecutionContext.cs
namespace HoneyDrunk.Agents.Abstractions;

using HoneyDrunk.Kernel.Abstractions;   // Kernel already exposes the base IAgentExecutionContext

// Per ADR-0020 D3 / D8: Agents extends Kernel's IAgentExecutionContext (see catalogs/relationships.json
// `honeydrunk-kernel.contracts`) with AI-specific bindings. Interface inheritance — not name shadowing —
// preserves Kernel ownership of the lifecycle/correlation semantics and lets Agents add only what it owns.
public interface IAgentExecutionContext : HoneyDrunk.Kernel.Abstractions.IAgentExecutionContext
{
    string AgentId { get; }
    string ExecutionId { get; }
    IReadOnlyDictionary<string, string> Bindings { get; }   // tool bindings, memory references, inference binding identifier
    // CorrelationId is inherited from Kernel's interface (not redeclared).
    // Short-term/execution-scope state lives on this context (ADR-0020 D8).
    // It is disposed when IAgentLifecycle.CompleteAsync runs.
}
```

The interface-inheritance form (not name shadowing) makes the Agents-side concrete: the type Kernel already exposes at `catalogs/relationships.json` line 10 (`honeydrunk-kernel.contracts`) is the base; Agents extends it with `AgentId` / `ExecutionId` / `Bindings`. Downstream consumers that want only the Kernel-level semantics keep using Kernel's interface; consumers that need the AI-specific bindings reach for the Agents one. There is no silent shadowing of Kernel's contract.

```csharp
// IAgentLifecycle.cs
public interface IAgentLifecycle
{
    Task RegisterAsync(IAgent agent, CancellationToken cancellationToken = default);
    Task<IAgent?> ResolveAsync(string agentId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<string>> ListAsync(CancellationToken cancellationToken = default);
    Task<IAgentExecutionContext> InitializeAsync(string agentId, AgentRequest request, CancellationToken cancellationToken = default);
    Task CompleteAsync(IAgentExecutionContext context, CancellationToken cancellationToken = default);
    Task DecommissionAsync(string agentId, CancellationToken cancellationToken = default);
}
```

```csharp
// IToolInvoker.cs
public interface IToolInvoker
{
    Task<ToolInvocationResult> InvokeAsync(ToolInvocationRequest request, IAgentExecutionContext context, CancellationToken cancellationToken = default);
}

public sealed record ToolInvocationRequest(string ToolName, string ToolVersion, string ArgumentsJson);
public sealed record ToolInvocationResult(bool Success, string? ResultJson, ToolInvocationError? Error);
public sealed record ToolInvocationError(ToolErrorCode Code, string Message);

public enum ToolErrorCode { NotRegistered = 0, VersionNotFound = 1, Unauthorized = 2, InvalidArguments = 3, ExecutionFailed = 4 }
```

```csharp
// IAgentMemory.cs
public interface IAgentMemory
{
    Task WriteAsync(AgentMemoryWriteRequest request, IAgentExecutionContext context, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<AgentMemoryReadResult>> SearchAsync(AgentMemoryQueryRequest query, IAgentExecutionContext context, CancellationToken cancellationToken = default);
}

public sealed record AgentMemoryWriteRequest(string Content, IReadOnlyDictionary<string, string> Metadata);
public sealed record AgentMemoryQueryRequest(string QueryText, int MaxResults, IReadOnlyDictionary<string, string> Filters);
public sealed record AgentMemoryReadResult(string Content, IReadOnlyDictionary<string, string> Metadata, double SimilarityScore);
```

The `AgentMemory*` prefix disambiguates from Memory Node's `MemoryEntry` / `MemoryQuery` shapes when ADR-0022 ships (Agents owns request/result shapes at its own surface; Memory owns its store-level shapes). Naming records drop the `I` per the Grid-wide convention; interfaces keep `I`.

`HoneyDrunk.Agents.Abstractions` references **only** `Microsoft.Extensions.*` abstractions and `HoneyDrunk.Kernel.Abstractions` (so that Agents's `IAgentExecutionContext` can extend Kernel's base interface — see "Interface inheritance" stanza below). Per invariant 1, `Kernel.Abstractions` is itself an Abstractions package with zero HoneyDrunk runtime dependencies, so the reference does not violate the rule. **Do not** reference any other `HoneyDrunk.*` package from Agents.Abstractions — no AI, no Capabilities, no Operator, no Memory, no Kernel runtime. Per D13, no third-party AI-runtime compile-time dependencies either (no Microsoft.Extensions.AI, no model-provider SDKs, no agent-framework libraries).

**Strict Abstractions stance.** `AgentRequest.CallerCorrelationId` is `string`, not `CorrelationId`. `IAgentExecutionContext.CorrelationId` (inherited from Kernel) follows Kernel's shape — see Kernel.Abstractions for its type contract. The runtime package's `AgentTelemetry` does the GridContext propagation against Kernel — Agents.Abstractions itself carries a reference only to `HoneyDrunk.Kernel.Abstractions` for the base `IAgentExecutionContext`, never to the Kernel runtime package (invariant 1 still holds — `Kernel.Abstractions` is an Abstractions package, not a runtime package).

**First-pass shape; subject to refinement.** Member sets subject to evolution before v0.2.0 baseline lock. Canary catches breaking shape changes.

### Runtime details — `HoneyDrunk.Agents`

`HoneyDrunk.Agents` references:
- `HoneyDrunk.Agents.Abstractions` (project)
- `HoneyDrunk.Kernel.Abstractions` (for `ITelemetryActivityFactory`, `IGridContext`, `IGridContextAccessor`, `IOperationContext`, `IAgentExecutionContext`)
- `HoneyDrunk.AI.Abstractions` (for `IChatClient`, `IEmbeddingGenerator`, `ModelCapabilityDeclaration`)
- `HoneyDrunk.Capabilities.Abstractions` (for `ICapabilityRegistry`, `ICapabilityInvoker`, `ICapabilityGuard`)
- `HoneyDrunk.Operator.Abstractions` (for `IApprovalGate`, `ICircuitBreaker` per D7)
- `HoneyDrunk.Memory.Abstractions` (for `IMemoryStore`, `IMemoryScope` per D6)
- `Microsoft.Extensions.DependencyInjection.Abstractions`
- `Microsoft.Extensions.Hosting.Abstractions`
- `Microsoft.Extensions.Logging.Abstractions`

**Per invariant 2** ("Runtime packages depend on Abstractions, never on other runtime packages at the same layer"), the Agents runtime composes upstream Nodes through their `.Abstractions` packages only — never against the runtime packages (`HoneyDrunk.Kernel`, `HoneyDrunk.AI`, `HoneyDrunk.Capabilities`, `HoneyDrunk.Operator`, `HoneyDrunk.Memory`). Host applications resolve the concrete runtime implementations at composition time.

**Upstream Abstractions availability — hard cross-initiative dependency.** Packet 03's frontmatter declares hard dependencies on the AI, Capabilities, and Operator scaffold packets so `file-work-items.yml` blocks filing until all four upstream `.Abstractions` packages exist on NuGet. The Memory `.Abstractions` package is the lone exception: if ADR-0022's scaffold has not yet shipped at edit time, `DefaultAgentMemory` ships as a placeholder no-op with a structured warning and a follow-up packet wires the real composition once Memory lands. AI, Capabilities, and Operator have no such escape — the executing agent should fail the build if any of those three `.Abstractions` packages cannot be resolved.

Four default implementations:

- **`DefaultAgent`** — orchestrates the agent execution: validates request, resolves agent via lifecycle, opens execution context, runs the function-calling loop, returns `AgentResult` with trace.
- **`DefaultAgentLifecycle`** — in-process registry (`ConcurrentDictionary<string, IAgent>`). `RegisterAsync` validates non-empty `agentId`; `ResolveAsync` returns null for missing entries; `InitializeAsync` creates a fresh `IAgentExecutionContext` with the ambient `IGridContext.CorrelationId` and disposes via `CompleteAsync`. Per D11, the registry is in-process; cross-host distribution is deferred.
- **`DefaultToolInvoker`** — composes `ICapabilityRegistry` + `ICapabilityInvoker` + `ICapabilityGuard` from Capabilities. Resolve `(toolName, toolVersion)`, check guard, dispatch via `ICapabilityInvoker`, marshal result. Agents never reaches around `ICapabilityInvoker` to dispatch directly.
- **`DefaultAgentMemory`** — composes `IMemoryStore` + `IMemoryScope` from Memory. Resolves the agent's scope from its execution context's `AgentId`, reads/writes through that scope. Embeddings flow through AI's `IEmbeddingGenerator` (which Memory's runtime composes; Agents does not call `IEmbeddingGenerator` directly from this surface).

Plus one substrate-defining adapter:

- **`FunctionCallAdapter`** — the loop of "model function-call output → `IToolInvoker` calls → next inference call." Per D12, this lives only in `HoneyDrunk.Agents`. The mechanism (Option for this work-item: a generic adapter keyed by `ModelCapabilityDeclaration` that translates `IChatClient.CompleteAsync` results' function-call payloads into `ToolInvocationRequest` shapes, dispatches via `IToolInvoker`, builds the result back into the next inference message). Provider-specific shape variations are handled by per-`ModelCapabilityDeclaration` translation rules read from App Config — no per-provider adapter code in this scaffold.

Plus `AgentTelemetry` for D9 emission — wraps every lifecycle, execution, tool-invocation, memory-access call in `ITelemetryActivityFactory` activities and propagates `IGridContext`.

Service registration:

```csharp
public static IServiceCollection AddHoneyDrunkAgents(this IServiceCollection services, Action<AgentsOptions>? configure = null)
{
    services.AddSingleton<IAgentLifecycle, DefaultAgentLifecycle>();
    services.AddScoped<IAgent, DefaultAgent>();
    services.AddScoped<IToolInvoker, DefaultToolInvoker>();
    services.AddScoped<IAgentMemory, DefaultAgentMemory>();
    services.AddScoped<FunctionCallAdapter>();
    return services;
}
```

### Testing fixture — `HoneyDrunk.Agents.Testing`

In-memory implementations of every Agents-owned interface:

- `InMemoryAgent` — script-driven `ExecuteAsync` that returns canned results without invoking inference, tools, or memory. Used by Flow / Sim / Evals tests where the agent is a black box.
- `InMemoryAgentLifecycle` — single-threaded dictionary, no telemetry, no Kernel composition.
- `InMemoryToolInvoker` — script-driven `InvokeAsync` returning canned results without composing Capabilities.
- `InMemoryAgentMemory` — in-memory dictionary; no composition with Memory.
- `DeterministicClock` — `IClock` substitute for lifecycle-timing tests.
- `RecordingExecutionLogger` — captures every execution-trace entry for test assertions.

`HoneyDrunk.Agents.Testing` references **only** `HoneyDrunk.Agents.Abstractions` + `Microsoft.Extensions.*`. No reference to runtime, Kernel, AI, Capabilities, Operator, Memory. Per invariant 3 applied to companion packages.

### CI workflows

Five workflow files, thin callers of `HoneyDrunk.Actions`. `api-compatibility.yml` path-filtered to `src/HoneyDrunk.Agents.Abstractions/**`. The whole-assembly diff covers the four hot-path interfaces from invariant 57 (default — packet 02 assigns final number) (`IAgent`, `IAgentExecutionContext`, `IToolInvoker`, `IAgentMemory`) plus `IAgentLifecycle` and the records.

**`IAgentLifecycle` canary scope — follow-up.** `IAgentLifecycle` is the fifth D3 interface but is not in invariant 57's four hot-path canary set. The whole-assembly diff above will still catch shape drift, but the canary's hard failure mode is scoped to the four hot-path interfaces only. Revisit this once HoneyDrunk.Actions wires the cloud-agent trigger path (per ADR-0020 Unblocks) — that's the first consumer to compile against `IAgentLifecycle` and the natural moment to escalate its shape to hot-path. File the follow-up packet at that wiring time.

### `HoneyDrunk.Standards` wiring

Per invariant 26, every `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets="all"`.

### Documentation

- Repo README — purpose, package matrix, "How to consume" snippet with `AddHoneyDrunkAgents()`, link to ADR-0020. Include a `## For downstream consumers — canary projects` section with the minimal compose-the-runtime snippet.
- Repo CHANGELOG — `## [0.1.0] - 2026-MM-DD`.
- Per-package README + CHANGELOG.

## Affected Files
Entire repo. Notable new files under "Repository layout".

## NuGet Dependencies

### `HoneyDrunk.Agents.Abstractions.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For the base `IAgentExecutionContext` interface Agents extends (interface inheritance per ADR-0020 D3 / D8) |

(No other PackageReference. Both refs are Abstractions packages so invariant 1 is preserved. Invariant 56 [default, assigned by packet 02] forbids third-party AI-runtime deps — no `Microsoft.Extensions.AI`, no provider SDKs, no agent-framework libraries.)

### `HoneyDrunk.Agents.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For telemetry, context, `IAgentExecutionContext` base |
| `HoneyDrunk.AI.Abstractions` | For `IChatClient`, `IEmbeddingGenerator`, `ModelCapabilityDeclaration` |
| `HoneyDrunk.Capabilities.Abstractions` | For `ICapabilityRegistry`, `ICapabilityInvoker`, `ICapabilityGuard` |
| `HoneyDrunk.Operator.Abstractions` | For `IApprovalGate`, `ICircuitBreaker` per D7 |
| `HoneyDrunk.Memory.Abstractions` | For `IMemoryStore`, `IMemoryScope` per D6 — conditional on availability at edit time |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | |
| `Microsoft.Extensions.Hosting.Abstractions` | |
| `Microsoft.Extensions.Logging.Abstractions` | |

Per invariant 2, the runtime composes upstream Nodes through `.Abstractions` packages only. The corresponding runtime packages (`HoneyDrunk.Kernel`, `HoneyDrunk.AI`, etc.) are not referenced.

Project reference: `HoneyDrunk.Agents.Abstractions`.

### `HoneyDrunk.Agents.Testing.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | |

Project reference: `HoneyDrunk.Agents.Abstractions`. No reference to runtime, Kernel, AI, Capabilities, Operator, Memory.

### Test projects
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.NET.Test.Sdk`, `xunit`, `xunit.runner.visualstudio`, `Microsoft.Extensions.DependencyInjection`, `NSubstitute` | Standard |

## Boundary Check
- [x] All work inside `HoneyDrunk.Agents`.
- [x] `HoneyDrunk.Agents.Abstractions` carries only `HoneyDrunk.Kernel.Abstractions` (for the base `IAgentExecutionContext` interface — both packages are Abstractions, so invariant 1 holds) and `Microsoft.Extensions.*` references. Zero third-party AI-runtime references (invariant 56 — default, assigned by packet 02).
- [x] `HoneyDrunk.Agents.Testing` references only `HoneyDrunk.Agents.Abstractions` (invariant 3).
- [x] Agents never imports a model-provider SDK (invariant 52 — default).
- [x] Agents never reaches around `IToolInvoker` to dispatch tools (invariant 53 — default).
- [x] Agents never persists agent state outside `IAgentMemory` (invariant 54 — default).
- [x] Function-calling loop lives only in `HoneyDrunk.Agents` runtime (invariant 55 — default).

## Acceptance Criteria
- [ ] `HoneyDrunk.Agents.slnx` builds clean from a fresh clone.
- [ ] All five D3 interfaces present with XML docs.
- [ ] `HoneyDrunk.Agents.Abstractions` references only `HoneyDrunk.Kernel.Abstractions` (for the base `IAgentExecutionContext` interface) and `Microsoft.Extensions.*` packages. No reference to AI, Capabilities, Operator, Memory, or any runtime HoneyDrunk package. Zero third-party AI-runtime references (no `Microsoft.Extensions.AI`, no `OpenAI`, no `Anthropic.SDK`, no `Azure.AI.OpenAI`, no LangChain, no Semantic Kernel). `rg` over the .csproj returns zero matches for forbidden references.
- [ ] `HoneyDrunk.Agents.Testing` references only `HoneyDrunk.Agents.Abstractions` + Microsoft.Extensions.*.
- [ ] `AddHoneyDrunkAgents()` registers all five contracts; resolves cleanly from DI.
- [ ] `DefaultAgentLifecycle.RegisterAsync` rejects empty / null `agentId`. Unit test covers.
- [ ] `DefaultToolInvoker.InvokeAsync` calls `ICapabilityGuard.CheckAsync` before dispatch. Unit test verifies.
- [ ] `DefaultAgentMemory` resolves scope from `IAgentExecutionContext.AgentId` and writes through Memory's `IMemoryStore`. Unit test verifies.
- [ ] `FunctionCallAdapter` translates an `IChatClient`-style function-call payload into a `ToolInvocationRequest`, dispatches via `IToolInvoker`, and feeds the result back. Unit test covers the end-to-end loop using `InMemoryToolInvoker`.
- [ ] `AgentTelemetry` emits per-call activities for lifecycle, execution, tool-invocation, memory-access. Verified by test.
- [ ] All five `.github/workflows/*.yml` files present and call `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/*@main`.
- [ ] `api-compatibility.yml` path-filtered to `src/HoneyDrunk.Agents.Abstractions/**`. Scaffolding PR reports `status: skipped` (expected). Verification via throwaway breaking-change PR post-merge.
- [ ] `pr-core.yml` passes on the scaffolding PR.
- [ ] Repo + per-package `CHANGELOG.md` + `README.md` present.
- [ ] All `src/*.csproj` carry Version `0.1.0`; tests excluded.
- [ ] Manual confirmation that `v0.1.0` tag triggers `release.yml` (verify workflow exists; do not push yet).
- [ ] **No provider SDK references.** `rg -n 'OpenAI|Anthropic\.SDK|Azure\.AI\.OpenAI|LangChain|SemanticKernel' src/HoneyDrunk.Agents/` returns zero matches (the runtime composes AI's `IChatClient` for inference, never a provider SDK directly).
- [ ] **No `.github/dependabot.yml`.** Per ADR-0009.
- [ ] Repo README includes a `## For downstream consumers — canary projects` section.

## Human Prerequisites
- [ ] Packet 02b complete.
- [ ] After merge, push tag `v0.1.0` from `main`.
- [ ] **Upstream Abstractions availability check — AI / Capabilities / Operator are hard prerequisites.** Before this packet's PR is opened, confirm on NuGet: `HoneyDrunk.AI.Abstractions 0.1.0`, `HoneyDrunk.Capabilities.Abstractions 0.1.0`, `HoneyDrunk.Operator.Abstractions 0.1.0`. The filing pipeline's `addBlockedBy` wiring (driven by the cross-initiative `dependencies:` entries in this packet's frontmatter) keeps the Hive board item Blocked until the three upstream scaffold issues close. If any of those three packages is unresolvable at edit time, stop and flag rather than ship a placeholder — the upstream scaffold packet is the right place to land it, not here.
- [ ] **Memory is the lone placeholder escape.** If `HoneyDrunk.Memory.Abstractions 0.1.0` has not yet shipped, `DefaultAgentMemory` may ship as a placeholder no-op with a structured warning log and a follow-up packet to wire the real composition once Memory lands. This applies only to Memory; AI / Capabilities / Operator have no placeholder escape.
- [ ] **Branch protection sequencing.** Add `api-compatibility / abstractions-shape` to required checks after the post-merge throwaway-PR verification.
- [ ] No Azure provisioning required.
- [ ] After merge + tag, file a SonarCloud onboarding follow-up.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. `HoneyDrunk.Transport` depends on `HoneyDrunk.Kernel.Abstractions`, not `HoneyDrunk.Kernel`. Applied here: `HoneyDrunk.Agents` references the `.Abstractions` package of every upstream Node it composes (Kernel, AI, Capabilities, Operator, Memory).

> **Invariant 3:** Companion packages (Testing, Providers) depend on the parent Node's contracts package, not internal implementation details.

> **Invariant 4:** No circular dependencies. Kernel is always at the root.

> **Invariant 11:** One repo per Node.

> **Invariant 12:** Semantic versioning with CHANGELOG and README.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 26:** `## NuGet Dependencies` section required; `HoneyDrunk.Standards` on every new .NET project.

> **Invariant 27:** All projects in a solution share one version.

> **Agents downstream-coupling invariant (number assigned by packet 02, default 51):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Agents.Abstractions`. Composition against `HoneyDrunk.Agents` and `HoneyDrunk.Agents.Testing` is a host-time (and test-time) concern.

> **Agents no-direct-model-providers invariant (default 52):** All inference flows through `IChatClient` from `HoneyDrunk.AI.Abstractions`. No provider SDK imports in any Agents package.

> **Agents no-direct-tool-implementations invariant (default 53):** All tool invocations flow through `IToolInvoker`, which composes Capabilities's `ICapabilityRegistry` + `ICapabilityInvoker` + `ICapabilityGuard`.

> **Agents no-direct-Memory-writes invariant (default 54):** All memory access flows through `IAgentMemory`. Execution-scope state stays on `IAgentExecutionContext`; anything that must survive disposal is written through `IAgentMemory`.

> **Agents function-calling-loop-only-in-Agents invariant (default 55):** The "model tool-call output → `IToolInvoker` calls → next inference call" loop lives in the `HoneyDrunk.Agents` runtime and nowhere else.

> **Agents Abstractions-no-third-party-AI invariant (default 56):** `HoneyDrunk.Agents.Abstractions` takes no third-party AI-runtime compile-time dependencies (no `Microsoft.Extensions.AI`, no provider SDKs, no agent-framework libraries).

> **Agents contract-shape canary invariant (default 57):** The HoneyDrunk.Agents Node CI must include a contract-shape canary that fails the build on shape drift to `IAgent`, `IAgentExecutionContext`, `IToolInvoker`, or `IAgentMemory` without a corresponding version bump.

## Referenced ADR Decisions

**ADR-0020 D1:** HoneyDrunk.Agents is the agent-runtime substrate, not an orchestrator.

**ADR-0020 D2:** Three packages — Abstractions + runtime + Testing.

**ADR-0020 D3:** Five interfaces; no records at stand-up.

**ADR-0020 D4:** Boundary against AI / Capabilities / Operator / Memory / Flow.

**ADR-0020 D5:** Tool invocation composes Capabilities. Agents does not own a registry.

**ADR-0020 D6:** Memory access composes Memory. `IMemoryScope` is Memory's, not Agents's.

**ADR-0020 D7:** Safety-gate composition with Operator — invoke (synchronous), not emit. Agents calls `IApprovalGate` and `ICircuitBreaker` on the hot path. No runtime dependency on Communications.

**ADR-0020 D8:** Agents holds execution-scope state only. `IAgentExecutionContext` disposes when `CompleteAsync` runs.

**ADR-0020 D9:** Pulse consumes Agents telemetry; no runtime dependency on Pulse.

**ADR-0020 D10:** Canary on four hot-path interfaces.

**ADR-0020 D11:** In-process agent registry at stand-up.

**ADR-0020 D12:** Function-calling adapter lives in `HoneyDrunk.Agents` only. Specific mechanism is a scaffold-packet decision; this packet picks a generic adapter keyed by `ModelCapabilityDeclaration` with App-Config-sourced per-model translation rules.

**ADR-0020 D13:** `HoneyDrunk.Agents.Abstractions` takes no third-party AI-runtime compile-time deps. Runtime may.

**ADR-0016 D6 (referenced):** Shape-compatible-with-MEAI is structural, not type-identity. Applies here — `IChatClient` is consumed from `HoneyDrunk.AI.Abstractions`, not from `Microsoft.Extensions.AI`.

## Dependencies
- `work-item:01` — Architecture catalog registration
- `work-item:02` — Constitution invariants for Agents
- `work-item:02b` — Repo + clone verification
- `adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold` — `HoneyDrunk.AI.Abstractions 0.1.0` must be on NuGet
- `adr-0017-capabilities-standup/04-capabilities-node-scaffold` — `HoneyDrunk.Capabilities.Abstractions 0.1.0` must be on NuGet
- `adr-0018-operator-standup/03-operator-node-scaffold` — `HoneyDrunk.Operator.Abstractions 0.1.0` must be on NuGet

Memory's scaffold (`adr-0022-memory-standup/03-memory-node-scaffold`) is intentionally NOT a hard dependency. Memory is the lone substrate Agents may stub with a placeholder no-op (see Human Prerequisites). All three of AI / Capabilities / Operator are required upstream and must ship `.Abstractions 0.1.0` to NuGet before this packet's PR is opened — the filing pipeline's `addBlockedBy` wiring enforces this.

## Labels
`feature`, `tier-2`, `ai`, `scaffold`, `adr-0020`

## Agent Handoff

**Objective:** Take the `HoneyDrunk.Agents` repo (LICENSE + README) and ship 0.1.0 with five D3 contracts, four default runtime implementations composing AI / Capabilities / Operator / Memory, a function-calling adapter per D12, in-memory testing fixture, full CI, and the contract-shape canary scoped to Abstractions.

**Target:** HoneyDrunk.Agents, branch from `main`.

**Context:**
- Goal: Unblock Flow / Sim / Lore / Actions cloud-agent path / HoneyHub / Evals.
- Feature: ADR-0020 standup initiative, packet 03.
- ADRs: ADR-0020 (sole standup); ADR-0016/0017/0018/0022 (upstream substrates Agents composes).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01, 02, 02b.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. `HoneyDrunk.Agents.Abstractions.csproj` contains no `HoneyDrunk.*` PackageReference or ProjectReference.
- **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. `HoneyDrunk.Agents.csproj` references upstream Nodes (Kernel, AI, Capabilities, Operator, Memory) through their `.Abstractions` packages only — never against `HoneyDrunk.Kernel`, `HoneyDrunk.AI`, `HoneyDrunk.Capabilities`, `HoneyDrunk.Operator`, or `HoneyDrunk.Memory` directly.
- **Invariant 56 (assigned by packet 02, default):** `HoneyDrunk.Agents.Abstractions` takes no third-party AI-runtime compile-time dependencies. No `Microsoft.Extensions.AI`, no model-provider SDKs, no agent-framework libraries.
- **Invariant 52 (default):** No model-provider SDKs in any Agents package. Inference goes through `IChatClient` from AI.
- **Invariant 53 (default):** No direct tool implementations or direct `ICapabilityInvoker.InvokeAsync` calls outside `DefaultToolInvoker`. Tool calls go through `IToolInvoker`.
- **Invariant 54 (default):** No direct `IMemoryStore` writes outside `DefaultAgentMemory`.
- **Invariant 55 (default):** The function-calling loop lives only in `HoneyDrunk.Agents` runtime. No equivalent loop in any other AI-sector Node.
- **Invariant 3 applied to Testing:** `HoneyDrunk.Agents.Testing.csproj` references only `HoneyDrunk.Agents.Abstractions`. No runtime, no Kernel, no AI, no Capabilities, no Operator, no Memory.
- **Strict Abstractions stance.** `AgentRequest.CallerCorrelationId` and `IAgentExecutionContext.CorrelationId` are `string`, not `CorrelationId`. Kernel reference lives in the runtime package's `AgentTelemetry`.
- **`IMemoryScope` is Memory's, not Agents's.** Do not author `IMemoryScope` in this scaffold; consume it from `HoneyDrunk.Memory.Abstractions` (if available; otherwise no-op placeholder per Human Prereqs).
- **`IChatClient` is direct from AI, not via `IToolInvoker`.** `IToolInvoker` routes tool calls to Capabilities. The two paths are distinct.
- **In-process registry per D11.** `DefaultAgentLifecycle` uses `ConcurrentDictionary` keyed by `agentId`. No cross-host persistence at stand-up.
- **Records drop `I`; interfaces keep it.** `AgentRequest`, `AgentResult`, `AgentExecutionError`, `AgentTraceEntry`, `ToolInvocationRequest`, `ToolInvocationResult`, `ToolInvocationError`, `AgentMemoryWriteRequest`, `AgentMemoryQueryRequest`, `AgentMemoryReadResult` are records. The five D3 interfaces have `I`. The `AgentMemory*` prefix on the memory-side records disambiguates from Memory Node's own shapes (`MemoryEntry`, `MemoryQuery`) — Agents owns request/result records at its surface; Memory owns its store-level records.
- **Function-calling mechanism for v0.1.0:** generic adapter keyed by `ModelCapabilityDeclaration`. Per-model translation rules read from App Config via `IConfigProvider` (no hardcoded per-provider logic in code). Per-provider adapter classes are deferred to follow-up packets if a specific provider's payload shape proves intractable through the generic mechanism.
- **Upstream conditional — Memory only.** AI / Capabilities / Operator `.Abstractions 0.1.0` are hard cross-initiative dependencies declared in this packet's frontmatter; the filing pipeline's `addBlockedBy` wiring keeps the Hive board item Blocked until those upstream scaffold issues close. There is no placeholder escape for those three. Memory is the lone exception: if `HoneyDrunk.Memory.Abstractions 0.1.0` has not shipped, `DefaultAgentMemory` ships as a placeholder no-op with a structured warning and a follow-up packet wires the real composition once Memory lands.
- **Canary on scaffolding PR is expected to skip.** Post-merge verification via throwaway breaking-change PR.

**Key Files:**
- `HoneyDrunk.Agents.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Agents.Abstractions/` — 5 interface files + supporting records
- `src/HoneyDrunk.Agents/` — `DefaultAgent`, `DefaultAgentLifecycle`, `DefaultToolInvoker`, `DefaultAgentMemory`, `FunctionCallAdapter`, `AgentTelemetry`, `ServiceCollectionExtensions`
- `src/HoneyDrunk.Agents.Testing/` — in-memory implementations + `DeterministicClock` + `RecordingExecutionLogger`
- `.github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml`
- `README.md`, `CHANGELOG.md` (repo-level + per-package)
- `tests/HoneyDrunk.Agents.Tests/`, `tests/HoneyDrunk.Agents.Testing.Tests/`

**Contracts:**
- Five D3 interfaces authored fresh in `HoneyDrunk.Agents.Abstractions`.
- Supporting records authored alongside.
- Contract-shape canary baseline established at this packet's commit.
