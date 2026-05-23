# ADR-0060: Stand Up the HoneyDrunk.Identity Node — User Record, Credential Seam, and Erasure Fan-Out

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale). Per the project convention, the Node is **not** added to `catalogs/nodes.json` until acceptance:

- [ ] Create `HoneyDrunk.Identity` GitHub repo as **public** (Grid default; identity-layer code, not credential storage — see D2)
- [ ] Add `honeydrunk-identity` Node entry to `catalogs/nodes.json` with Core sector, `signal: "seed"`, `cluster: "security"`
- [ ] Add `honeydrunk-identity` entries to `catalogs/relationships.json`: consumes `honeydrunk-kernel`, `honeydrunk-vault`, `honeydrunk-auth` (for `IAuthorizationPolicy` reuse), `honeydrunk-audit` (`IAuditLog`), `honeydrunk-data` (`IRepository`/`IUnitOfWork` for the user record + IdP-claim-map tables), `honeydrunk-communications` (for verification email / account-change notifications via Communications intents); `consumed_by_planned` includes `hearth`, `lately`, and `honeydrunk-notify-cloud`
- [ ] Add `IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, and the supporting records (`UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck`) to `catalogs/contracts.json` under `honeydrunk-identity`
- [ ] Add the `honeydrunk-identity` row to `catalogs/grid-health.json` reflecting the stood-up contract surface and the contract-shape canary expectation
- [ ] Add `honeydrunk-identity` entries to `catalogs/modules.json` for `HoneyDrunk.Identity.Abstractions` and `HoneyDrunk.Identity` (runtime)
- [ ] Update `constitution/sectors.md` Core-sector table to add the **Identity** row (`Signal: Seed`, `Responsibility: User record, external-IdP seam, internal-token issuance, account-deletion fan-out`)
- [ ] Author the additive amendment note on `adrs/ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md` recording that the `UserId` ↔ `PseudoUserToken` map ownership relocates from `HoneyDrunk.Auth.IdentityMap` to `HoneyDrunk.Identity.IdentityMap` (additive only; D6 architectural posture unchanged — only the Node that owns the table moves)
- [ ] Author the additive amendment note on `repos/HoneyDrunk.Auth/` context files clarifying Auth is validation-only and that Identity owns the user record
- [ ] Wire the contract-shape canary into Actions for the frozen surfaces (`IUserDirectory`, `IUserProfileStore`, `IInternalTokenIssuer`, `IExternalIdpClaimMapper`, `IIdentityDeletionFanout`, `UserId`, `PrincipalId`, `ExternalSubject`, `UserProfile`, `InternalToken`, `DeletionIntent`, `DeletionAck`)
- [ ] Create `repos/HoneyDrunk.Identity/` context folder in the Architecture repo (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`) — matching the template used by `repos/HoneyDrunk.Audit/` and `repos/HoneyDrunk.Operator/`
- [ ] File the HoneyDrunk.Identity scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline via HoneyDrunk.Actions shared workflows, Data-backed user-record and claim-map stores, the Node's own managed identity, in-memory test fixtures, IdP-provider-slot Abstractions). Scaffold does **not** include the Entra adapter — that lands as the first feature packet when Hearth or Lately pulls on it.
- [ ] Scope agent flips Status → Accepted after the first packet declaring this ADR in `accepts:` merges

## Context

**Auth is not Identity.** This is the central confusion this ADR exists to resolve.

[`HoneyDrunk.Auth`](../repos/HoneyDrunk.Auth/overview.md) is shipped, accepted, and works. Per its `nodes.json` entry and per **Invariant 10** it is *"the per-request gatekeeper — JWT bearer validation with Vault-backed signing keys, deterministic policy evaluation."* Invariant 10 states explicitly:

> Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.**

That invariant was written when only the Grid's internal service-to-service traffic existed and Auth was the only piece of the identity stack the studio needed. The forcing functions have changed.

What Auth does **not** own, what no Node in the Grid owns today, and what the first user-facing app will force:

- **The user record.** Account lifecycle (created, verified, active, locked, deleted), profile fields (display name, avatar, locale, preferences that are user-level rather than tenant-level), `created_at` / `last_login_at` / `email_verified_at` — none of this has a home.
- **Credential storage** (passwords, passkeys, OAuth refresh tokens). Auth has no users; it has signing keys.
- **Token issuance** (signup, login, refresh). Auth validates tokens it did not issue. Today there is no Node that issues them; the JWTs Auth validates in dev are minted by `dotnet user-jwts` and in service-to-service flows by a one-off issuer in `HoneyDrunk.Web.Rest.Tests.Integration`. That is not a production identity story.
- **User-deletion fan-out across Nodes.** [ADR-0050 D6](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) commits the pseudonymization-based GDPR Art. 17 resolution at the **tenant** level. The corresponding user-level path is named but its home is undefined — D6 says "delete the row for that `pseudo_user_token` in `HoneyDrunk.Auth.IdentityMap`" without committing the Node that owns that workflow or the fan-out to downstream Nodes holding user-scoped data outside the identity map.
- **The `/users/me` surface** every consumer app will ask for on day one.

The forcing functions converging now:

- **[PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md) (Hearth)** is the scout's pick for first-build and is a consumer app that requires signup/login.
- **[PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md) (Lately)** and **[PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md) (Curiosities)** are queued behind it, both consumer apps with the same need.
- **[ADR-0050 D6](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) (Proposed)** introduces `HoneyDrunk.Auth.IdentityMap` as the interim home for the `PseudoUserToken` ↔ `UserId` ↔ PII map. That ADR explicitly used **Auth** as the interim home because no Identity Node existed. This ADR is the canonical home that ADR-0050 anticipated.
- **[ADR-0051](./ADR-0051-ai-agent-authorization-and-tool-scoping-model.md) (Proposed)** introduces a three-principal model: `UserPrincipal` / `ServicePrincipal` / `AgentPrincipal`. `UserPrincipal` needs a `UserId` and a record-backed source-of-truth.
- **[ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) (Proposed)** commits OAuth 2.1 with PKCE as the user-facing auth flow. There is no Node today that owns the OAuth authorization endpoint, the token endpoint, or the user-info endpoint.

The collision between Invariant 10 ("Auth is validation, not issuance") and the obvious next architectural step ("we need a thing that issues tokens for our first user-facing app") is resolved cleanly by **adding a new Node** rather than by widening Auth. The invariant survives intact: Auth still only validates. **Identity** issues internal tokens; Identity wraps an external IdP that issues external tokens; Auth keeps the gatekeeper boundary it has always had.

This ADR is the **stand-up decision** for the Identity Node — what it owns, what it does not own, which contracts it exposes, how downstream Nodes couple to it, and what scaffolds in the first PR. It is not a scaffolding packet. It does not commit the specific IdP vendor (Entra External ID is the leading candidate per D2; the choice is made *at the Node*, not in this ADR) and it does not bundle the Entra adapter into the standup. Per the project convention, the **boundary is named now so the first user-facing app's signup work has somewhere to land**; the **Node itself doesn't get built** until that first user-facing app pulls on it. From [`constitution/charter.md`](../constitution/charter.md) §"What this charter licenses":

> Time invested in ADRs, invariants, substrate hygiene, and architectural correctness is not "premature optimization" or "procrastinating on shipping." It is the work.

## Decision

### D1. HoneyDrunk.Identity is the Core sector's owner of the user record, the external-IdP seam, internal-token issuance, and account-deletion fan-out

`HoneyDrunk.Identity` is the single Node in the Core sector that owns the **user record** and the **seam** between the Grid's internal identity model and whichever external IdP issues credentials. It owns:

- The canonical Grid `UserId` and `PrincipalId` value types (the records ADR-0051 names but does not commit a home for).
- The user-profile store (display name, avatar, locale, account-level preferences) that does not belong inside an external IdP because the IdP is replaceable and the profile is not.
- The mapping between the external IdP's `sub` claim and the Grid's `UserId`.
- The internal-token issuer used for service-to-service flows where a `UserPrincipal` context is required and the call did not originate from the user-facing edge (background jobs operating "on behalf of" a user, agent calls executing under `UserPrincipal` per ADR-0051).
- The account-deletion fan-out — the workflow that, when a user requests deletion, tells every Node holding user-scoped data to delete or pseudonymize.
- The user-level GDPR Art. 17 path that ADR-0050 D6 names but assigns to "Auth-side packet."

It does **not** own:

- **JWT validation.** That is Auth. Invariant 10 holds.
- **Credential storage** (passwords, passkeys, OAuth refresh tokens). Per D2, those live in the chosen external IdP. Identity stores zero passwords.
- **Tenant lifecycle.** That is the workflow defined in ADR-0050, hosted in Communications. Identity is **upstream** of tenant lifecycle — a user can exist before being attached to a tenant (the prospect signup flow per ADR-0050 D2 creates a user before the tenant exists).
- **Authorization policy evaluation.** That remains in Auth. Identity is the source of truth for *who the principal is*; Auth decides *what that principal may do*.
- **Per-tenant user-scope preferences** (notification preferences within a tenant, in-app feature toggles). Those live in their respective Nodes (Communications for notification preferences, FeatureFlags for tenant-scoped feature gates per ADR-0055). Identity owns account-level preferences only.

Boundary against Auth (validation vs. issuance), against Communications (orchestration is downstream of identity decisions, not where identity decisions are made), and against the tenant lifecycle workflow (tenant lifecycle composes Identity, not the other way around) is pinned here and is not re-opened in feature work.

### D2. Wrap an external IdP rather than build a credential store — leading candidate is Microsoft Entra External ID

The central architectural decision is **whether HoneyDrunk owns the credential store** or **whether HoneyDrunk wraps an external IdP** that owns it. The options were evaluated honestly; the recommendation is **wrap an external IdP**, with **Microsoft Entra External ID** as the leading candidate to be confirmed at the first feature packet. This ADR commits to the *posture* (wrap an IdP); it does **not** commit to Entra specifically because the choice can be re-litigated when the first user-facing app's packet lands and the customer-experience tradeoffs are concrete.

**The posture decision (this ADR):** Identity is a **thin seam over an external IdP**. The credential store — password hashes, passkey public keys, OAuth refresh tokens, MFA enrollments, account-lockout state — lives in the IdP. Identity stores **zero credentials**. The Node maps external `sub` claims to internal `UserId`, owns the user profile and account-level preferences, issues short-lived internal tokens for service-to-service flows, and runs the deletion-fan-out workflow.

**Why wrap an IdP rather than own the credential store:**

| Factor | Wrap an IdP | Self-host credential store |
|---|---|---|
| **Solo-dev cost** | Hours of integration work per provider | Months of engineering to do correctly (password hashing, breach detection, MFA, social login, account recovery, suspicious-login throttling, brute-force protection, geo-IP signal, device fingerprinting) and ongoing maintenance |
| **Breach liability** | The IdP is responsible for credential breach detection and disclosure (their reputation, their dedicated security team) | We are responsible for credential breach — the worst single security event a studio can have |
| **Compliance posture** | The IdP's SOC 2 / ISO 27001 covers the credential layer | We need our own auditable credential-handling discipline |
| **MFA, passkeys, social login** | Built-in, vendor-maintained, kept current as standards evolve (FIDO2, WebAuthn) | Each one is its own implementation project |
| **Account recovery** | Built-in flows, edge cases handled (forgotten password, lost MFA device, account takeover dispute) | Each edge case is our problem |
| **Vendor risk** | Real but bounded — the IdP can change pricing, get acquired, or sunset their offering | Zero direct vendor risk on credentials, but full direct cost of the consequences |
| **Migration cost (away)** | Re-keying users to a new IdP is non-trivial but bounded (the password store is what's hard to move, and a wrapping seam means the user records are ours) | N/A |

The single decisive factor for a solo-dev studio is **breach liability**. The credential store is the single most security-sensitive component a studio can run. Outsourcing it to a vendor with a dedicated security team is the right call for a one-person operation that does not have a security on-call rotation and where charter §"What this charter forbids" item 2 ("architecture-as-procrastination") makes spending six months building a credential store before shipping the first user-facing app obviously wrong.

The wrapping-seam architecture preserves the option to switch IdPs later. Because Identity owns the user record (not the IdP), and the IdP's `sub` claim is just a *foreign key* into the user record, switching IdPs is a re-keying operation, not a data-migration disaster.

**Why Entra External ID is the leading candidate:**

- **Free up to ~50k MAU.** This covers every reasonable v1 customer trajectory for Hearth, Lately, and Curiosities combined. Notify.Cloud's tenant *operators* are likely to be paying users; their *end users* would only count against this if a tenant operator delegates user-management to us, which is not the v1 model (per ADR-0050 each tenant currently brings its own users in their own model).
- **Integrates with the existing Azure footprint.** Per the project's Azure-first architectural decisions (per-service isolation, naming prefix `hd`), Entra is the natural fit. App Configuration, Key Vault, and Container Apps already speak Entra.
- **OAuth 2.1 / OIDC standard endpoints** for the OAuth-with-PKCE flow ADR-0057 commits. No bespoke flows.
- **Passkey support is built-in** (the WebAuthn / FIDO2 surface).
- **Custom-domain support** for the auth endpoints (so the user-facing URL can be `auth.honeydrunkstudios.com`, not a vendor subdomain) — important for brand consistency on the Hearth / Lately / Curiosities surfaces.
- **B2C-style user-flow customization** for the signup, sign-in, and password-reset journeys without bespoke UI for each.

**Alternatives honestly evaluated (rejected at the IdP-vendor layer, but the wrapping-seam decision means swapping is bounded if a v2 reconsideration happens):**

- **Clerk.** Best developer experience in 2026 for consumer-app signup flows. Strong on passkey and social-login UX. Pricing is per-MAU above the free tier (~10k MAU free, then per-user). Rejected as leading candidate because the Azure-native integration story is weaker (no managed-identity flows back to Azure resources; everything goes through their tokens) and the pricing curve at scale is steep relative to Entra's. Strong contender if Entra's developer experience proves too clunky in practice.
- **Auth0.** Mature, enterprise-grade. Pricing is the prohibitive factor — the B2C / consumer tier ($240+/month for production use above the free tier) is a recurring cost that does not match the charter's "lean substrate" posture for a not-yet-revenue product layer. Rejected on cost.
- **Supabase Auth.** Open-source-friendly, Postgres-native (which matches the Grid's storage posture). The credential store is owned by the developer (it's just a table in the developer's Postgres) which **negates the breach-liability argument** in D2's analysis — the whole reason to wrap an IdP. Rejected because if the user is going to host the credential store anyway, building it on ASP.NET Core Identity + OpenIddict (next bullet) is the same posture with one fewer vendor in the stack.
- **ASP.NET Core Identity + OpenIddict, self-hosted.** The "we own everything" path. Strong technical fit with the .NET-first Grid. Rejected for the breach-liability reason in D2's analysis: a one-person studio should not be the credential-breach response team for its own users. Held as the eventual destination only if the IdP economics become prohibitive at scale, with the wrapping-seam architecture ensuring the transition is bounded.
- **Do nothing yet; let the first app roll its own and extract later.** Considered. Rejected as architecturally regressive: the first app would necessarily embed a credential store, a token-issuance flow, and a user record inside the app's process, and **extracting that later is the classic distributed-monolith breakup**. The charter explicitly licenses spending on substrate when the substrate is what makes future apps cheap; this is precisely that case. Adding a Node now costs a stand-up ADR (this document) and a future scaffold packet; deferring costs the cumulative pain of every app re-inventing the same boundary.

The vendor confirmation lands in the **first feature packet** (when Hearth or Lately pulls on Identity). If at that point the Entra developer experience or pricing has degraded, the alternatives above are re-evaluated. The Node's contract surface is IdP-agnostic by design (D4).

### D3. The `UserId` and `PrincipalId` shape

Per the grid-wide naming rule (2026-04-19 memory: records drop `I`, interfaces keep it), the value types are:

- `UserId` — record struct. **26-character ULID, prefixed `usr_`** (e.g., `usr_01HKMS3ZQ4N7P8YR2J5W9XCBVF`). The prefix discipline matches ADR-0026's `tnt_` for `TenantId` and ADR-0050 D6's `pu_` / `pt_` for pseudonymous tokens. ULIDs are sortable, URL-safe, and 128-bit collision-resistant.
- `PrincipalId` — record. A discriminated value that wraps either a `UserId`, a `ServicePrincipal` identifier, or an `AgentPrincipal` identifier, per ADR-0051's three-principal model. The wrapper exists so authorization policies (per ADR-0051) and the audit substrate (per ADR-0030) can speak in `PrincipalId` regardless of the principal kind.
- `ExternalSubject` — record. Holds the external IdP's `sub` claim plus the IdP issuer identifier (so a `sub` of `abc123` from Entra and a `sub` of `abc123` from a future Clerk migration are distinguishable). Stored in the `ExternalSubjectMap` table alongside the `UserId` it resolves to.

**Relationship to ADR-0050's `PseudoUserToken`:**

ADR-0050 D6 introduced `PseudoUserToken` (`pu_` + 32-char base32) as the **opaque, non-derivable token** the audit substrate carries. The pseudonymization model in D6 says: audit records hold `pu_*` tokens; the PII↔token map lives in an erasable store; deleting the map row makes the audit tokens permanently unresolvable (GDPR Art. 17 compliance via Art. 4(5) pseudonymization).

This ADR adds: **the `PseudoUserToken` ↔ `UserId` map is owned by `HoneyDrunk.Identity`**, not by `HoneyDrunk.Auth`. ADR-0050 D6 used "Auth.IdentityMap" as the interim home explicitly because no Identity Node existed; ADR-0050 D12 said "**ADR-0049 (Tenant Data Isolation, Proposed) — interlocks. Provisioning instantiates the partition (D3 step 5); offboarding deletes it (D5); identity-map deletion is coordinated (D6).**" — the work coordinator was unnamed. This ADR names it.

The architectural posture from ADR-0050 D6 is **unchanged**: audit substrate stores only pseudonymous tokens; the map is erasable; Invariant 47 (audit append-only) is preserved. Only the Node owning the map relocates from Auth to Identity. This is the additive amendment in the follow-up-work checklist.

Concretely:

- `UserId` is the **Grid-internal identifier**. It appears in the `IdentityMap`, in the user record, and in service-to-service contexts where the principal needs to be resolvable for operational use.
- `PseudoUserToken` is the **audit-substrate identifier**. It appears in audit records and nowhere else.
- The map row connecting `UserId ↔ PseudoUserToken ↔ ExternalSubject ↔ PII` lives in the Identity Node's `IdentityMap` table.
- Erasure deletes the map row. Post-erasure, the `UserId` is also unresolvable to PII (the design property is preserved); the audit `PseudoUserToken` becomes structurally orphaned exactly as ADR-0050 D6 commits.

### D4. Exposed contracts

Six interfaces and six records form the Identity Node's public boundary. These are the surfaces downstream Nodes are allowed to compile against.

| Contract | Kind | Purpose |
|---|---|---|
| `IUserDirectory` | interface | Resolve a `UserId` to a user record (or return "not found" / "deleted"); look up by `ExternalSubject` from the IdP's `sub` claim; lifecycle transitions (`MarkVerified`, `Lock`, `Unlock`, `Delete`). |
| `IUserProfileStore` | interface | Read/write user profile fields (display name, avatar URL, locale, account-level preferences). Separate from `IUserDirectory` because the directory's surface is identity-stable (the `UserId` and account state); the profile is mutable user-driven content. |
| `IInternalTokenIssuer` | interface | Issue short-lived (≤ 5 min) internal JWT bearer tokens for service-to-service flows under a `UserPrincipal` context. Tokens are signed with a key resolved through `ISecretStore` per Invariants 8 and 9. **Auth validates these tokens** per its existing surface — Invariant 10 holds. |
| `IExternalIdpClaimMapper` | interface | Map external IdP claims (from Entra, or whichever IdP) to internal `UserPrincipal` state. Provider-slot abstraction: an Entra implementation, a Clerk implementation, etc., implement this interface. The Identity Node's main runtime composes one implementation at host time per the ADR-0016 / ADR-0017 abstraction-first pattern. |
| `IIdentityDeletionFanout` | interface | Coordinate user-level GDPR Art. 17 deletion across Nodes holding user-scoped data. Emits `DeletionIntent` to every registered downstream consumer; collects `DeletionAck` from each; emits `UserErased` to Audit per ADR-0030 / ADR-0050 D6. Idempotent end-to-end per ADR-0042. |
| `IIdentityHealth` | interface | Operational health: identity-map reachability, IdP-claim-mapper reachability, deletion-fan-out queue depth. Standard Kernel `IHealthContributor` shape. |

Records (drop `I` per the grid-wide naming rule):

| Contract | Kind | Purpose |
|---|---|---|
| `UserId` | record struct | 26-char ULID prefixed `usr_`. See D3. |
| `PrincipalId` | record | Discriminated `UserPrincipal` / `ServicePrincipal` / `AgentPrincipal` wrapper. See D3 and ADR-0051. |
| `ExternalSubject` | record | External IdP `sub` claim + IdP issuer identifier. See D3. |
| `UserProfile` | record | Display name, avatar URL, locale, account-level preferences map. |
| `InternalToken` | record | The internal-issuance token shape `IInternalTokenIssuer` returns: token string, expiry, claim set. |
| `DeletionIntent` | record | Emitted by `IIdentityDeletionFanout` to each downstream Node: `UserId`, `PseudoUserToken`, `correlation_id`, `requested_at`. The downstream Node must respond with `DeletionAck` within the configured timeout. |

The full surface above is frozen at stand-up and protected by the contract-shape canary (D7). Shape drift requires a version bump.

### D5. Where the user profile lives

The user profile (display name, avatar URL, locale, account-level preferences) lives in **HoneyDrunk.Identity's `UserProfile` table**, not in the external IdP. Rationale:

- **The IdP is replaceable; the profile is not.** Migrating IdPs means re-keying the credential store. If the profile lived in the IdP, every IdP migration would also be a profile migration. Putting the profile in Identity makes IdP migration a bounded credential-only move.
- **The profile is queryable by other Nodes.** Communications wants the user's display name for personalization; the Hearth app wants the avatar URL on its town square; Curiosities wants the locale for content selection. None of these should hit the IdP. They hit `IUserProfileStore`.
- **The profile carries account-level preferences that don't belong in the IdP at all.** Locale, accessibility preferences, default tenant — these are Grid concerns, not credential concerns.

Per-tenant user-scope preferences (notification preferences within a tenant, in-app feature toggles, tenant-specific display name overrides) live in **their respective Nodes**: Communications owns notification preferences per ADR-0019 D4; FeatureFlags owns tenant-scoped feature gates per ADR-0055. Identity owns **account-level** preferences only — the ones that are user-global, not tenant-scoped.

### D6. Internal-token issuance — Identity issues, Auth validates

`IInternalTokenIssuer` issues short-lived (≤ 5 min) internal JWT bearer tokens, signed with a key resolved through `ISecretStore` per Invariants 8 and 9. The use cases:

- Background jobs operating "on behalf of" a user (e.g., a scheduled email-generation job running under the user's `UserPrincipal` context for audit attribution).
- Agent execution under `UserPrincipal` per ADR-0051 (an agent acting on behalf of a user needs a token to carry through the call chain).
- Service-to-service calls that originate from Grid-internal context but need a `UserPrincipal` claim set (e.g., a re-tried Communications send that must carry the original requesting user's identity through the retry).

**Auth validates these tokens** through its existing `IJwtBearerValidator` surface — the same code path that validates externally-issued tokens. The signing key is in Identity's Key Vault namespace (per ADR-0006); Auth fetches the JWKS document from a well-known endpoint Identity exposes. No new validation primitive lands in Auth. **Invariant 10 holds: Auth still only validates.**

This is the central reconciliation between Invariant 10 ("Auth is not an identity provider") and the obvious need for the Grid to be able to issue tokens for its own internal use:

- Identity is the identity provider. It issues internal tokens.
- Auth is the gatekeeper. It validates all tokens, internal or external.
- The invariant survives intact because **Auth still issues nothing**.

### D7. Contract-shape canary

A contract-shape canary is added to the Identity Node's CI per the precedent established by ADR-0016 D8, ADR-0019 D8, ADR-0030 D7, and ADR-0031 D8. It fails the build if the `HoneyDrunk.Identity.Abstractions` public surface changes shape without a corresponding version bump. The protected surface includes:

- The six interfaces in D4.
- The six records in D4.
- Any enum/value types backing those records.

The implementation may be the existing `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.Identity.Abstractions`; the obligation is the gate, not the specific workflow.

### D8. Account-deletion fan-out and the user-level GDPR Art. 17 path

The user-level GDPR Art. 17 path is named — but not implemented — by ADR-0050 D6 ("Auth-side packet"). This ADR commits the home (`HoneyDrunk.Identity`) and the mechanism (`IIdentityDeletionFanout`).

**Trigger.** A user invokes Art. 17 through the user-facing portal (the tenant's app surface — Hearth, Lately, Curiosities — exposes a "Delete my account" action that calls Identity's API), or operations triggers the deletion on the user's behalf via the Studios admin console.

**Fan-out mechanism.** `IIdentityDeletionFanout.Erase(UserId, correlationId)` emits a `DeletionIntent` to every registered downstream consumer. The consumer list is configured per environment (App Configuration value resolved via Vault's `IConfigProvider` per Invariant 45). At v1, the consumer list is:

- **HoneyDrunk.Communications** — delete preference entries and decision-log entries scoped to the user.
- **Tenant data partitions** (via the tenant's Data-backed runtime) — for every tenant the user is a member of, delete user-scoped rows. The fan-out reaches Data through Communications' tenant-scoped workflow (because Communications already coordinates per-tenant work per ADR-0019), not directly — Identity does not know the tenant topology, Communications does.
- **HoneyDrunk.Memory** (when stood up per ADR-0022) — delete user-scoped agent memories.
- **HoneyDrunk.Knowledge** (when stood up per ADR-0021) — delete user-attributable knowledge entries.

**Transport.** `DeletionIntent` is a domain event on Service Bus per ADR-0028 (cross-Node async command). Each consumer responds with a `DeletionAck` back to Identity via the same transport. The fan-out is **idempotent end-to-end per ADR-0042** — re-running the workflow with the same `UserId` and `correlation_id` produces the same deletions without double-execution.

**Audit.** Identity emits the `UserErased` event to Audit per ADR-0030 / ADR-0050 D6 step 3. The event carries the `PseudoUserToken` (now-orphaned), the `correlation_id`, the `gdpr_request_id`, and the list of acknowledging consumers. The audit substrate never sees the `UserId` or the user's PII — the pseudonymization invariant from ADR-0050 D6 holds because Identity is on the *PII side* of the boundary, not the audit-substrate side.

**Map-row deletion.** The final step deletes the `IdentityMap` row that maps `UserId ↔ PseudoUserToken ↔ ExternalSubject ↔ PII`. After this row is gone, the `PseudoUserToken` in the audit substrate is permanently orphaned, satisfying GDPR Art. 17 per the EDPB-blessed pseudonymization carve-out (Art. 4(5)) — exactly the legal posture ADR-0050 D6 commits.

**IdP-side deletion.** Identity also calls the external IdP's delete-user API to remove credentials. For Entra External ID, this is the Microsoft Graph `DELETE /users/{id}` endpoint. The IdP-side deletion is part of the fan-out workflow; failure to reach the IdP halts the workflow (the user record cannot be considered erased while the IdP still holds credentials).

**Coordination with tenant lifecycle (ADR-0050 D5).** Tenant-level closure (per ADR-0050 D5) and user-level erasure (per this ADR's D8) are **distinct workflows**. Tenant closure deletes the tenant data partition and the tenant identity-map rows; user erasure deletes the user's identity-map row and fans out per-user deletions across tenants. A user can erase their account while remaining tenants stay open; a tenant can close while its users remain (now no longer members of that tenant, but still existent in the Identity directory).

### D9. The Identity Node has its own managed identity

The Identity Node runs under its **own dedicated managed identity**, distinct from Auth's, Audit's, and Operator's. Per-Node identity isolation is the Grid's established posture (project memory: Azure per-service isolation, naming prefix `hd`). Key Vault namespace is `kv-hd-identity-{env}` per Invariant 17 and ADR-0005. The signing key for `IInternalTokenIssuer` lives in this Vault namespace; rotation follows ADR-0006's tier-1 SLA (≤ 30 days, Azure-native rotation).

The Node is **deployable** — it runs as a Container App per ADR-0015 (`ca-hd-identity-{env}`, system-assigned Managed Identity, multi-revision mode with traffic splitting per Invariant 36). The HTTP surface fronts the OAuth callback flow (for the external IdP), the user-info endpoint, the JWKS endpoint for `IInternalTokenIssuer`'s signing key, and the `/users/me` surface for consumer apps.

### D10. Boundaries explicit

| Boundary | Identity owns | Identity does NOT own |
|---|---|---|
| **Auth** | User record, internal-token issuance | JWT validation, policy evaluation, signing-key rotation for externally-issued tokens (those keys are in the external IdP) |
| **Audit** | The `IdentityMap` (PII↔token map), the `UserErased` emission | The audit substrate, the append-only store, `IAuditQuery` |
| **Tenant lifecycle (ADR-0050)** | The user record (a user can exist before being attached to a tenant) | The tenant state machine, tenant-side provisioning workflow, tenant data partitions |
| **Communications** | User identity resolution as input to orchestration; deletion-fan-out coordination via Communications-hosted workflows where the tenant topology matters | Notification preferences, cadence rules, message intents |
| **Notify** | Nothing directly — Identity calls Communications, which delegates to Notify | Email/SMS delivery, template rendering |
| **Vault** | Identity's per-Node Vault namespace and its rotation discipline | The Vault Node itself |
| **External IdP** | The seam (claim mapping, fan-out trigger) | Credential storage, MFA enrollment, password reset flows, social-login provider configuration |

### D11. Charter sanity check — is this premature?

The charter (§"What this charter forbids" item 2) explicitly warns against **architecture-as-procrastination**: "Even in a workshop, the foundation eventually has to serve the cool stuff being built on top of it. If a year goes by and only ADRs ship, the foundation is consuming the workshop instead of supporting it." This warning applies to this ADR; the test is whether **naming the Identity boundary now** is foundation-work-that-supports-the-workshop or foundation-work-that-replaces-it.

**The argument that this is appropriately-timed:**

- The first user-facing app (Hearth per PDR-0005) is the scout's pick for first-build. When its signup flow is scoped, the question "where does the user record live" must have an answer. Without this ADR, the answer is "inside Hearth," which is the distributed-monolith trap.
- The Node is **not built** until that first app pulls on it. This ADR commits the boundary and the contract surface; the scaffolding packet is a follow-up; the Entra adapter is a follow-up after that. The investment now is hours, not weeks.
- Identity is **upstream of ADR-0050** (Tenant Lifecycle). A user must exist before being attached to a tenant. ADR-0050 explicitly anticipated this dependency by using "Auth-side packet" as a placeholder for the user-level GDPR path. This ADR resolves that placeholder.
- Per the charter's licensed permissions ("Spend on the foundation. Time invested in ADRs, invariants, substrate hygiene, and architectural correctness is not 'premature optimization' or 'procrastinating on shipping.' It is the work."), naming a boundary that three queued PDRs will all need is precisely the substrate work the charter licenses.

**The argument that this is premature** — and the honest counterweight:

- No user-facing app has shipped. The boundary could be re-litigated when the first one does.
- The IdP-vendor choice in D2 is itself deferred to the first feature packet — which suggests the whole decision could have waited.

**The resolution:** the boundary is named now because the *boundary itself* is what's load-bearing for the next user-facing app's planning. The vendor choice (which is what's actually deferable) is deferred. This is the same posture ADR-0058 / ADR-0059 took with the Cache Node (boundary named, backings deferred to actual consumers), and the same posture every AI-sector stand-up took (boundary named, first feature deferred).

**Charter verdict:** appropriately-timed, not procrastination.

### D12. Phased rollout

- **Phase 0 (this ADR).** Boundary, contract surface, IdP-wrapping posture committed. No code.
- **Phase 1 (scaffold packet, when accepted).** Repo created, solution scaffolded, `HoneyDrunk.Standards` wired, CI per ADR-0012, in-memory test fixtures for `IUserDirectory` / `IUserProfileStore` / `IInternalTokenIssuer` / `IExternalIdpClaimMapper` / `IIdentityDeletionFanout`. No IdP adapter yet. The Node compiles, ships an empty runtime, and is queryable by downstream Nodes via the Abstractions package. Contract-shape canary live from day one.
- **Phase 2 (first user-facing app's feature packet — Hearth signup).** The IdP-vendor confirmation (D2). The first concrete `IExternalIdpClaimMapper` implementation (likely Entra) lands as part of this packet. The signup flow is wired end-to-end: external IdP → Identity claim mapping → user record creation → internal token issuance → app handoff.
- **Phase 3 (when ADR-0050 advances past provisioning).** The user-level GDPR Art. 17 path lands here per D8: `IIdentityDeletionFanout`, the `UserErased` Audit emission, the IdP-side delete-user call. Identity-map relocation from Auth (per the ADR-0050 D6 follow-up amendment) happens in this phase.
- **Phase 4 (when the second user-facing app pulls on Identity).** Cross-app account-stability validation: a user signing into Hearth should be the same `UserId` when they later sign into Lately. The Phase 2 work covers this implicitly (the `UserId` is global) but the second app's packet verifies it with a canary.
- **Phase 5 (when a non-Entra IdP becomes interesting).** Add a second `IExternalIdpClaimMapper` implementation (Clerk, or whatever the second pull is). Validates that the wrapping-seam architecture (D2) actually delivers IdP-swap optionality. No re-keying of existing users required.

### D13. Relationship to existing ADRs

- **Invariant 10** ("Auth is not an identity provider") — **preserved**. Auth still only validates. Identity issues internal tokens; the external IdP issues external tokens.
- **ADR-0005 (Configuration and Secrets Strategy)** — Identity gets its own per-Node Key Vault `kv-hd-identity-{env}` per Invariant 17.
- **ADR-0006 (Secret Rotation and Lifecycle)** — Identity's signing key for `IInternalTokenIssuer` is tier-1 (≤ 30 day rotation, Azure-native).
- **ADR-0015 (Container Hosting Platform)** — Identity is a containerized deployable, `ca-hd-identity-{env}`, multi-revision per Invariant 36.
- **ADR-0019 (Communications Stand-Up)** — Identity calls Communications for user-facing notifications (verification email, account-change confirmation, account-deletion confirmation). Identity does NOT call Notify directly per the ADR-0019 D4 boundary.
- **ADR-0026 (Grid Multi-Tenant Primitives)** — Identity is upstream of tenancy. Users exist before tenant attachment. The `IGridContext.TenantId` may be `TenantId.Internal` during user-only operations (signup before tenant attachment), per the existing internal-sentinel convention.
- **ADR-0028 (Event-Driven Architecture)** — `DeletionIntent` and `DeletionAck` are domain events on Service Bus.
- **ADR-0030 (Grid-Wide Audit Substrate)** — Identity is a first-class emitter alongside Auth, per ADR-0030's D6 expectation. New event types: `UserCreated`, `UserVerified`, `UserLocked`, `UserUnlocked`, `UserErased`, `InternalTokenIssued` (sampled).
- **ADR-0031 (Audit Standup)** — Identity is reconciled into `consumed_by_planned` on `honeydrunk-audit`.
- **ADR-0042 (Idempotency Contract)** — `IIdentityDeletionFanout` is idempotent end-to-end. Map rows have idempotency keys; downstream `DeletionAck` is keyed.
- **ADR-0049 (Data Classification, PII Handling)** — Identity's `IdentityMap` is the **single most PII-concentrated table in the Grid**. Per ADR-0049's PII sub-taxonomy, the table is `Restricted` / `Sensitive PII`. Backup tier: T0 per ADR-0036 (loss of `IdentityMap` is loss of GDPR-erasure capability for active users — Tier 0).
- **ADR-0050 (Tenant Lifecycle, Proposed)** — **additive amendment**: the `IdentityMap` ownership relocates from `HoneyDrunk.Auth` to `HoneyDrunk.Identity` per D3 of this ADR. The architectural posture from ADR-0050 D6 is unchanged.
- **ADR-0051 (AI Agent Authorization)** — `UserPrincipal` is a `PrincipalId` variant defined here. `IUserDirectory` is the source of truth for resolving a `UserPrincipal` to a user record.
- **ADR-0057 (Public HTTP API Versioning)** — Identity's user-facing endpoints are `/v1/users/*`, follow the standard RFC 7807 error envelope, and OAuth 2.1 with PKCE is wired through the external IdP per Phase 2.
- **PDR-0003 (Lately)**, **PDR-0005 (Hearth)**, **PDR-0008 (Curiosities)** — all three consumer apps consume Identity for signup/login. **Unblocks** the user-account layer for all three.

## Consequences

### Affected Nodes

- **HoneyDrunk.Auth** — receives an additive context note (Auth is validation-only; Identity owns the user record). No code change at stand-up. When Phase 2 lands, Auth validates Identity-issued internal tokens via the same JWKS-based path it uses for external tokens (no new validation primitive).
- **HoneyDrunk.Audit** — gains Identity as a first-class emitter (new event types: `UserCreated`, `UserVerified`, `UserLocked`, `UserUnlocked`, `UserErased`, `InternalTokenIssued`). The audit substrate is unchanged; only the consumer relationship is added in `consumed_by_planned`.
- **HoneyDrunk.Vault** — gains an Identity-Node namespace (`kv-hd-identity-{env}`) at scaffold time. Existing Vault contracts unchanged.
- **HoneyDrunk.Data** — gains a new Data-backed runtime composition for Identity's `UserRecord`, `UserProfile`, `IdentityMap`, and `ExternalSubjectMap` tables. Existing Data contracts unchanged.
- **HoneyDrunk.Communications** — gains Identity as an upstream caller. Verification email, account-change notification, account-deletion confirmation are Communications intents. Also gains a `tenant-scoped DeletionIntent` workflow per Phase 3 (because Communications knows tenant topology and Identity does not).
- **HoneyDrunk.Notify** — no direct relationship. Notify is reached via Communications per the ADR-0019 D4 boundary.
- **HoneyDrunk.Kernel** — no change. `IGridContext` already carries `PrincipalId`-shaped context; the existing surface accommodates.
- **HoneyDrunk.Studios** — gains admin-console pages for the user directory (list users, view user record, deletion-fan-out status, deletion-event audit timeline). Lands as a follow-up packet alongside the Phase 3 work.
- **PDRs 0003 / 0005 / 0008** — unblocked for the user-account layer. Each will declare Identity as a dependency when their signup-flow packets scope.

### Invariants

This ADR proposes (not commits — invariant numbers and final wording assigned by the scope agent at acceptance):

- **Invariant proposal: User identity records (including the `IdentityMap` PII↔token map) live in `HoneyDrunk.Identity`, not in `HoneyDrunk.Auth`.** Preserves Invariant 10 by clarifying ownership: Auth validates, Identity owns the user record.
- **Invariant proposal: Internal-token issuance is the exclusive responsibility of `HoneyDrunk.Identity.IInternalTokenIssuer`.** Any other Node minting JWT bearer tokens for internal use is a boundary violation. (This is the affirmative version of Invariant 10 — Invariant 10 says Auth doesn't issue; this proposed invariant says only Identity does.)
- **Invariant proposal: Downstream Nodes take a runtime dependency only on `HoneyDrunk.Identity.Abstractions`.** Composition against `HoneyDrunk.Identity` (runtime) is a host-time concern. Same pattern as ADR-0019 (Communications), ADR-0031 (Audit), ADR-0044 (AI), and ADR-0017 (Capabilities).
- **Invariant proposal: The `HoneyDrunk.Identity.IdentityMap` (PII↔`PseudoUserToken` map) and the audit substrate are owned by different Nodes and connected only by `DeletionIntent` workflows.** Preserves Invariant 47 (Audit append-only) and the ADR-0050 D6 pseudonymization posture: the audit substrate never holds reverse-lookup capability; reverse lookup goes through Identity's erasable map.

### Operational Consequences

- **The user-account layer is unblocked.** PDRs 0003 / 0005 / 0008 can scope their signup flows knowing where the user record lives.
- **Breach liability is materially reduced** by outsourcing the credential store to the external IdP (per D2). The remaining identity-side breach surface (the `IdentityMap`, which holds PII but not credentials) is the single most security-sensitive Grid table; it is T0 backup tier per ADR-0036.
- **Invariant 10 survives intact.** The cleanest possible outcome of the validation-vs-issuance reconciliation: add a new Node that issues, leave Auth as it is.
- **ADR-0050 D6 is fully resolvable.** The "Auth-side packet" placeholder for the user-level GDPR Art. 17 path resolves to "Identity-side packet."
- **A new Container App joins the Grid** in Phase 1. `ca-hd-identity-{env}` per ADR-0015. Modest cost (one extra Container App per environment); operationally consistent with every other deployable Node.
- **Vendor risk on the IdP is real but bounded.** Entra (or whichever vendor lands) is a real dependency. The wrapping-seam architecture (D2) means swapping vendors is a re-keying operation, not a data migration. This is the architectural property D2 specifically buys.
- **The user-facing OAuth flows go through the external IdP** (Entra by default). The studio's UI surface for "log in" is the IdP's hosted UI (with custom branding via Entra's user-flow customization). For consumer apps where the brand-control matters (Hearth, Lately, Curiosities), the IdP's branded-flow capability is the path; if at some point brand control becomes insufficient, the wrapping seam lets us host the UI ourselves later without breaking the user record.
- **`IInternalTokenIssuer` introduces a new internal trust root.** The signing key in `kv-hd-identity-{env}` is critical-tier. Loss = inability to authenticate service-to-service `UserPrincipal` traffic; compromise = ability to forge `UserPrincipal` tokens. Tier-1 rotation per ADR-0006 is the standard discipline. The blast radius is bounded by the 5-minute token TTL.

### Follow-up Work

- Stand up the `HoneyDrunk.Identity` repo and scaffold the Node (Phase 1; this is the first packet that declares this ADR in `accepts:`, triggering the scope-agent flip to Accepted).
- Implement the `IExternalIdpClaimMapper` Entra adapter (Phase 2; lands with the first user-facing app's signup packet).
- Implement `IInternalTokenIssuer` and wire Auth's existing JWT validator to fetch Identity's JWKS (Phase 2).
- Implement `IIdentityDeletionFanout` and the `UserErased` audit emission (Phase 3).
- Relocate `IdentityMap` from `HoneyDrunk.Auth` to `HoneyDrunk.Identity` (Phase 3; coordinates with ADR-0050 D6).
- Author the Studios admin-console pages for the user directory (Phase 3).
- Re-evaluate the IdP vendor choice if Entra's developer experience or pricing has degraded by Phase 2 (D2 alternative slate held warm).
- Add a Lately-vs-Hearth cross-app `UserId`-stability canary (Phase 4).
- Add a second `IExternalIdpClaimMapper` implementation when an alternative IdP becomes interesting (Phase 5).
- Update `constitution/invariants.md` with the four proposed invariants once accepted.

## Alternatives Considered

### Do nothing yet; let the first user-facing app roll its own identity layer and extract later

Rejected. The first app would necessarily embed a credential store, a token-issuance flow, a user record, and a profile model inside its own process. Extracting those later is the classic distributed-monolith breakup — each piece is independently load-bearing, the seams are not designed for separation, and the migration is a multi-month rewrite of the first app's hottest code paths. The charter explicitly licenses spending on substrate when the substrate is what makes future apps cheap (§"What this charter licenses"); this is precisely that case. The marginal cost of naming the Identity boundary now is one ADR (this document) and one future scaffold packet. The marginal cost of deferring is the rewrite of every consumer app's identity layer once the boundary is finally named. Asymmetric in the wrong direction.

### Widen `HoneyDrunk.Auth` to include the user record, profile, and token issuance — drop Invariant 10

Considered, especially because Auth already exists, already has a clear name, and is already in the Grid. The simplest possible architecture is "Auth does everything authentication-and-identity-related." Rejected:

- **Invariant 10 is load-bearing.** "Auth is not an identity provider" is the discipline that has kept Auth small, stable, and reusable across every Node that needs request-gatekeeping. Widening it would create the kind of god-Node the Grid is structured to avoid.
- **The current Auth Node's surface is well-suited to its current scope.** JWT validation + policy evaluation is a tight, well-understood, well-tested boundary. Adding user records, profiles, IdP claim mapping, and deletion fan-out to that surface would 3x the Node's contract surface and 4x its dependency footprint.
- **The two responsibilities have different deployment shapes.** Auth is a library Node consumed by every HTTP-fronted Node (it ships as a NuGet package; consumers compose it). Identity is a deployable Node (a Container App with its own HTTP surface — OAuth callback, user-info endpoint, JWKS endpoint, `/users/me`). Bundling them would force every Auth consumer to take on Identity's deployable footprint or split the deployable from the library, which is just two Nodes wearing one name.

Rejected with conviction.

### Build a credential store in-house using ASP.NET Core Identity + OpenIddict

The "we own everything" path. Strong technical fit with the .NET-first Grid. Rejected per D2's breach-liability analysis: a one-person studio should not be the credential-breach response team for its own users. The cost-benefit of running a credential store correctly (password hashing, breach detection, MFA, social login, account recovery, suspicious-login throttling, brute-force protection, geo-IP signal, device fingerprinting, and ongoing maintenance) is enormous, and the failure mode (a credential breach) is catastrophic in a way that bounds the studio's options. The wrapping-seam architecture (D2) explicitly preserves the option to migrate to this posture later if the IdP economics become prohibitive at scale — the user record is owned by Identity, the `ExternalSubject` mapping is the foreign key, and a future cutover is a re-keying operation rather than a data migration.

Held as the **eventual destination only** if both (a) IdP costs grow large enough to justify the engineering investment and (b) the studio's security posture matures to the point of being able to operate a credential store credibly. Neither condition holds today.

### Use Supabase Auth as the IdP

Considered. Supabase Auth is open-source-friendly, Postgres-native, and matches the Grid's storage posture. The credential store is owned by the developer (it's just a table in the developer's Postgres). Rejected because **that property defeats the breach-liability argument** in D2 — the whole reason to wrap an IdP is to outsource the credential-store breach surface. If the credential store is going to live in developer-hosted infrastructure anyway, ASP.NET Core Identity + OpenIddict is the same posture with one fewer vendor in the stack. Rejected as redundant.

### Use Auth0 as the IdP

Considered. Mature, enterprise-grade, well-documented, broad social-login support. Rejected on cost — the B2C / consumer tier ($240+/month for production above the free tier) is a recurring fixed cost that doesn't match the charter's lean-substrate posture for a not-yet-revenue product layer. Held as a credible alternative if Entra's developer experience proves intolerable; the wrapping-seam architecture means a future migration is bounded.

### Use Clerk as the IdP

Considered. Best developer experience in 2026 for consumer-app signup flows; strong on passkey and social-login UX. Pricing is per-MAU above the free tier (~10k MAU free, then per-user, escalating). Rejected as leading candidate because:

- **Azure-native integration is weaker.** Everything goes through Clerk's tokens; managed-identity-back-to-Azure-resources flows are not first-class.
- **Pricing curve at scale is steep relative to Entra's.** Free up to 10k MAU vs. Entra's ~50k MAU.
- **Brand-control story is similar.** Both offer custom-domain hosting; both have hosted-UI customization. Not a tiebreaker.

Strong contender if Entra's developer experience proves too clunky in the Phase 2 evaluation. The wrapping-seam architecture explicitly preserves the option.

### Make Identity a library Node consumed by every deployable that needs auth, rather than a deployable

Considered. Mirrors the Auth shape (library, consumed everywhere). Rejected because Identity needs its own HTTP surface for the OAuth callback flow, the user-info endpoint, the JWKS endpoint for `IInternalTokenIssuer`, and the user-facing API (`/users/me`, `/users/me/profile`, account-deletion endpoints). Embedding those endpoints into every consumer app would either replicate the surface N times (and create N OAuth-callback endpoints to register with the IdP, which is a configuration nightmare) or force one consumer to be the de-facto Identity host (which is just Identity-as-a-deployable without the clarity of a separate Node).

Rejected. Identity is a deployable Container App.

### Skip the `IdentityMap` relocation from `HoneyDrunk.Auth` (ADR-0050 D6) — leave it in Auth, just add Identity alongside

Considered as a smaller-blast-radius option. Rejected:

- **The map is identity data, not auth data.** Leaving it in Auth perpetuates the conflation this ADR exists to resolve.
- **The Auth Node would gain a runtime dependency on Data** (to host the map) that it currently does not have. Auth is currently a Vault-only-runtime-dependency Node. Adding Data widens Auth's footprint for a responsibility that conceptually belongs in Identity.
- **The additive amendment to ADR-0050 D6 is minimal.** Only the Node owning the table moves; the architectural posture (pseudonymization, erasable map, audit-substrate preserved) is unchanged. The amendment is cheap; the alternative (long-term Auth-hosts-identity-data weirdness) is expensive.

Rejected. The relocation lands in Phase 3.

### Use an unprefixed UUID instead of a `usr_`-prefixed ULID for `UserId`

Considered. UUIDs are universal, well-tooled, and avoid a project-specific prefix convention. Rejected:

- **The Grid has a prefix convention** (`tnt_` per ADR-0026, `pt_`/`pu_` per ADR-0050 D6). `usr_` extends that convention.
- **ULIDs are sortable** in a way UUIDs are not — useful for the user directory's pagination and time-ordered queries.
- **The prefix is operationally useful.** `usr_01HKM…` is immediately recognizable as a user identifier in logs, traces, audit timelines, and ops tooling. `01HKM…` without a prefix is ambiguous with every other ULID.

Rejected. `usr_`-prefixed ULID it is.

### Issue long-lived internal tokens (≥ 1 hour) for service-to-service flows instead of ≤ 5 min

Considered. Longer-lived tokens reduce the refresh overhead and simplify long-running background-job flows. Rejected:

- **Compromise blast radius is the determining factor.** A 5-minute token, if leaked, is useful to an attacker for 5 minutes. A 1-hour token is useful for 12x as long.
- **`IInternalTokenIssuer` is cheap to call.** Background jobs that need a token can mint one per operation; agents executing under `UserPrincipal` can mint one per request. The overhead is sub-millisecond.
- **Refresh tokens are a separate concept that lives in the external IdP** for the user-facing-app session-extension path. Internal tokens don't need refresh — they need short TTLs.

Rejected. Internal tokens are ≤ 5 minutes.

### Defer Identity until the second user-facing app makes the cross-app `UserId` stability obviously necessary

Considered. The first user-facing app could conceivably ship without Grid-wide identity if its user records lived inside the app. The second app would force extraction. Rejected per the "do nothing yet" alternative above — the extraction cost is much higher than the up-front naming cost. Naming the boundary now is the cheaper option. The charter's licensed permissions explicitly cover this.
