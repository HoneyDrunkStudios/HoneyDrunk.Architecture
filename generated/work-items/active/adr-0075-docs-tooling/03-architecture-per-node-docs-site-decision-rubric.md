---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "meta", "docs", "adr-0075", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0075"]
accepts: ["ADR-0075"]
wave: 3
initiative: adr-0075-docs-tooling
node: honeydrunk-architecture
---

# Author the per-Node docs-site decision rubric addendum

## Summary
Author the per-Node docs-site decision rubric — the operator-facing doc that answers "when does a Node warrant a standalone Docusaurus site versus when is the Architecture-repo `overview.md` enough?" — per ADR-0075's Follow-up Work item: "Per-Node docs-site decision rubric documented in a future addendum (when does a Node warrant Docusaurus vs. when is overview.md enough)." This addendum lives in the Architecture repo and is consulted at the moment a Node-owner (operator or AI agent) asks "should this Node have a docs site?"

## Context
ADR-0075 D2 commits Docusaurus as the canonical standalone-docs-site SSG **but explicitly does not commit it for every Node**. The default per-Node docs surface is `overview.md`/`boundaries.md`/`invariants.md` in `HoneyDrunk.Architecture/repos/{node}/`. The ADR enumerates three "warranted when" criteria:

- A Node has external developer consumers (Notify Cloud's external tenants is the canonical case).
- A Node has a public conceptual surface that overflows `overview.md` (e.g., a hypothetical `HoneyDrunk.Search` Node with multiple provider backings might warrant a docs site to explain the trade-offs).
- An operator-time-saving threshold is hit — repeated questions about a Node from outside the operator suggest a docs site would pay back the build cost.

But the ADR does not enumerate the **decision procedure** — the questions the operator or AI agent should ask, the evidence to look for, the default answer, the escape clauses. That is the addendum's job.

The rubric is a thin, decision-shaped document — not a long-form essay. Solo-developer scale means the operator (or scope agent) reads it in under a minute when triaging a "should this Node have docs?" question. The right shape: a short intro committing to "default is no docs site"; a numbered yes/no checklist that resolves the question; an explicit list of currently-warranted Nodes (Notify Cloud once external developers exist; everyone else: no); and a pointer to the dispatch-plan note about Notify Cloud being the canonical first Docusaurus consumer.

**Repo-shape ground truth.**
- The Architecture repo carries per-Node folders under `repos/{node}/` — each has `overview.md` (always), and typically `boundaries.md`, `integration-points.md`, `invariants.md`. This **is** the default per-Node docs surface per ADR-0075 D2.
- The Architecture repo has `constitution/` for grid-wide conventions, `adrs/` for ADRs, `initiatives/` for in-progress work, `business/context/` for operator-facing notes. The addendum is a Grid-wide convention (it tells the Node-owner how to decide), and the strong default location is **`constitution/`** alongside `naming-conventions.md`, `terminology.md`, and the docs-tooling convention note from packet 01.
- ADR-0008 covers initiative/packet conventions and is **not** where the rubric lives — the rubric is operational, not initiative-shaped.

**The addendum's content (verbatim-in-substance from ADR-0075's "Why not on every Node" paragraph, structured as a decision rubric):**

1. **Default answer: no docs site.** Per-Node `overview.md`/`boundaries.md`/`invariants.md` in this repo is the canonical Node docs. Most Nodes do not need a Docusaurus site. The decision to add one is opt-in and operator-evidenced.
2. **Decision checklist — does this Node warrant a docs site?** Yes if any of the following is true:
   - **External developer consumers exist or are imminent.** External-to-the-operator developers consume this Node's API and need conceptual + reference docs (Notify Cloud's tenant developers is the canonical case; an SDK-consuming partner is another).
   - **The public conceptual surface overflows `overview.md`.** The Node has explainer content (multi-provider trade-offs, schema-evolution guidance, conceptual model walkthroughs) that doesn't fit cleanly in a per-section Markdown file. Length is a symptom, not a criterion — concision in `overview.md` is the first thing to try.
   - **The operator-time-saving threshold is hit.** The operator (or an AI agent operating on the Node's behalf) is answering the same questions about this Node repeatedly to people outside the operator. The pay-back calculus: a docs site costs hours, ongoing maintenance is small with the shared `@honeydrunk/docs-preset`; if the alternative is the operator answering the same question every week, the build-cost amortizes within months.
3. **Decision is reversible.** A Node can stand up a docs site and tear it down if it stops paying back. A Node can also rely on `overview.md` indefinitely and add a docs site later. The cutover cost is bounded.
4. **Currently-warranted Nodes (as of ADR-0075 acceptance).** Notify Cloud (per ADR-0027) is the only Node currently flagged as a likely first Docusaurus consumer — sequenced with first paying tenant or first integrator-developer signup. The decision lives at the per-Node moment, not in this rubric.
5. **Pointers.** Once a Node passes the rubric: consume `@honeydrunk/docs-preset` (packet 04 of this initiative — currently parked behind Web.UI Node standup per ADR-0071); deploy via the docs-deploy reusable workflow (packet 05 of this initiative, targeting Cloudflare Pages per ADR-0029); cite ADR-0075 D2 in the per-Node docs-site standup packet.

The addendum cross-references the ADR-0075 dispatch plan's "Deferred Items — Notify Cloud docs site" entry. The pointer is informational; this addendum does not file a packet.

This is a docs-only packet. No code, no .NET project, no catalog edit.

## Scope
- Author a new addendum file at the Grid's established location for cross-cutting conventions — the strong default: `constitution/per-node-docs-site-rubric.md`, matching the file-naming convention of `constitution/naming-conventions.md` and the docs-tooling convention note from packet 01.
- Cross-link the addendum from:
  - The `adr-0075-docs-tooling` entry in `initiatives/active-initiatives.md` (when this initiative's tracking entry exists per packet 00).
  - The docs-tooling convention note from packet 01 (if landed by then), so a reader of the convention note can navigate to the decision rubric.
  - Optionally, ADR-0075 itself via a "Follow-up addendum:" footnote — only if the ADR-amendment convention supports it. ADRs are normally immutable post-acceptance; if the convention permits a single trailing pointer, add it; otherwise skip the ADR-side cross-link.

## Proposed Implementation
1. **Audit** `constitution/` for existing rubric/decision documents — `naming-conventions.md`, `terminology.md`, `sector-interaction-map.md` show the file conventions. Match the format and section style.
2. **Create** `constitution/per-node-docs-site-rubric.md` with sections:
   - **Default** (the "no docs site by default" stance, citing ADR-0075 D2)
   - **Decision checklist** (the three "warranted when" criteria with concrete operator-evidenced framing)
   - **Reversibility** (a Node can add or remove a docs site over time; the cutover cost is bounded)
   - **Currently-warranted Nodes** (Notify Cloud as the canonical first consumer; everyone else: no)
   - **Pointers** (preset packet 04, deploy workflow packet 05, hosting per ADR-0029)
3. **Cite ADR-0075** as the governing decision. Cite ADR-0027 for the Notify Cloud reference. Cite ADR-0029 for the Cloudflare Pages hosting target.
4. **Cross-link** from:
   - `initiatives/active-initiatives.md` `adr-0075-docs-tooling` entry (the link goes in the entry's Description or Exit criteria).
   - Packet 01's docs-tooling convention note (if landed by then).
5. **Do not** edit ADRs (immutable post-acceptance) unless the established convention permits a single trailing "Follow-up addendum:" pointer. Skip the ADR edit if uncertain.
6. **No catalog edit.** This is a `constitution/`-level convention; no `catalogs/*.json` schema represents decision rubrics.

## Affected Files
- `constitution/per-node-docs-site-rubric.md` (new)
- `initiatives/active-initiatives.md` (cross-link in the initiative entry, if the entry exists per packet 00)
- Optional: `constitution/docs-tooling.md` (cross-link from packet 01's convention note, if landed)

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No invariant change — this is a decision rubric, not a Grid-wide rule.

## Acceptance Criteria
- [ ] `constitution/per-node-docs-site-rubric.md` (or the established-convention equivalent location) exists with the five sections: Default, Decision checklist, Reversibility, Currently-warranted Nodes (Notify Cloud), Pointers
- [ ] The rubric's "default is no docs site" stance is explicit and load-bearing — most Nodes do not get a Docusaurus site
- [ ] The three "warranted when" criteria from ADR-0075 D2 are recorded verbatim-in-substance (external developer consumers; overflow of `overview.md`; operator-time-saving threshold)
- [ ] Notify Cloud (per ADR-0027) is named as the canonical currently-warranted Node, sequenced with first paying tenant or first integrator-developer signup
- [ ] Pointers to packet 04 (`@honeydrunk/docs-preset`) and packet 05 (docs-deploy workflow) and ADR-0029 (Cloudflare Pages hosting) are present
- [ ] ADR-0075 is cited as the governing decision
- [ ] Cross-linked from the `adr-0075-docs-tooling` entry in `initiatives/active-initiatives.md` and/or packet 01's docs-tooling convention note
- [ ] `constitution/invariants.md` is **not** edited (ADR-0075 commits zero new invariants; this packet adds none either)
- [ ] No catalog schema change

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0075 D2 — Docusaurus is the canonical public documentation site generator, used when a Node warrants its own doc site.** The three "warranted when" criteria are: external developer consumers exist; public conceptual surface overflows `overview.md`; operator-time-saving threshold is hit. Default per-Node docs are `overview.md`/`boundaries.md`/`invariants.md` in the Architecture repo. Most Nodes do not have a doc site.

**ADR-0075 Follow-up Work — Per-Node docs-site decision rubric documented in a future addendum.** This packet is that addendum.

**ADR-0027 — Notify Cloud.** Names the canonical first Docusaurus consumer when external-developer demand justifies. The rubric records Notify Cloud as the currently-warranted example.

**ADR-0029 — Cloudflare DNS and edge platform.** Cloudflare Pages is the strong default for the per-Node docs-site hosting target.

**ADR-0071 — Web.UI Node.** The shared `@honeydrunk/docs-preset` (packet 04) consumes Web.UI tokens for cross-Node visual coherence. The rubric pointers reference both the preset and the Web.UI tokens dependency.

## Constraints
- **Default is no docs site.** The rubric must commit to this stance explicitly. Per-Node `overview.md` in the Architecture repo is the canonical Node docs. A Docusaurus site is opt-in and operator-evidenced.
- **Concision before docs-site.** If `overview.md` is becoming unwieldy, the first response is concision in `overview.md`, not standing up a docs site. The rubric should not lower the bar.
- **No invariant change.** ADR-0075 commits zero new invariants; this rubric is a `constitution/`-level convention, not a numbered invariant.
- **Do not edit ADRs.** ADRs are immutable post-acceptance. Cross-link from `initiatives/` or `constitution/`, not from inside the ADR file. (If the established convention supports a single trailing "Follow-up addendum:" pointer in the ADR, that is the only ADR edit permitted; skip if uncertain.)

## Labels
`feature`, `tier-3`, `meta`, `docs`, `adr-0075`, `wave-3`

## Agent Handoff

**Objective:** Author the per-Node docs-site decision rubric — the operator-facing decision procedure for "should this Node have a Docusaurus docs site?"

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: When a Node-owner asks "should I build docs for this Node?", the rubric answers in under a minute. Default is no; the three "warranted when" criteria carve the exception space.
- Feature: ADR-0075 Documentation Tooling rollout, Wave 3.
- ADRs: ADR-0075 D2 (primary), ADR-0027 (Notify Cloud reference), ADR-0029 (Cloudflare Pages), ADR-0071 (Web.UI preset).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0075 should be Accepted before its addendum is authored.

**Constraints:**
- Default is no docs site — explicit and load-bearing.
- Concision in `overview.md` is the first response to overflow, not a docs site.
- No invariant added; ADR-0075 commits zero invariants.
- Do not edit ADR-0075 itself (ADRs immutable post-acceptance) — cross-link from `initiatives/` and `constitution/`.

**Key Files:**
- `constitution/per-node-docs-site-rubric.md` (new — strong default location)
- `initiatives/active-initiatives.md` (cross-link in the `adr-0075-docs-tooling` entry)
- Optionally `constitution/docs-tooling.md` (cross-link from packet 01)

**Contracts:** None — pure governance/operational doc.
