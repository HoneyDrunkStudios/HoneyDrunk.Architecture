# PDR-0008: Curiosities — Discovery-First City App

**Status:** Proposed
**Date:** 2026-05-16
**Deciders:** HoneyDrunk Studios
**Sector:** Market / Location / AI / Play
**Codename:** Curiosities (final product name TBD)
**Supersedes:** PDR-0004 (Wayside), PDR-0007 (Arcadia)

---

## Supersession Note

This PDR replaces two prior recorded directions and resolves the tension between them:

- **PDR-0004 (Wayside)** recorded a walking + place-memory app whose lead loop was *passive private place-memory* (auto-detected walks become Mochi chapters) plus a *public marginalia* UGC layer, with the question-mark unlock mechanic absorbed as a kill-switched v1.5 "Curiosities" mode (§P).
- **PDR-0007 (Arcadia)** recorded a standalone city quest-map app built on the question-mark unlock loop, then killed it and folded its ideas into PDR-0004 §P.

PDR-0008 **inverts PDR-0004's priority.** The curated question-mark discovery loop is no longer a v1.5 additive mode behind a kill switch — it is the **lead product loop at v1**. Private place-memory and Mochi are retained as the **memory backbone** that makes discoveries stick and drives retention, but they are the supporting layer, not the headline. The public marginalia UGC layer — identified in PDR-0004 §Problem-2 as "the highest-risk feature in the entire concept" — is **cut from v1** and deferred to a post-v1 bet.

The substantive product content of PDR-0004 and PDR-0007 is preserved in those documents as historical record and remains the source for detail on Mochi's persona constraints (PDR-0004 §D), the watercolor map pipeline (PDR-0004 §E), the moderation stack should public notes ever return (PDR-0004 §C), and the original quest-template and collectible design (PDR-0007 §D–§E). This PDR records only the deltas and the new product spine.

What does **not** change as a result of this supersession:

- **PDR-0002 (Notify Cloud)** remains the Grid's first commercial product and first revenue milestone.
- **PDR-0005 (Hearth)** remains the recorded first consumer-facing app on the Grid. Curiosities does not jump the build queue; it is direction-only, sequenced behind Notify Cloud and Hearth.
- Core Grid invariants are unchanged. No new Node, Sector, or invariant is introduced by this PDR.

---

## Context

The studio is exploring consumer apps with soul — products that make ordinary life feel more interesting without becoming feeds, chores, or grind systems. Three recorded consumer directions touch adjacent territory: Hearth (personal growth as a living town, PDR-0005), Lately/Currents (connection and social suggestions, PDR-0003/0006), and the now-superseded Wayside/Arcadia pair.

PDR-0004 and PDR-0007 between them carried two different emotional cores for a place-based app:

- **The Wayside core:** *"My walks become memory."* Passive, retention-first, journaling-shaped. The screenshot moment is a stranger's note on the bench you're sitting on.
- **The Arcadia core:** *"The city map has question marks; I uncover them."* Active, discovery-first, collection-shaped. The screenshot moment is the corner you pass every day turning out to contain something.

PDR-0004's amendment subordinated the Arcadia core to the Wayside core and bounded it behind a v1.5 kill switch. The studio has since decided the discovery core is the stronger v1 spine for a solo studio, for three reasons developed in this PDR: it removes the two-sided cold-start problem, it defers the highest-risk feature, and it produces a more demoable and more obviously sellable v1.

The cost of this inversion is also clear and is the central subject of this PDR: **content production becomes the v1 critical path.** PDR-0007 §49 named this as the single thing that kills a city-discovery app for a solo studio. Wayside had this risk bounded as a v1.5 experiment; Curiosities-first re-arms it as a v1 obligation. This PDR's decision is therefore primarily about the content model, the v1 scope cut, and the kill criteria that keep the content bet honest.

---

## Problem Statement

### 1. Cities are full of overlooked places, and maps are too utilitarian

People move through their cities on habitual routes, passing murals, plaques, old buildings, strange stores, and public art without noticing them. Google Maps, Yelp, Atlas Obscura, and tourism sites answer "where should I go?" but rarely create the feeling of discovery, mystery, or collection. The unmet emotional niche is *the city as a playable world you uncover*, not *the city as a directory you search*.

### 2. The discovery loop must carry acquisition, not just retention

PDR-0004 §P.8 argued that question-mark unlocks are "most valuable to users who already have Wayside on their phone — a retention asset, not an acquisition wedge." Curiosities-first deliberately rejects that constraint: the discovery loop must now do the cold-start work of *acquiring* users, because it is the headline. This is a harder bar than the one PDR-0004 set for the same mechanic, and the product must be designed to clear it (a strong first-session uncover, a demoable launch district, paid-pack legibility).

### 3. Content production is the critical path and the primary kill risk

A discovery app dies if every place needs bespoke editorial writing, custom art, manual quest design, and ongoing maintenance. Wayside could afford to treat this as a bounded v1.5 experiment. Curiosities-first cannot — the curated POI pipeline is the v1 product. If 50–100 quality curated places per launch district cannot be produced and maintained at a sustainable pace by a solo dev plus AI agents, the product does not ship.

### 4. The walking backbone must serve discovery without diluting it

PDR-0004's passive walk-journal is a genuine retention engine, but its emotional posture (effortless, poetic, no-ask) is different from the discovery loop's posture (go out, chase, uncover). Demoting walking to a backbone risks two failure modes: the backbone becomes vestigial and adds no retention, or it competes with the discovery loop for the user's attention and muddies the product. The relationship must be explicitly designed, not assumed.

### 5. Location products carry safety and moderation risk

Any app that points users at physical places can route them to unsafe locations, private property, sensitive facilities, or places inappropriate at certain hours. Curiosities-first *reduces* this risk versus Wayside by cutting the public UGC layer from v1 — but curated POI selection still carries safety obligations, and every published v1 place must be human-reviewed against an explicit safety policy.

---

## Decision

### A. Curiosities is a discovery-first city app; the curated unlock loop is the lead

The product's primary loop, the thing the first session must deliver and the thing marketing leads with:

1. The user opens a stylized watercolor city map (the PDR-0004 §E pipeline, unchanged).
2. Nearby unknown points appear as **question marks**.
3. The user physically approaches a point.
4. The point **unlocks** into a named place card.
5. The card gives short context, one optional micro-action (a lightweight prompt template), and a collectible entry.
6. The user's city atlas fills in over time as a collection of what they uncovered.

The product promise is **"go outside, follow curiosity, uncover your city"** — discovery and collection as the headline, not "best places near me" and not "your walks become a journal."

### B. Walking + Mochi is the memory backbone, not the headline

The PDR-0004 private place-memory layer is retained, re-scoped as the connective tissue of discovery:

- Auto-detected walks still become illustrated chapters narrated by Mochi (PDR-0004 §D persona constraints unchanged — one voice, no input box, no advice, no parasocial register).
- The framing shifts: chapters are now **"the record of how you found things"** — the path between unlocks, the walk on which you uncovered three curiosities, the season you filled in a district. The walk-journal is the *substrate* the discoveries are pinned into, which is what makes a collected curiosity feel earned rather than tapped.
- This layer remains the **retention engine**: users come back for their accumulating atlas and Mochi's continuity, not only for new question marks. Discovery is the acquisition and first-session magic; the memory backbone is why week 6 still matters.

### C. Public marginalia (UGC) is cut from v1

PDR-0004's anonymous public place-notes layer — its self-identified highest-risk feature, carrying two-sided cold start, abuse, and a six-layer moderation obligation — is **not in Curiosities v1**. Consequences:

- v1 ships with **zero UGC**. All content is curated and human-approved. The §C six-layer moderation stack from PDR-0004 is not built for v1.
- This is the single largest risk reduction of the inversion: the scariest feature is deferred, not merely demoted.
- Public marginalia becomes a **post-v1 candidate bet**, not a recorded commitment. If it ever returns, it returns through PDR-0004 §C's full moderation stack and gets its own decision record. It is explicitly out of scope here.

### D. Content model: open data + AI-assisted enrichment, human-approved, curated-only

The v1 content pipeline (inherited from PDR-0007 §C, now load-bearing rather than experimental):

- **Open/public data sources** — landmarks, public art registries, historical markers, Wikipedia/Wikidata, OpenStreetMap, parks, public buildings, archive material where licensing allows.
- **AI-assisted summarization** — short plain-language place cards and curiosity hooks, generated then reviewed.
- **Human approval** — every published v1 place is reviewed by HoneyDrunk before it appears. Curated-only keeps the review burden bounded to the launch-district footprint.
- **Reusable templates** — prompts are generated from a small safe set, not bespoke-designed per location.
- **Mochi narrates unlock cards in Wayside's voice** (PDR-0004 §D / §P.3). No separate game-y narrator. Unlock-card prose is indistinguishable from a walk chapter.

The content bar: good enough to make a walk feel intentional, not academic enough to become a museum app.

### E. V1 is one dense launch district, not a thin global map

Curiosities v1 is constrained to **one dense, walkable launch district inside one launch city.** A credible v1 footprint:

- 50–100 human-reviewed curated POIs.
- 5–10 themed collections.
- A small set of safe prompt templates (PDR-0007 §D: Look Closely, Then/Now, Sound of the Corner, Color Hunt, Public Art Scan, Tiny Detour, Postcard Moment).
- No UGC. No business listings beyond selected curiosity content. No routing into private property, sensitive facilities, schools, or isolated/time-risky locations.

The first release must feel handcrafted in one place rather than thin everywhere. Geographic expansion is district-by-district, each new district paying the same curated content cost.

### F. Collectibles are emotional, not addictive

Inherited unchanged from PDR-0007 §E: place stamps, district cards, architectural motifs, local-legend fragments, public-art styles, historical-era tags, contextual memories ("first rain walk," "golden hour find"). No XP, levels, streaks, leaderboards, scarcity manipulation, daily pressure, or expiring collectibles. Collection rewards attention, not compulsion. The collection book lives inside the atlas surface.

### G. The Atlas is reframed as a discovery artifact, and remains the revenue hook

PDR-0004 §K's Yearly Atlas print-on-demand hook is retained and **strengthened by the inversion**. The Atlas is no longer "a book of your walks" — it is **"the atlas of what you uncovered this year"**: collected curiosities, the districts you filled in, the walks between them rendered as connective chapters. A discovery artifact is a more giftable, more screenshot-worthy, more obviously valuable object than a pure walk journal. The print-on-demand pipeline and pricing logic from PDR-0004 §K/§L carry forward; only the framing changes.

### H. Monetization: city/district packs and a founding tier, then Atlas

Aligned with PDR-0007 §G and PDR-0004 §L:

- Paid curated **city/district packs** — the cleanest early willingness-to-pay test.
- **Founding Explorer** lifetime tier for the launch city.
- **Yearly Atlas** print-on-demand (§G) as the recurring revenue hook.
- No ads in v1. No selling location trails. No dark-pattern notification loops. Partner/sponsored packs only after trust exists, clearly labeled, never mixed into organic question marks.

### I. Sequencing — direction-only, behind Notify Cloud and Hearth

This PDR is a **commitment to direction, not to immediate build.** It does not change the build queue:

- Notify Cloud (PDR-0002) remains the first commercial milestone.
- Hearth (PDR-0005) remains the first consumer-facing app built.
- Curiosities is the recorded next-place-app direction *for when the studio takes that swing*, with the product shape, content model, and risk posture pre-decided so a future build packet has strategic ground to stand on.

### J. Tech stack and Grid dependencies — inherited from PDR-0004

The PDR-0004 §I tech-stack position (mobile-first, iOS-first, .NET backend) and §J Grid-dependency posture carry forward unchanged. Cutting UGC from v1 *removes* the moderation-pipeline dependency for v1; it does not add any new Grid dependency. If backend services are introduced they follow Grid context, tenant, secrets, telemetry, packaging, and deployment invariants.

---

## Options Evaluated

### Option 1: Keep PDR-0004 as written (Wayside-first, Curiosities as v1.5 mode)

**Pros**

- No new decision record; the chain of prior decisions stays intact.
- Passive walk-journal is a proven retention shape; Curiosities stays bounded behind a kill switch.

**Cons**

- v1 carries the public UGC layer — the self-identified highest-risk feature — with full two-sided cold-start and moderation cost.
- The strongest demoable, most obviously sellable loop (curated discovery, paid packs) is buried at v1.5 behind a kill switch.

**Verdict:** Reject. The studio's read is that the discovery loop is the stronger v1 spine and the UGC layer is the right thing to defer.

### Option 2: Revive standalone Arcadia (PDR-0007) as the product

**Pros**

- Honest to what a discovery-first product is.
- No Wayside scar tissue.

**Cons**

- Throws away the Mochi voice and the walk-memory retention backbone, which are the studio's strongest differentiators and the answer to "why is week 6 still good."
- Re-pays every walking/map/voice cost Wayside already designed.

**Verdict:** Reject. The discovery loop needs the memory backbone for retention; a pure quest map has the novelty-decay problem (PDR-0007 §Risk-4) with no answer.

### Option 3: New superseding PDR — Curiosities-first, walk-memory backbone, UGC cut from v1 (Selected)

**Pros**

- Discovery loop leads (acquisition + first-session magic); walk-memory backbone answers retention.
- Highest-risk feature (public UGC) deferred out of v1 entirely.
- Most demoable and most obviously monetizable v1 (curated packs, discovery Atlas).
- One clean record rather than amendment scar tissue across 0004/0007.

**Cons**

- Content production becomes the v1 critical path — the single largest kill risk (PDR-0007 §49).
- Discovery loop must now carry acquisition, a harder bar than PDR-0004 set for the same mechanic.

**Verdict:** Recommended. The cons are real and are the subject of the Risks and Kill Criteria sections; the studio accepts them as the right risk to take for a solo-studio v1.

### Option 4: Content pipeline spike only, no app

**Pros**

- De-risks the hardest part (scalable curated content) before mobile work.

**Cons**

- Does not test the embodied unlock loop or the acquisition bar.
- Easy to overbuild tooling without user signal.

**Verdict:** Useful as a Phase-0 prerequisite spike, not the product decision. Folded into Rollout.

---

## Trade-offs

| Trade-off | Position | Rationale |
|---|---|---|
| Discovery-first vs. walk-memory-first | **Discovery-first** | Discovery is the acquisition wedge and first-session magic; walk-memory alone is retention without a hook. The inversion puts the demoable, sellable loop in front. |
| Public UGC at v1 vs. cut from v1 | **Cut from v1** | The self-identified highest-risk feature (PDR-0004 §Problem-2). Cutting it removes two-sided cold start and the six-layer moderation build from v1. Largest single risk reduction. |
| Curated content as v1 critical path vs. v1.5 experiment | **v1 critical path** | Accepted cost of leading with discovery. Bounded by the one-dense-district cap and an explicit content kill criterion (§O). |
| Walk-memory cut vs. retained as backbone | **Retained as backbone** | A pure quest map has unanswered novelty decay (PDR-0007 §Risk-4). Mochi + accumulating atlas is the retention answer and the studio's strongest differentiator. |
| Atlas as walk-journal vs. discovery artifact | **Discovery artifact** | A "what you uncovered this year" book is more giftable and sellable than a walk diary; strengthens the §K revenue hook rather than weakening it. |
| Build now vs. direction-only | **Direction-only** | Notify Cloud (PDR-0002) and Hearth (PDR-0005) keep their queue positions; this PDR pre-decides shape, not schedule. |

---

## Architecture Implications

Curiosities is a consumer app surface under the Apps/Market product line, not a Core Grid Node. No existing Grid invariant changes.

Relative to PDR-0004's recorded architecture, the deltas are **subtractions and a reframe**, not new surface:

- **No public-UGC moderation pipeline at v1.** PDR-0004 §C's six-layer stack is not built for v1. This removes the largest backend and policy surface from the v1 architecture.
- **No new Notify/Communications event types at v1.** "A question mark appeared near you" pushes remain explicitly out of scope; the loop is pull-by-curiosity, not push-by-nudge.
- **Curated content pipeline becomes a v1 system, not a v1.5 one.** Source ingestion, AI-assisted enrichment, an editorial review queue, and a repeatable district-pack build process move onto the v1 critical path. Potentially informed by Lore/Knowledge ingestion patterns later; no dependency taken now.
- **Mochi prose binding** runs unlock cards through the existing on-device persona (PDR-0004 §D) with a Curiosities prompt addendum. No new on-device model; no new cloud surface.
- **Watercolor map pipeline** (PDR-0004 §E) carries forward unchanged.

If backend services are introduced they must follow Grid context, tenant, secrets, telemetry, packaging, and deployment invariants.

---

## Product Implications

### Target users

Curious city walkers; people who like Atlas Obscura, urban history, public art, walking tours, cozy exploration games; locals rediscovering their own city; visitors who prefer wandering to checklist tourism.

### Positioning

> Your city is full of question marks. Walk to them, and they become yours.

Softer alternate:

> Discover the hidden corners, stories, and small curiosities around you — and keep them.

### MVP success signal

Not downloads. Whether users **physically go to at least 3–5 unlocks** in the launch district and describe it as fun, magical, or motivating enough to repeat — and whether the accumulating atlas brings them back after the novelty of the first session.

### Pricing hypothesis

A paid launch-district pack or Founding Explorer tier is the cleanest early willingness-to-pay test. If nobody will pay a small amount for a carefully made district, the product should not scale.

### Build-in-public alignment

A dense, handcrafted launch district is strong build-in-public material: visible, local, beautiful, demoable in a single screen recording — better public-story fuel than a passive journal.

---

## What Does NOT Change

- **Notify Cloud (PDR-0002)** remains the Grid's first commercial product and first revenue milestone.
- **Hearth (PDR-0005)** remains the recorded first consumer-facing app built. Curiosities does not jump the queue.
- **Mochi's persona constraints (PDR-0004 §D)** — one constrained literary voice, no input box, no advice, no parasocial register — unchanged and now also bind unlock-card prose.
- **The watercolor map pipeline (PDR-0004 §E)** — unchanged.
- **Core Grid invariants** — unchanged. No new Node or Sector.
- Curiosities does not become HoneyHub, Lore, or a generic local-search engine.
- Curiosities introduces **no public UGC platform at v1.**

---

## Risks

1. **Content production overruns v1 capacity.** The single largest risk. 50–100 quality curated POIs per district is "small" only relative to a global map; for a solo dev plus AI agents it is real, recurring work. If it can't be produced at quality and pace, the product does not ship. (PDR-0007 §49 / §Risk-1, now v1-critical.)
2. **The discovery loop fails the acquisition bar.** As the headline, the unlock loop must now acquire users cold — a harder bar than PDR-0004 set for the same mechanic (§P.8). It may delight existing users but fail to pull new ones.
3. **Novelty wears off.** Unlocking question marks may be fun once but not retain. The walk-memory backbone (§B) is the designed answer; if the backbone is vestigial, this risk is unmitigated.
4. **Generated content feels generic.** AI summaries can flatten the weirdness out of places into tourism-board blandness.
5. **Safety mistakes.** Bad curated POI selection could route users somewhere unsafe, private, or inappropriate. Lower than Wayside's UGC risk, but non-zero and human-review-dependent.
6. **The backbone competes with the loop instead of supporting it.** If walk-journal and discovery pull for attention rather than reinforcing, v1 is two half-products.
7. **Weak willingness-to-pay.** Users may like the idea but expect city content free.

---

## Mitigations

1. **Content overrun:** strict 50–100 POI cap, one district only, templates over bespoke design, AI-assisted summarization with human approval, district-by-district expansion. Phase-0 content spike before any mobile build (Rollout). Explicit content kill criterion (§O.1).
2. **Acquisition bar:** the launch district must be dense and demoable enough that the first session delivers a real uncover; paid-pack legibility tested early; build-in-public used to seed the launch city.
3. **Novelty decay:** the walk-memory backbone (§B) and accumulating discovery Atlas (§G) are the designed retention answer; their effectiveness is an explicit Phase-1 success signal, not an assumption.
4. **Generic content:** human review every v1 POI; reject AI output that flattens the place; bias toward the weird/specific over the comprehensive.
5. **Safety:** explicit content-safety policy before any POI publishes — exclude private property, sensitive facilities, schools, isolated and time-risky locations; human-review every POI.
6. **Backbone competition:** the walk-journal is framed as the substrate discoveries pin into (§B), not a parallel surface; Phase-1 user testing validates that the two read as one product.
7. **Willingness-to-pay:** test a paid district pack or Founding Explorer tier early; treat refusal to pay for a carefully made district as a scale-stop signal.

---

## Kill Criteria

The product should be cut or reverted if, at the relevant phase:

1. **Content cannot be produced at quality and pace.** If a single dense launch district of 50–100 reviewed POIs cannot be built and maintained sustainably by a solo dev plus AI agents within the Phase-0/Phase-1 window, the discovery-first thesis is not viable for this studio and the direction is killed.
2. **The loop is not embodied.** If users browse the map but do not physically walk to unlocks, the product is not working — the same hard line as PDR-0007 §Mitigation-6.
3. **Retention is novelty-only.** If the walk-memory backbone and accumulating Atlas do not bring users back after the first-session novelty fades, the backbone is vestigial and the product has no retention answer.
4. **No willingness to pay for a curated district.** If a carefully made paid district pack or Founding Explorer tier finds no buyers, the product should not scale.

These criteria replace PDR-0004 §O.4 (the Curiosities-as-v1.5-mode kill switch), which no longer applies because Curiosities is no longer an additive mode.

---

## Consequences

### Short-term (direction-only — no immediate build)

Curiosities becomes the recorded place-app direction, replacing the Wayside/Arcadia pair. The studio has a single, demoable, sellable v1 shape with the highest-risk feature (public UGC) deferred and the central risk (content production) named with explicit kill criteria. PDR-0004 and PDR-0007 move to Superseded.

### Long-term (if built)

If validated, Curiosities could become a paid city-pack product, a curated city-exploration platform with trusted contributors, and a strong public-facing HoneyDrunk demo. The deferred public-marginalia layer remains a candidate post-v1 bet, gated on the PDR-0004 §C moderation stack and its own decision record. If not validated, the curated-content pipeline and place-curation lessons still inform Hearth, Currents, and any future place work.

---

## Rollout — Phased (when build begins)

### Phase 0 — Content spike + loop prototype

- Pick one launch district.
- Build the curated-content pipeline against open data + AI-assisted enrichment; produce ~25 reviewed POIs to measure real per-POI cost. **This phase tests Kill Criterion 1 before any significant mobile investment.**
- Build a lightweight prototype: watercolor map, question marks, GPS/manual unlock, place card, collection book.
- Test with a few real walks.

### Phase 1 — Launch-district v1

- Expand to 50–100 reviewed POIs with safety-reviewed metadata.
- Wire the walk-memory backbone (auto-detected walks → Mochi chapters as connective tissue).
- Add the discovery collection book / atlas surface.
- Test a paid district pack or Founding Explorer tier.
- Measure Kill Criteria 2–4.

### Phase 2 — Content pipeline hardening + Atlas season

- Repeatable district-pack build process; editorial review queue.
- First Yearly Atlas season ("what you uncovered this year"), print-on-demand.

### Phase 3 — Optional expansion

Only after the curated product works: additional districts/cities, trusted-curator suggestions (not direct publish), partner packs. Public marginalia is **not** in this rollout; if ever revived it takes the PDR-0004 §C moderation stack and a separate decision record.

---

## Open Questions

1. **Final name.** Codename is "Curiosities" (also the customer-facing mechanic word from PDR-0004 §P). Is the product name "Curiosities," or does the mechanic word stay a feature label while the product takes a distinct name? Alternates to weigh: a place/wander-flavored name that leaves "curiosities" free as the in-app collectible noun.
2. **Launch city/district.** Which place is emotionally and logistically best for the first dense test?
3. **Unlock verification.** GPS radius only, plaque/QR scan, photo proof, or manual unlock?
4. **Backbone weight.** How prominent is the walk-journal at v1 — a visible second surface, or a quiet substrate that only becomes legible in the Atlas?
5. **Content tone.** More historical, weird/Atlas-Obscura, cozy, or literary — within Mochi's persona constraints?
6. **Paid test shape.** District pack upfront, free sample + paid district, or Founding Explorer tier?

---

## Recommended Follow-Up Artifacts

- **Product one-pager:** Curiosities launch-district pitch and target user.
- **Content safety policy:** allowed/disallowed POI and prompt rules (prerequisite to any publish).
- **Content pipeline spike work-item:** evaluate open data sources and licensing for one city; measure real per-POI production cost (tests Kill Criterion 1).
- **Prototype work-item:** lightweight map + 25 POIs + collection screen.
- **Future ADR:** only if backend content storage, the curated-content pipeline, an editorial review queue, or AI-assisted content generation are accepted for build.
