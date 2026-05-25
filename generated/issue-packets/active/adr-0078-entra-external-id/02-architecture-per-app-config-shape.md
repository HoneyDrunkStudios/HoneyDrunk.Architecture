---
name: Architecture Docs Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "core", "docs", "identity", "adr-0078", "wave-2"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0078", "ADR-0060", "ADR-0005"]
accepts: ADR-0078
wave: 2
initiative: adr-0078-entra-external-id
node: honeydrunk-identity
---

# Chore: Document the per-application Entra configuration shape — App Configuration keys, Vault secret naming, claim-mapper reference

## Summary

Author the per-application Entra External ID configuration shape per ADR-0078 D6 as a reference doc that the first consumer-app feature packet (Hearth signup per PDR-0005, then Lately / Currents / Curiosities / Notify Cloud tenant operators) consumes when wiring its OAuth flow. The doc lives at `repos/HoneyDrunk.Identity/entra-configuration.md` and covers: per-application Azure App Configuration key naming (`Identity:Entra:{App}:{Key}`), per-application Vault secret naming (`entra-app-{app}-client-secret` where confidential-client flows are used), the redirect URI pattern, the tenant-issuer URL pattern, the OIDC-standard claim mapping reference for the `IExternalIdpClaimMapper` Entra implementation, and the diagnostic-vs-load-bearing distinction for Entra-proprietary claims per invariant 94.

This is a doc-only packet — no code, no Bicep, no Azure provisioning. The Bicep templates land later (under ADR-0077 follow-up work once Bicep's Entra resource coverage is confirmed); the actual Azure App Configuration / Vault seeding happens in the first consumer-app feature packet that pulls on Identity. This packet writes the *shape* so those later packets have an unambiguous target.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0078 D6 names the per-application configuration shape but does not commit specific App Configuration key names, Vault secret names, or redirect URI patterns. Without a documented shape:

- The first consumer-app feature packet (Hearth signup) has to derive the App Configuration key naming from scratch, risking inconsistency with ADR-0005's `Identity:*` namespace pattern.
- The `HoneyDrunk.Identity.Providers.Entra` package's `IExternalIdpClaimMapper` implementation has no reference for which Entra token claims map to which `UserProfile` / `ExternalSubject` fields and which Entra-proprietary claims to log diagnostically without using them in application logic (invariant 94).
- The OIDC-standard-claims-only discipline (D3 / invariant 94) is a rule without a positive example — agents may accidentally consume `oid` or `tid` if there's no concrete "use these, log these but don't branch on these" reference.

This packet writes that reference doc. It is the architectural contract every consumer-app feature packet's Entra wiring will read.

## Proposed Implementation

### `repos/HoneyDrunk.Identity/entra-configuration.md` — new reference doc

Create a new file in the Identity context folder. The file is a reference doc consumed by feature packets, not by runtime code. Structure:

```markdown
# Microsoft Entra External ID — Per-Application Configuration Shape

**ADR:** [ADR-0078](../../adrs/ADR-0078-end-user-identity-entra-external-id.md) (Accepted)
**Companion ADR:** [ADR-0060](../../adrs/ADR-0060-stand-up-honeydrunk-identity-node.md) (the Identity Node standup)
**Audience:** Consumer-app feature packets (Hearth signup, Lately signup, Currents signup, Curiosities signup, Notify Cloud tenant-operator sign-in) wiring their first OAuth flow against the Grid's Entra tenant.

## Tenant Topology (Reminder)

- **One** Grid-wide Entra External ID tenant. Tenant identifier finalized at provisioning (packet 03 of adr-0078-entra-external-id).
- **One App Registration per consumer-app** (Hearth, Lately, Currents, Curiosities) **plus one** for Notify Cloud tenant operators.
- Each App Registration has its own client ID, redirect URIs, branding, and (if confidential-client) its own client secret.
- All App Registrations share the same tenant-issuer URL (the Grid tenant's `https://{tenant-id}.ciamlogin.com/{tenant-id}/v2.0` endpoint).
- Custom domain: `auth.honeydrunkstudios.com` is wired to the tenant per ADR-0078 D1 / "Operational Consequences"; consumer-app OAuth flows redirect through the custom domain, not the raw `*.ciamlogin.com` URL.

## App Configuration Keys (Non-Secret)

Per ADR-0005 (Configuration and Secrets Strategy), non-secret per-application config lives in Azure App Configuration under the `Identity:*` namespace. Per-application keys follow this shape:

| Key | Type | Description |
|-----|------|-------------|
| `Identity:Entra:TenantId` | string (GUID) | The Grid-wide Entra External ID tenant ID. Shared across all consumer apps. |
| `Identity:Entra:TenantIssuerUrl` | string (URL) | The OIDC issuer URL for the Grid tenant. Shared across all consumer apps. |
| `Identity:Entra:CustomDomain` | string (FQDN) | `auth.honeydrunkstudios.com`. Shared. |
| `Identity:Entra:{App}:ClientId` | string (GUID) | The App Registration's client ID. Per-application (one per consumer app). |
| `Identity:Entra:{App}:RedirectUri` | string (URL) | The OAuth callback URL for this app. Per-application. |
| `Identity:Entra:{App}:Scopes` | string (CSV) | The OIDC scopes this app requests. Default: `openid,profile,email`. |
| `Identity:Entra:{App}:SignUpSignInPolicy` | string | The Entra user-flow name for sign-up + sign-in. Per-application. |
| `Identity:Entra:{App}:PasswordResetPolicy` | string | The Entra user-flow name for password reset. Per-application. |

`{App}` is the lowercase consumer-app short name: `hearth`, `lately`, `currents`, `curiosities`, `notify-cloud`. Example concrete key: `Identity:Entra:Hearth:ClientId`.

## Vault Secret Names (Confidential-Client Flows Only)

Per [ADR-0005](../../adrs/ADR-0005-configuration-and-secrets-strategy.md), per-application secrets live in `kv-hd-identity-{env}` (Identity's per-Node Key Vault per invariant 17). Per-application client-secret names follow this shape:

| Secret Name | Description |
|-------------|-------------|
| `entra-app-{app}-client-secret` | Entra App Registration's client secret. **Only present for confidential-client flows.** Public-client flows (browser-based OAuth 2.1 with PKCE — the default for consumer apps) do not have a client secret and have no entry here. |

`{app}` is the same lowercase consumer-app short name as the App Configuration keys. Example: `entra-app-hearth-client-secret`.

## Redirect URI Pattern

Each consumer app's redirect URI follows this pattern:

```
https://{app}.honeydrunkstudios.com/auth/callback
```

Examples (concrete redirect URIs are committed at consumer-app provisioning time; this is the pattern):

- `https://hearth.honeydrunkstudios.com/auth/callback`
- `https://lately.honeydrunkstudios.com/auth/callback`
- `https://currents.honeydrunkstudios.com/auth/callback`
- `https://curiosities.honeydrunkstudios.com/auth/callback`
- `https://notify-cloud.honeydrunkstudios.com/auth/callback`

For local dev: each consumer app may register a `https://localhost:{port}/auth/callback` URI on its App Registration. The dev redirect URI is registered in addition to the production one.

## OIDC Claim Mapping (Reference for `IExternalIdpClaimMapper` Entra implementation)

The Entra implementation of `IExternalIdpClaimMapper` (the package `HoneyDrunk.Identity.Providers.Entra`) maps the OIDC-standard claims from Entra-issued tokens to internal Identity types. **OIDC-standard claims only are load-bearing in application logic per ADR-0078 D3 and invariant 94.** Entra-proprietary claims are logged diagnostically and never branched on.

### Load-Bearing OIDC-Standard Claims

| Claim | Maps to | Notes |
|-------|---------|-------|
| `sub` | `ExternalSubject.Subject` | The IdP subject identifier. Resolved via `IUserDirectory` to `UserId`. |
| `iss` | `ExternalSubject.Issuer` | The IdP issuer URL. Stored alongside `sub` so two `sub: abc123` from different issuers are distinguishable. |
| `aud` | (validation only — not stored) | The audience claim. Validated against the App Registration's client ID by `HoneyDrunk.Auth.IJwtBearerValidator` per ADR-0078 D5 and invariant 10. |
| `exp`, `iat`, `nbf` | (validation only — not stored) | Token lifetime claims. Validated by `HoneyDrunk.Auth.IJwtBearerValidator`. |
| `email` | `UserProfile.Email` (canonical) | The user's primary email address. Required for `IIdentityDeletionFanout` user-level GDPR Art. 17 lookups. |
| `email_verified` | `UserRecord.EmailVerified` | Whether Entra has verified the email. Drives the `UserLifecycleStatus` transition from `PendingVerification` to `Active`. |
| `name` | `UserProfile.DisplayName` (initial value) | Display name; user can edit in-app after signup. |
| `given_name`, `family_name` | (informational — not stored as canonical) | Available but `UserProfile.DisplayName` is the canonical name field. |
| `preferred_username` | `UserProfile.PreferredUsername` | Display-name candidate. Per ADR-0060 D5 the profile is mutable post-signup. |

### Diagnostic-Only Entra-Proprietary Claims

Per invariant 94, these claims are logged in diagnostic-tier logs (per ADR-0049 data classification, these are PII / `Sensitive` and never leave the audit boundary) but are **never branched on in application logic**:

| Claim | Why it's diagnostic-only |
|-------|--------------------------|
| `oid` | Entra's own object ID for the user. Locks application code to Entra; the canonical user-identity key is `UserId`, resolved from `sub`. |
| `tid` | Entra tenant ID. The Grid uses a single Entra tenant — `tid` is always the Grid tenant. Logging is fine; branching on `tid` is forbidden. |
| `idp` | The upstream IdP for federated sign-in (e.g., `google.com` when the user signed in with Google). Useful for support diagnostics; never used in authorization decisions. |
| `acrs`, `acr` | Authentication context references. Entra-specific format; the Grid does not consume these in policy decisions. MFA enforcement, if added, uses Entra's user-flow policy enforcement, not claim inspection. |
| Any other non-OIDC-standard claim | Diagnostic-only by default per invariant 94. |

**Code-level enforcement:** the Entra implementation of `IExternalIdpClaimMapper` extracts only the load-bearing OIDC-standard claims into the returned mapping. Diagnostic claims may be passed to `ITraceEnricher` for inclusion in OpenTelemetry spans (subject to ADR-0049 PII-handling rules) but must not appear in the mapper's returned `UserPrincipal` / `UserProfile` shape.

## Vendor-Exit Hedge in Practice

The OIDC-standards-only discipline (D3 / invariant 94) is the cheap vendor-exit hedge. Concretely:

- A future migration to **Clerk** would replace `HoneyDrunk.Identity.Providers.Entra` with `HoneyDrunk.Identity.Providers.Clerk`. The new provider implements the same `IExternalIdpClaimMapper`. Since application code consumes only OIDC-standard claims (which Clerk also emits per the OIDC spec), no application-code rework is needed.
- A future migration to **self-hosted OpenIddict** would replace the provider package with `HoneyDrunk.Identity.Providers.OpenIddict`. Same `IExternalIdpClaimMapper` contract; same OIDC-standard claims.
- The migration cost is bounded to: (a) re-keying user credentials (users authenticate against the new IdP at next login); (b) swapping the provider package; (c) updating the App Configuration `Identity:Entra:*` keys to the new provider's equivalents.

The user record (`UserRecord`, `UserProfile`, `IdentityMap`) and the application code stay intact — see ADR-0078 D7.

## What This Doc Does NOT Cover

- **Bicep provisioning templates for Entra App Registrations.** Queued under ADR-0077 follow-up work once Bicep's Entra resource coverage is confirmed. Until then, App Registration provisioning is portal-based (see packet 04 of this initiative for the walkthrough).
- **The first concrete OAuth flow implementation.** That ships with the first consumer-app feature packet — Hearth signup per PDR-0005 Phase 2.
- **MFA enforcement policy.** Per ADR-0078 D10, MFA defaults to "optional, user-enrollable" at v1. Per-app policy hardens later.
- **Social-login provider enablement.** Per ADR-0078 D10, default is "email-only" at v1. Per-app may add Google / Apple / GitHub later.
- **Tenant-scoped Entra setup for Notify Cloud organizational sign-in.** Notify Cloud-side concern; see ADR-0027 follow-up.
- **Client-secret rotation cadence.** Tier-2 ≤ 90 days per invariant 20. Operational burden documented as a Constraint on packet 03 of this initiative. The ADR-0006 Tier-2 rotation extension proposal (allowing longer secret lifetimes with documented exception) is packet 05 of this initiative.
```

### `CHANGELOG.md` (Architecture repo)

Append to the current dated SemVer section:

> `Architecture: Author repos/HoneyDrunk.Identity/entra-configuration.md — per-application Entra External ID configuration shape per ADR-0078 D6. Documents the Azure App Configuration key namespace (Identity:Entra:{App}:{Key}), Vault secret naming (entra-app-{app}-client-secret in kv-hd-identity-{env} per invariant 17 and ADR-0005), redirect URI pattern (https://{app}.honeydrunkstudios.com/auth/callback), OIDC-standard claim mapping reference for the IExternalIdpClaimMapper Entra implementation, and the diagnostic-only-vs-load-bearing distinction for Entra-proprietary claims per invariant 94. Doc-only — no code, no Bicep, no Azure provisioning.`

## Affected Files

- `repos/HoneyDrunk.Identity/entra-configuration.md` (new)
- `CHANGELOG.md` (append under current dated SemVer section)

## NuGet Dependencies

None. Architecture is a knowledge repo.

## Boundary Check

- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No code changes, no Bicep changes, no Azure provisioning.
- [x] No contract surface changes — the doc references existing contracts (`IExternalIdpClaimMapper`, `UserRecord`, `UserProfile`, `ExternalSubject`, `IUserDirectory`, `IIdentityDeletionFanout`) from ADR-0060 D4 without adding new ones.
- [x] App Configuration namespace (`Identity:*`) follows ADR-0005 D3 (per-Node configuration namespaces).
- [x] Vault secret naming (`kv-hd-identity-{env}` + `entra-app-{app}-client-secret`) follows ADR-0005 D1 (per-Node per-environment Key Vault) and invariant 17.

## Acceptance Criteria

- [ ] `repos/HoneyDrunk.Identity/entra-configuration.md` exists and is structured as described above.
- [ ] App Configuration key namespace is `Identity:Entra:{App}:{Key}` — never an Entra-proprietary or top-level namespace.
- [ ] Vault secret name pattern is `entra-app-{app}-client-secret` and explicitly notes that public-client flows (browser-based OAuth 2.1 with PKCE) do not have a client secret.
- [ ] Redirect URI pattern is `https://{app}.honeydrunkstudios.com/auth/callback` and lists concrete examples for the five consumer-app surfaces (Hearth, Lately, Currents, Curiosities, Notify Cloud).
- [ ] OIDC claim mapping table lists `sub`, `iss`, `aud`, `exp`, `iat`, `nbf`, `email`, `email_verified`, `name`, `given_name`, `family_name`, `preferred_username` and shows what each maps to inside the Identity contracts.
- [ ] Diagnostic-only-claims table lists `oid`, `tid`, `idp`, `acrs`, `acr` and explicitly states they are never load-bearing in application logic per invariant 94.
- [ ] Vendor-exit-hedge section walks through a Clerk migration and a self-hosted OpenIddict migration as concrete examples.
- [ ] "What This Doc Does NOT Cover" section explicitly defers Bicep provisioning, the first concrete OAuth flow implementation, MFA enforcement policy, social-login enablement, tenant-scoped Entra setup, and client-secret rotation cadence to other packets or future work.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section.
- [ ] No code changes, no Bicep changes, no Azure provisioning in this packet.

## Human Prerequisites

- [ ] **ADR-0060 packet 01 must be merged to `main` before this packet executes.** Packet 01 of the adr-0060-identity-standup initiative creates the `repos/HoneyDrunk.Identity/` folder this packet adds a new file to. Confirmation: `ls repos/HoneyDrunk.Identity/` should succeed.
- [ ] Packet 00 of this initiative (ADR-0078 acceptance + invariants 93/94) must be merged so the doc's references to invariant 94 by number are not forward-pointing.
- [ ] Packet 01 of this initiative (catalog updates) must be merged so the contracts.json `notes:` field and the Identity context-file amendments referencing Entra are in place — the doc this packet writes cross-links to those.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — `HoneyDrunk.Identity.Abstractions` (containing `IExternalIdpClaimMapper`) stays vendor-agnostic. The Entra-specific implementation lives in `HoneyDrunk.Identity.Providers.Entra` per ADR-0078 D4. This doc records that boundary at the configuration shape level.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. — Client secrets for confidential-client App Registrations live in `kv-hd-identity-{env}` and resolve through `ISecretStore`. This doc documents the secret naming pattern.

> **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Entra-issued tokens are validated by `HoneyDrunk.Auth.IJwtBearerValidator` against Entra's JWKS. The doc records that the `aud`, `exp`, `iat`, `nbf` claims are validation-only and not stored.

> **Invariant 17:** One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}`. — The doc names `kv-hd-identity-{env}` as the home for Entra App Registration client secrets.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. — The doc references the App Configuration namespace `Identity:Entra:*`; the App Configuration endpoint itself reaches Identity via `AZURE_APPCONFIG_ENDPOINT` per ADR-0005.

> **Invariant 21:** Applications must never pin to a specific secret version. — Client secrets in the Vault are read latest-version through `ISecretStore`; no version pinning.

> **Invariant 94 (Proposed — pending ADR-0078 acceptance via packet 00):** Application code consumes OIDC-standard claims only from Entra-issued tokens. — The doc's claim-mapping table is the positive enforcement: only OIDC-standard claims are mapped into application-visible Identity types; Entra-proprietary claims are diagnostic-only.

## Referenced ADR Decisions

**ADR-0078 D1 — Microsoft Entra External ID is the end-user IdP.** Single Grid-wide tenant; per-application App Registrations; OAuth 2.1 with PKCE on OpenID Connect.

**ADR-0078 D3 — OIDC-standard claims only.** Restated as invariant 94. This doc's claim-mapping table is the operational reference.

**ADR-0078 D4 — `HoneyDrunk.Identity` is the seam; Entra is the provider.** `HoneyDrunk.Identity.Providers.Entra` is the package that implements `IExternalIdpClaimMapper` against Entra External ID.

**ADR-0078 D5 — Token validation stays in `HoneyDrunk.Auth` per Invariant 10.** The doc's claim-mapping table records that `aud`, `exp`, `iat`, `nbf` are validation-only (not stored in the mapping result).

**ADR-0078 D6 — Per-application configuration shape.** App Registration ID in App Configuration; tenant-issuer URL; redirect URIs; app-specific branding. This doc commits the specific key names, secret names, and redirect URI patterns.

**ADR-0078 D7 — Migration path away from Entra.** The wrapping seam from ADR-0060 D2 plus the OIDC-standards-only discipline (D3) bound the migration cost. The doc's "Vendor-Exit Hedge in Practice" section walks through concrete migration shapes (Clerk, OpenIddict).

**ADR-0005 D1 — Per-Node per-environment Key Vault.** `kv-hd-identity-{env}` is Identity's Vault.

**ADR-0005 D3 — Per-Node App Configuration namespace.** `Identity:*` is Identity's namespace; `Identity:Entra:*` is the Entra-vendor-specific subspace.

**ADR-0060 D2 — Wrap external IdP.** The vendor-agnostic interface (`IExternalIdpClaimMapper`) stays vendor-agnostic; vendor commitment is at the configuration / package-binding level.

**ADR-0060 D4 — Exposed contracts.** `IExternalIdpClaimMapper`, `UserRecord`, `UserProfile`, `ExternalSubject`, `IUserDirectory`, `IIdentityDeletionFanout` are referenced by this doc but not modified.

## Dependencies

- `packet:00` — ADR-0078 acceptance + invariants 93/94. This doc references invariant 94 by number.
- `packet:01` — Catalog updates. This doc cross-links to the Identity context-file amendments and the `notes:` field text in `contracts.json`.

## Labels

`chore`, `tier-2`, `core`, `docs`, `identity`, `adr-0078`, `wave-2`

## Agent Handoff

**Objective:** Author `repos/HoneyDrunk.Identity/entra-configuration.md` — the per-application Entra External ID configuration shape per ADR-0078 D6. The doc is the architectural contract every consumer-app feature packet's Entra wiring reads when implementing its OAuth flow.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Commit the concrete configuration shape so consumer-app feature packets (Hearth signup first) do not re-derive the App Configuration key naming, Vault secret naming, redirect URI pattern, or claim-mapping behavior from scratch.
- Feature: ADR-0078 End-User Identity rollout, Wave 2, Packet 02.
- ADRs: ADR-0078 D1 / D3 / D4 / D5 / D6 / D7 (the vendor decision and discipline), ADR-0060 D2 / D4 (the seam architecture and exposed contracts), ADR-0005 D1 / D3 (Vault + App Configuration shape).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 00 and 01 of this initiative.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. — `IExternalIdpClaimMapper` lives in `HoneyDrunk.Identity.Abstractions`; the Entra implementation is in `HoneyDrunk.Identity.Providers.Entra`. The doc records that split at the package binding level.
- **Invariant 9:** Vault is the only source of secrets. — Client secrets live in `kv-hd-identity-{env}` only; never in env vars or config files.
- **Invariant 10:** Auth tokens are validated, never issued. — The doc records that `aud`, `exp`, `iat`, `nbf` claims are validation-only and not part of the mapping result.
- **Invariant 17:** One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}`. — Identity's Vault is `kv-hd-identity-{env}`.
- **Invariant 21:** Applications must never pin to a specific secret version. — Secret reads through `ISecretStore` resolve latest-version automatically.
- **Invariant 94:** Application code consumes OIDC-standard claims only from Entra-issued tokens. — The doc's claim-mapping table is the positive enforcement reference.
- The doc must not invent new contracts. It references existing Identity contracts from ADR-0060 D4 (`IExternalIdpClaimMapper`, `UserRecord`, `UserProfile`, `ExternalSubject`, `IUserDirectory`, `IIdentityDeletionFanout`) without adding new ones.
- The doc must not include Bicep templates or Azure provisioning steps. Those are out of scope (see "What This Doc Does NOT Cover" section).
- App Configuration key namespace must be `Identity:Entra:{App}:{Key}` — never Entra-proprietary or top-level.
- Vault secret naming pattern: `entra-app-{app}-client-secret` in `kv-hd-identity-{env}`.
- Redirect URI pattern: `https://{app}.honeydrunkstudios.com/auth/callback`.

**Key Files:**
- `repos/HoneyDrunk.Identity/entra-configuration.md` — new
- `CHANGELOG.md` — append under current dated SemVer section

**Contracts:** None changed. The doc references existing contracts; it does not author new ones.
