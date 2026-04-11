---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Data
labels: ["feature", "tier-2", "core", "infrastructure", "adr-0005"]
dependencies: ["vault-bootstrap-extensions", "vault-event-driven-cache-invalidation", "architecture-infra-setup", "actions-oidc-and-secret-cleanup"]
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: honeydrunk-data
---

# Feature: Migrate HoneyDrunk.Data config bootstrap to `AZURE_KEYVAULT_URI` + `AZURE_APPCONFIG_ENDPOINT`

## Summary
Move Data's connection-string handling and tenant provisioning secrets under `ISecretStore`, bootstrap via the new env-driven `AddVault` + `AddAppConfiguration` extensions, and subscribe its cache to Event Grid invalidation.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Data`

## Motivation
Data is the highest-risk Node for secret leakage because it holds the SQL connection strings. Tier-1 rotation (SQL keys) depends entirely on this Node honoring cache invalidation — otherwise rotated connection strings won't reach running queries for up to a full TTL window.

## Proposed Implementation
- `builder.AddVault()` + `builder.AddAppConfiguration()` in startup
- Every connection string read now goes through `ISecretStore` with names like `Sql--{Purpose}Connection` (provider-grouped convention)
- Remove `DefaultConnection` from `appsettings*.json`
- Non-secret config (command timeout, retry policies, migration toggles) moves to App Configuration under the `honeydrunk-data` label
- Webhook endpoint for cache invalidation registered
- Outbox dispatcher, repository, and unit-of-work code must never cache raw connection strings; they must resolve per-scope via `ISecretStore` (invariant 21 — no version pinning)
- CI to OIDC reusable workflow

## Affected Packages
- `HoneyDrunk.Data` (runtime)
- `HoneyDrunk.Data.SqlServer` (provider) — verify no direct env-var reads
- Any `HoneyDrunk.Data.*.Migrations` tooling

## NuGet Dependencies

### `HoneyDrunk.Data` host project — additions to existing references
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | StyleCop + EditorConfig analyzers — confirm already present; add if missing |
| `HoneyDrunk.Vault.Providers.AzureKeyVault` (preview from packet 01) | Provides the new env-driven `AddVault()` overload |
| `HoneyDrunk.Vault.Providers.AppConfiguration` (preview from packet 01) | Provides `AddAppConfiguration()` |
| `HoneyDrunk.Vault.EventGrid` (preview from packet 02) | Provides `MapVaultInvalidationWebhook` for the `/internal/vault/invalidate` endpoint |

### `HoneyDrunk.Data.SqlServer` — additions to existing references
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | Confirm already present; add if missing |

### Migration tooling projects — additions to existing references
| Package | Notes |
|---|---|
| `HoneyDrunk.Vault.Providers.AzureKeyVault` (preview from packet 01) | Migration runner must also resolve connection strings via `ISecretStore` — not from `appsettings` |

## Boundary Check
- [x] Data's secret surface lives here; the migration is internal
- [x] Does not alter `IRepository`/`IUnitOfWork` contracts

## Acceptance Criteria
- [ ] Startup uses only env-driven extensions
- [ ] All connection strings resolved via `ISecretStore` (including migration tooling)
- [ ] Provider-grouped secret names in use
- [ ] Non-secret config from App Configuration with Data label
- [ ] Event Grid invalidation webhook registered and tested
- [ ] Tier-1 rotation canary: simulate a `SecretNewVersionCreated` event, assert next `ISecretStore` call returns the new value
- [ ] CI uses OIDC
- [ ] Existing tests + canary pass
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
- **§Tier 3:** Each Key Vault has an Event Grid subscription on `SecretNewVersionCreated`. A Function/webhook invalidates the `HoneyDrunk.Vault` cache entry. Next `ISecretStore` read fetches latest version. TTL becomes fallback, not primary mechanism. Apps must never pin to a version.

## Context
- ADR-0005, ADR-0006
- Invariants 8, 9, 17, 18, 21
- Data is already aligned to Kernel 0.4.0 (per active-initiatives), so this migration lands cleanly

## Dependencies
- `vault-bootstrap-extensions` + `vault-event-driven-cache-invalidation` (merged and published as a preview Vault package first)
- `architecture-infra-setup` (portal walkthroughs for vault/OIDC provisioning)
- `actions-oidc-and-secret-cleanup` (reusable OIDC deploy workflow)

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Bring Data bootstrap in line with ADR-0005/0006 and make Tier-1 SQL-key rotation work end-to-end.
**Target:** HoneyDrunk.Data, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave
- ADRs: ADR-0005 (Configuration and Secrets Strategy — per-Node Key Vaults, env-var discovery, three-tier config split), ADR-0006 (Secret Rotation and Lifecycle — five-tier rotation, Event Grid cache invalidation)

**Acceptance Criteria:** As listed above

**Dependencies:** `vault-bootstrap-extensions` and `vault-event-driven-cache-invalidation` merged and published as a preview Vault package before this lands.

**Constraints:**
- **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. This includes migration tooling.
- **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005. Data's vault: `kv-hd-data-{env}`.
- **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006. Especially important because EF Core connection pooling tempts caching.
- `kv-hd-data-{env}` is 13 chars total, well within limits

**Key Files:**
- `Program.cs`
- SQL Server provider connection factory
- `appsettings*.json`
- Migration runner entry points
- `.github/workflows/*.yml`

**Contracts:** None changed.
