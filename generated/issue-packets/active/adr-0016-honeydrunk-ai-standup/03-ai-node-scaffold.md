---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "scaffold", "adr-0016"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0016", "ADR-0010", "ADR-0005"]
wave: 2
initiative: adr-0016-honeydrunk-ai-standup
node: honeydrunk-ai
---

# Feature: Stand up the HoneyDrunk.AI repo — solution, packages, contracts, CI, InMemory provider

## Summary
Bring the empty `HoneyDrunk.AI` repo from zero to first-shippable state per ADR-0016. Land the solution layout, the six package families (Abstractions + runtime + four provider slots), the seven D3 contracts inside `HoneyDrunk.AI.Abstractions`, default routing/cost/policy implementations in the `HoneyDrunk.AI` runtime, the deterministic InMemory provider, the standard CI pipeline (PR core + release + nightly), and the contract-shape canary scoped to `HoneyDrunk.AI.Abstractions` per ADR-0016 D8 / invariant 41.

This is the unblocker for the six AI-sector Nodes currently waiting on AI (Capabilities, Operator, Agents, Memory, Knowledge, Evals). After this packet merges and a `0.1.0` tag lands, those Nodes can compile against `HoneyDrunk.AI.Abstractions` and start their own work in parallel.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.AI`

## Motivation
ADR-0016 establishes *what* HoneyDrunk.AI is and what contracts it exposes. The repo carries a working tree on disk but is empty — no `.slnx`, no projects, no CI, no contracts. Six AI-sector Nodes are blocked on this single repo coming online. Standing it up is the highest-leverage unblock available right now.

This packet is intentionally larger than typical bring-up packets because:

- The AI Node has six packages, not the usual one or two.
- The seven D3 contracts must all land in the first commit so the contract-shape canary has a baseline.
- The InMemory provider is required for downstream Nodes to write tests against AI without network calls.
- Per the user's standing convention, a new Node's scaffold work bundles into one packet rather than fragmenting across many — fragmentation creates ordering hazards inside an empty repo.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.AI/
├── HoneyDrunk.AI.slnx
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
│   ├── HoneyDrunk.AI.Abstractions/
│   │   ├── HoneyDrunk.AI.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IChatClient.cs
│   │   ├── IEmbeddingGenerator.cs
│   │   ├── IModelProvider.cs
│   │   ├── IModelRouter.cs
│   │   ├── IRoutingPolicy.cs
│   │   ├── ModelCapabilityDeclaration.cs
│   │   ├── ICostLedger.cs
│   │   └── (request/response types — see "Contract details" below)
│   ├── HoneyDrunk.AI/
│   │   ├── HoneyDrunk.AI.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs    (AddHoneyDrunkAI)
│   │   ├── Routing/
│   │   │   ├── DefaultModelRouter.cs
│   │   │   └── PolicyLoader.cs               (reads policies from IConfigProvider)
│   │   ├── Cost/
│   │   │   └── DefaultCostLedger.cs          (reads rate-table from IConfigProvider)
│   │   └── Telemetry/
│   │       └── InferenceTelemetry.cs         (uses ITelemetryActivityFactory)
│   ├── HoneyDrunk.AI.Providers.OpenAI/
│   │   ├── HoneyDrunk.AI.Providers.OpenAI.csproj
│   │   ├── README.md
│   │   └── CHANGELOG.md
│   │   (no implementation in this packet — slot only, throws NotImplementedException with TODO ADR-0016 follow-up)
│   ├── HoneyDrunk.AI.Providers.Anthropic/      (same pattern)
│   ├── HoneyDrunk.AI.Providers.AzureOpenAI/    (same pattern)
│   └── HoneyDrunk.AI.Providers.InMemory/
│       ├── HoneyDrunk.AI.Providers.InMemory.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── InMemoryModelProvider.cs            (deterministic — see "InMemory provider details")
│       └── InMemoryCapabilities.cs
└── tests/
    ├── HoneyDrunk.AI.Abstractions.Tests/        (compile-only smoke tests)
    ├── HoneyDrunk.AI.Tests/                     (DefaultModelRouter unit tests, DefaultCostLedger unit tests)
    └── HoneyDrunk.AI.Providers.InMemory.Tests/  (deterministic-output assertions)
```

### Solution

`HoneyDrunk.AI.slnx` references all six `src/*` projects and all three `tests/*` projects. Solution-level `Directory.Build.props` sets:

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <Version>0.1.0</Version>
    <Authors>HoneyDrunk Studios</Authors>
    <PackageProjectUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.AI</PackageProjectUrl>
    <RepositoryUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.AI</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
    <PublishRepositoryUrl>true</PublishRepositoryUrl>
    <IncludeSymbols>true</IncludeSymbols>
    <SymbolPackageFormat>snupkg</SymbolPackageFormat>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
  </PropertyGroup>
</Project>
```

Per invariant 27, every project in the solution carries the same `Version` (0.1.0 for this initial release). Test projects are excluded from version-bump scope.

### Contract details — `HoneyDrunk.AI.Abstractions`

All seven D3 contracts. Records drop the `I` prefix; interfaces keep it. Match the **shape** of `Microsoft.Extensions.AI`'s `IChatClient` and `IEmbeddingGenerator` (D6) but declare them as distinct types under the `HoneyDrunk.AI.Abstractions` namespace.

```csharp
// IChatClient.cs
namespace HoneyDrunk.AI.Abstractions;

public interface IChatClient
{
    Task<ChatCompletion> CompleteAsync(
        IReadOnlyList<ChatMessage> messages,
        ChatOptions? options = null,
        CancellationToken cancellationToken = default);

    IAsyncEnumerable<ChatCompletionUpdate> CompleteStreamingAsync(
        IReadOnlyList<ChatMessage> messages,
        ChatOptions? options = null,
        CancellationToken cancellationToken = default);
}
```

Supporting types (`ChatMessage`, `ChatCompletion`, `ChatCompletionUpdate`, `ChatOptions`, `ChatRole`) live alongside `IChatClient.cs` in the same namespace. Match Microsoft.Extensions.AI's shapes where they are stable (the parameter shape and member set), not the literal type identities.

```csharp
// IEmbeddingGenerator.cs
public interface IEmbeddingGenerator
{
    Task<IReadOnlyList<Embedding>> GenerateAsync(
        IEnumerable<string> values,
        EmbeddingOptions? options = null,
        CancellationToken cancellationToken = default);
}
```

```csharp
// IModelProvider.cs (provider slot)
public interface IModelProvider
{
    string ProviderId { get; }
    ModelCapabilityDeclaration[] DeclaredCapabilities { get; }
    IChatClient GetChatClient(string modelId);
    IEmbeddingGenerator GetEmbeddingGenerator(string modelId);
}
```

```csharp
// IModelRouter.cs
public interface IModelRouter
{
    Task<RoutedModel> RouteAsync(
        ChatRequestSummary request,
        IRoutingPolicy policy,
        CancellationToken cancellationToken = default);
}

public record RoutedModel(string ProviderId, string ModelId, ModelCapabilityDeclaration Capability);
public record ChatRequestSummary(int EstimatedInputTokens, int MaxOutputTokens, IReadOnlyList<string> RequiredCapabilities);
```

```csharp
// IRoutingPolicy.cs
public interface IRoutingPolicy
{
    string PolicyName { get; }
    RoutingDecision Choose(IReadOnlyList<ModelCandidate> candidates, ChatRequestSummary request);
}

public record ModelCandidate(string ProviderId, string ModelId, ModelCapabilityDeclaration Capability, decimal CostPerKToken);
public record RoutingDecision(ModelCandidate Selected, string Reason);
```

```csharp
// ModelCapabilityDeclaration.cs (record — drops I prefix per Grid-wide naming rule)
public record ModelCapabilityDeclaration(
    string ProviderId,
    string ModelId,
    int MaxContextTokens,
    bool SupportsStreaming,
    bool SupportsVision,
    bool SupportsFunctionCalling,
    string[] SupportedRegions,
    decimal? InputCostPerKToken,
    decimal? OutputCostPerKToken);
```

```csharp
// ICostLedger.cs
public interface ICostLedger
{
    Task RecordAsync(InferenceCost cost, CancellationToken cancellationToken = default);
    Task<CostSummary> GetSummaryAsync(string scope, DateTimeOffset since, CancellationToken cancellationToken = default);
}

public record InferenceCost(string ProviderId, string ModelId, int InputTokens, int OutputTokens, decimal EstimatedCost, string OperationCorrelationId);
public record CostSummary(string Scope, DateTimeOffset Since, DateTimeOffset Until, decimal TotalCost, int TotalCalls);
```

`HoneyDrunk.AI.Abstractions` references **only** `Microsoft.Extensions.*` abstractions per invariant 1 — specifically `Microsoft.Extensions.Logging.Abstractions` for any logger contracts and `Microsoft.Extensions.Options.Abstractions` if needed. **Do not** reference any other `HoneyDrunk.*` package from Abstractions, including `HoneyDrunk.Kernel.Abstractions` — keep the AI Abstractions surface dependency-free so downstream consumers don't transit a Kernel version pin through us.

**First-pass shape; subject to refinement before v0.2.0 baseline lock.** The exact member sets of `ICostLedger` (specifically the `RecordAsync`/`GetSummaryAsync` parameter shape and the `InferenceCost`/`CostSummary` records) and `IModelProvider.GetEmbeddingGenerator` are first-pass. The contract-shape canary established in this packet makes any post-v0.1.0 change a deliberate version-bump event, so the executing agent should land workable shapes here without overdesigning — refinement before downstream consumers lock against v0.2.0 is expected.

**Strict Abstractions stance — deliberate, not a defect.** The `Abstractions`-has-zero-`HoneyDrunk.*`-references rule is the user's explicit scoping resolution between repo-local invariant 1 (`repos/HoneyDrunk.AI/invariants.md:5`, strict) and ADR-0016 D2 line 42 (originally permissive of Kernel.Abstractions). Packet 01 amends D2 line 42 to match the strict stance. Concretely: `InferenceCost.OperationCorrelationId` stays `string`, `ICostLedger.GetSummaryAsync(string scope, ...)` stays `string`, and any GridContext / CorrelationId propagation lives in the `HoneyDrunk.AI` runtime package (e.g. inside `InferenceTelemetry`), not in Abstractions. Abstractions does not import `HoneyDrunk.Kernel.Abstractions` to type those fields.

### Runtime details — `HoneyDrunk.AI`

`HoneyDrunk.AI` references:
- `HoneyDrunk.AI.Abstractions` (project reference)
- `HoneyDrunk.Kernel` (for `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext`)
- `HoneyDrunk.Vault` (for `IConfigProvider` to read App Config — D5)
- `Microsoft.Extensions.DependencyInjection.Abstractions`
- `Microsoft.Extensions.Hosting.Abstractions`

Three default implementations:

- **`DefaultModelRouter`** — accepts a registered set of `IModelProvider` instances via DI, builds the candidate list from `provider.DeclaredCapabilities`, hands off to the configured `IRoutingPolicy`. No baked-in policy choice — at startup, `PolicyLoader` reads `policy:active` from App Config via `IConfigProvider` and resolves the matching `IRoutingPolicy` from DI.
- **`DefaultCostLedger`** — in-process accumulator keyed by `(ProviderId, ModelId, scope)`. Reads token prices from App Config via `IConfigProvider` at startup; refreshes on `IConfigProvider` change events. Persistence (e.g., to Data) is a follow-up — for first ship, in-memory is enough for Operator's cost-control story to start using.
- **`InferenceTelemetry`** — wraps `IChatClient`/`IEmbeddingGenerator` calls in `ITelemetryActivityFactory`-created activities, emits per-call attributes (token in, token out, model id, provider id, latency, estimated cost). This is the "AI emits, Pulse observes" surface from D7. GridContext / CorrelationId propagation onto inference-call activities also lives here in the runtime package — not in `HoneyDrunk.AI.Abstractions`, which stays HoneyDrunk-dependency-free.

**Host registration of `IConfigProvider`.** `DefaultModelRouter`, `DefaultCostLedger`, and `PolicyLoader` all depend on `IConfigProvider` being registered with an Azure App Configuration source. The deployable host (not this package) is responsible for `services.AddVault().AddAppConfigurationProvider(...)` per ADR-0005's host-composition rule. `HoneyDrunk.AI` references `HoneyDrunk.Vault` for the `IConfigProvider` contract, but it does **not** reference `HoneyDrunk.Vault.Providers.AppConfiguration` directly — that wiring is host concern. AddHoneyDrunkAI() throws a clear `InvalidOperationException` at first resolution if `IConfigProvider` is missing from the container, so a misconfigured host fails fast with a useful message.

**Vault is not split into a separate Abstractions package today.** `IConfigProvider` ships from the `HoneyDrunk.Vault` runtime package (no `HoneyDrunk.Vault.Abstractions` exists yet). Referencing `HoneyDrunk.Vault` from the `HoneyDrunk.AI` runtime is therefore consistent with the existing Grid dependency pattern. If Vault later splits its abstractions out, `HoneyDrunk.AI` follows by switching the reference — that is a future-version concern, not in scope for this packet.

Service registration:

```csharp
// ServiceCollectionExtensions.cs
public static IServiceCollection AddHoneyDrunkAI(this IServiceCollection services, Action<AIOptions>? configure = null)
{
    services.AddSingleton<IModelRouter, DefaultModelRouter>();
    services.AddSingleton<ICostLedger, DefaultCostLedger>();
    // Routing policies registered by consumer or via AddRoutingPolicy<T>() helper.
    // Providers registered by consumer or via AddModelProvider<T>() helper.
    return services;
}
```

### InMemory provider details — `HoneyDrunk.AI.Providers.InMemory`

The InMemory provider exists for two distinct downstream consumers:

- **Evals** — needs a deterministic provider whose outputs are fixture-driven, so eval runs are reproducible without spending API budget.
- **CI / canary tests across the Grid** — needs a provider that compiles and runs without network access or secrets.

Implementation:

```csharp
public sealed class InMemoryModelProvider : IModelProvider
{
    public string ProviderId => "inmemory";
    public ModelCapabilityDeclaration[] DeclaredCapabilities => InMemoryCapabilities.All;

    public IChatClient GetChatClient(string modelId) => new InMemoryChatClient(modelId, _scriptedResponses);
    public IEmbeddingGenerator GetEmbeddingGenerator(string modelId) => new InMemoryEmbeddingGenerator(modelId);
    // ...
}
```

`InMemoryChatClient` accepts a scripted `IReadOnlyDictionary<string, ChatCompletion>` keyed by request fingerprint. Default behavior with no script: returns a fixed echo completion `"[InMemory:{modelId}] {firstUserMessageContent}"`. `InMemoryEmbeddingGenerator` returns a deterministic float vector derived from `string.GetHashCode()` over the input — enough for similarity-search correctness tests without semantic meaning.

The provider declares two synthetic models in `InMemoryCapabilities`:
- `inmemory:fast` — 8K context, no streaming, no vision, no functions, $0.00 per Ktoken
- `inmemory:large` — 32K context, streaming, no vision, no functions, $0.00 per Ktoken

### CI workflows

All five workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows. No bespoke CI logic in the AI repo.

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
# .github/workflows/api-compatibility.yml — ADR-0016 D8 / invariant 41
name: API Compatibility (Abstractions)
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/HoneyDrunk.AI.Abstractions/**'
jobs:
  abstractions-shape:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main
    with:
      project-path: src/HoneyDrunk.AI.Abstractions/HoneyDrunk.AI.Abstractions.csproj
```

The path filter ensures the canary only runs when Abstractions changes — keeps PR feedback fast for runtime/provider-only changes. The whole-assembly diff produced by `job-api-compatibility.yml` is sufficient to enforce D8: per D9 invariant 39, Abstractions is the only thing downstream Nodes compile against, so any shape drift in any public type in Abstractions counts.

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

Tags are human-pushed per invariant 27 — agents do not push tags. The release workflow packs and publishes all six `src/*` projects in a single tag-driven run.

`nightly-deps.yml` and `nightly-security.yml` follow the same thin-caller pattern — copy the configurations from `HoneyDrunk.Vault` or `HoneyDrunk.Auth` for reference. The exact `with:` and `secrets:` blocks should match those repos verbatim so nightly runs converge across Grid Nodes.

### `HoneyDrunk.Standards` wiring

Each `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets="all"` per invariant 26:

```xml
<ItemGroup>
  <PackageReference Include="HoneyDrunk.Standards" Version="*" PrivateAssets="all" />
</ItemGroup>
```

This pulls in the StyleCop ruleset, `.editorconfig`, and analyzer suite that every Grid repo uses.

### Documentation

- **Repo `README.md`** — purpose statement, package matrix, "How to consume from a downstream Node" snippet showing `AddHoneyDrunkAI()` + `AddModelProvider<InMemoryModelProvider>()`, link to ADR-0016.
- **Repo `CHANGELOG.md`** — `## [0.1.0] - 2026-MM-DD` entry covering the entire scaffold landing.
- **Per-package `README.md`** — purpose, public API surface summary, install command. Required by invariant 12 for new packages.
- **Per-package `CHANGELOG.md`** — `## [0.1.0]` entry for each package introduced in this packet.

## Affected Files
Entire repo is created from this packet. Notable new files:
- `HoneyDrunk.AI.slnx`, `Directory.Build.props`, `README.md`, `CHANGELOG.md`, `.editorconfig`, `.gitignore`
- `src/HoneyDrunk.AI.Abstractions/` — 7 contract files + supporting record/type files + `.csproj` + `README.md` + `CHANGELOG.md`
- `src/HoneyDrunk.AI/` — `.csproj`, `ServiceCollectionExtensions.cs`, `DefaultModelRouter.cs`, `DefaultCostLedger.cs`, `InferenceTelemetry.cs`, `PolicyLoader.cs`, `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.AI.Providers.OpenAI/` — `.csproj`, stub provider class, `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.AI.Providers.Anthropic/` — same
- `src/HoneyDrunk.AI.Providers.AzureOpenAI/` — same
- `src/HoneyDrunk.AI.Providers.InMemory/` — `.csproj`, `InMemoryModelProvider.cs`, `InMemoryChatClient.cs`, `InMemoryEmbeddingGenerator.cs`, `InMemoryCapabilities.cs`, `README.md`, `CHANGELOG.md`
- `tests/*` — three test projects with at least smoke-test coverage
- `.github/workflows/` — 5 workflow files

## NuGet Dependencies

Every new `.csproj` lists `HoneyDrunk.Standards` (`PrivateAssets="all"`) per invariant 26.

### `HoneyDrunk.AI.Abstractions.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

(No other PackageReference. Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages, only `Microsoft.Extensions.*` abstractions are permitted, and even those only when needed. Nothing here needs them.)

### `HoneyDrunk.AI.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel` | For `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext` |
| `HoneyDrunk.Vault` | For `IConfigProvider` (D5 — App Config sourcing) |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | DI registration helpers |
| `Microsoft.Extensions.Hosting.Abstractions` | For startup hook integration |
| `Microsoft.Extensions.Logging.Abstractions` | Logger contracts |
| `Microsoft.Extensions.Options.ConfigurationExtensions` | Bind options from `IConfigProvider` |

Project reference: `HoneyDrunk.AI.Abstractions`.

### `HoneyDrunk.AI.Providers.OpenAI.csproj`, `.Anthropic.csproj`, `.AzureOpenAI.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

Project reference: `HoneyDrunk.AI.Abstractions` (per invariant 3 — providers depend on the parent Node's contracts package, not the runtime).

(SDK packages like `OpenAI`, `Anthropic.SDK`, `Azure.AI.OpenAI` are deferred to follow-up packets that actually implement each provider. Stub classes throw `NotImplementedException("ADR-0016 follow-up — not yet implemented")`.)

### `HoneyDrunk.AI.Providers.InMemory.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

Project reference: `HoneyDrunk.AI.Abstractions`.

### Test projects
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.NET.Test.Sdk` | Standard |
| `xunit` | Standard |
| `xunit.runner.visualstudio` | Standard |
| `Microsoft.Extensions.DependencyInjection` | For DI in router/cost ledger tests |

Project references as appropriate to each `.Tests` project.

## Boundary Check
- [x] All work inside `HoneyDrunk.AI`. No edits to other Grid repos.
- [x] `HoneyDrunk.AI.Abstractions` carries zero `HoneyDrunk.*` references — invariant 1.
- [x] Provider packages reference `HoneyDrunk.AI.Abstractions` only — invariant 3.
- [x] No model name or provider hardcoded anywhere in `HoneyDrunk.AI` — invariant 28. Routing reads from App Config; cost rates read from App Config.
- [x] No secrets in code. All API keys (when provider implementations land later) flow through `ISecretStore` per invariant 9 — for this packet, the stub providers don't even take credentials.
- [x] Abstractions' shape compatibility with `Microsoft.Extensions.AI` is structural, not type-identity (D6).
- [x] Records (e.g. `ModelCapabilityDeclaration`, `RoutedModel`, `ModelCandidate`, `RoutingDecision`, `InferenceCost`, `CostSummary`, `Embedding`, `ChatMessage`, `ChatCompletion`) all drop the `I` prefix; interfaces keep it (Grid-wide naming rule).

## Acceptance Criteria
- [ ] `HoneyDrunk.AI.slnx` builds clean from a fresh clone via `dotnet build` with no warnings (warnings-as-errors).
- [ ] All seven D3 contracts present in `HoneyDrunk.AI.Abstractions` with XML documentation per invariant 13.
- [ ] `HoneyDrunk.AI.Abstractions` has zero `HoneyDrunk.*` PackageReference or ProjectReference entries (invariant 1 enforced).
- [ ] `HoneyDrunk.AI` runtime exposes `AddHoneyDrunkAI()` extension; default `IModelRouter` and `ICostLedger` resolve from DI after registration.
- [ ] `HoneyDrunk.AI.Providers.InMemory` is fully functional — scripted and default-echo modes both work, deterministic embedding output verified by a unit test.
- [ ] OpenAI / Anthropic / AzureOpenAI provider stubs compile and throw `NotImplementedException` with a message naming ADR-0016 follow-up.
- [ ] All five `.github/workflows/*.yml` files present and reference `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/*@main`.
- [ ] `api-compatibility.yml` runs on PR. On the scaffolding PR itself the workflow runs against an absent `main` baseline and reports `status: skipped` per the `HoneyDrunk.Actions/.github/actions/api/check-compatibility/action.yml` missing-baseline path (it emits a `::warning::` and exits 0 when `git worktree add` against the baseline ref fails) — that is correct first-build behavior, not a failure. The scaffolding PR merge establishes the `main` baseline. **Verify post-merge** by opening a throwaway PR that removes a public member from `IChatClient` (or any other frozen contract); the workflow must fail with breaking-changes-detected. Revert the throwaway PR after observation.
- [ ] `pr-core.yml` passes on the initial scaffolding PR (build + tests + analyzers + dependency scan + secret scan).
- [ ] Repo-level `CHANGELOG.md` has a `## [0.1.0]` entry covering the scaffold; per-package `CHANGELOG.md` files each have their own `## [0.1.0]` entry naming the package's specific introductions (per invariants 12 and 27).
- [ ] Repo-level `README.md` and per-package `README.md` files all present per invariant 12.
- [ ] Test suite runs and passes — minimum coverage: `DefaultModelRouter` happy-path test with two providers + a cost-first policy, `DefaultCostLedger` accumulation test, `InMemoryChatClient` scripted-response test + default-echo test, `InMemoryEmbeddingGenerator` determinism test.
- [ ] All projects in the solution carry the same `Version` (0.1.0), excluding test projects (invariant 27).
- [ ] Manual confirmation that pushing tag `v0.1.0` triggers `release.yml` and produces NuGet packages for the six `src/*` projects (do not actually push the tag — verify the workflow exists and a tag-push trigger is configured).

## Human Prerequisites
- [ ] Confirm OIDC federated credential exists for the `HoneyDrunk.AI` repo's release workflow against the Grid's NuGet publishing identity. Cross-link: [`infrastructure/oidc-federated-credentials.md`](../../../../infrastructure/oidc-federated-credentials.md). The Grid has a standard NuGet publishing identity used by every Node — confirm `repo:HoneyDrunkStudios/HoneyDrunk.AI:ref:refs/tags/v*` is in its federated credential list.
- [ ] After this packet's PR merges, push tag `v0.1.0` from `main` to trigger the first NuGet publish. Tags are human-pushed per invariant 27.
- [ ] Repo settings: branch protection on `main` requires `pr-core / core` and `api-compatibility / abstractions-shape` checks, no force-pushes, signed commits not required (matches other Grid repos).
- [ ] No Azure resource provisioning required for this packet — HoneyDrunk.AI is a library Node, not a deployable. (When a future packet stands up the cost-rate App Config keys, that packet will carry the App Config provisioning Human Prereq, not this one.)

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. — `HoneyDrunk.AI.Providers.InMemory` references `HoneyDrunk.AI.Abstractions`, not `HoneyDrunk.AI` runtime.

> **Invariant 3:** Provider packages depend on their parent Node's contracts, not internal implementation details. When a Node splits contracts into a separate package (as `HoneyDrunk.AI.Abstractions` does), providers reference that package.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — `HoneyDrunk.AI` references `Kernel`; nothing in `HoneyDrunk.AI.*` is referenced back from Kernel.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. — Provider implementations (when they land in follow-up packets) must resolve API keys via `ISecretStore`.

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning. — This packet is the establishment of HoneyDrunk.AI's solution and CI pipeline.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. Repo-level `CHANGELOG.md` is mandatory; per-package `CHANGELOG.md` and `README.md` required for each package.

> **Invariant 13:** All public APIs have XML documentation. Enforced by HoneyDrunk.Standards analyzers. — All seven D3 contracts and their supporting types must carry `///` summaries.

> **Invariant 14:** Canary tests validate cross-Node boundaries. Each Node that depends on another has a `.Canary` project verifying integration assumptions. — Future-facing: downstream Nodes will add `.Canary` projects against `HoneyDrunk.AI.Abstractions`. This packet does not author those — they belong with each downstream Node's stand-up.

> **Invariant 15:** Tests never depend on external services. Use InMemory providers for isolation. — The `InMemory` provider in this packet exists specifically to satisfy this for downstream Nodes' tests.

> **Invariant 16:** No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. `HoneyDrunk.Standards` must be explicitly listed on every new .NET project (StyleCop + EditorConfig analyzers, `PrivateAssets: all`). — This packet's NuGet Dependencies section enumerates all six new `src/*` projects' references.

> **Invariant 27:** All projects in a solution share one version and move together. When a version bump is warranted, every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit. — Initial scaffold ships at `0.1.0` across all six packages.

> **Invariant 28:** Application code must never hardcode a model name or provider. All model selection goes through `IModelRouter` in HoneyDrunk.AI. Routing policies are stored in App Configuration (ADR-0005) and are operator-configurable without a redeploy. — `DefaultModelRouter` and `DefaultCostLedger` both read from App Config via `IConfigProvider`. No `if (modelId == "gpt-4") ...` branches anywhere.

> **Invariant 39 (this initiative, packet 02):** Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`. Composition against `HoneyDrunk.AI` and any `HoneyDrunk.AI.Providers.*` package is a host-time concern resolved at application startup from App Configuration. — Reinforced in this scaffold by giving `Abstractions` zero HoneyDrunk dependencies so consumers don't transit unintended pins.

> **Invariant 40 (this initiative, packet 02):** Token cost rates, routing policies, and capability declarations are sourced from Azure App Configuration via Vault's `IConfigProvider`. Hardcoded rates, policies, or capability declarations in application code are forbidden. — `DefaultCostLedger` reads token prices from `IConfigProvider`; `PolicyLoader` reads `policy:active` and policy-specific config keys.

> **Invariant 41 (this initiative, packet 02):** The HoneyDrunk.AI Node CI must include a contract-shape canary that fails the build on shape drift to `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, or `IModelRouter` without a corresponding version bump. — `api-compatibility.yml` calls `HoneyDrunk.Actions/job-api-compatibility.yml` scoped to `HoneyDrunk.AI.Abstractions`. The whole-assembly diff covers all four hot-path contracts plus `IRoutingPolicy`, `ModelCapabilityDeclaration`, `ICostLedger`.

## Referenced ADR Decisions

**ADR-0016 D1 (Inference substrate):** HoneyDrunk.AI is the AI sector's shared substrate, not an orchestrator. This scaffold ships only the substrate — no agent execution, no workflow logic, no prompt management.

**ADR-0016 D2 (Package families):** Six package families — Abstractions + runtime + four provider slots (OpenAI, Anthropic, AzureOpenAI, InMemory). All six land in this packet. Provider implementations beyond InMemory are stubs awaiting follow-up packets.

**ADR-0016 D3 (Exposed contracts):** Seven contracts. Records drop `I`; interfaces keep it. **D3 is the canonical surface** — `IInferenceResult` (mentioned in the ADR's "If Accepted" checklist) is **not** part of D3 and is **not** in this scaffold. `ICostLedger` is.

**ADR-0016 D5 (App Configuration sourcing):** `DefaultCostLedger` and `PolicyLoader` both read from `IConfigProvider`. No rate or policy literal in code.

**ADR-0016 D6 (Microsoft.Extensions.AI shape compatibility):** Method signatures and parameter shapes mirror MEAI where practical, but the types live in `HoneyDrunk.AI.Abstractions`. The `HoneyDrunk.AI.Interop.MEAI` adapter package is **deferred to Q3 2026** and is not part of this packet.

**ADR-0016 D7 (Telemetry direction):** `InferenceTelemetry` emits via `ITelemetryActivityFactory` (Kernel). No Pulse package reference. Pulse consumes downstream — out of scope for this packet.

**ADR-0016 D8 (Contract-shape canary):** `api-compatibility.yml` is the canary. Scoped to `HoneyDrunk.AI.Abstractions` since per D9 that is the only public-boundary package.

**ADR-0016 D9 (Downstream coupling):** `Abstractions` is dependency-clean so downstream Nodes can take it without pulling Kernel or Vault transitively.

**ADR-0010 (already accepted):** Source of `IModelProvider`, `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`. Their concrete shapes are decided in this packet — ADR-0010 said "these contracts exist," ADR-0016 D3 said "they live in `HoneyDrunk.AI.Abstractions` with these member sets," and this packet authors them.

**ADR-0005 (already accepted, deployable Nodes):** HoneyDrunk.AI is a **library Node**, not a deployable. Per ADR-0005, library Nodes have no Key Vault. App Config is shared across the Grid — `HoneyDrunk.AI` reads from it via `IConfigProvider` when composed into a deployable. This packet does not provision App Config — it consumes whatever the deployable host's App Config contains.

## Dependencies
- `packet:01` — catalog registration must land first so the Architecture catalogs match what this packet ships. Filing order matters for the `addBlockedBy` graph on The Hive.
- `packet:02` — invariants 39, 40, 41 must exist in `constitution/invariants.md` before this packet's acceptance criteria reference them by number.

## Labels
`feature`, `tier-2`, `ai`, `scaffold`, `adr-0016`

## Agent Handoff

**Objective:** Take the empty `HoneyDrunk.AI` repo and ship version 0.1.0 with the seven D3 contracts, default runtime, four provider-slot packages (InMemory functional, three stubs), full CI, and the contract-shape canary scoped to Abstractions.

**Target:** HoneyDrunk.AI, branch from `main`. (If `main` does not yet exist because the repo is fully empty, push directly to `main` for the initial commit.)

**Context:**
- Goal: Unblock six AI-sector Nodes (Capabilities, Operator, Agents, Memory, Knowledge, Evals) currently waiting for `HoneyDrunk.AI.Abstractions` to exist.
- Feature: ADR-0016 standup initiative — this is the substrate scaffold, the third and largest packet of the initiative.
- ADRs: ADR-0016 (sole governing ADR for the standup); ADR-0010 (already-accepted source of routing contracts); ADR-0005 (App Config split that D5 builds on).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01 and 02 of this initiative must merge first.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `HoneyDrunk.AI.Abstractions.csproj` must contain no `HoneyDrunk.*` PackageReference or ProjectReference. The `HoneyDrunk.Standards` reference uses `PrivateAssets="all"` so it does not propagate.
- **Invariant 3:** Provider packages depend on their parent Node's contracts package. — All four provider `.csproj` files reference `HoneyDrunk.AI.Abstractions` (project reference), nothing else from the AI Node.
- **Invariant 9:** Vault is the only source of secrets. All access goes through `ISecretStore`. — When future packets implement OpenAI/Anthropic/AzureOpenAI providers, they will resolve credentials via `ISecretStore`. This packet's stubs do not take credentials and do not need to reference `HoneyDrunk.Vault`.
- **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — Every one of the six `src/*` projects must ship a `README.md` and `CHANGELOG.md` in the same commit it is added.
- **Invariant 13:** All public APIs have XML documentation. — Every public type/member in `HoneyDrunk.AI.Abstractions` carries `///` summaries. StyleCop rules from `HoneyDrunk.Standards` enforce this.
- **Invariant 26:** Packets for .NET code work must include `## NuGet Dependencies`. `HoneyDrunk.Standards` must be on every new .NET project. — Confirmed in the NuGet Dependencies section above.
- **Invariant 27:** All projects in a solution share one version. — Every `src/*.csproj` ships at `0.1.0`. Test projects do not bump.
- **Invariant 28:** No hardcoded model name or provider. — `DefaultModelRouter`, `DefaultCostLedger`, and `PolicyLoader` all read from App Config. The InMemory provider's two synthetic models are declared via `ModelCapabilityDeclaration` data, not branched on by string in any consumer.
- **Invariant 39:** Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`. — Reinforced by keeping Abstractions HoneyDrunk-dependency-free.
- **Invariant 40:** Token cost rates, routing policies, and capability declarations sourced from App Configuration via `IConfigProvider`. — `DefaultCostLedger` and `PolicyLoader` both read from `IConfigProvider`. No `decimal RatePerKToken = 0.03m` literals anywhere.
- **Invariant 41:** AI Node CI must include the contract-shape canary on the four hot-path contracts. — `api-compatibility.yml` covers this by scoping to `HoneyDrunk.AI.Abstractions`.
- **Canary on the scaffolding PR is expected to report `status: skipped`, not fail.** The shared `HoneyDrunk.Actions/.github/actions/api/check-compatibility/action.yml` emits `::warning::` and exits 0 with `status: skipped` when `git worktree add` against the baseline ref fails — which it always does on a first PR against an empty repo. Do not treat the skip as a misconfiguration and do not chase it. The scaffolding PR's merge establishes the `main` baseline; verification of the canary actually firing happens **post-merge** via a throwaway breaking-change PR that is reverted after observation.
- **Strict Abstractions stance is deliberate.** `HoneyDrunk.AI.Abstractions` ships with zero `HoneyDrunk.*` references. This is the user's explicit scoping resolution — see ADR-0016 D2 line 42 (amended by packet 01 to `Microsoft.Extensions.*` only) and `repos/HoneyDrunk.AI/invariants.md:5`. Any GridContext/CorrelationId propagation belongs in the `HoneyDrunk.AI` runtime package (specifically `InferenceTelemetry`), not in Abstractions. `InferenceCost.OperationCorrelationId` is a `string`; `ICostLedger.GetSummaryAsync(string scope, ...)` takes a `string`. Do not import `HoneyDrunk.Kernel.Abstractions` in any `HoneyDrunk.AI.Abstractions` source file.
- **D3 is canonical, not the "If Accepted" checklist.** Author exactly the seven D3 contracts. Do **not** author `IInferenceResult`. If you find a reference to `IInferenceResult` anywhere in scope (e.g. an old example in the AI sector architecture doc), that is drift to be cleaned up by packet 01 or as a follow-up — do not invent the type just because the ADR's checklist mentions it.
- **Records drop `I`; interfaces keep it.** `ModelCapabilityDeclaration` is a record (no `I`). The other six contracts are interfaces (with `I`). Supporting record types in the same files (`RoutedModel`, `ModelCandidate`, `RoutingDecision`, `InferenceCost`, `CostSummary`, `ChatMessage`, `ChatCompletion`, `Embedding`, `EmbeddingOptions`, `ChatOptions`) all drop the `I`.
- **Shape compatibility with `Microsoft.Extensions.AI` is structural, not type-identity.** Match the parameter shapes and member sets where they are stable. Do **not** reference any `Microsoft.Extensions.AI.*` package. The MEAI interop adapter is deferred to Q3 2026 per D6.

**Key Files:**
- `HoneyDrunk.AI.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.AI.Abstractions/IChatClient.cs`, `IEmbeddingGenerator.cs`, `IModelProvider.cs`, `IModelRouter.cs`, `IRoutingPolicy.cs`, `ModelCapabilityDeclaration.cs`, `ICostLedger.cs` and supporting record types in the same folder
- `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs`, `Routing/DefaultModelRouter.cs`, `Routing/PolicyLoader.cs`, `Cost/DefaultCostLedger.cs`, `Telemetry/InferenceTelemetry.cs`
- `src/HoneyDrunk.AI.Providers.InMemory/InMemoryModelProvider.cs`, `InMemoryChatClient.cs`, `InMemoryEmbeddingGenerator.cs`, `InMemoryCapabilities.cs`
- `src/HoneyDrunk.AI.Providers.{OpenAI,Anthropic,AzureOpenAI}/` — stub `.csproj` + stub `*ModelProvider.cs` throwing `NotImplementedException`
- `.github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml`
- `README.md`, `CHANGELOG.md` (repo-level), per-package `README.md` and `CHANGELOG.md`
- `tests/HoneyDrunk.AI.Tests/`, `tests/HoneyDrunk.AI.Providers.InMemory.Tests/`

**Contracts:**
- All seven D3 contracts authored fresh in this packet inside `HoneyDrunk.AI.Abstractions`.
- The contract-shape canary establishes its baseline against this packet's commit. Future shape changes to any public type in Abstractions trigger the canary.
