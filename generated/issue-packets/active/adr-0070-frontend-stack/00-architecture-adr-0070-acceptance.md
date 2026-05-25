---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0070", "wave-1"]
dependencies: []
adrs: ["ADR-0070"]
accepts: ["ADR-0070"]
wave: 1
initiative: adr-0070-frontend-stack
node: honeydrunk-architecture
---

# Accept ADR-0070 — flip status, record stack-selection conventions, register the initiative

## Summary
Flip ADR-0070 (Frontend Platform Stack — React for Web, Blazor for Simple Admin, React Native + Expo for Mobile) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, and register the `adr-0070-frontend-stack` initiative in `initiatives/active-initiatives.md`. ADR-0070 explicitly defers numbered-invariant work — its four invariant-class statements are committed as **scoping conventions** enforced by per-PDR scope checks (packet 01) and per-PR review checks (packet 02), not as numbered entries in `constitution/invariants.md`.

## Context
ADR-0070 commits the Grid to three frontend toolchains, names what each is for, and explicitly disposes of the alternatives. Its decisions:

- **D1** — React + TypeScript is the default for **consumer-facing web**. Vite is the strong build-tool default; Next.js where SSR/SSG needs justify it. Blazor is not adopted for consumer web; Vue/Svelte/Solid/Angular are not adopted.
- **D2** — Blazor is permitted for **admin sites only when the admin surface is simple** — ~15 views, ~30 components, CRUD-shaped, internal/operator-facing. The first concrete Blazor consumer is the Notify Cloud tenant-operator admin per ADR-0027.
- **D3** — Every mobile surface in the Grid uses **React Native + Expo** (Expo EAS Build, Expo Notifications, Expo Router). iOS and Android come from a single codebase. MAUI is not adopted; native Swift/Kotlin is not adopted; Flutter is not adopted; Cordova/Ionic/Capacitor are not adopted.
- **D4** — The three-stack DX/test/component tax is acknowledged and accepted as the correct cost for fitness-to-purpose. The single-stack alternatives lose worse on at least one surface.
- **D5** — Cross-stack design system flows through the paired ADR-0071 Web.UI Node. Tokens and primitive CSS are stack-agnostic; React components are first-class; Blazor components ship lazily per admin-surface need; RN component implementations are deliberately separate per ADR-0071 D5.
- **D6** — Out of scope: DX-baseline `make` semantics per stack (separate ADR, named in the charter-aware draft cluster 4.1); mobile E2E tool selection (separate ADR per ADR-0047's named-but-unsolved gap); React state-management library choice (per-PDR); React build-tool choice between Vite and Next.js (per-PDR with Vite as the documented default); native-feature escape hatches (per-PDR escalation: Expo Modules → Dev Client → Bare Workflow); designer tooling adoption; frontend-side i18n runtime (deferred to a future `HoneyDrunk.Locale` Node).

ADR-0070's Consequences "Invariants" section is **explicit** that the four stack rules are **scoping conventions**, not numbered invariants:

> No new Grid-wide invariants in `constitution/invariants.md`. The following are committed conventions enforced by per-PDR scoping (the scope agent's checklist gains a "frontend stack matches ADR-0070" item at packet authoring time)…
>
> - New consumer-facing web surfaces use React + TypeScript.
> - New admin surfaces use Blazor only when they meet D2's "simple enough" test.
> - New mobile surfaces use React Native + Expo.
> - Cross-stack design assets flow through ADR-0071's Web.UI Node.
>
> If the scope agent judges any of these invariant-class at acceptance time, numbering is added then; the proposed text here treats them as scoping conventions.

**Scope-agent judgment at acceptance (this packet):** treat all four as scoping conventions, **not numbered invariants**. The enforcement surface is the scope agent's quality checklist (packet 01) and the review agent's rubric (packet 02). This decision matches the ADR's preferred posture and avoids spending an invariant-numbering slot on a policy that is naturally checked at packet-authoring and PR time rather than at canary-test time.

If a later forcing function (e.g. an out-of-policy stack lands and ships before the scope/review checks catch it) argues for hard invariant enforcement, a follow-up packet adds numbered invariants then. Today the soft-enforcement posture is correct.

ADR-0070 is a **policy ADR**. The concrete cross-stack code — the Web.UI Node's tokens/CSS/component packages, the Notify Cloud admin Blazor app, each consumer PDR's frontend scaffolding — lands in the **paired ADR-0071** initiative and in **per-PDR scaffolding packets** that cite ADR-0070's stack constraints. This initiative ships the policy substrate: acceptance, scope/review wiring, charter-draft updates, and cross-PDR reconciliation.

## Scope
- `adrs/ADR-0070-frontend-platform-stack.md` — apply two pre-acceptance body amendments (D3 known-exceptions note; Alternatives Considered "Native Swift/Kotlin" wording softened to acknowledge PDR-0005 and PDR-0008), then flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0070 row Status column to Accepted (date stays at 2026-05-23 per the existing convention that the table tracks decision date, not acceptance date).
- `initiatives/active-initiatives.md` — register the `adr-0070-frontend-stack` initiative with the packet checklist for this folder.
- **Do not** add any numbered invariants to `constitution/invariants.md` — the four stack rules are scoping conventions per the ADR's explicit instruction.
- **Do not** touch `catalogs/*.json` — there are no schema slots for "default frontend stack" per Node; the conventions live where they enforce (scope/review agents, packets 01–02). `catalogs/nodes.json` continues to track per-Node `stack` only at the existing per-row granularity.

## Proposed Implementation

### Pre-acceptance ADR amendment — acknowledge the PDR-0005/PDR-0008 carve-out

ADR-0070 as currently drafted asserts "No current or queued PDR meets that bar" (under Alternatives Considered → Native Swift/Kotlin for mobile). That statement is factually wrong at acceptance time: PDR-0005 (Hearth) and PDR-0008 (Curiosities, inheriting PDR-0004 Wayside) both commit to native Swift + Kotlin and explicitly reject RN/MAUI/Flutter. Accepting the ADR with that wording stamps a known-wrong claim into the substrate.

Before flipping Status to Accepted, edit ADR-0070's body to acknowledge the known PDR exceptions. The amendments are narrow — they record the conflict honestly without pre-committing the resolution (packet 04 is where the operator picks Path A / B / C):

**D3 — append a known-exceptions note.** After the D3 paragraph (the React Native + Expo commitment), append:

> **Known exceptions at acceptance (2026-05-24):** PDR-0005 (Hearth) and PDR-0008 (Curiosities, via PDR-0004 Wayside) explicitly commit to native Swift + Kotlin and reject RN/MAUI/Flutter for reasons documented in those PDRs (watercolor render pipeline, on-device Core ML, WeatherKit). The conflict is surfaced by the `adr-0070-frontend-stack` initiative's packet 04 (`Actor=Human`) for explicit operator resolution. Until that resolution lands, this ADR is Accepted as policy for *new* mobile surfaces; PDR-0005 and PDR-0008 are pending reconciliation.

**Alternatives Considered → "Native Swift/Kotlin for mobile" — weaken the absolute claim.** Edit the sentence:

> No current or queued PDR meets that bar.

to:

> Two queued PDRs (PDR-0005 Hearth, PDR-0008 Curiosities via PDR-0004 Wayside) explicitly commit to native Swift + Kotlin and reject the cross-platform alternatives. This conflict with D3 is surfaced by packet 04 of the acceptance initiative for explicit operator resolution (Path A: carve out the ADR; Path B: amend the PDRs; Path C: per-PDR exception note). No silent acceptance of native in either direction.

These two body edits are part of this packet's scope — they make the ADR text honest about the substrate state before the Status flip. They do not pre-decide packet 04's resolution; they only record the conflict in the ADR's own voice.

### Status flip and registration

1. Apply the two body edits above (D3 known-exceptions note; Alternatives Considered weakening).
2. Edit the ADR-0070 header: `**Status:** Proposed` → `**Status:** Accepted`. Leave the Date at 2026-05-23. No other body edits beyond the two pre-acceptance amendments above.
3. Update the ADR-0070 index row in `adrs/README.md` Status column from Proposed to Accepted. Optionally tighten the Impact text to acknowledge what is now binding (e.g., "Three-stack split: React + TypeScript consumer web; Blazor simple admin; React Native + Expo mobile. Scoping convention enforced by scope-agent checklist and review-agent rubric.").
4. Register the initiative in `initiatives/active-initiatives.md` under "In Progress" with the wave structure and packet checklist for this folder. Use the format established by sibling initiatives (see the `adr-0045-grid-wide-error-tracking` and `adr-0044-cloud-code-review` entries already in the file). Six packets, five agent/one human:
   - Wave 1: packet 00 (this packet)
   - Wave 2: packet 01 (scope-agent checklist update), packet 02 (review-agent rubric update), packet 03 (charter-aware draft sync)
   - Wave 3: packet 04 (consumer-PDR reconciliation, `Actor=Human`), packet 05 (Notify Cloud D2 re-count)
5. **Do not add invariants.** Per the ADR's explicit instruction, the four stack rules are scoping conventions. The acceptance criteria of this packet include a positive check that `constitution/invariants.md` is **not** edited.

### Cross-initiative dependency note

ADR-0071 (paired Web.UI Node standup) has a **soft cross-initiative dependency** on this packet: ADR-0071's acceptance checklist requires "Confirm the paired ADR-0070 is Accepted." ADR-0071's acceptance gates on this packet landing on `main`. The ADR-0071 initiative is filed in its own folder and does not block this packet — but downstream packets in the ADR-0071 initiative will block on packet 00 here. The dispatch plan calls this out under "ADR-0071 Pairing."

## Affected Files
- `adrs/ADR-0070-frontend-platform-stack.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No catalog schema change.
- [x] No `constitution/invariants.md` change — explicit by ADR-0070 design.

## Acceptance Criteria
- [ ] ADR-0070 D3 carries a "Known exceptions at acceptance (2026-05-24)" note naming PDR-0005 and PDR-0008 and pointing at packet 04 for resolution
- [ ] ADR-0070 "Alternatives Considered → Native Swift/Kotlin for mobile" wording is softened — the "No current or queued PDR meets that bar" sentence is replaced with the PDR-0005/PDR-0008 acknowledgment and the packet-04 reference (per Proposed Implementation)
- [ ] ADR-0070 header reads `**Status:** Accepted`
- [ ] The ADR-0070 row in `adrs/README.md` reflects Accepted; Date column unchanged at 2026-05-23
- [ ] `initiatives/active-initiatives.md` registers the `adr-0070-frontend-stack` initiative with a packet checklist mirroring the six packets in this folder
- [ ] `constitution/invariants.md` is **not edited** — the four stack rules are scoping conventions per ADR-0070's Consequences/Invariants section
- [ ] No `catalogs/*.json` edited
- [ ] No code change in any repo
- [ ] No other ADR-0070 body edits beyond the two pre-acceptance amendments above (D3 known-exceptions note; Alternatives Considered softening)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0070 D1 — React + TypeScript for consumer-facing web.** Every consumer-facing web surface uses React, TypeScript (no plain JavaScript), and a per-PDR build-tool choice (Vite is the strong default; Next.js where SSR/SSG needs justify it). Blazor is not the default for consumer web; Vue/Svelte/Solid/Angular are not adopted.

**ADR-0070 D2 — Blazor for simple admin only.** Blazor is permitted for admin surfaces meeting the "simple enough" test: fewer than ~15 distinct views, fewer than ~30 interactive components, CRUD-shaped interactivity, internal/operator-facing audience. First concrete consumer: Notify Cloud tenant-operator admin (ADR-0027). If a Blazor admin grows past D2's threshold, it migrates to React.

**ADR-0070 D3 — React Native + Expo for mobile.** Every mobile surface in the Grid uses React Native + Expo (Expo EAS Build, Expo Notifications, Expo Router). One codebase for iOS and Android. MAUI, native Swift/Kotlin, Flutter, and Cordova/Ionic/Capacitor are not adopted. Native is held in reserve for the scenario where a specific consumer PDR's UX requirements exceed what RN+Expo can deliver (no current or queued PDR meets that bar per ADR-0070's authoring at 2026-05-23 — see packet 04 for PDR-side reconciliation).

**ADR-0070 D4 — Three-stack tax acknowledged and accepted.** React + TypeScript + Vite/Next, Blazor, and React Native + Expo. The DX baseline, test infrastructure, component sharing, and operator cognitive load all carry per-stack costs; the alternative single-stack postures lose worse on at least one surface.

**ADR-0070 D5 — Cross-stack design system via Web.UI (ADR-0071).** Tokens (color, spacing, typography, radii, shadows, motion) and primitive CSS are stack-agnostic. React components are first-class. Blazor components ship per admin-surface need. RN components are deliberately separate per ADR-0071 D5 (RN's StyleSheet model makes a component fork inevitable; tokens cross over via Expo's design-system tooling).

**ADR-0070 D6 — Out of scope.** DX-baseline `make` semantics per stack; mobile E2E tool selection; React state-management library; React build-tool choice between Vite and Next.js; native-feature escape hatches; designer tooling; frontend-side i18n runtime. Each is a separate ADR or per-PDR decision.

**ADR-0070 Invariants section — scoping conventions, not numbered invariants.** The four stack rules ride on the scope-agent checklist and review-agent rubric, not on `constitution/invariants.md`. The ADR is explicit: "If the scope agent judges any of these invariant-class at acceptance time, numbering is added then; the proposed text here treats them as scoping conventions." Scope-agent judgment at this acceptance: keep them as scoping conventions.

## Constraints
- **Acceptance precedes flip.** ADR-0070 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Pre-acceptance body edits are bounded.** Only the two amendments named in Proposed Implementation (D3 known-exceptions note; Alternatives Considered softening) — these correct a factual error before the Status flip. Any further body revision is a separate ADR amendment packet, not this one.
- **No invariant numbers added.** The four stack rules are scoping conventions. The enforcement surface is the scope/review agents, not the canary tests.
- **No catalog edits.** `catalogs/nodes.json` per-Node `stack` field continues to track the per-row granularity it already does; ADR-0070's policy does not require a schema change.
- **No code edits in any repo.** This packet is governance-only.
- **ADR-0071 sequencing.** ADR-0071 (Web.UI Node standup) is paired with ADR-0070 and depends on it; ADR-0071's acceptance checklist explicitly requires "Confirm the paired ADR-0070 is Accepted (Web.UI's stack constraints derive from there)." This packet unblocks ADR-0071's acceptance; ADR-0071's standup initiative is filed separately. The dependency is soft cross-initiative: ADR-0071's initiative does not block this packet, but its downstream packets block on this one landing on `main`.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0070`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0070 to Accepted and register the frontend-stack initiative. Bind the four stack rules as scoping conventions, not numbered invariants.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0070 so packets 01–04 in this initiative can reference its decisions as live policy, and so the paired ADR-0071 (Web.UI Node) can be accepted on the strength of ADR-0070's stack commitments.
- Feature: ADR-0070 Frontend Platform Stack acceptance, Wave 1.
- ADRs: ADR-0070 (primary), ADR-0071 (paired — unblocked by this acceptance), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Two bounded pre-acceptance body amendments are required (D3 known-exceptions note; Alternatives Considered softening per Proposed Implementation), then flip Status to Accepted. No other ADR body edits.
- No numbered invariants added — the four stack rules are scoping conventions per ADR-0070's explicit instruction.
- No catalog schema change.
- No code edits in any other repo.

**Key Files:**
- `adrs/ADR-0070-frontend-platform-stack.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
