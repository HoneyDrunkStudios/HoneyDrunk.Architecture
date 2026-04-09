---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Auth
labels: ["feature", "tier-2", "core", "infrastructure", "adr-0005"]
dependencies: ["vault-env-driven-add-vault-wiring", "vault-add-app-configuration-extension", "vault-event-driven-cache-invalidation"]
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: honeydrunk-auth
---

# Feature: Migrate HoneyDrunk.Auth config bootstrap to `AZURE_KEYVAULT_URI` + `AZURE_APPCONFIG_ENDPOINT`

## Summary
Switch Auth's startup wiring to the new env-var-driven `AddVault` + `AddAppConfiguration` extensions, remove any direct env-var or `appsettings` secret reads, adopt the shared App Configuration with per-Node label, and ensure it can receive Event Grid cache invalidation.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Auth`

## Motivation
ADR-0005 mandates every deployable Node bootstrap through two env vars and consume secrets exclusively via `ISecretStore`. ADR-0006 adds the expectation that rotated secrets propagate via Event Grid cache invalidation — the Node must expose the webhook endpoint from `HoneyDrunk.Vault.EventGrid`.

## Proposed Implementation
- Replace explicit vault URI configuration in Program.cs / startup with `builder.AddVault()` (new env-driven overload)
- Add `builder.AddAppConfiguration()` call, passing no URI — the extension reads `AZURE_APPCONFIG_ENDPOINT`
- Audit the codebase for any direct reads of secrets from `IConfiguration` / env vars / `appsettings*.json`. Replace every one with `ISecretStore.GetSecretAsync(name)` and provider-grouped PascalCase names (`Jwt--SigningKey`, `Auth--SomeProviderKey`, etc.). Invariant 9.
- Move non-secret settings (token lifetimes, issuer, feature flags) to App Configuration under the `honeydrunk-auth` label (matches `HONEYDRUNK_NODE_ID`)
- Register `/internal/vault/invalidate` webhook from the new `HoneyDrunk.Vault.EventGrid` helper so this Node's `SecretCache` is invalidated on `SecretNewVersionCreated`
- Add a `kv-hd-auth-{env}` vault provisioning note in the repo's `deployment.md` (portal walkthrough lives in Architecture — cross-link)
- Update CI workflow to use the new reusable OIDC workflow template (see `actions-oidc-federated-credentials-workflow` packet). Remove any `AZURE_CLIENT_SECRET` references.
- Remove any hardcoded vault URIs from `appsettings*.json` files

## Affected Packages
- `HoneyDrunk.Auth` (runtime host)
- Any `HoneyDrunk.Auth.*` packages that currently read secrets directly

## Boundary Check
- [x] Work is purely Auth's own bootstrap surface and its secret reads — no cross-Node API changes
- [x] Does not touch JWT validation logic (invariant 10 — Auth still validates, never issues)

## Acceptance Criteria
- [ ] `Program.cs` uses only `AddVault()` + `AddAppConfiguration()` (no explicit URIs)
- [ ] Zero direct `IConfiguration` reads for anything secret; verified by a canary test
- [ ] Secret names follow `{Provider}--{Key}` convention
- [ ] Non-secret config sourced from App Configuration with the Auth label
- [ ] Webhook endpoint registered and tested against a synthetic Event Grid event
- [ ] CI workflow uses OIDC federated credentials — no client secrets
- [ ] All existing tests pass
- [ ] CHANGELOG updated
- [ ] Canary test verifies `ISecretStore` is the only path to secret values

## Context
- ADR-0005 §Bootstrap, §Three-tier configuration split
- ADR-0006 §Tier 3
- Invariants 8, 9, 10, 17, 18, 21
- Active initiative: Grid v0.4 Stabilization — Auth is already aligned to Kernel 0.4, so this migration lands cleanly on top

## Dependencies
- `2026-04-09-vault-env-driven-add-vault-wiring.md`
- `2026-04-09-vault-add-app-configuration-extension.md`
- `2026-04-09-vault-event-driven-cache-invalidation.md`
- `2026-04-09-architecture-infra-portal-walkthroughs.md` (for vault/OIDC provisioning steps)
- `2026-04-09-actions-oidc-federated-credentials-workflow.md` (reusable CI workflow)

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Make Auth's bootstrap fully compliant with ADR-0005/0006.
**Target:** HoneyDrunk.Auth, branch from `main`
**Context:**
- Goal: ADR-0005/0006 per-Node migration wave
- Feature: Configuration & secrets strategy rollout
- ADRs: ADR-0005, ADR-0006

**Acceptance Criteria:**
- [ ] As listed above

**Dependencies:** Wave 1 Vault packets must be merged and released as a preview package before this lands.

**Constraints:**
- Invariant 9 — `ISecretStore` only
- Invariant 10 — Auth validates, does not issue
- Invariant 17 — `kv-hd-auth-{env}` vault per environment
- Invariant 21 — never pin secret versions

**Key Files:**
- `Program.cs`
- `appsettings*.json` (audit + clean)
- `.github/workflows/*.yml`
- Any `StartupExtensions.cs` / `AuthBuilderExtensions.cs`

**Contracts:** None changed — internal migration only.
