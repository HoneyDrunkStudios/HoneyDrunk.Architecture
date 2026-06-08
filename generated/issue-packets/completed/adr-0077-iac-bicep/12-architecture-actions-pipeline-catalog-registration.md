---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0077", "wave-1"]
dependencies: ["packet:18", "packet:10"]
adrs: ["ADR-0077", "ADR-0012"]
wave: 1
initiative: adr-0077-iac-bicep
node: honeydrunk-actions
---

# Register the Bicep deploy + lint reusable workflows under honeydrunk-actions in the catalogs

> **Supersedes the Actions-side scope of packet 01** (`Architecture#385`). Packet 01 registered the Bicep *modules library* + the `acrhdbicep` registry + `bicep-publish.yml` + `job-deploy-bicep.yml` all under `honeydrunk-actions`. Under the ADR-0077 amendment (2026-06-02): the modules library MOVES to `HoneyDrunk.Infrastructure` (registered by packet 10); `acrhdbicep` and `bicep-publish.yml` are DROPPED (registry gone); only the deploy + lint reusable workflows STAY registered under `honeydrunk-actions` per ADR-0012. This packet records just that residual. Issue `Architecture#385` is closed as superseded by packets 10 + 12.

## Summary
Register, in the Grid catalogs under `honeydrunk-actions`, exactly the two Bicep *pipeline* surfaces that stay in `HoneyDrunk.Actions` per ADR-0012: the `job-deploy-bicep.yml` reusable deploy workflow and the `bicep lint` reusable gate (the `job-bicep-lint.yml` / `pr-core.yml` Bicep step). Do NOT register the modules library (it moved to `HoneyDrunk.Infrastructure`, registered by packet 10), `acrhdbicep` (registry dropped), or `bicep-publish.yml` (dropped).

## Context
The ADR-0077 amendment (2026-06-02) splits the original packet-01 catalog scope:
- **Pipeline (stays in Actions per ADR-0012):** `job-deploy-bicep.yml` + the `bicep lint` gate. These remain `honeydrunk-actions` surfaces — they are reusable workflows the CI/CD control plane owns and every infra-deploying consumer calls.
- **Content (moved to HoneyDrunk.Infrastructure):** the per-concern modules library + `platform/` + `nodes/`. Registered under `honeydrunk-infrastructure` by packet 10.
- **Dropped (registry gone):** `acrhdbicep` ACR, `bicep-publish.yml`, the `modules/v{N}.{N}.{N}` publish flow, `br:` refs.

This packet is the narrow Actions-side residual: surface the two pipeline workflows on the `honeydrunk-actions` catalog entry, and ensure the `acrhdbicep` grid-health entry from the original packet 01 is NOT created.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/contracts.json` — in the `honeydrunk-actions` block, add (or confirm) the two workflow entries: `job-deploy-bicep.yml` (`kind: workflow`) and `job-bicep-lint.yml` / the `bicep lint` `pr-core.yml` step (`kind: workflow`). Remove/omit any `bicep/modules`, `acrhdbicep`, or `bicep-publish.yml` entry — they are not Actions surfaces under the amendment.
- `catalogs/relationships.json` — surface the two workflow identifiers on the `honeydrunk-actions` exposes-array (matching the existing non-.NET-Node shape). Do not surface modules/registry identifiers.
- `catalogs/grid-health.json` — confirm NO `acrhdbicep` resource entry exists (the registry is dropped). If a draft of packet 01's entry was ever added, remove it.

## Proposed Implementation
1. **Inspect the `honeydrunk-actions` blocks first** in `contracts.json` and `relationships.json`; match the existing workflow-entry shape (Actions is a non-.NET Node whose "contracts" are reusable workflows).
2. **`catalogs/contracts.json`** — add to the `honeydrunk-actions` interfaces/workflows array:
   - `job-deploy-bicep.yml` — `kind: workflow` — "Reusable deploy workflow that runs `az deployment group create` (or `az deployment sub create` for subscription-scoped resources) on a Bicep template (`main.bicep` from `HoneyDrunk.Infrastructure/nodes/{node}/` or `platform/`) with the appropriate `parameters.{env}.bicepparam` per ADR-0077 D4 (as amended). Consumed by `HoneyDrunk.Infrastructure` deploy workflows. Local-path module resolution — no registry."
   - `job-bicep-lint.yml` (or the `bicep lint` step in `pr-core.yml`) — `kind: workflow` — "Reusable `bicep lint` + `bicep build-params` PR gate per ADR-0077 D3. Fails the PR on error-severity linter findings against the consuming repo's `bicepconfig.json`. Consumed by `HoneyDrunk.Infrastructure`'s `pr.yml`."
3. **`catalogs/relationships.json`** — append the same two identifiers to the `honeydrunk-actions` exposes-array. Note that `honeydrunk-infrastructure` consumes these (the edge is recorded on the Infrastructure side by packet 10; this side just surfaces the workflows).
4. **`catalogs/grid-health.json`** — verify there is NO `acrhdbicep` entry. The original packet 01 would have added one; under the amendment it must not exist.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`

## NuGet Dependencies
None. Catalog JSON only; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Catalog data.
- [x] Records only the two pipeline workflows that stay in Actions per ADR-0012.
- [x] No modules-library / registry surface registered under Actions (that content moved to Infrastructure / was dropped).

## Acceptance Criteria
- [ ] `catalogs/contracts.json` `honeydrunk-actions` block registers `job-deploy-bicep.yml` and the `bicep lint` gate as workflow surfaces, with no `bicep/modules`, `acrhdbicep`, or `bicep-publish.yml` entry
- [ ] `catalogs/relationships.json` `honeydrunk-actions` exposes-array surfaces the two workflow identifiers, all existing entries untouched
- [ ] `catalogs/grid-health.json` has NO `acrhdbicep` resource entry (registry dropped)
- [ ] No `bicep-publish.yml`, `modules/v{N}.{N}.{N}`, or `br:acrhdbicep.azurecr.io` reference appears in any edited file
- [ ] No invariant change in this packet; the invariant-35 carve-out is NOT added

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0077 amendment (2026-06-02).** The deploy + lint reusable workflows STAY in Actions per ADR-0012; the modules library, `platform/`, and `nodes/` MOVE to `HoneyDrunk.Infrastructure`; the registry (`acrhdbicep`, `bicep-publish.yml`, SemVer-tag-publish, `br:` refs) is DROPPED. Invariant 35 stands unchanged.

**ADR-0012 — Actions is the Grid CI/CD control plane.** Reusable Bicep workflows belong in Actions; only the Bicep content moves.

## Constraints
- **Two workflows only.** Register exactly `job-deploy-bicep.yml` and the `bicep lint` gate under `honeydrunk-actions`. Nothing else Bicep-related belongs on the Actions entry now.
- **No registry artifacts.** No `acrhdbicep`, no `bicep-publish.yml`, no `br:` paths.
- **Match the non-.NET-Node shape** for Actions (workflows-as-contracts).

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0077`, `wave-1`

## Agent Handoff

**Objective:** Register only the two Bicep *pipeline* workflows (`job-deploy-bicep.yml` + `bicep lint` gate) under `honeydrunk-actions` in the catalogs; ensure no modules-library / `acrhdbicep` / `bicep-publish.yml` surface is registered under Actions.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Record the residual Actions-side pipeline surface after the registry-drop consolidation moved the content to `HoneyDrunk.Infrastructure`.
- Feature: ADR-0077 IaC — Bicep rollout (amended 2026-06-02), Wave 1.
- ADRs: ADR-0077 + 2026-06-02 amendment, ADR-0012 (Actions owns the pipeline).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0077 (amended) Accepted.
- `packet:10` — Infrastructure Node registered (so the consume edge has a target).

**Constraints:**
- Two workflows only; no modules/registry surface under Actions.
- No `acrhdbicep` / `bicep-publish.yml` / `br:` artifacts.
- Match the non-.NET-Node workflow-as-contract shape.

**Key Files:**
- `catalogs/contracts.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`

**Contracts:** Records the two reusable-workflow surfaces; no .NET contract.
