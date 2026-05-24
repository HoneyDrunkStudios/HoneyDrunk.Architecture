---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Identity
labels: ["feature", "tier-2", "core", "identity", "scaffold", "adr-0060"]
dependencies: ["packet:01", "packet:02", "packet:03"]
adrs: ["ADR-0060", "ADR-0050", "ADR-0051", "ADR-0026", "ADR-0030", "ADR-0031", "ADR-0042", "ADR-0005"]
accepts: ADR-0060
wave: 2
initiative: adr-0060-identity-standup
node: honeydrunk-identity
---

# Feature: Stand up the HoneyDrunk.Identity repo — solution, two packages, six interfaces, seven records, in-memory test fixtures, CI with canary

## Summary

Bring the empty `HoneyDrunk.Identity` repo from zero to first-shippable state per ADR-0060 D12 Phase 1. Land the solution layout, the two package families (`HoneyDrunk.Identity.Abstractions` + `HoneyDrunk.Identity`), the D4 public surface inside `Abstractions` (six interfaces: `IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, `IIdentityHealth`; seven records: `UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck`), the runtime package with the IdP-provider-slot pattern (no Entra adapter yet — that ships in Phase 2), Data-backed user-record and IdentityMap stores using `IRepository`/`IUnitOfWork`, the Node's own dedicated managed identity wiring scaffolded (Azure provisioning deferred), in-memory `IUserDirectory` / `IUserProfileStore` / `IInternalTokenIssuer` / `IExternalIdpClaimMapper` / `IIdentityDeletionFanout` fixtures for tests, the end-to-end smoke test (signup → claim mapping → user record → token issuance), the standard CI pipeline (PR core + release + nightly deps + nightly security), and the contract-shape canary scoped to the full `HoneyDrunk.Identity.Abstractions` public surface per ADR-0060 D7 / invariant **{N-canary}**.

This is the unblocker for the first user-facing app's signup flow (Hearth per PDR-0005, queued behind it Lately per PDR-0003 and Curiosities per PDR-0008) and for Notify.Cloud's prospect signup. After this packet merges and `v0.1.0` tags, Hearth's signup packet can take `HoneyDrunk.Identity.Abstractions 0.1.0` as a PackageReference and wire the first concrete `IExternalIdpClaimMapper` (likely Entra External ID).

**Invariant numbers (substitute via packet 02 pre-filing under invariant 24).** Identity constitutional invariants are **{N-ownership}** (Identity owns user records and IdentityMap, not Auth — D1 / D3), **{N-issuance}** (internal-token issuance exclusivity — D6), **{N-coupling}** (downstream Abstractions-only coupling — D13), and **{N-canary}** (Identity contract-shape canary — D7). Defaults at scoping time (high-water mark 53): 54 / 55 / 56 / 57.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Identity`

## Motivation

ADR-0060 D12 Phase 1 specifies the first-PR scaffold for HoneyDrunk.Identity. Packet 03 created the GitHub repo and cloned the local tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Identity/` (`.gitignore`, `LICENSE`, placeholder `README.md` only). Catalogs and Identity invariants (`{N-ownership}`, `{N-issuance}`, `{N-coupling}`, `{N-canary}`) are already in place after packets 01 and 02. This packet ships the code and freezes a contract shape that supports the user record, the external-IdP seam, internal-token issuance, and the account-deletion fan-out from v0.1.0.

Until this packet ships: Hearth (PDR-0005) has no `HoneyDrunk.Identity.Abstractions 0.1.0` to reference for its signup flow; Lately, Curiosities, and Notify.Cloud have no canonical user-account target; the contract-shape canary has no baseline; the ADR-0050 D6 "Auth-side packet" placeholder for the user-level GDPR Art. 17 path has no Identity-side implementation site to compile against; the user record problem ADR-0060 exists to solve stays unsolved. ADR-0060 D12 Phase 1 explicitly requires the D4 surface + round-trip proof in the first commit so the canary has a coherent baseline.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Identity/
├── HoneyDrunk.Identity.slnx
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
│       └── api-compatibility.yml    (calls Actions/job-api-compatibility.yml — D7 / invariant {N-canary} canary)
├── src/
│   ├── HoneyDrunk.Identity.Abstractions/
│   │   ├── HoneyDrunk.Identity.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── IUserDirectory.cs
│   │   ├── IUserProfileStore.cs
│   │   ├── IInternalTokenIssuer.cs
│   │   ├── IExternalIdpClaimMapper.cs
│   │   ├── IIdentityDeletionFanout.cs
│   │   ├── IIdentityHealth.cs
│   │   ├── UserId.cs                (record struct — drops I per Grid-wide naming rule)
│   │   ├── PrincipalId.cs           (record — discriminated User/Service/Agent)
│   │   ├── ExternalSubject.cs       (record)
│   │   ├── UserProfile.cs           (record)
│   │   ├── InternalToken.cs         (record)
│   │   ├── DeletionIntent.cs        (record)
│   │   ├── DeletionAck.cs           (record)
│   │   ├── UserRecord.cs            (record — directory's resolved user shape)
│   │   ├── UserLifecycleStatus.cs   (enum: Active, PendingVerification, Locked, Deleted)
│   │   └── DeletionAckStatus.cs     (enum: Acknowledged, Skipped, Failed)
│   └── HoneyDrunk.Identity/
│       ├── HoneyDrunk.Identity.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── ServiceCollectionExtensions.cs    (AddHoneyDrunkIdentity)
│       ├── DataUserDirectory.cs              (IUserDirectory impl over IRepository/IUnitOfWork)
│       ├── DataUserProfileStore.cs           (IUserProfileStore impl)
│       ├── JwksInternalTokenIssuer.cs        (IInternalTokenIssuer impl — signs via ISecretStore-resolved key)
│       ├── EventBasedIdentityDeletionFanout.cs (IIdentityDeletionFanout impl — Service Bus per ADR-0028)
│       ├── DefaultIdentityHealth.cs          (IIdentityHealth impl)
│       ├── Storage/
│       │   ├── UserRecordEntity.cs           (Data-mapped entity for the User table)
│       │   ├── IdentityMapEntity.cs          (PseudoUserToken ↔ UserId ↔ ExternalSubject ↔ PII)
│       │   ├── ExternalSubjectMapEntity.cs   (ExternalSubject ↔ UserId)
│       │   └── UserProfileEntity.cs          (Data-mapped entity for the UserProfile table)
│       ├── IdentityOptions.cs                (IInternalTokenIssuer signing-key reference, TTL, etc., bound via IConfigProvider)
│       └── IdentityTelemetry.cs              (operational telemetry via ITelemetryActivityFactory)
└── tests/
    ├── HoneyDrunk.Identity.Abstractions.Tests/
    │   ├── HoneyDrunk.Identity.Abstractions.Tests.csproj
    │   ├── ContractSurfaceTests.cs            (compile-only + shape assertions on Abstractions public surface)
    │   ├── UserIdShapeTests.cs                (asserts `usr_` prefix + 26-char ULID body)
    │   └── PrincipalIdDiscriminatedTests.cs   (asserts User / Service / Agent variants)
    └── HoneyDrunk.Identity.Tests/
        ├── HoneyDrunk.Identity.Tests.csproj
        ├── Fixtures/
        │   ├── InMemoryUserDirectory.cs         (internal)
        │   ├── InMemoryUserProfileStore.cs      (internal)
        │   ├── InMemoryInternalTokenIssuer.cs   (internal)
        │   ├── InMemoryExternalIdpClaimMapper.cs (internal — emits deterministic claims for tests)
        │   └── InMemoryIdentityDeletionFanout.cs (internal)
        ├── DataUserDirectoryTests.cs
        ├── DataUserProfileStoreTests.cs
        ├── JwksInternalTokenIssuerTests.cs
        ├── EventBasedIdentityDeletionFanoutTests.cs
        └── SmokeTests.cs                       (end-to-end: claim mapping → user record → token issuance → round-trip)
```

**Fixtures stay `internal`** to `HoneyDrunk.Identity.Tests/Fixtures/` per the ADR-0027 D3 precedent followed by ADR-0031 (Audit) — no speculative `Testing` package; cut later as non-breaking when a third consumer needs it. Hearth (the first user-facing consumer) writes its own narrowly-scoped test double in Phase 2.

### Solution

`HoneyDrunk.Identity.slnx` references both `src/*` projects and both `tests/*` projects. Solution-level `Directory.Build.props` sets `TargetFramework: net10.0`, `Nullable: enable`, `ImplicitUsings: enable`, `LangVersion: latest`, `TreatWarningsAsErrors: true`, `Version: 0.1.0`, `Authors: HoneyDrunk Studios`, package metadata (`PackageProjectUrl`, `RepositoryUrl`, `RepositoryType: git`, `PublishRepositoryUrl: true`, `IncludeSymbols: true`, `SymbolPackageFormat: snupkg`, `GenerateDocumentationFile: true`) — same shape as `HoneyDrunk.Audit/Directory.Build.props`.

Per invariant 27 (all projects in a solution share one version and move together), both `src/*.csproj` files carry the same `Version` (0.1.0 for this initial release). Test projects are excluded from version-bump scope.

### Contract details — `HoneyDrunk.Identity.Abstractions`

Records drop the `I` prefix per the Grid-wide naming rule; interfaces keep it.

**Single `HoneyDrunk.*` reference: `HoneyDrunk.Kernel.Abstractions`** (for `TenantId` strong type per ADR-0026). Permitted by ADR-0060 D4 / D13 as the same exception ADR-0031 took for Audit — every downstream consumer (Hearth, Lately, Curiosities, Notify.Cloud) already has Kernel.Abstractions in its closure, so no new transitively-pinned package.

**`UserId` shape** (D3): 26-char ULID prefixed `usr_`. Define as a `readonly record struct`:

```csharp
namespace HoneyDrunk.Identity.Abstractions;

/// <summary>
/// Canonical Grid user identifier. 26-character ULID prefixed `usr_` (e.g., `usr_01HKMS3ZQ4N7P8YR2J5W9XCBVF`).
/// Sortable, URL-safe, 128-bit collision-resistant. The Grid-internal identifier; appears in IdentityMap,
/// in user records, and in service-to-service contexts where the principal needs to be resolvable for operational use.
/// </summary>
public readonly record struct UserId(string Value)
{
    private const string Prefix = "usr_";

    /// <summary>
    /// Generate a new <see cref="UserId"/> with a fresh 26-character ULID body.
    /// </summary>
    public static UserId New() => new(Prefix + Ulid.NewUlid().ToString());

    /// <summary>
    /// The empty / unset identifier. Use for builder/scaffold scenarios; not valid as a directory key.
    /// </summary>
    public static UserId Empty { get; } = new(string.Empty);

    public bool IsEmpty => string.IsNullOrEmpty(Value);

    public override string ToString() => Value;
}
```

`Ulid` is `NUlid` (BSD-3) — already a Grid-common ULID library; verify the Grid's existing ULID convention against `HoneyDrunk.Kernel.Abstractions` and pick the same library Kernel uses. If Kernel does not ship a ULID dependency on the Abstractions surface, take `NUlid` directly here as the implementation choice (the package is a leaf dependency; no transitive `HoneyDrunk` weight).

**`PrincipalId` shape** (D3): discriminated record wrapping `UserPrincipal` / `ServicePrincipal` / `AgentPrincipal`. Use C# discriminated-shape pattern (private constructor + factory methods + a Kind enum) consistent with the Grid's `MessageDecision` / `AuthorizationDecision` patterns in Communications/Auth.

**`ExternalSubject` shape** (D3): `(string IdpIssuer, string Sub)` record — the IdP issuer identifier (e.g., `https://login.microsoftonline.com/{tenant}/v2.0`) plus the `sub` claim. Stored alongside `UserId` in the `ExternalSubjectMap` table.

**Six interfaces** (D4) per the table in ADR-0060. The full XML-doc'd `.cs` shapes are written per the precedent established by `HoneyDrunk.Audit.Abstractions` — each interface has 1–3 methods, all `Task`-returning, all carrying `CancellationToken`. Signatures (high-level):

- `IUserDirectory` — `ResolveAsync(UserId, ct) -> Task<UserRecord?>`, `LookupByExternalSubjectAsync(ExternalSubject, ct) -> Task<UserRecord?>`, `MarkVerifiedAsync(UserId, ct)`, `LockAsync(UserId, reason, ct)`, `UnlockAsync(UserId, ct)`, `DeleteAsync(UserId, ct)` (deletion fan-out lives in `IIdentityDeletionFanout`; this is the directory-side mark-as-deleted call invoked by the fanout's final step).
- `IUserProfileStore` — `ReadAsync(UserId, ct) -> Task<UserProfile?>`, `WriteAsync(UserId, UserProfile, ct)`.
- `IInternalTokenIssuer` — `IssueAsync(PrincipalId, IReadOnlyDictionary<string, string> claims, TimeSpan? ttl, ct) -> Task<InternalToken>`. TTL ≤ 5 min hard-capped by the implementation per D6.
- `IExternalIdpClaimMapper` — `MapAsync(IDictionary<string, string> idpClaims, ct) -> Task<UserPrincipal>`. The runtime composes one implementation at host time (Entra adapter ships in Phase 2).
- `IIdentityDeletionFanout` — `EraseAsync(UserId, string correlationId, ct) -> Task<IReadOnlyList<DeletionAck>>`. Idempotent end-to-end per ADR-0042 — re-running with the same `(UserId, correlationId)` produces the same deletions without double-execution.
- `IIdentityHealth` — Kernel `IHealthContributor` shape.

**Records** (D4): `UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck` plus `UserRecord` (the directory's resolved user shape — `UserId Id`, `ExternalSubject ExternalSubject`, `UserLifecycleStatus Status`, `DateTimeOffset CreatedAt`, `DateTimeOffset? VerifiedAt`, `DateTimeOffset? LastLoginAt`).

**`UserLifecycleStatus` enum**: `Active = 0`, `PendingVerification = 1`, `Locked = 2`, `Deleted = 3`.

The full surface above is frozen at stand-up and protected by the contract-shape canary (D7 / invariant **{N-canary}**). Shape drift requires a version bump.

### Runtime details — `HoneyDrunk.Identity`

`HoneyDrunk.Identity` references:

- `HoneyDrunk.Identity.Abstractions` (project reference)
- `HoneyDrunk.Kernel.Abstractions` (for `ITelemetryActivityFactory`, `IGridContext`, `IGridContextAccessor`, `TenantId`)
- `HoneyDrunk.Kernel` (optional — drop if `Kernel.Abstractions` suffices; mirror the audit-runtime pattern)
- `HoneyDrunk.Data.Abstractions` (for `IRepository`, `IUnitOfWork`)
- `HoneyDrunk.Vault` (for `ISecretStore` — resolves the JWT signing key; for `IConfigProvider` — reads identity options)
- `HoneyDrunk.Auth.Abstractions` (for `IAuthorizationPolicy` reuse on directory lifecycle gates per D5 / ADR-0060 D13's relationship-to-existing-ADRs table)
- `HoneyDrunk.Audit.Abstractions` (for `IAuditLog` emission — Identity emits `UserCreated`, `UserVerified`, `UserLocked`, `UserUnlocked`, `UserErased`, `InternalTokenIssued` sampled per ADR-0060 D13)
- `Microsoft.Extensions.DependencyInjection.Abstractions`
- `Microsoft.Extensions.Hosting.Abstractions`
- `Microsoft.Extensions.Logging.Abstractions`
- `Microsoft.Extensions.Options.ConfigurationExtensions`
- `System.IdentityModel.Tokens.Jwt` + `Microsoft.IdentityModel.Tokens` (JWT signing for `IInternalTokenIssuer` — same library family Auth uses for validation)

**`DataUserDirectory`** — implements `IUserDirectory`. Persists via `IRepository<UserRecordEntity>` + `IUnitOfWork`. Each method emits an `AuditEntry` via `IAuditLog` for the corresponding event (`UserCreated`, `UserVerified`, `UserLocked`, `UserUnlocked`, `UserErased`). Audit emission is **optional at the DI-resolution layer** (same pattern Auth uses for ADR-0031's first-emitter wiring): if no `IAuditLog` is registered in the host's container, Identity resolves a no-op stub and logs a `::warning::` at startup. **However**, ADR-0060 D9 + the invariant 47 expectation make `IAuditLog` registration effectively mandatory in production hosts. The no-op stub is a build-passing safety net, not a production posture.

**`DataUserProfileStore`** — implements `IUserProfileStore`. Persists via `IRepository<UserProfileEntity>`. Per D5, the profile lives in Identity's table, not the external IdP — IdP migration is bounded.

**`JwksInternalTokenIssuer`** — implements `IInternalTokenIssuer`. Resolves the signing key via `ISecretStore.GetSecretAsync(name)` where `name` is `identity:internal-token-signing-key` (read once at startup via `IdentityOptions`). Hard-caps the TTL at 5 minutes per D6 (`Math.Min(ttl ?? TimeSpan.FromMinutes(5), TimeSpan.FromMinutes(5))`). Signs with HS256 or RS256 — the choice is configurable via `IdentityOptions.SigningAlgorithm`, default RS256 for production-shape and `HS256` accepted only in test composition. The token shape is a standard JWT with `iss: https://identity.honeydrunk` (placeholder; configurable), `aud: honeydrunk-internal`, `sub: PrincipalId`, `exp`, `nbf`, `iat`, and any caller-supplied claims merged in.

**`EventBasedIdentityDeletionFanout`** — implements `IIdentityDeletionFanout`. Per D8, the fan-out emits `DeletionIntent` as a domain event on Service Bus (ADR-0028 transport). The transport mechanism is wired via a host-supplied `IDeletionTransport` slot interface (not in this packet's Abstractions surface — runtime-internal); the scaffold ships an `InMemoryDeletionTransport` for tests, and the production deployable wires Service Bus in Phase 3 when the full fan-out lands. **For v0.1.0 the EraseAsync implementation is intentionally limited**: it marks the directory entry deleted (via `DataUserDirectory.DeleteAsync`), deletes the IdentityMap row, emits `UserErased` to Audit, and emits `DeletionIntent` events for the registered consumer list. The full per-consumer ack-collection workflow lands in Phase 3 — v0.1.0 ships the boundary and the in-memory test loop; production-grade ack-collection waits for the Phase-3 packet.

**`IdentityOptions`** — bound via `IConfigProvider` against the `Identity:*` config namespace. Holds: `InternalTokenSigningKeyName` (default `identity:internal-token-signing-key`), `InternalTokenIssuer` (default `https://identity.honeydrunk`), `InternalTokenAudience` (default `honeydrunk-internal`), `InternalTokenDefaultTtl` (default `00:05:00`), `SigningAlgorithm` (default `RS256`), `DeletionConsumerNodeIds` (list — defaults to the v1 set from D8: `["honeydrunk-communications"]` only at v0.1.0; Phase 3 adds Memory, Knowledge, and tenant-scoped Data partitions via Communications-mediated fan-out).

**Host registration.** `ISecretStore`, `IConfigProvider`, `IRepository`, `IUnitOfWork`, `IAuditLog` (optional), `IAuthorizationPolicy` (optional — only required if the directory lifecycle gates are enabled) are host-wired. `AddHoneyDrunkIdentity()` throws `InvalidOperationException` at first resolution if any required dependency is missing.

```csharp
namespace HoneyDrunk.Identity;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddHoneyDrunkIdentity(this IServiceCollection services)
    {
        services.AddOptions<IdentityOptions>().BindConfiguration("Identity");
        services.AddSingleton<IUserDirectory, DataUserDirectory>();
        services.AddSingleton<IUserProfileStore, DataUserProfileStore>();
        services.AddSingleton<IInternalTokenIssuer, JwksInternalTokenIssuer>();
        services.AddSingleton<IIdentityDeletionFanout, EventBasedIdentityDeletionFanout>();
        services.AddSingleton<IIdentityHealth, DefaultIdentityHealth>();
        services.AddSingleton<IdentityTelemetry>();
        // Note: IExternalIdpClaimMapper is NOT registered here — the host composes its own implementation
        // (Entra adapter in Phase 2; tests register InMemoryExternalIdpClaimMapper).
        return services;
    }
}
```

**Singleton lifetimes** with `IGridContextAccessor` for per-call context, scoped Data resolution via `IServiceScopeFactory.CreateAsyncScope()` — same captive-dep avoidance pattern Audit uses.

### What this scaffold does NOT ship

Per ADR-0060 D12 Phase 1 scope:

- **No Entra adapter.** The IdP-vendor confirmation and the first concrete `IExternalIdpClaimMapper` implementation land in Phase 2 with the first user-facing app's feature packet. v0.1.0 ships only the in-memory test fixture for `IExternalIdpClaimMapper`.
- **No OAuth callback HTTP surface.** No `/users/me`, no JWKS endpoint, no OAuth authorization-code-grant handler. Those are HTTP-surface concerns that land when the deployable host is provisioned (Phase 2/3).
- **No Container App, no managed identity, no Key Vault `kv-hd-identity-{env}`.** Per ADR-0060 D9 the Node runs as `ca-hd-identity-{env}` with its own managed identity — that's deployable-host work, not library-scaffold work. The `IdentityOptions` already names the signing-key reference; the Vault namespace is created when the first deployable host is provisioned (Phase 2/3).
- **No full deletion fan-out workflow.** `EraseAsync` ships the boundary + the in-memory loop + a single Communications `DeletionIntent` emission. The full per-consumer ack-collection workflow + IdentityMap relocation from Auth lands in Phase 3 per ADR-0060 D12.
- **No `HoneyDrunk.Identity.Testing` package.** The in-memory fixtures stay `internal` to `HoneyDrunk.Identity.Tests/Fixtures/`. Cut later as non-breaking when a third consumer needs it. Same posture as Audit per ADR-0027 D3 precedent.

### In-memory fixtures — `tests/HoneyDrunk.Identity.Tests/Fixtures/`

Five `internal sealed` classes; not packaged at v0.1.0.

- `InMemoryUserDirectory : IUserDirectory` — `Dictionary<UserId, UserRecord>` + `Dictionary<ExternalSubject, UserId>` + `lock(_gate)`. Lifecycle transitions update the record's `UserLifecycleStatus`.
- `InMemoryUserProfileStore : IUserProfileStore` — `Dictionary<UserId, UserProfile>`.
- `InMemoryInternalTokenIssuer : IInternalTokenIssuer` — produces a structurally valid HS256 JWT signed with a fixed test key; TTL hard-capped at 5 minutes.
- `InMemoryExternalIdpClaimMapper : IExternalIdpClaimMapper` — deterministic mapping: `sub` claim → `UserPrincipal` with a deterministic `UserId` derived from the sub (so tests can predict the UserId).
- `InMemoryIdentityDeletionFanout : IIdentityDeletionFanout` — records the `(UserId, correlationId)` pairs called on it; returns synthesized `DeletionAck`s for each registered consumer node.

### Smoke test — `tests/HoneyDrunk.Identity.Tests/SmokeTests.cs`

`SignupFlow_RoundTripsThroughIdentityBoundary`:

1. External IdP "issues" a token (build a fake claim set with `sub: "abc123"`, `iss: "https://test-idp/"`, `email: "alice@example.com"`).
2. Call `InMemoryExternalIdpClaimMapper.MapAsync(claims)` → returns a `UserPrincipal` with a deterministic `UserId`.
3. Call `InMemoryUserDirectory.LookupByExternalSubjectAsync(externalSubject)` → returns null (first signup).
4. Create the user record: `InMemoryUserDirectory.Save(...)` (test helper) with `UserLifecycleStatus.PendingVerification`.
5. Call `InMemoryUserDirectory.MarkVerifiedAsync(userId)`.
6. Call `InMemoryInternalTokenIssuer.IssueAsync(new PrincipalId.User(userId), claims: empty, ttl: 1 minute)` → returns an `InternalToken` with non-empty `TokenString`, `ExpiresAt` ~= now + 1 min.
7. Assert: the resolved user record has `UserLifecycleStatus.Active`, `VerifiedAt` non-null; the internal token's `TokenString` parses as a valid JWT with `sub == userId.Value`, `iss == "https://identity.honeydrunk"` (or whatever the test config sets), `exp <= now + 5 minutes` (TTL cap respected).

Add a second smoke for the deletion path: signup → erase → assert directory entry status is `Deleted`, `InMemoryIdentityDeletionFanout` recorded the call, `DeletionIntent` events were emitted to the configured consumer list. Satisfies the round-trip-proof requirement from ADR-0060 D12 Phase 1.

### Contract-surface canary — `tests/HoneyDrunk.Identity.Abstractions.Tests/`

- `ContractSurfaceTests` — reflection-based assertions that the six interfaces and seven records exist with the expected method counts / record-member counts. The CI api-compatibility canary is the load-bearing check; this test is a fast in-build sanity check.
- `UserIdShapeTests` — `UserId.New().Value.StartsWith("usr_")`, length == 30 (4 prefix + 26 ULID body).
- `PrincipalIdDiscriminatedTests` — round-trip each of `PrincipalId.User(UserId)` / `PrincipalId.Service(string)` / `PrincipalId.Agent(string)` through a pattern-match and assert the `Kind` enum exposes all three variants.

### CI workflows

All five workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows — mirror the `HoneyDrunk.Audit/.github/workflows/` setup.

- **`pr-core.yml`** — calls `pr-core.yml@main`, `dotnet-version: '10.0.x'`.
- **`api-compatibility.yml`** (D7 / invariant **{N-canary}**):

```yaml
name: API Compatibility (Abstractions)
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/HoneyDrunk.Identity.Abstractions/**'
      - 'Directory.Build.props'
jobs:
  abstractions-shape:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main
    with:
      project-path: src/HoneyDrunk.Identity.Abstractions/HoneyDrunk.Identity.Abstractions.csproj
```

- **`release.yml`** — `on: push: tags: [v*.*.*]`, calls `release.yml@main` with `enable-nuget-publish: true` and `nuget-api-key: ${{ secrets.NUGET_API_KEY }}`. No `secrets: inherit`. Tags are human-pushed per invariant 27.
- **`nightly-deps.yml` / `nightly-security.yml`** — thin callers; copy `with:`/`secrets:` blocks verbatim from `HoneyDrunk.Audit` or `HoneyDrunk.Auth`.

### `HoneyDrunk.Standards` wiring

Each `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets="all"` per invariant 26:

```xml
<ItemGroup>
  <PackageReference Include="HoneyDrunk.Standards" Version="*" PrivateAssets="all" />
</ItemGroup>
```

### Documentation

- **Repo `README.md`** — purpose statement, package matrix, link to active-work tracker, plus a `## For downstream consumers — minimal wiring` section showing `services.AddVault().AddData(...).AddHoneyDrunkAuditData().AddHoneyDrunkIdentity().AddSingleton<IExternalIdpClaimMapper, MyEntraAdapter>()`. Also a **`## Phase-1 honest limitation`** section naming three intentional gaps:
  1. **No external IdP adapter.** v0.1.0 ships the Abstractions + runtime + in-memory test fixtures; the Entra (or whichever IdP) adapter ships in Phase 2 with the first user-facing app's feature packet. The runtime requires a host-composed `IExternalIdpClaimMapper` — no real signup flow works against v0.1.0 directly.
  2. **No OAuth callback HTTP surface.** Identity at v0.1.0 is a library Node. The OAuth callback handler, JWKS endpoint, `/users/me` surface land when Identity becomes a deployable Container App in Phase 2/3.
  3. **Limited deletion fan-out.** `EraseAsync` ships the boundary + the in-memory loop + a single Communications `DeletionIntent` emission. The full per-consumer ack-collection workflow + IdentityMap relocation from Auth lands in Phase 3.

  Per memory `feedback_no_adr_in_docs`, the README does not cite ADR numbers in narrative paragraphs (the catalog rows do; that's metadata, not user-facing prose).
- **Repo `CHANGELOG.md`** — `## [0.1.0] - YYYY-MM-DD` entry. No `## Unreleased` at commit time per memory `feedback_no_unreleased_commits`.
- **Per-package `README.md`** + **`CHANGELOG.md`** — required by invariant 12 for both new packages.

## Affected Files

Entire repo is created from this packet. Notable new files:

- `HoneyDrunk.Identity.slnx`, `Directory.Build.props`, `README.md`, `CHANGELOG.md`, `.editorconfig`
- `src/HoneyDrunk.Identity.Abstractions/` — `.csproj`, six interface `.cs` files, seven record `.cs` files, two enum `.cs` files (`UserLifecycleStatus`, `DeletionAckStatus`), one record `.cs` file (`UserRecord`), `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.Identity/` — `.csproj`, `ServiceCollectionExtensions.cs`, five runtime impl `.cs` files (`DataUserDirectory`, `DataUserProfileStore`, `JwksInternalTokenIssuer`, `EventBasedIdentityDeletionFanout`, `DefaultIdentityHealth`), four storage entity `.cs` files (`UserRecordEntity`, `IdentityMapEntity`, `ExternalSubjectMapEntity`, `UserProfileEntity`), `IdentityOptions.cs`, `IdentityTelemetry.cs`, `README.md`, `CHANGELOG.md`
- `tests/HoneyDrunk.Identity.Abstractions.Tests/` — `.csproj`, `ContractSurfaceTests.cs`, `UserIdShapeTests.cs`, `PrincipalIdDiscriminatedTests.cs`
- `tests/HoneyDrunk.Identity.Tests/` — `.csproj`, `Fixtures/` (5 files), `DataUserDirectoryTests.cs`, `DataUserProfileStoreTests.cs`, `JwksInternalTokenIssuerTests.cs`, `EventBasedIdentityDeletionFanoutTests.cs`, `SmokeTests.cs`
- `.github/workflows/` — 5 workflow files (`pr-core.yml`, `release.yml`, `nightly-deps.yml`, `nightly-security.yml`, `api-compatibility.yml`)

## NuGet Dependencies

Every new `.csproj` lists `HoneyDrunk.Standards` (`PrivateAssets="all"`) per invariant 26.

### `HoneyDrunk.Identity.Abstractions.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `TenantId` strong type (ADR-0026). Deliberate departure from zero-`HoneyDrunk` stance per ADR-0060 D4 / D13 — same exception as Audit (ADR-0031). |
| `NUlid` | ULID generation for `UserId.New()`. Leaf dependency; no transitive `HoneyDrunk` weight. If Kernel.Abstractions already exposes a ULID library indirectly, defer to that. |

### `HoneyDrunk.Identity.csproj`

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `ITelemetryActivityFactory`, `IGridContext`, `IGridContextAccessor`, `TenantId` |
| `HoneyDrunk.Kernel` | Optional — drop if `Kernel.Abstractions` suffices. Mirror Audit's `HoneyDrunk.Audit.Data` decision. |
| `HoneyDrunk.Data.Abstractions` | For `IRepository`, `IUnitOfWork` |
| `HoneyDrunk.Vault` | For `ISecretStore` (signing key) and `IConfigProvider` (identity options). |
| `HoneyDrunk.Auth.Abstractions` | For `IAuthorizationPolicy` reuse on directory lifecycle gates per ADR-0060 D13 |
| `HoneyDrunk.Audit.Abstractions` | For `IAuditLog` emission per ADR-0060 D13 / invariant 47 |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | DI helpers |
| `Microsoft.Extensions.Hosting.Abstractions` | Startup hook |
| `Microsoft.Extensions.Logging.Abstractions` | Logger contracts |
| `Microsoft.Extensions.Options.ConfigurationExtensions` | Bind options |
| `System.IdentityModel.Tokens.Jwt` | JWT signing for `IInternalTokenIssuer` |
| `Microsoft.IdentityModel.Tokens` | Token signing primitives — same family Auth uses for validation |

Project reference: `HoneyDrunk.Identity.Abstractions`.

### Test projects

`HoneyDrunk.Standards` (`PrivateAssets="all"`), `Microsoft.NET.Test.Sdk`, `xunit`, `xunit.runner.visualstudio`, `Microsoft.Extensions.DependencyInjection`, `AwesomeAssertions` (per ADR-0047). Project refs: `Abstractions.Tests` → `Abstractions`; `Identity.Tests` → both.

## Boundary Check

- [x] All work inside `HoneyDrunk.Identity`. No other Grid repos edited.
- [x] `HoneyDrunk.Identity.Abstractions` carries exactly ONE `HoneyDrunk.*` ref: `HoneyDrunk.Kernel.Abstractions` (for `TenantId`). Plus `NUlid` for ULID generation; no other Grid-runtime refs.
- [x] `HoneyDrunk.Identity` references Abstractions (project), Kernel.Abstractions, Data.Abstractions, Vault, Auth.Abstractions, Audit.Abstractions. No `HoneyDrunk.Pulse` (telemetry is one-way via Kernel's factory).
- [x] No secrets in code; signing key resolved via `ISecretStore` per Invariants 8/9.
- [x] No credential storage — Identity stores zero passwords, passkeys, or OAuth refresh tokens per ADR-0060 D2.
- [x] No JWT validation — the runtime issues but never validates (Auth validates per Invariant 10).
- [x] `IExternalIdpClaimMapper` is **not** auto-registered by `AddHoneyDrunkIdentity()` — the host composes its implementation. v0.1.0 ships only the in-memory test fixture.
- [x] Records drop `I` (`UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck`, `UserRecord`); interfaces keep it (`IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, `IIdentityHealth`).
- [x] Fixtures `internal` to test project; not packaged at v0.1.0.
- [x] Scaffold does NOT include: Entra adapter (Phase 2), OAuth callback HTTP surface (Phase 2/3), full deletion fan-out workflow (Phase 3), IdentityMap relocation from Auth (Phase 3), Container App / managed identity / Key Vault (deferred to first deployable host).
- [x] No documentation describes the Phase-1 scaffold as production-ready for signup flows. The README's `## Phase-1 honest limitation` section is explicit.

## Acceptance Criteria

- [ ] `HoneyDrunk.Identity.slnx` builds clean from a fresh clone via `dotnet build` with no warnings (warnings-as-errors).
- [ ] D4 public surface present in `HoneyDrunk.Identity.Abstractions` with XML documentation per invariant 13: `IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, `IIdentityHealth`, plus the records `UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck`, `UserRecord`, and the enums `UserLifecycleStatus`, `DeletionAckStatus`. Records and enums drop the `I` prefix; interfaces keep it.
- [ ] `HoneyDrunk.Identity.Abstractions` has exactly ONE `HoneyDrunk.*` PackageReference: `HoneyDrunk.Kernel.Abstractions`. Per ADR-0060 D4 / D13's permitted exception (same as Audit per ADR-0031). No `HoneyDrunk.Kernel` runtime ref; no `HoneyDrunk.Data*` / `HoneyDrunk.Vault*` / `HoneyDrunk.Pulse*` / `HoneyDrunk.Auth*` / `HoneyDrunk.Audit*` refs. Constitutional invariant **{N-coupling}** (downstream Abstractions-only coupling) is satisfied — Abstractions stay near-minimal.
- [ ] `UserId` is a `readonly record struct` with `Value` (string), `New()` factory (returns `usr_` + 26-char ULID), `Empty` static property, `IsEmpty` instance property, and `ToString()` returning the wrapped string. Asserted by `UserIdShapeTests` (the `Value` starts with `usr_` and has length 30).
- [ ] `PrincipalId` is a discriminated record with three variants: `User(UserId)`, `Service(string)`, `Agent(string)`. Asserted by `PrincipalIdDiscriminatedTests`.
- [ ] `IInternalTokenIssuer.IssueAsync` hard-caps the TTL at 5 minutes per ADR-0060 D6. Asserted by `JwksInternalTokenIssuerTests` (callers passing TTL > 5 min get a token with `exp <= now + 5 min`).
- [ ] `JwksInternalTokenIssuer` resolves the signing key via `ISecretStore.GetSecretAsync(name)` where `name` is sourced from `IdentityOptions.InternalTokenSigningKeyName` (default `identity:internal-token-signing-key`). **No hardcoded key in source.** Constitutional invariants 8 (secret values never appear in logs) and 9 (Vault is the only source of secrets) are honored.
- [ ] `DataUserDirectory`, `DataUserProfileStore`, `JwksInternalTokenIssuer`, `EventBasedIdentityDeletionFanout`, `DefaultIdentityHealth`, `IdentityTelemetry` are all registered as `Singleton` in `AddHoneyDrunkIdentity()`. `IExternalIdpClaimMapper` is **not** registered (host-composed per ADR-0060 D2 / D4).
- [ ] `DataUserDirectory` and `DataUserProfileStore` resolve `IGridContext` via `IGridContextAccessor.GridContext` (ambient per-call), **not** via direct `IGridContext` ctor injection (captive-dep avoidance — same pattern as Audit).
- [ ] `DataUserDirectory` and friends resolve `IRepository<...>` / `IUnitOfWork` via `IServiceScopeFactory.CreateAsyncScope()` per call (Singletons resolving Scoped abstractions).
- [ ] `DataUserDirectory` emits `AuditEntry` records via `IAuditLog` for `UserCreated`, `UserVerified`, `UserLocked`, `UserUnlocked`, `UserErased` events. `JwksInternalTokenIssuer` emits sampled `InternalTokenIssued` events. Per ADR-0060 D13 / invariant 47.
- [ ] `IAuditLog` injection is **optional** at the DI-resolution layer — if no `IAuditLog` is registered, Identity resolves a no-op stub and logs a `::warning::` at startup. Same pattern as Auth's audit emission per ADR-0031 packet 04. (Production hosts must register `IAuditLog`; the no-op stub is a build-passing safety net.)
- [ ] `EventBasedIdentityDeletionFanout.EraseAsync` is idempotent end-to-end per ADR-0042 — re-running with the same `(UserId, correlationId)` produces the same deletions without double-execution. Asserted by `EventBasedIdentityDeletionFanoutTests`.
- [ ] `EventBasedIdentityDeletionFanout.EraseAsync` at v0.1.0 (1) marks the directory entry deleted, (2) deletes the IdentityMap row, (3) emits `UserErased` to Audit, (4) emits `DeletionIntent` events for the registered consumer list. **Full per-consumer ack-collection is Phase 3**; v0.1.0 ships the boundary + in-memory test loop.
- [ ] `IdentityOptions` is bound via `IConfigProvider` against the `Identity:*` config namespace. No hardcoded issuer, audience, signing-key name, or default TTL in source.
- [ ] The scaffold's `README.md` includes a "Phase-1 honest limitation" section that explicitly states v0.1.0 ships the Abstractions + runtime + in-memory test fixtures only; no external IdP adapter, no OAuth callback HTTP surface, limited deletion fan-out. No language describing v0.1.0 as production-ready for signup flows appears anywhere in the repo.
- [ ] In-memory fixtures `InMemoryUserDirectory`, `InMemoryUserProfileStore`, `InMemoryInternalTokenIssuer`, `InMemoryExternalIdpClaimMapper`, `InMemoryIdentityDeletionFanout` exist under `tests/HoneyDrunk.Identity.Tests/Fixtures/` with `internal` visibility. **No `src/HoneyDrunk.Identity.Testing/` project exists** — the fixtures are not packaged at v0.1.0.
- [ ] `SmokeTests.SignupFlow_RoundTripsThroughIdentityBoundary` passes, proving the contracts round-trip through the in-memory fixtures end-to-end (per ADR-0060 D12 Phase 1).
- [ ] All five `.github/workflows/*.yml` files present and reference `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/*@main`.
- [ ] `api-compatibility.yml` runs on PR. On the scaffolding PR itself the workflow runs against an absent `main` baseline and reports `status: skipped` per the existing missing-baseline path — that is correct first-build behavior. **Verify post-merge** by opening a throwaway PR that removes a method from `IUserDirectory` (or modifies the `UserId` record-struct shape); the workflow must fail with breaking-changes-detected. Revert the throwaway PR after observation.
- [ ] `pr-core.yml` passes on the initial scaffolding PR (build + tests + analyzers + dependency scan + secret scan).
- [ ] Repo-level `CHANGELOG.md` has a `## [0.1.0] - YYYY-MM-DD` entry covering the scaffold (per invariants 12, 27, and memory `feedback_no_unreleased_commits` — no `## Unreleased` block at commit time).
- [ ] Per-package `CHANGELOG.md` files each have their own `## [0.1.0]` entry naming the package's specific introductions (per invariants 12 and 27).
- [ ] Repo-level `README.md` and per-package `README.md` files all present per invariant 12.
- [ ] Test suite runs and passes — minimum coverage: `ContractSurfaceTests` (reflection on Abstractions surface), `UserIdShapeTests`, `PrincipalIdDiscriminatedTests`, `DataUserDirectoryTests` (lifecycle transitions + audit emission), `DataUserProfileStoreTests` (read/write), `JwksInternalTokenIssuerTests` (issuance, TTL hard-cap, signing-key resolution via `ISecretStore`), `EventBasedIdentityDeletionFanoutTests` (idempotency, emission to consumer list), `SmokeTests` (round-trip via in-memory fixtures).
- [ ] Both projects in the solution carry the same `Version` (0.1.0), excluding test projects (invariant 27).
- [ ] Manual confirmation that pushing tag `v0.1.0` triggers `release.yml` and produces NuGet packages for both `src/*` projects (do not actually push the tag — verify the workflow exists and a tag-push trigger is configured).
- [ ] **No `.github/dependabot.yml` file exists.** Per ADR-0009, dependency-scanning lives in the nightly workflows.
- [ ] **`AuditEntry.TenantId` (when Identity emits to Audit) is the Kernel `TenantId` strong type** per ADR-0026. Identity passes `IGridContextAccessor.GridContext.TenantId` directly — no stringification.
- [ ] **Repo `README.md` includes a `## For downstream consumers — minimal wiring` section** showing the host-side `services.AddVault().AddData(...).AddHoneyDrunkAuditData().AddHoneyDrunkIdentity().AddSingleton<IExternalIdpClaimMapper, MyEntraAdapter>()` snippet, copy-pasteable. This is load-bearing for the first user-facing app's signup packet (Phase 2).
- [ ] **The README does NOT cite "ADR-0060" by number in narrative paragraphs.** Per memory `feedback_no_adr_in_docs`. (Runtime metadata references — catalog entries, frontmatter — are fine.)

## Human Prerequisites

- [ ] Packet 03 of this initiative complete — `HoneyDrunkStudios/HoneyDrunk.Identity` repo exists on GitHub with org-default branch protection, labels seeded, OIDC federated credential wired, and the local working tree cloned at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Identity/`.
- [ ] Packet 02 of this initiative merged — the four new Identity invariants exist in `constitution/invariants.md` so this packet's acceptance criteria reference them by number. **This packet's source file uses `{N-ownership}`, `{N-issuance}`, `{N-coupling}`, `{N-canary}` placeholders** for the four Identity-related invariant numbers; substitute the real numbers in place pre-push under invariant 24's pre-filing carve-out, **after** packet 02 merges and the assigned numbers are known. Hardcoding 54/55/56/57 is wrong if the high-water mark moved between scoping and packet 02's edit time.
- [ ] Packet 01 of this initiative merged — the `repos/HoneyDrunk.Identity/` context folder is registered and `honeydrunk-identity` is in `catalogs/nodes.json`; the ADR-0050 amendment is on disk; the Auth context files are amended.
- [ ] After this packet's PR merges, push tag `v0.1.0` from `main` to trigger the first NuGet publish. Tags are human-pushed per invariant 27.
- [ ] **`NUGET_API_KEY` repository (or org-level) secret is available to the `HoneyDrunk.Identity` repo before `v0.1.0` is tagged.** Org-level `NUGET_API_KEY` shared with other HoneyDrunk repos publishing to nuget.org is the standard approach — verify it's bound to this repo before tagging.
- [ ] **Branch protection sequencing.** Branch protection on `main` was set by packet 03 requiring only `pr-core / core` for the initial scaffolding PR. After the throwaway breaking-change PR confirms the canary fires post-merge, add `api-compatibility / abstractions-shape` to required checks in a follow-up branch-protection update.
- [ ] **No Azure resource provisioning required for this packet.** HoneyDrunk.Identity is a library Node at Phase 1, not a deployable. The Identity Node's own dedicated managed identity (per ADR-0060 D9), the Key Vault `kv-hd-identity-{env}`, the Container App `ca-hd-identity-{env}`, and the App Configuration keys for `Identity:*` belong with whichever packet first deploys an Identity-composing host (Phase 2/3). The scaffold ships the *read* path and sensible defaults. Cross-link: [`infrastructure/walkthroughs/azure-provisioning-guide.md`](../../../../infrastructure/walkthroughs/azure-provisioning-guide.md) for when that work lands.
- [ ] After this packet's PR merges and `v0.1.0` ships, file a small follow-up to add `HoneyDrunk.Identity` to the grid-health aggregator's watched-repos list in `HoneyDrunk.Actions` — only if the aggregator does not auto-discover from `catalogs/nodes.json`. Verify which behavior is in place at the time this prereq is being checked.
- [ ] After this packet's PR merges, file a SonarCloud onboarding follow-up packet for `HoneyDrunk.Identity` modeled on the closest match in `generated/issue-packets/active/adr-0011-code-review-pipeline/`.
- [ ] After this packet's PR merges, file a follow-up packet to enable the OpenClaw/Codex reviewer on `HoneyDrunk.Identity` per ADR-0044 D1 (add `.honeydrunk-review.yaml` with `enabled: true`).

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `HoneyDrunk.Identity.Abstractions` takes a single permitted exception: `HoneyDrunk.Kernel.Abstractions` for `TenantId`. This is the same exception ADR-0031 took for Audit and is justified by the same reasoning — every downstream consumer already has Kernel.Abstractions in its closure, so no new transitively-pinned package.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. — `JwksInternalTokenIssuer` traces the signing-key *name* (e.g., `identity:internal-token-signing-key`), never the value. Audit emission for `InternalTokenIssued` traces the `PrincipalId`, the token's `jti`/`exp`, and the signing-key *name* — never the token string itself.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. — `JwksInternalTokenIssuer` resolves the signing key via `ISecretStore.GetSecretAsync(name)`. No `Environment.GetEnvironmentVariable`, no `IConfiguration[]` reads for the key value.

> **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Preserved by this scaffold. Identity issues internal tokens; Auth validates them through its existing JWKS-based path. No new validation primitive lands in Auth. The combination of Invariant 10 and Identity invariant **{N-issuance}** (this packet's reference) pins the validation-vs-issuance boundary unambiguously: Auth validates everything; only Identity issues internal tokens.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — This packet stands up the new repo's solution and CI pipeline.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Every repo must have a repo-level CHANGELOG.md; every package directory must contain a README.md and (for packages with functional changes) a per-package CHANGELOG.md. — This packet creates both files for the repo and for each of the two new packages.

> **Invariant 13:** All public APIs have XML documentation. — Every interface, record, and enum in `HoneyDrunk.Identity.Abstractions` gets XML doc comments. Enforced by `HoneyDrunk.Standards` analyzers.

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — This packet's `{N-ownership}` / `{N-issuance}` / `{N-coupling}` / `{N-canary}` placeholders are substituted with the assigned numbers in place pre-push, after packet 02's PR merges. Packets 02 and 04 cannot be filed in the same push.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. — See the §NuGet Dependencies section above.

> **Invariant 27:** All projects in a solution share one version and move together. — Both `src/*.csproj` files carry `Version 0.1.0`. Tags are human-pushed; agents never push tags.

> **Invariant 36:** Container App revision mode is `Multiple` with explicit traffic splitting on deploy. Single-revision mode is forbidden. — Not relevant to this scaffold (Identity at v0.1.0 is a library Node, not a deployable); flagged for the Phase-2/3 deployable-host packet.

> **Invariant 47:** Durable, attributable security, action, and data-change events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. — Identity is a first-class emitter. New event types (`UserCreated`, `UserVerified`, `UserLocked`, `UserUnlocked`, `UserErased`, `InternalTokenIssued` sampled) flow through `IAuditLog`.

> **Invariant 48:** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`. — Identity is a downstream consumer of Audit; the runtime references `HoneyDrunk.Audit.Abstractions` only. No `HoneyDrunk.Audit.Data` reference.

> **Invariant {N-ownership}** (assigned by packet 02 of this initiative, default 54): **User identity records, the `IdentityMap`, and the user profile live in `HoneyDrunk.Identity`, not in `HoneyDrunk.Auth`.** — This scaffold is the implementation site for that invariant. The `IdentityMap` table relocation from Auth happens in Phase 3 (a follow-up packet); this scaffold ships the new home so the relocation has a destination.

> **Invariant {N-issuance}** (assigned by packet 02, default 55): **Internal-token issuance for service-to-service `UserPrincipal` flows is the exclusive responsibility of `HoneyDrunk.Identity.IInternalTokenIssuer`.** — `JwksInternalTokenIssuer` is the only implementation in the Grid; no other Node mints JWT bearer tokens for internal use. The 5-minute TTL hard-cap is the structural defense against compromise.

> **Invariant {N-coupling}** (assigned by packet 02, default 56): **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Identity.Abstractions`.** — This scaffold structures the package boundary to enforce that rule. Composition against `HoneyDrunk.Identity` is a host-time concern.

> **Invariant {N-canary}** (assigned by packet 02, default 57): **The HoneyDrunk.Identity Node CI must include a contract-shape canary for the full `HoneyDrunk.Identity.Abstractions` public surface.** — The `api-compatibility.yml` workflow is wired in this packet; the canary covers all six interfaces and all seven records from v0.1.0.

## Referenced ADR Decisions

**ADR-0060 D1 (Identity Node ownership):** HoneyDrunk.Identity is the Core sector's single Node owning the user record, the external-IdP seam, internal-token issuance, and account-deletion fan-out. This scaffold ships the foundation; the deployable host (Container App), the Entra adapter, and the full deletion fan-out land in subsequent phases.

**ADR-0060 D2 (Wrap external IdP, leading candidate Entra External ID):** Identity is a thin seam over an external IdP. The credential store lives in the IdP; Identity stores zero credentials. This scaffold ships the seam (`IExternalIdpClaimMapper`) and a test-only fixture; the Entra adapter ships in Phase 2 with the first user-facing app's feature packet. Vendor confirmation happens at that point.

**ADR-0060 D3 (UserId / PrincipalId / ExternalSubject shape):** `UserId` is a 26-char ULID prefixed `usr_`; `PrincipalId` is a discriminated wrapper over UserPrincipal / ServicePrincipal / AgentPrincipal per ADR-0051; `ExternalSubject` holds the IdP issuer + `sub` claim. The `IdentityMap` (relocated from Auth per the ADR-0050 amendment landed by packet 01) is the PII-concentrated table — Restricted/Sensitive PII per ADR-0049, T0 backup tier per ADR-0036.

**ADR-0060 D4 (Exposed contracts):** Six interfaces and seven records. The full surface is frozen at stand-up and protected by the contract-shape canary per D7.

**ADR-0060 D5 (Where the user profile lives):** In Identity's UserProfile table, not the external IdP. IdP migration is a re-keying operation, not a data migration. This scaffold ships `DataUserProfileStore` over `IRepository<UserProfileEntity>`.

**ADR-0060 D6 (Internal-token issuance — Identity issues, Auth validates):** Identity issues short-lived (≤ 5 min) internal JWT bearer tokens via `IInternalTokenIssuer`. Auth validates the tokens through its existing JWKS-based path. Invariant 10 holds: Auth still only validates. This scaffold ships `JwksInternalTokenIssuer` with the 5-minute TTL hard-cap.

**ADR-0060 D7 (Contract-shape canary):** A contract-shape canary is added to the Identity Node's CI; it fails the build if any of the six interfaces or seven records change shape without a corresponding version bump. This scaffold ships `api-compatibility.yml` scoped to `HoneyDrunk.Identity.Abstractions`.

**ADR-0060 D8 (Account-deletion fan-out and the user-level GDPR Art. 17 path):** `IIdentityDeletionFanout.EraseAsync` emits `DeletionIntent` to registered downstream consumers (v1 list: Communications). Each consumer responds with `DeletionAck`. Identity emits `UserErased` to Audit. Idempotent end-to-end per ADR-0042. This scaffold ships the boundary + in-memory test loop; the full per-consumer ack-collection workflow lands in Phase 3.

**ADR-0060 D9 (Identity Node has its own managed identity):** Identity runs under its own dedicated managed identity at Phase 2/3 when the deployable host lands. The Key Vault namespace `kv-hd-identity-{env}` holds the internal-token signing key (tier-1 rotation per ADR-0006). Not in scope for this scaffold; the runtime is library-shaped.

**ADR-0060 D11 (Charter sanity check):** Standing up the boundary now is foundation work that supports the workshop; the Entra-vendor confirmation (the deferable part) is deferred to Phase 2. This scaffold is the foundation half.

**ADR-0060 D12 (Phased rollout):** Phase 1 = scaffold packet (this packet). Phase 2 = first user-facing app's feature packet (Hearth signup) lands the IdP-vendor confirmation and the first concrete `IExternalIdpClaimMapper`. Phase 3 = full deletion fan-out + IdentityMap relocation from Auth + Studios admin-console pages. Phase 4 = cross-app `UserId`-stability canary. Phase 5 = second `IExternalIdpClaimMapper` implementation.

**ADR-0060 D13 (Relationship to existing ADRs):** Invariant 10 preserved; ADR-0005 (per-Node Key Vault `kv-hd-identity-{env}`); ADR-0006 (tier-1 rotation for signing key); ADR-0015 (Container App deployable in Phase 2/3); ADR-0026 (TenantId strong type); ADR-0028 (DeletionIntent as Service Bus domain event in Phase 3); ADR-0030 (Audit first-class emitter); ADR-0031 (Audit downstream coupling rule — `Identity` references `Audit.Abstractions` only); ADR-0042 (idempotency); ADR-0049 (IdentityMap is Restricted/Sensitive PII; T0 backup tier per ADR-0036); ADR-0050 (additive amendment landed by packet 01 — IdentityMap relocates from Auth to Identity); ADR-0051 (UserPrincipal is a PrincipalId variant); ADR-0057 (OAuth 2.1 with PKCE via external IdP in Phase 2).

## Dependencies

- `packet:01` — Architecture catalog registration + `repos/HoneyDrunk.Identity/` context folder + ADR-0050 amendment + Auth context amendments must be on `main` so the catalogs and the cross-references are correct when the scaffold lands.
- `packet:02` — Constitutional invariants `{N-ownership}` / `{N-issuance}` / `{N-coupling}` / `{N-canary}` must exist in `constitution/invariants.md` so this packet's acceptance criteria reference them by number. Packet 02 also substitutes this packet's placeholders pre-push (invariant 24's carve-out).
- `packet:03` — The GitHub repo must exist on `HoneyDrunkStudios` and the local working tree must be cloned at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Identity/` before scaffolding can run.

## Labels

`feature`, `tier-2`, `core`, `identity`, `scaffold`, `adr-0060`

## Agent Handoff

**Objective:** Bring `HoneyDrunk.Identity` from the empty post-creation state (only `.gitignore` + `LICENSE` + placeholder `README.md`) to first-shippable v0.1.0 per ADR-0060 D12 Phase 1. Land the solution, both packages, the D4 contract surface, the runtime implementations, the in-memory test fixtures, the smoke test, and the full CI pipeline including the contract-shape canary.

**Target:** HoneyDrunk.Identity, branch from `main`.

**Context:**
- Goal: Unblock the first user-facing app's signup flow (Hearth per PDR-0005) by shipping `HoneyDrunk.Identity.Abstractions 0.1.0` to NuGet. Hearth's signup packet then takes the PackageReference and wires its concrete `IExternalIdpClaimMapper` (likely Entra External ID).
- Feature: ADR-0060 standup initiative, Wave 2, Packet 04.
- ADRs: ADR-0060 (sole standup); ADR-0050 (additive amendment landed by packet 01); ADR-0051 (PrincipalId model); ADR-0026 (TenantId strong type); ADR-0030/0031 (Audit consumption boundary); ADR-0042 (idempotency for deletion fan-out); ADR-0005 (Vault for signing key + IConfigProvider for options).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01, 02, 03 of this initiative all merged / Done on The Hive.

**Constraints:**

- **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Auth's role in the Phase-2 token flow is validation only. Identity's `JwksInternalTokenIssuer` issues; Auth's `IJwtBearerValidator` validates through its existing JWKS-based path. No new validation primitive lands in Auth.
- **Invariant 8 / 9:** Secret values never appear in logs/traces/exceptions/telemetry; Vault is the only source of secrets. — The signing key is resolved via `ISecretStore.GetSecretAsync` by name; the name appears in logs/traces, the value never does.
- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages — with the permitted exception of `HoneyDrunk.Kernel.Abstractions` for `TenantId` per ADR-0060 D4 / D13 (same exception as Audit).
- **Invariant {N-coupling}** (default 56): Downstream Nodes take a runtime dependency only on `HoneyDrunk.Identity.Abstractions`. — Structure the package boundary so consumers can compile against Abstractions alone.
- **Invariant {N-canary}** (default 57): The HoneyDrunk.Identity Node CI must include a contract-shape canary for the full `HoneyDrunk.Identity.Abstractions` public surface. — `api-compatibility.yml` covers all six interfaces and all seven records (plus the supporting enums).
- **Records drop `I` prefix; interfaces keep it.** Per the Grid-wide naming rule.
- **`IExternalIdpClaimMapper` is NOT auto-registered.** The host composes its implementation. v0.1.0 ships only the in-memory test fixture (`InMemoryExternalIdpClaimMapper`).
- **No Entra adapter, no OAuth callback HTTP surface, no full deletion fan-out workflow, no IdentityMap relocation from Auth, no Container App / managed identity / Key Vault provisioning** in this scaffold. Those are Phase 2/3 follow-ups.
- **No documentation describes v0.1.0 as production-ready for signup flows.** The README's `## Phase-1 honest limitation` section is explicit.
- **No `## Unreleased` in CHANGELOG at commit time.** Per memory `feedback_no_unreleased_commits`, the initial commit lands under `## [0.1.0] - YYYY-MM-DD`. The tag push happens after merge.
- **No ADR numbers in README narrative.** Per memory `feedback_no_adr_in_docs`. Catalog rows and frontmatter cite ADRs; the README explains what the package does.

**Key Files:**
- `HoneyDrunk.Identity.slnx`, `Directory.Build.props`, top-level `README.md` / `CHANGELOG.md`
- `src/HoneyDrunk.Identity.Abstractions/` — six interface `.cs` files, seven record `.cs` files, two enum `.cs` files, `UserRecord.cs`, per-package README/CHANGELOG
- `src/HoneyDrunk.Identity/` — five runtime impl `.cs` files, four storage entity `.cs` files, `IdentityOptions.cs`, `IdentityTelemetry.cs`, `ServiceCollectionExtensions.cs`, per-package README/CHANGELOG
- `tests/HoneyDrunk.Identity.Abstractions.Tests/` and `tests/HoneyDrunk.Identity.Tests/`
- `.github/workflows/` — 5 thin-caller files

**Contracts:** This packet authors the full D4 contract surface (`IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, `IIdentityHealth` interfaces; `UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck`, `UserRecord` records; `UserLifecycleStatus`, `DeletionAckStatus` enums) plus the runtime implementations and the in-memory test fixtures. The contract-shape canary covers all of the Abstractions public surface from v0.1.0.
