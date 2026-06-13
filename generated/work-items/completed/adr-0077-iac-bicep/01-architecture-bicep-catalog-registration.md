---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0077", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0077"]
accepts: ["ADR-0077"]
wave: 1
initiative: adr-0077-iac-bicep
node: honeydrunk-architecture
---

# Register the Bicep modules library, the acrhdbicep registry, and the deploy workflows in the Grid catalogs

> **STATUS — SUPERSEDED (2026-06-02) by packets 10 + 12.** Filed as `Architecture#385` (OPEN, unmerged). The ADR-0077 amendment (2026-06-02) moves the modules library to the new `HoneyDrunk.Infrastructure` Node (registered by packet 10), drops the `acrhdbicep` registry and `bicep-publish.yml` (registry confirmed dropped), and keeps only the deploy + lint reusable workflows registered under `honeydrunk-actions` (packet 12). This packet is retained for traceability; do not execute it. Close `Architecture#385` as superseded by packets 10 + 12. See `dispatch-plan.md`.

## Summary
Record ADR-0077's IaC substrate as catalog data: register the Bicep modules library and its publish/deploy workflows in `catalogs/contracts.json` under `honeydrunk-actions` (the Node that owns the modules library and the workflows per ADR-0012); add the `acrhdbicep` Bicep registry as a new "not-yet-provisioned" entry in `catalogs/grid-health.json` so packet 02's portal work flips it to `provisioned`; and update the `honeydrunk-actions` entry in `catalogs/relationships.json` to expose the new module-library and workflow surface.

## Context
ADR-0077 D2 places the Bicep modules library in `HoneyDrunk.Actions/bicep/modules/` and publishes modules to a dedicated `acrhdbicep` Azure Container Registry. D4 places the `job-deploy-bicep.yml` reusable deploy workflow in `HoneyDrunk.Actions`. Per ADR-0012, Actions is the Grid's CI/CD control plane — placing both the modules library and the deploy/publish workflows here is consistent with that role.

The Grid catalogs are the discoverability surface:
- `catalogs/contracts.json` registers each Node's contracts in its node block's `interfaces` array. The Bicep modules surface (the per-concern modules, the publish workflow, the deploy workflow) is the closest thing the Actions Node has to a "contract" — it is a public consumption surface for every other Node's per-repo `infra/main.bicep`.
- `catalogs/relationships.json` lists each Node's `exposes.contracts`; updating the `honeydrunk-actions` entry surfaces the new Bicep substrate to the dependency graph.
- `catalogs/grid-health.json` tracks per-environment infrastructure provisioning state. The `acrhdbicep` registry is new infrastructure that does not yet exist; packet 02 provisions it and flips its grid-health entry to `provisioned`.

This packet records only the **catalog** state. The actual library, workflows, modules, and registry land in subsequent packets (02–07).

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/contracts.json` — locate the node block whose `node` value is `honeydrunk-actions`. If it has no `interfaces` array yet (Actions' contracts are workflows, not .NET interfaces — so the block may need to be created or extended), add an `interfaces` array with the new entries listed below. The `kind` for workflow entries is `workflow`; for the modules library it is `library`; for the registry it is `azure-resource`.
- `catalogs/relationships.json` — append the new Bicep-substrate identifiers to the `honeydrunk-actions` entry's `exposes.contracts` (or the equivalent surface field for non-.NET Nodes — match the existing shape of the `honeydrunk-actions` entry). Do not invent a new field structure; if the existing entry exposes only workflow names, follow that pattern.
- `catalogs/grid-health.json` — add a new entry for the `acrhdbicep` Bicep registry with state `not-provisioned` (packet 02 flips it). If `grid-health.json` already has a section for shared Azure resources (the per-environment ACR `acrhdshared{env}` for instance), follow that section's shape.
- `catalogs/nodes.json` — **not edited.** nodes.json has no `exposes` field; the substrate surface lives in relationships.json and contracts.json.

## Proposed Implementation
1. **Inspect the existing shapes first.** Read the `honeydrunk-actions` block in `catalogs/contracts.json` and `catalogs/relationships.json` and the relevant section of `catalogs/grid-health.json`. The catalogs encode multiple Node types; match the existing shape for Actions (the CI/CD control-plane Node) rather than imposing a .NET-Node shape on it.
2. **`catalogs/contracts.json`** — locate or create the `honeydrunk-actions` node block. Add the following entries to its `interfaces` array (the existing array name; do not rename):
   - `bicep/modules` — `kind: library` — "The per-concern Bicep modules library shipped from `HoneyDrunk.Actions/bicep/modules/`. Published to the `acrhdbicep` Azure Container Registry on tagged release (`modules/v{N}.{N}.{N}`). Module groups: networking, compute, identity, data, secrets, messaging, observability. Consumed by per-Node `infra/main.bicep` templates via `br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}`."
   - `bicep-publish.yml` — `kind: workflow` — "Reusable workflow that runs `az bicep publish` for each changed module against the `acrhdbicep` registry on tagged release. Trigger: tag push of the form `modules/v{N}.{N}.{N}`. Authenticated via the existing Actions OIDC federation."
   - `job-deploy-bicep.yml` — `kind: workflow` — "Reusable deploy workflow that runs `az deployment group create` (or `az deployment sub create` for subscription-scoped resources) on a Node's `infra/main.bicep` with the appropriate `parameters.{env}.bicepparam` per ADR-0077 D4. Consumed by per-Node release workflows."
   - `acrhdbicep` — `kind: azure-resource` — "The shared Azure Container Registry hosting the published Bicep modules per ADR-0077 D2. Environment-agnostic (single registry across `dev`/`staging`/`prod`). Distinct from the per-environment container-image registry `acrhdshared{env}` per invariant 35."
   - `bicepconfig.json` — `kind: config` — "Bicep linter rules per ADR-0077 D3. Flags missing required tags (`hd:node`, `hd:env`, `hd:owner`, `hd:cost-center`, `hd:dr-tier`, `hd:adr`), non-conformant resource names, and hardcoded secret-shaped literals. Inherited by per-Node templates via Bicep's config-file resolution; enforced at PR time by the `bicep lint` step in `pr-core.yml`."
3. **`catalogs/relationships.json`** — append the same identifiers (`bicep/modules`, `bicep-publish.yml`, `job-deploy-bicep.yml`, `acrhdbicep`, `bicepconfig.json`) to the `honeydrunk-actions` entry's `exposes.contracts` array (or whichever existing surface field is the equivalent for non-.NET Nodes). Do not create a new top-level Node-to-Node edge — every Node already depends on Actions via the existing reusable-workflow pattern; the Bicep substrate is additive on the same edge.
4. **`catalogs/grid-health.json`** — add an entry for `acrhdbicep`. Match the shape of existing infrastructure entries: identifier, environment scope (`shared` — environment-agnostic), provisioning state (`not-provisioned` until packet 02 lands), the resource group it lives in (`rg-hd-platform-shared` recommended per the dispatch plan, or whichever RG the operator decides in packet 02 — leave it as a placeholder if unknown), the responsible ADR (`ADR-0077`).
5. **`catalogs/nodes.json`** — no edit. nodes.json has no `exposes` field; do not invent one.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`

## NuGet Dependencies
None. This packet touches only catalog JSON; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data only — the modules library, workflows, registry, and per-Node templates land in packets 02–09.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers the Bicep substrate entries (`bicep/modules`, `bicep-publish.yml`, `job-deploy-bicep.yml`, `acrhdbicep`, `bicepconfig.json`) in the `honeydrunk-actions` node block, matching the existing entry shape for that block
- [ ] `catalogs/relationships.json` `honeydrunk-actions` entry surfaces the new identifiers in its existing exposes-array shape, with all existing entries untouched
- [ ] `catalogs/grid-health.json` has a new `acrhdbicep` entry with state `not-provisioned`, scoped `shared` (environment-agnostic), citing `ADR-0077`
- [ ] `catalogs/nodes.json` is NOT modified (it has no `exposes` field)
- [ ] No new top-level Node-to-Node edge is created — every Node already depends on Actions; the Bicep substrate is additive on the existing dependency
- [ ] The `acrhdbicep` entry in grid-health.json is identifiable as distinct from `acrhdshared{env}` (the per-environment container-image registry — invariant 35) — comment or description field clarifies it
- [ ] No invariant change in this packet (invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0077 D2 — Modularize by concern.** Modules live in `HoneyDrunk.Actions/bicep/modules/` (Networking / Compute / Identity / Data / Secrets / Messaging / Observability). Published to `acrhdbicep` Azure Container Registry on tagged release via `bicep-publish.yml`. Per-Node templates consume modules via `br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}`. `acrhdbicep` is distinct from the per-environment container-image registry `acrhdshared{env}`.

**ADR-0077 D3 — Linter rules in `bicepconfig.json`.** Naming and tagging conventions enforced; PR gate fails on violation.

**ADR-0077 D4 — Per-environment deployment.** `main.bicep` + `parameters.{env}.bicepparam`; `job-deploy-bicep.yml` runs `az deployment group create` per environment.

**ADR-0012 — Actions is the Grid CI/CD control plane.** The Bicep deploy/publish workflows and the modules library belong in `HoneyDrunk.Actions`.

**Invariant 35 — One shared Container Apps Environment and one shared Azure Container Registry per environment.** `acrhdshared{env}` is the per-environment container-image registry. The Bicep modules registry `acrhdbicep` is a separate, environment-agnostic resource (D2 explicitly carves it out). Packet 00 reconciles the invariant text; this packet records the distinction in the catalog data.

## Constraints
- **Match existing catalog shapes for Actions.** Actions is not a .NET Node — its "contracts" are workflows and (now) Bicep modules. Inspect the existing `honeydrunk-actions` blocks in contracts.json and relationships.json and follow that shape rather than imposing the .NET-Node shape on it.
- **Do not register the modules themselves.** Individual modules (`compute/containerApp`, etc.) ship in packet 05. This packet records only the **library surface** and the workflows that publish/deploy it.
- **`acrhdbicep` is distinct from `acrhdshared{env}`.** The catalog entry must make the distinction visible — they are different resources for different purposes, despite the shared `acrhd` prefix.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0077`, `wave-1`

## Agent Handoff

**Objective:** Register the Bicep modules library, the `acrhdbicep` registry, and the `bicep-publish.yml` / `job-deploy-bicep.yml` workflows in the Grid catalogs under `honeydrunk-actions`, and add `acrhdbicep` as a `not-provisioned` entry in `grid-health.json`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the catalogs accurate so subsequent implementation packets (02–09) read a correct substrate surface.
- Feature: ADR-0077 IaC — Bicep rollout, Wave 1.
- ADRs: ADR-0077 D2/D3/D4 (primary), ADR-0012 (Actions as CI/CD control plane), invariant 35 (per-environment container-image ACR — the Bicep registry is a carve-out).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0077 should be Accepted before its substrate is recorded as catalog data.

**Constraints:**
- Match existing catalog shapes for `honeydrunk-actions` — Actions is not a .NET Node.
- Do not register individual modules (those ship in packet 05).
- Distinguish `acrhdbicep` from `acrhdshared{env}` in the catalog data; they are different resources.
- nodes.json is NOT edited — it has no `exposes` field.

**Key Files:**
- `catalogs/contracts.json` — new entries in the `honeydrunk-actions` block.
- `catalogs/relationships.json` — `honeydrunk-actions` exposes-array enrichment.
- `catalogs/grid-health.json` — new `acrhdbicep` entry, state `not-provisioned`.

**Contracts:** None changed — this packet records catalog metadata for substrate that packets 02–07 implement.
