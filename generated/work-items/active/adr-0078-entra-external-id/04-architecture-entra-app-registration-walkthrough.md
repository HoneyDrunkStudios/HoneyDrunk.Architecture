---
name: Infrastructure Walkthrough
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "core", "docs", "infra", "identity", "adr-0078", "wave-2"]
dependencies: ["work-item:00", "work-item:01", "work-item:02"]
adrs: ["ADR-0078", "ADR-0006", "ADR-0005", "ADR-0029", "ADR-0077"]
accepts: ADR-0078
wave: 2
initiative: adr-0078-entra-external-id
node: honeydrunk-identity
---

# Chore: Author `infrastructure/walkthroughs/entra-app-registration.md` — repeatable portal walkthrough for adding consumer-app Entra App Registrations

## Summary

Author a portal-based walkthrough at `infrastructure/walkthroughs/entra-app-registration.md` that future consumer-app feature packets (Hearth signup, Lately signup, Currents signup, Curiosities signup, and any later consumer surfaces) reference when adding a new Entra App Registration under the Grid's single External ID tenant. The walkthrough captures the Steps 3-6 portion of packet 03 (App Registration creation + user flow attachment + App Configuration key seeding + Vault secret storage for confidential-client flows), generalized for repeat use. **Bicep-based provisioning is explicitly out of scope** — queued under ADR-0077 follow-up work once Bicep's Entra resource coverage is confirmed; until then, App Registration provisioning is portal-based per ADR-0078 D6's "via a documented Portal-or-CLI workflow until Bicep's coverage closes the gap" clause.

This is a doc-only packet that runs in parallel with packet 03. Packet 03 provisions the *first* tenant + App Registration; this packet writes the *repeatable* recipe so the second/third/Nth App Registration does not re-derive the steps from scratch.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

Packet 03 of this initiative provisions the tenant + the first App Registration. The four follow-on consumer-app surfaces (Hearth, Lately, Currents, Curiosities) each need their own App Registration. Without a walkthrough doc:

- Each consumer-app feature packet re-derives the App Registration creation steps from scratch, risking drift in scopes, optional-claim configuration, redirect URI patterns, or App Configuration key naming.
- The OIDC-standards-only claim discipline (invariant 94) is enforced at the App Registration level (Step 3 of packet 03); the walkthrough must restate this so the same enforcement happens consistently for every App Registration.
- The "no Entra-proprietary claims explicitly added" rule is easy to miss in a portal flow that defaults to including some proprietary claims; the walkthrough surfaces this as a callout.
- Future App Registrations may be added by a different human (a contractor, a future hire) who has not internalized the per-app configuration shape from packet 02; the walkthrough is the self-contained reference.

This packet writes that walkthrough. It is a sibling to the other docs in `infrastructure/walkthroughs/` (e.g., `oidc-federated-credentials.md`, `key-vault-creation.md`) and follows the same `**Applies to:**` / `**Related invariants:**` / `## Goal` / `## Portal Breadcrumb` / `## Step-by-step` / `## Critical guardrails` structure.

## Proposed Implementation

### `infrastructure/walkthroughs/entra-app-registration.md` — new walkthrough

Create the file following the existing walkthrough template. Structure:

```markdown
# Entra External ID App Registration (Azure Portal)

**Applies to:** ADR-0078 (End-User Identity — Microsoft Entra External ID), ADR-0060 (Identity Node standup, Phase 2 consumer-app feature packets).
**Related invariants:** 8, 9, 10, 17, 18, 20, 21, 22, 93, 94.
**Companion docs:** `repos/HoneyDrunk.Identity/entra-configuration.md` (per-application configuration shape — what keys to seed and where), `infrastructure/walkthroughs/key-vault-creation.md` (if `kv-hd-identity-{env}` does not exist yet), `infrastructure/walkthroughs/app-configuration-provisioning.md` (if the shared App Configuration store does not exist yet).
**Bicep status:** Not yet supported. Until Bicep's Entra resource coverage closes the gap (queued under ADR-0077 follow-up work), App Registration provisioning is portal-based per ADR-0078 D6.

## Goal

Add a new consumer-app App Registration to the Grid's existing Entra External ID tenant. The App Registration owns its own client ID, redirect URIs, optional-claim configuration, user-flow attachments, and (for confidential-client flows) client secret. After this walkthrough, the consumer app has a working OAuth target ready for its feature packet.

## Portal Breadcrumb

**Azure Portal → Microsoft Entra External ID (the Grid tenant from packet 03 of adr-0078-entra-external-id) → App registrations → + New registration**

## Pre-flight

- The Grid-wide Entra External ID tenant exists (provisioned by packet 03 of `adr-0078-entra-external-id`). If it does not, complete that packet first.
- `kv-hd-identity-{env}` exists if the new App Registration uses a confidential-client flow. If absent, follow `key-vault-creation.md` first.
- The shared App Configuration store (`appcs-hd-platform-shared`) exists. If absent, follow `app-configuration-provisioning.md` first.
- You know the consumer-app short name (`hearth`, `lately`, `currents`, `curiosities`, `notify-cloud`).
- You know whether the flow is public-client (browser-based OAuth 2.1 with PKCE — the default for consumer apps) or confidential-client (server-side flow that requires a client secret).

## Step-by-step

### 1. Create the App Registration

Inside the Entra External ID tenant: **App registrations → + New registration**.

- **Name:** `HoneyDrunk {AppName}` (e.g., `HoneyDrunk Hearth`).
- **Supported account types:** Accounts in this organizational directory only.
- **Redirect URI platform:**
  - **Single-page application (SPA)** for browser-based OAuth 2.1 with PKCE (the default for consumer apps).
  - **Web** for server-side confidential-client flows.
- **Redirect URI value:** Per the redirect URI pattern from `repos/HoneyDrunk.Identity/entra-configuration.md`: `https://{app}.honeydrunkstudios.com/auth/callback`.

Click **Register**. **Record the Application (client) ID** — this goes into App Configuration as `Identity:Entra:{App}:ClientId` in Step 5.

### 2. Configure optional claims — OIDC-standard claims only (invariant 94)

Inside the new App Registration: **Token configuration → + Add optional claim** for **ID tokens**:

- `email`
- `family_name`
- `given_name`
- `preferred_username`

**Do NOT** add Entra-proprietary claims (`oid`, `tid`, `idp`, `acrs`, `acr`, etc.). Per invariant 94, application code consumes OIDC-standard claims only; Entra-proprietary claims appear in token payloads automatically but are diagnostic-only — explicit addition would signal that application code intends to consume them, violating invariant 94.

### 3. Configure API permissions

**API permissions → + Add a permission → Microsoft Graph → Delegated permissions:**

- `openid`
- `profile`
- `email`

Click **Add permissions**, then **Grant admin consent for {tenant name}**. The status column should show green checkmarks.

If the App Registration needs to call Microsoft Graph for account-deletion fan-out (per ADR-0060 D8, the `DELETE /users/{id}` call), also add:

- `User.ReadWrite.All` (Application permission, not Delegated — the deletion fan-out is a service-to-service call).

Grant admin consent for `User.ReadWrite.All` as well.

### 4. Add the client secret (confidential-client flows only)

Skip this step for SPA / public-client / PKCE flows — they do not require a client secret.

For Web / confidential-client flows:

Inside the new App Registration: **Certificates & secrets → + New client secret**.

- **Description:** `Initial client secret — {date}` (e.g., `Initial client secret — 2026-05-25`).
- **Expires:** **180 days** is the portal default; **90 days** is the invariant-20 Tier-2 SLA target. Pick 90 days if your operational schedule supports quarterly rotation; pick 180 days if you accept the documented invariant-20 exception per packet 03 of `adr-0078-entra-external-id` (see "Critical guardrails" below).
- Click **Add**.
- **Copy the secret value immediately** (the portal shows it only once).

Open **Key Vault → `kv-hd-identity-{env}` → Secrets → + Generate/Import**:

- **Upload options:** Manual.
- **Name:** `entra-app-{app}-client-secret` (e.g., `entra-app-hearth-client-secret`).
- **Secret value:** paste the copied client secret.
- Click **Create**.

### 5. Attach user flows

Inside the App Registration: **Authentication → User flows** (or via the tenant's User flows blade, select the user flow then add the App Registration as a consumer):

- Attach the sign-up + sign-in flow (`b2c_susi_default` from packet 03, or whichever exists).
- Attach the password-reset flow (`b2c_pwd_reset_default` from packet 03, or whichever exists).

If you need per-app sign-up form fields (e.g., Hearth wants a "town name" question at signup, Currents wants a "favorite genre" question), create a new user flow specific to this App Registration rather than modifying the shared default flow. Name per-app user flows `b2c_susi_{app}` and `b2c_pwd_reset_{app}`.

### 6. Seed App Configuration keys

Open **App Configuration → `appcs-hd-platform-shared` → Configuration explorer → + Create → Key-value**:

| Key | Value |
|-----|-------|
| `Identity:Entra:{App}:ClientId` | The Application (client) ID from Step 1 |
| `Identity:Entra:{App}:RedirectUri` | The redirect URI from Step 1 |
| `Identity:Entra:{App}:Scopes` | `openid,profile,email` |
| `Identity:Entra:{App}:SignUpSignInPolicy` | `b2c_susi_default` (or `b2c_susi_{app}` if per-app) |
| `Identity:Entra:{App}:PasswordResetPolicy` | `b2c_pwd_reset_default` (or `b2c_pwd_reset_{app}` if per-app) |

`{App}` is the consumer-app short name in lowercase (`hearth`, `lately`, etc.).

Per packet 02's per-application configuration shape, the Grid-wide keys (`Identity:Entra:TenantId`, `Identity:Entra:TenantIssuerUrl`, `Identity:Entra:CustomDomain`) are already seeded by packet 03 of this initiative; do not re-seed them.

### 7. Verify

In the App Registration's **Endpoints** blade, copy the OpenID Connect metadata document URL (`https://{tenant}/.well-known/openid-configuration`). Open it in a browser tab — it should return a JSON document with `issuer`, `authorization_endpoint`, `token_endpoint`, `jwks_uri`, `userinfo_endpoint`, and supported scopes including `openid profile email`.

If the JSON loads and the issuer matches `Identity:Entra:TenantIssuerUrl` from App Configuration, the App Registration is correctly wired.

## Critical guardrails

- **OIDC-standard claims only at the optional-claim configuration.** Step 2's enumeration is the entire allowed list at the App Registration level. Per invariant 94, application code consumes the OIDC-standard claim set only; Entra-proprietary claims are diagnostic-only. Adding Entra-proprietary claims to the optional-claim configuration is a boundary violation.
- **Client secret values never appear in chat / PR / chore-issue text.** Per invariant 8, only the secret name (`entra-app-{app}-client-secret`) and the Vault location (`kv-hd-identity-{env}`) are mentioned. The portal shows the value once; copy directly into Key Vault and never paste elsewhere.
- **Public-client (SPA / PKCE) flows have NO client secret.** Skip Step 4 entirely. The absence of a client secret is the security model — PKCE substitutes for the secret. Trying to add a client secret to a public-client App Registration would either fail or weaken the PKCE flow.
- **Invariant 20 exception applies if the client-secret expiry exceeds 90 days.** Per invariant 20, Tier-2 secrets ≤ 90 days unless an active exception is logged. Packet 03 of `adr-0078-entra-external-id` logged the first such exception. If you set the secret expiry to 180 days or longer, append a row to the same exception record (Log Analytics custom log or `governance/exceptions/invariant-20-entra-app-secret.md`) naming the new App Registration's secret. The long-term resolution is packet 05 of `adr-0078-entra-external-id` (ADR-0006 Tier-2 rotation extension proposal).
- **Cloudflare CNAME for `auth.honeydrunkstudios.com`** is set up Grid-wide by packet 03 of this initiative; new App Registrations do **not** add per-app DNS records — they use the same custom-domain endpoint. Per-app subdomains (e.g., `hearth.honeydrunkstudios.com`) are the *redirect target*, not the *Entra endpoint*; the redirect target's DNS is the responsibility of the consumer-app's hosting setup (Container App, Vercel, etc. per the app's own infrastructure).
- **Diagnostic settings.** If `kv-hd-identity-{env}` does not yet have diagnostic settings routed to the shared Log Analytics workspace, configure them now per invariant 22 (required for rotation SLA monitoring, unauthorized access alerting, and audit).
- **Tags.** Apply `env={env}`, `node=identity` (the App Registration is per-Identity-Node-application surface) to the App Registration's Notes / Tags blade (Entra App Registrations support a small notes field; longer tagging metadata may need to live in the App Configuration key descriptions instead).
- **Bicep replacement is coming.** Once Bicep's Entra resource coverage matures and the ADR-0077 follow-up packet for Entra App Registration provisioning lands, this walkthrough may be deprecated in favor of a `bicep deploy` recipe. The walkthrough is the bridge until then.

## Verification checklist (after walkthrough completes)

- [ ] App Registration exists under the Grid Entra tenant with name `HoneyDrunk {AppName}`.
- [ ] Redirect URI is `https://{app}.honeydrunkstudios.com/auth/callback` (SPA platform for PKCE; Web platform for confidential-client).
- [ ] Optional claims configured: `email`, `family_name`, `given_name`, `preferred_username`. No Entra-proprietary claims explicitly added.
- [ ] API permissions: `openid`, `profile`, `email` (Delegated, admin-consented). `User.ReadWrite.All` (Application, admin-consented) if account-deletion fan-out is needed.
- [ ] Client secret (confidential-client only): stored in `kv-hd-identity-{env}` as `entra-app-{app}-client-secret`. Expiry recorded with associated invariant-20 exception entry if > 90 days.
- [ ] User flows attached (sign-up + sign-in; password reset).
- [ ] App Configuration keys seeded under `Identity:Entra:{App}:*`.
- [ ] OIDC metadata document loads at `https://{tenant}/.well-known/openid-configuration` and matches App Configuration `Identity:Entra:TenantIssuerUrl`.
- [ ] If client-secret expiry > 90 days: invariant-20 exception record updated.
- [ ] Diagnostic settings on `kv-hd-identity-{env}` routed to the shared Log Analytics workspace (invariant 22).
- [ ] Cost check: $0 incremental (the App Registration itself is free under the 50K-MAU tier per ADR-0078 D8).
```

### `CHANGELOG.md` (Architecture repo)

Append to the current dated SemVer section:

> `Architecture: Author infrastructure/walkthroughs/entra-app-registration.md — repeatable portal walkthrough for adding consumer-app Entra App Registrations under the Grid's single External ID tenant per ADR-0078 D1 / D6. Captures App Registration creation, optional-claim configuration (OIDC-standard claims only per invariant 94), API permissions, client-secret handling for confidential-client flows (with invariant-20 exception cross-reference to packet 03), user-flow attachment, App Configuration key seeding, and verification via the OIDC metadata document. Bicep-based provisioning explicitly out of scope — queued under ADR-0077 follow-up work; portal-based until Bicep's Entra resource coverage closes the gap per ADR-0078 D6.`

## Affected Files

- `infrastructure/walkthroughs/entra-app-registration.md` (new)
- `CHANGELOG.md` (entry under current dated SemVer section)

## NuGet Dependencies

None. Architecture is a knowledge repo.

## Boundary Check

- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No code changes; doc-only.
- [x] No new infrastructure provisioning — this packet writes the *recipe*, not the *first instance*; the first instance is packet 03 of this initiative.
- [x] Walkthrough follows the existing `infrastructure/walkthroughs/` template structure (Applies to / Related invariants / Goal / Portal Breadcrumb / Step-by-step / Critical guardrails).
- [x] Bicep stance explicitly recorded — portal until Bicep's Entra coverage matures, then ADR-0077 follow-up swaps in `bicep deploy`.

## Acceptance Criteria

- [ ] `infrastructure/walkthroughs/entra-app-registration.md` exists and is structured per the template above.
- [ ] The walkthrough's **OIDC-standard claims only** section (Step 2) explicitly enumerates the allowed claims (`email`, `family_name`, `given_name`, `preferred_username`) and explicitly forbids adding Entra-proprietary claims (`oid`, `tid`, `idp`, `acrs`, `acr`).
- [ ] The walkthrough's **client-secret** section (Step 4) covers the public-client-no-secret case explicitly and the confidential-client-with-secret case with Vault storage at `entra-app-{app}-client-secret` in `kv-hd-identity-{env}`.
- [ ] The walkthrough's **Critical guardrails** section covers: invariant 8 (no secret values in chat/PR/issue text), invariant 94 (OIDC-standard claims only), invariant 20 (client-secret expiry > 90 days triggers exception entry), invariant 22 (Vault diagnostic settings), and the Bicep-replacement note.
- [ ] The walkthrough's **Verification checklist** is a flat checkbox list capturing every step's success condition.
- [ ] The walkthrough cross-links to `repos/HoneyDrunk.Identity/entra-configuration.md` (packet 02's per-application configuration shape doc) and to packet 03 of this initiative (for the first tenant + App Registration setup that this walkthrough generalizes from).
- [ ] The walkthrough cross-links to `infrastructure/walkthroughs/key-vault-creation.md` and `infrastructure/walkthroughs/app-configuration-provisioning.md` as pre-flight dependencies.
- [ ] Bicep-deferred status is explicitly recorded in the doc preamble (under "Bicep status:").
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section.

## Human Prerequisites

- [ ] Packets 00, 01, 02 of this initiative merged to `main` (the invariants 93/94, the catalog updates, and the per-application configuration shape doc must all be in place — the walkthrough cross-links to them).
- [ ] Packet 03 of this initiative is **not** a strict prerequisite for *this* doc-authoring packet; the doc can be written in parallel with the provisioning work. (Packet 03 is a strict prerequisite for *using* the walkthrough — you can't add a second App Registration before the first tenant exists.)

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. — The walkthrough's Critical guardrails section restates this and operationalizes it: copy the client secret from the Entra portal directly into the Key Vault portal; never paste it into chat / PR / issue text.

> **Invariant 9:** Vault is the only source of secrets. — The walkthrough stores client secrets in `kv-hd-identity-{env}` only; application code reads via `ISecretStore` (covered by packet 02's per-application configuration shape doc).

> **Invariant 10:** Auth tokens are validated, never issued. — The walkthrough is provisioning-only; token validation stays in `HoneyDrunk.Auth` per ADR-0078 D5.

> **Invariant 17:** One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}`. — Client secrets live in `kv-hd-identity-{env}`.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. — The walkthrough seeds App Configuration keys; the App Configuration endpoint itself reaches Identity via `AZURE_APPCONFIG_ENDPOINT` per ADR-0005.

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. Tier 2 (third-party via rotation Function): ≤ 90 days. Exceptions must be logged in Log Analytics. — Step 4's secret-expiry guidance cross-references the invariant; the Critical guardrails section explicitly directs the operator to update the invariant-20 exception record if expiry > 90 days.

> **Invariant 21:** Applications must never pin to a specific secret version. — Vault entries are read latest-version through `ISecretStore`; manual rotation creates new versions that consumers pick up automatically.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. — The walkthrough's Critical guardrails section reminds the operator to configure diagnostic settings on `kv-hd-identity-{env}` if not yet done.

> **Invariant 93 (pending packet 00):** End-user identity tokens are issued by Microsoft Entra External ID. — Every App Registration this walkthrough creates is under the Grid's single Entra External ID tenant, satisfying the invariant.

> **Invariant 94 (pending packet 00):** Application code consumes OIDC-standard claims only from Entra-issued tokens. — The walkthrough's Step 2 (optional-claim configuration) and Critical guardrails enforce the discipline at the configuration boundary.

## Referenced ADR Decisions

**ADR-0078 D1 — Microsoft Entra External ID is the end-user IdP.** Single Grid-wide tenant; per-application App Registrations. The walkthrough is the recipe for adding the per-application App Registrations.

**ADR-0078 D3 — OIDC-standard claims only.** The walkthrough's Step 2 (optional-claim configuration) enforces this at the App Registration level.

**ADR-0078 D5 — Token validation stays in `HoneyDrunk.Auth` per Invariant 10.** The walkthrough is provisioning-only; no validation logic.

**ADR-0078 D6 — Per-application configuration shape.** The walkthrough's Step 6 (App Configuration key seeding) implements the schema documented in packet 02. The "Bicep-or-Portal until coverage closes the gap" clause is the explicit license for this walkthrough's portal-based approach.

**ADR-0006 (Secret Rotation and Lifecycle):** The walkthrough's Step 4 (client-secret expiry) cross-references invariant 20; long-term resolution is packet 05 of this initiative (ADR-0006 Tier-2 rotation extension proposal).

**ADR-0005 D1 — Per-Node per-environment Key Vault.** `kv-hd-identity-{env}` is the Vault home.

**ADR-0005 D3 — Per-Node App Configuration namespace.** `Identity:Entra:{App}:*` is the namespace.

**ADR-0029 (Cloudflare DNS):** Custom-domain wiring is handled Grid-wide in packet 03; per-App-Registration walkthroughs do not add DNS records.

**ADR-0077 (Infrastructure-as-Code — Bicep):** The walkthrough is portal-based today per ADR-0078 D6's explicit Bicep-or-Portal clause. A future ADR-0077 follow-up packet may add Bicep templates for Entra App Registrations and deprecate this walkthrough in favor of `bicep deploy`.

**ADR-0060 D2 — Wrap external IdP.** The App Registration is the IdP-side concrete; the wrapping seam (`IExternalIdpClaimMapper`) and the runtime adapter (`HoneyDrunk.Identity.Providers.Entra`) consume the App Registration's client ID + secret + scopes via the App Configuration keys this walkthrough seeds.

## Dependencies

- `work-item:00` — ADR-0078 acceptance + invariants 93/94. The walkthrough cites invariant 94 by number.
- `work-item:01` — Catalog updates. The walkthrough references the contracts.json `notes:` field text indirectly via the seam architecture description.
- `work-item:02` — Per-application configuration shape doc. The walkthrough cross-links to it as the schema source for the App Configuration keys.

## Labels

`chore`, `tier-2`, `core`, `docs`, `infra`, `identity`, `adr-0078`, `wave-2`

## Agent Handoff

**Objective:** Author `infrastructure/walkthroughs/entra-app-registration.md` — the repeatable portal walkthrough for adding consumer-app Entra App Registrations under the Grid's single Entra External ID tenant. Generalizes Steps 3-6 of packet 03 for re-use by every subsequent consumer-app feature packet.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make App Registration provisioning a repeatable recipe rather than a re-derive-from-scratch effort for every consumer app. Restate the OIDC-standards-only discipline (invariant 94) at the configuration boundary so each App Registration enforces it consistently.
- Feature: ADR-0078 End-User Identity rollout, Wave 2, Packet 04.
- ADRs: ADR-0078 D1 / D3 / D5 / D6 (Entra commitment + OIDC-standards discipline + per-app config shape + Portal-or-Bicep clause), ADR-0006 (invariant-20 rotation cadence cross-reference), ADR-0005 (Vault + App Configuration), ADR-0029 (Cloudflare DNS already handled by packet 03), ADR-0077 (Bicep stance — out of scope today, may swap in later).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 00, 01, 02 of this initiative.

**Constraints:**
- The walkthrough must follow the existing `infrastructure/walkthroughs/` template structure (Applies to / Related invariants / Goal / Portal Breadcrumb / Step-by-step / Critical guardrails / Verification checklist).
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. — Critical guardrails restate this and operationalize it.
- **Invariant 94 (pending packet 00):** Application code consumes OIDC-standard claims only from Entra-issued tokens. — Step 2 (optional-claim configuration) enforces this at the App Registration boundary and Critical guardrails restate the forbiddance of Entra-proprietary claims.
- **Invariant 20:** Tier-2 secrets ≤ 90 days unless an active exception is logged in Log Analytics. — Step 4 cross-references the invariant; Critical guardrails direct the operator to update the invariant-20 exception record if expiry > 90 days.
- Bicep-deferred status must be explicit in the doc preamble — the walkthrough is the bridge until Bicep's Entra coverage matures per ADR-0078 D6.
- The walkthrough must cross-link to `repos/HoneyDrunk.Identity/entra-configuration.md` (packet 02 of this initiative) and packet 03 of this initiative.
- Public-client (SPA / PKCE) vs confidential-client (Web + secret) distinction must be explicit; do not let a reader accidentally add a client secret to a public-client App Registration.

**Key Files:**
- `infrastructure/walkthroughs/entra-app-registration.md` — new
- `CHANGELOG.md` — append under current dated SemVer section

**Contracts:** None changed. The walkthrough is operational documentation.
