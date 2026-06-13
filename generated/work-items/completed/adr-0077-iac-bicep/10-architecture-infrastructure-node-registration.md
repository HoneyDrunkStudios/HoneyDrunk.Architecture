---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0077", "wave-1"]
dependencies: ["work-item:18"]
adrs: ["ADR-0077", "ADR-0012", "ADR-0082"]
wave: 1
initiative: adr-0077-iac-bicep
node: honeydrunk-infrastructure
---

# Register HoneyDrunk.Infrastructure as a new Grid Node in the catalogs and routing rules

> **Supersedes the catalog-registration scope of packet 01** (`Architecture#385`). Packet 01 registered the Bicep substrate under `honeydrunk-actions` and added the `acrhdbicep` grid-health entry. The ADR-0077 amendment (2026-06-02) consolidates all Bicep *content* into a new `HoneyDrunk.Infrastructure` repo and drops the cross-repo module registry. This packet registers the new Node; packet 12 carries the residual *Actions-side* catalog edit (the deploy + lint reusable workflows stay registered under `honeydrunk-actions`); the `acrhdbicep` grid-health entry from packet 01 is **not** created (registry dropped). Issue `Architecture#385` should be closed as superseded by this packet + packet 12.

## Summary
Register the new `HoneyDrunk.Infrastructure` Node in the Grid catalogs and routing rules per the ADR-0077 amendment (2026-06-02): add the Node row to `catalogs/nodes.json`, the edges block to `catalogs/relationships.json`, the entry to `catalogs/grid-health.json`, the contracts block to `catalogs/contracts.json`, a routing-rule keyword row to `routing/repo-discovery-rules.md`, a sector row to `constitution/sectors.md`, and the five-file context folder at `repos/HoneyDrunk.Infrastructure/`. This is the catalog/governance prerequisite for the new repo (invariant 102 items 1–6 + the routing entry) — it lands before the repo's first non-bootstrap PR.

## Context
The ADR-0077 amendment (2026-06-02) made `HoneyDrunk.Infrastructure` a NEW Node. All Bicep *content* — `modules/` (the seven per-concern module groups, moved out of `HoneyDrunk.Actions/bicep/modules/`), the NEW `platform/` layer (shared/foundational resources: shared Container Apps Environment, the shared image ACR `acrhdshared{env}`, Log Analytics, the shared Service Bus namespace, networking), and `nodes/{node}/` (thin per-Node leaf templates relocated out of each Node's own repo) — lives in the new repo. The *pipeline* does not move: the reusable deploy workflow (`job-deploy-bicep.yml`) and the `bicep lint` gate stay in `HoneyDrunk.Actions` per ADR-0012 (Actions is the CI/CD control plane); `HoneyDrunk.Infrastructure` *consumes* them.

Modules are referenced by **local relative path** (`'../../modules/compute/containerApp.bicep'`), not via a registry. The cross-repo Bicep module registry (`acrhdbicep` ACR, `bicep-publish.yml`, the `modules/v{N}.{N}.{N}` tag-publish flow, `br:acrhdbicep.azurecr.io/...` refs) is **dropped in full** — confirmed by the operator 2026-06-02 — because a single-repo monorepo makes a Bicep registry pure overhead.

Per invariant 102, a Node repo must have its catalog rows, context folder, and sector row **before** its first non-bootstrap PR merges. This packet lands those (the Phase-A items 1–6 from invariant 102, plus the routing keyword row). The repo creation itself and the in-repo scaffolding (`repo-to-node.yml`, `.honeydrunk-review.yaml`, `pr.yml`, branch protection, org-secret binding — invariant 102 items 6–10) are operator/bootstrap work tracked in packet 11.

This is a catalog/governance docs packet. No code, no .NET project.

## Node identity (operator decision needed — see Human Prerequisites)
Proposed identity, matching the `honeydrunk-actions` / `honeydrunk-architecture` non-.NET-Node shape:
- **id:** `honeydrunk-infrastructure`
- **name:** `HoneyDrunk.Infrastructure`
- **sector:** `Ops` (same sector as Actions; IaC is an Ops/cross-cutting substrate per ADR-0077)
- **signal:** `Seed` at registration (no content shipped yet); flips to `Live` when the first module set + platform scaffold land.
- **cluster:** `foundation`
- **type:** `node`
- **foundational:** `false` (consistent with `honeydrunk-actions`)
- **short:** "Bicep IaC content for the Grid — per-concern modules, the shared platform layer, and per-Node leaf templates."

## Scope
- `catalogs/nodes.json` — add the `honeydrunk-infrastructure` Node row (match the `honeydrunk-actions` shape; it is a non-.NET content repo, not a package-publishing Node).
- `catalogs/relationships.json` — add a `honeydrunk-infrastructure` entry under `nodes`. It **consumes** `honeydrunk-actions` (the `job-deploy-bicep.yml` deploy workflow + the `bicep lint` gate as reusable workflows). It is **consumed_by** no Node at runtime (Bicep content is a deploy-time artifact, not a runtime dependency); record `consumed_by: []` or the catalog's empty-equivalent.
- `catalogs/grid-health.json` — add a `honeydrunk-infrastructure` node entry, `signal: Seed`, `tracked_workflows: ["pr.yml"]` initially (the repo's `pr.yml` calls `pr-core.yml`; the deploy workflow runs from this repo but is defined in Actions). Do **not** add an `acrhdbicep` resource entry — the registry is dropped.
- `catalogs/contracts.json` — add a `honeydrunk-infrastructure` block. Its "contracts" are the consumable Bicep surfaces: `modules/` (per-concern module library, local-path-referenced), `platform/` (shared-foundation templates), `nodes/` (per-Node leaf templates). `kind: bicep-module` / `bicep-template` as appropriate. No `br:` registry path — reference style is local relative path within the repo.
- `routing/repo-discovery-rules.md` — add a keyword row: `bicep, IaC, infrastructure, main.bicep, bicepparam, module, platform, container apps environment, resource group, provisioning, az deployment → HoneyDrunk.Infrastructure`.
- `constitution/sectors.md` — add the `HoneyDrunk.Infrastructure` row under the Ops sector.
- `repos/HoneyDrunk.Infrastructure/` — new context folder with all five files: `overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`.

## Proposed Implementation
1. **`catalogs/nodes.json`** — add the Node row using the identity block above. Inspect the `honeydrunk-actions` row and mirror its field set (it is the closest analogue: an Ops, non-package, foundation-cluster Node). Set `signal: "Seed"`.
2. **`catalogs/relationships.json`** — add under `nodes`:
   - `consumes`: `["honeydrunk-actions"]` with `consumes_detail.honeydrunk-actions: ["job-deploy-bicep.yml", "bicep lint (pr-core.yml)"]`.
   - `consumed_by` / `consumed_by_planned`: empty (deploy-time artifact; no runtime consumer). Note in the entry: "Every deployable Node's infrastructure is *declared* here under `nodes/{node}/`, but no Node takes a runtime dependency on this repo — Bicep content is applied at deploy time, not linked at build time."
3. **`catalogs/grid-health.json`** — add the node entry; `signal: "Seed"`, `version: null` or `"n/a"` (non-versioned content repo, like Actions/Architecture), `tracked_workflows: ["pr.yml"]`, note: "New IaC-content Node per ADR-0077 amendment 2026-06-02; holds modules/, platform/, nodes/. No acrhdbicep registry (dropped)."
4. **`catalogs/contracts.json`** — add the `honeydrunk-infrastructure` block with the three consumable surfaces (`modules/`, `platform/`, `nodes/`), each described with its local-relative-path reference style. Explicitly note no registry/`br:` path.
5. **`routing/repo-discovery-rules.md`** — add the keyword row to the Keyword → Repo Mapping table.
6. **`constitution/sectors.md`** — add the row under Ops.
7. **`repos/HoneyDrunk.Infrastructure/`** — author the five context files:
   - `overview.md` — what the Node is (Bicep IaC content: modules/platform/nodes), why it exists (ADR-0077 amendment consolidation — one place for the whole topology, the shared-layer home, one PR per cross-Node infra change), the modules-by-local-path model, the consume-Actions-pipeline model.
   - `boundaries.md` — owns: all Bicep templates and modules; the `platform/` shared layer; per-Node leaf templates under `nodes/{node}/`. Does NOT own: the deploy/lint pipeline (Actions owns it per ADR-0012); runtime application code; secret *values* (Vault owns those — templates reference by URI per ADR-0077 D7). Cross-boundary rule: per-Node *runtime* code stays in the Node's own repo; only its `infra/` Bicep relocates here.
   - `invariants.md` — point to the three IaC invariants (numbers from packet 00's reservation block) and the relevant Hosting Platform invariants (34, 35), naming (19), secrets (8).
   - `integration-points.md` — consumes `job-deploy-bicep.yml` + `bicep lint` from Actions; declares the shared platform resources that every Node's leaf template references by resource ID (closing the hand-pasted-ARM-ID gap).
   - `active-work.md` — the ADR-0077 initiative is the in-flight work; list the bringup packets (11, 13, 14, 15).

## Affected Files
- `catalogs/nodes.json`
- `catalogs/relationships.json`
- `catalogs/grid-health.json`
- `catalogs/contracts.json`
- `routing/repo-discovery-rules.md`
- `constitution/sectors.md`
- `repos/HoneyDrunk.Infrastructure/overview.md` (new)
- `repos/HoneyDrunk.Infrastructure/boundaries.md` (new)
- `repos/HoneyDrunk.Infrastructure/invariants.md` (new)
- `repos/HoneyDrunk.Infrastructure/active-work.md` (new)
- `repos/HoneyDrunk.Infrastructure/integration-points.md` (new)

## NuGet Dependencies
None. Catalog/governance docs only; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] Registers a NEW Node per the ADR-0077 amendment; no code change in any other repo.
- [x] No runtime contract cascade — Bicep content is a deploy-time artifact, not a runtime dependency.

## Acceptance Criteria
- [ ] `catalogs/nodes.json` carries a `honeydrunk-infrastructure` row in the `honeydrunk-actions` non-.NET-Node shape, `signal: Seed`, sector `Ops`
- [ ] `catalogs/relationships.json` carries a `honeydrunk-infrastructure` entry that `consumes` `honeydrunk-actions` (deploy + lint workflows) and has empty runtime `consumed_by`
- [ ] `catalogs/grid-health.json` carries a `honeydrunk-infrastructure` entry, `signal: Seed`, `tracked_workflows: ["pr.yml"]`, with NO `acrhdbicep` resource entry (registry dropped)
- [ ] `catalogs/contracts.json` carries a `honeydrunk-infrastructure` block listing `modules/`, `platform/`, `nodes/` as local-path-referenced surfaces — no `br:`/registry path anywhere
- [ ] `routing/repo-discovery-rules.md` carries a keyword row mapping IaC/Bicep/platform keywords to `HoneyDrunk.Infrastructure`
- [ ] `constitution/sectors.md` carries a `HoneyDrunk.Infrastructure` row under Ops
- [ ] `repos/HoneyDrunk.Infrastructure/` exists with all five context files, each non-empty and accurate to the amendment shape
- [ ] No `acrhdbicep`, no `bicep-publish.yml`, no `modules/v{N}.{N}.{N}`, no `br:acrhdbicep.azurecr.io` reference appears in any edited file (registry dropped per ADR-0077 amendment)
- [ ] No invariant change in this packet (invariants land in packet 00; the invariant-35 carve-out is NOT added)

## Human Prerequisites
- [ ] Confirm the Node identity block (id `honeydrunk-infrastructure`, sector `Ops`, signal `Seed`). If a different sector or short name is preferred, the executor uses the operator's choice.
- [ ] Confirm the GitHub repo `HoneyDrunkStudios/HoneyDrunk.Infrastructure` will be created (the actual creation is packet 11; this packet only registers the catalog rows that must precede the repo's first non-bootstrap PR per invariant 102).

## Referenced ADR Decisions
**ADR-0077 amendment (2026-06-02).** All Bicep content consolidates into `HoneyDrunk.Infrastructure`: `modules/` (per-concern, moved out of Actions), `platform/` (NEW shared-foundation home — shared Container Apps Environment, shared image ACR, Log Analytics, shared Service Bus, networking), `nodes/{node}/` (thin per-Node leaf templates relocated out of Node repos). Modules referenced by local relative path. The cross-repo module registry (`acrhdbicep` ACR, `bicep-publish.yml`, the SemVer-tag-publish flow, `br:` refs) is DROPPED in full. The deploy + lint workflows STAY in Actions per ADR-0012; Infrastructure consumes them. Invariant 35 stands unchanged (no carve-out needed — registry dropped).

**ADR-0012 — Actions is the Grid CI/CD control plane.** The Bicep deploy/lint reusable workflows belong in `HoneyDrunk.Actions`; the new repo consumes them.

**Invariant 102 (ADR-0082) — Node registration is mandatory before the first non-bootstrap PR merges.** Items 1–6 (nodes.json row, relationships edges, grid-health entry, five-file context folder, sectors row, repo-to-node mapping) are Phase A and merge before the scaffold PR. This packet lands items 1–5 + the routing keyword row; the `repo-to-node.yml` mapping (item 6) is in `HoneyDrunk.Actions` and is carried by packet 12.

## Constraints
- **Match the non-.NET-Node shape.** `HoneyDrunk.Infrastructure` is a content repo (Bicep templates), like Actions and Architecture — not a package-publishing .NET Node. Mirror the `honeydrunk-actions` catalog shape; do not invent a `package`/`Abstractions` shape.
- **No registry artifacts anywhere.** Do not add `acrhdbicep`, `bicep-publish.yml`, `modules/v{N}.{N}.{N}`, or any `br:acrhdbicep.azurecr.io/...` reference. The registry is dropped per the confirmed amendment.
- **No runtime cascade edge.** Bicep content is applied at deploy time; no Node takes a build-time/runtime dependency on this repo. The relationship is consume-Actions-workflows only.
- **Signal is Seed at registration.** It flips to Live when packets 13 (modules) + 14 (platform) land content.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0077`, `wave-1`

## Agent Handoff

**Objective:** Register `HoneyDrunk.Infrastructure` as a new Grid Node — catalog rows (nodes/relationships/grid-health/contracts), routing keyword row, sectors row, and the five-file `repos/HoneyDrunk.Infrastructure/` context folder — per the ADR-0077 amendment, with no registry artifacts.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the invariant-102 Phase-A catalog prerequisites so the new repo's first non-bootstrap PR is legal.
- Feature: ADR-0077 IaC — Bicep rollout (amended 2026-06-02), Wave 1.
- ADRs: ADR-0077 + its 2026-06-02 amendment (primary), ADR-0012 (pipeline stays in Actions), ADR-0082 (invariant 102 standup procedure).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0077 (with the amendment) should be Accepted before its new Node is registered.

**Constraints:**
- Non-.NET content-repo shape (mirror `honeydrunk-actions`).
- No `acrhdbicep` / `bicep-publish.yml` / `modules/v*` / `br:` artifacts anywhere — registry dropped.
- No runtime cascade edge; consume-Actions-workflows only.
- Signal `Seed` at registration.

**Key Files:**
- `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/contracts.json`
- `routing/repo-discovery-rules.md`, `constitution/sectors.md`
- `repos/HoneyDrunk.Infrastructure/{overview,boundaries,invariants,active-work,integration-points}.md` (new)

**Contracts:** None changed at runtime — Bicep content is a deploy-time artifact. The "contracts" registered are the consumable Bicep surfaces (`modules/`, `platform/`, `nodes/`), local-path-referenced.
