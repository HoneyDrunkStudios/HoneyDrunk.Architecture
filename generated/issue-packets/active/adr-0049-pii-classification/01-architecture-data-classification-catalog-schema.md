---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0049", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0049"]
wave: 1
initiative: adr-0049-pii-classification
node: honeydrunk-architecture
---

# Author the catalogs/data-classification.json schema and seed an empty inventory

## Summary
Create `catalogs/data-classification.json` per ADR-0049 D9 with the schema for the Grid-wide data-classification inventory artifact. Seed the file with an empty `nodes` object — actual per-Node classification entries land in packet 09 after Phase 2 backfill completes. Document the schema in `catalogs/README.md` (or whichever index documents the catalogs).

## Context
ADR-0049 D9 commits a new catalog file at `catalogs/data-classification.json` that enumerates, per Node, the public surface that carries classified data — the contracts (per `catalogs/contracts.json`) that pass through Restricted-class fields, the audit-emit shapes, the API request/response shapes, the persisted-record types. The catalog does NOT duplicate every field of every record — it declares the **summary surface**: which contracts touch which classification tiers, which PII categories are present per Node, what the highest-classification fanout looks like across the Grid.

The catalog is the operator's "where does PII flow in my Grid" surface. It answers the question that today requires reading every Node's source code. ADR-0049 D9 names `hive-sync` (per ADR-0014) as the reconciler — it reconciles the catalog against the source code's `[Classification]` and `[PiiField]` attributes on every nightly run, treating drift as a finding. The reconciliation logic itself lands in packet 10.

This packet ships the **schema and an empty seed** — the structure is in place so packets 04, 05, 06, 07, 08, 09 can reference a real file without inventing their own format. The actual classification entries for the 12 live Nodes are populated in packet 09 once the per-Node backfill (packets 07, 08) has determined the field-level classifications. The redactor-integration packets (04, 05) also reference this file but do not write to it — their concern is the runtime redaction, not the catalog representation.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/data-classification.json` — new file with schema version `1.0`, `generated_at` timestamp, and an empty `nodes` object.
- `catalogs/README.md` (or equivalent index) — document the new catalog file's purpose, schema, and reconciliation cadence.

## Proposed Implementation

1. Create `catalogs/data-classification.json` with this shape (sketch from ADR-0049 D9, normalized to a strict JSON schema):

```json
{
  "version": "1.0",
  "generated_at": "2026-05-22T00:00:00Z",
  "description": "Grid-wide data-classification inventory per ADR-0049 D9. Per-Node summary of contracts, audit emits, API surfaces, and persisted stores that carry classified data. Reconciled nightly by hive-sync against source-code [Classification]/[PiiField] attributes.",
  "schema": {
    "node_entry": {
      "highest_classification": "Public | Internal | Confidential | Restricted",
      "pii_categories": ["Pii", "SensitivePii", "Pseudonymous"],
      "sensitive_pii": "boolean — true if any field is marked [PiiField(SensitivePii)]",
      "contracts": [
        {
          "name": "interface or method or record name",
          "request_class": "Public | Internal | Confidential | Restricted",
          "fields": ["FieldName:PiiCategory or FieldName:DataClass for non-PII Restricted"]
        }
      ],
      "stores": [
        {
          "name": "store / table / container name",
          "class": "Public | Internal | Confidential | Restricted",
          "retention_class": "tenant-active | telemetry-90d | audit-730d | audit-t0-7yr | backup-T0 | backup-T1 | backup-T2 | error-90d | indefinite — see ADR-0049 D3"
        }
      ]
    }
  },
  "nodes": {}
}
```

2. Leave `nodes` as `{}`. The per-Node entries land in packet 09 after backfill (packets 07, 08). The redactor-integration packets (04, 05) read this file at composition time to confirm structure but do not populate entries.

3. Document the file in `catalogs/README.md` (or the closest equivalent — if no top-level README exists for the catalogs directory, add a short header section to the file itself explaining schema and reconciliation). Cross-link to `catalogs/contracts.json` (the per-Node contract surface) and `catalogs/relationships.json` (the per-Node dependency edges) so the operator can pivot between the three.

4. Do NOT modify `catalogs/nodes.json`, `catalogs/contracts.json`, or `catalogs/relationships.json` in this packet. The catalog augmentation for per-contract classification annotations (ADR-0049 D11: "`catalogs/contracts.json` gains classification annotations on contracts") lands in packet 09 alongside the per-Node population, so the two changes land coherently.

## Affected Files
- `catalogs/data-classification.json` (new)
- `catalogs/README.md` (or equivalent index — small additions only)

## NuGet Dependencies
None. This packet touches only catalog JSON / Markdown; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Schema only; no Node-level entries — those land in packet 09.

## Acceptance Criteria
- [ ] `catalogs/data-classification.json` exists with `version`, `generated_at`, `description`, a `schema` block documenting the `node_entry` shape, and an empty `nodes` object
- [ ] The `schema` block enumerates all four `DataClass` values, all three `PiiCategory` values, and the `retention_class` shorthand keys covering the ADR-0049 D3 retention schedule rows
- [ ] `catalogs/README.md` (or the closest catalog index) documents the new file's purpose, schema, and the nightly `hive-sync` reconciliation cadence
- [ ] `catalogs/nodes.json` is NOT modified (per-Node classification context lives in the new file, not nodes.json)
- [ ] `catalogs/contracts.json` is NOT modified in this packet (contract-level classification annotations land in packet 09)
- [ ] `catalogs/relationships.json` is NOT modified in this packet
- [ ] The JSON validates against any existing JSON-validation step in the repo's CI

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0049 D9 — Inventory artifact `catalogs/data-classification.json`.** Per-Node summary of contracts, audit-emit shapes, API surfaces, and persisted stores that carry classified data. Schema fields: `highest_classification`, `pii_categories`, `sensitive_pii`, `contracts[]` (each with `name`, `request_class`, `fields[]`), `stores[]` (each with `name`, `class`, `retention_class`). Reconciled nightly by `hive-sync` against source-code `[Classification]`/`[PiiField]` attributes; drift is a finding.

**ADR-0049 D3 — Retention schedule.** The catalog's `retention_class` field references the ADR-0049 D3 table: telemetry-traces/logs/errors 90 days; metrics 93 days; Audit-sourced logs 730 days; audit records 730 days minimum / T0 7 years; tenant operational data indefinite while tenant active + 90 days grace; Restricted PII deleted within 30 days of erasure; backups T0/T1/T2 per ADR-0036 D2; restore-drill logs 7 years; `generated/incidents/` indefinite.

**ADR-0049 D11 — Affected Nodes.** "`HoneyDrunk.Architecture` — `catalogs/data-classification.json` added; `catalogs/contracts.json` gains classification annotations on contracts; `constitution/invariants.md` amends Invariant 47 to reference this ADR." The contracts-catalog annotation lands with the per-Node population in packet 09.

## Constraints
- **Schema only, no Node-level entries.** Packet 09 owns the population pass. Putting entries here would conflict with packet 09 and force a re-edit.
- **No edits to other catalog files in this packet.** `nodes.json`, `contracts.json`, `relationships.json` stay untouched; their data-classification-related changes (if any) land in packet 09.
- **`retention_class` shorthand must cover all of ADR-0049 D3's rows.** The schema documents the legal values; the full retention number is cross-referenced via the ADR-0049 D3 table, not duplicated in the catalog.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0049`, `wave-1`

## Agent Handoff

**Objective:** Create the `catalogs/data-classification.json` schema and seed an empty inventory; document the file in the catalog index.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the catalog structure so downstream packets can reference a real file without inventing format.
- Feature: ADR-0049 Data Classification rollout, Wave 1.
- ADRs: ADR-0049 D9 (primary), ADR-0014 (hive-sync reconciliation pattern).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0049 Accepted before its catalog artifact is created.

**Constraints:**
- Schema only — empty `nodes` object. Per-Node population is packet 09.
- Do not modify `nodes.json` / `contracts.json` / `relationships.json` here.

**Key Files:**
- `catalogs/data-classification.json` (new).
- `catalogs/README.md` or closest catalog index (small documentation addition).

**Contracts:** None changed.
