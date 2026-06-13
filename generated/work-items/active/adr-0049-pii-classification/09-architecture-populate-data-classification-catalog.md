---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0049", "wave-5"]
dependencies: ["work-item:01", "work-item:07", "work-item:08"]
adrs: ["ADR-0049"]
wave: 5
initiative: adr-0049-pii-classification
node: honeydrunk-architecture
---

# Populate catalogs/data-classification.json from the post-backfill Grid surface

## Summary
Now that the Core-sector (packet 07) and Ops-sector (packet 08) backfill PRs have landed, walk every live Node's `[Classification]`/`[PiiField]` markers and populate `catalogs/data-classification.json` (schema established in packet 01) with the per-Node summary surface: `highest_classification`, `pii_categories`, `sensitive_pii` flag, `contracts[]`, `stores[]`. Additionally, add classification annotations to `catalogs/contracts.json` so the contract registry surface carries the per-contract classification tier alongside the existing `name`/`kind`/`description`.

## Context
ADR-0049 D9 names `catalogs/data-classification.json` as the Grid-wide operator-facing inventory: the "where does PII flow in my Grid" answer. ADR-0049 D11 names a related companion edit: "`catalogs/contracts.json` gains classification annotations on contracts." Both changes land here in a single packet because they answer different sides of the same operator question:

- `catalogs/data-classification.json` — per-Node summary across all contracts/stores; the "where" surface.
- `catalogs/contracts.json` (annotated) — per-contract per-Node classification; the "what tier is this specific interface?" surface.

The data sources:
- The post-merge state of every Live-signal Node carrying classification markers (after packets 07 and 08).
- The Audit redactor's reflection-visible shapes (after packet 05).
- The Pulse redactor's processor catalog (after packet 04).

The catalog does not duplicate every field of every record — that would be unmaintainable and redundant with the source-of-truth code. Per ADR-0049 D9 it declares the **summary surface**: which contracts touch which classification tiers, which PII categories are present per Node, what the highest-classification fanout looks like across the Grid.

## Scope
- `catalogs/data-classification.json` — populate the `nodes` object for every Live-signal Node in `catalogs/nodes.json` plus any Seed-signal Node whose backfill has occurred (Audit per packet 05). Per-Node entry conforms to the schema established in packet 01.
- `catalogs/contracts.json` — add a per-interface/type `classification` field (and `pii_categories` array for any record that carries `[PiiField]` markers). The shape of the annotation must match the file's existing `interfaces[]`/types[]` block structure; do not invent a parallel shape.

## Proposed Implementation

1. **Re-read packet 01's schema** for `catalogs/data-classification.json`. The schema shape and the empty `nodes: {}` seed are in place from packet 01. This packet populates `nodes` with one entry per Live-signal Node.

2. **Per-Node walk.** For each Live-signal Node in `catalogs/nodes.json`:
   - Identify the highest-classification field anywhere in the Node's persisted-record/contract/Audit-payload types.
   - Enumerate which `PiiCategory` values appear at least once (any subset of `Pii`, `SensitivePii`, `Pseudonymous`).
   - Flag `sensitive_pii: true` if any `[PiiField(SensitivePii)]` marker exists; else `false`.
   - List the public contracts that pass classified data (interface name or method or record name; the request-side classification tier; the per-field markers as `FieldName:PiiCategory` strings).
   - List the persisted stores (store/table/container name; the highest classification of fields in the store; the retention class shorthand from ADR-0049 D3).

   Per-Node entry example, drawn from ADR-0049 D9's sketch:
   ```json
   "HoneyDrunk.Notify": {
     "highest_classification": "Restricted",
     "pii_categories": ["Pii"],
     "sensitive_pii": false,
     "contracts": [
       {
         "name": "INotificationSender.SendAsync",
         "request_class": "Restricted",
         "fields": ["RecipientEmail:Pii", "MessageBody:Pii", "Tenant:Pseudonymous"]
       },
       {
         "name": "AuditEntry(NotifySent)",
         "request_class": "Confidential",
         "fields": ["RecipientPrincipalId:Pseudonymous", "Tenant:Pseudonymous"]
       }
     ],
     "stores": [
       {
         "name": "DeliveryAttempts",
         "class": "Restricted",
         "retention_class": "tenant-active"
       }
     ]
   }
   ```

   Drive the population from the actual post-merge code state. Read each Node's source after packets 07 / 08 have merged.

3. **`catalogs/contracts.json` annotation.** For each Node block's `interfaces[]` and types[]` entries, add a new `classification` field at the entry level:
   ```json
   {
     "name": "INotificationSender",
     "kind": "interface",
     "description": "...",
     "classification": "Restricted",
     "pii_categories": ["Pii"]
   }
   ```
   The `classification` value is the highest classification of any field on the request or response shape; the `pii_categories` array is the union of `PiiCategory` values present. The annotation is per-interface, not per-field — the per-field detail lives in the source code (declarative attributes) and the per-Node summary lives in `data-classification.json`.

4. **Live Nodes covered:** the Live-signal Nodes per `catalogs/nodes.json` at packet-09 branch time. As of authoring: Kernel, Transport, Vault, Auth, Web.Rest, Data, Actions, Notify, Communications, Studios, Architecture (12 entries). Pulse and Audit are currently Seed but have ADR-0049 marker coverage from packets 04/05 — include them. AI-sector Nodes (Capabilities, Operator, Agents, Memory, Knowledge, Evals, Sim, Flow, AI) are Seed/planned and have no markers yet; **leave them out of this packet's population** — they'll register themselves when their standup ADRs land per ADR-0049 D10 Phase 6.

5. **Catalog reconciliation cadence.** `hive-sync` (per packet 10) will reconcile drift between source markers and catalog entries nightly. This packet's job is to populate the **initial** state; ongoing drift is `hive-sync`'s problem.

6. **Update `generated_at` timestamp** in `catalogs/data-classification.json` to the populate-time UTC stamp.

7. **No edits to `catalogs/nodes.json` or `catalogs/relationships.json`.** This packet's scope is the classification catalog (new file) and the contracts catalog (annotation addition). Nodes and relationships catalogs are unaffected.

## Affected Files
- `catalogs/data-classification.json` — `nodes` object populated for ~14 Nodes.
- `catalogs/contracts.json` — `classification` and `pii_categories` annotations on per-interface entries across all Live-marker Nodes.

## NuGet Dependencies
None. Catalog JSON only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo. Read-only walk of post-merge state.
- [x] No new top-level Node-to-Node edge — only catalog enrichment.

## Acceptance Criteria
- [ ] `catalogs/data-classification.json` has a populated `nodes` entry for every Live-signal Node carrying classification markers post-backfill — at minimum Auth, Vault, Data, Notify, Communications, Pulse, Audit; ideally all 12 Live-signal Nodes plus marker-bearing Seed Nodes
- [ ] Each `nodes` entry conforms to the schema from packet 01: `highest_classification`, `pii_categories[]`, `sensitive_pii`, `contracts[]`, `stores[]`
- [ ] `catalogs/contracts.json` has a per-interface `classification` annotation on every interface that carries classified data; `pii_categories[]` annotation on every interface carrying PII markers
- [ ] `generated_at` timestamp in `data-classification.json` is updated to the populate-time UTC stamp
- [ ] `catalogs/nodes.json` is NOT modified
- [ ] `catalogs/relationships.json` is NOT modified in this packet
- [ ] The JSON validates against any existing JSON-validation step in the repo's CI
- [ ] No AI-sector Seed Node is added to the catalog — those will self-register at standup per ADR-0049 D10 Phase 6

## Human Prerequisites
- [ ] **Confirm packets 07 and 08 have ALL merged and released.** This packet reads the post-backfill state across Core-sector and Ops-sector Live Nodes. If any backfill PR is unmerged at branch time, this packet WAITS — partial population locks in drift.
- [ ] **Confirm packet 01 (catalog schema) is merged.** The file must exist with its schema before this packet populates it.

## Referenced ADR Decisions
**ADR-0049 D9 — `catalogs/data-classification.json` inventory artifact.** Per-Node summary: `highest_classification`, `pii_categories`, `sensitive_pii`, `contracts[]`, `stores[]`. The catalog declares the **summary surface**; it does not duplicate every field. The mapping table itself (PrincipalId ↔ email/name) is NOT in this catalog — it lives in the per-Node identity store per D6.

**ADR-0049 D11 — `catalogs/contracts.json` annotation.** "`catalogs/contracts.json` gains classification annotations on contracts." The annotation lives on the per-interface entry.

**ADR-0049 D10 Phase 4 — Catalog and `hive-sync` reconciliation.** "Author `catalogs/data-classification.json` schema; populate from the Phase 2 backfill output; wire `hive-sync` reconciliation rule." Schema in packet 01; population in this packet; reconciliation in packet 10.

**ADR-0049 D10 Phase 6 — Consumer-app onboarding stores.** Consumer-app PDRs (0003/0005/0006/0008) register themselves in `data-classification.json` at their standup. Not in scope here.

## Constraints
- **Read-only walk of post-merge source.** This packet does not modify any Node's source code. It walks the markers and records the summary.
- **No AI-sector Seed Nodes in the catalog.** Each AI-sector Node self-registers at its standup per ADR-0049 D10 Phase 6.
- **Mapping table is NOT in this catalog.** The `PrincipalId ↔ raw value` mapping per ADR-0049 D6 lives in the per-Node identity store; this catalog records only the summary surface.
- **JSON validation passes.** Confirm the populated file validates against any existing schema-validation step in the repo's CI.
- **The 14-Node count is illustrative.** The actual count depends on which Nodes have post-backfill markers at branch time. Read `catalogs/nodes.json` for the canonical Live-signal Node list.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0049`, `wave-5`

## Agent Handoff

**Objective:** Populate `catalogs/data-classification.json` per-Node entries from the post-backfill Grid surface; add `classification`/`pii_categories` annotations to `catalogs/contracts.json`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Operator-facing inventory of where PII flows in the Grid.
- Feature: ADR-0049 Data Classification rollout, Wave 5 (Phase 4 catalog reconciliation).
- ADRs: ADR-0049 D9/D11 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — catalog schema and empty seed exist.
- `work-item:07` — Core-sector backfill complete and released.
- `work-item:08` — Ops-sector backfill complete and released.

**Constraints:**
- Read-only walk; no source-code edits.
- Live Nodes only at v1; AI-sector Seed Nodes self-register at standup.
- Mapping table not in this catalog.
- JSON validation passes.

**Key Files:**
- `catalogs/data-classification.json` — `nodes` population.
- `catalogs/contracts.json` — `classification` and `pii_categories` annotations on per-interface entries.

**Contracts:** No code contracts changed. Catalog metadata only.
