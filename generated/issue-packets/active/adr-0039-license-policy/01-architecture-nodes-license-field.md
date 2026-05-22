---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0039", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0039", "ADR-0027"]
accepts: ["ADR-0039"]
wave: 1
initiative: adr-0039-license-policy
node: honeydrunk-architecture
---

# Extend catalogs/nodes.json with `license` and `visibility` fields and backfill every Node (ADR-0039 D8)

## Summary
Add two new fields to every Node object in `catalogs/nodes.json`: a `license` field carrying the SPDX license expression for that Node (`MIT`, `FSL-1.1-MIT`, or `proprietary`) per ADR-0039 D8, and a `visibility` field (`public` | `private`) recording whether the repo is publicly licensed/open or proprietary/closed. Backfill all current entries, and document the fields in the catalog schema so `hive-sync` (packet 06) and ADR-0034's `Directory.Build.props` default can derive from them.

**Both `license` and `visibility` are genuine new additions to the `nodes.json` node-object schema** — verified: today no node entry carries either field (current keys: `id, type, name, public_name, short, description, sector, signal, cluster, energy, priority, flow, tags, links, long_description, foundational, strategy_base, tier, time_pressure, done, cooldown_days`). `catalogs/nodes.json` is a top-level JSON array with no `_meta`/`schema_version` block, so there is no schema-version key to bump — if a future refactor introduces one, that is out of this packet's scope.

## Context
ADR-0039 D8 makes `catalogs/nodes.json` the single source of truth for each Node's license: "`catalogs/nodes.json` gains a `license` field per Node with the SPDX expression (MIT, FSL-1.1-MIT, proprietary)." Today no `license` field exists — license reality is scattered across each repo's `LICENSE` file with no Grid-level record.

The packet also adds a companion `visibility` field. The public/private split that ADR-0039 relies on (Studios is proprietary/private and excluded; `HoneyDrunk.Notify.Cloud` is private; the open Grid repos are public) is currently asserted only in packet prose with no catalog backing. Adding `visibility` to every node entry lets packet 06's `hive-sync` license-drift check and every future fan-out **derive the public/private split mechanically** rather than re-asserting it in prose. `license` and `visibility` are related but distinct: `proprietary` license implies `private` visibility, but the catalog records both explicitly so a query for "public repos" need not infer it from the license enum.

This packet creates both catalog fields and backfills them, which gives every later packet (the fan-out in packet 05, the `hive-sync` reconciliation in packet 06) a single authoritative source to reconcile against.

This is a docs/catalog-only packet. No code, no workflow, no .NET project.

## Scope
- `catalogs/nodes.json` — add a `license` string field and a `visibility` string field to every node object; backfill all current entries (see Proposed Implementation for the per-Node assignment).
- The catalog schema documentation — if a `catalogs/README.md` or schema doc exists describing the `nodes.json` shape, add the `license` and `visibility` fields to it. If no such doc exists, do not create a new schema doc just for these fields unless the catalog already has one.

## Proposed Implementation
Add a `license` field and a `visibility` field to each node object in `catalogs/nodes.json`.

`license` is one of three SPDX-style expressions:

- `MIT` — the Grid default (ADR-0039 D1).
- `FSL-1.1-MIT` — revenue Nodes (ADR-0039 D2).
- `proprietary` — private Nodes (ADR-0039 D4).

`visibility` is one of two values:

- `public` — the repo is open / publicly licensed (`MIT` or `FSL-1.1-MIT`). FSL is still a public, source-available license, so FSL Nodes are `public`.
- `private` — the repo is closed / proprietary. Every `proprietary`-license Node is `private`.

Per-Node assignment for the **current catalog entries** (cross-check `catalogs/nodes.json` `id` keys):

| Node id | `license` | `visibility` | Rationale |
|---|---|---|---|
| `honeydrunk-kernel` | `MIT` | `public` | D1 default — library Node |
| `honeydrunk-transport` | `MIT` | `public` | D1 default |
| `honeydrunk-vault` | `MIT` | `public` | D1 default |
| `honeydrunk-vault-rotation` | `MIT` | `public` | D1 default |
| `honeydrunk-auth` | `MIT` | `public` | D1 default |
| `honeydrunk-web-rest` | `MIT` | `public` | D1 default |
| `honeydrunk-data` | `MIT` | `public` | D1 default |
| `honeydrunk-audit` | `MIT` | `public` | D1 default |
| `honeydrunk-pulse` | `MIT` | `public` | D1 default |
| `honeydrunk-notify` | `FSL-1.1-MIT` | `public` | Revenue Node — D2, ADR-0027; FSL is source-available/public |
| `honeydrunk-communications` | `FSL-1.1-MIT` | `public` | Revenue Node — D2, ADR-0027; FSL is source-available/public |
| `honeydrunk-actions` | `MIT` | `public` | D1 default — ships workflows, no NuGet packages, but the repo is public and MIT-licensed |
| `honeydrunk-architecture` | `MIT` | `public` | D1 default for code; documentation/content in this repo is CC-BY-4.0 per D7 — see note below |
| `honeydrunk-standards` | `MIT` | `public` | D1 default |
| `honeydrunk-studios` | `proprietary` | `private` | Private marketing site per ADR-0029 / ADR-0039 D7 — not a public license posture |
| `honeydrunk-lore` | `MIT` | `public` | D1 default for code (the Lore wiki content may be CC-BY-4.0 per D7 — see note below) |
| All Seed Nodes (`honeydrunk-ai`, `honeydrunk-capabilities`, `honeydrunk-agents`, `honeydrunk-memory`, `honeydrunk-knowledge`, `honeydrunk-flow`, `honeydrunk-operator`, `honeydrunk-evals`, `honeydrunk-sim`, `honeydrunk-observe`) | `MIT` | `public` | D1 default — these are not-yet-scaffolded library Nodes; none is a designated revenue Node, all are intended public |

If `HoneyDrunk.Notify.Cloud` (ADR-0027, private) is present as a catalog entry, it is `proprietary` / `private`. It is not in the current catalog at scoping time — backfill it only if it exists when this packet runs; otherwise it adopts these fields at its own standup.

**Dual-license note for D7 repos.** ADR-0039 D7 says `HoneyDrunk.Architecture` (and any future documentation surface) licenses *content* under CC-BY-4.0 while *code* in those repos is MIT. The `license` field on `catalogs/nodes.json` records the **code license** — `MIT` for Architecture and Lore. The CC-BY-4.0 content license is recorded by the per-repo `LICENSE`/`LICENSE-docs` file the fan-out packet (05) adds, not by a second catalog field. If the implementing agent judges a second field worthwhile (e.g. `content_license`), flag it in the PR for the developer to decide — do not add it unilaterally; ADR-0039 D8 specifies a single `license` field.

**Studios caveat.** `honeydrunk-studios` is `proprietary`. ADR-0039 D7 explicitly states the Studios marketing site is a separate private/proprietary posture "not addressed here." The catalog still records `proprietary` so the field is complete and `hive-sync` does not flag it as missing — recording it is not the same as ADR-0039 governing it.

Match the JSON style of the existing `catalogs/nodes.json` — two-space indent. Place `license` and `visibility` consistently within each node object (e.g. immediately after `id`, adjacent to each other — pick one position and apply it uniformly).

## Affected Files
- `catalogs/nodes.json`
- the catalog schema doc, if one exists (otherwise none)

## NuGet Dependencies
None. This packet edits a JSON catalog; no .NET project is created or modified.

## Boundary Check
- [x] Catalogs live in `HoneyDrunk.Architecture`. Routing rule "catalog → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] Every node object in `catalogs/nodes.json` has a `license` string field AND a `visibility` string field
- [ ] `license` is exactly one of `MIT`, `FSL-1.1-MIT`, `proprietary` — no other value
- [ ] `visibility` is exactly one of `public`, `private` — no other value
- [ ] `honeydrunk-notify` and `honeydrunk-communications` are `FSL-1.1-MIT` / `public`; `honeydrunk-studios` is `proprietary` / `private`; all other current entries are `MIT` / `public`
- [ ] Every `proprietary`-license node is `private`; no node is both `proprietary` and `public`
- [ ] The JSON remains well-formed and matches the existing two-space-indent catalog style
- [ ] The `license` and `visibility` fields are placed at a consistent position within every node object
- [ ] If a catalog schema doc exists, it documents the new `license` and `visibility` fields; if none exists, no new schema doc is created solely for these fields
- [ ] No third license field (e.g. `content_license`) is added unilaterally — if the agent judges one useful, it is flagged in the PR, not committed

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0039 D8 — License catalog.** "`catalogs/nodes.json` gains a `license` field per Node with the SPDX expression (MIT, FSL-1.1-MIT, proprietary). The catalog is the single source of truth; ADR-0034's `Directory.Build.props` and CI gates derive from it. `hive-sync` (ADR-0014) reconciles the catalog with each repo's actual `LICENSE` file."

**ADR-0039 D1 — Default license: MIT.** Every Grid Node defaults to MIT unless D2 or D3 applies.

**ADR-0039 D2 — Revenue Nodes: FSL-1.1-MIT.** Revenue Nodes license under FSL-1.1-MIT. Current revenue Nodes: `HoneyDrunk.Notify`, `HoneyDrunk.Communications` (both per ADR-0027). `HoneyDrunk.Notify.Cloud` is private (not yet scaffolded — out of this catalog backfill until it exists). `HoneyDrunk.Billing` and consumer-app server Nodes are future.

**ADR-0039 D4 — Private Nodes: proprietary.** Private Nodes carry a short `LICENSE` file stating "All rights reserved. Proprietary to HoneyDrunk Studios LLC."

**ADR-0039 D7 — Documentation and content: CC-BY-4.0.** `HoneyDrunk.Architecture` and future documentation surfaces license *content* under CC-BY-4.0; *code* in those repos is MIT. The Studios marketing site is a separate private/proprietary posture not addressed by ADR-0039.

## Constraints
- **`license` is a closed enum** — exactly `MIT`, `FSL-1.1-MIT`, or `proprietary`. No other value, no free-text.
- **`visibility` is a closed enum** — exactly `public` or `private`. No other value. Every `proprietary` Node is `private`; FSL Nodes are `public` (FSL is source-available).
- **The catalog records the code license.** For D7 dual-license repos (Architecture, Lore), the `license` field is `MIT` (the code license); the CC-BY-4.0 content license is carried by the per-repo `LICENSE`/`LICENSE-docs` file added in packet 05, not a second catalog field — unless the developer decides otherwise on the flagged PR.
- **Backfill is complete** — every node object gets both fields, including all 10 Seed Nodes, so `hive-sync` never reports a missing-field drift.
- This packet does not touch any repo's actual `LICENSE` file — that is the fan-out packet (05). This packet records the *intended* license; packet 05 makes the repos match.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0039`, `wave-1`

## Agent Handoff

**Objective:** Add a `license` field and a `visibility` field to every Node in `catalogs/nodes.json` and backfill both per ADR-0039 D8.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Establish the single-source-of-truth license catalog that the fan-out (packet 05) and `hive-sync` reconciliation (packet 06) read against.
- Feature: ADR-0039 Grid Open Source License Policy rollout, Wave 1.
- ADRs: ADR-0039 (D8, D1, D2, D4, D7), ADR-0027 (FSL precedent for Notify/Communications), ADR-0014 (`hive-sync` reconciliation).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0039 acceptance (soft — references ADR-0039 D8 as a live rule).

**Constraints:**
- `license` is a closed enum: `MIT` / `FSL-1.1-MIT` / `proprietary`. `visibility` is a closed enum: `public` / `private`.
- Both are genuine new schema additions — no node entry carries either today; `nodes.json` has no `_meta`/`schema_version` to bump.
- The `license` field records the code license; D7 content licensing is a per-repo file, not a second catalog field.
- Every `proprietary` Node is `private`; FSL Nodes are `public`.
- Backfill every node object with both fields, including the 10 Seed Nodes.
- Do not touch any repo's actual `LICENSE` file — that is packet 05.

**Key Files:**
- `catalogs/nodes.json`
- the catalog schema doc, if one exists

**Contracts:** Introduces the `license` and `visibility` fields on the `nodes.json` node-object schema. `license` is consumed by `hive-sync` license-drift reconciliation (packet 06) and — per ADR-0034 — the `Directory.Build.props` license default. `visibility` lets packet 06's drift check and future fan-outs derive the public/private repo split mechanically.
