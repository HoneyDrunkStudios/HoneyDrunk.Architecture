---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0054", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0054", "ADR-0036"]
accepts: ["ADR-0054"]
wave: 1
initiative: adr-0054-incident-response
node: honeydrunk-architecture
---

# Register the incident-record contract and the per-Node runbook convention in the Grid catalogs

## Summary
Record ADR-0054's structural commitments as catalog data: formalize `generated/incidents/` as a contract with the D7 front-matter schema documented, add `repos/{node}/runbooks/` as a per-Node directory convention, and add a `runbook_compliance` field to `catalogs/contracts.json` (or the closest existing per-Node compliance surface) so the minimum-set invariant is observable from the catalog.

## Context
ADR-0054 makes two structural commitments that land in the Architecture repo as catalog/convention data:

- **`generated/incidents/` formalized as a contract.** ADR-0054's Affected Nodes: "`HoneyDrunk.Architecture` — `generated/incidents/` formalized as a contract (D7 template)." The directory already exists and is referenced by `CLAUDE.md`, but no schema bound it. This packet registers the D7 template's required front-matter (incident_id, severity, status, opened_at, acknowledged_at, investigating_at, mitigating_at, resolved_at, reviewing_at, closed_at, customer_impact, affected_tenants, affected_nodes, alert_sources, mtta_minutes, mtmitigate_minutes, mttr_minutes, post_mortem_required, post_mortem_link) as the contract.
- **`repos/{node}/runbooks/` as a per-Node convention.** ADR-0054 D10: "Per-Node runbooks live in `repos/{node}/runbooks/`. This convention is added by this ADR." The convention is added here so the catalog can observe per-Node compliance.
- **`catalogs/contracts.json` gains a runbook-compliance field per Node.** ADR-0054's Affected Nodes: "`catalogs/contracts.json` gains a 'runbook compliance' field per Node." Match the existing per-Node convention in `contracts.json` at edit time — if the catalog tracks per-Node compliance fields, add `runbook_compliance` to each Node entry; if a separate compliance/observability surface (`grid-health.json` or similar) is the established place, add it there. Read the catalog ground truth before editing.

**Catalog schema ground truth — read before editing.**
- `catalogs/contracts.json` has the shape `{_meta, contracts:[{node, node_name, package, status, interfaces:[...]}]}` per the sibling ADR-0045 packet's notes — no compliance field currently exists. The "runbook compliance" addition must match whatever convention the catalog uses for per-Node metadata at edit time (it may be that `contracts.json` is the wrong file and `grid-health.json` or a new `runbook_compliance.json` is the right home — match the convention, do not invent a parallel structure).
- `catalogs/grid-health.json` node entries carry `signal`/`version`/`canary_status`/`last_release`/`active_blockers`/`notes`. If the runbook-compliance field is best expressed as a node-status indicator, `grid-health.json` is the right home; record the choice in the PR.
- `catalogs/nodes.json` has no `exposes` field; this packet does not touch it.

**No new App resource.** This packet adds no Azure resource; it is pure catalog/convention work.

This is a docs/catalog packet. No code, no .NET project.

## Scope
- A formal contract registration for the `generated/incidents/` directory and the D7 front-matter schema — recorded in the location the Grid uses for catalog contracts (likely a new entry in `catalogs/contracts.json` under the `honeydrunk-architecture` Node, or a separate schema doc — match the existing convention).
- A per-Node convention note for `repos/{node}/runbooks/` — recorded where the Grid documents per-Node directory conventions (likely a new section in the Architecture repo's `repos/` README or each Node's `boundaries.md` reference; match the existing convention).
- A `runbook_compliance` field per Node in the appropriate catalog file (`contracts.json` or `grid-health.json` — match the existing per-Node compliance/metadata convention at edit time).

## Proposed Implementation
1. **`generated/incidents/` contract registration.** Register the directory and its D7 front-matter schema as a contract. The simplest expression: add a new entry to `catalogs/contracts.json` under the `honeydrunk-architecture` Node listing `generated/incidents/` as a documented surface with the D7 front-matter as the schema. Field set per the D7 template: `incident_id`, `severity` (enum: SEV-1/SEV-2/SEV-3/SEV-4), `status` (enum matching the D6 lifecycle states), the seven lifecycle timestamps, `customer_impact` (bool), `affected_tenants` (string list), `affected_nodes` (string list), `alert_sources` (string list), `mtta_minutes` / `mtmitigate_minutes` / `mttr_minutes` (int), `post_mortem_required` (bool), `post_mortem_link` (string). Mark the contract status `planned` if the catalog tracks status; flip to `live` once packet 02 lands the template files. The contract description states: "Every paying-tenant-impacting incident (SEV-1/SEV-2) produces a record at `generated/incidents/YYYY-MM-DD-<slug>.md` with this front-matter."
2. **`repos/{node}/runbooks/` convention.** Add a per-Node convention note. The simplest expression: a section in the Architecture repo's `repos/README.md` (or the equivalent index that documents per-Node directory conventions) naming `runbooks/` as the per-Node runbook directory, with the minimum file set from D10 (`restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md`, plus `escalation.md` for Tier 0 Nodes per ADR-0036) and a one-line description of each file's purpose. Cross-reference D10's freshness rule (a runbook older than 90 days untouched is flagged in the nightly `hive-sync` report).
3. **`runbook_compliance` field per Node.** Add a per-Node compliance field that records whether the Node carries the minimum runbook set. Match the existing convention at edit time:
   - If `catalogs/contracts.json` tracks per-Node compliance, extend each Node's entry with `runbook_compliance: { restart: bool, rollback: bool, health_check: bool, common_sev2_patterns: bool, escalation: bool, all_present: bool }`.
   - Else if `catalogs/grid-health.json` tracks per-Node operational metadata, add the field there.
   - Else create a new catalog file `catalogs/runbook-compliance.json` and document why a separate file was the right choice.
   For the initial population, mark every deployable Node as `all_present: false` until the playbook (packet 10) and per-Node fanout fills in the runbooks. Tier-0 Nodes (Vault, Audit, Notify Cloud per ADR-0036) require all five files; Tier-1 / Tier-2 deployable Nodes require the four non-escalation files; library-only Nodes (Kernel, Vault, Transport per invariant 17 / ADR-0005 — i.e., Nodes with no deployable surface) are exempt and marked `not_applicable: true`.
4. **No D7/D8 template file creation here.** The concrete template markdown files (`generated/incidents/_templates/incident-record.md`, `generated/incidents/_templates/post-mortem.md`) land in packet 02 — this packet only registers the schema, not the files.
5. **No runbook content created here.** Per-Node runbooks land via packet 10's playbook and subsequent per-Node fanout. This packet registers the convention only.

## Affected Files
- `catalogs/contracts.json` (or `grid-health.json` or new `runbook-compliance.json` — match convention) — the `generated/incidents/` contract entry and the per-Node `runbook_compliance` field.
- `repos/README.md` (or the equivalent index that documents per-Node directory conventions) — the `runbooks/` convention note.

## NuGet Dependencies
None. This packet touches only catalog JSON and Markdown; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data only — the template files land in packet 02; the runbook content lands via packet 10 and follow-on per-Node fanout.

## Acceptance Criteria
- [ ] `generated/incidents/` is registered as a contract in the appropriate catalog file (likely `catalogs/contracts.json` under the `honeydrunk-architecture` Node) with the D7 front-matter schema fully enumerated and the contract description referencing the SEV-1/2 invariant from packet 00
- [ ] `repos/{node}/runbooks/` is documented as a per-Node directory convention with the minimum file set from D10 (`restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md`; `escalation.md` additionally for Tier 0 Nodes per ADR-0036), each file's purpose described in one line
- [ ] A `runbook_compliance` field is added per Node in the appropriate catalog file (matching existing per-Node compliance/metadata convention at edit time); the choice of file is documented in the PR
- [ ] Every deployable Node is initially populated `all_present: false`; library-only / non-deployable Nodes are marked `not_applicable: true`
- [ ] No template file is added in this packet (those land in packet 02)
- [ ] No runbook content is added in this packet (those land via packet 10 and follow-on per-Node fanout)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0054 D7 — Incident record template.** Every incident produces a markdown file at `generated/incidents/YYYY-MM-DD-<slug>.md` with the full front-matter (incident_id, severity, status, the seven lifecycle timestamps, customer_impact, affected_tenants, affected_nodes, alert_sources, mtta/mtmitigate/mttr minutes, post_mortem_required, post_mortem_link). The template is the contract; the directory `generated/incidents/` is the surface. The schema is **machine-readable** because `hive-sync` consumes it for the rolling MTTA/MTTR dashboard and the incident-volume report.

**ADR-0054 D10 — Per-Node runbooks at `repos/{node}/runbooks/`.** Minimum file set: `restart.md`, `rollback.md`, `health-check.md`, `common-sev2-patterns.md` for every deployable Node; `escalation.md` additionally for Tier 0 Nodes per ADR-0036. A runbook older than 90 days untouched is flagged in the nightly `hive-sync` report.

**ADR-0054 Affected Nodes — Architecture commitments.** "`HoneyDrunk.Architecture` — `generated/incidents/` formalized as a contract (D7 template). `repos/{node}/runbooks/` directory added per D10. `catalogs/contracts.json` gains a 'runbook compliance' field per Node."

**ADR-0036 — Tier classification.** Tier-0 Nodes (Vault, Audit, Notify Cloud tenant data) carry the additional `escalation.md` requirement per ADR-0054 D10. The packet's per-Node initial population follows the ADR-0036 tier mapping.

## Constraints
- **Match existing catalog convention.** Do not invent a parallel structure. If `contracts.json` is the established home for per-Node compliance, extend it there; if `grid-health.json` is, extend it there; if neither, create a separate file and document the choice.
- **No template files in this packet.** The D7 incident-record and D8 post-mortem template files land in packet 02; this packet registers the schema only.
- **No runbook content in this packet.** Per-Node runbooks land via packet 10 and follow-on per-Node fanout.
- **Library-only Nodes are exempt.** Kernel, Vault (the abstraction package — not the deployable), Transport, Architecture, Standards are library-only and marked `not_applicable: true`. Deployable Nodes (Vault.Rotation, Notify, Communications, Pulse, Audit, Notify Cloud, etc.) carry the requirement.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0054`, `wave-1`

## Agent Handoff

**Objective:** Register `generated/incidents/` as a contract with the D7 front-matter schema, document `repos/{node}/runbooks/` as a per-Node convention, and add a `runbook_compliance` field per Node in the appropriate catalog file.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the D7 schema and the D10 runbook convention catalog-observable so `hive-sync` and the per-Node compliance gates can act on them.
- Feature: ADR-0054 Incident Response rollout, Wave 1.
- ADRs: ADR-0054 D7/D10 (primary), ADR-0036 (tier mapping).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0054 should be Accepted before its catalog commitments land.

**Constraints:**
- Match existing catalog convention; do not invent a parallel structure.
- No template files in this packet (packet 02 owns them).
- No runbook content in this packet (packet 10 owns the playbook).
- Library-only Nodes are exempt and marked `not_applicable: true`.

**Key Files:**
- `catalogs/contracts.json` (and/or `grid-health.json`, depending on which file matches the existing convention for per-Node compliance metadata)
- `repos/README.md` (or the equivalent per-Node convention index)

**Contracts:** `generated/incidents/` registered as a contract; `runbook_compliance` field added per Node.
