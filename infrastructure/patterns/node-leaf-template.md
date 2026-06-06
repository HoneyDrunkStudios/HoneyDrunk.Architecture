# Pattern: Node leaf-template scaffold (`nodes/{node}/`)

**Applies to:** ADR-0077 (amended 2026-06-02), ADR-0033, ADR-0036.
**Supersedes:** the registry-shaped per-Node-`infra/` predecessor (packet 08).

The canonical scaffold the `scope` agent and operators consult when a Node needs
to provision a new Azure resource under the consolidated
`HoneyDrunk.Infrastructure/nodes/{node}/` shape. This is a **pattern, not a
template** — it authors no specific Node's `main.bicep`; per-Node leaf templates
land in `HoneyDrunk.Infrastructure` at each Node's first significant
infrastructure touchpoint.

For migrating an existing manually-provisioned resource into this shape, use the
[import playbook](bicep-import-existing-resources.md) instead.

---

## Purpose

ADR-0077 D6 commits: **"New infrastructure goes through Bicep from day one."**
The 2026-06-02 amendment relocates a Node's infrastructure out of the Node's own
repo and into `HoneyDrunk.Infrastructure/nodes/{node}/`, references per-concern
modules by **local relative path** (no registry), references shared resources
via the `platform/` layer's **exported resource IDs**, and deploys infra on its
**own cadence, decoupled from application release tags** (this supersedes the D4
tag-coupling framing).

Without a canonical pattern, each Node's leaf template would invent its own
layout, module-reference style, parameter shape, and deploy wiring — guaranteed
drift. This doc fixes the shape once.

## When to use

- **Every time a Node needs to provision a new Azure resource.** A new Key Vault,
  Container App, App Configuration store, Service Bus namespace, etc. for a Node
  goes here.
- Use the [import playbook](bicep-import-existing-resources.md) instead when a
  resource **already exists** (manually provisioned) and needs to come under IaC
  at its next significant touchpoint (D6).

## `nodes/{node}/` layout

```
HoneyDrunk.Infrastructure/
  bicepconfig.json            # single repo-root config (D3 linter rules) — governs nodes/ too
  modules/{concern}/*.bicep   # per-concern reusable modules (consumed by local relative path)
  platform/                   # shared-foundation layer; exports resource IDs
  nodes/{node}/
    main.bicep
    parameters.dev.bicepparam
    parameters.staging.bicepparam
    parameters.prod.bicepparam
```

There is **no per-Node `bicepconfig.json`.** The single repo-root
`bicepconfig.json` governs `modules/`, `platform/`, and `nodes/` via Bicep's
config-file resolution (which walks up the directory tree). The `bicep lint`
gate evaluates every leaf template against that one config (ADR-0077 D3 /
invariant 92).

## `main.bicep` skeleton (annotated)

```bicep
// nodes/identity/main.bicep — illustrative scaffold (not a shipped template).

targetScope = 'resourceGroup'

@allowed(['dev', 'staging', 'prod'])
param env string
param location string = resourceGroup().location

param nodeId string = 'honeydrunk-identity'
param costCenter string
param drTier string                        // hd:dr-tier — see ADR-0036 (T0/T1/T2)

// Shared-foundation resource IDs come from the platform/ layer's OUTPUTS,
// NOT hand-pasted ARM strings. Passed in via the .bicepparam (see below).
param platformLogAnalyticsId string        // platform/ output: logAnalyticsWorkspaceId
param platformCaeId string                 // platform/ output: containerAppEnvironmentId

// The container image reference (built + tagged by the application release flow).
param image string

// ── The composed Grid tag object (ADR-0077 D3) — composed once, applied uniformly.
var tags = {
  'hd:node': nodeId
  'hd:env': env
  'hd:owner': 'honeydrunkstudios'
  'hd:cost-center': costCenter
  'hd:dr-tier': drTier
  'hd:adr': 'ADR-XXXX'                      // the provisioning ADR for this Node's infra
}

// ── Per-Node Key Vault — module consumed by LOCAL RELATIVE PATH (no br:).
//    Real params (HoneyDrunk.Infrastructure/modules/secrets/README.md):
//    service, env, tags, location, logAnalyticsWorkspaceId.
module nodeVault '../../modules/secrets/keyVault.bicep' = {
  name: 'nodeVault'
  params: {
    service: 'identity'                    // @maxLength(13); feeds kv-hd-identity-<env>
    env: env
    tags: tags
    location: location
    logAnalyticsWorkspaceId: platformLogAnalyticsId   // from platform/ outputs (invariant 22)
  }
}

// ── Node Container App — module consumed by LOCAL RELATIVE PATH (no br:).
//    Real params (HoneyDrunk.Infrastructure/modules/compute/README.md):
//    service, env, tags, location, containerAppEnvironmentId, image, targetPort.
module nodeApp '../../modules/compute/containerApp.bicep' = {
  name: 'nodeApp'
  params: {
    service: 'identity'
    env: env
    tags: tags
    location: location
    containerAppEnvironmentId: platformCaeId          // from platform/ outputs (invariant 35)
    image: image
    targetPort: 8080
  }
}
```

Highlights:

- **(a)** `tags` is composed **once** from params and applied to every module —
  D3 required tags (`hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`,
  `hd:dr-tier`, `hd:adr`).
- **(b)** Every module reference is a **local relative path**
  (`'../../modules/{concern}/{name}.bicep'`) — **there is no `br:` reference**.
  Modules are not published to a registry; `acrhdbicep` and the publish flow
  were dropped by the amendment.
- **(c)** Shared resources come from the `platform/` layer's **exported IDs**
  (`platformLogAnalyticsId`, `platformCaeId`), passed in via the `.bicepparam` —
  **not hand-pasted ARM strings.** This closes the original hand-pasted-ARM-ID
  gap (see the `platform/` exported-IDs work, packet 14).
- **(d)** **No secret value enters the template** (ADR-0077 D7 / invariant 91).
  The Container App reaches Key Vault / App Configuration / ACR via its
  system-assigned managed identity + RBAC; no connection strings, instrumentation
  keys, registry credentials, or `AZURE_CREDENTIALS` JSON are templated.

> **`AZURE_KEYVAULT_URI` (invariant 18).** The v1 `containerApp` module takes a
> single `image` param and **does not yet expose an env-var (`envVars`) param**.
> The intended shape is for the Node's Container App to receive
> `AZURE_KEYVAULT_URI` = `nodeVault.outputs.vaultUri` as an environment variable
> (invariant 18 — Vault URIs reach Nodes via env vars). Illustratively, that
> wiring looks like:
>
> ```bicep
> // ILLUSTRATIVE — the v1 containerApp module does not yet accept this param.
> // Wire AZURE_KEYVAULT_URI to the platform/ Vault URI (invariant 18), never a secret value.
> envVars: [
>   { name: 'AZURE_KEYVAULT_URI', value: nodeVault.outputs.vaultUri }
> ]
> ```
>
> Until the module is extended to accept env vars, flag this as a **module
> extension needed** in the per-Node packet (the `containerApp` module's v1
> surface is `service` / `env` / `tags` / `location` /
> `containerAppEnvironmentId` / `image` / `targetPort`). Do **not** invent the
> param in a leaf template; extend the module. Note that `vaultUri` is a
> non-secret data-plane URI, not a secret value (D7-safe).

## `parameters.{env}.bicepparam` skeleton

```bicep
// nodes/identity/parameters.dev.bicepparam — non-secret config only (D7).
using './main.bicep'

param env = 'dev'
param costCenter = 'platform'
param drTier = 'T2'                         // ADR-0036 DR tier for this env

// platform/ exported IDs — sourced from the platform/ layer's deploy outputs,
// passed in per environment. NOT hand-pasted ARM strings, NOT secrets.
param platformLogAnalyticsId = '<platform/ output: logAnalyticsWorkspaceId for dev>'
param platformCaeId = '<platform/ output: containerAppEnvironmentId for dev>'

// The image reference the application release flow produced for this env.
param image = '<acr-login-server>/identity:<tag>'
```

No secret values, connection strings, instrumentation keys, or
`AZURE_CREDENTIALS` JSON appear in any `.bicepparam` (ADR-0077 D7 / invariant 91).
Where a secret is conceptually needed, a `.bicepparam` carries a Key Vault secret
**reference** (`az.getSecret()` / `getSecret()`), never the secret value itself.

## Consumer-side `pr.yml` lint wiring

The leaf template is gated by the reusable `bicep lint` workflow, consumed from
`HoneyDrunk.Actions` (ADR-0012). In `HoneyDrunk.Infrastructure/.github/workflows/pr.yml`:

```yaml
jobs:
  bicep-lint:
    permissions:
      contents: read                          # superset of the callee (invariant 39)
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-bicep-lint.yml@main
```

The caller **must** declare a `permissions:` block that is a superset of the
reusable workflow's (ADR-0012 D5 / invariant 39); under `workflow_call` the
callee's `permissions:` is documentary and the caller's grant is what applies.

`job-bicep-lint.yml` runs `bicep lint` + `bicep build-params` against the
repo-root `bicepconfig.json` and **fails the PR on error-severity findings**
(ADR-0077 D3 / invariant 92).

## Deploy wiring — `job-deploy-bicep.yml` with ADR-0033 env gates

Deploy the leaf template per environment via the reusable
`job-deploy-bicep.yml` workflow (consumed from `HoneyDrunk.Actions`), with
ADR-0033 `environment:` approval gates:

Each caller job declares `permissions: { id-token: write, contents: read }` —
the superset `job-deploy-bicep.yml` requires for OIDC federation (invariant 39) —
and passes the OIDC identity via repo/org **vars** (no secret values). The
`environment:` is declared by the caller, not the reusable workflow.

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy-node-infra-dev:
    environment: dev
    permissions:
      id-token: write                       # OIDC federation (job-deploy-bicep.yml)
      contents: read
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
    with:
      env: dev
      template-path: nodes/identity/main.bicep
      parameters-path: nodes/identity/parameters.dev.bicepparam
      deployment-scope: resourceGroup
      resource-group: rg-hd-identity-dev
      azure-client-id: ${{ vars.AZURE_CLIENT_ID }}
      azure-tenant-id: ${{ vars.AZURE_TENANT_ID }}
      azure-subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

  deploy-node-infra-staging:
    environment: staging                    # ADR-0033 required-reviewers gate
    needs: deploy-node-infra-dev
    permissions:
      id-token: write
      contents: read
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
    with:
      env: staging
      template-path: nodes/identity/main.bicep
      parameters-path: nodes/identity/parameters.staging.bicepparam
      deployment-scope: resourceGroup
      resource-group: rg-hd-identity-staging
      azure-client-id: ${{ vars.AZURE_CLIENT_ID }}
      azure-tenant-id: ${{ vars.AZURE_TENANT_ID }}
      azure-subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

  deploy-node-infra-prod:
    environment: prod                       # ADR-0033 required-reviewers gate (gated prod)
    needs: deploy-node-infra-staging
    permissions:
      id-token: write
      contents: read
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
    with:
      env: prod
      template-path: nodes/identity/main.bicep
      parameters-path: nodes/identity/parameters.prod.bicepparam
      deployment-scope: resourceGroup
      resource-group: rg-hd-identity-prod
      azure-client-id: ${{ vars.AZURE_CLIENT_ID }}
      azure-tenant-id: ${{ vars.AZURE_TENANT_ID }}
      azure-subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

**Infra deploys on its own cadence, decoupled from application release tags.**
The trigger is the `HoneyDrunk.Infrastructure` repo's own cadence — a push to
`main`, a manual `workflow_dispatch`, or an infra-specific tag — **NOT** the
application Node's release tag. The 2026-06-02 amendment decoupled these:
infrastructure and application code rarely change together, and when they do, two
separate deploys is acceptable. `job-deploy-bicep.yml` runs a `what-if` preflight
before applying (OIDC auth, no client secret).

## Tag composition reference

The `tags` object is composed once (D3) from these sources:

| Tag | Source |
| --- | --- |
| `hd:node` | the Node identifier (`nodeId` param), e.g. `honeydrunk-identity` |
| `hd:env` | `env` param (`dev` / `staging` / `prod`) |
| `hd:owner` | constant `honeydrunkstudios` |
| `hd:cost-center` | `costCenter` param |
| `hd:dr-tier` | `drTier` param — ADR-0036 DR tier (T0 / T1 / T2) |
| `hd:adr` | the provisioning ADR for this Node's infra (literal in `main.bicep`) |

## What this pattern does NOT cover

- **Multi-region DR topology** — per-Node, deferred (ADR-0077 D8).
- **Subscription-scoped resources beyond the resource group** — role
  assignments, policy assignments, and subscription-level resources are out of
  scope for the standard RG-scoped leaf template.
- **Private-link / VNet networking** — not part of the v1 scaffold.
- **The `platform/` shared-foundation layer itself** — that is `platform/`-owned
  (packet 14); leaf templates *consume* its exported IDs, they do not create
  shared resources.

## Cross-references

- [Importing existing resources](bicep-import-existing-resources.md) — the D6
  migration playbook (packet 17).
- The `platform/` exported-ID layer (packet 14) — source of
  `platformLogAnalyticsId` / `platformCaeId` and the other shared IDs.
- The reusable deploy + lint workflows in `HoneyDrunk.Actions` (packet 16) —
  `job-deploy-bicep.yml` and `job-bicep-lint.yml`.
- `HoneyDrunk.Infrastructure/modules/*/README.md` — the **real** per-concern
  module parameter contracts (e.g. `modules/secrets/README.md`,
  `modules/compute/README.md`). Always check the module README for the current
  param surface before wiring a leaf template.
