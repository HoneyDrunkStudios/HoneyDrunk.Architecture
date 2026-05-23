# ADR-0078: End-User Identity — Microsoft Entra External ID

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core

## Context

[ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) stood up `HoneyDrunk.Identity` as the Core sector's owner of the user record, the external-IdP seam, internal-token issuance, and account-deletion fan-out. ADR-0060 D2 explicitly **deferred the vendor choice**:

> The vendor confirmation lands in the **first feature packet** (when Hearth or Lately pulls on Identity). If at that point the Entra developer experience or pricing has degraded, the alternatives above are re-evaluated. The Node's contract surface is IdP-agnostic by design (D4).

ADR-0060 D2 also named **Microsoft Entra External ID as the leading candidate** and laid out the alternatives slate (Clerk, Auth0, Supabase Auth, ASP.NET Core Identity + OpenIddict self-hosted). The boundary was committed (Identity wraps an external IdP per D2's posture); the specific vendor was deferred.

This ADR **fills ADR-0060 D2's deferred vendor decision** before the first user-facing app (Hearth per [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md)) pulls on Identity. Resolving the vendor now means the Identity Node's scaffold packet can include the Entra adapter (or at minimum, the Entra-specific configuration shape) rather than deferring the adapter to a later packet and leaving the Identity Node scaffolded-but-unusable for signup flows.

The forcing functions converging now:

- **[ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) Phase 2** (the first user-facing app's signup packet) needs the IdP vendor to be settled.
- **[PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md) Hearth** is the scout's pick for first-build per [`charter-aware draft`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md). Its signup flow is the imminent consumer.
- **[PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md) Lately** and **[PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md) Curiosities** are queued behind it; all three consumer-app PDRs need the same answer.
- **Azure AD B2C is being sunset for new tenants.** Microsoft has communicated that B2C is no longer the recommended product for new customer-identity (CIAM) projects; the replacement is Entra External ID. Adopting B2C today would be adopting a sunset product.
- **The Azure-deep posture is reinforced.** Per [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md), the Grid is committed to Azure as the cloud platform; Entra is the native identity layer.
- **The Notify Cloud tenant user surface** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) needs an answer for "how do tenant operators sign in." The same IdP serves consumer apps and Notify Cloud tenants (different application registrations under one Entra External ID tenant).

The charter framing ([`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids" item 2):

> Architecture-as-procrastination. Even in a workshop, the foundation eventually has to serve the cool stuff being built on top of it.

Deferring the IdP vendor past the imminent Hearth signup packet is exactly that failure mode — the boundary is named (ADR-0060) but the cool stuff (Hearth signup) is blocked. This ADR commits the vendor before the block becomes a delay.

## Decision

### D1 — Microsoft Entra External ID is the end-user identity provider

**Microsoft Entra External ID** is the identity provider for all end-user authentication in the Grid. Every consumer-app user (Hearth, Lately, Currents, Curiosities, future consumer PDRs) and every Notify Cloud tenant-operator user authenticates via Entra External ID.

The committed shape:

- **Single Entra External ID tenant** for the Grid (`honeydrunkstudios.com` or similar tenant identifier; exact tenant naming finalized at provisioning).
- **Per-application App Registrations** under the External ID tenant — one for Hearth, one for Lately, one for Currents, one for Curiosities, one for Notify Cloud tenant operators, etc. Each App Registration carries its own redirect URIs, branding, and policy configuration.
- **OAuth 2.1 with PKCE** as the authentication flow per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) (which committed OAuth 2.1 + PKCE as the user-facing flow shape).
- **OpenID Connect** as the identity protocol on top of OAuth.
- **External ID handles**: signup, sign-in, password reset, MFA enrollment, passkey enrollment, social login, account lockout, suspicious-login throttling, brute-force protection, geo-IP signal, device fingerprinting.

**Why Entra External ID:**

- **Microsoft's current CIAM offering.** Entra External ID is the actively-developed successor to B2C; Microsoft has signaled long-term investment. The many-decade horizon ([`constitution/charter.md`](../constitution/charter.md)) is served by adopting the current product rather than the sunset one.
- **Native Azure integration.** Same identity-and-RBAC plane as the rest of the Grid's Azure surface. Managed identities, Key Vault access, App Configuration access, Service Bus subscriptions — all under one Entra umbrella. No second identity vendor to wire up.
- **Free up to 50K MAU.** The pricing curve covers every reasonable v1 consumer-app trajectory for Hearth, Lately, and Curiosities combined. Per-MAU pricing thereafter is predictable; no per-feature gating at the free tier.
- **Standards-based.** OIDC + OAuth 2.1 + PKCE are open standards; Entra implements them per spec. No vendor-proprietary auth flow.
- **Passkey / FIDO2 / WebAuthn support built in.** The current generation of consumer-identity best practice (phishing-resistant authentication) is supported without bespoke implementation.
- **Custom-domain support.** The user-facing auth URL can be `auth.honeydrunkstudios.com` rather than a vendor subdomain — important for brand consistency on consumer-app surfaces.
- **B2C-style user-flow customization.** Signup, sign-in, and password-reset journeys can be customized without bespoke UI for each.
- **AI-assistance gradient.** Microsoft's identity products are well-represented in 2026 AI training data; Claude / Codex / Copilot have meaningful pattern recognition on Entra OIDC flows.

The negative form: Auth0 is not the default; Clerk is not the default; Supabase Auth is not adopted; self-hosted credential storage is not adopted at v1.

### D2 — Not Azure AD B2C

**Azure AD B2C is explicitly not adopted.** B2C is in sunset / maintenance mode for new tenants per Microsoft's communicated product direction; Entra External ID is the migration target for existing B2C customers and the canonical choice for new ones.

Adopting B2C today would be adopting a product Microsoft has indicated will not receive significant new investment. The migration cost from B2C → External ID at some future date would be the same kind of cost this ADR exists to avoid by picking the current product now.

### D3 — OIDC-standard claims only

The Grid consumes **OIDC-standard claims only** from Entra-issued tokens. The standard set:

- **`sub`** — the IdP subject identifier (mapped to `ExternalSubject` per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D3 and resolved to `UserId`).
- **`iss`** — the IdP issuer URL.
- **`aud`** — the audience (application identifier).
- **`exp`, `iat`, `nbf`** — token lifetime claims.
- **`email`, `email_verified`** — email and verification status (where the user has authenticated with a credential bound to an email).
- **`name`, `given_name`, `family_name`** — basic profile claims when the user has provided them.
- **`preferred_username`** — display-name candidate.

**Entra-proprietary claims (`oid`, `tid`, etc.) are not consumed for application logic.** They may be logged for diagnostic purposes; they are not load-bearing in the Identity Node's claim-mapping logic.

**Why standard-only:** This is the **cheap vendor-exit hedge** (the same pattern from [ADR-0076](./ADR-0076-cache-backing-azure-cache-for-redis.md) D3 and [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) D5). Application code that depends only on OIDC-standard claims migrates cleanly to any other OIDC-compliant IdP; code that depends on `oid` or `tid` is bound to Entra specifically. The discipline at the consuming end pre-pays the migration cost if Entra's trajectory ever turns hostile.

The `IExternalIdpClaimMapper` interface from [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D4 is the seam where claim mapping happens; the Entra implementation maps standard claims; a future alternative-IdP implementation maps the same standard claims from a different issuer.

### D4 — HoneyDrunk.Identity is the seam; Entra is the provider

The relationship between Identity Node and Entra is the same provider-slot pattern Vault uses with Key Vault, Notify uses with Resend, etc.:

- **`HoneyDrunk.Identity`** (per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md)) owns the user record, the `UserId` ↔ `ExternalSubject` map, the user profile, internal-token issuance, and the deletion fan-out.
- **`HoneyDrunk.Identity.Providers.Entra`** is the package that implements `IExternalIdpClaimMapper` against Entra External ID. Other implementations (Clerk, Auth0, OpenIddict-self-hosted) could be authored against the same `IExternalIdpClaimMapper` contract; Entra is the default.
- **Application code consumes `HoneyDrunk.Identity`'s contracts**, never Entra's SDKs directly. The wrapping seam means swapping providers (per D7's migration posture) is a per-Node adapter swap, not application-code rework.

The negative form: consumer applications do not import `Microsoft.Identity.Web` or other Entra-specific SDKs directly. The HTTP front-door for end-user authentication (the OAuth callback, the JWKS endpoint, the user-info endpoint, the `/users/me` endpoint) is hosted by `HoneyDrunk.Identity`; consumer apps redirect to Identity's HTTP surface for the OAuth dance.

### D5 — Token validation stays in HoneyDrunk.Auth per Invariant 10

Per [Invariant 10](../constitution/invariants.md) ("Auth tokens are validated, never issued"), token validation remains in `HoneyDrunk.Auth`. This ADR does not change that.

- **Entra-issued tokens** (the OIDC ID tokens and access tokens external IDPs issue at the OAuth callback) are validated by `HoneyDrunk.Auth.IJwtBearerValidator` against Entra's JWKS endpoint.
- **HoneyDrunk.Identity-issued internal tokens** (`IInternalTokenIssuer` per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D6) are validated by the same `HoneyDrunk.Auth.IJwtBearerValidator` against Identity's JWKS endpoint.
- **Auth is unchanged.** No new validation primitive lands in Auth; the existing JWKS-based validator already handles both cases.

The architectural posture from ADR-0060 D6 is preserved: Identity issues; Auth validates; the invariant survives intact because **Auth still issues nothing**.

### D6 — Per-application configuration shape

Each consumer application (Hearth, Lately, etc.) and Notify Cloud's tenant-operator surface get separate Entra App Registrations. Per-app configuration carries:

- **App Registration ID** in App Configuration per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) (non-secret) or Vault (if the auth flow involves a confidential-client secret).
- **Tenant-issuer URL** (the Entra External ID tenant's issuer endpoint) — Grid-wide; resolved through App Configuration.
- **Redirect URIs** registered with Entra for each app's OAuth callback path.
- **App-specific branding** in Entra (logo, color scheme, custom domain segment).
- **App-specific user-flow customization** (signup form fields, social-login providers enabled).

The Entra-side configuration (App Registrations, custom branding, user flows) is provisioned via Bicep per [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) where Bicep's Entra resource coverage suffices; otherwise via a documented Portal-or-CLI workflow until Bicep's coverage closes the gap.

### D7 — Migration path away from Entra

The Grid commits to Entra External ID today. If Entra's trajectory ever turns hostile (pricing change, sunset like B2C, hostile policy), the migration path is bounded by:

- **The wrapping seam from [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D2.** The user record lives in Identity; the IdP holds only credentials. A new `IExternalIdpClaimMapper` implementation against a different IdP plus a user-credential-rekeying flow is the migration shape.
- **The OIDC-standards-only discipline (D3).** Application code does not depend on Entra-proprietary claims; the migration target needs only to be OIDC-compliant.
- **The user record persists.** Existing `UserId` values do not change across the migration; `ExternalSubject` values are rewritten to the new IdP's `sub` claims.

The migration cost is real but bounded: the cost is the per-user credential migration (users have to authenticate against the new IdP at next login; passwords / passkeys are not portable between IdPs). The user record stays intact; the application code stays intact.

### D8 — Cost posture

**Free up to 50K MAU** is the headline. Per-MAU pricing thereafter is predictable:

- **Tier 1: 0 – 50K MAU** — free.
- **Tier 2: 50K – 1M MAU** — per-MAU pricing (~$0.0055/MAU at the time of this ADR; the operator confirms current rates at adoption time).
- **Tier 3: 1M+ MAU** — pricing tier shift; operator-level decision when triggered.

The Grid's MAU trajectory through Hearth + Lately + Currents + Curiosities + Notify Cloud tenants at the low-hundreds ceiling is well below the 50K threshold; the IdP cost is effectively zero through MVP and well into post-MVP scale.

Cost re-evaluation triggers per [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) governance — if Entra spend ever exceeds $200/mo or the per-MAU rate changes meaningfully, a re-evaluation against the alternatives in D9 happens.

### D9 — Alternatives evaluated

Per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D2, the alternatives were evaluated; this ADR confirms the Entra pick over them:

| Vendor | Status | Reason |
|---|---|---|
| **Azure AD B2C** | Rejected | Sunset for new tenants; Entra External ID is the migration target |
| **Auth0** | Rejected on cost | $240+/mo for production CIAM tier; doesn't match charter's lean-substrate posture for not-yet-revenue products |
| **Clerk** | Strong contender | Best DX in 2026 for consumer-app signup; weaker Azure-native integration; pricing curve steeper than Entra at scale |
| **Supabase Auth** | Rejected | Self-hosts credential store; negates the breach-liability argument from [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D2 |
| **ASP.NET Core Identity + OpenIddict (self-hosted)** | Held as eventual destination only | Eliminates vendor risk; requires solo-dev to be the credential-breach response team; not viable today |

Clerk is the alternative most likely to be re-evaluated. If Entra's developer experience proves clunky in concrete Phase-2 implementation work, the wrapping-seam architecture (D7) makes the Clerk migration bounded.

### D10 — Out of scope

The following are explicitly **not** decided by this ADR:

- **The Identity Node's contract surface.** Owned by [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D4. This ADR fills the vendor slot, not the contract.
- **The user-deletion fan-out workflow.** Owned by [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D8. The Entra-side delete-user call (Microsoft Graph `DELETE /users/{id}`) is part of the workflow; this ADR confirms it as the deletion mechanism.
- **Per-application branding and user-flow customization details.** Per-PDR consumer-app concern; lands per app at Phase 2.
- **MFA enforcement policy.** Per-application policy decision; defaults to "optional, user-enrollable" at v1; per-app policy hardens later.
- **Social-login provider enablement.** Per-application decision; the default is "email-only" at v1; per-app may add Google / Apple / GitHub.
- **Tenant-scoped Entra setup (the Notify Cloud tenant operators' organizational sign-in).** Notify Cloud-side concern; lands per [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) follow-up.
- **B2B / enterprise-customer auth via Entra (workforce identity).** Out of scope; the Grid's identity boundary is consumer / end-user. If a future enterprise-customer scenario emerges, the wrapping-seam architecture supports it.
- **API-key authentication for the public Grid APIs.** Per [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md), Notify Cloud tenants authenticate API requests with API keys (a different auth surface from end-user identity); out of scope.

## Consequences

### Affected Nodes

- **[HoneyDrunk.Identity](./ADR-0060-stand-up-honeydrunk-identity-node.md)** — receives the Entra vendor confirmation. The Phase 2 packet now includes the `HoneyDrunk.Identity.Providers.Entra` adapter (or that adapter's first version).
- **[HoneyDrunk.Auth](../repos/HoneyDrunk.Auth/overview.md)** — no code change. Validates Entra-issued tokens via existing `IJwtBearerValidator` against Entra's JWKS endpoint (and validates Identity-issued internal tokens against Identity's JWKS endpoint per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D6). Invariant 10 holds.
- **[HoneyDrunk.Vault](../repos/HoneyDrunk.Vault/overview.md)** — Entra App Registration secrets (where confidential-client flows are used) live in `kv-hd-identity-{env}` per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md).
- **HoneyDrunk.Actions** — Bicep templates per [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) provision per-app Entra App Registrations where Bicep's Entra resource coverage suffices.
- **[ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) Notify Cloud** — tenant-operator sign-in uses Entra (a separate App Registration from consumer apps). API-key authentication for tenant API access is unchanged.
- **Consumer-app PDRs** ([PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md)) — each declares Identity as a dependency; each gets a per-app Entra App Registration.

### Invariants

This ADR proposes (numbering finalized at acceptance):

- **End-user identity tokens are issued by Microsoft Entra External ID.** Any other end-user IdP requires an ADR amendment.
- **Application code consumes OIDC-standard claims only from Entra-issued tokens.** Entra-proprietary claims (`oid`, `tid`, etc.) are not load-bearing in application logic. (Codifies D3; vendor-exit hedge.)
- **Auth still issues nothing.** [Invariant 10](../constitution/invariants.md) is preserved; Identity issues internal tokens, Entra issues external tokens, Auth validates both.

### Operational Consequences

- **Hearth (and every subsequent consumer-app PDR) is unblocked on identity.** The vendor decision was the last gating decision for Phase 2 of [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md).
- **Credential-breach surface is outsourced to a vendor with a dedicated security team.** Per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D2's breach-liability analysis, this is the right posture for a solo-dev shop.
- **The Azure-deep posture is reinforced.** Identity is one more Azure-native binding; the vendor-exit cost compounds.
- **Cost is effectively zero through MVP** (50K MAU free tier).
- **OAuth 2.1 + PKCE is the user-facing flow.** Aligns with [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md).
- **Per-application Entra App Registrations** are operationally cheap to provision; one per consumer-app and one for Notify Cloud tenants.
- **Custom domain `auth.honeydrunkstudios.com`** unifies the OAuth experience under the Grid's brand.
- **MFA, passkeys, social login, account recovery** all come for free through Entra's features; no Grid-side implementation work.
- **Vendor risk on Entra is real but bounded.** Per D7's migration posture, the Identity Node owns the user record; Entra holds credentials; switching IdPs is a re-keying operation, not a data migration.

### Follow-up Work

- Provision the Entra External ID tenant.
- Provision per-application Entra App Registrations (one for Hearth, queued for the other consumer-app PDRs, one for Notify Cloud).
- Ship `HoneyDrunk.Identity.Providers.Entra` package implementation per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) Phase 2.
- Wire `auth.honeydrunkstudios.com` custom domain to Entra.
- Notify Cloud tenant-operator sign-in adopts Entra ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) follow-up).
- Bicep templates for Entra App Registration provisioning land in HoneyDrunk.Actions per [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md).
- Per-application branding configuration documented per consumer-app PDR.
- Cost-monitoring per [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) tracks Entra spend against the D8 thresholds.
- Watch list: Entra External ID stewardship continues; pricing changes; Clerk's trajectory closes or doesn't close the DX gap; future enterprise-customer scenarios.

## Alternatives Considered

### Azure AD B2C

Considered briefly for completeness. The argument: B2C is mature, well-documented, broadly deployed.

Rejected per D2. B2C is being sunset for new tenants; Microsoft has signaled External ID as the successor. Adopting a sunset product is exactly the architecture-as-procrastination failure mode the charter warns against — short-term familiarity, long-term migration cost.

### Auth0

Considered. Mature, enterprise-grade, broad social-login support, mature SDK ecosystem.

Rejected on cost per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D2. The B2C / consumer tier ($240+/month for production above the free tier) is a recurring cost that does not match the charter's "lean substrate" posture for a not-yet-revenue product layer. Held as a credible alternative if Entra's developer experience proves intolerable; the wrapping-seam architecture (D7) means a future migration is bounded.

### Clerk

Considered. Best developer experience in 2026 for consumer-app signup flows; strong on passkey and social-login UX.

Rejected as leading candidate per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D2's reasoning:

- **Azure-native integration is weaker.** Managed-identity flows back to Azure resources are not first-class.
- **Pricing curve at scale is steeper than Entra's.** Free up to 10K MAU vs. Entra's ~50K MAU.
- **The multi-product-tenant scenario is non-ideal.** A single Clerk instance serving Hearth + Lately + Currents + Curiosities + Notify Cloud tenants requires more configuration than Entra's per-App-Registration model.

Strong contender for re-evaluation if Entra's developer experience disappoints in Phase 2.

### Supabase Auth

Considered. Open-source-friendly, Postgres-native, modern API.

Rejected per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D2. The credential store is developer-owned (it's just a table in the developer's Postgres) — which **negates the breach-liability argument** in D2's analysis. The whole reason to wrap an IdP is to outsource the credential-store breach surface; Supabase Auth doesn't actually do that. Rejected as redundant.

Additionally, Supabase Auth pulls in opinions about the rest of the data stack (PostgREST, Row Level Security) that conflict with the Grid's EF + Dapper + Vault pattern per [ADR-0072](./ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md).

### Self-rolled identity on the Identity Node (ASP.NET Core Identity + OpenIddict)

Considered. Maximum control; no vendor dependency.

Rejected per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D2's breach-liability analysis. A one-person studio should not be the credential-breach response team for its own users. The cost-benefit of running a credential store correctly (password hashing, breach detection, MFA, social login, account recovery, suspicious-login throttling, brute-force protection, geo-IP signal, device fingerprinting, and ongoing maintenance) is enormous; the failure mode (a credential breach) is catastrophic.

Held as the **eventual destination only** if (a) IdP costs grow large enough to justify the engineering investment and (b) the studio's security posture matures to the point of being able to operate a credential store credibly. Neither condition holds today.

### FusionAuth

Considered briefly. Self-hosted IAM platform; permissive license.

Rejected on the same self-hosting argument as Supabase Auth — the breach-liability surface stays on the operator. Plus an additional vendor (FusionAuth as the codebase) to maintain.

### Build a thin Identity Node that does not wrap an IdP at all — pure pass-through to a future IdP decision

Considered. The argument: defer the IdP decision indefinitely; ship the Identity Node with no IdP integration and add one when forced.

Rejected. Hearth's signup flow needs an IdP at Phase 2; deferring forces a Phase 2 packet that re-derives this decision. The Identity Node's scaffold (Phase 1 per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D12) does ship without an IdP adapter, but Phase 2 needs the adapter — and Phase 2 is the next packet. Settling the vendor here lets the adapter ship in Phase 2 rather than triggering a Phase 1.5 vendor-decision packet.

### Adopt multiple IdPs from day one (Entra for consumer apps, something else for tenant operators)

Considered. The argument: different audiences (consumer-app users vs. Notify Cloud tenant operators) may have different IdP fit.

Rejected. One IdP simplifies the operational story (one tenant to manage, one set of policies, one cost line, one vendor relationship). The per-App Registration model in Entra accommodates different application contexts under one IdP. The complexity of multi-IdP is not justified by any current requirement.

### Defer this ADR until Hearth is actually scaffolded

Considered. The argument: the IdP decision is most informed by concrete consumer-app needs.

Rejected. Per the forcing-functions analysis, Hearth's scaffolding work needs the IdP decision settled at start, not in the middle. Settling now adds one ADR; settling mid-Hearth-scaffolding stalls Hearth.

## References

- [`constitution/charter.md`](../constitution/charter.md) — Azure-deep posture, foundation-investment license, vendor-exit honesty
- [`constitution/invariants.md`](../constitution/invariants.md) — invariant 10 (Auth validates, never issues)
- [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) — Vault for Entra App Registration secrets
- [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) — Entra-related secret rotation
- [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) — Notify Cloud tenant-operator sign-in
- [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) — PII handling (Entra-side credentials are outside the Grid; PII↔token map is Identity-side)
- [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) — cost governance (Entra spend monitoring)
- [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) — OAuth 2.1 with PKCE
- [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) — Identity Node standup (this ADR fills D2's deferred vendor decision)
- [ADR-0072](./ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md) — EF Core (Identity's `IdentityMap` table)
- [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) — Bicep (Entra App Registration provisioning)
- [PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md) — consumer-app PDRs that consume Identity (and therefore Entra)
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) — Hearth scout pick, charter context
