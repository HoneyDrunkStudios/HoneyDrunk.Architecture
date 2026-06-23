---
title: Add host-builder-compatible App Configuration bootstrap
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault
node: HoneyDrunk.Vault
wave: 1
tier: tier-2
labels:
  - bug
  - tier-2
  - sector-core
adrs:
  - ADR-0005
  - ADR-0043
initiative: tactical-node-audit
dependencies: []
source: tactical
generator: node-audit
---

# Add host-builder-compatible App Configuration bootstrap

## Summary

Make `HoneyDrunk.Vault.Providers.AppConfiguration.AddAppConfiguration()` work with host builders whose service collection exposes `IConfiguration` but not a mutable `IConfigurationManager`, so deployable Function and worker hosts do not need a consumer-side workaround.

## Context

The 2026-06-23 tactical audit for Vault found that `HoneyDrunk.Vault.Providers.AppConfiguration/Extensions/AppConfigurationBootstrapExtensions.cs` resolves `IConfiguration` from `builder.Services` and throws if the instance is not `IConfigurationManager`.

Audit report: `generated/audits/HoneyDrunk.Vault-2026-06-23.md`

ADR-0015 implementation notes already captured the production symptom from Notify.Functions: the isolated worker crashed on startup with `App Configuration bootstrap requires a mutable IConfigurationManager instance on the service collection`, because `FunctionsApplication.CreateBuilder` did not register a mutable `ConfigurationManager` as `IConfiguration`. Notify #56 fixed the consumer side by registering `builder.Configuration` before Vault bootstrap, but the durable fix belongs in Vault.

ADR-0005 makes `AddAppConfiguration()` the canonical deploy-time bootstrap seam: `AZURE_APPCONFIG_ENDPOINT` reaches Nodes through environment configuration, and the extension uses Managed Identity / `DefaultAzureCredential` to connect to shared App Configuration with per-Node labels.

## Scope

- Update `HoneyDrunk.Vault.Providers.AppConfiguration`.
- Prefer an overload or resolver path that can take an `IHostApplicationBuilder` or equivalent host-builder configuration surface when available.
- Preserve the existing `IHoneyDrunkBuilder AddAppConfiguration(...)` API for current consumers.
- Keep endpoint discovery through `AZURE_APPCONFIG_ENDPOINT` and label partitioning through `HONEYDRUNK_NODE_ID`.
- Add tests that cover a host-builder shape where `IConfiguration` is present but is not itself `IConfigurationManager`.
- Update the repo-level and package-level changelogs because this changes shipped bootstrap behavior.

## Acceptance Criteria

- [ ] `AddAppConfiguration()` no longer requires each consumer to manually register a mutable `ConfigurationManager` workaround before calling Vault bootstrap.
- [ ] Existing ASP.NET Core / `ConfigurationManager` callers keep working.
- [ ] A new test covers the isolated-worker / generic-host composition case that previously threw.
- [ ] Missing `AZURE_APPCONFIG_ENDPOINT` in non-development environments still fails fast with a clear error.
- [ ] Development fallback behavior remains covered and unchanged unless deliberately replaced with an equivalent host-builder-safe path.
- [ ] No secret values, connection strings with credentials, tokens, webhook URLs, customer PII, or full stack traces are logged, traced, added to tests, or copied into docs.
- [ ] Repo-level `CHANGELOG.md` and `HoneyDrunk.Vault.Providers.AppConfiguration/CHANGELOG.md` document the fix.
- [ ] `dotnet test HoneyDrunk.Vault.slnx -c Release` passes from the repo solution directory.

## Human Prerequisites

None.

## Dependencies

None.

## Constraints

- Grid invariant 8: Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.
- Grid invariant 18: Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.
- Grid invariant 12: Semantic versioning with CHANGELOG and README. Repo-level `CHANGELOG.md` is mandatory and covers the full release holistically. Per-package `CHANGELOG.md` carries detailed entries when that package has functional changes.
- Grid invariant 27: All projects in a solution share one version and move together. If this fix warrants a version bump, every non-test `.csproj` in the solution must be updated to the same new version in one commit, and repo/package changelogs must follow the invariant 12 alignment rules.
- Vault boundary: Vault owns unified secret access via `ISecretStore`, multi-provider support with automatic fallback, in-memory caching with configurable TTL, resilience policies, the provider-slot pattern through `ISecretProvider`, secure telemetry that never logs secret values, and `SecretIdentifier`, `SecretValue`, and `VaultResult<T>` models.
- Vault boundary: Vault does not own application-level configuration. Vault provides `IConfigProvider` and bootstrap/provider seams; applications define their own configuration models and decide which non-secret values they read.
- ADR-0005 bootstrap rule: `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service application settings at deploy time. Neither value is a secret. From that point forward, Managed Identity handles auth and no further wiring is required.

## Agent Handoff

**Objective:** Make Vault's App Configuration bootstrap work in ASP.NET Core, generic host, and Azure Functions isolated-worker composition without consumer-side registration hacks.

**Target:** HoneyDrunk.Vault, branch from `main`

**Context:**
- Goal: ADR-0043 tactical audit follow-up
- Feature: Vault App Configuration bootstrap reliability
- ADRs: ADR-0005, ADR-0043

**Acceptance Criteria:**
- [ ] Existing and new bootstrap tests pass.
- [ ] The previous Functions isolated-worker crash shape is represented by a regression test.
- [ ] Changelogs are updated for the behavior change.

**Dependencies:**
- None.

**Constraints:**
- Do not move App Configuration policy or application-specific settings into Vault. Vault owns the bootstrap/provider seam, not consumer configuration models.
- Do not log, trace, or include secret values in exceptions, telemetry, tests, docs, or PR prose.
- Preserve env-var bootstrap; do not derive endpoints from Node names or Azure naming conventions.

**Key Files:**
- `HoneyDrunk.Vault/HoneyDrunk.Vault.Providers.AppConfiguration/Extensions/AppConfigurationBootstrapExtensions.cs`
- `HoneyDrunk.Vault/HoneyDrunk.Vault.Providers.AppConfiguration/Extensions/BootstrapConfigurationResolver.cs`
- `HoneyDrunk.Vault/HoneyDrunk.Vault.Tests/Extensions/AppConfigurationBootstrapExtensionsTests.cs`
- `HoneyDrunk.Vault/CHANGELOG.md`
- `HoneyDrunk.Vault/HoneyDrunk.Vault.Providers.AppConfiguration/CHANGELOG.md`

**Contracts:**
- `IHoneyDrunkBuilder AddAppConfiguration(this IHoneyDrunkBuilder builder, Action<AppConfigurationOptions>? configure = null)`
- Any new overload must remain additive unless a separate breaking-change decision is explicitly made.
