---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault
labels: ["feature", "tier-2", "core", "infrastructure", "adr-0005"]
dependencies: []
adrs: ["ADR-0005"]
wave: 1
initiative: adr-0005-0006-rollout
node: honeydrunk-vault
---

# Feature: Add `AddAppConfiguration` builder extension reading `AZURE_APPCONFIG_ENDPOINT`

## Summary
Introduce `HoneyDrunkBuilderExtensions.AddAppConfiguration(...)` that reads `AZURE_APPCONFIG_ENDPOINT` and wires Azure App Configuration with Managed Identity plus Key Vault references so non-secret config and feature flags reach every deployable Node without per-Node boilerplate.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault`

## Motivation
ADR-0005 establishes a three-tier config split: secrets in `kv-hd-{service}-{env}`, non-secrets in a shared `appcs-hd-shared-{env}`, and bootstrap env vars. Nodes need a one-liner to wire the shared App Configuration store, including label-per-Node partitioning and Key Vault reference resolution. This is the sibling of the env-driven `AddVault` extension.

## Proposed Implementation
- Add `AddAppConfiguration(this IHoneyDrunkBuilder builder, Action<AppConfigurationOptions>? configure = null)` in `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/HoneyDrunkBuilderExtensions.cs` (or a new AppConfiguration-specific provider package under `HoneyDrunk.Vault.Providers.AppConfiguration` — preferred, mirrors the AzureKeyVault provider split).
- Behavior:
  - Reads `AZURE_APPCONFIG_ENDPOINT` via `IConfiguration`
  - Uses `Microsoft.Extensions.Configuration.AzureAppConfiguration` with `DefaultAzureCredential`
  - Applies a per-Node label pulled from `HONEYDRUNK_NODE_ID` (required invariant per existing Kernel bootstrap) plus an optional `null`-label fallback for shared keys
  - Resolves Key Vault references automatically using the same `DefaultAzureCredential`
  - Registers `IFeatureManager` hooks so feature flags are queryable
  - In Development, falls back to reading `appsettings.Development.json` if the endpoint is absent
  - In non-Development, throws if the endpoint is absent
- No secret reads through this path — only non-secret config and KV-referenced secret-adjacent keys. Direct secret reads still go through `ISecretStore` (invariant 9).

## Affected Packages
- New: `HoneyDrunk.Vault.Providers.AppConfiguration` (or co-located under the AzureKeyVault bootstrap package — decide during implementation, keep consistent with `AddVault` packet)
- `HoneyDrunk.Vault` (extension surface only, if co-located)

## Boundary Check
- [x] Fits HoneyDrunk.Vault's stated role as the canonical config/secrets manager (see `repos/HoneyDrunk.Vault/overview.md`)
- [x] Does not overlap with Kernel (`IGridContext`, options) — Kernel stays unchanged
- [x] Label partitioning keeps the shared store blast-radius bounded

## Acceptance Criteria
- [ ] `AddAppConfiguration` method exists and is discoverable on the builder
- [ ] Reads `AZURE_APPCONFIG_ENDPOINT` via `IConfiguration`
- [ ] Configures `AzureAppConfiguration` with `DefaultAzureCredential` and per-Node label from `HONEYDRUNK_NODE_ID`
- [ ] Resolves Key Vault references via the same credential (no fresh credential chain)
- [ ] Feature flags reachable via `IFeatureManager`
- [ ] Missing endpoint in non-Development throws with a pointer to ADR-0005
- [ ] Unit tests: endpoint present, endpoint absent + Dev, endpoint absent + Prod
- [ ] XML docs reference ADR-0005, invariants 17–18
- [ ] CHANGELOG updated

## Context
- ADR-0005 §Three-tier configuration split and §Bootstrap
- Invariants 17, 18
- Azure App Configuration client library: `Microsoft.Azure.AppConfiguration.AspNetCore`

## Dependencies
None — foundational.

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Give every Node a one-liner to wire Azure App Configuration with MI + KV references.
**Target:** HoneyDrunk.Vault, branch from `main`
**Context:**
- Goal: Implement the `AddAppConfiguration` half of ADR-0005 bootstrap
- Feature: Configuration & secrets strategy rollout
- ADRs: ADR-0005

**Acceptance Criteria:**
- [ ] As listed in Acceptance Criteria above

**Dependencies:** None (can run in parallel with the `AddVault` wiring packet)

**Constraints:**
- Invariant 9 — secrets still flow only through `ISecretStore`. App Configuration's KV-reference resolution must not bypass `ISecretStore` for anything classified as a secret; use KV references only for secret-adjacent config values
- No circular dependency from Vault back into Kernel runtime

**Key Files:**
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/HoneyDrunkBuilderExtensions.cs`
- New provider project under `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault.Providers.AppConfiguration/`

**Contracts:**
- New public extension: `IHoneyDrunkBuilder AddAppConfiguration(this IHoneyDrunkBuilder, Action<AppConfigurationOptions>?)`
- New `AppConfigurationOptions` type for optional label overrides and refresh policies
