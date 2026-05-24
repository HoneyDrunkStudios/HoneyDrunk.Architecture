---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Files
labels: ["feature", "tier-2", "files", "scaffold", "adr-0061"]
dependencies: ["packet:01", "packet:02", "packet:03"]
adrs: ["ADR-0061", "ADR-0026", "ADR-0027", "ADR-0042", "ADR-0009", "ADR-0005"]
accepts: ADR-0061
wave: 3
initiative: adr-0061-files-standup
node: honeydrunk-files
---

# Feature: Stand up the HoneyDrunk.Files repo — solution, four packages, contracts, CI, in-memory reference adapter

## Summary
Bring the empty `HoneyDrunk.Files` repo from zero to first-shippable state per ADR-0061 D3. Land the solution layout, the four package families (`HoneyDrunk.Files.Abstractions` + `HoneyDrunk.Files` + `HoneyDrunk.Files.InMemory` + `HoneyDrunk.Files.AzureBlob` placeholder), the D6 public surface inside `Abstractions` (5 interfaces + 6 supporting records), the runtime composition (DI registration, lifecycle hooks, telemetry, upload-session orchestrator, processing-pipeline dispatcher), the in-memory reference adapter for unit tests and the first integration scenarios, the standard CI pipeline (PR core + release + nightly deps + nightly security), and the contract-shape canary scoped to `HoneyDrunk.Files.Abstractions` per ADR-0061's D6 boundary and the public-surface stability obligation.

This is the unblocker for every PDR-driven app's first media-bearing packet (Hearth's journal photo upload being the named imminent driver), for Notify's optional `file_id`-resolved attachment path, for Communications' digest embeddings, and for any future Studios product surface needing avatar serving. After this packet merges and `v0.1.0` tags, those consumers can take a `HoneyDrunk.Files.Abstractions 0.1.0` PackageReference and start wiring their own work in parallel.

**Invariant numbers assigned.** Files constitutional invariants are `{N-domain-meaning}` (Files persists bytes + bytes-metadata, never domain meaning) and `{N-download-shape}` (every download is CDN-fronted public or short-lived SAS). These placeholders are substituted with the actual assigned numbers in place pre-push, after packet 02 of this initiative merges and lands the actual numeric assignments.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Files`

## Motivation
ADR-0061 D3 specifies the first-PR scaffold for HoneyDrunk.Files. Packet 03 created the GitHub repo and cloned the local tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Files/` (`.gitignore`, `LICENSE`, placeholder `README.md` only). Catalogs and Files invariants (`{N-domain-meaning}`, `{N-download-shape}`) are already in place. This packet ships the code and freezes a contract shape that supports both the test-time path (InMemory reference adapter) and the production path (AzureBlob placeholder ready for the first feature packet to fill in).

Until this packet ships: every consumer named in ADR-0061 has no `HoneyDrunk.Files.Abstractions 0.1.0` to reference; the contract-shape canary has no baseline; the Phase-1 "no Azure backing on day one" promise is unenforced; the first feature packet that activates Files has no anchor to land its `HoneyDrunk.Files.AzureBlob` implementation against. ADR-0061 D3 explicitly requires the D6 surface + InMemory round-trip proof + empty AzureBlob placeholder in the first commit so the canary has a coherent baseline.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Files/
├── HoneyDrunk.Files.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── LICENSE                          (placed by packet 03; verify content matches Grid LICENSE)
├── .editorconfig                    (from HoneyDrunk.Standards)
├── .gitignore                       (from packet 03; extend as needed)
├── .github/
│   └── workflows/
│       ├── pr-core.yml              (calls Actions/pr-core.yml)
│       ├── release.yml              (calls Actions/release.yml)
│       ├── nightly-deps.yml         (calls Actions/nightly-deps.yml)
│       ├── nightly-security.yml     (calls Actions/nightly-security.yml)
│       └── api-compatibility.yml    (calls Actions/job-api-compatibility.yml — D6 canary)
├── src/
│   ├── HoneyDrunk.Files.Abstractions/
│   │   ├── HoneyDrunk.Files.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IFileStore.cs                 (read/write/delete; backing-agnostic)
│   │   ├── IFileUploadSession.cs         (initiate → quota check → SAS → completion → pipeline)
│   │   ├── IFileMetadata.cs              (metadata-only queries)
│   │   ├── IFileProcessor.cs             (pluggable processing stage)
│   │   ├── IFileQuotaPolicy.cs           (per-tenant quota; UploadDenied at the limit)
│   │   ├── FileId.cs                     (strong-typed id, record-struct, drops I prefix)
│   │   ├── FileDescriptor.cs             (record — canonical metadata envelope)
│   │   ├── FilePurpose.cs                (enum — avatar/journal-media/attachment/voice-clip/system-asset)
│   │   ├── FileClassification.cs         (enum — Public/Internal/Confidential/Restricted)
│   │   ├── FileProcessingStatus.cs       (enum — Pending/ScanPending/Processing/Available/Failed/SoftDeleted)
│   │   ├── UploadRequest.cs              (record — consumer-supplied upload intent)
│   │   ├── UploadSession.cs              (record — Initiate result: file_id + signed_upload_url + expires_at)
│   │   ├── UploadDenied.cs               (record — quota/limit denial reason)
│   │   ├── SignedDownloadUrl.cs          (record — read URL: CDN-fronted-public OR short-lived SAS)
│   │   ├── QuotaSnapshot.cs              (record — per-tenant current usage)
│   │   └── RetentionPolicy.cs            (record — soft-delete window)
│   ├── HoneyDrunk.Files/
│   │   ├── HoneyDrunk.Files.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs        (AddHoneyDrunkFiles)
│   │   ├── DefaultFileUploadSession.cs           (orchestrator — quota check → file_id → SAS via IFileStore)
│   │   ├── DefaultFileMetadata.cs                (composed over IFileStore metadata methods)
│   │   ├── ProcessingPipelineDispatcher.cs       (stage queue, idempotency-by-file_id)
│   │   ├── DefaultFileQuotaPolicy.cs             (reads QuotaSnapshot via IConfigProvider; tier-defaults)
│   │   └── FilesTelemetry.cs                     (operational telemetry via ITelemetryActivityFactory)
│   ├── HoneyDrunk.Files.InMemory/
│   │   ├── HoneyDrunk.Files.InMemory.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── InMemoryFileStore.cs                  (IFileStore impl — Dictionary<FileId, (bytes, descriptor)>)
│   │   ├── InMemorySasMinter.cs                  (deterministic SAS-token analog for tests)
│   │   └── PassThroughVirusScan.cs               (no-op IFileProcessor scan stage for tests)
│   └── HoneyDrunk.Files.AzureBlob/
│       ├── HoneyDrunk.Files.AzureBlob.csproj
│       ├── README.md                              (states explicitly: "Placeholder. No implementation on day one. The Azure adapter lands with the first feature packet that activates Files.")
│       └── CHANGELOG.md                           (## [0.1.0] entry — "Placeholder project created. No implementation; see README.")
└── tests/
    ├── HoneyDrunk.Files.Abstractions.Tests/
    │   ├── HoneyDrunk.Files.Abstractions.Tests.csproj
    │   ├── ContractSurfaceTests.cs               (compile-only + shape assertions on Abstractions public surface)
    │   ├── DomainMeaningBoundaryTests.cs         (reflection check: FileDescriptor has no domain-meaning fields beyond the allow-list)
    │   └── DownloadShapeTests.cs                 (reflection check: IFileStore.GetDownloadUrl returns SignedDownloadUrl, never raw string)
    ├── HoneyDrunk.Files.Tests.Unit/
    │   ├── HoneyDrunk.Files.Tests.Unit.csproj
    │   ├── DefaultFileUploadSessionTests.cs      (quota-check, file_id assignment, SAS-issuance flow)
    │   ├── DefaultFileQuotaPolicyTests.cs        (tier-defaults, UploadDenied behavior)
    │   ├── ProcessingPipelineDispatcherTests.cs  (stage queue + idempotency by file_id)
    │   └── SmokeTests.cs                         (end-to-end: Initiate → upload via InMemoryFileStore → GetDownloadUrl → bytes round-trip)
    └── HoneyDrunk.Files.Tests.Canary/
        ├── HoneyDrunk.Files.Tests.Canary.csproj
        ├── KernelCanaryTests.cs                  (IGridContext flows through every operation; TenantId propagation)
        └── AbstractionsSurfaceCanaryTests.cs     (boundary verification — Abstractions has zero HoneyDrunk runtime deps)
```

**Fixtures live in `HoneyDrunk.Files.InMemory`** (not `internal` to a test project) because — unlike Audit's pattern (ADR-0027 D3 / ADR-0031 D2: small known consumer set, fixture stays `internal`) — Files' first-named consumer (PDR-0005 Hearth) is an external repo that will need to mock the `IFileStore` surface in its own unit tests from the first media-bearing packet. Cutting `HoneyDrunk.Files.InMemory` as a shipped reference adapter from v0.1.0 is the right call. Compare ADR-0017 D2 (Capabilities ships `HoneyDrunk.Capabilities.Testing` at standup for the same reason) vs. ADR-0027 / ADR-0031 (Communications and Audit keep fixtures `internal` — both have small known consumer sets and ship Testing later). Files is the Capabilities pattern: ship the InMemory adapter at standup because downstream consumers are app Nodes that need test infrastructure from day one.

### Solution

`HoneyDrunk.Files.slnx` references all four `src/*` projects and all three `tests/*` projects. Solution-level `Directory.Build.props` sets:

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
    <PackageProjectUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Files</PackageProjectUrl>
    <RepositoryUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Files</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
    <PublishRepositoryUrl>true</PublishRepositoryUrl>
    <IncludeSymbols>true</IncludeSymbols>
    <SymbolPackageFormat>snupkg</SymbolPackageFormat>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
  </PropertyGroup>
</Project>
```

Per invariant 27 (all projects in a solution share one version and move together), all four `src/*.csproj` files carry the same `Version` (0.1.0 for this initial release). Test projects are excluded from version-bump scope.

### Contract details — `HoneyDrunk.Files.Abstractions`

Records drop the `I` prefix per the Grid-wide naming rule (memory `project_naming_rule_records`); interfaces keep it.

**Single `HoneyDrunk.*` reference: `HoneyDrunk.Kernel.Abstractions`** (for `TenantId` strong type per ADR-0026, `CorrelationId` if needed, and ambient `IGridContext` context types). This matches the Audit standup precedent (ADR-0031 D2) and the AI standup precedent (ADR-0016 D2). Every downstream consumer already has Kernel.Abstractions in its closure, so no new transitively-pinned package.

**Strong-typed `FileId`** as a `readonly record struct` matching the Kernel `TenantId` / `CorrelationId` template:

```csharp
namespace HoneyDrunk.Files.Abstractions;

/// <summary>
/// Strong-typed file identifier. ULID-shaped. Assigned writer-side by IFileUploadSession.Initiate.
/// </summary>
public readonly record struct FileId(string Value)
{
    public static FileId New() => new(System.Guid.NewGuid().ToString("N"));
    public static FileId Empty { get; } = new(string.Empty);
    public bool IsEmpty => string.IsNullOrEmpty(Value);
    public override string ToString() => Value;
}
```

**Enums.** `FilePurpose`, `FileClassification`, `FileProcessingStatus` — value types, drop the `I`:

```csharp
namespace HoneyDrunk.Files.Abstractions;

public enum FilePurpose
{
    Avatar = 0,
    JournalMedia = 1,
    Attachment = 2,
    VoiceClip = 3,
    SystemAsset = 4,
}

public enum FileClassification
{
    Public = 0,
    Internal = 1,
    Confidential = 2,
    Restricted = 3,
}

public enum FileProcessingStatus
{
    Pending = 0,
    ScanPending = 1,
    Processing = 2,
    Available = 3,
    Failed = 4,
    SoftDeleted = 5,
}
```

**`FileDescriptor`** is the canonical metadata envelope. Field list is the byte-metadata allow-list — adding a field that encodes domain meaning is a constitutional invariant violation per packet 02:

```csharp
namespace HoneyDrunk.Files.Abstractions;

using HoneyDrunk.Kernel.Abstractions.Identity;

/// <summary>
/// Canonical bytes-metadata envelope. Files persists this; the bytes themselves live behind IFileStore.
/// </summary>
/// <param name="Id">Strong-typed file identifier. ULID-shaped. Assigned by IFileUploadSession.Initiate.</param>
/// <param name="TenantId">Tenant scope of the file. Uses the Kernel strong type per ADR-0026; use TenantId.Internal for first-party Grid blobs.</param>
/// <param name="Purpose">Files-defined enumeration — avatar / journal-media / attachment / voice-clip / system-asset.</param>
/// <param name="ContentType">MIME content-type pinned at SAS issuance time.</param>
/// <param name="SizeBytes">Stored byte size. Set at upload-completion time.</param>
/// <param name="Classification">Classification tier per the data-classification rubric.</param>
/// <param name="UploadedAt">UTC timestamp the upload completed (not when initiated).</param>
/// <param name="ProcessingStatus">Current pipeline state.</param>
/// <param name="SoftDeletedAt">Non-null if the file is in the soft-delete window. Hard-deleted files are removed from metadata entirely.</param>
/// <param name="IsPublic">True for CDN-fronted public assets; false for private (short-lived SAS) assets.</param>
public sealed record FileDescriptor(
    FileId Id,
    TenantId TenantId,
    FilePurpose Purpose,
    string ContentType,
    long SizeBytes,
    FileClassification Classification,
    DateTimeOffset UploadedAt,
    FileProcessingStatus ProcessingStatus,
    DateTimeOffset? SoftDeletedAt,
    bool IsPublic);
```

**`UploadRequest`**, **`UploadSession`**, **`UploadDenied`**, **`SignedDownloadUrl`**, **`QuotaSnapshot`**, **`RetentionPolicy`** — all records, all drop `I`:

```csharp
namespace HoneyDrunk.Files.Abstractions;

using HoneyDrunk.Kernel.Abstractions.Identity;

public sealed record UploadRequest(
    TenantId TenantId,
    FilePurpose Purpose,
    string ContentType,
    long DeclaredSizeBytes,
    FileClassification DeclaredClassification,
    string? IdempotencyKey = null);

public sealed record UploadSession(
    FileId Id,
    string SignedUploadUrl,
    DateTimeOffset ExpiresAt,
    string CompletionCallbackUrl);

public sealed record UploadDenied(
    FilePurpose Purpose,
    string ReasonCode,    // "quota-bytes-exceeded" | "quota-files-exceeded" | "single-file-cap-exceeded" | "tenant-suspended" | "tenant-offboarding"
    string Message);

public sealed record SignedDownloadUrl(
    string Url,
    DateTimeOffset? ExpiresAt,   // null for CDN-fronted public URLs
    bool IsPublic);

public sealed record QuotaSnapshot(
    TenantId TenantId,
    long BytesUsed,
    int FileCount,
    DateTimeOffset LastRefreshed);

public sealed record RetentionPolicy(
    int SoftDeleteWindowDays);
```

**Interfaces.** Five total:

```csharp
namespace HoneyDrunk.Files.Abstractions;

/// <summary>
/// Read/write/delete operations against bytes + metadata. Backing-agnostic.
/// </summary>
public interface IFileStore
{
    /// <summary>
    /// Look up a file by id. Returns null if the file does not exist or is in soft-delete state
    /// and the caller is not a tnt_internal-privileged principal.
    /// </summary>
    Task<FileDescriptor?> GetAsync(FileId fileId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Issue a download URL for a file. The result is either a CDN-fronted public URL
    /// (for public assets) or a short-lived SAS (for private assets). The Files Node
    /// never returns a long-lived storage-account-shared-key URL.
    /// </summary>
    Task<SignedDownloadUrl> GetDownloadUrlAsync(FileId fileId, TimeSpan? ttl = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// Soft-delete a file. Hard-delete happens via the offboarding / erasure cascade or
    /// the retention-elapsed sweep — never directly through this method.
    /// </summary>
    Task DeleteAsync(FileId fileId, CancellationToken cancellationToken = default);
}

public interface IFileUploadSession
{
    /// <summary>
    /// Initiate an upload. Checks IFileQuotaPolicy; if any limit is exceeded, returns null
    /// and emits an UploadDenied audit event. Otherwise allocates a FileId, mints a write-scoped
    /// SAS, persists a pending UploadSession record, and returns the session to the consumer.
    /// </summary>
    Task<UploadSession?> InitiateAsync(UploadRequest request, CancellationToken cancellationToken = default);
}

public interface IFileMetadata
{
    /// <summary>
    /// Query metadata for a file without reading the bytes.
    /// </summary>
    Task<FileDescriptor?> GetAsync(FileId fileId, CancellationToken cancellationToken = default);

    /// <summary>
    /// List files for a tenant under a purpose, time-bounded. Soft-deleted files are excluded
    /// unless the caller is a tnt_internal-privileged principal.
    /// </summary>
    Task<IReadOnlyList<FileDescriptor>> ListAsync(
        TenantId tenantId,
        FilePurpose purpose,
        DateTimeOffset since,
        DateTimeOffset until,
        int? limit = null,
        CancellationToken cancellationToken = default);
}

public interface IFileProcessor
{
    /// <summary>
    /// Stage name for telemetry and idempotency keying. Unique within the pipeline.
    /// </summary>
    string StageName { get; }

    /// <summary>
    /// Run this stage against the given file. Idempotent by file_id per ADR-0042.
    /// </summary>
    Task ProcessAsync(FileId fileId, CancellationToken cancellationToken = default);
}

public interface IFileQuotaPolicy
{
    /// <summary>
    /// Check whether the requested upload fits within the tenant's quota.
    /// Returns null if allowed; an UploadDenied if the limit is exceeded.
    /// </summary>
    Task<UploadDenied?> CheckAsync(UploadRequest request, CancellationToken cancellationToken = default);

    /// <summary>
    /// Current quota snapshot for a tenant.
    /// </summary>
    Task<QuotaSnapshot> GetSnapshotAsync(TenantId tenantId, CancellationToken cancellationToken = default);
}
```

### Runtime details — `HoneyDrunk.Files`

`HoneyDrunk.Files` references:

- `HoneyDrunk.Files.Abstractions` (project reference)
- `HoneyDrunk.Kernel.Abstractions` (for `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext` — interfaces, contract consumption per invariant 2)
- `HoneyDrunk.Data.Abstractions` (for `IRepository`, `IUnitOfWork` — `FileDescriptor` persistence)
- `HoneyDrunk.Vault` (for `IConfigProvider` — quota tier defaults, retention window, scan integration toggles. Note: `IConfigProvider` namespace is `HoneyDrunk.Vault.Abstractions` but ships from the `HoneyDrunk.Vault` package since Vault does not ship a separate `.Abstractions` NuGet)
- `Microsoft.Extensions.DependencyInjection.Abstractions`
- `Microsoft.Extensions.Hosting.Abstractions`
- `Microsoft.Extensions.Logging.Abstractions`
- `Microsoft.Extensions.Options.ConfigurationExtensions` (bind options from `IConfigProvider`)

**`DefaultFileUploadSession`** — implements `IFileUploadSession.InitiateAsync`:

- Resolves the upload request's TenantId via `IGridContextAccessor.GridContext` if the request's TenantId is `default`.
- Calls `IFileQuotaPolicy.CheckAsync(request)`. If a denial is returned, returns `null` and emits a `FileUploadDenied` audit event (via `IAuditLog`) for quota-exceeded outcomes.
- Allocates a fresh `FileId` (`FileId.New()`).
- Calls `IFileStore`-side SAS minting (the backing adapter exposes a `MintWriteSasAsync` extension on its concrete implementation; the runtime composes against the adapter, not the interface). For v0.1.0 with the InMemory adapter, this is `InMemorySasMinter` which returns a deterministic synthetic URL.
- Persists a pending `UploadSession` record via `IRepository<UploadSession>.AddAsync` + `IUnitOfWork.SaveChangesAsync`. Idempotency key is `{tenant_id}:{purpose}:{client-provided-idempotency-key}` per ADR-0042; re-initiating the same logical upload returns the same `FileId` if the session is still pending.
- Returns the `UploadSession` to the consumer.
- Emits `files.upload.initiated` operational telemetry via `ITelemetryActivityFactory`.

**`DefaultFileMetadata`** — composed over `IFileStore` and `IRepository<FileDescriptor>`:

- `GetAsync(FileId)`: reads `FileDescriptor` via `IReadOnlyRepository<FileDescriptor>.FindByIdAsync`. Enforces `TenantId` match against `IGridContext.TenantId` (unless the caller is `tnt_internal`).
- `ListAsync(TenantId, FilePurpose, since, until, limit)`: composes the filter as a single `Expression<Func<FileDescriptor, bool>>` and calls `FindAsync`. Time ordering and `Limit` happen post-fetch, in memory (same Phase-1 pattern as `DataAuditQuery` in ADR-0031 packet 03). Limit default 100, cap 1000.

**`ProcessingPipelineDispatcher`** — dispatches `IFileProcessor` stages in registered order. Idempotency-by-`file_id` is enforced: if a stage has already run for a given file_id, it is skipped. Stage execution is async and runs off the upload-completion event. v0.1.0 ships:

- A `PassThroughVirusScan` stage (in `HoneyDrunk.Files.InMemory`) used by tests.
- No production-toolchain stages (ImageSharp / FFmpeg / Defender for Storage integration) — those land with the first feature packet per ADR-0061 D9.

**`DefaultFileQuotaPolicy`** — reads tier defaults from `IConfigProvider` (key prefix `files:quota:`). Cached per-tenant in a `QuotaSnapshot` record. Tier-default seed values per ADR-0061 D10 (`tnt_internal` 1 TB / 1M files / 1 GB single; Trialing 500 MB / 1000 / 25 MB; etc.) live in code as static seed defaults that the production-time deployable host overrides via App Configuration. For v0.1.0 (no Azure backing), the policy reads `IConfigProvider` and falls back to the in-code seeds with a `::warning::` log.

**`FilesTelemetry`** — Convenience helpers wrapping `ITelemetryActivityFactory`. GridContext propagation onto telemetry activities lives here. **Telemetry direction is one-way to Pulse** per ADR-0061 D6 — `HoneyDrunk.Files.csproj` does not reference any `HoneyDrunk.Pulse.*` package.

**Host registration.** `IConfigProvider`, `IRepository`, `IUnitOfWork`, `IAuditLog`, `IFileStore`, `IFileProcessor` (zero or more) are host-wired. `AddHoneyDrunkFiles()` throws `InvalidOperationException` at first resolution if any required dependency is missing.

```csharp
namespace HoneyDrunk.Files;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddHoneyDrunkFiles(this IServiceCollection services)
    {
        services.AddSingleton<IFileUploadSession, DefaultFileUploadSession>();
        services.AddSingleton<IFileMetadata, DefaultFileMetadata>();
        services.AddSingleton<IFileQuotaPolicy, DefaultFileQuotaPolicy>();
        services.AddSingleton<ProcessingPipelineDispatcher>();
        services.AddSingleton<FilesTelemetry>();
        return services;
    }
}
```

### Lifetime story — Singletons over scoped GridContext access via `IGridContextAccessor`

Singletons; resolve `IGridContext` via `IGridContextAccessor.GridContext` (ambient per-call), not via ctor injection. Resolve scoped `IRepository` / `IUnitOfWork` fresh per call via `IServiceScopeFactory.CreateAsyncScope()` (same pattern as Audit's `DataAuditLog` per ADR-0031 packet 03). This matches the lifetime story expected by every Singleton-emitter consumer (Hearth's media-upload pipeline will be Singleton-shaped).

### `HoneyDrunk.Files.InMemory` — reference adapter

Three classes:

- **`InMemoryFileStore : IFileStore`** — backed by `ConcurrentDictionary<FileId, (byte[] bytes, FileDescriptor descriptor)>`. `GetAsync` returns the descriptor; `GetDownloadUrlAsync` returns a `SignedDownloadUrl` with `Url = $"inmem://{fileId}"`, `ExpiresAt = DateTimeOffset.UtcNow.AddMinutes(15)`, `IsPublic = descriptor.IsPublic`. `DeleteAsync` marks `SoftDeletedAt = DateTimeOffset.UtcNow`. Exposes `internal MintWriteSasAsync(FileId, contentType, expiresAt)` extension consumed by `DefaultFileUploadSession` test composition.
- **`InMemorySasMinter`** — deterministic synthetic SAS minter. For a given `FileId`/`contentType`/`expiresAt`, returns `$"inmem://write/{fileId}?ct={contentType}&exp={expiresAt:O}"`. Used to make `DefaultFileUploadSession` testable without a real Storage account.
- **`PassThroughVirusScan : IFileProcessor`** — `StageName = "virus-scan"`; `ProcessAsync` is a no-op that returns immediately. The default scan in tests.

The `HoneyDrunk.Files.InMemory.csproj` references:

- `HoneyDrunk.Files.Abstractions` (project)
- `HoneyDrunk.Standards` (`PrivateAssets="all"`)
- No backing-cloud SDK references.

### `HoneyDrunk.Files.AzureBlob` — placeholder

The `.csproj` is set up identically to the other `src/` projects (HoneyDrunk.Standards reference, Version 0.1.0, target framework net10.0, package metadata fields). But there is **no implementation source file**. A single sentinel file `Placeholder.cs` contains:

```csharp
// Placeholder. No implementation on day one — see README and ADR-0061 D3.
//
// The Azure adapter lands with the first feature packet that activates Files
// (likely PDR-0005 Hearth's first media-bearing packet). At that time this file
// is replaced with the real AzureBlobFileStore implementation, the
// Azure.Storage.Blobs package reference is added, and the package version bumps
// from 0.1.0 (empty placeholder) to 0.2.0 (first real implementation).
namespace HoneyDrunk.Files.AzureBlob;

internal static class Placeholder
{
}
```

`HoneyDrunk.Files.AzureBlob/README.md` carries a one-line description:

> **Placeholder.** No implementation on day one. The Azure adapter lands with the first feature packet that activates Files. See the repo-root README and ADR-0061 D3.

`HoneyDrunk.Files.AzureBlob/CHANGELOG.md` carries a single `## [0.1.0] - YYYY-MM-DD` entry: `Placeholder project created. No implementation; see README.`

### Smoke test — `tests/HoneyDrunk.Files.Tests.Unit/SmokeTests.cs`

`UploadInitiate_ThroughIFileUploadSession_RoundTrips_ToBytesViaIFileStore`:

1. Instantiate `InMemoryFileStore` + `InMemorySasMinter`.
2. Compose `DefaultFileUploadSession` over them with a permissive `IFileQuotaPolicy` and a test `IGridContextAccessor` populated with `TenantId.Internal`.
3. Call `InitiateAsync(new UploadRequest(TenantId.Internal, FilePurpose.JournalMedia, "image/jpeg", 1024, FileClassification.Restricted))`.
4. Assert `UploadSession` is returned, `Id.IsEmpty == false`, `SignedUploadUrl` starts with `inmem://write/`.
5. Simulate the client upload by writing bytes directly to `InMemoryFileStore` (test-only seam).
6. Call `IFileStore.GetDownloadUrlAsync(uploadSession.Id, TimeSpan.FromMinutes(15))` and assert the returned `SignedDownloadUrl.Url` starts with `inmem://`, `ExpiresAt` is non-null and ~15 minutes ahead, `IsPublic == false` (the upload was Restricted-classification, not public).

A second smoke test `PublicAvatar_GetsCdnUrl_NotSas`:

1. Same setup but upload a `FilePurpose.Avatar` with `is_public: true` (set via the descriptor's `IsPublic` field at upload-completion).
2. Call `GetDownloadUrlAsync` and assert `SignedDownloadUrl.IsPublic == true`, `ExpiresAt == null`.

### Constitutional-invariant enforcement tests

**`tests/HoneyDrunk.Files.Abstractions.Tests/DomainMeaningBoundaryTests.cs`** — reflection asserts `FileDescriptor` has exactly the byte-metadata allow-list members: `Id`, `TenantId`, `Purpose`, `ContentType`, `SizeBytes`, `Classification`, `UploadedAt`, `ProcessingStatus`, `SoftDeletedAt`, `IsPublic`. Any additional member (e.g., `ContentDescription`, `AssetTitle`, `Caption`, `OwnerName`) fails the test — that is the constitutional invariant `{N-domain-meaning}` defense at the type-shape level. Build-time defense against accidental future domain-meaning addition.

**`tests/HoneyDrunk.Files.Abstractions.Tests/DownloadShapeTests.cs`** — reflection asserts `IFileStore.GetDownloadUrlAsync` returns `Task<SignedDownloadUrl>`, never `Task<string>`. The `SignedDownloadUrl` envelope is the only valid return shape; a raw URL string would let callers fabricate long-lived URLs. This is the constitutional invariant `{N-download-shape}` defense at the type-shape level.

### CI workflows

All five workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows.

- **`pr-core.yml`** — calls `pr-core.yml@main`, `dotnet-version: '10.0.x'`.

- **`api-compatibility.yml`** (D6 canary):

```yaml
name: API Compatibility (Abstractions)
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/HoneyDrunk.Files.Abstractions/**'
      - 'Directory.Build.props'
jobs:
  abstractions-shape:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main
    with:
      project-path: src/HoneyDrunk.Files.Abstractions/HoneyDrunk.Files.Abstractions.csproj
```

Path filter includes `Directory.Build.props` so version-bumped contract-shape changes don't merge without the canary running. Whole-assembly diff covers all 5 interfaces + all 6 records + `FileId`.

- **`release.yml`** — `on: push: tags: [v*.*.*]`, calls `release.yml@main` with `enable-nuget-publish: true` and:

```yaml
    secrets:
      nuget-api-key: ${{ secrets.NUGET_API_KEY }}
```

**No `secrets: inherit`** — the caller passes only the named secret `release.yml` declares. Tags are human-pushed per invariant 27. Packet 03 must seed `NUGET_API_KEY` (org-level secret already exists for other repos; verify it's bound to `HoneyDrunk.Files`).

- **`nightly-deps.yml` / `nightly-security.yml`** — thin callers; copy `with:`/`secrets:` blocks verbatim from `HoneyDrunk.Audit` or `HoneyDrunk.Vault`.

### `HoneyDrunk.Standards` wiring

Each `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets="all"` per invariant 26:

```xml
<ItemGroup>
  <PackageReference Include="HoneyDrunk.Standards" Version="*" PrivateAssets="all" />
</ItemGroup>
```

This pulls in the StyleCop ruleset, `.editorconfig`, and analyzer suite that every Grid repo uses.

### Documentation

- **Repo `README.md`** — purpose statement, package matrix, link to active-work tracker, plus a `## For downstream consumers — minimal wiring` section showing copy-pasteable `services.AddVault().AddData(...).AddHoneyDrunkFiles().AddSingleton<IFileStore, InMemoryFileStore>()` (the test composition) and a follow-up sentence noting the production composition swaps `InMemoryFileStore` for `AzureBlobFileStore` from `HoneyDrunk.Files.AzureBlob` when that adapter lands. Also a **`## Phase-1 honest limitation`** section naming three intentional gaps:
  1. The `HoneyDrunk.Files.AzureBlob` package is a **placeholder at v0.1.0** — no implementation source on day one. The Azure adapter lands with the first feature packet activating Files (likely PDR-0005 Hearth).
  2. The processing pipeline ships only `PassThroughVirusScan` at v0.1.0. Real image processing (ImageSharp/Magick.NET), audio normalization (FFmpeg/NAudio), EXIF stripping, and malware scan (Defender for Storage integration) all land with the first feature packet.
  3. No Azure resources are provisioned at standup — no Storage Account, no CDN profile, no Front Door endpoint, no Defender for Storage subscription, no Key Vault. Provisioning lands with the first feature packet.

  Per memory `feedback_no_adr_in_docs`, the README does not cite ADR numbers in narrative paragraphs.

- **Repo `CHANGELOG.md`** — `## [0.1.0] - YYYY-MM-DD` entry. No `## Unreleased` at commit time (per memory `feedback_no_unreleased_commits`).
- **Per-package `README.md`** + **`CHANGELOG.md`** — required by invariant 12 for all four new packages. `HoneyDrunk.Files.AzureBlob`'s README explicitly names itself as a placeholder.

## Affected Files
Entire repo is created from this packet. Notable new files:

- `HoneyDrunk.Files.slnx`, `Directory.Build.props`, `README.md`, `CHANGELOG.md`, `.editorconfig`
- `src/HoneyDrunk.Files.Abstractions/` — `.csproj`, 5 interfaces + 6 records + 3 enums + `FileId` strong-typed id, `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.Files/` — `.csproj`, `ServiceCollectionExtensions.cs`, `DefaultFileUploadSession.cs`, `DefaultFileMetadata.cs`, `ProcessingPipelineDispatcher.cs`, `DefaultFileQuotaPolicy.cs`, `FilesTelemetry.cs`, `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.Files.InMemory/` — `.csproj`, `InMemoryFileStore.cs`, `InMemorySasMinter.cs`, `PassThroughVirusScan.cs`, `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.Files.AzureBlob/` — `.csproj`, `Placeholder.cs`, `README.md` (placeholder notice), `CHANGELOG.md` (placeholder entry only)
- `tests/HoneyDrunk.Files.Abstractions.Tests/` — `.csproj`, `ContractSurfaceTests.cs`, `DomainMeaningBoundaryTests.cs`, `DownloadShapeTests.cs`
- `tests/HoneyDrunk.Files.Tests.Unit/` — `.csproj`, `DefaultFileUploadSessionTests.cs`, `DefaultFileQuotaPolicyTests.cs`, `ProcessingPipelineDispatcherTests.cs`, `SmokeTests.cs`
- `tests/HoneyDrunk.Files.Tests.Canary/` — `.csproj`, `KernelCanaryTests.cs`, `AbstractionsSurfaceCanaryTests.cs`
- `.github/workflows/` — 5 workflow files (`pr-core.yml`, `release.yml`, `nightly-deps.yml`, `nightly-security.yml`, `api-compatibility.yml`)

## NuGet Dependencies

Every new `.csproj` lists `HoneyDrunk.Standards` (`PrivateAssets="all"`) per invariant 26.

### `HoneyDrunk.Files.Abstractions.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `TenantId` strong type, `IGridContext` accessor types (ADR-0026). Deliberate departure from zero-`HoneyDrunk` stance per ADR-0061 D3 — single Kernel-Abstractions reference is the same pattern Audit and AI took. |

### `HoneyDrunk.Files.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `ITelemetryActivityFactory`, `IGridContext`, `IOperationContext`, `TenantId` |
| `HoneyDrunk.Data.Abstractions` | For `IRepository`, `IUnitOfWork` (FileDescriptor + UploadSession persistence) |
| `HoneyDrunk.Vault` | For `IConfigProvider` (quota tier defaults, retention window, scan toggles via App Configuration). Interface namespace is `Vault.Abstractions`; Vault ships one package only. |
| `HoneyDrunk.Audit.Abstractions` | For `IAuditLog` (Restricted-tier upload events, deletion-cascade events per ADR-0061 D12) |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | DI helpers |
| `Microsoft.Extensions.Hosting.Abstractions` | Startup hook |
| `Microsoft.Extensions.Logging.Abstractions` | Logger contracts |
| `Microsoft.Extensions.Options.ConfigurationExtensions` | Bind options |

Project reference: `HoneyDrunk.Files.Abstractions`.

### `HoneyDrunk.Files.InMemory.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

Project reference: `HoneyDrunk.Files.Abstractions`. No cloud SDK references.

### `HoneyDrunk.Files.AzureBlob.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |

Project reference: `HoneyDrunk.Files.Abstractions`. **No `Azure.Storage.Blobs` reference at v0.1.0** — the placeholder is intentional. The first feature packet activating Files adds the Azure SDK reference along with the real implementation.

### Test projects

`HoneyDrunk.Standards` (`PrivateAssets="all"`), `Microsoft.NET.Test.Sdk`, `xunit`, `xunit.runner.visualstudio`, `Microsoft.Extensions.DependencyInjection`, `FluentAssertions`. Project refs:

- `Abstractions.Tests` → `Abstractions`
- `Tests.Unit` → `Abstractions`, runtime, `InMemory`
- `Tests.Canary` → `Abstractions`, `Kernel.Abstractions` (canary verifies the Abstractions boundary surface)

## Boundary Check

- [x] All work inside `HoneyDrunk.Files`. No other Grid repos edited.
- [x] `HoneyDrunk.Files.Abstractions` carries exactly ONE `HoneyDrunk.*` ref: `HoneyDrunk.Kernel.Abstractions` (for `TenantId` and ambient context types). No Data/Vault/Audit/Pulse/Kernel-runtime refs.
- [x] `HoneyDrunk.Files` references `Abstractions` (project), `Kernel.Abstractions`, `Data.Abstractions`, `Vault`, `Audit.Abstractions`. No `HoneyDrunk.Pulse.*` (telemetry is one-way per ADR-0061 D6).
- [x] `HoneyDrunk.Files.InMemory` references `Abstractions` (project) only. No cloud SDK references.
- [x] `HoneyDrunk.Files.AzureBlob` references `Abstractions` (project) only at v0.1.0. **No `Azure.Storage.Blobs` reference** until the first feature packet activates the real implementation.
- [x] No secrets in code; storage account credentials, SAS signing keys, and quota tier-default values are all sourced via `IConfigProvider`/`ISecretStore` at runtime (and at v0.1.0 none of those values are actually provisioned in Azure — the InMemory adapter doesn't need them).
- [x] Records/enums drop `I` (`FileDescriptor`, `UploadRequest`, `UploadSession`, `UploadDenied`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy`, `FilePurpose`, `FileClassification`, `FileProcessingStatus`, `FileId`); interfaces keep it (`IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy`).
- [x] `FileDescriptor` carries exactly the byte-metadata allow-list — no domain-meaning fields. `DomainMeaningBoundaryTests` enforces this at the type-shape level.
- [x] `IFileStore.GetDownloadUrlAsync` returns `Task<SignedDownloadUrl>`, never `Task<string>`. `DownloadShapeTests` enforces this at the type-shape level.
- [x] Scaffold does NOT include: real Azure Blob Storage adapter (deferred to first feature packet), real processing toolchain (deferred), real malware scan integration (deferred), Azure resource provisioning (deferred), Hearth/Lately/Currents/Curiosities consumer wiring (deferred to each app's own first media-bearing packet).
- [x] The placeholder `HoneyDrunk.Files.AzureBlob` is **honestly named** in its README and `.csproj` description — no "tamper-evident", no "production-ready", no claim of any Azure functionality at v0.1.0.

## Acceptance Criteria

- [ ] `HoneyDrunk.Files.slnx` builds clean from a fresh clone via `dotnet build` with no warnings (warnings-as-errors).
- [ ] D6 public surface present in `HoneyDrunk.Files.Abstractions` with XML documentation per invariant 13: `IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy` (interfaces, keep `I` prefix); `FileId` (record-struct, drops `I`), `FileDescriptor`, `UploadRequest`, `UploadSession`, `UploadDenied`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy` (records, drop `I`); `FilePurpose`, `FileClassification`, `FileProcessingStatus` (enums, drop `I`).
- [ ] `HoneyDrunk.Files.Abstractions` has exactly ONE `HoneyDrunk.*` PackageReference: `HoneyDrunk.Kernel.Abstractions` (for `TenantId` strong type and ambient context types). Constitutional invariants 1 (Abstractions zero-dependency) and `{N-domain-meaning}` (Files persists bytes + bytes-metadata, never domain meaning) are satisfied — the single Kernel-Abstractions reference is the same intentional, ADR-permitted exception Audit and AI both took.
- [ ] `IFileStore.GetDownloadUrlAsync` returns `Task<SignedDownloadUrl>`, never `Task<string>`. The reflection test `DownloadShapeTests.cs` asserts this and passes. Constitutional invariant `{N-download-shape}` is satisfied at the type-shape level.
- [ ] `FileDescriptor` has exactly the byte-metadata allow-list members: `Id`, `TenantId`, `Purpose`, `ContentType`, `SizeBytes`, `Classification`, `UploadedAt`, `ProcessingStatus`, `SoftDeletedAt`, `IsPublic`. The reflection test `DomainMeaningBoundaryTests.cs` asserts this and passes. Constitutional invariant `{N-domain-meaning}` is satisfied at the type-shape level.
- [ ] `HoneyDrunk.Files` exposes `AddHoneyDrunkFiles()` extension; `IFileUploadSession`, `IFileMetadata`, `IFileQuotaPolicy` all resolve from DI after registration.
- [ ] `DefaultFileUploadSession.InitiateAsync` calls `IFileQuotaPolicy.CheckAsync` before allocating a `FileId`; returns `null` if the policy denies and emits an audit event via `IAuditLog`. Test coverage in `DefaultFileUploadSessionTests.cs`.
- [ ] `DefaultFileMetadata.GetAsync` enforces `TenantId` match against `IGridContext.TenantId` (unless caller is `tnt_internal`).
- [ ] `DefaultFileQuotaPolicy.CheckAsync` reads tier-default values from `IConfigProvider` (key prefix `files:quota:`) **once at startup**; falls back to in-code seeds with a `::warning::` log if unset. **No subscription to change-events** — `IConfigProvider` does not expose a change-token at v0.1.0; configuration changes require a host restart. Hot-reload is out of scope.
- [ ] `IFileUploadSession`, `IFileMetadata`, `IFileQuotaPolicy`, `ProcessingPipelineDispatcher`, `FilesTelemetry` are all registered as `Singleton` in `AddHoneyDrunkFiles()`. Lifetime story matches the Audit precedent (Singletons over scoped GridContext access via `IGridContextAccessor`).
- [ ] `DefaultFileUploadSession`, `DefaultFileMetadata`, `DefaultFileQuotaPolicy` resolve `IGridContext` via `IGridContextAccessor.GridContext` (ambient per-call), **not** via direct `IGridContext` ctor injection. They resolve `IRepository<...>` / `IReadOnlyRepository<...>` / `IUnitOfWork` via `IServiceScopeFactory.CreateAsyncScope()` per call.
- [ ] `HoneyDrunk.Files.InMemory` ships `InMemoryFileStore : IFileStore`, `InMemorySasMinter`, `PassThroughVirusScan : IFileProcessor`. No cloud SDK references in the `.csproj`.
- [ ] `HoneyDrunk.Files.AzureBlob` ships a `Placeholder.cs` file with the comment naming the deferred status and ADR-0061 D3 as the reference. **No `Azure.Storage.Blobs` PackageReference** in the `.csproj`. The README explicitly states the package is a placeholder at v0.1.0 with no implementation.
- [ ] `DefaultFileUploadSession`, `DefaultFileMetadata`, `DefaultFileQuotaPolicy` emit operational telemetry via `ITelemetryActivityFactory` (activities `files.upload.initiated`, `files.metadata.read`, `files.quota.checked`). No `HoneyDrunk.Pulse.*` reference anywhere in `HoneyDrunk.Files.csproj` or `HoneyDrunk.Files.AzureBlob.csproj`.
- [ ] Per ADR-0061 D12, Restricted-tier upload-completed events, admin/cross-tenant download events, and hard-delete events emit audit records via `IAuditLog`. v0.1.0 ships only the upload-denied event emission (the rest land with the first feature packet that activates the production paths). At minimum: `DefaultFileUploadSession` emits `FileUploadDenied` audit event when `IFileQuotaPolicy.CheckAsync` returns a denial; covered by `DefaultFileUploadSessionTests.cs`.
- [ ] `SmokeTests.UploadInitiate_ThroughIFileUploadSession_RoundTrips_ToBytesViaIFileStore` passes, proving the contracts round-trip through the InMemory adapter (per ADR-0061 D3 verification).
- [ ] `SmokeTests.PublicAvatar_GetsCdnUrl_NotSas` passes, proving the public-vs-private metadata-driven distinction is honored at runtime.
- [ ] All five `.github/workflows/*.yml` files present and reference `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/*@main`.
- [ ] `api-compatibility.yml` runs on PR. On the scaffolding PR itself the workflow runs against an absent `main` baseline and reports `status: skipped` per the missing-baseline path — correct first-build behavior, not a failure. **Verify post-merge** by opening a throwaway PR that removes a member from `FileDescriptor` (or any member of the `IFileStore` / `IFileUploadSession` / `IFileMetadata` / `IFileProcessor` / `IFileQuotaPolicy` interfaces); the workflow must fail with breaking-changes-detected. Revert the throwaway PR after observation.
- [ ] `pr-core.yml` passes on the initial scaffolding PR (build + tests + analyzers + dependency scan + secret scan).
- [ ] Repo-level `CHANGELOG.md` has a `## [0.1.0] - YYYY-MM-DD` entry covering the scaffold (per invariants 12, 27, and memory `feedback_no_unreleased_commits` — no `## Unreleased` block at commit time).
- [ ] Per-package `CHANGELOG.md` files each have their own `## [0.1.0]` entry naming the package's specific introductions (per invariants 12 and 27). `HoneyDrunk.Files.AzureBlob`'s entry is explicit about the placeholder status.
- [ ] Repo-level `README.md` and per-package `README.md` files all present per invariant 12. `HoneyDrunk.Files.AzureBlob/README.md` explicitly names itself as a placeholder.
- [ ] Test suite runs and passes — minimum coverage: `DomainMeaningBoundaryTests` (reflection assertion on `FileDescriptor` members), `DownloadShapeTests` (reflection assertion on `IFileStore.GetDownloadUrlAsync` return type), `DefaultFileUploadSessionTests` (quota check + denial + audit event emission), `DefaultFileQuotaPolicyTests` (tier-default seed + `IConfigProvider` override + UploadDenied at the limit), `ProcessingPipelineDispatcherTests` (stage queue + idempotency by file_id), `SmokeTests` (round-trip via InMemory adapter), Canary tests (Kernel context flow + Abstractions boundary).
- [ ] All four projects in the solution carry the same `Version` (0.1.0), excluding test projects (invariant 27). `HoneyDrunk.Files.AzureBlob` ships at 0.1.0 as a placeholder per invariant 27's "all projects move together" rule.
- [ ] Manual confirmation that pushing tag `v0.1.0` triggers `release.yml` and produces NuGet packages for all four `src/*` projects (do not actually push the tag in this PR — verify the workflow exists and a tag-push trigger is configured).
- [ ] **No `.github/dependabot.yml` file exists.** Per ADR-0009, dependency-scanning lives in the nightly workflows; no Dependabot config file is committed.
- [ ] **`FileDescriptor.TenantId` is the Kernel `TenantId` strong type** (from `HoneyDrunk.Kernel.Abstractions.Identity`), per ADR-0026. `UploadRequest.TenantId` and `QuotaSnapshot.TenantId` use the same strong type. The Files-side per-tenant quota and forensic-listing paths justify the contract dependency on `Kernel.Abstractions` — same trade Audit made.
- [ ] **Repo `README.md` includes a `## For downstream consumers — minimal wiring` section** showing the host-side composition snippet (test-time with `InMemoryFileStore`; production-time placeholder noting `AzureBlobFileStore` lands with the first feature packet), copy-pasteable. This is load-bearing for every downstream consumer (Hearth's first media packet, Notify's optional `file_id` attachment path, Communications digests).
- [ ] **Repo `README.md` includes a `## Phase-1 honest limitation` section** that explicitly names: (a) `HoneyDrunk.Files.AzureBlob` is a placeholder at v0.1.0 — no implementation; (b) the processing pipeline ships only the `PassThroughVirusScan` stage — real image/audio processing, EXIF stripping, and malware scan integration land with the first feature packet; (c) no Azure resources are provisioned at standup. No language describing the AzureBlob package as "production-ready" or "Azure-backed" appears anywhere in the repo.
- [ ] **The README does NOT cite "ADR-0061" by number in narrative paragraphs.** Per memory `feedback_no_adr_in_docs`. (Runtime metadata references — CHANGELOG, catalog entries elsewhere — are fine; the README is user-facing narrative.)

## Human Prerequisites

- [ ] Packet 03 of this initiative complete — `HoneyDrunkStudios/HoneyDrunk.Files` repo exists on GitHub with org-default branch protection, labels seeded, OIDC federated credential wired, and the local working tree cloned at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Files/`.
- [ ] Packet 02 of this initiative merged — the two new Files invariants exist in `constitution/invariants.md` so this packet's acceptance criteria reference them by number. **This packet's source file uses `{N-domain-meaning}` and `{N-download-shape}` placeholders** for the two Files-related invariant numbers; substitute the real numbers in place pre-push under invariant 24's pre-filing carve-out, **after** packet 02 merges and the assigned numbers are known. At scoping time (2026-05-24) the expected assignments are 50 and 51, but the collision-check protocol at packet 02's edit time is authoritative.
- [ ] After this packet's PR merges, push tag `v0.1.0` from `main` to trigger the first NuGet publish. Tags are human-pushed per invariant 27.
- [ ] **`NUGET_API_KEY` repository (or org-level) secret is available to the `HoneyDrunk.Files` repo before `v0.1.0` is tagged.** The reusable `release.yml` in `HoneyDrunk.Actions` declares `nuget-api-key` as a named secret (no `secrets: inherit` pattern). Org-level `NUGET_API_KEY` (shared with other HoneyDrunk repos publishing to nuget.org) is the standard approach — verify it's bound to this repo before tagging.
- [ ] **Branch protection sequencing.** Branch protection on `main` was set by packet 03 requiring only `pr-core / core` for the initial scaffolding PR (the `api-compatibility / abstractions-shape` check reports `status: skipped` on the first PR). After the throwaway breaking-change PR confirms the canary fires post-merge, add `api-compatibility / abstractions-shape` to required checks in a follow-up branch-protection update.
- [ ] **No Azure resource provisioning required for this packet.** HoneyDrunk.Files is a library Node at Phase 1, not a deployable. Storage account, CDN, Defender for Storage, Front Door endpoint, Key Vault, managed identity, App Configuration keys for quota tier defaults — all belong with whichever packet first deploys a Files-composing host (likely the first PDR-0005 Hearth media-bearing packet). Cross-link: [`infrastructure/walkthroughs/azure-provisioning-guide.md`](../../../../infrastructure/walkthroughs/azure-provisioning-guide.md) for when that work lands.
- [ ] After this packet's PR merges and `v0.1.0` ships, file a small follow-up to add `HoneyDrunk.Files` to the grid-health aggregator's watched-repos list in `HoneyDrunk.Actions` — only if the aggregator does not auto-discover from `catalogs/nodes.json`. Verify which behavior is in place at the time this prereq is being checked. (If auto-discovery is wired, packet 01's `grid-health.json` edit is sufficient and this prereq is satisfied automatically.)
- [ ] After this packet's PR merges, file a SonarCloud onboarding follow-up packet for `HoneyDrunk.Files` modeled on the corresponding ADR-0011 onboarding packet.
- [ ] After this packet's PR merges and `v0.1.0` ships, file a small follow-up Architecture packet to bump the four `modules.json` entries for Files from `0.0.0` to `0.1.0` and to flip the `grid-health.json` Files row's `version` from `0.0.0` to `0.1.0`, `signal` from `Seed` to `Live` (if appropriate), and clear the `active_blockers` array. That follow-up is not in this packet's scope.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `Abstractions.csproj` carries ONE `HoneyDrunk.*` ref (`Kernel.Abstractions` for `TenantId` and ambient context types) — intentional, ADR-0061 D3-permitted exception. `HoneyDrunk.Standards` uses `PrivateAssets="all"`.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. — `Files.csproj` references `Files.Abstractions` (project), `Kernel.Abstractions`, `Data.Abstractions`, `Vault`, `Audit.Abstractions`.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Files → Kernel and Files → Data → Kernel and Files → Audit → Data → Kernel are all DAG-consistent.

> **Invariant 5:** GridContext must be present in every scoped operation. — `DefaultFileUploadSession.InitiateAsync` enriches the upload request's TenantId from `IGridContextAccessor.GridContext` if the request's TenantId is `default`.

> **Invariant 6:** CorrelationId is never null or empty, and TenantId is never absent, in a live GridContext. — Files enriches empty fields rather than persisting unattributable upload sessions.

> **Invariant 9:** Vault is the only source of secrets. — Quota tier defaults are non-secret config via `IConfigProvider` (ADR-0005), not `ISecretStore`. Storage account credentials and SAS signing keys live in Files' own Key Vault (`kv-hd-files-{env}`) and are sourced via `ISecretStore` when the first deployable host lands — not in this scaffold.

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning. — This packet establishes Files' solution + CI.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — All four packages ship README + CHANGELOG; repo-level files also.

> **Invariant 13:** All public APIs have XML documentation. Enforced by HoneyDrunk.Standards analyzers. — All 5 interfaces + 6 records + 3 enums + `FileId` carry `///` summaries.

> **Invariant 14:** Canary tests validate cross-Node boundaries. — `HoneyDrunk.Files.Tests.Canary` verifies the Kernel context flow and the Abstractions boundary surface. Downstream Nodes (Hearth, Lately, etc.) will carry their own canary tests against the Files Abstractions boundary in their own scaffold packets.

> **Invariant 15:** Unit tests and in-process integration tests never depend on external services. — `InMemoryFileStore` + `InMemorySasMinter` + `PassThroughVirusScan` satisfy this. No Azure SDK references in test projects.

> **Invariant 16:** No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only. — `HoneyDrunk.Files.InMemory` ships the reference adapter as production source (used at test-time by consumers, not as test-only code).

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. `HoneyDrunk.Standards` must be on every new .NET project. — Confirmed above.

> **Invariant 27:** All projects in a solution share one version and move together. — All four `src/*` packages ship at `0.1.0`; `HoneyDrunk.Files.AzureBlob` ships at 0.1.0 as a placeholder per this rule. Test projects do not bump.

> **Invariant `{N-domain-meaning}` (this initiative, packet 02):** The Files Node persists bytes and bytes-metadata, never domain meaning. The classification of *what a file means* lives in the consuming Node; Files knows the bytes, the size, the content type, the purpose-tag, the tenant, the classification tier, the upload timestamp, the processing status, and the soft-delete state — nothing more. — `FileDescriptor` carries exactly that allow-list; `DomainMeaningBoundaryTests` enforces it at the type-shape level.

> **Invariant `{N-download-shape}` (this initiative, packet 02):** Every download path through Files is either CDN-fronted public or a short-lived SAS issued after policy check. Long-lived storage-account-shared-key URLs are forbidden anywhere in the Grid. — `IFileStore.GetDownloadUrlAsync` returns `Task<SignedDownloadUrl>` (envelope type), never `Task<string>`; `DownloadShapeTests` enforces the return shape at the type-shape level. `SignedDownloadUrl.IsPublic` distinguishes CDN-public from SAS-private at the response level.

## Referenced ADR Decisions

- **ADR-0061 D1** — Files is the Core sector's single Node for bytes + bytes-metadata. Substrate only; no domain meaning, no observability pipeline, no audit storage.
- **ADR-0061 D3** — Four packages (`Abstractions` + runtime + `InMemory` reference adapter + `AzureBlob` placeholder); contracts authored fresh in this packet; `AzureBlob` ships empty at v0.1.0.
- **ADR-0061 D6** — Primary surfaces: `IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy`; supporting records: `FileDescriptor`, `UploadRequest`, `UploadSession`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy`.
- **ADR-0061 D5** — Tenant isolation is path-prefixed (`{tenant_id}/{purpose}/{file_id}{?/derivative}`) within a single container per environment. v0.1.0 doesn't have a real Azure container, but `DefaultFileMetadata.GetAsync` and `DefaultFileMetadata.ListAsync` enforce `TenantId` match at the metadata-read level (policy-side enforcement of the isolation rule that the storage-side SAS-prefix-constraint will reinforce when the AzureBlob adapter lands).
- **ADR-0061 D7** — Upload pattern is signed-URL direct-to-blob. The API never proxies bytes. The runtime composition reflects this: `DefaultFileUploadSession.InitiateAsync` returns a `SignedUploadUrl`; there is no `IFileUploadSession.UploadBytesAsync(stream)` method.
- **ADR-0061 D8** — Public vs. private is metadata-driven. `FileDescriptor.IsPublic` is the flag; `IFileStore.GetDownloadUrlAsync` returns `SignedDownloadUrl` with `IsPublic` set; no path-based distinction.
- **ADR-0061 D9** — Processing pipeline is async, idempotent, scan-before-available. v0.1.0 ships `ProcessingPipelineDispatcher` + a `PassThroughVirusScan` stage; real toolchain (ImageSharp, FFmpeg, Defender for Storage) lands with first feature packet.
- **ADR-0061 D10** — Per-tenant quota enforced at SAS issuance. `DefaultFileQuotaPolicy` reads tier defaults from `IConfigProvider`; `DefaultFileUploadSession.InitiateAsync` calls `CheckAsync` before allocating a `FileId`.
- **ADR-0061 D11** — Soft-delete by default; hard-delete via offboarding/erasure cascade. `FileDescriptor.SoftDeletedAt` carries the state; `IFileStore.DeleteAsync` is soft-delete only at this surface; hard-delete is an internal operation triggered by `TenantClosed`/`UserErasureRequest` events (event-handler wiring lands with the first feature packet that wires Files to Transport).
- **ADR-0061 D12** — Audit events emit via `IAuditLog`. v0.1.0 emits `FileUploadDenied` (quota path); other event kinds land with the first feature packet that activates the production paths.
- **ADR-0061 D13** — Notify-attachment compatibility — both paths supported. Not directly in scope here; the optional `file_id` field on Notify's `Attachment` record is wired in a Notify-side follow-up packet that consumes `HoneyDrunk.Files.Abstractions 0.1.0`.
- **ADR-0026** — `IGridContext.TenantId` is the non-nullable Kernel `TenantId` strong type with `Internal` sentinel. Files' per-tenant quota and forensic-listing paths use the strong type at the contract surface.
- **ADR-0027** — The fixture-vs-Testing-package decision: Files ships `HoneyDrunk.Files.InMemory` as a separately-packaged reference adapter at v0.1.0 (the Capabilities pattern, ADR-0017 D2), not the Audit pattern (fixture `internal` to test project). Justification: PDR-0005 Hearth as the named first consumer is an external repo that will need to mock `IFileStore` in its own unit tests from the first media-bearing packet.
- **ADR-0042** — Idempotency contract for async boundaries. `ProcessingPipelineDispatcher` is idempotent by `file_id`; `DefaultFileUploadSession.InitiateAsync` is idempotent by `{tenant_id}:{purpose}:{client-provided-idempotency-key}`.
- **ADR-0009** — No `.github/dependabot.yml`; nightly workflows handle deps.
- **ADR-0005** — Quota tier defaults sourced through `IConfigProvider` from App Configuration via Vault, not direct App Config SDK.

## Dependencies

- `packet:01` — Architecture catalog registration must be merged so `repos/HoneyDrunk.Files/` context folder and `honeydrunk-files` catalog entries exist.
- `packet:02` — the two new Files invariants must exist in `constitution/invariants.md` before this packet's acceptance criteria reference them by number. Substitute the assigned `{N-domain-meaning}` and `{N-download-shape}` numbers in this packet's source file in place pre-push under invariant 24's pre-filing carve-out, **after** packet 02 merges.
- `packet:03` — the `HoneyDrunk.Files` GitHub repo must exist with branch protection, labels, OIDC, and the local working tree cloned. The scaffolding agent has nowhere to author into without packet 03 done.

## Labels

`feature`, `tier-2`, `files`, `scaffold`, `adr-0061`

## Agent Handoff

**Objective:** Take the empty `HoneyDrunk.Files` repo and ship version 0.1.0 with the D6 public surface (5 interfaces + 6 supporting records + 3 enums + `FileId`), default runtime composition (upload session orchestrator, metadata composer, quota policy reader, processing pipeline dispatcher, telemetry helpers), `HoneyDrunk.Files.InMemory` reference adapter (InMemoryFileStore + InMemorySasMinter + PassThroughVirusScan), `HoneyDrunk.Files.AzureBlob` placeholder (no implementation), Abstractions/Unit/Canary test projects, end-to-end smoke tests proving round-trip via the InMemory adapter, the two constitutional-invariant enforcement reflection tests, full CI, and the contract-shape canary scoped to `Abstractions`.

**Target:** HoneyDrunk.Files, branch from `main`. (Packet 03 ensures `main` exists with `.gitignore`/`LICENSE` already in place.)

**Context:**
- Goal: Unblock every PDR-driven app's first media-bearing packet (Hearth's journal photo upload is the named imminent driver), Notify's optional `file_id`-resolved attachment path, Communications' digest embeddings, and any future Studios product surface needing avatar serving. Establish the contract-shape canary baseline that protects the surface from drift.
- Feature: ADR-0061 standup initiative — this is the substrate scaffold, the fourth packet of the initiative (after Architecture catalog registration, the two new Files invariants `{N-domain-meaning}` / `{N-download-shape}`, and the human-only repo creation).
- ADRs: ADR-0061 (sole governing standup ADR); ADR-0026 (TenantId strong type at the contract surface); ADR-0027 (fixture-vs-Testing-package convention — Files ships InMemory as a separately-packaged reference adapter); ADR-0042 (idempotency contract for upload-initiation and processing-pipeline stages); ADR-0005 (App Config-via-Vault pattern for quota tier defaults); ADR-0009 (no Dependabot config file).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01, 02, and 03 of this initiative must merge / be Done first.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are normally permitted. — `HoneyDrunk.Files.Abstractions.csproj` carries exactly one intentional ADR-permitted `HoneyDrunk.*` reference: `HoneyDrunk.Kernel.Abstractions` for `TenantId` and ambient context types. The `HoneyDrunk.Standards` reference uses `PrivateAssets="all"`.
- **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Files → Kernel and Files → Data → Kernel and Files → Audit → Data → Kernel are all DAG-consistent. Files does NOT reference Notify, Communications, or any consumer app Node.
- **Invariant 5/6:** GridContext + CorrelationId + TenantId must be present in every scoped operation. — `DefaultFileUploadSession` enriches the upload request's TenantId from `IGridContextAccessor.GridContext` if the request's TenantId is `default`.
- **Invariant 9:** Vault is the only source of secrets. — The quota tier-default values are non-secret configuration, sourced via `IConfigProvider` from App Configuration per ADR-0005. No `ISecretStore` calls are needed in this scaffold (Storage account credentials and SAS signing keys land with the first feature packet that wires the AzureBlob adapter).
- **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — All four `src/*` projects ship `README.md` and `CHANGELOG.md` in the same commit.
- **Invariant 13:** All public APIs have XML documentation. — Every public type/member in `HoneyDrunk.Files.Abstractions` carries `///` summaries. StyleCop rules from `HoneyDrunk.Standards` enforce this.
- **Invariant 26:** Packets for .NET code work must include `## NuGet Dependencies`. `HoneyDrunk.Standards` must be on every new .NET project. — Confirmed in the NuGet Dependencies section above.
- **Invariant 27:** All projects in a solution share one version. — All four `src/*.csproj` ship at `0.1.0`. Test projects do not bump. `HoneyDrunk.Files.AzureBlob` ships at 0.1.0 as a placeholder per this rule.
- **Invariant `{N-domain-meaning}` (Files persists bytes and bytes-metadata, never domain meaning):** The classification of *what a file means* lives in the consuming Node. Files knows the bytes, the size, the content type, the purpose-tag, the tenant, the classification tier, the upload timestamp, the processing status, and the soft-delete state — nothing more. Domain-meaning fields on `FileDescriptor` or any package surface in `HoneyDrunk.Files.Abstractions` are rejected by review. — `FileDescriptor` carries exactly the byte-metadata allow-list; `DomainMeaningBoundaryTests.cs` makes the addition of a domain-meaning field a build failure via reflection.
- **Invariant `{N-download-shape}` (every Files download is CDN-fronted public or short-lived SAS):** Long-lived storage-account-shared-key URLs are forbidden anywhere in the Grid. The shape of every Files download is auditable from this rule alone. The default TTL is 15 minutes; maximum 4 hours. `IFileStore.GetDownloadUrlAsync` is the only valid download-URL minting site. — `IFileStore.GetDownloadUrlAsync` returns `Task<SignedDownloadUrl>` (envelope type), never `Task<string>`; `DownloadShapeTests.cs` enforces the return shape at the type-shape level.
- **Canary on the scaffolding PR reports `status: skipped`, not fail.** First PR against near-empty repo: `git worktree add` against the baseline ref fails → `::warning::` + exit 0. Not a misconfiguration. Scaffold merge establishes baseline; verify post-merge via a throwaway breaking-change PR (revert after).
- **Abstractions stance — exactly ONE `HoneyDrunk.*` ref**, `HoneyDrunk.Kernel.Abstractions` (for `TenantId` per ADR-0026). No `Kernel`-runtime, no `Data*`, no `Vault*`, no `Audit*`, no `Pulse*`.
- **Records drop `I`; interfaces keep it.** `FileId`, `FileDescriptor`, `UploadRequest`, `UploadSession`, `UploadDenied`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy`, `FilePurpose`, `FileClassification`, `FileProcessingStatus` are all records/structs/enums and have no `I` prefix. `IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy` are interfaces and keep the `I` prefix.
- **No `.github/dependabot.yml`** (ADR-0009). Org-default Dependabot security alerts stay enabled.
- **`HoneyDrunk.Files.AzureBlob` is a deliberate placeholder.** No `Azure.Storage.Blobs` reference. No implementation source beyond `Placeholder.cs` with the deferred-status comment. The README and CHANGELOG name the placeholder status explicitly. Do not be tempted to "stub out" the AzureBlob class shape — the implementation lands with the first feature packet that activates Files. Adding a stub here would lie about the package's status.
- **No `HoneyDrunk.Pulse.*` ref anywhere** (telemetry is one-way per D6).
- **`InMemoryFileStore` is a reference adapter, not a test fixture.** It ships in `src/HoneyDrunk.Files.InMemory/`, not in a test project. Downstream consumers (Hearth, Notify, etc.) take a PackageReference on `HoneyDrunk.Files.InMemory` from their test projects.
- **`FileDescriptor` carries the byte-metadata allow-list ONLY.** Do not add `ContentDescription`, `AssetTitle`, `Caption`, `OwnerName`, `RelatedEntityId`, `Tags` (or anything similar). `DomainMeaningBoundaryTests` will fail.
- **`IFileStore.GetDownloadUrlAsync` returns `SignedDownloadUrl`, never `string`.** No `Task<string>` overload. No `Task<Uri>` overload. The envelope type carries the public/private distinction and the expiry; consumers do not get a raw URL.

**Key Files:**
- `HoneyDrunk.Files.slnx`, `Directory.Build.props`
- `src/HoneyDrunk.Files.Abstractions/` — 5 interfaces + 6 records + 3 enums + `FileId`
- `src/HoneyDrunk.Files/` — `ServiceCollectionExtensions.cs`, `DefaultFileUploadSession.cs`, `DefaultFileMetadata.cs`, `ProcessingPipelineDispatcher.cs`, `DefaultFileQuotaPolicy.cs`, `FilesTelemetry.cs`
- `src/HoneyDrunk.Files.InMemory/` — `InMemoryFileStore.cs`, `InMemorySasMinter.cs`, `PassThroughVirusScan.cs`
- `src/HoneyDrunk.Files.AzureBlob/` — `Placeholder.cs`, `README.md` (placeholder notice), `CHANGELOG.md` (placeholder entry)
- `tests/HoneyDrunk.Files.Abstractions.Tests/` — `ContractSurfaceTests.cs`, `DomainMeaningBoundaryTests.cs`, `DownloadShapeTests.cs`
- `tests/HoneyDrunk.Files.Tests.Unit/` — `DefaultFileUploadSessionTests.cs`, `DefaultFileQuotaPolicyTests.cs`, `ProcessingPipelineDispatcherTests.cs`, `SmokeTests.cs`
- `tests/HoneyDrunk.Files.Tests.Canary/` — `KernelCanaryTests.cs`, `AbstractionsSurfaceCanaryTests.cs`
- `.github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility}.yml`
- `README.md`, `CHANGELOG.md` (repo-level), per-package `README.md` and `CHANGELOG.md`

**Contracts:**
- D6 public surface (`IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy`) plus supporting records and enums authored fresh in this packet inside `HoneyDrunk.Files.Abstractions`.
- The contract-shape canary establishes its baseline against this packet's commit. Future shape changes to any public type in `Abstractions` trigger the canary.
