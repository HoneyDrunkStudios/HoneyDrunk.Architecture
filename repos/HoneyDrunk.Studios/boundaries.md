# HoneyDrunk.Studios — Boundaries

## What Studios Owns

- The public marketing surface for HoneyDrunk Studios — landing, manifesto, charter framing, story
- The Grid visualization at `/grid` (Three.js / WebGL)
- The public ADR / PDR / BDR / Node / Sector / roadmap browsers
- Studios-specific copy, brand voice, marketing content
- The www DNS records and edge config for the public domain (per [ADR-0029](../../adrs/ADR-0029-cloudflare-dns-and-edge-platform.md))
- The Studios-specific design implementation (page templates, animation, 3D scenes) on top of `HoneyDrunk.Web.UI` tokens and primitives

## What Studios Does NOT Own

- **The shared frontend design system** — [`HoneyDrunk.Web.UI`](../../adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md). Studios consumes from it; it does not host it. Tokens, primitive CSS, and design contracts live in Web.UI per ADR-0071 D3.
- **Per-Node standalone docs sites** — those run on Docusaurus per [ADR-0075](../../adrs/ADR-0075-documentation-tooling.md). Studios is not a docs site.
- **Notify Cloud's tenant-operator admin UI** — that is its own product surface per [ADR-0027](../../adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md), likely Blazor per [ADR-0070](../../adrs/ADR-0070-frontend-platform-stack.md) D2.
- **Identity / accounts** — Studios is a public read-only marketing and visualization surface. There are no user accounts on Studios itself; any "log in" affordance routes to a per-product surface.
- **The Grid catalogs** — those are owned by `HoneyDrunkStudios/HoneyDrunk.Architecture`. Studios reads them at build time; it does not edit them.
- **AI-driven content generation runtime** — Studios does not host agents. If AI is used to author copy, that happens upstream (in editorial workflow), not in the running Studios app.
- **Per-product analytics** — Studios may emit page-level analytics (per the future product-analytics ADR), but does not host product-analytics infrastructure for other Nodes.

## Boundary Decision Tests

- **"Should this content live in Studios or in a Docusaurus docs site?"** — If the content is marketing, manifesto, brand, or visualization-driven, Studios. If it is technical reference (API docs, integration guides, SDK readmes), Docusaurus.
- **"Should this UI component live in Studios or in Web.UI?"** — If it's reusable across consumer-app surfaces (Button, Input, Card, Toast), Web.UI. If it's a Studios-specific composition (a Hero section, the `/grid` WebGL scene, a roadmap page layout), Studios.
- **"Should this be a Studios page or its own Node?"** — A Studios page surfaces Grid information for external consumption. A separate Node ships a product. Anything with a runtime contract, persistent state, or authenticated users is its own Node, not a Studios page.
