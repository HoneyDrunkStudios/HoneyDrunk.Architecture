---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "core", "identity", "adr-0060"]
dependencies: []
adrs: ["ADR-0060", "ADR-0050", "ADR-0051", "ADR-0057", "ADR-0026", "ADR-0030", "ADR-0031"]
accepts: ADR-0060
wave: 1
initiative: adr-0060-identity-standup
node: honeydrunk-identity
---

# Chore: Register HoneyDrunk.Identity in Architecture catalogs, sectors, context folder, and ADR-0050/Auth amendments

## Summary

Bring `HoneyDrunk.Architecture` into alignment with ADR-0060's stand-up decisions for the new `HoneyDrunk.Identity` Node — the Core sector's owner of the user record, the external-IdP seam, internal-token issuance, and account-deletion fan-out. Adds `honeydrunk-identity` to `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json` (six interfaces + six records per D4), `catalogs/grid-health.json`, and `catalogs/modules.json` (`HoneyDrunk.Identity.Abstractions` + `HoneyDrunk.Identity`). Adds the **Identity** row to `constitution/sectors.md` under Core. Creates the `repos/HoneyDrunk.Identity/` context folder (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`) matching the template used by `repos/HoneyDrunk.Audit/` and `repos/HoneyDrunk.Operator/`. Authors the additive amendment note on `adrs/ADR-0050-...` recording that the `UserId` ↔ `PseudoUserToken` map relocates from `HoneyDrunk.Auth.IdentityMap` to `HoneyDrunk.Identity.IdentityMap` (additive only — ADR-0050 D6 architectural posture unchanged). Authors the additive amendment note on `repos/HoneyDrunk.Auth/` context files (boundaries.md + overview.md) clarifying Auth is validation-only and that Identity owns the user record. Registers the initiative + roadmap bullet.

ADR-0060 stays at `Status: Proposed` for this packet — the Status flip is a separate post-merge housekeeping step the scope agent handles after the entire initiative completes.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0060 establishes the Identity Node's exposed contracts, package families, IdP-wrapping posture, the `UserId`/`PrincipalId` shape, internal-token issuance, account-deletion fan-out, and what scaffolds in the first PR. None of that has reached the catalogs yet. Until it does:

- Downstream consumers (Hearth, Lately, Curiosities, Notify.Cloud) cannot scope their signup-flow packets against an Identity boundary that exists in the Grid's metadata.
- The ADR-0050 D6 placeholder ("Auth-side packet" for the user-level GDPR Art. 17 path) has no canonical home in the catalogs — the map's owner stays ambiguous.
- The Auth boundary doc still reads as if Auth is the canonical home for user-management responsibilities ("What Auth Does NOT Own — User management"), but does not yet point to Identity as the Node that does own it.
- The Architecture catalogs continue to read as if the Grid has no user-record substrate at all.

This packet closes those gaps by registering the Node, the contract surface, the relationships, and the cross-references — without flipping ADR-0060 to Accepted and without authoring any `.cs` files.

## Proposed Implementation

### `catalogs/nodes.json` — new `honeydrunk-identity` block

Insert a new entry. Place it after `honeydrunk-audit` (which lives near the Core security cluster) so the Core sector security-related Nodes group together. Mirror the schema used by `honeydrunk-audit` (Seed Node with full long_description block).

```json
{
  "id": "honeydrunk-identity",
  "type": "node",
  "name": "HoneyDrunk.Identity",
  "public_name": "HoneyDrunk.Identity",
  "short": "User record, external-IdP seam, internal-token issuance, account-deletion fan-out",
  "description": "Core-sector owner of the canonical Grid user record, the seam between the Grid and an external IdP (leading candidate Microsoft Entra External ID), short-lived internal-token issuance for service-to-service flows, and the user-level GDPR Art. 17 deletion fan-out workflow. Wraps an external IdP rather than owning a credential store.",
  "sector": "Core",
  "signal": "Seed",
  "cluster": "security",
  "energy": 0,
  "priority": 0,
  "flow": 0,
  "tags": ["identity", "user-record", "oauth", "idp", "internal-token", "deletion-fanout", "principal", "gdpr"],
  "links": {
    "repo": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Identity"
  },
  "long_description": {
    "overview": "HoneyDrunk.Identity is the Core sector's single Node that owns the user record, the seam between the Grid's internal identity model and the external IdP that issues credentials, internal-token issuance for service-to-service flows under a UserPrincipal context, and the user-level GDPR Art. 17 deletion fan-out across Nodes holding user-scoped data. Identity stores zero credentials — the credential store lives in the wrapped external IdP. Identity owns the canonical UserId, the external-IdP claim mapping, the user profile (display name, avatar, locale, account-level preferences), and the IdentityMap (PseudoUserToken ↔ UserId ↔ ExternalSubject ↔ PII).",
    "why_it_exists": "Auth is not Identity. Auth validates JWT Bearer tokens; it has no users, no credentials, no token issuance. No Node in the Grid owned the user record, the external-IdP seam, or the account-deletion fan-out — and the first user-facing apps (Hearth, Lately, Curiosities) all need a Grid-wide user account substrate. Naming the boundary now is the substrate work that makes future consumer apps cheap, per the charter's licensed permissions.",
    "primary_audience": "Consumer-app developers (Hearth, Lately, Curiosities) wiring signup/login; security reviewers tracing the user identity boundary; operations triggering user-level GDPR Art. 17 erasure via the Studios admin console.",
    "value_props": [
      "Single canonical UserId across every Grid Node and consumer app",
      "Wraps an external IdP — credential breach liability outsourced to a vendor with a dedicated security team",
      "User profile lives in Identity, not the IdP — IdP migration is a re-keying operation, not a data migration",
      "Internal-token issuance for service-to-service UserPrincipal flows (Invariant 10 holds — Auth still only validates)",
      "User-level GDPR Art. 17 deletion fan-out coordinated across Nodes holding user-scoped data",
      "Pseudonymization-aware: IdentityMap owns the PseudoUserToken ↔ UserId map ADR-0050 D6 anticipated"
    ],
    "monetization_signal": "Internal-first Core primitive. Identity costs are dominated by the wrapped IdP's pricing tier (Entra External ID free up to ~50k MAU covers Hearth/Lately/Curiosities v1).",
    "roadmap_focus": "Stand up the Node, Abstractions package, runtime, in-memory test fixtures (Phase 1). Wire the Entra (or whichever IdP) adapter when Hearth signup forces the IdP-vendor confirmation (Phase 2). Land the deletion fan-out and IdentityMap relocation from Auth (Phase 3).",
    "grid_relationship": "Consumes Kernel (IGridContext, lifecycle, telemetry), Vault (signing key for IInternalTokenIssuer, IdP client secret via ISecretStore), Auth (IAuthorizationPolicy reuse), Audit (IAuditLog for UserCreated/UserVerified/UserLocked/UserUnlocked/UserErased/InternalTokenIssued events), Data (IRepository / IUnitOfWork for the user record + IdentityMap + ExternalSubjectMap tables), Communications (verification email, account-change notifications, deletion-fan-out coordination per tenant). Consumed-planned by Hearth, Lately, Curiosities, and Notify.Cloud.",
    "integration_depth": "deep",
    "demo_path": "External IdP issues a token → IExternalIdpClaimMapper maps the IdP's sub claim to a Grid UserId → IUserDirectory resolves the user → IInternalTokenIssuer issues a short-lived internal token for downstream service-to-service flows → Auth validates the token via its existing JWT path.",
    "signal_quote": "The user record nobody had a home for, until now.",
    "stability_tier": "seed",
    "impact_vector": "consumer app readiness"
  },
  "foundational": false,
  "strategy_base": 14,
  "tier": "none",
  "time_pressure": 0,
  "done": false,
  "cooldown_days": 14
}
```

### `catalogs/relationships.json` — new `honeydrunk-identity` block

Insert after the `honeydrunk-audit` block. Mirror the schema used by `honeydrunk-audit`.

```json
{
  "id": "honeydrunk-identity",
  "consumes": ["honeydrunk-kernel", "honeydrunk-vault", "honeydrunk-auth", "honeydrunk-audit", "honeydrunk-data", "honeydrunk-communications"],
  "consumed_by": [],
  "consumed_by_planned": ["hearth", "lately", "curiosities", "honeydrunk-notify-cloud"],
  "blocked_by": [],
  "exposes": {
    "contracts": [
      "IUserDirectory",
      "IUserProfileStore",
      "IInternalTokenIssuer",
      "IExternalIdpClaimMapper",
      "IIdentityDeletionFanout",
      "IIdentityHealth",
      "UserId",
      "PrincipalId",
      "ExternalSubject",
      "UserProfile",
      "InternalToken",
      "DeletionIntent",
      "DeletionAck"
    ],
    "packages": ["HoneyDrunk.Identity.Abstractions", "HoneyDrunk.Identity"]
  },
  "consumes_detail": {
    "honeydrunk-kernel": ["IGridContext", "IOperationContext", "IStartupHook", "IHealthContributor", "ITelemetryActivityFactory", "TenantId", "HoneyDrunk.Kernel.Abstractions", "HoneyDrunk.Kernel"],
    "honeydrunk-vault": ["ISecretStore", "IConfigProvider", "HoneyDrunk.Vault"],
    "honeydrunk-auth": ["IAuthorizationPolicy", "AuthorizationDecision", "HoneyDrunk.Auth.Abstractions"],
    "honeydrunk-audit": ["IAuditLog", "AuditEntry", "HoneyDrunk.Audit.Abstractions"],
    "honeydrunk-data": ["IRepository", "IUnitOfWork", "HoneyDrunk.Data.Abstractions"],
    "honeydrunk-communications": ["ICommunicationOrchestrator", "MessageIntent", "HoneyDrunk.Communications.Abstractions"]
  }
}
```

Also update the **`honeydrunk-auth`** block's `consumed_by_planned` array to include `honeydrunk-identity` (so the upstream-edge from Identity to Auth shows). Locate the existing array `["honeydrunk-capabilities", "honeydrunk-operator", "honeydrunk-audit"]` and add `"honeydrunk-identity"`.

Also update **`honeydrunk-audit`**'s `consumed_by_planned` to include `honeydrunk-identity` (currently `["honeydrunk-auth", "honeydrunk-operator"]`).

Also update **`honeydrunk-data`**'s `consumed_by_planned` to include `honeydrunk-identity`.

Also update **`honeydrunk-communications`**'s `consumed_by_planned` to include `honeydrunk-identity`.

Notes on `consumed_by_planned` entries: `hearth`, `lately`, `curiosities`, `honeydrunk-notify-cloud` are forward references to Nodes/apps not yet registered in `nodes.json`. That mirrors how other standup ADRs forward-reference future consumers — the entries are honored when those nodes register.

### `catalogs/contracts.json` — new `honeydrunk-identity` block

Insert a new block after the `honeydrunk-audit` block. Records drop the `I` prefix per the Grid-wide naming rule; interfaces keep it.

```json
{
  "node": "honeydrunk-identity",
  "node_name": "HoneyDrunk.Identity",
  "package": "HoneyDrunk.Identity.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "IUserDirectory", "kind": "interface", "description": "Resolve a UserId to a user record (found / not-found / deleted); look up by ExternalSubject from the IdP's sub claim; lifecycle transitions (MarkVerified, Lock, Unlock, Delete). ADR-0060 D4." },
    { "name": "IUserProfileStore", "kind": "interface", "description": "Read/write user profile fields (display name, avatar URL, locale, account-level preferences). Separate from IUserDirectory because the directory surface is identity-stable; the profile is mutable user-driven content. ADR-0060 D4." },
    { "name": "IInternalTokenIssuer", "kind": "interface", "description": "Issue short-lived (≤ 5 min) internal JWT bearer tokens for service-to-service flows under a UserPrincipal context. Signed with a key resolved through ISecretStore. Auth validates these tokens — Invariant 10 holds. ADR-0060 D4 / D6." },
    { "name": "IExternalIdpClaimMapper", "kind": "interface", "description": "Provider-slot abstraction. Map external IdP claims (Entra, Clerk, etc.) to internal UserPrincipal state. The Identity runtime composes one implementation at host time per ADR-0060 D2's wrapping-seam architecture. ADR-0060 D4." },
    { "name": "IIdentityDeletionFanout", "kind": "interface", "description": "Coordinate user-level GDPR Art. 17 deletion. Emits DeletionIntent to each registered downstream consumer; collects DeletionAck; emits UserErased to Audit. Idempotent end-to-end per ADR-0042. ADR-0060 D4 / D8." },
    { "name": "IIdentityHealth", "kind": "interface", "description": "Operational health: identity-map reachability, IdP-claim-mapper reachability, deletion-fan-out queue depth. Standard Kernel IHealthContributor shape. ADR-0060 D4." },
    { "name": "UserId", "kind": "type", "description": "Record struct. 26-character ULID, prefixed `usr_`. Sortable, URL-safe, 128-bit collision-resistant. Matches the Grid prefix discipline (tnt_ per ADR-0026; pu_/pt_ per ADR-0050 D6). ADR-0060 D3." },
    { "name": "PrincipalId", "kind": "type", "description": "Record. Discriminated UserPrincipal / ServicePrincipal / AgentPrincipal wrapper per ADR-0051's three-principal model. Lets authorization policies and the audit substrate speak in PrincipalId regardless of kind. ADR-0060 D3." },
    { "name": "ExternalSubject", "kind": "type", "description": "Record. External IdP sub claim plus the IdP issuer identifier (so a sub of `abc123` from Entra and a sub of `abc123` from Clerk are distinguishable). Stored alongside the UserId in the ExternalSubjectMap table. ADR-0060 D3." },
    { "name": "UserProfile", "kind": "type", "description": "Record. Display name, avatar URL, locale, account-level preferences map. Lives in Identity's UserProfile table — not the external IdP — so IdP migration is bounded. ADR-0060 D5." },
    { "name": "InternalToken", "kind": "type", "description": "Record. The internal-issuance token shape IInternalTokenIssuer returns: token string, expiry, claim set. ADR-0060 D4 / D6." },
    { "name": "DeletionIntent", "kind": "type", "description": "Record. Emitted by IIdentityDeletionFanout to each downstream Node: UserId, PseudoUserToken, correlation_id, requested_at. Consumers respond with DeletionAck within the configured timeout. ADR-0060 D4 / D8." },
    { "name": "DeletionAck", "kind": "type", "description": "Record. Downstream Node's acknowledgement of a DeletionIntent: consumer node id, status (acknowledged / skipped / failed), correlation_id, completed_at. ADR-0060 D4 / D8." }
  ]
}
```

### `catalogs/grid-health.json` — new `honeydrunk-identity` block

Insert after the `honeydrunk-audit` block. Mirror the seed-state shape.

```json
{
  "id": "honeydrunk-identity",
  "name": "HoneyDrunk.Identity",
  "sector": "Core",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": [
    "Repo not yet created (scaffold packet 04 of adr-0060-identity-standup blocked on packet 03 — create-repo)",
    "Scaffold packet 04 not yet executed"
  ],
  "notes": "ADR-0060 standup ADR Proposed 2026-05-23. Catalog surface registered (6 interfaces + 6 records + 1 record for DeletionAck per D4). Awaiting scaffold: HoneyDrunk.Identity.Abstractions, HoneyDrunk.Identity runtime, Data-backed user-record and claim-map stores, Standards wiring, CI with contract-shape canary scoped to the full Abstractions public surface. Entra adapter and OAuth callback wiring deferred to Phase 2 when the first consumer-facing app (Hearth) pulls on Identity."
}
```

### `catalogs/modules.json` — append new entries

Append two new entries at the end of the modules array, before the closing `]`. Match the schema used by `audit-abstractions` / `audit-data`:

```json
{
  "id": "identity-abstractions",
  "nodeId": "honeydrunk-identity",
  "name": "HoneyDrunk.Identity.Abstractions",
  "type": "abstractions",
  "version": "0.0.0",
  "description": "Near-zero-HoneyDrunk-dependency contracts for the Grid-wide user record, external-IdP seam, internal-token issuance, and account-deletion fan-out — IUserDirectory, IUserProfileStore, IInternalTokenIssuer, IExternalIdpClaimMapper, IIdentityDeletionFanout, IIdentityHealth and the supporting records (UserId, PrincipalId, ExternalSubject, UserProfile, InternalToken, DeletionIntent, DeletionAck)"
},
{
  "id": "identity-runtime",
  "nodeId": "honeydrunk-identity",
  "name": "HoneyDrunk.Identity",
  "type": "runtime",
  "version": "0.0.0",
  "description": "Data-backed user record + IdentityMap + ExternalSubjectMap stores, IInternalTokenIssuer signed via ISecretStore, IIdentityDeletionFanout coordination over the configured event transport, IExternalIdpClaimMapper composition at host time (Entra/Clerk/etc.). IdP-vendor adapter ships in Phase 2 with the first user-facing app's feature packet."
}
```

### `constitution/sectors.md` — add Identity row to the Core sector table

In the **Core** sector table (currently ends at the `Audit` row), append a new row immediately after the Audit row:

```
| **Identity** | Seed | User record, external-IdP seam, internal-token issuance, account-deletion fan-out |
```

The Core sector table's other entries remain unchanged.

### `repos/HoneyDrunk.Identity/` — new context folder (5 files)

Create the folder and the five context files matching the template used by `repos/HoneyDrunk.Audit/` and `repos/HoneyDrunk.Operator/`. The directory will contain:

```
repos/HoneyDrunk.Identity/
├── overview.md
├── boundaries.md
├── invariants.md
├── active-work.md
└── integration-points.md
```

**`overview.md`** — purpose statement, key packages, key contracts, design notes. Mirror the structure of `repos/HoneyDrunk.Audit/overview.md`. Required content:

- **Sector / Version / Framework / Repo / Status** header block (Status: `Seed; scaffold packet 04 of adr-0060-identity-standup not yet executed`).
- **Purpose** paragraph summarizing what Identity owns (user record, external-IdP seam, internal-token issuance, account-deletion fan-out) and what it does not (JWT validation, credential storage, tenant lifecycle, authorization policy evaluation, per-tenant user preferences).
- **Key Packages** table — `HoneyDrunk.Identity.Abstractions` (contracts) and `HoneyDrunk.Identity` (runtime), each with type and one-line description.
- **Key Contracts** bulleted list — the six interfaces + the supporting records.
- **Design Notes** — the wrapping-seam architecture (D2), the user profile lives in Identity not the IdP (D5), internal-token issuance preserves Invariant 10 (D6), the IdentityMap is upstream of audit pseudonymization (D3).
- **Phase-1 honest limitation** section — Phase-1 ships the boundary and the in-memory test fixtures; the Entra adapter and OAuth callback HTTP surface land in Phase 2 with the first user-facing app's feature packet.

**`boundaries.md`** — owns / does not own table. Mirror the structure of `repos/HoneyDrunk.Audit/boundaries.md`. Required content:

- **What Identity Owns:** canonical Grid UserId and PrincipalId; user-profile store; external-IdP sub-claim mapping; internal-token issuer for service-to-service flows; account-deletion fan-out workflow; user-level GDPR Art. 17 path; the IdentityMap (PseudoUserToken ↔ UserId ↔ ExternalSubject ↔ PII).
- **What Identity Does NOT Own:** JWT validation (that is Auth — Invariant 10 holds); credential storage (passwords, passkeys, OAuth refresh tokens — those live in the external IdP); tenant lifecycle (that is ADR-0050 hosted in Communications); authorization policy evaluation (that is Auth); per-tenant user-scope preferences (Communications owns notification preferences; FeatureFlags owns tenant-scoped feature gates per ADR-0055); the audit substrate itself (that is Audit — Identity emits but does not own).

**`invariants.md`** — repo-local invariant cross-reference. Mirror the trailing-paragraph pattern used by `repos/HoneyDrunk.Audit/invariants.md`. Final paragraph (substitute the actual numbers from packet 02):

> `_Constitutional invariants {N1} (Identity user-record ownership), {N2} (internal-token issuance exclusivity), {N3} (downstream Abstractions-only coupling), and {N4} (Identity contract-shape canary) in \`constitution/invariants.md\` are the Grid-level rules this Node exists to enforce. They were landed by ADR-0060's stand-up initiative._`

Use the **placeholder names `{N1}` / `{N2}` / `{N3}` / `{N4}`** in this packet's authored file. Packet 02 of this initiative substitutes the assigned numbers (54/55/56/57 at the current high-water mark of 53) in lockstep when packet 02's PR lands. **Packets 01 and 02 cannot be filed in the same push** because packet 02 needs to overwrite a placeholder in this packet's output — pre-filing carve-out under invariant 24 applies to packet 02's amendment of the `invariants.md` file, and to the pre-push amendment of packet 04's source.

**`active-work.md`** — initial entry referencing the in-flight standup initiative. Mirror the template used by `repos/HoneyDrunk.Audit/active-work.md`. Single in-progress entry: "ADR-0060 standup — packet 04 (scaffold) blocked on packet 03 (create-repo)."

**`integration-points.md`** — Consumes / Exposes / Emits / Canary-Coverage tables. Mirror the structure of `repos/HoneyDrunk.Operator/integration-points.md` (the more elaborate template). Required tables:

- **Consumes** table: Kernel (IGridContext + lifecycle + telemetry), Vault (ISecretStore for signing key, IConfigProvider for IdP config), Auth (IAuthorizationPolicy reuse for IUserDirectory lifecycle gates), Audit (IAuditLog emission for UserCreated/UserVerified/UserLocked/UserUnlocked/UserErased/InternalTokenIssued events), Data (IRepository / IUnitOfWork for user record + IdentityMap + ExternalSubjectMap), Communications (verification email, account-change notifications, deletion-fan-out coordination per tenant).
- **Exposes** table: each of the six interfaces with the consumer set (consumer-facing app columns marked "Hearth, Lately, Curiosities" at Phase 2; service-internal columns marked appropriately).
- **Emits** table (one-way, no runtime dependency): `UserCreated` / `UserVerified` / `UserLocked` / `UserUnlocked` / `UserErased` / `InternalTokenIssued (sampled)` to Audit; operational telemetry to Pulse via Kernel's ITelemetryActivityFactory; `DeletionIntent` to downstream consumer Nodes (Communications-mediated for tenant-topology fan-out).
- **Canary Coverage Required** bullets: Identity.Canary → Kernel; Identity.Canary → Vault; Identity.Canary → Auth; Identity.Canary → Audit; Identity.Canary → Data; Identity.Canary → Communications; Identity.Canary → contract-shape (fails the build if any of the six interfaces or six records change shape without a version bump).
- **Dependency Order for Bring-Up** bullets: Identity is itself a prerequisite for Hearth, Lately, Curiosities, Notify.Cloud.

### `adrs/ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md` — additive amendment note

Append a new section near the bottom of ADR-0050 (after the existing Consequences / Alternatives sections, before any "Last Updated" footer if one exists). Format:

```markdown
## Amendment — 2026-05-23 (driven by ADR-0060 standup)

`HoneyDrunk.Auth.IdentityMap` is renamed to `HoneyDrunk.Identity.IdentityMap`. The table relocates from the `HoneyDrunk.Auth` Node to the new `HoneyDrunk.Identity` Node per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D3.

**What this amendment changes:**

- D6 step 4 ("Delete the row for that `pseudo_user_token` in `HoneyDrunk.Auth.IdentityMap`") reads as "Delete the row for that `pseudo_user_token` in `HoneyDrunk.Identity.IdentityMap`" once the Identity Node ships.
- The interim "Auth-side packet" placeholder for the user-level GDPR Art. 17 path resolves to "Identity-side packet" — specifically `IIdentityDeletionFanout` per ADR-0060 D8.
- Affected Nodes list in ADR-0050's Consequences section: `HoneyDrunk.Auth` no longer gains the `IdentityMap` table — `HoneyDrunk.Identity` does. Auth retains the rest of its existing surface unchanged.

**What this amendment does NOT change:**

- The architectural posture from D6 — audit substrate stores only pseudonymous tokens; the map is erasable; Invariant 47 (audit append-only) is preserved.
- The legal posture (Art. 4(5) pseudonymization carve-out).
- The pseudonymous-token shape (`pu_` + 32-char base32).
- Any tenant-level workflow (provisioning, suspension, offboarding, export).
- ADR-0050's Status (stays Proposed; this amendment is additive only).

Only the Node owning the IdentityMap relocates from Auth to Identity. See ADR-0060 D3 for the full reasoning.
```

### `repos/HoneyDrunk.Auth/overview.md` — additive amendment

In `repos/HoneyDrunk.Auth/overview.md`'s Purpose section (currently reads "JWT Bearer token validation and policy-based authorization with Vault-backed signing key management. Auth validates trust and enforces access — it is not an identity provider."), append a new sentence:

> `**Auth is validation-only.** The user record, external-IdP seam, internal-token issuance, and account-deletion fan-out are owned by [HoneyDrunk.Identity](../HoneyDrunk.Identity/overview.md) per ADR-0060.`

Do not modify the Purpose paragraph's existing text. The additive sentence is a pointer; the existing "it is not an identity provider" line was already correct and stays.

### `repos/HoneyDrunk.Auth/boundaries.md` — additive amendment

In `repos/HoneyDrunk.Auth/boundaries.md`'s "What Auth Does NOT Own" list, append a new bullet:

```markdown
- **The user record, external-IdP seam, internal-token issuance, account-deletion fan-out** — those are owned by [HoneyDrunk.Identity](../HoneyDrunk.Identity/overview.md) per ADR-0060. Auth still validates JWT Bearer tokens (including the internal tokens Identity issues) through its existing JWKS-based path; no new validation primitive lands in Auth.
```

Do not modify any of the existing bullets in the "What Auth Does NOT Own" section. The existing line "User management — No user CRUD, registration, or profiles" stays; the new line clarifies who does own that surface.

### `initiatives/active-initiatives.md` — new entry

Append a new entry under `## In Progress`:

```markdown
### ADR-0060 HoneyDrunk.Identity Standup
**Status:** In Progress
**Scope:** Architecture, HoneyDrunk.Identity (new repo)
**Initiative:** `adr-0060-identity-standup`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Stand up `HoneyDrunk.Identity` as the Core sector's owner of the user record, the external-IdP seam (leading candidate Microsoft Entra External ID), internal-token issuance for service-to-service flows, and the user-level GDPR Art. 17 deletion fan-out. Catalog registration (6 interfaces + 7 records per D4 — including DeletionAck), four new invariants for D1 / D6 / D9 / D7 (default numbers 54-57), `repos/HoneyDrunk.Identity/` context folder, ADR-0050 amendment (IdentityMap relocates from Auth to Identity), Auth-context amendments (validation-only clarification), public repo creation (human-only), and the scaffold packet. Unblocks Hearth (PDR-0005), Lately (PDR-0003), Curiosities (PDR-0008), and Notify.Cloud signup flows.

**Tracking:**
- [ ] Architecture#NN: Catalog registration + context folder + ADR-0050/Auth amendments (packet 01)
- [ ] Architecture#NN: Add four new invariants for D1 / D6 / D9 / D7 (packet 02)
- [ ] Architecture#NN: Create HoneyDrunk.Identity public repo, branch protection, labels, OIDC, clone locally (packet 03 — human-only)
- [ ] Identity#NN: Scaffold HoneyDrunk.Identity (packet 04)
```

### `initiatives/roadmap.md` — add Q2 2026 bullet

In the Q2 2026 section, append a bullet:

```markdown
- [ ] **ADR-0060 HoneyDrunk.Identity Standup — scoped** *(4 packets queued; scaffold blocked on repo-creation chore; Entra adapter deferred to first consumer-app pull)*
```

### `CHANGELOG.md` (Architecture repo)

Append to the current dated SemVer section (per memory `feedback_no_unreleased_commits` — no `## Unreleased` block; use the existing dated section or create a new one if this commit bumps the version):

> `Architecture: Register honeydrunk-identity Node in catalogs (nodes.json with Seed signal + Core sector; relationships.json with 6 upstream consumers and 4 consumer-app/Notify.Cloud planned consumers; contracts.json with 6 interfaces and 7 records per ADR-0060 D4; grid-health.json with the scaffold blocker; modules.json with HoneyDrunk.Identity.Abstractions and HoneyDrunk.Identity 0.0.0). Add Identity row to constitution/sectors.md Core sector table. New repos/HoneyDrunk.Identity/ context folder (overview, boundaries, invariants, active-work, integration-points) matching the Audit/Operator template. Additive amendment on ADR-0050 (IdentityMap relocates from HoneyDrunk.Auth.IdentityMap to HoneyDrunk.Identity.IdentityMap per ADR-0060 D3; D6 architectural posture unchanged). Additive amendments on repos/HoneyDrunk.Auth/overview.md and boundaries.md (validation-only clarification; user-record ownership pointer). Register adr-0060-identity-standup initiative and Q2 2026 roadmap bullet. ADR-0060 stays Proposed in this packet — Status flip is a separate post-merge step.`

## Affected Files

- `catalogs/nodes.json` (insert `honeydrunk-identity` block after `honeydrunk-audit`)
- `catalogs/relationships.json` (insert `honeydrunk-identity` block; update `honeydrunk-auth` / `honeydrunk-audit` / `honeydrunk-data` / `honeydrunk-communications` `consumed_by_planned` arrays)
- `catalogs/contracts.json` (insert `honeydrunk-identity` block)
- `catalogs/grid-health.json` (insert `honeydrunk-identity` block)
- `catalogs/modules.json` (append `identity-abstractions` + `identity-runtime` entries)
- `constitution/sectors.md` (append `Identity` row to the Core sector table)
- `repos/HoneyDrunk.Identity/overview.md` (new)
- `repos/HoneyDrunk.Identity/boundaries.md` (new)
- `repos/HoneyDrunk.Identity/invariants.md` (new — placeholders `{N1}` / `{N2}` / `{N3}` / `{N4}` for the four invariant numbers landing in packet 02)
- `repos/HoneyDrunk.Identity/active-work.md` (new)
- `repos/HoneyDrunk.Identity/integration-points.md` (new)
- `adrs/ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md` (append amendment section)
- `repos/HoneyDrunk.Auth/overview.md` (append one sentence to Purpose)
- `repos/HoneyDrunk.Auth/boundaries.md` (append one bullet to "What Auth Does NOT Own")
- `initiatives/active-initiatives.md` (new entry)
- `initiatives/roadmap.md` (new Q2 2026 bullet)
- `CHANGELOG.md` (entry under current dated SemVer section)

## NuGet Dependencies

None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check

- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules.
- [x] No code changes; catalogs + docs + ADR amendments only.
- [x] D4 contract surface authored verbatim per ADR-0060 (six interfaces, six records, plus the `DeletionAck` record named in D4's `IIdentityDeletionFanout` description for the consumer ack shape).
- [x] Records drop `I` prefix per the Grid-wide naming rule (`UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck`); interfaces keep it (`IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, `IIdentityHealth`).
- [x] ADR-0050 amendment is additive only — no edits to D6's architectural posture or to ADR-0050's `Status`.
- [x] Auth context amendments are additive only — no edits remove existing text.
- [x] ADR-0060 stays at `Status: Proposed`. Status flip is handled by the scope agent after the entire initiative merges.

## Acceptance Criteria

- [ ] `catalogs/nodes.json` contains a new `honeydrunk-identity` entry with Seed signal, Core sector, `cluster: "security"`, and the full `long_description` block.
- [ ] `catalogs/relationships.json` contains a new `honeydrunk-identity` block with `consumes`, `consumed_by_planned`, `exposes.contracts` (13 entries), `exposes.packages` (2 entries), and `consumes_detail` (6 upstream blocks).
- [ ] `catalogs/relationships.json` `honeydrunk-auth.consumed_by_planned` includes `honeydrunk-identity`.
- [ ] `catalogs/relationships.json` `honeydrunk-audit.consumed_by_planned` includes `honeydrunk-identity`.
- [ ] `catalogs/relationships.json` `honeydrunk-data.consumed_by_planned` includes `honeydrunk-identity`.
- [ ] `catalogs/relationships.json` `honeydrunk-communications.consumed_by_planned` includes `honeydrunk-identity`.
- [ ] `catalogs/contracts.json` contains a new `honeydrunk-identity` block with `IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, `IIdentityHealth` (kind: interface) and `UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck` (kind: type).
- [ ] `catalogs/grid-health.json` contains a new `honeydrunk-identity` entry with `signal: "Seed"`, `version: "0.0.0"`, `canary_status: "none"`, and active-blockers listing the create-repo and scaffold packets.
- [ ] `catalogs/modules.json` contains `identity-abstractions` and `identity-runtime` entries at version `0.0.0`.
- [ ] `constitution/sectors.md` Core sector table contains the `Identity | Seed | ...` row after the `Audit` row.
- [ ] `repos/HoneyDrunk.Identity/` folder exists and contains five files: `overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`. Each matches the template used by `repos/HoneyDrunk.Audit/` or `repos/HoneyDrunk.Operator/`.
- [ ] `repos/HoneyDrunk.Identity/invariants.md` uses `{N1}` / `{N2}` / `{N3}` / `{N4}` placeholders for the four invariant numbers landing in packet 02. (Packet 02 of this initiative substitutes the assigned numbers — pre-filing carve-out applies because packet 02's PR is what overwrites them, not this packet.)
- [ ] `adrs/ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md` has a new `## Amendment — 2026-05-23 (driven by ADR-0060 standup)` section. ADR-0050's `Status:` line is **not** modified.
- [ ] `repos/HoneyDrunk.Auth/overview.md` Purpose section has a new trailing sentence pointing to HoneyDrunk.Identity. No existing text in `overview.md` is removed or rewritten.
- [ ] `repos/HoneyDrunk.Auth/boundaries.md` "What Auth Does NOT Own" list has a new trailing bullet. No existing bullets are removed or rewritten.
- [ ] `initiatives/active-initiatives.md` has a new "ADR-0060 HoneyDrunk.Identity Standup" entry under `## In Progress`.
- [ ] `initiatives/roadmap.md` has a new Q2 2026 bullet for the standup initiative.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section describing all the registrations + amendments (not under `## Unreleased`).
- [ ] `adrs/ADR-0060-stand-up-honeydrunk-identity-node.md` is **not** modified by this packet. ADR-0060 stays at `Status: Proposed`.

## Human Prerequisites

None. The 2026-05-23 ADR-0060 text is already on disk; this packet reflects it in the catalogs and the cross-references.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Reinforces why `HoneyDrunk.Identity.Abstractions` is what downstream Nodes will compile against. Note: per ADR-0060 D4 the Abstractions package may take the same Kernel.Abstractions dependency Audit took (for `TenantId`), as a permitted exception. Full enforcement comes from packet 02's downstream-coupling invariant.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Identity consumes Kernel, Vault, Auth, Audit, Data, Communications; none of those consume Identity in return. The DAG stays acyclic.

> **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Survives ADR-0060 intact. Auth still only validates; Identity is the new Node that issues internal tokens. The Auth context amendment in this packet makes the boundary visually unambiguous.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Identity is a new Node ⇒ new repo. Packet 03 of this initiative creates that repo.

> **Invariant 47:** Durable, attributable security, action, and data-change events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry. — Identity is a first-class emitter alongside Auth; its new event types (`UserCreated`, `UserVerified`, `UserLocked`, `UserUnlocked`, `UserErased`, `InternalTokenIssued` sampled) flow through `IAuditLog`. This is recorded in the `consumes_detail.honeydrunk-audit` edge in `catalogs/relationships.json` and in `repos/HoneyDrunk.Identity/integration-points.md`.

## Referenced ADR Decisions

**ADR-0060 D1 (Identity Node ownership):** HoneyDrunk.Identity is the Core sector's single Node owning the user record, the external-IdP seam, internal-token issuance, and account-deletion fan-out. Adds `honeydrunk-identity` to the Core sector. Boundary against Auth (validation vs. issuance), against Communications (orchestration is downstream of identity decisions), and against the tenant lifecycle workflow (tenant lifecycle composes Identity, not the other way around) is pinned in this ADR and not re-opened in feature work.

**ADR-0060 D2 (Wrap external IdP, leading candidate Entra External ID):** Identity is a thin seam over an external IdP. The credential store lives in the IdP; Identity stores zero credentials. The vendor confirmation lands in the first feature packet — this catalog-registration packet is IdP-agnostic.

**ADR-0060 D3 (UserId / PrincipalId / ExternalSubject shape):** `UserId` is a 26-char ULID prefixed `usr_`; `PrincipalId` is a discriminated wrapper over UserPrincipal / ServicePrincipal / AgentPrincipal per ADR-0051; `ExternalSubject` holds the external IdP `sub` claim plus the IdP issuer identifier. The `IdentityMap` relocates from `HoneyDrunk.Auth.IdentityMap` to `HoneyDrunk.Identity.IdentityMap` per ADR-0050's anticipated future — additive amendment to ADR-0050 in this packet.

**ADR-0060 D4 (Exposed contracts):** Six interfaces (`IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, `IIdentityHealth`) and seven records (`UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck`). The full surface above is frozen at stand-up and protected by the contract-shape canary (D7 in ADR-0060's text; landed at packet 04 in this initiative).

**ADR-0060 D8 (Account-deletion fan-out):** `IIdentityDeletionFanout.Erase(UserId, correlationId)` emits `DeletionIntent` to Communications, tenant data partitions (via Communications' tenant-scoped workflow), Memory, and Knowledge. Each consumer responds with `DeletionAck`. Identity emits `UserErased` to Audit. Idempotent end-to-end per ADR-0042.

**ADR-0060 D13 (Relationship to existing ADRs):** Invariant 10 preserved; ADR-0005/0006 (per-Node Vault, tier-1 rotation), ADR-0015 (Container App deployable), ADR-0019 (Communications-mediated tenant-topology fan-out), ADR-0026 (TenantId strong type), ADR-0030 (Audit first-class emitter), ADR-0031 (Audit consumer-side coupling), ADR-0042 (idempotency contract), ADR-0049 (IdentityMap is Restricted/Sensitive PII), ADR-0050 (additive amendment), ADR-0051 (UserPrincipal is a PrincipalId variant), ADR-0057 (OAuth 2.1 with PKCE via external IdP) — all interlock with the catalog rows authored in this packet.

## Dependencies

None. Packet 01 is the foundation of the initiative.

## Labels

`chore`, `tier-2`, `architecture`, `core`, `identity`, `adr-0060`

## Agent Handoff

**Objective:** Bring `HoneyDrunk.Architecture` catalogs, the Core-sector table, the `repos/HoneyDrunk.Identity/` context folder, ADR-0050's amendment section, the Auth context files, the active-initiatives tracker, and the roadmap into alignment with ADR-0060's stand-up decisions.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Reflect ADR-0060 acceptance work in the canonical Architecture metadata so downstream consumers (Hearth, Lately, Curiosities, Notify.Cloud signup flows) can scope against an Identity boundary that exists in the catalogs, and so the ADR-0050 D6 "Auth-side packet" placeholder resolves to "Identity-side packet" in the metadata.
- Feature: ADR-0060 standup initiative, Wave 1, Packet 01.
- ADRs: ADR-0060 (sole standup); ADR-0050 (additive amendment); ADR-0051 (PrincipalId model); ADR-0057 (OAuth flow); ADR-0026 (TenantId strong type); ADR-0030 / ADR-0031 (Audit boundary).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Reinforces why `HoneyDrunk.Identity.Abstractions` is what downstream Nodes will compile against. Per ADR-0060 D4 the Abstractions package may take a single dependency on `HoneyDrunk.Kernel.Abstractions` (for `TenantId`), the same permitted exception Audit took. This packet does not author the .csproj; it records the package name in the catalogs.
- **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Identity consumes Kernel, Vault, Auth, Audit, Data, Communications; none of those consume Identity in return. The DAG stays acyclic.
- **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Survives ADR-0060 intact. Auth still only validates; Identity is the new Node that issues internal tokens. The Auth context amendment in this packet makes the boundary visually unambiguous.
- **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Identity is a new Node ⇒ new repo. Packet 03 creates it.
- **Records drop `I` prefix; interfaces keep it.** Per the Grid-wide naming rule. `UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck` are records. The six other surfaces are interfaces.
- **ADR-0050 amendment is additive only.** Do not modify ADR-0050's D6 architectural posture, its Status, or any of its existing decisions. Append the amendment section after Consequences/Alternatives.
- **Auth context amendments are additive only.** Do not remove or rewrite any existing text in `repos/HoneyDrunk.Auth/overview.md` or `repos/HoneyDrunk.Auth/boundaries.md`. The new sentence in `overview.md` and the new bullet in `boundaries.md` extend the existing content.
- **No ADR Status flip in this packet.** ADR-0060 stays Proposed throughout the initiative. Status flip is handled by the scope agent after every packet merges.
- **`{N1}` / `{N2}` / `{N3}` / `{N4}` placeholders in `repos/HoneyDrunk.Identity/invariants.md`** must be left in place. Packet 02 of this initiative substitutes the assigned numbers (54/55/56/57 at the current high-water mark, or whichever next four slots are free at packet 02's edit time).

**Key Files:**
- `catalogs/nodes.json` — insert `honeydrunk-identity` block after `honeydrunk-audit`
- `catalogs/relationships.json` — insert `honeydrunk-identity` block; update four upstream Nodes' `consumed_by_planned`
- `catalogs/contracts.json` — insert `honeydrunk-identity` block
- `catalogs/grid-health.json` — insert `honeydrunk-identity` block
- `catalogs/modules.json` — append `identity-abstractions` + `identity-runtime`
- `constitution/sectors.md` — append `Identity` row to Core sector table
- `repos/HoneyDrunk.Identity/{overview,boundaries,invariants,active-work,integration-points}.md` — new files, mirror Audit/Operator templates
- `adrs/ADR-0050-...` — append `## Amendment — 2026-05-23 (driven by ADR-0060 standup)` section
- `repos/HoneyDrunk.Auth/overview.md` — append one sentence
- `repos/HoneyDrunk.Auth/boundaries.md` — append one bullet
- `initiatives/active-initiatives.md` — new entry
- `initiatives/roadmap.md` — new Q2 bullet
- `CHANGELOG.md` — append under current dated SemVer section

**Contracts:** This packet does not author any `.cs` files. Catalog + docs + ADR amendments only. Authoring `.cs` files happens in packet 04 (the scaffold inside `HoneyDrunk.Identity`).
