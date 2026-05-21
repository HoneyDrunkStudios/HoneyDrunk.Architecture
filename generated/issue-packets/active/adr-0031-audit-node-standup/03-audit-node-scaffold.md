---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Audit
labels: ["feature", "tier-2", "audit", "scaffold", "adr-0031"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0031", "ADR-0030", "ADR-0026", "ADR-0027", "ADR-0009", "ADR-0005"]
accepts: ADR-0031
wave: 2
initiative: adr-0031-audit-node-standup
node: honeydrunk-audit
---

# Feature: Stand up the HoneyDrunk.Audit repo — solution, two packages, audit contracts, Data-backed append-only store, CI, in-memory fixture, smoke test

## Summary
Bring the empty `HoneyDrunk.Audit` repo from zero to first-shippable state per ADR-0031 D11. Land the solution layout, the two package families (`HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data`), the D3 public surface inside `Abstractions` (`IAuditLog`, `IAuditQuery`, `AuditEntry`, plus the supporting category/outcome/target/change/query value types), the Data-backed append-only `IAuditLog` writer and `IAuditQuery` reader over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork` with the audit-class retention hook (App Config-sourced), the in-memory `IAuditLog`/`IAuditQuery` fixture (internal to the runtime package's test project — deliberately not a `Testing` package per ADR-0027 precedent), the end-to-end smoke test that writes through `IAuditLog` and reads back through `IAuditQuery` against the in-memory fixture, the standard CI pipeline (PR core + release + nightly deps + nightly security), and the contract-shape canary scoped to the full `HoneyDrunk.Audit.Abstractions` public surface per ADR-0031 D8 / invariant `{N-canary}`.

This is the unblocker for `HoneyDrunk.Auth` (packet 04 of this initiative), future data-change emitters, and any future Node recording security, activity, system, integration, or privileged-action events. After this packet merges and `v0.1.0` tags, Auth can take a `HoneyDrunk.Audit.Abstractions 0.1.0` PackageReference and wire the first emitter.

**Pre-filing invariant-number substitution required.** This packet's body uses `{N-coupling}` and `{N-canary}` placeholders for the two invariant numbers landed by packet 01 of this initiative (downstream coupling + contract-shape canary). After packet 01 merges and the actual assigned numbers are known, edit this file in place pre-push (invariant 24's pre-filing carve-out) to substitute the real numbers. Hardcoding 45/46 here is WRONG — those slots are occupied by ADR-0016 AI standup as of 2026-05-20.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Audit`

## Motivation
ADR-0031 D11 specifies the first-PR scaffold for HoneyDrunk.Audit. Packet 02 created the GitHub repo and cloned the local tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Audit/` (`.gitignore`, `LICENSE`, placeholder `README.md` only). Catalogs and Audit invariants (`{N-substrate}`, `{N-coupling}`, `{N-canary}`) are already in place. This packet ships the code and freezes a contract shape that supports both activity/security audit and data-change audit from v0.1.0.

Until this packet ships: Auth (packet 04) has no `HoneyDrunk.Audit.Abstractions 0.1.0` to reference; data-change emitters have no canonical target; the contract-shape canary has no baseline; the Phase-1 append-only-by-interface guarantee is unenforced; Operator's eventual reconciliation has nothing to consume. ADR-0031 D11 explicitly requires the D3 surface + round-trip proof in the first commit so the canary has a coherent baseline.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Audit/
├── HoneyDrunk.Audit.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── LICENSE                          (placed by packet 02; verify content matches Grid LICENSE)
├── .editorconfig                    (from HoneyDrunk.Standards)
├── .gitignore                       (from packet 02; extend as needed)
├── .github/
│   └── workflows/
│       ├── pr-core.yml              (calls Actions/pr-core.yml)
│       ├── release.yml              (calls Actions/release.yml)
│       ├── nightly-deps.yml         (calls Actions/nightly-deps.yml)
│       ├── nightly-security.yml     (calls Actions/nightly-security.yml)
│       └── api-compatibility.yml    (calls Actions/job-api-compatibility.yml — D8 / invariant {N-canary} canary)
├── src/
│   ├── HoneyDrunk.Audit.Abstractions/
│   │   ├── HoneyDrunk.Audit.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IAuditLog.cs             (append-only — no update method, no delete method)
│   │   ├── IAuditQuery.cs           (time-ordered + filtered forensic reads)
│   │   ├── AuditEntry.cs            (record envelope — drops the I prefix per Grid-wide naming rule)
│   │   ├── AuditEntryId.cs          (strong-typed id)
│   │   ├── AuditCategory.cs         (Security/UserActivity/DataChange/SystemAction/AgentAction/Integration)
│   │   ├── AuditOutcome.cs          (Succeeded/Denied/Failed/Pending)
│   │   ├── AuditTarget.cs           (resource/entity target identity)
│   │   └── AuditChange.cs           (data-change field diff with redaction flag)
│   └── HoneyDrunk.Audit.Data/
│       ├── HoneyDrunk.Audit.Data.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── ServiceCollectionExtensions.cs    (AddHoneyDrunkAuditData)
│       ├── DataAuditLog.cs                   (IAuditLog impl over IRepository/IUnitOfWork — append-only)
│       ├── DataAuditQuery.cs                 (IAuditQuery impl — time-ordered + filtered reads)
│       ├── AuditRetentionPolicy.cs           (audit-class retention sourced from IConfigProvider)
│       └── AuditTelemetry.cs                 (operational telemetry via ITelemetryActivityFactory)
└── tests/
    ├── HoneyDrunk.Audit.Abstractions.Tests/
    │   ├── HoneyDrunk.Audit.Abstractions.Tests.csproj
    │   ├── ContractSurfaceTests.cs            (compile-only + shape assertions on Abstractions public surface)
    │   └── AppendOnlyAtInterfaceTests.cs      (reflection check: IAuditLog has no update/delete method)
    └── HoneyDrunk.Audit.Data.Tests/
        ├── HoneyDrunk.Audit.Data.Tests.csproj
        ├── Fixtures/
        │   ├── InMemoryAuditLog.cs            (internal — the in-memory IAuditLog fixture; D2)
        │   └── InMemoryAuditQuery.cs          (internal — the in-memory IAuditQuery fixture; D2)
        ├── DataAuditLogTests.cs               (append behavior, retention hook, telemetry emission)
        ├── DataAuditQueryTests.cs             (time-ordered reads, filtered reads)
        └── SmokeTests.cs                      (end-to-end: write via IAuditLog → read via IAuditQuery against in-memory)
```

**Fixtures stay `internal`** to `HoneyDrunk.Audit.Data.Tests/Fixtures/` per ADR-0031 D2 + ADR-0027 D3 (no speculative Testing package; cut later as non-breaking when a third consumer needs it). Auth (packet 04) writes its own narrowly-scoped test double.

### Solution

`HoneyDrunk.Audit.slnx` references both `src/*` projects and both `tests/*` projects. Solution-level `Directory.Build.props` sets:

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
    <PackageProjectUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Audit</PackageProjectUrl>
    <RepositoryUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Audit</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
    <PublishRepositoryUrl>true</PublishRepositoryUrl>
    <IncludeSymbols>true</IncludeSymbols>
    <SymbolPackageFormat>snupkg</SymbolPackageFormat>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
  </PropertyGroup>
</Project>
```

Per invariant 27 (all projects in a solution share one version and move together), both `src/*.csproj` files carry the same `Version` (0.1.0 for this initial release). Test projects are excluded from version-bump scope.

### Contract details — `HoneyDrunk.Audit.Abstractions`

Records drop the `I` prefix per the Grid-wide naming rule; interfaces keep it.

**Single `HoneyDrunk.*` reference: `HoneyDrunk.Kernel.Abstractions`** (for `TenantId` strong type per ADR-0026). Permitted by ADR-0031 D2. This is a deliberate departure from ADR-0016 AI standup's zero-`HoneyDrunk` stance — Audit is queried for per-tenant compliance/forensic retrieval; stringly-typing tenancy at this surface re-introduces the consumer-side parse-and-default footgun ADR-0026 closed. Every downstream emitter already has Kernel.Abstractions in its closure, so no new transitively-pinned package.

**`CorrelationId` stays `string` at v0.1.0** — lower stakes (forensic queries filter by actor/action/tenant/time, not correlation), and keeps the canary baseline narrow. v0.2.0 follow-up packet promotes it to `Kernel.Abstractions.Identity.CorrelationId` as one intentional shape bump.

**`AuditEntry.Id` is the strong type `AuditEntryId` from v0.1.0** — assigned writer-side (single-site, internal — no propagation cost) and the primary-key shape in storage, so promoting later would be wider than `CorrelationId`. Define it as a `readonly record struct` matching the Kernel template (`TenantId`, `CorrelationId`):

```csharp
namespace HoneyDrunk.Audit.Abstractions;

public readonly record struct AuditEntryId(string Value)
{
    public static AuditEntryId New() => new(System.Guid.NewGuid().ToString("N"));
    public static AuditEntryId Empty { get; } = new(string.Empty);
    public bool IsEmpty => string.IsNullOrEmpty(Value);
    public override string ToString() => Value;
}
```

Consumers create entries with `Id: AuditEntryId.Empty`; the writer overwrites at append time.

```csharp
// IAuditLog.cs
namespace HoneyDrunk.Audit.Abstractions;

/// <summary>
/// Append-only write surface for the Grid's durable, attributable security and action record.
/// Exposes no update method and no delete method — append-only is enforced at the interface
/// surface, not only at the storage layer.
/// </summary>
public interface IAuditLog
{
    /// <summary>
    /// Append a single audit entry to the durable record. The entry is immutable once appended.
    /// </summary>
    Task AppendAsync(AuditEntry entry, CancellationToken cancellationToken = default);
}
```

```csharp
// IAuditQuery.cs
namespace HoneyDrunk.Audit.Abstractions;

using HoneyDrunk.Kernel.Abstractions.Identity;

/// <summary>
/// Time-ordered and filtered read surface for incident reconstruction and forensic retrieval
/// over the durable audit record. The contract the future tenant-facing forensics Service
/// will compile against without any contract migration.
/// </summary>
public interface IAuditQuery
{
    /// <summary>
    /// Read entries within the given time window, optionally filtered by actor, category,
    /// event name, target, correlation id, or tenant, in time order (earliest first).
    /// </summary>
    Task<IReadOnlyList<AuditEntry>> ReadAsync(
        AuditQueryFilter filter,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Forensic query filter. Null fields are ignored (no filter on that dimension).
/// </summary>
public sealed record AuditQueryFilter(
    DateTimeOffset Since,
    DateTimeOffset Until,
    string? Actor = null,
    AuditCategory? Category = null,
    string? EventName = null,
    string? TargetType = null,
    string? TargetId = null,
    string? CorrelationId = null,
    TenantId? TenantId = null,
    int? Limit = null);
```

```csharp
// AuditCategory.cs
namespace HoneyDrunk.Audit.Abstractions;

/// <summary>
/// Broad audit event family. Used for routing, retention review, and forensic filters.
/// </summary>
public enum AuditCategory
{
    Security = 0,
    UserActivity = 1,
    DataChange = 2,
    SystemAction = 3,
    AgentAction = 4,
    Integration = 5,
}
```

```csharp
// AuditOutcome.cs
namespace HoneyDrunk.Audit.Abstractions;

/// <summary>
/// Outcome of the audited event.
/// </summary>
public enum AuditOutcome
{
    Succeeded = 0,
    Denied = 1,
    Failed = 2,
    Pending = 3,
}
```

```csharp
// AuditTarget.cs
namespace HoneyDrunk.Audit.Abstractions;

/// <summary>
/// Resource, entity, workflow, integration, or system component targeted by an audit event.
/// </summary>
public sealed record AuditTarget(
    string Type,
    string Id,
    string? DisplayName = null);
```

```csharp
// AuditChange.cs
namespace HoneyDrunk.Audit.Abstractions;

/// <summary>
/// Optional per-field data-change detail. Values must be redacted before append when the
/// field contains secrets, credentials, tokens, regulated data, or sensitive PII.
/// </summary>
public sealed record AuditChange(
    string Field,
    string? Before = null,
    string? After = null,
    bool IsRedacted = false);
```

```csharp
// AuditEntry.cs (record — drops I prefix per Grid-wide naming rule)
namespace HoneyDrunk.Audit.Abstractions;

using HoneyDrunk.Kernel.Abstractions.Identity;

/// <summary>
/// Canonical append-only audit record envelope. Generalized Grid-wide from the original
/// Operator-scoped shape per ADR-0030 D5.
/// </summary>
/// <param name="Id">Unique identifier for the audit entry. Strong-typed <c>AuditEntryId</c> (ULID-shaped). Pass <see cref="AuditEntryId.Empty"/> at construction; the writer overwrites at append time.</param>
/// <param name="OccurredAt">Wall-clock time the audited action occurred.</param>
/// <param name="Category">Broad event family: security, user activity, data change, system action, agent action, or integration.</param>
/// <param name="EventName">Stable domain event name (e.g. <c>auth.login.attempt</c>, <c>entity.customer.updated</c>, <c>purchase.completed</c>).</param>
/// <param name="Actor">Identifier for who performed or attempted the action (user id, system id, agent id, etc.).</param>
/// <param name="Target">Resource/entity/workflow/integration target of the event.</param>
/// <param name="Outcome">Outcome of the audited event.</param>
/// <param name="CorrelationId">Correlation identifier tying this entry to a broader operation. Stays string at v0.1.0; promoted to <c>Kernel.Abstractions.Identity.CorrelationId</c> at v0.2.0 (follow-up packet).</param>
/// <param name="TenantId">Tenant scope of the entry. Uses the Kernel strong type per ADR-0026; use <c>TenantId.Internal</c> for non-tenant-scoped Grid events.</param>
/// <param name="Metadata">Structured string metadata for event-specific detail. Do not store secrets.</param>
/// <param name="Changes">Optional data-change detail for create/update/delete audit. Redact sensitive fields before append.</param>
public sealed record AuditEntry(
    AuditEntryId Id,
    DateTimeOffset OccurredAt,
    AuditCategory Category,
    string EventName,
    string Actor,
    AuditTarget Target,
    AuditOutcome Outcome,
    string CorrelationId,
    TenantId TenantId,
    IReadOnlyDictionary<string, string>? Metadata = null,
    IReadOnlyList<AuditChange>? Changes = null);
```

**`AuditQueryFilter` is first-pass; refinement expected before v0.2.0.** The names `IAuditLog`, `IAuditQuery`, `AuditEntry`, and their supporting category/outcome/target/change value types are stable; only additive filter refinements are expected before v0.2.0.

**`Id` and `OccurredAt` assignment.** Writer assigns `Id` (`DataAuditLog.AppendAsync` overwrites caller-passed). Caller assigns `OccurredAt`; Audit never overwrites it.

### Runtime details — `HoneyDrunk.Audit.Data`

`HoneyDrunk.Audit.Data` references:
- `HoneyDrunk.Audit.Abstractions` (project reference)
- `HoneyDrunk.Kernel.Abstractions` (for `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext` — these are interfaces, compile-time contract consumption; per invariant 2, depend on Abstractions not runtime)
- `HoneyDrunk.Kernel` (for the lifecycle / health registration extensions and any runtime concrete types — only if needed; prefer dropping this row if `Kernel.Abstractions` is sufficient and the host wires concrete Kernel lifecycle separately)
- `HoneyDrunk.Data.Abstractions` (for `IRepository`, `IUnitOfWork`)
- `HoneyDrunk.Vault` (for `IConfigProvider` to read App Config — audit-class retention value per D4. **Note:** `IConfigProvider` lives in the `HoneyDrunk.Vault.Abstractions` *namespace* but is shipped as part of the `HoneyDrunk.Vault` *package* — Vault does not ship a separate `.Abstractions` NuGet, so the package reference is unavoidably `HoneyDrunk.Vault`. If Vault later splits to a separate `.Abstractions` package, switch to it.)
- `Microsoft.Extensions.DependencyInjection.Abstractions`
- `Microsoft.Extensions.Hosting.Abstractions`
- `Microsoft.Extensions.Logging.Abstractions`
- `Microsoft.Extensions.Options.ConfigurationExtensions` (bind options from `IConfigProvider`)

**`DataAuditLog`** — implements `IAuditLog.AppendAsync(AuditEntry, CancellationToken)`:
- Accepts both activity/security/system events and data-change events through the same `AuditEntry` envelope; validates that `AuditCategory.DataChange` entries include a target and at least one `AuditChange` when the action is update/delete.
- Assigns the entry's `Id` (ULID) at write time, overwriting any caller-passed value.
- Enriches the entry with the caller's `IGridContext.CorrelationId` and `TenantId` if the entry's fields are empty (defensive — callers should pass them, but Audit is the durable-record-of-last-resort; an unattributable audit entry is worse than a redundantly-attributed one).
- Persists via `IRepository<AuditEntry>.AddAsync` + `IUnitOfWork.SaveChangesAsync`. No update path. No delete path. The contract has none; the implementation must have none either.
- Emits operational telemetry via `ITelemetryActivityFactory` (`audit.log.append`, latency, byte size). Telemetry direction is **one-way to Pulse** per D7 — `HoneyDrunk.Audit.Data` does not reference any `HoneyDrunk.Pulse` package.

**`DataAuditQuery`** — implements `IAuditQuery.ReadAsync(AuditQueryFilter, CancellationToken)`:
- Composes the filter as a single `Expression<Func<AuditEntry, bool>>` and calls `IReadOnlyRepository<AuditEntry>.FindAsync(predicate, ct)`. Per the actual `HoneyDrunk.Data.Abstractions/Repositories/IReadOnlyRepository.cs` surface (`FindByIdAsync`, `FindAsync`, `FindOneAsync`, `ExistsAsync`, `CountAsync`), there is **no `Query()` method** at v0.1.0.
- **Ordering and `Limit` happen post-fetch, in memory** (`FindAsync` returns `IReadOnlyList<TEntity>` without order-by/take semantics). Phase-1 inefficiency for very large result sets — acceptable because forensic queries are low-volume and time-window-bounded. Phase-2 revisits when `IReadOnlyRepository<T>` ships order-by/take or `DataAuditQuery` drops to direct `DbContext`. The class file carries a `// Phase-1: FindAsync + in-memory order/take` comment near the read site.
- `Limit`: default 1000, cap 10000 (class constants — query-shape, not App-Config).
- Emits `audit.query.read` telemetry.

**`AuditRetentionPolicy`** — sources `audit:retention:days` from `IConfigProvider.GetValueAsync` **once at startup**. Default if unset: **365 days** with a `::warning::` log. Exposes `public int RetentionDays { get; }`. `IConfigProvider` exposes no change-token at v0.1.0 (surface is `GetValueAsync`/`TryGetValueAsync`/`GetValueAsync<T>`); config changes require host restart. Hot-reload is out of scope. Retention enforcement (background job or query-time filter) is Phase-2; Phase-1 ships only the value and read path. Audit-class retention is distinct from observability per ADR-0030 D4 / ADR-0031 D4 — 365d is intentionally order-of-magnitude longer than observability defaults.

**`AuditTelemetry`** — Convenience helpers wrapping `ITelemetryActivityFactory`. GridContext/CorrelationId propagation onto telemetry activities lives here, not in `Abstractions`.

**Host registration.** `IConfigProvider`, `IRepository`, `IUnitOfWork` are host-wired. `AddHoneyDrunkAuditData()` throws `InvalidOperationException` at first resolution if any is missing.

Service registration:

```csharp
// ServiceCollectionExtensions.cs
namespace HoneyDrunk.Audit.Data;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddHoneyDrunkAuditData(this IServiceCollection services)
    {
        services.AddSingleton<AuditRetentionPolicy>();
        services.AddSingleton<IAuditLog, DataAuditLog>();      // Singleton — see lifetime story below
        services.AddSingleton<IAuditQuery, DataAuditQuery>();  // Singleton — same reason
        services.AddSingleton<AuditTelemetry>();
        return services;
    }
}
```

### Lifetime story — `DataAuditLog` and `DataAuditQuery` are Singleton

Both registered Singleton. Reasoning:

1. **Auth's emitters are Singleton.** Scoped `IAuditLog` injected into Auth's Singleton emitters = captive-dep on first scope.
2. **`DataAuditLog.AppendAsync` holds no scoped state.** Resolves `IGridContext` via `IGridContextAccessor.GridContext` (ambient, not ctor-injected). Resolves Scoped `IRepository<AuditEntry>` + `IUnitOfWork` fresh per call via `IServiceScopeFactory.CreateAsyncScope()`.
3. **Append is single-row** — per-call scope is the right UoW.

Shape:

```csharp
public sealed class DataAuditLog : IAuditLog
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IGridContextAccessor _gridContextAccessor;
    private readonly AuditTelemetry _telemetry;

    public async Task AppendAsync(AuditEntry entry, CancellationToken cancellationToken = default)
    {
        // Stamp Id, enrich CorrelationId/TenantId from _gridContextAccessor.GridContext if empty
        using var scope = _scopeFactory.CreateAsyncScope();
        var repo = scope.ServiceProvider.GetRequiredService<IRepository<AuditEntry>>();
        var uow = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
        await repo.AddAsync(stamped, cancellationToken);
        await uow.SaveChangesAsync(cancellationToken);
    }
}
```

`DataAuditQuery` follows the same per-call-scope pattern. `AuditRetentionPolicy` resolves `IConfigProvider` via `IServiceScopeFactory` at startup (read-once, Singleton-safe regardless of Vault provider's `IConfigProvider` lifetime).

### In-memory fixture — `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/`

Two `internal sealed` classes; not packaged at v0.1.0 (per D2 + ADR-0027 D3). Cut into `HoneyDrunk.Audit.Testing` as non-breaking change when a third consumer needs it.

- `InMemoryAuditLog : IAuditLog` — `List<AuditEntry>` + `lock(_gate)`; `AppendAsync` stamps `Id` (via `entry with { Id = entry.Id.IsEmpty ? AuditEntryId.New() : entry.Id }`) and appends; exposes `internal IReadOnlyList<AuditEntry> Snapshot()` for assertions.
- `InMemoryAuditQuery : IAuditQuery` — takes `InMemoryAuditLog` in ctor; `ReadAsync` filters snapshot by `Since`/`Until`/optional `Actor`/`Category`/`EventName`/`TargetType`/`TargetId`/`CorrelationId`/`TenantId`, `OrderBy(e => e.OccurredAt)`, applies `Limit` via `Take`.

### Smoke test — `tests/HoneyDrunk.Audit.Data.Tests/SmokeTests.cs`

`WriteThroughIAuditLog_ReadBackThroughIAuditQuery_RoundTrips`: instantiate `InMemoryAuditLog` + `InMemoryAuditQuery` over it; append one `AuditEntry` with `Id: AuditEntryId.Empty`, `Category: AuditCategory.Security`, `EventName: "auth.login.attempt"`, `Actor: "user:42"`, `Target: new AuditTarget("auth-session", "session:123")`, `Outcome: AuditOutcome.Succeeded`, `TenantId: TenantId.Internal`; query a one-minute window around `OccurredAt`; assert single result with the expected Actor/EventName/Outcome and `Id.IsEmpty == false` (writer-stamped). Add a second smoke/fixture test for `AuditCategory.DataChange` with target `customer:42`, one public changed field, and one redacted sensitive changed field. Satisfies ADR-0031 D11.

### Append-only-at-interface enforcement test

`tests/HoneyDrunk.Audit.Abstractions.Tests/AppendOnlyAtInterfaceTests.cs` uses reflection — asserts `typeof(IAuditLog).GetMethods()` contains exactly `AppendAsync` and none of `UpdateAsync`/`ReplaceAsync`/`DeleteAsync`/`RemoveAsync`. Build-time defense against accidental future update/delete addition.

### CI workflows

All five workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows.

- **`pr-core.yml`** — calls `pr-core.yml@main`, `dotnet-version: '10.0.x'`.
- **`api-compatibility.yml`** (D8 / `{N-canary}`):

```yaml
name: API Compatibility (Abstractions)
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/HoneyDrunk.Audit.Abstractions/**'
      - 'Directory.Build.props'
jobs:
  abstractions-shape:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main
    with:
      project-path: src/HoneyDrunk.Audit.Abstractions/HoneyDrunk.Audit.Abstractions.csproj
```

Path filter includes `Directory.Build.props` so version-bumped contract-shape changes don't merge without the canary running. Whole-assembly diff covers `IAuditLog`/`IAuditQuery`/`AuditEntry`/`AuditQueryFilter`/`AuditEntryId`.

- **`release.yml`** — `on: push: tags: [v*.*.*]`, calls `release.yml@main` with `enable-nuget-publish: true` and:

```yaml
    secrets:
      nuget-api-key: ${{ secrets.NUGET_API_KEY }}
```

**No `secrets: inherit`** — the caller passes only the named secret `release.yml` declares. ACR auth is OIDC. Tags are human-pushed per invariant 27. Packet 02 must seed `NUGET_API_KEY`.

- **`nightly-deps.yml` / `nightly-security.yml`** — thin callers; copy `with:`/`secrets:` blocks verbatim from `HoneyDrunk.Vault` or `HoneyDrunk.Auth`.

### `HoneyDrunk.Standards` wiring

Each `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets="all"` per invariant 26:

```xml
<ItemGroup>
  <PackageReference Include="HoneyDrunk.Standards" Version="*" PrivateAssets="all" />
</ItemGroup>
```

This pulls in the StyleCop ruleset, `.editorconfig`, and analyzer suite that every Grid repo uses.

### Documentation

- **Repo `README.md`** — purpose statement, package matrix, link to active-work tracker, plus a `## For downstream consumers — minimal wiring` section showing copy-pasteable `services.AddVault().AddData(...).AddHoneyDrunkAuditData()`. Also a **`## Phase-1 honest limitation`** section naming two intentional gaps:
  1. The interface is append-only; storage is **NOT** cryptographically tamper-evident. Hash-chain/WORM is deferred behind the boundary.
  2. Append-only is enforced at `IAuditLog`'s surface only. `DataAuditLog` consumes `IRepository<AuditEntry>` which exposes `Update`/`Remove`/`UpdateRange`/`RemoveRange` (inherited from `HoneyDrunk.Data.Abstractions/Repositories/IRepository.cs`). `DataAuditLog`'s source calls none of them, and `AppendOnlyAtInterfaceTests` enforces the interface shape. An `IAppendOnlyRepository<T>` carve-out is a Phase-2 hardening item. v0.1.0 boundary = (a) `IAuditLog` shape, (b) reviewed source, (c) Audit's dedicated managed identity (ADR-0031 D5).

  Per memory `feedback_no_adr_in_docs`, the README does not cite ADR numbers in narrative.
- **Repo `CHANGELOG.md`** — `## [0.1.0] - YYYY-MM-DD` entry. No `## Unreleased` at commit time.
- **Per-package `README.md`** + **`CHANGELOG.md`** — required by invariant 12 for both new packages.

## Affected Files
Entire repo is created from this packet. Notable new files:
- `HoneyDrunk.Audit.slnx`, `Directory.Build.props`, `README.md`, `CHANGELOG.md`, `.editorconfig`
- `src/HoneyDrunk.Audit.Abstractions/` — `.csproj`, `IAuditLog.cs`, `IAuditQuery.cs`, `AuditEntry.cs`, `AuditEntryId.cs` (record-struct, strong-typed id per Kernel template), `AuditCategory.cs`, `AuditOutcome.cs`, `AuditTarget.cs`, `AuditChange.cs`, `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.Audit.Data/` — `.csproj`, `ServiceCollectionExtensions.cs`, `DataAuditLog.cs`, `DataAuditQuery.cs`, `AuditRetentionPolicy.cs`, `AuditTelemetry.cs`, `README.md`, `CHANGELOG.md`
- `tests/HoneyDrunk.Audit.Abstractions.Tests/` — `.csproj`, `ContractSurfaceTests.cs`, `AppendOnlyAtInterfaceTests.cs`
- `tests/HoneyDrunk.Audit.Data.Tests/` — `.csproj`, `Fixtures/InMemoryAuditLog.cs`, `Fixtures/InMemoryAuditQuery.cs`, `DataAuditLogTests.cs`, `DataAuditQueryTests.cs`, `SmokeTests.cs`
- `.github/workflows/` — 5 workflow files (`pr-core.yml`, `release.yml`, `nightly-deps.yml`, `nightly-security.yml`, `api-compatibility.yml`)

## NuGet Dependencies

Every new `.csproj` lists `HoneyDrunk.Standards` (`PrivateAssets="all"`) per invariant 26.

### `HoneyDrunk.Audit.Abstractions.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `TenantId` strong type (ADR-0026). Deliberate departure from zero-`HoneyDrunk` stance per ADR-0031 D2. |

### `HoneyDrunk.Audit.Data.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext`, `TenantId` |
| `HoneyDrunk.Kernel` | Optional — drop if `Kernel.Abstractions` suffices. Mirror a peer `Data` package (Communications/Notify). |
| `HoneyDrunk.Data.Abstractions` | For `IRepository`, `IUnitOfWork` |
| `HoneyDrunk.Vault` | For `IConfigProvider` (interface namespace is `Vault.Abstractions`; Vault ships one package only). |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | DI helpers |
| `Microsoft.Extensions.Hosting.Abstractions` | Startup hook |
| `Microsoft.Extensions.Logging.Abstractions` | Logger contracts |
| `Microsoft.Extensions.Options.ConfigurationExtensions` | Bind options |

Project reference: `HoneyDrunk.Audit.Abstractions`.

### Test projects

`HoneyDrunk.Standards` (`PrivateAssets="all"`), `Microsoft.NET.Test.Sdk`, `xunit`, `xunit.runner.visualstudio`, `Microsoft.Extensions.DependencyInjection`. Project refs: `Abstractions.Tests` → `Abstractions`; `Data.Tests` → both.

## Boundary Check

- [x] All work inside `HoneyDrunk.Audit`. No other Grid repos edited.
- [x] `HoneyDrunk.Audit.Abstractions` carries exactly ONE `HoneyDrunk.*` ref: `HoneyDrunk.Kernel.Abstractions` (for `TenantId`). No Data/Vault/Pulse/Kernel-runtime refs.
- [x] `HoneyDrunk.Audit.Data` references `Abstractions` (project), `Kernel.Abstractions`, `Data.Abstractions`, `Vault`. No `HoneyDrunk.Pulse` (telemetry is one-way per D7).
- [x] No secrets in code; retention value is non-secret config read via `IConfigProvider`.
- [x] `IAuditLog` exposes exactly `AppendAsync` — no update/replace/delete. Enforces `{N-substrate}` at interface surface.
- [x] Records/enums drop `I` (`AuditEntry`, `AuditQueryFilter`, `AuditTarget`, `AuditChange`, `AuditCategory`, `AuditOutcome`); interfaces keep it (`IAuditLog`, `IAuditQuery`).
- [x] Fixtures `internal` to test project; not packaged.
- [x] Scaffold does NOT include: hash-chain/WORM tamper-evidence (Phase-2), tenant-facing forensics Service (deferred), Auth emitter wiring (packet 04), Operator reconciliation (separate).
- [x] Store is **not** documented as tamper-evident anywhere. README's `## Phase-1 honest limitation` section is explicit.

## Acceptance Criteria

- [ ] `HoneyDrunk.Audit.slnx` builds clean from a fresh clone via `dotnet build` with no warnings (warnings-as-errors).
- [ ] D3 public surface present in `HoneyDrunk.Audit.Abstractions` with XML documentation per invariant 13: `IAuditLog`, `IAuditQuery`, `AuditEntry`, `AuditEntryId`, `AuditQueryFilter`, `AuditCategory`, `AuditOutcome`, `AuditTarget`, and `AuditChange`. Records/enums drop the `I` prefix; interfaces keep it. The strong-typed identifier `AuditEntryId` is also a record-struct without `I` (Grid-wide naming rule).
- [ ] `HoneyDrunk.Audit.Abstractions` has exactly ONE `HoneyDrunk.*` PackageReference: `HoneyDrunk.Kernel.Abstractions` (for `TenantId`). Per ADR-0031 D2's "zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions" allowance. No `HoneyDrunk.Kernel` runtime ref; no `HoneyDrunk.Data*` / `HoneyDrunk.Vault*` / `HoneyDrunk.Pulse*` refs. Constitutional invariants `{N-coupling}` and 1 (downstream Abstractions-only coupling; Abstractions stay near-minimal) are satisfied — the single Kernel-Abstractions reference is an intentional, ADR-permitted exception.
- [ ] `IAuditLog` exposes exactly one method, `AppendAsync(AuditEntry, CancellationToken)`. No `UpdateAsync`, no `ReplaceAsync`, no `DeleteAsync`, no `RemoveAsync`. The reflection test `AppendOnlyAtInterfaceTests.cs` asserts this and passes.
- [ ] `HoneyDrunk.Audit.Data` exposes `AddHoneyDrunkAuditData()` extension; `IAuditLog` and `IAuditQuery` resolve from DI after registration.
- [ ] `DataAuditLog.AppendAsync` persists via `IRepository<AuditEntry>.AddAsync` + `IUnitOfWork.SaveChangesAsync`. **No source-code call to `Update`/`Remove`/`UpdateRange`/`RemoveRange`** on `IRepository<AuditEntry>` — even though those methods exist on the inherited `IRepository<T>` interface (per `HoneyDrunk.Data.Abstractions/Repositories/IRepository.cs`), `DataAuditLog`'s source does not invoke any of them. Code review enforces this at v0.1.0; the README's Phase-1 honest limitation section explicitly names the storage-layer gap (`IAppendOnlyRepository<T>` carve-out is a Phase-2 hardening item).
- [ ] `DataAuditLog.AppendAsync` assigns the entry's `Id` at write time as a fresh `AuditEntryId` (ULID-shaped strong type) and overwrites any caller-passed value (caller passes `AuditEntryId.Empty`); sets `CorrelationId`/`TenantId` defensively from `IGridContextAccessor.GridContext` if the entry's fields are empty.
- [ ] `DataAuditLog` and `DataAuditQuery` resolve `IGridContext` via `IGridContextAccessor.GridContext` (ambient per-call), **not** via direct `IGridContext` ctor injection. The classes are Singleton; `IGridContext` is Scoped — direct injection would be a captive-dep.
- [ ] `DataAuditLog` and `DataAuditQuery` resolve `IRepository<AuditEntry>` / `IReadOnlyRepository<AuditEntry>` / `IUnitOfWork` via `IServiceScopeFactory.CreateAsyncScope()` per call (the classes are Singleton; Data abstractions are typically Scoped — same captive-dep avoidance pattern).
- [ ] `IAuditLog`, `IAuditQuery`, `AuditRetentionPolicy`, `AuditTelemetry`, `DataAuditLog`, `DataAuditQuery` are all registered as `Singleton` in `AddHoneyDrunkAuditData()`. Lifetime story is documented in the repo README and matches the Singleton-emitters-in-Auth lifetime (per packet 04).
- [ ] `DataAuditQuery.ReadAsync` is implemented over `IReadOnlyRepository<AuditEntry>.FindAsync(predicate, ct)` (the actual public read method on the Data abstraction at v0.1.0; there is no `Query()` method). Time ordering and `Limit` are applied post-fetch, in memory. Filters cover `Since`/`Until`, `Actor`, `Category`, `EventName`, `TargetType`, `TargetId`, `CorrelationId`, and `TenantId`. The class file carries a `// Phase-1: FindAsync + in-memory order/take. Phase-2: switch to a public order-by/take primitive when Data ships one.` comment near the read site.
- [ ] **`AuditEntryId` strong type lives at `src/HoneyDrunk.Audit.Abstractions/AuditEntryId.cs`** as a `readonly record struct` matching the Kernel template (`TenantId`, `CorrelationId`). Exposes `AuditEntryId.New()`, `AuditEntryId.Empty`, `IsEmpty` property, and `ToString()` returning the wrapped string. `AuditEntry.Id` is typed as `AuditEntryId`, not `string`.
- [ ] `DataAuditLog` and `DataAuditQuery` emit operational telemetry via `ITelemetryActivityFactory` (activities `audit.log.append`, `audit.query.read`). No `HoneyDrunk.Pulse.*` reference anywhere in `HoneyDrunk.Audit.Data.csproj`.
- [ ] Data-change audit is first-class: `AuditCategory.DataChange`, `AuditTarget`, and `AuditChange` exist; at least one unit test appends an entity update with a redacted sensitive field and reads it back through `IAuditQuery`.
- [ ] README documents that before/after field values must be redacted before append; Audit stores the supplied record and must not become a secret/PII leak path.
- [ ] `AuditRetentionPolicy.RetentionDays` is sourced from `IConfigProvider.GetValueAsync` (key `audit:retention:days`) **once at startup**; defaults to 365d with a `::warning::` log if unset. No hardcoded retention literal in code. **No subscription to change-events** — `IConfigProvider` does not expose a change-token / observable surface at v0.1.0 (see `HoneyDrunk.Vault.Abstractions/IConfigProvider.cs`). Configuration changes require a host restart; hot-reload is an out-of-scope follow-up.
- [ ] The scaffold's `README.md` includes a "Phase-1 honest limitation" section that explicitly states the store is **append-only-by-interface and NOT tamper-evident**, hash-chain/WORM is deferred behind the boundary. No language describing the store as tamper-evident appears anywhere in the repo.
- [ ] In-memory fixtures `InMemoryAuditLog` and `InMemoryAuditQuery` exist under `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/` with `internal` visibility. **No `src/HoneyDrunk.Audit.Testing/` project exists** — the fixture is not packaged at v0.1.0.
- [ ] `SmokeTests.WriteThroughIAuditLog_ReadBackThroughIAuditQuery_RoundTrips` passes, proving the contracts round-trip through the in-memory fixture (per D11).
- [ ] All five `.github/workflows/*.yml` files present and reference `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/*@main`.
- [ ] `api-compatibility.yml` runs on PR. On the scaffolding PR itself the workflow runs against an absent `main` baseline and reports `status: skipped` per the `HoneyDrunk.Actions/.github/actions/api/check-compatibility/action.yml` missing-baseline path (it emits a `::warning::` and exits 0 when `git worktree add` against the baseline ref fails) — that is correct first-build behavior, not a failure. The scaffolding PR merge establishes the `main` baseline. **Verify post-merge** by opening a throwaway PR that removes the `AppendAsync` method from `IAuditLog` (or any member of `IAuditQuery` / `AuditEntry`); the workflow must fail with breaking-changes-detected. Revert the throwaway PR after observation.
- [ ] `pr-core.yml` passes on the initial scaffolding PR (build + tests + analyzers + dependency scan + secret scan).
- [ ] Repo-level `CHANGELOG.md` has a `## [0.1.0] - YYYY-MM-DD` entry covering the scaffold (per invariants 12, 27, and memory `feedback_no_unreleased_commits` — no `## Unreleased` block at commit time).
- [ ] Per-package `CHANGELOG.md` files each have their own `## [0.1.0]` entry naming the package's specific introductions (per invariants 12 and 27).
- [ ] Repo-level `README.md` and per-package `README.md` files all present per invariant 12.
- [ ] Test suite runs and passes — minimum coverage: `AppendOnlyAtInterfaceTests` (reflection assertion on `IAuditLog`), `DataAuditLogTests` (append + Id assignment + retention hook + telemetry emission), `DataAuditQueryTests` (time-ordered reads + each filter dimension + Limit honored), `SmokeTests` (round-trip via in-memory fixture).
- [ ] Both projects in the solution carry the same `Version` (0.1.0), excluding test projects (invariant 27).
- [ ] Manual confirmation that pushing tag `v0.1.0` triggers `release.yml` and produces NuGet packages for both `src/*` projects (do not actually push the tag — verify the workflow exists and a tag-push trigger is configured).
- [ ] **No `.github/dependabot.yml` file exists.** Per ADR-0009, dependency-scanning lives in the nightly workflows; no Dependabot config file is committed.
- [ ] **`AuditEntry.TenantId` is the Kernel `TenantId` strong type** (from `HoneyDrunk.Kernel.Abstractions.Identity`), per ADR-0026. `AuditQueryFilter.TenantId` is `TenantId?` (nullable for "no filter on tenant"). **`CorrelationId` stays `string` at v0.1.0** (with a v0.2.0 promotion to the Kernel strong type flagged in a follow-up packet). The trade is explicit: per-tenant compliance/forensic queries justify the contract dependency on `Kernel.Abstractions`; correlation id is lower-stakes for filtering and stays string until the v0.2.0 bump can carry the promotion as one intentional contract-shape change.
- [ ] **Repo `README.md` includes a `## For downstream consumers — minimal wiring` section** showing the host-side `services.AddVault().AddData(...).AddHoneyDrunkAuditData()` snippet, copy-pasteable. This is load-bearing for packet 04 (Auth emitter wiring) and future Operator reconciliation.
- [ ] **The README does NOT cite "ADR-0031" by number in narrative paragraphs.** Per memory `feedback_no_adr_in_docs`. (Runtime metadata references — catalog entries elsewhere — are fine; the README is user-facing narrative.)

## Human Prerequisites

- [ ] Packet 02 of this initiative complete — `HoneyDrunkStudios/HoneyDrunk.Audit` repo exists on GitHub with org-default branch protection, labels seeded, OIDC federated credential wired, and the local working tree cloned at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Audit/`.
- [ ] Packet 01 of this initiative merged — the two new Audit invariants exist in `constitution/invariants.md` so this packet's acceptance criteria reference them by number. **This packet's source file uses `{N-coupling}`, `{N-canary}`, and `{N-substrate}` placeholders** for the three Audit-related invariant numbers; substitute the real numbers in place pre-push under invariant 24's pre-filing carve-out, **after** packet 01 merges and the assigned numbers are known. Hardcoding 45/46 is wrong — those slots are occupied by ADR-0016 AI standup at scoping time.
- [ ] After this packet's PR merges, push tag `v0.1.0` from `main` to trigger the first NuGet publish. Tags are human-pushed per invariant 27.
- [ ] **`NUGET_API_KEY` repository (or org-level) secret is available to the `HoneyDrunk.Audit` repo before `v0.1.0` is tagged.** The reusable `release.yml` in `HoneyDrunk.Actions` declares `nuget-api-key` as a named secret (no `secrets: inherit` pattern). If packet 02's repo-creation chore did not seed this secret, the first `release.yml` run will surface the missing-key failure clearly. Org-level `NUGET_API_KEY` (shared with other HoneyDrunk repos publishing to nuget.org) is the standard approach — verify it's bound to this repo before tagging. (Container-registry publish via OIDC does not need a secret.)
- [ ] **Branch protection sequencing.** Branch protection on `main` was set by packet 02 requiring only `pr-core / core` for the initial scaffolding PR (the `api-compatibility / abstractions-shape` check reports `status: skipped` on the first PR — see acceptance criteria). After the throwaway breaking-change PR confirms the canary fires post-merge, add `api-compatibility / abstractions-shape` to required checks in a follow-up branch-protection update.
- [ ] **No Azure resource provisioning required for this packet.** HoneyDrunk.Audit is a library Node at Phase 1, not a deployable. The Audit Node's own dedicated managed identity (per ADR-0031 D5) belongs with whichever packet first deploys an Audit-composing host. Same for the App Configuration key `audit:retention:days` — seeding it for real in App Config is the responsibility of the first consuming deployable, not this scaffold. The scaffold ships the *read* path and a 365d startup default with a `::warning::` if the key is unset. Cross-link: [`infrastructure/walkthroughs/azure-provisioning-guide.md`](../../../../infrastructure/walkthroughs/azure-provisioning-guide.md) for when that work lands.
- [ ] After this packet's PR merges and `v0.1.0` ships, file a small follow-up to add `HoneyDrunk.Audit` to the grid-health aggregator's watched-repos list in `HoneyDrunk.Actions` — only if the aggregator does not auto-discover from `catalogs/nodes.json`. Verify which behavior is in place at the time this prereq is being checked. (If auto-discovery is wired, ADR-0030 packet 01's `grid-health.json` edit is sufficient and this prereq is satisfied automatically.)
- [ ] After this packet's PR merges, file a SonarCloud onboarding follow-up packet for `HoneyDrunk.Audit` modeled on `generated/issue-packets/active/adr-0011-code-review-pipeline/06-kernel-sonarcloud-onboarding.md` (or whichever ADR-0011 onboarding packet is the closest match in shape).

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `Abstractions.csproj` carries ONE `HoneyDrunk.*` ref (`Kernel.Abstractions` for `TenantId`) — intentional, ADR-0031 D2-permitted exception. `HoneyDrunk.Standards` uses `PrivateAssets="all"`.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. — `Audit.Data` references `Audit.Abstractions` (project), `Kernel.Abstractions`, `Data.Abstractions`, `Vault`.

> **Invariant 3:** Provider packages depend on their parent Node's contracts, not internal implementation details. — N/A at Phase 1 (no Audit providers).

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Audit → Data → Kernel and Audit → Kernel are DAG-consistent.

> **Invariant 5:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null `TenantId`. — `DataAuditLog.AppendAsync` enriches `CorrelationId`/`TenantId` from `IGridContextAccessor.GridContext` defensively when caller-passed fields are empty.

> **Invariant 6:** CorrelationId is never null or empty, and TenantId is never absent, in a live GridContext. — Audit enriches empty entry fields rather than persisting unattributable entries.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. — Retention value is non-secret config via `IConfigProvider` (ADR-0005), not `ISecretStore`.

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning. — This packet establishes Audit's solution + CI.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — Both packages ship README + CHANGELOG; repo-level files also.

> **Invariant 13:** All public APIs have XML documentation. Enforced by HoneyDrunk.Standards analyzers. — All contracts + `AuditQueryFilter` + `AuditEntryId` carry `///` summaries.

> **Invariant 14:** Canary tests validate cross-Node boundaries. — Audit consumes Kernel/Data via pre-stable contracts; downstream `.Canary` projects (Auth at packet 04, Operator later) carry the boundary-verification load. Audit's own round-trip smoke test is the equivalent shape here.

> **Invariant 15:** Tests never depend on external services. Use InMemory providers for isolation. — In-memory `IAuditLog`/`IAuditQuery` fixture satisfies this.

> **Invariant 16:** No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only. — Fixtures live under `tests/...Tests/Fixtures/`.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. `HoneyDrunk.Standards` must be on every new .NET project. — Confirmed above.

> **Invariant 27:** All projects in a solution share one version and move together. When a version bump is warranted, every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit. — Both `src/*` ship at `0.1.0`.

> **Invariant `{N-substrate}` (ADR-0030 packet 02):** Durable, attributable security and action events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. Phase-1 audit integrity is append-only-by-interface (`IAuditLog` exposes no update and no delete method); it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. — This scaffold IS the substrate. `AppendOnlyAtInterfaceTests` enforces the interface shape; README's `## Phase-1 honest limitation` names the not-tamper-evident reality.

> **Invariant `{N-coupling}` (this initiative, packet 01):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`. Composition against `HoneyDrunk.Audit.Data` is a host-time concern resolved at application startup from App Configuration. — `Abstractions` kept near-minimal (one Kernel.Abstractions ref).

> **Invariant `{N-canary}` (this initiative, packet 01):** The HoneyDrunk.Audit Node CI must include a contract-shape canary for the `HoneyDrunk.Audit.Abstractions` public surface. Shape drift on `IAuditLog`, `IAuditQuery`, `AuditEntry`, or the supporting query/category/outcome/target/change value types is a build failure unless paired with an intentional version bump. — `api-compatibility.yml` covers this (whole-assembly diff over `Abstractions`).

## Referenced ADR Decisions

- **ADR-0031 D1** — Audit is the Core sector's single Node for durable security, action, and data-change records. Substrate only; no allow/deny logic, no aggregation.
- **ADR-0031 D2** — Two packages (`Abstractions` + `Data`); runtime named for backing; fixtures `internal` per ADR-0027 D3.
- **ADR-0031 D3** — Primary surfaces: `IAuditLog`, `IAuditQuery`, `AuditEntry`; supporting value types: `AuditEntryId`, `AuditQueryFilter`, `AuditCategory`, `AuditOutcome`, `AuditTarget`, `AuditChange`.
- **ADR-0031 D4** — Data-backed via `IRepository`/`IUnitOfWork`; append-only at interface (no update/delete method). Audit-class retention distinct from observability; sourced via App Config / `IConfigProvider`. Phase-1 is append-only-by-interface, NOT tamper-evident (D9).
- **ADR-0031 D5** — Audit runs under its own managed identity. Both packages are libraries here; identity provisioning belongs with the first deploying packet.
- **ADR-0031 D6** — Auth is first emitter (packet 04); Operator reconciliation lands with Operator scaffolding (separate initiative).
- **ADR-0031 D7** — Telemetry one-way to Pulse via `ITelemetryActivityFactory`. **Audit records are not telemetry and never flow to Pulse.** No Pulse package ref.
- **ADR-0031 D8** — `api-compatibility.yml` canary scoped to `Abstractions`.
- **ADR-0031 D9** — Downstream Nodes compile only against `Abstractions`.
- **ADR-0031 D10** — Audit takes runtime deps on Kernel + Data. Catalog edges landed by ADR-0030 packet 01.
- **ADR-0031 D11** — This packet implements the full first-PR checklist (managed identity deferred per library-Node rationale).
- **ADR-0030 D4** — Audit-class retention distinct from observability. `AuditRetentionPolicy` ships value + read path; enforcement loop is Phase-2.
- **ADR-0030 D5** — `IAuditLog`/`AuditEntry` authored here (conceptual relocation; Operator was never scaffolded).
- **ADR-0030 D9** — Phase-1 honest limitation: append-only-by-interface, NOT tamper-evident. README's `## Phase-1 honest limitation` is explicit.
- **ADR-0026** — `IGridContext.TenantId` is the non-nullable Kernel `TenantId` strong type with `Internal` sentinel. Audit's per-tenant forensic query path requires strong-typing at the contract surface to avoid re-introducing consumer-side parse-and-default footgun. `CorrelationId` stays string at v0.1.0; v0.2.0 follow-up promotes it.
- **ADR-0027** — No speculative Testing package; fixture `internal` until third consumer needs it.
- **ADR-0009** — No `.github/dependabot.yml`; nightly workflows handle deps.
- **ADR-0005** — Retention sourced through `IConfigProvider` from Vault, not direct App Config SDK.

## Dependencies

- `packet:01` — the two new Audit invariants (downstream coupling + contract-shape canary) must exist in `constitution/invariants.md` before this packet's acceptance criteria reference them by number. Substitute the assigned `{N-coupling}` and `{N-canary}` numbers in this packet's source file in place pre-push under invariant 24's pre-filing carve-out, **after** packet 01 merges.
- `packet:02` — the `HoneyDrunk.Audit` GitHub repo must exist with branch protection, labels, OIDC, and the local working tree cloned. The scaffolding agent has nowhere to author into without packet 02 done.

## Labels

`feature`, `tier-2`, `audit`, `scaffold`, `adr-0031`

## Agent Handoff

**Objective:** Take the empty `HoneyDrunk.Audit` repo and ship version 0.1.0 with the D3 public surface, Data-backed append-only `IAuditLog` writer + `IAuditQuery` reader, audit-class retention policy hook (App Config-sourced), first-class activity/security and data-change event shapes, in-memory fixture (internal to the test project), end-to-end smoke tests proving round-trip, full CI, and the contract-shape canary scoped to `Abstractions`.

**Target:** HoneyDrunk.Audit, branch from `main`. (Packet 02 ensures `main` exists with `.gitignore`/`LICENSE` already in place.)

**Context:**
- Goal: Unblock HoneyDrunk.Auth (packet 04 of this initiative — first emitter), future data-change emitters, and any future Node that needs to record durable, attributable security, activity, system, integration, or privileged-action events. Establish the contract-shape canary baseline that protects the surface from drift.
- Feature: ADR-0031 standup initiative — this is the substrate scaffold, the third packet of the initiative (after the two new Audit invariants `{N-coupling}` / `{N-canary}` in packet 01 and the repo creation in packet 02).
- ADRs: ADR-0031 (sole governing standup ADR); ADR-0030 (the driving capability/decision ADR — Phase-1 honest limitation, contract relocation, retention regime, Operator reconciliation framing all come from there); ADR-0005 (App Config-via-Vault pattern that D4 builds on); ADR-0009 (no Dependabot config file).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01 and 02 of this initiative must merge / be Done first.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are normally permitted. — `HoneyDrunk.Audit.Abstractions.csproj` carries exactly one intentional ADR-permitted `HoneyDrunk.*` reference: `HoneyDrunk.Kernel.Abstractions` for `TenantId`. The `HoneyDrunk.Standards` reference uses `PrivateAssets="all"` so it does not propagate.
- **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Audit → Data → Kernel and Audit → Kernel are DAG-consistent. The rejected Kernel-hosted alternative (per ADR-0030) would have created a Kernel → Data → Kernel cycle; this Node placement specifically avoids that.
- **Invariant 5/6:** GridContext + CorrelationId + TenantId must be present in every scoped operation. — `DataAuditLog.AppendAsync` enriches the entry from `IGridContext` defensively when caller-passed fields are empty.
- **Invariant 9:** Vault is the only source of secrets. — The retention value is non-secret configuration, sourced via `IConfigProvider` from App Configuration per ADR-0005. No `ISecretStore` calls are needed in this scaffold.
- **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — Both `src/*` projects ship `README.md` and `CHANGELOG.md` in the same commit.
- **Invariant 13:** All public APIs have XML documentation. — Every public type/member in `HoneyDrunk.Audit.Abstractions` carries `///` summaries. StyleCop rules from `HoneyDrunk.Standards` enforce this.
- **Invariant 26:** Packets for .NET code work must include `## NuGet Dependencies`. `HoneyDrunk.Standards` must be on every new .NET project. — Confirmed in the NuGet Dependencies section above.
- **Invariant 27:** All projects in a solution share one version. — Both `src/*.csproj` ship at `0.1.0`. Test projects do not bump.
- **Invariant `{N-substrate}` (substrate-level audit-emission boundary, ADR-0030 packet 02):** Durable, attributable security, action, and data-change events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. Phase-1 audit integrity is append-only-by-interface (`IAuditLog` exposes no update and no delete method); it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. Data-change details that include sensitive fields must be redacted before append. — `IAuditLog` exposes exactly `AppendAsync`. The reflection test `AppendOnlyAtInterfaceTests` makes accidental future addition of an update/delete method a build failure. The README's "Phase-1 honest limitation" section names the not-tamper-evident reality.
- **Invariant `{N-coupling}`:** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`. Composition against `HoneyDrunk.Audit.Data` is a host-time concern. — Reinforced by keeping `Abstractions` near-minimal (one `HoneyDrunk.Kernel.Abstractions` reference for `TenantId`).
- **Invariant `{N-canary}`:** The HoneyDrunk.Audit Node CI must include a contract-shape canary for the `HoneyDrunk.Audit.Abstractions` public surface. Shape drift on `IAuditLog`, `IAuditQuery`, `AuditEntry`, or the supporting query/category/outcome/target/change value types is a build failure unless paired with an intentional version bump. — `api-compatibility.yml` covers this by scoping to `HoneyDrunk.Audit.Abstractions`.
- **Canary on the scaffolding PR reports `status: skipped`, not fail.** First PR against near-empty repo: `git worktree add` against the baseline ref fails → `::warning::` + exit 0. Not a misconfiguration. Scaffold merge establishes baseline; verify post-merge via a throwaway breaking-change PR (revert after).
- **Abstractions stance — exactly ONE `HoneyDrunk.*` ref**, `HoneyDrunk.Kernel.Abstractions` (for `TenantId` per ADR-0026). No `Kernel`-runtime, no `Data*`, no `Vault*`, no `Pulse*`. `CorrelationId` stays `string` until v0.2.0.
- **Records drop `I`; interfaces keep it.**
- **No `.github/dependabot.yml`** (ADR-0009). Org-default Dependabot security alerts stay enabled.
- **Phase-1 store is NOT tamper-evident.** Do not soften the README's `## Phase-1 honest limitation`. No "tamper-evident" language in code/csproj/README/CHANGELOG.
- **`IAuditLog` has exactly `AppendAsync`** — no Update/Replace/Delete/Remove/AppendBatch. Reflection test enforces.
- **`AuditEntry.Id` writer-assigned; `OccurredAt` caller-assigned and never overwritten.**
- **No `HoneyDrunk.Pulse.*` ref anywhere.**
- **In-memory fixtures stay `internal`** — no `src/HoneyDrunk.Audit.Testing/` at v0.1.0.

**Key Files:**
- `HoneyDrunk.Audit.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Audit.Abstractions/IAuditLog.cs`, `IAuditQuery.cs`, `AuditEntry.cs`, `AuditEntryId.cs`, `AuditQueryFilter.cs`, `AuditCategory.cs`, `AuditOutcome.cs`, `AuditTarget.cs`, `AuditChange.cs`
- `src/HoneyDrunk.Audit.Data/ServiceCollectionExtensions.cs`, `DataAuditLog.cs`, `DataAuditQuery.cs`, `AuditRetentionPolicy.cs`, `AuditTelemetry.cs`
- `tests/HoneyDrunk.Audit.Abstractions.Tests/ContractSurfaceTests.cs`, `AppendOnlyAtInterfaceTests.cs`
- `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/InMemoryAuditLog.cs`, `Fixtures/InMemoryAuditQuery.cs`, `DataAuditLogTests.cs`, `DataAuditQueryTests.cs`, `SmokeTests.cs`
- `.github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml`
- `README.md`, `CHANGELOG.md` (repo-level), per-package `README.md` and `CHANGELOG.md`

**Contracts:**
- D3 public surface (`IAuditLog`, `IAuditQuery`, `AuditEntry`) plus supporting value types (`AuditEntryId`, `AuditQueryFilter`, `AuditCategory`, `AuditOutcome`, `AuditTarget`, `AuditChange`) authored fresh in this packet inside `HoneyDrunk.Audit.Abstractions`.
- The contract-shape canary establishes its baseline against this packet's commit. Future shape changes to any public type in `Abstractions` trigger the canary.
