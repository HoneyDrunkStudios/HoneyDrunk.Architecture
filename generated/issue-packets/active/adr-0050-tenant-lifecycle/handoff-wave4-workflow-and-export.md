# Handoff — Wave 4: Communications workflow + Data export pipeline

**Initiative:** `adr-0050-tenant-lifecycle`
**Wave transition:** Wave 3 (Auth state machine + canary spec) → Wave 4 (Communications workflow scaffold + Data export pipeline)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 3 landed

- **Packet 03** — `HoneyDrunk.Auth` v0.6.0 with the seven-state `Tenants` machine, the `IdentityMap` (PII↔pseudonymous-token resolution), pseudonymous-token issuance via CSPRNG, the runtime transition guard rejecting undeclared moves. In-memory defaults; durable backing deferred.
  - **Contracts:** `TenantState` enum, `Tenant` record, `ITenantStore` (CreateProspect / Transition / Get-by-id / Get-by-pseudonymous-token), `IIdentityMap` (Create / Resolve / ResolveByUserId / EraseUser; symmetric for tenants), `TransitionRules`, `InvalidTenantTransitionException`, `UserIdentity`, `TenantIdentity`.
  - **Mechanics-only — no audit emission.** `TransitionAsync` and `EraseUserAsync` ship as pure-mechanic methods; audit emission lands in packet 07.
- **Packet 04** — `constitution/gdpr-erasure-canary.md` ships. Seven-section specification (Purpose, Setup, Act, Assertions, Non-goals, Where it runs, Implementation packet). The four load-bearing assertions are committed: identity-map row deletion (both resolution directions), audit substrate retention with unresolvable tokens, erasure idempotency, `UserErased` event emission (deferred to the implementing packet). The implementation is a deferred follow-up.

Wave 4 can now start: Communications composes Auth's `ITenantStore` / `IIdentityMap`; Data composes Auth's `IIdentityMap` for tenant-token resolution.

## What Wave 4 must deliver (packets 05 and 06, in parallel)

### Packet 05 — `HoneyDrunk.Communications` v0.3.0

Scaffold the tenant-lifecycle workflow:

- **`HoneyDrunk.Communications.Abstractions`** — `Prospect` record, `IProspectIntake`, `ITenantLifecycleWorkflow`, the nine `IProvisioningStep`-derived interfaces, `SuspensionReason`, `OffboardingReason`, `ProvisioningWorkflowFailure`.
- **`HoneyDrunk.Communications`** (runtime) — in-memory `IProspectIntake` + `IProspectStore`, `TenantLifecycleWorkflow` (in-process `Task.Run`-style sequencing — durable runtime deferred), the nine step implementations (most are no-op contract seams for un-scaffolded capabilities; only `AllocateTenantIdStep`, `EmitTenantProvisionedAuditStep`, `SendWelcomeEmailStep` do real work in this packet — the audit-emission step will be **dropped** by packet 07's consolidation, but for packet 05's scope it's a no-op).
- Version bump `0.2.0 → 0.3.0` (invariant 27).
- Per-step decision-log entries via the existing `ICommunicationDecisionLog` (invariant 42).

The workflow shape (9 steps from ADR-0050 D3):
1. Allocate `TenantId` (composes `ITenantStore.CreateProspectAsync` from packet 03).
2. Create Vault namespace (no-op).
3. Provision Auth scope (no-op — Auth's `CreateProspectAsync` already covers).
4. Assign owner role (no-op).
5. Provision data partition (no-op — per the missing Tenant-Data-Isolation ADR).
6. Allocate Notify quota (no-op).
7. Create billing customer (no-op — `HoneyDrunk.Billing` not scaffolded).
8. Emit `TenantProvisioned` audit event (placeholder in this packet; **dropped by packet 07**).
9. Send welcome email (composes `INotificationSender` per the existing v0.2.0 pattern).

### Packet 06 — `HoneyDrunk.Data` v0.7.0

Implement the tenant-data export pipeline:

- **`HoneyDrunk.Data.Abstractions`** — `ITenantDataExporter`, `TenantExportResult`, `TenantExportEntry`, `TenantExportManifest`, `ITenantExportRateLimiter`, `TenantExportRateLimitException`, `ITenantExportableEntity`.
- **`HoneyDrunk.Data`** (runtime) — `TenantDataExporter` (walks tenant-scoped repositories filtering by `TenantId`, emits NDJSON + CSV + JSON schema per entity into a ZIP, uploads to Azure Blob Storage, returns a 7-day signed URL), in-memory rate limiter, the manifest/README builder.
- Audit emission of `TenantDataExported` via `AuditEntry.CreatePseudonymous` — resolves the tenant token via `IIdentityMap.ResolveTenantAsync` (Auth-side packet 03).
- Sync-only delivery for v1; async/email path deferred.
- Rate limit: 1 export per tenant per 24 hours (configurable).
- Signed URL TTL: 7 days (configurable).
- Version bump `0.6.0 → 0.7.0`.

The exportable-entity registry is **empty by default** — hosts register tenant-scoped entities via `services.AddTenantExportDescriptor<T>(...)`. The empty case is a tested code path returning an empty manifest + explanatory README + a valid signed URL.

## Interface signatures consumed by both packets

From packet 03 (`HoneyDrunk.Auth` v0.6.0):

```csharp
public interface ITenantStore
{
    ValueTask<Tenant?> GetByIdAsync(TenantId id, CancellationToken ct);
    ValueTask<Tenant?> GetByPseudonymousTokenAsync(PseudoTenantToken token, CancellationToken ct);
    ValueTask<Tenant> CreateProspectAsync(/* prospect details */, CancellationToken ct);
    ValueTask<Tenant> TransitionAsync(TenantId id, TenantState target, TenantStateTransition transition, CancellationToken ct);
}

public interface IIdentityMap
{
    ValueTask<UserIdentity> CreateUserIdentityAsync(string userId, string email, string? displayName, CancellationToken ct);
    ValueTask<UserIdentity?> ResolveUserAsync(PseudoUserToken token, CancellationToken ct);
    ValueTask<UserIdentity?> ResolveByUserIdAsync(string userId, CancellationToken ct);
    ValueTask EraseUserAsync(PseudoUserToken token, string gdprRequestId, CancellationToken ct);
    // Symmetric methods for tenant identities.
}
```

From packet 02 (`HoneyDrunk.Audit.Abstractions` v0.2.0):

```csharp
public static AuditEntry CreatePseudonymous(
    AuditEntryId id, DateTimeOffset occurredAt,
    PseudoUserToken actor, PseudoTenantToken tenantToken,
    string eventName, AuditCategory category, AuditOutcome outcome, AuditTarget target,
    string? correlationId = null, ...);

public static class AuditEvents
{
    public const string TenantProvisioned = "tenant.provisioned";
    public const string TenantDataExported = "tenant.data_exported";
    // ... and the other five
}
```

## Frozen / do-not-touch

- **The durable-workflow runtime choice.** Dapr Workflow vs Azure Durable Functions vs roll-your-own — D8 explicitly defers this. Packet 05 ships an in-process placeholder. Do NOT introduce a durable runtime dependency in this packet.
- **The Communications/Notify boundary.** Communications owns decisions (invariant 41); Notify owns delivery mechanics. The welcome email goes through `INotificationSender` — do NOT add new sender-side logic to Notify.
- **The tenant-data partition model.** ADR-0050 cites "ADR-0049 (Tenant Data Isolation)" but the actual ADR-0049 is a different ADR (Data Classification). Packet 06's export walks tenant-scoped repositories via `TenantId` filtering per ADR-0026 — partition-agnostic. Do NOT invent a partition model in this packet.
- **The Audit substrate's append-only property.** All emissions through `IAuditLog.Append`. No deletion path.
- **The pseudonymous-token randomness.** Tokens are CSPRNG-generated and stored. Do NOT add derivation paths (`Hash`, `For`, `Derive`).

## Invariants binding Wave 4

- **Invariant 1** — Abstractions stay zero-HoneyDrunk-runtime-dependency. Communications.Abstractions references Auth.Abstractions and Audit.Abstractions (both Abstractions packages, OK). Data.Abstractions gains the same references.
- **Invariant 27** — Per-solution version coherence. Both packets are version-bumping packets on their respective solutions. Every non-test `.csproj` to the new minor version in one commit.
- **Invariant 41** — Decisions in Communications, delivery in Notify. Packet 05's workflow respects this.
- **Invariant 42** — Every orchestrated send records a decision-log entry. Packet 05's per-step entries satisfy this.
- **Invariant 47** — Audit append-only. Packet 06's audit emission uses `Append` (append-only).
- **Invariant 78** (this initiative) — Pseudonymous tokens only at the audit boundary. Packet 05's workflow audit emissions and packet 06's `TenantDataExported` emission both use `CreatePseudonymous`.
- **Naming rule** — Records drop the `I`. `Prospect`, `TenantExportResult`, etc. are records. Interfaces keep it.

## Acceptance gate for the wave

Packet 05's PR passes the `pr-core.yml` tier-1 gate and the Communications contract-shape canary (the new contracts are additive, paired with the `0.3.0` bump). Packet 06's PR passes its tier-1 gate. Both solutions are at their new minor versions.

Wave 5 (packet 07 — wire audit emissions in Auth and Communications) can then start. Packet 07 consumes packet 05's workflow scaffold (replacing the no-op `EmitTenantProvisionedAuditStep` with consolidation into Auth's state-transition emission) and packet 06's export pipeline (no overlap; packet 06 already emits its own `TenantDataExported`).

**Human package release at the Wave 4→5 boundary — agents never tag.** Packet 07 (Auth + Communications) consumes packets 05 and 06's NuGet artifacts. After 05 and 06 merge, humans push the corresponding git release tags so packet 07 can compile.

**Note on the workflow's step 8 — `EmitTenantProvisionedAuditStep`.** Packet 05 ships this as a placeholder. Packet 07 will **drop it** (consolidate the emission into Auth's `TransitionAsync(Prospect → Trialing)`). Packet 05's executor should NOT pre-emptively drop the step; ship it as a no-op or simple placeholder as the scaffold lists, and let packet 07 do the consolidation explicitly.

## What's NOT in Wave 4

- Audit-emission wiring at state transitions — packet 07 (Wave 5).
- Stripe webhook handlers — deferred follow-up (Billing standup).
- API-gateway suspension responses (402/403/410) — deferred follow-up.
- Scheduled-job triggers (PastDue grace, T+30 close) — deferred follow-up (scheduled-job substrate decision).
- Studios admin console — deferred initiative.
- Customer-facing portal trigger for exports — deferred follow-up (Studios admin-console area).
- Durable workflow runtime — deferred spike packet (D8 explicitly defers the Dapr/Durable-Functions choice).
- Async/email-delivered exports — deferred follow-up.
