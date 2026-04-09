---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Data
labels: ["feature", "tier-2", "core", "infrastructure", "adr-0005"]
dependencies: ["vault-env-driven-add-vault-wiring", "vault-add-app-configuration-extension", "vault-event-driven-cache-invalidation"]
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

## Context
- ADR-0005, ADR-0006
- Invariants 8, 9, 17, 18, 21
- Data is already aligned to Kernel 0.4.0 (per active-initiatives), so this migration lands cleanly

## Dependencies
- Wave 1 Vault packets
- `architecture-infra-portal-walkthroughs`
- `actions-oidc-federated-credentials-workflow`

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Bring Data bootstrap in line with ADR-0005/0006 and make Tier-1 SQL-key rotation work end-to-end.
**Target:** HoneyDrunk.Data, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave
- ADRs: ADR-0005, ADR-0006

**Acceptance Criteria:** As listed above

**Dependencies:** Wave 1 Vault packets merged + preview packages available

**Constraints:**
- Invariant 9 — `ISecretStore` only, including for migration tooling
- Invariant 17 — `kv-hd-data-{env}`
- Invariant 21 — no version pinning; especially important because EF Core connection pooling tempts caching
- `kv-hd-data-{env}` is 13 chars total, well within limits

**Key Files:**
- `Program.cs`
- SQL Server provider connection factory
- `appsettings*.json`
- Migration runner entry points
- `.github/workflows/*.yml`

**Contracts:** None changed.
