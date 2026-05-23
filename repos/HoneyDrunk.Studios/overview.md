# HoneyDrunk.Studios — Overview

**Sector:** Meta
**Signal:** Live
**Stack:** Next.js 16 · React 19 · Three.js (WebGL)
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Studios`
**Public surface:** [honeydrunkstudios.com](https://honeydrunkstudios.com)

## Purpose

The Grid's public-facing website and live Grid visualizer. Renders the Hive — Nodes, Sectors, signals, ADRs, PDRs, BDRs, roadmap — for an external audience, with a WebGL-driven neon-lit visualization at `/grid`. It is the build-in-public surface ([`constitution/charter.md`](../../constitution/charter.md) §"Build-in-public, honestly") rendered as a product.

It is one product Node among many — **not** a baseline, **not** the design-system home, **not** a docs site. The shared frontend design system lives in [`HoneyDrunk.Web.UI`](../../adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md). Per-Node standalone docs sites live in Docusaurus per [ADR-0075](../../adrs/ADR-0075-documentation-tooling.md). Studios consumes from those substrates; it does not host them.

## Key surfaces

| Surface | Purpose |
|---------|---------|
| `/` | Studio landing — manifesto, charter framing, current focus |
| `/grid` | Live WebGL visualization of the Grid (Three.js) — Nodes by Sector, real-time signal indicators, click-through to details |
| `/nodes` | Browsable Node catalog — pulls from the Grid catalogs published by the Architecture repo |
| `/sectors` | Sector pages with cluster maps |
| `/adrs` | Public ADR browser |
| `/pdrs` | Public PDR browser |
| `/roadmap` | Public roadmap surface |
| `/incidents` | Public post-mortem feed (per future ADR for public-post-mortem cadence) |

## Stack rationale

- **Next.js 16** is the React metaframework chosen for SSR/SSG of marketing content and the Node/ADR browser pages.
- **React 19** matches [ADR-0070](../../adrs/ADR-0070-frontend-platform-stack.md) D1's consumer-web default.
- **Three.js** powers the `/grid` WebGL visualization. This is a Studios-specific dependency; the shared `HoneyDrunk.Web.UI` design system does not opinionate on 3D / canvas runtimes.

Studios pre-dates [ADR-0070](../../adrs/ADR-0070-frontend-platform-stack.md); the stack ADR ratifies Studios' existing choices rather than forcing a migration.

## Relationship to Web.UI

Studios is the **first consumer** of [`HoneyDrunk.Web.UI`](../../adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md) tokens and primitives, not its host. Per ADR-0071 D3, Studios is "a product, not a baseline" — design tokens migrate **into** Studios from Web.UI's first release, not the other way around.

## Data sources

Studios is a **read-only consumer** of Grid data published by the Architecture repo:

- `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/services.json`, `catalogs/contracts.json`, `catalogs/grid-health.json`
- `adrs/`, `pdrs/`, `business/decisions/`
- `initiatives/roadmap.md`, `initiatives/releases.md`

Studios does not write back to Architecture and does not call any Grid runtime contract. The visualization is statically built from catalogs at deploy time, with optional client-side enhancement.
