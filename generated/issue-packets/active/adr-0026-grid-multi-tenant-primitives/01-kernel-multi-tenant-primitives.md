---
name: Cross-Repo Change
type: cross-repo-change
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-3", "core", "breaking-change", "adr-0026", "wave-1"]
dependencies: []
adrs: ["ADR-0026"]
wave: 1
initiative: adr-0026-grid-multi-tenant-primitives
node: honeydrunk-kernel
---

# Feature: Grid multi-tenant primitives — TenantId promotion, ITenantRateLimitPolicy, IBillingEventEmitter, noop defaults

## Summary
Promote `IGridContext.TenantId` from `string?` to non-nullable `TenantId`; add a well-known `TenantId.Internal` ULID sentinel and `TenantId.IsInternal` predicate; add the `Tenancy` namespace to `HoneyDrunk.Kernel.Abstractions` with `ITenantRateLimitPolicy` + `TenantRateLimitDecision` + `TenantRateLimitOutcome` and `IBillingEventEmitter` + `BillingEvent`; ship `NoopTenantRateLimitPolicy` and `NoopBillingEventEmitter` defaults in `HoneyDrunk.Kernel`. Update `GridContextMiddleware`, `MessagingContextMapper`, `JobContextMapper`, and `GridContextSerializer` to parse / round-trip the strong type and apply the `TenantId.Internal` default at Grid entry. One coordinated Kernel + Kernel.Abstractions minor version bump.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Kernel`

## Motivation
PDR-0002 (Notify Cloud as the Grid's first commercial product) requires Grid-wide multi-tenant primitives so Notify Cloud — and any future commercial Node — does not invent its own incompatible tenancy types. ADR-0026 settles the design: tenancy is a Kernel-Abstractions concern (contracts), Kernel ships noop defaults (so internal Grid usage is unaffected), and consumer Nodes register real implementations at gateway-layer middleware. This packet ships the entire Kernel half of step 1 in ADR-0026 D9.

The current shape (`IGridContext.TenantId` is `string?`) forces every consumer to parse strings into `TenantId` at use site, swallowing malformed values silently and creating a `??` fallback footgun. The new shape (non-nullable `TenantId`, with `TenantId.Internal` as the boundary-layer default) makes tenancy a typed first-class context value with one centralized parse and one centralized default.

## Proposed Implementation

### A. `TenantId.Internal` sentinel + `IsInternal` predicate

In `HoneyDrunk.Kernel.Abstractions/Identity/TenantId.cs`:

```csharp
public readonly record struct TenantId
{
    // ... existing members ...

    /// <summary>
    /// Well-known ULID sentinel used by the Grid for non-multi-tenant operations.
    /// This value is stable across Kernel versions (pinned by canary test) and is
    /// the default applied by GridContextMiddleware / MessagingContextMapper /
    /// JobContextMapper when no X-Tenant-Id header is present at Grid entry.
    /// </summary>
    public static TenantId Internal { get; } = new(Ulid.Parse("00000000000000000000000001"));

    /// <summary>
    /// True if this TenantId is the well-known internal sentinel.
    /// Downstream consumers (rate limiter, billing emitter, Vault resolver) MUST
    /// short-circuit on this predicate and return Allow / no-op / shared-secret-path.
    /// </summary>
    public bool IsInternal => this == Internal;
}
```

The chosen sentinel ULID **is a human bikeshed call (ADR-0026 Open Questions §3) — flag this for confirmation before final commit.** A plausible default is `00000000000000000000000001` (a low-bit ULID that is parseable but unmistakable in logs); the constructor must accept it, so verify `new TenantId("00000000000000000000000001")` does not throw. If the chosen value is rejected by the existing `TenantId(string)` constructor's Ulid.TryParse, switch to a value that parses (e.g., `01HZZZZZZZZZZZZZZZZZZZZZZZ` — a well-known crockford-base32 ULID). The exact bits are not load-bearing; what matters is **stability across versions** (canary-pinned) and **uniqueness across mintable IDs** (`TenantId.NewId()` must never produce it in practice).

Add a canary test that asserts the literal byte / string value of `TenantId.Internal` and fails if it changes.

### B. `IGridContext.TenantId` typed promotion + Grid-entry defaulting

`HoneyDrunk.Kernel.Abstractions/Context/IGridContext.cs`:

Change:
```csharp
string? TenantId { get; }
```
to:
```csharp
TenantId TenantId { get; }
```

Update the XML doc — Kernel still does not interpret, authorize, or enforce tenancy. The new doc must read approximately: *"This is an identity attribute ONLY — Kernel parses, applies the Internal default at Grid entry, propagates, and exposes. It does not authorize, rate-limit, or bill. When no X-Tenant-Id header is present, this returns `TenantId.Internal`. Consumers never see null and never need a `??` fallback."*

`HoneyDrunk.Kernel/Context/GridContext.cs`:
- Change the backing field of `TenantId` from `string?` to `TenantId`.
- Update `Initialize(...)` to take `TenantId tenantId` (non-nullable).
- The `Initialize` overload signature changes: `string? tenantId` parameter becomes `TenantId tenantId`. Callers (the three mappers + middleware + the serializer's deserialize path) all update.

`HoneyDrunk.Kernel/Context/Middleware/GridContextMiddleware.cs`:
- Replace the `tenantId = ExtractHeader(httpContext, GridHeaderNames.TenantId);` block with a typed parse:
  - If the header is absent → `var tenantId = TenantId.Internal;`
  - If the header is present and `TenantId.TryParse(headerValue, out var parsed)` succeeds → `tenantId = parsed;`
  - If the header is present but `TryParse` fails → respond with HTTP 400 and a non-PII error body. The existing defensive truncation is now obsolete for this header — it was a string-safety measure; the strong type's `TryParse` is the new safety boundary. The 400 surfaces malformed tenancy as a client error rather than silently defaulting.
- Update the response-echo block: the `responseTenantId` variable becomes a `TenantId`. The header echo predicate changes from `if (!string.IsNullOrWhiteSpace(responseTenantId))` to `if (!responseTenantId.IsInternal)` — internal-tenant requests omit the `X-Tenant-Id` response header (so the receiver applies its own Internal default per ADR-0026 D3).

`HoneyDrunk.Kernel/Context/Mappers/MessagingContextMapper.cs`:
- Replace the `tenantId = GetMetadata(...) ?? GetMetadata(...) ?? GetMetadata(...);` block with: parse via `TenantId.TryParse`; on null/missing/parse-failure, default to `TenantId.Internal`. Parse-failure on a messaging hop should NOT throw the way the HTTP edge does (a queued message cannot be 400'd back to the sender); log a warning, default to `Internal`, and proceed. Document this divergence with an inline code comment.
- `MessageContextValues` record's `TenantId` property changes from `string?` to `TenantId`.

`HoneyDrunk.Kernel/Context/Mappers/JobContextMapper.cs`:
- `InitializeForJob`, `InitializeForScheduledJob`, `InitializeFromMetadata` all pass `TenantId.Internal` for the no-tenant path (today they pass `null`).
- `InitializeFromMetadata` parses the metadata value via `TenantId.TryParse` and falls back to `Internal` on failure (same warning-log pattern as the messaging mapper).

`HoneyDrunk.Kernel/AgentsInterop/GridContextSerializer.cs`:
- `Serialize`: emit `tenantId` as the ULID string form via `context.TenantId.ToString()`. If `context.TenantId.IsInternal`, omit the property (or emit it as a recognizable sentinel string — choose one consistent shape and document it; the omit-when-internal shape minimizes wire noise).
- `Deserialize`: parse the property via `TenantId.TryParse` and default to `TenantId.Internal` on absence or parse failure. The signature of the internal `gridContext.Initialize(...)` call updates to pass `TenantId` non-nullable.

### C. New `Tenancy` namespace in `HoneyDrunk.Kernel.Abstractions`

Create `HoneyDrunk.Kernel.Abstractions/Tenancy/`:

`ITenantRateLimitPolicy.cs`:
```csharp
namespace HoneyDrunk.Kernel.Abstractions.Tenancy;

using HoneyDrunk.Kernel.Abstractions.Identity;

/// <summary>
/// Contract a tenancy-aware Node consults at its gateway / intake layer before
/// performing tenant-billable work. Implementations MUST short-circuit on
/// <see cref="TenantId.IsInternal"/> and return Allow without consulting any
/// store. Storage of tenant rate-limit state is an implementation detail of the
/// registered policy.
/// </summary>
public interface ITenantRateLimitPolicy
{
    ValueTask<TenantRateLimitDecision> EvaluateAsync(
        TenantId tenantId,
        string operationKey,
        CancellationToken cancellationToken);
}
```

`TenantRateLimitDecision.cs`:
```csharp
namespace HoneyDrunk.Kernel.Abstractions.Tenancy;

/// <summary>
/// Result of a per-tenant rate-limit evaluation. Reason MUST NOT contain secret
/// material — secret values never appear in logs, traces, exceptions, or
/// telemetry (the broader Vault/Kernel rule applies here).
/// </summary>
public sealed record TenantRateLimitDecision(
    TenantRateLimitOutcome Outcome,
    TimeSpan? RetryAfter,
    string? Reason);

public enum TenantRateLimitOutcome
{
    Allow,
    Throttle,
    Reject,
}
```

`IBillingEventEmitter.cs`:
```csharp
namespace HoneyDrunk.Kernel.Abstractions.Tenancy;

/// <summary>
/// Contract a tenancy-aware Node uses to emit consumed-capacity events for
/// billing or metering. Fire-and-forget. Implementations MUST short-circuit on
/// <see cref="BillingEvent.TenantId"/>.IsInternal and return without emitting.
/// Queue topology, provider, and delivery semantics are implementation details
/// of the registered emitter.
/// </summary>
public interface IBillingEventEmitter
{
    ValueTask EmitAsync(BillingEvent billingEvent, CancellationToken cancellationToken);
}
```

`BillingEvent.cs`:
```csharp
namespace HoneyDrunk.Kernel.Abstractions.Tenancy;

using HoneyDrunk.Kernel.Abstractions.Identity;

/// <summary>
/// Tenant-scoped billing event representing consumed capacity (not requested
/// capacity). Attributes are bounded — implementations should reject events
/// with more than ~16 attributes — and never carry PII or secret material.
/// </summary>
public sealed record BillingEvent(
    TenantId TenantId,
    string EventType,
    string OperationKey,
    long Units,
    DateTimeOffset OccurredAtUtc,
    string CorrelationId,
    IReadOnlyDictionary<string, string> Attributes);
```

Naming-rule check: records drop the `I`, interfaces keep it. `TenantRateLimitDecision` and `BillingEvent` are records (no `I`). `ITenantRateLimitPolicy` and `IBillingEventEmitter` are interfaces (kept `I`). `TenantRateLimitOutcome` is an enum (no prefix).

### D. Noop defaults in `HoneyDrunk.Kernel`

Create `HoneyDrunk.Kernel/Tenancy/`:

`NoopTenantRateLimitPolicy.cs`:
```csharp
namespace HoneyDrunk.Kernel.Tenancy;

using HoneyDrunk.Kernel.Abstractions.Identity;
using HoneyDrunk.Kernel.Abstractions.Tenancy;

/// <summary>
/// Default ITenantRateLimitPolicy registered for internal Grid usage and tests.
/// Returns Allow for every tenant, including non-internal ones. Production
/// multi-tenant Nodes (e.g., Notify Cloud) replace this registration with a
/// real implementation backed by their own store.
/// </summary>
public sealed class NoopTenantRateLimitPolicy : ITenantRateLimitPolicy
{
    private static readonly TenantRateLimitDecision _allow =
        new(TenantRateLimitOutcome.Allow, RetryAfter: null, Reason: null);

    public ValueTask<TenantRateLimitDecision> EvaluateAsync(
        TenantId tenantId,
        string operationKey,
        CancellationToken cancellationToken) => new(_allow);
}
```

`NoopBillingEventEmitter.cs`:
```csharp
namespace HoneyDrunk.Kernel.Tenancy;

using HoneyDrunk.Kernel.Abstractions.Tenancy;

/// <summary>
/// Default IBillingEventEmitter registered for internal Grid usage and tests.
/// Drops every event silently. Production multi-tenant Nodes replace this
/// registration with a real provider-backed emitter.
/// </summary>
public sealed class NoopBillingEventEmitter : IBillingEventEmitter
{
    public ValueTask EmitAsync(BillingEvent billingEvent, CancellationToken cancellationToken)
        => ValueTask.CompletedTask;
}
```

Register both in the default `AddHoneyDrunkNode()` extension (or whichever DI extension owns the canonical Kernel registrations). Use `services.TryAddSingleton<ITenantRateLimitPolicy, NoopTenantRateLimitPolicy>()` and `services.TryAddSingleton<IBillingEventEmitter, NoopBillingEventEmitter>()` so consumer Nodes can override by registering their own implementation before `AddHoneyDrunkNode()` runs (or via standard DI override patterns).

### E. Canary tests

Add a contract-shape canary that fails on shape drift for all four surfaces (`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`). Same pattern as the canaries that protect existing Kernel.Abstractions surfaces — read each type via reflection, assert public member set + signatures match a frozen snapshot. Snapshot lives in the test project.

Add a canary that pins the literal value of `TenantId.Internal` (string form). Failing this test means the sentinel changed across versions, which would silently change the behavior of every consumer's `IsInternal` check.

Add canaries for the noop defaults: `NoopTenantRateLimitPolicy.EvaluateAsync(TenantId.NewId(), "op", default)` returns `Outcome.Allow`; `NoopBillingEventEmitter.EvaluateAsync(...)` does not throw and completes synchronously.

Add a unit test for the typed `IGridContext.TenantId` — `GridContextMiddleware` with no header populates `TenantId.Internal`; with a valid header populates the parsed value; with a malformed header returns 400 (test via a `TestServer`). Same shape for `MessagingContextMapper` and `JobContextMapper`, but parse-failure is a warning-log + Internal-default rather than an error.

### F. Coordinated version bump

Per Invariant 27, `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel` move together to the next minor (`0.5.0` from current `0.4.0`). Update both `.csproj` files and both per-package `CHANGELOG.md`s with the actual changes. Repo-level `CHANGELOG.md` gets a new `0.5.0` entry summarizing the multi-tenant primitives addition + the breaking change on `IGridContext.TenantId`.

The breaking change on `IGridContext.TenantId` (string? → TenantId) is a minor break. ADR-0026 D-Negative documents that the current audit shows zero non-Kernel callsites read this property — Kernel's own serializer + middleware are the only consumers. Verify this is still true at execution time by grepping the workspace; if a non-Kernel consumer has appeared since the ADR was scoped, surface it in the PR description (the consumer's update is small — string consumer becomes typed consumer, null check becomes unnecessary).

## Affected Files

### `HoneyDrunk.Kernel.Abstractions/`
- `Identity/TenantId.cs` (edit — add `Internal` static + `IsInternal` predicate)
- `Context/IGridContext.cs` (edit — `TenantId` property type changes from `string?` to `TenantId`; XML doc updated)
- `Tenancy/ITenantRateLimitPolicy.cs` (new)
- `Tenancy/TenantRateLimitDecision.cs` (new — also defines `TenantRateLimitOutcome` enum, or split into separate file at agent's discretion)
- `Tenancy/IBillingEventEmitter.cs` (new)
- `Tenancy/BillingEvent.cs` (new)
- `HoneyDrunk.Kernel.Abstractions.csproj` (version 0.4.x → 0.5.0)

### `HoneyDrunk.Kernel/`
- `Context/GridContext.cs` (edit — `TenantId` field + `Initialize(...)` parameter become typed `TenantId`; non-nullable)
- `Context/Middleware/GridContextMiddleware.cs` (edit — typed `TenantId` parse + Internal default + 400 on malformed; response-echo predicate changes to `!IsInternal`)
- `Context/Mappers/MessagingContextMapper.cs` (edit — typed parse + Internal default; `MessageContextValues.TenantId` becomes `TenantId`)
- `Context/Mappers/JobContextMapper.cs` (edit — all three init methods pass `TenantId.Internal` for the no-tenant path; `InitializeFromMetadata` parses + defaults)
- `AgentsInterop/GridContextSerializer.cs` (edit — serialize/deserialize the typed value; Internal-default on missing/malformed; pick + document one wire shape, e.g., omit-when-internal)
- `Tenancy/NoopTenantRateLimitPolicy.cs` (new)
- `Tenancy/NoopBillingEventEmitter.cs` (new)
- DI extension that owns the canonical `AddHoneyDrunkNode()` registrations (locate at execution; likely `Hosting/` or `Extensions/`) — register both noops via `TryAddSingleton`
- `HoneyDrunk.Kernel.csproj` (version 0.4.x → 0.5.0)

### `HoneyDrunk.Kernel.Tests/` (and any existing `.Canary` project — verify at execution; today there is no `HoneyDrunk.Kernel.Canary` on disk per recent SonarCloud onboarding packet)
- New canary for `TenantId.Internal` literal value
- New canary for the four contract shapes (`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`)
- New canary for the noop default behaviors
- New tests for `GridContextMiddleware`, `MessagingContextMapper`, `JobContextMapper`, `GridContextSerializer` typed-tenant behavior
- Update existing tests that asserted `string?` shape on `IGridContext.TenantId`

### Repo-level
- `CHANGELOG.md` (root) — new `0.5.0` entry (invariants 12 and 27)
- Per-package `CHANGELOG.md` for each of `HoneyDrunk.Kernel.Abstractions/` and `HoneyDrunk.Kernel/` — actual changes documented; do NOT add a noise entry to any `.Tests` package (invariant 12 — alignment-only bumps get no per-package changelog entry)
- `README.md` (root or per-package) — update if public API surface changed in a way that affects installation or Quick Start. The new tenancy primitives are an additive API surface, so a new "Multi-Tenant Primitives" subsection in the relevant README is appropriate (do not include the ADR ID in the README per `feedback_no_adr_in_docs`).

## NuGet Dependencies

No new package references. Per ADR-0026 D8:
- `HoneyDrunk.Kernel.Abstractions` — zero new runtime dependencies (Invariant 1 holds — only `Microsoft.Extensions.*` abstractions are permitted, and this packet adds none).
- `HoneyDrunk.Kernel` — already depends on `HoneyDrunk.Kernel.Abstractions`. No new package references.
- `HoneyDrunk.Kernel.Tests` — no changes to test-project references; the canary additions use already-referenced reflection/test packages.

If the repo's `HoneyDrunk.Standards` is not yet attached to a project that gets touched, leave it as-is — this packet does not add new projects.

## Boundary Check
- [x] All code lives in `HoneyDrunk.Kernel.Abstractions` (contracts) and `HoneyDrunk.Kernel` (default impls). No work spills into Vault, Pulse, or any consumer Node — those are separate packets in this initiative.
- [x] Kernel's interpretation-free stance is preserved. Kernel parses, applies the Internal default at the boundary, propagates, and exposes. It does not authorize, rate-limit, or bill — those concerns live in consumer Nodes.
- [x] The four new contracts live in a dedicated namespace (`HoneyDrunk.Kernel.Abstractions.Tenancy`) and do not introduce runtime dependencies on the rest of the Grid.
- [x] Naming rule honored: records drop `I` (`TenantRateLimitDecision`, `BillingEvent`), interfaces keep it (`ITenantRateLimitPolicy`, `IBillingEventEmitter`).

## Acceptance Criteria

- [ ] `TenantId.Internal` static property exists on `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` and returns a stable, parseable ULID.
- [ ] `TenantId.IsInternal` predicate exists and returns true for `TenantId.Internal` and false for `TenantId.NewId()` results.
- [ ] Canary test pins the literal string value of `TenantId.Internal` and would fail if the sentinel changed.
- [ ] `IGridContext.TenantId` is typed `TenantId` (non-nullable). XML doc reflects "Internal default applied at Grid entry; consumers always read a value."
- [ ] `GridContext.Initialize(...)` accepts a non-nullable `TenantId`.
- [ ] `GridContextMiddleware`:
  - Populates `TenantId.Internal` when no `X-Tenant-Id` header is present
  - Populates the parsed value when the header is well-formed
  - Returns HTTP 400 with a non-PII error body when the header is present but malformed
  - Echoes the `X-Tenant-Id` response header only when `!gridContext.TenantId.IsInternal`
- [ ] `MessagingContextMapper.InitializeFromMessage` and `ExtractFromMessage` parse via `TenantId.TryParse`, default to `TenantId.Internal` on missing/malformed, and log a warning on parse failure (no throw).
- [ ] `JobContextMapper.InitializeForJob`, `InitializeForScheduledJob`, `InitializeFromMetadata` populate `TenantId.Internal` for the no-tenant path; `InitializeFromMetadata` parses + defaults via `TryParse`.
- [ ] `GridContextSerializer.Serialize` emits the typed value (omit-when-internal or single documented sentinel string — pick one and document inline). `Deserialize` parses + defaults via `TryParse`.
- [ ] `MessageContextValues.TenantId` is `TenantId` (non-nullable).
- [ ] `HoneyDrunk.Kernel.Abstractions.Tenancy` namespace exists and exports `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `TenantRateLimitOutcome`, `IBillingEventEmitter`, `BillingEvent` with the exact shapes defined in the Proposed Implementation section.
- [ ] `HoneyDrunk.Kernel.Tenancy.NoopTenantRateLimitPolicy` returns `Outcome.Allow` for every input (including non-internal tenants) and is registered via `TryAddSingleton<ITenantRateLimitPolicy, NoopTenantRateLimitPolicy>()` in the default DI extension.
- [ ] `HoneyDrunk.Kernel.Tenancy.NoopBillingEventEmitter` completes without emitting and is registered via `TryAddSingleton<IBillingEventEmitter, NoopBillingEventEmitter>()` in the default DI extension.
- [ ] Contract-shape canary covers all four interfaces / records and is green.
- [ ] All four interface / record types carry XML docs (Invariant 13 — public APIs documented).
- [ ] `HoneyDrunk.Kernel.Abstractions.csproj` and `HoneyDrunk.Kernel.csproj` move together to `0.5.0` in a single commit (Invariant 27).
- [ ] Repo-level `CHANGELOG.md` has a new `0.5.0` entry covering the breaking change on `IGridContext.TenantId`, the new tenancy primitives namespace, and the noop defaults.
- [ ] Per-package `CHANGELOG.md` for `HoneyDrunk.Kernel.Abstractions/` and `HoneyDrunk.Kernel/` are updated. No per-package entry is added for any test project (alignment-only).
- [ ] No non-Kernel consumer was broken by the `IGridContext.TenantId` type change. Verify by `rg "gridContext\.TenantId|\.TenantId\s*[?]" --type cs` across the workspace and confirm only Kernel-internal callsites consume the property; if a consumer has appeared since the ADR was scoped, note it in the PR description and coordinate the consumer update.
- [ ] Existing tests asserting `string?`-shaped `TenantId` are updated to assert the typed shape and the Internal-default behavior.
- [ ] All canary tests green; full unit-test suite green.

## Human Prerequisites

- [ ] **Confirm the `TenantId.Internal` ULID value before merge.** ADR-0026 Open Questions §3 lists this as a bikeshed-shaped human call. The packet proposes `00000000000000000000000001` (or a fallback like `01HZZZZZZZZZZZZZZZZZZZZZZZ` if the constructor rejects the all-zero variant). The agent will pick one that parses and write the canary; the human (oleg@honeydrunkstudios.com) confirms or replaces the literal value at PR review. Once merged, the canary pins it for the lifetime of the type.
- [ ] No portal / Azure work. This is a NuGet-only library packet.

## Dependencies
None. First packet in the initiative; this is the foundation Vault and Pulse depend on.

## Downstream Unblocks
- Packet 02 (Vault) — needs the typed `TenantId` and `IsInternal` predicate to short-circuit the resolver on internal traffic.
- Packet 03 (Pulse) — needs the typed `TenantId` so the `tenant_id` enrichment tag has a single canonical source.
- Packet 04 (Architecture catalog + invariant) — flips ADR-0026 status to Accepted only after this packet, the Vault packet, and the Architecture catalog packet all merge (per ADR-0026 D9 + Done When list).
- Notify Cloud (PDR-0002) and Communications (ADR-0019) inherit the strong type automatically; their consumer-side wiring is scoped by their own future packets — not in this initiative.

## Referenced Invariants

> **Invariant 1 (Dependency):** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. **Why it matters here:** The new `HoneyDrunk.Kernel.Abstractions.Tenancy` namespace adds four contract types — none of them may pull in additional dependencies. Verify the `.csproj` is unchanged on the `<PackageReference>` side.

> **Invariant 2 (Dependency):** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. **Why it matters here:** The noop default implementations in `HoneyDrunk.Kernel` reference `HoneyDrunk.Kernel.Abstractions` (already a dependency). No new runtime-package edges are introduced.

> **Invariant 5 (Context):** GridContext must be present in every scoped operation. **Why it matters here:** The typed `TenantId` is now part of that contract — every scoped operation reads a non-null value (`TenantId.Internal` if the request entered Grid without a tenant header).

> **Invariant 8 (Secrets & Trust):** Secret values never appear in logs, traces, exceptions, or telemetry. **Why it matters here:** The `Reason` field on `TenantRateLimitDecision` and the `Attributes` dictionary on `BillingEvent` are consumer-supplied free-form strings — implementations must never put secrets into either. Document this in the XML docs of both types.

> **Invariant 12 (Packaging):** Semantic versioning with CHANGELOG and README — repo-level mandatory, per-package only when the package has functional changes. **Why it matters here:** Repo-level `CHANGELOG.md` gets a new `0.5.0` entry. Per-package `CHANGELOG.md` updates apply to `HoneyDrunk.Kernel.Abstractions/` and `HoneyDrunk.Kernel/` (both have actual changes). No noise entries on test projects.

> **Invariant 13 (Packaging):** All public APIs have XML documentation. **Why it matters here:** All four new public types (`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`), the new `TenantId.Internal` static, and the new `TenantId.IsInternal` predicate must carry XML docs.

> **Invariant 14 (Testing):** Canary tests validate cross-Node boundaries. **Why it matters here:** The four new contracts get a contract-shape canary; the `TenantId.Internal` literal value gets a pinning canary; the noop defaults get behavior canaries.

> **Invariant 26 (Work Tracking):** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. **Why it matters here:** The section above explicitly states "no new package references" rather than omitting the section.

> **Invariant 27 (Versioning):** All projects in a solution share one version and move together. **Why it matters here:** `HoneyDrunk.Kernel.Abstractions.csproj` and `HoneyDrunk.Kernel.csproj` both move from `0.4.x` to `0.5.0` in a single commit. Test projects move with them; no test-project-only `CHANGELOG.md` noise entries.

> **Invariant 31 (Code Review):** Every PR traverses the tier-1 gate before merge. **Why it matters here:** PR includes the type promotion and the new noop registrations; tier-1 gate (build, unit tests, analyzers, vuln, secret scan) must be green before merge.

> **Invariant 32 (Code Review):** Agent-authored PRs must link to their packet in the PR body. **Why it matters here:** The PR body must include `> Packet: <permalink-to-this-packet>` so the review agent uses it as the primary scope anchor.

## Referenced ADR Decisions

**ADR-0026 (Grid Multi-Tenant Primitives):**
- **D1 — `TenantId` is a Kernel-Abstractions primitive, ULID-backed, with a well-known `Internal` sentinel.** This packet adds `TenantId.Internal` (canary-pinned) and `TenantId.IsInternal`. `TenantId.NewId()` continues to mint random ULIDs; the Internal sentinel is not mintable.
- **D2 — `IGridContext.TenantId` is promoted from `string?` to `TenantId` (non-nullable).** Header parsing AND the Internal default happen once, in `GridContextMiddleware` and the messaging/job mappers, at Grid entry. Consumers never see null and never write a `??` fallback.
- **D3 — Tenant resolution is explicit threading via `IGridContext`, never AsyncLocal.** No `TenantContext.Current`, no static accessor, no AsyncLocal. Tenancy rides the same `IGridContext` instance every other context value rides on. Cross-Node propagation: HTTP edge → header → `GridContextMiddleware` parses or applies Internal; messaging hop → `MessagingContextMapper` round-trips; job hop → `JobContextMapper` same; HTTP outbound omits `X-Tenant-Id` for internal-tenant requests.
- **D4 — Per-tenant rate-limit policy is a Kernel-Abstractions contract, enforced at gateway-layer middleware.** This packet ships the contract (`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `TenantRateLimitOutcome`) and the noop default. Storage is deferred to consumer Nodes. Default policy for `TenantId.Internal` is always `Allow` — the noop satisfies this trivially; the canary asserts it for any future implementation.
- **D6 — Tenant-scoped billing events are a Kernel-Abstractions contract with a provider-slot pattern.** This packet ships the contract (`IBillingEventEmitter`, `BillingEvent`) and the noop default. Default behavior for `TenantId.Internal` is no event emitted — the noop emits nothing for any input; canary asserts the Internal short-circuit for any real implementation.
- **D8 — Where these primitives live — packages and dependency rule.** Four contract surfaces in `HoneyDrunk.Kernel.Abstractions.Tenancy`. Two noop defaults in `HoneyDrunk.Kernel.Tenancy`. Zero new dependencies.
- **D9 — Ordering — Kernel ships first, then Vault docs, then consumer Nodes.** This is step 1. `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel` move together to `0.5.0`.

**ADR-0019 (Communications standup + Notify refactor) — context only.** ADR-0019 renamed Notify's `Orchestration/` folder to `Intake/`, which is the layer the rate-limit and billing primitives are intended to land in for consumer Nodes. This packet does not touch Notify; the reference is for downstream context.

## Constraints

- **Naming rule.** Records drop `I` (`TenantRateLimitDecision`, `BillingEvent`); interfaces keep it (`ITenantRateLimitPolicy`, `IBillingEventEmitter`); enums get no prefix (`TenantRateLimitOutcome`). Verify before commit.
- **No ADR ID in code comments or README.** Per the no-ADR-in-docs convention, the new XML docs and README sections do NOT mention `ADR-0026`. Packet runtime data (this file, frontmatter, CHANGELOG) does reference the ADR.
- **No new runtime dependencies.** Verify both `.csproj` files are unchanged on the `<PackageReference>` side. If a new dependency is needed, stop and flag — adding one violates Invariant 1 / 2 and is not in this packet's scope.
- **Internal-default at the boundary, never at the consumer.** The fix for "consumer forgot to default" is centralized parsing in `GridContextMiddleware` + the mappers + the serializer's deserialize path. Do not add `?? TenantId.Internal` at any consumer site — that defeats the purpose of the type promotion.
- **Malformed-header handling differs by transport.** HTTP edge → 400 (defensive rejection). Messaging hop → log warning + Internal default (cannot 400 a queued message). Job hop → log warning + Internal default. Document the divergence inline.
- **Sentinel value must be parseable AND stable.** `TenantId.Internal` must round-trip through `TenantId(string)` constructor and `TenantId.TryParse`. The chosen literal is canary-pinned for the lifetime of the type.
- **`TryAddSingleton` for the noop registrations.** Consumer Nodes (Notify Cloud, future commercial Nodes) must be able to register their own `ITenantRateLimitPolicy` / `IBillingEventEmitter` and have it win. `TryAddSingleton` makes the noop a default rather than a hard-wired registration.
- **No analyzer additions.** ADR-0026 Open Questions §2 mentions a future static analyzer that flags `ITenantRateLimitPolicy` references inside `Routing/`, `Worker/`, or `Providers/` folders. That is a separate future packet for `HoneyDrunk.Standards`, not this one.

## Labels
`feature`, `tier-3`, `core`, `breaking-change`, `adr-0026`, `wave-1`

## Agent Handoff

**Objective:** Ship the entire Kernel half of ADR-0026 step 1 — typed `TenantId` on `IGridContext`, `Internal` sentinel + `IsInternal` predicate, the four-surface `Tenancy` namespace in Kernel.Abstractions, the two noop defaults in Kernel, with a coordinated 0.5.0 minor version bump on both Kernel and Kernel.Abstractions.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Make Grid-wide multi-tenant primitives a Kernel-Abstractions concern so Notify Cloud — and any future commercial Node — does not invent its own tenancy types.
- Feature: ADR-0026 Grid Multi-Tenant Primitives, step 1 of D9 ordering.
- ADRs: ADR-0026 (multi-tenant primitives), ADR-0019 (context only — Notify's `Intake/` folder is where consumer Nodes will land the rate-limit / billing wiring later).
- PDR: PDR-0002 (Notify Cloud as the Grid's first commercial product) — this packet's primitives are the foundation Notify Cloud sits on.

**Acceptance Criteria:** As listed above.

**Dependencies:** None upstream. Downstream: Vault packet (#02), Pulse packet (#03), Architecture catalog packet (#04).

**Constraints:** Per Constraints section above. Specifically:
- Naming rule (records drop `I`, interfaces keep it).
- No ADR ID in code comments / README.
- No new NuGet dependencies (Invariant 1 / 2).
- Internal-default at the boundary, not at consumers.
- HTTP-edge malformed → 400; messaging/job malformed → warning + Internal default.
- `TryAddSingleton` for noop registrations.
- Coordinated `0.4.x → 0.5.0` bump on both `.csproj` files (Invariant 27).

**Inlined Invariant Text (for review without leaving the target repo):**

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer.

> **Invariant 5:** GridContext must be present in every scoped operation.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Two tiers: repo-level (mandatory for every release) and per-package (only when the package has functional changes — no noise entries for alignment bumps).

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 14:** Canary tests validate cross-Node boundaries.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section.

> **Invariant 27:** All projects in a solution share one version and move together. The first packet to land on a solution in an initiative bumps the version; subsequent packets append to the CHANGELOG only.

> **Invariant 31:** Every PR traverses the tier-1 gate before merge.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

**Key Files:**
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions/Identity/TenantId.cs`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions/Context/IGridContext.cs`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions/Tenancy/` (new folder, 4 new files)
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel/Context/GridContext.cs`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel/Context/Middleware/GridContextMiddleware.cs`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel/Context/Mappers/MessagingContextMapper.cs`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel/Context/Mappers/JobContextMapper.cs`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel/AgentsInterop/GridContextSerializer.cs`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel/Tenancy/` (new folder, 2 noop default files)
- DI extension owning `AddHoneyDrunkNode()` registrations (locate at execution; likely under `Hosting/` or `Extensions/`)
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Tests/` — new canaries + updated tenant tests
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` (version)
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` (version)
- Per-package `CHANGELOG.md` and root-level `CHANGELOG.md`

**Contracts (the four wired by this packet):**
- `ITenantRateLimitPolicy.EvaluateAsync(TenantId, string, CancellationToken) → ValueTask<TenantRateLimitDecision>`
- `TenantRateLimitDecision(TenantRateLimitOutcome, TimeSpan?, string?)` record + `TenantRateLimitOutcome { Allow, Throttle, Reject }` enum
- `IBillingEventEmitter.EmitAsync(BillingEvent, CancellationToken) → ValueTask`
- `BillingEvent(TenantId, string, string, long, DateTimeOffset, string, IReadOnlyDictionary<string, string>)` record
- Promoted: `IGridContext.TenantId` from `string?` to `TenantId` (non-nullable)
- Added: `TenantId.Internal` static + `TenantId.IsInternal` predicate
