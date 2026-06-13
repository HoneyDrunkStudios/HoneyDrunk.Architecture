# Handoff — Wave 2: Audit pseudonymous-token foundation

**Initiative:** `adr-0050-tenant-lifecycle`
**Wave transition:** Wave 1 (governance + catalog) → Wave 2 (Audit pseudonymous-token foundation)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 landed

- **Packet 00** — ADR-0050 flipped to **Accepted**. Two new invariants added to `constitution/invariants.md` under a new `## Multi-Tenant Lifecycle Invariants` section (after `## Multi-Tenant Boundary Invariants`), numbered **78, 79** (pre-reserved for ADR-0050 as part of a 12-ADR batch; current verified max is 51):
  1. **78** — Audit substrate actor and subject fields accept only pseudonymous tokens. PII rejected at the audit-writer boundary. The PII↔token map lives in `HoneyDrunk.Auth.IdentityMap`, which is erasable; destruction of the map row is GDPR Art. 17 erasure per EDPB Guidelines 01/2025. **Preserves and complements invariant 47** (audit append-only) — the audit substrate never had the PII to begin with.
  2. **79** — Every tenant exists in exactly one of the seven enumerated states (`Prospect`, `Trialing`, `Active`, `PastDue`, `Suspended`, `Offboarding`, `Closed`). State machine integrity is a compile-time enum plus a runtime transition guard. Every transition emits an audit event with source state, target state, initiator, mechanism.
- **Packet 01** — The tenant-lifecycle artifacts registered in the Grid catalogs: `PseudoUserToken` and `PseudoTenantToken` under `honeydrunk-audit`; `TenantState` under `honeydrunk-auth`; the Communications→{Auth, Vault, Data, Notify, Audit} workflow-composition edges; the four-sub-flow Tenant Lifecycle entry in `constitution/feature-flow-catalog.md`; the IdentityMap description in `repos/HoneyDrunk.Auth/integration-points.md`.

ADR-0050's decisions are now live rules. Packet 02 implements the contracts the catalog already advertises.

## What Wave 2 must deliver (packet 02)

Build the audit pseudonymous-token foundation in **`HoneyDrunk.Audit`** (live Node, currently v0.1.0, .NET 10.0):

- **`HoneyDrunk.Audit.Abstractions`** — add:
  - `PseudoUserToken` (record, format `pu_` + 32-char base32, validated at construction).
  - `PseudoTenantToken` (record, format `pt_` + 32-char base32, validated at construction).
  - New `AuditEntry.CreatePseudonymous(...)` static factory accepting `PseudoUserToken` + `PseudoTenantToken` for actor/tenant fields.
  - New `AuditEntry.ActorToken` and `AuditEntry.TenantToken` init properties.
  - Seven new event-name constants in an `AuditEvents` static class (or extension of an existing one): `TenantProvisioned`, `TenantSuspended`, `TenantReinstated`, `TenantOffboarding`, `TenantClosed`, `TenantDataExported`, `UserErased`.
- **`HoneyDrunk.Audit.Data`** (the writer composition home) — add an internal `PiiRejection` helper that rejects raw email / IPv4 / IPv6 / phone-shaped Actor strings with a clear `InvalidOperationException` naming the resolution (the IdentityMap). Pseudonymous tokens and synthetic actor strings (`system-*`, `ops-*`, `webhook-*`) pass.
- This is the **version-bumping packet**: bump every non-test `.csproj` in the solution `0.1.0` → `0.2.0` in one commit (invariant 27).

## The transitional accommodation — load-bearing

The existing `(string Actor, TenantId TenantId)` primary constructor of `AuditEntry` **remains in place** during a transitional window. Auth v0.5.0 is a live emitter (per the ADR-0031 standup), and a straight rename of `Actor: string` → `Actor: PseudoUserToken` would break Auth's compilation against `HoneyDrunk.Audit.Abstractions` v0.2.0 until packets 03 and 07 land.

The transitional path:
1. Packet 02 adds the new types + factory. Existing `string Actor` overload remains. Runtime PII rejection at the writer.
2. Packet 07 rewires Auth and Communications emitters to use the new pseudonymous-token factory.
3. A **future packet** (not in this initiative) marks `string Actor` `[Obsolete]`.
4. A **further future packet** removes `string Actor` entirely.

This is **additive in v0.2.0** — no compile break for current emitters. D6's type-level enforcement is achieved over the subsequent two minor versions.

## Interface signatures for downstream packets

`PseudoUserToken` — record wrapping a non-empty string:
```
public sealed record PseudoUserToken(string Value);
// Format: "pu_" + 32-char base32 (no padding), validated at construction.
```

`PseudoTenantToken` — same shape, `pt_` prefix:
```
public sealed record PseudoTenantToken(string Value);
// Format: "pt_" + 32-char base32 (no padding), validated at construction.
```

`AuditEntry.CreatePseudonymous` — the new factory packets 03 (Auth), 05 (Communications), 06 (Data export), 07 (audit emission wiring) consume:
```
public static AuditEntry CreatePseudonymous(
    AuditEntryId id,
    DateTimeOffset occurredAt,
    PseudoUserToken actor,
    PseudoTenantToken tenantToken,
    string eventName,
    AuditCategory category,
    AuditOutcome outcome,
    AuditTarget target,
    string? correlationId = null,
    AuditOperation operation = AuditOperation.None,
    IReadOnlyList<AuditChange>? changes = null,
    IReadOnlyDictionary<string, string>? metadata = null,
    string? reason = null);
```

The factory:
- Populates `ActorToken` and `TenantToken` init properties.
- Sets the legacy `string Actor` field to `actor.Value` for backward-compat with consumers reading `Actor`.
- Passes `TenantId.Internal` for the legacy `TenantId` field — the actual tenant reference rides `TenantToken`.

`AuditEvents` constants — the canonical event-name strings:
```
public static class AuditEvents
{
    public const string TenantProvisioned = "tenant.provisioned";
    public const string TenantSuspended = "tenant.suspended";
    public const string TenantReinstated = "tenant.reinstated";
    public const string TenantOffboarding = "tenant.offboarding";
    public const string TenantClosed = "tenant.closed";
    public const string TenantDataExported = "tenant.data_exported";
    public const string UserErased = "user.erased";
}
```

## Frozen / do-not-touch

- **The `IAuditLog` interface shape.** `IAuditLog.Append(AuditEntry)` is unchanged. The new factory produces an `AuditEntry`; the writer consumes it through the same interface. Invariant 47 is preserved.
- **The existing `AuditEntry` primary constructor.** Do NOT remove or mark `[Obsolete]` — Auth v0.5.0 emitters use it.
- **The `TenantId` Kernel primitive.** `TenantId` from ADR-0026 is a Grid-plumbing identifier (the `tnt_` + 26-char ULID). It is NOT pseudonymous in the GDPR sense (it's a Grid-internal ID, not PII). It can coexist with `PseudoTenantToken` on `AuditEntry` — the legacy path uses `TenantId`; the pseudonymous path uses `TenantToken`.
- **Invariant 47.** Preserved. The audit substrate remains append-only. No `IAuditLog.Delete` ever exists.

## Invariants binding Wave 2

- **Invariant 1** — `HoneyDrunk.Audit.Abstractions` has zero runtime dependencies on other HoneyDrunk packages beyond the existing `HoneyDrunk.Kernel.Abstractions` reference (for `TenantId`). The new value types use BCL types only. The `PiiRejection` helper lives in `HoneyDrunk.Audit.Data` (runtime), not Abstractions.
- **Invariant 13** — All public APIs have XML documentation.
- **Invariant 27** — Every non-test `.csproj` in the solution moves to `0.2.0` in one commit. No partial bumps. Packet 07's Audit-side work (if option 1 is taken) appends to or patch-bumps from this baseline.
- **Invariant 47** — Audit substrate is append-only by interface. Preserved.
- **Invariant 78** (new this initiative) — Audit substrate actor/subject fields accept only pseudonymous tokens; PII rejected at the boundary. The PII-rejection helper enforces the runtime side; the new factory enforces the compile-time side.
- **Naming rule** — Records drop the `I` (`PseudoUserToken`, `PseudoTenantToken`); interfaces keep it (`IAuditLog`, `IAuditQuery`).

## Acceptance gate for the wave

Packet 02's PR passes the `pr-core.yml` tier-1 gate. `HoneyDrunk.Audit` is at `0.2.0` with the pseudonymous-token foundation shipped. Wave 3 (packet 03 in `HoneyDrunk.Auth` for the state machine + IdentityMap, packet 04 in `HoneyDrunk.Architecture` for the canary spec) can then start in parallel.

**Human package release at the Wave 2→3 boundary — agents never tag.** Packet 03 (Auth) builds against `HoneyDrunk.Audit.Abstractions` `0.2.0`; that artifact reaches the package feed only after a human pushes a git release tag on `HoneyDrunk.Audit`. After packet 02 merges, a human must tag/release `HoneyDrunk.Audit` `0.2.0` so packet 03 can compile. Packet 04 (canary spec) has no NuGet dependency — it can land anytime after packet 00.
