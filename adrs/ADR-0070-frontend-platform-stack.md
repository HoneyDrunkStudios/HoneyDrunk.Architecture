# ADR-0070: Frontend Platform Stack — React for Web, Blazor for Simple Admin, React Native + Expo for Mobile

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Creator / cross-cutting (frontend choice affects every consumer-facing PDR)

## Context

The Grid has no committed frontend platform. Today:

- **Studios website** is the only deployed frontend Node ([`repos/HoneyDrunk.Studios/overview.md`](../repos/HoneyDrunk.Studios/overview.md)). Its stack is settled by virtue of existing; it does not generalize to the rest of the Grid.
- **Notify Cloud admin** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) needs a tenant-operator UI. No stack is committed; the packet currently leaves the choice to the implementer.
- **Consumer-app PDRs** ([PDR-0003 Lately](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005 Hearth](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006 Currents](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008 Curiosities](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md)) all require user-facing surfaces — every one of them implies a web presence and a mobile app. None of them commit a stack.
- **No mobile platform decision has been made.** [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 7.7 flags this explicitly as an open operator question: "Big platform-direction decision; doesn't belong in a candidate document; flagging so the operator schedules it explicitly."

Without an ADR, each consumer PDR picks a stack independently — Studios is React, Notify Cloud admin might land in Blazor or React, Hearth might land in Flutter, Lately might land in React Native, Curiosities might re-derive the question. Three or four toolchains in parallel, none sharing components, design tokens, or AI-assistance leverage.

The forcing functions converging now:

- **The Hearth and Lately PDRs are next-build candidates** per the scout's queue. The signup flow ([ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) Phase 2) needs a frontend the day it lands. Without a stack ADR, Hearth picks one and sets the de-facto precedent.
- **Notify Cloud admin UI is imminent.** Tenant-operator surfaces (API key rotation, tier viewing, send-history forensics) are part of the GA scope per PDR-0002.
- **The shared design-system Node ([ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md), paired with this ADR)** has no target stack to ship components against without this decision.
- **AI multiplier matters for stack selection.** The charter's AI-multiplier bet ([`constitution/charter.md`](../constitution/charter.md) §"The AI multiplier") implies the Grid should prefer stacks where Claude, Codex, and Copilot have the deepest training corpus and the most mature pattern recognition. The ecosystem with the largest 2026 AI-assistance leverage is React/TypeScript; the second-largest is .NET; the third is Swift/Kotlin native. Stacks outside that gradient (Flutter, alternative frameworks) deliver less per token of agent attention.

The charter also frames the cost honestly. From [`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids":

> Architecture-as-procrastination. Even in a workshop, the foundation eventually has to serve the cool stuff being built on top of it.

A frontend-stack ADR is foundation work that **directly serves the cool stuff** — every consumer PDR consumes it on day one. The ADR is correctly-timed.

This ADR commits the three-stack split, names the boundaries, and explicitly disposes of the alternatives (single-stack, alternative ecosystems).

## Decision

### D1 — React is the default for consumer-facing web

Every consumer-facing web surface in the Grid uses **React** as the frontend framework. "Consumer-facing" means any product surface that an end user interacts with — Hearth's web companion, Lately's web preview, Curiosities' web map, any future PDR-driven consumer site.

The committed shape:

- **React** (current stable major, kept current via the Web.UI Node's cadence per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md)).
- **TypeScript** (no plain JavaScript for new work — the type safety is load-bearing for solo-dev velocity and AI-assistance accuracy).
- **Build tooling per consumer-PDR choice** (Vite is the strong default; Next.js if a PDR has server-rendering needs that justify it). The Web.UI Node ([ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md)) ships its tokens/CSS as build-tool-agnostic packages.

**Why React over alternatives for consumer web:**

- **Ecosystem depth.** Component libraries (Radix, shadcn, Mantine, Chakra), state-management options (Zustand, Jotai, TanStack Query), routing (TanStack Router, React Router), animation (Framer Motion), data-fetching, testing — all are first-tier mature in 2026. No other framework has the breadth.
- **AI-assistance leverage.** Claude, Codex, and Copilot have the deepest training depth on React + TypeScript in 2026. Pattern recognition on JSX, hooks, common library shapes, and recent best practices is markedly stronger than on Vue, Svelte, Solid, or Blazor. For a solo-dev shop running on the AI-multiplier bet, the per-token-of-agent-attention productivity gradient is the single most important selection factor.
- **Designer tooling alignment.** Figma export-to-React workflows, design-system tooling (Storybook is React-native), and the broader UX ecosystem assume React-shaped components. Solo-dev shops without a dedicated designer benefit disproportionately from tooling alignment.
- **Long-term ecosystem stability.** React is older than every meaningful alternative and has survived multiple "is React dying" cycles. The many-decade horizon ([`constitution/charter.md`](../constitution/charter.md) §"What this is") favors the framework with the longest survivability runway.

The negative form: Blazor is not the default for consumer web; Vue / Svelte / Solid are not adopted; Angular is not adopted.

### D2 — Blazor is permitted for admin sites only when the admin surface is simple

**Blazor** is permitted for the Grid's admin surfaces when the surface is **simple enough** that the productivity win of staying in .NET (one language end-to-end, shared types between server and UI, no separate frontend build pipeline, no TypeScript translation layer) outweighs the lost React ecosystem.

The decision test for "simple enough":

- **Surface size.** Fewer than ~15 distinct views, fewer than ~30 interactive components. Anything larger pulls in the kind of component-library and state-management surface that React's ecosystem covers better.
- **Interactivity profile.** CRUD-style forms, tables with filtering and pagination, modal flows, and simple charts are well within Blazor's comfort zone. Heavy real-time interaction, complex animation, drag-and-drop interfaces, or canvas/SVG-heavy work argue for React.
- **Audience.** Internal admin / operator-facing surfaces (a single user, the operator) tolerate Blazor's defaults; consumer-facing surfaces (millions of potential users, brand-sensitive UX) deserve the React ecosystem's polish.
- **AI-assistance gradient.** Blazor pattern recognition in 2026 AI tools is meaningful but trailing React. The simpler the Blazor surface, the smaller the gradient's cost.

**Concrete first applications:**

- **Notify Cloud tenant-operator admin** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) — likely Blazor at v1 (small surface, CRUD-shaped, single-operator-per-tenant audience). If it grows past D2's threshold, migrates to React.
- **Studios admin internals** ([repos/HoneyDrunk.Studios/overview.md](../repos/HoneyDrunk.Studios/overview.md)) — already React; not migrated.
- **Future per-Node admin consoles** — case-by-case. Simple Vault rotation status pages: Blazor. Complex Operator approval queues with real-time agent activity: React.

The cost of permitting Blazor: a third toolchain to maintain. The benefit: meaningful DX wins on the surfaces where Blazor fits well, and a hedge against React lock-in for the surfaces that are inside the .NET-native productivity gradient.

**Why not React-only:** Two arguments rejected. (a) "One stack is simpler" — true, but loses real productivity on admin surfaces where Blazor's shared-type and shared-language story is concretely better. (b) "Eventually the admin surface always outgrows simple" — sometimes true, but the migration cost from Blazor to React is bounded (the surface is small by definition; the migration is a rewrite of < 30 components), and prematurely paying React's complexity tax on every admin is an over-correction.

### D3 — React Native + Expo for mobile

Every mobile surface in the Grid uses **React Native + Expo**. iOS and Android come from a single codebase; the operator does not maintain two native apps.

The committed shape:

- **React Native** (current stable; tracked by the Web.UI Node's cadence where applicable).
- **Expo** (the managed React Native runtime — eliminates most of the native-toolchain pain that vanilla RN imposes on a solo dev).
- **Expo EAS Build** for app builds (cloud-built; no local Xcode / Android Studio dance for routine builds).
- **Expo Notifications** for push (per [ADR-0073 D3](./ADR-0073-notify-default-providers.md)).
- **Expo Router** for routing (file-based, React Router-shaped).

**Why React Native + Expo over alternatives:**

- **Reuses React skills.** A solo dev who is fluent in React/TypeScript per D1 carries 80%+ of that fluency into React Native. The cognitive switching cost is the smallest of any cross-stack mobile choice.
- **Ecosystem maturity in 2026.** RN + Expo has converged on stable patterns for navigation, push, deep linking, OTA updates (Expo Updates), and AI-assistance coverage. The 2023-era "RN is fading" narrative did not survive — Expo's stewardship and the React-team alignment have made it the default cross-platform stack for solo and small-team shops.
- **Solo-dev viability.** Two-platform mobile development without RN's abstractions is a non-starter for one human. Native Swift + Kotlin requires maintaining two codebases, two testing surfaces, two release pipelines, and two deeply different toolchains. The AI-multiplier does not close that gap.
- **Expo eliminates the worst RN pain points.** Pre-Expo, RN required local Xcode + Android Studio dance, native-module-linking errors, and a fragile build chain. Expo Managed Workflow removes most of that for the cases the Grid will hit; Expo Dev Client handles the rest.
- **AI-assistance leverage.** Claude/Codex/Copilot pattern recognition on RN + Expo in 2026 is materially deeper than on Flutter or MAUI. The same React-ecosystem reasoning from D1 applies.

The negative form: MAUI is not adopted; native Swift/Kotlin is not adopted; Flutter is not adopted; Cordova / Ionic / Capacitor are not adopted.

### D4 — The three-stack tax is acknowledged and accepted

The Grid is now committed to three frontend toolchains:

- **React + TypeScript + Vite/Next** (consumer web)
- **Blazor** (simple admin)
- **React Native + Expo** (mobile)

That is more toolchains than a single-stack policy would carry. The cost is real:

- **DX baseline must cover all three.** The future DX-baseline ADR (per the [charter-aware draft](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 4.1) must declare `make repo` / `make test` / `make pack` semantics for React, Blazor, and RN+Expo repos. Each toolchain's idioms differ.
- **Test infrastructure splits.** Per [ADR-0047 D5](./ADR-0047-testing-patterns-and-tooling.md), Playwright handles web E2E (works for both React and Blazor surfaces — Playwright is framework-agnostic at the browser layer); mobile E2E needs a separate tool (per ADR-0047's named-but-unsolved mobile-E2E gap). Maestro is the strong default for RN+Expo; commitment lives in the mobile-E2E ADR that ADR-0047 names.
- **Component sharing is per-stack, not Grid-wide.** [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) handles tokens + CSS as the cross-stack shared layer; component implementations are per-stack. A React `<Button>` and a Blazor `<Button>` and a RN `<Button>` are three implementations of one design contract.
- **Operator cognitive load.** Switching contexts between React, Blazor, and RN within the same week is a real tax on a solo dev. The mitigation: the three stacks share more than they differ (TypeScript ≈ C# at the type-system level; React ≈ RN at the component-model level; Blazor's component syntax is React-shaped in many ways).

This ADR explicitly chooses the three-stack tax as the **correct cost** for fitness-to-purpose. The single-stack alternatives (D6) all force worse trade-offs on at least one surface.

### D5 — Cross-stack design system via HoneyDrunk.Web.UI

Tokens, CSS, and design contracts ship from the paired [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) Node `HoneyDrunk.Web.UI`. The relationship to this ADR:

- **Tokens (color, spacing, typography, radii, shadows, motion)** are stack-agnostic — they ship as a CSS-variables file and a JSON tokens file that any of the three stacks can consume.
- **Primitive CSS** (base layer, reset, typography) ships as a CSS bundle consumable from React, Blazor, and any web context.
- **React components** are the first-class component implementations. Blazor components ship when an admin surface needs one; the default posture is "tokens + CSS only" for Blazor surfaces, with component-level work added per-surface.
- **React Native components** are deliberately separate per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) D5 — RN's styling model (StyleSheet objects, not CSS) makes a component-level fork inevitable. Tokens cross over via Expo's design-system-friendly tooling; component shapes track the React web components for visual consistency.

The Web.UI Node is the single home for design decisions. Per-PDR consumer apps consume it; no PDR rewrites the design system locally.

### D6 — Out of scope

The following are explicitly **not** decided by this ADR:

- **DX baseline per stack.** `make` / task runners / repo conventions per stack are the DX-baseline ADR's scope (per the charter-aware draft cluster 4.1).
- **Mobile E2E tool selection.** Named-but-unsolved by [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md). A follow-up ADR commits Maestro vs. Detox vs. alternative; this ADR pins the mobile platform that the tool serves.
- **State-management library choice for React.** Per-PDR decision. The Web.UI Node ([ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md)) does not opinionate.
- **Build-tool choice for React (Vite vs. Next.js vs. Remix).** Per-PDR decision based on rendering needs. Vite is the strong default; Next.js if a PDR has SSR/SSG needs that justify it.
- **Native-feature escape hatches.** When a mobile feature requires Expo Modules / native code that Expo Managed Workflow does not cover, the per-PDR escalation path (Expo Dev Client → Expo Bare Workflow → custom native module) is documented at the consuming PDR, not here.
- **Designer tooling adoption.** Figma + design-token export workflows live with the Web.UI Node's evolution, not here.
- **Internationalization runtime for the frontend.** Per the charter-aware draft cluster 7.6, a `HoneyDrunk.Locale` Node is a future-state concern; this ADR does not commit a frontend-side i18n library.

## Consequences

### Affected Nodes

- **HoneyDrunk.Web.UI** (new — stood up by paired [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md)) — receives the stack constraints from D1, D2, D5. React is the first-class stack; Blazor components are second-class additions per admin-surface demand.
- **HoneyDrunk.Studios** ([repos/HoneyDrunk.Studios/overview.md](../repos/HoneyDrunk.Studios/overview.md)) — already React; this ADR ratifies the existing stack rather than forcing a migration.
- **HoneyDrunk.Notify.Cloud** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) — tenant-operator admin lands in Blazor per D2 unless the surface complexity pushes past the threshold.
- **Consumer-app PDRs** ([PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md)) — each consumes this ADR's stack constraints. Web surfaces in React; mobile surfaces in React Native + Expo.

### Invariants

No new Grid-wide invariants in `constitution/invariants.md`. The following are committed conventions enforced by per-PDR scoping (the scope agent's checklist gains a "frontend stack matches ADR-0070" item at packet authoring time):

- New consumer-facing web surfaces use React + TypeScript.
- New admin surfaces use Blazor only when they meet D2's "simple enough" test.
- New mobile surfaces use React Native + Expo.
- Cross-stack design assets flow through [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md)'s Web.UI Node.

If the scope agent judges any of these invariant-class at acceptance time, numbering is added then; the proposed text here treats them as scoping conventions.

### Operational Consequences

- **The Grid pays a three-toolchain DX tax.** Each toolchain has its own build pipeline, test runner, IDE plugins, and version cadence. The mitigation is the AI multiplier — three toolchains, all in the AI-assistance gradient, is sustainable for one human in a way it would not have been five years ago.
- **Component implementations split per stack.** A new design system component requires React, Blazor (if used in admin), and RN implementations — three implementations of one design contract. The Web.UI Node owns the contract; the surface-cost is real but bounded by D2 (Blazor components only when needed).
- **AI-assistance gradient becomes a stack-selection input for future ADRs.** Adopting a stack outside the React/.NET/native gradient (e.g., Elm, Svelte, Solid) carries the AI-multiplier cost and must justify the trade in the ADR that proposes it.
- **Mobile E2E remains an open gap.** [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) names mobile E2E as unresolved; this ADR pins the platform the future tool serves (RN+Expo → Maestro is the strong candidate), but does not close the testing-tool gap.
- **Vendor risk is bounded by the wrapping pattern.** Expo is a vendor on top of React Native; if Expo's pricing or stewardship deteriorates, the migration path is RN bare-workflow — bounded cost, no wholesale platform change. React is a Meta project but governance and ecosystem breadth make capture risk low. Blazor is Microsoft-owned and aligned with the existing Azure / .NET posture.

### Follow-up Work

- The Web.UI Node ([ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md)) ships tokens, CSS, and the first React component pack.
- The DX-baseline ADR (per [charter-aware draft cluster 4.1](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md)) commits per-stack `make repo` / `make test` / `make pack` semantics.
- The mobile-E2E ADR (per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) gap) commits Maestro or equivalent.
- Notify Cloud admin UI packet ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) follow-up) lands in Blazor under D2.
- Hearth / Lately / Curiosities PDRs each consume this ADR; their first scaffolding packets cite stack compliance.
- Per-PDR mobile build pipeline (Expo EAS) configuration lands when the first mobile PDR enters scaffolding.

## Alternatives Considered

### Blazor everywhere (consumer web and admin)

Considered. The argument: one stack, one language end-to-end, full .NET-native sharing of types, no JavaScript ecosystem to maintain.

Rejected. The React ecosystem on consumer-facing surfaces is decisively larger across every dimension that matters for shipped consumer products — component libraries, designer tooling, hiring-optionality at scale, and AI-assistance leverage. A "Blazor everywhere" Grid would underserve every consumer PDR for the marginal admin-side win. The cost is asymmetric: Blazor wins meaningfully on simple admin and loses meaningfully on consumer surfaces. The split (D1 + D2) captures the win without paying the loss.

### React everywhere (including all admin surfaces)

Considered. The argument: one toolchain (collapsing D1 and D2), no per-surface decision tax, simpler operator cognitive model.

Rejected. The "one language end-to-end" win for simple admin surfaces is concrete — shared types between server and UI (no DTO duplication), single dotnet build, no separate frontend pipeline. Forcing React on a 15-view CRUD admin pays React's full complexity tax (build pipeline, dependency tree, npm vulnerability surface, separate test runner) for surfaces where Blazor's defaults are concretely better. The escape valve (D2's "simple enough" test) is precisely the case where Blazor wins; foreclosing it gains nothing.

### MAUI for mobile

Considered. The argument: MAUI is Microsoft's cross-platform mobile stack, aligns with the .NET-deep Grid posture, allows shared types with .NET backends.

Rejected. MAUI's ecosystem momentum in 2026 is materially behind RN+Expo. Component libraries are thinner; AI-assistance pattern recognition is markedly weaker (Claude/Codex/Copilot have much less training-corpus depth on MAUI); the build and deployment story is less polished; the Expo-equivalent managed-workflow does not exist. The "shared .NET types with backend" argument is real but bounded — type-sharing across an HTTP boundary is a generated-SDK problem ([ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md)), not a runtime-stack problem. RN+Expo with TypeScript and a generated TS client is the same shape of solution with a larger ecosystem.

If MAUI's 2027–2028 trajectory closes the gap meaningfully (Microsoft has invested significantly), this ADR is revisable. Today the answer is RN+Expo.

### Native Swift/Kotlin for mobile

Considered. The argument: maximum native UX fidelity, maximum platform-feature access, no cross-platform abstraction tax.

Rejected. Solo-dev with two native codebases is not viable. The maintenance burden — two test surfaces, two release pipelines, two language ecosystems, two SDKs to track — exceeds what one human plus AI agents can sustain on the charter's many-decade horizon. The AI-multiplier does not close this gap; native iOS and native Android each carry their own AI-assistance gradients that do not compound. Native is held in reserve for the scenario where a specific consumer PDR's UX requirements exceed what RN+Expo can deliver (e.g., a graphics-intensive consumer app where the native rendering pipeline matters). No current or queued PDR meets that bar.

### Flutter for mobile

Considered. The argument: Dart + Flutter's rendering engine produces high-fidelity UI, single codebase for iOS + Android (and optionally web/desktop), strong tooling.

Rejected on two grounds. (a) Flutter adds **two new toolchains** to the Grid (Dart the language; Flutter the framework) where React Native adds **one** that reuses the React D1 fluency. The marginal toolchain cost is concretely worse. (b) AI-assistance leverage on Flutter+Dart in 2026 is meaningful but trailing React+TypeScript. The per-token-of-agent-attention gradient favors RN. The "Flutter web" angle (one codebase for mobile *and* web) is intellectually attractive but Flutter web's production maturity remains weaker than React for consumer surfaces, so the win does not materialize in practice.

Reconsidered if Flutter's AI-assistance gradient closes and a consumer PDR's UX needs specifically benefit from Flutter's rendering model.

### Cordova / Ionic / Capacitor for mobile

Considered. Hybrid mobile (web-tech inside a native shell) reuses web skills 1:1.

Rejected. UX quality for consumer apps in 2026 is not competitive with native-shape RN/Flutter/native experiences. The hybrid approach earns its keep on internal apps and prototypes; consumer-grade product surfaces demand the native-feel that RN delivers. The PDR set targets consumer-facing products; hybrid does not meet that bar.

### Skip the ADR and let each consumer PDR pick its own stack

Considered. The argument: stack choice is a PDR concern; the Architecture repo should not opinionate on frontend.

Rejected. Without an ADR, each PDR re-derives the question, each picks differently, and the Grid ends up with three React variants, a Blazor admin, a Flutter consumer app, a native iOS prototype, and zero shared design assets — exactly the outcome the Web.UI Node ([ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md)) exists to prevent. Stack-level coherence is the precondition for design-system coherence; design-system coherence is the precondition for cross-PDR substrate ROI. Skipping this ADR is the architecturally-regressive choice the charter's §"What this charter forbids" item 2 names: foundation that fails to serve the cool stuff being built on top of it.

### Adopt Next.js as the universal React framework (instead of leaving build-tool choice per-PDR)

Considered. The argument: one React framework eliminates intra-React-camp drift; Next.js is the closest thing to a "default" in 2026.

Deferred, not rejected. Next.js is a strong default for surfaces with server-rendering needs; Vite is a stronger default for SPA-shaped surfaces. Forcing Next.js on every consumer PDR pays Next.js's complexity tax (server runtime, deployment shape, framework-specific patterns) on surfaces where it does not earn its keep. The per-PDR choice with Vite as the documented default is the cheaper substrate posture today. If consumer PDRs converge on SSR needs, a future ADR may pin Next.js Grid-wide.

### Adopt Svelte / Solid / Qwik instead of React

Considered. Each is a credible 2026 alternative with smaller bundles and (arguably) cleaner DX in narrow dimensions.

Rejected. The AI-assistance gradient is the deciding factor. Claude/Codex/Copilot's React+TypeScript pattern recognition in 2026 is markedly deeper than for any of the alternatives; the per-token-of-agent-attention productivity gradient is the single most important selection factor for a solo-dev shop running on the AI-multiplier bet. The alternatives may be technically attractive, but the productivity cost is real and unrecouped. Reconsidered if the AI-assistance gradient converges across frameworks (likely in the 2028–2030 timeframe); today React is the right choice.

## References

- [`constitution/charter.md`](../constitution/charter.md) — workshop framing, AI multiplier, many-decade horizon
- [`constitution/invariants.md`](../constitution/invariants.md) — invariant set this ADR honors
- [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) — Notify Cloud admin (first Blazor consumer)
- [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) — testing patterns; mobile E2E gap referenced
- [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) — SDK generation (cross-stack type sharing)
- [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) — paired Web.UI Node standup
- [ADR-0073](./ADR-0073-notify-default-providers.md) — Expo Notifications as the push provider
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) — Web.UI Node candidate context; DX-baseline ADR named as follow-up
- [PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md) — consumer-app PDRs that consume this ADR's stack choices
