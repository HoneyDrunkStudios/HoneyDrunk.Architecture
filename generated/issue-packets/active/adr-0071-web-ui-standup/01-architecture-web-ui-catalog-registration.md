---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "web-ui", "adr-0071"]
dependencies: []
adrs: ["ADR-0071"]
accepts: ADR-0071
wave: 1
initiative: adr-0071-web-ui-standup
node: honeydrunk-web-ui
---

# Chore: Register HoneyDrunk.Web.UI's standup decisions in Architecture catalogs

## Summary
Land the catalog and reference-doc surface for `HoneyDrunk.Web.UI` per ADR-0071's "If Accepted — Required Follow-Up Work" checklist. Add the new Creator-sector Node to every catalog file (`nodes.json`, `relationships.json`, `grid-health.json`, `modules.json`, `contracts.json`), anchor the Creator-sector in `constitution/sectors.md`, add the Q2 2026 roadmap bullet, add an in-progress entry to `initiatives/active-initiatives.md`, capture Studios' informal token inventory into a new context-folder file (`studios-tokens-inventory.md`) for packet 04's reference, and create the `repos/HoneyDrunk.Web.UI/` context folder (`overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md`) matching the template used by `repos/HoneyDrunk.Studios/` and `repos/HoneyDrunk.Audit/`.

ADR-0071 stays at `Status: Proposed` for this packet — the Status flip is a separate post-merge housekeeping step the scope agent handles after the entire initiative completes, per the user's standing ADR acceptance workflow. This packet's body does not edit the ADR header.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0071 establishes the `HoneyDrunk.Web.UI` Node's sector and purpose (D1, D2), its anchor role for the empty Creator sector (D2), the Studios-consumes-Web.UI inversion (D3), the per-stack component strategy (D4), the phased shipping plan (D5), the per-stack package layout (D6), the semver discipline (D7), the explicit boundaries (D8), the runtime-dependency posture (D9), the charter sanity check (D10), and the relationships to ADR-0070 / ADR-0027 / ADR-0035 / ADR-0039 (D11). None of that has reached the canonical catalogs yet. Until it does, every downstream consumer (Studios as the first consumer, Notify Cloud's Blazor admin, all four queued consumer-app PDRs Hearth/Lately/Currents/Curiosities) reads stale metadata when scoping its own work, and the scaffold packet (packet 04 of this initiative) has nothing to anchor its `node:` frontmatter or its in-Architecture context-folder cross-references against.

Eight catalog/doc surfaces drift today:

1. **`catalogs/nodes.json`** carries no `honeydrunk-web-ui` entry. The Creator sector currently has zero Nodes; Web.UI is the anchor that gives the sector live identity.
2. **`catalogs/relationships.json`** has no `honeydrunk-web-ui` block. The new edges (consumes nothing at runtime per D9; `consumed_by_planned` includes Studios, Notify Cloud admin, and the four PDR-driven consumer apps) need to land in lockstep with the Node entry. Also: `honeydrunk-studios.consumes_planned` gains `honeydrunk-web-ui` because Studios is the first named consumer per D3.
3. **`catalogs/grid-health.json`** has no Web.UI row. Stand-up state is empty (no `0.1.0` yet, no npm packages published, scaffold packet pending) — the row must reflect that honestly.
4. **`catalogs/modules.json`** has no Web.UI package entries. ADR-0071 D6 commits five packages on the initial surface (`@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, `@honeydrunk/web-ui-react`, `HoneyDrunk.Web.UI.Blazor` deferred, `@honeydrunk/web-ui-native` deferred). Two ship at v0.1.0 (tokens + CSS per D5 Phase 1); three are placeholders awaiting Phase 2/3/4 demand. All five need module entries at version 0.0.0 pre-scaffold.
5. **`catalogs/contracts.json`** has no Web.UI contracts block. The shipped tokens schema (color, spacing, typography, radii, shadows, motion, breakpoints, z-index) plus the primitive-CSS class taxonomy need registration with `status: seed` so downstream Nodes can find the canonical surface.
6. **`constitution/sectors.md`** Creator-sector text reads "No real Nodes yet. Planned: HoneyDrunk.Signal, Forge." Web.UI must replace that placeholder as the anchor row and update the Creator-sector text accordingly.
7. **`infrastructure/reference/tech-stack.md`** has no Web.UI entry — but the canonical npm/CSS/React substrate doesn't fit the existing "Backend" / "Azure SDK" sections cleanly. The Frontend section (under `## Frontend` if present, else added under a new section) gains Web.UI rows.
8. **`initiatives/roadmap.md`** and **`initiatives/active-initiatives.md`** have no Web.UI entries. The Q2 2026 (Apr–Jun) section is where this Node lives, given the Studios-first-consumer driver and the queued PDR-0005 Hearth.

The `repos/HoneyDrunk.Web.UI/` context folder does not exist on disk — confirmed by `ls repos/` showing the sibling folders (`HoneyDrunk.Audit/`, `HoneyDrunk.Studios/`, `HoneyDrunk.Communications/`, etc.) but no `HoneyDrunk.Web.UI/`. This packet creates it with the four standard files matching the Studios template's shape (the closest analog because both are JS-shaped Nodes), plus a fifth file `studios-tokens-inventory.md` that captures the informal tokens Studios uses today so packet 04's scaffolding agent has a concrete starting point for the first `@honeydrunk/web-ui-tokens` release.

The ADR Status flip (Proposed → Accepted) is intentionally **not** in this packet. Per the user's standing ADR acceptance workflow (`feedback_adr_workflow.md`), the scope agent flips Status only after the entire initiative's PRs have merged. This is a separate post-merge housekeeping step that runs after packets 01 / 02 / 03 / 04 are all closed — not a line-edit on this packet.

## Proposed Implementation

### `catalogs/nodes.json` — new `honeydrunk-web-ui` entry

**Anchor semantically, not by line number.** Find the `honeydrunk-studios` block via `rg -n '"id": "honeydrunk-studios"' catalogs/nodes.json` at edit time and insert the new `honeydrunk-web-ui` block adjacent to it (Studios is the closest analog — both Meta/Creator-adjacent, both JS-shaped). Do not rely on the line numbers cited anywhere in this packet; treat them as scoping-time hints only and re-confirm by grep at edit time.

The new block follows the same schema every other Node uses (see `honeydrunk-studios` and `honeydrunk-audit` for shape reference).

**Cluster value note:** Use `cluster: "visualization"` — matches the Studios precedent (Studios is `cluster: "visualization"` in the current `nodes.json`). The allowed cluster values in the existing taxonomy are: `foundation`, `security`, `observability`, `infrastructure`, `orchestration`, `governance`, `visualization`, `cognition`, `quality`, `knowledge`. `frontend` is **not** in the taxonomy and would invent a new cluster. `visualization` is the closest semantic match (design substrate that powers visual surfaces) and aligns with Studios' classification.

```json
{
  "id": "honeydrunk-web-ui",
  "type": "node",
  "name": "HoneyDrunk.Web.UI",
  "public_name": "HoneyDrunk.Web.UI",
  "short": "Cross-stack design system — tokens, primitive CSS, component contracts",
  "description": "The Creator sector's design substrate Node. Owns design tokens (color, spacing, typography, radii, shadows, motion, breakpoints), primitive CSS (reset, base typography, utility classes), and component contracts (design specifications) shared across React, Blazor, and React Native consumers. Tokens cross-stack; components per-stack. Pure client-side substrate — no runtime dependency on any Grid Node.",
  "sector": "Creator",
  "signal": "Seed",
  "cluster": "visualization",
  "energy": 0,
  "priority": 0,
  "flow": 0,
  "tags": ["design-system", "tokens", "css", "react", "blazor", "react-native", "frontend-substrate", "creator-sector-anchor"],
  "links": {
    "repo": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI"
  },
  "long_description": {
    "overview": "HoneyDrunk.Web.UI is the Creator sector's single Node that owns the Grid's design substrate — tokens, primitive CSS, and component contracts consumed by every frontend surface in the Grid. It is the cross-stack reconciliation point for the three-stack split committed by the paired frontend-platform ADR: React for consumer web, Blazor for simple admin, React Native + Expo for mobile. Tokens are shared (one JSON + CSS-variables source consumed identically by every stack); primitive CSS is shared across web stacks (React + Blazor); components ship per-stack (React first-class, Blazor and RN added per surface demand). The boundary is named at standup; the Node ships tokens + primitive CSS at Phase 1 with Studios as the first consumer.",
    "why_it_exists": "Every consumer surface in the Grid was re-deriving its visual language. Studios had informal tokens; Notify Cloud admin would have invented its own; each of the four queued consumer-app PDRs (Hearth, Lately, Currents, Curiosities) implied a separate per-PDR design tax. Without a shared substrate Node, the design tax compounded with every new surface and brand recognizability degraded per product. Web.UI exists so cross-PDR design coherence becomes the default and every consumer inherits the Grid's visual language without re-deriving it.",
    "primary_audience": "Every Grid consumer frontend that renders a user-facing surface — HoneyDrunk.Studios (first consumer at Phase 1), HoneyDrunk.Notify.Cloud (Blazor admin at Phase 2; tokens + CSS only), and the four PDR-driven consumer apps (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0008 Curiosities — each from its first scaffolding packet).",
    "value_props": [
      "Single Grid Node owns design tokens — color, spacing, typography, radii, shadows, motion, breakpoints, z-index",
      "Tokens stack-agnostic (JSON + CSS variables) — consumed identically by React, Blazor, and React Native",
      "Primitive CSS bundle (reset + base typography + utility classes) shared across web stacks",
      "Component contracts (design specs) shared; per-stack implementations preserved (React first-class, Blazor and RN per demand)",
      "Pure client-side substrate — no runtime dependency on any Grid Node, no Kernel coupling",
      "Studios-consumes-Web.UI inversion — Web.UI is not folded into Studios; substrate is upstream of every product",
      "Per-PDR CSS-variable overrides permitted — consumers diverge where their brand needs it while inheriting the baseline",
      "Cross-stack brand coherence compounds — every new consumer surface inherits the Grid's visual language"
    ],
    "monetization_signal": "Internal-first design substrate. The investment compounds with every consumer PDR that consumes Web.UI on day one instead of paying its own per-surface design tax. Future open-source surface possible once the token + component pack stabilizes.",
    "roadmap_focus": "Phase 1 — stand up the monorepo, publish @honeydrunk/web-ui-tokens and @honeydrunk/web-ui-css at 0.1.x with Studios' existing tokens formalized. Phase 2 — ship @honeydrunk/web-ui-react component pack (Button, Input, Label, Card, Modal, Toast, Alert, Spinner, Skeleton) at first non-Studios consumer demand. Phase 3 — HoneyDrunk.Web.UI.Blazor components per Notify Cloud admin demand. Phase 4 — @honeydrunk/web-ui-native at first mobile PDR. Phase 5 — designer-tooling integration (Figma / Penpot) when designer joins.",
    "grid_relationship": "Does NOT depend on any runtime Grid Node — pure client-side substrate. No Kernel, Vault, Auth, Data, Transport, Audit, or Pulse reference at v1. The dependency direction is one-way: consumer → Web.UI, never the inverse. Consumed (planned) by Studios (first consumer at Phase 1), Notify.Cloud (Blazor admin at Phase 2 with tokens + CSS only), and PDR-driven consumer apps from their first scaffolding packet.",
    "integration_depth": "shallow",
    "demo_path": "Open Studios → observe tokens consumed from @honeydrunk/web-ui-tokens (CSS variables on :root) → inspect primitive class names from @honeydrunk/web-ui-css → see consistent button/card/modal shapes across surfaces.",
    "signal_quote": "The Grid has a face.",
    "stability_tier": "seed",
    "impact_vector": "frontend coherence"
  },
  "foundational": false,
  "strategy_base": 12,
  "tier": "none",
  "time_pressure": 1,
  "done": false,
  "cooldown_days": 14
},
```

### `catalogs/relationships.json` — new `honeydrunk-web-ui` block

**Anchor semantically, not by line number.** Add a new entry to the `nodes` array, placed adjacent to the `honeydrunk-studios` entry (closest analog). Find the current position via `rg -n '"id": "honeydrunk-studios"' catalogs/relationships.json` at edit time. Also amend the existing `honeydrunk-studios` entry's `consumes_planned` array to record the new downstream-of-Studios edge per ADR-0071 D3 (Studios consumes Web.UI; Studios is not the host).

- `honeydrunk-studios`: append `"honeydrunk-web-ui"` to `consumes_planned` (Studios migrates to consume Web.UI tokens at Phase 1 per D3). If `consumes_planned` does not exist on the Studios entry, add it.
- `honeydrunk-notify-cloud` (if present): append `"honeydrunk-web-ui"` to `consumes_planned` (Notify Cloud admin consumes tokens + CSS at Phase 2 per D5). If the entry doesn't exist yet (cloud Node not stood up), skip — the cloud Node's own standup ADR's catalog packet will add the edge bidirectionally.

The new Web.UI entry:

```json
{
  "id": "honeydrunk-web-ui",
  "consumes": [],
  "consumed_by": [],
  "consumed_by_planned": ["honeydrunk-studios", "honeydrunk-notify-cloud"],
  "blocked_by": [],
  "exposes": {
    "contracts": ["DesignTokens", "PrimitiveCss", "ComponentContract"],
    "packages": ["@honeydrunk/web-ui-tokens", "@honeydrunk/web-ui-css", "@honeydrunk/web-ui-react", "HoneyDrunk.Web.UI.Blazor", "@honeydrunk/web-ui-native"]
  },
  "consumes_detail": {}
},
```

**Note on `consumed_by_planned`:** ADR-0071 names Hearth, Lately, Currents, Curiosities as future consumer-app PDR consumers. None of those Nodes have a stand-up ADR yet (no `honeydrunk-hearth` / `honeydrunk-lately` / `honeydrunk-currents` / `honeydrunk-curiosities` ids exist in `nodes.json` as of 2026-05-25). Listing them as future planned consumers in catalog form would invent Node ids that have not been committed. **Do not list non-existent Node ids in `consumed_by_planned`.** The two entries above (`honeydrunk-studios` and `honeydrunk-notify-cloud`) are the actual existing Nodes (Studios live; Notify.Cloud at standup-pending — verify Notify.Cloud presence in nodes.json at edit time before including it). When each PDR-driven app standup ADR lands, that ADR's own Wave-1 catalog packet adds the bidirectional edge.

**`consumes` array is empty.** Per ADR-0071 D9, Web.UI has no runtime dependency on any Grid Node. This is the load-bearing posture; the empty `consumes` array is correct and not an oversight.

### `catalogs/grid-health.json` — new `honeydrunk-web-ui` row

**Anchor semantically.** Insert a new row into the `nodes` array. Find the position adjacent to the `honeydrunk-studios` row via `rg -n '"id": "honeydrunk-studios"' catalogs/grid-health.json` at edit time. The row reflects empty-stand-up state — no published npm packages yet, no canary baseline.

```json
{
  "id": "honeydrunk-web-ui",
  "name": "HoneyDrunk.Web.UI",
  "sector": "Creator",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": [
    "GitHub repo not yet created (packet 03 of adr-0071-web-ui-standup)",
    "Scaffold packet (packet 04 of adr-0071-web-ui-standup) not yet executed",
    "npm scope @honeydrunk not yet verified (packet 03)"
  ],
  "notes": "ADR-0071 standup ADR Proposed 2026-05-23 (Status flip to Accepted is a separate post-merge housekeeping step after the initiative completes). Catalog surface registered. Awaiting GitHub repo creation (human-only, packet 03 — also handles npm scope verification and NPM_TOKEN seeding) and scaffold execution: monorepo with pnpm workspaces, @honeydrunk/web-ui-tokens (tokens JSON + CSS variables), @honeydrunk/web-ui-css (primitive CSS bundle), @honeydrunk/web-ui-react (placeholder at standup; first components ship at Phase 2), HoneyDrunk.Web.UI.Blazor (placeholder; ships at Phase 3 per Notify Cloud demand), @honeydrunk/web-ui-native (placeholder; ships at Phase 4 per first mobile PDR), CI with publish-on-tag pipeline. Studios is the first named consumer — migration packet follows after 0.1.0 publishes."
},
```

Also update the `summary.blocked_nodes` array at the bottom of the file — append `"honeydrunk-web-ui"` and bump `summary.total_nodes`, `summary.seed`, and `summary.canary_none` each by 1. **Read the actual current values from `summary` at edit time** (find via `rg -n '"summary"' catalogs/grid-health.json`); scoping-time counts may have shifted if other Nodes flipped to Live or were added in the interim.

### `catalogs/modules.json` — five new module entries

Append five entries to the modules array (file is a flat JSON array). All five start at `version: "0.0.0"` reflecting empty pre-scaffold state. After the scaffold packet (packet 04) lands `v0.1.0` for the two shipping packages, a separate post-scaffold catalog reconciliation bumps the tokens + CSS entries to 0.1.0 — that bump is the follow-up packet `05-architecture-web-ui-post-release-version-bump.md` (filed at the same time as this initiative but parked behind `v0.1.0` shipping).

**Anchor semantically.** Insert immediately after the existing `studios` entry — find its position via `rg -n '"nodeId": "honeydrunk-studios"' catalogs/modules.json` at edit time:

```json
{
  "id": "web-ui-tokens",
  "nodeId": "honeydrunk-web-ui",
  "name": "@honeydrunk/web-ui-tokens",
  "type": "abstractions",
  "version": "0.0.0",
  "description": "Stack-agnostic design tokens — color, spacing, typography, radii, shadows, motion, breakpoints, z-index scale. Shipped as JSON for stack-agnostic consumption and as CSS variables for direct browser consumption. The single source of truth for the Grid's visual language."
},
{
  "id": "web-ui-css",
  "nodeId": "honeydrunk-web-ui",
  "name": "@honeydrunk/web-ui-css",
  "type": "runtime",
  "version": "0.0.0",
  "description": "Primitive CSS bundle — reset, base typography, utility classes. Consumed by React and Blazor surfaces. Built on top of @honeydrunk/web-ui-tokens; consumes the CSS variables emitted by the tokens package."
},
{
  "id": "web-ui-react",
  "nodeId": "honeydrunk-web-ui",
  "name": "@honeydrunk/web-ui-react",
  "type": "provider",
  "version": "0.0.0",
  "description": "First-class React component implementations (Phase 2 — placeholder at standup; first components Button/Input/Label/Card/Modal/Toast/Alert/Spinner/Skeleton ship at first non-Studios consumer demand). Built on tokens + CSS, may build on headless primitives (Radix UI, shadcn patterns) at the implementation layer."
},
{
  "id": "web-ui-blazor",
  "nodeId": "honeydrunk-web-ui",
  "name": "HoneyDrunk.Web.UI.Blazor",
  "type": "provider",
  "version": "0.0.0",
  "description": "Blazor component implementations (Phase 3 — placeholder at standup). Added per admin-surface demand. Most Blazor consumers need only tokens + CSS per ADR-0071 D4."
},
{
  "id": "web-ui-native",
  "nodeId": "honeydrunk-web-ui",
  "name": "@honeydrunk/web-ui-native",
  "type": "provider",
  "version": "0.0.0",
  "description": "React Native component implementations (Phase 4 — placeholder at standup). Mobile-specific patterns (TabBar, BottomSheet, etc.) join when first mobile PDR demands them. Web-specific patterns (Tooltip on hover) have no RN equivalent and are documented as web-only."
}
```

### `catalogs/contracts.json` — new `honeydrunk-web-ui` block

Append a new entry to the `contracts` array. Schema mirrors every other Node's block — find the `honeydrunk-studios` entry (or the closest neighbor) via `rg -n '"node":' catalogs/contracts.json` at edit time:

```json
{
  "node": "honeydrunk-web-ui",
  "node_name": "HoneyDrunk.Web.UI",
  "package": "@honeydrunk/web-ui-tokens",
  "status": "seed",
  "interfaces": [
    { "name": "DesignTokens", "kind": "type", "description": "JSON schema covering color (semantic + scale), spacing (4px-based scale), typography (font family, size scale, weight scale, line-height scale), radii (scale), shadows (elevation scale), motion (duration + easing scale), breakpoints (mobile/tablet/desktop), z-index scale. Stack-agnostic." },
    { "name": "TokensCssVariables", "kind": "type", "description": "Browser-consumable CSS-variables emission of the DesignTokens JSON. Format: --hd-color-* / --hd-space-* / --hd-radius-* / --hd-shadow-* etc. Consumed by primitive CSS and by per-PDR consumer code." },
    { "name": "PrimitiveCss", "kind": "type", "description": "Primitive CSS bundle exported by @honeydrunk/web-ui-css — reset, base typography (h1-h6, p, ul, ol, etc.), utility class taxonomy (margin / padding / display / flex / grid / text alignment / color). Naming follows the hd- prefix convention to avoid collision with consumer CSS." },
    { "name": "ComponentContract", "kind": "type", "description": "Design specification for each primitive component (Button, Input, Card, Modal, Toast, Alert, Spinner, Skeleton, ...). Names the variants, the states (hover/focus/active/disabled/loading), the accessibility expectations (keyboard nav, ARIA, focus management). Per-stack implementations target the same contract." }
  ]
}
```

### `constitution/sectors.md` — anchor the Creator sector with Web.UI

The Creator-sector section (find via `rg -n '^## Creator' constitution/sectors.md`) currently reads:

```
## Creator

Tools that turn imagination into momentum — from marketing automation to creative analytics.

**Color:** `#14B8A6` (chromeTeal)

*No real Nodes yet. Planned: HoneyDrunk.Signal, Forge.*
```

Replace the placeholder line with a table matching the format of the other live sectors. Update the section to read:

```
## Creator

Tools that turn imagination into momentum — from design substrate to marketing automation to creative analytics. The Creator sector anchors the Grid's creative-tooling layer for people building consumer surfaces.

**Color:** `#14B8A6` (chromeTeal)

| Node | Signal | Responsibility |
|------|--------|---------------|
| **Web.UI** | Seed | Cross-stack design system — tokens (color, spacing, typography, radii, shadows, motion, breakpoints), primitive CSS, component contracts shared across React, Blazor, and React Native consumers |

*Planned: HoneyDrunk.Signal, Forge.*
```

Also locate the **Dependency Flow (Real Nodes)** code block (find via `rg -n 'Dependency Flow' constitution/sectors.md`). Since Web.UI is not yet "Real" (the repo doesn't exist; scaffold pending; per ADR-0071 D9 Web.UI has no upstream Grid-Node dependencies), do **not** add it to the Real-Nodes flow in this packet. It joins the diagram only after packet 04 lands `0.1.0`. Flagging this here so a future agent doesn't preemptively edit the diagram against an unbuilt Node. (When the diagram does include Web.UI post-release, the edge shape is `Web.UI → (no upstream Grid Node)` — pure client-side substrate.)

### `infrastructure/reference/tech-stack.md` — add Web.UI rows

Multiple table additions. **Anchor semantically** — find existing section headers via `rg -n '^## ' infrastructure/reference/tech-stack.md` at edit time.

**Frontend section table.** If a `## Frontend` section exists, append Web.UI rows. If not, add a new section after the Backend section:

```
## Frontend

| Stack/Library | Version | Used By |
|---------------|---------|---------|
| React | 19.x | Studios, Web.UI (target stack) |
| Next.js | 16.x | Studios |
| TypeScript | 5.x | Studios, Web.UI (per ADR-0070 D1) |
| pnpm | 9.x | Web.UI (monorepo workspace tool) |
```

Adjust versions to whatever is current at edit time — these are scoping-time references.

**Planned Nodes (no code yet) table.** Find via `rg -n 'Planned Nodes' infrastructure/reference/tech-stack.md`. Web.UI is being stood up (this initiative) — but the scaffold hasn't run, so it's still "no code yet" until packet 04 closes. Add the row:

```
| Web.UI | Creator | Cross-stack design system — tokens, primitive CSS, component contracts (anchors the Creator sector) |
```

After packet 04 lands and `0.1.0` ships, a follow-up reconciliation moves Web.UI out of "Planned Nodes (no code yet)" into the live Frontend section. That reconciliation is not in this packet's scope.

### `initiatives/roadmap.md` — add Web.UI entry under Q2 2026

Find the Q2 2026 section via `rg -n 'Q2 2026' initiatives/roadmap.md`. The named first consumer (Studios) is already a live Q2 priority. Add a new bullet under Q2 2026 in the appropriate position (find the closest analog — likely the `HoneyDrunk.Files` line if packet 01 of ADR-0061's initiative has merged by then — and insert nearby):

```
- [ ] **HoneyDrunk.Web.UI Standup (ADR-0071)** — Cross-stack design system anchoring the Creator sector; tokens + primitive CSS at Phase 1 with Studios as first consumer
```

### `initiatives/active-initiatives.md` — new "In Progress" entry

Insert a new entry under `## In Progress`, immediately after the most-recent ADR-0061 (HoneyDrunk.Files Standup) block or the closest analog standup block at edit time. Find the section position via `rg -n '## In Progress' initiatives/active-initiatives.md`. The new entry:

```markdown
### ADR-0071 HoneyDrunk.Web.UI Standup
**Status:** In Progress
**Scope:** Architecture (catalog/context-folder registration + invariants) + HoneyDrunk.Web.UI (new repo, scaffold)
**Initiative:** `adr-0071-web-ui-standup`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Stand up `HoneyDrunk.Web.UI` as the Creator sector's anchor Node per ADR-0071. Owns design tokens (color, spacing, typography, radii, shadows, motion, breakpoints, z-index scale), primitive CSS (reset, base typography, utility classes), and component contracts (design specifications) shared across React, Blazor, and React Native consumers. Tokens cross-stack, components per-stack. Phase 1 ships `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css` at 0.1.x with Studios' existing informal tokens formalized as the first input. Pure client-side substrate — no runtime dependency on any Grid Node. Four packets: catalog/context-folder registration (Architecture; also captures Studios tokens inventory), three new invariants (token consumption + Studios-not-host + zero Grid-Node runtime dependency), human-only GitHub repo creation + npm scope verification + NPM_TOKEN seeding, scaffold (monorepo with pnpm workspaces, five package placeholders, tokens + CSS shipped first). Anchors the previously-empty Creator sector. Unblocks Studios' tokens migration packet, Notify Cloud admin Blazor consumer, and all four PDR-driven consumer-app scaffolds (Hearth, Lately, Currents, Curiosities).

**Tracking:**
- [ ] Architecture#NN: Catalog registration + context folder + Studios tokens inventory (packet 01)
- [ ] Architecture#NN: Add three new Web.UI invariants (packet 02)
- [ ] Architecture#NN: Create HoneyDrunk.Web.UI GitHub repo + verify @honeydrunk npm scope + seed NPM_TOKEN (human-only — packet 03)
- [ ] Web.UI#NN: Scaffold HoneyDrunk.Web.UI — monorepo, five packages (tokens + CSS shipped at 0.1.x; React/Blazor/Native placeholders), CI with npm publish-on-tag (packet 04)
- [ ] Architecture#NN: Post-release catalog version bumps — `modules.json` Web.UI entries `0.0.0` → `0.1.0` (tokens + CSS only; the three placeholders stay at 0.0.0 per ADR-0071 D7's pre-1.0 phasing), `grid-health.json` Web.UI row `version` `0.0.0` → `0.1.0`, clear `active_blockers` (packet 05; parked behind `@honeydrunk/web-ui-tokens 0.1.0` and `@honeydrunk/web-ui-css 0.1.0` shipping to npm)

> **Sync (YYYY-MM-DD):** Initiative scoped today. Packets 01/02 ready to file in Wave 1; packet 03 (human-only repo creation + npm scope + NPM_TOKEN) ready in Wave 2; packet 04 parked on packets 02 + 03 landing — packet 02 because the scaffold body cites assigned invariant numbers, packet 03 because the repo must exist and npm scope must be verified before file-packets.sh can target the repo and scaffold can authenticate to npm.
```

Replace `YYYY-MM-DD` in the sync line with the date this packet's PR is opened (or merged — the convention is whichever your hive-sync agent normalizes against).

### `repos/HoneyDrunk.Web.UI/` — new context folder (five files)

Create `repos/HoneyDrunk.Web.UI/` with five files. Four match the template used by `repos/HoneyDrunk.Studios/` (the closest JS-shaped analog), plus a fifth `studios-tokens-inventory.md` that captures the informal tokens Studios uses today so packet 04's scaffolding agent has a concrete starting point.

#### `repos/HoneyDrunk.Web.UI/overview.md`

```markdown
# HoneyDrunk.Web.UI — Overview

**Sector:** Creator
**Signal:** Seed
**Version:** 0.0.0 (standup pending)
**Stack:** TypeScript · React · CSS · Blazor (deferred) · React Native (deferred)
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Web.UI`
**Status:** Capability/decision accepted (ADR-0071). Stand-up scaffold pending.

## Purpose

The Creator sector's anchor Node. Owns the Grid's design substrate — tokens, primitive CSS, and component contracts shared across React, Blazor, and React Native consumers. Tokens cross-stack; components per-stack.

It is a substrate Node — the design analog of Kernel for runtime context, Vault for secrets, Audit for the security record. It owns the visual language; the consuming Node owns the product. Pure client-side; no runtime dependency on any Grid Node.

## Key Packages (per ADR-0071 D6)

| Package | Stack | Type | Description |
|---------|-------|------|-------------|
| `@honeydrunk/web-ui-tokens` | stack-agnostic (JSON + CSS variables) | Abstractions | Color, spacing, typography, radii, shadows, motion, breakpoints, z-index scale. The canonical source for the Grid's visual language. Ships at 0.1.x in Phase 1. |
| `@honeydrunk/web-ui-css` | web (React + Blazor) | Runtime | Reset, base typography, utility classes. The primitive CSS bundle. Built on top of tokens. Ships at 0.1.x in Phase 1. |
| `@honeydrunk/web-ui-react` | React | Provider | First-class React component implementations. Initial component set: Button, Input, Label, Card, Modal, Toast, Alert, Spinner, Skeleton. Placeholder at 0.0.0 until Phase 2 (first non-Studios consumer demand). |
| `HoneyDrunk.Web.UI.Blazor` (NuGet) | Blazor | Provider | Blazor component implementations. Added per admin surface need. Placeholder at 0.0.0 until Phase 3 (first Blazor consumer that needs components beyond tokens + CSS). |
| `@honeydrunk/web-ui-native` | React Native | Provider | Mobile-specific component implementations. Placeholder at 0.0.0 until Phase 4 (first mobile PDR). |

## Key Contracts

- `DesignTokens` (JSON schema) — color (semantic + scale), spacing (4px-based scale), typography (font family, size scale, weight scale, line-height scale), radii (scale), shadows (elevation scale), motion (duration + easing scale), breakpoints (mobile/tablet/desktop), z-index scale.
- `TokensCssVariables` — browser-consumable CSS-variables emission of the tokens JSON. Format: `--hd-color-*` / `--hd-space-*` / `--hd-radius-*` / `--hd-shadow-*` etc.
- `PrimitiveCss` — primitive CSS bundle exported by `@honeydrunk/web-ui-css` — reset, base typography, utility class taxonomy.
- `ComponentContract` — design specification for each primitive component. Names the variants, the states, the accessibility expectations. Per-stack implementations target the same contract.

## Design Notes

**Tokens are shared.** One source of truth (a tokens JSON + a CSS variables file), consumed identically by every stack. Color, spacing, typography, radii, shadows, motion, breakpoints, z-index scale. Stack-agnostic by construction.

**Primitive CSS is shared across web stacks.** The reset, the base typography, the utility classes ship as a CSS bundle that React consumers and Blazor consumers both import. The `hd-` prefix avoids collision with consumer CSS.

**Components are per-stack.** React's component model, Blazor's `RenderFragment` model, and React Native's `StyleSheet` model do not converge. A "universal component" abstraction loses to per-stack implementations on every dimension — performance, idiomatic API, ecosystem alignment, AI-assistance accuracy. The shared contract is the **design specification**, not the code.

**Studios is the first consumer.** Studios continues using its current informal tokens until Web.UI's first release is ready. At that release, a Studios follow-up packet migrates Studios to consume the Web.UI tokens package. The migration is bounded (Studios is one product; the cutover is one PR) and the tokens align (Studios' existing tokens are formalized into the first Web.UI release, so the migration is mechanical).

**Phase-1 honest limitation:** the first release ships tokens + primitive CSS only — `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css` at 0.1.x. The three component packages (`@honeydrunk/web-ui-react`, `HoneyDrunk.Web.UI.Blazor`, `@honeydrunk/web-ui-native`) ship as placeholders at 0.0.0 and gain their first real implementations at Phase 2/3/4 per consumer demand. No designer-tooling integration (Figma / Penpot) at standup — deferred until designer joins.
```

#### `repos/HoneyDrunk.Web.UI/boundaries.md`

```markdown
# HoneyDrunk.Web.UI — Boundaries

## What Web.UI Owns

- **Design tokens.** The canonical source for color (semantic + scale), spacing, typography, radii, shadows, motion, breakpoints, z-index scale. Shipped as CSS variables and as a JSON tokens file (stack-agnostic).
- **Primitive CSS.** Reset, base typography, utility classes. Shipped as a CSS bundle consumable from React, Blazor, and any web-based context.
- **Component contracts.** The design specification for each primitive (Button, Input, Card, Modal, Toast, Alert, Spinner, Skeleton, etc.). The contract names the variants, the states, the accessibility expectations.
- **React component implementations.** The first-class implementation of every component contract. The default ships from `@honeydrunk/web-ui-react`.
- **Blazor component implementations (per-surface).** Added when a specific Blazor admin surface needs a component beyond what tokens + CSS alone provide. Most Blazor consumers need only tokens + CSS at v1.
- **React Native component implementations.** Mobile-specific implementations, kept visually consistent with the React web components per the per-stack-implementation-shared-contract pattern.
- **Default light + default dark themes.** Shipped as token sets. Per-PDR custom themes layer on top via the standard CSS-variable cascade.
- **Accessibility baseline.** Every primitive has a11y baseline (keyboard nav, ARIA, focus management). Per-PDR a11y audits of composed surfaces are the consumer's responsibility.
- **Opinion on icon set.** Web.UI may opinionate on which icon set the Grid uses (the strong default is a single open-source icon set like Lucide or Phosphor) but does not author icons itself.

## What Web.UI Does NOT Own

- **The Studios website.** Studios is a separate Node and product. Web.UI is **consumed by** Studios; Web.UI does not house Studios. This separation is load-bearing — substrate is upstream of every product.
- **Per-product page templates, marketing pages, content models.** Those are PDR-side concerns.
- **State management, routing, data fetching, runtime application concerns.** Web.UI ships visual primitives, not application substrate. No Zustand, no TanStack Query, no React Router, no Apollo, no anything that takes a position on runtime application shape.
- **Backend integration code.** Web.UI is purely client-side; it does not depend on any Grid Node's runtime contract.
- **i18n / l10n catalogs.** `HoneyDrunk.Locale` is the future-state home for translation infrastructure. Web.UI's text strings on primitive components are English defaults; localization is the consuming PDR's responsibility for now.
- **Icon libraries (the icons themselves).** Web.UI re-exports if the Grid commits to a single icon set; it does not author icons.
- **Designer tooling integration.** Figma / Penpot integration is deferred until designer workflow exists.
- **Per-PDR token overrides.** Consumers may set CSS-variable overrides locally; Web.UI does not consume those back.
- **Application-specific composites.** A "BillingDashboard" is a Notify Cloud concern, not a Web.UI concern.
- **The stack-selection ADR.** Web.UI implements the cross-stack split — ADR-0070 makes the stack-selection decision.

## Boundary Decision Tests

- Is this a **color, spacing, type, radius, shadow, motion, breakpoint, or z-index value the Grid wants to be consistent on**? → Web.UI tokens.
- Is this a **reset, base typography rule, or utility class**? → Web.UI primitive CSS.
- Is this a **primitive interactive component (Button, Input, Modal, etc.)**? → Web.UI component contract + per-stack implementation.
- Is this an **application-specific composite (BillingDashboard, JournalCalendar, MapWithPins)**? → Consuming PDR.
- Is this **product-specific marketing or content**? → Consuming Node (Studios for HoneyDrunk Studios marketing; per-PDR for product marketing).
- Is this **runtime state management, routing, or data fetching**? → Consuming PDR (Web.UI does not opinionate).
- Is this a **translation catalog or l10n surface**? → `HoneyDrunk.Locale` (future) — not Web.UI.
- Is this **dependent on a Grid Node's runtime contract**? → Boundary violation — Web.UI does not consume Grid Node runtime contracts. The consumer's adapter does the mapping if needed.
- Is this **a designer tool export pipeline (Figma → tokens)**? → Deferred — when designer joins, this becomes a Web.UI capability.
```

#### `repos/HoneyDrunk.Web.UI/invariants.md`

```markdown
# HoneyDrunk.Web.UI — Invariants

Web.UI-specific invariants (supplements `constitution/invariants.md`).

1. **Web.UI is pure client-side substrate — no runtime dependency on any Grid Node.**
   No Kernel, Vault, Auth, Data, Transport, Audit, Pulse, or Notify reference in any Web.UI package. The dependency direction is consumer → Web.UI, never the inverse. JSON-deserialized values pass through Web.UI primitives the same way arbitrary string values do; if a future consumer needs to render a Grid-canonical value type (e.g., `Money` per ADR-0069, `TenantId` per ADR-0026), the dependency direction is consumer-side (the consuming PDR's adapter, not the Web.UI primitive).

2. **Tokens are stack-agnostic — components are per-stack.**
   `@honeydrunk/web-ui-tokens` ships JSON + CSS variables consumed identically by every stack. Components ship per-stack: `@honeydrunk/web-ui-react` for React, `HoneyDrunk.Web.UI.Blazor` for Blazor (per-surface), `@honeydrunk/web-ui-native` for React Native. No "universal component abstraction" wrapper; per-stack idioms are preserved.

3. **The shared contract is the design specification, not the code.**
   What stays shared is the **what** (a Button has primary / secondary / ghost variants; it has hover / focus / active / disabled states; it supports loading; it is keyboard-accessible). The **how** is per-stack. Per-stack implementations target the same `ComponentContract`.

4. **Studios consumes Web.UI — Web.UI does not host Studios.**
   Studios is a product Node, not the design-system host. Coupling cross-PDR substrate to a single product's deployment cadence, repo lifecycle, and release schedule inverts the substrate's role. The migration shape: Studios consumes Web.UI from the first 0.1.0 release.

5. **Per-PDR overrides flow through standard CSS-variable cascade — Web.UI does not consume them back.**
   Consumers diverge where their brand needs it (e.g., Hearth's "town" metaphor might want a warmer palette than the Grid default) while still inheriting the Grid baseline. Web.UI does not bidirectionally absorb consumer overrides into the canonical token set.

6. **The npm packages live under `@honeydrunk` scope.**
   `@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, `@honeydrunk/web-ui-react`, `@honeydrunk/web-ui-native`. The NuGet package `HoneyDrunk.Web.UI.Blazor` follows the existing `HoneyDrunk.*` NuGet naming.

7. **Phased shipping — no pre-emptive component surface.**
   v0.1.0 ships tokens + primitive CSS only. Component packages ship per-consumer-demand, lazily. The Web.UI Node does not pre-ship surface it does not have consumers for.

8. **Default light + default dark themes ship as token sets.**
   Per-PDR custom themes layer on top via the CSS-variable cascade. Web.UI does not ship arbitrary per-PDR themes — only the two defaults.

9. **Third-party UI library coupling is scoped per-stack and confined to the implementation layer.**
   React component implementations may build on Radix UI / shadcn patterns; Blazor may use a permissive-licensed Blazor library; RN may use Expo's primitive set. None of those leak into the public component contract or the tokens. A vendor swap is bounded to one package's implementation.

_Constitutional invariants {N1} (Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`), {N2} (`HoneyDrunk.Web.UI` does not host `HoneyDrunk.Studios` — Web.UI is consumed by Studios), and {N3} (`HoneyDrunk.Web.UI` does not depend on any Grid Node's runtime contracts) in `constitution/invariants.md` are the Grid-level rules this Node exists to enforce. All three are landed by ADR-0071's stand-up initiative (packet 02). The numeric assignments are made at packet 02's edit time via the reservation registry._

## Status

Capability/decision accepted (ADR-0071 Proposed → Accepted flips after this initiative's PRs merge). Standup scaffold (repo, monorepo with pnpm workspaces, five package placeholders with tokens + CSS shipped first, CI with npm publish-on-tag) governed by ADR-0071 itself — a distinct initiative tracked at `generated/issue-packets/active/adr-0071-web-ui-standup/`.
```

#### `repos/HoneyDrunk.Web.UI/integration-points.md`

```markdown
# HoneyDrunk.Web.UI — Integration Points

## Upstream Dependencies

**Web.UI has zero upstream Grid-Node dependencies at runtime.** This is the load-bearing posture per ADR-0071 D9.

Web.UI's runtime dependencies are purely on the JavaScript / npm ecosystem and (for Blazor) NuGet — none on any Grid Node.

| Dependency layer | Notes |
|------------------|-------|
| `react`, `react-dom` (peer dependencies of `@honeydrunk/web-ui-react`) | Consumer-provided; not bundled |
| `react-native` (peer dependency of `@honeydrunk/web-ui-native`) | Consumer-provided; not bundled |
| Headless primitives (Radix UI, shadcn patterns) | Optional implementation-layer dependencies of `@honeydrunk/web-ui-react`; vendor swap is bounded to one package |
| Build tooling (TypeScript, pnpm, esbuild/Rollup, tsup) | Build-time only; not exposed in published packages |

## Telemetry (no runtime dependency)

Web.UI is pure client-side substrate; it does not emit operational telemetry to Pulse. The consuming PDR's runtime is what gets observed.

## Downstream Consumers (Planned)

| Node | Contract Used | Status |
|------|---------------|--------|
| **HoneyDrunk.Studios** | `@honeydrunk/web-ui-tokens` (JSON + CSS variables), `@honeydrunk/web-ui-css` | Studios is the first named consumer. Migration packet follows after `0.1.0` publishes. Studios' existing informal tokens are formalized into the first Web.UI release, so the migration is mechanical. |
| **HoneyDrunk.Notify.Cloud (admin)** | `@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css` (and `HoneyDrunk.Web.UI.Blazor` if/when admin surface demands components beyond tokens + CSS) | Blazor admin consumes tokens + CSS at Phase 2. Most Blazor admin surfaces need no component package. |
| **PDR-driven consumer apps (Hearth, Lately, Currents, Curiosities)** | `@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, `@honeydrunk/web-ui-react` (when Phase 2 components ship); `@honeydrunk/web-ui-native` (when Phase 4 mobile components ship) | Each PDR-driven app's first scaffolding packet consumes Web.UI. Each PDR's standup ADR will commit its specific edges. |

## Boundary Notes

- Downstream Nodes consume the published npm / NuGet packages only — never the repo source directly, never a workspace symlink in production.
- Web.UI runs **no host process** at v1. It is a published-package substrate, not a service. No managed identity, no Container App, no Azure Function, no Key Vault. The repo is library-only.
- The `@honeydrunk` npm scope is org-verified at packet 03 (human-only). All Web.UI npm packages publish under that scope. The NuGet `HoneyDrunk.Web.UI.Blazor` package publishes under the existing Grid NuGet identity (same OIDC federated credential pattern as other Grid NuGet packages).
- Per-PDR consumer overrides flow one-way through standard CSS-variable cascade. Web.UI does not consume consumer overrides back into the canonical token set.

## Canary Coverage Required

Before any Web.UI code is considered production-ready:

- `web-ui-tokens.test` → exports a `DesignTokens` JSON object that matches the shape contracted in `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md` (structural assertion that the keys exist; values are intentionally flexible to support future palette rebrands).
- `web-ui-css.test` → the published `.css` file contains the `hd-` prefixed reset selectors and the documented utility class taxonomy.
- `web-ui-react.test` (when Phase 2 ships) → each component implements the `ComponentContract` design specification (variant/state/a11y coverage).
- Cross-PDR brand-coherence canary → manual; each consumer's first scaffolding packet asserts that it consumes Web.UI tokens via the documented CSS-variable names.
```

#### `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md` (new)

This file captures Studios' informal tokens as the starting point for `@honeydrunk/web-ui-tokens`'s first release. Studios is the first consumer per ADR-0071 D3, and its existing tokens are formalized into the first Web.UI release. Packet 04 references this file as the source of truth for the initial tokens JSON.

```markdown
# Studios Informal Tokens Inventory

**Purpose:** Capture the design tokens Studios currently uses informally so packet 04's scaffolding agent has a concrete starting point for `@honeydrunk/web-ui-tokens`'s first release. Once tokens publish, Studios migrates to consume them via a follow-up packet (out of scope here).

**Caveat:** Studios pre-dates Web.UI. The "tokens" below are partly literal CSS variables Studios has declared and partly observable patterns (recurring colors, spacings, type sizes) in Studios' codebase. The scaffolding agent should treat this as the **shape** of what to formalize, not a verbatim copy — equivalent token-name normalization (e.g., Studios' `neonPink` → Web.UI's `--hd-color-accent-pink` with a semantic alias) is expected.

## Sector colors (from `constitution/sectors.md`)

These are already in Studios in some form, and they're load-bearing for the `/grid` WebGL visualization. Web.UI tokens MUST preserve them:

| Sector | Token name (proposed) | Hex value |
|--------|----------------------|-----------|
| Core | `--hd-color-sector-core` | `#7B61FF` (violetFlux) |
| Ops | `--hd-color-sector-ops` | `#FF8C00` (cyberOrange) |
| Meta | `--hd-color-sector-meta` | `#FFFF00` (neonYellow) |
| HoneyNet | `--hd-color-sector-honeynet` | `#00FF41` (matrixGreen) |
| Creator | `--hd-color-sector-creator` | `#14B8A6` (chromeTeal) |
| Market | `--hd-color-sector-market` | `#F5B700` (aurumGold) |
| HoneyPlay | `--hd-color-sector-honeyplay` | `#FF2A6D` (neonPink) |
| Cyberware | `--hd-color-sector-cyberware` | `#00D1FF` (electricBlue) |
| AI | `--hd-color-sector-ai` | `#D946EF` (synthMagenta) |

Tokens JSON shape:

```json
{
  "color": {
    "sector": {
      "core": "#7B61FF",
      "ops": "#FF8C00",
      "meta": "#FFFF00",
      "honeynet": "#00FF41",
      "creator": "#14B8A6",
      "market": "#F5B700",
      "honeyplay": "#FF2A6D",
      "cyberware": "#00D1FF",
      "ai": "#D946EF"
    }
  }
}
```

## Other categories Studios uses

Studios' codebase additionally exposes informal patterns for:

- **Neutral palette** — backgrounds, text, surfaces. Likely a 0-900 numeric scale (Tailwind-shaped).
- **Spacing** — 4px-based scale per the broad Grid convention (4, 8, 12, 16, 24, 32, 48, 64, 96).
- **Typography** — font family (likely a sans-serif default + monospace), size scale (xs/sm/base/lg/xl/2xl/3xl/4xl/5xl), weight scale (regular/medium/semibold/bold), line-height scale.
- **Radii** — none / sm / md / lg / full.
- **Shadows** — sm / md / lg / xl elevation scale.
- **Motion** — duration tokens (fast/normal/slow) and easing tokens (standard/in/out/inout).
- **Breakpoints** — mobile / tablet / desktop / wide.
- **Z-index scale** — base / dropdown / modal / toast / tooltip.

**Action for packet 04's scaffolding agent:** Inspect Studios' codebase at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Studios/` for the actual values currently in use (Tailwind config, CSS custom properties, etc.) and capture them as the v0.1.0 tokens JSON. The sector-color block above is **mandatory** — it must round-trip identically. The other categories are recommended starting shapes; capture actuals where Studios has them and document any synthesized defaults where it does not (the v0.1.0 release is allowed to introduce sensible defaults; a follow-up Studios migration packet reconciles any drift).

## Migration shape (Studios-side follow-up packet)

Out of scope for this initiative. After `@honeydrunk/web-ui-tokens 0.1.0` publishes:

1. Add `@honeydrunk/web-ui-tokens` as a Studios dependency.
2. Replace Studios' informal CSS-variable declarations with the import from `@honeydrunk/web-ui-tokens/css/variables.css`.
3. Replace Studios' Tailwind config color-palette block with the import from `@honeydrunk/web-ui-tokens/json/tokens.json` (or the Tailwind preset if one ships).
4. Verify `/grid` WebGL visualization renders identically (sector colors round-trip).
5. Ship.

The migration is a single Studios-side PR. It is **not** in this initiative — it lives in a follow-up packet against the Studios repo once Web.UI 0.1.0 publishes.
```

### `CHANGELOG.md` (Architecture repo)

Append to the current in-progress dated SemVer section (per memory `feedback_no_unreleased_commits`):

`Architecture: Register HoneyDrunk.Web.UI standup decisions (ADR-0071) in catalogs. Add honeydrunk-web-ui to nodes.json (Creator sector, cluster=visualization, signal=Seed), relationships.json (zero consumes; Studios + Notify.Cloud as consumed_by_planned), grid-health.json (version 0.0.0, three active_blockers), modules.json (five package entries — tokens + CSS + react + blazor + native — all at 0.0.0 pre-scaffold), contracts.json (DesignTokens + TokensCssVariables + PrimitiveCss + ComponentContract). Anchor the Creator sector in constitution/sectors.md (Web.UI as the first row, "No real Nodes yet" placeholder removed). Add tech-stack.md Frontend section + Planned Nodes row. Add Q2 2026 roadmap bullet and active-initiatives In Progress entry. Create repos/HoneyDrunk.Web.UI/ context folder (overview, boundaries, invariants, integration-points) matching the Studios template; also capture Studios' informal tokens as studios-tokens-inventory.md for packet 04's scaffolding reference.`

## Affected Files

- `catalogs/nodes.json` (add `honeydrunk-web-ui` block)
- `catalogs/relationships.json` (add `honeydrunk-web-ui` block; amend `honeydrunk-studios.consumes_planned` and `honeydrunk-notify-cloud.consumes_planned` if Notify.Cloud Node exists in catalogs at edit time)
- `catalogs/grid-health.json` (add row, bump `summary` counts)
- `catalogs/modules.json` (5 new entries — tokens, css, react, blazor, native — all at 0.0.0)
- `catalogs/contracts.json` (new `honeydrunk-web-ui` block)
- `constitution/sectors.md` (Creator-sector anchor — table replaces placeholder line)
- `infrastructure/reference/tech-stack.md` (Frontend section + Planned Nodes row)
- `initiatives/roadmap.md` (Q2 2026 bullet)
- `initiatives/active-initiatives.md` (In Progress entry)
- `repos/HoneyDrunk.Web.UI/overview.md` (new)
- `repos/HoneyDrunk.Web.UI/boundaries.md` (new)
- `repos/HoneyDrunk.Web.UI/invariants.md` (new)
- `repos/HoneyDrunk.Web.UI/integration-points.md` (new)
- `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md` (new — references for packet 04)
- `CHANGELOG.md` (entry under the current dated SemVer-bumped section)

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules.
- [x] No new design decision — every catalog entry / context file is derived from ADR-0071's decisions and the `## If Accepted` checklist.
- [x] `cluster: "visualization"` matches existing taxonomy (Studios precedent) — `frontend` is **not** in the allowed cluster values and would invent a new one.
- [x] `consumes: []` for Web.UI per ADR-0071 D9 (zero runtime dependency on Grid Nodes). This is the load-bearing posture, not an oversight.
- [x] `consumed_by_planned` lists only existing Node ids — speculative PDR-driven app Nodes (hearth/lately/etc.) are not invented; each PDR-driven app's standup ADR will add its own edge.
- [x] No edit to ADR-0071's Status header. Status stays Proposed; the flip is post-merge housekeeping.

## Acceptance Criteria

- [ ] `catalogs/nodes.json` carries a new `honeydrunk-web-ui` block with `sector: "Creator"`, `signal: "Seed"`, `cluster: "visualization"` (NOT `"frontend"` — that value is not in the existing cluster taxonomy), full `long_description` per the block above.
- [ ] `catalogs/relationships.json` carries a new `honeydrunk-web-ui` block with `consumes: []` (empty per ADR-0071 D9), `consumed_by_planned` listing only existing Node ids (Studios; Notify.Cloud if present).
- [ ] `honeydrunk-studios` block in `catalogs/relationships.json` has `"honeydrunk-web-ui"` appended to its `consumes_planned` (creating the array if it does not already exist).
- [ ] `catalogs/grid-health.json` carries a new `honeydrunk-web-ui` row at `version: "0.0.0"`, `canary_status: "none"`, three `active_blockers` entries naming packet 03 (repo creation), packet 04 (scaffold), and npm scope verification. `summary.blocked_nodes`, `summary.total_nodes`, `summary.seed`, and `summary.canary_none` bumped by 1.
- [ ] `catalogs/modules.json` has five new entries: `web-ui-tokens`, `web-ui-css`, `web-ui-react`, `web-ui-blazor`, `web-ui-native` — all at `version: "0.0.0"` pre-scaffold.
- [ ] `catalogs/contracts.json` carries a new `honeydrunk-web-ui` block with `package: "@honeydrunk/web-ui-tokens"`, `status: "seed"`, and four contract types: `DesignTokens`, `TokensCssVariables`, `PrimitiveCss`, `ComponentContract`.
- [ ] `constitution/sectors.md` Creator-sector section has its "No real Nodes yet" placeholder replaced with a table containing the Web.UI row at `Signal: Seed`. Section intro paragraph updated to name design substrate as Creator's role.
- [ ] `infrastructure/reference/tech-stack.md` carries a Frontend section (or extends an existing one) with React/Next.js/TypeScript/pnpm rows naming Web.UI as the consumer.
- [ ] `infrastructure/reference/tech-stack.md` Planned Nodes (no code yet) table has a Web.UI row.
- [ ] `initiatives/roadmap.md` Q2 2026 section has a Web.UI Standup bullet.
- [ ] `initiatives/active-initiatives.md` has a new "ADR-0071 HoneyDrunk.Web.UI Standup" In Progress entry with the five Tracking checkboxes and the dated Sync line.
- [ ] `repos/HoneyDrunk.Web.UI/` folder created with five files: `overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md`, `studios-tokens-inventory.md` — all per the content blocks above.
- [ ] `studios-tokens-inventory.md` explicitly lists the 9 sector colors with hex values matching `constitution/sectors.md` exactly. Studios' migration depends on these round-tripping.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section describing the catalog and context-folder additions (not under `## Unreleased`).
- [ ] PR body explicitly notes: (1) zero catalog drift introduced by this packet (every cited file was actually edited); (2) `cluster: "visualization"` chosen (matches Studios precedent; `frontend` is not in the taxonomy); (3) Studios tokens inventory captured for packet 04's reference; (4) ADR-0071 Status stays Proposed.

## Human Prerequisites

None. This packet is pure documentation/catalog work — no portal steps, no manual deploy-time actions, no secrets to seed.

## Dependencies

None. This is the leading packet for the initiative — it depends only on ADR-0071 itself being on disk in `Proposed` state (which it is at scoping time).

## Labels

`chore`, `tier-2`, `architecture`, `web-ui`, `adr-0071`

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — New Node ⇒ new context-folder entry here; new repo created by packet 03.

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — This packet's content is finalized at filing; the substituted invariant numbers landed by packet 02 do not require edits to this packet (packet 02 handles the cross-reference substitution on `repos/HoneyDrunk.Web.UI/invariants.md`).

## Referenced ADR Decisions

**ADR-0071 D1 (Web.UI is the Creator sector's owner of design tokens, primitive CSS, and component contracts):** This packet registers the Node entry and contracts surface in the catalogs and authors the per-repo context folder reflecting D1's ownership statement.

**ADR-0071 D2 (Sector placement — Creator anchor):** The `constitution/sectors.md` edit replaces the placeholder line with Web.UI as the first Creator-sector row.

**ADR-0071 D3 (Web.UI is consumed by Studios — not folded into Studios):** The relationships entry has `consumed_by_planned: ["honeydrunk-studios", ...]` and Studios' `consumes_planned` gains the Web.UI edge — the inversion is encoded in catalog form.

**ADR-0071 D6 (Package layout):** The five `modules.json` entries reflect the package families per D6 — tokens + CSS at standup; React + Blazor + Native as placeholders for Phase 2/3/4.

**ADR-0071 D9 (Web.UI has no runtime dependency on any Grid Node):** The `consumes: []` empty array in relationships.json encodes the load-bearing posture. This is the substrate property the constitutional invariant in packet 02 enforces.

**Memory `project_repos_public_by_default`:** Web.UI repo is public by default — design substrate is exactly the kind of build-in-public surface the Grid licenses; no carve-out applies. Packet 03 handles the repo-creation step with Visibility = Public.

**Memory `feedback_no_unreleased_commits`:** CHANGELOG entry lands under the current dated SemVer-bumped section, not under `## Unreleased`.

## Agent Handoff

**Objective:** Register `HoneyDrunk.Web.UI` in every catalog file, anchor the Creator sector in `constitution/sectors.md`, add tech-stack/roadmap/active-initiatives entries, create the `repos/HoneyDrunk.Web.UI/` context folder, and capture Studios' informal tokens as a starting reference for packet 04. This is the Wave-1 documentation/catalog landing; the actual code work (npm packages, monorepo, CI) happens in packet 04 against a different repo.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Land the catalog and context surface for `HoneyDrunk.Web.UI` so the scaffold packet (packet 04 of this initiative) has its `node:` frontmatter, in-Architecture context-folder cross-references, and tokens-inventory starting point all in place.
- Feature: ADR-0071 standup initiative — this is the documentation side of Wave 1.
- ADRs: ADR-0071 (this packet realizes its catalog and context-folder commitments).

**Acceptance Criteria:** As listed above.

**Dependencies:** None — this is the leading packet in the initiative. ADR-0071 itself is on disk at `Proposed` status; no other prereqs.

**Constraints:**

- **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Web.UI is a new Node, so it gets a new repo (created by packet 03) and a new context-folder entry (created here).
- **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — This packet's body is finalized at filing; packet 02 handles cross-reference substitution.
- **`cluster: "visualization"` not `"frontend"`.** The existing `nodes.json` taxonomy does not include `frontend`. The allowed values are: `foundation`, `security`, `observability`, `infrastructure`, `orchestration`, `governance`, `visualization`, `cognition`, `quality`, `knowledge`. `visualization` matches the Studios precedent and is the closest semantic match for a design-substrate Node. Inventing a new cluster value would be a catalog-shape violation.
- **`consumes: []` is correct.** Per ADR-0071 D9, Web.UI has no runtime dependency on any Grid Node. The empty array is the load-bearing posture, not an oversight. Do not "fix" this by adding a Kernel reference.
- **Do not list non-existent Node ids in `consumed_by_planned`.** The four queued consumer-app PDR Nodes (Hearth, Lately, Currents, Curiosities) do not yet exist in `nodes.json` — adding them here would invent ids. Each PDR-driven app's standup ADR adds its own edge bidirectionally.
- **No edit to ADR-0071 Status.** Status stays Proposed throughout this initiative; the flip is post-merge housekeeping.
- **Sector-color round-trip is mandatory.** `studios-tokens-inventory.md` lists the 9 sector colors with hex values matching `constitution/sectors.md` exactly. If `sectors.md` is rebranded in the future, the tokens inventory needs corresponding update — but at scoping time the round-trip is exact.

**Key Files:**
- `catalogs/nodes.json` — append `honeydrunk-web-ui` block
- `catalogs/relationships.json` — append `honeydrunk-web-ui` block; amend `honeydrunk-studios` (and `honeydrunk-notify-cloud` if present) `consumes_planned`
- `catalogs/grid-health.json` — append row; bump summary counts
- `catalogs/modules.json` — append 5 module entries at 0.0.0
- `catalogs/contracts.json` — append `honeydrunk-web-ui` contracts block
- `constitution/sectors.md` — Creator-sector anchor (table replaces placeholder)
- `infrastructure/reference/tech-stack.md` — Frontend section + Planned Nodes row
- `initiatives/roadmap.md` — Q2 2026 bullet
- `initiatives/active-initiatives.md` — In Progress entry
- `repos/HoneyDrunk.Web.UI/` — 5 new files: overview, boundaries, invariants, integration-points, studios-tokens-inventory
- `CHANGELOG.md` — entry under current dated SemVer section

**Contracts:**
- This packet does not author any new contracts. It registers ADR-0071's already-decided contracts in the catalog. The actual `DesignTokens` JSON schema, `TokensCssVariables` CSS file, and `PrimitiveCss` bundle are authored in packet 04 (the scaffold).
