---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0005"]
dependencies: ["vault-bootstrap-extensions", "vault-event-driven-cache-invalidation", "architecture-infra-setup", "actions-oidc-and-secret-cleanup"]
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: honeydrunk-notify
---

# Feature: Migrate HoneyDrunk.Notify config bootstrap to `AZURE_KEYVAULT_URI` + `AZURE_APPCONFIG_ENDPOINT`

## Summary
Switch Notify's Resend/Twilio/SMTP secret resolution to the new env-driven Vault bootstrap and register the Event Grid cache-invalidation webhook. Notify is the first Tier-2 rotation target — this Node must be ready before `HoneyDrunk.Vault.Rotation` ships its Resend/Twilio rotators.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Notify`

## Motivation
Notify holds the primary third-party provider credentials (Resend API key, Twilio SID/token). ADR-0006 Tier 2 rotates these via the new `HoneyDrunk.Vault.Rotation` Function. For rotation to actually reach running workers, Notify must resolve these every call via `ISecretStore` and honor Event Grid invalidation — no local caching of the raw key, no version pinning. Also Notify is pending Azure Functions deployment per active-initiatives, so this migration lands alongside the deployment bring-up.

## Proposed Implementation
- Replace startup wiring with `builder.AddVault()` + `builder.AddAppConfiguration()` in both the worker host and any Functions host
- Resend credential: `Resend--ApiKey`
- Twilio credentials: `Twilio--AccountSid`, `Twilio--AuthToken`
- SMTP credentials: `Smtp--Username`, `Smtp--Password`
- Queue connection (Azure Storage Queue): `NotifyQueueConnection` (flat — Node-internal)
- Non-secret provider defaults (from addresses, retry policies, per-channel throttles) → App Configuration label `honeydrunk-notify`
- Providers (`HoneyDrunk.Notify.Providers.Resend`, `.Twilio`, `.Smtp`) must resolve credentials on each outbound call — not cache them in options at bootstrap
- Webhook for Event Grid invalidation registered in both worker host and Functions host
- CI to OIDC workflow

## Affected Packages
- `HoneyDrunk.Notify` (runtime host + worker)
- `HoneyDrunk.Notify.Providers.Resend`
- `HoneyDrunk.Notify.Providers.Twilio`
- `HoneyDrunk.Notify.Providers.Smtp`
- Azure Functions host project (pending deployment)

## Boundary Check
- [x] All secret handling belongs in Notify's provider layer
- [x] No Transport contract change

## Acceptance Criteria
- [ ] Startup uses only env-driven extensions in both host flavors
- [ ] All provider credentials resolved through `ISecretStore` at call time, not at bootstrap
- [ ] Provider-grouped secret naming
- [ ] Non-secret config from App Configuration with Notify label
- [ ] Event Grid invalidation webhook registered
- [ ] Rotation canary: swap `Resend--ApiKey` version, invalidate, confirm next send uses the new key without process restart
- [ ] CI uses OIDC — no client secrets
- [ ] Existing integration tests still pass
- [ ] CHANGELOG updated

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.

> **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006.

## Referenced ADR Decisions

**ADR-0005 (Configuration and Secrets Strategy):** Per-deployable-Node Key Vaults (`kv-hd-{service}-{env}`), `{Provider}--{Key}` secret naming, Managed Identity + Azure RBAC access, three-tier config split (Key Vault for secrets, App Configuration for non-secret config, env vars for bootstrap only), and env-var-driven discovery (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`).
- **§Bootstrap:** `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service application settings at deploy time. `AddVault(...)` reads the vault URI; `AddAppConfiguration(...)` reads the App Config endpoint. Both use `DefaultAzureCredential`. Convention-based derivation from Node name was rejected.
- **§Three-tier configuration split:** Secrets go in Key Vault, non-secret config goes in shared App Configuration (`appcs-hd-shared-{env}`) with label-per-Node partitioning, env vars are bootstrap only.

**ADR-0006 (Secret Rotation and Lifecycle):** Five-tier rotation model — Azure-native rotation (≤30d), third-party rotation via `HoneyDrunk.Vault.Rotation` Function (≤90d), Event Grid cache invalidation on `SecretNewVersionCreated`, audit via Log Analytics, and deploy-blocking rotation SLAs.
- **§Tier 2:** `HoneyDrunk.Vault.Rotation` is a new Azure Function App sub-Node for rotating third-party secrets (Resend, Twilio, OpenAI). Triggers via Event Grid or manual. Mints new key via provider API, writes to Key Vault, disables old version after grace period.
- **§Tier 3:** Each Key Vault has an Event Grid subscription on `SecretNewVersionCreated`. A Function/webhook invalidates the `HoneyDrunk.Vault` cache entry. Next `ISecretStore` read fetches latest version. TTL becomes fallback, not primary mechanism. Apps must never pin to a version.

## Context
- ADR-0005, ADR-0006
- Invariants 8, 9, 17, 18, 21
- Active initiative: Notification Subsystem Launch (Azure Functions deployment pending — this packet is the deployment bring-up gate)

## Dependencies
- `vault-bootstrap-extensions` + `vault-event-driven-cache-invalidation` (merged and published as a preview Vault package first)
- `architecture-infra-setup` (portal walkthroughs for vault/OIDC provisioning)
- `actions-oidc-and-secret-cleanup` (reusable OIDC deploy workflow)

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Make Notify's provider credentials rotation-safe and env-driven.
**Target:** HoneyDrunk.Notify, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave + unblock Notify Azure deployment
- Feature: Configuration/rotation rollout + Notification Subsystem Launch
- ADRs: ADR-0005 (Configuration and Secrets Strategy — per-Node Key Vaults, env-var discovery, three-tier config split), ADR-0006 (Secret Rotation and Lifecycle — five-tier rotation, Event Grid cache invalidation)

**Acceptance Criteria:** As listed above

**Dependencies:** `vault-bootstrap-extensions` and `vault-event-driven-cache-invalidation` merged and published as a preview Vault package before this lands. This Node is the canonical test case for Tier-2 rotation.

**Constraints:**
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. Never log Resend/Twilio/SMTP credentials, even during troubleshooting.
- **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.
- **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005. Notify's vault: `kv-hd-notify-{env}` (6 chars).
- **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006. Credentials must be fetched per call or at least per invalidation boundary.

**Key Files:**
- `Program.cs` (both host flavors)
- Provider projects under `HoneyDrunk.Notify.Providers.*`
- `appsettings*.json`
- `.github/workflows/*.yml`
- Azure Functions `host.json`

**Contracts:** None changed.
