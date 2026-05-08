# PDR-0003: Lately — A Currents-Based Connection App for Regular Humans

**Status:** Proposed
**Date:** 2026-05-05
**Deciders:** HoneyDrunk Studios
**Sector:** Market / Core / Ops
**Codename:** **Lately** — final consumer product name is TBD. The codename is used throughout this PDR; do not interpret "Lately" as the launch brand.

---

## Context

PDR-0002 named HoneyDrunk Notify as the Grid's first commercial product — a B2B developer tool sold to indie .NET devs at $19/mo. That decision stands. This PDR opens a **second, independent product line** aimed at a fundamentally different audience: regular humans, not developers. Different buyer, different brand surface, different revenue mechanic, different success criteria.

The motivation is not commercial portfolio optimization. The user is a solo dev building for the love of building. Lately exists because the connection-app category is broken in a specific, well-understood way — and the wedge to fix it is mechanical, not aesthetic.

Two strategic realities frame this decision:

### The connection-app category is structurally exhausted

Every major dating and friendship app since 2014 has been a re-skin of Tinder's swipe loop. Hinge added prompts. Bumble added "women message first." Coffee Meets Bagel added curation. The Sauce added video. None of them touched the underlying mechanic: **judge a stranger from a static profile, swipe yes/no, hope a fragment of their identity matches yours**.

The static profile is the bug. Profiles built on all-time top 5 lists ("favorite movies of all time," "books that shaped me") are aspirational, low-information, and perpetually outdated. Two people who both list *Infinite Jest* as a favorite have nothing to talk about — they read it eight years apart, in different contexts, and the listing is identity signaling, not a current shared experience.

What works on Letterboxd and BookTok is the opposite: **people show what they are actually engaging with right now**. The signal is recency. It is conversational. It produces "did you finish it yet?" — the question that does not exist in dating-app discourse.

No one has built a connection app on this mechanic. Letterboxd and Goodreads have tribal social layers, but they are platform-locked (you need to know someone's username) and not designed for meeting strangers. BookTok and FilmTok produce parasocial recommendation flows, not dyadic connection. Hinge and Bumble produce dyadic flows, but their profile primitive does not surface recency.

The unmet need: **a connection surface where the conversational opener is built-in because both people are currently engaged with the same thing**.

### Dating apps churn because they are extractive, not generative

The standard dating-app loop:
1. User signs up.
2. User swipes for a week. Matches a few people.
3. Conversations stall after three messages.
4. User deletes the app.
5. App re-prompts via push, email, paid boost.

The retention crisis is real and well-documented (Pew 2024, Tinder Q3 2025 earnings). The category's response has been to introduce predatory monetization — swipe limits, pay-to-see-likes, pay-to-boost. This makes the experience worse, not better, and accelerates churn for users who feel manipulated.

The retention mechanic Lately bets on is structural, not behavioral: **a nightly synchronous moment (The Room) where people who are currently consuming the same things are surfaced together, not as matches but as co-readers / co-viewers / co-listeners**. It is a reason to open the app at 8pm that does not depend on dopamine intermittent reinforcement.

This is the core thesis. If it is wrong, the product fails regardless of how well it is built.

---

## What It Does

In plain language: **Lately is a connection app where your profile is what you are reading, watching, and listening to right now — not a list of all-time favorites. Every night at 8pm, The Room opens: 6–8 people currently engaged with the same thing as you, sharing one-line liner notes about what they're consuming.**

You sign up with photos (3–5, prominent), and you fill in:
- 1 book you are currently reading
- 1 show or movie you are currently watching
- 1 album you are currently listening to
- (Optional) 1 recent place — café, bookstore, neighborhood

Every 30 days, you must update at least one of those entries. If you do not, your profile is hidden. This is not a punishment — it is a filter. Lately is for people who are currently consuming things, not people who set up a profile and forgot.

You can browse profiles in friendship mode, dating mode, or both. The card shows photos prominently at the top. The currents shelf sits below — the four items, with a single tap-to-underline gesture called a **fingerprint**. If two people fingerprint each other on multiple items, that becomes a "warm context" surface ("you both fingerprinted each other on three different things — *The Bear*, *Pachinko*, and *Brat*").

Every night at 8pm local, **The Room** opens. For each item on your currents shelf, Lately surfaces 6–8 strangers currently engaged with the same thing. Members leave one-line liner notes — "halfway through, the prison chapter wrecked me," "rewatched the kitchen fight three times," "this album is my whole September." That is the surface where conversations begin. The Room is open for 90 minutes. It closes at 9:30pm.

How it sits next to the field:

- **Hinge / Bumble / Tinder** — swipe-based, all-time profile primitives, dating-only, retention-extractive monetization.
- **Letterboxd / Goodreads** — recency-based recommendation surfaces, but platform-locked and not designed for stranger connection.
- **BookTok / FilmTok** — parasocial recommendation, no dyadic connection.
- **Lately** — recency-first profile, friendship-and-dating modes, synchronous nightly surface, non-extractive pricing, optional fingerprint mechanic for warm-context matching.

---

## Problem Statement

### 1. Static profiles produce stalled conversations

All-time favorites are identity signaling, not conversational starters. Two strangers matching on *Infinite Jest* as an all-time favorite have nothing to actually say to each other. Two strangers both currently reading *Pachinko* have an immediate, time-bound, specific topic. The conversational opener is the product. Static profiles do not produce conversational openers; current consumption does.

### 2. Dating-app retention is a structural problem, not a feature problem

Adding more prompts, more video, more AI matchmaking does not fix the underlying loop. Users match, leave the app, and never return because there is no reason to come back besides more swiping. **The Room is the structural fix**: a nightly, synchronous, 90-minute window that is interesting to open even when you have no active matches.

### 3. Friendship apps are an underserved category

The user-facing market splits artificially between dating (Hinge, Bumble) and friendship (Bumble BFF, Meetup, Geneva). Most adults — especially adults who have moved cities, left a relationship, or aged out of college friend groups — want both, sometimes simultaneously. The friendship category is bigger, less saturated, and lower-stakes than dating. **Lately is friendship-first with optional dating mode**, not the other way around. This lowers the bar to signup and reduces the "is this person here for sex" anxiety that dating-app onboarding induces.

### 4. The fingerprint mechanic solves the swipe-fatigue problem

Swipe-yes / swipe-no is binary, fast, and shallow. The fingerprint is a single-tap micro-gesture on a specific item ("I underlined that you're reading *Pachinko*"). It is a smaller commitment than a like, more specific than a swipe, and produces measurable signal. Mutual fingerprints across multiple items are a quantifiable warm-context match — concretely better than "you both swiped right."

### 5. The category needs a product that is not predatory

Tier-stacking, swipe limits, pay-to-see-likes — these monetization patterns exist because dating apps have nothing else to charge for. Lately's free tier has all core features, no swipe limits, no artificial scarcity. The paid tier (Hardcover, $8.99/mo) buys time-shifted features (rewinds, see-who-fingerprinted-you, advanced filters) — not access to core functionality. **This is a product positioning bet**: that an honest pricing model wins among the audience that has been burned by Tinder Gold and Hinge Premium.

---

## Decision

### A. Lately is a separate product line from Notify Cloud

Lately is HoneyDrunk Studios' second commercial product, parallel to Notify Cloud (PDR-0002), not subordinate to it. Different audience, different brand, different go-to-market, different revenue model.

| Dimension | Notify Cloud | Lately |
|---|---|---|
| Buyer | Indie .NET dev | Regular human, 25–40, urban or suburban |
| Channel | Open-source distribution + dev-community marketing | App store + word of mouth + community partnerships |
| Pricing | $19/mo SaaS, B2B | Free + $8.99/mo, B2C |
| Brand surface | `notify.honeydrunkstudios.com` (studio brand) | Separate consumer brand (TBD), not housed under HoneyDrunk Studios in customer surfaces |
| Architecture | Backend service on the Grid | Mobile app + thin backend reusing Grid Nodes |
| Success metric | Paying customers (10 in 90 days) | Daily active users, weekly active users, fingerprint mutuality rate, paid conversion |
| Risk shape | Multi-tenant complexity, dev community CAC | Cold-start liquidity, T&S exposure, app-store dynamics |

**Brand separation is deliberate.** The HoneyDrunk Studios brand is build-in-public, dev-shaped, architecture-forward. None of that translates to a consumer connection app. Regular humans do not care about the Grid, about Nodes, or about open-core software. The Lately brand exists in a different cultural register — warm, literary-aesthetic, evening-not-morning, anime-cozy-adjacent without being kitschy.

The internal architecture lives on the Grid; the customer never sees that. No "Powered by HoneyDrunk Grid" footer. No PDR or ADR links from the marketing site. Lately is a standalone product with its own brand surface; HoneyDrunk Studios is the parent company that ships it.

### B. The currents-based matching thesis

The wedge is mechanical, not aesthetic. **The profile primitive itself is different**.

| Field | Lately | Hinge / Bumble | Letterboxd / Goodreads |
|---|---|---|---|
| Photos | 3–5, top of card | 6, primary surface | None |
| All-time favorites | None | "Six prompts" + sometimes top movies | All-time list available |
| Currently consuming | **Required, prominent, 30-day refresh** | Not surfaced | Implicit via recent activity |
| Conversation starter built in | Yes — "are you halfway through?" | No — prompts are static | Yes — but not designed for strangers |
| Retention mechanic | The Room (8pm nightly synchronous) | Push, email, paid boosts | Recommendation feed |

The currents shelf has hard structural rules:

- **Exactly four slots** at v1: 1 book, 1 show/movie, 1 album, 1 optional recent place. No more, no less. Constraint is a feature — it forces honest curation and makes The Room's overlap algorithm tractable.
- **30-day refresh requirement.** If no item has been updated in 30 days, the profile is hidden from discovery and from The Room. Profile owner sees a soft prompt every 7 days starting at day 23. This is the dead-profile filter and the active-consumption filter, in one mechanic.
- **Items are linked to canonical IDs**, not free-text. Books resolve to ISBNs (Open Library / Hardcover API). Films/shows resolve to TMDB IDs. Albums resolve to MusicBrainz / Spotify IDs. Free-text is the death of overlap-matching; canonical IDs make The Room's "who else is reading this" query a join, not a fuzzy-match.
- **Photos remain prominent.** This is not a profile-photos-de-prioritized app. The card surface puts photos at the top because attraction (in friendship and dating contexts both) is partially visual, and pretending otherwise produces a product that doesn't match human behavior. The currents shelf sits **below** photos — distinct, structured, prominent, but second.

### C. The Room as the retention mechanic

The Room is the bet. **It is the reason to open the app on a Tuesday at 8pm when no match has messaged you**.

**Mechanics:**

- Opens at 8pm local, closes at 9:30pm. 90-minute window. Asynchronous within the window — you can drop in and out.
- For each item on your currents shelf, you see a Room of 6–8 strangers currently consuming the same item. If you have 4 items, that's up to 4 Rooms a night. Some Rooms may be empty (cold-start risk — see §E); some may have more than 8 (algorithm picks the best 8 by recency-of-update + tier proximity).
- **Liner notes** are the surface — single-line text fragments (140 chars), tied to the item. "Halfway through, the prison chapter wrecked me." "This rewatch hits different post-divorce." "Side B is louder than Side A and I love it."
- **Fingerprints in The Room** are first-class. You can fingerprint someone's note (the gesture flows through to their profile, where it accumulates). You can also fingerprint someone's profile from inside The Room.
- **No DMs from inside The Room.** Connection happens after — if mutual fingerprints accumulate, the warm-context surface is generated and a connection prompt appears in both users' main feed the next day. This is intentional — The Room is a public surface, not a back-channel for private cold-DMs.
- **Geographic scope is configurable but defaults to broader-than-city.** The Room is not a "people in your city" feature — it is a "people currently engaged with this thing" feature. Matching the book matters more than matching the zip code. Filters can narrow to a city if the user wants; defaults are regional (state / metro area).

**Why this works as a retention mechanic:**

The category's retention failure is that nothing happens between matches. The app is interesting on signup, boring on day 7. The Room creates a daily, predictable, contextual reason to open — independent of whether you have unread messages. It is closer in shape to **a daily news app or a daily Wordle** than to a swipe-loop app. People open Wordle because something happens at midnight; people will open Lately because something happens at 8pm.

If The Room does not produce ≥3 Lately app-opens per week per active user, the retention thesis is wrong.

### D. The fingerprint as the warm-context matching primitive

The fingerprint replaces the swipe.

- **Single tap-to-underline** on any currents shelf item, on a profile or in The Room.
- **Asymmetric until mutual.** A fingerprint is private — the recipient does not see who fingerprinted them (free tier). Pro tier sees who fingerprinted them.
- **Mutuality is the trigger.** When two users fingerprint each other on the same or different items, a warm-context match surface is generated: "you both fingerprinted each other on *Pachinko*, *The Bear*, and *Slow Horses*." This is the connection prompt.
- **Mutual fingerprints across multiple items are a stronger signal than a single mutual fingerprint.** The surface ranks by depth — three mutual fingerprints produces a stronger warm-context display than one, and the user's main feed sorts by depth.

The fingerprint is a **smaller, more specific commitment than a swipe**. It says "I notice that we are reading the same thing" rather than "I have decided based on your photos whether to allow communication." That specificity is the product — it produces less anxiety on the sender side and more meaningful signal on the receiver side.

Liking the entire profile (Hinge's "send like + comment") still exists, in a reduced form. The fingerprint is the primary gesture; whole-profile-likes are secondary.

### E. Cold-start strategy — three options, recommended position

Lately is a two-sided marketplace. Without enough density in a given city / fandom / item, The Room is empty, fingerprints don't accumulate, and the wedge fails. **This is the single biggest risk.**

Three viable cold-start strategies were evaluated:

#### Strategy 1: One city only, broad fandom

Launch in a single city (e.g., Brooklyn, Austin, or Portland) with no fandom restriction. Recruit 2,000+ users in that city before opening to a second city. The Room is geographically tight; overlap density is high because everyone is local; word of mouth is the primary growth channel.

**Pros:** Tight feedback loop. Local word of mouth is high-conversion. The Room reliably has ≥3–4 strangers per item once density hits ~2,000 users in a metro.

**Cons:** Slow geographic expansion. Press cycles are city-specific. The user is not in any of these cities (the user is solo, location-flexible, and may not have geographic affinity to any of them) — recruiting 2,000 users in a city you don't live in is hard.

#### Strategy 2: One fandom only, geographically broad

Launch tied to a single existing community — e.g., Letterboxd-adjacent film viewers, BookTok readers, a specific anime / manga subreddit, an indie music newsletter audience. No geographic restriction; the audience is national. Partner with one or two community influencers / newsletter-writers for distribution.

**Pros:** Geographic breadth. Self-selecting users who already care about currents (people who post on Letterboxd by definition update their currents). Distribution channel is concrete.

**Cons:** Community partnerships are work the user has not validated. Risk of the app being seen as "Letterboxd's flirty cousin" — a positioning trap. The Room's overlap is more on items than on geography, which could feel less local-warm.

#### Strategy 3: Friendship-only beta, broad audience

Launch as friendship-only (no dating mode at all) for the first 90 days. Lower bar to signup ("it's not a dating app"). Recruit broadly — Reddit, Twitter, college networks, alumni groups, professional friendship-seekers (people who moved cities). Add dating mode at 90 days once density and trust are established.

**Pros:** Lower CAC because friendship apps face less stigma than dating apps. Gets density without the dating-app trust overhead. Dating mode is added later as a "we built the trust first" narrative — itself a marketing wedge.

**Cons:** Many users will sign up wanting both. Restricting to friendship-only at v1 creates "this is missing features" friction. Dating mode at +90 days is a hard launch event that may not get the same press as initial launch.

#### Recommended position: **Strategy 2 (one fandom only) for soft launch + Strategy 3 (friendship-first) for the public framing**

The two are compatible. Soft-launch in a single fandom (recommended: **Letterboxd-adjacent film viewers**, because the recency-of-currents primitive is most natural for film, and the audience is large enough to seed without being too large to manage). Frame the product publicly as friendship-first with optional dating mode toggle. Add geographic breadth gradually. **Strategy 1 is rejected for v1** because the user has no specific city affinity and city-only launches require ground-game effort the user cannot scale.

The kill criterion against cold-start (§K) measures density per item per city per week. If after 90 days the median Room has fewer than 3 strangers, the cold-start strategy did not produce liquidity, and the product is killed regardless of total signups.

### F. Trust & safety — minimum viable bar for a solo dev

A solo dev cannot build a Hinge-grade T&S team. The realistic v1 bar:

**Identity verification — soft, not hard:**
- **No mandatory ID verification at signup.** Adding government-ID verification requires a vendor (Veriff, Persona, Stripe Identity at $1–$3 per check), which is operationally sustainable but adds signup friction that kills early activation.
- **Photo verification is mandatory and automated.** Selfie compared to profile photos using a vendor (AWS Rekognition or a similar face-similarity API). Verified-photo badge appears on the profile. Unverified profiles can still post but are deprioritized in The Room and discovery.
- **Phone number verification at signup** (SMS code, Twilio, reuses Notify infrastructure). Cheap and high-value.

**Age verification:**
- **18+ for friendship mode, 18+ for dating mode.** No 13+ tier — Lately is not a teen product.
- **Self-attestation at signup; spot-checked via ID verification only when the user reports another user's age.** This is the realistic solo-dev bar. Hinge does the same.

**Abuse and harassment:**
- **Block and report on every profile and message.** Standard.
- **Reports route to a queue triaged by AI agent (first pass) + human (second pass within 48h).** AI agent flags severity (spam, harassment, threats, doxxing, illegal content); human reviews high-severity flags and confirms actions.
- **Auto-ban triggers** on threats, doxxing, child-safety content. Standard list, vendor-derivable.
- **Three reports → temporary suspension pending review.** Lower bar than enterprise apps; calibrated for solo capacity.

**Photo content moderation:**
- **AWS Rekognition Content Moderation** (or equivalent) on every uploaded photo. Cost ≈$0.001/image. Auto-rejects nudity, violence, drugs, weapons. Cheap, fast, and well-trodden.

**Data minimization:**
- **No precise geolocation stored on servers.** The Room uses metro-area derived from phone IP at signup and on-demand; not continuous location tracking.
- **No social graph imports.** Lately does not import contacts, Facebook friends, or address books. Builds its own graph.
- **No tracking pixels or third-party analytics that share user data.** First-party analytics only (which the Grid's Pulse Node already provides).
- **GDPR / CCPA compliant data export and deletion** from day one. This is solo-feasible because the data model is small and the architecture is single-region.

**Solo-dev T&S limits — explicit:**
- **No 24/7 incident response.** A reported safety incident may sit in the queue for up to 48 hours. The marketing site says so honestly.
- **No real-time chat moderation.** AI flagging is async; humans review within 48h. High-severity auto-actions (auto-mute, auto-ban) catch the worst before human review.
- **No appeals court, no escalation team, no legal counsel on retainer.** Reports of high-stakes incidents (threats, child safety) escalate immediately to law-enforcement-appropriate channels and the user (founder) is the human-in-the-loop.

This bar is below Hinge's. It is **above** the bar most v1 indie connection apps ship with. The honest framing on the marketing site is the moat — Lately is run by a solo dev who cares about safety more than scale, and is honest about what that means.

### G. MVP scope — ruthless cuts

**In v1:**
- 3–5 photos + 4-slot currents shelf (book, show/movie, album, optional place)
- Friendship + dating mode toggle
- The Room (8pm local, 90-min window)
- Fingerprint gesture (single tap-to-underline)
- Mutual fingerprint warm-context display
- Phone number verification, photo verification, photo content moderation
- Block, report, AI-triaged reports queue
- 30-day currents-refresh requirement
- Free tier (all core features)
- Hardcover paid tier ($8.99/mo): rewinds, see-who-fingerprinted-you, advanced filters
- Item resolution to canonical IDs (Open Library, TMDB, MusicBrainz / Spotify)
- iOS + Android (mobile-first, no web app at v1)
- Single-region backend (US East)
- Single-fandom soft launch (Letterboxd-adjacent), then broadened

**Cut from v1 (deliberate):**
- **No video profile components.** Photos only. Video is heavy, expensive to moderate, and a category-defining signal Lately is not making.
- **No voice notes, no voice intros.** Same reasoning.
- **No in-app messaging at v1 launch beyond the warm-context handshake.** This is the most aggressive cut. Once a mutual fingerprint match is generated, Lately produces a warm-context summary and prompts both users to **move to a third-party platform of their choice (Instagram DM, iMessage, etc.) or use a v1.5 minimal in-app DM**. The in-app DM at v1 is text-only, no media, no voice — sufficient to take a conversation past the match prompt. The reasoning is twofold: (1) full chat infrastructure is heavy and is not the wedge; (2) most dating-app conversations migrate off-platform within 5 messages anyway, and Lately leaning into that is honest and reduces in-app message moderation surface.
- **No groups, no events, no IRL meetup features.** v1 is dyadic only.
- **No public profile feed / explore tab.** Discovery is via The Room and via mutual fingerprints. No infinite scroll.
- **No matchmaking AI / "Lately knows what you'll like" features.** v1 is recency-driven, not preference-learned. Adding AI-driven match scoring is post-launch, validated against real engagement data.
- **No social sharing (post a Lately profile to Instagram, etc.).** Privacy-first.
- **No web version. No tablet version.** Phones only.
- **No multi-language UI.** English-only. International launch is post-MVP.
- **No SOC2, no GDPR DPA-as-a-product.** GDPR-compliant in behavior, not certified.
- **No swipe limits, no pay-to-see-likes, no boosts that hide the algorithm, no premium-tier ranking advantages.** This is non-negotiable. The pricing wedge requires it.

The cuts are aggressive. Each one is the answer to "what is the smallest v1 that has a buyer-shaped surface."

### H. Tech stack — solo dev with AI agents

The user is one person plus AI agents. Tech stack choices must respect that.

**Mobile client:**

Three options evaluated:

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **React Native + TypeScript** | Single codebase, large ecosystem, hot reload, AI-agent friendly, the user has React experience | Native module gotchas, photo handling and Camera APIs require some native code | **Recommended** |
| **Flutter + Dart** | Excellent UI primitives, strong photo handling, single codebase | Dart is a smaller ecosystem; less AI-agent training data; the user has no Dart experience | Rejected for solo-dev velocity |
| **Native (Swift + Kotlin)** | Best performance, best platform integration | Two codebases, two skill sets, double the work | Rejected — solo-dev cannot maintain |

**Recommendation: React Native** with Expo for fast iteration. Native modules only where required (camera, push notifications, deep links).

**Backend:**

Two options:

| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **.NET on the Grid (reuse Auth, Vault, Notify, Communications, Pulse, Web.Rest)** | Reuses ~6 Nodes already in production. Auth handles JWT + refresh; Vault holds secrets; Notify handles email + SMS verification + push; Communications handles preferences and cadence; Pulse handles telemetry. Low marginal cost. | Mobile clients consume REST surfaces from the Grid — no precedent yet, but Web.Rest patterns are clean. | **Recommended** |
| **Greenfield Node.js / Python backend** | Closer to the React Native ecosystem, abundant tutorials | Builds infrastructure the Grid already has. Doubles maintenance surface. Forks the user's mental model. | Rejected — defeats the Grid's purpose |

**Recommendation: .NET on the Grid.** Lately's backend is a new Node — call it `HoneyDrunk.Lately` (codename) or its product-name equivalent — in a new sector (likely a new **Apps** sector, see §I). It depends on Auth, Vault, Notify, Communications, Pulse, and Web.Rest. It owns its own domain (profiles, currents, fingerprints, Rooms).

**Photo storage:**

- **Azure Blob Storage** (already in the Grid's Azure footprint).
- **CDN (Azure Front Door or Cloudflare R2 if cost makes more sense)** for delivery.
- **Image processing on upload** — resize, sanitize EXIF metadata, run through Rekognition, store original + multiple resolutions. Standard pattern.

**Geolocation:**

- **Coarse only.** Phone IP → metro area at signup. No continuous tracking.
- **No GPS access requested at v1.** The Room's geographic filter operates on metro-level cohorts derived from signup IP and refreshable on demand by the user.
- This is a deliberate trust posture: privacy-first, no creep factor, no "Lately knows where you are right now" anxiety.

**Real-time / The Room implementation:**

- **The Room's 8pm window is not real-time chat.** It is a 90-minute polling window where users post liner notes and fingerprints. Polling at 5-second intervals when the Room is open is sufficient and avoids WebSocket infrastructure.
- WebSockets / SignalR can be a v1.5 addition if engagement justifies the latency improvement. v1 keeps it simple.

**Item canonical IDs:**

- **Open Library API** for books (free, ISBN-resolvable).
- **Hardcover API** as the modern alternative for books (paid tier exists; free tier may be sufficient).
- **TMDB API** for films and shows (free with key, well-documented).
- **MusicBrainz** for albums (free, exhaustive). Spotify API for catalog convenience and image rights (free with rate limits).

**Push notifications:**

- **Notify Node already supports email and SMS.** Push (APNS/FCM) is on Notify's v1.5 roadmap (per PDR-0002 §G). Lately needs push at launch — this means Notify's push channel ships **as a Lately dependency**, not as a Notify Cloud dependency.
- This is convergent: PDR-0002 deferred push because Notify Cloud's buyer profile (B2B indie dev) does not need it for v1. Lately's buyer (consumer) does. **This PDR pulls Notify push forward as a Lately prerequisite.**

### I. Dependencies on the HoneyDrunk Grid

Lately reuses substantially more of the Grid than Notify Cloud does, because Lately's backend is a full domain Node with consumer-grade auth, secrets, notifications, and telemetry needs.

**Reused Nodes (no contract changes needed):**

| Node | Use | Notes |
|---|---|---|
| **HoneyDrunk.Auth** | JWT issuance and validation for Lately's mobile clients. Refresh token flow. Phone-number-based auth (SMS code via Notify). | Auth's existing flow works — phone-as-username is a supported pattern. |
| **HoneyDrunk.Vault** | Stores third-party API keys (TMDB, Open Library, Hardcover, MusicBrainz, Rekognition). Per-environment isolation already standard. | No changes. |
| **HoneyDrunk.Notify** | Email (welcome, transactional), SMS (phone verification, abuse alerts), push (match prompts, Room reminders). | **Push channel must ship before Lately launches.** |
| **HoneyDrunk.Communications** | User preferences (notification cadence, quiet hours, Room time customization), decision-log (why Lately did or did not surface a Room). | Same primitives Notify Cloud uses; reuse is clean. |
| **HoneyDrunk.Pulse** | Telemetry, engagement metrics, retention dashboards. | Critical for kill-criteria measurement (§K). |
| **HoneyDrunk.Web.Rest** | Lately's REST API surface. Response envelopes, correlation IDs, error handling. | Standard Grid pattern. |
| **HoneyDrunk.Kernel** | Context propagation, lifecycle, identity primitives. | Standard. |

**New Node:**

- **`HoneyDrunk.Lately`** (codename — final Node name aligns with final product name). Lives in a new **Apps** sector. Owns domain: profile, currents-shelf, fingerprint, Room, mutual-match, item-canonical-ID resolution.

**Sector decision:**

Lately is a proposed consumer product in the canonical **Market** sector. This PDR uses **Apps** only as a working portfolio label for consumer surfaces pending a future constitution amendment; it does not itself add a new canonical sector. Notify Cloud lives in Ops (it is an extension of the Notify delivery engine); Lately is its own consumer-product domain.

**Push channel pull-forward:**

Per PDR-0002 §G, the Notify Cloud v1 cuts push. This PDR reverses that for Lately's needs:

- **Notify push channel (APNS + FCM) ships as a Lately prerequisite.**
- Notify Cloud customers may opt in to the same push channel post-launch — gravy, not core.
- The push capability is built once, in Notify, used by both Lately and (eventually) Notify Cloud customers.

**No AI-sector dependency at v1.**

Lately does not depend on HoneyDrunk.AI, HoneyDrunk.Agents, or any AI-sector Node at v1. Recommendation algorithms (currents-similarity, Room ranking) are deterministic at v1 — recency-weighted overlap, not ML inference. Adding AI-driven matchmaking is a post-launch decision validated against real engagement.

This is consistent with PDR-0002's Notify Cloud cuts and with PDR-0001's "rule-based first, adaptive later" routing posture.

### J. Pricing analysis — willingness-to-pay and the $8.99 anchor

**Comparable consumer connection-app pricing (2026):**

| App | Free tier | Paid entry | Notes |
|---|---|---|---|
| **Tinder Plus** | Limited swipes, see-who-likes-you locked | $9.99/mo | Anchor price for the category |
| **Tinder Gold** | — | $19.99/mo | Pay-to-see-likes monetization |
| **Hinge Preferred** | Standard swipes | $19.99/mo | Higher-tier filters, "Roses" |
| **Bumble Premium** | Standard | $19.99/mo | Beeline, Spotlight, advanced filters |
| **Coffee Meets Bagel Premium** | — | $34.99/mo | High-end positioning |
| **Feeld Majestic** | Limited | $14.99/mo | Niche-positioning premium |

**The $8.99 anchor for Lately:**

- **Below Tinder Plus's $9.99.** This is deliberate. The category's mental model is "$10 is dating-app money." Lately at $8.99 reads as "below the category's floor" — perceived as more honest and less premium-trap.
- **Well below Hinge / Bumble Premium's $19.99.** Lately does not compete on premium gating; it competes on no-gating. The price reflects that.
- **Above zero.** A free-only product is not a sustainable business and positions Lately as untrustworthy ("how do they make money — by selling my data?"). $8.99 is the price of trust signaling.
- **No annual discount at v1.** Monthly only. Annual subscriptions can be added if retention proves sustainable; v1 does not lock users in.
- **Optional one-time boosts** ($2.99 each) for niche features (e.g., "Room boost" — see your Room first when it opens; max one per day). Boosts are a marginal revenue surface, not a core monetization mechanic. They can be cut entirely if they prove tier-stacking-adjacent.

**What gates the Hardcover ($8.99/mo) tier:**

| Free tier | Hardcover tier |
|---|---|
| All photos | Same |
| 4-slot currents shelf | Same |
| Update currents anytime | Same |
| The Room (all your items) | Same |
| Fingerprint anyone | Same |
| Friendship + dating mode | Same |
| **Mutual fingerprint matches surfaced** | Same |
| In-app DM after match | Same |
| Block and report | Same |
| 30-day refresh requirement | Same |
| | **See who fingerprinted you (asymmetric reveal)** |
| | **Rewinds** — unfingerprint a profile, undo a Room dismissal |
| | **Advanced filters** (age, gender preference scope, distance scope, currents-overlap-depth filter) |
| | **Currents history** — see what you were consuming 6 months ago |

**What does NOT gate Hardcover (the non-negotiable list):**
- Swipe / fingerprint limits — none, ever, on either tier.
- Profile visibility — Free profiles are not deprioritized.
- Match acceptance — Free users get matches at the same rate as Hardcover.
- The Room access — Free users get every Room.
- Algorithm bias — Hardcover does not buy ranking advantages.

This is the pricing wedge. It is non-negotiable because it is the marketing story.

**Estimated paid conversion:** Hinge converts ~5–7% of MAU to paid. Bumble ~3–4%. Lately's lower price point and non-extractive positioning could plausibly hit 6–10% if the wedge is real, but **3% is the planning baseline**. At 10K MAU, that is 300 paid users at $8.99 = $2,697/mo. At 100K MAU, that is $26,970/mo. These are the rough scale benchmarks the kill criteria measure against.

### K. Kill criteria

Lately gets killed if any of the following triggers within 90 days of public launch:

1. **<5K daily active users by day 90.** This is the engagement bar. If after 90 days of public launch Lately has fewer than 5K DAU, the wedge is not pulling people in often enough to sustain the network. Kill.
2. **Median Room density <3 strangers per item.** This is the cold-start bar. If after 90 days the typical Room has fewer than 3 strangers, The Room is not delivering on its promise and the retention thesis fails. Kill.
3. **<1% paid conversion at 90 days.** This is the commercial bar. The pricing wedge requires that some users find the Hardcover features valuable. Below 1% is fundamentally below the category's floor. Kill.
4. **Sev-1 trust & safety incident with no operationally feasible mitigation.** This is the responsibility bar. If a class of T&S incident is structurally unmanageable at solo-dev scale (e.g., scalable harassment vectors that AI triage cannot handle), Lately gets killed regardless of engagement. The user does not ship a connection app that produces harm at scale.

A soft kill condition that triggers a PDR review (not an automatic kill):

5. **Operating cost exceeds revenue by 4× at any point in the first 6 months.** Different multiplier than Notify Cloud (PDR-0002 used 3×) because Lately's operating cost is structurally higher (storage, mod APIs, push, photo CDN) and the unit economics curve takes longer to bend. Triggers a pricing or scope review.

Kill criteria are independent. Any single trigger at the threshold is enough.

### L. Brand and aesthetic register

Customer-facing brand is TBD. Working codename is Lately. Final product name is gated on a separate brand and trademark exercise — not part of this PDR.

**Aesthetic register notes (secondary to mechanics, but not ignorable):**

- **Anime / cozy / literary** is a welcome register but cannot be the wedge. The wedge is mechanical (currents-based, The Room, fingerprint, non-extractive pricing). Aesthetic is dressing.
- **Warm, evening-not-morning, soft palette.** Not the sharp blues of dating apps; not the loud yellows of Bumble. A muted, library-after-dark aesthetic.
- **The Room as a visual concept.** Literal: the screen at 8pm should *feel* like a room — soft lighting, items on a shelf, people's notes pinned up. This is the aesthetic moat against generic-feeling indie connection apps.
- **No corporate-speak in copy.** Lately is written in second person, lower-case, conversational. No "discover meaningful connections." The category's corporate-speak is one of the things users have learned to mistrust.
- **No HoneyDrunk Grid metaphors in user-facing concepts.** No "Nodes," no "Sectors," no "Hive." Lately is for regular humans; the architecture is invisible.

The brand exercise that produces the final product name is a separate engagement. This PDR commits to the mechanics, the architecture, and the strategic bets — not the name.

---

## Options Evaluated

### Option 1: Status quo — do not ship a consumer app

**Description:** HoneyDrunk Studios remains a B2B / dev-tools studio. Notify Cloud is the only commercial product. No consumer product line.

**Pros:**
- Single product line, single brand, single buyer profile.
- Solo-dev focus is undivided.
- No T&S exposure, no app-store dynamics, no consumer support volume.

**Cons:**
- The user is building for the love of building. A consumer app is meaningful work the user wants to do; refusing it for portfolio-optimization reasons is the wrong default for a solo-dev studio that is not VC-funded.
- The Grid was designed with consumer-app needs in mind (Auth's phone-based flow, Notify's multi-channel, Communications's preferences). Without a consumer product, half the Grid's design intent is unused.
- The studio narrative — "a studio that ships products on a unified architecture" — has only one product. Consumer + dev-tool dual-market is a stronger long-term narrative than dev-tool-only.

**Verdict:** Rejected. The user wants to build this. Refusing on pure commercial grounds is the wrong call; the product also has a defensible strategic basis (the Grid is consumer-capable; the category has a real wedge).

### Option 2: Ship Lately on a re-skinned dating-app loop (no Room, no fingerprint, no currents)

**Description:** Build a Hinge-style swipe-and-prompt app with a slight differentiation (e.g., literary aesthetic). Ship faster, take less risk on novel mechanics.

**Pros:**
- Well-trodden product surface; no novel mechanics to validate.
- Faster to ship.
- Lower T&S exposure (less novel content surface).

**Cons:**
- Has no wedge. The category has 50+ Hinge-shaped apps. Lately would be #51.
- Cannot defend pricing on a non-extractive model if the product is mechanically identical to extractive competitors.
- No structural retention mechanic. Lately would inherit the category's churn problem.
- Aesthetic differentiation alone is not a wedge — Hinge is already aesthetically polished and well-funded.

**Verdict:** Rejected. The whole point of building this is that the mechanics are different. A re-skin is a worse product, not a faster product.

### Option 3: Build the full Lately concept including AI matchmaking, voice notes, video profiles, in-app events

**Description:** Ship Lately as a category-defining premium consumer product with every feature on the wishlist.

**Pros:**
- Most ambitious version. Best feature parity with future-state competitors.

**Cons:**
- Unbuildable by a solo dev in any reasonable timeline.
- AI matchmaking has no v1 training data — premature.
- Voice notes and video profiles double moderation surface.
- In-app events introduce IRL safety surface (meeting strangers IRL is a different product category and a different liability shape).
- Ships years late or not at all.

**Verdict:** Rejected. The cuts in §G are not optional; they are the only way this ships from a solo dev.

### Option 4: Ship Lately as the v1 concept — currents-based, photo-prominent, The Room, fingerprint, friendship + dating, $8.99 paid tier, fandom-soft-launch (Selected)

**Description:** The v1 described in §A through §J. Ruthlessly cut to MVP. Mechanics are the wedge.

**Pros:**
- Mechanical wedge is real and defensible against the category's incumbents.
- Cuts are aggressive and sized for solo-dev capacity.
- Reuses the Grid heavily — marginal cost to add Lately is mostly the mobile client and the new Lately Node.
- Pricing posture is a marketing wedge in itself.
- Friendship-first framing lowers signup bar and reduces dating-app stigma.
- The Room is a structural retention bet, not a behavioral one.

**Cons:**
- Two-sided marketplace cold-start risk is real (mitigated by Strategy 2 fandom soft-launch + kill criteria).
- T&S exposure is novel for the studio; solo-dev T&S is below industry norm (mitigated by honest framing and AI-triaged moderation).
- Notify push channel must ship before Lately launches — adds dependency.
- Mobile-app shipping requires app-store review, which adds latency and surprise risk.
- Brand exercise is incomplete; the codename Lately is not the launch name.

**Verdict:** Selected. The wedge is real; the cuts are right; the architecture is buildable; the pricing posture is defensible. The risk surface is bounded by aggressive kill criteria.

### Option 5: Ship Lately friendship-only at v1, defer dating mode entirely

**Description:** v1 is friendship-only. Dating mode is v2 or later. Lower T&S exposure, lower category-stigma, simpler positioning.

**Pros:**
- Simpler T&S surface (friendship apps face less harassment than dating apps).
- Less category-stigma at signup.
- Friendship-app market is less saturated.

**Cons:**
- Most users want both. Restricting to friendship-only at v1 creates "this is missing" friction.
- Dating mode is a strong wedge against Hinge / Bumble. Cutting it removes a key differentiator.
- The 8pm Room and fingerprint mechanics work equally well for friendship and dating; cutting dating cuts revenue surface and acquisition channels.

**Verdict:** Rejected as a v1 cut, but **adopted partially as soft-launch framing** (per §E recommended position): friendship-first public framing with dating mode toggle present from day one.

### Option 6: Ship Lately as a partner-app under HoneyDrunk Studios brand

**Description:** Lately lives as a sub-product under `lately.honeydrunkstudios.com`, with HoneyDrunk Studios branding visible.

**Pros:**
- Brand consolidation — one parent brand, multiple products.
- Build-in-public continuity.

**Cons:**
- HoneyDrunk Studios is dev-shaped and architecture-forward. That register is wrong for a consumer connection app. Regular humans do not sign up for "the connection app from a dev studio that builds Grid infrastructure."
- Build-in-public is a B2B marketing strategy, not a consumer marketing strategy.
- Architectural transparency — a marketing wedge for Notify Cloud — is irrelevant to consumer buyers and could even be a trust-negative (regular humans do not want to know their connection app is built on "Nodes").

**Verdict:** Rejected. Brand separation is required (per §A).

---

## Trade-offs

| Trade-off | Favored Position | Rationale |
|---|---|---|
| Mechanical wedge (Room, fingerprint, currents) vs. aesthetic wedge (cozy/literary) | **Mechanical** | Aesthetic is dressing. Mechanics defend against re-skin competitors; aesthetic does not. |
| Photos-prominent vs. text/currents-prominent | **Photos prominent, currents below** | Pretending photos do not matter produces a product that does not match human behavior. The wedge is the addition of currents below, not the removal of photos above. |
| Friendship-first vs. dating-first vs. both | **Both, friendship-framed publicly** | Friendship-only excludes a strong wedge; dating-only inherits category stigma. Toggle from day one, friendship is the public framing. |
| Cold-start: city-only vs. fandom-only vs. friendship-first | **Fandom-only for soft launch, friendship-first for framing** | The user has no city affinity; community partnerships are reachable. The two strategies are compatible. |
| Single fandom (film) vs. multi-fandom soft launch | **Single fandom (Letterboxd-adjacent)** | Density is the bet. Multi-fandom soft launch dilutes The Room's overlap. Pick the fandom most aligned with the recency primitive. |
| .NET on the Grid vs. greenfield Node.js / Python backend | **.NET on the Grid** | The Grid's reuse cost is near-zero. Greenfield duplicates infrastructure. |
| React Native vs. native iOS + Android | **React Native** | Solo-dev cannot maintain two native codebases. Performance gap is not material for a connection app. |
| In-app messaging at v1 vs. minimal-handoff to third-party platforms | **Minimal in-app DM at v1, third-party-friendly** | Full chat is not the wedge. Most chat migrates off-platform anyway. Reduces moderation surface. |
| Mandatory ID verification vs. soft photo verification | **Soft photo verification + phone verification** | Mandatory ID kills early activation. Photo + phone verification is the realistic solo-dev bar. |
| AI matchmaking at v1 vs. deterministic recency-weighted matching | **Deterministic at v1** | No training data. Adding AI later, validated against engagement, is the right sequence. |
| Free tier with all features vs. free tier with gates | **Free tier with all core features** | The pricing wedge requires it. Gating swipes / matches / messages reproduces the predatory pattern Lately is positioned against. |
| Annual discount at v1 vs. monthly only | **Monthly only** | Annual locks users in before retention is proven. v1 is honest about uncertainty. |
| Push channel built in Notify (deferred per PDR-0002) vs. push built directly in Lately | **Built in Notify, used by Lately** | Reuse compounds. Push is a Notify capability; Lately is the first consumer. Notify Cloud can opt in later. |
| Brand under HoneyDrunk Studios vs. separate consumer brand | **Separate consumer brand (TBD)** | Studio brand is dev-shaped. Consumer brand needs different register. |
| Publicly mention HoneyDrunk Grid in Lately's marketing vs. invisible architecture | **Invisible architecture** | Regular humans do not care about Grid. Visibility is a trust-negative. |
| 90-day kill clock vs. longer runway | **90 days** | Aligns with PDR-0002. Solo-dev can't afford to sustain a non-converting consumer product. The metrics (DAU, Room density, paid conversion) are observable in 90 days. |

---

## Architecture Implications

### New surface area

**New repo: `HoneyDrunk.Lately`** (codename — final repo name aligns with final product name).

This is a proposed consumer Node in the canonical **Market** sector. A future ADR may formalize **Apps** as a sub-sector or replacement taxonomy; until then, the consumer-app portfolio exists within Market and is expected to:
- Distinguish consumer products from internal Core / Ops / Meta concerns.
- Give consumer products their own boundary and naming conventions (no Grid metaphors leak into consumer surfaces).
- Enable future consumer products (Lately is the first, not necessarily the last) to inherit the same boundaries.

**Mobile client repo (separate):**
- **`HoneyDrunk.Lately.Mobile`** (codename) — React Native + Expo. iOS + Android targets. Private repo (consumer apps are not open-source; the engine could be partially OSS but the mobile client is closed).

**Package families (parallels Notify Cloud's standup shape):**

- `HoneyDrunk.Lately.Abstractions` — `IProfileService`, `ICurrentsShelf`, `IFingerprint`, `IRoomCoordinator`, `IItemResolver` (canonical-ID resolution for books/films/albums).
- `HoneyDrunk.Lately` — runtime composition. Domain logic for profile / currents / fingerprint / Room / mutual-match.
- `HoneyDrunk.Lately.Web.Rest` — REST API surface for the mobile client. Reuses Web.Rest patterns.
- `HoneyDrunk.Lately.ItemResolution.{OpenLibrary, TMDB, MusicBrainz}` — provider-slot pattern for canonical-ID resolution. Each external API is its own adapter.

### Dependencies

```
HoneyDrunk.Lately
  ├─ consumes ──► Auth (JWT, refresh, phone-based auth)
  ├─ consumes ──► Vault (third-party API keys, photo CDN credentials)
  ├─ consumes ──► Notify (email, SMS, push) — push is a Lately prerequisite
  ├─ consumes ──► Communications (preferences, cadence, decision-log)
  ├─ consumes ──► Web.Rest (response envelopes, correlation)
  ├─ consumes ──► Kernel (IGridContext, lifecycle, telemetry)
  └─ emits telemetry ──► Pulse
```

Lately does **not** consume HoneyHub. Lately does **not** consume any AI-sector Node at v1.

### Boundary changes to existing Nodes

| Node | Change | Notes |
|---|---|---|
| **HoneyDrunk.Notify** | **Push channel (APNS + FCM) ships as a Lately prerequisite.** Was deferred to v1.5 in PDR-0002. | Notify Cloud can opt in later. The push capability is built once. |
| **HoneyDrunk.Auth** | Phone-number-based auth flow validated for consumer use (it already exists; needs UX polish for mobile). | Standard. |
| **HoneyDrunk.Communications** | New preference categories: Room-time customization, push-quiet-hours, match-frequency, friendship-vs-dating-mode toggle. | Additive — Communications's preference primitive supports this. |
| **HoneyDrunk.Vault** | New tenant-style scoping for Lately's third-party API keys (TMDB, Open Library, etc.). | Per-environment isolation already standard. No contract change. |
| **HoneyDrunk.Pulse** | Consumer-product telemetry shape: DAU, WAU, Room density, fingerprint mutuality rate, paid conversion, retention curves. | New dashboard, not new contract. |
| **HoneyDrunk.Web.Rest** | Mobile-client-shaped REST patterns formalized. (Notify Cloud is API-key-auth; Lately is JWT-with-refresh-from-mobile.) | Auth pattern coexists; new SDK shape for mobile clients. |

### What does NOT change

- **Notify Cloud's roadmap (PDR-0002).** Notify Cloud's v1 cuts (no push) are revisited only because Lately needs push. Notify Cloud's launch sequence is unchanged.
- **HoneyHub.** This PDR does not change HoneyHub's direction.
- **The Grid's manifesto, sector model, or invariants.** Any Apps taxonomy change is deferred to a constitution amendment.
- **Notify Cloud's pricing or feature list.** Notify Cloud and Lately share infrastructure but not roadmap.
- **The Grid's open-core stance.** Lately's mobile client is closed; the Lately engine may be partially open at the Node level if it makes sense (unlikely — there is no community value in open-sourcing a connection-app domain). The Grid's open-core principle does not require every Node to be open.

---

## Product Implications

### Tier shape

| Tier | Price | Buyer | Hook |
|---|---|---|---|
| Free | $0 | All users — Lately's growth tier | All core features. The Room. Fingerprints. Mutual matches. In-app DM. |
| Hardcover | $8.99/mo | Engaged users who want async-symmetric reveals and rewinds | See-who-fingerprinted-you, rewinds, advanced filters, currents history |
| Optional boosts | $2.99 each | One-off upgrade for a specific moment | E.g., Room boost (see your Room first when it opens); max one per day |

### Customer acquisition

**Soft launch (single fandom):**
- **Letterboxd-adjacent users** — partner with a Letterboxd-aligned newsletter, podcast, or community influencer. Distribution narrative: "Letterboxd is great for what you watched; Lately is for what you're watching tonight."
- **One or two pre-launch newsletter / podcast partnerships** — hand-picked, not paid.
- **TestFlight / Play Console internal beta** — 100–200 beta users, no payment.

**Public launch:**
- **App store launch** with iOS-first, Android within 2 weeks.
- **Press**: targeted at tech-culture publications (The Verge, Mashable, Wired). The pricing-as-honesty narrative is the press hook, not the mechanics.
- **TikTok / Instagram organic** — Room mechanics produce shareable moments (a screenshot of "you both fingerprinted each other on three different things — *Pachinko*, *The Bear*, *Slow Horses*" is share-worthy). Encourage organic sharing without making it mandatory.
- **Dating-app exit narrative** — "Tinder is broken, here's what we built instead." This is high-effort, high-reward content that could be a single launch essay.

### Retention dashboards (Pulse-driven)

Critical metrics, all visible in Pulse from day one:

- DAU / WAU / MAU
- Median Room density per item per night
- Mean active currents items per user (target: ≥3)
- 30-day refresh rate (% of profiles updated within window)
- Fingerprint volume per DAU
- Mutual fingerprint match rate
- Match → in-app DM rate
- Match → off-platform handoff rate (where measurable)
- Paid conversion (Free → Hardcover) at day 7, 30, 90
- Hardcover churn (monthly)
- Reports per 1K DAU (T&S volume)
- Time-to-resolution on reports

These map directly to the kill criteria. Without Pulse instrumentation from day one, the kill criteria cannot be measured. Pulse instrumentation is non-negotiable v1 work.

### Brand and aesthetic

The brand exercise that produces the final product name and aesthetic register is a separate engagement. This PDR commits to:
- **Codename Lately** for internal use through pre-launch.
- **Separate consumer brand**, not under HoneyDrunk Studios.
- **No HoneyDrunk Grid metaphors** in any consumer surface.
- **Anime / cozy / literary register** is acceptable secondary; mechanics are primary.

The brand engagement is a **decision the user must make before MVP design work begins** — see "Next Steps."

---

## What Does NOT Change

- **PDR-0001 and PDR-0002.** Both stand. Lately is independent.
- **Notify Cloud's launch sequence.** Lately depends on Notify, not on Notify Cloud's commercial launch.
- **HoneyHub's internal direction.** Unchanged by this PDR.
- **The Grid's manifesto, invariants, and canonical sector model.**
- **The solo-dev operating model.** Lately is solo-shipped with AI agents. No hires, no investor narrative.
- **Open-core repo posture.** Lately's mobile and engine code are closed by default; this is consistent with the existing public-by-default-with-revenue-exception rule.

---

## Risks

| Risk | Severity | Description |
|---|---|---|
| **Cold-start liquidity failure** | High | Two-sided marketplace dynamics. Without enough density per item per metro, The Room is empty and the wedge fails. Kill criterion 2. |
| **The Room thesis is wrong** | High | If users do not open Lately at 8pm, the retention bet fails and the app inherits the category's churn problem. No mitigation for a wrong thesis except killing fast. |
| **Trust & safety incident exceeds solo-dev capacity** | High | A coordinated harassment vector or a class of T&S incidents that AI triage cannot handle is an automatic kill (criterion 4). |
| **App store rejection / suspension** | Medium-High | Apple and Google review processes are unpredictable for new connection apps. Rejection delays launch; suspension mid-flight is catastrophic. |
| **30-day refresh requirement creates churn** | Medium | If users see the refresh prompt and bounce instead of refreshing, the activation-to-retention curve breaks. Tunable (the requirement could become a soft prompt, not a hard hide). |
| **Pricing wedge does not convert** | Medium | If <1% of users pay, the commercial bar fails (kill criterion 3). Mitigation: Hardcover features must be genuinely valuable, not artificially gated. |
| **Notify push channel slips** | Medium | Lately depends on Notify push. If Notify push is delayed, Lately launch slips. Mitigated by sequencing push as a hard prerequisite, not a parallel work stream. |
| **Brand confusion across Notify Cloud and Lately** | Medium | Two consumer-facing surfaces from one studio confuses press and audience. Mitigated by brand separation (§A) and distinct domains. |
| **Item canonical ID resolution failure** | Medium | If TMDB / Open Library / Hardcover / MusicBrainz coverage is incomplete, users see "I can't find my book" friction. Mitigated by a "free-text fallback" that does not participate in The Room's overlap query — degraded experience for that user, no degradation for others. |
| **App-store consumer-app economics** | Medium | iOS takes 30% (15% after year 1 for subscriptions). Android 15-30% depending on tier. The $8.99 price is gross-of-store-cut; net is $6.30–$7.65. Affects unit economics. |
| **Photo storage / CDN cost scales superlinearly with users** | Low-Medium | Photo storage at 50K MAU is meaningful Azure cost. Mitigated by aggressive image resizing on upload, conservative resolution policies, and Cloudflare R2 if Azure CDN cost gets out of hand. |
| **Solo-dev burnout from dual product lines** | Medium | Notify Cloud + Lately is two products. Solo-dev capacity is not unlimited. Mitigated by strict scope cuts, AI-agent leverage, and willingness to kill either product if the dual-line load proves untenable. |
| **Anime / cozy aesthetic register comes off as kitschy** | Low | Aesthetic missteps damage brand. Mitigated by treating brand as a separate engagement, not a side concern. |
| **Letterboxd-adjacent fandom does not transfer** | Low-Medium | Soft-launch partnership with a film community may not produce signups. Mitigated by having a backup soft-launch strategy (BookTok-adjacent, indie-music-newsletter-adjacent). |

---

## Mitigations

| Risk | Mitigation |
|---|---|
| Cold-start liquidity failure | Single-fandom soft launch (Letterboxd-adjacent). Fandom-first is the strategy that gives The Room density without depending on city-by-city ground-game. Backup fandom selected before soft launch begins. |
| The Room thesis is wrong | The 90-day kill clock catches this. There is no mitigation for a wrong thesis other than measuring fast and killing fast. |
| T&S incident exceeds capacity | Automated photo moderation (Rekognition), phone verification, AI-triaged report queue with 48h human review, auto-action on high-severity classes (threats, doxxing, child safety). Honest framing on the marketing site about solo-dev T&S limits. |
| App store rejection | Conservative content policies in the app's own ToS. Pre-submission review against Apple's known-rejection-vectors checklist. Engaged review processes with Apple and Google before submission. Backup TestFlight / Play Console internal beta surface to maintain user contact during any review cycle. |
| 30-day refresh churn | Soft prompts starting at day 23 (not day 30). Refresh UX is one tap if the user is opening the app at all. If churn proves to be a real issue, the hide-after-30-days threshold can be lengthened to 45 or 60 without changing the wedge. |
| Pricing wedge does not convert | Hardcover features (rewinds, see-who-fingerprinted-you, advanced filters, currents history) are genuinely valuable, not gated essentials. Free tier is genuinely free. Conversion experiments (price testing at $6.99, $8.99, $11.99 across cohorts) post-launch. |
| Notify push slip | Sequenced as a hard prerequisite. Notify push is built before Lately mobile client work begins on push integration. Single owner (the user, scope-agent driven). |
| Brand confusion | Separate consumer brand, separate domain, no HoneyDrunk Studios footer in Lately. Marketing surfaces never cross-link. Press kit is brand-isolated. |
| Item canonical ID failure | Free-text fallback for items not found in canonical sources. Free-text items show the user "we couldn't find this; you'll see fewer matches in The Room until you pick a canonical version." Honest, simple. |
| App-store consumer economics | The $8.99 price is calibrated against the post-store-cut net. Operating cost calculations assume the net, not the gross. |
| Photo storage / CDN cost | Aggressive resizing (max 1080x1080 stored, multiple resolutions served). Image cache TTLs and CDN caching aggressive. Cloudflare R2 is a known fallback if Azure CDN cost becomes an issue. |
| Solo-dev burnout | Notify Cloud and Lately are sequenced, not parallel. Notify Cloud reaches public launch (target 2026-09-15) before Lately enters public-launch territory. Lately's earliest public launch is calendar Q1 2027, after Notify Cloud has either cleared or failed its 90-day bar. This is non-negotiable scheduling. |
| Anime / cozy register kitschy | Brand engagement is a real, scoped exercise — not a vibes call. Specific designer / brand consultant engagement before MVP visual design. |
| Fandom does not transfer | Backup fandom selected before soft launch. If Letterboxd-adjacent is the primary partnership, BookTok-adjacent is the backup, indie-music-newsletter is the third option. |

---

## Consequences

### Short-term (next 4–6 months — through 2026-11)

- **Notify push channel ships** as a Lately prerequisite. APNS + FCM provider integrations in Notify. Communications updated for push-quiet-hours and push-frequency preferences.
- **New `HoneyDrunk.Lately` Node** stands up with its own scaffold ADR (per the standup-ADR convention).
- **Consumer-app taxonomy** is resolved through a follow-up constitution amendment before implementation work begins.
- **New `HoneyDrunk.Lately.Mobile` repo** stands up with React Native + Expo. iOS + Android targets.
- **Brand engagement** is commissioned: final product name, visual register, marketing copy direction. Decision before MVP design.
- **Item canonical ID adapters** are scaffolded against TMDB, Open Library / Hardcover, MusicBrainz / Spotify.
- **Lately consumes substantial Grid surface** for the first time — Auth, Vault, Notify, Communications, Pulse, Web.Rest. Stresses the Grid in ways internal-only use does not.
- **Notify Cloud launch (PDR-0002) is calendar-protected** — Lately work does not begin before Notify Cloud's public launch (2026-09-15 target). This is non-negotiable scheduling per the §Mitigations row on burnout.

### Medium-term (next 9–12 months — through 2027 Q2)

- **Lately MVP design**, build, soft launch (single fandom), public launch. Calendar Q1 2027 earliest public launch.
- **90-day kill clock** runs from public launch. Q2 2027 is the kill review window.
- **The Grid's first consumer-product Node** is in production. Telemetry and operational shape are validated.
- **The studio narrative shifts** — HoneyDrunk Studios ships both dev tools (Notify Cloud) and consumer apps (Lately). Two-product portfolio, one Grid.

### Long-term (post-90-day kill clock)

If Lately clears the 90-day bar:

- **The consumer-app portfolio is validated** as a viable product line. Future consumer products inherit the pattern.
- **The retention thesis** (synchronous nightly windows, recency-first profiles, fingerprint-as-warm-context) is validated at scale and becomes a defensible product-design pattern within the studio.
- **Lately becomes the consumer-facing front of the Grid**, in the same way Notify Cloud is the dev-facing front. The studio is bi-modal.
- **Cross-product learning** — Notify Cloud's multi-tenant patterns and Lately's consumer-mobile patterns inform future products.

If Lately does not clear the 90-day bar:

- **Lately is killed.** The mobile client repo is archived. The Lately Node is preserved (to learn from the post-mortem) but no longer accepts new users.
- **A retrospective PDR** documents what the wedge missed.
- **The consumer-app portfolio remains** as a category for future products — the portfolio itself is not invalidated by one product's failure.
- **The Grid's investment in Lately-specific infrastructure** (Notify push, consumer-app patterns, item canonical ID adapters) is preserved and reusable.

Either outcome generates more learning than not shipping.

---

## Rollout — Phased Approach

### Phase 0: Notify Cloud public launch (2026-09-15 target)

- Notify Cloud launches per PDR-0002. **Lately work does not begin in earnest before this milestone.** Solo-dev capacity protection.
- Brand engagement for Lately can begin in parallel during Notify Cloud's pre-launch phases (it is non-coding work).

**Exit criteria:** Notify Cloud is live at `notify.honeydrunkstudios.com` with paying customers possible.

### Phase 1: Notify push channel + Lately scaffold (calendar Q4 2026)

- **Notify push channel ships** — APNS + FCM provider integrations, push-quiet-hours preference in Communications, push-frequency preference, push delivery telemetry in Pulse.
- **`HoneyDrunk.Lately` Node scaffold** — standup ADR, Abstractions package, runtime composition, REST surface, item canonical ID adapter scaffolds.
- **`HoneyDrunk.Lately.Mobile` repo** scaffold — React Native + Expo, iOS + Android targets. Auth flow against the Grid's Auth Node.
- **Consumer-app taxonomy** resolved in constitution/catalog updates, if Architecture accepts a dedicated Apps label.
- **Brand engagement complete** — final product name, visual register, marketing copy direction.

**Exit criteria:** Notify push delivers a real APNS / FCM message in production. Lately mobile client can sign in via phone and load a placeholder profile screen. Final product name selected.

### Phase 2: Lately MVP build (calendar Q4 2026 – Q1 2027)

- Profile creation (3–5 photos + 4-slot currents shelf).
- Item canonical ID resolution against TMDB, Open Library / Hardcover, MusicBrainz / Spotify.
- 30-day refresh requirement implementation.
- Photo upload, Rekognition moderation, photo verification.
- Phone verification (already exists in Notify; mobile UX integration).
- Block, report, AI-triaged moderation queue.
- Fingerprint gesture implementation.
- Mutual fingerprint match logic.
- The Room implementation (8pm local, 90-min window, item-keyed cohort selection).
- In-app DM (minimal, text-only).
- Free + Hardcover tier with Stripe / app-store IAP.
- Pulse instrumentation for all kill-criteria metrics.

**Exit criteria:** App runs end-to-end on TestFlight + Play Console internal beta. 50+ internal beta users (HoneyDrunk Studios extended network) actively using the app.

### Phase 3: Soft launch (calendar Q1 2027)

- Soft launch in single fandom (Letterboxd-adjacent or backup choice). Hand-picked partnership with one or two community-aligned newsletters / podcasts.
- 500–2000 hand-picked early users.
- Weekly review of usage data, T&S incidents, wedge performance.
- Iterate on currents shelf UX, Room mechanics, fingerprint gesture, match-handoff flow.

**Exit criteria:** ≥1000 weekly active users in soft launch. Median Room density ≥3 strangers per item per night for the soft-launch fandom. No Sev-1 T&S incidents.

### Phase 4: Public launch (calendar Q1 / Q2 2027)

- App store public launch (iOS first, Android within 2 weeks).
- Press cycle (tech-culture publications). Pricing-as-honesty narrative.
- Free tier active, Hardcover ($8.99) live with Stripe + app-store IAP.
- **The 90-day kill clock starts here.**

**Exit criteria for "successful public launch":** Public traffic, working signup flow, paid IAP processing, no Sev-1 incidents in the first 7 days.

### Phase 5: Kill-clock review (90 days post public launch)

- Count DAU, Room density, paid conversion, T&S incident rate.
- Apply kill criteria from §K. Any single trigger → kill.
- If clear: continue, write next-PDR for v1.5 / v2.
- If kill: retrospective PDR, archive, refocus.

**Exit criteria:** Clear go/no-go decision documented as a follow-up PDR.

---

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| Final product name (replacing codename "Lately") | Product / Brand | Must resolve before Phase 1 exit. Trademark search required. |
| Final consumer brand and aesthetic register (anime/cozy register specifics, visual identity, copy voice) | Product / Brand | Brand engagement deliverable. Parallel to Phase 0. |
| Soft-launch fandom — Letterboxd-adjacent (recommended) vs. backup (BookTok / indie-music) | Product | Default proposed: Letterboxd-adjacent. Backup commitment before Phase 3 begins. |
| Specific community partnerships for soft launch | Product | Identify 2–3 candidate partners during Phase 1. |
| App-store IAP vs. Stripe for paid tier (or hybrid) | Product / Architecture | Default proposed: app-store IAP for iOS / Android (Apple and Google require it for digital goods). Stripe is not viable for in-app subscriptions on iOS. This locks Lately into app-store cut economics. |
| Final repo name for the Node and the mobile client | Architecture | Aligns with final product name. |
| Hardcover tier name (final naming — "Hardcover" is a working name) | Product / Brand | Parallel to brand engagement. |
| Optional one-time boosts — included at v1 or deferred to v1.5 | Product | Default proposed: deferred. v1 ships with Free + Hardcover only. Boosts add complexity to onboarding and risk tier-stacking perception. |
| Item canonical ID provider commitments — Hardcover (paid) vs. Open Library (free) for books | Architecture | Default proposed: start with Open Library. Hardcover only if Open Library coverage is materially insufficient for the soft-launch fandom. |
| In-app DM scope — text-only at v1 vs. media-allowed | Product / T&S | Default proposed: text-only at v1. Media-allowed expands moderation surface and is a v1.5 decision. |
| Match-handoff to third-party platforms — explicit ("share to Instagram") vs. implicit ("here's their handle") | Product / T&S | Default proposed: explicit-but-optional. Users opt to share an external contact post-match. Privacy-first. |
| Whether to include geographic distance in The Room cohort selection | Product | Default proposed: metro-area-derived cohort with regional fallback when item density is low. |
| 30-day refresh — hard hide vs. soft deprioritization | Product | Default proposed: hard hide (after 30 days, profile is invisible until refreshed). Tunable based on early activation data. |
| App review — iOS vs. Android first | Operations | Default proposed: iOS first by 2 weeks. iOS is more conservative on connection-app review and the buyer demographic skews iOS-heavy in early-adopter cohorts. |
| Brand domain and naming — separate consumer brand domain | Product / Brand | Required before public launch. Concrete domain decision is a brand-engagement output. |
| GDPR / CCPA legal posture — counsel review | Legal | Solo dev does not have counsel on retainer. Engagement with privacy-specific legal review before public launch is required. |
| Whether Lately's engine is open-source at any layer | Architecture | Default proposed: closed at v1. Re-evaluate if the engine has reusable primitives that future Apps-sector products would benefit from. |

---

## Recommended Follow-Up Artifacts

| Artifact | Type | Purpose |
|---|---|---|
| `HoneyDrunk.Lately` standup ADR | ADR | Stands up the new Node per the standup-ADR convention. Names package families, downstream coupling rule, contract-shape canary, dependency surface. |
| `HoneyDrunk.Lately.Mobile` standup ADR | ADR | Stands up the mobile client repo. React Native + Expo decision, iOS + Android targets, build pipeline, OTA update posture, App Store / Play Console accounts. |
| Consumer-app taxonomy ADR | ADR | Decides whether consumer apps stay in Market or get a dedicated Apps sector/sub-sector. Defines boundaries (consumer products do not expose Grid metaphors; consumer Nodes consume Core / Ops Nodes; app Nodes own consumer brand surfaces). |
| Notify push channel ADR | ADR | Adds APNS + FCM provider integrations to Notify. Pull-forward from the v1.5 deferral in PDR-0002. Defines push-quiet-hours and push-frequency preferences in Communications. |
| Item canonical ID adapter ADR | ADR | Provider-slot pattern for item resolution: TMDB, Open Library, Hardcover, MusicBrainz, Spotify. Defines `IItemResolver` contract and adapter shape. |
| Lately T&S architecture ADR | ADR | Defines the moderation queue, AI-triage flow, human-review SLA, auto-action triggers, photo moderation pipeline, and reports-per-DAU thresholds. |
| Lately consumer brand engagement design doc | Design doc | Output of the brand exercise: final product name, visual register, marketing copy voice, domain. |
| Lately mobile UX design doc | Design doc | The Room UX, fingerprint gesture interaction, currents shelf composition flow, profile card visual hierarchy. |
| Lately privacy policy and ToS | Legal | Before public launch. GDPR / CCPA review. App-store-compliant. |
| Lately retrospective PDR (conditional) | PDR | If Lately is killed at the 90-day bar, the retrospective PDR documents what the wedge missed and informs future Apps-sector decisions. |
| Lately v1.5 / v2 PDR (conditional) | PDR | If Lately clears the 90-day bar, the next PDR scopes v1.5 (in-app messaging media, voice notes, IRL events) or v2 (multi-fandom expansion, geographic expansion, AI-driven matchmaking). |

---

## Next Steps

Concrete decisions the user must settle before any code or design work begins:

1. **Confirm Lately as a committed product line, not an exploration.** This PDR is Proposed. Acceptance — by the user, after sleeping on it — is the gate. If the user is not fully committed to dual product lines (Notify Cloud + Lately) under a solo-dev operating model, the right answer is to defer Lately to a future PDR rather than start work on a half-committed product.
2. **Confirm calendar-protected sequencing.** Notify Cloud public launch (2026-09-15 target) precedes Lately work. No Lately code begins before Notify Cloud is live. The user must agree to this sequence explicitly — otherwise the burnout risk is not adequately mitigated.
3. **Commission the brand engagement.** Final product name, visual register, marketing copy direction. This is non-coding work that can run in parallel with Notify Cloud's pre-launch phases. The brand engagement deliverable is required before Phase 1 exit.
4. **Confirm soft-launch fandom commitment.** Letterboxd-adjacent (recommended) or backup. The partnership identification work begins as part of the brand engagement.
5. **Confirm tech stack.** React Native + Expo + .NET on the Grid (recommended). The user must confirm this choice before Phase 1 begins.
6. **Confirm the cuts list (§G).** Particularly: no in-app messaging beyond minimal handoff at v1, no video, no voice notes, no AI matchmaking, no annual discount. If any of these are non-negotiable additions for the user, the v1 scope and timeline change materially.
7. **Confirm pricing wedge non-negotiables.** Free tier with all core features, no swipe limits, no pay-to-see-likes-as-the-product (Hardcover sees who fingerprinted you, but the wedge is asymmetric reveal not artificial gating). The user must confirm this is a non-negotiable design constraint, not a default that drifts.
8. **Confirm the kill criteria (§K).** 5K DAU at 90 days, median Room density ≥3, ≥1% paid conversion, no unmanageable T&S class. The user must commit to acting on these criteria in advance — saying yes now and rationalizing past them at month 3 is the failure mode.
9. **Confirm legal counsel engagement before public launch.** Privacy policy, ToS, GDPR / CCPA review. Solo dev does not have counsel; this engagement must be scoped and committed before Phase 4.
10. **Confirm Notify push pull-forward as a hard prerequisite.** Notify push channel ships before Lately mobile client begins push integration. This pulls forward work that PDR-0002 deferred. The user must agree explicitly.

Once these decisions settle, the next concrete artifacts are:

- The `HoneyDrunk.Lately` Node standup ADR
- The `HoneyDrunk.Lately.Mobile` repo standup ADR
- The consumer-app taxonomy ADR
- The Notify push channel ADR

Delegation: ADRs to the `adr-composer` agent. Repo work and scaffold packets to the `scope-agent`. Brand engagement is human-led, not agent-led.
