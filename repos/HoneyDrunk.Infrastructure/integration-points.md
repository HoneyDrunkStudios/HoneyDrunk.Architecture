# HoneyDrunk.Infrastructure — Integration Points

## Consumes

| Node | Workflow | Usage |
|------|----------|-------|
| **Actions** | `job-deploy-bicep.yml` | Reusable deploy workflow that applies this repo's Bicep templates at deploy time. |
| **Actions** | `job-bicep-lint.yml` | Reusable Bicep lint gate (invoked from this repo's `pr.yml`). |

## Exposes

| Surface | Kind | Reference style |
|---------|------|-----------------|
| `modules/` | Bicep modules | Local relative path (e.g. `'../../modules/compute/containerApp.bicep'`) — no registry. |
| `platform/` | Bicep templates | Provisions shared-foundation resources and **exports their resource IDs**. |
| `nodes/{node}/` | Bicep templates | Per-Node leaf templates (`main.bicep` + `parameters.{env}.bicepparam`). |

## Shared-Resource Declaration

The `platform/` layer declares the shared resources (the shared Container Apps Environment, image ACR, Log Analytics, Service Bus namespace, networking) and exports their resource IDs. Every Node's leaf template under `nodes/{node}/` references those resources by **resource ID**, closing the hand-pasted-ARM-resource-ID gap that existed when each Node owned its own infra Bicep in isolation.

## Boundary Note

No Node takes a **runtime** dependency on this repo. Bicep content is applied at deploy time, not linked at build time — the only integration edge is consuming the Actions deploy + lint workflows.
