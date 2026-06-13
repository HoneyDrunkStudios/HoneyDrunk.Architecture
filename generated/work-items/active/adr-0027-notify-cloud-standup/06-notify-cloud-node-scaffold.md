---
name: Repo Scaffold
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify.Cloud
labels: ["feature", "tier-2", "ops", "scaffolding", "new-node", "commercial", "adr-0027"]
dependencies: ["work-item:01", "work-item:02", "work-item:05"]
adrs: ["ADR-0027", "ADR-0026", "ADR-0019", "ADR-0015"]
accepts: ADR-0027
wave: 4
initiative: adr-0027-notify-cloud-standup
node: honeydrunk-notify-cloud
---

> **STATUS - superseded by NovOutbox (2026-06-13):** Retained for historical traceability only. Do not execute this `HoneyDrunk.Notify.Cloud` scaffold. Refile the scaffold against `HoneyDrunk.NovOutbox` with the five-contract surface (`INovOutboxGateway`, `INovOutboxApiKeyStore`, `NovOutboxTenantTier`, `NovOutboxApiKeyIssuance`, `NovOutboxSubmitResult`), the five-package layout including `HoneyDrunk.NovOutbox.AppHost`, no `src/` folder convention, and the Aspire-based AppHost decision from the NovOutbox bootstrap discussion.

# Feature: Stand up the HoneyDrunk.Notify.Cloud repo — solution, four packages, contracts, CI, Container Apps wiring

## Summary
Bring the empty `HoneyDrunk.Notify.Cloud` repo (private; created by packet 05) from zero to first-shippable state per ADR-0027 D13. Land the solution layout, four package families (`HoneyDrunk.Notify.Cloud.Abstractions`, `HoneyDrunk.Notify.Cloud`, `HoneyDrunk.Notify.Cloud.Billing.Stripe`, `HoneyDrunk.Notify.Cloud.Web`), the four D4 contracts inside `HoneyDrunk.Notify.Cloud.Abstractions`, the default `INotifyCloudGateway` wiring API-key-validation → rate-limit → tenant-context resolution → orchestration-delegation → billing-emission, an in-memory `INotifyCloudApiKeyStore` for tests, the Notify-Cloud-specific `ITenantRateLimitPolicy` implementation that replaces Kernel's `NoopTenantRateLimitPolicy` at host time, the Stripe billing-adapter stub implementing the Kernel `IBillingEventEmitter` interface, the Web placeholder (signup form scaffold + health endpoint), the full CI pipeline (PR core + release + nightly + security + contract-shape canary scoped to `HoneyDrunk.Notify.Cloud.Abstractions`), the proprietary LICENSE file (`LicenseRef-Proprietary`), and Container Apps deployment configuration referencing ADR-0015's reusable `job-deploy-container-app.yml` workflow targeting `ca-hd-notify-cloud-stg` in East US.

This is the substrate stand-up. It does not ship the actual Stripe webhook bridge, the full Web project surface, or the API key authentication middleware in Auth — those are explicit follow-ups per ADR-0027 D13's "scaffold packet does not include" list.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Notify.Cloud` (private — first private repo in the Grid)

## Motivation
ADR-0027 establishes *what* HoneyDrunk.Notify.Cloud is and what contracts it exposes. The repo is created by packet 05 (carrying only `.gitignore` and a placeholder README) but is otherwise empty — no `.slnx`, no projects, no CI, no contracts. Without this scaffold, PDR-0002's Phase 3 (Notify Cloud scaffold, weeks 10-14) cannot begin: there is no compile target for the Stripe billing-integration follow-up ADR, no production consumer for the Communications decision-log persistence ADR, and no concrete `INotifyCloudApiKeyStore` for the tenant onboarding workflow design doc to design against.

This packet is the unblocker. After it merges and a `0.1.0` tag lands, the entire Phase 3 follow-up surface becomes scopable: Stripe integration ADR, API key authentication ADR, Communications decision-log persistence ADR, tenant onboarding workflow doc, Web project full-surface packets.

The scaffold is intentionally bundled into one packet because:

- The Node has four packages, all of which must compile together to give the contract-shape canary a coherent baseline.
- The four D4 contracts must all land in the first commit so the canary baseline against `HoneyDrunk.Notify.Cloud.Abstractions` is complete from PR #1.
- The default `INotifyCloudGateway` wiring threads through four cross-Node consumers (Communications, Notify, Auth, Kernel multi-tenant primitives) — fragmenting that across packets creates ordering hazards.
- Per the user's standing convention, a new Node's scaffold work bundles into one packet rather than fragmenting across many.

## Proposed Implementation

### Repository layout

```
HoneyDrunk.Notify.Cloud/
├── HoneyDrunk.Notify.Cloud.slnx
├── Directory.Build.props
├── CHANGELOG.md
├── README.md
├── LICENSE                                  (LicenseRef-Proprietary; all rights reserved)
├── .editorconfig                            (from HoneyDrunk.Standards)
├── .gitignore                               (preserved from packet 05; VisualStudio template)
├── .github/
│   └── workflows/
│       ├── pr-core.yml                      (calls Actions/pr-core.yml)
│       ├── release.yml                      (calls Actions/release.yml — private feed, not public NuGet per ADR-0027)
│       ├── nightly-deps.yml                 (calls Actions/nightly-deps.yml)
│       ├── nightly-security.yml             (calls Actions/nightly-security.yml)
│       ├── api-compatibility.yml            (calls Actions/job-api-compatibility.yml — D8 canary)
│       └── deploy-stg.yml                   (calls Actions/job-deploy-container-app.yml per ADR-0015 — first deploy target)
├── src/
│   ├── HoneyDrunk.Notify.Cloud.Abstractions/
│   │   ├── HoneyDrunk.Notify.Cloud.Abstractions.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── INotifyCloudGateway.cs
│   │   ├── INotifyCloudApiKeyStore.cs
│   │   ├── NotifyCloudTenantTier.cs                  (record, no I prefix)
│   │   ├── ApiKeyIssuance.cs                         (record, no I prefix)
│   │   └── (supporting record/enum types — see "Contract details")
│   ├── HoneyDrunk.Notify.Cloud/
│   │   ├── HoneyDrunk.Notify.Cloud.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   ├── ServiceCollectionExtensions.cs           (AddHoneyDrunkNotifyCloud)
│   │   ├── Gateway/
│   │   │   └── DefaultNotifyCloudGateway.cs         (the full pipeline)
│   │   ├── ApiKeys/
│   │   │   └── HashingNotifyCloudApiKeyStore.cs     (production-shape implementation; backend is hash-table-in-Data per D9 default)
│   │   ├── RateLimiting/
│   │   │   └── TierDrivenTenantRateLimitPolicy.cs   (replaces Kernel's NoopTenantRateLimitPolicy at host time)
│   │   ├── Billing/
│   │   │   └── BillingEventEmissionTail.cs          (post-dispatch tail wired into the worker pipeline)
│   │   └── Telemetry/
│   │       └── NotifyCloudTelemetry.cs              (uses ITelemetryActivityFactory; GridContext propagation)
│   ├── HoneyDrunk.Notify.Cloud.Billing.Stripe/
│   │   ├── HoneyDrunk.Notify.Cloud.Billing.Stripe.csproj
│   │   ├── README.md
│   │   ├── CHANGELOG.md
│   │   └── StripeBillingEventEmitter.cs             (stub: implements Kernel IBillingEventEmitter; throws NotImplementedException on EmitAsync with TODO pointing at the Stripe billing integration ADR follow-up)
│   └── HoneyDrunk.Notify.Cloud.Web/
│       ├── HoneyDrunk.Notify.Cloud.Web.csproj
│       ├── README.md
│       ├── CHANGELOG.md
│       ├── Program.cs                                (ASP.NET Core minimal API host + Blazor Server registration per ADR-0027 D3 default)
│       ├── Pages/
│       │   └── Health.razor                          (basic health endpoint; placeholder)
│       └── Components/
│           └── SignupPlaceholder.razor               (scaffold-only signup form; non-functional)
└── tests/
    ├── HoneyDrunk.Notify.Cloud.Abstractions.Tests/   (compile-only smoke tests)
    ├── HoneyDrunk.Notify.Cloud.Tests/                (DefaultNotifyCloudGateway end-to-end smoke; HashingNotifyCloudApiKeyStore tests; TierDrivenTenantRateLimitPolicy tests)
    ├── HoneyDrunk.Notify.Cloud.Billing.Stripe.Tests/ (smoke tests; stub asserts NotImplementedException with the right TODO)
    └── HoneyDrunk.Notify.Cloud.Web.Tests/            (placeholder; minimal page-renders-without-error tests)
```

### Solution

`HoneyDrunk.Notify.Cloud.slnx` references all four `src/*` projects and all four `tests/*` projects. Solution-level `Directory.Build.props` sets:

```xml
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <LangVersion>latest</LangVersion>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <Authors>HoneyDrunk Studios</Authors>
    <Company>HoneyDrunk Studios</Company>
    <Copyright>Copyright (c) HoneyDrunk Studios. All rights reserved.</Copyright>
    <PackageProjectUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Notify.Cloud</PackageProjectUrl>
    <RepositoryUrl>https://github.com/HoneyDrunkStudios/HoneyDrunk.Notify.Cloud</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
    <PublishRepositoryUrl>true</PublishRepositoryUrl>
    <IncludeSymbols>true</IncludeSymbols>
    <SymbolPackageFormat>snupkg</SymbolPackageFormat>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <PackageLicenseFile>LICENSE</PackageLicenseFile>
    <!-- Private feed only — these packages do NOT publish to public NuGet per ADR-0027 -->
  </PropertyGroup>

  <ItemGroup>
    <None Include="$(MSBuildThisFileDirectory)LICENSE" Pack="true" PackagePath="\" Visible="false" />
  </ItemGroup>

  <!-- Version applies to shipping projects only. Test projects are excluded from
       the solution-shared-version rule per invariant 27. -->
  <PropertyGroup Condition="'$(IsTestProject)' != 'true'">
    <Version>0.1.0</Version>
  </PropertyGroup>
</Project>
```

Per invariant 27, every src project carries the same `Version` (0.1.0 for this initial release). Test projects are excluded via the `Condition="'$(IsTestProject)' != 'true'"` wrapper. The proprietary LICENSE is packed into every `.nupkg` via the `<None Include=... Pack="true">` block.

### `LICENSE` — proprietary

Create a `LICENSE` file at the repo root with proprietary content:

```
HoneyDrunk.Notify.Cloud
Copyright (c) 2026 HoneyDrunk Studios. All rights reserved.

All rights reserved. This software is the proprietary property of HoneyDrunk Studios.
No part of this repository may be copied, redistributed, or used without prior
written permission of HoneyDrunk Studios.

For licensing inquiries, contact oleg@honeydrunkstudios.com.
```

NuGet license identification: the `Directory.Build.props` declares `<PackageLicenseFile>LICENSE</PackageLicenseFile>` and the file is packed. Some NuGet tooling may also benefit from `<PackageLicenseExpression>LicenseRef-Proprietary</PackageLicenseExpression>` — but since `PackageLicenseFile` and `PackageLicenseExpression` cannot coexist, use the `PackageLicenseFile` form for clarity. The license-text inclusion in the package is the authoritative declaration.

### Contract details — `HoneyDrunk.Notify.Cloud.Abstractions`

All four D4 contracts. Records drop the `I` prefix; interfaces keep it (Grid-wide naming rule).

**Abstractions reference policy.** Per ADR-0027 D3, `HoneyDrunk.Notify.Cloud.Abstractions` has zero runtime dependencies beyond the three `*.Abstractions` packages the ADR explicitly allows:

- `HoneyDrunk.Kernel.Abstractions` — for `TenantId` (the strong ULID-backed record-struct type from `HoneyDrunk.Kernel.Abstractions.Identity` per ADR-0026 D1). `TenantId` is the canonical Grid tenant identifier; the strict-Abstractions stance from ADR-0016 / ADR-0017 / ADR-0019 packets does NOT apply here because ADR-0027 D3 explicitly enumerates this reference as permitted, and the existing Communications.Abstractions package (the most-recent sibling) already PackageReferences `HoneyDrunk.Kernel.Abstractions`.
- `HoneyDrunk.Notify.Abstractions` — permitted per ADR-0027 D3 for any Notify-side contract surfaces the gateway needs to reference at compile time (diagnostic / smoke-test paths only per ADR-0027 D5).
- `HoneyDrunk.Communications.Abstractions` — permitted per ADR-0027 D3 for `MessageIntent` / `ICommunicationOrchestrator` surfaces.

What stays string-typed in v0.1.0 (with a follow-up flag, not as a permanent decision):

- `ApiKeyId` / `KeyId` — strings at v0.1.0. The canonical TODO lives on the `ApiKeyMetadata.KeyId` field declaration (see below); no other TODO redundancy is needed elsewhere in the contracts. The API key authentication ADR follow-up settles whether to promote to a record-struct identifier on a level with `TenantId`.

What is consumed from Kernel at the runtime layer but **not** declared in Notify Cloud Abstractions (per ADR-0027 D4 and ADR-0026):

- `ITenantRateLimitPolicy`, `TenantRateLimitDecision` — live in `HoneyDrunk.Kernel.Abstractions.Tenancy`. The runtime package implements `ITenantRateLimitPolicy` and consumes `TenantRateLimitDecision`; Notify Cloud Abstractions does NOT redeclare either type.
- `IBillingEventEmitter`, `BillingEvent` — live in `HoneyDrunk.Kernel.Abstractions.Tenancy`. The Stripe provider package implements `IBillingEventEmitter`; Notify Cloud Abstractions does NOT redeclare either type.

`TenantId` (the type itself, not the policy/decision surrounding it) is referenced by `INotifyCloudGateway` and `INotifyCloudApiKeyStore` and is part of the four-contract public surface. Field types use the strong `TenantId` type, not `string`.

```csharp
// INotifyCloudGateway.cs
namespace HoneyDrunk.Notify.Cloud.Abstractions;

using HoneyDrunk.Kernel.Abstractions.Identity;   // TenantId per ADR-0026 D1

public interface INotifyCloudGateway
{
    Task<NotifyCloudGatewayResult> ProcessAsync(
        NotifyCloudGatewayRequest request,
        CancellationToken cancellationToken = default);
}

public sealed record NotifyCloudGatewayRequest(
    string ApiKey,                            // raw key from the request header
    TenantId? TenantIdHint,                   // strong type per ADR-0026; nullable because `default(TenantId)` collides with `TenantId.Internal` (both have Ulid.Empty) — a `null` hint means "no hint", not "Internal tenant". The runtime cross-checks against the TenantId resolved from the validated key.
    string CapabilityKey,                     // which delivery surface — e.g., "send.email" or "send.sms"
    string PayloadJson,                       // JSON-encoded request payload, forwarded to ICommunicationOrchestrator
    string CallerCorrelationId);              // string mirror; the runtime reconciles against IGridContext.CorrelationId. CorrelationId stays string for v0.1.0 — promoting the Kernel CorrelationId record-struct into Abstractions is a separate Grid-wide decision, not bundled with this Node's stand-up.

public sealed record NotifyCloudGatewayResult(
    bool Success,
    string? DeliveryId,                       // Communications-generated delivery id on success
    NotifyCloudGatewayError? Error);

public sealed record NotifyCloudGatewayError(
    NotifyCloudGatewayErrorCode Code,
    string Message,
    int? RetryAfterSeconds);                  // populated on 429 RateLimited only

public enum NotifyCloudGatewayErrorCode
{
    /// <summary>API key is invalid or expired.</summary>
    Unauthorized = 0,
    /// <summary>API key is valid but the tenant has exceeded its rate-limit ceiling.</summary>
    RateLimited = 1,
    /// <summary>Capability key is unknown or the tenant's tier does not include it.</summary>
    CapabilityNotAvailable = 2,
    /// <summary>Payload JSON does not validate against the expected shape for this capability.</summary>
    InvalidPayload = 3,
    /// <summary>Communications orchestrator denied the send (e.g., recipient opt-out, cadence violation).</summary>
    OrchestrationDenied = 4,
    /// <summary>Internal error in the orchestration or delivery pipeline.</summary>
    InternalError = 5,
    /// <summary>The request was cancelled before completion.</summary>
    Cancelled = 6,
}
```

The `Code` field is a typed enum (not a string with a comment listing values) so the contract-shape canary catches accidental additions/removals as breaking changes. Each enum member carries XML doc summarizing when the runtime emits it.

```csharp
// INotifyCloudApiKeyStore.cs
// TenantId is the Kernel strong type per ADR-0026 D1.
// The canonical KeyId-stays-string TODO lives on ApiKeyMetadata.KeyId below.
using HoneyDrunk.Kernel.Abstractions.Identity;   // TenantId per ADR-0026 D1

public interface INotifyCloudApiKeyStore
{
    /// <summary>
    /// Issue a new API key for the specified tenant. The plaintext key in the returned
    /// ApiKeyIssuance is the only time the raw key material is ever exposed to a caller;
    /// the store persists only the salted hash and the metadata.
    /// </summary>
    Task<ApiKeyIssuance> IssueAsync(
        TenantId tenantId,
        string label,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Validate a raw API key against the store. Returns the bound TenantId (Kernel strong type)
    /// on success, or null if the key is unknown, expired, or revoked.
    /// </summary>
    Task<TenantId?> ValidateAsync(
        string apiKey,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Revoke an issued key by its id. Subsequent ValidateAsync calls for the raw key
    /// return null.
    /// </summary>
    Task RevokeAsync(
        string keyId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// List the metadata (no raw key, no hash) for all keys issued to a tenant.
    /// Used by the Web project's API key management UI.
    /// </summary>
    Task<IReadOnlyList<ApiKeyMetadata>> ListForTenantAsync(
        TenantId tenantId,
        CancellationToken cancellationToken = default);
}

public sealed record ApiKeyMetadata(
    // CANONICAL TODO (API key authentication ADR follow-up): `KeyId` is `string` at v0.1.0. Promotion
    // to a record-struct `ApiKeyId` on a level with `TenantId` is settled by the API key authentication
    // ADR jointly with the Auth-side middleware shape. This is the one and only place this TODO lives —
    // ApiKeyIssuance.KeyId, INotifyCloudApiKeyStore.RevokeAsync(string keyId), and ApiKeyRecord (runtime
    // persistence record) all reference this decision point but do not repeat the TODO comment.
    string KeyId,
    TenantId TenantId,                        // strong type per ADR-0026
    string Label,
    DateTimeOffset IssuedAt,
    DateTimeOffset? RevokedAt);
```

```csharp
// NotifyCloudTenantTier.cs (record — no I prefix)
public sealed record NotifyCloudTenantTier(
    string Name,                                  // "Free", "Starter", "Pro"
    int EventsPerMonth,                           // ceiling (e.g., 1000 for Free, 10000 for Starter)
    IReadOnlyList<string> EnabledChannels,        // which delivery channels are available — "email", "sms", "webhook". IReadOnlyList per Grid convention (matches BillingEvent.Attributes IReadOnlyDictionary style); mutable arrays on public records are a footgun.
    bool BringYourOwnProviderKey);                // whether the tenant can bring their own Resend/Twilio key (Pro tier)
```

The tier is the source of truth that the runtime's `TierDrivenTenantRateLimitPolicy` consumes to derive per-tenant limits. Tier definitions are sourced from Azure App Configuration via `IConfigProvider` (not hardcoded in code per the local invariant 5).

```csharp
// ApiKeyIssuance.cs (record — no I prefix; returned exactly once at issuance)
// KeyId stays string at v0.1.0 — see the canonical TODO on ApiKeyMetadata.KeyId.
using HoneyDrunk.Kernel.Abstractions.Identity;   // TenantId per ADR-0026 D1

public sealed record ApiKeyIssuance(
    string KeyId,                            // stable id; safe to persist and reference. v0.1.0 string.
    string PlaintextKey,                     // only at this moment — never persisted, never returned again
    TenantId TenantId,                       // the tenant this key is bound to — Kernel strong type per ADR-0026
    DateTimeOffset IssuedAt);
```

Local invariant 3 in `repos/HoneyDrunk.Notify.Cloud/invariants.md` (landed by packet 01) requires: "API keys are stored only as salted hashes; raw key material is returned exactly once at issuance time." The `PlaintextKey` field on `ApiKeyIssuance` is the one-time-only carrier; after the issuance call returns, the runtime has no path to retrieve the raw key again.

### Primitives consumed (NOT redeclared here)

Per ADR-0027 D4 and ADR-0026, the following live in Kernel and are **consumed**, not redeclared in Notify Cloud Abstractions:

- `TenantId` — lives in `HoneyDrunk.Kernel.Abstractions.Identity` (record-struct, ULID-backed). The four D4 contracts use this strong type directly. `HoneyDrunk.Notify.Cloud.Abstractions` PackageReferences `HoneyDrunk.Kernel.Abstractions` to bring the type in. Per ADR-0027 D3, this is one of the three permitted Abstractions references for this package.
- `TenantId.Internal` sentinel — same package. Notify Cloud's gateway (`DefaultNotifyCloudGateway` steps 1a, 8) rejects Internal at the validation step and skips billing emission for Internal as defense-in-depth; `TierDrivenTenantRateLimitPolicy.EvaluateAsync` returns `Outcome: Allow` immediately when `tenantId.IsInternal`. Note that Kernel's `NoopBillingEventEmitter` does NOT itself short-circuit on Internal — it null-checks and returns — so the gateway-side guard is where the Internal-skip discipline lives, not at the emitter implementation.
- `ITenantRateLimitPolicy` and `TenantRateLimitDecision` — live in `HoneyDrunk.Kernel.Abstractions.Tenancy`. These are runtime-composition surfaces; the Notify Cloud runtime package implements `ITenantRateLimitPolicy` but `HoneyDrunk.Notify.Cloud.Abstractions` does NOT reference these types directly.
- `IBillingEventEmitter` and `BillingEvent` — live in `HoneyDrunk.Kernel.Abstractions.Tenancy`. The Stripe provider package implements `IBillingEventEmitter`; `HoneyDrunk.Notify.Cloud.Abstractions` does NOT reference these types directly.

`HoneyDrunk.Notify.Cloud.Abstractions.csproj` therefore PackageReferences `HoneyDrunk.Kernel.Abstractions` (for `TenantId`). The runtime package (`HoneyDrunk.Notify.Cloud`) **also** PackageReferences `HoneyDrunk.Kernel.Abstractions` — not the Kernel runtime — for `IGridContext`, `ITelemetryActivityFactory`, the rate-limit / billing-event policy surfaces in `HoneyDrunk.Kernel.Abstractions.Tenancy`, and the noop-registration replacement targets. Per invariant 2, runtime packages depend only on Abstractions, never on other runtime packages at the same layer. The Kernel runtime composition is wired at host time by the Container App's startup, not via a runtime PackageReference.

### Runtime details — `HoneyDrunk.Notify.Cloud`

`HoneyDrunk.Notify.Cloud` references:

- `HoneyDrunk.Notify.Cloud.Abstractions` (project reference)
- `HoneyDrunk.Kernel.Abstractions` (for `IGridContext`, `IOperationContext`, `ITelemetryActivityFactory`, and the multi-tenant primitives from `HoneyDrunk.Kernel.Abstractions.Tenancy`: `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`, and from `HoneyDrunk.Kernel.Abstractions.Identity`: `TenantId`). Per invariant 2, runtime packages depend on Abstractions, not on other runtime packages.
- `HoneyDrunk.Communications.Abstractions` (for `ICommunicationOrchestrator`, `IMessageIntent`, `MessageIntent` — hot-path delegate per ADR-0027 D5; uses Abstractions per invariant 40)
- `HoneyDrunk.Notify.Abstractions` (for `INotificationSender` — diagnostic/smoke-test paths only)
- `HoneyDrunk.Auth.Abstractions` (for `IApiKeyAuthenticator` middleware path — TODO: this interface lands in a follow-up ADR per ADR-0027 D12; the scaffold can reference a placeholder or proceed without the import and stub the validation call in `DefaultNotifyCloudGateway` until the Auth-side ADR lands)
- `HoneyDrunk.Vault` (for `ISecretStore` access via `TenantScopedSecretResolver`, and for `IConfigProvider` reads of tenant-tier definitions, cost-rate tables, abuse heuristics — `HoneyDrunk.Vault` is the runtime package because Vault does not split a separate `.Abstractions` package; interfaces live in the runtime per the existing repo shape)
- `Microsoft.Extensions.DependencyInjection.Abstractions`
- `Microsoft.Extensions.Hosting.Abstractions`
- `Microsoft.Extensions.Logging.Abstractions`

Key implementations:

**`DefaultNotifyCloudGateway`** — the full pipeline per ADR-0027 D5:

```csharp
public sealed class DefaultNotifyCloudGateway : INotifyCloudGateway
{
    public async Task<NotifyCloudGatewayResult> ProcessAsync(
        NotifyCloudGatewayRequest request,
        CancellationToken cancellationToken = default)
    {
        // 1. Validate API key via the Notify-Cloud-local INotifyCloudApiKeyStore (salted-hash lookup).
        //    Once the API key authentication ADR lands, Auth's IApiKeyAuthenticator middleware will wrap
        //    this call for trust-boundary discipline; until then the gateway calls the store directly.
        //    ValidateAsync returns the strong TenantId on success per the Abstractions contract.
        TenantId? resolvedTenantId = await _apiKeyStore.ValidateAsync(request.ApiKey, cancellationToken);
        if (resolvedTenantId is null)
        {
            return new(false, null, new(NotifyCloudGatewayErrorCode.Unauthorized, "Invalid API key.", null));
        }
        TenantId tenantId = resolvedTenantId.Value;

        // 1a. Defense-in-depth: reject any path where the validated key resolves to TenantId.Internal.
        //     `default(TenantId).Value == Ulid.Empty == TenantId.Internal` — so an unset/zeroed TenantId
        //     could otherwise sneak through as "Internal", which is a sentinel reserved for Grid-internal
        //     callers that never traverse the Notify Cloud gateway. HashingNotifyCloudApiKeyStore.IssueAsync
        //     also rejects TenantId.Internal at issuance time, but the gateway re-checks here as a
        //     belt-and-suspenders boundary.
        if (tenantId.IsInternal)
        {
            return new(false, null, new(
                NotifyCloudGatewayErrorCode.Unauthorized,
                "Internal tenant cannot transact via the Notify Cloud gateway.",
                null));
        }

        // 1b. Cross-check the caller-supplied TenantIdHint against the resolved tenant. `TenantIdHint`
        //     is `TenantId?` (nullable) — `null` means "no hint" (the common case). A non-null hint that
        //     disagrees with the validated key is a client-side bug; the validated key is authoritative.
        if (request.TenantIdHint is TenantId hint && !hint.Equals(tenantId))
        {
            return new(false, null, new(
                NotifyCloudGatewayErrorCode.Unauthorized,
                "TenantIdHint does not match the tenant bound to the API key.",
                null));
        }

        // 2. Resolve tenant tier from config (via IConfigProvider read). The tier resolver is registered
        //    AddScoped, so this read populates the per-request scoped cache; TierDrivenTenantRateLimitPolicy
        //    later reads from the same cached value in step 4 without a duplicate IConfigProvider call.
        //    See "Tier resolution caching" below for the scoped-cache pattern.
        NotifyCloudTenantTier tier = await _tierResolver.GetTierForTenantAsync(tenantId, cancellationToken);

        // 3. Capability-availability check. Tier gates which delivery surfaces a tenant may use.
        //    This lives in the gateway (not in TierDrivenTenantRateLimitPolicy) so that the rate-limit
        //    policy stays a pure rate-limit policy — concerns stay separated. Surfaces the dedicated
        //    CapabilityNotAvailable error code.
        if (!tier.EnabledChannels.Contains(ChannelForCapability(request.CapabilityKey), StringComparer.Ordinal))
        {
            return new(false, null, new(
                NotifyCloudGatewayErrorCode.CapabilityNotAvailable,
                $"Tier {tier.Name} does not include channel {ChannelForCapability(request.CapabilityKey)}.",
                null));
        }

        // 4. Consult ITenantRateLimitPolicy (Kernel contract; our TierDrivenTenantRateLimitPolicy replaces
        //    Kernel's NoopTenantRateLimitPolicy at host time). Kernel signature:
        //      ValueTask<TenantRateLimitDecision> EvaluateAsync(TenantId, string operationKey, CancellationToken)
        //    The Kernel contract uses `operationKey`; we map our `request.CapabilityKey` to that slot.
        //    TenantRateLimitDecision shape: (TenantRateLimitOutcome Outcome, TimeSpan? RetryAfter, string? Reason).
        TenantRateLimitDecision rateLimitDecision = await _rateLimitPolicy.EvaluateAsync(
            tenantId,
            operationKey: request.CapabilityKey,
            cancellationToken);
        if (rateLimitDecision.Outcome == TenantRateLimitOutcome.Reject
            || rateLimitDecision.Outcome == TenantRateLimitOutcome.Throttle)
        {
            // Convert TimeSpan? RetryAfter from Kernel's shape to int? RetryAfterSeconds at the gateway
            // boundary. The Notify Cloud Abstractions contract keeps int? for HTTP Retry-After-Header
            // semantics; the Kernel-layer TimeSpan is more precise but the public REST API surface uses
            // integer seconds. Both Reject and Throttle surface as RateLimited to the external caller —
            // the distinction lives in tracing/telemetry, not in the public error envelope.
            int? retryAfterSeconds = rateLimitDecision.RetryAfter is { } ts
                ? (int)Math.Ceiling(ts.TotalSeconds)
                : null;
            return new(false, null, new(
                NotifyCloudGatewayErrorCode.RateLimited,
                rateLimitDecision.Reason ?? "Tenant rate limit exceeded.",
                retryAfterSeconds));
        }
        // rateLimitDecision.Outcome == TenantRateLimitOutcome.Allow — fall through.

        // 5. Reconcile correlation IDs (string mirror vs ambient IGridContext.CorrelationId).
        //    Same pattern as Capabilities's DefaultCapabilityInvoker. CorrelationId stays string-typed
        //    in the request because promoting the Kernel CorrelationId record-struct into Abstractions
        //    is a Grid-wide decision not bundled with this Node's stand-up.
        var ambientCorrelationId = _gridContextAccessor.GridContext.CorrelationId;
        if (!string.IsNullOrEmpty(request.CallerCorrelationId)
            && !string.Equals(request.CallerCorrelationId, ambientCorrelationId.ToString(), StringComparison.Ordinal))
        {
            return new(false, null, new(
                NotifyCloudGatewayErrorCode.InvalidPayload,
                "CallerCorrelationId disagrees with ambient context.",
                null));
        }

        // 6. Open telemetry activity, propagating GridContext tags.
        using var activity = _telemetry.StartGatewayActivity(tenantId, request.CapabilityKey);

        // 7. Build the MessageIntent and delegate to ICommunicationOrchestrator (hot-path; per ADR-0027 D5).
        //    MessageIntent shape from HoneyDrunk.Communications.Abstractions is a positional record:
        //      MessageIntent(string IntentKind, string TriggerEventId, RecipientHandle Recipient,
        //                    IReadOnlyDictionary<string, string> Payload).
        //    The Recipient and Payload fields are populated from the JSON payload (e.g., the JSON contains
        //    a recipient email + per-channel parameters); the exact deserialization shape is implementation
        //    detail, but the gateway constructs MessageIntent inline rather than going through an injected
        //    factory. If a follow-up packet introduces an IMessageIntentFactory, this becomes _intentFactory.Create(...).
        var intent = BuildMessageIntent(request.CapabilityKey, request.PayloadJson, ambientCorrelationId);
        var orchestrationResult = await _orchestrator.OrchestrateAsync(intent, cancellationToken);
        if (!orchestrationResult.Success)
        {
            return new(false, null, new(
                NotifyCloudGatewayErrorCode.OrchestrationDenied,
                orchestrationResult.DenyReason ?? "Communications orchestration denied the send.",
                null));
        }

        // 8. Emit BillingEvent for successful delivery (post-dispatch tail; per invariant 39). Goes through
        //    IBillingEventEmitter (Kernel interface). Default registration at scaffold time is the Stripe
        //    stub (StripeBillingEventEmitter) — production composition swaps in the real implementation
        //    when the Stripe billing integration ADR lands.
        //
        //    Defense-in-depth: even though step 1a already rejects TenantId.Internal at the top of the
        //    pipeline, the BillingEvent emission step double-checks. Kernel's NoopBillingEventEmitter does
        //    NOT short-circuit on Internal — it null-checks the event and returns; so any responsibility
        //    to skip Internal sits on the gateway, not on the emitter implementation.
        //
        //    BillingEvent shape from Kernel (7-positional):
        //      (TenantId, string EventType, string OperationKey, long Units, DateTimeOffset OccurredAtUtc,
        //       string CorrelationId, IReadOnlyDictionary<string, string> Attributes)
        if (!tenantId.IsInternal)
        {
            await _billingEmitter.EmitAsync(new BillingEvent(
                TenantId:        tenantId,
                EventType:       "notify.delivery.success",
                OperationKey:    request.CapabilityKey,
                Units:           1,
                OccurredAtUtc:   DateTimeOffset.UtcNow,
                CorrelationId:   _gridContextAccessor.GridContext.CorrelationId.ToString(),
                Attributes:      ImmutableDictionary<string, string>.Empty), cancellationToken);
        }

        return new(true, orchestrationResult.DeliveryId, null);
    }

    // ... constructor with all injected dependencies, fields, etc.
    // BuildMessageIntent, ChannelForCapability are private helpers.
}
```

The full implementation handles error cases, telemetry enrichment, and the dependency-injection wiring; the snippet above captures the pipeline shape.

**Tier resolution caching (per-request scoped pattern).** `_tierResolver` is a Notify-Cloud-private DI service backed by `IConfigProvider`, registered as `AddScoped`. Both the gateway (step 2) and `TierDrivenTenantRateLimitPolicy` (step 4 internals) inject the same scoped instance and therefore share its per-request cached read of the `NotifyCloudTenantTier` for the current request's `TenantId`. The policy does NOT call back into the keystore for tier data, and does NOT issue a duplicate `IConfigProvider` read; it reads from the shared scoped cache. This prevents the agent implementing the policy from inventing a worse pattern (e.g., second IConfigProvider call, or worse, a callback into the keystore).

**`HashingNotifyCloudApiKeyStore`** — production-shape implementation per local invariant 3:

```csharp
using HoneyDrunk.Kernel.Abstractions.Identity;   // TenantId per ADR-0026 D1

public sealed class HashingNotifyCloudApiKeyStore : INotifyCloudApiKeyStore
{
    public async Task<ApiKeyIssuance> IssueAsync(TenantId tenantId, string label, CancellationToken ct)
    {
        // Defense-in-depth: issuance against the Internal sentinel is forbidden. `default(TenantId).Value
        // == Ulid.Empty == TenantId.Internal`, so a caller that omits/zeros the tenantId would otherwise
        // sneak through as "Internal". The Internal sentinel is reserved for Grid-internal callers that
        // never traverse the Notify Cloud gateway and have no API keys. The gateway also rejects Internal
        // at the validation step, but rejecting at issuance closes the loop.
        if (tenantId.IsInternal)
        {
            throw new ArgumentException(
                "API keys may not be issued against TenantId.Internal — the Internal sentinel is reserved for Grid-internal callers.",
                nameof(tenantId));
        }

        var rawKey = GenerateSecureRandomKey();     // 32-byte URL-safe base64 string
        var salt = GenerateSalt();
        var hash = ComputeHash(rawKey, salt);
        var keyId = GenerateKeyId();

        // Persist salt + hash + metadata. NEVER persist rawKey.
        // ApiKeyRecord stores TenantId as the strong type (ULID) — the repository serializes ULID
        // to the column-typed representation used by HoneyDrunk.Data.
        await _repository.AddAsync(new ApiKeyRecord(keyId, tenantId, label, salt, hash, DateTimeOffset.UtcNow, null), ct);

        // Return rawKey to caller exactly once — this is the only path it ever leaves the runtime.
        return new ApiKeyIssuance(keyId, rawKey, tenantId, DateTimeOffset.UtcNow);
    }

    public async Task<TenantId?> ValidateAsync(string apiKey, CancellationToken ct)
    {
        // Hash-compare lookup against the store. Constant-time comparison avoids timing leaks.
        var candidates = await _repository.ListActiveAsync(ct);
        foreach (var record in candidates)
        {
            if (CryptographicOperations.FixedTimeEquals(ComputeHash(apiKey, record.Salt), record.Hash))
            {
                return record.TenantId;
            }
        }
        return null;
    }

    public Task RevokeAsync(string keyId, CancellationToken ct)
        => _repository.SetRevokedAsync(keyId, DateTimeOffset.UtcNow, ct);

    public Task<IReadOnlyList<ApiKeyMetadata>> ListForTenantAsync(TenantId tenantId, CancellationToken ct)
        => _repository.ListMetadataForTenantAsync(tenantId, ct);

    // ... ComputeHash, GenerateSecureRandomKey, GenerateSalt helpers.
    // ComputeHash uses Argon2id or PBKDF2 (caller-configurable; default Argon2id) per cryptographic best practice
    // for password-style hashing. Don't use plain SHA-256 — the salt-and-stretch is the point. Comparison uses
    // System.Security.Cryptography.CryptographicOperations.FixedTimeEquals for timing-attack resistance.
}
```

The repository (`_repository`) is `HoneyDrunk.Data`-backed in production composition. For the in-memory test fixture path (see "Testing fixture" below), a simpler in-memory backend is used.

**`TierDrivenTenantRateLimitPolicy`** — replaces Kernel's `NoopTenantRateLimitPolicy` at host time:

```csharp
public sealed class TierDrivenTenantRateLimitPolicy : ITenantRateLimitPolicy
{
    // Signature matches Kernel exactly:
    //   ValueTask<TenantRateLimitDecision> EvaluateAsync(TenantId, string operationKey, CancellationToken)
    // The parameter is `operationKey` per the Kernel contract. Notify Cloud's gateway maps
    // `request.CapabilityKey` to this slot at the call site.
    public async ValueTask<TenantRateLimitDecision> EvaluateAsync(
        TenantId tenantId,
        string operationKey,
        CancellationToken cancellationToken)
    {
        // ADR-0026 D4: short-circuit on TenantId.Internal so Grid-internal traffic never consults the
        // tier resolver (which would have no tier entry for it anyway). The gateway's step 1a already
        // rejects Internal upstream of this call for external customer traffic, but this policy is a
        // Kernel-contract surface that can be invoked from other code paths too — the local guard stays.
        if (tenantId.IsInternal)
        {
            return new TenantRateLimitDecision(
                Outcome: TenantRateLimitOutcome.Allow,
                RetryAfter: null,
                Reason: null);
        }

        // Read the tier from the per-request scoped cache that the gateway already populated. _tierResolver
        // is registered AddScoped so this is the same instance the gateway used in step 2 — no duplicate
        // IConfigProvider call, no callback into the keystore. See "Tier resolution caching" in the
        // DefaultNotifyCloudGateway section.
        var tier = await _tierResolver.GetTierForTenantAsync(tenantId, cancellationToken);

        // Derive limits from tier — e.g., Free = 1000 events/month, Starter = 10000, Pro = unlimited.
        // NOTE: Capability-availability (channel-in-tier) is checked at the gateway, not here. This policy
        // is a pure rate-limit policy; the gateway is responsible for capability gating and surfaces the
        // dedicated CapabilityNotAvailable error code for that case.
        var monthlyLimit = tier.EventsPerMonth;
        var currentMonthCount = await _usageCounter.GetMonthlyCountAsync(tenantId, cancellationToken);

        if (currentMonthCount >= monthlyLimit)
        {
            // Reject (hard limit reached). RetryAfter is a TimeSpan? per the Kernel contract — the gateway
            // converts to int seconds at the public boundary if needed.
            return new TenantRateLimitDecision(
                Outcome: TenantRateLimitOutcome.Reject,
                RetryAfter: TimeUntilNextMonthStart(),
                Reason: $"Tenant on tier {tier.Name} has used {currentMonthCount} of {monthlyLimit} events this month.");
        }

        return new TenantRateLimitDecision(
            Outcome: TenantRateLimitOutcome.Allow,
            RetryAfter: null,
            Reason: null);
    }

    // TimeUntilNextMonthStart() returns the TimeSpan from "now" to the start of the next calendar month
    // (UTC). Used as the RetryAfter advisory when a tenant hits the monthly ceiling.
}
```

DI registration replaces the Kernel-default `NoopTenantRateLimitPolicy` registration:

```csharp
// in ServiceCollectionExtensions.cs
services.Replace(ServiceDescriptor.Scoped<ITenantRateLimitPolicy, TierDrivenTenantRateLimitPolicy>());
```

The `Replace` (rather than `Add`) ensures Notify Cloud's policy supersedes Kernel's noop registration in any host that composes Notify Cloud — per invariant 39's discipline ("Core dispatch paths for internal Grid callers must remain tenant-agnostic and default to `TenantId.Internal` without caller-specific branches"), the noop is what fires for Grid-internal callers, and Notify Cloud's policy fires for external callers.

**`BillingEventEmissionTail`** — Notify Cloud's invariant-39-compliant post-dispatch tail. Wired into the worker pipeline as a fire-after-success delegate that calls `IBillingEventEmitter.EmitAsync`. The default registered implementation is the Stripe stub at scaffold time; production composition wires the real Stripe emitter.

**`NotifyCloudTelemetry`** — emits `NotifyCloud.Gateway.Process` activity per call with tags: `tenant_id` (direct per ADR-0027 D7 low-cardinality bound), `capability_key`, `outcome` (Success / error code), `latency_ms`. The CorrelationId / CausationId / NodeId propagation from `IGridContext` is enriched on every activity. **No** raw API keys, no plaintext payloads, no recipient PII — only metadata.

### Provider details — `HoneyDrunk.Notify.Cloud.Billing.Stripe`

`HoneyDrunk.Notify.Cloud.Billing.Stripe` references:

- `HoneyDrunk.Kernel.Abstractions` (for `IBillingEventEmitter`, `BillingEvent` per ADR-0026 — the Stripe adapter implements the Kernel-defined interface, not a Notify-Cloud-defined one). No reference to `HoneyDrunk.Notify.Cloud.Abstractions` is required for the stub; if a future Stripe-adapter feature needs `NotifyCloudTenantTier` or similar Notify-Cloud-shaped data, add the project reference then.
- `HoneyDrunk.Vault` (for resolving the Stripe webhook signing key at runtime — eventually; the stub doesn't yet)
- `Microsoft.Extensions.Logging.Abstractions`

Single class:

```csharp
public sealed class StripeBillingEventEmitter : IBillingEventEmitter
{
    // Signature matches Kernel exactly: ValueTask EmitAsync(BillingEvent, CancellationToken).
    public ValueTask EmitAsync(BillingEvent billingEvent, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(billingEvent);

        // TODO (Stripe billing integration ADR follow-up): implement the webhook bridge.
        // For v0.1.0 (this scaffold), the emitter is a stub. It satisfies the IBillingEventEmitter
        // contract — a Stripe-shaped implementation exists — but the actual Stripe metered-billing
        // call is deferred to the follow-up ADR per ADR-0027 D13.
        throw new NotImplementedException(
            "StripeBillingEventEmitter is a v0.1.0 stub. Stripe webhook bridge implementation is "
            + "deferred to the Stripe billing integration ADR (PDR-0002 recommended follow-up).");
    }
}
```

The stub is **functional for tests** in the sense that it can be DI-registered and verified to throw; downstream code that calls `EmitAsync` and expects it to succeed is broken until the follow-up ADR lands. Composition at scaffold time uses a different default emitter for end-to-end smoke tests (an in-memory `LoggingBillingEventEmitter` lives in the runtime project's test project as an `internal` test helper per D3).

### Web project — `HoneyDrunk.Notify.Cloud.Web`

`HoneyDrunk.Notify.Cloud.Web` is an ASP.NET Core minimal-API host with Blazor Server pages per ADR-0027 D3 default. References:

- `HoneyDrunk.Notify.Cloud` (project reference — composes the runtime)
- `HoneyDrunk.Web.Rest.AspNetCore` (for response envelopes, correlation headers per invariant 18-style consistency)
- `Microsoft.AspNetCore.App` (framework reference — pulls in Blazor Server)
- `HoneyDrunk.Kernel.Abstractions` (for `IGridContext` propagation through the ASP.NET Core pipeline; Abstractions reference per invariant 2 — the runtime composition is brought in transitively via the project reference to `HoneyDrunk.Notify.Cloud`)

Three things ship at scaffold time:

- A health endpoint at `/health` returning `200 OK` with a tiny JSON body confirming the gateway is composed.
- A non-functional signup form at `/signup` (Blazor Server) — just the form scaffold, no backing API. Per ADR-0027 D13, the full signup flow lands in a follow-up packet.
- The standard ASP.NET Core pipeline wiring (`AddHoneyDrunkNotifyCloud()`, `AddRouting()`, `AddRazorComponents()`, etc.) in `Program.cs`.

The web project's full surface (full signup, billing dashboard, delivery logs, tenant management UI) is **explicitly out of scope for this scaffold** per ADR-0027 D13. The placeholder is enough to confirm the deployment path compiles and the `ca-hd-notify-cloud-stg` Container App can serve requests.

### CI workflows

All six workflow files are thin callers of `HoneyDrunk.Actions` reusable workflows. No bespoke CI logic in the Notify Cloud repo.

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
# .github/workflows/api-compatibility.yml — ADR-0027 D8 / Notify Cloud contract-shape canary invariant
name: API Compatibility (Abstractions)
on:
  pull_request:
    branches: [main]
    paths:
      - 'src/HoneyDrunk.Notify.Cloud.Abstractions/**'
jobs:
  abstractions-shape:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main
    with:
      project-path: src/HoneyDrunk.Notify.Cloud.Abstractions/HoneyDrunk.Notify.Cloud.Abstractions.csproj
```

The path filter ensures the canary only runs when Abstractions changes — keeps PR feedback fast for runtime/Web-only changes. The whole-assembly diff produced by `job-api-compatibility.yml` is sufficient to enforce D8: the four frozen contracts plus their supporting records and the `NotifyCloudGatewayErrorCode` enum are all in `HoneyDrunk.Notify.Cloud.Abstractions`, so any shape drift in any public type in Abstractions counts.

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
      # Notify Cloud packages publish to the private feed only — see release.yml composite action
      # for the feed-URL parameterization. Do NOT publish to public NuGet per ADR-0027.
    secrets: inherit
```

Tags are human-pushed per invariant 27 — agents do not push tags. The release workflow packs and publishes all four `src/*` projects to the private NuGet feed in a single tag-driven run. **The release workflow must be configured to publish to the private feed, not public NuGet** — this is a critical safeguard against accidentally publishing the wrapper packages publicly.

```yaml
# .github/workflows/deploy-stg.yml — ADR-0015 container-app deployment
# Phase 0 stance: workflow_dispatch only at v0.1.0. The full ADR-0033 trigger model
# (dev push-to-main, staging tag-push) lands in a follow-up packet — Notify Cloud
# is in Phase 0 alongside the ADR-0033 follow-up packet from the ADR-0024 fix pass.
# Per ADR-0033 D5, an explicit per-environment concurrency group is required.
name: Deploy (stg)
on:
  workflow_dispatch:                   # manual trigger only at v0.1.0 (see Phase 0 note above)
concurrency:
  group: deploy-stg-notify-cloud       # ADR-0033 D5: per-environment concurrency group
  cancel-in-progress: false
jobs:
  deploy:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml@main
    with:
      service-name: notify-cloud
      environment: stg
      image-tag: ${{ github.sha }}
    secrets: inherit
```

This is the first deploy target per ADR-0027 D13: `ca-hd-notify-cloud-stg` in East US. Production deployment (`ca-hd-notify-cloud-prd`) is a follow-up; staging is enough to prove the deployment path compiles. The `job-deploy-container-app.yml` reusable workflow handles the Container Apps provisioning per ADR-0015 (shared `cae-hd-stg` environment, shared `acrhdsharedstg` registry, system-assigned Managed Identity, `Multiple` revision mode per invariants 34-36).

**Environment model — `dev` deferred to follow-up.** Notify Cloud at v0.1.0 has no `dev` environment; staging (`ca-hd-notify-cloud-stg`) is both the dev cadence and the first promotion target until customer onboarding begins. A `dev` environment (`ca-hd-notify-cloud-dev`, with the ADR-0033 D1 push-to-main auto-deploy trigger) will be added in a follow-up packet when external preview begins.

**ADR-0033 trigger model — staged.** At v0.1.0 only `workflow_dispatch` is configured. The ADR-0033 D1 trigger model (`push: tags: ['v*.*.*']` mapping to staging, `push: branches: [main]` mapping to dev) lands in a follow-up packet that is co-scheduled with the ADR-0033 follow-up packet from the ADR-0024 fix pass. The follow-up packet adds the tag-push trigger to `deploy-stg.yml` and introduces `deploy-dev.yml` alongside.

`nightly-deps.yml` and `nightly-security.yml` follow the same thin-caller pattern — copy the configurations from `HoneyDrunk.Auth` or `HoneyDrunk.Vault` for reference.

### `HoneyDrunk.Standards` wiring

Each `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets="all"` per invariant 26:

```xml
<ItemGroup>
  <PackageReference Include="HoneyDrunk.Standards" Version="*" PrivateAssets="all" />
</ItemGroup>
```

This pulls in the StyleCop ruleset, `.editorconfig`, and analyzer suite that every Grid repo uses.

### Documentation

- **Repo `README.md`** — purpose statement, "Private repo" badge, package matrix, "How Notify Cloud composes Communications and Notify" pipeline diagram, link to ADR-0027.
- **Repo `CHANGELOG.md`** — `## [0.1.0] - 2026-MM-DD` entry covering the entire scaffold landing.
- **Per-package `README.md`** — purpose, public API surface summary. Required by invariant 12 for new packages.
- **Per-package `CHANGELOG.md`** — `## [0.1.0]` entry for each package introduced in this packet.

## Affected Files
Entire repo is created from this packet (the empty repo from packet 05 had only `.gitignore` and a placeholder README). Notable new files:
- `HoneyDrunk.Notify.Cloud.slnx`, `Directory.Build.props`, `README.md`, `CHANGELOG.md`, `LICENSE`, `.editorconfig`
- `src/HoneyDrunk.Notify.Cloud.Abstractions/` — four contract files + supporting record/enum files + `.csproj` + `README.md` + `CHANGELOG.md`
- `src/HoneyDrunk.Notify.Cloud/` — `.csproj`, `ServiceCollectionExtensions.cs`, `Gateway/DefaultNotifyCloudGateway.cs`, `ApiKeys/HashingNotifyCloudApiKeyStore.cs`, `RateLimiting/TierDrivenTenantRateLimitPolicy.cs`, `Billing/BillingEventEmissionTail.cs`, `Telemetry/NotifyCloudTelemetry.cs`, `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.Notify.Cloud.Billing.Stripe/` — `.csproj`, `StripeBillingEventEmitter.cs`, `README.md`, `CHANGELOG.md`
- `src/HoneyDrunk.Notify.Cloud.Web/` — `.csproj`, `Program.cs`, `Pages/Health.razor`, `Components/SignupPlaceholder.razor`, `README.md`, `CHANGELOG.md`
- `tests/*` — four test projects with at least smoke-test coverage
- `.github/workflows/` — 6 workflow files

## NuGet Dependencies

Every new `.csproj` lists `HoneyDrunk.Standards` (`PrivateAssets="all"`) per invariant 26.

### `HoneyDrunk.Notify.Cloud.Abstractions.csproj`

**v0.1.0 decision — single, explicit choice.** v0.1.0 PackageReferences `HoneyDrunk.Kernel.Abstractions` **only**. `HoneyDrunk.Notify.Abstractions` and `HoneyDrunk.Communications.Abstractions` are reserved by ADR-0027 D3 for future contract surfaces and will be added in a follow-up packet when a contract first consumes them. Do not add them at v0.1.0 — that creates dead references the agent can't justify.

| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For the `TenantId` record-struct from `HoneyDrunk.Kernel.Abstractions.Identity` per ADR-0026 D1. Load-bearing at v0.1.0. ADR-0027 D3 explicitly enumerates this as one of the three permitted Abstractions references for this package. Matches the established pattern from `HoneyDrunk.Communications.Abstractions` (also references `HoneyDrunk.Kernel.Abstractions`). |

Notes on Abstractions references — ADR-0027 D3 reads: "Zero runtime dependencies beyond `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Notify.Abstractions`, and `HoneyDrunk.Communications.Abstractions`." The strict-Abstractions stance applied in some ADR-0016 / ADR-0017 packets does NOT apply here — the ADR explicitly carved out these three. At v0.1.0 only `HoneyDrunk.Kernel.Abstractions` is actually consumed (for `TenantId`); `HoneyDrunk.Notify.Abstractions` and `HoneyDrunk.Communications.Abstractions` are reserved by D3 for future contract surfaces and are added by the follow-up packet that introduces the first contract consuming them.

### `HoneyDrunk.Notify.Cloud.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `IGridContext`, `IOperationContext`, `ITelemetryActivityFactory`, and the multi-tenant primitives in `HoneyDrunk.Kernel.Abstractions.Tenancy` (`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`) plus the `TenantId` strong type in `HoneyDrunk.Kernel.Abstractions.Identity` per ADR-0026. Per invariant 2, runtime packages depend on Abstractions, not on other runtime packages — so this is the Abstractions reference, not `HoneyDrunk.Kernel` (runtime). |
| `HoneyDrunk.Communications.Abstractions` | For `ICommunicationOrchestrator`, `IMessageIntent`, `MessageIntent` per ADR-0027 D5 (hot path) and invariant 40. `MessageIntent` is a positional record with shape `(string IntentKind, string TriggerEventId, RecipientHandle Recipient, IReadOnlyDictionary<string, string> Payload)` — the gateway constructs it inline via a `BuildMessageIntent` private helper (deserializing `request.PayloadJson` into the `Recipient` + `Payload` slots), NOT through an injected `_intentFactory`. The factory pattern would be premature at v0.1.0; if a follow-up packet introduces an `IMessageIntentFactory`, the helper graduates to that. |
| `HoneyDrunk.Notify.Abstractions` | For `INotificationSender` — diagnostic/smoke-test paths only per ADR-0027 D5 |
| `HoneyDrunk.Auth.Abstractions` | For `IApiKeyAuthenticator` middleware path (Auth-side surface to be finalized in a follow-up ADR per ADR-0027 D12) |
| `HoneyDrunk.Vault` | For `ISecretStore`, `IConfigProvider` (tenant tier definitions, cost-rate tables, abuse heuristics). The Vault repo does not split a separate `.Abstractions` package — the interfaces live in the runtime `HoneyDrunk.Vault` package per the existing repo shape. Confirm at implementation time; if a `.Abstractions` package has materialized by then, prefer it. |
| `HoneyDrunk.Data.Abstractions` | For the `HashingNotifyCloudApiKeyStore` repository backend per ADR-0027 D9 default ("hashed table in HoneyDrunk.Data") |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | DI registration helpers |
| `Microsoft.Extensions.Hosting.Abstractions` | For startup hook integration |
| `Microsoft.Extensions.Logging.Abstractions` | Logger contracts |

Project reference: `HoneyDrunk.Notify.Cloud.Abstractions`.

**Note on Kernel runtime vs Abstractions choice.** Earlier drafts listed `HoneyDrunk.Kernel` (the runtime package). Per invariant 2 (Runtime packages depend on Abstractions, never on other runtime packages at the same layer), the correct dependency is `HoneyDrunk.Kernel.Abstractions`. Composition against the Kernel runtime is a host-time concern; the runtime ServiceCollectionExtensions wire concrete implementations at the Container App composition point, not via a PackageReference from the Notify Cloud runtime to the Kernel runtime.

### `HoneyDrunk.Notify.Cloud.Billing.Stripe.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `HoneyDrunk.Kernel.Abstractions` | For `IBillingEventEmitter`, `BillingEvent` per ADR-0026 |
| `HoneyDrunk.Vault` | For Stripe webhook signing key resolution (eventually — stub doesn't use it yet) |
| `Microsoft.Extensions.Logging.Abstractions` | Logger contracts |
| `Stripe.net` | Reserved for the follow-up Stripe integration ADR — the v0.1.0 stub does not import it. Document as a planned reference in the project's README. |

(Project reference: none required for the stub — `StripeBillingEventEmitter` implements `IBillingEventEmitter` from `HoneyDrunk.Kernel.Abstractions.Tenancy` directly. If the stub somehow needs `NotifyCloudTenantTier`, add a project reference to `HoneyDrunk.Notify.Cloud.Abstractions`; otherwise omit.)

### `HoneyDrunk.Notify.Cloud.Web.csproj`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.AspNetCore.App` | Framework reference (Blazor Server, minimal API) |
| `HoneyDrunk.Kernel.Abstractions` | For `IGridContext` propagation through the ASP.NET Core pipeline — Abstractions reference per invariant 2. The runtime composition (concrete Kernel implementations) is brought in transitively via the project reference to `HoneyDrunk.Notify.Cloud`. |
| `HoneyDrunk.Web.Rest.AspNetCore` | Response envelopes, correlation headers — hosting-layer ASP.NET Core integration. This package is a hosting-tier sibling to runtime; ASP.NET Core hosting projects reference it directly per the existing Grid pattern. |

Project references: `HoneyDrunk.Notify.Cloud` (the runtime).

### Test projects
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` | `PrivateAssets="all"` |
| `Microsoft.NET.Test.Sdk` | Standard |
| `xunit` | Standard |
| `xunit.runner.visualstudio` | Standard |
| `Microsoft.Extensions.DependencyInjection` | For DI in gateway/store/rate-limit policy tests |
| `NSubstitute` | For mocking `ICommunicationOrchestrator`, `IBillingEventEmitter`, `IApiKeyAuthenticator` |

Project references as appropriate to each `.Tests` project.

## Boundary Check
- [x] All work inside `HoneyDrunk.Notify.Cloud`. No edits to other Grid repos.
- [x] `HoneyDrunk.Notify.Cloud.Abstractions` `HoneyDrunk.*` PackageReferences are limited to the three explicitly permitted by ADR-0027 D3: `HoneyDrunk.Kernel.Abstractions` (load-bearing for `TenantId`), `HoneyDrunk.Notify.Abstractions` (reserved; may be omitted if no v0.1.0 consumer), `HoneyDrunk.Communications.Abstractions` (reserved; may be omitted if no v0.1.0 consumer). The strict-Abstractions stance from sibling ADR-0016 / ADR-0017 packets does NOT apply here — ADR-0027 D3 explicitly carves out these three references.
- [x] `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` are **not** redeclared in Notify Cloud Abstractions — they live in `HoneyDrunk.Kernel.Abstractions.Tenancy` per ADR-0026 and the runtime package consumes them.
- [x] `TenantId` is referenced (not redeclared) — it is the canonical Kernel record-struct from `HoneyDrunk.Kernel.Abstractions.Identity` per ADR-0026 D1. The four D4 contracts use the strong type, not `string`.
- [x] Records (`NotifyCloudTenantTier`, `ApiKeyIssuance`, `NotifyCloudGatewayRequest`, `NotifyCloudGatewayResult`, `NotifyCloudGatewayError`, `ApiKeyMetadata`) all drop the `I` prefix; interfaces (`INotifyCloudGateway`, `INotifyCloudApiKeyStore`) keep it (Grid-wide naming rule).
- [x] No secrets in code. Stripe webhook signing key resolution is deferred to `IConfigProvider` / `ISecretStore` — the scaffold does not commit a key value.
- [x] The Auth dependency in `DefaultNotifyCloudGateway` uses a placeholder reference to `IApiKeyAuthenticator` (the actual interface signature is finalized in the follow-up ADR per ADR-0027 D12) — `HashingNotifyCloudApiKeyStore` is the Notify-Cloud-local salted-hash store; Auth's middleware wraps it for the trust-boundary discipline.
- [x] API keys are stored as salted hashes only (Argon2id or PBKDF2 by configuration); raw key material is returned exactly once via `ApiKeyIssuance` at issuance time. No path retrieves the raw key after `IssueAsync` returns.
- [x] The Notify-Cloud-specific `ITenantRateLimitPolicy` implementation uses `services.Replace(...)` to supersede Kernel's `NoopTenantRateLimitPolicy` registration at host time per invariant 39's intake/post-dispatch discipline.
- [x] LICENSE is `LicenseRef-Proprietary` (all rights reserved by default of being private) per ADR-0027 D11. The wrapper is private; the public FSL applies only to the engine repos (Notify, Communications — handled by packets 03 and 04).
- [x] Release workflow publishes to the private NuGet feed only — packages are NOT pushed to public NuGet per ADR-0027 D2's confidentiality framing.

## Acceptance Criteria
- [ ] `HoneyDrunk.Notify.Cloud.slnx` builds clean from a fresh clone via `dotnet build` with no warnings (warnings-as-errors).
- [ ] All four D4 contracts present in `HoneyDrunk.Notify.Cloud.Abstractions` with XML documentation per invariant 13.
- [ ] `HoneyDrunk.Notify.Cloud.Abstractions` PackageReferences at v0.1.0 are **exactly**: `HoneyDrunk.Standards` (`PrivateAssets="all"`) and `HoneyDrunk.Kernel.Abstractions` (for `TenantId`). `HoneyDrunk.Notify.Abstractions` and `HoneyDrunk.Communications.Abstractions` are reserved by ADR-0027 D3 but NOT added at v0.1.0 — they are added in a follow-up packet when a contract first consumes them. No other `HoneyDrunk.*` references at v0.1.0.
- [ ] `HoneyDrunk.Notify.Cloud.Abstractions` references `TenantId` from `HoneyDrunk.Kernel.Abstractions.Identity` and does NOT redeclare it. Verify by searching the Abstractions project source: `rg -n 'record\s+TenantId|struct\s+TenantId' src/HoneyDrunk.Notify.Cloud.Abstractions/` should return zero matches.
- [ ] `HoneyDrunk.Notify.Cloud.Abstractions` does NOT declare `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, or `BillingEvent`. Those live in `HoneyDrunk.Kernel.Abstractions.Tenancy` per ADR-0026. Verify by searching the Abstractions project source.
- [ ] The four D4 contracts use the strong `TenantId` type (from `HoneyDrunk.Kernel.Abstractions.Identity`) for every TenantId-shaped field. No `string` typed TenantId fields remain on `INotifyCloudGateway.NotifyCloudGatewayRequest`, `INotifyCloudApiKeyStore` method parameters, `ApiKeyMetadata`, or `ApiKeyIssuance`. Verify by `rg -n '\bstring\s+TenantId\b|\bstring\s+tenantId\b' src/HoneyDrunk.Notify.Cloud.Abstractions/` returning zero matches.
- [ ] `NotifyCloudGatewayRequest.TenantIdHint` is declared as `TenantId?` (nullable), NOT `TenantId`. This is the security fix for the `default(TenantId) == TenantId.Internal` aliasing collision: a `null` hint unambiguously means "no hint", whereas a bare `TenantId` field with a `default` value would alias to the Internal sentinel. Verify by `rg -n 'TenantId\??\s+TenantIdHint' src/HoneyDrunk.Notify.Cloud.Abstractions/INotifyCloudGateway.cs` returning the nullable form.
- [ ] `NotifyCloudTenantTier.EnabledChannels` is declared as `IReadOnlyList<string>` (or `ImmutableArray<string>`), NOT `string[]`. Mutable arrays on public records are a footgun; the read-only collection form matches Grid convention (compare to `BillingEvent.Attributes: IReadOnlyDictionary<string, string>`).
- [ ] `KeyId` / `ApiKeyId` stay `string` at v0.1.0 with a TODO comment near the type declaration in `INotifyCloudApiKeyStore` pointing at the follow-up API key authentication ADR for the eventual strong-type promotion. Promotion is not bundled with this scaffold.
- [ ] `HoneyDrunk.Notify.Cloud` runtime exposes `AddHoneyDrunkNotifyCloud()` extension; `INotifyCloudGateway`, `INotifyCloudApiKeyStore` resolve from DI after registration. Kernel's `ITenantRateLimitPolicy` registration is superseded via `services.Replace(...)` with `TierDrivenTenantRateLimitPolicy`.
- [ ] `HashingNotifyCloudApiKeyStore.IssueAsync` returns an `ApiKeyIssuance` containing the plaintext key exactly once. The repository persists only `(KeyId, TenantId, Label, Salt, Hash, IssuedAt, RevokedAt)` — never the raw key. A unit test verifies that no path retrieves the raw key after `IssueAsync` returns (e.g., `ListForTenantAsync` returns only metadata without any raw-key field).
- [ ] `HashingNotifyCloudApiKeyStore.IssueAsync` throws `ArgumentException` (paramName `nameof(tenantId)`) when called with `TenantId.Internal`. A unit test verifies this — the Internal sentinel is reserved for Grid-internal callers and may not be issued API keys. This closes the loop with the gateway's step 1a Internal-rejection: issuance refuses Internal, and validation/transaction refuses Internal even if a malformed key ever made it past issuance.
- [ ] `HashingNotifyCloudApiKeyStore.ValidateAsync` uses constant-time comparison (e.g., `CryptographicOperations.FixedTimeEquals` from `System.Security.Cryptography`) for the hash comparison. A unit test verifies validation succeeds with a freshly issued raw key and fails with a tampered key.
- [ ] `DefaultNotifyCloudGateway.ProcessAsync` runs the full pipeline in this order: API key validation → Internal-sentinel rejection → TenantIdHint cross-check → tier resolution → **capability-availability check** → rate-limit evaluation → correlation reconciliation → telemetry activity → orchestration delegation → billing emission. Capability-availability (channel-in-tier) lives at the gateway, NOT inside `TierDrivenTenantRateLimitPolicy`. The call to `_rateLimitPolicy.EvaluateAsync(tenantId, operationKey: request.CapabilityKey, ct)` uses the Kernel `ITenantRateLimitPolicy.EvaluateAsync` signature exactly (returns `ValueTask<TenantRateLimitDecision>`). Tests cover: invalid API key → `Unauthorized`; validated key resolving to `TenantId.Internal` → `Unauthorized` with the "Internal tenant cannot transact" message; non-null `TenantIdHint` disagreeing with the validated tenant → `Unauthorized`; null `TenantIdHint` (the common case) → no rejection; capability not in tier's `EnabledChannels` → `CapabilityNotAvailable` (NOT `RateLimited`); `Outcome: TenantRateLimitOutcome.Reject` → `RateLimited` with `RetryAfterSeconds = (int)Math.Ceiling(decision.RetryAfter.Value.TotalSeconds)`; `Outcome: TenantRateLimitOutcome.Throttle` → `RateLimited` (same envelope as Reject); orchestration denial → `OrchestrationDenied`; mismatched `CallerCorrelationId` → `InvalidPayload`.
- [ ] **Happy-path billing-event acceptance.** A unit test verifies that on a successful end-to-end gateway run, `IBillingEventEmitter.EmitAsync` was called exactly once with a `BillingEvent` whose: `TenantId` matches the validated key's tenant; `EventType == "notify.delivery.success"`; `OperationKey == request.CapabilityKey`; `Units == 1`; `CorrelationId` matches `_gridContextAccessor.GridContext.CorrelationId.ToString()`; `Attributes` is non-null (defaults to `ImmutableDictionary<string, string>.Empty`). The test uses `NSubstitute.Received()` against a mocked `IBillingEventEmitter`. A second test verifies that when the resolved `TenantId.IsInternal` is true (a path that the gateway's step 1a should already reject — this is a belt-and-suspenders test against direct invocation), `EmitAsync` is NOT called.
- [ ] `TierDrivenTenantRateLimitPolicy.EvaluateAsync(TenantId, string operationKey, CancellationToken)` returns `ValueTask<TenantRateLimitDecision>` matching the Kernel `ITenantRateLimitPolicy` signature exactly. `TenantRateLimitDecision` is constructed positionally as `(TenantRateLimitOutcome Outcome, TimeSpan? RetryAfter, string? Reason)` per the Kernel record shape — no `Allowed:` / `DenyReason:` / `RetryAfterSeconds:` legacy field names. Derives the monthly ceiling from `NotifyCloudTenantTier.EventsPerMonth` (sourced from `IConfigProvider` via the per-request scoped `_tierResolver`, mocked in tests). Unit tests cover: Free tier exceeding `EventsPerMonth` → `Outcome: TenantRateLimitOutcome.Reject` with a non-null `RetryAfter` advisory; Pro tier under the ceiling → `Outcome: TenantRateLimitOutcome.Allow` with `RetryAfter: null`, `Reason: null`; `TenantId.Internal` short-circuit → `Outcome: TenantRateLimitOutcome.Allow`. Capability-availability (channel-in-tier) is NOT tested in this policy — that lives at the gateway with `CapabilityNotAvailable` error code.
- [ ] `StripeBillingEventEmitter.EmitAsync` signature returns `ValueTask` (matching the Kernel `IBillingEventEmitter.EmitAsync(BillingEvent, CancellationToken) → ValueTask` shape exactly — NOT `Task`). The body null-checks `billingEvent` via `ArgumentNullException.ThrowIfNull(billingEvent)` then throws `NotImplementedException` with the TODO referencing the follow-up Stripe billing integration ADR. A unit test verifies (a) the throw on a non-null event, and (b) that `ArgumentNullException` (not `NotImplementedException`) fires when `billingEvent` is null. The scaffold's end-to-end smoke test does NOT call this emitter directly — composition uses an in-memory `LoggingBillingEventEmitter` internal test helper for the smoke path.
- [ ] `NotifyCloudTelemetry` emits `NotifyCloud.Gateway.Process` activity per call with tags `tenant_id`, `capability_key`, `outcome`, `latency_ms`. No raw API keys, no plaintext payloads, no recipient PII. Verified by a test using `TestActivityListener`-style fixture.
- [ ] `HoneyDrunk.Notify.Cloud.Web` exposes `/health` returning `200 OK` with a JSON body confirming the gateway is composed. A `/signup` page exists as a Blazor Server placeholder (renders the form scaffold but performs no backing API call).
- [ ] `LICENSE` file exists at repo root with the proprietary-license text. `Directory.Build.props` declares `<PackageLicenseFile>LICENSE</PackageLicenseFile>` and the file is packed into every `.nupkg` via `<None Include=... Pack="true">`.
- [ ] All six `.github/workflows/*.yml` files present and reference `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/*@main`.
- [ ] `release.yml` is configured to publish to the **private** NuGet feed only. **No path publishes Notify.Cloud packages to public NuGet.** Verify the feed-URL parameter in the workflow file matches the private feed. If accidentally configured for public NuGet, the workflow itself must be rejected and reauthored.
- [ ] `deploy-stg.yml` calls `job-deploy-container-app.yml` per ADR-0015 with `service-name: notify-cloud`, `environment: stg`. Verifies the deployment path compiles even if not executed. (Actually running the deployment requires Azure resources from the Human Prerequisites.)
- [ ] **Service-name length check.** Verify `"notify-cloud".Length` is 12 — fits inside invariant 19's ≤ 13 character limit for Azure resource naming. The full resource name `ca-hd-notify-cloud-stg` is 23 characters (under Container Apps' 32-char limit); `kv-hd-notify-cloud-stg` is 23 characters (under Key Vault's 24-char limit). Document the count in `HoneyDrunk.Notify.Cloud/README.md` so a future Node author sees the precedent.
- [ ] `deploy-stg.yml` declares an explicit per-environment `concurrency` group keyed by environment name (`deploy-stg-notify-cloud`) with `cancel-in-progress: false` per ADR-0033 D5. Verify the workflow has the `concurrency:` block at the top level, not inside the job.
- [ ] `api-compatibility.yml` runs on PR. On the scaffolding PR itself the workflow runs against an absent `main` baseline and reports `status: skipped` per the `HoneyDrunk.Actions/.github/actions/api/check-compatibility/action.yml` missing-baseline path — that is correct first-build behavior, not a failure. **Verify post-merge** by opening a throwaway PR that removes a public member from `INotifyCloudGateway` (or any other frozen contract); the workflow must fail with breaking-changes-detected. Revert the throwaway PR after observation.
- [ ] `pr-core.yml` passes on the initial scaffolding PR (build + tests + analyzers + dependency scan + secret scan).
- [ ] Repo-level `CHANGELOG.md` has a `## [0.1.0] - YYYY-MM-DD` entry covering the scaffold; per-package `CHANGELOG.md` files each have their own `## [0.1.0]` entry naming the package's specific introductions (per invariants 12 and 27).
- [ ] Repo-level `README.md` and per-package `README.md` files all present per invariant 12.
- [ ] Test suite runs and passes — minimum coverage as described in the Acceptance Criteria above.
- [ ] All projects in the solution carry the same `Version` (0.1.0), excluding test projects (invariant 27).
- [ ] Manual confirmation that pushing tag `v0.1.0` from `main` would trigger `release.yml` and produce private-feed packages for the four `src/*` projects (do not actually push the tag — verify the workflow exists and a tag-push trigger is configured against the private feed).

## Human Prerequisites
- [ ] **Provision the shared Container Apps Environment `cae-hd-stg` (first-Container-App bundle).** Per ADR-0015 and the user's standing rule "Provision Azure resources when first needed; CAE has no standalone portal Create — bundle with first Container App." Notify Cloud is the first containerized Node deploying to `stg`, so the CAE provisioning happens here. Cross-link: see `infrastructure/walkthroughs/` for any container-apps-environment walkthrough doc (e.g., `infrastructure/walkthroughs/container-apps-environment-stg.md` if it has been authored; if not, create it as part of this prerequisite and capture the portal steps for the next Node to consume).
- [ ] **Provision Azure resources for the `stg` deployment.** Per ADR-0015 and ADR-0027 D13:
  - Resource group `rg-hd-notify-cloud-stg` in East US (create via Azure portal: Resource Groups → Create)
  - Container App `ca-hd-notify-cloud-stg` in the `cae-hd-stg` environment provisioned above, with system-assigned Managed Identity (per invariant 34).
  - Key Vault `kv-hd-notify-cloud-stg` with Azure RBAC enabled (per invariant 17). Service name `notify-cloud` is 12 characters — fits within invariant 19's 13-char limit. Diagnostic settings routed to the shared Log Analytics workspace per invariant 22.
  - App Service configuration: `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` set as environment variables (per invariant 18, never derived by convention, never hardcoded).
  - OIDC federated credential for `repo:HoneyDrunkStudios/HoneyDrunk.Notify.Cloud:ref:refs/heads/main` (for the `workflow_dispatch`-triggered deploy) and `repo:HoneyDrunkStudios/HoneyDrunk.Notify.Cloud:ref:refs/tags/v*` (for the tag-triggered release publish) against the deployment identity. Cross-link: [infrastructure/walkthroughs/oidc-federated-credentials.md](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).
  - Lean Azure tag scheme per user preference: `env=stg`, `node=notify-cloud`, no `initiative` tag. Default cheapest viable tier for `stg` (Container App: Consumption plan; Key Vault: Standard; App Config: Free if available).
  - Use Azure Portal walkthroughs rather than CLI per user preference. Cross-link any relevant `infrastructure/walkthroughs/` doc.
- [ ] **Post-merge canary verification.** After the scaffolding PR merges, open a throwaway PR that removes a public member from `INotifyCloudGateway` (e.g., delete the `CancellationToken cancellationToken = default` parameter), observe `api-compatibility / abstractions-shape` fail with breaking-changes-detected, record the failing run URL in a comment on the throwaway PR, then revert the throwaway PR. Once observed, update branch protection to add `api-compatibility / abstractions-shape` to the required-checks list. The scaffolding PR's merge establishes the `main` baseline; until that exists, the canary correctly reports `status: skipped` on every PR — that is not a misconfiguration.
- [ ] **Push tag `v0.1.0`** from `main` to trigger the release workflow and publish the four packages to the private NuGet feed. Tags are human-pushed per invariant 27 — agents never push tags. **Confirm the release workflow is publishing to the private feed, not public NuGet, before pushing.**
- [ ] **No Stripe API key seeding required at v0.1.0** — the Stripe billing emitter is a stub that throws. The follow-up Stripe billing integration ADR carries the API key provisioning step.
- [ ] **No tenant-tier definitions seeded at v0.1.0** — `IConfigProvider` reads of `tenant-tier-{tenantId}` keys will return empty / default until a tenant is provisioned in App Configuration. That is fine for scaffold; tenant provisioning is a follow-up workflow (tenant onboarding doc per ADR-0027 unblocks list).
- [ ] **Follow-up tracking: hive-sync catalog reconciliation.** After all six packets in this initiative merge, open a tracking issue against `HoneyDrunk.Architecture` titled "hive-sync: reconcile catalogs/*.json + initiatives/* + adrs/README.md after ADR-0027 standup" so that the explicitly-deferred index-file updates land as a single hive-sync pass. Per the standing convention, scope-agent-authored packets do not touch shared index files; hive-sync owns that step.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `HoneyDrunk.Notify.Cloud.Abstractions.csproj` must contain no `HoneyDrunk.*` PackageReference or ProjectReference. The `HoneyDrunk.Standards` reference uses `PrivateAssets="all"` so it does not propagate.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. — `HoneyDrunk.Notify.Cloud` references `HoneyDrunk.Communications.Abstractions`, `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Auth.Abstractions`, `HoneyDrunk.Kernel.Abstractions` directly — not the runtime packages of any of those Nodes. Composition of the concrete runtimes happens at host time in the Container App.

> **Invariant 3:** Provider packages depend on their parent Node's contracts, not internal implementation details. — `HoneyDrunk.Notify.Cloud.Billing.Stripe` references `HoneyDrunk.Kernel.Abstractions` (for the parent contract `IBillingEventEmitter` it implements) — that "parent" here is Kernel, not Notify Cloud, because the contract being implemented lives in Kernel per ADR-0026.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Notify Cloud references Communications, Notify, Auth, Vault, Kernel, Data; none of those reference Notify Cloud back. Notify Cloud is a leaf per ADR-0027 D9.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. — Extended to API key material by local invariant 3 and constitutional invariant 54 (number assigned by packet 02). Raw API keys, plaintext payloads, and recipient PII are never logged or emitted to telemetry.

> **Invariant 9:** Vault is the only source of secrets. — Stripe webhook signing key (when the Stripe stub becomes a real implementation), per-tenant secret scoping, tenant-tier definitions, cost-rate tables, abuse heuristics are all sourced from Vault's `ISecretStore` and `IConfigProvider`. Not from environment variables, not from config files, not from provider SDKs.

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning. — This packet is the establishment of HoneyDrunk.Notify.Cloud's solution and CI pipeline.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. New projects must have both files from the first commit. — Every one of the four `src/*` projects ships a `README.md` and `CHANGELOG.md` in the same commit it is added.

> **Invariant 13:** All public APIs have XML documentation. Enforced by HoneyDrunk.Standards analyzers. — Every public type/member in `HoneyDrunk.Notify.Cloud.Abstractions` carries `///` summaries. StyleCop rules from `HoneyDrunk.Standards` enforce this.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. — `kv-hd-notify-cloud-stg` provisioned per Human Prerequisites. Service name `notify-cloud` is 12 characters, fits within invariant 19's 13-char limit.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. — Set in the Container App's environment variables, not in code.

> **Invariant 19:** Service names in Azure resource naming must be ≤ 13 characters. — `notify-cloud` is 12 characters, satisfies this.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. — Provisioned per Human Prerequisites.

> **Invariant 26:** Work items for .NET code work must include an explicit `## NuGet Dependencies` section. `HoneyDrunk.Standards` must be on every new .NET project. — Confirmed in the NuGet Dependencies section above.

> **Invariant 27:** All projects in a solution share one version. — Every `src/*.csproj` ships at `0.1.0`. Test projects do not bump.

> **Invariant 34:** Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`, one per Node per environment, with system-assigned Managed Identity. — `ca-hd-notify-cloud-stg` per Human Prerequisites.

> **Invariant 35:** One shared Container Apps Environment (`cae-hd-{env}`) and one shared Azure Container Registry (`acrhdshared{env}`) serve every containerized Node within a given environment. — `cae-hd-stg` and `acrhdsharedstg` per Human Prerequisites.

> **Invariant 36:** Container App revision mode is `Multiple` with explicit traffic splitting on deploy. — Configured in the deployment workflow inputs.

> **Invariant 39:** Tenant mechanics stay at intake and post-dispatch boundaries. Tenant resolution, tenant rate-limit checks, billing-event emission, and tenant-scoped secret lookup must live in intake middleware/orchestration edges or post-dispatch tails. Core dispatch paths for internal Grid callers must remain tenant-agnostic and default to `TenantId.Internal` without caller-specific branches. — `DefaultNotifyCloudGateway` is the intake middleware (resolves tenant from API key); `BillingEventEmissionTail` is the post-dispatch tail. Internal Grid callers never traverse Notify Cloud and continue to use `TenantId.Internal` through Kernel's `IGridContext` directly.

> **Invariant 40:** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`. Composition against `HoneyDrunk.Communications` is a host-time concern. — Notify Cloud runtime PackageReferences `HoneyDrunk.Communications.Abstractions`, not the runtime. The Container App composes the Communications runtime at host time.

> **Notify Cloud private-repo carve-out invariant (number assigned by packet 02 of this initiative — default 51):** The HoneyDrunk Grid's repo default is public; private repos require an explicit ADR-recorded justification under the revenue/compliance/experiment carve-out. — This repo is private per ADR-0027 D2; LICENSE is `LicenseRef-Proprietary`.

> **Notify Cloud hot-path invariant (number assigned by packet 02 of this initiative — default 52):** Commercial wrappers compose Communications, not Notify, for the hot delivery path. — `DefaultNotifyCloudGateway` calls `ICommunicationOrchestrator`, not `INotificationSender`. The Notify reference is `INotificationSender` for diagnostic/smoke-test paths only.

> **Notify Cloud SDK-in-open-repo invariant (number assigned by packet 02 of this initiative — default 53):** Customer-facing SDKs that cover both self-host and hosted-service consumers ship from the open engine repo. — No SDK source files in this repo. `HoneyDrunk.Notify.Client` lives in `HoneyDrunk.Notify`.

> **Notify Cloud API-key-hashing invariant (number assigned by packet 02 of this initiative — default 54):** API keys are stored only as salted hashes; raw key material is returned to the caller exactly once at issuance time and is never logged, traced, or persisted in raw form. — `HashingNotifyCloudApiKeyStore` enforces salted-hash storage; `ApiKeyIssuance` is the one-time issuance shape carrying the plaintext key.

> **Notify Cloud contract-shape canary invariant (number assigned by packet 02 of this initiative — default 55):** The HoneyDrunk.Notify.Cloud Node CI must include a contract-shape canary that fails the build on shape drift to `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, or `ApiKeyIssuance` without a corresponding version bump. — `api-compatibility.yml` covers this by scoping to `HoneyDrunk.Notify.Cloud.Abstractions`.

> **Notify Cloud FSL-on-engines invariant (number assigned by packet 02 of this initiative — default 56):** The open-source repos paired with `HoneyDrunk.Notify.Cloud` (`HoneyDrunk.Notify`, `HoneyDrunk.Communications`) ship under the Functional Source License (FSL) with two-year auto-conversion to Apache 2.0. The wrapper repo (`HoneyDrunk.Notify.Cloud`, private) is `LicenseRef-Proprietary`. — This repo's LICENSE is `LicenseRef-Proprietary` per ADR-0027 D11. The FSL application to the Notify and Communications repos is the substance of packets 03 and 04 of this initiative.

## Referenced ADR Decisions

**ADR-0027 D1 (Notify Cloud is the Ops sector's multi-tenant commercial wrapper above Notify):** Substrate stand-up. Owns API gateway, API key issuance/validation, per-tenant rate-limit enforcement, tenant-scoped billing-event emission, management website.

**ADR-0027 D2 (Private repo + revenue carve-out):** LICENSE is `LicenseRef-Proprietary`. Release workflow publishes to private feed only. Repo description marks the repo as private.

**ADR-0027 D3 (Package families):** Four packages — `HoneyDrunk.Notify.Cloud.Abstractions`, `HoneyDrunk.Notify.Cloud`, `HoneyDrunk.Notify.Cloud.Billing.Stripe`, `HoneyDrunk.Notify.Cloud.Web`. No `Testing` package at stand-up; in-memory fixtures live as `internal` test helpers until a second consumer emerges. Web stack default is Blazor Server per D3.

**ADR-0027 D4 (Exposed contracts):** Four surfaces — `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, `ApiKeyIssuance`. Records drop `I`; interfaces keep it. Multi-tenant primitives consumed from Kernel per ADR-0026.

**ADR-0027 D5 (Boundary rule):** `DefaultNotifyCloudGateway` delegates to `ICommunicationOrchestrator` for the hot path. Direct calls to `INotificationSender` are diagnostic/smoke-test only.

**ADR-0027 D6 (SDK in open Notify repo):** No SDK source in this packet. `HoneyDrunk.Notify.Client` lives in `HoneyDrunk.Notify`.

**ADR-0027 D7 (Telemetry direction):** `NotifyCloudTelemetry` emits via `ITelemetryActivityFactory` (Kernel). No Pulse PackageReference. Pulse consumes downstream. `tenant_id` is a direct low-cardinality label per the v1 cardinality bound.

**ADR-0027 D8 (Contract-shape canary):** `api-compatibility.yml` is the canary. Scoped to `HoneyDrunk.Notify.Cloud.Abstractions` since per D9 that is the only public-boundary package.

**ADR-0027 D9 (Downstream coupling — leaf node):** Notify Cloud is a leaf in the Grid-internal dependency graph. Its consumers are external customers via REST API or the SDK in the open Notify repo. Production composition is a host-time concern.

**ADR-0027 D11 (FSL on open engine repos, proprietary on the wrapper):** This repo's LICENSE is `LicenseRef-Proprietary`. The FSL application to Notify and Communications is the substance of packets 03 and 04.

**ADR-0027 D12 (API key authentication via Auth):** Validation primitive lives in `HoneyDrunk.Auth` as a new `IApiKeyAuthenticator` middleware path. Issuance lives in Notify Cloud (`INotifyCloudApiKeyStore.IssueAsync`). The Auth-side middleware shape, hashing scheme, and rotation flow are a separate follow-up ADR — this scaffold references `IApiKeyAuthenticator` as a placeholder and the runtime stubs the validation call until the follow-up ADR lands.

**ADR-0027 D13 (Standup checklist):** This packet authors exactly the artifacts listed in D13 — solution layout, `HoneyDrunk.Standards` wiring, CI pipeline, README/CHANGELOG/LICENSE files, in-memory `INotifyCloudApiKeyStore`, default `INotifyCloudGateway`, Container Apps deployment configuration targeting `ca-hd-notify-cloud-stg`. Per D13 the scaffold does NOT include: the Stripe billing adapter implementation (stub only), the Web project's full surface (placeholder only), the API key authentication middleware in Auth (separate ADR), production tenant data (none).

**ADR-0026 (Grid Multi-Tenant Primitives):** Accepted as of 2026-05-20. `TenantId`, `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` consumed from `HoneyDrunk.Kernel.Abstractions.Tenancy`. Notify Cloud is the first real (non-noop) consumer of these primitives.

**ADR-0019 (Communications standup):** `HoneyDrunk.Communications.Abstractions` at v0.2.0 carries `ICommunicationOrchestrator`, `IMessageIntent`, `MessageIntent`. Notify Cloud's hot path delegates here.

**ADR-0015 (Container Hosting Platform):** `job-deploy-container-app.yml` reusable workflow handles Container Apps provisioning. `ca-hd-notify-cloud-stg` is the first deploy target; `cae-hd-stg` shared environment, `acrhdsharedstg` shared registry, system-assigned Managed Identity, `Multiple` revision mode.

## Dependencies
- `work-item:01` — context-folder registration must land first so the Architecture repo's `repos/HoneyDrunk.Notify.Cloud/` matches what this packet ships.
- `work-item:02` — the six Notify Cloud invariants (private-repo carve-out, hot-path-through-Communications, SDK-in-open-repo, API-key-hashing, contract-shape canary, FSL-on-engines) must exist in `constitution/invariants.md` at their assigned numbers before this packet's acceptance criteria reference them.
- `work-item:05` — the GitHub repo must exist before this packet can be filed against it.

## Labels
`feature`, `tier-2`, `ops`, `scaffolding`, `new-node`, `commercial`, `adr-0027`

## Agent Handoff

**Objective:** Take the empty private `HoneyDrunk.Notify.Cloud` repo (created by packet 05) and ship version 0.1.0 with the four D4 contracts, default `INotifyCloudGateway` wiring API key validation → rate-limit → orchestration delegation → billing emission, salted-hash API key store, Notify-Cloud-specific rate-limit policy replacing Kernel's noop, Stripe billing-adapter stub, Web placeholder, full CI including the contract-shape canary, proprietary LICENSE, and Container Apps deployment configuration targeting `ca-hd-notify-cloud-stg`.

**Target:** HoneyDrunk.Notify.Cloud (private), branch from `main`. The repo exists at this point — packet 05 created it Private with an initial README. Branch from `main` for the first feature commit; do not push directly to `main`.

**Context:**
- Goal: Unblock PDR-0002 Phase 3 (Notify Cloud scaffold, weeks 10-14). Without this scaffold, the entire Phase 3 follow-up surface (Stripe integration ADR, API key authentication ADR, Communications decision-log persistence ADR, tenant onboarding workflow doc, Web full-surface packets) has no compile target.
- **Strategic positioning (PDR-0002).** Notify Cloud is the Grid's first commercial Node — the wrapper that converts the open-source Notify and Communications engines into a multi-tenant paid product. PDR-0002 commits to a single-region East US deployment at v1, a private-feed-only release path, and a Stripe-mediated billing model. This packet is the substrate stand-up; the commercial surface (Stripe webhook bridge, signup, billing dashboard) is staged across follow-up packets per PDR-0002 Phase 3. Treat the scaffold quality as the Grid's first impression — every shortcut compounds.
- Feature: ADR-0027 standup initiative — this is the substrate scaffold, the largest packet of the initiative.
- ADRs: ADR-0027 (sole governing ADR for the standup); ADR-0026 (multi-tenant primitives consumed); ADR-0019 (Communications hot-path delegate); ADR-0015 (Container Apps hosting platform); ADR-0033 (deploy-trigger model — staged to follow-up per the Phase 0 note in the deploy-stg.yml block).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01, 02, and 05 of this initiative must complete first.

**Constraints:**

- **Invariant 1 — ADR-0027 D3 carve-out:** Invariant 1 says Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. **ADR-0027 D3 explicitly carves out three permitted Abstractions references for `HoneyDrunk.Notify.Cloud.Abstractions`:** `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Communications.Abstractions`. This is the same pattern `HoneyDrunk.Communications.Abstractions` already follows (it PackageReferences `HoneyDrunk.Kernel.Abstractions`). The strict-Abstractions stance from sibling ADR-0016 / ADR-0017 packets does NOT apply here. Only `HoneyDrunk.Kernel.Abstractions` is load-bearing at v0.1.0 (for `TenantId`); the other two may be omitted if no v0.1.0 contract consumes them. `HoneyDrunk.Standards` is the only `PrivateAssets="all"` reference.
- **Invariant 2 — runtime packages reference Abstractions, not other runtime packages.** `HoneyDrunk.Notify.Cloud.csproj` PackageReferences `HoneyDrunk.Kernel.Abstractions`, NOT `HoneyDrunk.Kernel` (the runtime). The Kernel runtime is composed at host time by the Container App's startup; the Notify Cloud runtime depends only on Abstractions per invariant 2.
- **Kernel multi-tenant primitives are CONSUMED.** Per ADR-0027 D4 and ADR-0026 (Accepted), `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` live in `HoneyDrunk.Kernel.Abstractions.Tenancy`. **Do not redeclare any of these in `HoneyDrunk.Notify.Cloud.Abstractions`.** The Notify Cloud Abstractions package references `HoneyDrunk.Kernel.Abstractions` for `TenantId` only (the type, used as field types on the four D4 contracts). The policy/decision/emitter/event types are consumed at the runtime layer, where `HoneyDrunk.Notify.Cloud` references `HoneyDrunk.Kernel.Abstractions` to pull in `HoneyDrunk.Kernel.Abstractions.Tenancy`.
- **`TenantId` is the strong type, not `string`.** Per ADR-0026 D1, `TenantId` is the canonical Grid tenant identifier — a ULID-backed `readonly record struct` in `HoneyDrunk.Kernel.Abstractions.Identity`. The four D4 contracts use the strong type for every TenantId-shaped field: `NotifyCloudGatewayRequest.TenantIdHint` is `TenantId?` (nullable — see the next constraint); `INotifyCloudApiKeyStore.IssueAsync(TenantId tenantId, ...)`; `INotifyCloudApiKeyStore.ValidateAsync` returns `TenantId?`; `INotifyCloudApiKeyStore.ListForTenantAsync(TenantId tenantId, ...)`; `ApiKeyMetadata.TenantId` is `TenantId`; `ApiKeyIssuance.TenantId` is `TenantId`. **The string-typed boundary is a sibling-packet artifact, not the ADR's intent.**
- **`TenantIdHint` is `TenantId?` (nullable), `TenantId.Internal` is forbidden at the gateway, and `IssueAsync(TenantId.Internal, ...)` throws.** `default(TenantId).Value == Ulid.Empty == TenantId.Internal` — the Internal sentinel and an unset/zeroed `TenantId` are byte-identical. Three layered defenses close the aliasing security hole: (1) `NotifyCloudGatewayRequest.TenantIdHint` is declared `TenantId?` so `null` unambiguously means "no hint" rather than "Internal tenant"; (2) `DefaultNotifyCloudGateway.ProcessAsync` step 1a explicitly rejects validated keys that resolve to `TenantId.Internal` with the `Unauthorized` error code; (3) `HashingNotifyCloudApiKeyStore.IssueAsync` throws `ArgumentException` when called with `TenantId.Internal`. The Internal sentinel is reserved for Grid-internal callers that never traverse the Notify Cloud gateway and have no API keys.
- **`KeyId` / `ApiKeyId` stay `string` at v0.1.0.** Promotion to a record-struct `ApiKeyId` is a follow-up — the API key authentication ADR per ADR-0027 D12 settles it jointly with the Auth-side middleware shape. Leave `KeyId` as `string` with a TODO comment near `INotifyCloudApiKeyStore` pointing at the follow-up ADR.
- **`CallerCorrelationId` stays `string` at v0.1.0.** Promoting the Kernel `CorrelationId` record-struct into Abstractions is a separate Grid-wide decision, not bundled with this Node's stand-up. The runtime's `DefaultNotifyCloudGateway` reconciles the string against the ambient `IGridContext.CorrelationId` via `IGridContextAccessor` (Kernel Abstractions).
- **Records drop `I`; interfaces keep it.** `NotifyCloudTenantTier`, `ApiKeyIssuance`, `NotifyCloudGatewayRequest`, `NotifyCloudGatewayResult`, `NotifyCloudGatewayError`, `ApiKeyMetadata` are all records. `INotifyCloudGateway`, `INotifyCloudApiKeyStore` are interfaces.
- **API keys are salted-hash only, returned exactly once.** Per local invariant 3 and constitutional invariant 54 (default-numbered): `HashingNotifyCloudApiKeyStore.IssueAsync` returns the plaintext via `ApiKeyIssuance` exactly once; the repository persists only `(KeyId, TenantId, Label, Salt, Hash, IssuedAt, RevokedAt)`. No path retrieves the raw key after issuance. Use Argon2id or PBKDF2 (caller-configurable; default Argon2id) for hashing; do not use plain SHA-256. Use `System.Security.Cryptography.CryptographicOperations.FixedTimeEquals` for hash comparison.
- **Hot path goes through Communications.** Per ADR-0027 D5 and constitutional invariant 52 (default-numbered): `DefaultNotifyCloudGateway.ProcessAsync` calls `ICommunicationOrchestrator.OrchestrateAsync` for delivery. The `HoneyDrunk.Notify.Abstractions` reference (for `INotificationSender`) is only for diagnostic/smoke-test paths — do NOT call it from the gateway's customer-facing pipeline.
- **`ITenantRateLimitPolicy` is replaced via `services.Replace(...)`, not added.** Kernel registers `NoopTenantRateLimitPolicy` as the default; Notify Cloud's `TierDrivenTenantRateLimitPolicy` must supersede it, not be added alongside (which would leave the noop in service-resolution order and produce inconsistent enforcement). Per invariant 39, the core dispatch path stays tenant-agnostic for internal callers (using the noop); Notify Cloud's external-call path uses the tier-driven policy.
- **Kernel signature compliance — exact match.** `TierDrivenTenantRateLimitPolicy` MUST implement `ITenantRateLimitPolicy.EvaluateAsync(TenantId tenantId, string operationKey, CancellationToken cancellationToken) → ValueTask<TenantRateLimitDecision>` exactly. NOT `CheckAsync`. NOT `Task<...>`. The parameter is named `operationKey` per the Kernel contract; the gateway maps `request.CapabilityKey` to that slot at the call site. `TenantRateLimitDecision` is positional `(TenantRateLimitOutcome Outcome, TimeSpan? RetryAfter, string? Reason)` — NOT `(bool Allowed, string? DenyReason, int? RetryAfterSeconds)`. Similarly, `IBillingEventEmitter.EmitAsync(BillingEvent, CancellationToken) → ValueTask` (NOT `Task`). `BillingEvent` is 7-positional `(TenantId, string EventType, string OperationKey, long Units, DateTimeOffset OccurredAtUtc, string CorrelationId, IReadOnlyDictionary<string, string> Attributes)`. Conversion from `TenantRateLimitDecision.RetryAfter` (`TimeSpan?`) to `NotifyCloudGatewayError.RetryAfterSeconds` (`int?`) happens at the gateway boundary via `(int)Math.Ceiling(ts.TotalSeconds)`. Kernel's `NoopBillingEventEmitter` does NOT short-circuit on `TenantId.Internal` (it null-checks and returns) — so the gateway itself is responsible for skipping emission on Internal; see `DefaultNotifyCloudGateway` step 8.
- **Capability-availability lives at the gateway, not the rate-limit policy.** The channel-in-tier check (`tier.EnabledChannels.Contains(...)`) is a gateway concern that surfaces the dedicated `CapabilityNotAvailable` error code, not part of `TierDrivenTenantRateLimitPolicy.EvaluateAsync`. The rate-limit policy stays a pure rate-limit policy.
- **Tier resolver is `AddScoped`.** `_tierResolver` is a Notify-Cloud-private DI service backed by `IConfigProvider`, registered as `AddScoped` so that the gateway's read (step 2) and the policy's read share the same scoped instance within a request scope. No duplicate `IConfigProvider` calls; no callback into the keystore for tier data.
- **Tenant tier definitions, cost rates, abuse heuristics are config-sourced.** Per local invariant 5: these come from Azure App Configuration via `IConfigProvider`. Do not hardcode tier definitions, event ceilings, or rate-table values in code. Use `IConfigProvider` reads and document the App Configuration keys in `HoneyDrunk.Notify.Cloud/README.md`.
- **GridContext propagation lives in the runtime, not Abstractions.** `NotifyCloudGatewayRequest.CallerCorrelationId` is `string`, not `Kernel.CorrelationId`. The runtime's `DefaultNotifyCloudGateway` reconciles the string against the ambient `IGridContext.CorrelationId` via `IGridContextAccessor` (Kernel). Same pattern as Capabilities's `DefaultCapabilityInvoker`.
- **No raw API keys, payloads, or PII in telemetry.** Per invariant 8 and constitutional invariant 54 (default-numbered): only metadata (tenant_id, capability_key, outcome, latency_ms). `NotifyCloudTelemetry` activities carry no plaintext request body, no `request.ApiKey`, no recipient details.
- **LICENSE is proprietary.** Per ADR-0027 D11 and constitutional invariant 56 (default-numbered): LICENSE file at repo root with `LicenseRef-Proprietary` content (all rights reserved by default of being private). `<PackageLicenseFile>LICENSE</PackageLicenseFile>` packs into every `.nupkg`. Do NOT use FSL on this repo — FSL applies to the engine repos (Notify, Communications) handled by packets 03 and 04. The wrapper is proprietary.
- **Release workflow publishes to private feed only.** Per ADR-0027 D2 confidentiality: `release.yml` must be configured for the private NuGet feed, not public NuGet. Verify the feed-URL parameter in the workflow before merging. If accidentally configured for public NuGet, reject the workflow and reauthor.
- **Stripe billing-adapter is a stub.** Per ADR-0027 D13: `StripeBillingEventEmitter.EmitAsync` throws `NotImplementedException` with the TODO referencing the follow-up Stripe billing integration ADR. The scaffold's end-to-end smoke test uses an in-memory `LoggingBillingEventEmitter` (internal test helper in the runtime project's test project, per D3 "in-memory fixtures live as `internal` test helpers until a second consumer emerges").
- **Web project is a placeholder.** Per ADR-0027 D13: health endpoint + signup form scaffold (Blazor Server) only. Do NOT implement signup logic, billing dashboard, or delivery logs — those are follow-up packets.
- **API key authentication middleware in Auth is a follow-up.** Per ADR-0027 D12: the `IApiKeyAuthenticator` interface exists in `HoneyDrunk.Auth.Abstractions` (or will, once the follow-up ADR lands). For v0.1.0, the gateway calls `_apiKeyStore.ValidateAsync(request.ApiKey, ct)` directly (the Notify-Cloud-local store), with a TODO comment marking the spot where `IApiKeyAuthenticator` middleware will wrap this call once the follow-up ADR lands. The TODO must reference ADR-0027 D12.
- **Container App service name must be ≤ 13 characters per invariant 19.** `notify-cloud` is 12 characters — fits. `ca-hd-notify-cloud-{env}` per invariant 34; `kv-hd-notify-cloud-{env}` per invariant 17.
- **Canary on the scaffolding PR is expected to report `status: skipped`, not fail.** The shared `HoneyDrunk.Actions/.github/actions/api/check-compatibility/action.yml` emits `::warning::` and exits 0 with `status: skipped` when `git worktree add` against the baseline ref fails — which it always does on a first PR against a near-empty repo. Do not treat the skip as a misconfiguration. The scaffolding PR's merge establishes the `main` baseline; verification of the canary actually firing happens **post-merge** via a throwaway breaking-change PR that is reverted after observation.
- **Notify Cloud Abstractions reference policy is ADR-0027 D3, not the strict-Abstractions stance from sibling packets.** ADR-0027 D3 reads: "Zero runtime dependencies beyond `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Notify.Abstractions`, and `HoneyDrunk.Communications.Abstractions`." This is a deliberate carve-out — the Communications.Abstractions package (closest sibling) already PackageReferences `HoneyDrunk.Kernel.Abstractions` and that is the established Ops-sector pattern. Concretely: `NotifyCloudGatewayRequest.TenantIdHint` is `TenantId` (the Kernel strong type from `HoneyDrunk.Kernel.Abstractions.Identity` per ADR-0026 D1); `NotifyCloudGatewayRequest.CallerCorrelationId` stays `string` at v0.1.0 (promoting `CorrelationId` to a record-struct in Kernel.Abstractions is a separate Grid-wide decision); the four contracts PackageReference `HoneyDrunk.Kernel.Abstractions`. The other two carved-out references (`HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Communications.Abstractions`) may be omitted at v0.1.0 if no contract consumes them; both stay permitted by D3 for future extension.

**Key Files:**
- `HoneyDrunk.Notify.Cloud.slnx`, `Directory.Build.props`, `LICENSE` (proprietary)
- `src/HoneyDrunk.Notify.Cloud.Abstractions/INotifyCloudGateway.cs`, `INotifyCloudApiKeyStore.cs`, `NotifyCloudTenantTier.cs`, `ApiKeyIssuance.cs`, supporting record/enum types
- `src/HoneyDrunk.Notify.Cloud/ServiceCollectionExtensions.cs`, `Gateway/DefaultNotifyCloudGateway.cs`, `ApiKeys/HashingNotifyCloudApiKeyStore.cs`, `RateLimiting/TierDrivenTenantRateLimitPolicy.cs`, `Billing/BillingEventEmissionTail.cs`, `Telemetry/NotifyCloudTelemetry.cs`
- `src/HoneyDrunk.Notify.Cloud.Billing.Stripe/StripeBillingEventEmitter.cs` (stub)
- `src/HoneyDrunk.Notify.Cloud.Web/Program.cs`, `Pages/Health.razor`, `Components/SignupPlaceholder.razor`
- `.github/workflows/{pr-core,release,nightly-deps,nightly-security,api-compatibility,deploy-stg}.yml`
- `README.md`, `CHANGELOG.md` (repo-level), per-package `README.md` and `CHANGELOG.md`
- `tests/HoneyDrunk.Notify.Cloud.Tests/`, `tests/HoneyDrunk.Notify.Cloud.Billing.Stripe.Tests/`, etc.

**Contracts:**
- All four D4 contracts authored fresh in this packet inside `HoneyDrunk.Notify.Cloud.Abstractions`. The contracts use the strong `TenantId` type (`HoneyDrunk.Kernel.Abstractions.Identity.TenantId`) for every TenantId-shaped field per ADR-0026 D1; `KeyId` stays `string` at v0.1.0 with a TODO referencing the API key authentication ADR follow-up.
- The contract-shape canary establishes its baseline against this packet's commit. Future shape changes to any public type in Abstractions trigger the canary.
- **Do NOT redeclare** `TenantId`, `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, or `BillingEvent` in this repo. `TenantId` lives in `HoneyDrunk.Kernel.Abstractions.Identity`; the policy / decision / emitter / event types live in `HoneyDrunk.Kernel.Abstractions.Tenancy`. All five are consumed via the `HoneyDrunk.Kernel.Abstractions` PackageReference per ADR-0026.
