# PDR-0007: Arcadia — City Quest Map and Place Unlocks

**Status:** Proposed
**Date:** 2026-05-07
**Deciders:** HoneyDrunk Studios
**Sector:** Apps (consumer) · Location · AI · Play
**Codename:** Arcadia (final product name TBD)

---

## Context

The studio is exploring consumer apps with soul: products that make regular life feel more interesting without becoming chores, feeds, or grind systems. Existing proposed consumer directions cover adjacent territory:

- **Wayside** — walking, private place-memory, public marginalia, and illustrated chapters of the city.
- **Currents** — social suggestions and lightweight quests based on taste and active interests.
- **Hearth** — personal growth rendered as a living town.

This PDR records a related but distinct product idea: **a real-world city exploration app inspired by open-world game maps**. In games like *Assassin's Creed* or *The Witcher*, question marks on the map pull the player toward areas of interest. Arcadia applies that pattern to cities: unknown nearby points appear as question marks, and physically visiting them unlocks short local content, micro-quests, collectibles, and historical or cultural context.

The emotional thesis: **cities already contain quests; the app makes them visible.**

Unlike Wayside, Arcadia is not primarily a personal walking journal. Unlike Currents, it is not primarily a taste/social recommendation app. Arcadia is a playful exploration layer over real places: part walking game, part local guide, part collection book, part tiny museum.

The core strategic question is whether this can avoid the obvious trap: **content production.** A city-quest app dies if every location requires bespoke editorial writing, custom art, manual quest design, and ongoing maintenance. This PDR's decision is therefore mainly about the content model and MVP constraints.

---

## Problem Statement

### 1. Cities are full of overlooked places

Most people move through their city on habitual routes. They pass murals, plaques, old buildings, small parks, strange stores, public art, alleyways, and historical sites without noticing them. Existing maps tell users where businesses are; they do not make the city feel like a playable world.

### 2. Travel and local-discovery apps are too utilitarian

Google Maps, TripAdvisor, Yelp, Atlas Obscura, Eventbrite, and tourism-board websites are useful, but their emotional posture is mostly search, reviews, logistics, or bucket lists. They answer "where should I go?" but rarely create the feeling of discovery, mystery, or collection.

### 3. Generic quests become cringe quickly

A quest mechanic can become fake gamification fast: XP, streaks, badges, leaderboards, and corporate scavenger-hunt language. Arcadia has to borrow the *map curiosity* of games without importing the treadmill.

### 4. Bespoke content does not scale for a solo studio

A city exploration app seems content-heavy: every point needs copy, tasks, verification, safety checks, and maybe art. If the MVP requires hundreds of hand-written points per city, the product is not viable for HoneyDrunk Studios right now.

### 5. Location products carry safety and moderation risks

Any app that points users at physical places can accidentally route people to unsafe locations, private property, schools, sensitive facilities, or places inappropriate at certain hours. If user-generated locations are allowed too early, abuse and moderation risk explode.

---

## Decision

### A. Define Arcadia as a city quest map, not a generic travel guide

Arcadia's core loop is:

1. The user opens a stylized city map.
2. Nearby unknown points appear as **question marks**.
3. The user physically approaches a point.
4. The point **unlocks** into a named place card.
5. The card gives short context, one optional micro-action, and a collectible entry.
6. The user's city atlas fills in over time.

The product promise is not comprehensive recommendations. It is not "best restaurants near me." It is: **go outside, follow curiosity, uncover your city.**

### B. V1 starts with one dense launch geography

Arcadia does **not** launch as a global city app. V1 is constrained to one dense geography: one city, or even one walkable district inside a city.

A credible MVP could be:

- 50–100 seeded points of interest.
- 5–10 themed collections.
- 20–30 micro-quests.
- No user-generated public locations.
- No business listings beyond places selected as quest/map content.
- No routing into private property or unsafe areas.

The first release should feel handcrafted in one place rather than thin everywhere.

### C. Content model: seeded data plus AI-assisted enrichment, human-approved

Arcadia should not hand-write everything from scratch. The v1 content pipeline should combine:

- **Open/public data sources** — landmarks, public art registries, historical markers, Wikipedia/Wikidata, OpenStreetMap, parks, public buildings, library/archive material where licensing allows.
- **AI-assisted summarization** — short plain-language place cards, curiosity hooks, and suggested micro-actions.
- **Human approval** — every published v1 place is reviewed by HoneyDrunk before it appears.
- **Reusable templates** — quest types are generated from a small set of safe patterns rather than bespoke game design per location.

The content bar is: good enough to make a walk feel intentional, not academic enough to become a museum app.

### D. Quest types are lightweight prompts, not RPG systems

Arcadia can use "quest" internally, but customer-facing language may test better as **Finds**, **Discoveries**, **Curiosities**, **Prompts**, or **Missions**.

Safe v1 quest templates:

- **Look Closely:** find a detail on a building, mural, plaque, statue, or storefront.
- **Then / Now:** read a short historical note and compare it to what is there now.
- **Sound of the Corner:** pause for 30 seconds and note one sound.
- **Color Hunt:** find a dominant color or visual motif nearby.
- **Public Art Scan:** unlock a mural/sculpture/public artwork and collect its style tag.
- **Tiny Detour:** walk one block off the obvious route to unlock a nearby curiosity.
- **Postcard Moment:** take or save a private photo for the user's atlas.

Explicitly cut from v1:

- XP, levels, streaks, leaderboards.
- Competitive territory control.
- User-created public quests.
- AR overlays.
- Sponsored quests.
- Nighttime or isolated-location prompts.
- Anything that asks users to enter private property, disturb people, or interact with strangers.

### E. Collectibles are emotional, not addictive

Arcadia's collection layer should feel like filling a field guide, not grinding a battle pass.

Possible collectibles:

- Place stamps.
- District cards.
- Architectural motifs.
- Local legend fragments.
- Public art styles.
- Historical era tags.
- "First rain walk," "golden hour find," or other contextual memories.

No scarcity manipulation. No daily pressure. No streak loss. Collection should reward attention, not compulsion.

### F. Arcadia is related to Wayside but should remain distinct for now

Arcadia and Wayside both involve walking and place. They differ in primary loop:

- **Wayside:** "My walks become memories and marginalia." Private place-memory first; public notes are magic.
- **Arcadia:** "The city map contains mysteries to unlock." Exploration and discovery first; personal memory is secondary.

For now, Arcadia should be a separate PDR rather than folded into Wayside. They may later converge into one product if testing shows users want both loops together. Until then, keeping them separate avoids diluting either concept.

### G. Monetization starts as city packs or premium atlas, not ads

Potential monetization paths:

- Paid city/district packs.
- Premium yearly atlas export.
- Founding explorer lifetime tier for launch city.
- Partner-sponsored packs only after trust exists, clearly labeled, and never mixed into organic question marks.

No ads in v1. No selling location trails. No dark-pattern notification loops.

---

## Options Evaluated

### Option 1: Fold the idea into Wayside

**Pros**

- Reuses walking, map, place-memory, and atlas concepts.
- Avoids creating another consumer app direction.
- Combines private memory with external exploration.

**Cons**

- Makes Wayside even heavier; it already carries walking detection, Mochi, public notes, moderation, watercolor maps, and atlas export.
- The quest loop may conflict with Wayside's quieter poetic tone.
- Increases the chance that neither product has a crisp v1.

**Verdict:** Park as a possible future convergence, but do not fold it in now.

### Option 2: Build Arcadia as a global open quest platform

**Pros**

- Bigger vision.
- Could produce network effects if users create content.
- More like a platform than a local app.

**Cons**

- Content, safety, moderation, and cold-start risks are too high.
- Requires UGC governance and location abuse handling from day one.
- Too expensive for a solo studio before product-market signal.

**Verdict:** Reject for v1.

### Option 3: Build Arcadia as one handcrafted launch-city MVP

**Pros**

- Small enough to test.
- Lets the studio prove whether the question-mark city loop is actually fun.
- Avoids premature UGC and global content scale.
- Produces strong demo/storytelling material.

**Cons**

- Local launch limits audience size.
- Content still takes work.
- Monetization signal may be slow unless a paid city pack is tested early.

**Verdict:** Recommended.

### Option 4: Build only a content pipeline first, no app

**Pros**

- De-risks the hardest part: scalable place content.
- Could reuse Lore/Knowledge-style ingestion later.
- Lets the studio inspect output quality before mobile work.

**Cons**

- Does not test the embodied unlock loop.
- Easy to overbuild tooling without user signal.
- Less emotionally motivating than a tangible prototype.

**Verdict:** Useful as a prerequisite spike, not the product decision.

---

## Trade-offs

### Handcrafted magic vs. scalable coverage

Arcadia should choose handcrafted magic for v1. A thin global map with weak generated content would feel like a bad travel guide. A dense neighborhood with 75 good unlocks can prove the loop.

### Mystery vs. utility

The app should preserve mystery. Showing all place names upfront makes it a guidebook. Question marks create motion. The trade-off is that users may want practical information; v1 should provide enough safety and distance context without spoiling every unlock.

### AI generation vs. editorial trust

AI can help generate summaries and prompts, but publishing unreviewed location content is unsafe and brand-damaging. V1 content must be human-approved.

### Game language vs. emotional maturity

The app should borrow from games structurally, not aesthetically. Avoid fake RPG copy unless the brand later proves it can carry it.

---

## Architecture Implications

Arcadia is a consumer app surface under the Apps/Market-style product line, not a Core Grid Node.

Likely future architecture, if accepted for build:

- A private app repo for the consumer product.
- A place-content ingestion/enrichment pipeline, potentially informed by Lore/Knowledge patterns later.
- A moderation/safety policy for physical-location content before any public contribution feature exists.
- Notify/Communications may later support opt-in reminders or nearby unlock nudges, but v1 should avoid notification dependency.
- Pulse may later observe content quality and app usage, with strict privacy boundaries.

No existing Grid invariants change. If backend services are introduced, they must follow Grid context, tenant, secrets, telemetry, packaging, and deployment invariants.

---

## Product Implications

### Target users

Primary early users:

- Curious city walkers.
- People who like Atlas Obscura, urban history, public art, travel guides, walking tours, indie games, or cozy exploration games.
- Locals who want to rediscover their own city.
- Visitors who prefer wandering to checklist tourism.

### Positioning

Possible positioning:

> Turn your city into an open-world map.

Alternate softer positioning:

> Discover the hidden corners, stories, and small quests around you.

### MVP success signal

The key signal is not downloads. It is whether users physically go to at least 3–5 unlocks and describe the experience as fun, magical, or motivating enough to do again.

### Pricing hypothesis

The cleanest early pricing test is a paid launch-city pack or founding explorer tier. If nobody will pay a small amount for a carefully made city pack, the product probably should not scale.

---

## What Does NOT Change

- Notify Cloud remains the Grid's first commercial B2B wedge.
- Wayside remains the recorded direction for walking/place-memory and public marginalia.
- Currents remains the recorded direction for social suggestions and lightweight taste quests.
- Arcadia does not introduce a new public UGC platform in v1.
- Arcadia does not require changes to Core Grid invariants.
- Arcadia does not become HoneyHub, Lore, or a generic local-search engine.

---

## Risks

1. **Content production is still too heavy.** Even 75 good places may take too long.
2. **Generated content feels generic.** AI summaries can flatten the weirdness out of places.
3. **Safety mistakes.** Bad POI selection could route users somewhere unsafe, private, or inappropriate.
4. **Novelty wears off.** Unlocking question marks may be fun once but not retain users.
5. **Tourism-board blandness.** The product could become a prettier local guide with no soul.
6. **Overlap with Wayside.** Maintaining two place-based consumer concepts may fragment focus.
7. **Weak willingness-to-pay.** Users may like the idea but expect city content to be free.

---

## Mitigations

1. **Start with one district.** Keep v1 geography small enough to hand-audit.
2. **Use templates, not bespoke design.** Reusable quest templates reduce content cost.
3. **Human-review every v1 POI.** No unreviewed generated locations.
4. **Safety filters before charm.** Exclude private property, sensitive facilities, isolated spots, schools, and time-risky locations.
5. **Test with a no-code or lightweight prototype first.** A map, 25 unlocks, and a simple collection screen can test the loop before full mobile investment.
6. **Kill quickly if the loop is not embodied.** If users browse but do not walk, the product is not working.

---

## Consequences

### Short-term

Arcadia becomes a recorded consumer product direction. It gives the studio a crisp alternative to Wayside: more game-like, more discovery-driven, less journaling-first.

### Long-term

If validated, Arcadia could become:

- A paid city-pack product.
- A city exploration platform with curated contributors.
- A companion to Wayside, or a feature that later merges into it.
- A strong public-facing HoneyDrunk Studios demo: playful, local, beautiful, and legible.

If not validated, the content pipeline and place-curation lessons can still inform Wayside and Currents.

---

## Rollout

### Phase 0 — Prototype the loop

- Pick one launch district.
- Curate 25 POIs manually.
- Create 3 collections and 5–10 quest templates.
- Build a lightweight prototype: map, question marks, GPS/manual unlock, place card, collection book.
- Test with a few real walks.

### Phase 1 — Launch-city MVP

- Expand to 50–100 POIs.
- Add safety-reviewed place metadata.
- Add private photo/note capture per unlock.
- Add city/district completion view.
- Test paid pack or founding explorer tier.

### Phase 2 — Content pipeline

- Add source ingestion and AI-assisted enrichment.
- Add editorial review queue.
- Add repeatable city-pack build process.
- Keep all publishing human-approved.

### Phase 3 — Optional social/UGC expansion

Only after the curated product works:

- Allow users to suggest places, not publish directly.
- Add trusted curator accounts.
- Consider partner packs.
- Consider limited public notes only if Wayside's moderation strategy has been proven.

---

## Open Questions

1. **Launch city/district:** Which place is emotionally and logistically best for the first test?
2. **Brand:** Is Arcadia the right codename/final name, or too broad/mythic?
3. **Map style:** Stylized game map, illustrated flat map, or modified standard map for v1?
4. **Unlock verification:** GPS radius only, QR/plaque scan, photo proof, or manual unlock?
5. **Content tone:** More historical, weird/Atlas Obscura, cozy, literary, or game-like?
6. **Paid test:** City pack upfront, free sample + paid district, or founding explorer tier?
7. **Relationship to Wayside:** Separate app long-term, or eventual mode inside Wayside?

---

## Recommended Follow-Up Artifacts

- **Product one-pager:** Arcadia launch-district MVP pitch and target user.
- **Content safety policy:** Rules for allowed/disallowed POIs and quest prompts.
- **Prototype packet:** Scope a no-code/lightweight prototype with 25 POIs.
- **Content pipeline spike:** Evaluate public data sources and licensing for one city.
- **Future ADR:** Only if backend architecture, location storage, moderation queues, or AI-assisted content generation are accepted for build.
