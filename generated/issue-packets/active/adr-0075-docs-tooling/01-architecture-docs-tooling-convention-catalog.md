---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0075", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0075", "ADR-0057", "ADR-0071", "ADR-0029"]
accepts: ["ADR-0075"]
wave: 1
initiative: adr-0075-docs-tooling
node: honeydrunk-architecture
---

# Record the Scalar + Docusaurus tooling convention as a cross-cutting Grid note

## Summary
Record ADR-0075's tooling commitments as a cross-cutting Grid convention note where the Architecture repo keeps such notes — Scalar is the canonical in-product OpenAPI renderer; Docusaurus is the canonical public docs-site generator; per-Node `overview.md`/`boundaries.md`/`invariants.md` remains the default per-Node docs surface; both tools consume Web.UI tokens. Audit the existing catalogs for matching slots; do **not** invent fields that don't exist in the schemas.

## Context
ADR-0075's Affected Nodes section lists only conceptual touchpoints — every Node with an OpenAPI surface adopts Scalar over time, Notify Cloud is the first likely Docusaurus consumer, Studios is unaffected, Web.UI's tokens become the visual baseline for both tools — but the ADR commits **no numbered invariants** (per its Consequences/Invariants subsection: "No new Grid-wide invariants introduced"). The four committed conventions are enforced at packet authoring and review.

**Catalog schema ground truth — read before editing.**
- `catalogs/contracts.json` registers .NET contract interfaces per Node. ADR-0075 commits **no new contract interfaces** — Scalar is a renderer, Docusaurus is a static-site generator. **Do not add a Scalar or Docusaurus entry to `contracts.json`** — that schema does not represent tooling choices.
- `catalogs/grid-health.json` node entries carry `signal`/`version`/`canary_status`/`last_release`/`active_blockers`/`notes` — there is **no docs-tooling or renderer readout** in the per-Node schema. **Do not edit `grid-health.json` to add a docs-tooling field** — that would invent a field that does not exist.
- `catalogs/nodes.json` has no `tooling` or `docs_tooling` field. Do not invent one.
- `catalogs/modules.json` lists per-Node packages. Scalar is an external NuGet package (`Scalar.AspNetCore`); Docusaurus is an external npm package; `@honeydrunk/docs-preset` is a future Web.UI package (packet 04). `modules.json` is not the location for an external-tooling-convention note.

The right home for the convention is **a cross-cutting Grid note** — match the established convention for cross-cutting policy notes in this repo. Inspect the existing notes locations (look in `constitution/` for grid-wide conventions like `naming-conventions.md`, in `business/context/` for operator-facing notes, in `initiatives/` for in-progress tracking) and place the convention where similar tooling decisions already live. If no precedent exists, the strong default is a short Markdown file under `constitution/` (e.g., `constitution/docs-tooling.md`) — Scalar/Docusaurus are Grid-wide conventions and `constitution/` is the home for Grid-wide conventions that are not invariant-numbered.

The note's content (verbatim-in-substance from ADR-0075):

1. **In-product OpenAPI rendering — Scalar (`Scalar.AspNetCore`).** New Grid Nodes with an OpenAPI surface adopt Scalar from day one. `Microsoft.AspNetCore.OpenApi` generates the document per ADR-0057; Scalar renders it. Per-environment availability: dev/staging enabled by default; prod enabled at the Node's discretion. Existing Swagger UI usage grandfathers per ADR-0075 D4 — no campaign.
2. **Public per-Node documentation sites — Docusaurus 3.x.** Standalone Grid docs sites use Docusaurus 3.x. Per-Node docs sites live in the Node's repo under `docs-site/`; consume the shared `@honeydrunk/docs-preset` (packet 04) for cross-Node coherence. Hosting target: Cloudflare Pages per ADR-0029 (the docs-deploy reusable workflow ships in packet 05).
3. **Per-Node docs default — `overview.md`/`boundaries.md`/`invariants.md` in the Architecture repo.** A Docusaurus site is warranted only when external developer consumers exist, a public conceptual surface overflows `overview.md`, or an operator-time-saving threshold is hit. **Most Nodes do not have a doc site.** The decision rubric is packet 03's deliverable.
4. **Both tools consume Web.UI tokens (per ADR-0071).** Scalar custom CSS imports Web.UI's CSS variables; the Docusaurus preset imports Web.UI tokens. Cross-surface visual coherence is part of the tool choice.
5. **Studios website is out of scope** (per ADR-0075 D3) — Studios is a product Node with its own per-product tooling.

This is a docs/catalog packet. No code, no .NET project.

## Scope
- One cross-cutting Grid convention note recording the Scalar/Docusaurus tooling commitments and the four conventions listed above. Place the note in the established location for Grid-wide cross-cutting conventions (the strong default: `constitution/docs-tooling.md`, matching the file-naming convention of `constitution/naming-conventions.md`).
- No edit to `catalogs/contracts.json` (no contract added — Scalar/Docusaurus are tooling, not interfaces).
- No edit to `catalogs/grid-health.json` (its node-entry schema has no docs-tooling slot — do not invent one).
- No edit to `catalogs/nodes.json` or `catalogs/modules.json` (no schema slot for external-tooling conventions).
- Cross-link the new note from `adrs/README.md`'s ADR-0075 row or from `initiatives/active-initiatives.md`'s `adr-0075-docs-tooling` entry as appropriate.

## Proposed Implementation
1. **Audit existing locations first** — search `constitution/` and `business/context/` for files that record similar Grid-wide cross-cutting conventions (e.g., `naming-conventions.md`, `terminology.md`). Match the file format and section style.
2. **Create or extend the cross-cutting convention note.** If `constitution/` has a precedent file for tooling/library conventions, extend it; otherwise create `constitution/docs-tooling.md` recording the four conventions verbatim-in-substance from ADR-0075 and citing ADR-0075 as the source.
3. **Cite related ADRs in the note** — ADR-0057 (OpenAPI as source of truth), ADR-0071 (Web.UI tokens), ADR-0029 (Cloudflare Pages as docs-deploy target), ADR-0070 (React-ecosystem alignment for Docusaurus).
4. **Do not edit `catalogs/contracts.json` or `catalogs/grid-health.json`** — neither schema represents tooling conventions. Adding fields contradicts schema ground truth.
5. **Cross-link the new note** from `adrs/README.md`'s ADR-0075 row (if the README convention supports a "Notes" or "See also" column) or from the initiative entry in `initiatives/active-initiatives.md`. Match the existing cross-link style.

## Affected Files
- A new or extended Grid convention note (the strong default: `constitution/docs-tooling.md`).
- `adrs/README.md` or `initiatives/active-initiatives.md` (cross-link only, if the existing convention supports it).

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] No invented catalog fields — `contracts.json`/`grid-health.json` schemas are untouched.

## Acceptance Criteria
- [ ] A cross-cutting Grid convention note exists recording the four ADR-0075 conventions (Scalar for new OpenAPI surfaces; Docusaurus for standalone docs sites; per-Node `overview.md` as default; both tools consume Web.UI tokens), citing ADR-0075 as the source, citing ADR-0057 / ADR-0071 / ADR-0029 / ADR-0070 as related
- [ ] The note is placed in the Grid's established location for cross-cutting conventions (the strong default: `constitution/docs-tooling.md`)
- [ ] `catalogs/contracts.json` is **not** edited (Scalar/Docusaurus are tooling, not contracts)
- [ ] `catalogs/grid-health.json` is **not** edited (no docs-tooling slot in the schema; do not invent one)
- [ ] `catalogs/nodes.json` / `catalogs/modules.json` are **not** edited (no docs-tooling slot)
- [ ] The new note is cross-linked from `adrs/README.md` or the initiative entry, matching the existing cross-link convention
- [ ] No invariant change in this packet (ADR-0075 adds zero invariants per packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0075 D1 — Scalar is the canonical in-product OpenAPI renderer.** New Nodes with OpenAPI surfaces adopt `Scalar.AspNetCore`; document generation stays with `Microsoft.AspNetCore.OpenApi` per ADR-0057; per-environment availability is the Node's choice.

**ADR-0075 D2 — Docusaurus 3.x is the canonical standalone docs-site generator.** Used when a Node warrants its own doc site; per-Node `docs-site/`; shared `@honeydrunk/docs-preset`. Default per-Node docs remain `overview.md` in the Architecture repo.

**ADR-0075 D3 — Studios website is explicitly separate** — a product Node per ADR-0071 D3, not a docs site.

**ADR-0075 D4 — Migration is opportunistic, not a campaign.** Existing Swagger UI grandfathers.

**ADR-0075 D5 — Both tools consume Web.UI tokens.** Visual coherence across product, admin, and docs surfaces.

**ADR-0075 D6 — Out of scope:** Studios tooling, internal Architecture-repo docs (Markdown-in-repo only), DocFX-style XML-comment docs, per-Node CHANGELOG aggregation, l10n, docs hosting platform (Cloudflare Pages per ADR-0029 is the strong default for the docs-deploy packet).

**ADR-0057 — OpenAPI as source of truth.** Scalar renders what ADR-0057's `Microsoft.AspNetCore.OpenApi` generates. No document-generation change.

**ADR-0029 — Cloudflare DNS and edge platform.** Cloudflare Pages aligns with the Grid's edge posture and is the strong default for the docs-deploy target (packet 05).

**ADR-0071 — Web.UI Node.** Tokens become the visual baseline for both Scalar customization and the Docusaurus preset.

## Constraints
- **No invented catalog fields.** `catalogs/contracts.json` is for contract interfaces, not tooling. `catalogs/grid-health.json` per-Node schema has no docs-tooling readout — do not add one.
- **No invariant numbered 54+ added.** ADR-0075 explicitly commits zero new Grid-wide invariants; packet 00 confirmed this and did not edit `constitution/invariants.md`. This packet must not either.
- **Use the established convention-note location.** If `constitution/` already houses tooling/library conventions, extend the precedent rather than creating a parallel file. Match the existing file format and section style.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0075`, `wave-1`

## Agent Handoff

**Objective:** Record the Scalar + Docusaurus tooling convention as a Grid cross-cutting note, without inventing catalog fields.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make ADR-0075's four committed conventions readable in the Grid's established convention-notes location, so packet authors and review agents can reference them at edit time.
- Feature: ADR-0075 Documentation Tooling rollout, Wave 1.
- ADRs: ADR-0075 (primary), ADR-0057, ADR-0071, ADR-0029, ADR-0070.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0075 should be Accepted before its conventions are recorded.

**Constraints:**
- Audit the established convention-notes location first; do not create a parallel file if a precedent exists.
- Do **not** edit `catalogs/contracts.json` (no contract added) or `catalogs/grid-health.json` (no docs-tooling schema slot).
- Do **not** add any numbered invariant. ADR-0075 commits zero invariants.

**Key Files:**
- The new or extended convention note (strong default: `constitution/docs-tooling.md`).
- `adrs/README.md` or `initiatives/active-initiatives.md` for the cross-link, if the existing convention supports it.

**Contracts:** None — Scalar and Docusaurus are tooling choices, not interfaces.
