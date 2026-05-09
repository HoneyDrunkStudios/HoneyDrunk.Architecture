# PDR-0004: Wayside — Walking, Place-Memory, and Public Marginalia for Regular Humans

**Status:** Proposed
**Date:** 2026-05-05
**Amended:** 2026-05-09 — supersedes PDR-0007 (Arcadia); absorbs the question-mark unlock mechanic into Wayside as a v1.5 "Curiosities" mode (see §P).
**Deciders:** HoneyDrunk Studios
**Sector:** Market
**Codename:** Wayside (real product name TBD — previous codename was "Lantern Line")

---

## Context

Wayside is a separate consumer product line from the Grid's current commercial direction. The Grid's commercial direction is converging on B2B-shaped products: HoneyDrunk Notify (PDR-0002) sells multichannel orchestration to indie .NET devs. That is the right wedge for the Grid's first revenue-bearing surface. It is also a product line whose buyer is a developer.

The studio's brief is broader than that. The user wants to build apps with soul for regular humans — not dev tooling, not B2B SaaS. The 2026-05-05 brainstorm produced three locked codenames (Lately, Wayside, Hearth). This PDR addresses **Wayside**: a walking app that turns everyday foot travel into a personal mythology of the city, with a public layer of GPS-pinned notes left by strangers.

Wayside is a separate product line from Notify Cloud. It does not share a buyer, a brand surface, a pricing model, or — at v1 — much Grid infrastructure. It is the studio's bet that there is room in the consumer app market for an app that treats walking as story rather than as exercise data.

### The unmet niche

The walking / place-memory / personal-cartography category is fragmented:

- **Strava** — built for athletes. Pace, splits, segments, leaderboards. The aesthetic is sports telemetry; the social loop is competitive. A 30-minute aimless walk through your neighborhood does not belong here, and Strava users tell you so.
- **Apple Health / Google Fit** — sterile health trackers. Steps as a number, distance as a number. Zero narrative, zero aesthetic, zero memory of *place*.
- **Polarsteps** — travel-only. Beautiful, but built for trips, not for the everyday walks in the city you already live in.
- **Google Timeline** — surveillance UI. Renders your life as a heatmap of paranoia. Aesthetically and emotionally hostile.
- **Geocaching apps** — physical-object-based, gamified, niche.
- **Field-notes-style apps (Day One, etc.)** — generic journaling. Not place-aware. Walking is not a first-class concept.
- **Foursquare / Swarm** — check-in social, dying. Public layer exists but is consumed by power-users and businesses, not regular humans.

**The everyday-walking-as-mythology niche is unaddressed.** Walking from the cafe to the bookshop on a Tuesday afternoon, noticing the new graffiti on the wall behind the laundromat, and having that moment turn into a watercolor-illustrated chapter of the city you live in — no app does this. The closest analog is a paper notebook, which most people don't carry.

The category gap is real. The question this PDR addresses is whether the studio should build into it, what the product should be, and what scope is shippable by a solo dev with AI agents over the next 6–12 months.

### The dual thesis

Wayside makes two product bets that reinforce each other:

**A. Private place-memory.** *"My city, my walks, my Mochi."* Auto-detected walks become illustrated chapters. A persistent companion (Mochi — fox/cat/tanuki, TBD) observes places and develops favorite spots based on walking patterns. The output is a personal mythology of the city — your private layer of meaning over the streets you already walk.

**B. Public marginalia.** *"Strangers' notes at the bench I'm sitting on."* A public layer of short notes pinned to GPS coordinates (~10m radius). Anyone can leave a note. Anyone walking past later can read it. Anonymous by default. Notes decay after 30 days unless echoed by other passersby.

These two bets are not unrelated features bolted together. They reinforce each other:

- The private layer makes the user **invested in the places** before they are exposed to strangers' notes there. A user with no place-memory of a corner has no reason to read what a stranger left there. A user who walked there yesterday with Mochi *does*.
- The public layer **makes solo walking less lonely** in a way the private layer alone cannot. Mochi witnesses; strangers leave evidence of having witnessed. The combination is a city populated by ghosts of other people's attention.
- The private layer is the **retention engine**. Users come back for their own walks, their own chapters, their own Mochi. The public layer is the **magic** — the moment a user reads a note left by a stranger on the bench they're sitting on is the screenshot-worthy, friend-show-able, app-defining moment.

The risk is dilution: trying to be both a private journal and a public social product in v1 may produce a v1 that is neither. This PDR's MVP scope (§J) is the position on that risk.

### Strategic context

This PDR exists as a **commitment to direction, not to immediate build**. The user is currently in the middle of two large in-flight architectural initiatives (Actions#20, ADR-0019, Notify Cloud per PDR-0002) and a separate first-build app candidate (Hearth, the scout's pick from the 2026-05-05 brainstorm). Wayside is **not** the next thing being built. It is the recorded direction for *when* the studio takes a swing at a place-memory app, so the architecture, naming, and product shape are pre-decided rather than re-litigated.

The 2026-05-05 brainstorm explicitly ranked Hearth ahead of Wayside on first-build value (Hearth has no two-sided marketplace problem; Wayside's public layer does). This PDR does not contradict that ranking. It records the Wayside concept formally so a future "build Wayside" packet has a strategic ground to stand on.

---

## Problem Statement

### 1. The category gap is real but unproven as a market

Walking-as-mythology is an unaddressed niche, but "unaddressed" is not the same as "addressable." The risk is that the niche is unaddressed because no one wants to pay for it — that walking-as-data (Strava, health apps) is what the market actually wants, and walking-as-narrative is a small literary audience. Wayside has to validate that the audience is large enough to support a paying tier, not just to exist.

### 2. The public notes layer is the highest-risk feature in the entire concept

A user-generated content layer pinned to physical-world locations is a vector for every form of internet abuse simultaneously: harassment of specific places (a person's home), targeted hate at a known location (a synagogue, a mosque, an abortion clinic), commercial spam (every storefront flooded with ads), child safety risks at schools and playgrounds, and doxxing of individuals seen in photos. This is the **same class of risk** as Foursquare check-ins, Yelp reviews, Google Maps photos, and Twitter geotags — but with less moderation infrastructure than any of those, run by a solo dev.

Without a credible moderation strategy, the public notes layer is not shippable. With one, it is the magic. This PDR has to be specific about which.

### 3. Hand-drawn watercolor map rendering is a hard technical bar

The aesthetic is not optional. "Watercolor maps instead of Google Maps blue lines" is the entire visual identity. If the maps look like Mapbox tiles with a cheap watercolor filter, the product is dead on arrival. Real watercolor-feeling rendering is technically expensive — either as procedural generation, pre-rendered tiles, or AI-image-style transfer — and the trade-offs across those approaches are not obviously resolved.

### 4. Mochi is hard to get right and easy to ruin

A persistent literary companion that observes the user's life is either the killer feature or the most annoying one. Get the persona wrong, and Mochi is a creepy AI roommate who makes the user uninstall the app after a week. Get the prompt structure wrong, and Mochi says something off-character or out-of-bounds and breaks the spell permanently. The success bar is high; the failure modes are public.

### 5. Auto-detected walks require passive location tracking, which has battery and trust costs

The "no start/stop button" promise is core to the user experience. A user who has to remember to start the app before every walk does not get a year of walks at the end of the year. But passive location tracking is the most-scrutinized permission on iOS and Android, and indie apps that get the privacy story wrong get destroyed in App Store reviews and tech press alike. Wayside has to be honest about what data leaves the device, and that honest answer has to be acceptable to a privacy-conscious user.

### 6. The cold-start problem on the public layer

A walking app where every bench has a stranger's note pinned to it is magic. A walking app where no bench has a note is broken. The first 1,000 users in the launch city will see an empty public layer and feel a different product than the launch city's 100,000th user. The cold-start strategy has to be specific — not "we'll figure it out."

### 7. Solo-dev capacity vs. product surface

Wayside is iOS + Android, mobile-first, mapping-heavy, with an on-device LLM, an aesthetic that requires illustration discipline, a public moderation layer, and a print-on-demand pipeline. Each of those is a non-trivial engineering surface. A solo dev with AI agents cannot ship all of it at once. The MVP scope question (§J) is the gating product decision.

---

## Decision

This PDR records direction. None of the below is committed to a calendar; the decision to *start building* Wayside is a separate decision the user will make later, gated on Notify Cloud and Hearth outcomes.

### A. Build Wayside as a consumer app, separate product line from the Grid's commercial direction

Wayside is **not** marketed as a HoneyDrunk Grid product. It does not share branding with HoneyDrunk Notify or the studio's B2B surface. The customer never hears the words "Grid," "Node," "Sector," "ADR," or any architectural metaphor. This is consistent with the manifesto's stance that customer-facing language describes outcomes, not architecture (per PDR-0002 §H: "Internal Grid Nodes are invisible to customers").

The brand is its own — likely named after Wayside is replaced (current shortlist: TBD; the codename "Wayside" itself is a placeholder, and the previously-used "Lantern Line" was rejected as too on-the-nose). The studio's role is the parent (HoneyDrunk Studios) and the build-in-public narrative continues, but the product brand stands separately.

### B. Dual-thesis product, not feature-bolt-on

The private layer (walks, chapters, Mochi) and the public layer (place-notes) are co-equal in the product story. Marketing leads with both; the App Store screenshot reel shows both. The product is *not* "a walking app with a notes feature" — it is a **walking app and a public place-notes app that happen to share a coordinate system, a user account, and an aesthetic**.

The dual thesis means the v1 cuts (§J) cannot remove either side entirely. Removing the private layer leaves a hostile-by-default note-board; removing the public layer leaves a journaling app that competes with Hearth and Polarsteps without distinction.

### C. Public layer moderation strategy — six layers, all required

The public notes layer is the highest-risk feature. The moderation posture has six layers, all of which must ship in v1 of the public layer:

1. **Anonymous by default with a stable per-device pseudonym.** Notes do not carry usernames or profile photos. Each device has a stable internal pseudonym (used for rate-limiting, abuse signals, and report attribution), but the pseudonym is not visible to other users. There is no "follow" graph on the public layer. This eliminates harassment-of-individual vectors at the source — there is no individual to harass.

2. **Automatic personal-information filtering pre-publish.** Every note submission runs through a pre-publish filter that detects and blocks: phone numbers, addresses, full names in common name lists, government ID patterns, license plates, and explicit slurs. The filter runs on-device first (fast feedback) and on the server before publish (canonical decision). False positives are tolerated; false negatives are not. The filter is conservative — it errs on blocking.

3. **AI moderation pre-publish for content classes.** A second pre-publish pass classifies the note across: hate speech, harassment, sexual content, self-harm content, commercial spam, doxxing patterns, and threats of violence. This runs on-cloud (the on-device model is too small for this) with a per-note latency budget of <2 seconds. Notes that fail classification are surfaced to the user as "this note may violate our guidelines — please revise" rather than silently dropped. Borderline cases are queued for human review (the solo dev plus AI agents) before publication.

4. **Photos are bound to short text and run through a separate vision-class filter.** Photos cannot be uploaded without accompanying text. Photos run through a vision-class moderation pass: nudity, violence, identifiable faces (which are blurred automatically before publish), and contextual signals (e.g., minors detected in frame triggers a manual review queue regardless of the rest of the content).

5. **Community echo as a quality signal.** Every note can be echoed by another passerby ("I felt this here too"). Echoes are the **canonical quality signal** — notes with echoes are surfaced more prominently; notes with multiple reports and zero echoes decay faster. Echoes are a positive signal only; the inverse (downvote) is **not** offered, because downvote systems incentivize the wrong behaviors and require their own moderation.

6. **30-day decay is the self-cleaning mechanism.** A note that no one has echoed within 30 days is deleted. This is not a soft-archive; it is a hard delete. The decay rule means the public layer cannot accumulate stale or low-quality notes — the system actively forgets what nobody confirmed. This is the single most important architectural choice in the entire moderation strategy. It means even moderation failures are time-bounded, and it means the product's emotional shape is "alive, present, ephemeral" rather than "every bench is a tomb of every note ever left."

A **report flow** wraps the entire system: any user can report any note with one tap, reports are batched for the solo-dev-plus-agents review queue, and a tenant-style abuse threshold (X reports in Y minutes) triggers an automatic temporary takedown pending review. Reported notes are hidden from the reporting user immediately even before review.

**What this strategy does not promise:** zero harm. A determined bad actor will get a note past the filters. The moderation layers are designed for **time-to-remove**, not for **prevent-all**. The 30-day decay caps the worst case at 30 days even if no other layer catches a note.

### D. Mochi — constrained literary persona, not a chatbot

Mochi is a persistent companion (fox / cat / tanuki — the visual character is TBD; the design role is "small mammal that lives in the user's rail network"). Mochi observes and reports. Mochi does not converse. **There is no input box for the user to talk to Mochi.** This is the single most important constraint on Mochi's design.

Mochi's only outputs are:
- **Place observations** — short paragraphs (2–4 sentences) about a specific place, generated when the user pauses there or returns there.
- **Walk chapters** — the 3-line prose that accompanies each completed walk.
- **Favorite-spot reveals** — when Mochi has observed enough walks to identify a "favorite" place (one the user returns to repeatedly), Mochi mentions it in the next chapter. This is a long-cadence signal, not a daily one.
- **Returning-visitor-mode acknowledgments** — when the user enters a city Mochi has memory of, Mochi acknowledges the return in the next chapter.

**What Mochi never does:**
- Ask questions.
- Give advice.
- Reflect the user's emotions back at them.
- Comment on the user's mood or implied mental state.
- Reference world events, news, or anything outside the bounded set of observable inputs.
- Break character. There is no "as an AI language model" failure mode acceptable in production.

**Prompt structure (sketch, for the implementation ADR to refine):**

```
You are Mochi. You are a [fox/cat/tanuki] who lives in this person's rail network.
You observe places. You write 2-4 sentences about a place when prompted.
You write in the literary register of [persona profile — TBD between Murakami's quiet specificity, Calvino's invisible cities, and Yoko Ogawa's gentle attention].
You never ask questions. You never give advice. You never break character.

Inputs you may use:
  - Time of day
  - Weather (current observation only — not forecast)
  - Approximate place type (corner, bench, riverbank, alley, station)
  - Number of times the user has been here before
  - The user's photos at this place (if any), described abstractly

You may not use:
  - The user's name
  - The user's emotions (you do not know them)
  - News, current events, or facts about the world outside this place
  - Any information from outside this prompt

Output: 2-4 sentences. Plain prose. No emoji. No quotation marks.
```

The persona profile is the literary anchor. Mochi's voice is the entire product personality and is the most fragile thing in the build. The implementation ADR will need to settle: which author voices to anchor against, how strictly to red-team the prompt against jailbreak attempts, and how Mochi behaves when the inputs are degraded (no GPS, no weather data, walking through a tunnel).

**On-device vs. cloud split:**

| Output | Where it runs | Why |
|---|---|---|
| Place observations during a walk | On-device | Latency, battery efficiency for short prompts, privacy (no GPS coordinates leave the device for this path). Apple's on-device foundation model or a small llama.cpp / MLC-deployed model is the candidate set. |
| Walk chapter (post-walk, longer prose) | On-device or cloud (TBD) | Quality vs. privacy trade-off. On-device is preferable for the privacy story; cloud is preferable for prose quality. The decision is deferred to the implementation ADR after on-device model evaluation. |
| Public-layer moderation | Cloud only | Required for the moderation classifier and vision passes. Notes leave the device for moderation; this is a clear and disclosed data flow, not background telemetry. |
| Mochi's "memory" (places visited, favorites, returning-visitor recognition) | On-device | The memory is the user's data; it never leaves the device unless the user explicitly enables Lantern+ Memory Book sync (a Lantern+ feature — see §M). |

**Failure modes and their mitigations:**

| Failure | Mitigation |
|---|---|
| Mochi says something creepy or off-character | Strict prompt with red-team-tested negative examples baked in. A second pass (a small classifier or a deterministic rule set) checks output before display. If the check fails, fall back to a deterministic, hand-written "filler" line keyed to place type. The user never sees a model failure; they see a less-magical but always-safe line. |
| Mochi breaks character ("As an AI...") | Output filter rejects any line containing language patterns from the model's known refusal set. Fall back to filler. |
| Mochi makes factual claims about the world | Prompt forbids it. Output filter looks for proper-noun patterns Mochi shouldn't know (current politicians, brand names, etc.) and rejects. |
| On-device model is too slow on older phones | Tier the experience: on a slow phone, Mochi's per-place observations are deferred to "after the walk completes" rather than mid-walk. The walk chapter still feels alive. |
| User feels emotionally manipulated by Mochi's "favorites" | Favorites are surfaced sparingly (once per several walks) and in a tone that is observational, not affectionate ("Mochi spent more time at the riverbank this week" — not "Mochi loves the riverbank"). The literary register prevents the parasocial trap. |

### E. Hand-drawn watercolor maps — pre-rendered base + procedural overlay

Three options exist, with the trade-offs below.

| Option | Pros | Cons |
|---|---|---|
| **Real-time procedural watercolor generation** | Fully unique per walk. Maximum aesthetic control. Each walk's map is one-of-a-kind. | Slow (seconds to minutes per render). Expensive on-device. Hard to make consistent across zoom levels. Risk of failure modes that produce ugly maps. |
| **Pre-rendered watercolor tile overlays at known city zoom levels** | Fast (cached tiles serve like Mapbox). Consistent quality. Predictable cost. | Requires per-city manual rendering work (illustration discipline applied to base map data). Not unique per walk. New cities require seed work before users can have a chapter there. |
| **AI-image-style transfer over standard map tiles** | Cheapest dev cost. Universal — works in any city. | Quality is unreliable. Style transfer artifacts look bad. Aesthetic is "AI filter," not "watercolor." Kills the product premise. |

**Decision: pre-rendered watercolor tile base + procedural overlay for the walk path itself.**

The base map (streets, parks, rivers, landmarks) is pre-rendered watercolor tiles at known zoom levels for launch cities. This is illustration work — done by a real illustrator (the user, an commissioned artist, or an artist-in-residence model). The walk path itself, photo pins, and Mochi's place markers are rendered procedurally on top of the base — a brushstroke-styled vector path that varies subtly per walk.

This gets the watercolor identity right where it matters most (the base map is the dominant visual surface) while keeping per-walk rendering cheap and fast. It also creates a clean tier feature — *map style options* on Lantern+ are real artist-commissioned variations (a cherry-blossom palette, a winter palette, an alleyway-noir palette), each a separately rendered tile set.

The cost: every launch city requires the base-tile rendering work upfront. This caps geographic launch (§N).

**AI-image-style transfer is rejected** as the primary mechanism. It may show up as a *secondary* tier feature (a "your walk in the style of X" novelty) but it is not the visual foundation.

**Real-time procedural** is rejected for v1 due to performance and consistency risk; it remains an interesting v3+ direction if the product proves out and the studio can invest in a real graphics pipeline.

### F. Battery and privacy posture

Auto-detected walks require **passive location** tracking. The honest battery and privacy answer:

- Wayside uses the **significant-location-change** APIs on iOS (lower power than continuous GPS) and the equivalent geofence + activity-recognition APIs on Android. When the user is detected as walking (activity classification + significant change), Wayside escalates to a higher-fidelity track for the duration of the walk. When the walk ends (stationary for >5 min, or vehicle activity detected), Wayside drops back to low-power.
- **Battery cost target: <3% per day for typical urban walking patterns.** This is achievable with the platform APIs above. It is not achievable with continuous high-fidelity GPS, and the product does not need continuous high-fidelity GPS.

**What data leaves the device:**

| Data | Leaves device? | When | Why |
|---|---|---|---|
| GPS tracks of the user's walks | **No, by default.** | Stays on device. Synced encrypted to user's iCloud/Drive only if they enable Lantern+ Sync. | Walks are the user's mythology. They never become a HoneyDrunk-side dataset. |
| Photos taken during walks | **No, by default.** | Stays on device. Lantern+ optionally syncs to encrypted cloud. | Same. |
| Place-notes the user *publishes* to the public layer | **Yes, immediately on publish.** | Required for the public layer to function. Includes the GPS coordinate (rounded to ~10m), the text, the photo, and the device pseudonym. | Required for product. Disclosed at publish time and at signup. |
| Echoes (gestures of "I felt this too") | **Yes.** | Required for the public layer. Includes the note ID and the device pseudonym. | Required for product. |
| Anonymized usage telemetry (crash logs, screen views, no GPS) | **Yes, opt-out.** | Standard product telemetry. | Required for solo-dev visibility into what's working. |
| Mochi's prompts and outputs | **No.** | On-device for place observations. Walk chapters are TBD per §D. | Privacy of the user's specific walks. |

This posture is honest, defensible, and aggressively private-by-default. The marketing site says the same thing. The App Store privacy disclosures match. **No surprise data flows.**

### G. Public-layer cold start — geographic launch, one city at a time

Wayside cannot launch globally on day one. With zero notes pinned anywhere, the public layer is empty, and the magic is dead. The cold-start strategy is **geographic launch, one city at a time**, with a seed-content stage for each launch city.

**Launch city candidate: Tokyo.** Specifically, the Yamanote-line-bounded inner city. Reasoning:

- **Walking culture is built-in.** Tokyo is one of the highest-walking-density cities in the world. The product premise is native to the city.
- **The aesthetic register is native.** The app's visual identity (anime / Ghibli / watercolor) is Japanese-coded. Launching in Tokyo means the cultural context matches the product's voice. A launch in San Francisco would feel like aesthetic appropriation; a launch in Tokyo feels like the product has come home.
- **Density makes the public layer fill quickly.** A high-density walking city means the first 100 users will overlap routes within their first week, which means the public layer's first echoes happen fast.
- **The user has personal connection to Japan and Japanese aesthetics.** The studio can credibly market in this context. The user can travel to seed content and build community.

**Alternative launch cities considered:**

| City | Pro | Con |
|---|---|---|
| **Tokyo (Yamanote inner)** | Walking culture; aesthetic match; density. | Marketing in JA requires localization; user is not native JA speaker. |
| **Kyoto** | Aesthetic match; smaller market means easier to dominate. | Smaller market means lower revenue ceiling. |
| **New York (Manhattan/Brooklyn)** | Largest English-speaking walking city. Density. | Aesthetic match weaker. Crowded creator market. |
| **London (Zone 1–2)** | English-native, high walking density, strong creative scene. | Weather is hostile to "cozy walks" the marketing leans on. |
| **Lisbon, Porto, or Edinburgh** | Walking-friendly, beautiful, on-brand. | Smaller markets; revenue ceiling concern. |
| **The user's home city, whatever it is** | Founder-knowledge advantage; can manually seed content. | Founder-as-only-seed risk if it's a small market. |

**The decision on launch city is deferred** to the build-decision packet, but Tokyo is the proposed default. The point of recording it now is that *some specific city* must be picked before any launch work begins; "global launch" is a non-option.

**Seed-content strategies, all to be used in combination:**

1. **Mochi-authored seed notes as a tutorial.** Every new user's first 3 notes are auto-generated by Mochi at places along their first walk. This is a **tutorial mechanism** — Mochi shows the user what a note looks like by leaving them. These notes are clearly marked as Mochi-authored (different visual treatment) and do not count toward the public-layer note count. They exist to onboard, not to populate.
2. **Launch-team / partner seed content.** The studio commissions 5–15 local writers, illustrators, and walking-essay-adjacent creators to leave notes in their favorite places in the launch city. These are credited (with the creator's permission) and serve as *anchor content* — high-quality notes that establish the tone of the public layer for the city's first month.
3. **Friends-and-family seed.** The studio team, beta testers, and early access users leave notes in the launch city.
4. **Time-bounded "seeded mode" for launch.** For the first 30 days of a city's launch, the decay timer is paused on existing notes. New notes still decay normally. This stops the seed content from disappearing before the user base is large enough to keep the public layer alive on its own echoes.

**What the public layer feels like on day 1:** Sparse but not empty. A user walking from their apartment to the train station passes 2–5 notes. Most are seed content; a few are from other early users. The user may or may not echo them; if they do, the magic clicks. If not, they at least see the *shape* of the product they're going to have when they walk this route in three months.

### H. MVP scope — v1 is private layer + public layer + Mochi v1, with deliberate cuts

The dual thesis (§B) means v1 cannot drop either side of the product. The cuts are within each side rather than removing one entirely.

**In v1:**
- Auto-detected walks rendered on watercolor base tiles (launch city only).
- Walk chapters with 3-line generated prose (Mochi v1 — place type, weather, time, photo count, returning visitor flag).
- Mochi as a persistent character with persona-bound observations and walk-chapter prose.
- Public note layer (text + optional photo, ~10m GPS pin, anonymous, 30-day decay, echo gesture).
- Full moderation stack (§C) — non-negotiable for the public layer.
- Returning-visitor mode for the launch city only (year-over-year place memory).
- Free tier + Lantern+ subscription.
- iOS first; Android is **fast-follow**, not simultaneous (see §I).

**Cut from v1:**
- **Friends layer overlay.** Friends' notes weighted differently is a v2 feature. Adding a social graph to v1 doubles the moderation surface (now you have a follow graph, harassment vectors, account takeover risks, etc.). v1 is anonymous-only.
- **Voice notes.** Lantern+ feature, deferred to v1.5. Voice introduces transcription, accessibility, and moderation costs without a clear v1 wedge.
- **Multiple cities.** v1 ships with one city. Geographic expansion is post-launch.
- **Map style options.** v1 ships with one watercolor style (the launch artist's style). Style options are a Lantern+ feature, deferred to v1.5.
- **Yearly Atlas.** The print-on-demand book is the killer revenue hook (§M) but is **not a v1 feature**. v1 ships in time for users to walk *for a year*; the Atlas itself ships at the v1.5 mark (when there is a year of data to print).
- **Mochi's Memory Book.** A Lantern+ feature where Mochi compiles favorite-spots and patterns into a longer narrative. Deferred to v1.5.
- **Travel mode.** Polarsteps-style trip-clustering for visiting other cities. Deferred to v2.
- **Web app or desktop surface.** Mobile-only.

**Could v1 be "private only" with the public layer as v2?**

This is the key MVP question. Two arguments:

- **For private-only v1:** Eliminates the moderation risk (§C) entirely from v1. Cuts the build by 30–40%. Allows a faster ship and a chance to validate the private-side audience before assuming the public layer.
- **Against private-only v1:** The public layer is the **magic**, the screenshot moment, the friend-show-able feature. Without it, Wayside is "Polarsteps for everyday walks with cute prose" — a smaller, less differentiated product. The wedge softens.

**Decision: v1 includes the public layer.** The moderation strategy in §C is the price paid for keeping the magic in v1. The risk is contained by the 30-day decay (the worst case is bounded) and the launch-city scope (one city's public layer is humanly-reviewable by a solo dev plus AI agents during the first months).

If, during the build, the moderation surface proves heavier than expected, the fallback position is **v1 ships private-only and the public layer is v1.5** — but this is a fallback, not the plan. The plan is dual-thesis v1.

### I. Tech stack — mobile-first, iOS-first, .NET on the backend

**Mobile platform: iOS first, Android fast-follow.**

- **iOS first** because: Apple's on-device foundation model (Apple Intelligence) is the strongest candidate for Mochi's on-device model on launch devices. iOS users skew higher-willingness-to-pay for indie consumer apps. Mapping APIs and location-permission UX are more refined on iOS. Single-platform launch reduces solo-dev surface by ~50% during the riskiest phase.
- **Android fast-follow** (3–6 months after iOS launch) because: Android is half the global mobile market, and the launch-city target (Tokyo) skews Android-heavy in some demographics. But the Android build is not a v1 blocker.
- **Cross-platform framework:** Native Swift (iOS) and Kotlin (Android). **Not** .NET MAUI, **not** Flutter. The aesthetic and gesture standards Wayside needs (custom map rendering, smooth scrolling, watercolor texture rendering) are easier to hit on native than on cross-platform frameworks. The cost is two codebases for two platforms; the benefit is the visual identity actually lands.

**Mapping library:**

| Option | Pros | Cons |
|---|---|---|
| **Apple MapKit (iOS) / Google Maps SDK (Android)** | Free or cheap. Built-in. Rendering quality is high. | Hard to override the base style with custom watercolor tiles. Branding restrictions. |
| **Mapbox** | Custom tile sources are a first-class feature. Cross-platform consistent. | Pricing scales with users (free tier is generous; paid tiers are real). |
| **MapLibre (open-source Mapbox fork)** | Custom tiles, no per-user pricing. | Operational overhead (tile-server hosting). Less polish than Mapbox. |
| **Custom vector renderer** | Total control. | Massive build cost. |

**Decision: Mapbox for v1, with a path to MapLibre if Mapbox's pricing crosses a threshold.** Mapbox's custom-tile support is the cleanest path to watercolor base tiles. The pricing is acceptable for the launch-city scope. If Wayside scales past the Mapbox free-tier cliff, the migration to MapLibre is well-trodden (the tile format is the same).

**On-device LLM for Mochi:**

| Option | Pros | Cons |
|---|---|---|
| **Apple Intelligence on-device foundation model (iOS only)** | Free. High-quality. Runs natively. Power-efficient. | iOS-only; new (still evolving as of 2026); persona-anchoring discipline depends on Apple's prompt boundary controls. |
| **llama.cpp with a small (1.5B–3B) quantized model** | Cross-platform. Full control. | Larger app binary. Battery cost. iOS App Review may scrutinize. |
| **MLC LLM** | Cross-platform, optimized for mobile. | Less mature than llama.cpp; smaller community. |
| **Cloud-only Mochi (no on-device model)** | Simpler. | Privacy story breaks (every Mochi prompt becomes a cloud call). Latency. Cost. |

**Decision: Apple Intelligence on iOS v1.** Quality is sufficient for Mochi's bounded prompt. Cost is zero. Privacy is on-device by definition. Android fast-follow uses MLC LLM with a 2B-class model as the candidate; the implementation ADR will validate the persona discipline holds across both stacks.

**Backend: .NET, reusing the HoneyDrunk Grid.**

The Wayside backend is .NET on Azure, reusing the Grid's primitives where they fit:

- **Auth** for user identity (anonymous device pseudonym + optional email-bound account for sync).
- **Vault** for tenant secrets (tile-server keys, moderation API keys, etc.) — Wayside is a single Grid "tenant" architecturally, similar to how internal Notify usage is tenant `internal`.
- **Notify** for push notifications (someone echoed your note → push). This is the **second consumer of Notify** after Notify Cloud, and it is internal-tenant. No multi-tenant friction.
- **Communications** for the orchestration of those pushes (preferences, quiet hours, frequency caps).
- **Pulse** for telemetry.
- **Web.Rest** for the API surface.

**New infrastructure required:**

| Component | New? | Notes |
|---|---|---|
| **GPS-coords-to-notes spatial index** | New | A geospatial index keyed on H3 or geohash cells. Notes within a query radius are returned. No off-the-shelf Grid Node owns this; Wayside's backend introduces it. |
| **Photo storage** | New | Azure Blob Storage container with per-note SAS URLs and an ingestion pipeline that runs the vision moderation pass before publish. |
| **Map tile rendering pipeline** | New | Offline pipeline (run by the studio, not at runtime) that produces the watercolor tile sets per city per style. Output is uploaded to a CDN-fronted Blob Storage container. |
| **Moderation pipeline** | New | Pre-publish text and image classification, with a manual-review queue surfaced to the solo-dev-plus-agents review tool (likely a HoneyHub view, since HoneyHub is the internal control plane). |
| **Print-on-demand integration** | New | Adapter to the chosen POD provider (see §K). |

The Wayside backend lives in its own new Node — let's call it **`HoneyDrunk.Wayside`** for shorthand — that depends on Auth/Vault/Notify/Communications/Web.Rest/Pulse. The standup ADR (a follow-up artifact, not part of this PDR) defines the Node's package families per the standup-ADR convention.

This means Wayside is a Grid-internal product but a **non-Grid-branded customer surface** — the same pattern the Grid is set up for. Internal Grid use, customer-facing brand.

### J. Dependencies on the HoneyDrunk Grid

| Grid Node | Dependency | Notes |
|---|---|---|
| **Auth** | Wayside accounts (email-bound, optional). Anonymous device pseudonym is local. | Single-tenant for Wayside; Wayside is one logical tenant in Auth's view. |
| **Vault** | Tile server credentials, moderation API keys, POD provider keys, Apple Intelligence-related entitlements (if any). | Standard Vault usage. |
| **Notify** | Push notifications when a user's note is echoed; weekly digest emails for Lantern+. | Wayside is an internal Notify caller, not a Notify Cloud tenant. |
| **Communications** | Push/email orchestration with quiet hours, frequency caps, user preferences. | Standard internal usage; mirrors how the Grid's other internal consumers will use it. |
| **Pulse** | Telemetry. | Standard. |
| **Web.Rest** | API surface for the mobile clients. | Standard. |
| **Kernel / Transport / Data** | The usual runtime backbone. | Standard. |

**No dependency on:**
- HoneyDrunk.AI (Wayside's AI is on-device or via direct cloud API to Apple/Anthropic/OpenAI, depending on the pass — not via the AI routing layer in PDR-0001 §B). Wayside does not benefit from Grid-wide AI routing at v1; the routing layer's value is for organizations with AI governance needs, which Wayside-as-product does not have.
- HoneyDrunk.Observe — Wayside is not an observed external project; it's a Grid-internal app.
- HoneyHub-as-external — Wayside is a customer-facing app, not a HoneyHub-platform tenant.

**Wayside as a dogfood target:** Wayside's launch puts the second non-Notify-Cloud production load on Notify and Communications, which is healthy. It also creates a real consumer-app workload pattern (mobile clients, push notifications, user-generated content moderation) that the Grid has not seen before. The Grid benefits from Wayside the same way it benefits from Notify Cloud — production-pressure-shaped feedback that an internal-only Grid does not generate.

### K. The Yearly Atlas — print-on-demand pipeline as the killer revenue hook

The Atlas is the v1.5 revenue hook and is the most differentiated product surface. **A physical, bound book of the user's year of walking** — watercolor maps, photos, walk chapters, a foreword by Mochi — printed on demand, shipped at year-end.

**Pricing:** $24 retail (target). Cost target: $10–14 unit cost (print + ship). Margin target: $10–14 per Atlas, plus the marketing impression of a real physical artifact in the user's home.

**POD provider candidates:**

| Provider | Pros | Cons |
|---|---|---|
| **Blurb** | High-quality binding. Native consumer-facing brand. Long history. | Expensive per unit; $24 retail at quality is hard to hit. |
| **Lulu (Lulu Direct API)** | API-first. Lower per-unit cost than Blurb. Reasonable quality. | Quality varies by paper choice. International shipping is uneven. |
| **Bookwright / Blurb's API** | Decent API. Quality. | Same cost issue as Blurb. |
| **Mixam** | High quality, photo-book-tier paper. | Less API-friendly; more manual flow. |
| **Local Japanese print partner (if Tokyo launch)** | High quality (Japan's print culture is exceptional). On-brand for the launch city. | Custom integration. Solo-dev complexity. Revisit at v1.5+. |
| **Self-printing via a print broker** | Maximum margin. | Operational overhead the studio cannot absorb. |

**Decision: Lulu Direct API for v1.5 launch, with a Mixam evaluation for the upper-tier Atlas variant.** Lulu's API is the path of least resistance for a solo dev. If quality complaints arise, a manual Mixam path is a $10-more-unit-cost premium variant.

**Shipping logistics:**
- The Atlas is a once-per-year event for each user (ordered Dec 1–31 based on the previous walking year).
- The Atlas is **not** a subscription product; it's a one-time annual purchase. Lantern+ subscribers get a discount ($19 instead of $24); free users pay full price.
- The studio absorbs print fulfillment (Lulu prints and ships directly to the customer's address). The studio does not handle inventory or shipping logistics directly.
- Year-end seasonality: orders are batched in December; Lulu's print queue is a known quantity for that volume; shipping takes 2–4 weeks. Books arrive in January as a "year in review" gift to the user.

**Margin analysis (target):**
- Retail: $24 (free user) / $19 (Lantern+ user).
- Lulu unit cost: ~$10–14 (60–80 pages, hardcover, full color, photo-grade paper).
- Shipping: Lulu charges separately; passed through to customer or absorbed depending on tier.
- Stripe fee: ~$0.85 per transaction.
- **Net margin per Atlas: $8–12.** At 1,000 Atlases sold in the launch year, that's $8K–12K of net revenue from a feature that took ~3–4 weeks of build time. The Atlas is the most cost-efficient revenue surface in the entire product.

**Why this is the killer hook:** Subscription apps churn. Print artifacts don't. The Atlas is the **moment the user's relationship with Wayside becomes physical**, and the moment they become a returning customer next year. It is also the screenshot the user shares with friends — *I made this book of my walks this year* — which is the highest-quality marketing the product can produce.

### L. Pricing analysis

**Tier shape:**

| Tier | Price | What it is | Buyer |
|---|---|---|---|
| **Free** | $0 | Walks, chapters, Mochi, public layer (read + write), basic watercolor map style, one launch city | Anyone curious |
| **Lantern+** | $4.99/mo or $39/yr | Premium map styles, Mochi Memory Book, voice notes (v1.5), Atlas discount, multi-city support | The reader/journaler/aesthete who pays for cozy products |
| **Yearly Atlas** | $19 (Lantern+) / $24 (Free) | The physical bound book of the year | Anyone who wants the artifact |

**Willingness-to-pay benchmarks:**

| Comparable | Price | Format |
|---|---|---|
| **Strava Premium** | $79.99/yr (~$6.67/mo) | Subscription, athletic |
| **Polarsteps Premium** | ~$30/yr (~$2.50/mo) | Subscription, travel |
| **Day One Premium** | $34.99/yr (~$2.92/mo) | Subscription, journaling |
| **Headspace** | $69.99/yr | Subscription, wellness |
| **Calm** | $69.99/yr | Subscription, wellness |
| **AllTrails Pro** | $35.99/yr | Subscription, hiking |
| **Komoot Premium** | $59.99/yr | Subscription, outdoor route planning |

**Why $4.99/mo is the right anchor:**
- Below Strava's effective monthly ($6.67) — Wayside is not Strava, and the price reflects "everyday walks" pricing, not "athletic training" pricing.
- Above Polarsteps and Day One — Wayside has more on-device intelligence (Mochi) and more aesthetic build cost (watercolor) than either, justifying a small premium.
- $4.99/mo is the **App Store thumb-stop number** for indie consumer apps. Below $5 reads as approachable; at or above reads as serious.
- Annual at $39 is a 35% discount vs. monthly, which is the standard SaaS shape.
- The monthly price is **not** the primary revenue driver. The Atlas is. Lantern+ is the retention hook that makes the Atlas natural ("you've subscribed all year — your Atlas is ready to order at the discounted price").

**Why the Atlas is the killer hook:** see §K. Repeating because it's load-bearing: the Atlas is a one-time annual purchase that produces $8–12 of net margin per unit and is the strongest physical-artifact customer-relationship moment in the entire product. The math at 1K Atlases ($8K–12K) is meaningful for a solo-dev; at 10K Atlases ($80K–120K) it is the studio's primary consumer-app revenue.

**Combined revenue model (target, 12 months post-launch, single launch city):**
- 50K free users (the realistic ceiling for one city in 12 months with strong PR).
- 5% conversion to Lantern+ at $4.99/mo or $39/yr → 2,500 paying subscribers.
  - At an even split, ARR ≈ 2,500 × ~$40 = **$100K/yr** subscription revenue.
- 10% of all users buy the Atlas at $24 average → 5,000 Atlases × $10 net margin = **$50K Atlas margin**.
- **Total: $150K/yr at year-1 in one city.**

Numbers above are *targets*, not commitments. They are written here so the kill criteria (§N) have something to compare against.

### M. Lantern+ specifics

The Lantern+ tier is a paid layer over the free product. Its features:

- **Premium map styles** — multiple watercolor styles per city (cherry-blossom, winter, alleyway-noir, ukiyo-e, etc.), commissioned from real illustrators, swap-able per chapter or per walk.
- **Mochi Memory Book** — a longer-form synthesis Mochi writes for the user once per quarter ("the corners Mochi has noticed you returning to" — observational, not analytical, in keeping with §D's persona constraint). Stored on-device with optional encrypted sync.
- **Voice notes** (v1.5) — the user can leave voice notes on the public layer or the private layer. Transcribed; subject to the same moderation pipeline as text + photo. Lantern+ only because it's expensive to moderate.
- **Multi-city support** — return-visitor mode and watercolor base tiles for additional cities the user travels to. Free users get one city; Lantern+ unlocks all available cities.
- **Atlas discount** — $19 instead of $24.
- **Lantern+ Sync** — encrypted cloud sync of the user's walk history, photos, and Mochi memory across devices. Free users are device-local.

These features map to clear architectural surfaces (multi-style tile sets, on-device Memory Book file, voice transcription pipeline, multi-city tile cache, sync backend), so adding tier gates is a cleanly bounded code change.

### N. Geographic launch sequencing

| Phase | Cities | Buyer count target |
|---|---|---|
| **Soft launch (waitlist)** | 1 (Tokyo Yamanote inner) | <500 (invite-only) |
| **v1 public launch** | 1 (Tokyo Yamanote inner) | First-year target: 50K free, 2.5K paying |
| **v1.5 (post-Atlas)** | +1 (Kyoto, NYC, or London — TBD by traction) | Doubling target |
| **v2** | +3–5 cities | Tier expansion |

The pace of city expansion is bounded by the watercolor tile-rendering work (§E). Each new city requires illustration time that cannot be parallelized infinitely. The studio sets a pace of 2–3 cities per year as a sustainable cap.

### O. Kill criteria

Wayside is killed if either:

1. **<500 paying Lantern+ subscribers within 12 months of public launch** in the launch city, AND **<2,000 Atlases sold in the first Atlas season**. The combined kill-condition acknowledges that Lantern+ is the retention proxy and the Atlas is the revenue truth. Missing both means there is no audience.
2. **The public layer's moderation costs exceed Lantern+ revenue.** Specifically: if the time-and-money cost of running the moderation pipeline (cloud classifier costs, manual-review hours, abuse-incident response) is greater than the gross revenue from Lantern+ for two consecutive quarters, the public layer is not economically viable as a free feature. The fallback is to make the public layer Lantern+-only or to sunset it. This is an architectural pivot, not a kill of the whole product, but it removes the dual-thesis advantage and may trigger a v2 redesign.

A **soft kill**:

3. **Mochi failure-mode rate above tolerance.** If Mochi's off-character / break-character / creepy-output rate (measured via user reports + automated review) exceeds 1% of walk chapters in any 30-day window post-launch, Mochi is paused (replaced with a deterministic placeholder) until the persona stack is fixed. This is not a product kill but is a public-face hit that may compound.

4. **Curiosities adoption below floor.** If <15% of weekly active users open the Curiosities tab in month 1 of v1.5, cut Curiosities and revert Wayside to private-marginalia + public-notes-only. The mode is additive, not load-bearing; if the question-mark loop does not pull the existing Wayside audience, it does not earn its content cost.

The kill clock starts at v1 public launch. The Curiosities-specific clock (§O.4) starts at the v1.5 Curiosities ship.

### P. Curiosities mode — v1.5 absorption of the parked Arcadia direction

The previously-recorded Arcadia direction (a standalone city quest map with question-mark unlocks) is killed as a separate product and absorbed into Wayside as a **v1.5 mode named "Curiosities."** Wayside v1 ships per §H unchanged — Curiosities does not enter the v1 build. Curiosities targets the **9–12 month mark post-public-launch**, alongside or just after the first Atlas season. The strategic logic: Wayside already owns the walking customer, the watercolor map, the launch-city geography, and Mochi's voice. A second walking app competing with Wayside for the same buyer is a portfolio mistake. A second walking *mode* that pulls returning users back into the city is a retention asset.

Emotional thesis line: *"Walking through your city as your own quiet myth, with question marks at the corners."*

Customer-facing language is **"Curiosities."** Internal docs may use "quests" for the templates; the customer never sees the word "quest," "level," "XP," or "mission."

#### P.1 Core loop

The Curiosities mode is a tab inside Wayside, not a separate app:

1. The user opens the stylized Wayside map (same watercolor base tiles as the private layer).
2. Nearby unknown points appear as **question marks** on the map, separate visual layer from public place-notes.
3. The user physically approaches a question-mark point.
4. The point **unlocks** into a named place card.
5. The card gives short context, one optional micro-action (a Curiosities prompt template — see §P.4), and a collectible entry.
6. The user's city atlas fills in over time as a Curiosities collection book inside the existing atlas surface.

The product promise of Curiosities is not "best places nearby." It is **go outside, follow curiosity, uncover your city** — the same emotional shape as Wayside's private layer, with mystery as the pull.

#### P.2 Launch geography

Curiosities ships in **one dense launch district inside Wayside's launch city** at v1.5. It does not launch globally and does not launch across all of the launch city.

A credible v1.5 Curiosities footprint:

- **50–100 curated points of interest** within one walkable district.
- **5–10 themed collections** (architectural motifs, public art, local legend, historical era, etc.).
- **20–30 micro-quest templates** drawn from the prompt set in §P.4.
- **No UGC for Curiosities at launch.** This is the load-bearing distinction from Wayside's public marginalia layer (which is UGC by design, gated by the §C six-layer moderation stack). Curiosities POIs are **curated-only** at v1.5. User-suggested places may be considered post-v1.5 but are not part of the launch.
- **No business listings** beyond places selected as Curiosities content. Curiosities is not a local-discovery utility.
- **No routing into private property, sensitive facilities, or unsafe locations.** Same exclusion rules as Wayside's place-rendering invariants.

The first release of Curiosities should feel handcrafted in one district rather than thin everywhere. Geographic expansion of Curiosities follows Wayside's own city expansion (§N) — each new Wayside city eventually gets a Curiosities district, but not on day one of that city.

#### P.3 Content model

Curiosities does not hand-write everything from scratch. The pipeline:

- **Open/public data sources** — landmarks, public art registries, historical markers, Wikipedia/Wikidata, OpenStreetMap, parks, public buildings, library/archive material where licensing allows.
- **AI-assisted summarization** — short plain-language place cards, curiosity hooks, and suggested micro-actions generated against the curated data.
- **Human approval** — every published v1.5 Curiosities POI is reviewed by HoneyDrunk before it appears. Curated-only at launch means the review burden is bounded by the 50–100 POI footprint.
- **Reusable templates** — quest types are generated from the §P.4 prompt set rather than bespoke design per location.
- **Mochi narrates the unlock cards in Wayside's voice.** Curiosities does **not** introduce a separate game-y narrator. The unlock-card prose obeys the same persona constraints as §D (no input box, no questions, no advice, no parasocial register, no proper-noun knowledge outside the place itself). The literary tone of a Curiosities unlock is indistinguishable from a Wayside walk chapter.

The content bar is: good enough to make a walk feel intentional, not academic enough to become a museum app.

#### P.4 Quest templates as lightweight prompts

Curiosities uses Wayside-toned templates, not RPG systems. The v1.5 prompt set:

- **Look Closely** — find a detail on a building, mural, plaque, statue, or storefront.
- **Then / Now** — read a short historical note and compare it to what is there now.
- **Sound of the Corner** — pause for 30 seconds and note one sound.
- **Color Hunt** — find a dominant color or visual motif nearby.
- **Public Art Scan** — unlock a mural, sculpture, or public artwork and collect its style tag.
- **Tiny Detour** — walk one block off the obvious route to unlock a nearby curiosity.
- **Postcard Moment** — take or save a private photo for the user's atlas.

Explicitly cut from Curiosities (these are not deferrals — these are out of scope for the mode entirely):

- XP, levels, streaks, leaderboards.
- Competitive territory control.
- User-created public quests.
- AR overlays.
- Sponsored quests.
- Nighttime or isolated-location prompts.
- Anything that asks users to enter private property, disturb people, or interact with strangers.

The prompt set is intentionally small. New templates are added only after the existing set proves out post-launch.

#### P.5 Collectibles are emotional, not addictive

Curiosities' collection layer should feel like filling a field guide, not grinding a battle pass. The collectible types:

- Place stamps.
- District cards.
- Architectural motifs.
- Local legend fragments.
- Public art styles.
- Historical era tags.
- Contextual memory tags ("first rain walk," "golden hour find," etc.).

No scarcity manipulation. No daily pressure. No streak loss. No expiring collectibles. Collection rewards attention, not compulsion. The collection book lives inside the Wayside atlas surface — Curiosities entries appear alongside private walk chapters and (for the year-end Atlas) optionally render as a chapter of the printed book.

#### P.6 Sequencing — v1.5, not v1

Curiosities is **not in Wayside v1**. Wayside v1 ships per the existing §H phasing: private layer + public marginalia + Mochi v1, dual-thesis, launch city, no Curiosities. The Curiosities mode is a v1.5 addition, targeted for the **9–12 month mark post-public-launch**, alongside or just after the first Atlas season.

Reasoning for v1.5 placement (not v1):

- v1's risk surface is already dual-thesis. Adding curated POI content production to v1 widens the surface unsafely.
- Curiosities benefits from a populated launch city. Question marks inside a city where Mochi has already drawn the user back several times have more pull than question marks in a brand-new product.
- The Atlas pulls users into year-end attention. Curiosities sustains attention into year-2 by giving the user something new to do in the city they already walk in.
- The curated content model is reusable for multiple districts, which means the v1.5 build cost amortizes as Wayside expands cities (§N).

#### P.7 What changes elsewhere in Wayside

Curiosities does not displace any existing Wayside surface:

- **Private walks, walk chapters, Mochi, watercolor maps** — unchanged.
- **Public marginalia (place-notes with 30-day decay)** — unchanged. Curiosities is **a separate map layer** from public notes; users see question marks and notes as visually distinct surfaces, not merged into one feed. This protects the public layer's emotional shape ("strangers' attention at this bench") from being muddled with curated content.
- **Atlas** — Curiosities entries optionally render in the year-end Atlas as a "Curiosities of the year" chapter. This is a v1.5 enhancement, not a v1 promise.
- **Lantern+** — Curiosities is **free at launch**, not gated behind Lantern+. Premium Curiosities styling (decorative collection-book skins, multi-district unlocks beyond the launch district) is a candidate Lantern+ feature post-v1.5; v1.5 itself ships Curiosities free for all users so the loop is broadly tested.
- **Moderation pipeline (§C)** — unchanged. Curiosities POIs are curated-only and do not flow through the public-layer moderation stack at v1.5. If user-suggested Curiosities are added post-v1.5, they ride the existing moderation pipeline.
- **Notify / Communications** — Curiosities introduces no new notification types at v1.5. Push notifications for "a question mark appeared near you" are explicitly **not** in scope; the mode is pull-by-curiosity, not push-by-nudge.

#### P.8 Why this absorption beats a standalone Arcadia

Recorded for the supersession of PDR-0007:

- **One walking customer, not two.** A standalone Arcadia and a separate Wayside compete for the same buyer's pocket and attention. Folding the question-mark loop into Wayside avoids that.
- **One launch city, one tile pipeline, one moderation philosophy.** Arcadia would have re-paid every cost Wayside already pays.
- **One Mochi, not a separate game-y narrator.** The voice is Wayside's strongest asset; reusing it lets Curiosities inherit literary credibility for free.
- **Retention, not acquisition.** Curiosities' question marks are most valuable to users who already have Wayside on their phone. As a standalone, the question-mark loop has to do the cold-start work of acquisition; as a Wayside mode, it does the cheaper work of retention.
- **Curated-only is honest about solo-dev capacity.** Arcadia's standalone scope implied content scale; absorbed-as-a-mode at one district at v1.5 is the actually-shippable shape.

---

## Options Evaluated

### Option 1: Don't build Wayside

**Description:** Stay focused on Notify Cloud (PDR-0002), Hearth (the scout's first-build pick from the 2026-05-05 brainstorm), and the Grid's internal direction. No consumer walking app.

**Pros:**
- Solo-dev capacity stays focused on the ~3 in-flight initiatives.
- Lower risk — no new product launch, no public-layer moderation surface, no mobile-app surface.

**Cons:**
- The category gap (walking-as-mythology) is real and will eventually be addressed by someone. First-mover advantage is non-trivial.
- The studio's brief includes "apps with soul for regular humans" — without any consumer app, the brief is unfulfilled.
- Hearth is the first-build pick, but Hearth's 12-month outcome is unknown. Wayside as a recorded direction means a Plan B exists.

**Verdict:** Rejected as a permanent decision; accepted as a *current* decision. The user's near-term build queue does not include Wayside. This PDR records the direction so that *when* Wayside is picked up, the strategy is already settled.

### Option 2: Wayside, private layer only — no public notes

**Description:** Build Wayside as a personal walking-and-place-memory app. Mochi, watercolor maps, walk chapters, Atlas. **Drop the public notes layer entirely.**

**Pros:**
- Eliminates the moderation risk completely. No abuse vectors, no doxxing, no spam.
- Smaller build surface — no spatial index, no image vision moderation, no community echo system, no cold-start city-launch problem.
- Faster ship — likely 4–6 months instead of 9–12.
- Polarsteps-and-Day-One-style positioning is well-understood.

**Cons:**
- Loses the magic. The screenshot moment ("strangers' notes at the bench I'm sitting on") is gone.
- Wayside-without-public-layer is a less differentiated product. Polarsteps already exists; Day One already exists. Wayside's wedge against them softens to "watercolor and Mochi," which is real but smaller.
- The dual thesis (§B) explicitly argues the two layers reinforce each other. Removing one weakens both.

**Verdict:** Rejected as v1, retained as v1 fallback. If the moderation surface proves heavier than expected during the build, falling back to private-only v1 is acceptable. But the plan is dual-thesis v1.

### Option 3: Wayside, public layer only — no private journaling

**Description:** Build a public marginalia app — a city-of-strangers'-notes — without the private walking journal layer.

**Pros:**
- Sharpest focused product. One thing, well done.
- Smaller build surface (no Mochi, no walk auto-detection).

**Cons:**
- The product is hostile by default. Without the private investment in places, users have no reason to come back. The retention engine is gone.
- The product becomes Foursquare 2 or Geocaching 2. Both have markets, both have failure modes; neither has Wayside's intended emotional shape.
- The Atlas (the killer revenue hook) requires a year of private walking data. Without the private layer, no Atlas, no $50K of margin.

**Verdict:** Rejected. Removing the private layer kills the retention and the revenue model.

### Option 4: Wayside, dual-thesis v1, watercolor maps as v2

**Description:** Build the dual-thesis app but ship v1 with standard map tiles (Mapbox default style) instead of watercolor. Migrate to watercolor in v2 once the product proves out.

**Pros:**
- Removes the upfront illustration cost of watercolor tile sets.
- Faster ship.
- Validates the product mechanics without the visual investment.

**Cons:**
- Kills the visual identity in v1, which is the entire aesthetic premise of the product.
- A walking app on Mapbox default tiles is functionally indistinguishable from any other walking app. The aesthetic is *the wedge*.
- "Migrate to watercolor in v2" rarely happens. v1 momentum is what it is.

**Verdict:** Rejected. The watercolor identity is non-negotiable.

### Option 5: Build Wayside as the next consumer app after Hearth (Selected, deferred)

**Description:** Build Wayside as described in §A–O. The full dual-thesis product, with the moderation strategy, the watercolor identity, Mochi, the Atlas, and Lantern+. Launch in Tokyo (or final-decided city) with the geographic-launch + seed-content cold-start strategy.

**Pros:**
- Captures the full magic of the dual thesis.
- Builds a differentiated product against the category gap.
- Atlas margin is meaningful.
- Builds production-pressure-shaped load on Notify and Communications, which is healthy for the Grid.

**Cons:**
- Largest scope of any of the brainstorm-derived consumer app concepts.
- Public-layer moderation is genuinely the highest-risk feature in the brainstorm.
- Requires illustration discipline that the solo-dev studio does not currently have in-house.
- Cold-start risk is real even with the seed strategy.

**Verdict:** Selected as the recorded direction, with the explicit caveat that *building* Wayside is deferred to a future decision. This PDR is direction, not commitment-to-calendar.

### Option 6: Wayside, but with friends-only (not public) note layer

**Description:** Same as Option 5 but the note layer is friends-only. No anonymous strangers; only your follow graph.

**Pros:**
- Largely eliminates moderation risk (your friends harassing each other is a smaller surface than strangers harassing each other).
- The friends graph adds social retention.

**Cons:**
- Kills the magic. The "strangers' notes at the bench I'm sitting on" moment is impossible if only your friends can leave notes.
- Friends-only means a new Wayside user with no friends-on-Wayside has nothing to read. The cold-start problem is *worse*, not better — it's a two-sided market on top of an already-thin app.
- Adds an account / follow / friend-request system, which is a major build surface.

**Verdict:** Rejected. The strangers-not-friends design is the entire point of the public layer. A friends-layer is a v2 *overlay* on top of the public layer (already in §J: "Friends layer overlays: friends' notes weighted/colored differently"), not a replacement for it.

---

## Trade-offs

| Trade-off | Favored Position | Rationale |
|---|---|---|
| Dual-thesis v1 vs. private-only v1 | **Dual-thesis** | The public layer is the magic. Private-only is a safer ship but a less differentiated product. The moderation strategy in §C is the price paid for keeping the magic. |
| Watercolor maps in v1 vs. defer to v2 | **Watercolor in v1** | The aesthetic is the wedge. Standard tiles in v1 means Wayside is undifferentiated against Polarsteps. |
| Pre-rendered watercolor tiles vs. real-time procedural | **Pre-rendered base + procedural overlay** | Pre-rendered gets quality + speed; procedural overlay keeps the per-walk uniqueness. AI style transfer is rejected. |
| iOS-first vs. iOS+Android simultaneous | **iOS-first** | Solo-dev surface reduction. Apple Intelligence on-device model. Higher willingness-to-pay. Android fast-follow. |
| One launch city vs. global launch | **One launch city (Tokyo proposed)** | Cold-start density. Aesthetic match. Watercolor tile work caps geography. Global launch is impossible with a sparse public layer. |
| Mochi as on-device vs. cloud | **On-device for v1** | Privacy, latency, battery. Apple Intelligence is the candidate. The cloud fallback exists for walk chapters but isn't load-bearing. |
| Anonymous public layer vs. account-bound | **Anonymous (with stable per-device pseudonym)** | Eliminates harassment-of-individual vectors. Echo-as-quality-signal works without identity. The 30-day decay means abuse is time-bounded even for anonymous content. |
| 30-day decay vs. permanent notes | **30-day decay** | This is the single most important architectural choice in the moderation strategy. Permanent notes accumulate failures forever; decaying notes are a self-cleaning mechanism. The product's emotional shape is "alive, present, ephemeral," which is also better than "every place is a tomb." |
| Subscription-first revenue vs. Atlas-first revenue | **Atlas-first as the hook, subscription as the retention** | The Atlas margin is the highest-quality consumer-app revenue surface in the studio's design space. Lantern+ exists as a retention layer that funnels into the Atlas, not as the primary revenue line. |
| Native iOS/Kotlin vs. cross-platform framework | **Native** | The aesthetic and gesture standards Wayside needs are easier to hit on native. The cost (two codebases) is justified by the visual identity actually landing. |
| Build Wayside next vs. build Hearth next | **Hearth next (per the 2026-05-05 brainstorm scout)** | Hearth has no two-sided marketplace problem. Wayside's public layer does. This PDR records direction, not next-build priority. |
| Customer-facing brand: HoneyDrunk vs. separate | **Separate brand (TBD name)** | Wayside is consumer; HoneyDrunk Studios is studio. Hearth would also have its own brand. The studio is the parent; the products stand independently. |
| Standalone city-quest app (parked Arcadia) vs. mode inside Wayside | **Mode inside Wayside (Curiosities, v1.5)** | One walking customer, one launch city, one Mochi voice, one moderation philosophy. A standalone Arcadia would have re-paid every cost Wayside already pays. Question marks are a retention asset for an existing Wayside audience, not an acquisition wedge for a new one. See §P.8. |
| Curiosities at v1 vs. v1.5 | **v1.5** | v1's risk surface is already dual-thesis. Adding curated POI content production to v1 widens the surface unsafely. v1.5 also gives Curiosities a populated launch city to land into rather than an empty product. |
| Curiosities content: UGC vs. curated-only | **Curated-only at v1.5** | Wayside already pays the UGC moderation cost on the public marginalia layer. Layering UGC onto Curiosities at v1.5 doubles the moderation surface for a feature whose floor is unproven. User-suggested POIs are a post-v1.5 question. |

---

## Architecture Implications

### New Node

**`HoneyDrunk.Wayside`** — a proposed consumer Node in the canonical **Market** sector, distinct from Ops, Core, AI, and Meta. This PDR uses **Apps** only as a working portfolio label; a future constitution amendment may formalize that label if the studio decides Market is too broad.

The standup ADR (a follow-up artifact) defines:
- Package families: `HoneyDrunk.Wayside.Abstractions`, `HoneyDrunk.Wayside`, `HoneyDrunk.Wayside.Web` (the API), `HoneyDrunk.Wayside.Moderation` (the pipeline), `HoneyDrunk.Wayside.Print.Lulu` (the POD adapter).
- Spatial-index abstraction (`IPlaceNoteIndex`).
- Tile-rendering pipeline (offline studio tool, not a runtime Node — likely a separate `HoneyDrunk.Wayside.Cartography` repo for the illustration toolchain).
- The mobile clients themselves (`Wayside.iOS`, `Wayside.Android`) are separate repos in their own languages, not .NET packages.

### Boundary changes to existing Nodes

| Node | Change | Notes |
|---|---|---|
| **Notify** | Wayside is a new internal caller. New event types (`PlaceNoteEchoed`, `WeeklyDigest`). | No multi-tenant change; Wayside is internal-tenant. |
| **Communications** | Wayside-specific preferences (push channel, quiet hours, digest cadence). | Standard usage. |
| **Auth** | Wayside accounts are email-bound with optional anonymous flow. New device-pseudonym primitive. | Device pseudonym is a new auth shape — separate from JWT, separate from API key, separate from the anonymous-tenant pattern. May warrant its own ADR. |
| **Vault** | Wayside-specific secrets (tile server, Lulu, moderation classifier credentials). | Standard. |
| **Pulse** | Wayside-specific telemetry tags. New consumer-app metrics shape (DAU, walk-completion rate, public-layer interaction rate). | Standard, with new metric families. |
| **Web.Rest** | Wayside API endpoints. Custom auth path for device-pseudonym tokens. | New auth path needed. |

### What does NOT change

- **The Grid's internal infrastructure invariants.** Same as PDR-0002 §What Does Not Change: invariants 1–36 are not amended.
- **Notify Cloud's roadmap.** Wayside being recorded as direction does not change Notify Cloud's launch sequencing.
- **Hearth's first-build status** (per the 2026-05-05 brainstorm). Wayside is recorded; Hearth is built first.
- **The HoneyDrunk Studios B2B brand surface.** Wayside has its own consumer brand; the studio brand is the parent.

### Curiosities mode — additional surface area at v1.5

Curiosities (§P) is a v1.5 addition inside the existing `HoneyDrunk.Wayside` Node. It does not introduce a new Node or a new Sector. The architectural deltas at v1.5:

- **Curated POI store.** A new content surface for the launch-district POIs, their copy, their template bindings, and their collectible metadata. Curated entries are versioned and human-approved before publish; this is a different content lifecycle than the public-layer note (which is user-published with pre-publish moderation and 30-day decay). The store may live in the same database as the spatial index but uses a different write path.
- **Question-mark map layer.** A separate render layer on top of the watercolor base, distinct from the public-notes layer. Visually and interactively separated per §P.7. No change to the watercolor tile pipeline itself.
- **Collection book surface.** A new view inside the existing atlas surface. No new Node; no new Grid contract.
- **Mochi prose binding.** Curiosities unlock cards run through Mochi's existing on-device persona (§D) with a Curiosities-specific prompt addendum. No new on-device model; no new cloud surface.
- **No new Notify event types at v1.5.** "A question mark appeared near you" pushes are explicitly out of scope; Curiosities is pull-by-curiosity, not push-by-nudge.

---

## Product Implications

### Customer-facing brand and positioning

Wayside (final name TBD) is positioned as a **consumer walking and place-memory app**, not as a HoneyDrunk Studios product. The customer-facing surface (App Store listing, marketing site, in-app copy) does not mention HoneyDrunk Notify, the Grid, or any architectural metaphor. The studio's relationship to Wayside is a credit at the bottom of the marketing site ("from HoneyDrunk Studios") and a build-in-public dev log; no more.

This is consistent with PDR-0002 §H (separate consumer brands; the studio is the parent; the Grid is invisible to customers).

### Build-in-public alignment

Wayside's build is content the studio publishes as it ships. The architectural decisions (moderation pipeline, on-device LLM choices, watercolor tile pipeline) are public via PDRs and ADRs — but not surfaced to Wayside's customers. The audience for Wayside's PDRs is the same .NET-and-architecture audience that reads PDR-0001 and PDR-0002; the audience for Wayside the *product* is regular humans who walk in cities.

### Tier shape

| Tier | Price | Buyer | Why they pay |
|---|---|---|---|
| Free | $0 | Anyone | Walks, chapters, Mochi, public layer. |
| Lantern+ | $4.99/mo or $39/yr | The aesthete-walker, the journaler, the cozy-product buyer | Map styles, Memory Book, voice notes, multi-city, Atlas discount, sync. |
| Yearly Atlas | $19 (Lantern+) / $24 (Free) | Anyone with a year of walks | The physical artifact. The screenshot. The friend-show-able object. |

### Marketing channels

The .NET indie community is **not** the Wayside audience. Wayside's channels are:
- Aesthetic-Twitter / aesthetic-Mastodon / aesthetic-corner-of-Bluesky (the audiences who follow accounts about cozy art, walking, Tokyo, watercolor, etc.).
- **r/CozyPlaces, r/Citywalkers, r/Walking, r/Tokyo** on Reddit.
- Substack newsletters in the walking / urbanism / personal-essay / Japanese-aesthetic adjacent space.
- Instagram and TikTok (visual-first platforms; the watercolor identity is screenshot-bait).
- App Store editorial — Wayside is a strong "App Store Story" candidate if the editorial team picks it up.
- **The launch-city press.** Tokyo design press, Tokyo English-language press, Japanese walking-culture press if a launch in Tokyo lands.

The marketing budget at v1 is implicit (solo-dev time + AI agent time) plus optional commissioned-illustrator and seed-creator costs. No paid acquisition in v1; the plan is content-and-aesthetic-led.

---

## What Does NOT Change

- **The studio's manifesto.** Wayside is consistent with build-in-public ("the architecture is public, the customer-facing language is human") and Open Core ("the consumer apps are not OSS — they're the studio's commercial line").
- **PDR-0001 and PDR-0002.** Wayside is in a different product line. Notify Cloud's launch is unaffected. Notify Cloud remains the studio's first commercial milestone.
- **PDR-0005's first-consumer-build commitment.** Hearth remains the recorded first consumer-facing app on the Grid. Absorbing Curiosities into Wayside does not promote Wayside ahead of Hearth in the build queue. Hearth ships first; Wayside v1 ships second; Wayside Curiosities (v1.5) ships third.
- **Architecture invariants 1–36.**
- **The Grid's internal direction.** Wayside reuses Auth, Vault, Notify, Communications, Pulse, Web.Rest as an internal consumer.
- **Wayside v1 scope.** The §H phasing is unchanged by the Curiosities amendment. Curiosities is additive at v1.5; nothing in v1 shifts to make room for it.
- **The public marginalia layer.** Curiosities lives on a separate map layer with separate visual treatment and a separate (curated, not UGC) content model. The public-notes layer's anonymous-by-default, 30-day-decay, six-layer moderation posture (§C) is unchanged.

---

## Risks

| Risk | Severity | Description |
|---|---|---|
| **Public-layer moderation failure** | High | A determined bad actor gets harmful content past the moderation stack. The 30-day decay caps blast radius but does not eliminate it. |
| **Public-layer cold start fails** | High | The launch city's public layer feels empty at launch despite seed content. Users churn before the layer fills. |
| **Mochi breaks character publicly** | High | A screenshot of Mochi saying something off-character, racist, or otherwise harmful goes viral. The product's literary persona is destroyed in a single news cycle. |
| **Watercolor identity is technically unattainable** | High | The watercolor tile pipeline produces results that look like Mapbox-with-a-filter, not real watercolor. The aesthetic premise dies. |
| **Battery cost is unacceptable** | Medium-High | Auto-detected walks consume more battery than the iOS / Android budgets allow. Users disable background location. |
| **Apple Intelligence model is insufficient for Mochi's persona** | Medium | The on-device model lacks the literary register or the persona discipline to maintain Mochi credibly. Fallback to cloud breaks the privacy story. |
| **Solo-dev capacity is exceeded** | Medium-High | Wayside is the largest of the three brainstorm concepts. Even after Hearth, the solo dev does not have capacity to ship Wayside at the scope described. |
| **Atlas POD quality is below customer expectations** | Medium | Lulu's quality varies; a $24 book that arrives looking cheap is a refund problem and a reputation problem. |
| **Geographic concentration on Tokyo is a strategic mismatch** | Medium | The user is not native to the launch market. Marketing, support, and community-building in JA are real constraints. |
| **iOS App Review rejects an aspect of Wayside** | Medium | Background location apps face heightened scrutiny. The on-device LLM is novel enough that Apple may want to review the prompts. The public-layer moderation is the kind of thing Apple wants details on. |
| **Lantern+ conversion is below 5%** | Medium | The willingness-to-pay benchmark assumes 5% conversion from free to Lantern+. If actual is 1–2%, the subscription model is broken. |
| **Atlas is not bought at the assumed rate** | Medium-High | The Atlas math assumes 10% of users buy it. If it's 1%, the killer revenue hook is dead. |
| **Mochi's persona becomes parasocial in a harmful way** | Low-Medium | Users form unhealthy attachments to Mochi. The literary register (§D) is the mitigation, but parasocial attachment to AI characters is a real and increasing risk profile. |
| **The dual thesis is wrong** | Medium | The two layers do not reinforce each other in practice. Users use one or the other but not both. The product's premise is half-realized. |
| **Brand decision is delayed too long** | Low | "Wayside" remains the placeholder for too long; marketing momentum is lost during the rebrand. |
| **Curiosities content production overruns v1.5 capacity** | Medium | The 50–100 curated POI footprint is "small" only relative to a global map. For a solo dev plus AI agents shipping during v1.5, the curation, copy review, safety check, and template wiring per POI is real work. If the v1.5 ship slips because Curiosities content is incomplete, Wayside's broader v1.5 (Atlas, Memory Book, voice notes) slips with it. |
| **Curiosities dilutes the public marginalia layer's emotional shape** | Medium | If users perceive question marks and stranger-notes as the same thing, the "strangers' attention at this bench" magic flattens into "the app is telling me to do things here." The §P.7 visual-separation rule is the architectural guard, but a UX failure here is real. |
| **Curiosities adoption is below the §O.4 floor** | Medium | <15% of weekly active users open the Curiosities tab in month 1 of v1.5. The mode is cut and reverted per §O.4. Cost: the v1.5 build effort is mostly sunk, though the curated content and templates are partially salvageable for a future re-attempt or for Wayside's editorial-tone work. |
| **Curiosities pulls Mochi's voice off-shape** | Medium | Curiosities unlock cards must obey Mochi's persona constraints (§D). If the prose drifts toward game-narrator or tour-guide voice to fit the mechanic, the broader Wayside literary register erodes. |

---

## Mitigations

| Risk | Mitigation |
|---|---|
| Public-layer moderation failure | Six-layer moderation strategy (§C). 30-day decay caps blast radius. Manual review queue for borderline content. Per-place rate limits (no more than N notes per 100m radius per hour). Studio maintains an emergency takedown protocol for any reported note with an SLA of 4 hours during launch. |
| Public-layer cold start | Geographic launch with one city (§G). Mochi-authored tutorial seed notes. Launch-team and partner-creator seed content. Time-bounded paused-decay for the first 30 days of a city. Soft-launch waitlist to validate density signals before public launch. |
| Mochi breaks character | Strict prompt with red-team-tested negative examples. Output filter rejects refusal patterns and out-of-bounds proper nouns. Deterministic filler-line fallback. Continuous monitoring for off-character outputs via user reports + automated review; if rate >1% in any 30-day window, Mochi is paused (soft-kill criterion §O.3). |
| Watercolor identity unattainable | Pre-rendered tile set is illustration work, not algorithm work — commissioned from a real illustrator who controls quality. The studio reviews tile quality before any city launches. AI style transfer is explicitly rejected (§E). |
| Battery cost | Significant-location-change APIs as the low-power baseline. High-fidelity GPS only during active walks. Battery target <3%/day. Build measures battery cost as a CI metric on hardware emulation; ship-stop if exceeded. |
| Apple Intelligence insufficient | Implementation ADR validates persona discipline before scale-out. MLC LLM with a 2B model is the cross-platform fallback. Cloud Mochi is the third fallback (with an explicit privacy disclosure adjustment). |
| Solo-dev capacity | Wayside is **deferred** as a build until Notify Cloud and Hearth produce known outcomes. The PDR is direction-only. The build packet will require a fresh capacity review at the time it is opened. |
| Atlas POD quality | Lulu order-of-50 quality validation before public Atlas launch. Mixam upgrade path for premium Atlas variant. Customer-service hand-replacement policy for any Atlas that arrives damaged or below quality. |
| Tokyo strategic mismatch | The launch-city decision is deferred to the build-decision packet; Tokyo is the proposed default but not committed. Alternative cities (Lisbon, Edinburgh, NYC) remain on the table. |
| iOS App Review rejection | Pre-submission consultation with Apple where possible. Conservative permission language. Public moderation policy linked from the App Store listing. The walking-app + on-device-LLM + UGC combo is novel; allow buffer time for App Review back-and-forth. |
| Lantern+ conversion | Premium features are explicitly designed to be wanted by the cozy-product audience (map styles, Memory Book, sync). If conversion is <5% in the first 6 months, run pricing experiments (annual-only, $3.99/mo) before declaring a kill. |
| Atlas under-bought | The Atlas is the v1.5 launch event, not v1. The first Atlas season provides data; if 10% target is missed, the next year's marketing is restructured around the Atlas. The Atlas is not the only revenue line — Lantern+ is the floor. |
| Parasocial Mochi attachment | Mochi's literary register (§D) is the architectural mitigation. The "no input box" rule is structural — users cannot have a one-on-one relationship with Mochi because they cannot speak to her. This is not retroactive; it's by design. |
| Dual thesis is wrong | The fallback is private-only v1.5 (deprecate the public layer). The 30-day decay means a deprecated public layer cleans itself up within 30 days with no orphan content. |
| Brand delay | The build-decision packet (the next packet for Wayside, post-this-PDR) settles the brand name as a hard prerequisite to any user-facing work. |
| Curiosities content overrun | Strict 50–100 POI cap at v1.5 launch, one district only. Templates over bespoke. AI-assisted summarization with human approval. The Curiosities content build runs in parallel with the Atlas season, not in series — if it slips, it slips Curiosities, not Atlas. |
| Curiosities dilutes public marginalia | Visually distinct map layers (§P.7). Different unlock interaction (approach-then-tap for Curiosities; pin-tap-then-read for notes). Different copy tone (Curiosities cards are observational about the place; notes are first-person from a stranger). User testing during v1.5 prototype validates the separation reads cleanly. |
| Curiosities adoption below floor | The §O.4 kill criterion is bounded and time-limited. Reverting is a clean cut: question-mark layer disabled, curated content archived, no orphan UGC to clean up. The fallback Wayside (private + public marginalia) is the v1 product, which is already proven by the time v1.5 ships. |
| Curiosities pulls Mochi's voice off-shape | Curiosities unlock cards run through the same persona prompt and output filter as walk chapters (§D). The implementation ADR for Curiosities content explicitly forbids game-narrator and tour-guide register patterns. If Mochi's failure-mode rate (§O.3) climbs after Curiosities ships, Curiosities prose is the first surface to audit. |

---

## Consequences

### Short-term (this PDR is direction-only — there is no immediate build)

- **The recorded direction is published.** A future packet to "build Wayside" can refer to this PDR as the strategic anchor.
- **The 2026-05-05 brainstorm's Wayside concept is formalized.** Hearth remains the scout's first-build pick; Wayside is the recorded second.
- **No Grid changes are committed.** The standup ADR for `HoneyDrunk.Wayside` is a follow-up artifact, not part of this PDR.

### Long-term (if Wayside is built)

- **The Grid acquires a second consumer-facing product line.** Notify Cloud is B2B; Wayside is B2C. The studio is positioned as a portfolio of products, not a single-product studio.
- **The Grid's internal Notify and Communications gain a second non-trivial production load** beyond Notify Cloud.
- **The studio's revenue diversifies** — subscription (Lantern+), one-time annual (Atlas), and B2B (Notify Cloud) — reducing concentration risk.
- **The consumer-app portfolio is established** under the canonical Market sector. Future consumer apps (Hearth, Lately, future) can inherit the pattern.
- **The studio's public narrative evolves** from "B2B dev tool company" to "studio with a consumer line and a B2B line." This is a meaningful brand shift.

If Wayside is killed (§O):
- **The consumer-app portfolio still exists** for Hearth and any other consumer products.
- **The moderation pipeline knowledge is reusable** for any future UGC-bearing app.
- **The Atlas POD pipeline is reusable** — Hearth's Yearly Book ($34 hardcover) uses the same plumbing.
- **A retrospective PDR is written** documenting what the wedge missed.

---

## Rollout — Phased Approach (when build begins)

This rollout is **not** scheduled. It begins when the user opens a "build Wayside" packet. The phases are recorded so the build sequencing is pre-decided.

### Phase 0: Pre-build decisions

- Final brand name decided.
- Launch city decided.
- Illustrator commissioned for the launch-city watercolor tile set.
- Two seed creators contracted.

**Exit criteria:** brand, city, illustrator, two seed creators all committed.

### Phase 1: Tile pipeline + private layer prototype (weeks 0–8)

- Watercolor tile pipeline (offline studio tool) produces the launch-city tile set.
- iOS prototype: auto-detected walks, watercolor map rendering, basic walk chapter generation.
- Apple Intelligence integration for Mochi v0 (place observations only, no walk chapters yet).
- Notify and Communications wired for push notifications (no public layer yet, so no echo notifications — used for a "your walk has been chaptered" notification only).

**Exit criteria:** Internal users (the studio, beta) can take an auto-detected walk and see a watercolor map + chapter on iOS.

### Phase 2: Mochi v1 + walk chapters complete (weeks 8–14)

- Mochi v1: full place-observation persona, walk-chapter generation, returning-visitor recognition.
- Walk-chapter prose passes red-team review.
- Output filter and filler-line fallback validated.

**Exit criteria:** Mochi's failure-mode rate <0.5% across 1,000 simulated walk chapters (internal benchmark).

### Phase 3: Public layer prototype + moderation pipeline (weeks 14–22)

- Spatial index for place-notes.
- Note publish API + on-device PII filter + cloud moderation classifier + vision moderation pass + echo gesture + 30-day decay job.
- Manual-review queue surfaced via HoneyHub (or a Wayside-specific admin tool).
- Internal-only public layer: only the studio and beta testers can publish; only those users see the layer.

**Exit criteria:** 100 internal-published notes processed end-to-end with full moderation; <2% manual-review queue rate; <0.1% false-negative rate on adversarial tests.

### Phase 4: Soft launch (weeks 22–28)

- Waitlist opens for the launch city.
- 200–500 hand-picked users provisioned.
- Seed creator notes published.
- Mochi-authored tutorial notes ship.
- Lantern+ subscription is **not yet live** (no payments at soft-launch).
- Atlas is **not yet available** (one year of data not yet accumulated).

**Exit criteria:** ≥1,000 walks recorded across users. ≥200 published notes (combined seed and user). ≥30 echoes. No Sev-1 moderation incidents. Battery cost under target.

### Phase 5: Public launch (weeks 28–34)

- App Store launch (iOS).
- Lantern+ subscription via App Store IAP (or Stripe via web; TBD).
- Marketing push: aesthetic-Twitter, Substack outreach, App Store editorial pitch.
- The 12-month kill clock starts here.

**Exit criteria for "successful public launch":** App Store live, Lantern+ subscriptions processing, no Sev-1 incidents in the first 14 days.

### Phase 6: Atlas season + Android fast-follow (months 6–12)

- Lulu Direct API integration for Atlas printing.
- Atlas storefront launches in November of the launch year.
- First Atlas orders ship in January of year-2.
- Android client builds in parallel; ships at the 9–12 month mark.
- Multi-city evaluation begins (next launch city candidate).
- **Curiosities content production begins in parallel** for the launch district: 50–100 curated POIs, 5–10 themed collections, 20–30 micro-quest templates wired to the §P.4 prompt set. Human-approval queue active. Curiosities does not ship to users in this phase.

**Exit criteria:** ≥2,000 Atlases sold in the first season. Android client at parity with iOS. Second-city launch decision packet opened. Curiosities content footprint complete and human-approved.

### Phase 6.5: Curiosities v1.5 ship (months 9–12)

- Question-mark map layer enabled in production.
- Curated POI content released for the launch district.
- Mochi prose addendum live; unlock-card prose passes red-team review against the Mochi persona constraints (§D).
- Collection book surface available inside the atlas.
- Curiosities is free at launch (per §P.7).

**Exit criteria:** Curiosities tab reachable from the main map. ≥15% weekly-active-user open rate by the end of month 1 of v1.5 (the §O.4 floor). No Sev-1 moderation incidents (curated-only at launch limits this risk to editorial errors). Mochi failure-mode rate stays under §O.3.

### Phase 7: Kill-clock review (month 12)

- Lantern+ subscriber count vs. target (500).
- Atlas sales vs. target (2,000).
- Moderation cost vs. Lantern+ revenue.
- Mochi failure-mode rate.
- Curiosities adoption rate (§O.4 floor) — if v1.5 has shipped by this point.

Per §O, decide: continue, pivot (e.g., make public layer Lantern+-only, or cut Curiosities and revert to private + public-notes-only Wayside), or kill.

---

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Final product name (replace "Wayside") | Product | Hard prerequisite to any user-facing work. Codename history: "Lantern Line" rejected, "Wayside" is current placeholder. |
| Launch city — Tokyo (default) vs. alternative | Product | Default proposed: Tokyo Yamanote inner. Alternatives: Kyoto, NYC, London, Lisbon, Edinburgh, the user's home city. |
| Mochi's species — fox / cat / tanuki — and visual character | Product / Art | Each has different cultural register. Tanuki is most distinctive; cat is most universal; fox is most "spirit-of-place." Decision deferred to art direction. |
| Mochi's literary persona profile (which authors anchor the voice) | Product / Editorial | Candidates: Murakami, Calvino, Yoko Ogawa, Banana Yoshimoto, Olivia Laing, Rebecca Solnit. Probably a blend. Decision deferred to a Mochi persona doc. |
| Walk-chapter generation: on-device vs. cloud | Architecture | Trade-off: privacy (on-device) vs. quality (cloud). Decision deferred to implementation ADR after on-device model evaluation. |
| Mapbox vs. MapLibre for v1 | Architecture | Default proposed: Mapbox for v1, MapLibre as the migration path. |
| POD provider final choice | Operations | Default proposed: Lulu Direct API for v1.5; Mixam evaluated for premium Atlas tier. |
| Subscription billing — App Store IAP vs. Stripe via web | Architecture / Operations | App Store IAP is required for in-app subscriptions (Apple's rule); Stripe via a web-flow is permitted for purchases initiated outside the app. Likely answer: IAP for primary, Stripe for Atlas (which is a physical product, exempt from IAP). |
| Whether to formalize Apps as a sector/sub-sector or keep consumer apps in Market | Architecture | Default proposed: decide when the standup ADR is opened, not in this PDR. |
| How aggressive the moderation classifier should be (false positive tolerance) | Product / Trust & Safety | Default proposed: erring on conservative — false positives surface "please revise" UX, false negatives go to manual review. Tuning is a launch-time process. |
| Manual-review tool surface (HoneyHub view vs. standalone admin app) | Architecture | Default proposed: HoneyHub view for v1 (HoneyHub is the studio's internal control plane; surfacing the moderation queue there is consistent). Standalone admin app is a v2 concern. |
| Whether anonymous notes carry any device-side signing for verifying authenticity (or are purely server-trusted) | Architecture | Default proposed: server-trusted with rate-limited per-pseudonym. Cryptographic signing is overkill for v1. |
| Lantern+ Sync backend — encrypted blob storage vs. structured database | Architecture | Default proposed: encrypted blob storage of a per-user encrypted bundle. Server cannot read user walk data. Settled in implementation ADR. |
| Whether the Atlas includes the public-layer notes the user echoed during the year | Product | Open. Including them deepens the artifact ("the year of strangers' attention"); excluding them keeps the Atlas private. Strong opinion: include with attribution-anonymous, only notes the user echoed (not all notes the user passed). |
| What happens if a user moves cities mid-year (Atlas spans cities) | Product | Open. Default proposed: Atlas spans all cities the user walked in; map rendering switches per chapter. |
| Compliance posture for the public layer in the EU (GDPR), California (CCPA), Japan (APPI) | Legal | Open. The launch-city choice intersects this. Tokyo launch means APPI is the primary regime; EU expansion requires GDPR review. |
| iOS App Review pre-submission consultation | Operations | Open whether worth pursuing; novel product shape may warrant. |
| Curiosities launch district inside the launch city | Product | The launch *city* decision (Tokyo Yamanote inner is the proposed default) is a v1 question. The launch *district for Curiosities* is a separate v1.5 decision — a single walkable neighborhood inside the launch city where the 50–100 curated POIs are seeded. Default proposed: pick the densest aesthetic-and-history district inside the launch city when the v1.5 packet opens. |
| Curiosities unlock verification — GPS radius vs. plaque/QR vs. photo proof vs. manual unlock | Architecture | Default proposed: GPS radius for v1.5 (consistent with Wayside's existing location stack). Plaque/QR and photo-proof are post-v1.5 enhancements if the simple radius unlock proves too easy or too easy-to-spoof. |
| Whether a user can suggest a Curiosities POI (gated curation) | Product | Default proposed: not in v1.5. Curated-only at launch; user-suggested POIs are post-v1.5 if and only if the moderation pipeline (§C) can credibly extend to physical-place curation, which is a different risk surface than text/photo notes. |
| Whether Curiosities collectibles render in the year-end Atlas | Product | Default proposed: yes, as an optional "Curiosities of the year" chapter at v1.5+; the user opts in to including it. |
| Whether Curiosities is free or a Lantern+ feature | Product / Pricing | Default proposed: free at v1.5 launch (per §P.7), to maximize the test of the loop. Lantern+ gating of premium Curiosities styling and multi-district unlocks is a v2 candidate after the §O.4 floor is cleared. |

---

## Recommended Follow-Up Artifacts

| Artifact | Type | Purpose |
|---|---|---|
| `HoneyDrunk.Wayside` Node standup ADR | ADR | Stands up the new Node per the standup-ADR convention. Names package families, downstream coupling rule, contract-shape canary, dependency surface. Uses Market unless a taxonomy ADR formalizes Apps first. |
| Consumer-app taxonomy | Constitution amendment | Decides whether consumer-facing products stay in Market or move to a dedicated Apps sector/sub-sector. |
| Mochi persona and prompt design doc | Design doc | Locks the literary persona, the prompt shape, the output filter, and the filler-line catalog. The most critical product surface; deserves its own document. |
| Public-layer moderation pipeline ADR | ADR | Architects the six-layer moderation stack (PII filter, content classifier, vision moderation, echo signal, 30-day decay, report flow). Defines the manual-review surface and the abuse-detection thresholds. |
| Watercolor tile pipeline design doc | Design doc | The illustrator-facing tooling (tile rendering, palette specs, style versioning) and the runtime tile-serving plumbing. |
| Spatial index ADR | ADR | Defines `IPlaceNoteIndex`, the H3/geohash choice, the radius-query semantics, and the rate-limit primitives at the index layer. |
| Device-pseudonym auth pattern ADR | ADR | New auth shape — a stable per-device identity that is not user-facing. Lives in HoneyDrunk.Auth alongside JWT and (post-Notify-Cloud) API key paths. |
| On-device LLM choice ADR | ADR | Apple Intelligence on iOS, MLC LLM on Android. Persona discipline validation. |
| Atlas print-on-demand integration ADR | ADR | Lulu Direct API adapter, fulfillment flow, refund/replacement policy, year-end seasonality handling. |
| Wayside marketing site and brand-decision packet | Design doc | The brand name, the marketing site copy, the App Store listing, the launch-city decision. Hard prerequisite to any public-facing work. |
| Wayside privacy posture and disclosure document | Design doc | The honest posture on what data leaves the device, when, and why. The basis for App Store privacy disclosures, the marketing site privacy page, and the in-app first-run disclosure flow. |
| Cold-start seed-content playbook | Design doc | The launch-city seed strategy: how Mochi-authored tutorial notes are generated, how the seed creators are recruited and credited, how the time-bounded paused-decay rule is implemented. |
| Wayside retrospective PDR (conditional) | PDR | If Wayside is killed at the 12-month bar, the retrospective documents what the wedge missed. |
| Curiosities content safety policy | Design doc | Rules for allowed/disallowed Curiosities POIs and quest prompts. Mirrors the public-layer moderation policy but applied to curated, pre-publication content. Covers the §P.4 cut list (no nighttime prompts, no private property, no stranger interaction) operationally. |
| Curiosities content pipeline design doc | Design doc | The ingestion-and-enrichment flow for the launch district: open data sources (OpenStreetMap, Wikidata, Wikipedia, public art registries, historical markers), AI-assisted summarization, the human-approval surface, the template binding. |
| Curiosities map-layer ADR | ADR | Defines the question-mark layer's rendering on top of the existing watercolor base, the visual separation from the public-notes layer (§P.7), the unlock-interaction state machine, and the collectible-book surface inside the atlas. |
| Curiosities unlock-card prose prompt addendum | Design doc | An addendum to the Mochi persona doc covering the unlock-card prose pattern. Reinforces the persona constraints (§D) and forbids game-narrator/tour-guide register patterns. |

---

## Next steps

Concrete decisions the user needs to settle before any code work on Wayside begins:

1. **Calendar position.** Confirm Wayside is *deferred* — the next consumer-app build is Hearth (per the 2026-05-05 brainstorm scout). Wayside's build packet is opened only after Hearth produces a known outcome (ship + early-traction or kill).
2. **Final product name.** Replace "Wayside." Codename history excludes "Lantern Line." Brand decision is a prerequisite to the marketing site, App Store listing, and any user-facing work.
3. **Launch city.** Tokyo Yamanote inner is proposed; alternatives are Kyoto, NYC, London, Lisbon, Edinburgh, the user's home city. The launch city shapes the illustrator commission, the seed-creator recruitment, and the marketing channels.
4. **Mochi species and persona profile.** Fox / cat / tanuki, and the literary register (Murakami / Calvino / Ogawa / blend). The persona profile is the longest-lead-time creative work in the build.
5. **Illustrator commission.** Wayside's watercolor identity requires a real illustrator. Identifying and contracting one is the longest-lead-time engineering-adjacent dependency.
6. **MVP scope confirmation.** Confirm the dual-thesis v1 (private + public + Mochi) is the scope. Fallback to private-only-v1 is the documented contingency, not the plan.
7. **Consumer-app taxonomy formalization.** When the build packet opens, Architecture decides whether Wayside remains in Market or whether an Apps sector/sub-sector is added to `constitution/sectors.md` as part of the Node standup ADR.
8. **Privacy posture sign-off.** The "what data leaves the device" matrix in §F is committed before any production launch.
9. **Public-layer moderation review.** The six-layer moderation strategy (§C) is reviewed and signed off before any non-internal user can publish a note.
10. **Kill-criteria acknowledgment.** The 12-month thresholds (500 Lantern+ subscribers, 2,000 Atlases, moderation cost vs. revenue) are accepted as the kill bar.

Once the user is ready to build Wayside, the build packet should reference this PDR, open the standup ADR for `HoneyDrunk.Wayside`, and proceed through Phase 0 of the rollout.
