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

# Feature: Stand up the HoneyDrunk.Audit repo — solution, two packages, three contracts, Data-backed append-only store, CI, in-memory fixture, smoke test

## Summary
Bring the empty `HoneyDrunk.Audit` repo from zero to first-shippable state per ADR-0031 D11. Land the solution layout, the two package families (`HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data`), the three D3 contracts inside `Abstractions` (`IAuditLog`, `IAuditQuery`, `AuditEntry`), the Data-backed append-only `IAuditLog` writer and `IAuditQuery` reader over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork` with the audit-class retention hook (App Config-sourced), the in-memory `IAuditLog`/`IAuditQuery` fixture (internal to the runtime package's test project — deliberately not a `Testing` package per ADR-0027 precedent), the end-to-end smoke test that writes through `IAuditLog` and reads back through `IAuditQuery` against the in-memory fixture, the standard CI pipeline (PR core + release + nightly deps + nightly security), and the contract-shape canary scoped to `HoneyDrunk.Audit.Abstractions` per ADR-0031 D8 / invariant `{N-canary}`.

This is the unblocker for `HoneyDrunk.Auth` (packet 04 of this initiative) and any future Node recording security or privileged-action events. After this packet merges and `v0.1.0` tags, Auth can take a `HoneyDrunk.Audit.Abstractions 0.1.0` PackageReference and wire the first emitter.

**Pre-filing invariant-number substitution required.** This packet's body uses `{N-coupling}` and `{N-canary}` placeholders for the two invariant numbers landed by packet 01 of this initiative (downstream coupling + contract-shape canary). After packet 01 merges and the actual assigned numbers are known, edit this file in place pre-push (invariant 24's pre-filing carve-out) to substitute the real numbers. Hardcoding 45/46 here is WRONG — those slots are occupied by ADR-0016 AI standup as of 2026-05-20.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Audit`

## Motivation
ADR-0031 establishes *what* HoneyDrunk.Audit is, what it owns, what contracts it exposes, and what scaffolds in the first PR (D11). The `HoneyDrunkStudios/HoneyDrunk.Audit` GitHub repo was created by packet 02 of this initiative (`02-architecture-create-audit-repo.md`); the local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Audit/` was cloned by the same chore. The repo currently contains only `.gitignore`, `LICENSE`, and possibly a placeholder `README.md` — no `.slnx`, no projects, no contracts, no store, no CI. The substrate has been registered in the Architecture catalogs (by ADR-0030 packet 01) and the three Audit-related constitutional invariants are in place under `## Audit Invariants` — the substrate-level invariant (audit-emission boundary, by ADR-0030 packet 02) plus `{N-coupling}` (downstream Abstractions-only coupling) and `{N-canary}` (contract-shape canary, both by packet 01 of this initiative). What is missing is the code.

Until this packet ships:

- `HoneyDrunk.Auth` cannot wire the first emitter — the package it would reference (`HoneyDrunk.Audit.Abstractions 0.1.0`) does not exist on the NuGet feed.
- The contract-shape canary's baseline does not exist; there is nothing to diff against on future PRs.
- The Phase-1 append-only-by-interface promise (ADR-0030 D9 / the substrate-level audit-emission boundary invariant landed by ADR-0030 packet 02) is not actually enforced anywhere — the contract that enforces it (`IAuditLog` with no update/delete method) has not been authored.
- Operator's eventual reconciliation (D5 / D6) has nothing to consume.

This packet is intentionally larger than typical bring-up packets because:

- ADR-0031 D11 explicitly lists everything the first PR must produce; splitting it across multiple packets would conflate "the substrate exists and compiles" with "two specific Nodes are migrated onto it" — exactly the bundling the standup-ADR convention exists to prevent (the Auth emitter wiring lives in packet 04, separately).
- All three D3 contracts must land in the first commit so the contract-shape canary has a coherent baseline.
- The Data-backed store and the in-memory fixture together prove the round-trip — writing the contracts without proving they round-trip would ship dead code.

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
│   │   └── AuditEntry.cs            (record — drops the I prefix per Grid-wide naming rule)
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
    │   ├── ContractSurfaceTests.cs            (compile-only + shape assertions on IAuditLog/IAuditQuery/AuditEntry)
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

**Why the in-memory fixtures live `internal` to `HoneyDrunk.Audit.Data.Tests/Fixtures/` and not as a published `HoneyDrunk.Audit.Testing` package:** per ADR-0031 D2 and ADR-0031 §Alternatives Considered ("Ship a `HoneyDrunk.Audit.Testing` package at stand-up (ADR-0017 pattern) — rejected for this Node"), the consumer set at stand-up is small and known (Auth, Operator). ADR-0027 D3 is the precedent: a speculative `Testing` package is not shipped when the consumer set is small and known; the fixture is cut into a package as a non-breaking change when a third consumer emerges. Auth (packet 04) writes its own narrowly-scoped test double rather than taking a dependency on a non-existent `HoneyDrunk.Audit.Testing` package.

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

All three D3 contracts. Records drop the `I` prefix per the Grid-wide naming rule (memory `project_naming_rule_records`); interfaces keep it.

**`HoneyDrunk.Audit.Abstractions` carries exactly ONE `HoneyDrunk.*` reference: `HoneyDrunk.Kernel.Abstractions`**, for the `TenantId` strong type. This is permitted by ADR-0031 D2 ("Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions"). The Data/Vault/Pulse/runtime references all live in `HoneyDrunk.Audit.Data`, not here.

**Deliberate departure from the ADR-0016 AI standup's zero-`HoneyDrunk` strict stance.** ADR-0026 (Accepted) promoted `IGridContext.TenantId` from `string?` to the strong type `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` with a non-null `Internal` sentinel. The Audit Node will be queried for **per-tenant compliance and forensic retrieval**. Stringly-typing tenancy at this contract surface would re-introduce exactly the footgun ADR-0026 closed: every consumer parsing `string` → `TenantId` at use site, malformed values silently swallowed, the Internal default handled inconsistently across consumers. The trade for taking a `Kernel.Abstractions` dependency is: every downstream emitter and reader already has Kernel in its closure (Auth has it, Operator will have it, any Grid Node by definition does), so this introduces zero new transitively-pinned `HoneyDrunk.*` package — just the one already-universal Abstractions package whose entire purpose is grid-wide primitives like this.

**`CorrelationId` stays `string` at v0.1.0 with a follow-up flagged.** Kernel.Abstractions also exposes `CorrelationId` as a strong type. The same anti-footgun argument applies in principle, but `CorrelationId` has lower stakes at the Audit surface — forensic queries are not typically filtered by correlation id (they're filtered by actor, action, tenant, time-window), and the read path treats correlation id as an opaque tracer rather than a queried dimension. To keep the contract-shape canary baseline small at v0.1.0 and avoid a contract-shape change immediately after the canary establishes its baseline, ship `CorrelationId` as `string` now. Follow-up packet: promote `CorrelationId` to `Kernel.Abstractions.Identity.CorrelationId` at v0.2.0 as a single intentional contract-shape bump — that's the right moment to also revisit any other first-pass `AuditQueryFilter` member shapes (see "First-pass shape" note below).

**`AuditEntry.Id` is a strong type `AuditEntryId` from v0.1.0.** Define `AuditEntryId` as a `readonly record struct` in `HoneyDrunk.Audit.Abstractions/AuditEntryId.cs`, matching the Kernel pattern that produced `TenantId` and `CorrelationId`:

```csharp
namespace HoneyDrunk.Audit.Abstractions;

/// <summary>
/// Strong-typed identifier for an <see cref="AuditEntry"/>. Wraps a ULID-shaped string
/// assigned by the writer at append time. Construct via <see cref="New"/> for a freshly
/// generated id, or via the explicit string ctor for round-trip reads.
/// </summary>
public readonly record struct AuditEntryId(string Value)
{
    public static AuditEntryId New() => new(System.Guid.NewGuid().ToString("N"));
    // (Or use a ULID library — match whichever ID strategy DataAuditLog actually uses.)

    public static AuditEntryId Empty { get; } = new(string.Empty);

    public bool IsEmpty => string.IsNullOrEmpty(Value);

    public override string ToString() => Value;
}
```

Why strong-type `Id` at v0.1.0 even though `CorrelationId` stays string until v0.2.0:

- **`Id` is writer-assigned, not propagated.** The promotion-cost trade-off that pushes `CorrelationId` to v0.2.0 (every emitter passes a string from `IGridContext.CorrelationId`, which itself is `string`; the wrapping has to happen at the *boundary* per-emitter) doesn't apply to `Id`. `Id` is assigned inside `DataAuditLog.AppendAsync`, so the construction is single-site and internal.
- **`Id` is the *primary key shape* in the storage layer.** Strong-typing it at v0.1.0 means storage code, query code, and future `IAuditQuery.GetByIdAsync` (if ever added) all see the same type. Migrating it later would be a much wider contract-shape change than promoting `CorrelationId`.
- **Matches the Kernel template.** `TenantId` and `CorrelationId` in `HoneyDrunk.Kernel.Abstractions.Identity` are both `readonly record struct` wrappers over ULID-shaped strings. `AuditEntryId` follows the same shape so consumers see a consistent idiom.

`AuditEntry.Id` is therefore `AuditEntryId` (the strong type), not `string`. Consumers create entries with `Id: AuditEntryId.Empty` (the writer overwrites at append time). The in-memory fixture and the smoke test use the typed sentinel.

Update the `AuditEntry` record definition below to reflect this.

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
    /// Read entries within the given time window, optionally filtered by actor, action,
    /// correlation id, or tenant, in time order (earliest first).
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
    string? Action = null,
    string? CorrelationId = null,
    TenantId? TenantId = null,
    int? Limit = null);
```

```csharp
// AuditEntry.cs (record — drops I prefix per Grid-wide naming rule)
namespace HoneyDrunk.Audit.Abstractions;

using HoneyDrunk.Kernel.Abstractions.Identity;

/// <summary>
/// Canonical append-only audit record. Generalized Grid-wide from the original
/// Operator-scoped shape per ADR-0030 D5.
/// </summary>
/// <param name="Id">Unique identifier for the audit entry. Strong-typed <c>AuditEntryId</c> (ULID-shaped). Pass <see cref="AuditEntryId.Empty"/> at construction; the writer overwrites at append time.</param>
/// <param name="OccurredAt">Wall-clock time the audited action occurred.</param>
/// <param name="Actor">Identifier for who performed the action (user id, system id, etc.).</param>
/// <param name="Action">Identifier for what action was performed (e.g. "auth.login.attempt").</param>
/// <param name="Outcome">Outcome of the action (e.g. "granted", "denied", "succeeded", "failed").</param>
/// <param name="CorrelationId">Correlation identifier tying this entry to a broader operation. Stays string at v0.1.0; promoted to <c>Kernel.Abstractions.Identity.CorrelationId</c> at v0.2.0 (follow-up packet).</param>
/// <param name="TenantId">Tenant scope of the entry. Uses the Kernel strong type per ADR-0026; use <c>TenantId.Internal</c> for non-tenant-scoped Grid events.</param>
/// <param name="Context">Free-form JSON-shaped context payload (action-specific detail).</param>
public sealed record AuditEntry(
    AuditEntryId Id,
    DateTimeOffset OccurredAt,
    string Actor,
    string Action,
    string Outcome,
    string CorrelationId,
    TenantId TenantId,
    string? Context = null);
```

**First-pass shape; subject to refinement before v0.2.0 baseline lock.** The exact member set of `AuditQueryFilter` (specifically whether to include richer predicates like `outcome` filtering or tag-based search) is first-pass. The contract-shape canary established in this packet makes any post-v0.1.0 change a deliberate version-bump event, so the executing agent should land workable shapes here without overdesigning — refinement before Operator (the second consumer) locks against v0.2.0 is expected. The three names `IAuditLog`, `IAuditQuery`, `AuditEntry` are stable across refinement; only `AuditQueryFilter` is on the negotiable list.

**`Id` and `OccurredAt` assignment policy.** `Id` is assigned by the writer (`DataAuditLog.AppendAsync` generates a ULID and overwrites whatever value is passed in via the `AuditEntry` record). `OccurredAt` is set by the caller (Auth, Operator) at the moment the audited action happened — Audit does not overwrite it. The XML docs above reflect this; the `Id` parameter on the record carries a comment that consumers may pass `string.Empty` and the writer will assign.

**Abstractions stance — exactly one `HoneyDrunk.*` reference, for `Kernel.Abstractions.Identity.TenantId`.** `HoneyDrunk.Audit.Abstractions.csproj` carries exactly one `HoneyDrunk.*` PackageReference: `HoneyDrunk.Kernel.Abstractions`. No `HoneyDrunk.Kernel` (runtime), no `HoneyDrunk.Data*`, no `HoneyDrunk.Vault*`, no `HoneyDrunk.Pulse*`. The `HoneyDrunk.Standards` reference uses `PrivateAssets="all"` so analyzers do not propagate (allowed; that is the standard pattern). Any GridContext propagation, telemetry, or App Config sourcing lives in `HoneyDrunk.Audit.Data`, not in `Abstractions`. The `TenantId` field on `AuditEntry` and `AuditQueryFilter` is the Kernel strong type per ADR-0026; the `CorrelationId` field stays `string` at v0.1.0 with a v0.2.0 promotion flagged. (This is a **deliberate departure** from the ADR-0016 AI standup's zero-`HoneyDrunk` strict stance — driven by ADR-0026's per-tenant typing requirement. See "Contract details — `HoneyDrunk.Audit.Abstractions`" section above for the rationale.)

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
- Assigns the entry's `Id` (ULID) at write time, overwriting any caller-passed value.
- Enriches the entry with the caller's `IGridContext.CorrelationId` and `TenantId` if the entry's fields are empty (defensive — callers should pass them, but Audit is the durable-record-of-last-resort; an unattributable audit entry is worse than a redundantly-attributed one).
- Persists via `IRepository<AuditEntry>.AddAsync` + `IUnitOfWork.SaveChangesAsync`. No update path. No delete path. The contract has none; the implementation must have none either.
- Emits operational telemetry via `ITelemetryActivityFactory` (`audit.log.append`, latency, byte size). Telemetry direction is **one-way to Pulse** per D7 — `HoneyDrunk.Audit.Data` does not reference any `HoneyDrunk.Pulse` package.

**`DataAuditQuery`** — implements `IAuditQuery.ReadAsync(AuditQueryFilter, CancellationToken)`:
- **Composes the filter as a single `Expression<Func<AuditEntry, bool>>` and calls `IReadOnlyRepository<AuditEntry>.FindAsync(predicate, ct)`.** Per the actual `HoneyDrunk.Data.Abstractions/Repositories/IReadOnlyRepository.cs` surface (the public read methods are `FindByIdAsync(object id, ct)`, `FindAsync(Expression<Func<TEntity,bool>>, ct)`, `FindOneAsync(...)`, `ExistsAsync(...)`, `CountAsync(...)`), there is **no `Query()` method** on either `IRepository<T>` or `IReadOnlyRepository<T>` at v0.1.0. `FindAsync` is the supported predicate-based read path; the implementation builds the time-window + optional `Actor`/`Action`/`CorrelationId`/`TenantId` predicate at the C# `Expression` level and passes it to `FindAsync`, which the Data backing translates to a backing-store query.
- **Ordering and `Limit` happen post-fetch, in memory.** `FindAsync` returns `IReadOnlyList<TEntity>` without exposing order-by or take semantics at the abstraction. `DataAuditQuery` does the `OrderBy(e => e.OccurredAt)` and the `Take(limit)` after `FindAsync` returns. This is a **known Phase-1 inefficiency** for very large result sets — the entire filtered set is materialized in memory, then ordered and truncated. Acceptable at v0.1.0 because forensic queries are low-volume and the time-window predicate already bounds the result set. **Phase-2 hardening item:** when `IReadOnlyRepository<T>` ships order-by/take primitives (or `DataAuditQuery` switches to direct `DbContext`-internal access), revisit this; tracked as a known gap, not shipped at v0.1.0.
- Honors the optional `Limit` field (default if unset: 1000; cap if set above: 10000 — these are constants in the class, not App-Config-sourced, because they are query-shape concerns not retention concerns).
- Emits operational telemetry (`audit.query.read`, latency, result count).

**Open question for the executing agent:** if `IReadOnlyRepository<T>.FindAsync` materializes the *entire matching set* before in-memory ordering proves too costly on a real backing (large time-windows over months of audit), the alternative is to drop down to **direct `DbContext` access inside `DataAuditQuery`** with an explicit "intentional Data-internal coupling at Phase-1; rotate to public read surface when Data ships order-by/take primitives" comment in the class file. This is acceptable for the Audit Node specifically because (a) Audit's reads are forensic — bounded by user-supplied time-window — not a hot path, and (b) the boundary violation is contained to one class file with an inline TODO. **Pick `FindAsync` + in-memory order/take at v0.1.0 unless the executing agent's `dotnet build` profiles show >1s latency at realistic forensic volumes**, in which case fall back to direct `DbContext` access with the inline rationale. Either path satisfies the contract — `IAuditQuery.ReadAsync` returns a correctly time-ordered, optionally limited `IReadOnlyList<AuditEntry>`.

**`AuditRetentionPolicy`** — Sources the audit-class retention value (in days) from App Configuration via `IConfigProvider.GetValueAsync` **once at startup**. Default if the key is unset: **365 days**, with a `::warning::` logged ("audit:retention:days not configured; defaulting to 365d. Set this in App Configuration per the consuming deployable's policy."). The retention enforcement itself (whether implemented as a background job or as a query-time filter on reads) is a Phase-2 concern — Phase 1 lands the policy *value* and the read of it, not the enforcement loop. The class exposes a public `int RetentionDays { get; }` property populated at startup. **`IConfigProvider` does not expose change-events at v0.1.0** (see `HoneyDrunk.Vault.Abstractions/IConfigProvider.cs` — the surface is `GetValueAsync` / `TryGetValueAsync` / typed `GetValueAsync<T>`; no observable/change-token contract). Configuration changes therefore require a host restart to take effect at v0.1.0. **Hot-reload is a follow-up concern not in this packet's scope** — it requires either Vault adding a change-token surface to `IConfigProvider` or Audit subscribing to its own out-of-band notification channel. Neither is in scope here.

**Per ADR-0030 D4 and ADR-0031 D4: audit-class retention is distinct from observability retention; the two regimes are not shared and not interchangeable.** The default 365d is a sensible audit-class baseline (a full year of forensic depth) and is intentionally an order of magnitude longer than observability defaults — observability defaults are typically days/weeks for traces and a few months for sampled logs.

**`AuditTelemetry`** — Convenience helpers for `DataAuditLog` and `DataAuditQuery` to emit consistent activity names and tags. Wraps `ITelemetryActivityFactory`. **GridContext / CorrelationId propagation onto telemetry activities lives here** (not in `Abstractions`).

**Host registration of `IConfigProvider`, `IRepository`, `IUnitOfWork`.** All three are host concerns — the deployable host is responsible for `services.AddVault().AddAppConfigurationProvider(...)`, `services.AddData(...)`, and any `IUnitOfWork` registration. `HoneyDrunk.Audit.Data` references the contracts (`HoneyDrunk.Vault` for `IConfigProvider`, `HoneyDrunk.Data.Abstractions` for `IRepository`/`IUnitOfWork`); it does not reference any specific Data backing or Vault provider package. `AddHoneyDrunkAuditData()` throws a clear `InvalidOperationException` at first resolution if any of `IConfigProvider`, `IRepository<AuditEntry>`, or `IUnitOfWork` is missing, so a misconfigured host fails fast with a useful message.

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

`IAuditLog` and `IAuditQuery` are both registered as Singleton. This is deliberate and matches the in-memory fixture pattern (the `InMemoryAuditLog` test double uses `List<AuditEntry>` + `lock(_gate)` for thread-safe append; the production class follows the same shape — internal locking around the durable backing call). The reasons:

1. **Auth's emitters are Singleton.** `BearerTokenAuthenticationProvider` and `DefaultAuthorizationPolicy` are registered as Singleton by `HoneyDrunkAuthServiceCollectionExtensions.AddHoneyDrunkAuth()` (see packet 04 §Lifetime story). If `IAuditLog` were Scoped, Auth's Singleton emitters injecting it would create a **captive dependency** — the Singleton would close over the first scope's `IAuditLog` instance, and every subsequent emit would write to a disposed/stale scoped instance. Scoped → Singleton dep is the classic ASP.NET Core lifetime trap.

2. **`DataAuditLog.AppendAsync` does not hold scoped state across calls.** It receives the `AuditEntry` and the `IGridContext`-derived `CorrelationId`/`TenantId` per call (resolved via `IGridContextAccessor.GridContext` ambient access, **not** via direct `IGridContext` ctor injection — same captive-dep avoidance pattern as Auth's emitters). The `IRepository<AuditEntry>` and `IUnitOfWork` it consumes are resolved fresh per call via `IServiceScopeFactory` (Singleton-friendly resolver) — Data's `IRepository`/`IUnitOfWork` are themselves typically Scoped, so `DataAuditLog` creates a short-lived scope for each `AppendAsync` and disposes it after `SaveChangesAsync` returns. The per-call scope churn is the cost of keeping `IAuditLog` Singleton; it is paid per audit emit, which is low-frequency relative to per-request work.

3. **Append is single-row.** `IAuditLog` exposes exactly `AppendAsync(AuditEntry, CancellationToken)`. There is no batching, no bulk insert, no transaction spanning multiple appends. A per-call scope is the right unit of work.

The class-level shape:

```csharp
public sealed class DataAuditLog : IAuditLog
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IGridContextAccessor _gridContextAccessor;
    private readonly AuditTelemetry _telemetry;

    public async Task AppendAsync(AuditEntry entry, CancellationToken cancellationToken = default)
    {
        // Stamp Id, enrich CorrelationId/TenantId from ambient grid context, etc.
        // ...

        using var scope = _scopeFactory.CreateAsyncScope();
        var repo = scope.ServiceProvider.GetRequiredService<IRepository<AuditEntry>>();
        var uow = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();

        await repo.AddAsync(stamped, cancellationToken);
        await uow.SaveChangesAsync(cancellationToken);
    }
}
```

`DataAuditQuery` follows the same per-call-scope pattern for its `FindAsync` call.

**`IConfigProvider` lifetime.** `IConfigProvider` is host-side registered (via Vault); Audit consumes it from `AuditRetentionPolicy`'s ctor at the Singleton's first resolution to read `audit:retention:days` once at startup. No per-call resolution needed since the value is read-once. If `IConfigProvider` is itself Scoped in some Vault providers, the Singleton-resolving-Scoped captive-dep trap applies — `AuditRetentionPolicy` resolves it via `IServiceScopeFactory` at startup to be safe.

**Alternative rejected — Scoped `IAuditLog` with per-call resolution from Singleton emitters.** Could have kept `IAuditLog` Scoped and asked Auth's Singleton emitters to resolve it per-call via `IServiceScopeFactory.CreateAsyncScope()`. Rejected: pushes the scope-creation cost to every emitting Node, multiplies the per-call scope churn (Auth creates one for IAuditLog, then DataAuditLog creates one for IRepository — two scopes per emit), and makes the lifetime contract harder to reason about. Singleton-with-internal-scope-factory is simpler and matches the in-memory fixture's threading model.

### In-memory fixture details — `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/`

The in-memory fixture exists for two distinct consumers:

- **Audit's own `.Tests` projects** — for the end-to-end smoke test that proves the contracts round-trip without a database backing.
- **Future downstream consumers** that need a deterministic test double **eventually** — but not at v0.1.0. Per D2 / ADR-0027 D3 precedent, the fixture stays `internal` until a third consumer needs it; at that point it is cut into `HoneyDrunk.Audit.Testing` as a non-breaking change.

Implementation:

```csharp
// tests/HoneyDrunk.Audit.Data.Tests/Fixtures/InMemoryAuditLog.cs
namespace HoneyDrunk.Audit.Data.Tests.Fixtures;

internal sealed class InMemoryAuditLog : IAuditLog
{
    private readonly List<AuditEntry> _entries = new();
    private readonly object _gate = new();

    public Task AppendAsync(AuditEntry entry, CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            // Assign Id at append time, like the real DataAuditLog does.
            var stamped = entry with { Id = entry.Id.IsEmpty ? AuditEntryId.New() : entry.Id };
            _entries.Add(stamped);
        }
        return Task.CompletedTask;
    }

    internal IReadOnlyList<AuditEntry> Snapshot()
    {
        lock (_gate) { return _entries.ToArray(); }
    }
}
```

```csharp
// tests/HoneyDrunk.Audit.Data.Tests/Fixtures/InMemoryAuditQuery.cs
namespace HoneyDrunk.Audit.Data.Tests.Fixtures;

internal sealed class InMemoryAuditQuery : IAuditQuery
{
    private readonly InMemoryAuditLog _backing;

    public InMemoryAuditQuery(InMemoryAuditLog backing) => _backing = backing;

    public Task<IReadOnlyList<AuditEntry>> ReadAsync(AuditQueryFilter filter, CancellationToken cancellationToken = default)
    {
        var snapshot = _backing.Snapshot();
        IEnumerable<AuditEntry> q = snapshot
            .Where(e => e.OccurredAt >= filter.Since && e.OccurredAt <= filter.Until);
        if (filter.Actor is not null) q = q.Where(e => e.Actor == filter.Actor);
        if (filter.Action is not null) q = q.Where(e => e.Action == filter.Action);
        if (filter.CorrelationId is not null) q = q.Where(e => e.CorrelationId == filter.CorrelationId);
        if (filter.TenantId is TenantId t) q = q.Where(e => e.TenantId == t);
        q = q.OrderBy(e => e.OccurredAt);
        if (filter.Limit is int limit) q = q.Take(limit);
        return Task.FromResult<IReadOnlyList<AuditEntry>>(q.ToArray());
    }
}
```

### Smoke test — `tests/HoneyDrunk.Audit.Data.Tests/SmokeTests.cs`

```csharp
namespace HoneyDrunk.Audit.Data.Tests;

public class SmokeTests
{
    [Fact]
    public async Task WriteThroughIAuditLog_ReadBackThroughIAuditQuery_RoundTrips()
    {
        var fixture = new InMemoryAuditLog();
        IAuditLog log = fixture;
        IAuditQuery query = new InMemoryAuditQuery(fixture);

        var occurredAt = DateTimeOffset.UtcNow;
        var entry = new AuditEntry(
            Id: AuditEntryId.Empty, // writer assigns
            OccurredAt: occurredAt,
            Actor: "user:42",
            Action: "auth.login.attempt",
            Outcome: "granted",
            CorrelationId: "corr-abc",
            TenantId: TenantId.Internal);

        await log.AppendAsync(entry);

        var results = await query.ReadAsync(new AuditQueryFilter(
            Since: occurredAt.AddMinutes(-1),
            Until: occurredAt.AddMinutes(1)));

        Assert.Single(results);
        Assert.Equal("user:42", results[0].Actor);
        Assert.Equal("auth.login.attempt", results[0].Action);
        Assert.Equal("granted", results[0].Outcome);
        Assert.False(results[0].Id.IsEmpty);
    }
}
```

Per ADR-0031 D11: "An `AuditEntry` written through `IAuditLog` is read back through `IAuditQuery` against the in-memory fixture." This satisfies that requirement.

### Append-only-at-interface enforcement test

`tests/HoneyDrunk.Audit.Abstractions.Tests/AppendOnlyAtInterfaceTests.cs` uses reflection to prove `IAuditLog` exposes exactly one method (`AppendAsync`) — no `UpdateAsync`, no `DeleteAsync`, no `ReplaceAsync`. This is a build-time defense against accidental future addition of an update/delete method that would silently break the substrate-level audit-emission boundary invariant (ADR-0030 packet 02; numbered `{N-substrate}` in the constitution at this packet's edit time).

```csharp
[Fact]
public void IAuditLog_HasOnlyAppendAsync_NoUpdateOrDelete()
{
    var methods = typeof(IAuditLog).GetMethods().Select(m => m.Name).ToHashSet(StringComparer.Ordinal);
    Assert.Contains("AppendAsync", methods);
    Assert.DoesNotContain("UpdateAsync", methods);
    Assert.DoesNotContain("ReplaceAsync", methods);
    Assert.DoesNotContain("DeleteAsync", methods);
    Assert.DoesNotContain("RemoveAsync", methods);
    Assert.Equal(1, methods.Count);
}
```

### CI workflows

All five workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows. No bespoke CI logic in the Audit repo.

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
# .github/workflows/api-compatibility.yml — ADR-0031 D8 / invariant {N-canary}
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

The path filter ensures the canary only runs when `Abstractions` changes **or when the solution-level version moves** (a `Directory.Build.props` edit). Version bumps are the intentional contract-shape change events — leaving them out of the trigger means a `<Version>0.1.0 → 0.2.0</Version>` bump that accompanies a contract-shape change could merge without the canary running, leaving the baseline unverified. Mirror this in any AI-sector / Capabilities canary precedents if they are not already similar. The whole-assembly diff produced by `job-api-compatibility.yml` is sufficient to enforce D8 / invariant `{N-canary}`: per D9 / invariant `{N-coupling}`, `Abstractions` is the only thing downstream Nodes compile against, so any shape drift in any public type in `Abstractions` (`IAuditLog`, `IAuditQuery`, `AuditEntry`, `AuditQueryFilter`, `AuditEntryId`) counts. There is no low-traffic remainder to leave un-frozen.

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
      enable-nuget-publish: true
    secrets:
      nuget-api-key: ${{ secrets.NUGET_API_KEY }}
```

The reusable `release.yml` in `HoneyDrunk.Actions` declares a named optional secret `nuget-api-key` (and authenticates ACR via OIDC, which is what `id-token: write` in the reusable workflow's permissions block enables). **No `secrets: inherit`** — the caller passes only what `release.yml` actually declares. The packet 02 chore that created the `HoneyDrunk.Audit` repo must seed the `NUGET_API_KEY` repository secret (or org-level secret available to this repo) for `dotnet nuget push` to succeed; if the secret is missing, `release.yml`'s `nuget/push` action falls through and the publish step fails with a clear "API key not set" message. Tags are human-pushed per invariant 27 — agents do not push tags. The release workflow packs and publishes both `src/*` projects in a single tag-driven run.

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

- **Repo `README.md`** — purpose statement, package matrix, link to the active-work tracker in `repos/HoneyDrunk.Audit/active-work.md` (or to GitHub issues), plus a dedicated `## For downstream consumers — minimal wiring` section showing the host-side `services.AddVault().AddData(...).AddHoneyDrunkAuditData()` snippet. This snippet is copy-pasteable into a downstream Node's deployable host. Also include a "Phase-1 honest limitation" section that names two distinct, intentional gaps:
  1. **The interface is append-only; the underlying storage is not cryptographically tamper-evident.** Hash-chain / WORM tamper-evidence is deferred behind the boundary.
  2. **Append-only is enforced at the `IAuditLog` interface surface (no `Update`/`Delete` methods exposed). At the storage layer, `DataAuditLog` consumes `IRepository<AuditEntry>` which technically exposes `Update`/`Remove`/`UpdateRange`/`RemoveRange` methods inherited from `HoneyDrunk.Data.Abstractions/Repositories/IRepository.cs`.** `DataAuditLog`'s source code does not call any of those methods (and the `AppendOnlyAtInterfaceTests` reflection check on `IAuditLog` enforces the contract at the interface). A stronger compile-time guarantee — e.g., an `IAppendOnlyRepository<T>` carve-out from `HoneyDrunk.Data.Abstractions` that exposes only `AddAsync`/`AddRangeAsync` + the read methods — is a **Phase-2 hardening item**, not shipped at v0.1.0. The boundary at v0.1.0 is enforced by (a) the `IAuditLog` interface shape, (b) `DataAuditLog`'s reviewed source code, and (c) the Audit Node's dedicated managed identity (per ADR-0031 D5) which scopes who can perform storage-layer writes regardless of the C# surface.

  **Per memory `feedback_no_adr_in_docs`, the README does not cite "ADR-0031" by number in its narrative.** It explains what the package does and what its honest limitations are.
- **Repo `CHANGELOG.md`** — `## [0.1.0] - YYYY-MM-DD` entry covering the entire scaffold landing. **Per memory `feedback_no_unreleased_commits`, do not land entries under `## Unreleased` — use the dated, SemVer-bumped section.**
- **Per-package `README.md`** — purpose, public API surface summary, install command. Required by invariant 12 for new packages.
- **Per-package `CHANGELOG.md`** — `## [0.1.0]` entry for each package introduced in this packet.

## Affected Files
Entire repo is created from this packet. Notable new files:
- `HoneyDrunk.Audit.slnx`, `Directory.Build.props`, `README.md`, `CHANGELOG.md`, `.editorconfig`
- `src/HoneyDrunk.Audit.Abstractions/` — `.csproj`, `IAuditLog.cs`, `IAuditQuery.cs`, `AuditEntry.cs`, `AuditEntryId.cs` (record-struct, strong-typed id per Kernel template), `README.md`, `CHANGELOG.md`
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
| `HoneyDrunk.Kernel.Abstractions` | For `TenantId` strong type per ADR-0026. **Deliberate departure** from ADR-0016's zero-`HoneyDrunk` strict stance in Abstractions — see Abstractions stance section above. ADR-0031 D2 explicitly permits "zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions" for this Node's `Abstractions`. |

(No `HoneyDrunk.Kernel` runtime reference — `Kernel.Abstractions` carries the contracts including `TenantId`. Per invariant 2, `Abstractions` references `Abstractions`, never runtime.)

### `HoneyDrunk.Audit.Data.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext`, `TenantId` — compile-time contract consumption. Per invariant 2, depend on Abstractions not runtime where the consumed surface is interfaces. |
| `HoneyDrunk.Kernel` | Optional — only if Data needs concrete Kernel runtime types (lifecycle registration extensions, concrete `IGridContext` builder). If only the interfaces from `Kernel.Abstractions` are used, **drop this row** and let the composing host wire Kernel. Audit a similar Grid-Node `Data` package (e.g. `HoneyDrunk.Communications`, `HoneyDrunk.Notify`) to confirm which pattern it follows; mirror that pattern. |
| `HoneyDrunk.Data.Abstractions` | For `IRepository`, `IUnitOfWork` |
| `HoneyDrunk.Vault` | For `IConfigProvider` (D4 — App Config sourcing for audit-class retention). The interface namespace is `HoneyDrunk.Vault.Abstractions` but the package is `HoneyDrunk.Vault` — Vault does not ship a separate `.Abstractions` NuGet. If a future Vault refactor splits Abstractions out, switch this row to `HoneyDrunk.Vault.Abstractions`. |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | DI registration helpers |
| `Microsoft.Extensions.Hosting.Abstractions` | For startup hook integration |
| `Microsoft.Extensions.Logging.Abstractions` | Logger contracts |
| `Microsoft.Extensions.Options.ConfigurationExtensions` | Bind options from `IConfigProvider` |

Project reference: `HoneyDrunk.Audit.Abstractions`.

### Test projects

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.NET.Test.Sdk` | Standard |
| `xunit` | Standard |
| `xunit.runner.visualstudio` | Standard |
| `Microsoft.Extensions.DependencyInjection` | For DI in Data tests |

Project references as appropriate to each `.Tests` project:
- `HoneyDrunk.Audit.Abstractions.Tests` → `HoneyDrunk.Audit.Abstractions`
- `HoneyDrunk.Audit.Data.Tests` → `HoneyDrunk.Audit.Data` and `HoneyDrunk.Audit.Abstractions`

## Boundary Check

- [x] All work inside `HoneyDrunk.Audit`. No edits to other Grid repos.
- [x] `HoneyDrunk.Audit.Abstractions` carries exactly ONE `HoneyDrunk.*` reference: `HoneyDrunk.Kernel.Abstractions` (for `TenantId`). Per ADR-0031 D2's "zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions" allowance, and ADR-0026's per-tenant strong typing requirement. No `HoneyDrunk.Kernel` runtime ref; no `HoneyDrunk.Data*`, no `HoneyDrunk.Vault*`, no `HoneyDrunk.Pulse*` from Abstractions.
- [x] `HoneyDrunk.Audit.Data` references `HoneyDrunk.Audit.Abstractions` (project reference), `HoneyDrunk.Kernel.Abstractions` (for interfaces), `HoneyDrunk.Data.Abstractions`, `HoneyDrunk.Vault` — and **no** `HoneyDrunk.Pulse`. Optional `HoneyDrunk.Kernel` runtime reference dropped if not needed (audit a peer `Data` package to confirm). Telemetry is one-way to Pulse per D7; Audit has no runtime dependency on Pulse.
- [x] No secrets in code. The retention value is read via `IConfigProvider` from App Configuration (ADR-0005 host composition); no key vault access is needed from this runtime (the retention value is non-secret configuration).
- [x] `IAuditLog` exposes exactly `AppendAsync` — no update, no replace, no delete. Append-only is enforced at the interface surface per the substrate-level audit-emission boundary invariant `{N-substrate}` (ADR-0030 packet 02) and repo-local invariant 2.
- [x] `AuditEntry` is a record (no `I` prefix). `IAuditLog` and `IAuditQuery` are interfaces (with `I`). `AuditQueryFilter` is a record (no `I`). Per Grid-wide naming rule (memory `project_naming_rule_records`).
- [x] In-memory fixtures live `internal` to the test project — not packaged. Per D2 + ADR-0027 D3 precedent.
- [x] The scaffold does NOT include hash-chain / WORM tamper-evidence (deferred per D9 / ADR-0030 D8a). The scaffold does NOT include the deployable tenant-facing forensics Service (deferred per ADR-0030 D8b). The scaffold does NOT include the Auth emitter wiring (packet 04 — separate). The scaffold does NOT include Operator reconciliation (Operator scaffolding initiative — separate).
- [x] Per ADR-0030 D9 / D4: the store is **not** documented or described as tamper-evident. Repo README's "Phase-1 honest limitation" section names this explicitly.

## Acceptance Criteria

- [ ] `HoneyDrunk.Audit.slnx` builds clean from a fresh clone via `dotnet build` with no warnings (warnings-as-errors).
- [ ] All three D3 contracts present in `HoneyDrunk.Audit.Abstractions` with XML documentation per invariant 13. Records (`AuditEntry`, `AuditQueryFilter`) drop the `I` prefix; interfaces (`IAuditLog`, `IAuditQuery`) keep it. The strong-typed identifier `AuditEntryId` is also a record-struct without `I` (Grid-wide naming rule).
- [ ] `HoneyDrunk.Audit.Abstractions` has exactly ONE `HoneyDrunk.*` PackageReference: `HoneyDrunk.Kernel.Abstractions` (for `TenantId`). Per ADR-0031 D2's "zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions" allowance. No `HoneyDrunk.Kernel` runtime ref; no `HoneyDrunk.Data*` / `HoneyDrunk.Vault*` / `HoneyDrunk.Pulse*` refs. Constitutional invariants `{N-coupling}` and 1 (downstream Abstractions-only coupling; Abstractions stay near-minimal) are satisfied — the single Kernel-Abstractions reference is an intentional, ADR-permitted exception.
- [ ] `IAuditLog` exposes exactly one method, `AppendAsync(AuditEntry, CancellationToken)`. No `UpdateAsync`, no `ReplaceAsync`, no `DeleteAsync`, no `RemoveAsync`. The reflection test `AppendOnlyAtInterfaceTests.cs` asserts this and passes.
- [ ] `HoneyDrunk.Audit.Data` exposes `AddHoneyDrunkAuditData()` extension; `IAuditLog` and `IAuditQuery` resolve from DI after registration.
- [ ] `DataAuditLog.AppendAsync` persists via `IRepository<AuditEntry>.AddAsync` + `IUnitOfWork.SaveChangesAsync`. **No source-code call to `Update`/`Remove`/`UpdateRange`/`RemoveRange`** on `IRepository<AuditEntry>` — even though those methods exist on the inherited `IRepository<T>` interface (per `HoneyDrunk.Data.Abstractions/Repositories/IRepository.cs`), `DataAuditLog`'s source does not invoke any of them. Code review enforces this at v0.1.0; the README's Phase-1 honest limitation section explicitly names the storage-layer gap (`IAppendOnlyRepository<T>` carve-out is a Phase-2 hardening item).
- [ ] `DataAuditLog.AppendAsync` assigns the entry's `Id` at write time as a fresh `AuditEntryId` (ULID-shaped strong type) and overwrites any caller-passed value (caller passes `AuditEntryId.Empty`); sets `CorrelationId`/`TenantId` defensively from `IGridContextAccessor.GridContext` if the entry's fields are empty.
- [ ] `DataAuditLog` and `DataAuditQuery` resolve `IGridContext` via `IGridContextAccessor.GridContext` (ambient per-call), **not** via direct `IGridContext` ctor injection. The classes are Singleton; `IGridContext` is Scoped — direct injection would be a captive-dep.
- [ ] `DataAuditLog` and `DataAuditQuery` resolve `IRepository<AuditEntry>` / `IReadOnlyRepository<AuditEntry>` / `IUnitOfWork` via `IServiceScopeFactory.CreateAsyncScope()` per call (the classes are Singleton; Data abstractions are typically Scoped — same captive-dep avoidance pattern).
- [ ] `IAuditLog`, `IAuditQuery`, `AuditRetentionPolicy`, `AuditTelemetry`, `DataAuditLog`, `DataAuditQuery` are all registered as `Singleton` in `AddHoneyDrunkAuditData()`. Lifetime story is documented in the repo README and matches the Singleton-emitters-in-Auth lifetime (per packet 04).
- [ ] `DataAuditQuery.ReadAsync` is implemented over `IReadOnlyRepository<AuditEntry>.FindAsync(predicate, ct)` (the actual public read method on the Data abstraction at v0.1.0; there is no `Query()` method). Time ordering and `Limit` are applied post-fetch, in memory. The class file carries a `// Phase-1: FindAsync + in-memory order/take. Phase-2: switch to a public order-by/take primitive when Data ships one.` comment near the read site.
- [ ] **`AuditEntryId` strong type lives at `src/HoneyDrunk.Audit.Abstractions/AuditEntryId.cs`** as a `readonly record struct` matching the Kernel template (`TenantId`, `CorrelationId`). Exposes `AuditEntryId.New()`, `AuditEntryId.Empty`, `IsEmpty` property, and `ToString()` returning the wrapped string. `AuditEntry.Id` is typed as `AuditEntryId`, not `string`.
- [ ] `DataAuditLog` and `DataAuditQuery` emit operational telemetry via `ITelemetryActivityFactory` (activities `audit.log.append`, `audit.query.read`). No `HoneyDrunk.Pulse.*` reference anywhere in `HoneyDrunk.Audit.Data.csproj`.
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

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `HoneyDrunk.Audit.Abstractions.csproj` must contain zero `HoneyDrunk.*` references. The `HoneyDrunk.Standards` analyzer reference uses `PrivateAssets="all"` so it does not propagate.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. — `HoneyDrunk.Audit.Data` references `HoneyDrunk.Audit.Abstractions` (project reference) and `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Data.Abstractions`, `HoneyDrunk.Vault` for runtime needs; the layered structure is preserved. The `HoneyDrunk.Kernel` runtime row in the NuGet table is optional — only added if Data needs concrete Kernel runtime types beyond the interfaces from `Kernel.Abstractions`.

> **Invariant 3:** Provider packages depend on their parent Node's contracts, not internal implementation details. — Not directly applicable here (Audit has no provider packages at Phase 1). A future sibling backing slot (e.g. `HoneyDrunk.Audit.Cosmos`) would reference `HoneyDrunk.Audit.Abstractions` only, per this rule.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — `HoneyDrunk.Audit.Data` references Kernel and Data; nothing in `HoneyDrunk.Audit.*` is referenced back from Kernel or Data. Audit → Data → Kernel and Audit → Kernel are all DAG-consistent per ADR-0031 D10.

> **Invariant 5:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null `TenantId`. — `DataAuditLog.AppendAsync` resolves `IGridContext` from DI to enrich the entry's `CorrelationId` and `TenantId` defensively. Callers are expected to populate the fields themselves; Audit is the durable-record-of-last-resort and enriches when the fields are empty to avoid unattributable entries.

> **Invariant 6:** CorrelationId is never null or empty, and TenantId is never absent, in a live GridContext. — `DataAuditLog` honors this by enriching empty entry fields from `IGridContext` rather than persisting unattributable entries. Per `repos/HoneyDrunk.Audit/integration-points.md`: "an audit entry without correlation and tenant is unattributable, which defeats the substrate's purpose."

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. — The retention value is non-secret configuration, sourced via `IConfigProvider` (App Configuration), not via `ISecretStore`. This is the App-Configuration-via-Vault pattern per ADR-0005, not a secret read.

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning. — This packet establishes HoneyDrunk.Audit's solution and CI pipeline. Per the new-Node convention, the standup is itself ADR-governed (ADR-0031).

> **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — Both `src/*` projects ship `README.md` and `CHANGELOG.md` in the same commit. Repo-level `CHANGELOG.md` and `README.md` also present.

> **Invariant 13:** All public APIs have XML documentation. Enforced by HoneyDrunk.Standards analyzers. — All three D3 contracts and `AuditQueryFilter` carry `///` summaries.

> **Invariant 14:** Canary tests validate cross-Node boundaries. Each Node that depends on another has a `.Canary` project verifying integration assumptions. — Future-facing: downstream Nodes (Auth at packet 04, eventually Operator) will add `.Canary` projects against `HoneyDrunk.Audit.Abstractions`. This packet does not author those — they belong with each consuming Node's wiring packet. **Audit itself does not need a `.Canary` project at this scaffold** because it consumes Kernel and Data via well-established contracts; the dependency-direction canaries on Kernel/Data would catch any boundary drift on the *consumed* side. (If invariant 14's intent is interpreted as requiring every consuming Node to ship a `.Canary` project even when its consumed contracts are pre-stable, raise that as a follow-up — this packet ships the round-trip smoke test as the equivalent boundary-verification shape.)

> **Invariant 15:** Tests never depend on external services. Use InMemory providers for isolation. — The in-memory `IAuditLog`/`IAuditQuery` fixture exists specifically to satisfy this for Audit's own tests at v0.1.0, and (eventually, via a future `HoneyDrunk.Audit.Testing` package) for downstream Nodes' tests.

> **Invariant 16:** No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only. — Fixtures live under `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/`, not in `src/HoneyDrunk.Audit.Data/`.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. `HoneyDrunk.Standards` must be on every new .NET project. — This packet's NuGet Dependencies section enumerates all four new `.csproj` references plus the two test-project reference sets.

> **Invariant 27:** All projects in a solution share one version and move together. When a version bump is warranted, every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit. — Initial scaffold ships at `0.1.0` across both `src/*` packages.

> **Invariant `{N-substrate}` (ADR-0030 packet 02):** Durable, attributable security and action events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. Phase-1 audit integrity is append-only-by-interface (`IAuditLog` exposes no update and no delete method); it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. — This scaffold IS the durable substrate this invariant references. `IAuditLog` exposes no update or delete method (proven by `AppendOnlyAtInterfaceTests`); the README's "Phase-1 honest limitation" section names the not-tamper-evident reality.

> **Invariant `{N-coupling}` (this initiative, packet 01):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`. Composition against `HoneyDrunk.Audit.Data` is a host-time concern resolved at application startup from App Configuration. — Reinforced in this scaffold by keeping `Abstractions` near-minimal (one `HoneyDrunk.Kernel.Abstractions` reference for `TenantId`; nothing else) so consumers (Auth at packet 04, Operator later) don't transit unintended pins through.

> **Invariant `{N-canary}` (this initiative, packet 01):** The HoneyDrunk.Audit Node CI must include a contract-shape canary for `IAuditLog`, `IAuditQuery`, and `AuditEntry`. Shape drift on any of the three is a build failure unless paired with an intentional version bump. — `api-compatibility.yml` calls `HoneyDrunk.Actions/job-api-compatibility.yml` scoped to `HoneyDrunk.Audit.Abstractions`. The whole-assembly diff covers all three contracts plus `AuditQueryFilter`.

## Referenced ADR Decisions

**ADR-0031 D1 (Audit Node ownership):** HoneyDrunk.Audit is the Core sector's single Node owning the Grid's durable, attributable security-and-action record. It is a record substrate, not a control plane and not an observability pipeline. This scaffold ships only the substrate — no allow/deny decision logic, no sampling/aggregation.

**ADR-0031 D2 (Package families):** Two packages — `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data`. The runtime is named for its backing per the §Alternatives Considered rejection of a bare runtime package; a future sibling backing slot is left open. In-memory fixtures live `internal` to the test project per ADR-0027 D3 precedent.

**ADR-0031 D3 (Exposed contracts):** Three contracts — `IAuditLog` (interface), `IAuditQuery` (interface), `AuditEntry` (record). Records drop `I`; interfaces keep it.

**ADR-0031 D4 (Storage is Data-backed; append-only enforced at the interface):** `HoneyDrunk.Audit.Data` implements the store over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`. The append-only guarantee is enforced at the interface surface: `IAuditLog` exposes no update and no delete method. Audit data carries an audit-class retention policy distinct from observability retention; the retention value is sourced via the App Configuration pattern (ADR-0005), not hardcoded. **Phase-1 integrity is append-only-by-interface, not tamper-evident** (D9 / ADR-0030 D9) — this is the stated, accepted limitation and the standup must not document or describe the store as tamper-evident.

**ADR-0031 D5 (Managed identity):** The Audit Node runs under its own dedicated managed identity, distinct from Auth's and Operator's. **This scaffold is a library Node** — both packages are libraries, not deployables. The managed identity provisioning belongs with whichever packet first deploys an Audit-composing host. Cross-link the Azure provisioning walkthroughs at that future point. This packet's Human Prerequisites note the deferral.

**ADR-0031 D6 (First emitter Auth; Operator reconciled):** Auth is the first emitter — that work lands in packet 04 of this initiative against the `Abstractions` this scaffold ships. Operator reconciliation lands with Operator's own scaffolding initiative (Operator is not yet scaffolded as of 2026-05-20).

**ADR-0031 D7 (Telemetry direction):** `DataAuditLog` and `DataAuditQuery` emit operational telemetry via `ITelemetryActivityFactory` (Kernel). No Pulse package reference. Pulse consumes downstream — out of scope for this packet. **Audit *records* are not telemetry and never flow to Pulse.**

**ADR-0031 D8 (Contract-shape canary):** `api-compatibility.yml` is the canary. Scoped to `HoneyDrunk.Audit.Abstractions` since per D9 that is the only public-boundary package. All three contracts plus `AuditQueryFilter` are frozen from the first scaffold.

**ADR-0031 D9 (Downstream coupling):** Emitters and readers (Auth, Operator, future) compile only against `HoneyDrunk.Audit.Abstractions`. `Abstractions` is HoneyDrunk-dependency-free so consumers don't pull Kernel/Data/Vault transitively.

**ADR-0031 D10 (Kernel and Data as first-class):** Audit takes runtime dependencies on Kernel (for `IGridContext`, lifecycle, telemetry) and Data (for `IRepository`/`IUnitOfWork`). New edges in `catalogs/relationships.json` were landed by ADR-0030 packet 01.

**ADR-0031 D11 (Standup checklist):** This packet implements the full D11 first-PR checklist: solution layout, HoneyDrunk.Standards wiring, CI via Actions reused workflows, per-package README/CHANGELOG, LICENSE, Data-backed append-only store, the Node's managed identity *deferred* per the library-Node rationale above (D5), in-memory fixture, end-to-end smoke test.

**ADR-0030 D4 (Audit-class retention distinct from observability):** The `AuditRetentionPolicy` class lands in this scaffold; the value is sourced from `IConfigProvider`, default 365d, with a `::warning::` if unset. The retention enforcement loop is a Phase-2 concern; the *value* and the *read path* land here.

**ADR-0030 D5 (Contract relocation + Operator reconciliation):** `IAuditLog` and `AuditEntry` are authored in `HoneyDrunk.Audit.Abstractions` here (not relocated from existing Operator code, because Operator was never scaffolded — the relocation is a conceptual catalog-level move). Operator's eventual reconciliation is a separate packet against this `Abstractions`.

**ADR-0030 D9 (Phase-1 honest limitation):** Phase 1 is append-only-by-interface, NOT tamper-evident. The scaffold must not document or describe the store as tamper-evident. The repo `README.md` carries a `## Phase-1 honest limitation` section naming this explicitly.

**ADR-0026 (Grid Multi-Tenant Primitives — `TenantId` strong type, Accepted):** `IGridContext.TenantId` is the non-nullable `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` ULID record struct with a well-known `Internal` sentinel for non-multi-tenant operations. The Audit Node is queried for per-tenant compliance and forensic retrieval — re-introducing `string`-typed tenancy at the Audit contract surface would re-create exactly the consumer-side parse-and-default footgun ADR-0026 closed. This scaffold uses the `TenantId` strong type on `AuditEntry.TenantId` and `AuditQueryFilter.TenantId` (nullable on the filter for "no filter on tenant"), taking a single, well-bounded `HoneyDrunk.Kernel.Abstractions` reference on `HoneyDrunk.Audit.Abstractions.csproj`. The same argument applies to `CorrelationId`; at v0.1.0 the trade is to keep correlation `string` and promote to the Kernel strong type at v0.2.0 as one intentional contract-shape change (flagged as a follow-up).

**ADR-0027 (No speculative Testing package; cut later as non-breaking):** ADR-0031 D2 + §Alternatives Considered explicitly invoke this precedent. The in-memory `IAuditLog`/`IAuditQuery` fixture lives `internal` to `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/`; no `HoneyDrunk.Audit.Testing` package is shipped at v0.1.0.

**ADR-0009 (Dependabot stance, Accepted):** No `.github/dependabot.yml` is created. Dependency-scanning is delegated to `nightly-deps.yml` and `nightly-security.yml` calling `HoneyDrunk.Actions` reusable workflows.

**ADR-0005 (App Configuration via Vault, Accepted):** `HoneyDrunk.Audit.Data` reads the retention value through `IConfigProvider` from `HoneyDrunk.Vault`, not via direct App Configuration SDK calls. The composing host wires the App Configuration provider; this scaffold consumes the abstraction.

## Dependencies

- `packet:01` — the two new Audit invariants (downstream coupling + contract-shape canary) must exist in `constitution/invariants.md` before this packet's acceptance criteria reference them by number. Substitute the assigned `{N-coupling}` and `{N-canary}` numbers in this packet's source file in place pre-push under invariant 24's pre-filing carve-out, **after** packet 01 merges.
- `packet:02` — the `HoneyDrunk.Audit` GitHub repo must exist with branch protection, labels, OIDC, and the local working tree cloned. The scaffolding agent has nowhere to author into without packet 02 done.

## Labels

`feature`, `tier-2`, `audit`, `scaffold`, `adr-0031`

## Agent Handoff

**Objective:** Take the empty `HoneyDrunk.Audit` repo and ship version 0.1.0 with the three D3 contracts, Data-backed append-only `IAuditLog` writer + `IAuditQuery` reader, audit-class retention policy hook (App Config-sourced), in-memory fixture (internal to the test project), end-to-end smoke test proving round-trip, full CI, and the contract-shape canary scoped to `Abstractions`.

**Target:** HoneyDrunk.Audit, branch from `main`. (Packet 02 ensures `main` exists with `.gitignore`/`LICENSE` already in place.)

**Context:**
- Goal: Unblock HoneyDrunk.Auth (packet 04 of this initiative — first emitter) and any future Node that needs to record durable, attributable security or privileged-action events. Establish the contract-shape canary baseline that protects the surface from drift.
- Feature: ADR-0031 standup initiative — this is the substrate scaffold, the third packet of the initiative (after the two new Audit invariants `{N-coupling}` / `{N-canary}` in packet 01 and the repo creation in packet 02).
- ADRs: ADR-0031 (sole governing standup ADR); ADR-0030 (the driving capability/decision ADR — Phase-1 honest limitation, contract relocation, retention regime, Operator reconciliation framing all come from there); ADR-0005 (App Config-via-Vault pattern that D4 builds on); ADR-0009 (no Dependabot config file).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01 and 02 of this initiative must merge / be Done first.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `HoneyDrunk.Audit.Abstractions.csproj` must contain no `HoneyDrunk.*` PackageReference or ProjectReference. The `HoneyDrunk.Standards` reference uses `PrivateAssets="all"` so it does not propagate.
- **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Audit → Data → Kernel and Audit → Kernel are DAG-consistent. The rejected Kernel-hosted alternative (per ADR-0030) would have created a Kernel → Data → Kernel cycle; this Node placement specifically avoids that.
- **Invariant 5/6:** GridContext + CorrelationId + TenantId must be present in every scoped operation. — `DataAuditLog.AppendAsync` enriches the entry from `IGridContext` defensively when caller-passed fields are empty.
- **Invariant 9:** Vault is the only source of secrets. — The retention value is non-secret configuration, sourced via `IConfigProvider` from App Configuration per ADR-0005. No `ISecretStore` calls are needed in this scaffold.
- **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — Both `src/*` projects ship `README.md` and `CHANGELOG.md` in the same commit.
- **Invariant 13:** All public APIs have XML documentation. — Every public type/member in `HoneyDrunk.Audit.Abstractions` carries `///` summaries. StyleCop rules from `HoneyDrunk.Standards` enforce this.
- **Invariant 26:** Packets for .NET code work must include `## NuGet Dependencies`. `HoneyDrunk.Standards` must be on every new .NET project. — Confirmed in the NuGet Dependencies section above.
- **Invariant 27:** All projects in a solution share one version. — Both `src/*.csproj` ship at `0.1.0`. Test projects do not bump.
- **Invariant `{N-substrate}` (substrate-level audit-emission boundary, ADR-0030 packet 02):** Durable, attributable security and action events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. Phase-1 audit integrity is append-only-by-interface (`IAuditLog` exposes no update and no delete method); it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. — `IAuditLog` exposes exactly `AppendAsync`. The reflection test `AppendOnlyAtInterfaceTests` makes accidental future addition of an update/delete method a build failure. The README's "Phase-1 honest limitation" section names the not-tamper-evident reality.
- **Invariant `{N-coupling}`:** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`. Composition against `HoneyDrunk.Audit.Data` is a host-time concern. — Reinforced by keeping `Abstractions` near-minimal (one `HoneyDrunk.Kernel.Abstractions` reference for `TenantId`).
- **Invariant `{N-canary}`:** The HoneyDrunk.Audit Node CI must include a contract-shape canary for `IAuditLog`, `IAuditQuery`, and `AuditEntry`. Shape drift is a build failure unless paired with an intentional version bump. — `api-compatibility.yml` covers this by scoping to `HoneyDrunk.Audit.Abstractions`.
- **Canary on the scaffolding PR is expected to report `status: skipped`, not fail.** The shared `HoneyDrunk.Actions/.github/actions/api/check-compatibility/action.yml` emits `::warning::` and exits 0 with `status: skipped` when `git worktree add` against the baseline ref fails — which it always does on a first PR against a near-empty repo. Do not treat the skip as a misconfiguration and do not chase it. The scaffolding PR's merge establishes the `main` baseline; verification of the canary actually firing happens **post-merge** via a throwaway breaking-change PR that is reverted after observation.
- **Abstractions stance — exactly one `HoneyDrunk.*` reference, intentional.** `HoneyDrunk.Audit.Abstractions` ships with exactly one `HoneyDrunk.*` reference: `HoneyDrunk.Kernel.Abstractions`, for the `TenantId` strong type per ADR-0026. This is a **deliberate departure** from the ADR-0016 AI standup's zero-`HoneyDrunk` stance, justified by ADR-0026's per-tenant typing requirement and ADR-0031 D2's explicit allowance ("zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions"). Concretely: `AuditEntry.TenantId` and `AuditQueryFilter.TenantId` are the Kernel `TenantId` strong type (not `string`); `AuditEntry.CorrelationId` and `AuditQueryFilter.CorrelationId` stay `string` at v0.1.0 with a v0.2.0 promotion to the Kernel strong type flagged as a follow-up. Do NOT add any other `HoneyDrunk.*` reference to `HoneyDrunk.Audit.Abstractions.csproj` — not `HoneyDrunk.Kernel` (runtime), not `HoneyDrunk.Data*`, not `HoneyDrunk.Vault*`, not `HoneyDrunk.Pulse*`.
- **Records drop `I`; interfaces keep it.** `AuditEntry` is a record (no `I`). `AuditQueryFilter` is a record (no `I`). `IAuditLog` and `IAuditQuery` are interfaces (with `I`). Per Grid-wide naming rule (memory `project_naming_rule_records`).
- **Per ADR-0009, no `.github/dependabot.yml` is created.** Dependency-scanning is delegated to `nightly-deps.yml` and `nightly-security.yml` calling `HoneyDrunk.Actions` reusable workflows. GitHub Dependabot security alerts remain enabled at repo settings (org default — packet 02 confirms). No grouped or per-package `dependabot.yml` configuration file is committed to this repo.
- **Phase-1 store is NOT tamper-evident.** Per ADR-0030 D9 / ADR-0031 §Negative: hash-chain/WORM is deferred behind the boundary. The scaffold must not document, describe, or market the store as tamper-evident anywhere — in code comments, in package descriptions (`<Description>` in csproj), in READMEs, or in CHANGELOG entries. The repo `README.md` carries a `## Phase-1 honest limitation` section that names this explicitly. Do not soften, hedge, or marketize the limitation.
- **`IAuditLog` has exactly one method — `AppendAsync`.** No `UpdateAsync`, no `ReplaceAsync`, no `DeleteAsync`, no `RemoveAsync`, no `AppendBatchAsync` (the contract is single-entry append; batching is a future-version concern). The `AppendOnlyAtInterfaceTests` reflection test makes this a build-time gate.
- **`AuditEntry.Id` is writer-assigned at append time.** `DataAuditLog.AppendAsync` overwrites whatever value the caller passed in via the `AuditEntry.Id` field with a freshly-generated ULID. Callers may pass `string.Empty` (the in-memory fixture and the smoke test both do this). The XML docs on `AuditEntry.Id` reflect this convention.
- **`AuditEntry.OccurredAt` is caller-assigned and never overwritten.** The caller (Auth, Operator, future) sets `OccurredAt` at the moment the audited action occurred. `DataAuditLog` does not touch it.
- **No `HoneyDrunk.Pulse.*` reference anywhere in this repo.** Telemetry direction is one-way to Pulse per D7; Audit emits via Kernel's `ITelemetryActivityFactory`, and Pulse observes downstream. `HoneyDrunk.Audit.Data.csproj` must not contain a `HoneyDrunk.Pulse.*` PackageReference.
- **In-memory fixtures stay `internal` to the test project.** Per D2 + ADR-0027 D3: no `src/HoneyDrunk.Audit.Testing/` project at v0.1.0. The fixture files live under `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/` with `internal` visibility. Future cutting into a `HoneyDrunk.Audit.Testing` package is a non-breaking change when a third consumer needs it — out of scope here.

**Key Files:**
- `HoneyDrunk.Audit.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Audit.Abstractions/IAuditLog.cs`, `IAuditQuery.cs`, `AuditEntry.cs` (the record + the `AuditQueryFilter` record)
- `src/HoneyDrunk.Audit.Data/ServiceCollectionExtensions.cs`, `DataAuditLog.cs`, `DataAuditQuery.cs`, `AuditRetentionPolicy.cs`, `AuditTelemetry.cs`
- `tests/HoneyDrunk.Audit.Abstractions.Tests/ContractSurfaceTests.cs`, `AppendOnlyAtInterfaceTests.cs`
- `tests/HoneyDrunk.Audit.Data.Tests/Fixtures/InMemoryAuditLog.cs`, `Fixtures/InMemoryAuditQuery.cs`, `DataAuditLogTests.cs`, `DataAuditQueryTests.cs`, `SmokeTests.cs`
- `.github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml`
- `README.md`, `CHANGELOG.md` (repo-level), per-package `README.md` and `CHANGELOG.md`

**Contracts:**
- All three D3 contracts (`IAuditLog`, `IAuditQuery`, `AuditEntry`) plus the supporting `AuditQueryFilter` record authored fresh in this packet inside `HoneyDrunk.Audit.Abstractions`.
- The contract-shape canary establishes its baseline against this packet's commit. Future shape changes to any public type in `Abstractions` trigger the canary.
