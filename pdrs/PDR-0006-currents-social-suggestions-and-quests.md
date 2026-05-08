# PDR-0006: Currents — Social Suggestions and Lightweight Quests

**Status:** Proposed
**Date:** 2026-05-06
**Deciders:** HoneyDrunk Studios
**Sector:** Apps (consumer) · AI · Social
**Codename:** Currents (final product name TBD)

---

## Context

The studio wants consumer apps for regular people that are cool to build without becoming enormous, infrastructure-heavy bets. Hearth is the larger emotional product. Notify Cloud is the developer-tools revenue wedge. Currents is the smaller consumer-social product: an app for discovering what to read, watch, listen to, play, visit, cook, or try next — based on what people are actually into right now.

The original Lately concept used "currents" as the matching primitive for a connection app: current book, show/movie, album, and optional place. That primitive is stronger than the dating/friendship framing around it. The broader opportunity is a social discovery app where currents become taste signals, suggestions, and lightweight quests.

Most recommendation products are either algorithmic feeds or static lists:

- TikTok/Instagram/YouTube push algorithmic content, not intentional shared experience.
- Goodreads/Letterboxd/Backloggd track media, but do not create cross-domain "what should I try this week?" momentum.
- Pinterest and Notion boards collect ideas, but do not make them social or time-bound.
- Meetup/Eventbrite are too heavy for small cultural prompts.
- Dating/friend apps use interests as profile decoration, not as an engine for action.

Currents' thesis: **people do not only want recommendations; they want small reasons to do things and small ways to share that they did them.**

---

## Problem Statement

### 1. Taste is fragmented across apps

A person's real current taste is spread across Letterboxd, Goodreads, Spotify, TikTok saves, Notes, group chats, screenshots, and memory. There is no single lightweight surface for "here is what I am into this week, and here is what I might try next."

### 2. Recommendations are too passive

Recommendation feeds are endless and low-commitment. Users save things and never return. Currents needs to turn suggestions into tiny action loops: "watch one pilot episode," "listen to this album while walking," "make this recipe this weekend," "go to a bookstore and pick one translated novel."

### 3. Social apps over-index on performance

Most social products make the user perform a stable identity. Currents should be lighter: "this caught my attention lately," "I tried this," "I passed this to two friends." The tone is closer to friends trading recs than building a public persona.

### 4. Quests are useful but can become cringe quickly

The word "quest" is dangerous. If Currents becomes XP, badges, streaks, or fake RPG language, it falls into the same saturated self-improvement/gamification trap Hearth is avoiding. The quest mechanic must feel like a cultural prompt, not homework.

### 5. The product must be smaller than Hearth

Currents should not require a complex art pipeline, location tracking, marketplace liquidity, or high-risk UGC moderation at v1. It should be ship-able as a lean mobile/web app with profiles, suggestions, small groups, and shareable prompts.

---

## Decision

### A. Currents is a standalone consumer app, not only a Lately feature

Currents becomes its own proposed product direction. Lately can still exist as a future connection/dating/friendship surface, but Currents is broader and cleaner: social discovery + suggestions + lightweight quests around what regular people are currently consuming or trying.

Currents is not marketed as a HoneyDrunk Grid product. It is a consumer brand under HoneyDrunk Studios.

### B. The core object is a Current

A **Current** is something actively present in the user's life right now.

Examples:

- A book they are reading.
- A show/movie they are watching.
- An album/song they have on repeat.
- A game they are playing.
- A place they keep returning to.
- A recipe they want to try.
- A topic they are learning.
- A small creative project they are making.
- A mood/aesthetic they are exploring.

A Current is not a permanent favorite. It expires or asks for refresh after 30 days. This keeps the graph alive and avoids static-profile rot.

### C. Suggestions turn Currents into next actions

Currents generates suggestions from the user's active Currents and social graph.

Suggestion types:

- **Adjacent media:** "You are reading *Pachinko*; try this essay/interview/movie next."
- **Cross-medium bridges:** "You liked this album; here is a film with the same emotional weather."
- **Place/action prompts:** "Take this album on a 30-minute walk." / "Find a cafe and read one chapter."
- **Friend-sourced recs:** "Maya thinks you would like this because you both fingerprinted *The Bear*."
- **Group prompts:** "Three friends are watching the pilot this week. Join?"

The bar: suggestions must be small enough to do this week. Currents is not a backlog app.

### D. Quests are cultural prompts, not gamification

Currents may use the word **Quest** internally, but the customer-facing language should probably be **Prompt**, **Try**, **Thread**, or **Run** unless testing proves "quest" lands.

Quest examples:

- **One-Sitting Album:** listen to one album start-to-finish without shuffle.
- **Pilot Night:** watch the first episode of a show with 2–6 friends async/sync.
- **Bookstore Pull:** go to a bookstore/library and pick one book by spine/title alone.
- **Neighborhood Scene:** visit one local place and save a one-line note.
- **Three-Thing Thread:** book + album + movie around one mood.
- **Cook the Reference:** cook a dish that appeared in something you watched/read.
- **Friend Pass:** send one Current to someone with a one-line reason.

No XP. No streaks. No ranks. No guilt copy. Completion unlocks social texture, not power.

### E. Social is small-group first

Currents should not begin as a public feed. The first social shape is small groups and friend circles.

V1 social primitives:

- Follow/friend by invite code or contact link.
- Share a Current with one person or a small circle.
- React with one lightweight signal: **fingerprint** / **try** / **pass**.
- Create a group prompt with 2–8 people.
- See "what my people are into lately" without algorithmic infinite scroll.

Public discovery can come later. V1 should feel like a better group chat for taste, not another social network demanding performance.

### F. AI assists suggestions but does not impersonate taste

AI may generate candidate suggestions, explain why an item connects to another, and create small prompt bundles. But the product should clearly separate:

- Friend-sourced recommendations.
- Editorial/studio-curated recommendations.
- AI-assisted recommendations.

The user should never feel tricked into thinking a model recommendation came from a friend.

### G. MVP scope — what ships in v1

**In v1:**

- Mobile-first web app or iOS-first app (decision open; web may be faster for sharing).
- User profile with 3–7 active Currents.
- Current categories: book, show/movie, album/song, game, place, recipe, topic, project.
- 30-day refresh mechanic for active Currents.
- Manual add + simple external lookup where feasible (OpenLibrary, TMDB, Spotify/Apple Music link paste, IG/TikTok link paste as plain URL).
- Suggestions generated from active Currents.
- Small-group prompts for 2–8 people.
- Friend/circle sharing via invite link.
- Fingerprint / try / pass interactions.
- No public global feed.
- No dating/friend matching at v1.
- No location tracking.
- No algorithmic infinite scroll.

**Explicitly cut from v1:**

- Dating/friendship matching.
- Public Rooms.
- Passive media integrations.
- Location-based recommendations beyond manual place entry.
- Creator monetization.
- Complex reputation/XP systems.
- Full AI taste profile memory.

---

## Options Evaluated

### Option 1: Keep Currents inside Lately only

**Pros:**
- Preserves the original connection-app framing.
- Avoids another PDR/product surface.

**Cons:**
- Dating/friendship introduces cold-start, trust, and safety complexity.
- The Current primitive is broader and more useful than matching.
- The operator is looking for consumer app ideas that are cool but not enormous; dating/social matching is enormous.

**Verdict:** Rejected. Currents deserves a simpler standalone surface first.

### Option 2: Build Currents as a recommendation-only app

**Pros:**
- Smaller scope.
- No social graph required at v1.

**Cons:**
- Recommendation-only products become backlogs.
- The magic is people passing taste around, not model-generated lists.
- Harder to create retention without social loops.

**Verdict:** Rejected. Social is needed, but it must be small-group social.

### Option 3: Build Currents as small-group social discovery with lightweight quests *(Selected)*

**Pros:**
- Smaller than Hearth, safer than Lately-as-dating.
- Strong everyday use case: "what are my people into, and what should I try next?"
- Quests/prompts create action without heavy gamification.
- Good build-in-public content surface.

**Cons:**
- Still has some social cold-start risk.
- Recommendation quality has to be good quickly.
- The concept can drift into either Notion-backlog or TikTok-feed if not tightly scoped.

**Verdict:** Selected. This is the cleanest Currents shape.

### Option 4: Build Currents as a public taste network

**Pros:**
- Bigger upside if it works.
- Public discovery can grow organically.

**Cons:**
- Much higher moderation and spam risk.
- Public feeds create performance pressure.
- Harder to keep the cozy/direct friend-recommendation feel.

**Verdict:** Parked for v2+. Do not start here.

---

## Trade-offs

| Trade-off | Favored Position | Rationale |
|---|---|---|
| Small groups vs. public feed | **Small groups first** | Lower moderation risk and stronger trust. |
| Quests/prompts vs. passive recommendations | **Prompts** | Suggestions should produce action, not infinite saving. |
| AI suggestions vs. friend/editorial suggestions | **Hybrid with clear labeling** | AI helps breadth; friends/editorial preserve trust. |
| Web-first vs. iOS-first | **Open question** | Web is better for sharing; iOS is better for consumer polish. |
| Dating/friend matching vs. discovery | **Discovery first** | Matching makes the app much bigger and riskier. |
| Gamification vs. texture | **Texture** | No XP/streaks/ranks. Completion should create social texture, not status grind. |

---

## Architecture Implications

### New Node candidates

| Node | Sector | Purpose |
|---|---|---|
| **HoneyDrunk.Currents** | Apps | Consumer app surface for active currents, suggestions, prompts, and social circles. |
| **HoneyDrunk.Currents.Backend** | Apps | API/runtime for accounts, currents, circles, suggestions, prompts, and notifications. |
| **HoneyDrunk.Currents.Recs** | Apps / AI | Recommendation and prompt-generation service. May start inside Backend and split later. |

### Dependencies on existing Grid Nodes

- **Auth** — user accounts, invite links, JWT validation.
- **Vault** — provider API keys, encryption keys, third-party tokens if integrations are added.
- **Notify / Communications** — invite links, prompt reminders, optional group notifications; no spammy nudges.
- **HoneyDrunk.AI / IModelRouter** — AI-assisted suggestion generation and explanation.
- **Pulse** — content-free telemetry: current added, prompt joined, suggestion accepted/rejected.
- **Web.Rest / Kernel** — standard API envelope, context, lifecycle, telemetry.

### Boundary stance

Currents does not require new Core contracts at v1. It is an Apps-sector product consuming existing Grid primitives. Recommendation logic starts product-specific and should not be extracted into a generic Knowledge/AI Node until another product needs the same abstraction.

---

## Product Implications

### Buyer / user

Consumer users 18–40 who already trade recommendations with friends, maintain watch/read/listen lists, join small group chats, or enjoy cultural prompts but dislike public social performance.

Concrete initial user:

> A person with 3–8 close friends who are always saying "we should watch/read/listen to this" but whose recs disappear into group chat history.

### Pricing

V1 should probably be free while validating loops. Paid tier only after retention is proven.

Possible paid shape:

- **Currents Free:** active currents, small circles, limited prompt history.
- **Currents Plus ($3.99/mo or $29/yr):** unlimited circles, archived prompts, richer suggestion bundles, shared seasonal lists, export.
- **Group Pack:** one payer unlocks Plus features for a circle of up to 8.

Do not monetize with ads. Ads would corrupt the recommendation trust surface.

### Success metrics

- 40%+ of activated users add 3+ Currents in first week.
- 25%+ join or create a small circle in first week.
- 20%+ accept at least one suggestion/prompt in first two weeks.
- 15%+ weekly active after 30 days in a 100–500 user TestFlight/beta.
- Users voluntarily share prompts outside the app.

---

## What Does NOT Change

- Notify Cloud remains the first developer-tools commercial wedge.
- Hearth remains the stronger emotional/consumer wedge if the studio wants a larger flagship consumer app.
- Lately remains a possible future connection app, but Currents no longer depends on dating/friendship matching.
- No public feed, ads, or influencer economy at v1.

---

## Risks

| Risk | Severity | Why it matters |
|---|---|---|
| Recommendation quality is mediocre | High | Bad suggestions make the app feel generic immediately. |
| Social cold start | Medium | Without friends/circles, the product may feel empty. |
| Quest language feels cringe | Medium | The mechanic must feel culturally cool, not like fake productivity. |
| Scope creep into dating/social network | High | That turns a small app into a large trust/safety product. |
| Rights/API friction | Medium | Media providers have uneven APIs; link-paste fallback is needed. |

---

## Mitigations

- Start with manual entry + link paste; do not block on perfect integrations.
- Make onboarding invite-first: "start with 3 friends" rather than empty solo account.
- Use editorial seed packs for early suggestions so AI is not carrying quality alone.
- Avoid public feed until moderation, spam controls, and identity posture are designed.
- Test customer-facing words: Quest vs Prompt vs Try vs Run vs Thread.

---

## Consequences

### Short-term

Currents gives the studio a smaller consumer prototype candidate than Hearth. It can be built as a lean app to test whether people want social suggestions and small cultural prompts.

### Long-term

If Currents works, it can become the social/taste graph that later products reuse:

- Hearth can read Currents manually/imported as "media/currents" if the user opts in.
- Lately can reuse Currents for matching later.
- Wayside can reuse place prompts.
- Lore/Knowledge can provide richer recommendation context behind the scenes.

If Currents fails, the cost is bounded: it can be wound down without complex artifacts, location data, or high-risk personal journal data.

---

## Rollout

### Phase 0: Naming and mechanic test

- Decide whether customer-facing language is Currents, Prompts, Quests, Threads, or Runs.
- Create 20–30 sample prompt cards.
- Test manually with Oleg/friends/group chat before building.

### Phase 1: Prototype

- Build mobile-first web prototype.
- Manual current entry.
- Small circles.
- Prompt creation and acceptance.
- Basic suggestion generation from seed packs + AI assist.

### Phase 2: Private beta

- 50–100 users, invite-only.
- Measure active currents, prompts accepted, circles formed, week-4 retention.
- Cut or rewrite any mechanic that feels like homework.

### Phase 3: Public v1

- iOS app or polished PWA depending on Phase 1 signal.
- Add provider lookup integrations where they reduce friction.
- Launch with editorial seasonal prompt packs.

---

## Open Questions

| Question | Owner | Default |
|---|---|---|
| Customer-facing term: Quest, Prompt, Try, Run, Thread? | Product | Avoid "Quest" publicly unless users love it. |
| Web-first or iOS-first? | Product / Engineering | Web-first prototype; iOS if retention validates. |
| Is Currents separate from Lately permanently? | Product | Yes for v1; Lately can reuse the graph later. |
| Should places be manual only at v1? | Product / Privacy | Yes. No passive location tracking. |
| How much AI is visible? | Product / AI | Label AI-assisted suggestions clearly. |

---

## Recommended Follow-Up Artifacts

| Artifact | Type | Purpose |
|---|---|---|
| Currents naming/mechanics note | Product note | Decide Quest/Prompt/Try language and tone. |
| Currents prototype scope packet | Scope packet | Define the smallest buildable prototype. |
| Currents recommendation policy ADR | ADR | If built, define AI recommendation labeling, retention, and safety boundaries. |
| Currents privacy posture note | Product/security note | Define what social/taste data is stored and how deletion/export works. |

---

## Next steps

1. Decide whether Currents is a near-term prototype candidate or a parked PDR behind Hearth/Notify Cloud.
2. Test 20–30 prompt examples in plain text before building UI.
3. If the mechanic feels alive, scope a tiny web prototype instead of a full mobile app.
