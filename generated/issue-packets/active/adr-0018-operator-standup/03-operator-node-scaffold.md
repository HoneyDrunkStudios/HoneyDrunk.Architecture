---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Operator
labels: ["feature", "tier-2", "ai", "scaffold", "adr-0018"]
dependencies: ["packet:01", "packet:02", "packet:02b"]
adrs: ["ADR-0018", "ADR-0030", "ADR-0031", "ADR-0005"]
accepts: ADR-0018
wave: 3
initiative: adr-0018-operator-standup
node: honeydrunk-operator
---

# Feature: Stand up the HoneyDrunk.Operator repo — solution, three packages, contracts, CI, in-memory testing fixture

## Summary

Bring the near-empty `HoneyDrunk.Operator` repo from zero to first-shippable state per ADR-0018. Land the solution layout, the three package families (`Abstractions`, runtime, `Testing` fixture), the eight Operator-owned D3 contracts inside `HoneyDrunk.Operator.Abstractions`, default runtime implementations (`DefaultApprovalGate`, `DefaultCircuitBreaker`, `DefaultCostGuard`, `AuthBackedDecisionPolicy`, `DefaultSafetyFilter`, `OperatorTelemetry`), the in-memory testing fixture, the standard CI pipeline (PR core + release + nightly + secrets), and the contract-shape canary scoped to `HoneyDrunk.Operator.Abstractions` per ADR-0018 D10 and the Operator canary invariant (number assigned by packet 02).

**Critical amendment:** per the 2026-05-16 ADR-0030/0031 amendment to ADR-0018, `IAuditLog` and `AuditEntry` are **NOT** authored in this packet. Those two contracts live in `HoneyDrunk.Audit.Abstractions` (separate Node standup ADR). Operator is a **consumer** of `IAuditLog` — at this packet's commit, the consumer wiring depends on whether `HoneyDrunk.Audit.Abstractions` has shipped. If it has, this scaffold takes a runtime dependency on it for audit emission. If it has not, the scaffold ships with a placeholder no-op `IAuditLog` consumer interface that fails-soft (logs a structured warning) and the Audit edge is wired in a follow-up packet once `HoneyDrunk.Audit.Abstractions 0.1.0` is available.

This is the unblocker for the six AI-sector Nodes that consume Operator (Agents, Flow, AI, Capabilities, Evals, Sim). After this packet merges and a `0.1.0` tag lands, those Nodes can compile against `HoneyDrunk.Operator.Abstractions`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Operator`

## Motivation

ADR-0018 establishes *what* HoneyDrunk.Operator is and what contracts it exposes. The repo is created on GitHub and cloned locally (packet 02b verifies), and carries drafting folders (`docs/`, `contracts/`, `policies/`, `prompts/`, `staging/`) with design notes — but no `.slnx`, no projects, no CI, no contracts. Six AI-sector Nodes plus every domain Node that needs policy enforcement on agent paths are blocked on this single repo coming online.

This packet is intentionally larger than typical bring-up packets because:

- The Node has three packages.
- The eight Operator-owned D3 contracts must all land in the first commit so the contract-shape canary has a baseline.
- The `Testing` fixture is required for downstream Nodes to compose Operator without standing up real Auth policy resolution.
- Per the user's standing convention, a new Node's scaffold work bundles into one packet rather than fragmenting.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Operator/
├── HoneyDrunk.Operator.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── .editorconfig                    (from HoneyDrunk.Standards)
├── .gitignore
├── .github/
│   └── workflows/
│       ├── pr-core.yml
│       ├── release.yml
│       ├── nightly-deps.yml
│       ├── nightly-security.yml
│       └── api-compatibility.yml    (D10 canary)
├── docs/         (existing drafting folder — kept as source material, not edited)
├── contracts/    (existing drafting folder — kept as source material, not edited)
├── policies/     (existing drafting folder — kept as source material, not edited)
├── prompts/      (existing drafting folder — kept as source material, not edited)
├── staging/      (existing drafting folder — kept as source material, not edited)
├── src/
│   ├── HoneyDrunk.Operator.Abstractions/
│   │   ├── HoneyDrunk.Operator.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IApprovalGate.cs
│   │   ├── ICircuitBreaker.cs
│   │   ├── ICostGuard.cs
│   │   ├── IDecisionPolicy.cs
│   │   ├── ISafetyFilter.cs
│   │   ├── ApprovalRequest.cs
│   │   ├── ApprovalDecision.cs
│   │   ├── CostEvent.cs
│   │   └── (supporting record/enum types)
│   ├── HoneyDrunk.Operator/
│   │   ├── HoneyDrunk.Operator.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs    (AddHoneyDrunkOperator)
│   │   ├── Approval/DefaultApprovalGate.cs
│   │   ├── Breaker/DefaultCircuitBreaker.cs
│   │   ├── Cost/DefaultCostGuard.cs
│   │   ├── Policy/AuthBackedDecisionPolicy.cs
│   │   ├── Safety/DefaultSafetyFilter.cs
│   │   ├── Telemetry/OperatorTelemetry.cs
│   │   └── Events/ApprovalEventEmitter.cs    (event-out per D8 — emits via ITransportPublisher or configured transport)
│   └── HoneyDrunk.Operator.Testing/
│       ├── HoneyDrunk.Operator.Testing.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── InMemoryApprovalGate.cs
│       ├── InMemoryCircuitBreaker.cs
│       ├── InMemoryCostGuard.cs
│       ├── PermissiveDecisionPolicy.cs
│       ├── PermissiveSafetyFilter.cs
│       └── RecordingApprovalEventEmitter.cs
└── tests/
    ├── HoneyDrunk.Operator.Abstractions.Tests/
    ├── HoneyDrunk.Operator.Tests/
    └── HoneyDrunk.Operator.Testing.Tests/
```

### Solution

`HoneyDrunk.Operator.slnx` references the three `src/*` projects and three `tests/*` projects. Solution-level `Directory.Build.props` sets target framework `net10.0`, nullable enable, implicit usings, warnings as errors, `Version` 0.1.0 (test projects excluded via `IsTestProject` condition), authors, repository URL, symbols/snupkg.

### Contract details — `HoneyDrunk.Operator.Abstractions`

All eight Operator-owned D3 contracts. Records drop `I` prefix; interfaces keep it.

```csharp
// IApprovalGate.cs
namespace HoneyDrunk.Operator.Abstractions;

public interface IApprovalGate
{
    Task<ApprovalDecision> RequestAsync(ApprovalRequest request, CancellationToken cancellationToken = default);
    Task<ApprovalDecision?> CheckStatusAsync(string approvalId, CancellationToken cancellationToken = default);
}
```

```csharp
// ICircuitBreaker.cs
public interface ICircuitBreaker
{
    Task<bool> IsAllowedAsync(string breakerName, CancellationToken cancellationToken = default);
    Task TripAsync(string breakerName, string reason, CancellationToken cancellationToken = default);
    Task ResetAsync(string breakerName, CancellationToken cancellationToken = default);
    Task<BreakerState> GetStateAsync(string breakerName, CancellationToken cancellationToken = default);
}

public enum BreakerState
{
    Closed = 0,
    Open = 1,
    HalfOpen = 2,
}
```

```csharp
// ICostGuard.cs
public interface ICostGuard
{
    Task<CostCheckResult> CheckBudgetAsync(string scope, string window, decimal amount, CancellationToken cancellationToken = default);
    Task RecordAsync(CostEvent costEvent, CancellationToken cancellationToken = default);
    Task<CostStatus> GetStatusAsync(string scope, string window, CancellationToken cancellationToken = default);
}

public sealed record CostCheckResult(bool Allowed, decimal Remaining, decimal Limit, string? DenyReason);
public sealed record CostStatus(decimal Spent, decimal Limit, decimal Remaining, string Window);
```

```csharp
// IDecisionPolicy.cs
public interface IDecisionPolicy
{
    Task<PolicyDecision> EvaluateAsync(ActionContext context, CancellationToken cancellationToken = default);
}

public sealed record ActionContext(string ActorId, string Action, string Resource, IReadOnlyDictionary<string, string> Attributes);
public sealed record PolicyDecision(PolicyOutcome Outcome, string? Reason, string[] EvaluatedRules);

public enum PolicyOutcome { Allow = 0, Deny = 1, RequireApproval = 2 }
```

```csharp
// ISafetyFilter.cs
public interface ISafetyFilter
{
    Task<SafetyFilterResult> CheckAsync(SafetyFilterRequest request, CancellationToken cancellationToken = default);
}

public sealed record SafetyFilterRequest(string Content, string ContentKind, IReadOnlyDictionary<string, string> Context);
public sealed record SafetyFilterResult(bool Allowed, string? BlockReason, string[] FiredRules);
```

```csharp
// ApprovalRequest.cs (record — no I prefix)
public sealed record ApprovalRequest(
    string ApprovalId,
    string Subject,
    string Action,
    IReadOnlyDictionary<string, string> Context,
    string RequestedScope,
    DateTimeOffset Expiry,
    string RequesterCorrelationId);
```

```csharp
// ApprovalDecision.cs
public sealed record ApprovalDecision(
    string ApprovalId,
    ApprovalOutcome Outcome,
    string ApproverIdentity,
    DateTimeOffset DecidedAt,
    string? Reason);

public enum ApprovalOutcome { Pending = 0, Approved = 1, Denied = 2, Expired = 3 }
```

```csharp
// CostEvent.cs
public sealed record CostEvent(
    string EventId,
    string AgentId,
    string TenantId,
    string Window,
    decimal Amount,
    string Unit,
    string Source,
    DateTimeOffset OccurredAt,
    string OperationCorrelationId);
```

`HoneyDrunk.Operator.Abstractions` references **only** `Microsoft.Extensions.*` abstractions per invariant 1 (specifically `Microsoft.Extensions.Logging.Abstractions`). **Do not** reference any other `HoneyDrunk.*` package from Abstractions — no `HoneyDrunk.Kernel.Abstractions`, no `HoneyDrunk.Auth.Abstractions`, no `HoneyDrunk.Data.Abstractions`. Identity/correlation fields are `string`, not strongly-typed Kernel types.

**`IAuditLog` and `AuditEntry` are NOT authored in this Abstractions package** per the 2026-05-16 ADR-0030/0031 amendment. Those contracts live in `HoneyDrunk.Audit.Abstractions`. The Operator runtime package consumes them; the Abstractions surface does not declare them.

**v0.1.0 shape baseline.** The member sets of `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter` and their supporting records ship as v0.1.0 contracts. The contract-shape canary established here makes any change to them a deliberate version-bump event under invariant 50. A separate follow-up packet (filed after the six downstream consumer Nodes start composing against `HoneyDrunk.Operator.Abstractions`) revisits the shapes once real consumer usage surfaces missing or surplus members — that packet, not this one, is the place for shape refinement.

### Runtime details — `HoneyDrunk.Operator`

`HoneyDrunk.Operator` references:
- `HoneyDrunk.Operator.Abstractions` (project)
- `HoneyDrunk.Kernel.Abstractions` (for `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext` contracts)
- `HoneyDrunk.Auth.Abstractions` (for `IAuthorizationPolicy` contract consumed by `AuthBackedDecisionPolicy` per D5)
- `HoneyDrunk.Data.Abstractions` (for `IRepository`, `IUnitOfWork` contracts for cost-ledger and approval-store persistence per D12)
- `HoneyDrunk.Vault.Abstractions` (for `IConfigProvider` contract to read cost rates, breaker thresholds, policies from App Config per D6)
- **Optionally** `HoneyDrunk.Audit.Abstractions` (for `IAuditLog`, `AuditEntry`) — depends on whether `HoneyDrunk.Audit.Abstractions 0.1.0` has shipped at this packet's commit time. **Simplification per S2:** if not yet shipped, do NOT introduce a placeholder no-op `IAuditLog` interface inside Operator. Instead, mark every prospective audit-emission site with a `TODO(audit): wire IAuditLog.AppendAsync once HoneyDrunk.Audit.Abstractions ships — see follow-up packet 04` comment and ship the scaffold without the audit edge. A follow-up packet adds the package reference and the actual `IAuditLog.AppendAsync` calls in one PR. The executing agent verifies at edit time by checking NuGet.org or `catalogs/contracts.json` for `honeydrunk-audit`'s status.
- `Microsoft.Extensions.DependencyInjection.Abstractions`
- `Microsoft.Extensions.Hosting.Abstractions`
- `Microsoft.Extensions.Logging.Abstractions`

Six default implementations:

- **`DefaultApprovalGate`** — issues an `ApprovalRequest` with a generated `ApprovalId`, persists via `IRepository`, emits an approval-needed event via `ApprovalEventEmitter` (event-out per D8), returns immediately with a `Pending` decision. Consumers poll `CheckStatusAsync` or subscribe to a completion event.
- **`DefaultCircuitBreaker`** — in-process state machine (Closed → Open → HalfOpen → Closed). Thresholds (failure count, half-open trial count, reset window) read from App Config via `IConfigProvider` at startup; refreshes on config change.
- **`DefaultCostGuard`** — in-process accumulator backed by `IRepository` for durability. Reads cost-rate tables from App Config via `IConfigProvider`. Throws (or returns DenyReason) when budget exceeded per D6.
- **`AuthBackedDecisionPolicy`** — depends on `HoneyDrunk.Auth`'s `IAuthorizationPolicy`. Evaluates `descriptor`-style rules sourced from App Config via `IConfigProvider`. Returns `Allow`/`Deny`/`RequireApproval`.
- **`DefaultSafetyFilter`** — pluggable rule chain. The default rule set is loaded from App Config; consumers can register custom `ISafetyRule` implementations via DI.
- **`OperatorTelemetry`** — wraps every gate / breaker / cost / decision / safety-filter call in `ITelemetryActivityFactory`-created activities. Emits per-call attributes per D7. GridContext / CorrelationId propagation lives here in the runtime package, not in Abstractions.

Plus one event-out component:

- **`ApprovalEventEmitter`** — emits `ApprovalRequest`-needed events via the configured transport (deferred to host configuration per D8; the scaffold supplies an `ITransportPublisher`-backed default and a no-op fallback). The wire shape is a follow-up packet's concern.

**Audit emission (conditional, S2 simplification).** If `HoneyDrunk.Audit.Abstractions` is available at packet-execution time, every gate / breaker / cost / approval / safety-filter decision in the runtime calls `IAuditLog.AppendAsync(AuditEntry)` per the ADR-0030/0031 amendment. If `HoneyDrunk.Audit.Abstractions` is **not** available, do **not** introduce a placeholder internal interface in Operator (no risk of a name collision with the real `IAuditLog` that lands in HoneyDrunk.Audit later). Instead, mark each prospective audit-emission site with:

```csharp
// TODO(audit): emit AuditEntry via IAuditLog.AppendAsync once
//   HoneyDrunk.Audit.Abstractions 0.1.0 ships. Tracked in follow-up
//   packet 04-operator-wire-audit-emission.md.
```

and leave the call site otherwise untouched (no log statement, no warning, no no-op). The follow-up packet adds the package reference, removes the TODO comments, and wires the actual `IAuditLog.AppendAsync` calls in one PR. This keeps the scaffold's internal surface free of throwaway types.

Service registration:

```csharp
public static IServiceCollection AddHoneyDrunkOperator(this IServiceCollection services, Action<OperatorOptions>? configure = null)
{
    services.AddSingleton<IApprovalGate, DefaultApprovalGate>();
    services.AddSingleton<ICircuitBreaker, DefaultCircuitBreaker>();
    services.AddSingleton<ICostGuard, DefaultCostGuard>();
    services.AddSingleton<IDecisionPolicy, AuthBackedDecisionPolicy>();
    services.AddSingleton<ISafetyFilter, DefaultSafetyFilter>();
    services.AddSingleton<ApprovalEventEmitter>();
    return services;
}
```

### Testing fixture — `HoneyDrunk.Operator.Testing`

In-memory implementations of every Operator-owned interface:

- `InMemoryApprovalGate` — script-driven decisions; default returns `Approved` immediately for deterministic tests.
- `InMemoryCircuitBreaker` — always-closed default; configurable to simulate trips.
- `InMemoryCostGuard` — in-memory accumulator with caller-supplied budget.
- `PermissiveDecisionPolicy` — always returns `Allow`. Intended for unit tests where policy is not under test.
- `PermissiveSafetyFilter` — always returns `Allowed: true`.
- `RecordingApprovalEventEmitter` — captures emitted events for test assertions.

`HoneyDrunk.Operator.Testing` references **only** `HoneyDrunk.Operator.Abstractions` (project reference) and the test-relevant `Microsoft.Extensions.*` packages. **No reference to** `HoneyDrunk.Operator` runtime, `HoneyDrunk.Kernel`, `HoneyDrunk.Auth`, `HoneyDrunk.Data`, or `HoneyDrunk.Vault`. Per invariant 3 applied to companion packages.

### CI workflows

All five workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows. The `api-compatibility.yml` workflow is path-filtered to `src/HoneyDrunk.Operator.Abstractions/**` so it only runs when Abstractions changes.

```yaml
# .github/workflows/api-compatibility.yml — ADR-0018 D10 canary
name: API Compatibility (Abstractions)
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/HoneyDrunk.Operator.Abstractions/**'
jobs:
  abstractions-shape:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main
    with:
      project-path: src/HoneyDrunk.Operator.Abstractions/HoneyDrunk.Operator.Abstractions.csproj
```

The whole-assembly diff is sufficient to cover the four hot-path interfaces named in invariant 50 (`IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `ISafetyFilter`) plus the records and the `IDecisionPolicy` interface — per D11 invariant 47, Abstractions is the only thing downstream Nodes compile against.

### `HoneyDrunk.Standards` wiring

Each `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets="all"` per invariant 26.

### Documentation

- **Repo `README.md`** — purpose statement, package matrix, "How to consume" snippet with `AddHoneyDrunkOperator()` + `AddOperatorPolicy<T>()` + an event-subscriber-side example, link to ADR-0018. Include a note about the ADR-0030/0031 amendment and the relocated audit contracts.
- **Repo `CHANGELOG.md`** — `## [0.1.0] - 2026-MM-DD` entry covering the scaffold.
- **Per-package `README.md` + `CHANGELOG.md`** — required by invariant 12.

### Drafting folders disposition

The existing folders at the repo root (`docs/`, `contracts/`, `policies/`, `prompts/`, `staging/`) are **source material** for the scaffolding agent. The agent should:

1. Read them to understand the intended Operator design.
2. NOT commit them verbatim into `src/` projects.
3. NOT delete them in this packet (a follow-up cleanup packet decides whether they remain in the repo as reference docs or move under `docs/`).

The scaffold agent's commit should leave the drafting folders untouched.

## Affected Files
Entire repo (except drafting folders). Notable new files listed under "Repository layout" above.

## NuGet Dependencies

Every new `.csproj` lists `HoneyDrunk.Standards` (`PrivateAssets="all"`) per invariant 26.

### `HoneyDrunk.Operator.Abstractions.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

(No other PackageReference. Invariant 1.)

### `HoneyDrunk.Operator.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext` contracts. Use `.Abstractions` (not runtime) per invariant 2 — runtime packages depend on upstream Abstractions, not upstream runtime. |
| `HoneyDrunk.Auth.Abstractions` | For `IAuthorizationPolicy` consumed by `AuthBackedDecisionPolicy` per D5. `.Abstractions` only — the runtime Auth package would pull a JWT-validation stack Operator doesn't need. |
| `HoneyDrunk.Data.Abstractions` | For `IRepository`, `IUnitOfWork` contracts per D12. `.Abstractions` only — Operator composes against the contract surface; the concrete provider is wired by the host. |
| `HoneyDrunk.Vault.Abstractions` | For `IConfigProvider` per D6. `.Abstractions` only — the host wires a provider implementation; Operator just consumes the contract. |
| `HoneyDrunk.Audit.Abstractions` | Conditional — only if `HoneyDrunk.Audit.Abstractions 0.1.0` has shipped at this packet's execution time. See S2 simplification: if not yet shipped, ship the runtime **without** the package reference and mark every prospective audit call site with a `TODO(audit): wire IAuditLog.AppendAsync once HoneyDrunk.Audit.Abstractions 0.1.0 ships — follow-up packet 04` comment. The follow-up packet adds the reference and emission in one PR. No placeholder no-op interface, no internal name collision risk. |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | DI helpers |
| `Microsoft.Extensions.Hosting.Abstractions` | Startup hooks |
| `Microsoft.Extensions.Logging.Abstractions` | Logger contracts |

Project reference: `HoneyDrunk.Operator.Abstractions`.

**Note on `.Abstractions` vs runtime dependencies.** Operator's runtime package consumes only contract surfaces from upstream Nodes. There is no scenario at v0.1.0 that requires reaching into Kernel/Auth/Data/Vault concrete implementations — telemetry activity creation, authorization-policy evaluation, repository/unit-of-work, and config-provider reads are all expressed through interfaces in the corresponding `.Abstractions` packages. This keeps Operator composable: a host wiring Operator picks its own Kernel/Auth/Data/Vault runtime providers without inheriting Operator's pin.

### `HoneyDrunk.Operator.Testing.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | DI helpers |

Project reference: `HoneyDrunk.Operator.Abstractions`. **No reference to** `HoneyDrunk.Operator` runtime or any other Grid Node.

### Test projects
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.NET.Test.Sdk` | Standard |
| `xunit` | Standard |
| `xunit.runner.visualstudio` | Standard |
| `Microsoft.Extensions.DependencyInjection` | For DI in runtime tests |
| `NSubstitute` | For mocking Auth / Kernel / Data dependencies |

## Boundary Check
- [x] All work inside `HoneyDrunk.Operator`.
- [x] `HoneyDrunk.Operator.Abstractions` carries zero `HoneyDrunk.*` references — invariant 1.
- [x] `HoneyDrunk.Operator.Testing` references only `HoneyDrunk.Operator.Abstractions` — invariant 3 applied.
- [x] `IAuditLog` / `AuditEntry` NOT authored in Abstractions per the 2026-05-16 ADR-0030/0031 amendment.
- [x] No tool implementations live in any Operator package — Operator owns policy primitives only.
- [x] Records drop `I` prefix; interfaces keep it.
- [x] No secrets in code. Auth dependency is policy-resolution by name.

## Acceptance Criteria
- [ ] `HoneyDrunk.Operator.slnx` builds clean from a fresh clone via `dotnet build` with no warnings.
- [ ] All eight Operator-owned D3 contracts present in `HoneyDrunk.Operator.Abstractions` with XML documentation per invariant 13.
- [ ] `IAuditLog` and `AuditEntry` are **NOT** authored in `HoneyDrunk.Operator.Abstractions` (relocated to HoneyDrunk.Audit per ADR-0030/0031 amendment). `rg -n 'interface IAuditLog|record AuditEntry' src/HoneyDrunk.Operator.Abstractions/` returns zero matches.
- [ ] **No internal `IAuditLog` placeholder anywhere in the repo** — per S6, the scaffold ships without a no-op placeholder type to avoid future name collision with the real `IAuditLog` interface that lands in `HoneyDrunk.Audit.Abstractions`. `rg -n 'IAuditLog' src/ tests/` returns matches **only** if `HoneyDrunk.Audit.Abstractions` was pulled in as a package at execution time (in which case the matches are usages of the genuine contract, not an internal placeholder). If Audit wasn't yet shipped, the only `IAuditLog` references should be `TODO(audit)` comments — see Audit emission (conditional, S2 simplification).
- [ ] `HoneyDrunk.Operator.Abstractions` has zero `HoneyDrunk.*` PackageReference or ProjectReference entries (invariant 1).
- [ ] `HoneyDrunk.Operator.Testing` has zero references to `HoneyDrunk.Operator` runtime, `HoneyDrunk.Kernel`, `HoneyDrunk.Auth`, `HoneyDrunk.Data`, `HoneyDrunk.Vault`. Only `HoneyDrunk.Operator.Abstractions` and Microsoft.Extensions.*.
- [ ] `HoneyDrunk.Operator` runtime exposes `AddHoneyDrunkOperator()`; all five contracts resolve from DI.
- [ ] `DefaultCostGuard`, `DefaultCircuitBreaker`, `AuthBackedDecisionPolicy`, `DefaultSafetyFilter` all read configuration from App Config via `IConfigProvider`. No hardcoded thresholds, rates, or policies. Unit test verifies one of each.
- [ ] `DefaultApprovalGate` emits an approval-needed event via `ApprovalEventEmitter` and persists the request via `IRepository`. Unit test verifies emission.
- [ ] `OperatorTelemetry` emits per-call activities for every gate / breaker / cost / decision / safety-filter call. Verified by test.
- [ ] `HoneyDrunk.Operator.Testing` ships in-memory implementations of every Operator-owned interface. Each verified by unit test.
- [ ] All five `.github/workflows/*.yml` files present and reference `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/*@main`.
- [ ] `api-compatibility.yml` path-filtered to `src/HoneyDrunk.Operator.Abstractions/**`. On the scaffolding PR the workflow reports `status: skipped` against the absent `main` baseline (expected first-build behavior). Post-merge verification via a throwaway breaking-change PR — see procedure under Human Prerequisites.
- [ ] `pr-core.yml` passes on the scaffolding PR.
- [ ] Repo-level `CHANGELOG.md` has `## [0.1.0]` entry; per-package `CHANGELOG.md` each have `## [0.1.0]` entries.
- [ ] Repo-level `README.md` and per-package `README.md` present per invariant 12. Repo README notes the ADR-0030/0031 amendment.
- [ ] Test suite minimum coverage: `DefaultCircuitBreaker` Closed→Open→HalfOpen→Closed state machine; `DefaultCostGuard` accumulation + budget-exceeded denial; `AuthBackedDecisionPolicy` Allow/Deny/RequireApproval against mocked `IAuthorizationPolicy`; `DefaultApprovalGate` emission + status check; `OperatorTelemetry` activity emission; in-memory testing-fixture smoke tests.
- [ ] All projects in the solution share `Version` 0.1.0 (test projects excluded via `IsTestProject`).
- [ ] Manual confirmation that pushing tag `v0.1.0` triggers `release.yml` (verify workflow exists; do not push yet).
- [ ] Drafting folders (`docs/`, `contracts/`, `policies/`, `prompts/`, `staging/`) remain untouched.
- [ ] **`ICostController` does not appear anywhere** in the scaffold. `rg -n 'ICostController' src/ tests/` returns zero matches.

## Human Prerequisites
- [ ] Packet 02b complete — repo settings verified, branch protection in place, labels seeded, local working tree on `main`, OIDC federated credential confirmed.
- [ ] After this packet's PR merges, push tag `v0.1.0` from `main` to trigger the first NuGet publish. Tags are human-pushed per invariant 27.
- [ ] **Throwaway breaking-change PR procedure.** After the scaffolding PR merges (which sets the canary's baseline), open a throwaway PR off `main` that intentionally breaks one of the four hot-path interfaces — e.g. add a parameter to `IApprovalGate.RequestAsync` or rename a property on `CostEvent`. Open the PR, confirm the `api-compatibility / abstractions-shape` check **fails** with a shape-drift report, then close the PR without merging. This proves the canary is wired correctly against the v0.1.0 baseline. The throwaway PR is never merged. Track this as a one-off verification step, not a recurring concern.
- [ ] **Branch protection sequencing.** After the throwaway PR above confirms the canary fires, add `api-compatibility / abstractions-shape` to required checks in the repo's branch protection rule on `main`.
- [ ] **Audit Node dependency decision (executing agent, S2 simplification).** At packet execution time, check whether `HoneyDrunk.Audit.Abstractions 0.1.0` is available (via NuGet.org or `catalogs/contracts.json` `honeydrunk-audit.status`). If yes, take the package reference and wire audit emission. If no, ship **without** any audit edge — no internal placeholder interface, no no-op fallback, no warning logs. Mark each prospective emission site with a `TODO(audit): wire IAuditLog.AppendAsync once HoneyDrunk.Audit.Abstractions ships — follow-up packet 04` comment. File the follow-up packet (`04-operator-wire-audit-emission.md`) immediately after this packet's PR merges, regardless of which branch was taken — if the package was already available the follow-up is a no-op verification; if not, it carries the real wiring work.
- [ ] After merge + `v0.1.0` ships, file a SonarCloud onboarding follow-up modeled on the equivalent Kernel onboarding packet.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer.

> **Invariant 3:** Companion packages (Testing, Providers) depend on the parent Node's contracts package, not internal implementation details.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from env vars, config files, or provider SDKs.

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit.

> **Invariant 13:** All public APIs have XML documentation. Enforced by HoneyDrunk.Standards analyzers.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. `HoneyDrunk.Standards` must be on every new .NET project.

> **Invariant 27:** All projects in a solution share one version and move together.

> **Operator downstream-coupling invariant (number assigned by packet 02, default 47):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Operator.Abstractions`. Production projects must not reference `HoneyDrunk.Operator.Testing`.

> **Operator App-Config-sourcing invariant (number assigned by packet 02, default 48):** Cost-rate tables, breaker thresholds, decision policies, and safety-filter configuration are sourced from Azure App Configuration via Vault's `IConfigProvider`. No hardcoded values.

> **Operator approval-event-out invariant (number assigned by packet 02, default 49):** Operator does not take a runtime dependency on Communications. Approval-needed events are emitted via the configured transport.

> **Operator contract-shape canary invariant (number assigned by packet 02, default 50):** CI must include a contract-shape canary on `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `ISafetyFilter`.

## Referenced ADR Decisions

**ADR-0018 D1 (Substrate Node):** Operator owns human-policy primitives. It does not reason; it constrains.

**ADR-0018 D2 (Package families):** Three packages — Abstractions + runtime + Testing.

**ADR-0018 D3 (Ten exposed contracts as originally written; this packet authors the eight Operator-owned after the amendment):** Original D3 — six interfaces + four records (ten total). After the 2026-05-16 ADR-0030 D5 relocation of `IAuditLog`/`AuditEntry` to `HoneyDrunk.Audit.Abstractions`, the Operator-owned set is **eight** — five interfaces (`IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter`) + three records (`CostEvent`, `ApprovalRequest`, `ApprovalDecision`).

**ADR-0018 D5 (Authorization through Auth):** `AuthBackedDecisionPolicy` and `DefaultApprovalGate` delegate to Auth's `IAuthorizationPolicy`.

**ADR-0018 D6 (App Configuration sourcing):** Cost rates, breaker thresholds, decision-policy rule sets, safety-filter config all sourced from App Config via `IConfigProvider`.

**ADR-0018 D7 (Telemetry direction):** `OperatorTelemetry` emits via Kernel's `ITelemetryActivityFactory`; no Pulse runtime edge.

**ADR-0018 D8 (Approval event-out):** `ApprovalEventEmitter` is the event-out surface. Communications is the consumer; Operator does not call `ICommunicationOrchestrator`.

**ADR-0018 D10 (Contract-shape canary):** `api-compatibility.yml` scoped to `HoneyDrunk.Operator.Abstractions`.

**ADR-0018 D11 (Downstream coupling):** Abstractions is HoneyDrunk-dependency-free so consumers don't inherit transitive Kernel/Auth/Data pins.

**ADR-0018 D12 (First-class deps on Kernel, Auth, Data):** Runtime package takes those edges; Abstractions does not.

**ADR-0018 Amendment (2026-05-16, driven by ADR-0030 D5 with ADR-0031 standup):** `IAuditLog` and `AuditEntry` are NOT in this Abstractions package. They live in `HoneyDrunk.Audit.Abstractions` per ADR-0030 D5 ("Contract reconciliation — `IAuditLog`/`AuditEntry` are promoted; Operator becomes a consumer"). ADR-0031 is the corresponding HoneyDrunk.Audit Node standup that ships those contracts. Operator's runtime consumes them when Audit Node ships.

**ADR-0005 (already accepted, App Config split):** HoneyDrunk.Operator is a library Node. App Config is a Grid-shared resource — the runtime reads from it via `IConfigProvider` when composed into a deployable host.

## Dependencies
- `packet:01` — catalog registration must land first.
- `packet:02` — four invariants must exist before this packet's acceptance criteria reference them.
- `packet:02b` — repo settings verified, local clone confirmed.

## Labels
`feature`, `tier-2`, `ai`, `scaffold`, `adr-0018`

## Agent Handoff

**Objective:** Take the `HoneyDrunk.Operator` repo (carries drafting folders + LICENSE + README) and ship version 0.1.0 with the eight Operator-owned D3 contracts, default runtime, in-memory testing fixture, full CI, and the contract-shape canary scoped to Abstractions. Respect the ADR-0030/0031 amendment relocating audit.

**Target:** HoneyDrunk.Operator, branch from `main`.

**Context:**
- Goal: Unblock six AI-sector consumer Nodes (Agents, Flow, AI, Capabilities, Evals, Sim).
- Feature: ADR-0018 standup initiative — this is the substrate scaffold, packet 03.
- ADRs: ADR-0018 (sole standup); ADR-0030, ADR-0031 (amendment relocating audit); ADR-0005 (App Config split).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01, 02, 02b.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. `HoneyDrunk.Operator.Abstractions.csproj` contains no `HoneyDrunk.*` PackageReference or ProjectReference.
- **Invariant 3 applied to Testing:** `HoneyDrunk.Operator.Testing.csproj` references only `HoneyDrunk.Operator.Abstractions`. No reference to runtime, Kernel, Auth, Data, Vault.
- **Audit relocation is mandatory.** Do NOT author `IAuditLog` or `AuditEntry` in `HoneyDrunk.Operator.Abstractions`. They live in `HoneyDrunk.Audit.Abstractions` per the 2026-05-16 ADR-0030/0031 amendment.
- **`ICostController` is dead.** Author `ICostGuard`. If you find any reference to `ICostController` in the drafting folders, do not propagate it.
- **Records drop `I`; interfaces keep it.** `ApprovalRequest`, `ApprovalDecision`, `CostEvent`, `CostCheckResult`, `CostStatus`, `ActionContext`, `PolicyDecision`, `SafetyFilterRequest`, `SafetyFilterResult` are records. `IApprovalGate`, `ICircuitBreaker`, `ICostGuard`, `IDecisionPolicy`, `ISafetyFilter` are interfaces.
- **Strict Abstractions stance.** No HoneyDrunk-side types in Abstractions records. `ApprovalRequest.RequesterCorrelationId`, `CostEvent.OperationCorrelationId` are `string`, not `CorrelationId`.
- **Event-out for approval per D8.** `ApprovalEventEmitter` is the event-out surface. Do NOT take a runtime reference to `HoneyDrunk.Communications` from anywhere in this scaffold.
- **App Config sourcing per D6.** All thresholds, rates, policies, rule sets read from `IConfigProvider`. No hardcoded values. Unit tests verify config-driven behavior.
- **Drafting folders are read-only source material.** Don't commit them into `src/`. Don't delete them. Leave them as-is.
- **Canary on scaffolding PR is expected to skip.** Verification of canary firing happens post-merge via a throwaway breaking-change PR.
- **Audit Node dependency conditional (S2 simplification).** Check at edit time whether `HoneyDrunk.Audit.Abstractions 0.1.0` is shipped. If yes, take the package reference and emit `IAuditLog.AppendAsync` at every gate / breaker / cost / approval / safety-filter site. If no, ship the scaffold **without** an audit edge — no placeholder interface, no no-op fallback, no warning logs. Mark each prospective emission site with a `TODO(audit): wire IAuditLog.AppendAsync once HoneyDrunk.Audit.Abstractions ships — follow-up packet 04` comment. A follow-up packet adds the reference and the emission in one PR.

**Key Files:**
- `HoneyDrunk.Operator.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Operator.Abstractions/` — eight contract files + supporting record/enum files
- `src/HoneyDrunk.Operator/` — six default implementations + `ApprovalEventEmitter` + `ServiceCollectionExtensions`
- `src/HoneyDrunk.Operator.Testing/` — in-memory implementations + `RecordingApprovalEventEmitter`
- `.github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml`
- `README.md`, `CHANGELOG.md` (repo-level + per-package)
- `tests/HoneyDrunk.Operator.Tests/`, `tests/HoneyDrunk.Operator.Testing.Tests/`

**Contracts:**
- Eight Operator-owned D3 contracts authored fresh in `HoneyDrunk.Operator.Abstractions`.
- `IAuditLog`/`AuditEntry` NOT authored here.
