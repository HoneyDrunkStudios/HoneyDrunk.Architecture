---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.Rest
labels: ["feature", "tier-2", "core", "infrastructure", "adr-0005"]
dependencies: ["vault-bootstrap-extensions", "vault-event-driven-cache-invalidation", "architecture-infra-setup", "actions-oidc-and-secret-cleanup"]
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: honeydrunk-web-rest
---

# Feature: Migrate HoneyDrunk.Web.Rest config bootstrap to `AZURE_KEYVAULT_URI` + `AZURE_APPCONFIG_ENDPOINT`

## Summary
Switch Web.Rest's startup wiring to the new env-var-driven `AddVault` + `AddAppConfiguration` extensions, remove direct secret reads, consume non-secret config from shared App Configuration under the `honeydrunk-web-rest` label, and register the Event Grid cache-invalidation webhook.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Web.Rest`

## Motivation
Same as the Auth migration packet — ADR-0005 bootstrap contract + ADR-0006 rotation propagation. Web.Rest owns response envelopes and exception mapping; its secret surface is small (correlation signing, optional downstream API keys) but must still move to `ISecretStore`.

## Proposed Implementation
- Replace any explicit vault wiring in `Program.cs` with `builder.AddVault()` + `builder.AddAppConfiguration()`
- Audit all secret-adjacent reads, move them under `ISecretStore` with `{Provider}--{Key}` naming
- App Configuration label: `honeydrunk-web-rest` (matches `HONEYDRUNK_NODE_ID`)
- Map the `/internal/vault/invalidate` webhook from `HoneyDrunk.Vault.EventGrid`
- CI switch to OIDC reusable workflow — no client secrets
- Remove hardcoded URIs / secrets from `appsettings*.json`

## Affected Packages
- `HoneyDrunk.Web.Rest` (runtime)
- `HoneyDrunk.Web.Rest.*` sub-packages if any read `IConfiguration` for secrets

## Boundary Check
- [x] Bootstrap change is Web.Rest-internal
- [x] Response envelope and exception mapping logic untouched (invariant-aligned)

## Acceptance Criteria
- [ ] Startup uses only env-driven extensions
- [ ] Zero direct `IConfiguration` secret reads
- [ ] Secret names follow `{Provider}--{Key}`
- [ ] Non-secret config from App Configuration with Web.Rest label
- [ ] Event Grid invalidation webhook registered and tested
- [ ] CI uses OIDC — no client secrets
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

## Dependencies
- `vault-bootstrap-extensions` + `vault-event-driven-cache-invalidation` (merged and published as a preview Vault package first)
- `architecture-infra-setup` (portal walkthroughs for vault/OIDC provisioning)
- `actions-oidc-and-secret-cleanup` (reusable OIDC deploy workflow)

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Bring Web.Rest bootstrap in line with ADR-0005/0006.
**Target:** HoneyDrunk.Web.Rest, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave
- ADRs: ADR-0005 (Configuration and Secrets Strategy — per-Node Key Vaults, env-var discovery, three-tier config split), ADR-0006 (Secret Rotation and Lifecycle — five-tier rotation, Event Grid cache invalidation)

**Acceptance Criteria:** As listed above

**Dependencies:** `vault-bootstrap-extensions` and `vault-event-driven-cache-invalidation` merged and published as a preview Vault package before this lands.

**Constraints:**
- **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.
- **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005. Web.Rest's vault: `kv-hd-webrest-{env}` (service name `webrest`, 7 chars — within 13-char budget).
- **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006.

**Key Files:**
- `Program.cs`
- `appsettings*.json`
- `.github/workflows/*.yml`

**Contracts:** None changed.
