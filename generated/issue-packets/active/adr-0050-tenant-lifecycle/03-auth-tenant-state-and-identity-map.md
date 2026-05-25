---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Auth
labels: ["feature", "tier-2", "core", "adr-0050", "wave-3"]
dependencies: ["packet:02"]
adrs: ["ADR-0050", "ADR-0026"]
wave: 3
initiative: adr-0050-tenant-lifecycle
node: honeydrunk-auth
---

# Implement the tenant-state table, the IdentityMap, and pseudonymous-token issuance in HoneyDrunk.Auth

## Summary
Implement ADR-0050 D1 (the interim tenant-state home) and D6 (the IdentityMap that resolves the GDPR-vs-append-only collision) in `HoneyDrunk.Auth`: a `TenantState` enum in `HoneyDrunk.Auth.Abstractions`, a `Tenants` table carrying the seven-state machine, an `IdentityMap` table mapping `PseudoUserToken` ↔ `user_id` ↔ user PII and `PseudoTenantToken` ↔ `tenant_id` ↔ tenant metadata, pseudonymous-token issuance via CSPRNG at user/tenant creation, the `IIdentityMap` contract surface for the erasure deletion path, and a runtime transition guard rejecting undeclared state moves. Version-bumping packet for `HoneyDrunk.Auth`.

## Context
ADR-0050 D1 commits the seven-state tenant enumeration. State is persisted canonically in `HoneyDrunk.Billing` (when standup completes) with a read-replica view in `HoneyDrunk.Auth` for fast access-check decisions. **Until Billing is scaffolded, state lives in a `Tenants` table in `HoneyDrunk.Auth` as the interim home.** Auth is the only Node in the Grid today with a durable per-tenant identity surface; placing the state machine here is cheap and well-bounded.

ADR-0050 D6 commits the IdentityMap. Two logical mappings:
- `pseudo_user_token ↔ user_id ↔ user PII (email, name)`
- `pseudo_tenant_token ↔ tenant_id ↔ tenant metadata`

Both live in `HoneyDrunk.Auth`. The IdentityMap is **the load-bearing erasable store** — destruction of a row is the mechanism that satisfies GDPR Art. 17 while leaving the audit substrate untouched. It is the single most security-sensitive store in the Grid post-pseudonymization (all PII concentrates here).

The pseudonymous-token value types `PseudoUserToken` and `PseudoTenantToken` are shipped by packet 02 in `HoneyDrunk.Audit.Abstractions` v0.2.0. Auth references the new package version and **issues** tokens at user/tenant creation via CSPRNG, then stores the issued tokens in the IdentityMap.

`HoneyDrunk.Auth` is a live Node currently at v0.5.0 per the v0.5.0 audit-emitter release (ADR-0031 standup). This packet is the **first packet on the `HoneyDrunk.Auth` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.5.0` → `0.6.0`; new feature: tenant state machine + IdentityMap; additive).

> **Note on schema decision.** The exact persistence mechanism (EF Core via `HoneyDrunk.Data`, raw SQL, separate database, table layout) is an implementation-time decision. The contract obligations are: (a) the seven `TenantState` values are persisted and queryable by `TenantId`; (b) the IdentityMap is queryable by `PseudoUserToken` / `PseudoTenantToken` AND by `user_id` / `TenantId`; (c) row hard-delete on erasure works (no soft-delete that would defeat erasure). If Auth currently has no Data dependency and this packet would introduce one, the executor decides whether to (a) add `HoneyDrunk.Data` as a dependency, (b) use raw `Microsoft.Data.SqlClient` / equivalent, or (c) defer the durable backing behind an in-memory `ITenantStore` / `IIdentityMap` interface and ship the in-memory implementation here (similar to Communications' v0.2.0 in-memory stores). All three are acceptable; choose the lightest one consistent with Auth's existing patterns.

## Scope

### `HoneyDrunk.Auth.Abstractions` — new contracts
- `TenantState` — enum with seven values: `Prospect`, `Trialing`, `Active`, `PastDue`, `Suspended`, `Offboarding`, `Closed` (ADR-0050 D1).
- `TenantStateTransition` — record describing one transition: source state, target state, initiator (`Customer` / `Ops` / `Webhook` / `Scheduled`), mechanism (string description), timestamp, optional `Reason`.
- `Tenant` — record: `TenantId`, `PseudoTenantToken`, `TenantState`, `CreatedAt`, `LastTransitionedAt`. Carries minimal metadata; cross-tenant PII (email, company name from signup) lives in the IdentityMap rows, not on this aggregate.
- `IdentityMapEntry` — record carrying one mapping row (one for user, one for tenant). Two flavors: `UserIdentity` (with `PseudoUserToken`, `user_id`, `Email`, optional `DisplayName`) and `TenantIdentity` (with `PseudoTenantToken`, `TenantId`, optional `CompanyName`, optional contact email).
- `ITenantStore` — interface:
  - `ValueTask<Tenant?> GetByIdAsync(TenantId id, CancellationToken ct)`
  - `ValueTask<Tenant?> GetByPseudonymousTokenAsync(PseudoTenantToken token, CancellationToken ct)`
  - `ValueTask<Tenant> CreateProspectAsync(/* prospect details */, CancellationToken ct)` — allocates `TenantId`, allocates `PseudoTenantToken` via CSPRNG, stores Tenant in `Prospect` state, stores tenant-identity-map row.
  - `ValueTask<Tenant> TransitionAsync(TenantId id, TenantState target, TenantStateTransition transition, CancellationToken ct)` — validates the transition is allowed (runtime guard); persists the new state; appends the transition to a history table; returns the updated Tenant. Throws `InvalidTenantTransitionException` on undeclared transitions.
- `IIdentityMap` — interface:
  - `ValueTask<UserIdentity> CreateUserIdentityAsync(string userId, string email, string? displayName, CancellationToken ct)` — allocates `PseudoUserToken` via CSPRNG, stores the mapping, returns the issued identity.
  - `ValueTask<UserIdentity?> ResolveUserAsync(PseudoUserToken token, CancellationToken ct)` — reverse-lookup; returns null post-erasure.
  - `ValueTask<UserIdentity?> ResolveByUserIdAsync(string userId, CancellationToken ct)` — forward-lookup; returns null post-erasure or if the user was never registered.
  - `ValueTask EraseUserAsync(PseudoUserToken token, string gdprRequestId, CancellationToken ct)` — hard-deletes the row; returns successfully whether the row exists or not (idempotent erasure).
  - Symmetric methods for tenant identities.
- `TransitionRules` — static (or stateless service) carrying the valid-transition graph from ADR-0050 D1's table. Used by `ITenantStore.TransitionAsync` to validate moves at runtime.
- `InvalidTenantTransitionException` — thrown when an undeclared transition is attempted; the message names the actual source/target/initiator combination and references the seven-state-machine invariant (`68`, claimed by packet 00).

### `HoneyDrunk.Auth` (runtime) — implementations
- Default in-memory `ITenantStore` + `IIdentityMap` implementations (mirroring Communications' v0.2.0 in-memory-first pattern). Production hosts swap to a durable backing later (a deferred follow-up).
- Pseudonymous-token issuance: a `PseudonymousTokenIssuer` service using `RandomNumberGenerator` (CSPRNG) to generate 32-char base32 payloads. Internal — not surfaced on Abstractions.
- DI extensions: `services.AddHoneyDrunkAuthTenants()` registers in-memory implementations; the durable backing is registered separately when scaffolded.

### Versioning
- Bump every non-test `.csproj` in the `HoneyDrunk.Auth` solution to the next minor version (`0.5.0` → `0.6.0`) in one commit (invariant 27).
- Repo-level `CHANGELOG.md` new `[0.6.0]` entry.
- `HoneyDrunk.Auth.Abstractions/CHANGELOG.md` `[0.6.0]` entry (new contracts).
- `HoneyDrunk.Auth/CHANGELOG.md` `[0.6.0]` entry (new in-memory stores + token issuance).
- `HoneyDrunk.Auth.Abstractions/README.md` and `HoneyDrunk.Auth/README.md` updated to document the new public surface.

## Proposed Implementation

### 1. `TenantState` enum and the transition graph

```csharp
namespace HoneyDrunk.Auth.Abstractions;

/// <summary>Tenant lifecycle state per ADR-0050 D1.</summary>
public enum TenantState
{
    Prospect,
    Trialing,
    Active,
    PastDue,
    Suspended,
    Offboarding,
    Closed,
}
```

`TransitionRules` carries the valid transitions from ADR-0050 D1's table:

```
Prospect      → Trialing    (Ops, manual approval)
Trialing      → Active      (Customer self-serve / Stripe webhook)
Trialing      → Offboarding (Scheduled, trial expired no convert)
Active        → PastDue     (Stripe webhook, invoice.payment_failed)
Active        → Suspended   (Ops, ToS)
Active        → Offboarding (Customer self-serve / Ops)
PastDue       → Active      (Stripe webhook, invoice.payment_succeeded)
PastDue       → Suspended   (Scheduled, grace exceeded)
Suspended     → Active      (Ops, reinstatement)
Suspended     → Offboarding (Ops, escalation)
Offboarding   → Closed      (Scheduled, T+30 elapsed)
```

Implement as a `IReadOnlyDictionary<(TenantState from, TenantState to), TransitionInitiator>` or equivalent. The runtime transition guard reads this and rejects undeclared moves.

### 2. Pseudonymous-token issuance

CSPRNG-backed, 32-character base32 (RFC 4648 alphabet `A-Z2-7`, no padding). One internal helper:

```csharp
internal static class PseudonymousTokenIssuer
{
    private static readonly char[] Base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".ToCharArray();

    public static PseudoUserToken NewUserToken()
        => new("pu_" + RandomBase32(32));

    public static PseudoTenantToken NewTenantToken()
        => new("pt_" + RandomBase32(32));

    private static string RandomBase32(int length)
    {
        Span<byte> bytes = stackalloc byte[length];
        RandomNumberGenerator.Fill(bytes);
        var chars = new char[length];
        for (int i = 0; i < length; i++)
            chars[i] = Base32Alphabet[bytes[i] & 0x1F];   // 5 bits → base32 char
        return new string(chars);
    }
}
```

The output passes `PseudoUserToken` / `PseudoTenantToken`'s format validator (packet 02 ships those).

### 3. `Tenants` and `IdentityMap` storage shape

The exact storage shape is implementation-decided. Conceptually:

**`Tenants` table** (logical):
| Column | Type | Notes |
|--------|------|-------|
| `tenant_id` | string (`tnt_` + 26-char ULID) | PK |
| `pseudo_tenant_token` | string (`pt_` + 32-char base32) | Unique index for reverse-lookup |
| `state` | string (one of seven enum values) | Indexed for filter-by-state queries |
| `created_at` | timestamp | |
| `last_transitioned_at` | timestamp | |
| `last_transition_reason` | string nullable | |

**`TenantTransitions` table** (history, append-only — invariant 47 doesn't bind this, but the spirit applies):
| Column | Type | Notes |
|--------|------|-------|
| `id` | ULID | PK |
| `tenant_id` | string | FK to Tenants |
| `from_state` | string | |
| `to_state` | string | |
| `initiator` | string (`Customer` / `Ops` / `Webhook` / `Scheduled`) | |
| `mechanism` | string | |
| `occurred_at` | timestamp | |
| `reason` | string nullable | |

**`UserIdentityMap` table:**
| Column | Type | Notes |
|--------|------|-------|
| `pseudo_user_token` | string (`pu_` + 32-char base32) | PK |
| `user_id` | string | Unique index — the Grid `PrincipalId` per ADR-0026 |
| `email` | string | The user PII — load-bearing for the GDPR-erasure path (hard-delete this row → erasure) |
| `display_name` | string nullable | |
| `created_at` | timestamp | |

**`TenantIdentityMap` table:**
| Column | Type | Notes |
|--------|------|-------|
| `pseudo_tenant_token` | string | PK |
| `tenant_id` | string | Unique index |
| `company_name` | string nullable | |
| `contact_email` | string nullable | |
| `created_at` | timestamp | |

The two identity-map tables can be one table with a discriminator column if the executor prefers. The contract obligation is "hard-delete-by-pseudonymous-token is bounded and complete."

### 4. Erasure (hard-delete) — the load-bearing path

`IIdentityMap.EraseUserAsync(PseudoUserToken token, string gdprRequestId, CancellationToken ct)` performs a hard `DELETE` against the `UserIdentityMap` row by `pseudo_user_token`. **No soft-delete, no tombstone, no archive-table-copy.** The row goes away.

The audit emission of the `UserErased` event is **NOT** done in this packet — it lands in packet 07 (the audit-emitter wiring), which composes `IIdentityMap.EraseUserAsync` with an `IAuditLog.Append(AuditEntry.CreatePseudonymous(..., UserErased, ...))`. This packet ships only the deletion mechanic; the audit-event emission is wired in 07.

Idempotency: `EraseUserAsync` returns successfully whether the row exists or not. Calling erasure twice is not an error — that's the GDPR-compliant behavior (the second caller sees the same "the data is gone" state as the first).

### 5. Runtime transition guard

```csharp
public sealed class TenantStore : ITenantStore
{
    // ...

    public async ValueTask<Tenant> TransitionAsync(TenantId id, TenantState target, TenantStateTransition transition, CancellationToken ct)
    {
        var current = await GetByIdAsync(id, ct)
            ?? throw new InvalidOperationException($"Tenant {id} not found.");

        if (!TransitionRules.IsAllowed(current.State, target))
            throw new InvalidTenantTransitionException(current.State, target, transition.Initiator);

        // Persist new state + append transition history row.
        // ...
        return current with { State = target, LastTransitionedAt = DateTimeOffset.UtcNow };
    }
}
```

The `InvalidTenantTransitionException` message names the source/target/initiator combination and references the seven-state-machine invariant (`68`, claimed by packet 00).

### 6. Tests

Unit tests:
- `PseudonymousTokenIssuer`: tokens match the expected regex; two calls produce different tokens (with overwhelming probability).
- `TransitionRules`: every transition in ADR-0050 D1's table is allowed; every undeclared pair is rejected.
- `TenantStore.TransitionAsync`: declared transitions update state and append history; undeclared throws `InvalidTenantTransitionException`.
- `TenantStore.CreateProspectAsync`: returns a Tenant with `State = Prospect`, a freshly-issued `PseudoTenantToken`, and a corresponding `TenantIdentityMap` row.
- `IdentityMap.CreateUserIdentityAsync` + `ResolveUserAsync` + `EraseUserAsync`: round-trip; erasure clears both directions of resolution; calling erasure twice is idempotent.
- `IdentityMap.EraseUserAsync` with a non-existent token: returns successfully (idempotent).

## Affected Files
- `src/HoneyDrunk.Auth.Abstractions/Tenants/TenantState.cs` (new)
- `src/HoneyDrunk.Auth.Abstractions/Tenants/Tenant.cs` (new)
- `src/HoneyDrunk.Auth.Abstractions/Tenants/TenantStateTransition.cs` (new)
- `src/HoneyDrunk.Auth.Abstractions/Tenants/TransitionInitiator.cs` (new — enum)
- `src/HoneyDrunk.Auth.Abstractions/Tenants/ITenantStore.cs` (new)
- `src/HoneyDrunk.Auth.Abstractions/Tenants/TransitionRules.cs` (new — static class)
- `src/HoneyDrunk.Auth.Abstractions/Tenants/InvalidTenantTransitionException.cs` (new)
- `src/HoneyDrunk.Auth.Abstractions/Identity/IIdentityMap.cs` (new)
- `src/HoneyDrunk.Auth.Abstractions/Identity/UserIdentity.cs` (new)
- `src/HoneyDrunk.Auth.Abstractions/Identity/TenantIdentity.cs` (new)
- `src/HoneyDrunk.Auth/Tenants/TenantStore.cs` (new — in-memory default)
- `src/HoneyDrunk.Auth/Identity/IdentityMap.cs` (new — in-memory default)
- `src/HoneyDrunk.Auth/Identity/PseudonymousTokenIssuer.cs` (new — internal)
- `src/HoneyDrunk.Auth/DependencyInjection/ServiceCollectionExtensions.cs` (extended — `AddHoneyDrunkAuthTenants`)
- Every non-test `.csproj` — version bump
- `src/HoneyDrunk.Auth.Abstractions/CHANGELOG.md`, `README.md`
- `src/HoneyDrunk.Auth/CHANGELOG.md`, `README.md`
- Repo-level `CHANGELOG.md`
- Test project(s) — new unit tests as listed

## NuGet Dependencies
- **`HoneyDrunk.Auth.Abstractions`** — gain `HoneyDrunk.Audit.Abstractions` v0.2.0 (for `PseudoUserToken`, `PseudoTenantToken`). The existing `HoneyDrunk.Kernel.Abstractions` reference is retained.
- **`HoneyDrunk.Auth`** (runtime) — transitively gains v0.2.0 of `HoneyDrunk.Audit.Abstractions`. The CSPRNG via `System.Security.Cryptography.RandomNumberGenerator` is BCL — no new package.
- Confirm exact version of `HoneyDrunk.Audit.Abstractions` at execution time — packet 02 sets it.

## Boundary Check
- [x] `TenantState`, `ITenantStore`, `IIdentityMap`, `Tenant`, `UserIdentity`, `TenantIdentity`, `TransitionRules`, `InvalidTenantTransitionException` are all Auth-owned per ADR-0050 D1/D6. Routing rule "JWT, token validation, signing keys, authorization, identity, role, permission, claim, policy → HoneyDrunk.Auth" maps here.
- [x] The IdentityMap is the load-bearing erasable store. Holding it in Auth places it co-located with token-validation logic and consistent with ADR-0006 (per-Node Vaults — Auth's Vault namespace is the natural home for the storage credentials when the durable backing lands).
- [x] No dependency on `HoneyDrunk.Data` introduced by this packet's contract surface — the in-memory default avoids it. If the executor chooses the EF Core backing instead, that decision is documented in the PR.
- [x] No new cross-Node runtime dependency at the Abstractions layer beyond `HoneyDrunk.Audit.Abstractions` (for the pseudonymous-token types).

## Acceptance Criteria
- [ ] `HoneyDrunk.Auth.Abstractions` exposes `TenantState` enum with the seven values in the order from ADR-0050 D1
- [ ] `HoneyDrunk.Auth.Abstractions` exposes `Tenant`, `TenantStateTransition`, `TransitionInitiator`, `UserIdentity`, `TenantIdentity` records
- [ ] `HoneyDrunk.Auth.Abstractions` exposes `ITenantStore` with `GetByIdAsync`, `GetByPseudonymousTokenAsync`, `CreateProspectAsync`, `TransitionAsync`
- [ ] `HoneyDrunk.Auth.Abstractions` exposes `IIdentityMap` with create / resolve / resolve-by-id / erase methods for users AND for tenants
- [ ] `HoneyDrunk.Auth.Abstractions` exposes `TransitionRules` (static / stateless) and `InvalidTenantTransitionException`; every transition from ADR-0050 D1's table is allowed; every undeclared pair is rejected (unit-tested)
- [ ] `HoneyDrunk.Auth` (runtime) ships in-memory default implementations of `ITenantStore` and `IIdentityMap`
- [ ] Pseudonymous tokens are issued via CSPRNG (`RandomNumberGenerator`) at user/tenant creation; tokens match `PseudoUserToken` / `PseudoTenantToken` format validators (unit-tested)
- [ ] Tokens are NOT derived from underlying IDs (unit-tested: same `user_id` issued twice produces different tokens with overwhelming probability)
- [ ] `IIdentityMap.EraseUserAsync` is idempotent (calling on non-existent token returns successfully)
- [ ] `IIdentityMap.EraseUserAsync` hard-deletes the row (resolve returns null after erasure)
- [ ] `ITenantStore.TransitionAsync` throws `InvalidTenantTransitionException` on undeclared transitions; the message references the seven-state-machine invariant (`68`, claimed by packet 00)
- [ ] DI extension `services.AddHoneyDrunkAuthTenants()` registers the in-memory implementations
- [ ] All new public types have XML documentation (invariant 13)
- [ ] `HoneyDrunk.Auth.Abstractions` references `HoneyDrunk.Audit.Abstractions` v0.2.0 (per packet 02) and the existing `HoneyDrunk.Kernel.Abstractions`
- [ ] Every non-test `.csproj` in the solution is at the new minor version (`0.5.0` → `0.6.0`) in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.6.0]` entry
- [ ] `HoneyDrunk.Auth.Abstractions/CHANGELOG.md` and `HoneyDrunk.Auth/CHANGELOG.md` have `[0.6.0]` entries describing their functional changes
- [ ] `HoneyDrunk.Auth.Abstractions/README.md` and `HoneyDrunk.Auth/README.md` document the new contracts and the IdentityMap
- [ ] Tests contain no `Thread.Sleep` (invariant 51)
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
None for this packet. (The in-memory backing requires no Azure provisioning. When the durable backing is wired in a follow-up packet, that packet will name its own portal steps — likely a SQL database in the existing Auth Vault namespace per ADR-0006.)

## Referenced ADR Decisions

**ADR-0050 D1 — Seven-state tenant enumeration.** `Prospect → Trialing → Active → PastDue → Suspended → Offboarding → Closed`, with the transition graph in the ADR's D1 table. Interim home is Auth; canonical home moves to Billing when ADR-0037 scaffolds.

**ADR-0050 D6 — IdentityMap and pseudonymous-token issuance.** Tokens are random (CSPRNG-generated) — never derived from underlying IDs. Stored in the Auth-side identity map. Hard-deletion of the row is the GDPR Art. 17 erasure mechanism. Two map surfaces — `pseudo_user_token ↔ user_id ↔ user PII` and `pseudo_tenant_token ↔ tenant_id ↔ tenant metadata`.

**ADR-0050 D6 — Pseudonymous tokens are NOT derived from underlying identifiers.** "They are NOT derived from the underlying identifier (no hash, no HMAC) — derivation would re-create a re-identification path for anyone with knowledge of the underlying ID and the derivation function, which would defeat the erasure property. They are random and stored in the map."

**ADR-0026 — `TenantId` primitive.** ADR-0026's `TenantId` (`tnt_` + 26-char ULID) is the Grid-plumbing identifier; the `Tenants.tenant_id` column stores its string form. The pseudonymous `PseudoTenantToken` is a separate identifier (audit-scoped).

**Invariant 1 (constraint) — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** Auth.Abstractions gains a reference to Audit.Abstractions for the pseudonymous-token types — that is itself an Abstractions package (zero runtime dependencies, only contracts), so the Auth.Abstractions reference graph remains DAG-clean and Abstractions-only.

**Invariant 27 (constraint) — All projects in a solution share one version and move together.** Bump every non-test `.csproj` to `0.6.0` in one commit.

**Invariant `68` (from this initiative, claimed by packet 00) — Every tenant exists in exactly one of the seven enumerated states with audited initiator-attributed transitions.** This packet ships the state machine; packet 07 wires the audit emission of transition events.

**Invariant 47 (referenced) — Audit substrate is append-only and durable.** The IdentityMap is NOT the audit substrate. It is the erasable PII↔token map. Hard-deletion of an IdentityMap row is fully allowed and is the load-bearing GDPR-erasure mechanism; the audit substrate remains untouched.

## Constraints
- **Pseudonymous tokens are random, NOT derived.** Do not implement `PseudoUserToken.For(string userId)` or any hash-based factory. CSPRNG only.
- **Hard-delete, not soft-delete.** `IIdentityMap.EraseUserAsync` must perform a true `DELETE` against the persistence layer. No `IsDeleted = true` flag, no tombstone row, no archive-table copy. The PII must be irrecoverable from the IdentityMap post-erasure.
- **Idempotent erasure.** Calling `EraseUserAsync` on a non-existent token must return successfully. The GDPR-compliant behavior is "the data is gone" — both callers see the same outcome.
- **Audit emission is NOT in this packet.** This packet ships the `IIdentityMap.EraseUserAsync` deletion mechanic and the `ITenantStore.TransitionAsync` state-change mechanic. Wiring those to emit `UserErased` / `TenantProvisioned` / `TenantSuspended` / etc. audit events is packet 07's job. Do not add `IAuditLog` calls inside these methods in this packet — packet 07 composes them at the call site.
- **Invariant 1 — Abstractions stay zero-HoneyDrunk-runtime-dependency.** The reference to `HoneyDrunk.Audit.Abstractions` is acceptable (it's an Abstractions package with no runtime dependencies of its own). Do not pull in `HoneyDrunk.Audit` (the runtime) or `HoneyDrunk.Audit.Data`.
- **Invariant 27 — version bump every non-test `.csproj` in one commit.** No partial bumps. This is the bumping packet for `HoneyDrunk.Auth` in this initiative; packet 07's Auth-side work appends to the in-progress `[0.6.0]` CHANGELOG.
- **Records drop the `I`; interfaces keep it.** `Tenant`, `TenantStateTransition`, `UserIdentity`, `TenantIdentity` are records. `ITenantStore`, `IIdentityMap` are interfaces.
- **`TenantState` enum order matches ADR-0050 D1.** Some downstream consumers (e.g. the Studios admin console when scaffolded) may render by enum-order; don't reorder the values gratuitously.
- **The durable backing is deferred.** This packet ships in-memory implementations. A follow-up packet (or the next initiative needing durable tenant state) selects the storage backing — likely EF Core via `HoneyDrunk.Data` against a SQL database in the Auth Vault namespace per ADR-0006. Do not pretend the in-memory implementation is durable in CHANGELOGs or README.

## Labels
`feature`, `tier-2`, `core`, `adr-0050`, `wave-3`

## Agent Handoff

**Objective:** Implement the seven-state tenant machine, the IdentityMap (PII↔pseudonymous-token resolution), pseudonymous-token issuance via CSPRNG, and the runtime transition guard in `HoneyDrunk.Auth`. Bump the solution to `0.6.0`.

**Target:** `HoneyDrunk.Auth`, branch from `main`.

**Context:**
- Goal: Ship the Auth-side foundation packets 05, 06, 07 compose against. This is the load-bearing packet for the GDPR-erasure mechanism.
- Feature: ADR-0050 Tenant Lifecycle rollout, Wave 3.
- ADRs: ADR-0050 D1 (state machine) + D6 (IdentityMap), ADR-0026 (`TenantId` primitive), ADR-0006 (per-Node Vaults — for eventual durable-backing credentials).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — `HoneyDrunk.Audit.Abstractions` v0.2.0 exposes `PseudoUserToken` and `PseudoTenantToken`. Auth references them.

**Constraints:**
- **Pseudonymous tokens are random, NOT derived.** CSPRNG only. No hash factories.
- **Hard-delete, idempotent erasure.** `IIdentityMap.EraseUserAsync` performs a true DELETE; calling on a non-existent token succeeds.
- **Audit emission is NOT in this packet.** Packet 07 wires audit events at the state-machine transition and erasure points.
- **The durable backing is deferred.** Ship in-memory implementations. The IdentityMap is the most security-sensitive store in the Grid when it goes durable — do not pretend the in-memory version is durable in docs.
- Bump every non-test `.csproj` to `0.6.0` in one commit (invariant 27). This is the bumping packet for `HoneyDrunk.Auth` in this initiative.
- Records drop the `I`; interfaces keep it.
- `HoneyDrunk.Auth.Abstractions` stays zero-HoneyDrunk-runtime-dependency (invariant 1) — the new reference to `HoneyDrunk.Audit.Abstractions` is OK (also an Abstractions package).

**Key Files:**
- New `src/HoneyDrunk.Auth.Abstractions/Tenants/` and `src/HoneyDrunk.Auth.Abstractions/Identity/` folders with the new types
- New `src/HoneyDrunk.Auth/Tenants/TenantStore.cs` and `src/HoneyDrunk.Auth/Identity/IdentityMap.cs`
- `PseudonymousTokenIssuer.cs` (internal, CSPRNG-backed)
- DI registration extension
- Every non-test `.csproj` for the version bump
- Repo-level `CHANGELOG.md`; per-package CHANGELOGs; READMEs

**Contracts:**
- `TenantState` (new enum), `Tenant` (new record), `TenantStateTransition`, `TransitionInitiator`, `ITenantStore`, `TransitionRules`, `InvalidTenantTransitionException` — in `HoneyDrunk.Auth.Abstractions`.
- `IIdentityMap`, `UserIdentity`, `TenantIdentity` — in `HoneyDrunk.Auth.Abstractions`.
- In-memory implementations in `HoneyDrunk.Auth` runtime.
