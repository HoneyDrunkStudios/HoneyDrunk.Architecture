# Dispatch Plan — ADR-0075: Documentation Tooling (Scalar + Docusaurus)

**Initiative:** `adr-0075-docs-tooling`
**ADR:** ADR-0075 (Proposed → Accepted via packet 00)
**Sector:** Meta / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0075 commits a **two-tool split** for the Grid's documentation surfaces:

- **Scalar (`Scalar.AspNetCore`)** — the canonical in-product OpenAPI renderer that replaces Swagger UI in every Grid Node that exposes an OpenAPI spec. `Microsoft.AspNetCore.OpenApi` still generates the document (per ADR-0057); Scalar renders it.
- **Docusaurus 3.x** — the canonical static-site generator for standalone public per-Node documentation sites, used **when a Node warrants its own doc site** (external developer consumers, conceptual surface that overflows `overview.md`, repeated-questions threshold). Per-Node `overview.md` / `boundaries.md` / `invariants.md` in the Architecture repo remains the default.

Both tools consume **Web.UI tokens** per ADR-0071 for cross-surface visual coherence. The Studios website is explicitly **out of scope** per D3 — Studios is a product Node with its own per-product tooling, not a docs site. Existing Swagger UI usage grandfathers (D4) — no forced migration campaign.

This initiative delivers: the acceptance flip, the tooling-convention catalog/governance note, the `Scalar.AspNetCore` reference middleware in `HoneyDrunk.Web.Rest.AspNetCore` (the first Scalar adoption), the per-Node docs-site decision rubric addendum, the `@honeydrunk/docs-preset` Docusaurus preset package (parked behind Web.UI Node standup per ADR-0071), and the Cloudflare-Pages-based docs-deploy reusable workflow in `HoneyDrunk.Actions`.

**6 packets across 3 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Web.Rest`, `HoneyDrunk.Web.UI`, `HoneyDrunk.Actions`). 6 `Actor=Agent`, 0 `Actor=Human`.

## Trigger

ADR-0075 is Proposed with no scope. Forcing functions from the ADR's Context:

- ADR-0057 committed OpenAPI-spec-as-source-of-truth for SDK generation; the spec needs a canonical renderer.
- Notify Cloud GA is the first commercial product — external tenant developers consume the OpenAPI surface and the rendering quality is part of the first-impression for the first paying customer.
- Per ADR-0070 D1, the Grid's frontend stack is React; a future per-Node docs site should align (Docusaurus is React-based).
- Without an ADR, the first Node to need a doc site picks one; the next questions it; per-Node drift accumulates.

## Scope Detection

**Multi-repo.** ADR-0075 touches `HoneyDrunk.Web.Rest` (the Scalar reference middleware composition — the first concrete code adoption), `HoneyDrunk.Web.UI` (the `@honeydrunk/docs-preset` package, parked until the Web.UI Node is stood up per ADR-0071), `HoneyDrunk.Actions` (the docs-deploy reusable workflow), and `HoneyDrunk.Architecture` (acceptance, the tooling-convention note, the per-Node decision rubric addendum). No contract change cascades to consuming Nodes — Scalar is composed at the Node's host; the docs preset is consumed only by Nodes that actually stand up a doc site.

## Wave Diagram

### Wave 1 (governance — no dependencies)
- [ ] **00** — Architecture: Accept ADR-0075, register the initiative. `Actor=Agent`. No new invariants added (the ADR explicitly states "No new Grid-wide invariants introduced").
- [ ] **01** — Architecture: record the Scalar/Docusaurus tooling convention as a cross-cutting tooling note and update the docs-tooling readout where one fits. `Actor=Agent`. Blocked by: 00.

### Wave 2 (the Scalar reference middleware — the first concrete adoption)
- [ ] **02** — Web.Rest: add `Scalar.AspNetCore` to `HoneyDrunk.Web.Rest.AspNetCore` as the OpenAPI-rendering reference middleware. `Actor=Agent`. Blocked by: 00.

### Wave 3 (docs-site enablement — independent surfaces, parallel)
- [ ] **03** — Architecture: author the per-Node docs-site decision rubric addendum (when does a Node warrant Docusaurus vs. when is `overview.md` enough?). `Actor=Agent`. Blocked by: 00.
- [ ] **04** — Web.UI: build the `@honeydrunk/docs-preset` Docusaurus preset package consuming Web.UI tokens. `Actor=Agent`. **PARKED** until the Web.UI Node is stood up per ADR-0071 (no `honeydrunk-web-ui` Node in `catalogs/nodes.json` today). Blocked by: 00.
- [ ] **05** — Actions: author the reusable docs-deploy workflow targeting Cloudflare Pages per ADR-0029. `Actor=Agent`. Blocked by: 00.

Wave 3 packets are independent — they can run in parallel as soon as packet 00 lands. Packet 04 is parked behind the Web.UI Node standup ADR-0071 — file it as `parked` so the board reflects the dependency, but do not execute until ADR-0071's first phase ships `@honeydrunk/web-ui-tokens`.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0075](./00-architecture-adr-0075-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Tooling-convention catalog + note](./01-architecture-docs-tooling-convention-catalog.md) | Architecture | Agent | 1 | 00 |
| 02 | [Scalar.AspNetCore reference middleware](./02-web-rest-scalar-aspnetcore-reference-middleware.md) | Web.Rest | Agent | 2 | 00 |
| 03 | [Per-Node docs-site decision rubric](./03-architecture-per-node-docs-site-decision-rubric.md) | Architecture | Agent | 3 | 00 |
| 04 | [@honeydrunk/docs-preset Docusaurus preset (parked)](./04-web-ui-docs-preset-docusaurus-package.md) | Web.UI | Agent | 3 | 00 |
| 05 | [Docs-deploy reusable workflow (Cloudflare Pages)](./05-actions-docs-deploy-cloudflare-pages-workflow.md) | Actions | Agent | 3 | 00 |

## Version Bumps

- **`HoneyDrunk.Web.Rest`** — packet 02 is the only ADR-0075 packet on the solution; it bumps the version (minor — `HoneyDrunk.Web.Rest.AspNetCore` gains a `PackageReference` to `Scalar.AspNetCore` and a new public `AddRestOpenApiReference()` / `MapRestOpenApiReference()` extension surface). Per invariant 27, all projects in the solution share one version and move together — perform the in-progress version-state check at edit time. Per-package CHANGELOG entries only for packages with actual changes.
- **`HoneyDrunk.Web.UI`** — packet 04 is the only ADR-0075 packet on the repo; it bumps the `@honeydrunk/docs-preset` package version (initial 0.x release on the package alongside the Web.UI Node's other packages). Per ADR-0071 D6's npm-package versioning discipline.
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; packet 05 is a workflow YAML change. CHANGELOG updated per the repo convention if it keeps one.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance edits only (packets 00, 01, 03).

## Invariant Numbering

**ADR-0075 adds no Grid-wide invariants** — explicitly stated in the ADR's Consequences/Invariants subsection: "No new Grid-wide invariants introduced. The following are committed conventions enforced at packet authoring and review." Packet 00 does not edit `constitution/invariants.md`. The four committed conventions (new Nodes with OpenAPI surfaces use Scalar; standalone Grid docs sites use Docusaurus; per-Node docs default to `overview.md`/`boundaries.md`/`invariants.md`; both tools consume Web.UI tokens) are enforced at packet authoring and review, not encoded as numbered invariants.

## Cross-Cutting Concerns

### Coordination with ADR-0071 (Web.UI Node)

Packet 04 (`@honeydrunk/docs-preset`) depends on the Web.UI Node existing. ADR-0071 is Proposed; the Web.UI Node is not yet stood up (no `honeydrunk-web-ui` entry in `catalogs/nodes.json`). Until ADR-0071's scaffold packet lands and `@honeydrunk/web-ui-tokens` publishes its 0.x release, packet 04 cannot proceed. File packet 04 with a `parked` posture in the issue body (the agent picking it up reads the parked state and waits). The dependency is a soft Node-existence dependency, not a `dependencies:` edge — the parked-state framing is the source of truth.

### Coordination with ADR-0057 (OpenAPI Versioning + SDK Strategy)

ADR-0075 D1 is downstream of ADR-0057's commitment: `Microsoft.AspNetCore.OpenApi` generates the OpenAPI document and Scalar renders it. Packet 02 does **not** change document generation — that stays as-is per ADR-0057. The packet is purely about the renderer. No dependency edge is needed; the relationship is "Scalar consumes the document ADR-0057 already produces."

### Coordination with ADR-0027 (Notify Cloud)

ADR-0075 D2 names Notify Cloud as the first Node likely to warrant a standalone Docusaurus doc site (when external-developer demand justifies it). **No Notify Cloud docs-site packet is filed in this initiative** — it is deferred to the operational moment when demand emerges. The Notify Cloud docs site is recorded as a deferred item; when it is built, it consumes packet 04's preset and packet 05's deploy workflow.

### Coordination with ADR-0029 (Cloudflare DNS + Edge)

Packet 05's docs-deploy workflow targets Cloudflare Pages per the ADR-0075 D6 strong-default. No new ADR is needed — ADR-0029's existing edge-platform commitment covers the deployment target.

### Site sync

No site-sync flag. ADR-0075 commits internal tooling. The first public-facing docs-site that ships (likely Notify Cloud, deferred) will be its own packet at that moment, separate from this initiative.

### Migration discipline (Swagger UI → Scalar)

ADR-0075 D4 commits to **opportunistic migration, not a campaign**. Existing Nodes that ship with Swagger UI grandfather and migrate when their API surface is being modified for other reasons. **No retroactive migration packets are filed in this initiative.** A scan of the Grid finds no current Swagger UI usage (Web.Rest's `AspNetCore` package does not reference Swashbuckle or Scalar today) — so the grandfather posture is operationally invisible and packet 02 sets the new default rather than replacing existing usage.

## Deferred Items (tracked here, not in any catalog)

- **Notify Cloud docs site.** Will land on Docusaurus when external-developer demand justifies; sequenced with first paying tenant or first integrator-developer signup. Consumes packets 04 + 05.
- **Per-Node docs-site fan-out.** As future Nodes hit the "should this Node have a docs site?" threshold per packet 03's rubric, per-Node docs-site packets land at that moment.
- **Studios website tooling consolidation question.** Whether Studios should embed Docusaurus subsections for Node docs is product-shape work, not tooling work. Deferred to a future product decision.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; tooling-convention note removed. No runtime impact.
- **Packet 02 (Scalar in Web.Rest):** revert the PR. `HoneyDrunk.Web.Rest` solution version rolls back. No consuming Node depends on the Scalar middleware at runtime until a host composes it — a revert is contained to Web.Rest. The OpenAPI document generation per ADR-0057 is untouched.
- **Packet 03 (decision rubric):** revert the PR. Docs only.
- **Packet 04 (docs-preset):** revert the PR. `@honeydrunk/docs-preset` package unpublished from npm if a 0.x release was tagged. No consuming docs site exists yet, so the revert is bounded.
- **Packet 05 (docs-deploy workflow):** revert the workflow edit. The new reusable workflow has no consumers until a docs site repo invokes it — the workflow is inert until called.
- **Tool-level escape hatch:** ADR-0075's tool choices are reversible by design. Scalar can be swapped for Redoc or another renderer in a single Web.Rest-side change (per the ADR's "Alternatives Considered — Redoc"); Docusaurus can be swapped for Astro Starlight or MkDocs at the per-Node-docs-site moment (per the ADR's "Alternatives Considered — Astro Starlight"). The wrapping pattern (middleware behind ASP.NET Core; static-site generator producing portable HTML) bounds the migration cost.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
