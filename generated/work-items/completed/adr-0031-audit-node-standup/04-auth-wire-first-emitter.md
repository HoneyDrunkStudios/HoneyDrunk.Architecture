---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Auth
labels: ["feature", "tier-2", "auth", "audit", "adr-0031"]
dependencies: ["work-item:03"]
adrs: ["ADR-0031", "ADR-0030", "ADR-0026", "ADR-0027"]
accepts: ADR-0031
wave: 3
initiative: adr-0031-audit-node-standup
node: honeydrunk-auth
---

# Feature: Wire HoneyDrunk.Auth as the first `IAuditLog` emitter — durable security events (login attempts, authz grants/denials)

## Summary
Wire `HoneyDrunk.Auth` to emit durable `AuditEntry` records via `IAuditLog` for the two event classes ADR-0030 D6 names — token-validation outcomes (login-attempt analogue: bearer-token validation success/failure) and authorization-policy decisions (grants and denials). Auth becomes the first real emitter against the substrate stood up by packet 03. The emission is **additive** to Auth's existing OTel traces, on the separate durable channel per the substrate-level audit-emission boundary invariant `47` (landed by ADR-0030 packet 02) — Auth's identity-out-of-traces invariant is untouched (audit records are out-of-band of traces, and the existing trace enrichment is not changed; what Auth was already tracing it continues to trace, and the new audit emission lives in parallel).

This packet does **not** introduce identity-bearing PII into Auth's OTel traces; audit records carry actor/correlation/tenant in their own durable channel.

**Invariant numbers assigned.** Audit constitutional invariants are 47 (audit-emission boundary), 48 (downstream Abstractions-only coupling), and 49 (Audit contract-shape canary).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Auth`

## Motivation

Per ADR-0030 D6 / ADR-0031 D6, Auth is the first emitter against the substrate. Two event classes:

- **Token validation outcomes** — `BearerTokenAuthenticationProvider` validates a bearer token; today the outcome lives only in sampled OTel traces (with identity deliberately kept out per Auth's identity-out-of-traces invariant). Durable, attributable audit solves this without compromising the trace invariant.
- **Authorization-policy decisions** — `DefaultAuthorizationPolicy.EvaluateAsync` returns Allow or Deny; same trace-only problem today. **Emission lives on `DefaultAuthorizationPolicy`, NOT `AuthorizationPolicyEvaluator`.** `AuthorizationPolicyEvaluator.Evaluate(...)` is a `public sealed class` with a `static` method — the pure, side-effect-free decision core. `DefaultAuthorizationPolicy` is the I/O-side Singleton decorator (`IAuthorizationPolicy`) that already wraps the pure evaluator with telemetry/logging. Audit goes there too. Injecting `IAuditLog` into the static evaluator is structurally impossible and would defeat its deliberate purity.

Per ADR-0030 D6: recording is additive to OTel traces, on a separate durable channel, identity-out-of-traces invariant untouched.

## Proposed Implementation

### Add `HoneyDrunk.Audit.Abstractions` PackageReference

In `HoneyDrunk.Auth/HoneyDrunk.Auth.csproj`, add:

```xml
<PackageReference Include="HoneyDrunk.Audit.Abstractions" Version="0.1.0" />
```

**Per invariant `48` (this initiative, packet 01): downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`.** Do not add `HoneyDrunk.Audit.Data` — composition is a host-time concern. The host that deploys Auth registers `IAuditLog` and `IAuditQuery` via `services.AddHoneyDrunkAuditData()` (or whichever backing-slot composition the host chooses); Auth just consumes `IAuditLog` from DI.

### Inject `IAuditLog` into the two emitting classes

**`BearerTokenAuthenticationProvider`** — Add two constructor-injected dependencies alongside the existing parameters: `IAuditLog` and `IGridContextAccessor`. The `IAuditLog` injection is **optional** at the DI-resolution layer: if no `IAuditLog` is registered in the host's container, Auth resolves a no-op stub and logs a `::warning::` at startup ("HoneyDrunk.Audit.Abstractions.IAuditLog is not registered; security event audit emission is disabled. Compose HoneyDrunk.Audit.Data (or another IAuditLog backing) in the host to enable durable security-event audit per the Grid's audit-emission boundary invariant."). The Hive board can carry a follow-up "wire Audit composition in host X" item if a host ships Auth-with-audit without an `IAuditLog` registration.

**Why optional rather than required.** Auth ships as a library Node consumed by multiple hosts; some hosts (e.g., the canary project at v0.4.0) may not have an audit backing wired yet. Hard-failing on `IAuditLog` missing would break those hosts' first build against `HoneyDrunk.Auth` v0.5.0. The no-op stub + startup `::warning::` is the same pattern Communications uses for optional decision-log composition (ADR-0019); see `HoneyDrunk.Communications` for reference.

**`DefaultAuthorizationPolicy`** — Same pattern: add `IAuditLog` and `IGridContextAccessor` to the existing primary-constructor parameter list (`ITelemetryActivityFactory telemetryFactory, ILogger<DefaultAuthorizationPolicy> logger, IAuditLog auditLog, IGridContextAccessor gridContextAccessor`). Emission lands inside `EvaluateAsync` after the existing `RecordTelemetry`/`LogDecision` calls, on the same return path that already returns `Task.FromResult(decision)`. The pure static `AuthorizationPolicyEvaluator.Evaluate` is **not** touched — keeping it pure is the whole reason `DefaultAuthorizationPolicy` exists.

### Lifetime story — Singleton emitters with `IGridContextAccessor` (avoid captive-dep)

`BearerTokenAuthenticationProvider` and `DefaultAuthorizationPolicy` are registered Singleton by `HoneyDrunkAuthServiceCollectionExtensions.AddHoneyDrunkAuth()` (lines 83, 86). `IGridContext` is Scoped — direct ctor injection into a Singleton is the captive-dep anti-pattern.

Both emitters take `IGridContextAccessor` (ambient access, Singleton-friendly) instead. Per its XML docs: "exists for scenarios where constructor injection is not feasible (e.g., static methods, cross-cutting concerns)." At emit site:

```csharp
var gridContext = _gridContextAccessor.GridContext; // current scope's instance
// build AuditEntry with gridContext.CorrelationId / gridContext.TenantId
```

`IGridContextAccessor` is already in `ValidateKernelServices()` required list (line 99). **Do NOT add `IGridContext` directly to either constructor.**

### Emission shape

**On token validation in `BearerTokenAuthenticationProvider`:**

After `ValidateTokenAsync(...)` returns its `AuthenticationResult`, before `AuthenticateAsync` returns to caller, emit. Inspect the actual `AuthenticationResult` shape at `HoneyDrunk.Auth.Abstractions/AuthenticationResult.cs` — success-discriminator is `IsAuthenticated` (bool), `Identity` is nullable `AuthenticatedIdentity?` populated on success, `Identity.SubjectId` is non-null `string` on success:

```csharp
var gridContext = _gridContextAccessor.GridContext;
try
{
    await _auditLog.AppendAsync(new AuditEntry(
        Id: AuditEntryId.Empty,
        OccurredAt: DateTimeOffset.UtcNow,
        Actor: result.Identity?.SubjectId ?? "anonymous",
        Action: "auth.token.validate",
        Outcome: result.IsAuthenticated ? "granted" : "denied",
        CorrelationId: gridContext.CorrelationId,  // already string; no .ToString()
        TenantId: gridContext.TenantId,            // Kernel strong type per ADR-0026 — pass through
        Context: BuildValidationContext(result)
    ), cancellationToken);
}
catch (Exception ex)
{
    _logger.LogError(ex, "Audit emission failed for token validation; authentication outcome is unchanged");
}
```

`BuildValidationContext` produces JSON-shaped string with non-identity-bearing metadata: token-id (`jti`), issuer (`iss`), audience (`aud`), expiration (`exp`), plus `FailureCode`+`FailureMessage` when `IsAuthenticated == false`. **No raw token text. No claim values beyond identifier claims.** Use the `AuditAllowedClaims` constant (below) — single source of truth.

**Emit failure must not fail the request.** try/catch logs and continues — audit-store SLO problem, not Auth's.

**`IGridContext.CorrelationId` is `string` at v0.1.0** (see `HoneyDrunk.Kernel.Abstractions/Context/IGridContext.cs:52`). Pass-through direct, no `.ToString()`. v0.2.0 follow-up wraps as `new CorrelationId(gridContext.CorrelationId)` when `AuditEntry.CorrelationId` promotes.

**On authorization-policy decision in `DefaultAuthorizationPolicy`:**

After existing `RecordTelemetry(activity, decision)` + `LogDecision(request, decision)` inside `EvaluateAsync`, before `return Task.FromResult(decision);`, emit (same try/catch shape) with `Actor: identity?.SubjectId ?? "anonymous"`, `Action: $"auth.authorize.{request.Action}"`, `Outcome: decision.IsAllowed ? "granted" : "denied"`, `Context: BuildAuthorizationContext(decision, request)`. The method body's last line changes from `return Task.FromResult(decision);` to `await _auditLog.AppendAsync(...); return decision;` (method becomes truly async).

Verify against `HoneyDrunk.Auth/Authorization/DefaultAuthorizationPolicy.cs`:

- `EvaluateAsync(AuthenticatedIdentity? identity, AuthorizationRequest request, CancellationToken)` — `identity` is the parameter; null identity already short-circuits to a `NotAuthenticated` deny inside the static evaluator, but the audit emission still happens with `Actor="anonymous"` so denied attempts are durably recorded.
- `decision.IsAllowed` — **NOT `IsGranted`** (line 67 of existing `RecordTelemetry`).
- `request.Action` — `string` verb (`read`/`write`/`delete`). Use directly in `auth.authorize.{request.Action}`. `PolicyName` is always `"Default"`, so it goes in `Context`, not `Action`.

`Context` carries policy name, `request.Resource` identifier (existing identifier, not new identity surface), `decision.SatisfiedRequirements`, and `decision.DenyReasons` (codes only, since messages can contain subject IDs per existing `LogDecision`).

### `AuditAllowedClaims` whitelist — production constant

In `BearerTokenAuthenticationProvider`:

```csharp
private static readonly HashSet<string> AuditAllowedClaims = new(StringComparer.Ordinal)
{ "jti", "iss", "aud", "exp" };
```

`BuildValidationContext` iterates result claims and emits only keys matching `AuditAllowedClaims` into the JSON. Test `BearerTokenAuthenticationProvider_AuditContext_RespectsAllowedClaimsWhitelist` references the same constant — single source of truth.

### `Context` size limit (Phase-1 defensive truncation)

`AuditEntry.Context` is unbounded `string?` at the contract surface. Both emission sites cap the serialized JSON at **4096 bytes** (4 KiB) — pathological JWT with a 10MB `iss` claim cannot blow up a single audit row. If over cap, truncate and append `"...[truncated]"`:

```csharp
private const int AuditContextMaxBytes = 4096;
private static string CapContext(string json)
{
    if (System.Text.Encoding.UTF8.GetByteCount(json) <= AuditContextMaxBytes) return json;
    var bytes = System.Text.Encoding.UTF8.GetBytes(json);
    return System.Text.Encoding.UTF8.GetString(bytes, 0, AuditContextMaxBytes - 16) + "...[truncated]";
}
```

Phase-2 revisits when Audit ships its own context-size policy.

### No-op stub class

Add `HoneyDrunk.Auth/Authentication/NullAuditLog.cs` (or similar location):

```csharp
internal sealed class NullAuditLog : IAuditLog
{
    public Task AppendAsync(AuditEntry entry, CancellationToken cancellationToken = default)
        => Task.CompletedTask;
}
```

This is the fallback registered by `HoneyDrunkAuthServiceCollectionExtensions.AddHoneyDrunkAuth()` when no `IAuditLog` is already in the container. The registration uses `services.TryAddSingleton<IAuditLog, NullAuditLog>()` so a host-side `AddHoneyDrunkAuditData()` (or any other backing) takes precedence — the `Try` semantics mean Auth's stub only wins if nothing else is registered.

### Startup warning when `NullAuditLog` is active

The startup hook is `HoneyDrunk.Auth/Lifecycle/AuthStartupHook.cs` — the existing `IStartupHook` registered by `HoneyDrunkAuthServiceCollectionExtensions.AddHoneyDrunkAuth()` at line 89 of `HoneyDrunkAuthServiceCollectionExtensions.cs`. It already validates Auth's signing-key/issuer/audience configuration via `ExecuteAsync` and throws `InvalidOperationException` on fatal misconfiguration. Extend its constructor to also accept `IAuditLog` (resolved from the same scope), and at the end of `ExecuteAsync` — after the existing validation succeeds — check if the resolved `IAuditLog` is the `NullAuditLog` stub. If so, log a `::warning::` (do NOT throw — a missing audit backing is a degraded state, not a fatal one; Auth still validates tokens). The check itself is `auditLog is NullAuditLog` — internal-sealed type so the cast works inside the Auth assembly; `InternalsVisibleTo` is not needed because both classes live in the same `HoneyDrunk.Auth` assembly.

The warning text:

```
WARN HoneyDrunk.Audit.Abstractions.IAuditLog is not registered in the host container; security event audit emission is disabled (NullAuditLog stub active). Compose HoneyDrunk.Audit.Data (or another IAuditLog backing) in the host to enable durable security-event audit per the Grid's audit-emission boundary invariant. See https://github.com/HoneyDrunkStudios/HoneyDrunk.Audit#for-downstream-consumers---minimal-wiring.
```

This is a startup-time signal that a deployed host is non-compliant with the substrate-level audit-emission boundary invariant `47` (auditable security events emitted to the Audit substrate). The Hive can carry a follow-up to enforce this at host-level CI later; for now it is a developer-visible warning.

### Tests

Add under `HoneyDrunk.Auth.Tests/`:

- `BearerTokenAuthenticationProvider_EmitsAuditEntry_OnValidToken` — `Outcome=granted`, `Action=auth.token.validate`.
- `BearerTokenAuthenticationProvider_EmitsAuditEntry_OnInvalidToken` — `Outcome=denied`.
- `BearerTokenAuthenticationProvider_DoesNotFailRequest_WhenAuditLogThrows` — throwing `IAuditLog`; authentication still completes; throw logged at Error.
- `BearerTokenAuthenticationProvider_AuditContext_RespectsAllowedClaimsWhitelist` — token with `jti`/`iss`/`sub`/`name`/`secret-claim`; assert `Context` contains `jti`/`iss` only; no raw token text. Includes the 10 KB `iss` truncation case (≤ 4096 bytes ending in `"...[truncated]"`).
- `DefaultAuthorizationPolicy_EmitsAuditEntry_OnAllow` — `decision.IsAllowed == true` → `Outcome=granted`.
- `DefaultAuthorizationPolicy_EmitsAuditEntry_OnDeny` — `IsAllowed == false` → `Outcome=denied`.
- `NullAuditLog_IsDefault_WhenNothingElseRegistered` + `HostRegisteredIAuditLog_TakesPrecedenceOverNullAuditLog` — verifies `TryAddSingleton` semantics.
- `AuthStartupHook_LogsWarning_WhenAuditLogIsNullAuditLog` — `::warning::` fires at startup.

### Test double policy

Auth does NOT depend on `HoneyDrunk.Audit.Testing` (no such package at Audit v0.1.0 per ADR-0031 D2 / ADR-0027 D3). Hand-written ≈ 20-line `InMemoryAuditLog` in `HoneyDrunk.Auth.Tests/Fakes/` — `List<AuditEntry>` + lock + `AppendAsync` + `Snapshot()`. Future cut to `HoneyDrunk.Audit.Testing` is non-breaking.

### Canary project update

Add one end-to-end audit-emission test in `HoneyDrunk.Auth.Canary` using the in-memory test double (no backing required).

### Version bump

Per invariant 27, bump every `src/*.csproj` `<Version>` from `0.4.0` to `0.5.0` in one commit. Test projects do not bump.

### CHANGELOG entries (repo-level + per-package)

**Per memory `feedback_no_unreleased_commits`: no `## Unreleased` block at commit time.** Land entries under `## [0.5.0] - YYYY-MM-DD`.

**Repo-level `CHANGELOG.md`:**

```
## [0.5.0] - YYYY-MM-DD

### Added
- HoneyDrunk.Auth now emits durable AuditEntry records via IAuditLog for token-validation outcomes (auth.token.validate) and authorization-policy decisions (auth.authorize.{policyName}). The emission is additive to existing OTel traces, on the separate durable audit channel per the Grid's audit-emission boundary invariant. Auth's identity-out-of-traces invariant is untouched — audit records are out-of-band of traces and carry no token text, claim values, or other PII beyond the actor identifier.
- HoneyDrunk.Audit.Abstractions 0.1.0 added as a PackageReference (the only Audit dependency Auth takes, per the downstream-Abstractions-only coupling invariant).
- NullAuditLog stub registered via TryAddSingleton; hosts that do not compose an IAuditLog backing get a no-op fallback with a startup warning.
```

**Per-package `CHANGELOG.md` for `HoneyDrunk.Auth`:** mirror the same entry (this package has the actual code change).

**Per-package `CHANGELOG.md` for `HoneyDrunk.Auth.Abstractions` and `HoneyDrunk.Auth.AspNetCore`:** these did not change in this packet (the actual code change is in `HoneyDrunk.Auth`). Per invariant 27 ("per-package CHANGELOG.md updated only for packages with actual changes — do not add alignment-bump noise entries"), do not add a `## [0.5.0]` entry to these. They are version-bumped to 0.5.0 in the same commit per invariant 27's single-solution-version rule, but the changelogs do not get noise entries.

### README updates

Update `HoneyDrunk.Auth/README.md` to mention the audit emission. Add a short section (≈ 5 lines) describing what Auth records to `IAuditLog`, that it requires a host-side `AddHoneyDrunkAuditData()` (or other backing) to actually persist, and that the emission is additive (Auth's identity-out-of-traces invariant is preserved). **Per memory `feedback_no_adr_in_docs`, do not cite "ADR-0030" or "ADR-0031" by number in the README narrative** — describe what the package does. Link to `HoneyDrunk.Audit`'s README for downstream-consumer wiring guidance.

### Architecture-side follow-up (separate packet)

This packet is Auth-only. `file-work-items.yml` cannot cross-commit. The Architecture edit (`repos/HoneyDrunk.Auth/integration-points.md` — add Audit row under "Upstream Dependencies" naming `IAuditLog`) is a separate follow-up Architecture packet, filed after this PR merges. Listed in the dispatch-plan's "What This Initiative Does NOT Deliver".

## Affected Files

All edits live inside `HoneyDrunkStudios/HoneyDrunk.Auth`. The Architecture-side `repos/HoneyDrunk.Auth/integration-points.md` reconciliation is a separate follow-up packet (see "Architecture-side" section above) — it does not appear here because `target_repo` is Auth.

- `HoneyDrunk.Auth/HoneyDrunk.Auth/HoneyDrunk.Auth.csproj` — add `HoneyDrunk.Audit.Abstractions` PackageReference; bump `<Version>` to 0.5.0
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Abstractions/HoneyDrunk.Auth.Abstractions.csproj` — bump `<Version>` to 0.5.0 (alignment, per invariant 27)
- `HoneyDrunk.Auth/HoneyDrunk.Auth.AspNetCore/HoneyDrunk.Auth.AspNetCore.csproj` — bump `<Version>` to 0.5.0 (alignment, per invariant 27)
- `HoneyDrunk.Auth/HoneyDrunk.Auth/Authentication/BearerTokenAuthenticationProvider.cs` — add `IAuditLog` + `IGridContextAccessor` to the primary constructor's parameter list (the class uses primary-constructor syntax); add `AuditAllowedClaims` static readonly HashSet constant + `AuditContextMaxBytes` const + `CapContext` helper + `BuildValidationContext` method that consults the whitelist; insert the audit emit + try/catch inside `AuthenticateAsync` between the existing `ValidateTokenAsync` call result and the return-to-caller path
- `HoneyDrunk.Auth/HoneyDrunk.Auth/Authorization/DefaultAuthorizationPolicy.cs` — add `IAuditLog` + `IGridContextAccessor` to the existing primary-constructor parameter list (next to `telemetryFactory`/`logger`); add `BuildAuthorizationContext` helper; insert the audit emit + try/catch inside `EvaluateAsync` between `LogDecision(...)` and the existing return; the method body's last two statements change from `return Task.FromResult(decision);` to `await _auditLog.AppendAsync(...); return decision;` (the method becomes truly `async`). **Note: `AuthorizationPolicyEvaluator.cs` (the pure static decision core) is NOT touched.**
- `HoneyDrunk.Auth/HoneyDrunk.Auth/Authentication/NullAuditLog.cs` (new) — no-op `IAuditLog` stub, `internal sealed`
- `HoneyDrunk.Auth/HoneyDrunk.Auth/DependencyInjection/HoneyDrunkAuthServiceCollectionExtensions.cs` — add `services.TryAddSingleton<IAuditLog, NullAuditLog>()` registration inside `AddHoneyDrunkAuth(IServiceCollection, Action<AuthOptions>)`, alongside the existing `BearerTokenAuthenticationProvider` and `DefaultAuthorizationPolicy` registrations (lines 83 and 86 of the existing file)
- `HoneyDrunk.Auth/HoneyDrunk.Auth/Lifecycle/AuthStartupHook.cs` — extend existing class: add `IAuditLog` to the primary-constructor parameter list, and at the end of `ExecuteAsync` (after the existing signing-key/issuer/audience validation succeeds) check `auditLog is NullAuditLog` and `_logger.LogWarning(...)` the deferred-composition message
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/Fakes/InMemoryAuditLog.cs` (new) — narrowly-scoped test double
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/Authentication/BearerTokenAuthenticationProviderTests.cs` — add the four audit-emission tests; the no-token-text test verifies the `AuditAllowedClaims` whitelist constant is the source of truth
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/Authorization/DefaultAuthorizationPolicyTests.cs` — add the two audit-emission tests (grant, deny). (If the test file currently exists under a different name following the production-class name change — e.g., the historical `AuthorizationPolicyEvaluatorTests.cs` against the static class — verify and add tests to whichever file covers `DefaultAuthorizationPolicy.EvaluateAsync`.)
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/Lifecycle/AuthStartupHookTests.cs` — add `AuthStartupHook_LogsWarning_WhenAuditLogIsNullAuditLog` (the existing file is confirmed at this path; verify ctor signature in the test matches the new IAuditLog parameter)
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/DependencyInjection/HoneyDrunkAuthServiceCollectionExtensionsTests.cs` — add `NullAuditLog_IsDefault_WhenNothingElseRegistered` + `HostRegisteredIAuditLog_TakesPrecedenceOverNullAuditLog`
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Canary/` — add a single end-to-end audit-emission canary test
- `HoneyDrunk.Auth/HoneyDrunk.Auth/README.md` — short section describing audit emission
- `HoneyDrunk.Auth/CHANGELOG.md` — `## [0.5.0]` entry (repo-level)
- `HoneyDrunk.Auth/HoneyDrunk.Auth/CHANGELOG.md` — `## [0.5.0]` entry (per-package, the only one that changed)

## NuGet Dependencies

### `HoneyDrunk.Auth/HoneyDrunk.Auth.csproj` (modified)

| Package | Version | Notes |
|---|---|---|
| `HoneyDrunk.Audit.Abstractions` | `0.1.0` | **NEW** — per invariant `48` (downstream Abstractions-only coupling), the only Audit dependency Auth takes. Do not add `HoneyDrunk.Audit.Data` (composition is host-time). |
| `HoneyDrunk.Kernel.Abstractions` | `0.7.0` | unchanged |
| `HoneyDrunk.Standards` | `0.2.7` | `PrivateAssets="all"` — unchanged |
| `HoneyDrunk.Vault` | `0.5.0` | unchanged |
| `HoneyDrunk.Vault.Providers.AppConfiguration` | `0.5.0` | unchanged |
| `HoneyDrunk.Vault.Providers.AzureKeyVault` | `0.5.0` | unchanged |
| `Microsoft.Extensions.Configuration.Binder` | `10.0.6` | unchanged |
| `Microsoft.IdentityModel.JsonWebTokens` | `8.17.0` | unchanged |

### `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests` (modified — new tests added but no PackageReference additions)

The test project already references `xunit`, `Microsoft.NET.Test.Sdk`, etc. No new PackageReferences needed — the `InMemoryAuditLog` test double is a hand-written class file.

## Boundary Check

- [x] Auth references `HoneyDrunk.Audit.Abstractions` only — **NOT** `HoneyDrunk.Audit.Data`. Invariant `48` (downstream Abstractions-only coupling) honored.
- [x] Audit emission is additive to existing OTel traces. Auth's existing trace enrichment is unchanged; no identity-bearing PII is added to traces. Invariant `47` (audit-emission boundary, durable channel separate from observability) honored.
- [x] No token text or claim values beyond the `AuditAllowedClaims` static whitelist (`jti`, `iss`, `aud`, `exp`) appear in `AuditEntry.Context`. Production code reads the whitelist constant; the test `BearerTokenAuthenticationProvider_AuditContext_RespectsAllowedClaimsWhitelist` verifies the constant is the single source of truth.
- [x] `AuditEntry.Context` is capped at 4096 bytes via `CapContext` (Phase-1 defensive truncation). A pathological token cannot blow up a single audit row.
- [x] Audit emit failure does not fail the request. Wrapped in try/catch with error log. Test `BearerTokenAuthenticationProvider_DoesNotFailRequest_WhenAuditLogThrows` enforces this.
- [x] `NullAuditLog` stub is the fallback when no host-side backing is composed. Registered via `TryAddSingleton` so host-side registrations win. Startup `::warning::` makes the no-op state visible.
- [x] Test double lives in `HoneyDrunk.Auth.Tests/Fakes/`, hand-written, NOT taken from a `HoneyDrunk.Audit.Testing` package (no such package exists at Audit v0.1.0; per ADR-0031 D2 and ADR-0027 D3 precedent).
- [x] Single solution version per invariant 27 — both `Abstractions` and `Auth.AspNetCore` `.csproj` `<Version>` bumped to 0.5.0 even though only `HoneyDrunk.Auth` changed. Per-package CHANGELOG updates land only for the package that actually changed (`HoneyDrunk.Auth`), per invariant 27's no-alignment-noise rule.
- [x] **Both emitters stay Singleton; inject `IGridContextAccessor`, NOT `IGridContext`** (captive-dep avoidance — see Lifetime story).
- [x] **`AuthorizationPolicyEvaluator` (pure static decision core) is not touched.** Audit emission lands on `DefaultAuthorizationPolicy.EvaluateAsync` (the I/O-side decorator).

## Acceptance Criteria

- [ ] `HoneyDrunk.Auth/HoneyDrunk.Auth.csproj` contains `<PackageReference Include="HoneyDrunk.Audit.Abstractions" Version="0.1.0" />`.
- [ ] `HoneyDrunk.Auth/HoneyDrunk.Auth.csproj` does NOT contain `HoneyDrunk.Audit.Data` (invariant `48` — downstream Abstractions-only coupling — enforced).
- [ ] `BearerTokenAuthenticationProvider.AuthenticateAsync` emits an `AuditEntry` with `Action=auth.token.validate` after every `ValidateTokenAsync` returns. `Outcome=granted` on `result.IsAuthenticated == true`, `Outcome=denied` otherwise (invalid signature/issuer/audience, expired, missing-claim, unsupported scheme — all fall under `IsAuthenticated == false`). **`result.IsValid` is NOT the property name — `AuthenticationResult` exposes `IsAuthenticated`** (see `HoneyDrunk.Auth.Abstractions/AuthenticationResult.cs:23`).
- [ ] `DefaultAuthorizationPolicy.EvaluateAsync` emits an `AuditEntry` with `Action=auth.authorize.{request.Action}` after `AuthorizationPolicyEvaluator.Evaluate(...)` returns and the existing telemetry/logging side-effects run. `Outcome=granted` on `decision.IsAllowed == true`, `Outcome=denied` otherwise. **`AuthorizationDecision.IsGranted` is NOT the property name — the existing field is `IsAllowed`** (see `HoneyDrunk.Auth/Authorization/DefaultAuthorizationPolicy.cs:67` where it's already used by `RecordTelemetry`).
- [ ] **The static `AuthorizationPolicyEvaluator` is not touched.** Audit emission lands in `DefaultAuthorizationPolicy` (the I/O-side decorator), not in the pure static class. Verified by `git diff` showing no edits under `Authorization/AuthorizationPolicyEvaluator.cs`.
- [ ] `AuditEntry.Actor` is set from `result.Identity?.SubjectId` (for authentication) or `identity?.SubjectId` (for authorization, where `identity` is the `AuthenticatedIdentity?` parameter of `EvaluateAsync`), falling back to `"anonymous"` only when no subject is resolved.
- [ ] `AuditEntry.CorrelationId` comes from `gridContext.CorrelationId` resolved via `_gridContextAccessor.GridContext` at emit time — **no `.ToString()` call** (`IGridContext.CorrelationId` is already declared as `string` per `IGridContext.cs:52`). The v0.2.0 follow-up to wrap with `new CorrelationId(...)` when `AuditEntry.CorrelationId` promotes to the Kernel strong type is captured in packet 03's contract notes and is not part of this packet.
- [ ] `AuditEntry.TenantId` is passed through directly from `gridContext.TenantId` as the Kernel `TenantId` strong type (per ADR-0026; `AuditEntry.TenantId` is the typed value, not stringified). The non-null `TenantId.Internal` sentinel handles header-less internal callers — Auth does not need any null-handling or default-fallback at the emission site.
- [ ] `AuditEntry.Context` is a JSON-shaped string containing only non-PII metadata. **The `AuditAllowedClaims` static readonly HashSet constant (= `{ "jti", "iss", "aud", "exp" }`, ordinal comparer)** is the single source of truth — `BuildValidationContext` reads from it; the test `BearerTokenAuthenticationProvider_AuditContext_RespectsAllowedClaimsWhitelist` reads the same constant. Token text, claim values beyond identifier claims, and bearer-token contents NEVER appear in `Context`.
- [ ] **`AuditEntry.Context` is capped at 4096 bytes via `CapContext`.** A test verifies that a token with a fabricated 10 KB `iss` claim produces an `AuditEntry.Context` of at most 4096 bytes ending in the `"...[truncated]"` sentinel.
- [ ] Audit emission failures (e.g., `IAuditLog.AppendAsync` throws) are caught, logged at `Error` level via the existing `ILogger<BearerTokenAuthenticationProvider>` / `ILogger<DefaultAuthorizationPolicy>`, and do **not** fail authentication or authorization. The existing request handling continues to return the `AuthenticationResult`/`AuthorizationDecision` it would have returned without the emit step.
- [ ] **Both emitting classes inject `IGridContextAccessor`, NOT `IGridContext` directly.** `git diff` shows the constructor parameter lists for `BearerTokenAuthenticationProvider` and `DefaultAuthorizationPolicy` include `IGridContextAccessor gridContextAccessor` (and `IAuditLog auditLog`). Neither class takes a direct `IGridContext` ctor parameter — that would be a captive-dep on a Scoped dependency in a Singleton.
- [ ] `NullAuditLog` stub class exists at `HoneyDrunk.Auth/Authentication/NullAuditLog.cs`, is `internal sealed`, implements `IAuditLog` with `AppendAsync` returning `Task.CompletedTask`.
- [ ] `HoneyDrunkAuthServiceCollectionExtensions.AddHoneyDrunkAuth()` calls `services.TryAddSingleton<IAuditLog, NullAuditLog>()` — `Try` semantics so host-side `AddHoneyDrunkAuditData()` (or any other backing) takes precedence.
- [ ] A startup `::warning::` is logged when the resolved `IAuditLog` is the `NullAuditLog` stub. **The warning lives at the end of `AuthStartupHook.ExecuteAsync` (file: `HoneyDrunk.Auth/Lifecycle/AuthStartupHook.cs`)** — `AuthStartupHook` is the existing `IStartupHook` registered at line 89 of `HoneyDrunkAuthServiceCollectionExtensions.cs`. It does NOT throw on the no-op-stub case; missing audit composition is degraded-state, not fatal. The warning text directs the operator to compose `HoneyDrunk.Audit.Data` (or another backing). The warning may name the audit-emission boundary invariant by number (`47`) once the actual assigned number is substituted pre-push.
- [ ] All eight new tests pass: four BearerToken emission tests (valid path, invalid path, throw-resilience, context-respects-whitelist+truncation), two DefaultAuthorizationPolicy emission tests (grant via `IsAllowed==true`, deny via `IsAllowed==false`), one DI test (`NullAuditLog_IsDefault_WhenNothingElseRegistered`), and one AuthStartupHook test (`AuthStartupHook_LogsWarning_WhenAuditLogIsNullAuditLog`).
- [ ] `HoneyDrunk.Auth.Tests/Fakes/InMemoryAuditLog.cs` exists as a hand-written test double. **No PackageReference to a `HoneyDrunk.Audit.Testing` package** (none exists at Audit v0.1.0).
- [ ] `HoneyDrunk.Auth.Canary` carries a single end-to-end audit-emission test using the in-memory test double.
- [ ] Every `src/*.csproj` in the solution carries `<Version>0.5.0</Version>` (invariant 27 — `HoneyDrunk.Auth`, `HoneyDrunk.Auth.Abstractions`, `HoneyDrunk.Auth.AspNetCore`). Test projects do not bump.
- [ ] Repo-level `CHANGELOG.md` has a `## [0.5.0] - YYYY-MM-DD` entry covering the audit emission (per invariants 12, 27, and memory `feedback_no_unreleased_commits` — no `## Unreleased` block at commit time).
- [ ] `HoneyDrunk.Auth/HoneyDrunk.Auth/CHANGELOG.md` (the per-package CHANGELOG of the only package that changed) has a `## [0.5.0]` entry.
- [ ] `HoneyDrunk.Auth.Abstractions/CHANGELOG.md` and `HoneyDrunk.Auth.AspNetCore/CHANGELOG.md` are **NOT** updated with a `## [0.5.0]` noise entry — per invariant 27's no-alignment-noise rule.
- [ ] `HoneyDrunk.Auth/HoneyDrunk.Auth/README.md` carries a short section describing audit emission (what events are emitted, that host-side composition is required, that the emission is additive and Auth's identity-out-of-traces invariant is untouched). **No ADR numbers in the README narrative** (memory `feedback_no_adr_in_docs`).
- [ ] **`repos/HoneyDrunk.Auth/integration-points.md` is NOT edited in this packet's PR.** That reconciliation is a separate follow-up Architecture packet (see §"Architecture-side" — flagged in the dispatch plan under "What This Initiative Does NOT Deliver"). Cross-repo PRs are unsupported by `file-work-items.yml`'s single-`target_repo` model.
- [ ] `pr-core.yml` passes on the PR.
- [ ] The contract-shape canary on `HoneyDrunk.Audit.Abstractions` (in the HoneyDrunk.Audit repo) is **not** triggered by this packet — Auth's emission shape is downstream code, not Abstractions code. The canary protects against shape drift in `IAuditLog.AppendAsync` / `AuditEntry` member set / `IAuditQuery` — none of those change in this packet.

## Human Prerequisites

- [ ] Packet 03 of this initiative complete — `HoneyDrunk.Audit 0.1.0` published to NuGet with `HoneyDrunk.Audit.Abstractions 0.1.0` discoverable on the consumer feed. Auth's PackageReference resolves against the public NuGet feed; if the feed has not propagated the package yet, the build fails and this packet must wait.
- [ ] After this packet's PR merges, push tag `v0.5.0` from `main` in `HoneyDrunk.Auth` to trigger the NuGet release of the new Auth version. Tags are human-pushed per invariant 27.
- [ ] **Host composition follow-up.** Auth's new emission requires the consuming host to compose an `IAuditLog` backing (e.g., `HoneyDrunk.Audit.Data` plus `HoneyDrunk.Data` registration) for durable persistence. Without that, the `NullAuditLog` stub is active and the startup warning fires. File a small follow-up packet per host that ships HoneyDrunk.Auth (Web.Rest deployable, future Auth-consuming Container Apps) to wire `AddHoneyDrunkAuditData()` and seed the App Config `audit:retention:days` key. **Not in scope for this packet** — this packet ships the emission; host wiring is per-host.
- [ ] Confirm a follow-up Architecture packet is filed to update `repos/HoneyDrunk.Auth/integration-points.md` with the Audit row (this packet is Auth-only; cross-repo PRs are unsupported by `file-work-items.yml`). Do not silently skip it — that file is the canonical record of Auth's integration boundaries. The follow-up should land soon after this PR merges so the catalog reflects reality on `main`.
- [ ] **Managed-identity note for the future deployable-host packet.** The host that first composes `HoneyDrunk.Audit.Data` (e.g., a Container App that links Auth-plus-Audit at deploy time) should provision a **dedicated managed identity for Audit**, distinct from the host's own identity and distinct from Auth's identity, per ADR-0031 D5 (recorder-is-not-the-actor). Inheriting the host's identity collapses the durable-record-attribution layer into the requesting layer — the same boundary ADR-0030 D2 (recorder ≠ actor) prevents. This is **not in scope for this packet** (Auth is a library, not a deployable; no managed identity provisioning happens here). Cross-link [`infrastructure/walkthroughs/azure-provisioning-guide.md`](../../../../infrastructure/walkthroughs/azure-provisioning-guide.md) in the future deployable-host packet for the portal walkthrough.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Reinforces why Auth's reference is to `HoneyDrunk.Audit.Abstractions` (zero-`HoneyDrunk` package) rather than `HoneyDrunk.Audit.Data` (which would transit Kernel/Data/Vault pins through Auth's dependency closure).

> **Invariant 5:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null `TenantId`. — `BearerTokenAuthenticationProvider` and `DefaultAuthorizationPolicy` resolve the current scope's `IGridContext` via `IGridContextAccessor.GridContext` (the Singleton-safe accessor) to populate the `AuditEntry`'s `CorrelationId` and `TenantId`. **Direct `IGridContext` ctor injection is avoided** because both classes are Singleton-registered — a Scoped `IGridContext` injected into a Singleton would be captive on the first scope.

> **Invariant 6:** CorrelationId is never null or empty, and TenantId is never absent, in a live GridContext. — Audit entries inherit valid correlation + tenant from `IGridContext`. Empty values are a Kernel-layer invariant violation that should not happen at the Auth-emission point.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. — Extended in spirit to audit emission: token text and raw claim values are not in `AuditEntry.Context`. `Context` carries only identifier claims (`jti`, `iss`, `aud`, `exp`) and the failure-reason string.

> **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. It is not an identity provider. — Unchanged. The audit emission records the *validation outcome*; it does not record token issuance because Auth does not issue tokens.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Every version that ships must have an entry in the repo-level CHANGELOG. — Both repo-level and the affected per-package CHANGELOG land `## [0.5.0]` entries; alignment-bumped packages do NOT get noise entries (invariant 27).

> **Invariant 26:** Work items for .NET code work must include an explicit `## NuGet Dependencies` section. — Section above lists the one PackageReference addition (`HoneyDrunk.Audit.Abstractions 0.1.0`).

> **Invariant 27:** All projects in a solution share one version and move together. Per-package changelogs are updated only for packages with actual changes — do not add alignment-bump noise entries. — All three `src/*.csproj` bump to 0.5.0; only `HoneyDrunk.Auth/CHANGELOG.md` gets a per-package entry (the other two are alignment bumps).

> **Invariant `47` (ADR-0030 packet 02 — substrate-level audit-emission boundary):** Durable, attributable security and action events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. Login attempts, authorization grants and denials, and privileged-action execution are recorded durably and attributably through `IAuditLog`. Phase-1 audit integrity is append-only-by-interface (`IAuditLog` exposes no update and no delete method); it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. — This packet IS the first compliant emitter against `47`. Token-validation outcomes (login-attempt analogue) and authorization-policy decisions are durably recorded.

> **Invariant `48` (this initiative, packet 01 — downstream Abstractions-only coupling):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`. Composition against `HoneyDrunk.Audit.Data` is a host-time concern resolved at application startup from App Configuration. — Auth's PackageReference is `HoneyDrunk.Audit.Abstractions 0.1.0` only. Composition (which backing actually persists) is the host's job.

> **Invariant `49` (this initiative, packet 01 — contract-shape canary):** The HoneyDrunk.Audit Node CI must include a contract-shape canary for `IAuditLog`, `IAuditQuery`, and `AuditEntry`. — Not directly enforced by this packet (the canary lives in the HoneyDrunk.Audit repo's CI), but this packet is what *consumes* the canary-protected surface, so the existence of the canary protects Auth from accidental upstream shape drift. If Audit's canary catches a breaking change, Auth's build against the unshipped change is the second line of defense.

> **Invariant 39 (Tenant mechanics stay at intake and post-dispatch boundaries — ADR-0026):** `IGridContext.TenantId` carries the strong-typed Kernel `TenantId` (the `Internal` sentinel for header-less requests). — This packet passes `gridContext.TenantId` (resolved via `_gridContextAccessor.GridContext`) through to `AuditEntry.TenantId` as the typed value; it does not stringify, default, or re-parse. Per ADR-0026, the consumer site (Auth's emission point) never re-introduces a `?? TenantId.Internal` fallback.

## Referenced ADR Decisions

**ADR-0030 D6 (First emitter Auth; observability identity-out-of-traces preserved):** "The first real emitter wired at stand-up is `HoneyDrunk.Auth`, recording durable attributable security events additively to its existing OTel traces, on a separate durable channel, with Auth's identity-out-of-traces invariant untouched." This packet implements that decision.

**ADR-0030 D1 (Audit substrate ownership):** Audit owns the durable, attributable record. Auth, by emitting via `IAuditLog`, becomes a producer against the substrate — not a co-owner. Boundary preserved: Auth still owns authentication and authorization decisions; it now also durably records those decisions.

**ADR-0030 D2 (Recorder ≠ actor):** Auth makes the allow/deny decision; Audit records it. The two are structurally separate even though both run under their own managed identities. This packet preserves that — Auth records *its own outcomes* via the Audit substrate, but Auth is not the recorder of itself in the trust sense (the Audit Node's managed identity is what writes; Auth's identity is what *originated* the record).

**ADR-0030 D7 / ADR-0031 D7 (Telemetry one-way to Pulse; audit records are not telemetry):** Audit *records* never flow to Pulse — they live on the durable audit channel. Auth's existing OTel traces are unchanged by this packet; the new emission goes to `IAuditLog`, not to Pulse. The two channels stay separate.

**ADR-0031 D6 (First emitter Auth; Operator reconciled):** Same as ADR-0030 D6, restated in the stand-up ADR's terms. This packet is the implementation.

**ADR-0031 D9 (Downstream coupling):** Auth takes a PackageReference on `HoneyDrunk.Audit.Abstractions` only. Composition against `HoneyDrunk.Audit.Data` is a host-time concern.

**ADR-0027 D3 (No speculative Testing package; cut later as non-breaking):** Auth writes its own narrowly-scoped in-memory `IAuditLog` test double inside `HoneyDrunk.Auth.Tests/Fakes/` rather than depending on a `HoneyDrunk.Audit.Testing` package (which does not exist at Audit v0.1.0). When a third consumer needs the fixture, it is cut into `HoneyDrunk.Audit.Testing` as a non-breaking change — Auth can switch then if it wants. Out of scope here.

**ADR-0026 D1/D2/D3 (TenantId strong type, non-nullable, propagation via `IGridContext`):** `IGridContext.TenantId` is the non-null Kernel `TenantId` strong type with the `Internal` sentinel for header-less requests. — This packet passes `gridContext.TenantId` (resolved via `_gridContextAccessor.GridContext` per-call from the Singleton emitter) through directly to `AuditEntry.TenantId` (the Kernel strong type on the `AuditEntry` record per packet 03's contract). No stringification, no null-handling, no `?? TenantId.Internal` consumer-site fallback. Per invariant 39, tenant mechanics stay at intake (`GridContextMiddleware`) and at post-dispatch boundaries — Auth's emission point is a consumer of the already-resolved `IGridContext.TenantId`.

## Dependencies

- `work-item:03` — `HoneyDrunk.Audit 0.1.0` (specifically the `HoneyDrunk.Audit.Abstractions` package) must be published to the consumer NuGet feed. Auth references the package by version pin; it cannot resolve `0.1.0` against an unpublished package.

## Labels

`feature`, `tier-2`, `auth`, `audit`, `adr-0031`

## Agent Handoff

**Objective:** Wire `HoneyDrunk.Auth` v0.5.0 to emit durable `AuditEntry` records via `IAuditLog` for token-validation outcomes and authorization-policy decisions, additively to existing OTel traces, on the separate durable audit channel per the substrate-level audit-emission boundary invariant `47`. Auth's identity-out-of-traces invariant remains untouched.

**Target:** HoneyDrunk.Auth, branch from `main`.

**Context:**
- Goal: Land the first compliant emitter against the Audit substrate (packet 03 of this initiative shipped `HoneyDrunk.Audit.Abstractions 0.1.0`). Token-validation and authorization-policy decisions are exactly the event classes invariant `47` (audit-emission boundary) names; this packet records them durably.
- Feature: ADR-0031 standup initiative — this is the consumer-side packet that gives the substrate its first real producer.
- ADRs: ADR-0031 (D6 — first emitter); ADR-0030 (D6 — same decision in the capability ADR; D2 — recorder ≠ actor); ADR-0027 D3 (no speculative `HoneyDrunk.Audit.Testing` package — write a hand-written test double).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 03 of this initiative must merge and `v0.1.0` must publish to NuGet first.

**Constraints:**

- **Invariant 5:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null `TenantId`. — `BearerTokenAuthenticationProvider` and `DefaultAuthorizationPolicy` resolve the current-scope `IGridContext` via `IGridContextAccessor.GridContext` (the Singleton-safe ambient accessor) and use `CorrelationId`/`TenantId` from it.
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. — Extended to audit: no token text or claim values beyond `jti`/`iss`/`aud`/`exp` in `AuditEntry.Context`. A test enforces this.
- **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. It is not an identity provider. — Unchanged. The audit emission records validation outcomes, not issuance.
- **Invariant 12:** Semantic versioning with CHANGELOG and README. — Repo-level `CHANGELOG.md` gets a `## [0.5.0] - YYYY-MM-DD` entry. `HoneyDrunk.Auth/CHANGELOG.md` (per-package, the only package that changed) gets the same entry.
- **Invariant 26:** Work items for .NET code work must include an explicit `## NuGet Dependencies` section. `HoneyDrunk.Standards` must be on every new .NET project. — Section above lists the single PackageReference addition.
- **Invariant 27:** All projects in a solution share one version and move together. Per-package changelogs are updated only for packages with actual changes — do not add alignment-bump noise entries. — `HoneyDrunk.Auth`, `HoneyDrunk.Auth.Abstractions`, and `HoneyDrunk.Auth.AspNetCore` all bump to 0.5.0; only `HoneyDrunk.Auth/CHANGELOG.md` (the one with the actual change) gets a per-package entry. The other two `.csproj` are alignment bumps without changelog noise.
- **Invariant `47` (audit-emission boundary):** Durable, attributable security and action events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. Phase-1 audit integrity is append-only-by-interface; it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. — Auth's emission is on `IAuditLog`, not on Pulse. The OTel-trace path stays unchanged.
- **Invariant `48` (downstream Abstractions-only coupling):** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`. Composition against `HoneyDrunk.Audit.Data` is a host-time concern resolved at application startup from App Configuration. — Add `HoneyDrunk.Audit.Abstractions 0.1.0` only. **DO NOT** add `HoneyDrunk.Audit.Data` to `HoneyDrunk.Auth.csproj`.
- **Invariant 39 (Tenant mechanics — ADR-0026):** Tenant resolution and the `Internal` sentinel default happen at intake (`GridContextMiddleware`), not at the consumer site. `IGridContext.TenantId` is the non-null Kernel `TenantId` strong type. — Pass `gridContext.TenantId` (resolved via `_gridContextAccessor.GridContext`) through to `AuditEntry.TenantId` directly. No `.ToString()`, no `?? TenantId.Internal` fallback, no null-handling. Stringly-typing tenancy at this emission site re-introduces ADR-0026's footgun.
- **Auth's identity-out-of-traces invariant is untouched.** Existing OTel trace enrichment is not changed by this packet. No identity-bearing fields are added to traces. Audit emission lives entirely on the durable audit channel, in parallel.
- **Emission failures must not fail the request.** Wrap `IAuditLog.AppendAsync` in try/catch with error log + continue. A flaky audit store is the audit substrate's SLO problem; it should not break authentication.
- **`Context` carries no PII.** Token text, claim values beyond identifier claims, and bearer-token contents NEVER appear in `AuditEntry.Context`. Test `BearerTokenAuthenticationProvider_AuditContext_ContainsNoTokenText` enforces this.
- **`TryAddSingleton<IAuditLog, NullAuditLog>` is the registration pattern.** Hosts that compose `AddHoneyDrunkAuditData()` (or any other backing) take precedence. Hosts that don't get the no-op stub plus a startup `::warning::`. The `Try` semantics are load-bearing — without them, Auth would clobber host-side registrations.
- **Hand-written test double, NOT a `HoneyDrunk.Audit.Testing` package.** No such package exists at Audit v0.1.0 per ADR-0031 D2 and ADR-0027 D3. The test double lives at `HoneyDrunk.Auth.Tests/Fakes/InMemoryAuditLog.cs` as ≈ 20 lines of hand-written code.
- **No ADR numbers in `HoneyDrunk.Auth/README.md` narrative.** Per memory `feedback_no_adr_in_docs`, the README describes what the package does; it does not cite "ADR-0030" or "ADR-0031" by number.
- **`Action` strings are namespaced.** Use `auth.token.validate` and `auth.authorize.{policyName}` — the prefix establishes the emitting Node (Auth) and the verb names the operation. Future emitters (Operator's AI-runtime decisions, future privileged-action emitters) follow the same `{node}.{verb}` shape.

**Key Files:**
- `HoneyDrunk.Auth/HoneyDrunk.Auth/HoneyDrunk.Auth.csproj` — add PackageReference, bump Version to 0.5.0
- `HoneyDrunk.Auth/HoneyDrunk.Auth/Authentication/BearerTokenAuthenticationProvider.cs` — add `IAuditLog` + `IGridContextAccessor` to primary-ctor params; add `AuditAllowedClaims` static readonly HashSet, `AuditContextMaxBytes` const, `CapContext` helper, `BuildValidationContext`; emit `AuditEntry` post-`ValidateTokenAsync` with try/catch
- `HoneyDrunk.Auth/HoneyDrunk.Auth/Authorization/DefaultAuthorizationPolicy.cs` — add `IAuditLog` + `IGridContextAccessor` to existing primary-ctor params (next to `telemetryFactory`, `logger`); add `BuildAuthorizationContext`; emit `AuditEntry` between existing `LogDecision` and return; method body becomes `await _auditLog.AppendAsync(...); return decision;`. **`AuthorizationPolicyEvaluator.cs` (the pure static class) is NOT touched** — emission goes on the I/O-side decorator alongside the existing telemetry/logging.
- `HoneyDrunk.Auth/HoneyDrunk.Auth/Authentication/NullAuditLog.cs` (new) — internal sealed no-op stub
- `HoneyDrunk.Auth/HoneyDrunk.Auth/DependencyInjection/HoneyDrunkAuthServiceCollectionExtensions.cs` — add `TryAddSingleton<IAuditLog, NullAuditLog>()` alongside existing registrations at lines 83/86
- `HoneyDrunk.Auth/HoneyDrunk.Auth/Lifecycle/AuthStartupHook.cs` — add `IAuditLog` to primary-ctor; at end of `ExecuteAsync`, after the existing signing-key/issuer/audience validation succeeds, check `auditLog is NullAuditLog` and `_logger.LogWarning(...)`; do NOT throw on the no-op case (degraded ≠ fatal)
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/Fakes/InMemoryAuditLog.cs` (new) — hand-written test double
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/Authentication/BearerTokenAuthenticationProviderTests.cs` — four new tests (the AuditContext-whitelist test verifies the `AuditAllowedClaims` constant is the single source of truth)
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/Authorization/DefaultAuthorizationPolicyTests.cs` — two new tests (grant via `IsAllowed==true`, deny via `IsAllowed==false`)
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/Lifecycle/AuthStartupHookTests.cs` — one new test (`AuthStartupHook_LogsWarning_WhenAuditLogIsNullAuditLog`); the file already exists at this path
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Tests/DependencyInjection/HoneyDrunkAuthServiceCollectionExtensionsTests.cs` — one new test (`NullAuditLog_IsDefault_WhenNothingElseRegistered`)
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Canary/` — one end-to-end canary test
- `HoneyDrunk.Auth/HoneyDrunk.Auth/README.md` — short audit-emission section (no ADR numbers in narrative)
- `HoneyDrunk.Auth/CHANGELOG.md` — repo-level [0.5.0] entry
- `HoneyDrunk.Auth/HoneyDrunk.Auth/CHANGELOG.md` — per-package [0.5.0] entry (only this package gets one)
- `HoneyDrunk.Auth/HoneyDrunk.Auth.Abstractions/HoneyDrunk.Auth.Abstractions.csproj` — bump Version (alignment)
- `HoneyDrunk.Auth/HoneyDrunk.Auth.AspNetCore/HoneyDrunk.Auth.AspNetCore.csproj` — bump Version (alignment)

(`repos/HoneyDrunk.Auth/integration-points.md` in the Architecture repo is a separate follow-up Architecture packet — see §"Architecture-side" in this packet's body. `file-work-items.yml` only opens PRs against `target_repo`, which here is `HoneyDrunkStudios/HoneyDrunk.Auth`.)

**Contracts:**
- This packet consumes `IAuditLog` and `AuditEntry` from `HoneyDrunk.Audit.Abstractions 0.1.0`. It does not author any new contracts.
- The audit emission shape (`Action=auth.token.validate`, `Action=auth.authorize.{policyName}`, `Outcome=granted|denied`, no-PII `Context`) is a convention this packet establishes. Future emitters in Auth (or in other Nodes) should follow the same `{node}.{verb}` `Action` naming and the same no-PII `Context` discipline.
