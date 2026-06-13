---
name: Infrastructure Provisioning
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "core", "infra", "identity", "adr-0078", "human-only", "wave-2"]
dependencies: ["work-item:00", "work-item:01", "work-item:02"]
adrs: ["ADR-0078", "ADR-0006", "ADR-0005", "ADR-0029"]
accepts: ADR-0078
wave: 2
initiative: adr-0078-entra-external-id
node: honeydrunk-identity
---

# Chore: Provision Entra External ID tenant + first App Registration + verify/create `rg-hd-platform-shared` + custom-domain prep (human-only)

## Summary

Provision the Grid's single Entra External ID tenant per ADR-0078 D1, create the first App Registration (Notify Cloud tenant operators by default, or Hearth if Hearth signup is ready first), verify-or-create the `rg-hd-platform-shared` resource group (the home for Grid-wide shared resources that are not per-Node), wire the custom domain `auth.honeydrunkstudios.com` per ADR-0078 D1 "Operational Consequences" + ADR-0029 (Cloudflare DNS), and **log the active invariant-20 exception** for Entra App Registration client-secret rotation cadence (Entra defaults to 24-month secret expiration, which exceeds invariant 20's Tier-2 ≤ 90-day SLA; the exception is logged in Log Analytics per invariant 20's documented exception clause until the ADR-0006 Tier-2 rotation extension (packet 05 of this initiative) lands).

This is **`Actor=Human`** — every step is portal-based (Azure portal + Cloudflare portal + Microsoft Graph API for tenant creation). No agent can execute portal clicks for the Entra tenant creation, the App Registration setup, the resource-group creation, the custom-domain wiring, or the Cloudflare CNAME record. Frontmatter sets `labels: ["human-only", ...]` per the user's source-of-truth convention.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens in the Azure portal + Cloudflare portal + Log Analytics)

## Actor

**`Human`.** Tenant creation, App Registration creation, resource-group creation, custom-domain DNS wiring, and the invariant-20 exception log entry all require portal access. Frontmatter sets `labels: ["human-only", ...]` which is the source-of-truth per the user's convention (the visual `Actor` pill on The Hive defaults to `Agent` unless the `human-only` label is present).

## Motivation

ADR-0078 names Entra External ID as the committed end-user IdP. The infrastructure does not exist yet:

- **No Grid-wide Entra External ID tenant exists.** Microsoft Entra workforce tenants (the standard developer-tenant for HoneyDrunkStudios.com) are separate from External ID tenants. A new External ID tenant must be provisioned via the Azure portal.
- **No App Registrations exist under the (non-existent) Entra External ID tenant.** The first App Registration commits the tenant to specific consumer apps. Default ordering: Notify Cloud tenant operators first (the operator surface is needed before Hearth ships), or Hearth if Hearth signup is the imminent forcing function — the human decides at provisioning time.
- **`rg-hd-platform-shared` may or may not exist.** Per memory `feedback_lean_azure_tags` the Grid uses a `purpose=platform-shared` tag for Grid-wide shared resources. The resource group's *existence* should be verified; if absent, create it (per memory `feedback_provision_when_needed` — provision when first needed, do not pre-create). Entra External ID tenants are subscription-bound resources; the tenant lives in this resource group.
- **The custom domain `auth.honeydrunkstudios.com` is not yet wired.** Per ADR-0078 D1's "Operational Consequences" the custom domain unifies the OAuth experience under the Grid's brand. Wiring requires a Cloudflare CNAME record per ADR-0029 (Cloudflare DNS) plus an Entra-side custom-domain claim.
- **Invariant 20 exception for the App Registration client secret has not been logged.** Entra App Registration client secrets default to 24-month expiration. Invariant 20 requires Tier-2 (third-party via rotation Function) secrets to rotate ≤ 90 days unless an active exception is logged in Log Analytics. The 90-day rotation cycle is operationally expensive (manual portal step every quarter); the right posture per invariant 20 is to log the exception now, document the operational burden, and resolve via ADR-0006 Tier-2 rotation extension (packet 05 of this initiative) — Option (b) per the scoping refinement.

## Steps

### Step 1 — Verify or create `rg-hd-platform-shared` resource group

Per the user's lean-tag convention (memory `feedback_lean_azure_tags`), the Grid uses a `purpose=platform-shared` tag for resources that are Grid-wide rather than per-Node. The Entra External ID tenant is Grid-wide — there is one tenant for the whole Grid per ADR-0078 D1. The tenant lives in a shared resource group.

1. Open https://portal.azure.com → Resource groups
2. Search for `rg-hd-platform-shared`.
3. **If it exists:** verify tags include `env=prod`, `purpose=platform-shared`. If missing, add via the resource group's Tags blade.
4. **If it does NOT exist:** click **+ Create**.
   - **Subscription:** the Grid's main subscription (the user's known production subscription; not the per-Node subscriptions per the user's Azure decisions in memory `project_azure_decisions`).
   - **Resource group:** `rg-hd-platform-shared`
   - **Region:** Azure US East 2 (per memory `project_azure_decisions` and ADR-0049's data-residency invariant for Restricted data; Entra External ID tenants are global by nature but the resource-group home should match the Grid's standard region).
   - **Tags:** `env=prod`, `purpose=platform-shared`
   - Click **Review + create**, then **Create**.
   - Cost: $0 (resource groups themselves are free).

**Rationale (cross-link to `infrastructure/walkthroughs/azure-provisioning-guide.md` if it exists; otherwise inline):** Per-Node resources live in `rg-hd-{service}-{env}` (e.g., `rg-hd-identity-prod`). Grid-wide shared resources — the Entra External ID tenant, the App Configuration store, the shared ACR — live in `rg-hd-platform-shared`. The Entra tenant is Grid-wide (one tenant for every consumer app + Notify Cloud tenant operators per ADR-0078 D1), so it belongs in the shared resource group.

### Step 2 — Create the Entra External ID tenant

1. Open https://portal.azure.com → search for **"Microsoft Entra External ID"** (not "Entra ID" alone — that is the workforce tenant) → **+ Create tenant**.
2. **Tenant type:** **External** (the consumer/CIAM variant; **not** the workforce variant).
3. **Configuration:**
   - **Organization name:** `HoneyDrunk Studios`
   - **Initial domain name:** `honeydrunkstudios.onmicrosoft.com` (Azure-assigned default; can be customized per Microsoft's tenant-naming rules — the custom domain `auth.honeydrunkstudios.com` is configured in Step 5 below, not here).
   - **Region:** Azure US East 2 (matches the Grid's standard region per memory `project_azure_decisions`).
   - **Subscription:** the Grid's main subscription.
   - **Resource group:** `rg-hd-platform-shared` (from Step 1).
4. Click **Review + create**, then **Create**.
5. Wait for provisioning (~5-10 minutes).
6. Once created, **record the tenant ID** (a GUID) and the tenant's OIDC issuer URL — these go into App Configuration as `Identity:Entra:TenantId` and `Identity:Entra:TenantIssuerUrl` per the schema documented in packet 02 of this initiative.
7. Tag the tenant with `env=prod`, `purpose=platform-shared`.

**Cost check (per memory `feedback_default_cheapest_azure_tier`):** Entra External ID is **free up to 50K MAU** per ADR-0078 D8. The Grid's MAU trajectory through Hearth + Lately + Currents + Curiosities + Notify Cloud tenants at low-hundreds is well below 50K. Expected monthly cost: **$0**.

### Step 3 — Create the first App Registration

The first App Registration commits the tenant to a specific consumer-app surface. Choose **one** of:

- **Notify Cloud tenant operators** (`notify-cloud` App Registration) — recommended default if Hearth signup is not yet imminent. Provides a working OAuth flow for the operator surface immediately and exercises the tenant.
- **Hearth signup** (`hearth` App Registration) — choose this if Hearth signup is the next consumer-app feature packet to land.

Either way:

1. Inside the new Entra External ID tenant: **App registrations → + New registration**.
2. **Name:** `HoneyDrunk Notify Cloud` (or `HoneyDrunk Hearth`) — human-friendly.
3. **Supported account types:** Accounts in this organizational directory only (Single tenant — the new External ID tenant).
4. **Redirect URI:** Platform **Single-page application (SPA)** for public-client PKCE flows, or **Web** for confidential-client flows. URI value per the redirect URI pattern from packet 02's doc: `https://notify-cloud.honeydrunkstudios.com/auth/callback` (or `https://hearth.honeydrunkstudios.com/auth/callback`).
5. Click **Register**.
6. **Record the Application (client) ID** — this is the `Identity:Entra:{App}:ClientId` value in App Configuration.
7. If the flow is confidential-client:
   - Inside the App Registration: **Certificates & secrets → + New client secret**.
   - **Description:** `Initial client secret — ADR-0078 packet 03`.
   - **Expires:** **180 days** (Microsoft's portal default — the minimum is 24 hours, maximum is 24 months; the practical choice given invariant 20 is 90 days). **NOTE: this is the invariant-20 exception trigger — see Step 7 below.**
   - Click **Add**.
   - **Copy the secret value immediately** (the portal shows it only once).
   - Store the secret in `kv-hd-identity-prod` under the secret name `entra-app-notify-cloud-client-secret` (or `entra-app-hearth-client-secret`) per the naming convention in packet 02's doc. Use the Azure portal's Key Vault → Secrets → + Generate/Import flow.
8. Configure **token configuration**:
   - **+ Add optional claim** for **ID tokens**: `email`, `family_name`, `given_name`, `preferred_username` (the OIDC-standard claims per invariant 94 / packet 02's mapping table).
   - Do **not** add Entra-proprietary claims (`oid`, `tid`, etc.) — they're auto-included by Entra; explicitly not configured here.
9. Configure **API permissions**:
   - Default: **Microsoft Graph → openid, profile, email** (the OIDC-standard scopes).
   - Grant admin consent for these scopes.

### Step 4 — Configure the sign-up + sign-in user flow

1. Inside the Entra External ID tenant: **User flows → + New user flow**.
2. **Type:** Sign-up and sign-in.
3. **Name:** `b2c_susi_default` (Entra retains the b2c_* prefix in External ID user-flow names for historical compatibility).
4. **Identity providers:** Email with password (default at v1 per ADR-0078 D10 — social-login providers added per-app at later packets).
5. **User attributes and token claims:**
   - **Collect from user during signup:** Email Address, Display Name, Country/Region (per Hearth + Notify Cloud needs).
   - **Return in token:** Email Addresses, Display Name (only — OIDC-standard claims per invariant 94).
6. Click **Create**.
7. Record the user-flow name for the `Identity:Entra:{App}:SignUpSignInPolicy` App Configuration key.
8. Create a similar **Password reset** flow (`b2c_pwd_reset_default`) — same pattern, type "Password reset".

### Step 5 — Custom domain `auth.honeydrunkstudios.com` (Entra side + Cloudflare side)

Per ADR-0078 D1's "Operational Consequences" and ADR-0029 (Cloudflare DNS).

**Entra side:**

1. Inside the Entra External ID tenant: **Company branding → Custom URL domains → + Custom URL domain**.
2. **Custom URL domain:** `auth.honeydrunkstudios.com`.
3. Entra shows the CNAME target the new custom domain should resolve to (a `*.ciamlogin.com` or similar Microsoft-managed hostname). **Record this CNAME target.**

**Cloudflare side (per ADR-0029):**

1. Open https://dash.cloudflare.com → `honeydrunkstudios.com` zone → **DNS → Records → + Add record**.
2. **Type:** CNAME.
3. **Name:** `auth`.
4. **Target:** the CNAME target Entra showed in the previous step.
5. **Proxy status:** **DNS only** (orange cloud off — Entra needs direct CNAME resolution for the domain-verification flow; the proxy can be re-enabled later if cache/perf reasons emerge, but ADR-0029's stance defaults to DNS-only for IdP-bound names).
6. **TTL:** Auto.
7. Click **Save**.

**Back in Entra side:**

1. Return to **Company branding → Custom URL domains** and click **Verify** on the `auth.honeydrunkstudios.com` entry.
2. Wait for DNS propagation (typically 1-5 minutes; can be up to an hour).
3. Once verified, Entra shows the domain as **Active**.

### Step 6 — Seed the App Configuration keys (manual; Bicep-deferred)

Per packet 02's per-application configuration shape, seed the following keys in Azure App Configuration (`appcs-hd-platform-shared` — the Grid's shared App Configuration store per ADR-0005). Do this via the portal until the Bicep templates for App Configuration provisioning land (ADR-0077 follow-up).

| Key | Value (source) |
|-----|----------------|
| `Identity:Entra:TenantId` | The tenant ID GUID from Step 2 |
| `Identity:Entra:TenantIssuerUrl` | The OIDC issuer URL from Step 2 |
| `Identity:Entra:CustomDomain` | `auth.honeydrunkstudios.com` |
| `Identity:Entra:NotifyCloud:ClientId` (or `Identity:Entra:Hearth:ClientId`) | The Application (client) ID from Step 3 |
| `Identity:Entra:NotifyCloud:RedirectUri` (or `Identity:Entra:Hearth:RedirectUri`) | The redirect URI from Step 3 |
| `Identity:Entra:NotifyCloud:Scopes` (or `Identity:Entra:Hearth:Scopes`) | `openid,profile,email` |
| `Identity:Entra:NotifyCloud:SignUpSignInPolicy` (or equivalent for Hearth) | `b2c_susi_default` |
| `Identity:Entra:NotifyCloud:PasswordResetPolicy` (or equivalent for Hearth) | `b2c_pwd_reset_default` |

The non-secret values land in App Configuration. The client secret (if confidential-client) is already in `kv-hd-identity-prod` from Step 3.

### Step 7 — Log the invariant-20 exception in Log Analytics

Per invariant 20: *"No secret may exceed its tier's rotation SLA without an active exception. Tier 2 (third-party via rotation Function): ≤ 90 days. ... Exceptions must be logged in Log Analytics."*

Entra App Registration client secrets default to 24-month expiration. 90-day rotation is operationally expensive (manual portal step every quarter; no `IRotator` exists for Entra App Registration secrets yet — that is part of the ADR-0006 Tier-2 rotation extension work in packet 05 of this initiative).

The right posture per invariant 20: **log the exception now, document the operational burden, and resolve via ADR-0006 amendment** (packet 05).

1. Open https://portal.azure.com → Log Analytics workspace `log-hd-platform-shared` (or whichever shared workspace per ADR-0006 / ADR-0040; if no shared workspace exists yet, create one in `rg-hd-platform-shared` per the same cheapest-tier-first principle — Pay-As-You-Go ~$2.30/GB ingested).
2. Either via a **Custom log** or via a **manual workbook entry**, append a record with:
   - **Exception type:** `InvariantException`
   - **Invariant:** `20`
   - **Secret name:** `entra-app-notify-cloud-client-secret` (or `entra-app-hearth-client-secret`)
   - **Vault:** `kv-hd-identity-prod`
   - **Issuer/Vendor:** `Microsoft Entra External ID`
   - **Current SLA:** Tier-2, ≤ 90 days
   - **Actual rotation cadence:** Set at 180 days for the initial secret; manual rotation in the Azure portal until the ADR-0006 Tier-2 rotation extension lands.
   - **Reason:** No `IRotator` implementation for Entra App Registration secrets exists; 90-day manual portal rotation is operationally expensive for a solo-dev shop. Mitigation: Microsoft enforces strong app-secret hygiene (secret values not log-traced; only secret IDs); the consumer-app surface is browser-based PKCE (public client — no secret required for the primary OAuth flow); the client secret is needed only for Microsoft Graph callbacks (account-deletion fan-out per ADR-0060 D8) which are infrequent.
   - **Follow-up:** Resolved by packet 05 of `adr-0078-entra-external-id` (ADR-0006 Tier-2 rotation extension proposal).
   - **Logged at:** the current date.
   - **Logged by:** the user.
3. If the Log Analytics workspace does not yet have a custom-log table for invariant exceptions, create one (Custom Logs → + Add custom log → schema with the fields above). The schema is small and reusable for future invariant-20 exceptions.

**Alternative for solo-dev shops:** if maintaining a Log Analytics custom-log table is itself overhead, the exception may be logged in `governance/exceptions/invariant-20-entra-app-secret.md` in the Architecture repo (a Markdown record that the review agent and any future audit can read). **Add that file in this same PR** if you go that route — the exception must be discoverable somewhere structured. The Markdown route is acceptable per invariant 20's "logged in Log Analytics" clause being interpreted as "logged in a structured, discoverable, queryable location"; Markdown in the governance folder qualifies.

### Step 8 — Tag everything and confirm

Apply tags `env=prod`, `purpose=platform-shared`, `node=identity` (per memory `feedback_lean_azure_tags` — `node` tag for per-Node resources, but the Entra tenant is Grid-wide so `purpose=platform-shared` is the primary tag) to:

- The Entra External ID tenant (Step 2).
- The `rg-hd-platform-shared` resource group (Step 1).
- The Log Analytics workspace (Step 7).
- (App Configuration keys do not carry Azure tags; the App Configuration store itself is already tagged.)

Take a screenshot of the Entra External ID tenant Overview blade showing tenant ID + Active status, and attach to the closing comment on this chore issue.

## Acceptance Criteria

- [ ] `rg-hd-platform-shared` resource group exists in the Grid's main subscription with tags `env=prod` and `purpose=platform-shared`.
- [ ] A Microsoft Entra External ID tenant exists, provisioned inside `rg-hd-platform-shared`, tagged `env=prod`, `purpose=platform-shared`. Tenant ID and OIDC issuer URL recorded in the closing comment.
- [ ] At least one App Registration (Notify Cloud tenant operators or Hearth — the human chose at provisioning time) exists under the new tenant with: SPA or Web platform redirect URI, the OIDC-standard scopes (openid, profile, email), the OIDC-standard optional claims configured (email, family_name, given_name, preferred_username — no Entra-proprietary claims explicitly added), admin consent granted.
- [ ] If the App Registration uses a confidential-client flow: a client secret exists in `kv-hd-identity-prod` under the secret name `entra-app-{app}-client-secret` (e.g., `entra-app-notify-cloud-client-secret`).
- [ ] Sign-up + sign-in user flow `b2c_susi_default` exists, configured for email + password (no social-login at v1 per ADR-0078 D10), returning OIDC-standard claims only.
- [ ] Password reset user flow `b2c_pwd_reset_default` exists.
- [ ] `auth.honeydrunkstudios.com` custom domain is **Active** on the Entra tenant. Cloudflare CNAME record for `auth` exists in the `honeydrunkstudios.com` zone, set to DNS-only (proxy off).
- [ ] App Configuration store has the eight `Identity:Entra:*` keys from Step 6 seeded with their concrete values.
- [ ] **Invariant-20 exception logged** either in Log Analytics workspace `log-hd-platform-shared` as a structured custom-log entry, **or** in `governance/exceptions/invariant-20-entra-app-secret.md` in this repo (committed in this same PR if the Markdown route is chosen).
- [ ] Closing comment on this chore issue contains: the tenant ID, the OIDC issuer URL, the App Registration client ID, the Vault secret name (no value), the custom-domain verification screenshot, and the path to the invariant-20 exception record.
- [ ] Cost check confirmed: Entra External ID is free up to 50K MAU per ADR-0078 D8; expected monthly cost is **$0** for the tenant + App Registration + user flows.

## Human Prerequisites

- [ ] Org-admin role on `HoneyDrunkStudios` (required to create the Entra External ID tenant in the Grid's main subscription).
- [ ] Azure portal access with subscription-Owner role on the Grid's main subscription (required to create the resource group, the tenant, the App Registrations, and the Log Analytics workspace).
- [ ] Cloudflare portal access on the `honeydrunkstudios.com` zone (required for the custom-domain CNAME record per ADR-0029).
- [ ] Browser with current sessions for Azure portal + Cloudflare portal.
- [ ] Packets 00, 01, 02 of this initiative merged to `main` (the contracts.json `notes:` field, the grid-health entry for the custom domain, the per-app configuration shape doc, and the invariants 93/94 must all be in place so this packet's tracking issue references them by number).
- [ ] **The human decides at provisioning time whether to set up the Notify Cloud or Hearth App Registration first.** This is not a packet-time decision; it depends on which consumer-app surface is the next feature packet to land.

## Dependencies

- `work-item:00` — ADR-0078 acceptance + invariants 93/94. This chore's tracking issue references invariant 94 by number.
- `work-item:01` — Catalog updates (the `entra-custom-domain-auth-honeydrunkstudios-com` grid-health entry must exist so the custom-domain provisioning has a discoverable surface to update from `Planned` to active once provisioning completes).
- `work-item:02` — Per-application configuration shape doc (this chore seeds the keys named in that doc; the doc must be on `main` before the human can reference it during provisioning).

## Downstream Unblocks

- The first consumer-app feature packet (Hearth signup per PDR-0005 Phase 2 + `HoneyDrunk.Identity.Providers.Entra` package authoring per ADR-0060 D12 Phase 2) becomes implementable once this chore is Done — the App Registration exists, the App Configuration keys are seeded, the client secret (if any) is in Vault, the custom domain is wired.
- Packet 04 of this initiative (the Entra App Registration provisioning walkthrough doc) is independent of this chore and can run in parallel — the doc captures the steps for future App Registration provisioning rather than depending on the first tenant existing.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. — The closing comment on this chore must record the Vault secret name but **never the secret value**. Microsoft's portal shows the client-secret value once at creation; copy and paste it directly into the Key Vault portal, then do not retain it elsewhere.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. — The Entra App Registration client secret lives in `kv-hd-identity-prod` only. It is read by application code via `ISecretStore` (never inlined in config files or environment variables).

> **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. **It is not an identity provider.** — Survives ADR-0078 intact. The Entra-issued tokens are validated by Auth's existing `IJwtBearerValidator` against Entra's JWKS endpoint.

> **Invariant 17:** One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}`. — The Entra App Registration client secret lives in `kv-hd-identity-prod` (Identity's per-Node Vault). If that Vault does not exist yet (Identity is still Phase 1 library-only per ADR-0060 D12), the secret can be staged temporarily in `kv-hd-platform-shared` until Identity's Vault is provisioned with the first Identity deployable. Flag this in the closing comment.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. — Not changed by this chore; reflects the future-state once Identity is deployed.

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. Tier 1 (Azure-native): ≤ 30 days. Tier 2 (third-party via rotation Function): ≤ 90 days. Certificates: auto-renewed 30 days before expiry. Exceptions must be logged in Log Analytics. — The Entra App Registration client secret defaults to 24-month expiration; that exceeds the Tier-2 SLA. **Step 7 of this chore logs the active exception** per invariant 20's exception clause. The exception is resolved long-term by packet 05 of this initiative (ADR-0006 Tier-2 rotation extension proposal).

> **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. — The Vault entry created in Step 3 carries the latest version; application code reads through `ISecretStore` which resolves latest. Manual rotation in the portal creates a new version; consumers pick it up automatically.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. Required for rotation SLA monitoring, unauthorized access alerting, and audit. — `kv-hd-identity-prod` (if it exists) or `kv-hd-platform-shared` (if used as temporary staging) must have diagnostic settings routed. Verify in the closing comment.

> **Invariant 93 (Proposed — pending ADR-0078 acceptance via packet 00):** End-user identity tokens are issued by Microsoft Entra External ID. — This chore provisions the tenant + first App Registration that begin satisfying this invariant.

> **Invariant 94 (Proposed — pending ADR-0078 acceptance via packet 00):** Application code consumes OIDC-standard claims only from Entra-issued tokens. — The App Registration's optional-claim configuration (Step 3) and user-flow token-claim configuration (Step 4) explicitly return only OIDC-standard claims; the chore's portal steps enforce the discipline at the configuration boundary.

## Referenced ADR Decisions

**ADR-0078 D1 — Microsoft Entra External ID is the end-user IdP.** Single Grid-wide tenant; per-application App Registrations; OAuth 2.1 with PKCE on OpenID Connect. This chore provisions the tenant and the first App Registration.

**ADR-0078 D3 — OIDC-standard claims only.** The App Registration's optional-claim configuration in Step 3 includes only `email`, `family_name`, `given_name`, `preferred_username` (the OIDC-standard set per invariant 94 / packet 02's mapping table). No Entra-proprietary claims are configured.

**ADR-0078 D6 — Per-application configuration shape.** Step 6 seeds the App Configuration keys per the schema in packet 02's doc.

**ADR-0078 D8 — Cost posture.** Free up to 50K MAU. Expected monthly cost: $0.

**ADR-0078 D10 — Out of scope:** MFA enforcement policy defaults to "optional, user-enrollable" at v1; social-login defaults to "email-only" at v1; Notify Cloud tenant-operator full setup is a per-ADR-0027 follow-up. The user flow created in Step 4 matches the v1 defaults (email + password, no social-login).

**ADR-0006 (Secret Rotation and Lifecycle):** Step 7's invariant-20 exception logging follows ADR-0006's "Exceptions must be logged in Log Analytics" guidance. Packet 05 of this initiative is the ADR-0006 Tier-2 rotation extension proposal that resolves the exception long-term.

**ADR-0005 D1 — Per-Node per-environment Key Vault.** `kv-hd-identity-prod` is the home for the Entra App Registration client secret (with `kv-hd-platform-shared` as temporary staging if Identity's Vault does not exist yet).

**ADR-0005 D3 — Per-Node App Configuration namespace.** `Identity:Entra:*` is the namespace; seed in Step 6.

**ADR-0029 (Cloudflare DNS):** Custom domain `auth.honeydrunkstudios.com` is wired via Cloudflare CNAME per ADR-0029's DNS-only-by-default stance for IdP-bound names.

**ADR-0060 D2 — Wrap external IdP.** This chore provisions the wrapped IdP (Entra External ID). The Identity Node's `HoneyDrunk.Identity.Providers.Entra` package consumes this provisioning at the first consumer-app feature packet.

**ADR-0049 Data classification:** Tenant + App Registrations + client secrets all sit in `Restricted` / `Sensitive PII` boundary. Step 7's invariant-20 exception record must respect ADR-0049 — the exception text describes the secret name and rotation cadence but never the secret value.

**ADR-0052 Cost governance:** Spend baseline for Entra External ID is $0 through MVP. If the Entra tenant ever exceeds $200/mo a re-evaluation against the alternatives in ADR-0078 D9 happens per ADR-0052's governance hooks.

## Constraints

- **Actor=Human.** This chore is portal-based end-to-end. No agent can execute the Entra tenant creation, the App Registration setup, the Cloudflare CNAME record, the user-flow creation, or the invariant-20 exception logging. Frontmatter sets `labels: ["human-only", ...]` per the user's source-of-truth convention.
- **Single Grid-wide Entra External ID tenant.** Per ADR-0078 D1. Do not create per-Node or per-environment tenants. Per-app App Registrations under the one tenant accommodate different application contexts.
- **OIDC-standard claims only at the App Registration level.** Step 3's optional-claim configuration includes only `email`, `family_name`, `given_name`, `preferred_username`. Do not add Entra-proprietary claims (`oid`, `tid`, etc.) — Entra auto-includes those; explicit addition would be a signal that application code intends to consume them, which violates invariant 94.
- **Custom domain DNS is DNS-only (Cloudflare proxy off).** Per ADR-0029's posture for IdP-bound names. Do not enable the orange-cloud proxy on the `auth` CNAME record; Entra needs direct CNAME resolution.
- **Invariant-20 exception MUST be logged.** Either in Log Analytics custom log or in `governance/exceptions/invariant-20-entra-app-secret.md`. If the Markdown route is chosen, commit the file in the same PR as the chore-closure comment so the discoverable record exists on `main`.
- **The invariant-20 exception is temporary** — it is resolved by packet 05 of this initiative (ADR-0006 Tier-2 rotation extension proposal). The exception record must reference packet 05 as the follow-up.
- **Client secret values never appear in chore comments or PR descriptions.** Per invariant 8. Only the secret *name* (`entra-app-{app}-client-secret`) and the Vault location (`kv-hd-identity-prod`) are mentioned.
- **Cost confirmation.** Free tier through 50K MAU. The closing comment must state "Cost: $0 (Free tier)" so a future cost review has the baseline recorded.
- **Tag discipline.** `env=prod`, `purpose=platform-shared` on the resource group + tenant + Log Analytics workspace. `node=identity` is **not** the primary tag for the Entra tenant (the tenant is Grid-wide, not per-Identity-Node) — `purpose=platform-shared` is the primary tag.

## Labels

`chore`, `tier-1`, `core`, `infra`, `identity`, `adr-0078`, `human-only`, `wave-2`

## Agent Handoff

**Objective:** Provision the Grid-wide Microsoft Entra External ID tenant; create the first App Registration (Notify Cloud tenant operators or Hearth — human picks at provisioning time); verify-or-create the `rg-hd-platform-shared` resource group; wire the custom domain `auth.honeydrunkstudios.com` via Cloudflare CNAME; seed the App Configuration keys; log the active invariant-20 exception for the Entra App Registration client-secret rotation cadence in Log Analytics or `governance/exceptions/invariant-20-entra-app-secret.md`.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture` (tracking issue lives here; actual work happens in Azure portal + Cloudflare portal + Log Analytics workspace).

**Context:**
- Goal: Stand up the Entra External ID infrastructure so the first consumer-app feature packet has a working OAuth target and the OpenID Connect surface is reachable via the Grid's brand domain.
- Feature: ADR-0078 End-User Identity rollout, Wave 2, Packet 03.
- ADRs: ADR-0078 (Entra commitment), ADR-0006 (secret rotation — invariant-20 exception), ADR-0005 (Vault + App Configuration shape), ADR-0029 (Cloudflare DNS for the custom domain).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 00, 01, 02 of this initiative.

**Constraints:** As listed above. Most critically:
- This is `Actor=Human` (`human-only` label is the source of truth).
- Single Grid-wide Entra External ID tenant — not per-Node or per-environment.
- OIDC-standard claims only at the App Registration optional-claim configuration; never explicitly add Entra-proprietary claims.
- Cloudflare CNAME for `auth` is DNS-only (no proxy).
- Invariant-20 exception MUST be logged; commit `governance/exceptions/invariant-20-entra-app-secret.md` in the same PR if the Markdown route is chosen.
- Client secret values never appear in chore comments or PR descriptions (invariant 8).

**Key Files:** (committed if the Markdown exception-record route is chosen)
- `governance/exceptions/invariant-20-entra-app-secret.md` — new (if used)

**Contracts:** None changed. This is provisioning work; the Identity contract surface from ADR-0060 D4 is not modified.
