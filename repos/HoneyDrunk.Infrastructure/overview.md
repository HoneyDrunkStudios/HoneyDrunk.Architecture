# HoneyDrunk.Infrastructure — Overview

**Sector:** Ops
**Signal:** Seed
**Cluster:** foundation
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Infrastructure`

## Purpose

HoneyDrunk.Infrastructure is the single home for the Grid's Bicep infrastructure-as-code **content**. It holds three things:

- `modules/` — per-concern reusable Bicep modules (networking, compute, identity, data, secrets, messaging, observability), moved out of `HoneyDrunk.Actions/bicep/modules/`.
- `platform/` — the shared-foundation layer: the shared Container Apps Environment (`cae-hd-{env}`), the shared image ACR (`acrhdshared{env}`), Log Analytics, the shared Service Bus namespace, and networking. Exports resource IDs that every Node's leaf template references.
- `nodes/{node}/` — thin per-Node leaf templates (`main.bicep` + `parameters.{env}.bicepparam`), relocated out of each Node's own repo.

## Why It Exists

Per the ADR-0077 amendment (2026-06-02), all Bicep content consolidates into one repo. The consolidation buys:

- **Whole-topology visibility** — the entire Grid's infrastructure is described in one place.
- **A home for the shared platform layer** — the foundational resources every Node depends on live in `platform/`, not scattered.
- **One PR per cross-Node infrastructure change** — instead of a fan-out across Node repos.

## Module Reference Model

Modules are referenced by **local relative path** (e.g. `'../../modules/compute/containerApp.bicep'`). There is **no module registry** — the cross-repo Bicep module-registry approach was dropped in full by the 2026-06-02 amendment, because a single-repo monorepo makes a Bicep registry pure overhead.

## Pipeline Model

The deploy + lint **pipeline does not live here**. The reusable deploy workflow (`job-deploy-bicep.yml`) and the Bicep lint gate (`job-bicep-lint.yml`) stay in `HoneyDrunk.Actions`, the Grid CI/CD control plane (ADR-0012). HoneyDrunk.Infrastructure **consumes** them.
