---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0075", "wave-1"]
dependencies: []
adrs: ["ADR-0075"]
accepts: ["ADR-0075"]
wave: 1
initiative: adr-0075-docs-tooling
node: honeydrunk-architecture
---

# Accept ADR-0075 — flip status, register the initiative

## Summary
Flip ADR-0075 (Documentation Tooling — Scalar and Docusaurus) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, and register the `adr-0075-docs-tooling` initiative in `initiatives/active-initiatives.md`. **ADR-0075 adds no Grid-wide invariants** — its Consequences/Invariants subsection explicitly states "No new Grid-wide invariants introduced. The following are committed conventions enforced at packet authoring and review." This packet does **not** edit `constitution/invariants.md`.

## Context
ADR-0075 commits the Grid's two documentation surfaces to specific tools:

- **D1** — **Scalar** (`Scalar.AspNetCore`) replaces Swagger UI as the canonical in-product OpenAPI renderer in every Grid Node that exposes an OpenAPI spec. `Microsoft.AspNetCore.OpenApi` continues to generate the document per ADR-0057; Scalar renders it. Per-environment availability: dev/staging enabled by default; prod enabled at the Node's discretion (Notify Cloud's public API surface keeps Scalar in prod; internal-only Nodes like Identity and Audit may keep it dev/staging-only).
- **D2** — **Docusaurus 3.x** is the canonical static-site generator for standalone public per-Node documentation sites. Per-Node doc sites live in the Node's repo under `docs-site/`; deployed to a per-Node subdomain or path under `honeydrunkstudios.com`; consume a shared `@honeydrunk/docs-preset` Docusaurus preset for cross-Node coherence. **Not** every Node gets a docs site — per-Node `overview.md` / `boundaries.md` / `invariants.md` in the Architecture repo is the default; a Docusaurus site is warranted only when external developer consumers exist, a public conceptual surface overflows `overview.md`, or an operator-time-saving threshold is hit.
- **D3** — The Studios website is **explicitly separate** from Docusaurus scope. Studios is one product Node with its own per-product tooling (likely Next.js or Vite per ADR-0070 D1), not a docs site. The two are deliberately separate.
- **D4** — Migration discipline: **opportunistic, not a campaign**. New Nodes use Scalar from day one; existing Swagger UI usage grandfathers and migrates when its Node is touched for other reasons. Forced retroactive migration is forbidden per the charter's "architecture-as-procrastination" forbidding.
- **D5** — Both tools consume **Web.UI tokens** per ADR-0071 for cross-surface visual coherence.
- **D6** — Out of scope: Studios website tooling, internal Architecture-repo docs, XML-comment-based DocFX-style API docs, per-Node CHANGELOG aggregation, translation/l10n workflow, docs hosting platform (deferred to per-Node docs-deploy packets with Cloudflare Pages as the strong default per ADR-0029), cross-Node docs search.

ADR-0075 is a **policy / tooling-choice** ADR. The concrete code — Scalar in the Web.Rest reference middleware, the `@honeydrunk/docs-preset` Docusaurus preset, the docs-deploy reusable workflow — lands in subsequent packets (02, 04, 05). Catalog and governance notes land as packets 01 and 03. Every other packet in this initiative references ADR-0075's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0075-documentation-tooling.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0075 row Status column to Accepted.
- `initiatives/active-initiatives.md` — register the `adr-0075-docs-tooling` initiative with the packet checklist for this folder.
- `constitution/invariants.md` — **not touched.** ADR-0075's Consequences/Invariants subsection explicitly commits zero new Grid-wide invariants. The four committed conventions (new Nodes with OpenAPI surfaces use Scalar; standalone Grid docs sites use Docusaurus; per-Node docs default to overview.md/boundaries.md/invariants.md; both tools consume Web.UI tokens) are enforced at packet authoring and review, not encoded as numbered invariants.

## Proposed Implementation
1. Edit the ADR-0075 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0075 index row in `adrs/README.md` to Accepted.
3. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder. The entry mirrors the format of other Accepted-tooling initiatives in the file (Title, Status: In Progress, Scope, Initiative slug, Board link, Description, Tracking checklist per wave, Exit criteria). The exit criterion: ADR-0075 is Accepted; the `Scalar.AspNetCore` reference middleware is shipped in `HoneyDrunk.Web.Rest.AspNetCore`; the per-Node docs-site decision rubric is published; the Cloudflare-Pages docs-deploy reusable workflow exists in `HoneyDrunk.Actions`; the `@honeydrunk/docs-preset` package is filed parked behind the Web.UI Node standup.
4. **Do not edit `constitution/invariants.md`.** ADR-0075's "No new Grid-wide invariants introduced" stance is load-bearing — adding numbered invariants in this packet contradicts the ADR text.

## Affected Files
- `adrs/ADR-0075-documentation-tooling.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0075 header reads `**Status:** Accepted`
- [ ] The ADR-0075 row in `adrs/README.md` reflects Accepted
- [ ] `initiatives/active-initiatives.md` registers the `adr-0075-docs-tooling` initiative with a packet checklist matching the dispatch plan's wave structure
- [ ] `constitution/invariants.md` is **not** edited — ADR-0075 explicitly adds zero new invariants
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0075 D1 — Scalar is the canonical in-product OpenAPI renderer.** `Scalar.AspNetCore` replaces Swagger UI as the .NET middleware. `Microsoft.AspNetCore.OpenApi` continues to generate the document per ADR-0057; Scalar renders it. Per-environment availability is the Node's choice — dev/staging enabled by default; prod enabled when the Node's API surface is consumer-facing (Notify Cloud) or kept dev/staging-only for internal-only Nodes.

**ADR-0075 D2 — Docusaurus is the canonical public documentation site generator, used when a Node warrants its own doc site.** Docusaurus 3.x; per-Node `docs-site/`; shared `@honeydrunk/docs-preset` for cross-Node coherence; **not** every Node by default — `overview.md`/`boundaries.md`/`invariants.md` in the Architecture repo remains the default per-Node docs surface.

**ADR-0075 D3 — Studios website is explicitly separate from Docusaurus scope.** Studios is a product Node per ADR-0071 D3; its tooling is per-product within the ADR-0070 D1 React constraint.

**ADR-0075 D4 — Migration discipline: opportunistic, not a campaign.** New Nodes use Scalar from day one; existing Swagger UI grandfathers and migrates only when its Node is touched for other reasons. Forced retroactive migration is forbidden per the charter.

**ADR-0075 D5 — Both tools consume Web.UI tokens per ADR-0071** for visual coherence across docs, admin, and product surfaces.

**ADR-0075 Consequences — Invariants.** ADR-0075 adds **zero new Grid-wide invariants**. The four committed conventions (Scalar for new OpenAPI surfaces; Docusaurus for standalone docs sites; per-Node `overview.md` as default; both tools consume Web.UI tokens) are enforced at packet authoring and review.

## Constraints
- **Acceptance precedes flip.** ADR-0075 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Do not add invariants.** ADR-0075 explicitly commits zero new Grid-wide invariants. Adding numbered invariants in this packet contradicts the ADR text. The current highest invariant in `constitution/invariants.md` is 53; do not append any number above that for this ADR.
- **No catalog edit in this packet.** Catalog/tooling-convention notes land in packet 01.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0075`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0075 to Accepted and register the docs-tooling initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0075 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0075 Documentation Tooling (Scalar + Docusaurus) rollout, Wave 1.
- ADRs: ADR-0075 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0075 stays Proposed until this PR merges.
- **Do not edit `constitution/invariants.md`.** ADR-0075 explicitly states "No new Grid-wide invariants introduced." Adding any numbered invariant contradicts the ADR.
- No catalog edit in this packet — packet 01 owns the tooling-convention note.

**Key Files:**
- `adrs/ADR-0075-documentation-tooling.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
