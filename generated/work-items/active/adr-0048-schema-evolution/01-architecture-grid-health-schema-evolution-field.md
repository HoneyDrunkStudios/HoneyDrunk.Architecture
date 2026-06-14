---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "core", "docs", "adr-0048", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0048"]
wave: 1
initiative: adr-0048-schema-evolution
node: honeydrunk-architecture
---

# Add schema_evolution field to grid-health.json and Schema Deployment Coordination line to integration-points template

## Summary
Two catalog/template tasks from ADR-0048's Follow-up Work: (1) add a per-Node `schema_evolution` field to `catalogs/grid-health.json` with values `sql-project-dacpac`, `cosmos-schema-on-read`, or `n/a`; (2) extend the per-Node `integration-points.md` template with a Schema Deployment Coordination line so Nodes whose migration ordering matters across other Nodes have a discoverable place to record it.

## Context
ADR-0048's Follow-up Work names two catalog/template tasks:
- "Add the `schema_evolution` field to `catalogs/grid-health.json` (drift task per ADR-0014 `hive-sync`)."
- "Update `repos/{name}/integration-points.md` template with the Schema Deployment Coordination line."

`catalogs/grid-health.json` currently records `signal` / `version` / `canary_status` / `last_release` / `active_blockers` / `notes` per Node. Adding `schema_evolution` makes the per-Node migration posture discoverable from one catalog read — a Node either uses SQL Server database projects and DACPACs (D1 relational stores), Cosmos schema-on-read (D7 document stores), or has no persistent schema at all (library-only Nodes; `n/a`).

`repos/{name}/integration-points.md` is the per-Node integration-surface doc. Adding a Schema Deployment Coordination line lets Nodes whose migrations must sequence against other Nodes (e.g. an Expand-phase schema change that downstream consumers must read before the Contract phase lands) record that coordination explicitly. For most Nodes the line will be "None — migrations are Node-local." For Nodes like Audit or Notify Cloud that ship contracts whose schema shape downstream consumers depend on, the line will name those consumers.

This is a docs/catalog packet. No code, no .NET project.

## Scope
- `catalogs/grid-health.json` — add the `schema_evolution` field to every Node entry. Update `_meta.updated` and bump `_meta.schema_version` to `1.1`.
- `repos/{name}/integration-points.md` — extend each existing file with a `## Schema Deployment Coordination` section. The wording template is identical across files; the per-Node content fills in what (if anything) sequences against the Node's migrations.

## Proposed Implementation

### 1. `catalogs/grid-health.json` — `schema_evolution` field
Add the field to every Node entry. Values, taken from ADR-0048 D1/D7:
- `sql-project-dacpac` — the Node holds a relational store evolved via SQL Server database projects and DACPACs per ADR-0048 D1. Applies to: Audit (when standup lands), Memory, Knowledge, Billing, Notify Cloud, any Node with `HoneyDrunk.<Node>.Data` carrying a `DbContext`.
- `cosmos-schema-on-read` — the Node holds a document store evolved via schema-on-read per ADR-0048 D7. Applies to: Kernel.Idempotency (Cosmos dedup state per ADR-0042 D2), Pulse historical signals (Cosmos), any future vector/document backing.
- `n/a` — the Node holds no persistent schema. Applies to: library-only Nodes (Kernel core, Transport, Vault contracts, Auth contracts, Architecture, Standards, Actions, Studios), Nodes whose only persistence is Key Vault itself (Vault — Key Vault has no relational schema per ADR-0048 D5 carve-out).

Assignments to record (read from `nodes.json` for the current Node roster; do not assume an exhaustive list — assign by inspection):
- `honeydrunk-kernel` — `n/a` for the core Kernel; if the repo carries an `HoneyDrunk.Kernel.Idempotency.*` package family or equivalent document-store-backed sub-package, that sub-piece is `cosmos-schema-on-read` (per ADR-0042 D2 + ADR-0048 D7). At the **Node entry level** in grid-health.json, set `cosmos-schema-on-read` once the Kernel pilot lands (packet 08); until then, `n/a` is accurate. Record current state at edit time.
- `honeydrunk-transport`, `honeydrunk-vault`, `honeydrunk-vault-rotation`, `honeydrunk-auth`, `honeydrunk-web-rest`, `honeydrunk-architecture`, `honeydrunk-standards`, `honeydrunk-studios`, `honeydrunk-actions`, `honeydrunk-ai`, `honeydrunk-capabilities`, `honeydrunk-agents`, `honeydrunk-communications` — `n/a` (library-only or no relational schema).
- `honeydrunk-data` — `n/a` at the Node level (Data ships the *pattern* and provider packages, but Data itself doesn't host a persistent store; each consuming Node owns its store). Record `n/a` and note in `notes` that the per-consuming-Node schema deployment framework is `sql-project-dacpac` per ADR-0048 D1.
- `honeydrunk-notify` — `sql-project-dacpac` (Notify's `DbContext` already carries one or two scaffold migrations per ADR-0048 Context).
- `honeydrunk-pulse` — `cosmos-schema-on-read` if Pulse's historical-signals store is Cosmos; `n/a` otherwise. Check the Pulse repo state at edit time.
- `honeydrunk-observe` — `n/a` (Observe is event-intake; persistence is per-connector and currently no relational store exists).
- `honeydrunk-audit` (Seed) — `sql-project-dacpac` (Audit's `HoneyDrunk.Audit.Data` will hold the `AuditEntry` table per ADR-0030/ADR-0031). Even though the Node is Seed and the table doesn't exist yet, the *committed posture* is `sql-project-dacpac` so the field is forward-looking.
- `honeydrunk-memory`, `honeydrunk-knowledge` (Seed) — `sql-project-dacpac` (relational layouts per their standup ADRs); revisit at standup time if a vector-native backing is chosen, which would shift to `cosmos-schema-on-read`.
- `honeydrunk-billing` (proposed by ADR-0037, not yet in catalogs) — out of scope of this packet; if Billing's `nodes.json` entry doesn't exist, no `grid-health.json` row exists either. Billing's row will be added by ADR-0037's initiative when Billing is cataloged.
- Any other Node entries — assign by inspecting the Node's repo: a `DbContext` and a `HoneyDrunk.<Node>.Database/` folder ⇒ `sql-project-dacpac`; a Cosmos backing ⇒ `cosmos-schema-on-read`; neither ⇒ `n/a`.

Bump `_meta.schema_version` to `1.1` and update `_meta.updated` to today's date.

### 2. `repos/{name}/integration-points.md` — Schema Deployment Coordination section
Locate every existing `repos/HoneyDrunk.<Node>/integration-points.md` (a `Glob` of `repos/*/integration-points.md` returns the current set). Append a `## Schema Deployment Coordination` section to each file. The per-Node content fills in based on the Node's actual migration interactions:

```markdown
## Schema Deployment Coordination

**Migration framework:** `sql-project-dacpac` | `cosmos-schema-on-read` | `n/a` (matches `catalogs/grid-health.json`'s `schema_evolution` field).

**Downstream consumers whose migrations sequence against this Node's:** {list of Nodes whose Expand-phase code must land before this Node's Contract-phase migration; or "None — migrations are Node-local."}

**Upstream contracts this Node's schema depends on:** {list of Abstractions packages whose contracts shape this Node's tables; or "None."}

**Notes:** {anything else that affects migration ordering — e.g. "Audit's `AuditEntry` table is append-only-by-interface per ADR-0030; column drops, type narrowing, and `NOT NULL` additions are forbidden per ADR-0048 D8."}
```

The default content for most Nodes is "None — migrations are Node-local." Nodes that need detail:
- **Audit (when standup lands)** — note the ADR-0030 append-only-by-interface constraint and the ADR-0048 D8 paired-table pattern for breaking changes.
- **Kernel** — note the Cosmos idempotency dedup store follows ADR-0048 D7 schema-on-read; the schema-on-read documentation lives in `HoneyDrunk.<Node>.Database/README.md` (per packet 08, when it lands).
- **Notify** — note existing scaffold schema changes are retroactively annotated per packet 07 (when it lands).
- **Notify Cloud (when standup lands)** — note the shared-schema multi-tenancy posture per ADR-0048 D9 and the per-tenant variant trigger if/when adopted.

For Nodes whose detail won't be known until their standup or pilot lands (Audit, Memory, Knowledge, Billing, Notify Cloud, Kernel.Idempotency), record "None — migrations are Node-local. To be updated when {trigger}." with the trigger named (e.g. "to be updated when ADR-0048 packet 08 lands the Cosmos schema-on-read doc for the Kernel idempotency dedup store").

## Affected Files
- `catalogs/grid-health.json`
- Every `repos/HoneyDrunk.<Node>/integration-points.md` that currently exists in `repos/`.

## NuGet Dependencies
None. This packet touches only JSON/Markdown catalog/template files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] `repos/{name}/integration-points.md` is the per-Node integration-surface doc that lives in the Architecture repo (not in each Node repo), so editing it here is in-boundary.

## Acceptance Criteria
- [ ] Every Node entry in `catalogs/grid-health.json` carries a `schema_evolution` field with value `sql-project-dacpac`, `cosmos-schema-on-read`, or `n/a`
- [ ] `catalogs/grid-health.json` `_meta.schema_version` is bumped to `1.1` and `_meta.updated` reflects the edit date
- [ ] Every `repos/HoneyDrunk.<Node>/integration-points.md` file carries a `## Schema Deployment Coordination` section with the four sub-fields (framework, downstream consumers, upstream contracts, notes)
- [ ] Nodes with no current migration interactions record "None — migrations are Node-local." (or "None — migrations are Node-local. To be updated when {trigger}." for Seed Nodes)
- [ ] Audit's `integration-points.md` (if the file exists) notes the ADR-0030 append-only-by-interface constraint and the ADR-0048 D8 paired-table pattern for breaking changes
- [ ] No new Node-to-Node edge is added to `relationships.json`; this packet only adds documentation/catalog fields
- [ ] No invariant change (the three invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0048 D1 — SQL Server database projects and DACPACs is the Grid-wide framework for relational stores.** Document-store schema-on-read (D7) is the only exception. The `schema_evolution` catalog field surfaces each Node's committed posture in one place.

**ADR-0048 D7 — Document stores follow schema-on-read.** Cosmos and future vector/document backings have no DDL; new fields added by writing them; reading code tolerates absence; backfill jobs are documented as `Backfill/Backfill-YYYYMMDD-{description}.md` runbooks.

**ADR-0048 D8 — Audit table specifics.** `AuditEntry` migrations: no column drops ever; no type narrowing ever; no `NOT NULL` additions; new columns always nullable; paired-table pattern (`AuditEntryV2` alongside) for breaking changes. Surfaced in Audit's `integration-points.md` Schema Deployment Coordination section.

**ADR-0048 Follow-up Work — catalog and template tasks.** "Add the `schema_evolution` field to `catalogs/grid-health.json` (drift task per ADR-0014 `hive-sync`)." "Update `repos/{name}/integration-points.md` template with the Schema Deployment Coordination line." Both delivered by this packet.

**ADR-0014 — `hive-sync` drift reconciliation.** The catalog field is added in source here; `hive-sync` will detect drift if a Node's actual migration posture diverges from the catalog value.

## Constraints
- **Schema-evolution values are restricted to the three named: `sql-project-dacpac`, `cosmos-schema-on-read`, `n/a`.** Do not invent additional values (e.g. `flyway`, `none`, `to-be-decided`). If a Node's posture is genuinely unknown, use `n/a` and note the uncertainty in `notes`.
- **Library-only Nodes are `n/a`, not blank.** Every Node entry gets a value; missing the field is a schema violation.
- **Match the existing `grid-health.json` shape.** Place `schema_evolution` consistently across entries (e.g. between `last_release` and `active_blockers`, or wherever the existing field order suggests); preserve all existing fields.
- **`hive-sync` is the reconciler, not this packet.** This packet adds the field with the best-current-knowledge value; `hive-sync` reconciles drift later. Do not run `hive-sync` from this packet's PR.

## Labels
`feature`, `tier-3`, `core`, `docs`, `adr-0048`, `wave-1`

## Agent Handoff

**Objective:** Add the `schema_evolution` field to `catalogs/grid-health.json` for every Node and the Schema Deployment Coordination section to every existing `repos/{name}/integration-points.md` template.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Surface each Node's migration posture in one catalog read and give Nodes a discoverable place to record migration-ordering coordination with other Nodes.
- Feature: ADR-0048 Schema Evolution rollout, Wave 1.
- ADRs: ADR-0048 D1/D7/D8 (primary), ADR-0014 (`hive-sync` drift), ADR-0030 (Audit append-only-by-interface).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0048 should be Accepted before its catalog footprint is recorded.

**Constraints:**
- `schema_evolution` values are exactly one of `sql-project-dacpac`, `cosmos-schema-on-read`, `n/a` — no other values.
- Library-only Nodes are `n/a`, not blank.
- Bump `_meta.schema_version` to `1.1`.
- Schema Deployment Coordination section default is "None — migrations are Node-local."; only Nodes with real cross-Node coordination get detail.

**Key Files:**
- `catalogs/grid-health.json`
- Every `repos/HoneyDrunk.<Node>/integration-points.md` (Glob `repos/*/integration-points.md`).

**Contracts:** None changed — catalog metadata only.
