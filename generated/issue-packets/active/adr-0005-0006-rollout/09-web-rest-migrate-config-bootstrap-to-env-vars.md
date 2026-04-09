---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.Rest
labels: ["feature", "tier-2", "core", "infrastructure", "adr-0005"]
dependencies: ["vault-env-driven-add-vault-wiring", "vault-add-app-configuration-extension", "vault-event-driven-cache-invalidation"]
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
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

## Context
- ADR-0005, ADR-0006
- Invariants 8, 9, 17, 18, 21

## Dependencies
- Wave 1 Vault packets
- `architecture-infra-portal-walkthroughs`
- `actions-oidc-federated-credentials-workflow`

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Bring Web.Rest bootstrap in line with ADR-0005/0006.
**Target:** HoneyDrunk.Web.Rest, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave
- ADRs: ADR-0005, ADR-0006

**Acceptance Criteria:** As listed above

**Dependencies:** Wave 1 Vault packets merged + preview packages available

**Constraints:**
- Invariant 9 — `ISecretStore` only
- Invariant 17 — `kv-hd-webrest-{env}` (service name `webrest`, 7 chars — within 13-char budget)
- Invariant 21 — no version pinning

**Key Files:**
- `Program.cs`
- `appsettings*.json`
- `.github/workflows/*.yml`

**Contracts:** None changed.
