# HoneyDrunk.Infrastructure — Boundaries

## What Infrastructure Owns

- All Bicep templates and modules for the Grid.
- The `platform/` shared layer (shared Container Apps Environment, shared image ACR, Log Analytics, shared Service Bus namespace, networking) and the resource IDs it exports.
- Per-Node leaf templates under `nodes/{node}/` (`main.bicep` + `parameters.{env}.bicepparam`).
- The per-concern module library under `modules/`, referenced by local relative path.

## What Infrastructure Does NOT Own

- **The deploy/lint pipeline** — `HoneyDrunk.Actions` owns the reusable `job-deploy-bicep.yml` and `job-bicep-lint.yml` workflows per ADR-0012. Infrastructure consumes them.
- **Runtime application code** — each Node's runtime code stays in the Node's own repo.
- **Secret values** — `HoneyDrunk.Vault` / Key Vault own secret values. Templates reference secrets by **URI** per ADR-0077 D7 and invariant 91; they never contain secret values (invariant 8).

## Cross-Boundary Rule

Per-Node **runtime** code stays in the Node's own repo. Only a Node's `infra/` Bicep relocates here, under `nodes/{node}/`. The boundary test: if the artifact **describes Azure resources to provision**, it belongs in Infrastructure; if it **runs at request/message time**, it belongs in the Node's repo.
