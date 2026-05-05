---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Capabilities
labels: ["feature", "tier-2", "ai", "scaffolding", "new-node", "adr-0017"]
dependencies: ["packet:01", "packet:02", "packet:03"]
adrs: ["ADR-0017"]
wave: 3
initiative: adr-0017-honeydrunk-capabilities-standup
node: honeydrunk-capabilities
---

# Feature: Stand up the HoneyDrunk.Capabilities repo — solution, three packages, contracts, CI, in-memory testing fixture

## Summary
Bring the empty `HoneyDrunk.Capabilities` repo from zero to first-shippable state per ADR-0017. Land the solution layout, the three package families (`Abstractions`, runtime, `Testing` fixture), the four D3 contracts inside `HoneyDrunk.Capabilities.Abstractions`, default registry/invoker/Auth-backed guard implementations in the runtime, the in-memory registry/dispatcher/permissive guard fixture in `HoneyDrunk.Capabilities.Testing`, the standard CI pipeline (PR core + release + nightly + secrets + contract-shape canary), and the contract-shape canary scoped to `HoneyDrunk.Capabilities.Abstractions` per ADR-0017 D8 and the Capabilities canary invariant (number assigned by packet 02 — see Constraints below).

This is the unblocker for the five AI-sector Nodes that consume Capabilities (Agents, Operator, Memory, Knowledge, Evals) and for any domain Node that registers an agent-callable tool (Data, Notify, Vault). After this packet merges and a `0.1.0` tag lands, those Nodes can compile against `HoneyDrunk.Capabilities.Abstractions` and start their own work in parallel.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Capabilities`

## Motivation
ADR-0017 establishes *what* HoneyDrunk.Capabilities is and what contracts it exposes. The repo is created by packet 03 but is otherwise empty — no `.slnx`, no projects, no CI, no contracts. Five AI-sector Nodes plus every tool-registering domain Node are blocked on this single repo coming online. Standing it up is the highest-leverage unblock available after packet 03 closes.

This packet bundles the full stand-up:

- The Node has three packages (`Abstractions`, runtime, `Testing` fixture), not the typical two.
- The four D3 contracts must all land in the first commit so the contract-shape canary has a baseline.
- The `Testing` fixture is required for downstream Nodes (especially Evals) to write deterministic tests against Capabilities without standing up a full Auth policy resolver.
- Per the user's standing convention, a new Node's scaffold work bundles into one packet rather than fragmenting across many — fragmentation creates ordering hazards inside an empty repo.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Capabilities/
├── HoneyDrunk.Capabilities.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── .editorconfig                    (from HoneyDrunk.Standards)
├── .gitignore
├── .github/
│   └── workflows/
│       ├── pr-core.yml              (calls Actions/pr-core.yml)
│       ├── release.yml              (calls Actions/release.yml)
│       ├── nightly-deps.yml         (calls Actions/nightly-deps.yml)
│       ├── nightly-security.yml     (calls Actions/nightly-security.yml)
│       └── api-compatibility.yml    (calls Actions/job-api-compatibility.yml — D8 canary)
├── src/
│   ├── HoneyDrunk.Capabilities.Abstractions/
│   │   ├── HoneyDrunk.Capabilities.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ICapabilityRegistry.cs
│   │   ├── CapabilityDescriptor.cs
│   │   ├── ICapabilityInvoker.cs
│   │   ├── ICapabilityGuard.cs
│   │   └── (request/response types — see "Contract details" below)
│   ├── HoneyDrunk.Capabilities/
│   │   ├── HoneyDrunk.Capabilities.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs    (AddHoneyDrunkCapabilities)
│   │   ├── Registry/
│   │   │   └── DefaultCapabilityRegistry.cs  (in-process versioned registry)
│   │   ├── Dispatch/
│   │   │   └── DefaultCapabilityInvoker.cs   (guard + dispatch pipeline)
│   │   ├── Authorization/
│   │   │   └── AuthBackedCapabilityGuard.cs  (delegates to HoneyDrunk.Auth)
│   │   └── Telemetry/
│   │       └── CapabilityTelemetry.cs        (uses ITelemetryActivityFactory)
│   └── HoneyDrunk.Capabilities.Testing/
│       ├── HoneyDrunk.Capabilities.Testing.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── InMemoryCapabilityRegistry.cs
│       ├── InMemoryCapabilityInvoker.cs
│       └── PermissiveCapabilityGuard.cs       (allow-all guard for tests)
└── tests/
    ├── HoneyDrunk.Capabilities.Abstractions.Tests/  (compile-only smoke tests)
    ├── HoneyDrunk.Capabilities.Tests/               (DefaultCapabilityRegistry, DefaultCapabilityInvoker, AuthBackedCapabilityGuard tests)
    └── HoneyDrunk.Capabilities.Testing.Tests/       (InMemory* fixtures verified against Abstractions contracts)
```

### Solution

`HoneyDrunk.Capabilities.slnx` references the three `src/*` projects and the three `tests/*` projects. Solution-level `Directory.Build.props` sets:

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <Authors>HoneyDrunk Studios</Authors>
    <PackageProjectUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Capabilities</PackageProjectUrl>
    <RepositoryUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Capabilities</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
    <PublishRepositoryUrl>true</PublishRepositoryUrl>
    <IncludeSymbols>true</IncludeSymbols>
    <SymbolPackageFormat>snupkg</SymbolPackageFormat>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
  </PropertyGroup>

  <!-- Version applies to shipping projects only. Test projects are excluded from
       the solution-shared-version rule per invariant 27. The IsTestProject
       MSBuild property is set to true by Microsoft.NET.Test.Sdk's targets when
       a test project imports it; the negative condition therefore matches src/* but not tests/*. -->
  <PropertyGroup Condition="'$(IsTestProject)' != 'true'">
    <Version>0.1.0</Version>
  </PropertyGroup>
</Project>
```

Per invariant 27 — "All projects in a solution share one version and move together. Every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit." — every src project carries the same `Version` (0.1.0 for this initial release). Test projects are excluded from version-bump scope; the `Condition="'$(IsTestProject)' != 'true'"` wrapper on the `<Version>` PropertyGroup enforces this so test projects do not pick up the version from `Directory.Build.props`.

### Contract details — `HoneyDrunk.Capabilities.Abstractions`

All four D3 contracts. Records drop the `I` prefix; interfaces keep it (Grid-wide naming rule).

```csharp
// ICapabilityRegistry.cs
namespace HoneyDrunk.Capabilities.Abstractions;

public interface ICapabilityRegistry
{
    Task RegisterAsync(CapabilityDescriptor descriptor, CancellationToken cancellationToken = default);
    Task<CapabilityDescriptor?> ResolveAsync(string name, string version, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<CapabilityDescriptor>> ListAsync(CancellationToken cancellationToken = default);
    Task<IReadOnlyList<CapabilityDescriptor>> ListVersionsAsync(string name, CancellationToken cancellationToken = default);
}
```

The registry key is the pair `(name, version)` per ADR-0017 D6. Unversioned registration is forbidden — the descriptor record requires a non-null/non-empty `Version` field, and `RegisterAsync` validates this and throws on violation. `ListVersionsAsync(name)` returns every registered version of a named tool so callers can iterate available versions when policy permits.

```csharp
// CapabilityDescriptor.cs (record — drops I prefix per Grid-wide naming rule)
public sealed record CapabilityDescriptor(
    string Name,
    string Version,
    string OwningNodeId,             // string, not NodeId — Abstractions stays HoneyDrunk-dependency-free
    string Description,
    CapabilityParameter[] Parameters,
    CapabilityReturnType ReturnType,
    string[] RequiredPermissions);   // policy names resolved by ICapabilityGuard

public sealed record CapabilityParameter(
    string Name,
    string SchemaJson,                // JSON-schema fragment for the parameter
    bool Required,
    string? Description);

public sealed record CapabilityReturnType(
    string SchemaJson,                // JSON-schema fragment for the return value
    string? Description);
```

**Tool-schema versioning model — fixed at scaffold per D6.** ADR-0017 D6 said "every registered tool descriptor carries an explicit `version` field" and "the specific versioning *model* is deferred to the scaffold packet." This packet picks **plain semantic-version strings** (`"1.0.0"`, `"1.1.0"`, `"2.0.0"`) as the format — `Version` is a `string`, validated by the registry as non-empty (parsing rules, e.g. SemVer compliance, are enforced by analyzer or runtime guard rather than by the type system, to avoid pulling a `SemanticVersion` library into Abstractions). The decision tradeoff: SemVer strings are familiar, mechanical to compare, and avoid coupling the descriptor to a third-party version type. Future packets can tighten parsing if needed.

```csharp
// ICapabilityInvoker.cs
public interface ICapabilityInvoker
{
    Task<CapabilityInvocationResult> InvokeAsync(
        CapabilityInvocationRequest request,
        CancellationToken cancellationToken = default);
}

public sealed record CapabilityInvocationRequest(
    string CapabilityName,
    string CapabilityVersion,
    string ArgumentsJson,                  // JSON-encoded arguments matching CapabilityDescriptor.Parameters
    string CallerCorrelationId);           // string, not CorrelationId — Abstractions stays HoneyDrunk-dependency-free

public sealed record CapabilityInvocationResult(
    bool Success,
    string? ResultJson,                    // JSON-encoded result matching CapabilityDescriptor.ReturnType
    CapabilityInvocationError? Error);

public sealed record CapabilityInvocationError(
    CapabilityErrorCode Code,
    string Message,
    string? DetailsJson);

public enum CapabilityErrorCode
{
    /// <summary>The named capability is not registered with the registry.</summary>
    NotRegistered = 0,
    /// <summary>The named capability is registered but the requested version is not.</summary>
    VersionNotFound = 1,
    /// <summary>The capability guard denied the invocation.</summary>
    Unauthorized = 2,
    /// <summary>Argument JSON does not validate against the descriptor's parameter schema.</summary>
    InvalidArguments = 3,
    /// <summary>The handler ran but threw or returned a failure.</summary>
    ExecutionFailed = 4,
    /// <summary>The invocation was cancelled before the handler completed.</summary>
    Cancelled = 5,
    /// <summary>Caller-supplied CallerCorrelationId disagrees with the ambient IGridContext.CorrelationId.</summary>
    InvalidCorrelationId = 6,
}
```

The `Code` field is a typed `CapabilityErrorCode` enum, not a string — adding or removing a value is a public-symbol diff that the contract-shape canary catches. This is intentional: a string with a comment listing legal values would let value removals slip through silently, which the canary's enforcement model is supposed to prevent. Each enum member carries XML doc summarizing when the runtime emits it.

`CapabilityErrorCode` is part of the four-frozen-contracts surface monitored by the contract-shape canary — even though it is a value type rather than a hot-path interface, its stable shape matters because every consumer's error-handling path branches on its values. Removing or reordering a value is a breaking change. The canary scope set in `api-compatibility.yml` is the whole `HoneyDrunk.Capabilities.Abstractions` assembly, so the enum is covered without additional configuration.

```csharp
// ICapabilityGuard.cs
public interface ICapabilityGuard
{
    Task<CapabilityGuardDecision> CheckAsync(
        CapabilityDescriptor descriptor,
        CapabilityInvocationRequest request,
        CancellationToken cancellationToken = default);
}

public sealed record CapabilityGuardDecision(
    bool Allow,
    string? DenyReason,
    string[] EvaluatedPolicies);
```

The guard returns a structured decision (allow + evaluated-policy list, or deny + reason + evaluated-policy list). The default `AuthBackedCapabilityGuard` (in the runtime package) translates `descriptor.RequiredPermissions` into Auth's `IAuthorizationPolicy` evaluations and aggregates the results.

`HoneyDrunk.Capabilities.Abstractions` references **only** `Microsoft.Extensions.*` abstractions per invariant 1 — specifically `Microsoft.Extensions.Logging.Abstractions` for any logger contracts and `Microsoft.Extensions.Options.Abstractions` if needed. **Do not** reference any other `HoneyDrunk.*` package from Abstractions, including `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Auth.Abstractions`. This keeps the strict-Abstractions stance per `repos/HoneyDrunk.Capabilities/invariants.md:5` and ADR-0017 D2 (which already reads `Zero runtime dependencies beyond \`Microsoft.Extensions.*\` abstractions.`).

**Strict Abstractions stance is deliberate, not a defect.** Concretely:

- `CapabilityDescriptor.OwningNodeId` is `string`, not `HoneyDrunk.Kernel.Abstractions.NodeId`.
- `CapabilityInvocationRequest.CallerCorrelationId` is `string`, not `HoneyDrunk.Kernel.Abstractions.CorrelationId`.
- `ICapabilityGuard` does not transit any Auth type — it works in `descriptor.RequiredPermissions` (string array of policy names). The runtime guard in the `HoneyDrunk.Capabilities` package is what imports `HoneyDrunk.Auth` and translates strings into `IAuthorizationPolicy` evaluations.

GridContext propagation onto invocation activities lives in the runtime package's `CapabilityTelemetry` (which uses Kernel's `ITelemetryActivityFactory`) — not in any Abstractions type.

**First-pass shape; subject to refinement before v0.2.0 baseline lock.** The exact member sets of `CapabilityInvocationRequest`/`Result`/`Error` and the `CapabilityErrorCode` enum are first-pass. The contract-shape canary established in this packet makes any post-v0.1.0 change a deliberate version-bump event, so the executing agent should land workable shapes here without overdesigning — refinement before downstream consumers lock against v0.2.0 is expected.

**Known shape question for v0.2.0:** `CapabilityParameter.Required` is potentially redundant with what a JSON Schema `SchemaJson` already encodes (the standard `required` keyword on object schemas). The two are kept independent in v0.1.0 to avoid pre-committing to a JSON-Schema parser at the boundary, but the duplication invites drift (a parameter could be marked `Required: true` while its schema permits omission, or vice versa). Revisit this before v0.2.0 — either remove `Required` and require callers to read it out of `SchemaJson`, or document an authoritative-source rule. Out of scope for this packet.

### Runtime details — `HoneyDrunk.Capabilities`

`HoneyDrunk.Capabilities` references:
- `HoneyDrunk.Capabilities.Abstractions` (project reference)
- `HoneyDrunk.Kernel` (for `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext`)
- `HoneyDrunk.Auth` (for `IAuthorizationPolicy` evaluation in `AuthBackedCapabilityGuard` per ADR-0017 D5/D10)
- `Microsoft.Extensions.DependencyInjection.Abstractions`
- `Microsoft.Extensions.Hosting.Abstractions`
- `Microsoft.Extensions.Logging.Abstractions`

Three default implementations:

- **`DefaultCapabilityRegistry`** — in-process, thread-safe, version-aware. Uses a `ConcurrentDictionary<string, ConcurrentDictionary<string, CapabilityDescriptor>>` keyed by `(name → version → descriptor)`. `RegisterAsync` validates that `descriptor.Name` and `descriptor.Version` are non-empty and that `(name, version)` is not already registered. `ResolveAsync` returns null for missing entries; `ListVersionsAsync` returns the inner dictionary's values for the named tool.
- **`DefaultCapabilityInvoker`** — pipeline:
  1. **Reconcile correlation IDs.** Read the ambient `IGridContext.CorrelationId` via `IGridContextAccessor` (Kernel) and compare against `request.CallerCorrelationId`. If `request.CallerCorrelationId` is non-empty and does not match the ambient `CorrelationId.ToString()` value, return `CapabilityInvocationResult(Success: false, Error: { Code: InvalidCorrelationId })`. If `request.CallerCorrelationId` is empty, accept the ambient value silently. The runtime treats the ambient `IGridContext.CorrelationId` as authoritative; `CallerCorrelationId` is the *string mirror for Abstractions parity* (Abstractions cannot reference `Kernel.CorrelationId`), not an independent ID source.
  2. Resolve descriptor from registry (return `CapabilityErrorCode.NotRegistered` for an unknown name, `CapabilityErrorCode.VersionNotFound` for a known name with an unknown version)
  3. Call `ICapabilityGuard.CheckAsync` (return `Unauthorized` if denied, including the deny reason and evaluated policies)
  4. Open a `CapabilityInvocation` activity via `CapabilityTelemetry`, propagating the ambient `IGridContext` (CorrelationId, CausationId) onto the activity tags.
  5. Dispatch to the registered handler — handler resolution for v0.1.0 uses a simple `IServiceProvider`-based lookup keyed by `(name, version)`, registered via DI helpers from `ServiceCollectionExtensions`. Handlers throwing produce `ExecutionFailed`; cancellation produces `Cancelled`.
  6. Close the activity with success/error attributes
- **`AuthBackedCapabilityGuard`** — depends on `HoneyDrunk.Auth`'s `IAuthorizationPolicy` resolver. For each `descriptor.RequiredPermissions[i]` (string), resolves the matching policy via Auth and evaluates it against the current `IGridContext`'s authenticated identity. Aggregates: all-allow ⇒ allow, any-deny ⇒ deny with the first deny reason. The list of evaluated policy names is returned in `CapabilityGuardDecision.EvaluatedPolicies`.
- **`CapabilityTelemetry`** — wraps `RegisterAsync`/`ResolveAsync`/`InvokeAsync` calls in `ITelemetryActivityFactory`-created activities, emits per-call attributes (capability name, version, owning node, decision, deny reason if any, latency). This is the "Capabilities emits, Pulse observes" surface from D7. GridContext / CorrelationId propagation onto activity tags also lives here in the runtime package — not in `HoneyDrunk.Capabilities.Abstractions`, which stays HoneyDrunk-dependency-free.

Service registration:

```csharp
// ServiceCollectionExtensions.cs
public static IServiceCollection AddHoneyDrunkCapabilities(
    this IServiceCollection services,
    Action<CapabilitiesOptions>? configure = null)
{
    services.AddSingleton<ICapabilityRegistry, DefaultCapabilityRegistry>();
    services.AddScoped<ICapabilityInvoker, DefaultCapabilityInvoker>();
    services.AddScoped<ICapabilityGuard, AuthBackedCapabilityGuard>();
    // Tool handlers registered by consumer via AddCapabilityHandler<TDescriptorMatch, THandler>()
    return services;
}
```

`AddCapabilityHandler` is a small extension that takes the descriptor `(name, version)` pair and a delegate or `ICapabilityHandler` implementation, registers both, and registers the descriptor with the registry at `IStartupHook` time.

### Testing fixture details — `HoneyDrunk.Capabilities.Testing`

The `Testing` fixture exists for two distinct downstream consumers:

- **Evals** — needs a deterministic registry/invoker/guard chain for reproducible test runs without spinning up real Auth policy resolution.
- **Other AI-sector and domain Nodes' unit tests** — need to compose `ICapabilityRegistry`/`Invoker`/`Guard` without referencing the runtime package or pulling in Auth.

Implementation:

```csharp
// InMemoryCapabilityRegistry.cs
public sealed class InMemoryCapabilityRegistry : ICapabilityRegistry
{
    // identical-shape, simpler implementation than DefaultCapabilityRegistry —
    // backed by a plain Dictionary, single-threaded assumption, no telemetry
}

// InMemoryCapabilityInvoker.cs
public sealed class InMemoryCapabilityInvoker : ICapabilityInvoker
{
    // takes a registry + a guard + a handler delegate dictionary, dispatches synchronously
}

// PermissiveCapabilityGuard.cs
public sealed class PermissiveCapabilityGuard : ICapabilityGuard
{
    // always returns CapabilityGuardDecision(Allow: true, DenyReason: null, EvaluatedPolicies: [])
    // intended for unit tests where the guard surface is not under test
}
```

`HoneyDrunk.Capabilities.Testing` references **only** `HoneyDrunk.Capabilities.Abstractions` (project reference) and the test-relevant `Microsoft.Extensions.*` packages — no `HoneyDrunk.Kernel`, no `HoneyDrunk.Auth`. Per invariant 3 (provider/companion packages depend on the parent Node's contracts package, not the runtime), `Testing` references `Abstractions`, never the runtime. This is the same pattern Vault uses for `HoneyDrunk.Vault.Providers.InMemory` referencing `HoneyDrunk.Vault.Abstractions`-equivalent.

### CI workflows

All five workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows. No bespoke CI logic in the Capabilities repo.

```yaml
# .github/workflows/pr-core.yml
name: PR Core
on:
  pull_request:
    branches: [main]
jobs:
  core:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/pr-core.yml@main
    with:
      dotnet-version: '10.0.x'
```

```yaml
# .github/workflows/api-compatibility.yml — ADR-0017 D8 / Capabilities canary invariant
name: API Compatibility (Abstractions)
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/HoneyDrunk.Capabilities.Abstractions/**'
jobs:
  abstractions-shape:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main
    with:
      project-path: src/HoneyDrunk.Capabilities.Abstractions/HoneyDrunk.Capabilities.Abstractions.csproj
```

The path filter ensures the canary only runs when Abstractions changes — keeps PR feedback fast for runtime/testing-only changes. The whole-assembly diff produced by `job-api-compatibility.yml` is sufficient to enforce D8: per the Capabilities downstream-coupling invariant, Abstractions is the only thing downstream Nodes compile against, so any shape drift in any public type in Abstractions counts.

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    tags:
      - 'v*.*.*'
jobs:
  release:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/release.yml@main
    with:
      dotnet-version: '10.0.x'
    secrets: inherit
```

Tags are human-pushed per invariant 27 — agents do not push tags. The release workflow packs and publishes all three `src/*` projects in a single tag-driven run.

`nightly-deps.yml` and `nightly-security.yml` follow the same thin-caller pattern — copy the configurations from `HoneyDrunk.Auth` or `HoneyDrunk.Vault` for reference. The exact `with:` and `secrets:` blocks should match those repos verbatim so nightly runs converge across Grid Nodes.

### `HoneyDrunk.Standards` wiring

Each `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets="all"` per invariant 26:

```xml
<ItemGroup>
  <PackageReference Include="HoneyDrunk.Standards" Version="*" PrivateAssets="all" />
</ItemGroup>
```

This pulls in the StyleCop ruleset, `.editorconfig`, and analyzer suite that every Grid repo uses.

### Documentation

- **Repo `README.md`** — purpose statement, package matrix, "How to consume from a downstream Node" snippet showing `AddHoneyDrunkCapabilities()` + `AddCapabilityHandler<...>()`, link to ADR-0017.
- **Repo `CHANGELOG.md`** — `## [0.1.0] - 2026-MM-DD` entry covering the entire scaffold landing.
- **Per-package `README.md`** — purpose, public API surface summary, install command. Required by invariant 12 for new packages.
- **Per-package `CHANGELOG.md`** — `## [0.1.0]` entry for each package introduced in this packet.

## Affected Files
Entire repo is created from this packet. Notable new files:
- `HoneyDrunk.Capabilities.slnx`, `Directory.Build.props`, `README.md`, `CHANGELOG.md`, `.editorconfig`, `.gitignore`
- `src/HoneyDrunk.Capabilities.Abstractions/` — 4 contract files + supporting record/type files + `.csproj` + `README.md` + `CHANGELOG.md`
- `src/HoneyDrunk.Capabilities/` — `.csproj`, `ServiceCollectionExtensions.cs`, `Registry/DefaultCapabilityRegistry.cs`, `Dispatch/DefaultCapabilityInvoker.cs`, `Authorization/AuthBackedCapabilityGuard.cs`, `Telemetry/CapabilityTelemetry.cs`, `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.Capabilities.Testing/` — `.csproj`, `InMemoryCapabilityRegistry.cs`, `InMemoryCapabilityInvoker.cs`, `PermissiveCapabilityGuard.cs`, `README.md`, `CHANGELOG.md`
- `tests/*` — three test projects with at least smoke-test coverage
- `.github/workflows/` — 5 workflow files

## NuGet Dependencies

Every new `.csproj` lists `HoneyDrunk.Standards` (`PrivateAssets="all"`) per invariant 26.

### `HoneyDrunk.Capabilities.Abstractions.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

(No other PackageReference. Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages, only `Microsoft.Extensions.*` abstractions are permitted, and even those only when needed. Nothing here needs them.)

### `HoneyDrunk.Capabilities.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel` | For `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext` |
| `HoneyDrunk.Auth` | For `IAuthorizationPolicy` evaluation in `AuthBackedCapabilityGuard` (ADR-0017 D5/D10) |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | DI registration helpers |
| `Microsoft.Extensions.Hosting.Abstractions` | For startup hook integration |
| `Microsoft.Extensions.Logging.Abstractions` | Logger contracts |

Project reference: `HoneyDrunk.Capabilities.Abstractions`.

### `HoneyDrunk.Capabilities.Testing.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | for DI helper registration in test fixtures |

Project reference: `HoneyDrunk.Capabilities.Abstractions`. **No reference to `HoneyDrunk.Capabilities` runtime, no reference to `HoneyDrunk.Kernel`, no reference to `HoneyDrunk.Auth`.** The `Testing` package depends on the contract surface only (invariant 3 applied to a non-provider companion package).

### Test projects
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.NET.Test.Sdk` | Standard |
| `xunit` | Standard |
| `xunit.runner.visualstudio` | Standard |
| `Microsoft.Extensions.DependencyInjection` | For DI in registry/invoker/guard tests |
| `NSubstitute` | For mocking `IAuthorizationPolicy` evaluation in `AuthBackedCapabilityGuard` tests |

Project references as appropriate to each `.Tests` project.

## Boundary Check
- [x] All work inside `HoneyDrunk.Capabilities`. No edits to other Grid repos.
- [x] `HoneyDrunk.Capabilities.Abstractions` carries zero `HoneyDrunk.*` references — invariant 1.
- [x] `HoneyDrunk.Capabilities.Testing` references only `HoneyDrunk.Capabilities.Abstractions` — invariant 3 applied to the Testing fixture.
- [x] No tool implementations live in any Capabilities package — `repos/HoneyDrunk.Capabilities/invariants.md:14` ("Tool implementations never live in the Capabilities package"). The scaffold ships registry, invoker, guard, telemetry only.
- [x] Every invocation passes through `ICapabilityGuard` via `DefaultCapabilityInvoker` — `repos/HoneyDrunk.Capabilities/invariants.md:8` ("Every tool invocation passes through a permission check"). No bypass surface.
- [x] Tool descriptors require non-empty `Version`; `RegisterAsync` validates and throws — D6 enforced.
- [x] No secrets in code. The Auth dependency in `AuthBackedCapabilityGuard` resolves policy by name via `HoneyDrunk.Auth`'s already-stable contracts; no credentials touched.
- [x] Records (`CapabilityDescriptor`, `CapabilityParameter`, `CapabilityReturnType`, `CapabilityInvocationRequest`, `CapabilityInvocationResult`, `CapabilityInvocationError`, `CapabilityGuardDecision`) all drop the `I` prefix; interfaces (`ICapabilityRegistry`, `ICapabilityInvoker`, `ICapabilityGuard`) keep it (Grid-wide naming rule).

## Acceptance Criteria
- [ ] `HoneyDrunk.Capabilities.slnx` builds clean from a fresh clone via `dotnet build` with no warnings (warnings-as-errors).
- [ ] All four D3 contracts present in `HoneyDrunk.Capabilities.Abstractions` with XML documentation per invariant 13.
- [ ] `HoneyDrunk.Capabilities.Abstractions` has zero `HoneyDrunk.*` PackageReference or ProjectReference entries (invariant 1 enforced).
- [ ] `HoneyDrunk.Capabilities.Testing` has zero references to `HoneyDrunk.Capabilities` (the runtime), `HoneyDrunk.Kernel`, or `HoneyDrunk.Auth`. Only `HoneyDrunk.Capabilities.Abstractions` and Microsoft.Extensions.*.
- [ ] `HoneyDrunk.Capabilities` runtime exposes `AddHoneyDrunkCapabilities()` extension; `ICapabilityRegistry`, `ICapabilityInvoker`, `ICapabilityGuard` all resolve from DI after registration.
- [ ] `DefaultCapabilityRegistry.RegisterAsync` rejects descriptors with null/empty `Version` (per ADR-0017 D6 / the descriptor-versioning invariant). A unit test covers this.
- [ ] `DefaultCapabilityInvoker` calls `ICapabilityGuard.CheckAsync` before dispatch on every invocation. A unit test verifies the guard is called and that an `Unauthorized` result short-circuits dispatch.
- [ ] `DefaultCapabilityInvoker` reconciles `request.CallerCorrelationId` against the ambient `IGridContext.CorrelationId` (resolved via Kernel's `IGridContextAccessor`). If `CallerCorrelationId` is non-empty and disagrees with the ambient value, the invoker returns `CapabilityInvocationResult(Success: false, Error: { Code: InvalidCorrelationId })`. Empty `CallerCorrelationId` is accepted silently and the ambient value is used. Unit tests cover all three cases (empty caller, matching caller, mismatched caller).
- [ ] `AuthBackedCapabilityGuard` translates `descriptor.RequiredPermissions` into Auth policy evaluations via `IAuthorizationPolicy` (mocked in tests). All-allow ⇒ allow; any-deny ⇒ deny.
- [ ] `CapabilityTelemetry` emits a `Capability.Register` activity on every `RegisterAsync` call, tagged with `capability.name`, `capability.version`, `capability.owning_node`. Verified by a test using a `TestActivityListener`-style fixture against `ITelemetryActivityFactory`.
- [ ] `CapabilityTelemetry` emits a `Capability.Resolve` activity on every `ResolveAsync` call, tagged with `capability.name`, `capability.version`, and `capability.resolved` (bool). Verified by a test.
- [ ] `CapabilityTelemetry` emits a `Capability.Invoke` activity on every `InvokeAsync` call, tagged with `capability.name`, `capability.version`, `capability.guard_decision` (Allow/Deny), `capability.outcome` (Success/error code), and the ambient `correlation_id` and `causation_id` from `IGridContext`. Verified by a test that runs a full happy-path invocation and asserts the emitted activity tags.
- [ ] `HoneyDrunk.Capabilities.Testing` ships `InMemoryCapabilityRegistry`, `InMemoryCapabilityInvoker`, and `PermissiveCapabilityGuard`. Each is fully functional and verified by unit tests against the four D3 contracts.
- [ ] All five `.github/workflows/*.yml` files present and reference `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/*@main`.
- [ ] `api-compatibility.yml` runs on PR. On the scaffolding PR itself the workflow runs against an absent `main` baseline and reports `status: skipped` per the `HoneyDrunk.Actions/.github/actions/api/check-compatibility/action.yml` missing-baseline path (it emits a `::warning::` and exits 0 when `git worktree add` against the baseline ref fails) — that is correct first-build behavior, not a failure. The scaffolding PR merge establishes the `main` baseline. **Verify post-merge** by opening a throwaway PR that removes a public member from `ICapabilityRegistry` (or any other frozen contract); the workflow must fail with breaking-changes-detected. Revert the throwaway PR after observation.
- [ ] `pr-core.yml` passes on the initial scaffolding PR (build + tests + analyzers + dependency scan + secret scan).
- [ ] Repo-level `CHANGELOG.md` has a `## [0.1.0]` entry covering the scaffold; per-package `CHANGELOG.md` files each have their own `## [0.1.0]` entry naming the package's specific introductions (per invariants 12 and 27).
- [ ] Repo-level `README.md` and per-package `README.md` files all present per invariant 12.
- [ ] Test suite runs and passes — minimum coverage: `DefaultCapabilityRegistry` register/resolve/list-versions happy path + version-validation rejection test, `DefaultCapabilityInvoker` guard-allow + guard-deny tests, `AuthBackedCapabilityGuard` all-allow + first-deny tests using mocked `IAuthorizationPolicy`, `InMemoryCapabilityRegistry`/`Invoker`/`PermissiveCapabilityGuard` smoke tests.
- [ ] All projects in the solution carry the same `Version` (0.1.0), excluding test projects (invariant 27).
- [ ] Manual confirmation that pushing tag `v0.1.0` triggers `release.yml` and produces NuGet packages for the three `src/*` projects (do not actually push the tag — verify the workflow exists and a tag-push trigger is configured).

## Human Prerequisites
- [ ] Confirm OIDC federated credential exists for the `HoneyDrunk.Capabilities` repo's release workflow against the Grid's NuGet publishing identity. Cross-link: [`infrastructure/oidc-federated-credentials.md`](../../../../infrastructure/oidc-federated-credentials.md). The Grid has a standard NuGet publishing identity used by every Node — confirm `repo:HoneyDrunkStudios/HoneyDrunk.Capabilities:ref:refs/tags/v*` is in its federated credential list.
- [ ] After this packet's PR merges, push tag `v0.1.0` from `main` to trigger the first NuGet publish. Tags are human-pushed per invariant 27.
- [ ] Repo settings: branch protection on `main` requires `pr-core / core` and `api-compatibility / abstractions-shape` checks, no force-pushes, signed commits not required (matches other Grid repos). Most of these are seeded by packet 03's repo-creation steps; confirm they are still in place at this point.
- [ ] No Azure resource provisioning required for this packet — HoneyDrunk.Capabilities is a library Node, not a deployable.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. — `HoneyDrunk.Capabilities.Testing` references `HoneyDrunk.Capabilities.Abstractions`, not `HoneyDrunk.Capabilities` runtime.

> **Invariant 3:** Provider packages depend on their parent Node's contracts, not internal implementation details. When a Node splits contracts into a separate package (as `HoneyDrunk.Capabilities.Abstractions` does), companion packages reference that package. — Applied here to the `Testing` fixture as well: it references `Abstractions`, never the runtime.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — `HoneyDrunk.Capabilities` references `Kernel` and `Auth`; nothing in `HoneyDrunk.Capabilities.*` is referenced back from Kernel or Auth.

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning. — This packet is the establishment of HoneyDrunk.Capabilities's solution and CI pipeline.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. Repo-level `CHANGELOG.md` is mandatory; per-package `CHANGELOG.md` and `README.md` required for each package.

> **Invariant 13:** All public APIs have XML documentation. Enforced by HoneyDrunk.Standards analyzers. — All four D3 contracts and their supporting types must carry `///` summaries.

> **Invariant 14:** Canary tests validate cross-Node boundaries. Each Node that depends on another has a `.Canary` project verifying integration assumptions. — Future-facing: downstream Nodes will add `.Canary` projects against `HoneyDrunk.Capabilities.Abstractions`. This packet does not author those — they belong with each downstream Node's stand-up. The Capabilities-side Canary covers Auth integration for `AuthBackedCapabilityGuard` and Kernel integration for context propagation; both can be added in a follow-up packet once Capabilities's runtime is exercising them in a deployable host.

> **Invariant 15:** Tests never depend on external services. Use InMemory providers for isolation. — `HoneyDrunk.Capabilities.Testing` exists specifically to satisfy this for downstream Nodes' tests.

> **Invariant 16:** No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only. — `HoneyDrunk.Capabilities.Testing` is **not** test code. It is a production-quality fixture *used by* tests. The package itself is not a test project; consumers reference it from their test projects.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. `HoneyDrunk.Standards` must be explicitly listed on every new .NET project (StyleCop + EditorConfig analyzers, `PrivateAssets: all`). — This packet's NuGet Dependencies section enumerates all three new `src/*` projects' references plus test project references.

> **Invariant 27:** All projects in a solution share one version and move together. When a version bump is warranted, every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit. — Initial scaffold ships at `0.1.0` across all three packages.

> **Capabilities downstream-coupling invariant (number assigned by packet 02):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Capabilities.Abstractions`. Composition against `HoneyDrunk.Capabilities` and `HoneyDrunk.Capabilities.Testing` is a host-time (and test-time) concern, resolved at application startup. Test projects may reference `HoneyDrunk.Capabilities.Testing` to pick up the in-memory fixture. Production projects must not. — Reinforced in this scaffold by giving `Abstractions` zero HoneyDrunk dependencies so consumers don't transit unintended pins.

> **Capabilities descriptor-versioning invariant (number assigned by packet 02):** Every registered capability descriptor carries an explicit version; the registry key is `(name, version)`. Unversioned registration is a build failure. — `DefaultCapabilityRegistry.RegisterAsync` validates `descriptor.Version` is non-empty and throws on violation; a unit test covers this.

> **Capabilities authorization invariant (number assigned by packet 02):** Authorization for capability invocation is resolved through `HoneyDrunk.Auth` policy via `ICapabilityGuard`. Capabilities does not maintain an independent permission model. Invocation paths must always pass through the guard before dispatch — no bypass surface exists. — `DefaultCapabilityInvoker` always calls `ICapabilityGuard.CheckAsync` before dispatching; a unit test verifies the guard short-circuits dispatch when it returns Allow=false. The default guard is `AuthBackedCapabilityGuard`, which delegates to `HoneyDrunk.Auth`'s `IAuthorizationPolicy`.

> **Capabilities contract-shape canary invariant (number assigned by packet 02):** The HoneyDrunk.Capabilities Node CI must include a contract-shape canary that fails the build on shape drift to `ICapabilityRegistry`, `CapabilityDescriptor`, `ICapabilityInvoker`, or `ICapabilityGuard` without a corresponding version bump. — `api-compatibility.yml` covers this by scoping to `HoneyDrunk.Capabilities.Abstractions`.

## Referenced ADR Decisions

**ADR-0017 D1 (Tool-registry and dispatch substrate):** HoneyDrunk.Capabilities is the AI sector's shared tool-registry and dispatch substrate, not an orchestrator. This scaffold ships only the substrate — no agent execution, no tool implementations, no policy management.

**ADR-0017 D2 (Package families):** Three package families — `Abstractions` + runtime + `Testing` fixture. All three land in this packet. The `Testing` package is a separate NuGet artifact, not a `Providers.*` slot, because there is no family of providers at the registry layer (no OpenAI-vs-Anthropic axis here).

**ADR-0017 D3 (Exposed contracts):** Four contracts. Records drop `I`; interfaces keep it. The placeholder `ICapability` and `ICapabilityPermission` entries from the prior catalog are **not** authored here — they are superseded by the D3 surface.

**ADR-0017 D5 (Authorization through Auth) and D10 (Auth dependency is first-class):** `AuthBackedCapabilityGuard` is the default `ICapabilityGuard` implementation. It delegates allow/deny decisions to `HoneyDrunk.Auth` via `IAuthorizationPolicy`. Capabilities does not invent its own permission model.

**ADR-0017 D6 (Tool-schema versioning principle, mechanism deferred):** Every descriptor carries an explicit `Version` field. The registry key is `(name, version)`. The scaffold packet picks **plain SemVer strings** as the format — `Version` is a `string`, validated as non-empty by the registry. SemVer parsing is enforced at runtime by analyzer rules (or a future invariant if drift appears), not by the type system. Future packets can tighten parsing without a breaking change to `CapabilityDescriptor` (the field stays `string`).

**ADR-0017 D7 (Telemetry direction):** `CapabilityTelemetry` emits via `ITelemetryActivityFactory` (Kernel). No Pulse package reference. Pulse consumes downstream — out of scope for this packet.

**ADR-0017 D8 (Contract-shape canary):** `api-compatibility.yml` is the canary. Scoped to `HoneyDrunk.Capabilities.Abstractions` since per D9 that is the only public-boundary package.

**ADR-0017 D9 (Downstream coupling):** `Abstractions` is dependency-clean so downstream Nodes can take it without pulling Kernel, Auth, or any other Grid dependency transitively.

**ADR-0017 D2 strict-Abstractions phrasing (already in the ADR text pre-filing):** The strict-Abstractions stance is the active rule. `HoneyDrunk.Capabilities.Abstractions` ships with zero `HoneyDrunk.*` references, including no `HoneyDrunk.Kernel.Abstractions`. Concretely: `CapabilityDescriptor.OwningNodeId` is `string`, `CapabilityInvocationRequest.CallerCorrelationId` is `string`. GridContext propagation lives in the runtime package's `CapabilityTelemetry`, not in any Abstractions type.

## Dependencies
- `packet:01` — catalog registration must land first so the Architecture catalogs match what this packet ships, and so the integration-points doc exists for the canary checklist.
- `packet:02` — the four Capabilities invariants (downstream coupling, descriptor versioning, Auth as authorization root, contract-shape canary) must exist in `constitution/invariants.md` at their assigned numbers before this packet's acceptance criteria reference them.
- `packet:03` — the GitHub repo must exist before this packet can be filed against it. Per the dispatch plan, packet 04 cannot be filed until packet 03 is closed.

## Labels
`feature`, `tier-2`, `ai`, `scaffolding`, `new-node`, `adr-0017`

## Agent Handoff

**Objective:** Take the empty `HoneyDrunk.Capabilities` repo (created by packet 03) and ship version 0.1.0 with the four D3 contracts, default registry/invoker/Auth-backed guard implementations, in-memory testing fixture, full CI, and the contract-shape canary scoped to Abstractions.

**Target:** HoneyDrunk.Capabilities, branch from `main`. (The repo exists at this point — packet 03 created it with an initial README. Branch from `main` for the first feature commit; do not push directly to `main`.)

**Context:**
- Goal: Unblock five AI-sector consumer Nodes (Agents, Operator, Memory, Knowledge, Evals) and every domain Node that registers an agent-callable tool (Data, Notify, Vault).
- Feature: ADR-0017 standup initiative — this is the substrate scaffold, the fourth and largest packet of the initiative.
- ADRs: ADR-0017 (sole governing ADR for the standup).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01, 02, and 03 of this initiative must complete first.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `HoneyDrunk.Capabilities.Abstractions.csproj` must contain no `HoneyDrunk.*` PackageReference or ProjectReference. The `HoneyDrunk.Standards` reference uses `PrivateAssets="all"` so it does not propagate.
- **Invariant 3 applied to the `Testing` fixture:** The `Testing` package depends on the parent Node's contracts package, not the runtime. — `HoneyDrunk.Capabilities.Testing.csproj` must reference only `HoneyDrunk.Capabilities.Abstractions`. No reference to `HoneyDrunk.Capabilities` runtime, no reference to `HoneyDrunk.Kernel`, no reference to `HoneyDrunk.Auth`.
- **`repos/HoneyDrunk.Capabilities/invariants.md:8`:** Every tool invocation passes through a permission check. `ICapabilityGuard` is evaluated before dispatch. No bypass path exists. — `DefaultCapabilityInvoker` calls `ICapabilityGuard.CheckAsync` on every invocation. Unit test covers this.
- **`repos/HoneyDrunk.Capabilities/invariants.md:11`:** Tool schemas are versioned. Breaking changes to a tool's parameter or return schema require a new version. — `CapabilityDescriptor.Version` is required; `DefaultCapabilityRegistry.RegisterAsync` validates and throws on null/empty.
- **`repos/HoneyDrunk.Capabilities/invariants.md:14`:** Tool implementations never live in the Capabilities package. Capabilities owns the registry and dispatch. Implementations live in their owning Nodes. — This scaffold ships zero tool implementations. Handler registration is a DI extension that consumers use to wire their Node's tools; it is not the implementation surface.
- **`repos/HoneyDrunk.Capabilities/invariants.md:17`:** Unregistered tool invocations fail fast. Attempting to invoke a tool that is not registered returns a structured error, not an exception. — `DefaultCapabilityInvoker` returns `CapabilityInvocationResult(Success: false, Error: { Code: CapabilityErrorCode.NotRegistered })` for an unregistered name (or `CapabilityErrorCode.VersionNotFound` if the name is registered but the version is not) for unregistered `(name, version)` pairs. No exception is thrown for the not-registered case (cancellation and execution failure produce different codes).
- **`repos/HoneyDrunk.Capabilities/invariants.md:20`:** GridContext is propagated through tool invocations. The dispatch pipeline carries CorrelationId and CausationId from agent to tool implementation. — `CapabilityTelemetry` enriches the activity with the current `IGridContext`. The runtime invoker picks up `IGridContext` via `IGridContextAccessor` from Kernel; `CallerCorrelationId` on the request is the *string* mirror so Abstractions can describe the propagation without referencing Kernel types.
- **Invariant 9 (Vault is the only source of secrets):** No secrets touched in this packet. The Auth dependency is policy resolution by name, not credentials.
- **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — Every one of the three `src/*` projects must ship a `README.md` and `CHANGELOG.md` in the same commit it is added.
- **Invariant 13:** All public APIs have XML documentation. — Every public type/member in `HoneyDrunk.Capabilities.Abstractions` carries `///` summaries. StyleCop rules from `HoneyDrunk.Standards` enforce this.
- **Invariant 26:** Packets for .NET code work must include `## NuGet Dependencies`. `HoneyDrunk.Standards` must be on every new .NET project. — Confirmed in the NuGet Dependencies section above.
- **Invariant 27:** All projects in a solution share one version. — Every `src/*.csproj` ships at `0.1.0`. Test projects do not bump.
- **Capabilities downstream-coupling invariant (assigned by packet 02):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Capabilities.Abstractions`. — Reinforced by keeping Abstractions HoneyDrunk-dependency-free.
- **Capabilities descriptor-versioning invariant (assigned by packet 02):** Every registered descriptor carries an explicit version. — Enforced at register-time in `DefaultCapabilityRegistry`.
- **Capabilities authorization invariant (assigned by packet 02):** Invocation paths always pass through `ICapabilityGuard`. — `DefaultCapabilityInvoker` calls the guard on every dispatch.
- **Capabilities contract-shape canary invariant (assigned by packet 02):** CI must include the canary on the four hot-path contracts. — `api-compatibility.yml` covers this by scoping to `HoneyDrunk.Capabilities.Abstractions`.
- **Canary on the scaffolding PR is expected to report `status: skipped`, not fail.** The shared `HoneyDrunk.Actions/.github/actions/api/check-compatibility/action.yml` emits `::warning::` and exits 0 with `status: skipped` when `git worktree add` against the baseline ref fails — which it always does on a first PR against a near-empty repo (the repo has only the README from packet 03, no Abstractions assembly to baseline against). Do not treat the skip as a misconfiguration. The scaffolding PR's merge establishes the `main` baseline; verification of the canary actually firing happens **post-merge** via a throwaway breaking-change PR that is reverted after observation.
- **Strict Abstractions stance is deliberate.** `HoneyDrunk.Capabilities.Abstractions` ships with zero `HoneyDrunk.*` references. This is the user's standing scoping resolution applied to ADR-0017 D2 (which already reads `Zero runtime dependencies beyond \`Microsoft.Extensions.*\` abstractions.`) and matches `repos/HoneyDrunk.Capabilities/invariants.md:5`. Concretely: `CapabilityDescriptor.OwningNodeId` is `string`, `CapabilityInvocationRequest.CallerCorrelationId` is `string`. Any GridContext/CorrelationId propagation belongs in the `HoneyDrunk.Capabilities` runtime package (specifically `CapabilityTelemetry`), not in Abstractions. Do not import `HoneyDrunk.Kernel.Abstractions` in any `HoneyDrunk.Capabilities.Abstractions` source file.
- **Records drop `I`; interfaces keep it.** `CapabilityDescriptor`, `CapabilityParameter`, `CapabilityReturnType`, `CapabilityInvocationRequest`, `CapabilityInvocationResult`, `CapabilityInvocationError`, `CapabilityGuardDecision` are all records. `ICapabilityRegistry`, `ICapabilityInvoker`, `ICapabilityGuard` are interfaces.
- **D3 is canonical, not the prior catalog placeholder.** Author exactly the four D3 contracts. Do **not** author `ICapability` or `ICapabilityPermission`. If a doc anywhere mentions them, that is drift to be cleaned up by packet 01 or as a follow-up — do not re-introduce the types.
- **Naming-collision discipline (D4).** Do not use the word "actions" to describe tool invocations in code, comments, or docs (the Ops Node `HoneyDrunk.Actions` owns that English word). Do not use `capabilities:` as a YAML/JSON key for runtime concepts (the superseded ADR-0004 used that as agent-definition frontmatter).

**Key Files:**
- `HoneyDrunk.Capabilities.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Capabilities.Abstractions/ICapabilityRegistry.cs`, `CapabilityDescriptor.cs`, `ICapabilityInvoker.cs`, `ICapabilityGuard.cs` and supporting record types in the same folder
- `src/HoneyDrunk.Capabilities/ServiceCollectionExtensions.cs`, `Registry/DefaultCapabilityRegistry.cs`, `Dispatch/DefaultCapabilityInvoker.cs`, `Authorization/AuthBackedCapabilityGuard.cs`, `Telemetry/CapabilityTelemetry.cs`
- `src/HoneyDrunk.Capabilities.Testing/InMemoryCapabilityRegistry.cs`, `InMemoryCapabilityInvoker.cs`, `PermissiveCapabilityGuard.cs`
- `.github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml`
- `README.md`, `CHANGELOG.md` (repo-level), per-package `README.md` and `CHANGELOG.md`
- `tests/HoneyDrunk.Capabilities.Tests/`, `tests/HoneyDrunk.Capabilities.Testing.Tests/`

**Contracts:**
- All four D3 contracts authored fresh in this packet inside `HoneyDrunk.Capabilities.Abstractions`.
- The contract-shape canary establishes its baseline against this packet's commit. Future shape changes to any public type in Abstractions trigger the canary.
