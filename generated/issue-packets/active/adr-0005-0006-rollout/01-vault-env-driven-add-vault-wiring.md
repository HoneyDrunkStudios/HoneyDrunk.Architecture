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

# Feature: Env-var-driven `AddVault` wiring for `AZURE_KEYVAULT_URI`

## Summary
Make `HoneyDrunkBuilderExtensions.AddVault(...)` read `AZURE_KEYVAULT_URI` from environment by convention so every deployable Node bootstraps the Azure Key Vault provider without passing URIs in code.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault`

## Motivation
ADR-0005 fixes the bootstrap contract: `AZURE_KEYVAULT_URI` is set as an App Service application setting at deploy time, and `AddVault` must read it. Convention-based URI derivation (from `HONEYDRUNK_NODE_ID`) was rejected. Currently `AddVault` requires callers to construct their own provider wiring — that forces every Node to duplicate the Azure Key Vault provider registration boilerplate and couples application code to infra naming.

This is the first half of the bootstrap story in ADR-0005. Its sibling is `AddAppConfiguration` (separate packet).

## Proposed Implementation
- Add an overload / new method on `HoneyDrunkBuilderExtensions` (path: `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/HoneyDrunkBuilderExtensions.cs`) that:
  - Reads `AZURE_KEYVAULT_URI` from `IConfiguration` (so any standard .NET config source can override — env var wins by convention in Azure App Service)
  - If present, wires the `HoneyDrunk.Vault.Providers.AzureKeyVault` provider with `DefaultAzureCredential`
  - If absent and running in `Development`, falls back to the `File` provider against `secrets/dev-secrets.json`
  - If absent in any non-Development environment, throws a clear bootstrap exception naming the env var
- Do not introduce a new runtime dependency between `HoneyDrunk.Vault` and `HoneyDrunk.Vault.Providers.AzureKeyVault`. Keep the Azure provider optional — the new extension should live in the AzureKeyVault provider package (or a thin new `HoneyDrunk.Vault.Providers.AzureKeyVault.Bootstrap` extension) so a Node opts into Azure-default bootstrap explicitly via package reference.
- Works identically in dev, CI, and Azure because `DefaultAzureCredential` handles all three.

## Affected Packages
- `HoneyDrunk.Vault` (core — extension surface)
- `HoneyDrunk.Vault.Providers.AzureKeyVault` (new env-var bootstrap entry)

## Boundary Check
- [x] Feature is within HoneyDrunk.Vault's stated responsibility: secret store provider wiring
- [x] Does not duplicate any other Node's responsibility
- [x] No new cross-Node dependency — deployable Nodes consume via existing builder API

## Acceptance Criteria
- [ ] New extension method reads `AZURE_KEYVAULT_URI` from `IConfiguration` and wires the AzureKeyVault provider
- [ ] `DefaultAzureCredential` is used so dev (`az login`), CI (OIDC), and Azure (Managed Identity) all work
- [ ] Missing env var in non-Development throws a descriptive exception (includes the env var name and a pointer to ADR-0005)
- [ ] File provider remains the zero-friction dev default when env var is absent and `ASPNETCORE_ENVIRONMENT=Development`
- [ ] Unit tests cover: URI present, URI absent + Dev, URI absent + non-Dev (throws)
- [ ] XML docs on the new method cross-reference ADR-0005 and invariants 17, 18
- [ ] CHANGELOG updated
- [ ] Canary: consuming Node bootstraps with only `AZURE_KEYVAULT_URI` set

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.

## Referenced ADR Decisions

**ADR-0005 (Configuration and Secrets Strategy):** Per-deployable-Node Key Vaults (`kv-hd-{service}-{env}`), `{Provider}--{Key}` secret naming, Managed Identity + Azure RBAC access, three-tier config split (Key Vault for secrets, App Configuration for non-secret config, env vars for bootstrap only), and env-var-driven discovery (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`).
- **§Bootstrap:** `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service application settings at deploy time. `AddVault(...)` reads the vault URI; `AddAppConfiguration(...)` reads the App Config endpoint. Both use `DefaultAzureCredential`. Convention-based derivation from Node name was rejected.
- **§Access:** Runtime uses system-assigned Managed Identity with `Key Vault Secrets User` on own vault only. CI uses OIDC federated credentials with `Key Vault Secrets Officer`. Local dev uses File provider or `DefaultAzureCredential` via `az login`. Access policies and client secrets are forbidden.

## Context
- ADR-0005 §Bootstrap and §Access
- Invariants 17, 18
- Current implementation: `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/HoneyDrunkBuilderExtensions.cs`

## Dependencies
None — foundational. Blocks all per-Node migration packets.

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Wire `AddVault` so deployable Nodes bootstrap Azure Key Vault from a single `AZURE_KEYVAULT_URI` env var.
**Target:** HoneyDrunk.Vault, branch from `main`
**Context:**
- Goal: Implement the bootstrap contract from ADR-0005 so every Node reaches its vault by convention
- Feature: Configuration & secrets strategy rollout
- ADRs: ADR-0005 (per-deployable-Node Key Vaults, env-var bootstrap, Managed Identity + RBAC, three-tier config split)

**Acceptance Criteria:**
- [ ] Extension method compiles and is discoverable on the builder
- [ ] Env var read goes through `IConfiguration`, not `Environment.GetEnvironmentVariable`
- [ ] Tests listed above pass
- [ ] No behavioral change when callers use the existing explicit `AddVault` overloads

**Dependencies:** None

**Constraints:**
- Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. Note: the vault URI itself is non-secret per ADR-0005, so logging it at Information is acceptable once on startup.
- Invariant 9 — Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.
- Do not add a hard runtime dependency from `HoneyDrunk.Vault` to `HoneyDrunk.Vault.Providers.AzureKeyVault`

**Key Files:**
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/HoneyDrunkBuilderExtensions.cs`
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault.Providers.AzureKeyVault/` (new bootstrap extension)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault.Tests/`

**Contracts:**
- No public contract changes. Adds one new builder extension method.
