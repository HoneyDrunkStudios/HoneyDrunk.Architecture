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

# Feature: Env-var-driven bootstrap extensions (`AddVault` + `AddAppConfiguration`)

## Summary
Add two sibling builder extensions on `HoneyDrunk.Vault` that let every deployable Node bootstrap its Azure Key Vault and Azure App Configuration from two environment variables — `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` — without passing URIs in code. Together they implement the full ADR-0005 bootstrap contract.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault`

## Motivation
ADR-0005 fixes the bootstrap contract: two env vars are set as App Service application settings at deploy time, and the Vault extensions read them. Convention-based derivation from Node name was rejected. Currently `AddVault` requires callers to construct their own provider wiring, and no `AddAppConfiguration` helper exists at all — so every Node duplicates Azure Key Vault and App Configuration registration boilerplate and couples application code to infra naming.

This packet delivers both halves of the ADR-0005 bootstrap story as one coherent unit: a human developer would get both in one sprint story because they're the same API surface, the same testing story, and the same consuming Nodes.

## Part A — `AddVault` env-var wiring

### Proposed Implementation
- Add an overload / new method on `HoneyDrunkBuilderExtensions` (path: `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/HoneyDrunkBuilderExtensions.cs`) that:
  - Reads `AZURE_KEYVAULT_URI` from `IConfiguration` (so any standard .NET config source can override — env var wins by convention in Azure App Service)
  - If present, wires the `HoneyDrunk.Vault.Providers.AzureKeyVault` provider with `DefaultAzureCredential`
  - If absent and running in `Development`, falls back to the `File` provider against `secrets/dev-secrets.json`
  - If absent in any non-Development environment, throws a clear bootstrap exception naming the env var
- Do not introduce a new runtime dependency between `HoneyDrunk.Vault` and `HoneyDrunk.Vault.Providers.AzureKeyVault`. Keep the Azure provider optional — the new extension should live in the AzureKeyVault provider package (or a thin new `HoneyDrunk.Vault.Providers.AzureKeyVault.Bootstrap` extension) so a Node opts into Azure-default bootstrap explicitly via package reference.
- Works identically in dev, CI, and Azure because `DefaultAzureCredential` handles all three.

### Acceptance Criteria — Part A
- [ ] New extension method reads `AZURE_KEYVAULT_URI` from `IConfiguration` and wires the AzureKeyVault provider
- [ ] `DefaultAzureCredential` is used so dev (`az login`), CI (OIDC), and Azure (Managed Identity) all work
- [ ] Missing env var in non-Development throws a descriptive exception (includes the env var name and a pointer to ADR-0005)
- [ ] File provider remains the zero-friction dev default when env var is absent and `ASPNETCORE_ENVIRONMENT=Development`
- [ ] Unit tests cover: URI present, URI absent + Dev, URI absent + non-Dev (throws)
- [ ] XML docs on the new method cross-reference ADR-0005 and invariants 17, 18

## Part B — `AddAppConfiguration` builder extension

### Proposed Implementation
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

### Acceptance Criteria — Part B
- [ ] `AddAppConfiguration` method exists and is discoverable on the builder
- [ ] Reads `AZURE_APPCONFIG_ENDPOINT` via `IConfiguration`
- [ ] Configures `AzureAppConfiguration` with `DefaultAzureCredential` and per-Node label from `HONEYDRUNK_NODE_ID`
- [ ] Resolves Key Vault references via the same credential (no fresh credential chain)
- [ ] Feature flags reachable via `IFeatureManager`
- [ ] Missing endpoint in non-Development throws with a pointer to ADR-0005
- [ ] Unit tests: endpoint present, endpoint absent + Dev, endpoint absent + Prod
- [ ] XML docs reference ADR-0005, invariants 17–18

## Shared Acceptance Criteria
- [ ] Both extensions ship in the same PR and in the same preview package version so per-Node migrations consume them together
- [ ] CHANGELOG updated
- [ ] Canary: consuming Node bootstraps with only `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` set

## Affected Packages
- `HoneyDrunk.Vault` (core — extension surface)
- `HoneyDrunk.Vault.Providers.AzureKeyVault` (new env-var bootstrap entry)
- New: `HoneyDrunk.Vault.Providers.AppConfiguration` (or co-located under the AzureKeyVault bootstrap package — decide during implementation, keep both extensions consistent)

## NuGet Dependencies

### `HoneyDrunk.Vault.Providers.AzureKeyVault` — additions to existing project
| Package | Notes |
|---|---|
| `Azure.Extensions.AspNetCore.Configuration.Secrets` (latest stable) | Azure Key Vault as an `IConfiguration` source — required for the `AddVault` env-driven bootstrap |

### New: `HoneyDrunk.Vault.Providers.AppConfiguration`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | StyleCop + EditorConfig analyzers — required on every HoneyDrunk .NET project |
| `Azure.Identity` (latest stable) | `DefaultAzureCredential` for App Configuration + KV reference resolution |
| `Microsoft.Extensions.Configuration.AzureAppConfiguration` (latest stable) | Core App Configuration client |
| `Microsoft.Azure.AppConfiguration.AspNetCore` (latest stable) | ASP.NET Core integration, refresh middleware |
| `Microsoft.FeatureManagement.AspNetCore` (latest stable) | `IFeatureManager` / feature flag support |
| ProjectRef: `HoneyDrunk.Vault` | Dependency on the core secret store abstraction |

## Boundary Check
- [x] Feature is within HoneyDrunk.Vault's stated responsibility: secret store and config provider wiring
- [x] Does not duplicate any other Node's responsibility
- [x] No new cross-Node dependency — deployable Nodes consume via existing builder API
- [x] Does not overlap with Kernel (`IGridContext`, options) — Kernel stays unchanged
- [x] Label partitioning keeps the shared App Config store blast-radius bounded

## Referenced Invariants

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.

## Referenced ADR Decisions

**ADR-0005 (Configuration and Secrets Strategy):** Per-deployable-Node Key Vaults (`kv-hd-{service}-{env}`), `{Provider}--{Key}` secret naming, Managed Identity + Azure RBAC access, three-tier config split (Key Vault for secrets, App Configuration for non-secret config, env vars for bootstrap only), and env-var-driven discovery (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`).
- **§Bootstrap:** `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service application settings at deploy time. `AddVault(...)` reads the vault URI; `AddAppConfiguration(...)` reads the App Config endpoint. Both use `DefaultAzureCredential`. Convention-based derivation from Node name was rejected.
- **§Three-tier configuration split:** Secrets go in Key Vault, non-secret config goes in shared App Configuration (`appcs-hd-shared-{env}`) with label-per-Node partitioning, env vars are bootstrap only (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT`, `HONEYDRUNK_NODE_ID`).
- **§Access:** Runtime uses system-assigned Managed Identity with `Key Vault Secrets User` on own vault only. CI uses OIDC federated credentials with `Key Vault Secrets Officer`. Local dev uses File provider or `DefaultAzureCredential` via `az login`. Access policies and client secrets are forbidden.

## Context
- ADR-0005 §Bootstrap, §Three-tier configuration split, §Access
- Invariants 4, 8, 9, 17, 18
- Current implementation: `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/HoneyDrunkBuilderExtensions.cs`
- Azure App Configuration client library: `Microsoft.Azure.AppConfiguration.AspNetCore`

## Dependencies
None — foundational. Blocks all per-Node migration packets.

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Ship both env-driven bootstrap extensions — `AddVault` reading `AZURE_KEYVAULT_URI`, and `AddAppConfiguration` reading `AZURE_APPCONFIG_ENDPOINT` — as the foundational surface every deployable Node will consume.
**Target:** HoneyDrunk.Vault, branch from `main`
**Context:**
- Goal: Implement the full ADR-0005 bootstrap contract in one coherent change
- Feature: Configuration & secrets strategy rollout
- ADRs: ADR-0005 (per-deployable-Node Key Vaults, env-var bootstrap, Managed Identity + RBAC, three-tier config split)

**Acceptance Criteria:**
- [ ] As listed in Part A, Part B, and Shared sections above

**Dependencies:** None. This is the foundational piece; per-Node migration packets depend on it being merged and published as a preview package first.

**Constraints:**
- Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry. The vault URI and App Config endpoint themselves are non-secret per ADR-0005, so logging them at Information once on startup is acceptable.
- Invariant 9 — Vault is the only source of secrets. App Configuration's KV-reference resolution must not bypass `ISecretStore` for anything classified as a secret; use KV references only for secret-adjacent config values.
- Invariant 4 — No circular dependency from Vault back into Kernel runtime.
- Do not add a hard runtime dependency from `HoneyDrunk.Vault` to `HoneyDrunk.Vault.Providers.AzureKeyVault` or `HoneyDrunk.Vault.Providers.AppConfiguration`. Both provider packages must remain opt-in via explicit package reference.

**Key Files:**
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/HoneyDrunkBuilderExtensions.cs`
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault.Providers.AzureKeyVault/` (new env-var bootstrap entry)
- New: `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault.Providers.AppConfiguration/`
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault.Tests/`

**Contracts:**
- New public extension: `IHoneyDrunkBuilder AddVault(this IHoneyDrunkBuilder)` env-driven overload
- New public extension: `IHoneyDrunkBuilder AddAppConfiguration(this IHoneyDrunkBuilder, Action<AppConfigurationOptions>?)`
- New `AppConfigurationOptions` type for optional label overrides and refresh policies
- No behavioral change to existing explicit `AddVault` overloads
