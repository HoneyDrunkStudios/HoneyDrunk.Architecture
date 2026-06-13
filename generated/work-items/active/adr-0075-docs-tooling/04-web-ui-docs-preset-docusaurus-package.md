---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.UI
labels: ["feature", "tier-2", "creator", "adr-0075", "wave-3", "parked"]
dependencies: ["work-item:00"]
adrs: ["ADR-0075", "ADR-0071", "ADR-0070"]
accepts: ["ADR-0075"]
wave: 3
initiative: adr-0075-docs-tooling
node: honeydrunk-web-ui
---

# Build the @honeydrunk/docs-preset Docusaurus preset consuming Web.UI tokens

## Summary
Build `@honeydrunk/docs-preset` — the shared Docusaurus preset that per-Node docs sites consume for cross-Grid visual coherence per ADR-0075 D2. The preset wraps `@docusaurus/preset-classic`, imports `@honeydrunk/web-ui-tokens` for color/spacing/typography variables, and bundles a small set of Grid-aligned navigation/footer/theme defaults. Published to npm under the `@honeydrunk` scope alongside the other Web.UI packages per ADR-0071 D6.

**Status: PARKED.** This packet is blocked by the Web.UI Node standup (ADR-0071). The Web.UI Node has no entry in `catalogs/nodes.json` today; `@honeydrunk/web-ui-tokens` has not yet shipped its 0.x release. **Do not execute this packet until** ADR-0071's scaffold packet has merged AND `@honeydrunk/web-ui-tokens` has published at least its 0.x release. When those conditions are met, this packet becomes the next step (estimated: hours of work).

## Context
ADR-0075 D2 commits Docusaurus 3.x as the canonical standalone-docs-site SSG and names a shared preset for cross-Node coherence:

> Shared Docusaurus theme / preset across Grid doc sites — a small `@honeydrunk/docs-preset` package (per the Web.UI Node's monorepo posture per ADR-0071 D6 if it makes sense to home it there, or as a standalone package) carries the Grid's design tokens, fonts, navigation patterns, and footer. Per-Node sites consume the preset for cross-Node coherence.

ADR-0075 D5 commits the tokens consumption:

> Docusaurus preset (per D2) imports Web.UI tokens and component primitives. Per-Node docs sites visually align with Studios, Notify Cloud admin, and every consumer-PDR web surface.

ADR-0075's Follow-up Work confirms the homing decision:

> Build the `@honeydrunk/docs-preset` Docusaurus preset (likely housed in HoneyDrunk.Web.UI per ADR-0071 D6, packaged separately if it makes sense).

**Why PARKED.** ADR-0071 is **Proposed** at the time of ADR-0075's acceptance. The Web.UI Node does not exist in `catalogs/nodes.json`. ADR-0071's D6 names the package layout (`@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, `@honeydrunk/web-ui-react`, optional `@honeydrunk/web-ui-native`, optional `HoneyDrunk.Web.UI.Blazor`) and commits to a monorepo posture (the strong default, pnpm workspaces / Turbo / Nx). The `@honeydrunk/docs-preset` belongs in that monorepo. **Until ADR-0071's scaffold packet lands and `@honeydrunk/web-ui-tokens` ships its 0.x release, this packet cannot proceed** — there are no tokens to import, and the monorepo doesn't exist to add a package to.

**Resume criteria — both must be true before executing:**
1. ADR-0071 is Accepted, and its scaffold packet has merged. The `HoneyDrunk.Web.UI` repo exists; the monorepo posture is committed.
2. `@honeydrunk/web-ui-tokens` has published at least its 0.x release on npm under the `@honeydrunk` scope.

When both conditions are met, the agent picking up this packet should verify them, update the issue body to "Unparked: {date}", and proceed with the implementation per the Proposed Implementation below.

**Repo-shape ground truth (read at unpark time, not at file time).**
- ADR-0071 D6 commits the monorepo posture with pnpm workspaces / Turbo / Nx. `@honeydrunk/docs-preset` lands in the monorepo as a sibling package to `@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, etc.
- The npm scope is `@honeydrunk`. Publishing convention per ADR-0071 D7 matches semver discipline applied to JS packages: additive preset content is minor, breaking preset config changes are major.

**The preset's content (verbatim-in-substance from ADR-0075 D2 + D5).**
- **Wraps `@docusaurus/preset-classic`.** The preset is a small wrapper, not a fork. The Docusaurus 3.x classic preset stays the substrate; this preset layers Grid conventions on top.
- **Imports `@honeydrunk/web-ui-tokens`.** Color, spacing, typography, radii, shadows, motion, breakpoints, z-index. The preset exposes these as Docusaurus theme variables and CSS custom properties so consuming docs sites get Grid-aligned styling by default.
- **Bundles a Grid navigation pattern.** The Docusaurus navbar configuration default — site logo (from a per-site config), per-Node title, links to honeydrunkstudios.com, GitHub repo link, optional `/docs/` versioned-docs dropdown.
- **Bundles a Grid footer.** Copyright, links to Studios, the Grid Status page (when one exists), an optional "build-in-public" link to the manifesto per `constitution/manifesto.md`.
- **Bundles a small font stack.** Aligned with the Web.UI tokens' typography choices. Self-hosted if Web.UI commits a font; otherwise system font stack.
- **MDX support** (per ADR-0075 D2) — MDX is on by default in Docusaurus 3.x classic; the preset does not disable it.
- **Versioned-docs hook** (per ADR-0075 D2) — Docusaurus's versioning model is supported by the classic preset; this preset does not override it.
- **i18n hook** (per ADR-0075 D2 + ADR-0075 D6 deferral) — the classic preset's i18n configuration is supported; the preset does not commit a translation workflow (deferred to a future `HoneyDrunk.Locale` Node per ADR-0075 D6).
- **Algolia DocSearch configuration** (per ADR-0075 D2) — the preset accepts an Algolia DocSearch config and wires it into Docusaurus's classic-preset search. Free for OSS Grid Nodes; the per-Node docs-site standup provides its app-id / search-key.

**License.** MIT, matching `@honeydrunk/web-ui-tokens` and the rest of the Web.UI packages.

This packet is JS/npm work — no .NET project, no NuGet, no Azure resource.

## Scope
- A new package `@honeydrunk/docs-preset` in the `HoneyDrunk.Web.UI` monorepo, sibling to `@honeydrunk/web-ui-tokens` / `@honeydrunk/web-ui-css` / etc. per ADR-0071 D6.
- The preset wraps `@docusaurus/preset-classic` (Docusaurus 3.x), imports `@honeydrunk/web-ui-tokens`, and bundles the Grid navbar/footer/font defaults.
- Package metadata: name `@honeydrunk/docs-preset`, MIT license, initial 0.x release per ADR-0071 D7.
- Per-package CHANGELOG.md and README.md per the Web.UI monorepo convention.
- (At unpark time) Update `catalogs/modules.json` to add the `@honeydrunk/docs-preset` package row under the Web.UI Node — only if ADR-0071's scaffold packet did not already do this.

## Proposed Implementation
(Execute only after the resume criteria are met.)

1. **Verify resume criteria.** ADR-0071 is Accepted, its scaffold packet has merged, `HoneyDrunk.Web.UI` repo exists, the monorepo posture is in place, and `@honeydrunk/web-ui-tokens` has published its 0.x release. If any of these is false, leave the issue parked.
2. **Create the package directory** under the Web.UI monorepo at the location matching ADR-0071's monorepo layout (e.g., `packages/docs-preset/` or `apps/docs-preset/` — match what the scaffold packet established).
3. **`package.json`:**
   - `"name": "@honeydrunk/docs-preset"`, `"version": "0.1.0"` (or whatever initial 0.x version aligns with the Web.UI monorepo's release strategy)
   - `"license": "MIT"`
   - `"main": "src/index.js"` (or `src/index.ts` if the monorepo uses TypeScript per ADR-0071/ADR-0070)
   - `"peerDependencies"`:
     - `"@docusaurus/core": "^3.0.0"`
     - `"@docusaurus/preset-classic": "^3.0.0"`
     - `"react": "^18.0.0"`
     - `"react-dom": "^18.0.0"`
   - `"dependencies"`:
     - `"@honeydrunk/web-ui-tokens": "workspace:*"` (workspace protocol per the monorepo tooling — pnpm/Yarn/Turbo).
   - `"keywords"`, `"repository"`, `"homepage"` per the Web.UI package convention.
4. **`src/index.{js,ts}`:** The preset entry point. Exports a function `preset(context, options)` that:
   - Forwards `options` to `@docusaurus/preset-classic` so the classic preset's configuration surface remains usable.
   - Merges Grid navbar/footer defaults into the consumer's `themeConfig`. Per-site overrides take precedence; the preset provides defaults only.
   - Injects the `@honeydrunk/web-ui-tokens` CSS custom properties via the `presets.theme.customCss` configuration.
   - Wires Algolia DocSearch options if provided.
5. **CSS bridge.** Add a small `src/theme/custom.css` that maps Web.UI token CSS custom properties onto Docusaurus's `--ifm-*` variables (`--ifm-color-primary`, `--ifm-font-family-base`, etc.) so Docusaurus's classic theme inherits Grid styling automatically.
6. **Defaults.** The preset's defaults must be the four committed Grid conventions:
   - Navbar with Grid links (Studios, GitHub).
   - Footer with Grid links (Studios, manifesto, optional Status).
   - Web.UI typography stack.
   - Algolia DocSearch wiring (configurable; off by default).
7. **README.md** — per the Web.UI monorepo's README convention. Quick-start showing how a per-Node docs site consumes the preset (e.g., a `docusaurus.config.js` snippet referencing `@honeydrunk/docs-preset`).
8. **CHANGELOG.md** — initial 0.1.0 entry citing ADR-0075 D2 and ADR-0071.
9. **Tests.** A small smoke test that imports the preset and verifies it loads without runtime error against `@docusaurus/preset-classic`. Match the Web.UI monorepo's test stack (the scaffold packet should have established this).
10. **CI.** Match the existing Web.UI monorepo CI — the new package builds, lints, and tests as part of the workspace's standard CI invocation. Per ADR-0012's CI/CD control-plane stance.
11. **Optional `catalogs/modules.json` update** in `HoneyDrunk.Architecture` — only if ADR-0071's scaffold packet did not already register `@honeydrunk/docs-preset`. This is a cross-repo follow-on PR in Architecture, not part of this packet's primary PR.

## Affected Files
(At unpark time — adjust if Web.UI monorepo conventions established by ADR-0071's scaffold differ.)
- `HoneyDrunk.Web.UI/packages/docs-preset/package.json` (new)
- `HoneyDrunk.Web.UI/packages/docs-preset/src/index.{js,ts}` (new)
- `HoneyDrunk.Web.UI/packages/docs-preset/src/theme/custom.css` (new)
- `HoneyDrunk.Web.UI/packages/docs-preset/README.md` (new)
- `HoneyDrunk.Web.UI/packages/docs-preset/CHANGELOG.md` (new)
- `HoneyDrunk.Web.UI/packages/docs-preset/__tests__/...` (new)
- Possibly the monorepo's root `package.json` / `pnpm-workspace.yaml` / `turbo.json` to register the new package.
- Optionally `HoneyDrunk.Architecture/catalogs/modules.json` (cross-repo, follow-on PR).

## NuGet Dependencies
None. This is an npm/JS package; no .NET project is created or modified.

## Boundary Check
- [x] `HoneyDrunk.Web.UI` is the right repo per ADR-0075 Follow-up Work ("likely housed in HoneyDrunk.Web.UI per ADR-0071 D6") and per ADR-0071 D6 (Web.UI monorepo posture).
- [x] The preset depends on `@honeydrunk/web-ui-tokens` — the same dependency direction as every other Web.UI consumer. No reverse dependency (Web.UI tokens does not depend on the preset).
- [x] No .NET / NuGet dependency added; this is JS/npm work.
- [x] No cross-Node runtime dependency outside the Web.UI monorepo.

## Acceptance Criteria
- [ ] Resume criteria verified: ADR-0071 is Accepted, the Web.UI Node is stood up (`catalogs/nodes.json` carries a `honeydrunk-web-ui` entry), `@honeydrunk/web-ui-tokens` has published at least its 0.x release
- [ ] A new package `@honeydrunk/docs-preset` exists in the `HoneyDrunk.Web.UI` monorepo at the location matching the established monorepo layout
- [ ] `package.json` declares `@docusaurus/core`, `@docusaurus/preset-classic`, `react`, `react-dom` as peer dependencies; `@honeydrunk/web-ui-tokens` as a workspace dependency
- [ ] The preset wraps `@docusaurus/preset-classic` — the classic preset's configuration surface remains usable
- [ ] The preset imports `@honeydrunk/web-ui-tokens` and maps tokens onto Docusaurus's `--ifm-*` CSS variables for Grid-aligned styling by default
- [ ] Grid navbar/footer defaults are bundled (Studios, GitHub, manifesto, optional Status — per-site overrides take precedence)
- [ ] Algolia DocSearch is wired (off by default; opt-in via preset options)
- [ ] `README.md` documents the preset's quick-start with a `docusaurus.config.js` snippet
- [ ] `CHANGELOG.md` carries an initial 0.x entry citing ADR-0075 D2 and ADR-0071
- [ ] Smoke tests verify the preset loads without runtime error against `@docusaurus/preset-classic`
- [ ] The monorepo's CI builds, lints, and tests the new package as part of standard CI invocation
- [ ] License is MIT per the Web.UI package convention
- [ ] No invariant violation in the package work

## Human Prerequisites
- [ ] **Verify the resume criteria before executing.** ADR-0071 is Accepted; the `HoneyDrunk.Web.UI` repo exists; `@honeydrunk/web-ui-tokens` has published its 0.x release on npm. Until all three are true, this packet stays parked.
- [ ] (At publish time) The `@honeydrunk` npm scope must be claimed and accessible — typically established by ADR-0071's scaffold packet's first publish.

## Referenced ADR Decisions
**ADR-0075 D2 — Docusaurus 3.x is the canonical standalone-docs-site SSG.** Per-Node sites consume a shared preset for cross-Node coherence. The preset carries design tokens, fonts, navigation patterns, and footer.

**ADR-0075 D5 — Both tools consume Web.UI tokens for visual coherence.** The Docusaurus preset imports Web.UI tokens; per-Node docs sites visually align with Studios, Notify Cloud admin, and every consumer-PDR web surface.

**ADR-0075 Follow-up Work — Build the `@honeydrunk/docs-preset` Docusaurus preset.** Likely housed in HoneyDrunk.Web.UI per ADR-0071 D6, packaged separately if it makes sense.

**ADR-0071 D6 — Web.UI monorepo posture.** Web.UI's strong default is a monorepo (pnpm workspaces, Turbo, or Nx); the docs preset is a sibling package to `@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, etc. The npm scope is `@honeydrunk`.

**ADR-0071 D7 — Versioning discipline applied to JS packages.** Additive preset content is minor, breaking preset config changes are major. Pre-1.0 packages do not carry the same compatibility promise per ADR-0035's pre-1.0 disclaimer; this preset starts at 0.x.

**ADR-0070 D1 — React for the Grid's web frontend.** Docusaurus is React-based; the preset reuses the Grid's React-ecosystem alignment.

## Constraints
- **PARKED — do not execute until resume criteria are met.** ADR-0071 must be Accepted; Web.UI Node stood up; `@honeydrunk/web-ui-tokens` published its 0.x release. The resume-criteria check is the first acceptance criterion.
- **Wrap, don't fork.** The preset wraps `@docusaurus/preset-classic`; it does not replace or substantially override classic-preset behavior. Per-site configuration overrides take precedence over preset defaults.
- **MDX, versioned docs, i18n stay on.** Docusaurus 3.x classic-preset defaults for MDX, versioning, and i18n are not disabled by the preset. ADR-0075 D6 defers translation workflows to a future `HoneyDrunk.Locale` Node — the preset accepts i18n config but does not commit to a translation pipeline.
- **MIT license** per the Web.UI package convention.
- **Initial 0.x release** per ADR-0071 D7's pre-1.0 disclaimer.
- **No catalog edit if the scaffold packet already registered the package.** Check first; do not duplicate.

## Labels
`feature`, `tier-2`, `creator`, `adr-0075`, `wave-3`, `parked`

## Agent Handoff

**Objective:** Build `@honeydrunk/docs-preset` — the shared Docusaurus 3.x preset that per-Node docs sites consume for cross-Grid visual coherence.

**Target:** `HoneyDrunk.Web.UI`, branch from `main`.

**Context:**
- Goal: Make standing up a per-Node Docusaurus docs site cheap and Grid-aligned. The preset bundles the conventions so a per-Node site is `extends: @honeydrunk/docs-preset` plus the site's own content.
- Feature: ADR-0075 Documentation Tooling rollout, Wave 3.
- ADRs: ADR-0075 D2/D5 (primary), ADR-0071 D6/D7 (Web.UI monorepo + package versioning), ADR-0070 D1 (React-ecosystem alignment).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0075 should be Accepted before its preset lands.
- **Hard, not-yet-filed dependency:** ADR-0071 Acceptance + scaffold packet + `@honeydrunk/web-ui-tokens` 0.x publish. This packet is **PARKED** until those land. No `dependencies:` edge points at ADR-0071 (it has not been scoped yet); the parked-state framing is the source of truth.

**Constraints:**
- **PARKED.** Verify the resume criteria before executing — ADR-0071 must be Accepted, Web.UI Node stood up, tokens package published.
- Wrap `@docusaurus/preset-classic`, do not fork.
- Web.UI tokens consumed via workspace dependency; no other HoneyDrunk runtime/npm dependency.
- MDX/versioning/i18n stay on (Docusaurus 3.x classic defaults).
- Initial 0.x release per ADR-0071 D7.

**Key Files:**
- `HoneyDrunk.Web.UI/packages/docs-preset/...` (new package; exact path per Web.UI monorepo conventions established by ADR-0071's scaffold)
- Possibly the monorepo's root `package.json` / `pnpm-workspace.yaml` / `turbo.json` to register the new package.

**Contracts:**
- `@honeydrunk/docs-preset` exports a Docusaurus preset function `(context, options) => PresetConfig`. The exact `options` shape is forward-compatible with `@docusaurus/preset-classic`'s shape.
