# Node Audit: HoneyDrunk.Vault

**Auditor:** node-audit agent
**Date:** 2026-06-23
**Verdict:** Drifting

## Recommendation Breakdown

- **App Configuration bootstrap rejects isolated-worker host composition**
  - Recommendation: promote
  - Why: `AddAppConfiguration()` is the ADR-0005 bootstrap seam for deployable Nodes, but the current implementation requires `IConfiguration` to be a mutable `IConfigurationManager`; ADR-0015 implementation notes show this already crashed Notify.Functions and forced a consumer-side workaround.
  - Proposed packet path: `generated/work-items/proposed/2026-06-23-vault-add-host-builder-app-configuration-bootstrap.md`
  - Human action: Triage the packet into active work before the next deployable Function or worker host adopts Vault bootstrap.
  - Urgency: high
  - Dedupe/Skipped reason: _None._

- **Architecture catalog and context drift from Vault 0.7.0**
  - Recommendation: promote
  - Why: Architecture still records Vault as 0.5.0 in the repo overview and compatibility matrix, omits the current AppConfiguration/EventGrid packages from the package surface, and lacks the required `repos/HoneyDrunk.Vault/active-work.md` context file.
  - Proposed packet path: `generated/work-items/proposed/2026-06-23-architecture-reconcile-vault-catalog-context.md`
  - Human action: Triage the packet into active work so future audits, review agents, and catalog consumers see current Vault truth.
  - Urgency: normal
  - Dedupe/Skipped reason: _None._

## Identity and Intent

HoneyDrunk.Vault is a Core-sector Live Node and the Grid's canonical source of secrets and configuration. Architecture says other Nodes consume it through `ISecretStore` and `IConfigProvider`, not provider SDKs directly (`repos/HoneyDrunk.Vault/overview.md:10`). Its boundary owns unified secret access, provider fallback, in-memory caching, resilience policies, provider-slot interfaces, secure telemetry, and the `SecretIdentifier` / `SecretValue` / `VaultResult<T>` models; it does not own application-level configuration, Auth token management, storage backends outside provider packages, or encryption (`repos/HoneyDrunk.Vault/boundaries.md`). ADR-0005 governs env-var bootstrapping through `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT`; ADR-0006 governs rotation and Event Grid cache invalidation; ADR-0026 governs tenant-scoped secret resolution as a Vault usage pattern.

The local audited repo exists at `C:\Users\tatte\source\repos\HoneyDrunkStudios\HoneyDrunk.Vault`. That checkout is on `main` at `6e9beb5c29004abbff0acff898c71ce3215a4515` (2026-05-30) and reports `main...origin/main [behind 1]`, so exact file contents may be one commit behind remote `main`. The audit did not run build or test commands because this scheduled job's write boundary excludes the audited Node repository.

## Drift from Definition

**Changes Requested - Architecture metadata is stale.** `repos/HoneyDrunk.Vault/overview.md:4` records version `0.5.0`, and `catalogs/compatibility.json:20-23` records `honeydrunk-vault` at `0.5.0` compatible with Kernel `>=0.7.0`. The audited repo's package projects are all `0.7.0`, and the core package references `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions` `0.8.0`. This is catalog drift that can mislead downstream consumers and future automated compatibility checks.

**Changes Requested - Architecture package surface is incomplete.** The repo now ships `HoneyDrunk.Vault.Providers.AppConfiguration` and `HoneyDrunk.Vault.EventGrid`, both visible in the solution and package projects, but Architecture's Vault package list in `catalogs/relationships.json` omits them. `catalogs/contracts.json` includes `TenantScopedSecretResolver`, but does not expose the Event Grid invalidation package or the App Configuration bootstrap package as part of the Vault package surface. This understates the Node's ADR-0005/0006 delivery surface.

**Changes Requested - Vault context folder is missing `active-work.md`.** `repos/HoneyDrunk.Vault/` contains `overview.md`, `boundaries.md`, `invariants.md`, and `integration-points.md`, but not `active-work.md`. The Grid context-folder convention expects all five files so scope and review agents have the current in-flight work surface.

## Boundary Overlap

No direct cross-Node ownership violation was detected in the local repo walk. Provider SDK usage is contained in provider packages: Azure Key Vault SDK usage is under `HoneyDrunk.Vault.Providers.AzureKeyVault`, AWS Secrets Manager SDK usage is under `HoneyDrunk.Vault.Providers.Aws`, and Azure App Configuration bootstrap is under `HoneyDrunk.Vault.Providers.AppConfiguration`. This matches the provider-slot boundary.

One Architecture-definition inconsistency remains: `repos/HoneyDrunk.Vault/boundaries.md` says Vault does not own application-level configuration, while still owning `IConfigProvider` and App Configuration bootstrap. This is not a code violation, but the context packet should clarify that Vault owns the provider seam and bootstrap surface, while applications own the configuration models and values they read.

## Producer Quality

Vault is consumed by Auth, NovOutbox, Payments, and planned AI/Observe/Rotation consumers per `catalogs/relationships.json`. The repo exposes `ISecretStore`, `IConfigProvider`, `IVaultClient`, `ISecretProvider`, `IConfigSource`, `ISecretCacheInvalidator`, and `TenantScopedSecretResolver`, with package READMEs and package changelogs present. XML docs are enabled in package projects. The current contract surface appears broad but intentional for a pre-1.0 provider-slot Node.

**Changes Requested - App Configuration bootstrap is too host-shape-specific.** `HoneyDrunk.Vault.Providers.AppConfiguration/Extensions/AppConfigurationBootstrapExtensions.cs:39` resolves `IConfiguration` from services, then lines 51-54 and 85-88 throw unless that resolved instance is `IConfigurationManager`. ADR-0015 implementation notes record the production symptom: Notify.Functions isolated worker crashed because `FunctionsApplication.CreateBuilder` did not register a mutable `ConfigurationManager` as the `IConfiguration` service, forcing Notify #56 to register `builder.Configuration` before Vault bootstrap. The package currently has tests for `ConfigurationManager`-backed registration, development fallback, and missing endpoint errors, but no generic host / Functions-style builder coverage. Because ADR-0005 makes `AddAppConfiguration()` the env-var bootstrap seam for deployable Nodes, this is a producer-quality defect.

## Consumer Quality

Vault consumes Kernel and Kernel.Abstractions. The audited repo's core package references `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions` `0.8.0`, which is newer than Architecture's compatibility row for Vault. Provider packages reference the Vault runtime package by project reference and keep provider SDKs in provider packages.

No evidence was found that Vault reads secret values directly from environment variables. The environment variable reads observed in `BootstrapConfigurationResolver` and App Configuration bootstrap are for the ADR-0005 bootstrap keys and node/environment metadata, which are explicitly bootstrap configuration, not application secrets.

## Job Performance

The repo has a `HoneyDrunk.Vault.Tests` project, a canary test folder, package READMEs, per-package changelogs, and PR workflows. `pr.yml` consumes `HoneyDrunk.Actions` `pr-core.yml` with secret scanning, coverage thresholds, and SonarQube Cloud. `.honeydrunk-review.yaml` is enabled for the local worker.

**Suggestion - solution metadata references a stale workflow filename.** `HoneyDrunk.Vault.slnx` includes `../.github/workflows/validate-pr.yml`, but the repo contains `.github/workflows/pr.yml`. This looks like IDE/solution metadata drift. It is not packeted because it is low urgency and can be folded into normal repo maintenance.

## Cross-Cutting Health

No committed secret values were identified in the inspected source and docs. Tests explicitly cover secret-value redaction in telemetry. The audit did not run a secret scan or dependency vulnerability scan because executing build/test/restore tooling would write into the audited repository and exceed this scheduled job's allowed write paths.

The local Vault checkout is one commit behind `origin/main`; any human triage should verify the head state before filing the Vault implementation packet as a GitHub issue. The finding is still high confidence because both the Architecture implementation note and the inspected code point to the same host-builder compatibility issue.

## Findings Summary

### Blocking

- None detected.

### Changes Requested

- **Producer Quality - Host builder compatibility:** `AddAppConfiguration()` throws unless `IConfiguration` is a mutable `IConfigurationManager`, and the ADR-0015 implementation notes show this already crashed a Functions isolated-worker host. Add an overload or resolver path that can use `IHostApplicationBuilder` / host-builder configuration without requiring every consumer to register a workaround.
- **Drift from Definition - Architecture metadata:** Architecture records Vault as `0.5.0`, omits current packages from its package surface, and lacks `repos/HoneyDrunk.Vault/active-work.md`. Reconcile the catalog and context folder to Vault `0.7.0`.

### Suggestions

- **Job Performance - Solution metadata:** Refresh `HoneyDrunk.Vault.slnx` so it references `.github/workflows/pr.yml` instead of the stale `validate-pr.yml` filename.
- **Boundary Wording - Configuration ownership:** Clarify Vault owns the `IConfigProvider` and App Configuration bootstrap seam, while application Nodes own their configuration models and values.

## Recommended Handoffs

1. **Fix Vault App Configuration host-builder compatibility** -> `scope` packet for `HoneyDrunk.Vault`, then Codex implementation in the Vault repo.
2. **Reconcile Vault catalog/context drift** -> `scope` packet for `HoneyDrunk.Architecture`, then Codex metadata cleanup in this repo.
3. **Refresh stale solution workflow file reference** -> batch into a future Vault maintenance packet; not urgent enough for this tactical run.

## Checklist

- [x] Architecture context fully loaded
- [x] Repo walked on disk
- [x] Drift from definition
- [x] Boundary overlap
- [x] Producer quality
- [x] Consumer quality
- [x] Job performance
- [x] Cross-cutting health
