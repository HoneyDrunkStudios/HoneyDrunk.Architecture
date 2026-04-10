---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0005"]
dependencies: ["vault-bootstrap-extensions", "vault-event-driven-cache-invalidation", "architecture-infra-setup", "actions-oidc-and-secret-cleanup"]
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: pulse
---

# Feature: Migrate HoneyDrunk.Pulse config bootstrap to `AZURE_KEYVAULT_URI` + `AZURE_APPCONFIG_ENDPOINT`

## Summary
Switch Pulse and Pulse.Collector to env-driven `AddVault` + `AddAppConfiguration` wiring, move sink credentials (Loki/Tempo/Mimir/PostHog/Sentry/OTLP) to `ISecretStore`, and register the Event Grid cache-invalidation webhook. Pulse is pending production deployment — this packet is the deployment gate.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Pulse`

## Motivation
Pulse.Collector is a long-running OTLP receiver and must not hold stale sink credentials. ADR-0005/0006 define the bootstrap + propagation contract; this packet brings Pulse into line before it ships to production. The sink surface is mostly third-party (PostHog, Sentry, Loki/Tempo/Mimir auth tokens) — all are Tier-2 rotation candidates.

## Proposed Implementation
- `builder.AddVault()` + `builder.AddAppConfiguration()` in both Pulse host and Pulse.Collector host
- Sink credentials as provider-grouped secrets:
  - `PostHog--ApiKey`
  - `Sentry--Dsn`
  - `Loki--BasicAuth` (or `Loki--Username` + `Loki--Password`)
  - `Tempo--BasicAuth`
  - `Mimir--BasicAuth`
  - `Otlp--Headers` (if any auth header is needed)
- Non-secret config (endpoints, sampling, batch sizes) → App Configuration label `pulse` (matches the existing `id: "pulse"` in `catalogs/nodes.json`)
- Sink implementations must resolve credentials via `ISecretStore` and honor cache invalidation — not at process start
- Webhook registration on both host flavors
- CI to OIDC workflow

## Affected Packages
- `HoneyDrunk.Pulse` (runtime)
- `HoneyDrunk.Pulse.Collector` (OTLP receiver)
- All sink packages (`HoneyDrunk.Pulse.Sinks.*`)

## Boundary Check
- [x] Sink credential handling belongs in Pulse
- [x] Telemetry responsibilities unchanged — only bootstrap surface moves

## Acceptance Criteria
- [ ] Startup uses env-driven extensions in both hosts
- [ ] Zero direct env-var secret reads in sink implementations
- [ ] Provider-grouped secret naming
- [ ] Non-secret config from App Configuration with `pulse` label
- [ ] Event Grid invalidation webhook registered in both hosts
- [ ] Rotation canary on at least one sink credential
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
- **§Isolation:** Each deployable Node gets one Key Vault per environment (`kv-hd-{service}-{env}`), mirroring `rg-hd-{service}-{env}` 1:1. No shared vault. 24-char Azure limit means service names ≤ 13 chars.

**ADR-0006 (Secret Rotation and Lifecycle):** Five-tier rotation model — Azure-native rotation (≤30d), third-party rotation via `HoneyDrunk.Vault.Rotation` Function (≤90d), Event Grid cache invalidation on `SecretNewVersionCreated`, audit via Log Analytics, and deploy-blocking rotation SLAs.
- **§Tier 3:** Each Key Vault has an Event Grid subscription on `SecretNewVersionCreated`. A Function/webhook invalidates the `HoneyDrunk.Vault` cache entry. Next `ISecretStore` read fetches latest version. TTL becomes fallback, not primary mechanism. Apps must never pin to a version.
- **§Tier 5:** Rotation SLAs — Azure-native ≤30d, third-party ≤90d, certificates auto-renewed ≥30d before expiry. Exceeding SLA blocks deploys until resolved.

## Context
- ADR-0005, ADR-0006
- Invariants 8, 9, 17, 18, 21
- Active initiative: Ops Observability Pipeline (production deployment pending — this packet is the deployment gate)
- Note: `catalogs/nodes.json` Pulse entry has id `pulse` not `honeydrunk-pulse`; use `pulse` as the App Configuration label to match

## Dependencies
- `vault-bootstrap-extensions` + `vault-event-driven-cache-invalidation` (merged and published as a preview Vault package first)
- `architecture-infra-setup` (portal walkthroughs for vault/OIDC provisioning)
- `actions-oidc-and-secret-cleanup` (reusable OIDC deploy workflow)

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Bring Pulse + Pulse.Collector bootstrap in line with ADR-0005/0006 before production deployment.
**Target:** HoneyDrunk.Pulse, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave + unblock Pulse production deployment
- Feature: Configuration/rotation rollout + Ops Observability Pipeline
- ADRs: ADR-0005 (Configuration and Secrets Strategy), ADR-0006 (Secret Rotation and Lifecycle)

**Acceptance Criteria:** As listed above

**Dependencies:** `vault-bootstrap-extensions` and `vault-event-driven-cache-invalidation` merged and published as a preview Vault package before this lands.

**Constraints:**
- Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. Telemetry sink outputs must never contain raw credentials, even during debug.
- Invariant 9 — Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.
- Invariant 17 — One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. `kv-hd-pulse-{env}` (5 chars).
- Invariant 21 — Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation.

**Key Files:**
- `Program.cs` for Pulse + Pulse.Collector
- Sink projects under `HoneyDrunk.Pulse.Sinks.*`
- `appsettings*.json`
- `.github/workflows/*.yml`

**Contracts:** None changed.
