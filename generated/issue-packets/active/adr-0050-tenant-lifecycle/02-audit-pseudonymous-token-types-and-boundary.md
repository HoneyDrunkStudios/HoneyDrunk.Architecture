---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Audit
labels: ["feature", "tier-2", "core", "adr-0050", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0050", "ADR-0030"]
wave: 2
initiative: adr-0050-tenant-lifecycle
node: honeydrunk-audit
---

# Add PseudoUserToken / PseudoTenantToken value types and the audit-writer PII rejection boundary

## Summary
Add the ADR-0050 D6 pseudonymous-token foundation to `HoneyDrunk.Audit.Abstractions`: the `PseudoUserToken` and `PseudoTenantToken` value types (both records with format validation), a new `AuditEntry` constructor overload accepting pseudonymous tokens for actor/tenant fields, runtime PII rejection at the audit-writer boundary (rejects raw email / IP / phone / name patterns), and the seven new tenant-lifecycle event-name constants (`TenantProvisioned`, `TenantSuspended`, `TenantReinstated`, `TenantOffboarding`, `TenantClosed`, `TenantDataExported`, `UserErased`). The existing `string Actor` constructor overload **remains in place** during a transitional window — D6's "compile-time type enforcement where possible; runtime rejection where not" is achieved over two minor versions, not in one breaking jump. This is the version-bumping packet for `HoneyDrunk.Audit`.

## Context
ADR-0050 D6 is the central architectural commitment of this initiative: the audit substrate stores only pseudonymous tokens, the PII↔token map lives in an erasable store (`HoneyDrunk.Auth.IdentityMap` — packet 03), and destruction of the map row constitutes GDPR Art. 17 erasure of the pseudonymous data per EDPB Guidelines 01/2025. This preserves invariant 47 (audit append-only) while satisfying the right to erasure.

The Audit Node is **live** (`HoneyDrunk.Audit.Abstractions` and `HoneyDrunk.Audit.Data` v0.1.0 published per ADR-0031 standup completion 2026-05-21). The current `AuditEntry` shape (verified in `HoneyDrunk.Audit/src/HoneyDrunk.Audit.Abstractions/AuditEntry.cs`):

```csharp
public sealed record AuditEntry(
    AuditEntryId Id,
    DateTimeOffset OccurredAt,
    string Actor,                  // currently raw string
    string EventName,
    AuditCategory Category,
    AuditOutcome Outcome,
    AuditTarget Target,
    TenantId TenantId,             // currently the Kernel.Abstractions TenantId
    string? CorrelationId = null,
    AuditOperation Operation = AuditOperation.None,
    IReadOnlyList<AuditChange>? Changes = null,
    IReadOnlyDictionary<string, string>? Metadata = null,
    string? Reason = null);
```

`Actor` is a raw `string`. `TenantId` is the Kernel value type (good for Grid plumbing; not pseudonymous itself in the GDPR sense). D6 requires the actor and tenant references in audit records be pseudonymous.

**The breaking-change tension and the resolution.** A straight rename of `Actor: string` → `Actor: PseudoUserToken` in v0.2.0 would force Auth (the first emitter, v0.5.0 wired per ADR-0031) to fail compilation against `HoneyDrunk.Audit.Abstractions` v0.2.0 until packet 03 + 07 land. That defeats the wave structure — packet 03 (Auth state machine + IdentityMap) and packet 07 (Auth+Communications emitter rewires) are the work that makes Auth ready to emit pseudonymous tokens, and they consume the new types this packet ships.

The resolution is a **typed-narrowing with a transitional accommodation**:

1. **This packet (02)** adds the new types and a new constructor overload accepting pseudonymous tokens. The existing `string Actor` overload remains. The audit-writer boundary runs runtime PII rejection on the `string Actor` path — strings matching email / IP / phone / common-name patterns are rejected with a clear error. Strings that look like a `PseudoUserToken` (matching `^pu_[A-Z2-7]{32}$`) or `PseudoTenantToken` (matching `^pt_[A-Z2-7]{32}$`) pass through. This gives Auth's current v0.5.0 emitters a path that works (they likely emit synthetic actor strings like `system-auth-validator`, which fall through neither PII patterns nor token patterns — see Constraints for the precise rule).
2. **Packet 07** rewires Auth and Communications emitters to use the new `PseudoUserToken` / `PseudoTenantToken` constructor overload. After 07 merges, no code emits the `string Actor` overload.
3. **A future packet (Phase-1 follow-up, NOT in this initiative)** marks the `string Actor` overload `[Obsolete]` once the in-Grid emitter migration is verified complete.
4. **A further future packet** removes the `string Actor` overload entirely.

This is **additive in this packet** (no compile break for v0.5.0 Auth emitters), and the D6 type-level enforcement is achieved over the subsequent two minor versions.

`HoneyDrunk.Audit` is a live Node currently at v0.1.0 per the standup. This packet is the **first packet on the `HoneyDrunk.Audit` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.1.0` → `0.2.0`; new feature: pseudonymous-token contracts; additive, no break with the transitional accommodation).

## Scope
- `HoneyDrunk.Audit.Abstractions` — new contract types:
  - `PseudoUserToken` — record wrapping a `string Value` with format `pu_` + 32-char base32 (the format from ADR-0050 D6's "pseudo_user_token ::= 'pu_' + 32-char base32 (no padding)"). Validate format at construction.
  - `PseudoTenantToken` — record wrapping a `string Value` with format `pt_` + 32-char base32. Validate format at construction.
  - New `AuditEntry` constructor overload accepting `PseudoUserToken Actor` and `PseudoTenantToken TenantToken` for actor / tenant fields. The existing `(string Actor, TenantId TenantId)` overload is retained.
  - `AuditEvents` static class (or extend an existing constants location) carrying the seven new tenant-lifecycle event-name constants: `TenantProvisioned`, `TenantSuspended`, `TenantReinstated`, `TenantOffboarding`, `TenantClosed`, `TenantDataExported`, `UserErased`. These are `const string` values (e.g. `"tenant.provisioned"`) — the canonical event-name strings every emitter uses.
- `HoneyDrunk.Audit` (runtime) — `IAuditLog` implementation gains a **boundary-rejection helper** that runs runtime PII regex checks on string-actor inputs. The helper is also reusable by other backings; place it in the runtime package so the Abstractions layer remains pure-contract per invariant 1.
- `HoneyDrunk.Audit.Data` (if it carries the writer composition) — the writer composes the boundary-rejection helper.
- Every non-test `.csproj` version-bumped to `0.2.0` (invariant 27).
- `HoneyDrunk.Audit.Abstractions/CHANGELOG.md`, `README.md` updated. Repo-level `CHANGELOG.md` new `[0.2.0]` entry. Runtime/Data per-package CHANGELOGs only for packages with real changes (Data probably gains a CHANGELOG entry for the boundary-rejection composition; the runtime package's entry depends on which package houses the helper).

## Proposed Implementation

### 1. `PseudoUserToken` and `PseudoTenantToken` value types

```csharp
namespace HoneyDrunk.Audit.Abstractions;

/// <summary>
/// Opaque pseudonymous user token. Format: "pu_" + 32-char base32 (no padding).
/// Issued by HoneyDrunk.Auth at user creation via CSPRNG; stable for the lifetime of the
/// identity-map row; permanently orphaned in the audit substrate post-erasure.
/// Not derived from the underlying user id — derivation would re-create a re-identification
/// path. Stored in the Auth-side IdentityMap.
/// </summary>
public sealed record PseudoUserToken
{
    private static readonly Regex Format = new("^pu_[A-Z2-7]{32}$", RegexOptions.Compiled);

    public string Value { get; }

    public PseudoUserToken(string value)
    {
        ArgumentException.ThrowIfNullOrEmpty(value);
        if (!Format.IsMatch(value))
            throw new ArgumentException(
                "PseudoUserToken must match 'pu_' + 32-char base32 (no padding). See ADR-0050 D6.",
                nameof(value));
        Value = value;
    }

    public override string ToString() => Value;
}
```

`PseudoTenantToken` is structurally identical, with `pt_` prefix and corresponding regex.

Both are `sealed record` per the grid-wide naming rule (records drop the `I`).

### 2. New `AuditEntry` constructor overload

The current `AuditEntry` is a `sealed record` with a positional primary constructor. Add a second positional constructor overload (or, since records compose awkwardly with multiple primary constructors, a static factory method or a converter):

Recommended approach: **add a static factory method** to `AuditEntry` plus the new properties as optional record members:

```csharp
public sealed record AuditEntry(
    AuditEntryId Id,
    DateTimeOffset OccurredAt,
    string Actor,
    string EventName,
    AuditCategory Category,
    AuditOutcome Outcome,
    AuditTarget Target,
    TenantId TenantId,
    string? CorrelationId = null,
    AuditOperation Operation = AuditOperation.None,
    IReadOnlyList<AuditChange>? Changes = null,
    IReadOnlyDictionary<string, string>? Metadata = null,
    string? Reason = null)
{
    /// <summary>The pseudonymous user token for the actor, when emitted via the pseudonymous-token path.</summary>
    public PseudoUserToken? ActorToken { get; init; }

    /// <summary>The pseudonymous tenant token, when emitted via the pseudonymous-token path.</summary>
    public PseudoTenantToken? TenantToken { get; init; }

    /// <summary>
    /// Construct an AuditEntry using pseudonymous tokens for actor and tenant fields (ADR-0050 D6).
    /// The string Actor field is populated with the token's string representation for
    /// downstream-compat; emitters migrating to D6 should use this factory.
    /// </summary>
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
        string? reason = null)
        => new(id, occurredAt, actor.Value, eventName, category, outcome, target,
               TenantId.Internal, correlationId, operation, changes, metadata, reason)
        {
            ActorToken = actor,
            TenantToken = tenantToken,
        };

    // existing NormalizeForAppend remains
}
```

Two important details:

- **`TenantId` stays present as a Kernel-level identifier.** ADR-0026's `TenantId` (the `tnt_` + 26-char ULID) is the Grid-plumbing tenant identifier and is NOT a PII — it's a Grid-internal ID. The pseudonymous `PseudoTenantToken` is a *separate* identifier (Audit-scoped, opaque, post-erasure-orphanable). Both can coexist on `AuditEntry`. The pseudonymous-token path passes `TenantId.Internal` for the `TenantId` slot (no tenant-scoped ID leaks into the audit substrate) and the actual tenant reference rides `TenantToken`. The non-pseudonymous path (legacy emitters during the transitional window) continues to use `TenantId` directly.
- **`Actor` (string) is set to `actor.Value`** — the token's string representation — when emitted via the pseudonymous path. This is for backward-compat with consumers reading the `Actor` field; they get a `pu_...` string instead of a synthetic actor name. After packet 07 migrates all emitters, both `Actor` and `ActorToken` carry the same information (token-shaped); the `string Actor` field can be removed in a later breaking-change packet.

If the chosen pattern is awkward (records with multiple primary constructors, generated `Equals` issues, etc.), the alternative is to introduce a new sibling record type `PseudonymousAuditEntry` and an `IAuditLog.AppendPseudonymous(PseudonymousAuditEntry)` overload. The executor decides at implementation time; the contract obligation is "pseudonymous tokens flow into the audit substrate via a typed path."

### 3. Audit-writer boundary rejection

In the runtime package (or `HoneyDrunk.Audit.Data` if that's where the writer composition lives), add a `PiiRejection` helper:

```csharp
internal static class PiiRejection
{
    // Cheap regex sanity checks - not exhaustive, but catches the obvious cases.
    private static readonly Regex Email = new(@"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", RegexOptions.Compiled);
    private static readonly Regex Ipv4 = new(@"\b(?:\d{1,3}\.){3}\d{1,3}\b", RegexOptions.Compiled);
    private static readonly Regex Ipv6 = new(@"(?:[0-9a-fA-F]{1,4}:){2,}[0-9a-fA-F]{0,4}", RegexOptions.Compiled);
    private static readonly Regex Phone = new(@"\+?\d[\d\s\-().]{7,}\d", RegexOptions.Compiled);
    private static readonly Regex PseudoUser = new("^pu_[A-Z2-7]{32}$", RegexOptions.Compiled);
    private static readonly Regex PseudoTenant = new("^pt_[A-Z2-7]{32}$", RegexOptions.Compiled);

    public static void RejectIfPii(string actor)
    {
        // Pseudonymous tokens pass.
        if (PseudoUser.IsMatch(actor) || PseudoTenant.IsMatch(actor)) return;

        // Synthetic actor strings (no '@', no IP shape, no phone shape) pass.
        if (Email.IsMatch(actor))
            throw new InvalidOperationException(
                "Audit emission contains an email-shaped Actor. Per ADR-0050 D6 (invariant {N1} — pseudonymous-token boundary), " +
                "the audit substrate accepts only pseudonymous tokens. " +
                "Resolve the user via HoneyDrunk.Auth.IdentityMap and emit the PseudoUserToken.");
        if (Ipv4.IsMatch(actor) || Ipv6.IsMatch(actor))
            throw new InvalidOperationException(
                "Audit emission contains an IP-shaped Actor. See ADR-0050 D6 (invariant {N1} — pseudonymous-token boundary).");
        if (Phone.IsMatch(actor))
            throw new InvalidOperationException(
                "Audit emission contains a phone-shaped Actor. See ADR-0050 D6 (invariant {N1} — pseudonymous-token boundary).");
    }
}
```

The writer's `Append(AuditEntry)` method calls `PiiRejection.RejectIfPii(entry.Actor)` before persistence. Pseudonymous-path emissions pass trivially (their `Actor` is the `pu_...` string). Legacy synthetic-actor emissions (e.g. `system-auth-validator`) pass. Raw-PII emissions throw clear and actionable errors naming the resolution: "Resolve the user via the IdentityMap."

The same helper is also called on free-text fields (`Reason`, every value in `Metadata`, every redacted-flag-false `AuditChange` value) per D6's "Free-text fields ... rejected (not silently scrubbed — the emitter is buggy if it tried) if a known PII pattern is detected."

### 4. Tenant-lifecycle event-name constants

In `HoneyDrunk.Audit.Abstractions` add (or extend an existing AuditEvents constants area):

```csharp
public static class AuditEvents
{
    // Existing event names remain.

    /// <summary>Tenant transitioned into Trialing from Prospect (ADR-0050 D3).</summary>
    public const string TenantProvisioned = "tenant.provisioned";

    /// <summary>Tenant transitioned into Suspended (ADR-0050 D4).</summary>
    public const string TenantSuspended = "tenant.suspended";

    /// <summary>Tenant transitioned from Suspended back to Active (ADR-0050 D4).</summary>
    public const string TenantReinstated = "tenant.reinstated";

    /// <summary>Tenant transitioned into Offboarding (ADR-0050 D5).</summary>
    public const string TenantOffboarding = "tenant.offboarding";

    /// <summary>Tenant transitioned into Closed (terminal); identity-map row deleted (ADR-0050 D5/D6).</summary>
    public const string TenantClosed = "tenant.closed";

    /// <summary>Tenant data exported via the D7 contract.</summary>
    public const string TenantDataExported = "tenant.data_exported";

    /// <summary>User-level GDPR Art. 17 erasure executed; identity-map row deleted (ADR-0050 D6).</summary>
    public const string UserErased = "user.erased";
}
```

If the existing constants live elsewhere (e.g. in an enum or per-category file), follow the existing pattern.

### 5. Versioning, CHANGELOGs, README

- Bump every non-test `.csproj` in the solution to `0.2.0` in one commit (invariant 27).
- Repo-level `CHANGELOG.md` new `[0.2.0]` entry: "Add ADR-0050 D6 pseudonymous-token foundation. New `PseudoUserToken` / `PseudoTenantToken` value types in `HoneyDrunk.Audit.Abstractions`. New `AuditEntry.CreatePseudonymous` factory accepting pseudonymous tokens. New tenant-lifecycle event-name constants. Runtime PII rejection at the audit-writer boundary. Transitional: the existing `string Actor` overload remains; obsoletion and removal are subsequent packets."
- `HoneyDrunk.Audit.Abstractions/CHANGELOG.md` — `[0.2.0]` entry describing the new value types and the factory.
- `HoneyDrunk.Audit.Data/CHANGELOG.md` — `[0.2.0]` entry describing the boundary-rejection composition.
- `HoneyDrunk.Audit.Abstractions/README.md` — document the new value types and the `CreatePseudonymous` factory in the public-API section. Document the cross-link to ADR-0050 D6 and the eventual obsoletion path for `string Actor`.

### 6. Tests

Unit tests:
- `PseudoUserToken` / `PseudoTenantToken` construction: valid format passes; invalid prefix / invalid base32 / wrong length throws `ArgumentException` with a clear message.
- `AuditEntry.CreatePseudonymous` produces an entry with both `ActorToken` populated and `Actor` set to the token's string value.
- `PiiRejection.RejectIfPii`: emails throw; IPv4 / IPv6 throw; phone-shaped strings throw; pseudonymous tokens pass; synthetic actor names (`system-auth-validator`, `ops-operator`, etc.) pass.
- Writer integration: a writer composed with the rejection helper rejects email-shaped Actor inputs and accepts pseudonymous-token inputs.

## Affected Files
- `src/HoneyDrunk.Audit.Abstractions/PseudoUserToken.cs` (new)
- `src/HoneyDrunk.Audit.Abstractions/PseudoTenantToken.cs` (new)
- `src/HoneyDrunk.Audit.Abstractions/AuditEntry.cs` (extended — new `ActorToken` / `TenantToken` init properties; new `CreatePseudonymous` factory)
- `src/HoneyDrunk.Audit.Abstractions/AuditEvents.cs` (new or extended — the seven event-name constants)
- `src/HoneyDrunk.Audit.Abstractions/HoneyDrunk.Audit.Abstractions.csproj` (version bump)
- `src/HoneyDrunk.Audit.Abstractions/CHANGELOG.md`, `README.md`
- `src/HoneyDrunk.Audit.Data/` — `PiiRejection.cs` (new internal helper), `AuditLog.cs` (or wherever the writer composes — call `PiiRejection.RejectIfPii` in `Append`)
- `src/HoneyDrunk.Audit.Data/HoneyDrunk.Audit.Data.csproj` (version bump)
- `src/HoneyDrunk.Audit.Data/CHANGELOG.md`
- Repo-level `CHANGELOG.md`
- Test project(s) — new unit tests for value types, factory, and PiiRejection

## NuGet Dependencies
- **`HoneyDrunk.Audit.Abstractions`** — no new `PackageReference`. The new types use `System.Text.RegularExpressions` from the BCL. The existing `HoneyDrunk.Kernel.Abstractions` reference (for `TenantId`) is retained.
- **`HoneyDrunk.Audit.Data`** — no new `PackageReference` beyond the existing stack. `System.Text.RegularExpressions` is BCL.
- `HoneyDrunk.Standards` is already on every project; no change.

## Boundary Check
- [x] `PseudoUserToken` and `PseudoTenantToken` are audit-substrate contracts per ADR-0050 D6 (they are the type-level enforcement of the pseudonymous-token boundary invariant `{N1}` claimed by packet 00 — the audit-side boundary types). Routing rule "audit substrate, IAuditLog, AuditEntry, ... → HoneyDrunk.Audit" maps here.
- [x] The PII-rejection helper lives in the runtime/Data package, not Abstractions — invariant 1 (Abstractions have zero runtime dependencies on HoneyDrunk packages; no runtime logic in Abstractions).
- [x] The runtime PII check is regex-based, not a network call to a PII-detection service — the boundary check is a sanity gate, not a comprehensive scan.
- [x] No new cross-Node dependency. The new value types are Audit-owned; consuming Nodes (Auth in packet 03, Communications in packet 05) reference `HoneyDrunk.Audit.Abstractions` only.

## Acceptance Criteria
- [ ] `HoneyDrunk.Audit.Abstractions` exposes `PseudoUserToken` (record, format `pu_` + 32-char base32, validated at construction) and `PseudoTenantToken` (record, format `pt_` + 32-char base32, validated at construction)
- [ ] `AuditEntry` exposes new init properties `ActorToken` (`PseudoUserToken?`) and `TenantToken` (`PseudoTenantToken?`)
- [ ] `AuditEntry.CreatePseudonymous(...)` static factory exists, accepts `PseudoUserToken` + `PseudoTenantToken`, returns an entry with both new properties populated and the `Actor` string set to the token's string value
- [ ] The existing `(string Actor, TenantId TenantId)` primary constructor remains in place (transitional accommodation per the dispatch plan)
- [ ] `HoneyDrunk.Audit.Abstractions` exposes the seven tenant-lifecycle event-name constants (`TenantProvisioned`, `TenantSuspended`, `TenantReinstated`, `TenantOffboarding`, `TenantClosed`, `TenantDataExported`, `UserErased`) as `const string` values matching the canonical names
- [ ] The audit-writer composition rejects raw email / IPv4 / IPv6 / phone-shaped Actor inputs with a clear `InvalidOperationException` naming the resolution (the IdentityMap)
- [ ] Pseudonymous-token-shaped Actor inputs pass the boundary check
- [ ] Synthetic Actor strings (e.g. `system-auth-validator`) pass the boundary check
- [ ] All new public types have XML documentation (invariant 13)
- [ ] `HoneyDrunk.Audit.Abstractions` has zero runtime `PackageReference` on any HoneyDrunk package beyond the existing `HoneyDrunk.Kernel.Abstractions` for `TenantId` (invariant 1)
- [ ] Every non-test `.csproj` in the solution is at version `0.2.0` in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.2.0]` entry dated to the merge
- [ ] `HoneyDrunk.Audit.Abstractions/CHANGELOG.md` and `HoneyDrunk.Audit.Data/CHANGELOG.md` have `[0.2.0]` entries (both have functional changes — Abstractions ships new types; Data composes the PII-rejection helper)
- [ ] `HoneyDrunk.Audit.Abstractions/README.md` documents the new value types, factory, and event-name constants
- [ ] Unit tests cover: value-type construction (valid, invalid prefix, invalid base32, wrong length); factory output shape; PII rejection (email / IP / phone reject; pseudonymous / synthetic pass)
- [ ] Tests contain no `Thread.Sleep` (invariant 51)
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
None. (No portal action, no secret seeding — this is a pure-code packet.)

## Referenced ADR Decisions

**ADR-0050 D6 — Pseudonymization at the audit boundary.** Audit substrate stores only pseudonymous tokens. The token shapes are `pu_` + 32-char base32 for users and `pt_` + 32-char base32 for tenants. Tokens are generated by `HoneyDrunk.Auth` via CSPRNG (NOT derived from underlying IDs — derivation defeats erasure). The PII↔token map lives in `HoneyDrunk.Auth.IdentityMap`. Destruction of the map row constitutes effective GDPR Art. 17 erasure per EDPB Guidelines 01/2025. The audit substrate retains the orphaned tokens, the structural shape of the event, and the fact-that-an-erasure-happened event (`UserErased` / `TenantClosed`). Invariant 47 (audit append-only) is preserved.

**ADR-0050 D6 — Compile-time enforcement where possible; runtime rejection where not.** Compile-time: `PseudoUserToken` / `PseudoTenantToken` are typed value types; `CreatePseudonymous` requires them. Runtime: the writer rejects raw-PII patterns on the `string Actor` legacy path.

**ADR-0050 D3 / D4 / D5 — New event names.** `TenantProvisioned`, `TenantSuspended`, `TenantReinstated`, `TenantOffboarding`, `TenantClosed`, `TenantDataExported`, `UserErased` are first-class audit events emitted by the lifecycle workflow.

**ADR-0030 — Audit substrate (referenced).** The `IAuditLog` interface keeps its shape; the value types it accepts are tightened (raw `string` → `PseudoUserToken` / `PseudoTenantToken` on the new factory path).

**ADR-0031 (referenced) — Audit standup.** `HoneyDrunk.Audit.Abstractions` v0.1.0 and `HoneyDrunk.Audit.Data` v0.1.0 are published; this packet ships v0.2.0.

**Invariant 1 (constraint) — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** The pseudonymous-token types live in Abstractions (pure records, no runtime logic). The PII-rejection helper lives in the runtime/Data package.

**Invariant 27 (constraint) — All projects in a solution share one version and move together.** Bump every non-test `.csproj` to `0.2.0` in one commit.

**Invariant 47 (referenced, preserved) — Durable, attributable audit events flow through `IAuditLog` on a durable channel separate from observability telemetry.** This packet preserves invariant 47 — the writer surface remains append-only; only the typed shape of the actor/tenant fields is extended.

## Constraints
- **Transitional accommodation is intentional.** Do NOT remove the existing `(string Actor, TenantId TenantId)` primary constructor or mark it `[Obsolete]` in this packet — Auth v0.5.0 is a live emitter and breaking it now defeats the wave structure. The obsoletion path is a future packet after packet 07 migrates all emitters.
- **Pseudonymous tokens are NOT derived.** Do not implement `PseudoUserToken.For(string userId)` or `PseudoUserToken.Hash(...)`. They are random and stored in the IdentityMap (packet 03 builds the issuance path). This packet ships only the type and its format validator.
- **Synthetic actor strings must pass.** Strings like `system-auth-validator`, `ops-operator`, `scheduled-job-pastdue-sweep` — non-PII synthetic identifiers — must pass the PII-rejection helper. The regex set rejects email-shaped (`@`), IP-shaped (`d.d.d.d` or IPv6 colons), phone-shaped (`\+?\d` long sequences), and accepts everything else. Tune the regex set if a synthetic actor pattern legitimate in the current codebase is incorrectly rejected; document the tuning in the PR.
- **The `TenantId` slot is not erased by this packet's contract.** ADR-0026's `TenantId` (`tnt_` + 26-char ULID) is a Grid-internal plumbing ID, not PII. The pseudonymous `PseudoTenantToken` is a *separate* identifier scoped to the audit substrate. Both can coexist on `AuditEntry`. Pseudonymous emissions pass `TenantId.Internal` for the `TenantId` slot and the actual tenant reference rides `TenantToken`. The internal `TenantId.Internal` sentinel is from ADR-0026.
- **Invariant 1 — Abstractions stay zero-HoneyDrunk-dependency.** Only `Microsoft.Extensions.*` abstractions plus the existing `HoneyDrunk.Kernel.Abstractions` for `TenantId`. The PII-rejection helper lives in the runtime/Data package, not Abstractions.
- **Records drop the `I`.** `PseudoUserToken` / `PseudoTenantToken` are records — no `I` prefix. (Interfaces keep it: `IAuditLog` etc.)
- **Invariant 27 — all `.csproj` to `0.2.0` in one commit.** No partial bumps.
- **Invariant 12 — per-package CHANGELOGs are updated only for packages with functional changes.** Abstractions and Data both get entries (both ship real changes). Any other package in the solution that's only version-aligned without functional change gets no CHANGELOG noise.

## Labels
`feature`, `tier-2`, `core`, `adr-0050`, `wave-2`

## Agent Handoff

**Objective:** Add `PseudoUserToken` / `PseudoTenantToken` value types, the `AuditEntry.CreatePseudonymous` factory, the seven tenant-lifecycle event-name constants, and the audit-writer PII-rejection boundary helper. Bump `HoneyDrunk.Audit` solution to `0.2.0`.

**Target:** `HoneyDrunk.Audit`, branch from `main`.

**Context:**
- Goal: Ship the audit-side pseudonymous-token foundation every other packet in this initiative consumes.
- Feature: ADR-0050 Tenant Lifecycle rollout, Wave 2 (audit foundation).
- ADRs: ADR-0050 D6 (primary — the central architectural commitment), ADR-0030 (audit substrate, preserved), ADR-0031 (audit standup, lives at v0.1.0), ADR-0026 (`TenantId` primitive — coexists with `PseudoTenantToken`).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0050 Accepted; the two new tenant-lifecycle invariants (claimed as `{N1}`/`{N2}` from `constitution/invariant-reservations.md` by packet 00) live before the value types reference them.

**Constraints:**
- **The existing `string Actor` overload stays.** This is a transitional accommodation per the dispatch plan; do not mark `[Obsolete]` or remove. Auth v0.5.0 is a live emitter.
- **Pseudonymous tokens are random, not derived.** No `Hash`/`Derive` factory. Stored in the IdentityMap (packet 03).
- **Synthetic actor strings (`system-*`, `ops-*`, `scheduled-job-*`) must pass the PII-rejection helper.** Test against actual synthetic-actor strings in use by Auth's v0.5.0 emitters.
- Abstractions stay zero-HoneyDrunk-dependency except the existing `HoneyDrunk.Kernel.Abstractions` reference (invariant 1).
- Records drop the `I`.
- Bump every non-test `.csproj` to `0.2.0` in one commit (invariant 27). This is the bumping packet for `HoneyDrunk.Audit` in this initiative; packet 07's Audit-side work (if any) appends to the CHANGELOG.
- Invariant 47 is preserved — the writer surface remains append-only; only the typed shape of actor/tenant fields is extended.

**Key Files:**
- `src/HoneyDrunk.Audit.Abstractions/PseudoUserToken.cs`, `PseudoTenantToken.cs` (new)
- `src/HoneyDrunk.Audit.Abstractions/AuditEntry.cs` (extended)
- `src/HoneyDrunk.Audit.Abstractions/AuditEvents.cs` (new or extended)
- `src/HoneyDrunk.Audit.Data/PiiRejection.cs` (new internal helper)
- `src/HoneyDrunk.Audit.Data/AuditLog.cs` (writer composes the helper)
- Both `.csproj` files for the version bump
- Repo-level `CHANGELOG.md`; per-package CHANGELOGs for Abstractions and Data; Abstractions `README.md`

**Contracts:**
- `PseudoUserToken` (new record) — opaque pseudonymous user token; format `pu_` + 32-char base32; validated at construction.
- `PseudoTenantToken` (new record) — opaque pseudonymous tenant token; format `pt_` + 32-char base32; validated at construction.
- `AuditEntry.CreatePseudonymous` (new factory) — accepts pseudonymous tokens for actor/tenant; populates new `ActorToken` / `TenantToken` properties.
- `AuditEvents` constants (new or extended) — the seven tenant-lifecycle event-name strings.
