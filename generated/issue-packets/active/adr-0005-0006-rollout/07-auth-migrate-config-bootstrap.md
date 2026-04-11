---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Auth
labels: ["feature", "tier-2", "core", "infrastructure", "adr-0005"]
dependencies: ["vault-bootstrap-extensions", "vault-event-driven-cache-invalidation", "architecture-infra-setup", "actions-oidc-and-secret-cleanup"]
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: honeydrunk-auth
---

# Feature: Migrate HoneyDrunk.Auth config bootstrap to `AZURE_KEYVAULT_URI` + `AZURE_APPCONFIG_ENDPOINT`

## Summary
Switch Auth's startup wiring to the new env-var-driven `AddVault` + `AddAppConfiguration` extensions, remove any direct env-var or `appsettings` secret reads, adopt the shared App Configuration with per-Node label, and ensure it can receive Event Grid cache invalidation.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Auth`

## Motivation
ADR-0005 mandates every deployable Node bootstrap through two env vars and consume secrets exclusively via `ISecretStore`. ADR-0006 adds the expectation that rotated secrets propagate via Event Grid cache invalidation — the Node must expose the webhook endpoint from `HoneyDrunk.Vault.EventGrid`.

## Proposed Implementation
- Replace explicit vault URI configuration in Program.cs / startup with `builder.AddVault()` (new env-driven overload)
- Add `builder.AddAppConfiguration()` call, passing no URI — the extension reads `AZURE_APPCONFIG_ENDPOINT`
- Audit the codebase for any direct reads of secrets from `IConfiguration` / env vars / `appsettings*.json`. Replace every one with `ISecretStore.GetSecretAsync(name)` and provider-grouped PascalCase names (`Jwt--SigningKey`, `Auth--SomeProviderKey`, etc.). Invariant 9.
- Move non-secret settings (token lifetimes, issuer, feature flags) to App Configuration under the `honeydrunk-auth` label (matches `HONEYDRUNK_NODE_ID`)
- Register `/internal/vault/invalidate` webhook from the new `HoneyDrunk.Vault.EventGrid` helper so this Node's `SecretCache` is invalidated on `SecretNewVersionCreated`
- Add a `kv-hd-auth-{env}` vault provisioning note in the repo's `deployment.md` (portal walkthrough lives in Architecture — cross-link)
- Update CI workflow to use the new reusable OIDC workflow template (see `actions-oidc-federated-credentials-workflow` packet). Remove any `AZURE_CLIENT_SECRET` references.
- Remove any hardcoded vault URIs from `appsettings*.json` files

## Affected Packages
- `HoneyDrunk.Auth` (runtime host)
- Any `HoneyDrunk.Auth.*` packages that currently read secrets directly

## NuGet Dependencies

### `HoneyDrunk.Auth` host project — additions to existing references
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | StyleCop + EditorConfig analyzers — confirm already present; add if missing |
| `HoneyDrunk.Vault.Providers.AzureKeyVault` (preview from packet 01) | Provides the new env-driven `AddVault()` overload |
| `HoneyDrunk.Vault.Providers.AppConfiguration` (preview from packet 01) | Provides `AddAppConfiguration()` |
| `HoneyDrunk.Vault.EventGrid` (preview from packet 02) | Provides `MapVaultInvalidationWebhook` for the `/internal/vault/invalidate` endpoint |

## Boundary Check
- [x] Work is purely Auth's own bootstrap surface and its secret reads — no cross-Node API changes
- [x] Does not touch JWT validation logic (invariant 10 — Auth still validates, never issues)

## Acceptance Criteria
- [ ] `Program.cs` uses only `AddVault()` + `AddAppConfiguration()` (no explicit URIs)
- [ ] Zero direct `IConfiguration` reads for anything secret; verified by a canary test
- [ ] Secret names follow `{Provider}--{Key}` convention
- [ ] Non-secret config sourced from App Configuration with the Auth label
- [ ] Webhook endpoint registered and tested against a synthetic Event Grid event
- [ ] CI workflow uses OIDC federated credentials — no client secrets
- [ ] All existing tests pass
- [ ] CHANGELOG updated
- [ ] Canary test verifies `ISecretStore` is the only path to secret values

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. It is not an identity provider.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.

> **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006.

## Referenced ADR Decisions

**ADR-0005 (Configuration and Secrets Strategy):** Per-deployable-Node Key Vaults (`kv-hd-{service}-{env}`), `{Provider}--{Key}` secret naming, Managed Identity + Azure RBAC access, three-tier config split (Key Vault for secrets, App Configuration for non-secret config, env vars for bootstrap only), and env-var-driven discovery (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`).
- **§Bootstrap:** `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service application settings at deploy time. `AddVault(...)` reads the vault URI; `AddAppConfiguration(...)` reads the App Config endpoint. Both use `DefaultAzureCredential`. Convention-based derivation from Node name was rejected.
- **§Three-tier configuration split:** Secrets go in Key Vault, non-secret config goes in shared App Configuration (`appcs-hd-shared-{env}`) with label-per-Node partitioning, env vars are bootstrap only.

**ADR-0006 (Secret Rotation and Lifecycle):** Five-tier rotation model — Azure-native rotation (≤30d), third-party rotation via `HoneyDrunk.Vault.Rotation` Function (≤90d), Event Grid cache invalidation on `SecretNewVersionCreated`, audit via Log Analytics, and deploy-blocking rotation SLAs.
- **§Tier 3:** Each Key Vault has an Event Grid subscription on `SecretNewVersionCreated`. A Function/webhook invalidates the `HoneyDrunk.Vault` cache entry. Next `ISecretStore` read fetches latest version. TTL becomes fallback, not primary mechanism. Apps must never pin to a version.

## Context
- ADR-0005 §Bootstrap, §Three-tier configuration split
- ADR-0006 §Tier 3
- Invariants 8, 9, 10, 17, 18, 21
- Active initiative: Grid v0.4 Stabilization — Auth is already aligned to Kernel 0.4, so this migration lands cleanly on top

## Dependencies
- `vault-bootstrap-extensions` + `vault-event-driven-cache-invalidation` (merged and published as a preview Vault package first)
- `architecture-infra-setup` (portal walkthroughs for vault/OIDC provisioning)
- `actions-oidc-and-secret-cleanup` (reusable OIDC deploy workflow)

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Make Auth's bootstrap fully compliant with ADR-0005/0006.
**Target:** HoneyDrunk.Auth, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave
- Feature: Configuration & secrets strategy rollout
- ADRs: ADR-0005 (Configuration and Secrets Strategy — per-Node Key Vaults, env-var discovery, three-tier config split), ADR-0006 (Secret Rotation and Lifecycle — five-tier rotation, Event Grid cache invalidation)

**Acceptance Criteria:**
- [ ] As listed above

**Dependencies:** `vault-bootstrap-extensions` and `vault-event-driven-cache-invalidation` merged and published as a preview Vault package before this lands.

**Constraints:**
- **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.
- **Invariant 10:** Auth tokens are validated, never issued. HoneyDrunk.Auth validates JWT Bearer tokens. It is not an identity provider.
- **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005. Auth's vault: `kv-hd-auth-{env}`.
- **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006.

**Key Files:**
- `Program.cs`
- `appsettings*.json` (audit + clean)
- `.github/workflows/*.yml`
- Any `StartupExtensions.cs` / `AuthBuilderExtensions.cs`

**Contracts:** None changed — internal migration only.
