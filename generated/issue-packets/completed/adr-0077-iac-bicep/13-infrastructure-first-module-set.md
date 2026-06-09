---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Infrastructure
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0077", "wave-3"]
dependencies: ["packet:11"]
adrs: ["ADR-0077", "ADR-0012"]
wave: 3
initiative: adr-0077-iac-bicep
node: honeydrunk-infrastructure
---

# Author the first per-concern Bicep module set in HoneyDrunk.Infrastructure/modules/

> **Supersedes packets 03 and 05** (`Actions#118` and `Actions#120`). Packet 03 scaffolded `HoneyDrunk.Actions/bicep/modules/` + a root `bicepconfig.json`; packet 05 authored the first module set in Actions and tagged `modules/v1.0.0` to publish to `acrhdbicep`. Under the ADR-0077 amendment (2026-06-02): the modules library moves to `HoneyDrunk.Infrastructure/modules/` (the tree + root `bicepconfig.json` land in packet 11), the module bodies are authored here, and the tag-publish step DIES (no registry — modules are consumed by local relative path). Issues `Actions#118` and `Actions#120` are closed as superseded by packets 11 + 13.

## Summary
Author the first per-concern Bicep module set in `HoneyDrunk.Infrastructure/modules/` — the six concerns ADR-0077 names: `compute/containerApp.bicep`, `secrets/keyVault.bicep`, `secrets/appConfigurationStore.bicep`, `data/storageAccount.bicep`, `messaging/serviceBusNamespace.bicep`, and `observability/applicationInsights.bicep`. Each module applies the Grid naming and tagging conventions (D3) and references Vault for any secret-shaped input (D7). Modules are **consumed by local relative path** (e.g. `'../../modules/compute/containerApp.bicep'`) — there is NO publish step, NO `modules/v1.0.0` tag, NO `acrhdbicep` registry.

## Context
ADR-0077 D2 (principle unchanged by the amendment) commits modularize-by-concern. The amendment changes only the *home* (now `HoneyDrunk.Infrastructure/modules/`, scaffolded in packet 11) and the *distribution* (local relative path, not registry). The six concerns named in the original ADR's Follow-up Work are the v1 set; networking and identity modules land when a consumer first needs them.

Each module is a parameterized Bicep file enforcing D3:
- Required tags via a `tags` object parameter the consumer composes once and passes in.
- Name conventions via `@maxLength(13)` on the service/node name param + a name-composition expression building `{prefix}-hd-{name}-{env}`.
- Secret-shaped inputs use `keyVaultSecret` references / Vault URIs (D7) — never a raw secret param.

Consumers (per-Node leaf templates under `nodes/{node}/`, and `platform/` templates) reference these modules by **local relative path** since they share the repo:
```bicep
module identityApp '../../modules/compute/containerApp.bicep' = {
  name: 'identityApp'
  params: { service: 'identity', env: env, tags: tags, /* ... */ }
}
```

This packet does NOT author per-Node leaf templates (those are per-Node touchpoints, pattern documented by packet 15) and does NOT author `platform/` templates (packet 14).

## Scope
- `modules/compute/containerApp.bicep` (new) — Container App per invariant 34 (`ca-hd-{service}-{env}`, system-assigned MI, Multiple revision mode per invariant 36), consuming the shared Container Apps Environment by resource ID.
- `modules/secrets/keyVault.bicep` (new) — Key Vault per invariant 17 (`kv-hd-{service}-{env}`, Azure RBAC enabled, no access policies), with diagnostic settings to the shared Log Analytics workspace per invariant 22.
- `modules/secrets/appConfigurationStore.bicep` (new) — App Configuration store.
- `modules/data/storageAccount.bicep` (new) — Storage Account.
- `modules/messaging/serviceBusNamespace.bicep` (new) — Service Bus namespace.
- `modules/observability/applicationInsights.bicep` (new) — Application Insights (workspace-based, wired to shared Log Analytics).
- Each module's concern-directory `README.md` (updated from the empty-state stub) — document the module's params, outputs, and the local-path reference example.
- Repo `CHANGELOG.md` — append the first module set under `## [Unreleased]`.

## Proposed Implementation
1. **Author each module** with: a `tags` object param (required), name params with `@maxLength(13)` where the name feeds a `kv-`/`ca-`/etc. composition, an `env` param, a `location` param, the resource declaration with the composed name + tags, and `output` values consumers need (e.g. `keyVault.bicep` outputs `vaultUri`; `containerApp.bicep` outputs the principal ID and FQDN).
2. **Secret discipline (D7).** No module takes a raw secret value param. Where a secret is needed (e.g. a connection string), the module takes a Vault URI / `keyVaultSecret` reference and the deploy identity has provision-not-read rights. Document this in each module README.
3. **Shared-resource references.** `containerApp.bicep` takes `containerAppEnvironmentId` (the shared `cae-hd-{env}` from `platform/`, packet 14) as a parameter — it does not create the environment. `keyVault.bicep` and `applicationInsights.bicep` take `logAnalyticsWorkspaceId` (the shared workspace from `platform/`). This is the consume-the-platform-layer pattern that closes the hand-pasted-ARM-ID gap.
4. **Local-path reference docs.** Each concern README shows the `module x '../../modules/{concern}/{name}.bicep'` reference form. No `br:` syntax anywhere.
5. **No publish, no tag.** Do NOT add a `modules/v1.0.0` tag or any publish step. Modules ship as files consumed in-repo.
6. **CHANGELOG.** Append the module set entry under `## [Unreleased]`.

## Affected Files
- `modules/compute/containerApp.bicep` (new)
- `modules/secrets/keyVault.bicep` (new)
- `modules/secrets/appConfigurationStore.bicep` (new)
- `modules/data/storageAccount.bicep` (new)
- `modules/messaging/serviceBusNamespace.bicep` (new)
- `modules/observability/applicationInsights.bicep` (new)
- `modules/{compute,secrets,data,messaging,observability}/README.md` (updated)
- `CHANGELOG.md` (updated)

## NuGet Dependencies
None. Bicep templates only; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Infrastructure`. Modules are Bicep content — this repo's owned surface per the amendment.
- [x] No per-Node leaf template authored (per-Node touchpoints / packet 15 pattern).
- [x] No `platform/` template authored (packet 14).
- [x] No registry publish step (registry dropped).

## Acceptance Criteria
- [ ] Six modules exist under `modules/{compute,secrets,data,messaging,observability}/` covering containerApp, keyVault, appConfigurationStore, storageAccount, serviceBusNamespace, applicationInsights
- [ ] `containerApp.bicep` produces `ca-hd-{service}-{env}` names, system-assigned MI, Multiple revision mode (invariants 34, 36), and takes `containerAppEnvironmentId` as a param (does not create the environment)
- [ ] `keyVault.bicep` produces `kv-hd-{service}-{env}` names, Azure RBAC enabled, no access policies (invariant 17), with diagnostic settings to `logAnalyticsWorkspaceId` (invariant 22)
- [ ] Service/node name params carry `@maxLength(13)` (invariant 19) where they feed a composed resource name
- [ ] Every module applies the required tags (`hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`) via a `tags` object param (D3)
- [ ] No module takes a raw secret value param; secret-shaped inputs use Vault URI / `keyVaultSecret` references (D7)
- [ ] Each concern README documents params/outputs and a `module x '../../modules/{concern}/{name}.bicep'` local-path reference example — no `br:` syntax
- [ ] No `modules/v1.0.0` tag, no publish step, no `acrhdbicep` / `bicep-publish.yml` / `br:` reference anywhere (registry dropped)
- [ ] Repo `CHANGELOG.md` records the first module set under `## [Unreleased]`
- [ ] `bicep lint` (consumed from Actions via packet 16) passes on every module against the root `bicepconfig.json`

## Human Prerequisites
None. (The shared platform resources the modules reference by ID are provisioned in packet 14; module *authoring* does not require them to exist — they are parameters, resolved at deploy time.)

## Referenced ADR Decisions
**ADR-0077 D2 (principle unchanged; home + distribution amended).** Modularize by concern; the seven concern groups. Modules now live in `HoneyDrunk.Infrastructure/modules/` and are referenced by local relative path — no registry, no publish.

**ADR-0077 D3 — naming/tagging.** Required tags + name conventions; `@maxLength(13)` per invariant 19.

**ADR-0077 D7 — secrets in Bicep.** Templates never contain secret values; Vault URI / `keyVaultSecret` references only.

**Invariant 17 — one Key Vault per deployable Node per environment.** `kv-hd-{service}-{env}`, Azure RBAC enabled, access policies forbidden.

**Invariant 22 — every Key Vault routes diagnostics to the shared Log Analytics workspace.**

**Invariant 34 — Container Apps named `ca-hd-{service}-{env}`, system-assigned MI.** **Invariant 36 — Multiple revision mode.**

**Invariant 19 — service names ≤ 13 characters.**

## Constraints
- **Local-path references only.** Modules are consumed via `'../../modules/{concern}/{name}.bicep'`. No `br:` syntax, no registry, no publish step. This is the load-bearing consequence of the registry drop.
- **No raw secret params.** D7 / invariant 8 extended to IaC — Vault URI references only.
- **Modules don't create shared resources.** `containerApp` consumes `containerAppEnvironmentId`; `keyVault`/`applicationInsights` consume `logAnalyticsWorkspaceId`. The shared resources are `platform/`-owned (packet 14).
- **Six concerns only.** Networking and identity modules land when a consumer first needs them; do not pre-author them.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0077`, `wave-3`

## Agent Handoff

**Objective:** Author the first six per-concern Bicep modules in `HoneyDrunk.Infrastructure/modules/`, consumed by local relative path, applying D3 naming/tagging and D7 secret discipline. No publish, no registry.

**Target:** `HoneyDrunk.Infrastructure`, branch from `main`.

**Context:**
- Goal: Ship the reusable module library the per-Node leaf templates and `platform/` templates consume.
- Feature: ADR-0077 IaC — Bicep rollout (amended 2026-06-02), Wave 3.
- ADRs: ADR-0077 D2/D3/D7 (amended for home + distribution), invariants 17, 19, 22, 34, 36.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:11` — the `modules/` tree + root `bicepconfig.json` must exist.

**Constraints:**
- Local-path references only — no `br:`, no registry, no publish step.
- No raw secret params (Vault URI references only).
- Modules consume shared resources by ID; they don't create them.
- Six concerns only.

**Key Files:**
- `modules/compute/containerApp.bicep`, `modules/secrets/keyVault.bicep`, `modules/secrets/appConfigurationStore.bicep`, `modules/data/storageAccount.bicep`, `modules/messaging/serviceBusNamespace.bicep`, `modules/observability/applicationInsights.bicep`
- `modules/*/README.md`, `CHANGELOG.md`

**Contracts:** The six module parameter/output surfaces are the consumable contracts; local-path-referenced.
