---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "infrastructure", "docs", "adr-0036", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0036"]
accepts: ["ADR-0036"]
wave: 1
initiative: adr-0036-disaster-recovery
node: honeydrunk-architecture
---

# Add the dr_tier field to grid-health.json and backfill every stateful Node (ADR-0036 D1/D9)

## Summary
Add a `dr_tier` field to the `catalogs/grid-health.json` Node schema, document it in the catalog `_meta`, and backfill the tier assignment for every Node that holds durable state per ADR-0036 D1's tier-membership lists. Stateless Nodes get an explicit `dr_tier: null` (or are documented as exempt) so the absence of a tier is never ambiguous.

**This is a new field on the catalog Node schema.** No Node object carries a `dr_tier` field today — this packet adds it. The catalog's `_meta.schema_version` is bumped accordingly. This is an additive schema change, not a value-only backfill of an existing field.

## Context
ADR-0036 D1 assigns every stateful Node to one of three durability tiers (T0/T1/T2) and states the mapping "is recorded in `catalogs/grid-health.json` under a new `dr_tier` field per Node." ADR-0036 D9 lists this field addition under the documentation surface. The new invariant added by packet 00 — "every Node holding state has a `dr_tier` assignment" — is enforced by `hive-sync` (ADR-0014) reading this field; this packet creates the field the invariant references.

This is an Architecture-repo catalog change only. No code, no .NET project.

## Scope
- `catalogs/grid-health.json` — add a `dr_tier` field to every Node object; update `_meta` to document the field and the schema_version bump.

## Proposed Implementation
1. Add a `dr_tier` field to each Node object in `catalogs/grid-health.json`. This field does not exist on the schema today — it is a genuine schema addition, so `_meta.schema_version` must be bumped. Permitted values: `"T0"`, `"T1"`, `"T2"`, or `null` (stateless Node — explicitly not tiered).
2. Backfill values per ADR-0036 D1's tier-membership lists and the Consequences "Affected Nodes" section:
   - **T0:** `honeydrunk-vault` (loss of secrets cascades Grid-wide), `honeydrunk-audit` (regulatory/forensic completeness).
   - **T1:** `honeydrunk-notify` (delivery state — in-flight messages, retry queues), `honeydrunk-memory` (when stood up), `honeydrunk-knowledge` (when stood up).
   - **T2:** `honeydrunk-pulse` (historical signals; current values not durable per ADR-0028), `honeydrunk-flow` (non-customer-facing workflow state, when stood up), `honeydrunk-evals` (historical run data, when stood up).
   - **`null` (stateless — not tiered):** `honeydrunk-kernel`, `honeydrunk-transport`, `honeydrunk-web-rest`, `honeydrunk-communications`, `honeydrunk-actions`, `honeydrunk-architecture`, `honeydrunk-standards`, `honeydrunk-studios`. Per ADR-0036 D1 their DR posture is "redeploy from source" via ADR-0033.
   - **`honeydrunk-data` special case:** ADR-0036 Consequences states Data "doesn't have its own DR tier; its backings inherit from the consuming Node's tier." Set `honeydrunk-data` to `null` and add an inline note (e.g. a sibling `dr_tier_note` field, or a comment in `_meta`) recording the tier-inheritance rule: `Audit.Data → T0, Memory.Data → T1, Pulse.Data → T2`.
   - **Seed Nodes whose DR tier is decided at standup** (`honeydrunk-vault-rotation`, `honeydrunk-observe`, `honeydrunk-ai`, `honeydrunk-agents`, `honeydrunk-capabilities`, `honeydrunk-operator`, `honeydrunk-sim`, `honeydrunk-lore`): ADR-0036 says Memory/Knowledge/Flow's tiers are "decided at standup, recorded in their standup ADR amendments." For a Seed Node that does not yet hold state, set `dr_tier: null` with a note that it is assigned at standup. For `honeydrunk-memory`, `honeydrunk-knowledge`, `honeydrunk-flow` — ADR-0036 D1 already names their intended tiers (T1/T1/T2), so set those values and note "provisional — confirmed at standup."
3. Update `_meta`: bump `schema_version`, refresh `updated`, and document the `dr_tier` field (permitted values, the `null` = stateless/standup-deferred meaning, the Data tier-inheritance rule).

## Affected Files
- `catalogs/grid-health.json`

## NuGet Dependencies
None. This packet touches only a JSON catalog; no .NET project is created or modified.

## Boundary Check
- [x] `catalogs/grid-health.json` lives in `HoneyDrunk.Architecture`. Routing rule "catalog → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency. This is a catalog metadata field, not a runtime contract — `catalogs/contracts.json` is untouched.

## Acceptance Criteria
- [ ] Every Node object in `catalogs/grid-health.json` has a `dr_tier` field with value `T0`, `T1`, `T2`, or `null`
- [ ] Vault and Audit are `T0`; Notify is `T1`; Pulse is `T2` — matching ADR-0036 D1's tier-membership lists
- [ ] Memory and Knowledge are `T1`, Flow and Evals are `T2`, each noted "provisional — confirmed at standup"
- [ ] `honeydrunk-data` is `null` with a recorded tier-inheritance note (`Audit.Data → T0, Memory.Data → T1, Pulse.Data → T2`)
- [ ] Stateless Nodes (Kernel, Transport, Web.Rest, Communications, Actions, Architecture, Standards, Studios) are explicitly `null`
- [ ] `_meta` documents the `dr_tier` field, its permitted values, and the Data tier-inheritance rule; `schema_version` and `updated` are bumped
- [ ] The JSON is valid and the file's existing `summary` block is preserved

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0036 D1 — Three durability tiers.** T0: RPO ≤ 5 min, RTO ≤ 1 hr, geo-redundant with read-access secondary, annual drill + semiannual partial spot-check; members Vault, Audit, Notify Cloud tenant identity & billing. T1: RPO ≤ 1 hr, RTO ≤ 8 hr, geo-redundant passive secondary, semiannual drill; members Notify delivery state, Notify Cloud operational data, Memory, Knowledge. T2: RPO ≤ 24 hr, RTO ≤ 72 hr, LRS, annual drill; members Pulse historical signals, Flow non-customer workflow state, Evals history, internal dev/staging. Stateless Nodes not tiered — "redeploy from source" via ADR-0033.

**ADR-0036 Consequences — Affected Nodes.** Data has no own tier; backings inherit the consuming Node's tier (`Audit.Data → T0, Memory.Data → T1, Pulse.Data → T2`). Memory/Knowledge/Flow tiers are decided at standup, recorded in their standup ADR amendments.

**ADR-0036 D9 — Documentation surface.** A new `dr_tier` field in `catalogs/grid-health.json` is part of the documentation surface.

## Constraints
> **Invariant (added by packet 00) — every Node holding state has a `dr_tier` assignment in `catalogs/grid-health.json`.** A stateful Node with no `dr_tier` is drift. This packet is what makes that invariant satisfiable — every Node object must carry the field after this packet, stateless ones explicitly `null`.

- **Do not invent tiers.** Only `T0`, `T1`, `T2`, `null`. Tier promotion is an ADR amendment (ADR-0036 D8), not a catalog edit.
- **Preserve the existing `grid-health.json` structure** — Node ids, the `summary` block, and all existing fields stay intact; `dr_tier` is purely additive.

## Labels
`feature`, `tier-2`, `infrastructure`, `docs`, `adr-0036`, `wave-1`

## Agent Handoff

**Objective:** Add the `dr_tier` field to `catalogs/grid-health.json` and backfill every Node per ADR-0036 D1.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the packet-00 `dr_tier` invariant satisfiable; give `hive-sync` a field to reconcile.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 1.
- ADRs: ADR-0036 (D1/D9 primary), ADR-0014 (`hive-sync` reads the field), ADR-0028 (Pulse signals not durable — informs Pulse = T2), ADR-0033 (stateless = redeploy-from-source).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. The acceptance flip and the `dr_tier` invariant should land first so this catalog change reads against Accepted ADR text.

**Constraints:**
- Only `T0`/`T1`/`T2`/`null` values.
- Data is `null` + tier-inheritance note.
- Stateless Nodes explicitly `null`.
- Purely additive — preserve all existing fields and the `summary` block.

**Key Files:**
- `catalogs/grid-health.json`

**Contracts:** No runtime contract change — catalog metadata field only. `catalogs/contracts.json` untouched.
