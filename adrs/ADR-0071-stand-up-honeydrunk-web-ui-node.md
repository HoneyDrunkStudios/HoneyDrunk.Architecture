# ADR-0071: Stand Up the HoneyDrunk.Web.UI Node — Shared Frontend Design System

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Creator (anchor)

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale). Per the project convention, the Node is **not** added to `catalogs/nodes.json` until acceptance:

- [ ] Create `HoneyDrunk.Web.UI` GitHub repo as **public** (Grid default per [ADR-0039](./ADR-0039-grid-open-source-license-policy.md); design tokens and CSS are the kind of substrate the build-in-public stance covers naturally)
- [ ] Add `honeydrunk-web-ui` Node entry to `catalogs/nodes.json` with Creator sector, `signal: "seed"`, `cluster: "frontend"`
- [ ] Add `honeydrunk-web-ui` entries to `catalogs/relationships.json`: consumes `honeydrunk-kernel-abstractions` (records-only contract registration if any); `consumed_by_planned` includes `honeydrunk-studios` (already React, will migrate to consume tokens at the first natural opportunity), `honeydrunk-notify-cloud` (Blazor admin per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D2), and all consumer-app PDRs (`hearth`, `lately`, `currents`, `curiosities`)
- [ ] Anchor the **Creator** sector in [`constitution/sectors.md`](../constitution/sectors.md) — add Web.UI as the first Creator-sector row (Sector currently has zero real Nodes per `sectors.md` "Creator" section)
- [ ] Add Web.UI to `catalogs/modules.json` with the per-stack package layout from D6 (`@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, `@honeydrunk/web-ui-react`, optional `HoneyDrunk.Web.UI.Blazor`, optional `@honeydrunk/web-ui-native`)
- [ ] Add Web.UI to `catalogs/grid-health.json` reflecting the stood-up package surface (tokens + CSS at minimum on day one)
- [ ] Update [`constitution/sectors.md`](../constitution/sectors.md) Creator-sector text — Web.UI is the anchor, the "No real Nodes yet" line is replaced
- [ ] Create `repos/HoneyDrunk.Web.UI/` context folder (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`) — matching the template used by [`repos/HoneyDrunk.Audit/`](../repos/HoneyDrunk.Audit/) and [`repos/HoneyDrunk.Studios/`](../repos/HoneyDrunk.Studios/)
- [ ] File the HoneyDrunk.Web.UI scaffold packet (monorepo or polyrepo decision per D6; tokens-first publishing pipeline; CI per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md); semantic-versioning cadence per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md))
- [ ] Confirm the paired [ADR-0070](./ADR-0070-frontend-platform-stack.md) is Accepted (Web.UI's stack constraints derive from there)
- [ ] Scope agent flips Status → Accepted after the first packet declaring this ADR in `accepts:` merges and the tokens package publishes its 0.x release

## Context

The paired [ADR-0070](./ADR-0070-frontend-platform-stack.md) commits the Grid to three frontend stacks: React for consumer web, Blazor for simple admin, and React Native + Expo for mobile. With three stacks, the obvious next question is: **where does the design system live?**

Today: nowhere. Each consumer surface re-derives its visual language. Studios uses one set of design tokens (Tailwind config, custom CSS variables); Notify Cloud's admin will derive its own when the packet lands; every queued consumer PDR (Hearth, Lately, Currents, Curiosities) implies its own UI; even prototype work re-invents the buttons, the form layouts, the color choices.

The cost compounds with every new consumer surface:

- **Design drift across products.** A user who interacts with Hearth and then Notify Cloud sees two different visual languages with the same studio branding. The "this all came from HoneyDrunk" recognizability degrades per surface.
- **Re-derivation per PDR.** Each consumer-app PDR pays a per-surface design tax: pick colors, pick spacing, pick typography, write the base CSS, build the primitive components, write the documentation. Each surface pays it; nothing accrues to the next.
- **Cross-stack inconsistency.** With three stacks per [ADR-0070](./ADR-0070-frontend-platform-stack.md), the design tax compounds — a button in React and a button in Blazor and a button in RN should look and behave the same; without a shared contract they will not.
- **No place for design decisions to live.** Today a "should our brand accent be #FF6A00 or #FF8C00" decision exists in three different config files and one operator-internal note. There is no canonical source.

The forcing functions converging now:

- **Notify Cloud admin UI** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) is imminent. It needs visual identity from day one.
- **Hearth, Lately, Currents, Curiosities** are queued consumer PDRs. Each needs design system on day one.
- **Studios** ([repos/HoneyDrunk.Studios/overview.md](../repos/HoneyDrunk.Studios/overview.md)) is the established React surface today (Next.js 16, React 19, Three.js). It has settled tokens informally; formalizing them is the path of least resistance for Web.UI's first release.
- **The paired [ADR-0070](./ADR-0070-frontend-platform-stack.md)** commits three stacks. The Web.UI Node is the cross-stack reconciliation point.
- **The Creator sector is empty.** Per [`constitution/sectors.md`](../constitution/sectors.md), Creator has no real Nodes. Anchoring the sector with a Node whose role is "design substrate for the rest of the Grid" is sector-shape-correct.

The charter's framing is direct ([`constitution/charter.md`](../constitution/charter.md) §"What this charter licenses"):

> Spend on the foundation. Time invested in ADRs, invariants, substrate hygiene, and architectural correctness is not "premature optimization" or "procrastinating on shipping." It is the work.

A design-system Node is foundation work whose ROI compounds with every consumer surface. The investment now pays off in every PDR that scaffolds afterward.

This ADR is the **stand-up decision** for the Web.UI Node — what it owns, what it does not own, the per-stack split, the relationship to Studios (Web.UI is consumed by Studios, not folded into it), and what scaffolds in the first packet. It is not a scaffolding packet. Per the project convention, the **boundary is named now so the next consumer surface has somewhere to consume tokens from**; the **Node itself doesn't get built** until that first consumer surface pulls on it.

## Decision

### D1. HoneyDrunk.Web.UI is the Creator sector's owner of design tokens, primitive CSS, and component contracts

`HoneyDrunk.Web.UI` is the single Node in the Creator sector that owns the **design substrate** consumed by every other frontend surface in the Grid. It owns:

- **Design tokens** — color, spacing, typography, radii, shadows, motion, breakpoints. Shipped as CSS variables and as a JSON tokens file (stack-agnostic).
- **Primitive CSS** — reset, base typography, utility classes. Shipped as a CSS bundle consumable from React, Blazor, and any web-based context.
- **Component contracts** — the design specification for each primitive (Button, Input, Card, Modal, Toast, etc.). The contract names the variants, the states, the accessibility expectations.
- **React component implementations** — the first-class implementation of every component contract. The default ships from here.
- **Blazor component implementations (optional, per admin surface)** — added when a specific Blazor admin surface needs a component beyond what tokens + CSS alone provide.
- **React Native component contracts and implementations** — mobile-specific implementations of the design system, kept visually consistent with the React web components per D5.

It does **not** own:

- **The Studios website** ([repos/HoneyDrunk.Studios/overview.md](../repos/HoneyDrunk.Studios/overview.md)) — Studios is a separate Node and product. Web.UI is **consumed by** Studios; Web.UI does not house Studios. This separation is load-bearing per D3.
- **Per-product page templates, marketing pages, or content models** — those are PDR-side concerns.
- **State management, routing, data fetching, or any runtime application concerns** — Web.UI ships visual primitives, not application substrate.
- **Backend integration code** — Web.UI is purely client-side; it does not depend on any Grid Node's runtime contract beyond Kernel.Abstractions records (if used at all).
- **i18n / l10n catalogs** — per the [charter-aware draft cluster 7.6](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md), `HoneyDrunk.Locale` is the future-state home for translation infrastructure. Web.UI's text strings on primitive components are English defaults; localization is the consuming PDR's responsibility for now.
- **Icon libraries** — Web.UI may opinionate on which icon set the Grid uses (the strong default is a single open-source icon set like Lucide or Phosphor) but does not author icons itself.
- **Designer tooling integration (Figma, Penpot)** — adjacent concern, deferred until designer workflow exists.

### D2. Sector placement — Creator (anchor)

Web.UI lands in the **Creator** sector per [`constitution/sectors.md`](../constitution/sectors.md):

> Tools that turn imagination into momentum — from marketing automation to creative analytics.

The Creator sector is currently empty ("No real Nodes yet. Planned: HoneyDrunk.Signal, Forge."). Web.UI's role — design substrate that every consumer PDR consumes — fits the sector's intent: it is the Grid's creative-tooling layer for the people building the consumer surfaces.

Anchoring an empty sector with a Node whose role is concretely needed is the cheapest way to give the sector live identity. Future Creator-sector Nodes (Signal, Forge, the per-`adr-drafts` analytics Node) join Web.UI rather than entering an empty sector.

The **Core** sector was considered as an alternative placement. Rejected because Core is "Foundational primitives for everything else — kernel abstractions, data conventions, and reliable transport." Web.UI is not a Core primitive — it is a creative-surface primitive. The distinction matters: Core's discipline (zero-dependency Abstractions, Kernel-rooted contracts, runtime composition) does not map onto a design system. Creator is the sector-correct home.

### D3. Web.UI is consumed by Studios — not folded into Studios

Studios ([repos/HoneyDrunk.Studios/overview.md](../repos/HoneyDrunk.Studios/overview.md)) is the established React frontend Node in the Grid. The temptation: fold the design system into Studios; let Studios be the canonical source for tokens and components, with other surfaces consuming them from there.

Rejected. Studios is **a product, not a baseline**. The Studios website has its own purpose (HoneyDrunk Studios' public site — marketing, blog, project listings) and its own lifecycle. Folding the design system into Studios couples every consumer PDR to Studios' deployment cadence, Studios' npm package surface, and Studios' release schedule. Cross-PDR substrate should not be downstream of a single product.

The relationship is inverted: **Studios consumes Web.UI**, the same way Hearth, Lately, Currents, Curiosities, and Notify Cloud admin will consume Web.UI. Studios is the first consumer; it is not the host.

This separation is explicitly per-operator: "Studios is one product, not a baseline" is the framing this ADR records.

The migration shape: Studios continues using its current informal tokens until Web.UI's first release is ready. At that release, a Studios follow-up packet migrates Studios to consume the Web.UI tokens package. The migration is bounded (Studios is one product; the cutover is one PR) and the tokens align (Studios' existing tokens are formalized into the first Web.UI release, so the migration is mechanical).

### D4. Per-stack component strategy — tokens cross-stack, components per-stack

The hard reality: tokens (color, spacing, etc.) are stack-agnostic but components are not. A React `<Button>` and a Blazor `<Button>` and a React Native `<Button>` are three implementations of one design contract.

The committed split:

- **Tokens are shared.** One source of truth (a tokens JSON + a CSS variables file), consumed identically by every stack. Color, spacing, typography, radii, shadows, motion, breakpoints, z-index scale. Stack-agnostic by construction.
- **Primitive CSS is shared across web stacks.** The reset, the base typography, the utility classes ship as a CSS bundle that React consumers and Blazor consumers both import.
- **React components are first-class.** Every component contract has a React implementation in `@honeydrunk/web-ui-react`. This is the default and the first-shipped stack per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1.
- **Blazor components are added per-surface, not pre-shipped.** The Web.UI Node ships **no Blazor components on day one**. Blazor components ship when a specific admin surface needs one beyond what tokens + CSS alone provide. The minimum Blazor consumer (Notify Cloud admin) likely needs only tokens + CSS at v1; component-level work is added per-surface, lazily.
- **React Native components are first-class for the mobile-targeting subset.** Mobile-specific components (anything that needs `View` / `Text` / `Pressable` instead of `div` / `span` / `button`) ship in `@honeydrunk/web-ui-native`. The naming preserves the "Web.UI" Node identity while making the cross-stack reach explicit; the package surface is per-stack.

**Why per-stack and not "write once, render anywhere":**

- **Stack-specific idioms matter.** React's component model, Blazor's `RenderFragment` model, and React Native's `StyleSheet` model do not converge. A "universal component" abstraction loses to per-stack implementations on every dimension — performance, idiomatic API, ecosystem alignment, AI-assistance accuracy.
- **AI-assistance leverage favors per-stack.** Per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1's AI-multiplier reasoning, idiomatic React code is what AI tools are best at. A universal component abstraction would underutilize the AI multiplier.
- **The shared contract is the design specification, not the code.** What stays shared is the **what** (a Button has primary / secondary / ghost variants; it has hover / focus / active / disabled states; it supports loading; it is keyboard-accessible). The **how** is per-stack. Per [ADR-0017](./ADR-0017-stand-up-honeydrunk-capabilities-node.md) D-style abstraction-first thinking applied to UI: the contract is the interface; the per-stack code is the backing.

### D5. Phased shipping — tokens first, components incrementally

The Web.UI Node does **not** ship a complete design system on day one. The phasing:

- **Phase 0 (this ADR).** Boundary, sector placement, per-stack strategy committed. No code.
- **Phase 1 (scaffold packet, when accepted).** Repo created; tokens + primitive CSS shipped as `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css`. No components yet. Studios' existing tokens migrate in as Phase 1's first input. The Studios website becomes the first consumer immediately.
- **Phase 2 (first non-Studios consumer).** React component pack ships in `@honeydrunk/web-ui-react`. Initial component set is small and pragmatic: Button, Input, Label, Card, Modal, Toast, Alert, Spinner, Skeleton — the primitives every consumer PDR will need on day one. Notify Cloud admin (Blazor) consumes tokens + CSS without needing React components.
- **Phase 3 (first Blazor consumer surface that needs components).** A Blazor component or two ships in `HoneyDrunk.Web.UI.Blazor` (NuGet) as the first surface demands them. The default posture remains: most Blazor surfaces need tokens + CSS only.
- **Phase 4 (first mobile PDR).** React Native components ship in `@honeydrunk/web-ui-native`. Mobile-specific patterns (TabBar, BottomSheet, etc.) join the component contract; web-specific patterns (Tooltip on hover) do not have RN equivalents and are documented as web-only.
- **Phase 5 (designer-tooling integration).** If and when a designer joins the workflow, Figma / Penpot integration lands (tokens-as-Figma-styles export, component-as-Figma-symbol mappings). Deferred indefinitely otherwise.

The phasing matches consumer demand. The Node does not pre-ship surface it does not have consumers for; the Node also does not block consumers waiting for the surface they need.

### D6. Package layout

The packages Web.UI ships:

| Package | Stack | Purpose |
|---|---|---|
| `@honeydrunk/web-ui-tokens` | stack-agnostic (JSON + CSS variables) | Color, spacing, typography, radii, shadows, motion, breakpoints, z-index scale |
| `@honeydrunk/web-ui-css` | web (React + Blazor) | Reset, base typography, utility classes — the primitive CSS bundle |
| `@honeydrunk/web-ui-react` | React | First-class React component implementations |
| `HoneyDrunk.Web.UI.Blazor` (NuGet) | Blazor | Blazor component implementations (added per admin surface need) |
| `@honeydrunk/web-ui-native` | React Native | Mobile-specific component implementations |
| `@honeydrunk/web-ui-icons` (deferred) | stack-agnostic | If the Grid commits to a single icon set, the re-export lives here |

The npm packages live under the `@honeydrunk` scope (per the standard org convention). The NuGet package follows the existing `HoneyDrunk.*` naming.

**Monorepo vs. polyrepo:** The scaffold packet decides this. The strong default is a **monorepo** in `HoneyDrunk.Web.UI` (tools like pnpm workspaces, Turbo, or Nx handle the multi-package shape natively); a polyrepo split is permitted only if cross-stack coupling becomes a problem. The monorepo posture lets tokens, CSS, and components share linting, versioning, and CI.

### D7. Versioning

Each package follows semantic versioning per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md)'s discipline applied to JS/CSS packages:

- **Tokens (`@honeydrunk/web-ui-tokens`)** — token additions are minor; token removals or value changes that visually break consumers are major.
- **CSS (`@honeydrunk/web-ui-css`)** — class additions are minor; class removals or selector specificity changes that break consumers are major.
- **Component packages** — additive new components or props are minor; breaking API changes (prop renames, removed components) are major.

Pre-1.0 packages do not carry the same compatibility promise per ADR-0035's pre-1.0 disclaimer. Web.UI starts at 0.x and stays there until the cross-PDR consumer base stabilizes (likely Phase 4 — once Studios + Notify Cloud + one consumer-app PDR consume Web.UI, the 1.0 release pins the surface).

### D8. Boundaries explicit

| Boundary | Web.UI owns | Web.UI does NOT own |
|---|---|---|
| **Tokens / CSS** | The canonical source for color, spacing, typography, etc. | Per-PDR token overrides (consumers may set CSS-variable overrides locally; Web.UI does not consume those back) |
| **Components** | Design contract + per-stack implementations of the contract | Application-specific composites (e.g., a "BillingDashboard" is a Notify Cloud concern, not a Web.UI concern) |
| **Stack choice** | The per-stack split per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1/D2/D3 | The stack-selection ADR itself (that's [ADR-0070](./ADR-0070-frontend-platform-stack.md)) |
| **Studios** | Tokens / CSS / components consumed by Studios | The Studios website (a separate Node and product per D3) |
| **i18n** | Default English strings on primitives | The Grid's i18n runtime ([`HoneyDrunk.Locale`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 7.6) |
| **Icons** | Opinion on which icon set the Grid uses (single open-source set) | The icon designs themselves |
| **Designer tooling** | Future Figma/Penpot integration when designer joins | The design files themselves |
| **Accessibility** | A11y baseline on every primitive (keyboard nav, ARIA, focus management) | Per-PDR a11y audits of composed surfaces |
| **Theme / dark mode** | Default light + default dark themes shipping as token sets | Per-PDR custom themes (consumers can layer their own) |

### D9. Dependencies and Grid-relationship discipline

Web.UI's runtime dependencies are deliberately minimal:

- **No dependency on any runtime Grid Node.** Web.UI is purely client-side substrate; it has no need for Kernel, Auth, Data, Vault, etc.
- **No dependency on Kernel.Abstractions's record types** at v1. If a future Web.UI primitive needs to render a Grid-canonical value type (e.g., `Money` per [ADR-0069](./ADR-0069-currency-handling-and-money-representation.md), or `TenantId` per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md)), the dependency direction is **consumer-side** (the consuming PDR's adapter, not the Web.UI primitive). Web.UI stays Kernel-agnostic to preserve cross-stack viability — JSON-deserialized values pass through Web.UI primitives the same way arbitrary string values do.
- **Third-party UI dependencies are scoped per-stack.** React uses Radix primitives or shadcn-style headless primitives at the component level; Blazor uses native Blazor components or a permissive-licensed Blazor library if one fits; React Native uses Expo's primitive set. Each per-stack package documents its third-party tree; Web.UI does not bundle a "kitchen sink" UI library across all stacks.

Per [Invariant 1](../constitution/invariants.md) (Kernel.Abstractions has zero runtime dependencies): Web.UI does not violate any Kernel discipline because Web.UI is downstream of nothing. It is consumed; it does not consume the Grid's runtime contracts.

### D10. Charter sanity check — is this premature?

The charter ([`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids" item 2) explicitly warns against **architecture-as-procrastination**. The test for Web.UI:

**The argument that this is appropriately-timed:**

- Three consumer PDRs (Hearth, Lately, Curiosities) are queued and will all need design substrate from their first scaffolding packet. Without Web.UI, each pays the design tax independently.
- Notify Cloud admin needs visual identity from day one. With Web.UI, it inherits the Grid's design language; without, it invents one.
- The paired [ADR-0070](./ADR-0070-frontend-platform-stack.md) commits the three-stack split; Web.UI is the obvious cross-stack reconciliation point.
- The Node is **not built** until the first consumer pulls on it. This ADR commits the boundary, the per-stack strategy, and the package layout; the scaffold packet is a follow-up. The investment now is hours.
- Per the charter's licensed permissions ("Spend on the foundation. Time invested in ADRs … is the work."), naming a cross-PDR substrate that four queued PDRs will all need is precisely the substrate work the charter licenses.

**The argument that this is premature** — and the honest counterweight:

- No consumer app has shipped. The design substrate could be derived from the first one's actual needs.
- The Studios website already has informal tokens; the formalization could wait until a second consumer surface forces the issue.

**The resolution:** the **boundary** is named now because four queued consumer PDRs all need the same answer; the **vendor-equivalent choices** (which icon set, which Blazor component library if any) are deferred to the scaffold packet or to per-surface demand. This is the same posture every Node-standup ADR took (boundary now, first implementation per actual consumer).

**Charter verdict:** appropriately-timed, not procrastination.

### D11. Relationship to existing ADRs

- **[ADR-0070](./ADR-0070-frontend-platform-stack.md) (Frontend Platform Stack)** — paired. Web.UI ships the cross-stack substrate that ADR-0070's three-stack choice requires.
- **[ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) (Notify Cloud)** — Notify Cloud admin is the first Blazor consumer. Receives tokens + CSS at Phase 1; needs no Blazor components on day one per D4.
- **[ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md)** — Web.UI's packages follow semver per ADR-0035's discipline applied to JS/CSS.
- **[ADR-0039](./ADR-0039-grid-open-source-license-policy.md)** — Web.UI is public per the Grid default; license is MIT or equivalent (the per-Node default in ADR-0039 for non-commercial-trial Nodes).
- **[Invariant 1](../constitution/invariants.md)** — Web.UI does not violate Kernel.Abstractions's zero-dependency rule because Web.UI does not depend on Kernel.
- **[PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md)** — all four consumer PDRs consume Web.UI from their first scaffolding packet.
- **[`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md)** — Web.UI candidate context (cluster 7.8) is operationalized here.

## Consequences

### Affected Nodes

- **HoneyDrunk.Web.UI** (new) — stood up by this ADR. First packages publish at Phase 1.
- **HoneyDrunk.Studios** — becomes the first consumer of Web.UI tokens at Phase 1 (migration packet). No code change at stand-up.
- **HoneyDrunk.Notify.Cloud** — consumes Web.UI tokens + CSS at Phase 2 for the Blazor admin surface.
- **Consumer-app PDRs** ([PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md)) — each consumes Web.UI from its first scaffolding packet.
- **Creator sector** ([`constitution/sectors.md`](../constitution/sectors.md)) — anchored by Web.UI. The "No real Nodes yet" line is replaced; Creator becomes a live sector.
- **HoneyDrunk.Kernel / Kernel.Abstractions** — no change. Web.UI does not consume Kernel; the dependency direction stays one-way for runtime contracts.

### Invariants

This ADR proposes (not commits — invariant numbers and final wording assigned by the scope agent at acceptance):

- **Invariant proposal: Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`.** Per-PDR re-derivation of tokens or primitive CSS is a boundary violation. Per-PDR overrides via standard CSS-variable cascade are permitted.
- **Invariant proposal: Web.UI does not host Studios; Web.UI is consumed by Studios.** The Studios website is a product Node, not the design-system host. (Codifies D3.)
- **Invariant proposal: Web.UI does not depend on any Grid Node's runtime contracts.** Web.UI is purely client-side substrate; the dependency direction is consumer→Web.UI, never the inverse. (Codifies D9.)

### Operational Consequences

- **The first design-system release (Phase 1, tokens + CSS) is cheap.** Studios' existing informal tokens formalize into the first package release; the cutover is one Studios PR. Subsequent consumer surfaces inherit the work for free.
- **Component implementations split per stack.** Per D4, a new design-system component requires implementation in each stack it serves. The cost is bounded by the per-surface demand strategy (D5) — components ship lazily per consumer need, not pre-emptively.
- **Cross-PDR design coherence becomes the default.** Every consumer surface inherits the Grid's visual language. Brand recognizability across products compounds.
- **The Creator sector goes live.** From "No real Nodes yet" to one anchor Node. Future Creator-sector Nodes (Signal, Forge, analytics) inherit a live sector to join.
- **Versioning cadence is the operator's hand.** Without a designer or design-team pressure, token / component changes happen at the operator's pace. The semver discipline (D7) protects consumers from surprise breakage.
- **Vendor risk on third-party UI libraries is per-stack.** If a chosen React headless library deteriorates (license change, abandonment), the swap is bounded to one package. Tokens and CSS are vendor-free by construction.

### Follow-up Work

- Stand up the `HoneyDrunk.Web.UI` repo and scaffold the Node (Phase 1; first packet declaring this ADR in `accepts:`).
- Publish `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css` at 0.1.x with Studios' existing tokens formalized.
- Migrate Studios to consume the Web.UI packages (Studios-side follow-up packet, sequenced after Phase 1 publishes).
- Ship the first React component pack `@honeydrunk/web-ui-react` (Phase 2; sequenced with first non-Studios consumer demand).
- Notify Cloud admin packet ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) follow-up) lands in Blazor consuming Web.UI tokens + CSS.
- Each consumer-app PDR's scaffold packet consumes Web.UI from day one.
- Anchor the Creator sector in [`constitution/sectors.md`](../constitution/sectors.md).
- Update `constitution/invariants.md` with the three proposed invariants once accepted.

## Alternatives Considered

### React-only Node (no Blazor or RN consideration)

Considered. The argument: the React stack is the dominant frontend per [ADR-0070](./ADR-0070-frontend-platform-stack.md) D1; the Web.UI Node could ship React-only and let Blazor admin surfaces re-derive their tokens.

Rejected. The Blazor admin surfaces (Notify Cloud first) still need consistent visual identity with the rest of the Grid. Tokens and CSS are cheap to make stack-agnostic; foreclosing Blazor's access to them means every Blazor admin invents its own colors and spacing. The cost asymmetry favors cross-stack tokens + CSS by a large margin; React-only would pay the convenience of "one stack to think about" by losing the Grid-coherence win.

### Full per-stack components (React + Blazor + RN variants of every component from day one)

Considered. The argument: design coherence requires component-level coherence; ship every component in every stack as a single shipping unit.

Rejected per D4 and D5. Too much surface area for Seed phase. Most Blazor admin surfaces will not need component-level overrides beyond tokens + CSS — they'll use Blazor's native primitives styled with the Web.UI CSS bundle. Pre-shipping Blazor variants of every component pays the implementation tax without consumer demand. The lazy posture (component ships when a surface needs it) matches the Web.UI Node's actual Phase-1-through-Phase-4 usage pattern.

### Fold the design system into Studios

Considered (and explicitly rejected per operator). The argument: Studios is the existing React Node; adding a `studios/design-system` package and exporting from there minimizes new Node surface.

Rejected per D3. Studios is a product, not a baseline. Coupling cross-PDR substrate to a single product's deployment cadence, repo lifecycle, and release schedule inverts the substrate's role. The right shape is Studios-consumes-Web.UI, not Web.UI-lives-inside-Studios. This is the same shape ADR-0058 / ADR-0059 took with caching (Cache Node hosts backings; consumers are Cache-consumers, not Cache-hosters).

### Use a third-party design system (Material UI, Chakra, Mantine, Radix, shadcn)

Considered. The argument: cheap path to a mature design system without the work of authoring one.

Rejected as a top-level substitute, but **incorporated as building blocks at the component layer**. Web.UI's React component implementations may build on top of headless primitives (Radix UI, shadcn patterns) — the standard React-ecosystem move. What Web.UI **does not do** is rebrand "we are Material UI with a HoneyDrunk theme." The tokens, the component contracts, and the visual identity are Grid-owned; the React-side implementation can stand on the shoulders of headless primitives where they earn their keep. The same applies for Blazor (a permissive-licensed component library may sit underneath the Blazor component implementations) and RN (Expo's primitives + a few popular RN libraries).

The distinction: third-party libraries are **implementation details** of Web.UI's components, not the Grid's design language.

### Per-PDR design systems (no shared Node at all)

Considered. The argument: each PDR is a separate product with potentially different design needs; forcing shared tokens may over-constrain product-specific differentiation.

Rejected. The Grid's products are HoneyDrunk products; visual cohesion across them is brand-shaped, not over-constraint. The escape valve (per-PDR overrides via standard CSS-variable cascade per D8) lets a specific PDR diverge where it needs to (e.g., Hearth's "town" metaphor might want a warmer palette than the Grid default) while still inheriting the Grid baseline. No-shared-substrate is the failure mode this ADR exists to prevent.

### Defer the Node until two consumer PDRs are concretely scaffolded and the shared needs are obvious from real consumer code

Considered. The argument: design needs are easier to abstract from real consumer code than from speculative needs.

Rejected. Two-PDR-deferred means the first two consumer surfaces each pay the per-surface design tax in full, plus the cost of retroactive extraction once the patterns are visible. The marginal cost of naming the boundary and shipping tokens + CSS now (Phase 1 is one packet) is much smaller than the cost of two consumer PDRs each authoring their own tokens and then merging them later. The naming-the-boundary cost is one ADR (this one).

### Stand up Web.UI in Core sector instead of Creator

Considered. The argument: Web.UI is foundational for every consumer-facing PDR; Core (foundational primitives) is the natural fit.

Rejected per D2. Core is the sector for Kernel-rooted runtime primitives — Vault, Auth, Transport, Data, the runtime contracts every Node-compiles-against substrate. Web.UI is creative-surface substrate, not runtime. Sector intent matters: Core's discipline (zero-dependency Abstractions, runtime composition, contract-shape canaries on the package surface) does not map cleanly onto a design system. The Creator sector is the sector-correct home, and anchoring an empty sector is sector-shape-correct.

### Add tokens directly to Kernel.Abstractions

Considered. The argument: design tokens are constants; constants live in Kernel.Abstractions; one less Node to maintain.

Rejected on multiple grounds. (a) Kernel.Abstractions is .NET-only; tokens need to be consumable from JavaScript / CSS / React Native, which Kernel.Abstractions cannot serve. (b) Per [Invariant 1](../constitution/invariants.md), Kernel.Abstractions has zero runtime dependencies and a tightly-controlled surface; adding a design-tokens package to it would either bloat the contract or force a separate `HoneyDrunk.Kernel.Abstractions.Tokens` package — at which point the per-Node solution is exactly Web.UI. (c) Tokens evolve at a different cadence from Kernel contracts; coupling them is operationally wrong.

### Use Tailwind as the canonical CSS layer (instead of authoring primitive CSS)

Considered. The argument: Tailwind is widely adopted, well-tooled, AI-assistance-friendly, and could simplify the CSS layer to "use Tailwind classes everywhere."

Deferred, not rejected. Tailwind is a per-consumer-PDR decision (the React-side adapter may use Tailwind on top of Web.UI tokens). Web.UI's tokens are designed to be Tailwind-compatible (the tokens JSON maps to Tailwind's config shape natively). What Web.UI ships at the CSS layer is the primitive baseline (reset, base typography, utility classes); whether a consumer PDR layers Tailwind on top is the consumer's choice. Forcing Tailwind Grid-wide would over-constrain Blazor consumers (where Tailwind's pattern fits awkwardly) and over-constrain consumer PDRs that have legitimate reasons to use other utility-CSS conventions.

### Use a separate Node for Blazor components and another for React Native

Considered. The argument: per-stack Nodes minimize cross-stack coupling and let each stack evolve independently.

Rejected. The design **contract** is the same across stacks — a Button is a Button regardless of which renderer ships it. Splitting per-stack Nodes loses the contract-level coherence and forces three-way coordination on every design decision. The monorepo posture per D6 (one Node, per-stack packages) captures the per-stack implementation separation without losing the contract unity.

## References

- [`constitution/charter.md`](../constitution/charter.md) — workshop framing, foundation-investment license
- [`constitution/sectors.md`](../constitution/sectors.md) — Creator sector (Web.UI is the anchor)
- [`constitution/invariants.md`](../constitution/invariants.md) — invariants 1-3 honored
- [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) — Notify Cloud admin (first Blazor consumer)
- [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) — semver discipline applied to JS/CSS packages
- [ADR-0039](./ADR-0039-grid-open-source-license-policy.md) — Web.UI is public per the Grid default
- [ADR-0070](./ADR-0070-frontend-platform-stack.md) — paired stack-selection ADR
- [repos/HoneyDrunk.Studios/overview.md](../repos/HoneyDrunk.Studios/overview.md) — Studios website (first Web.UI consumer per D3)
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 7.8 — Web.UI candidate context
- [PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md) — consumer-app PDRs that consume Web.UI
