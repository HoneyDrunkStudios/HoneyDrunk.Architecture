---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "adr-0044", "wave-3"]
dependencies: ["packet:01"]
adrs: ["ADR-0044", "ADR-0030", "ADR-0031", "ADR-0035", "ADR-0037"]
accepts: ["ADR-0044"]
wave: 3
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Add the review_risk_class field to catalogs/grid-health.json

## Summary
Add a new `review_risk_class` field to the per-Node entries in `catalogs/grid-health.json` and populate it, so the cloud reviewer can auto-detect high-risk-Node touches and trigger D8's multi-perspective review without amending the ADR each time the high-risk list changes.

## Context
ADR-0044 D8 requires a non-`human` PR touching a high-risk Node to receive two independent LLM-review perspectives before merge. The ADR deliberately keeps the catalog of high-risk Nodes in `catalogs/grid-health.json` under a new `review_risk_class` field "so the list evolves with the Grid without amending this ADR." This is the data dependency Phase 3 (D8 activation, packet 14) is gated on — `job-review-agent.yml` reads this field to decide whether to escalate to Opus + a contrarian second pass. This packet adds and populates the field; packet 14 wires the workflow to consume it.

## Scope
- `catalogs/grid-health.json` — add `review_risk_class` to every Node entry and populate.
- The `grid-health.json` schema doc/README if one exists — document the new field.

## Proposed Implementation
Add `review_risk_class` to each Node entry. Values:
- **`high`** — the Node (or the specific touch) is high-risk per ADR-0044 D8.
- **`standard`** — default; no multi-perspective requirement.

ADR-0044 D8 names the high-risk Nodes and their trigger conditions — the field should capture enough for the workflow to make the call:
- **HoneyDrunk.Kernel** — high-risk on any change to `*.Abstractions` (ADR-0035 ABI cascade).
- **HoneyDrunk.Vault** — high-risk on any change to secret handling, bootstrap, or rotation.
- **HoneyDrunk.Auth** — high-risk on any change to token validation, principal resolution, or the Audit emit boundary (ADR-0031).
- **HoneyDrunk.Audit** — high-risk on any change to the append-only-by-interface guarantee (ADR-0030 Phase 1).
- **HoneyDrunk.Billing** — high-risk on any change (when the Node stands up per ADR-0037; not yet in `nodes.json` — note it as a forward entry, do not fabricate a Node row).
- **Any `.Cloud` revenue Node** (per ADR-0027 D2) — high-risk on any change.

Because some triggers are *path-scoped* (Kernel only on `*.Abstractions`, Vault only on secret-handling paths), a simple `high`/`standard` enum at the Node level is insufficient. Use a small object so the workflow can evaluate path conditions:

```json
"review_risk_class": {
  "class": "high",
  "trigger": "path",
  "high_risk_paths": ["**/*.Abstractions/**"],
  "rationale": "ADR-0035 ABI cascade — Abstractions changes ripple Grid-wide"
}
```
For Nodes that are high-risk on *any* change, use `"trigger": "any"` and omit `high_risk_paths`. For standard Nodes, `"class": "standard"`.

**Schema-alignment check (verified at scoping time, 2026-05-22).** A real `catalogs/grid-health.json` Node entry currently carries flat scalar fields (`id`, `name`, `sector`, `signal`, `version`, `canary_status`, `last_release`, `notes`) plus one array field (`active_blockers`). The file has `schema_version: "1.0"` in its `_meta` block and uses `snake_case` keys throughout. The `review_risk_class` object proposed here is consistent with that style: `snake_case` keys, additive, sitting alongside the existing per-Node fields. It is the **first nested-object field** in a per-Node entry, so the execution agent must (a) bump `_meta.schema_version` (e.g. to `1.1`) since a structural field is added, and (b) confirm no `grid-health.json`-reading tooling assumes a flat-only Node shape before landing. Keep the key style `snake_case` and the object minimal; do not restructure existing fields.

## Affected Files
- `catalogs/grid-health.json`
- the `grid-health.json` schema doc/README, if present

## NuGet Dependencies
None. This packet edits a JSON catalog; no .NET project is created or modified.

## Boundary Check
- [x] `catalogs/grid-health.json` lives in `HoneyDrunk.Architecture` — correct repo.
- [x] Additive field — existing tooling that reads `grid-health.json` for other fields is unaffected.

## Acceptance Criteria
- [ ] Every Node entry in `catalogs/grid-health.json` carries a `review_risk_class` value
- [ ] The six high-risk Nodes from ADR-0044 D8 are marked appropriately, with path-scoped triggers where the ADR specifies them (Kernel `*.Abstractions`, Vault secret-handling, Auth token/principal/Audit-boundary)
- [ ] Nodes that are high-risk on any change use `"trigger": "any"`; standard Nodes use `"class": "standard"`
- [ ] HoneyDrunk.Billing is noted as a forward high-risk entry without fabricating a Node row (it is not yet in `nodes.json`)
- [ ] The field shape is consistent with the existing `grid-health.json` conventions (`snake_case` keys; additive; existing fields untouched)
- [ ] `_meta.schema_version` is bumped (it is currently `1.0`) since a nested-object field is structurally new
- [ ] The schema doc/README documents the new field if such a doc exists
- [ ] The change is additive — no existing field altered

## Human Prerequisites
None. Pure Architecture-repo catalog edit.

## Dependencies
- `packet:01` — ADR-0044 acceptance (soft; D8 is a live binding once ADR-0044 is Accepted).

## Referenced ADR Decisions

**ADR-0044 D8** — High-risk Nodes (Kernel `*.Abstractions`, Vault secret handling, Auth token/principal/Audit-boundary, Audit append-only guarantee, Billing any change, any `.Cloud` revenue Node any change). The catalog of high-risk Nodes lives in `catalogs/grid-health.json` under `review_risk_class` so the list evolves without amending the ADR. The workflow auto-detects high-risk touches and escalates to Opus + a contrarian second pass.
**ADR-0030** — Audit append-only-by-interface guarantee (Phase 1).
**ADR-0031** — Auth/Audit emit boundary.
**ADR-0035** — `*.Abstractions` ABI cascade rules.
**ADR-0037** — HoneyDrunk.Billing Node (Proposed; not yet standing up).

## Constraints
- **Additive only.** Do not alter existing `grid-health.json` fields.
- **Do not fabricate a Billing Node row.** Billing is not in `nodes.json` yet; note it as a forward entry only.
- Match the existing `grid-health.json` field-style conventions.

## Labels
`docs`, `tier-2`, `meta`, `adr-0044`, `wave-3`

## Agent Handoff

**Objective:** Add and populate the `review_risk_class` field in `catalogs/grid-health.json` per ADR-0044 D8.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Provide the data the cloud reviewer reads to decide D8 multi-perspective escalation. Phase 3 (packet 14) is gated on this field.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 3.
- ADRs: ADR-0044 (D8), ADR-0030, ADR-0031, ADR-0035, ADR-0037.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0044 acceptance (soft).

**Constraints:**
- Additive only; no Billing Node fabrication; match existing field conventions.

**Key Files:**
- `catalogs/grid-health.json`

**Contracts:** Defines the `review_risk_class` field consumed by `job-review-agent.yml` (packet 14).
