---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "infrastructure", "adr-0077", "wave-4"]
dependencies: ["packet:02", "packet:03", "packet:04"]
adrs: ["ADR-0077", "ADR-0015", "ADR-0005", "ADR-0028", "ADR-0040"]
wave: 4
initiative: adr-0077-iac-bicep
node: honeydrunk-actions
---

# Author the first per-concern Bicep module set and tag modules/v1.0.0

> **STATUS — SUPERSEDED (2026-06-02) by packet 13.** Filed as `Actions#120` (OPEN, unmerged). The ADR-0077 amendment (2026-06-02) relocates module authoring to `HoneyDrunk.Infrastructure/modules/` (packet 13) and DROPS the `modules/v1.0.0` tag-publish step (no registry — modules are consumed by local relative path). This packet is retained for traceability; do not execute it. Close `Actions#120` as superseded by packet 13. See `dispatch-plan.md`.

## Summary
Author the first per-concern Bicep module set in `HoneyDrunk.Actions/bicep/modules/` per ADR-0077 D2's Follow-up Work — covering the six concerns named in the ADR: `compute/containerApp.bicep`, `secrets/keyVault.bicep`, `secrets/appConfigurationStore.bicep`, `data/storageAccount.bicep`, `messaging/serviceBusNamespace.bicep`, and `observability/applicationInsights.bicep`. Each module accepts the parameters needed to provision its resource per Grid naming and tagging conventions (D3) and references Vault for any secret-shaped input (D7). Tag `modules/v1.0.0` after merge so `bicep-publish.yml` (packet 04) publishes the set to `acrhdbicep`.

## Context
ADR-0077 D2's Follow-up Work names "a first set of modules covering Container Apps, Key Vault, App Configuration, Storage, Service Bus, and Application Insights." These six concerns map to the resource families the Grid already provisions today (or is about to provision per ADR-0059/0060/0061):

| Module | Resource | Naming (D3) | Source ADR(s) |
|---|---|---|---|
| `compute/containerApp` | Azure Container App + system-assigned MI | `ca-hd-{service}-{env}` (≤13-char service) | ADR-0015 D2, invariant 34 |
| `secrets/keyVault` | Azure Key Vault with Azure RBAC | `kv-hd-{node}-{env}` | ADR-0005 D3, invariant 17 |
| `secrets/appConfigurationStore` | Azure App Configuration | `appcs-hd-{env}` (shared) | ADR-0005 |
| `data/storageAccount` | Azure Storage Account | `sthd{node}{env}` (alphanumeric, ≤24 chars) | ADR-0036 (DR), ADR-0061 |
| `messaging/serviceBusNamespace` | Azure Service Bus namespace | `sbns-hd-shared-{env}` or `sbns-hd-{node}-{env}` | ADR-0028 D5 |
| `observability/applicationInsights` | Workspace-based App Insights | `appi-hd-{service}-{env}` | ADR-0040 D1 |

Each module:
- Accepts strongly-typed parameters with `@description`, `@minLength` / `@maxLength` (especially `@maxLength(13)` on `{service}` / `{node}` names per invariant 19), and `@allowed` for enumerations like `env`.
- Applies the required tags from D3 (`hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`) — passed as a single `tags` object parameter so the consumer composes them once at the per-Node template level.
- References secrets via Key Vault URI parameters, never as raw string parameters (D7 / invariant 85). For example, the `containerApp` module accepts an array of `secretRef: { name: 'X', keyVaultUrl: '...', identity: '...' }` rather than a `password: string` parameter.
- Outputs the canonical resource id and any consumer-facing properties (FQDN, registry login server, namespace endpoint).
- Has a sibling `README.md` or top-of-file comment block documenting the module's purpose, parameters, outputs, and example usage.

**Parameter convention enforces what bicepconfig.json cannot.** Per packet 03, the linter does not yet support fully custom rules for tag and name conventions. The module-author convention — `@maxLength(13)` on service names, the `tags` parameter shape, the `secretRef` shape for secrets — is what enforces ADR-0077 D3 at module-author time. Consumers of the modules inherit the discipline automatically.

**Module scope at v1.** This packet ships **only the six modules ADR-0077 D2 explicitly names**. Other modules (e.g. `data/redisCache` for ADR-0076 Cache, `data/postgresServer` for ADR-0060 Identity, `compute/containerAppJob`, `compute/functionApp`, `identity/userAssignedIdentity` + `identity/roleAssignment`, `networking/*`, `messaging/serviceBusTopic`, `observability/logAnalyticsWorkspace`, `observability/actionGroup`) are deferred to follow-up packets when their consuming Nodes scope their infrastructure work. The v1 set is the minimum that lets the Notify/Pulse existing deployables and the upcoming Cache/Identity/Files standups consume Bicep-from-day-one for the most common resources.

**Tagging the publish.** After merge, the operator (or a follow-up automation) tags `modules/v1.0.0` to fire `bicep-publish.yml` and land the modules in `acrhdbicep`. The packet's acceptance criteria include the post-merge tag step.

`HoneyDrunk.Actions` is the CI/CD control plane per ADR-0012. This is a Bicep authoring packet — no .NET project, no NuGet dependencies. The repo `CHANGELOG.md` is updated per the repo convention if it tracks Bicep modules.

## Scope
- `bicep/modules/compute/containerApp.bicep` (new)
- `bicep/modules/secrets/keyVault.bicep` (new)
- `bicep/modules/secrets/appConfigurationStore.bicep` (new)
- `bicep/modules/data/storageAccount.bicep` (new)
- `bicep/modules/messaging/serviceBusNamespace.bicep` (new)
- `bicep/modules/observability/applicationInsights.bicep` (new)
- Per-concern `README.md` files in each of `bicep/modules/{compute,secrets,data,messaging,observability}/` listing the modules and their parameter signatures
- The repo `CHANGELOG.md` if the repo keeps one for the workflow / Bicep surface

## Proposed Implementation
1. **Pattern, applied to each module.** Each `.bicep` file:
   - Opens with a top-of-file comment block: purpose, ADR reference, parameter table, outputs, example usage.
   - Declares strongly-typed parameters with decorators. Required tags go through a single `tags object` parameter; service / node names through `@maxLength(13)` `string` parameters; environment through `@allowed(['dev', 'staging', 'prod']) string env`.
   - Declares the Azure resource with the conformant name shape (composed from the parameters).
   - Applies the `tags` parameter to the resource.
   - Outputs `id`, the resource's canonical name, and any consumer-relevant property (login server, FQDN, endpoint, namespace).
2. **`compute/containerApp.bicep`.**
   - Parameters: `service` (`@maxLength(13)` string), `env`, `tags`, `containerAppEnvironmentId`, `imageRef` (e.g. `acrhdshareddev.azurecr.io/honeydrunk/notify-functions:0.2.0`), `cpu` (default `0.25`), `memory` (default `0.5Gi`), `minReplicas` (default `0`), `maxReplicas` (default `1`), `revisionMode` (default `Multiple` per invariant 36), `secretRefs` (array of `{ name, keyVaultUrl, identity }`), `envVars` (array of `{ name, value }` or `{ name, secretRef }`), `ingress` (object with `external`, `targetPort`).
   - Resource name: `'ca-hd-${service}-${env}'`.
   - System-assigned managed identity enabled (invariant 34).
   - Revision mode `Multiple` (invariant 36).
   - Outputs: `id`, `name`, `fqdn`, `principalId` (the MI's principal id, for downstream role assignments).
3. **`secrets/keyVault.bicep`.**
   - Parameters: `node` (`@maxLength(13)` string), `env`, `tags`, `location`, `enableRbacAuthorization` (default `true` per ADR-0005), `enableSoftDelete` (default `true`, retention `90`), `enablePurgeProtection` (default `true`).
   - Resource name: `'kv-hd-${node}-${env}'`.
   - Azure RBAC enabled (invariant 17).
   - Diagnostic settings parameter (`logAnalyticsWorkspaceId`) — when provided, configures diagnostic settings routing per invariant 22.
   - Outputs: `id`, `name`, `vaultUri`.
4. **`secrets/appConfigurationStore.bicep`.**
   - Parameters: `name` (e.g. `appcs-hd-${env}`), `env`, `tags`, `location`, `sku` (default `standard`), `softDeleteRetentionInDays` (default `7`).
   - Resource name composed from `name` parameter.
   - Outputs: `id`, `endpoint`.
5. **`data/storageAccount.bicep`.**
   - Parameters: `node` (`@maxLength(13)` — storage account names are ≤24 chars total, alphanumeric only; `sthd` prefix is 4 chars and the longest `env` value `staging` is 7 chars, leaving 13 chars for `node`), `env`, `tags`, `location`, `sku` (default `Standard_LRS`), `kind` (default `StorageV2`), `accessTier` (default `Hot`), `minimumTlsVersion` (default `TLS1_2`), `publicNetworkAccess` (default `Enabled`).
   - Resource name: `'sthd${node}${env}'` — note no hyphens (Azure storage account name restriction).
   - Outputs: `id`, `name`, `primaryBlobEndpoint`.
   - Math: `len('sthd') + maxLength(node) + len('staging') = 4 + 13 + 7 = 24` — fits the 24-char ceiling exactly for the longest `env`. `dev` / `prod` leave headroom.
6. **`messaging/serviceBusNamespace.bicep`.**
   - Parameters: `scope` (`@allowed(['shared', 'node'])`), `node` (`@maxLength(13)` string, used only when `scope == 'node'`), `env`, `tags`, `location`, `sku` (default `Standard`), `zoneRedundant` (default `false`).
   - Resource name: `scope == 'shared' ? 'sbns-hd-shared-${env}' : 'sbns-hd-${node}-${env}'`.
   - Outputs: `id`, `name`, `endpoint`.
7. **`observability/applicationInsights.bicep`.**
   - Parameters: `service` (`@maxLength(13)` string), `env`, `tags`, `location`, `workspaceResourceId` (the backing Log Analytics workspace per ADR-0040 D1's workspace-based App Insights), `applicationType` (default `web`).
   - Resource name: `'appi-hd-${service}-${env}'`.
   - Resource is workspace-based (ADR-0040 D1 — non-workspace mode is retired by Azure).
   - Outputs: `id`, `name`. **Does NOT output `connectionString` as a plain string** — the connection string contains the instrumentation key and is itself the secret per ADR-0040 packet 02. Bicep outputs surface in `az deployment` JSON and flow through to workflow outputs (`deployment-outputs` in `job-deploy-bicep.yml`), where they are visible in the calling workflow's run logs — a critical leak path. Instead the module outputs a Vault-reference shape consumers use to read the connection string at runtime: `outputs.connectionStringRef object = { kind: 'keyVaultSecret', id: <appi-resource-id>, listKeysExpression: 'listKeys(\'<resource-id>\', \'<api-version>\').connectionString' }` (or equivalent shape — the operational pattern is that consumers call `listKeys` against the App Insights resource at runtime via Managed Identity, never via a `string` output). Document this in the module README: callers wire the connection string into Vault via a Vault `keyVaultSecret` resource at the per-Node template level (or via a runtime `listKeys` call from the deployed app), never log it. **Acceptance criterion:** no `output ... string` or `@secure() output` of the connection string itself.
8. **Per-concern `README.md` files.** Each per-concern subdir gets a small `README.md` listing the modules it contains and their parameter signatures at-a-glance. The library-level `bicep/README.md` (packet 03) cross-references these.
9. **Update the repo `CHANGELOG.md`** if the repo keeps one for the workflow / Bicep surface.
10. **Post-merge tag step.** After merge, the operator tags `modules/v1.0.0` to fire `bicep-publish.yml` and publish the set. This is the **post-merge action** that completes the packet — call it out in the Human Prerequisites.

## Affected Files
- `bicep/modules/compute/containerApp.bicep` (new)
- `bicep/modules/secrets/keyVault.bicep` (new)
- `bicep/modules/secrets/appConfigurationStore.bicep` (new)
- `bicep/modules/data/storageAccount.bicep` (new)
- `bicep/modules/messaging/serviceBusNamespace.bicep` (new)
- `bicep/modules/observability/applicationInsights.bicep` (new)
- `bicep/modules/compute/README.md`, `secrets/README.md`, `data/README.md`, `messaging/README.md`, `observability/README.md` (new)
- The repo `CHANGELOG.md` if the repo keeps one for the workflow / Bicep surface
- (post-merge) `modules/v1.0.0` git tag — fires `bicep-publish.yml`

## NuGet Dependencies
None. Bicep authoring — no .NET project.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — ADR-0077 D2 names the canonical home; ADR-0012 confirms Actions as the CI/CD control plane.
- [x] The six modules match the ADR's Follow-up Work list exactly.
- [x] No code change in any Node — Bicep modules only.

## Acceptance Criteria
- [ ] All six modules (`compute/containerApp.bicep`, `secrets/keyVault.bicep`, `secrets/appConfigurationStore.bicep`, `data/storageAccount.bicep`, `messaging/serviceBusNamespace.bicep`, `observability/applicationInsights.bicep`) exist under `bicep/modules/`
- [ ] Each module has a top-of-file comment block documenting purpose, ADR reference, parameter table, outputs, and example usage
- [ ] Each module's resource name composes to the Grid naming convention for that resource type (`ca-hd-{service}-{env}`, `kv-hd-{node}-{env}`, `appcs-hd-{env}`, `sthd{node}{env}`, `sbns-hd-shared-{env}` or `sbns-hd-{node}-{env}`, `appi-hd-{service}-{env}`)
- [ ] Each module's service / node name parameter has `@maxLength(13)` enforcing invariant 19; the storage account module's `node` parameter is `@maxLength(13)` because `len('sthd') + 13 + len('staging') = 24` exactly hits the storage-account 24-char ceiling for the longest `env`
- [ ] Each module accepts a `tags object` parameter and applies it to the resource — no per-tag scalar parameters
- [ ] No module accepts a secret as a raw string parameter — secret-shaped inputs use a `secretRef`-style `{ name, keyVaultUrl, identity }` shape, or the consumer wires the Vault reference at the resource level (invariant 8, invariant 85, ADR-0077 D7)
- [ ] The `containerApp` module enables system-assigned managed identity (invariant 34) and sets revision mode `Multiple` (invariant 36) by default
- [ ] The `keyVault` module enables Azure RBAC by default (invariant 17 / ADR-0005 D3) and accepts an optional `logAnalyticsWorkspaceId` for invariant-22 diagnostic settings routing
- [ ] The `applicationInsights` module is workspace-based (consumes a `workspaceResourceId` parameter)
- [ ] The `applicationInsights` module does NOT output the App Insights `connectionString` as a `string` (or as any output that surfaces into `az deployment` JSON / workflow logs). Instead it outputs a Vault-reference shape (`{ kind: 'keyVaultSecret', id, listKeysExpression }`) consumers use to read the secret at runtime via Managed Identity. The module README documents the runtime-resolution pattern.
- [ ] Per-concern `README.md` files in `compute/`, `secrets/`, `data/`, `messaging/`, `observability/` list the modules and their parameter signatures
- [ ] Running `bicep build` on each module produces a clean ARM JSON output (no compile errors)
- [ ] Running `bicep lint` against each module with the `bicepconfig.json` from packet 03 produces no `error`-severity violations (warnings are acceptable for v1; future packets tighten)
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow / Bicep surface
- [ ] **(post-merge)** A git tag `modules/v1.0.0` is pushed and `bicep-publish.yml` succeeds, publishing all six modules to `acrhdbicep` — recorded as a closing comment on the issue

## Human Prerequisites
- [ ] Packet 02 must be done — `acrhdbicep` registry exists and OIDC `AcrPush` is granted. If packet 02 is not yet executed, the modules can still be merged; the post-merge `modules/v1.0.0` tag step waits.
- [ ] **Post-merge:** push the `modules/v1.0.0` git tag to fire `bicep-publish.yml` (packet 04). This is a one-line operator action: `git tag modules/v1.0.0 && git push origin modules/v1.0.0`. The packet is not fully closed until the tag is pushed and the publish workflow succeeds.

## Referenced ADR Decisions
**ADR-0077 D2 — First module set.** The ADR's Follow-up Work names "a first set of modules covering Container Apps, Key Vault, App Configuration, Storage, Service Bus, and Application Insights." This packet ships that set. Other modules (Redis, Postgres, networking, identity, observability/logAnalytics, etc.) are deferred to follow-up packets driven by their consuming Nodes' infrastructure work.

**ADR-0077 D3 — Naming and tagging conventions.** Resource name shape (per-resource-type prefix + `hd-` + `{service}/{node}` + `{env}`) and required tags (`hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`). Enforced by module-author convention (parameter decorators, `tags` parameter shape) where the linter cannot.

**ADR-0077 D7 — Secrets in Bicep.** Modules never accept secrets as raw string parameters. Secret-shaped inputs use a `secretRef` shape that references Vault by URI. Codifies invariant 8 / invariant 85.

**ADR-0015 / invariant 34 — Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`, one per Node per environment, with system-assigned Managed Identity.**

**Invariant 36 — Container App revision mode is `Multiple` with explicit traffic splitting on deploy.**

**ADR-0005 / invariant 17 — One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}` (`{service}` ≤ 13 chars per invariant 19), Azure RBAC enabled.**

**Invariant 19 — Service names in Azure resource naming must be ≤ 13 characters.**

**Invariant 22 — Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.** The `keyVault` module's optional `logAnalyticsWorkspaceId` parameter and the consumer-side wiring satisfy this.

**ADR-0028 D5 — `sbns-hd-shared-{env}` shared Service Bus namespace.** The `serviceBusNamespace` module's `scope` parameter supports both shared and per-Node shapes.

**ADR-0040 D1 — Workspace-based Application Insights.** The `applicationInsights` module is workspace-based; non-workspace mode is retired by Azure.

## Constraints
> **Invariant 8 / Invariant 85 — Bicep templates never contain secret values.** No module accepts a secret as a raw string parameter. Secret-shaped inputs use the `secretRef` shape ({ name, keyVaultUrl, identity }) that references Vault by URI. The `applicationInsights` module's `connectionString` output is documented as a secret that must be wired into Vault by the caller.

> **Invariant 19 — Service names in Azure resource naming must be ≤ 13 characters.** Modules enforce this with `@maxLength(13)` parameter decorators. The storage account module also uses `@maxLength(13)` — the storage-account 24-char total budget is exhausted by `sthd` (4) + 13 + `staging` (7) = 24 for the longest `env`.

> **Invariant 34, 36 — Container Apps shape.** The `containerApp` module enables system-assigned MI by default and sets revision mode `Multiple` by default.

> **Invariant 17 — Per-Node Key Vault, Azure RBAC.** The `keyVault` module enables Azure RBAC by default.

> **Invariant 22 — Diagnostic settings for Key Vaults.** The `keyVault` module exposes an optional `logAnalyticsWorkspaceId` parameter; consumers wire it.

- **Six modules in v1.** Match ADR-0077 D2's Follow-up Work list exactly. Do not add Redis, Postgres, networking, or other resources — those are follow-up packets driven by consuming Nodes.
- **One module per resource family.** Each module declares one Azure resource (or one resource plus its tightly-coupled children like Container App secrets). No mega-modules.
- **Outputs limited to what consumers need.** `id`, canonical name, and consumer-facing endpoints / FQDNs / principalIds. Do not leak full resource configs.
- **No local-path consumption in test code.** If a module test ever lands, it consumes the registry path, not the local file path — same discipline as per-Node templates.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `infrastructure`, `adr-0077`, `wave-4`

## Agent Handoff

**Objective:** Author the six Bicep modules ADR-0077 D2's Follow-up Work names, with parameter / tag / name conventions enforced at module-author time, and tag `modules/v1.0.0` after merge.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Ship the first reusable Bicep modules so upcoming Node infrastructure work (ADR-0059 Cache, ADR-0060 Identity, ADR-0061 Files) consumes the registry path from day one.
- Feature: ADR-0077 IaC — Bicep rollout, Wave 4.
- ADRs: ADR-0077 D2/D3/D7 (primary), ADR-0015 (Container Apps shape), ADR-0005 (Key Vault shape), ADR-0028 (Service Bus shape), ADR-0040 (App Insights shape).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — `acrhdbicep` registry exists and OIDC `AcrPush` is granted; required for the post-merge `modules/v1.0.0` publish to land somewhere.
- `packet:03` — `bicep/modules/` directory tree and `bicepconfig.json` exist.
- `packet:04` — `bicep-publish.yml` workflow exists, so the post-merge `modules/v1.0.0` tag fires the publish.

**Constraints:**
- Six modules in v1 — match D2's Follow-up Work list exactly.
- One Azure resource per module — no mega-modules.
- Tags via single `tags object` parameter; names via `@maxLength`-decorated `service`/`node` parameters; secrets via `secretRef` shape — never raw string secrets.
- `containerApp` defaults: system-assigned MI, revision mode `Multiple`.
- `keyVault` defaults: Azure RBAC enabled; soft-delete + purge protection on.
- `applicationInsights` is workspace-based; its `connectionString` output is a secret — document this in the module README.
- `bicep lint` against `bicepconfig.json` produces zero `error`-severity violations.

**Key Files:**
- `bicep/modules/compute/containerApp.bicep`
- `bicep/modules/secrets/keyVault.bicep`
- `bicep/modules/secrets/appConfigurationStore.bicep`
- `bicep/modules/data/storageAccount.bicep`
- `bicep/modules/messaging/serviceBusNamespace.bicep`
- `bicep/modules/observability/applicationInsights.bicep`
- Per-concern `README.md` files
- (post-merge) git tag `modules/v1.0.0`

**Contracts:**
- Each module exposes a contract (its parameter list + outputs) for per-Node `infra/main.bicep` consumers. The contract is documented in the module's top-of-file comment block and the per-concern README. Breaking changes require a SemVer major bump on the next `modules/v*` tag.
