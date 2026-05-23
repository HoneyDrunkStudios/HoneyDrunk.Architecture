# ADR-0075: Documentation Tooling — Scalar (In-Product OpenAPI) and Docusaurus (Public Docs)

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / cross-cutting

## Context

The Grid has two distinct documentation surfaces and neither has a committed tooling choice:

- **In-product OpenAPI rendering.** Every Node that exposes an HTTP surface (Web.Rest consumers, Notify Cloud's gateway per [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md), the future Identity Node per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md), every consumer-app backend) produces an OpenAPI specification per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md). The spec needs to be **renderable** for developer consumption — both for the operator (debugging) and for external SDK consumers (per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) D8's SDK story). Today the default is Swagger UI (the .NET ecosystem default since 2017), but Swagger UI's UX has aged and its "try it" experience has not kept pace with newer alternatives.
- **Public documentation sites.** Per-Node documentation sites for the broader Grid story — getting-started guides, conceptual explainers, longer-form tutorials — when a Node is mature enough to warrant one. Today: zero Nodes have a public doc site. Studios website is product/marketing-shaped; per-Node docs would be developer-facing and structurally different.

Without an ADR:

- **Each Node that adds an OpenAPI surface picks its renderer independently.** The first picks Swagger UI; the next questions it; per-Node drift accumulates.
- **The first Node to need a public doc site re-derives the question.** GitBook, Docusaurus, MkDocs Material, Astro Starlight, DocFX, plain GitHub Pages — each is a credible-looking option for a solo dev evaluating cold.
- **Cross-Node docs coherence suffers.** If Notify Cloud's docs are on Docusaurus and HoneyDrunk.AI's docs are on MkDocs, every reader navigates two different conventions, two different search UXes, two different theming approaches.

The forcing functions converging now:

- **[ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md)** committed the OpenAPI-spec-as-the-source-of-truth for SDK generation. The OpenAPI document needs a canonical renderer.
- **Notify Cloud GA** is the first commercial product. External developers (tenant operators integrating against the Notify Cloud API) consume the OpenAPI surface; the rendering quality is part of the first-impression for the first paying customer.
- **The Studios website is React** (per existing state and [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1). A future per-Node docs site should align with the React-ecosystem posture; that argues for Docusaurus (React-based) over MkDocs (Python-based).
- **The charter's build-in-public stance** ([`constitution/charter.md`](../constitution/charter.md) §"Build-in-public, honestly") implies the Grid's docs are part of the public artifact, not internal-only. Tooling that produces polished, public-quality docs matters; Swagger UI's "we built this in 2014" feel is the wrong first impression for the Grid's public posture.

This ADR commits the **two-tool split** — Scalar for in-product OpenAPI rendering, Docusaurus for standalone public documentation sites — and is explicit about what is **not** in scope (Studios website is a separate Node and product per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) D3).

## Decision

### D1 — Scalar is the canonical in-product OpenAPI renderer

**Scalar** replaces Swagger UI as the in-product OpenAPI renderer in every Grid Node that exposes an OpenAPI spec.

The committed shape:

- **`Scalar.AspNetCore`** as the .NET package.
- **Standard middleware composition** — `app.MapScalarApiReference()` (or equivalent at the API surface) replaces `UseSwaggerUI()` in every Node that has one.
- **OpenAPI document generation** stays as-is per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) — `Microsoft.AspNetCore.OpenApi` generates the document; Scalar renders it.
- **Per-environment availability**:
  - **dev**: enabled, accessible at `/scalar` (or the path the Node chooses).
  - **staging**: enabled.
  - **prod**: enabled at the Node's discretion. Notify Cloud's public API surface keeps Scalar enabled in prod (external consumers need it); internal-only Nodes (Identity, Audit) may keep it dev/staging-only.

**Why Scalar:**

- **Modern UX.** Clean, fast, dark-mode-by-default, polished "try it" interactions. The 2026 default for new OpenAPI renderers in the broader web ecosystem; Scalar is what new projects choose when starting fresh.
- **First-class .NET integration.** `Scalar.AspNetCore` ships native ASP.NET Core middleware; no JS-side wiring, no separate hosting concern.
- **Performance on large specs.** Notify Cloud's OpenAPI spec will be large (many endpoints, many tenant-aware schemas); Scalar's rendering performance on large specs is markedly better than Swagger UI's.
- **Theming hooks.** Custom CSS and branding align Scalar's appearance with the Grid's design tokens per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) when consumer-facing surfaces want brand-aligned API docs.
- **Permissive license.** MIT-licensed; healthy stewardship; no commercial-license trajectory concerns (matches [ADR-0074](./ADR-0074-testing-library-stack.md)'s license-hygiene principle).
- **AI-assistance gradient.** 2026 AI tools have meaningful pattern recognition on Scalar; the `Scalar.AspNetCore` integration is well-represented in training data.

The negative form: Swagger UI is not the default for new Node OpenAPI surfaces; existing Swagger UI usage in any Node grandfathers and migrates opportunistically (D4).

### D2 — Docusaurus is the canonical public documentation site generator

**Docusaurus** is the canonical static-site generator for standalone public documentation sites — used **when a Node warrants its own doc site**, not for every Node by default.

The committed shape:

- **Docusaurus 3.x** (or current stable major at the time the first site stands up).
- **Per-Node doc sites live in the Node's repo** under a `docs-site/` (or equivalent) folder.
- **Deployed to a per-Node subdomain or path** under `honeydrunkstudios.com` (e.g., `notify-cloud.honeydrunkstudios.com/docs` or `docs.honeydrunkstudios.com/notify-cloud`). The exact URL scheme is a deployment-time decision per the future docs-deployment packet.
- **Shared Docusaurus theme / preset across Grid doc sites** — a small `@honeydrunk/docs-preset` package (per the Web.UI Node's monorepo posture per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) D6 if it makes sense to home it there, or as a standalone package) carries the Grid's design tokens, fonts, navigation patterns, and footer. Per-Node sites consume the preset for cross-Node coherence.

**Why Docusaurus:**

- **React-ecosystem alignment.** Per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1, the Grid's web stack is React. Docusaurus is React-based; theme components, custom pages, and embeddable React widgets compose into doc sites naturally. The operator and AI assistants stay in one ecosystem.
- **Versioned docs are first-class.** Docusaurus's versioning model (per-version directories, automated nav for "v1.x / v2.x / Latest") matches the API-versioning discipline from [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md). When a Node ships v2 of an API, its docs site versions cleanly without manual coordination.
- **Long-running maturity for versioned docs.** Docusaurus has shipped continuously since 2017; the version-2.x rewrite stabilized in 2022; 3.x is the current major. The many-decade horizon ([`constitution/charter.md`](../constitution/charter.md)) is well-served.
- **i18n is built-in.** When the future [`HoneyDrunk.Locale`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) Node lands and consumer surfaces start localizing, Docusaurus's per-locale docs path is the supported pattern.
- **Search via Algolia DocSearch.** Free for open-source Grid Nodes; configurable for private content if needed. The search experience is good out of the box.
- **MDX support.** Markdown + JSX means embedded interactive components (live API demos, configuration calculators, anything React-side) compose into docs.
- **Permissive license.** MIT.

**Why not on every Node:** The Grid does not warrant a per-Node docs site on every Node from day one. Kernel and Vault have `repos/{Node}/overview.md` in the Architecture repo and that is sufficient. A doc site is warranted when:

- A Node has external developer consumers (Notify Cloud's external tenants is the canonical case).
- A Node has a public conceptual surface that overflows `overview.md` (e.g., a hypothetical `HoneyDrunk.Search` Node with multiple provider backings might warrant a doc site to explain the trade-offs).
- An operator-time-saving threshold is hit — repeated questions about a Node from outside the operator suggest a doc site would pay back the build cost.

The default posture: **most Nodes do not have a doc site**; the per-Node `overview.md` / `boundaries.md` / `invariants.md` in the Architecture repo is the canonical Node docs.

### D3 — Studios website is explicitly separate from Docusaurus scope

The Studios website ([repos/HoneyDrunk.Studios/overview.md](../repos/HoneyDrunk.Studios/overview.md)) is **a separate Node and a product surface**, not a docs site. Per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) D3:

> Studios is one product, not a baseline.

Docusaurus's role is documentation site generation; Studios is product/marketing surface generation. The two are deliberately separate:

- **Studios** is brand presentation, project listings, blog, public roadmap, public artifacts (failed-experiments shelf per [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 5.1, post-mortems, manifesto). It is a React site that consumes Web.UI per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md); its tooling is per-product (likely Next.js or Vite per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1).
- **Docusaurus sites** are developer-facing per-Node documentation. Different IA, different audience, different content shape.

A future operator decision may consolidate the two (e.g., "Studios should embed Docusaurus subsections for each Node's docs") — but that decision is product-shape work, not a tooling ADR. This ADR's scope is **the tooling**; the consolidation question is deferred.

### D4 — Migration discipline (Swagger UI → Scalar)

Existing Nodes that ship with Swagger UI (Web.Rest's reference middleware composition, Notify's debug surfaces) are **not retroactively migrated by a cross-cutting campaign**. The discipline matches [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D9 and [ADR-0074](./ADR-0074-testing-library-stack.md) D6:

- **New Nodes use Scalar from day one.**
- **Existing Nodes migrate opportunistically.** When a Node's API surface is being modified for other reasons, Scalar replaces Swagger UI as part of the change.
- **Forced retroactive migration is forbidden.** Per the charter's §"What this charter forbids" item 2 ("architecture-as-procrastination"), mass refactors that re-derive existing-and-working behavior are exactly the kind of work the charter warns against.

The grandfather posture is operationally invisible — Swagger UI still works; existing consumers (the operator, any existing dev-environment tooling) continue functioning until natural migration moments.

### D5 — Versioning and theming alignment with Web.UI

Both Scalar and Docusaurus consume **Web.UI tokens** per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) for visual coherence with the rest of the Grid's web surfaces:

- **Scalar** custom CSS imports Web.UI's CSS variables for color, spacing, typography. Renders the OpenAPI surface in the Grid's visual language.
- **Docusaurus** preset (per D2) imports Web.UI tokens and component primitives. Per-Node docs sites visually align with Studios, Notify Cloud admin, and every consumer-PDR web surface.

The tokens-as-the-cross-stack-shared-layer pattern from [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) D4 extends naturally into the documentation layer.

### D6 — Out of scope

The following are explicitly **not** decided by this ADR:

- **Studios website tooling.** Per D3, Studios is a separate product Node; its tooling is per-product choice within the [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1 React constraint.
- **Internal Architecture-repo docs.** This Architecture repo (`HoneyDrunk.Architecture`) carries `overview.md` / `boundaries.md` / `invariants.md` per Node. Those are Markdown files in this repo and are not republished through Docusaurus today. A future "Lore" Node concept (per [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 2.3) may surface these as a queryable knowledge graph; until then, the Markdown-in-repo model holds.
- **API documentation generation from XML comments.** .NET's XML-doc-comment story is supported by DocFX and similar tools; the Grid does not adopt those today. Per-Node API surface docs come from OpenAPI specs (Scalar) and per-Node README / overview (Markdown), not from generated XML-comment surfaces.
- **Per-Node CHANGELOG aggregation.** Per [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 5.2, a Grid-wide changelog aggregator is a future surface; this ADR does not commit one.
- **Translation / l10n workflow for docs.** Deferred to the future `HoneyDrunk.Locale` Node.
- **Docs hosting platform.** Vercel, Netlify, Cloudflare Pages, Azure Static Web Apps are all credible options. The decision lives at the per-Node docs-deploy packet; Cloudflare Pages aligns with [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md)'s edge posture and is the strong default.
- **Search across all Grid docs (not just per-Node).** A cross-Node docs search surface is a future-state concern; deferred.

## Consequences

### Affected Nodes

- **Every Node with an OpenAPI surface** — adopts Scalar from day one (new Nodes) or opportunistically (existing Nodes per D4). Initial impact: [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) (Notify Cloud gateway), [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) (Identity HTTP surface), [ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md) (Files HTTP surface), Web.Rest reference composition.
- **HoneyDrunk.Notify.Cloud** — the first Node likely to warrant a standalone Docusaurus doc site. Tenant-developer integration docs land in Docusaurus when external-developer demand justifies it.
- **HoneyDrunk.Studios** ([repos/HoneyDrunk.Studios/overview.md](../repos/HoneyDrunk.Studios/overview.md)) — unaffected. Per D3, Studios is a separate product Node; its tooling stays per-product.
- **HoneyDrunk.Web.UI** per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) — Web.UI tokens become the visual baseline for both Scalar customization and Docusaurus theming per D5. The Docusaurus preset (`@honeydrunk/docs-preset`) is a candidate Web.UI Node package.

### Invariants

No new Grid-wide invariants introduced. The following are committed conventions enforced at packet authoring and review:

- **New Nodes with OpenAPI surfaces use Scalar.**
- **Standalone Grid docs sites use Docusaurus.**
- **Per-Node docs default to `overview.md` / `boundaries.md` / `invariants.md` in the Architecture repo**; a Docusaurus site is warranted only when external consumers or operator-time-saving thresholds justify it.
- **Both tools consume Web.UI tokens for visual coherence.**

### Operational Consequences

- **Better first-impression for the Grid's public APIs.** Scalar's modern UX raises the bar for what external developers see when they encounter a Grid API spec. Important for Notify Cloud's first paying tenant.
- **Per-Node docs sites become a real option.** Docusaurus + shared preset means a new doc site is hours of work, not weeks. Lowering the cost makes "should this Node have a docs site?" a real question rather than a never-built default.
- **Cross-Node visual coherence in docs.** Tokens from Web.UI flow into Scalar and Docusaurus; the Grid's visual language carries across product surfaces, admin surfaces, API renderers, and per-Node docs sites.
- **Migration cost is bounded.** Per D4, no campaign-driven migration. Each existing Swagger UI usage migrates when its Node is touched anyway.
- **Vendor risk is bounded.** Both Scalar and Docusaurus are MIT-licensed, actively maintained, with healthy communities. The wrapping pattern (Scalar is middleware behind ASP.NET Core; Docusaurus is a static-site generator producing portable HTML) means a future migration to a replacement is bounded.
- **Studios website remains its own product.** No conflation with docs-tooling decisions.

### Follow-up Work

- Ship `Scalar.AspNetCore` in the Web.Rest reference middleware composition (first packet).
- Build the `@honeydrunk/docs-preset` Docusaurus preset (likely housed in HoneyDrunk.Web.UI per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) D6, packaged separately if it makes sense).
- Notify Cloud GA docs land on Docusaurus when the external-developer audience demands it (sequenced with first paying tenant or first integrator-developer signup).
- Per-Node docs-site decision rubric documented in a future addendum (when does a Node warrant Docusaurus vs. when is overview.md enough).
- The docs-deploy reusable workflow lands in HoneyDrunk.Actions (likely Cloudflare Pages per [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md)).
- Watch list: Scalar stewardship continues; Docusaurus 4.x or successor major when it lands; Algolia DocSearch terms continue free-for-OSS.

## Alternatives Considered

### Swagger UI for in-product OpenAPI

Considered. The argument: Swagger UI is the .NET-ecosystem default; every Node already knows it; staying with it minimizes per-Node migration cost.

Rejected per D1. Swagger UI's UX has aged — no dark mode by default, slow load on large specs, "try it" interactions feel dated, customization story is awkward. Scalar's UX win is material; first-impression for external API consumers (Notify Cloud's tenants) matters. The migration cost is bounded per D4 (opportunistic, not campaign-driven).

### Redoc for in-product OpenAPI

Considered. Redoc is a mature OpenAPI renderer with strong layout and good static-site generation.

Rejected. Redoc's read-only posture (it does not support "try it" interactions) loses meaningful value for developer-facing docs where API exploration is part of the workflow. Scalar's "try it" UX is markedly better. Redoc is held as a credible static-only alternative if a future use case wants read-only API docs without interactive features.

### MkDocs Material for public docs

Considered. MkDocs Material is the polished, Material-Design-themed static site generator; widely adopted in the Python ecosystem; strong search.

Rejected per D2 on React-ecosystem-alignment grounds. The Grid's frontend stack is React per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1; introducing a Python-based docs toolchain adds a third language ecosystem (Python alongside .NET and TypeScript/JS) for documentation-tier work. Docusaurus reuses React skills. MkDocs Material is functionally excellent; the ecosystem-alignment win for Docusaurus is decisive.

### Astro Starlight for public docs

Considered. Astro Starlight is a newer, performance-focused docs framework with strong defaults.

Rejected as immature relative to Docusaurus for versioned docs. Astro's broader trajectory is promising; Starlight specifically is younger and the versioned-docs story is thinner. The Grid's many-decade horizon favors the longer-track-record option. Reconsidered if Starlight's trajectory closes the gap by 2027–2028.

### DocFX for public docs

Considered. DocFX is the .NET-native docs tool; integrates with XML doc comments; long history in the Microsoft ecosystem.

Rejected. DocFX over-fits the .NET-only-content case; the Grid's docs surface is cross-stack (per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1, frontend is React; mobile is RN+Expo). DocFX's XML-comment integration is .NET-only; consumer-PDR docs that reference frontend or mobile components would have a partial DocFX experience and a partial something-else experience. The mismatch is not worth the per-language win.

### GitBook for public docs

Considered. GitBook is a managed docs platform; polished editor; built-in collaboration; cheap-to-start.

Rejected. (a) Vendor lock-in — content lives in GitBook's hosted system; export options exist but degrade. (b) The per-author pricing curve at scale is unfavorable. (c) The cross-Node theming and shared-preset story is weaker than self-hosted Docusaurus. (d) The Grid's discipline favors owned tooling for substrate-shaped concerns; docs are substrate.

### Plain GitHub Pages with Jekyll

Considered. The minimum-overhead option; GitHub-native; free.

Rejected for the public-docs case. Jekyll's themes look dated; the versioned-docs story is awkward; the i18n story is hand-rolled. For internal Markdown-in-repo, GitHub's own rendering is sufficient (and is what the Architecture repo uses); for external-facing Grid docs, Docusaurus is the right tool.

### Use Docusaurus for in-product OpenAPI too (instead of Scalar)

Considered. Docusaurus has OpenAPI plugins; consolidating to one tool reduces operational surface.

Rejected. Docusaurus's OpenAPI plugins are second-class — render quality is poorer than Scalar; the "try it" experience is weaker; the integration is a static-site-generation pipeline rather than in-process middleware. Scalar's in-process ASP.NET Core integration means the OpenAPI surface is live and always-fresh; a Docusaurus-based OpenAPI page is a build-time snapshot. For in-product rendering, Scalar is the right tool.

### Skip the ADR; let each Node pick its docs tooling

Considered. The argument: docs tooling is implementation detail; the Grid should not opinionate.

Rejected. Without an ADR, the first Node to need a doc site picks one; the next questions the choice; the third re-derives the question; per-Node drift makes cross-Node docs incoherent. The defaults are exactly what saves per-Node derivation; the per-Node escape valve (a Node may justify an alternative in its standup ADR) preserves room for the rare case.

### Adopt both Scalar and Redoc (use Scalar for interactive docs, Redoc for printable / read-only versions)

Considered. The argument: different audiences benefit from different renderings.

Rejected as over-engineering for the Grid's scale. Scalar covers the interactive-developer case; the read-only / printable case has no current demand. Reconsidered if a demand emerges.

## References

- [`constitution/charter.md`](../constitution/charter.md) — build-in-public stance, public-artifact framing
- [`constitution/invariants.md`](../constitution/invariants.md)
- [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) — Notify Cloud (first commercial-API docs consumer)
- [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md) — Cloudflare Pages as docs hosting candidate
- [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) — OpenAPI as source of truth (Scalar renders it; SDK generation consumes it)
- [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md), [ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md) — future OpenAPI-surfaced Nodes
- [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1 — React-ecosystem alignment (Docusaurus is React)
- [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) — Web.UI tokens (consumed by Scalar customization and Docusaurus preset)
- [ADR-0074](./ADR-0074-testing-library-stack.md) — license-hygiene principle (Scalar / Docusaurus both MIT)
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) clusters 2.3 (operator-memory / Lore), 5.1 (failed-experiments shelf), 5.2 (changelog aggregator)
- [repos/HoneyDrunk.Studios/overview.md](../repos/HoneyDrunk.Studios/overview.md) — Studios is a separate product per D3
