# PDR-0005: Hearth — Personal Growth as a Living Town

**Status:** Proposed
**Date:** 2026-05-05
**Deciders:** HoneyDrunk Studios
**Sector:** Market / AI / Ops
**Codename:** Hearth (final product name TBD; previous codename was *Yuki*)
**Framing:** Personal growth / self-improvement town. Journaling is one input, not the whole product.

---

## Context

The self-improvement app market is saturated at both obvious ends of the aesthetic spectrum. The cozy lane is full of journaling pets, mindfulness mascots, and soft habit trackers. The go-hard lane is full of Solo-Leveling-style discipline apps: quests, XP, stats, avatars, rankings, streaks, and grind language. Both lanes have demand, but both are crowded enough that a new entrant cannot win by being merely prettier or more anime.

Hearth's revised wedge is not "anime self-improvement" and not "journaling with a town." Hearth is a **personal growth app where the user's inner and outer life gradually builds a living town**. Journaling is one meaningful input, but so are goals, routines, walks, reading, creative sessions, reflection prompts, small acts of repair, and manually logged milestones. The product turns self-improvement away from dashboards and grind into place-making: your life becomes a town you want to return to.

The core critique of the category still stands. Most self-improvement apps convert a human life into compliance metrics: streaks, XP, daily tasks, guilt notifications, red missed-day states, and charts that make growth feel like work surveillance. Finch softens that with a pet. Solo-leveling apps intensify it with power fantasy. Hearth chooses a third lane: **growth without shame, progression without grind, game-feel without pretending life is an RPG stat sheet**.

Hearth's emotional moat is the town. The town grows when the user makes meaningful deposits into their life — not only when they write reflective entries. A bookshop may open because the user has been reading consistently. A workshop may appear because the user keeps shipping creative work. A garden may recover because the user has been taking care of their body. The post office, run by Tomoe, responds to reflective entries. Weather and palette respond to emotional tone, but buildings and civic life respond to broader growth signals.

This keeps the original soul of Hearth while answering the operator's product concern: if the user does not see himself opening a pure journaling app, the product should not be a pure journaling app. The more durable bet is a **life-building companion with journaling as its reflective core**, not a diary app competing head-on with Day One.

This is Scout's first-build pick of the consumer concepts (Lately, Wayside, Hearth), revised into a broader consumer wedge. It still wins on three filters PDR-0002 used for Notify Cloud's selection: **(a)** no two-sided marketplace problem — Hearth produces value with a single user on day one, **(b)** clean revenue shape — subscription + print-on-demand book/artifact + lifetime tier, no ad model, no marketplace cut, and **(c)** AI-native build profile — constrained characters, on-device classification, town progression, and narrative reflection are the parts of the product an AI-agent-collaborated solo dev studio is unusually good at building.

This PDR commits the studio to Hearth as the **first consumer-facing app on the Grid**, complementing PDR-0002's commercial-developer-tools wedge (Notify Cloud) with a commercial-consumer wedge for regular people.

---

## What It Does

In plain language: **Hearth is a personal growth app where your life builds a small, watercolor town.** The user does not level up an avatar; the town changes because the user is becoming someone. Journaling matters, but it is one of several inputs. The app accepts:

- **Reflections** — typed journal entries, short check-ins, letters to self, voice/handwriting later.
- **Goals and practices** — user-defined intentions such as "move my body," "read before bed," "ship creative work," "cook more," or "reach out to friends."
- **Small wins and milestones** — manually logged moments that do not fit a habit checkbox.
- **Creative work sessions** — writing, coding, drawing, music, study, or making.
- **Care actions** — sleep, walks, cleaning, recovery, social connection, therapy/doctor appointments if the user chooses to track them.
- **Media/currents** — books, shows, albums, games, or ideas currently shaping the user's inner weather.

Those inputs become town changes. A library expands as reading and learning accumulate. A workshop warms when creative sessions recur. A garden, bathhouse, shrine, gym, or market may appear as the user invests in different parts of life. NPCs do not say "you completed 7/7 tasks." They notice the town: "The workshop lanterns have been on late this week." The product frames growth as lived texture, not compliance.

Journaling remains the reflective core. The weather in the town responds to the *tone* of reflective writing — anxious entries make the snow heavier, joyful entries pull cherry blossoms in early, anger churns a thunderstorm into a winter sky. But the town's civic growth responds to the broader pattern of life inputs. This separation is important: **mood shapes atmosphere; action shapes the town.**

One NPC, **Tomoe**, runs a small post office. She reads the user's reflective entries only with explicit opt-in and writes letters back, one or two times a week. Tomoe is a literary character first, never a therapist, never a chatbot, never a productivity coach. There is no input box to talk to her. She just writes.

Real weather syncs with the user's local weather; time of day syncs with the user's local time. Sunset in the town is sunset where the user is. The town is designed mobile-first: portrait view, readable one-thumb interactions, tappable buildings, short scenes, and a home-screen widget that can show the town's current weather without demanding action.

Old entries and milestones surface organically — paper boats float down the river carrying a line from a year ago, festival lanterns light with a completed goal, a shopkeeper mentions a project the user returned to after months away. Users can seal letters to their future selves; the letters appear, with a watercolor stamp, on the day they chose.

Friends' towns are visible on a regional map in v2. The entire social mechanic is **postcards** — a small watercolor view of your town and a written note. Friends never see the journal, goals, or raw growth data. The mechanic is asynchronous, low-stakes, and aesthetically consistent with the rest of the product.

There are no streaks. There are no points. There are no leaderboards. The town gets quieter when the user is away, but that is a *response*, not a punishment, and the language never frames it as one. Returning is always welcome.

The pain it solves: *"I want to get better at being a person, but every self-improvement app turns my life into homework or a stat grind."*

How it sits next to the field:

- **Finch** — warm self-care pet, but still task/check-in driven; the pet is the center.
- **Habitica / solo-leveling apps** — quests, XP, stats, grind; motivating for some, but crowded and often shame-adjacent.
- **Day One / Journey / Stoic** — journal-first; strong archive/reflection, weaker progression/world layer.
- **Daylio / mood trackers** — charts and stats first; useful but emotionally sterile.
- **Notion / Apple Notes / Things** — flexible capture/task tools, but no emotional/narrative return surface.
- **Hearth** — watercolor town that grows from reflections, goals, care actions, and creative effort; game-feel without XP grind; no streaks, ever.

---

## Problem Statement

### 1. Self-improvement apps are split between cozy shame and grind fantasy

The cozy lane tells the user to be gentle, then quietly tracks whether they showed up. The go-hard lane tells the user to become a monster, then translates ordinary life into XP, quests, ranks, and missed-day penalties. Both can work for certain users, but both are saturated and both center compliance. Hearth needs a third lane: progression that feels meaningful without turning the user into a spreadsheet or an anime stat block.

### 2. Pure journaling is too narrow for the operator's own pull

The original Hearth concept was strong, but too journal-shaped. If the builder does not personally see himself opening it, that is not a small warning sign — it is product signal. Hearth should preserve journaling as the trust-and-reflection core while broadening the daily use case into personal growth, creative momentum, care, and life-building. The user should be able to open Hearth even on a day when he has no desire to write a diary entry.

### 3. The category has no aesthetic differentiation worth its category size

Day One has the best polish; Finch has the best charm; solo-leveling apps have the clearest power fantasy. Beyond those, the category's visual language is dashboards, charts, flat icons, mascots, or stat screens. For a category whose product is a person's attempt to live better, this is under-designed. Hearth occupies the gap: a self-improvement app whose *place* is the product, in the way a beloved game town or anime setting can become emotionally sticky.

### 4. AI-driven self-improvement features are being built by everyone, badly

AI coaches, prompt generators, habit summaries, and chatbot therapists are easy to bolt on and hard to trust. Hearth's opportunity is to build AI features that are **constrained, literary, and trustworthy** rather than chat-shaped. Tomoe is the headline example: an LLM-driven character with hard guardrails, no chat surface, no advice, written letters with deliberate cadence. The town engine is the second example — models the user mostly never sees, quietly translating reflection and chosen activity into atmosphere and growth.

### 5. The studio needs a consumer wedge

PDR-0002 commits the studio to Notify Cloud as the developer-tools wedge — clean SaaS revenue, technical buyer, narrow segment. This is correct for that segment but does not exercise the AI sector at consumer scale, does not produce a build-in-public consumer-narrative artifact, and does not give the studio's brand pull outside the .NET indie dev community. Hearth complements Notify Cloud: different buyer, different emotional register, different forcing function on the Grid.

Hearth is the consumer wedge.

---

## Decision

### A. Hearth is committed as the first consumer-facing app on the Grid

Hearth is committed as a multi-platform (iOS first, Android second) consumer app, built as a new product surface inside the HoneyDrunk Studios brand. It joins Notify Cloud (developer wedge, per PDR-0002) as a parallel commercial product, not a successor — they share infrastructure (Auth, Vault, Notify, Communications, Pulse) but target different audiences, run on different release cadences, and live under separate sub-brands.

Hearth is proposed as a consumer product in the canonical **Market** sector. This PDR uses **Apps** as a working portfolio label for consumer-facing product surfaces (Hearth, future game/app candidates), but does not amend the sector taxonomy itself. A follow-up constitution amendment can decide whether Apps becomes a dedicated sector/sub-sector or remains a Market portfolio.

### B. Hearth is a personal-growth town, not a pure journaling app

This PDR supersedes the narrower framing of Hearth as "journaling as a living town." The selected framing is **personal growth as a living town**. Journaling remains the reflective core, but the daily product surface includes goals, practices, creative sessions, care actions, milestones, and chosen currents.

The product model separates inputs into two classes:

1. **Atmosphere inputs** — reflective writing and emotional check-ins. These shape weather, palette, quietness, seasonal drift, and Tomoe context.
2. **Growth inputs** — goals, practices, care actions, learning, creative work, and milestones. These shape buildings, NPC availability, civic events, town districts, and long-term progression.

This prevents Hearth from becoming either a diary with decorations or a habit tracker with watercolor skin. The town is the synthesis layer: mood shapes how the place feels; action shapes what the place becomes.

### C. The "no streaks, ever" thesis is non-negotiable

The single largest UX decision Hearth makes is the one it refuses. There are no streaks. There are no points. There are no badges. There are no daily-prompt push notifications styled as encouragement. There are also no combat stats, ranks, leaderboards, or solo-leveling power ladders.

The product's response to absence is a quieter town. The shops are dimmer at dusk. The streets have less foot traffic. NPCs go about their lives but don't seek the user out as actively. **The town's quietness is descriptive, not evaluative.** The user is never told "you missed yesterday." The town is just quieter, in the way a real town is quieter when you've been away.

This is non-negotiable. Any future scope-pressure to add streaks or XP grind ("but they really do drive retention…") is rejected at the PDR level. If retention requires shame, streaks, or stat-grind mechanics, Hearth's thesis is wrong and the product should be sunset before the mechanic is introduced — preserving the architectural invariant is a hard rule, not a decision point. See §L (Decision Points and Hard Rules).

The corollary: Hearth's retention model cannot rely on engagement-metric forcing functions. Retention has to come from emotional resonance, visible town growth, Tomoe's letters, NPC arcs, anniversary mechanics, and the Yearly Artifact ritual. This is harder than streak-driven retention, and it is the bet.

### D. Tomoe is the headline differentiated character feature, with hard guardrails

Tomoe is a recurring NPC who runs the post office in the town. She reads the user's reflective entries (with explicit consent at onboarding) and writes letters back, **one to two times per week, asynchronously, on a cadence the model picks within a configured window.** The letters appear in the user's in-town mailbox.

#### Persona

Tomoe is a literary character: late-twenties, kept her childhood handwriting, runs the post office in a small town, reads novels in the back room when no one is in. She is **observant, gentle, present, sometimes a little melancholy, sometimes funny.** She notices things — the user mentioned a recipe their grandmother made; she writes about a recipe she found in a cookbook her grandmother left her. She is not a mirror. She has her own life, and she lives it in the letters.

#### Hard guardrails — what Tomoe will NEVER say

- No advice. ("You should…", "Have you tried…", "It might help to…" — banned at the prompt level.)
- No diagnosis or pathology language. (Anxiety, depression, trauma, disorder — never named.)
- No therapeutic framing. ("Have you considered talking to someone about this?" — banned, except in a single specific case below.)
- No flattery. ("I love how thoughtful you are." — banned.)
- No excessive mirroring. (Tomoe does not summarize the user's writing back to them; she reads it and lives her own day adjacent to it.)
- No claim to be a friend, family member, or therapist. She is a pen pal, in the literal pre-internet sense.
- No claim to be human, if asked directly. (See §K trust posture.)

The single exception to "no therapeutic framing" is a **safety routing path** for entries that contain explicit self-harm or crisis indicators. In that case, Tomoe does not write a letter at all — the system instead surfaces a gentle, non-Tomoe-shaped resource card with crisis-line numbers for the user's locale. This path is owned by a separate safety model (a small classifier running on-device or via a constrained API call), not by the Tomoe generation prompt. **Tomoe is never the surface for crisis response.** Conflating them is the failure mode that ruins similar products.

#### Generation cadence and context window

- **Cadence:** 1–2 letters per week, on a schedule Tomoe picks within a configured window. The user can adjust the cadence in settings (off, weekly, twice-weekly).
- **Context window per letter:** the user's last ~7–14 days of reflective entries, with the on-device theme tracker's running summary of longer-term threads. Older reflective entries are not in the context window — Tomoe is responding to recent writing, not the user's life history.
- **Output length:** 150–400 words, hand-lettered-feeling typography. Letters arrive with a watercolor stamp, dated, addressed to the user by their chosen town name.
- **Generation:** server-side via the AI Routing layer (per PDR-0001). Default model is a frontier-class instruction-tuned model with a strong system prompt; the routing layer's task classification will tag this as `creative-letter` and route accordingly. Cost per letter is meaningful at scale and is a key margin variable (see §I pricing).

#### On-device vs. cloud for Tomoe

Tomoe's letters are generated **server-side**, not on-device, for v1. Reasons:
- The letter quality bar is high; the smallest on-device models that produce literary-quality letters (Apple Intelligence Foundation, Gemini Nano, Phi-4-mini) are not yet at the bar Tomoe needs in 2026.
- Generation happens 1–2x per week, asynchronously. There is no latency requirement that demands on-device.
- The privacy posture (see §K) explicitly discloses that reflective text leaves the device for Tomoe generation, with end-to-end encrypted transport, no retention beyond the generation window, and clear user consent. **This is the most consequential trust trade-off in the product** and the disclosure is loud.

If on-device foundation models reach Tomoe's quality bar within 12–18 months (plausible — the trajectory is steep), the v2 evaluation is to move Tomoe on-device for the privacy upgrade. The architecture allows this swap because Tomoe is a consumer of `IModelRouter` (per PDR-0001), and the routing policy is the only thing that changes.

#### Trust posture — what if Tomoe says something that hurts?

This is a real risk. Hearth's user base, by the nature of the product, will skew toward people processing difficult things in their reflective writing. A tone-deaf or sharp letter from Tomoe — even a well-intended one — can land as a wound.

Mitigations:
- **Per-letter pre-publish review.** Each generated letter is run through a second-pass safety/tone evaluator before it appears in the mailbox. The evaluator checks against the guardrails above and against a tone bar (no flippancy, no false certainty, no advice). Failed letters are regenerated; persistent failures are silently dropped (no Tomoe letter that day; user does not know).
- **In-app flag + apologize flow.** Every Tomoe letter has a tiny ribbon at the bottom — "this letter didn't land right" — that quietly removes the letter from the user's mailbox, replaces it with a short apology card from Tomoe ("I think I missed you yesterday — I'll try again next week"), and ships the flagged letter (without journal context, just the letter) to a triage queue for review. The flag is non-judgmental: clicking it does not require a reason.
- **User control over Tomoe.** A single setting: "pause Tomoe's letters." On by default at install (Tomoe is opt-in, see §D trust). Off freezes letter generation; on resumes it. No streaks, no count of paused weeks.
- **Tomoe is opt-in, not default-on.** The user explicitly opts into Tomoe reading their reflective entries during onboarding, with a clear plain-language explanation of what she does, what hard rules she operates under, where the generation happens (server-side), and that she is a fictional character generated by an AI model. The opt-in is per-user, not per-tier; Hearth Snow subscribers can decline Tomoe and still get the rest of the tier.

### E. The town engine combines on-device sentiment with user-owned growth signals

The mechanic that maps "anxious entry" to "heavier snow" and "creative work returning" to "the workshop lights coming back on" is the second-most-differentiated feature. It needs to feel magical and never feel surveilled.

#### On-device, always

The sentiment classifier runs on-device. It reads the user's reflective text, produces a multi-axis sentiment vector (valence, arousal, dominance, plus a small set of categorical labels: grief, anxiety, joy, anger, gratitude, fatigue, hope), and emits a per-entry signature. The signature feeds the town's atmosphere engine. Separately, user-owned growth inputs — goals, practices, care actions, creative sessions, milestones — feed the town progression engine.

**The raw reflective text never leaves the device for sentiment analysis.** Only the resulting environment cues — "set today's atmospheric weight to 0.7," "shift the palette toward blue," "cue heavier snowfall" — are persisted into the town's state, and only the *environment cues* (not the sentiment vectors that produced them) are visible to any cloud surface. This is the privacy floor.

#### How the mapping works

The mapping from sentiment → environment and growth input → town progression is deterministic and designer-authored. It is not an LLM. It is a set of rule tables:

- High arousal + negative valence + anger label → thunderstorm cue, palette shift toward grey-violet.
- High arousal + positive valence + joy label → palette warming, cue an unscheduled cherry-blossom day.
- Low arousal + negative valence + grief label → snowfall heavier, palette muted, NPCs quieter.
- Low arousal + positive valence + gratitude label → golden-hour light extended, palette warmed.
- Fatigue label → world rendering speed slows fractionally; NPC movement softens.
- Three creative sessions in a week → workshop lanterns stay lit; maker NPC appears more often.
- Reading/learning current active for multiple weeks → library shelf expands; bookshop event unlocks.
- Care actions recurring gently → garden recovers; bathhouse steam returns; food stall opens.
- A completed personal milestone → festival lantern or bridge repair appears as a permanent town mark.

The mapping is hand-tuned by a small team (designer + writer + the user) over weeks of iteration. The output is a deterministic, testable, auditable mapping — not a generative function. This is intentional: a generative environment engine would be unpredictable, hard to evaluate, and risk producing tone-deaf juxtapositions. A rule table is boring and right.

#### Why the user doesn't notice it directly

The town's atmosphere drifts continuously, never abruptly. A single anxious entry does not summon a thunderstorm; it nudges the atmospheric weight by a small amount. The user experiences the town as moody and alive, not as a surveillance dashboard. The first time they realize it ("oh — I had a hard week, and the snow has been heavier") is the magic moment.

The product does not surface "your sentiment this week" charts or "you completed 83% of your habits" dashboards. It does not produce a mood-summary or productivity report. The dashboard view, if it exists at all, is the town itself — visited, walked through, looked at. **There is no weekly sentiment report.** That is the line that separates Hearth's mechanic from the surveillance-aesthetic of every existing journaling-with-mood-tracking app.

### F. NPC multi-month arcs are hybrid: pre-authored arcs + theme-aware selection

Five or six recurring NPCs each carry a multi-month thematic arc. Themes include: loss, family, change, joy, fear, beauty, work, friendship, longing. Each NPC's arc is a hand-authored, branching narrative (a baker losing her mother and slowly rebuilding her shop; a young man returning from a long trip and figuring out what changed at home; a retired teacher writing letters to a former student). Arcs progress in chapters; each chapter has a theme tag and a tone signature.

The system selects which NPC arc to advance, and which chapter, based on a **theme and growth tracker** that runs on-device:

- The theme tracker is a small on-device clustering model that periodically (weekly) summarizes the user's recent reflective entries into a small set of theme weights — what the user has been writing about most, with what emotional weight. The growth tracker is a deterministic local summary of the user's selected goals/practices/milestones — what they have been trying to build, without judgment language.
- The theme and growth weights, plus a lightweight randomization, drive arc selection: when a chapter is due, the system picks the NPC whose next chapter's theme tag is most adjacent to the user's current theme weights. *Adjacent* — not matching. The arcs orbit; they do not echo.
- Arc dialogue and gifts are pre-authored for v1. Generative dialogue per-arc is a v2+ exploration; the editorial control of pre-authored arcs is too valuable to give up at v1.

This is a hybrid: pre-written content + theme-aware selection. The hybrid lets the studio control quality (no tone-deaf NPC dialogue) while making the experience feel personalized.

#### Authoring tooling

Building NPCs at this quality bar requires authoring infrastructure. The studio commits to building, alongside the app:

- An **NPC arc authoring tool** (likely an internal web app inside HoneyDrunk Studios) for writing and tagging chapters, branching paths, and gifts.
- A **theme taxonomy** maintained as a versioned document — what counts as "loss," what counts as "joy," and how the on-device classifier maps to this taxonomy.
- A **dialogue review process** — every chapter is read aloud at least once before it ships. The voice has to feel right.

This is editorial work. It is the part of the product the AI cannot ship for the studio; it is the part the human writer ships, with AI assistance.

### G. The Yearly Artifact is sacred

The Yearly Artifact starts as a print-on-demand hardcover compiled from the user's year of reflections, milestones, town changes, and selected photos. It is offered as a separate purchase at $34, available to any user (Free or Hearth Snow) who has accumulated enough entries to make it meaningful (say, 30+ entries across the year).

The Yearly Artifact is the year-end ritual. It must feel sacred.

#### Contents

- **Cover:** custom watercolor illustration of the user's town as it stood at the year's end. Generated via the same art pipeline that renders the in-app town views, exported at print resolution.
- **Frontispiece:** the user's chosen town name, the year, a single watercolor vignette.
- **The reflections:** selected entries and milestones typeset to a printable book layout. Photos appear inline. Handwritten entries (from tablet input) appear as image inserts on textured paper. Voice entries are transcribed cleanly and noted as "spoken on [date]."
- **NPC interludes:** between months, a one-page vignette from one of the NPCs whose arc was active that month. Hand-authored, not generated. The interlude reflects the town's life that month, not the user's writing.
- **Tomoe's closing letter:** the final spread is a letter from Tomoe, generated from the year's themes. This letter is generated with a higher-quality, more deliberately constrained pipeline than her weekly letters — it is reviewed by a tone evaluator with a tighter bar, and the letter has a maximum length of one printed page. The user can preview and approve the closing letter before the book ships.
- **Colophon:** a single page at the back, naming the year, the town, the user's chosen name. Quiet, formal, real.

#### Production

- **Print-on-demand provider:** Lulu, Blurb, or Printify Pro at v1 (decision deferred — see §Open Questions). Quality bar: hardcover, sewn binding, 80–100lb cream paper, 6×9 inch trim, full-color watercolor cover. Lulu's photo book line meets this bar at a unit cost in the $10–14 range per book.
- **Margin:** $34 retail – ~$12 production – ~$3 shipping (US) – Stripe fees ≈ $17 gross margin per book. International shipping reduces margin; the price is a flat $34 with a soft cap on international destinations or a $4 international upcharge (TBD).
- **Cadence:** the book is offered in early January for the previous year. The user has a 60-day window to order. Each user can order one book per year as part of the ritual; additional copies (gifts) are at the same $34 price.

#### Why this matters

The Yearly Artifact is the **highest-LTV product in Hearth's catalog** at modest scale. A user who renews their Hearth Snow subscription for $54/year and orders a Yearly Artifact at $34 is an $88 LTV-per-year customer. A user who only renews is $54. A user who only buys the Yearly Artifact (free Hearth tier + book) is $34. The book is the upsell that doesn't feel like an upsell, because it is a tangible artifact of the year — a thing the user wants to have, not a feature gate.

It is also a **brand artifact.** The Yearly Artifact is what Hearth produces, in the world, that no other self-improvement app produces. A user who has the book on their shelf is a user who tells a friend about Hearth.

### H. MVP scope — what ships in v1

Aggressive cuts. The fastest path to a v1 buyer-shaped surface is the smallest v1 that holds the thesis.

**In v1:**

- iOS app (SwiftUI). Android deferred to v1.5.
- Typed reflections and short check-ins. (Voice and handwriting deferred to v1.5+.)
- Lightweight goals/practices/milestones: user-defined, optional, no streak counters, no red missed states.
- Creative-session and care-action logging as first-class inputs.
- Photo attachments inline in reflections and milestones; photos appear inside the user's in-town house view.
- The town renders. Day/night cycle. Real local weather sync. Seasonal palette. The user's house and 5–7 buildings.
- **2 recurring NPCs**, each with a 12-week pre-authored arc. (Down from the full 5–6 — the cuts are deliberate.)
- Town engine v1: on-device sentiment classifier for atmosphere + deterministic growth-input rules for buildings/events. This is in v1 — it is half the moat.
- Anniversary mechanics (basic): "On this day last year" surface every entry on its anniversary, framed as a paper boat on the river.
- Hearth Free tier: 2 NPCs, full town with sentiment + growth engine, no Tomoe, no Yearly Artifact offer.
- Hearth Snow paid tier: same plus Tomoe (1 letter/week at this tier — full 1–2/week comes in v1.5), Yearly Artifact offer, eventual friend towns at v2.
- Onboarding flow: town name, season-of-arrival, optional house customization, Tomoe opt-in.
- Privacy disclosures: clear, plain-language, in-app at signup and revisitable in settings.

**Explicitly cut from v1:**

- Tomoe at full cadence (v1 is 1/week; v1.5 is 1–2/week with the second letter being the Yearly-Book-style higher-quality pipeline).
- Voice journaling and tone analysis (v1.5+).
- Handwritten journaling on tablets and OCR (v2).
- The remaining 3–4 NPCs (added one per quarter post-launch).
- Friend towns and postcards (v2 — the social mechanic is the second-most-risky surface; it needs careful design and waits until v1 is stable).
- The Yearly Artifact itself (v1 markets it as "coming this December" — the book is built and shipped in time for the first January after launch, not at launch).
- Future-self letters with sealed delivery (v1.5).
- Lanterns at festival time (v1.5 — seasonal feature, ships when the season hits).
- Generative NPC dialogue (v3+ if ever).
- The Founding Townsfolk lifetime tier (v1 launch; capped at 1000 — see §I).

This is the smallest v1 that holds the thesis. The town renders, the sentiment + growth engine works, two NPCs live their lives, Tomoe writes once a week, and the user is told a Yearly Artifact is coming. That is the product.

### I. Pricing structure

| Tier | Price | What's included | Notes |
|---|---|---|---|
| **Hearth Free** | $0 | 2 NPCs, full town, sentiment + growth engine, real-weather sync, basic anniversary mechanics. No Tomoe. No Yearly Artifact offer. | The Free tier is real, not a trial. The user can use Hearth indefinitely without paying. The town is the same town; Tomoe is the gate. |
| **Hearth Snow** | $6.99/mo or **$54/yr** | Everything in Free, plus Tomoe (1 letter/week at v1, 1–2/week at v1.5), Yearly Artifact offered, future-self letters (v1.5), friend towns and postcards (v2), all NPCs as they ship. | Annual pricing intentionally anchors at $54 — between Day One ($35), Finch ($40), and Stoic ($50). Cheap enough for an indie consumer subscriber, expensive enough to fund Tomoe's per-user generation cost. |
| **Yearly Artifact** | $34 (one-time per year) | Print-on-demand hardcover of the user's year of reflections and growth. Tomoe's closing letter, NPC interludes, watercolor cover. | Available at year-end to any tier with sufficient entries. ~$17 gross margin. |
| **Founding Townsfolk** | $199 lifetime | All Hearth Snow features for life. Unique Founding Resident NPC visible in your town only — a lantern-keeper who lights an extra lantern each year on the anniversary of the user's signup. Limited to first 1000 customers. | **Funds early dev.** Caveats and limits in §J. |

#### Pricing intent

- **$54/year is the wedge price.** Day One Premium is $34.99/yr; Finch is $39.99/yr; Stoic is $49.99/yr; Journey is $44.99/yr. Hearth Snow at $54 is the most expensive in the band, and that is the right position — Hearth is producing more (Tomoe's letters cost real money to generate) and producing better (the aesthetic and emotional moat). Buyers who want cheap mood-tracking already have Daylio at $4. Hearth competes on quality, not price.
- **Free tier is the marketing engine.** The Free tier produces real value, which means real word-of-mouth. The Free user's town is as beautiful as the Snow user's town. The conversion from Free to Snow is gated on Tomoe and the Yearly Artifact — features that take time to want, not features the user immediately misses on signup.
- **The Yearly Artifact is the LTV multiplier.** At a 30% Yearly Artifact attach rate among Snow subscribers, the effective ARPU for Snow is $54 + (0.30 × $17) = $59.10. At 50%, it's $62.50. The book is the difference between Hearth being a $54 ARPU product and a $60+ ARPU product — meaningful at scale.
- **Founding Townsfolk funds early dev.** $199 × 1000 = $199K cap. Realistic capture in the first 6 months of launch is probably 200–500 ($40K–$100K), enough to fund 6–12 months of solo-dev-with-AI-agents work and offset Tomoe's per-user generation cost during the unprofitable early months.

### J. Founding Townsfolk lifetime tier — operational constraints

Lifetime tiers are dangerous. They are revenue today against a liability that compounds forever. Two operational concerns are non-trivial:

#### What "lifetime" means

The Founding Townsfolk tier promises "Hearth Snow features for life." Three honest constraints:

1. **For as long as Hearth exists.** If the studio shuts down Hearth, lifetime subscribers do not get a refund of pro-rata months — they paid for a service that is no longer offered, and the offering is over.
2. **For as long as the studio exists.** Studio bankruptcy, acquisition, or wind-down terminates the lifetime obligation. The terms of service must say this in plain language.
3. **For Hearth Snow at its v1 feature definition, plus reasonable evolution.** Future tiers above Hearth Snow (a hypothetical Hearth Premium with team/family features) are *not* covered by the Founding Townsfolk tier. This is the Spotify-Family-vs-Lifetime-Spotify problem; the terms address it explicitly.

The marketing copy and terms of service for Founding Townsfolk are reviewed by a lawyer before launch. **This is the only piece of v1 legal review that is non-negotiable.** Privacy policy, ToS, and the lifetime tier's wind-down terms.

#### Honest disclosure in marketing copy

The Founding Townsfolk tier's marketing copy says, in plain language: "If Hearth is around in five years, you'll have it. If Hearth shuts down, your purchase ended when the lights went out. We think it's worth the risk on our end and we hope you do too." This is the build-in-public stance applied to a commercial decision — buyers know what they're buying.

### K. Trust and privacy posture

Reflective entries, goals, care logs, and intimate photographs are among the most personal data a consumer app can hold. Hearth's privacy posture is a load-bearing feature, not a checkbox.

#### Data classification

| Class | Examples | Where it lives | Encryption |
|---|---|---|---|
| **Reflective text** | Every entry the user writes | On-device primary; encrypted-at-rest cloud backup if user enables sync (default on) | AES-256 at rest; TLS 1.3 in transit; end-to-end encrypted backups (key derived from user's account credential, not server-held) |
| **Sentiment signatures** | Per-reflection sentiment vectors | On-device only | N/A — never leaves the device |
| **Town environment/progression cues** | "Today's snow weight = 0.7", "workshop lanterns active" | On-device + cloud (sync) | Encrypted at rest |
| **Growth inputs** | Goals, practices, milestones, creative sessions, care actions | On-device primary; encrypted cloud sync if enabled | E2EE where content-like; encrypted at rest for metadata |
| **Photos** | User-attached photos | On-device + cloud (sync) | E2EE, same as reflective text |
| **Tomoe context (transient)** | The 7–14 day reflective-text window sent to the model for letter generation | Server-side only during the generation call | TLS 1.3 in transit; **not retained after generation** |
| **Tomoe letters** | The generated letters | On-device + cloud (sync) | E2EE |
| **Friend graph + postcards** | Friendship edges, postcards | Cloud | TLS in transit; postcards encrypted at rest |
| **Account metadata** | Email, billing | Cloud (Stripe + Auth) | Standard; Stripe-managed PCI |

#### The big disclosure

**Tomoe generation requires reflective text to leave the device.** This is the trade-off. Hearth discloses it loudly, in plain language, at three points:

1. At onboarding when Tomoe is opted into.
2. In the privacy policy, in a section titled "When Tomoe reads your journal."
3. In settings, where the user can pause Tomoe and read the explanation again.

The disclosure says: *"When Tomoe writes you a letter, your last week or two of reflective entries are sent to our generation service to give her the context she needs. The text is sent encrypted, used only to generate the letter, and not stored after the letter is written. The model that writes Tomoe's letters does not learn from your entries — they are not used for training. If you'd rather Tomoe not read your entries, you can pause her in settings, and the rest of Hearth still works."*

#### Data minimization

- **No analytics on journal content.** Hearth's analytics layer (Pulse) sees only structural events: app opens, reflections created (count + length, never content), growth inputs logged (type only, never text content), Tomoe letters delivered, town events. The content of entries is never an analytics dimension.
- **Search is on-device.** Server-side search across journal content would require server-side journal access. Search is not in v1; v2 search is on-device-only or e2e-encrypted-search (a research problem; deferred).
- **Export is unrestricted.** The user can export their entire journal at any time, in plain text + photos. This is a feature, not a churn vector.
- **Account deletion is real.** Account deletion deletes reflective text from cloud backup within 30 days, deletes Tomoe letter logs within 30 days, deletes the user's town state within 30 days. Stripe billing records are retained per regulatory requirements.

#### What the Grid contributes to this

- **Vault** stores the per-tenant encryption keys used by Hearth's backend.
- **Auth** validates Hearth user JWTs and (separately) the API-key path to Hearth's services from internal tools.
- **Notify** delivers the lightweight transactional emails (welcome, billing receipts, Yearly Artifact ready) — never journal content.
- **Communications** owns user notification cadence and quiet-hours logic.
- **Pulse** ingests structural-event telemetry, never content.
- **HoneyDrunk.AI / IModelRouter** routes Tomoe generation requests through the policy layer, with content not retained post-generation per the routing policy.

This is a non-trivial trust posture for a solo-dev studio. It is also the bar the product requires.

### L. Decision points and hard rules

Per `constitution/charter.md`, Hearth has **decision points** (evaluate and choose) and **hard rules** (act immediately if triggered). At each decision point the operator evaluates the signal and chooses one of three outcomes: **(a) extend / pivot**, **(b) drop to maintenance mode**, or **(c) sunset gracefully**. All three are valid.

**Decision points:**

1. **Registered users at month 6.** Target: ≥5,000. Below 5K signals the wedge or the marketing strategy is broken. Decision: pivot positioning and extend; extend soft-launch (invite-only) and defer public launch; drop to maintenance for existing users; or sunset. The 5K bar is a signal threshold, not an automatic terminator. Hearth's economics need volume eventually, but "eventually" can stretch in the workshop framing if the trajectory is alive.
2. **Free-to-Snow conversion at month 12.** Target: ≥3%. Industry baseline for high-quality consumer subscription apps is 3–8% (Headspace ~6%, Calm ~5%, Day One ~4–5%). Below 3% signals the Free tier is not producing funnel strength. Decision: adjust tier gating (gate a feature currently free); reduce Snow price; extend soft-launch for cleaner signal; drop to maintenance; or sunset.

**Hard rules (immediate action regardless of metrics):**

3. **Tomoe causes a real harm event.** A vulnerable user experiences a Tomoe-generated letter as harmful (not just disappointing) and the failure mode is one the guardrails should have caught. Single-event hard rule — not a frequency threshold. **Pause Tomoe across the user base while the failure mode is investigated;** sunset Hearth entirely if the failure mode cannot be resolved within constraint. The studio's reputation, and more importantly the user's wellbeing, are not negotiable. This is a safety bar.
4. **Founding Townsfolk legal exposure.** A regulator, lawyer, or state-AG inquiry about the lifetime tier raises a question the studio cannot answer satisfactorily. Withdraw the lifetime tier; refund recent purchases; revisit the structure.

**Soft review trigger:**

5. **Per-user gross margin negative at month 12.** If Tomoe + infrastructure cost per Snow subscriber exceeds $54/yr, pricing review. Likely lever: reduce Tomoe to 1/letter/week at the Snow tier, with 2/week as a higher tier ($89/yr) — segmenting the heavy users away from the price-sensitive subscribers.

### M. What does NOT change

- **The Grid's Core, Ops, and AI sectors.** Hearth is a consumer of existing Nodes; it is not a refactor of any of them.
- **The architectural invariants (1–36+).** No invariant is amended by this PDR. Hearth uses Auth, Vault, Notify, Communications, Pulse, and HoneyDrunk.AI through their published contracts.
- **PDR-0001's HoneyHub direction (as reframed by PDR-0002).** Hearth does not depend on HoneyHub. HoneyHub remains the internal control plane.
- **PDR-0002's Notify Cloud commitment.** Hearth does not delay or compete with Notify Cloud. They run in parallel under the same studio brand, on different release cadences, targeting different audiences. Hearth uses Notify (the engine, internally) for transactional emails — it does not consume Notify Cloud externally.
- **The solo-dev + AI-agents operating model.** Hearth is solo-shipped with AI-agent collaborators. No hiring is committed by this PDR. The art pipeline (see §Architecture) explicitly chooses approaches that fit the operating model.

---

## Options Evaluated

### Option 1: Status quo — no consumer app, focus the studio on Notify Cloud + Grid

**Description:** PDR-0002 commits to Notify Cloud. Don't add a consumer commercial product. Keep the Grid focused.

**Pros:**
- Maximum focus. Notify Cloud + the Grid is already a large-surface commitment.
- No consumer-product surface complexity (App Store reviews, support load from non-technical users, content moderation for the social mechanic).
- No exposure to consumer-AI trust failure modes (Tomoe).

**Cons:**
- The studio has no consumer brand pull. Build-in-public works for technical audiences; the studio's reach beyond .NET indie devs is zero.
- The AI sector's nine planned Nodes have no consumer-scale forcing function. Notify Cloud doesn't exercise them at all.
- Single-product-portfolio risk. If Notify Cloud lands on "sunset" at its 90-day decision point, the studio has nothing else in market.
- The studio's most differentiated capability — building constrained, character-driven AI features with editorial care — has no commercial expression.

**Verdict:** Rejected. Notify Cloud is the right developer wedge but is not the only wedge the studio should run. Hearth's economics, audience, and AI-sector forcing function are complementary, not competitive.

### Option 2: Build Lately (the second-ranked Scout pick)

**Description:** Ship Lately first instead of Hearth — a currents-based connection app for friendship/dating around books, shows, albums, and places.

**Pros:**
- Smaller scope than Hearth (no Tomoe, no NPC arcs, no sentiment engine).
- Faster to v1.

**Cons:**
- Weaker wedge. The "fragment capture" space is more crowded (Day One Notes, Apple Notes, Bear, Notion's daily notes).
- No emotional moat at Hearth's level. Lately is a quality of life upgrade, not a category redefinition.
- Lower price ceiling (capturing fragments is a $3-5/mo product, not a $6.99/mo product).
- Higher cold-start and trust risk. Connection apps need liquidity, safety, and moderation before the magic appears.

**Verdict:** Rejected. Lately is a fine product but not the right first consumer wedge. If Hearth succeeds, Lately is plausibly v2's second consumer product — a gentler entry point that funnels into Hearth.

### Option 3: Build Wayside (the third-ranked Scout pick)

**Description:** Ship Wayside first — a long-form route/walk journal with photo-and-route capture.

**Pros:**
- Highly differentiated. There is nothing exactly like Wayside.
- Strong tangibility (a printed walk map at year-end is a striking artifact).

**Cons:**
- Very narrow audience — people who walk regularly and want to journal them.
- Heavy device-feature dependency (GPS, route-tracking, battery management) that is a significant engineering effort for a solo-dev studio.
- Lower repeat-engagement; users walk in seasons, not daily.

**Verdict:** Rejected as first pick. Wayside is the most aesthetically distinctive of the three but the audience is the smallest. It is a candidate for v3+ when the studio has more capacity.

### Option 4: Build Hearth as a smaller v1 — town only, no Tomoe, no sentiment engine

**Description:** Ship Hearth's town-builds-itself mechanic, but defer the differentiated AI features to v2.

**Pros:**
- Faster to v1. Tomoe and the sentiment/growth engine are the two most expensive surfaces.
- Reduces the AI trust risk surface.

**Cons:**
- Loses both moats. Without Tomoe and without the sentiment/growth engine, Hearth is a cute town skin over a tracker. The town alone is not a defensible wedge; existing apps (Finch, Daylio with chibi avatars) occupy that adjacent space.
- The pricing thesis ($54/yr) does not hold without Tomoe. Snow tier becomes hard to justify.
- The build-in-public narrative is weaker — the AI features are what make the studio's contribution visible.

**Verdict:** Rejected. The differentiation lives in the combination. Cutting Tomoe and the sentiment/growth engine cuts the thesis.

### Option 5: Build Hearth with Tomoe and sentiment/growth engine, with aggressive scope cuts elsewhere — the v1 in §G *(Selected)*

**Description:** Ship Hearth iOS-first with Tomoe (1/wk at Snow tier), the sentiment/growth engine, lightweight goals/practices/milestones, 2 NPCs with 12-week arcs, real-weather sync, basic anniversary mechanics. Cut voice, handwriting, friend towns, and most NPCs from v1.

**Pros:**
- Holds the thesis. Both moats (Tomoe + sentiment-responsive town) ship at v1.
- Aggressive cuts make the scope solo-dev-feasible.
- Pricing tier is justified.
- AI sector forcing function is real.
- The Yearly Artifact lands in January, on the natural ritual calendar, ~3 months after a fall launch.

**Cons:**
- More ambitious than Option 4. Trust risk is real.
- iOS-only at v1 cuts ~half the consumer market.
- Authoring 2 NPCs at the quality bar is a non-trivial editorial effort.

**Verdict:** Selected. The cuts are aggressive enough to make v1 shippable; the surface that ships is enough to demonstrate the thesis. Android follows in v1.5.

### Option 6: Build Hearth as Android-first or cross-platform-from-day-one

**Description:** Ship Android first (or both platforms simultaneously) instead of iOS-first.

**Pros:**
- Larger global market on Android.
- Lower app-store revenue cut on Android (Google has been more flexible than Apple in 2025–26 on subscription cuts for some categories).

**Cons:**
- iOS audience over-indexes on the buyer profile (consumers willing to pay $6.99/mo for an aesthetic app; users who already pay for Day One, Finch, Headspace, Calm).
- Cross-platform from day one increases engineering scope ~1.6× and risks both platforms shipping at lower quality.
- Aesthetic-first apps disproportionately succeed on iOS first, then port (Halide, Things, Bear, Day One, Stoic, Finch — same pattern).

**Verdict:** Rejected. iOS-first is the right distribution wedge; Android in v1.5.

---

## Trade-offs

| Trade-off | Favored Position | Rationale |
|---|---|---|
| Streaks / XP grind (proven retention mechanic) vs. no-streak town growth (thesis) | **No streaks, no XP grind** | The thesis is non-negotiable. If retention requires shame or stat-grind mechanics, Hearth is wrong and should be sunset before betraying the differentiation — the architectural invariant is a hard rule. |
| Pure journaling app vs. broader personal-growth app | **Broader personal-growth app** | The operator does not personally feel pull toward a pure journaling app. Hearth keeps reflection as the core but expands daily use into goals, care, creative work, and milestones. |
| Tomoe server-side (quality) vs. Tomoe on-device (privacy) | **Server-side at v1, with loud disclosure** | On-device foundation models in 2026 do not yet meet the literary-quality bar Tomoe needs. The disclosure is the price. Re-evaluate at v2 as on-device models improve. |
| Generative NPC dialogue (personalized) vs. pre-authored NPC arcs (controlled) | **Pre-authored at v1** | Editorial quality is the moat. Generative NPCs at scale risk tone-deaf moments that breach trust. Hybrid (theme-aware selection of pre-authored content) preserves personalization without giving up control. |
| Friend towns at v1 (network effects) vs. friend towns at v2 (single-player on day one) | **v2** | The thesis works with one user. Friend towns introduce moderation, abuse, and trust surfaces that are second-order. Ship v1 single-player; layer the social mechanic on top once stable. |
| iOS-first vs. cross-platform | **iOS-first** | Audience over-indexes on iOS for aesthetic-first paid consumer apps. v1 quality > platform breadth. |
| Free tier as funnel vs. Free tier as marketing | **Both, leaning funnel** | Unlike Notify Cloud's Free-tier-as-watermark, Hearth's Free tier is real product the user can stay on. The conversion expectation is 3–8% over time, not the <5% that Notify Cloud's watermark accepts. |
| Yearly Artifact at $34 vs. cheaper-and-included | **$34 separate purchase** | The book is a ritual artifact. Bundling into Snow dilutes both the subscription's price defense and the book's specialness. The separate purchase reinforces the "this is an artifact" framing. |
| Founding Townsfolk lifetime tier (revenue now, liability forever) vs. no lifetime tier | **Lifetime, capped, with honest terms** | $40K–$200K of early-dev funding is meaningful at this studio's stage. The cap (1000) bounds liability. Honest terms ("if the studio shuts down, the offering ends") manage the obligation. |
| Sentiment data leaving the device (cloud server-side analysis) vs. on-device (privacy floor) | **On-device, always** | The sentiment engine is the surface the user is most likely to read as surveillance if the data leaves the device. The on-device commitment is a load-bearing piece of the trust posture. |
| Hand-authored NPC content (slow, expensive, editorial) vs. AI-generated NPC content (fast, cheap, scaled) | **Hand-authored, AI-assisted** | The voice has to feel right. AI can draft; the writer ships. This is the part of the product the AI cannot ship for the studio. |
| Real local weather sync (delightful) vs. always-narrative weather (controllable) | **Real local weather** | The day the user's first real rainstorm syncs with the town's first rainstorm is the magic moment. Worth the API integration cost. |
| Apple Vision Pro / spatial-computing surface in roadmap vs. flat 2D only | **Flat 2D only** | The watercolor aesthetic is not enhanced by spatial. Vision Pro is a deliberate non-goal. |

---

## Architecture Implications

### New sector — Apps

Hearth is part of the canonical **Market** sector and may later anchor an **Apps** portfolio/sub-sector for consumer-facing product surfaces. That future taxonomy should remain distinct from:

- **Core** (Kernel, Transport, Data, Auth) — runtime foundations.
- **Ops** (Notify, Communications, Pulse, Vault, Web.Rest, Studios, Notify.Cloud) — operational and developer-tools infrastructure.
- **AI** (HoneyDrunk.AI and the AI-sector Nodes) — model routing, agents, knowledge.
- **Meta** (HoneyHub) — internal control plane.
- **Apps** (Hearth — and any future consumer apps) — consumer product surfaces.

Consumer app Nodes follow the same conventions as the rest of the Grid: per-Node repo, semantic versioning, CHANGELOG, README, canary tests, GitHub Actions CI/CD.

### New repos and Nodes

| Node | Sector | Purpose |
|---|---|---|
| **HoneyDrunk.Hearth** | Market | The Hearth iOS app (and later Android). Consumer product surface, not a library Node. |
| **HoneyDrunk.Hearth.Backend** | Market | Hearth's server-side runtime. Tomoe generation orchestration, friend graph, town sync, account management, Yearly Artifact pipeline. |
| **HoneyDrunk.Hearth.ArtPipeline** | Market (or Studios sub-tool) | Watercolor town render pipeline — produces in-app town images and Yearly Artifact covers. Likely AI-assisted procedural generation; pipeline architecture deferred to a follow-up ADR. |
| **HoneyDrunk.Hearth.Authoring** | Market (internal-only) | NPC arc authoring tool. Internal web app. Not customer-facing. |

Consumer app Nodes are permitted to build product-specific Nodes that do not follow the Abstractions/Runtime split that Core and Ops Nodes follow. Hearth.Backend is a runtime application, not a library; it has its own composition root and is not consumed by other Grid Nodes.

### Dependencies on existing Grid Nodes

```
Hearth
  ├─ Hearth (iOS app)
  │   ├─ Local SQLite + on-device sentiment classifier (Core ML)
  │   └─ HTTPS to Hearth.Backend
  │
  ├─ Hearth.Backend
  │   ├─ consumes ──► Auth (user JWT validation)
  │   ├─ consumes ──► Vault (per-tenant secrets — encryption keys, Stripe creds, Resend creds)
  │   ├─ consumes ──► Notify (transactional email — billing, account, Yearly Artifact ready)
  │   ├─ consumes ──► Communications (notification cadence, quiet hours)
  │   ├─ consumes ──► HoneyDrunk.AI / IModelRouter (Tomoe letter generation)
  │   ├─ consumes ──► Web.Rest (API envelope, correlation)
  │   ├─ consumes ──► Kernel (IGridContext, lifecycle)
  │   ├─ consumes ──► Print-on-demand provider (third-party — Lulu/Blurb API)
  │   ├─ consumes ──► Stripe (subscription billing)
  │   ├─ consumes ──► Weather provider (third-party — Apple WeatherKit or OpenWeatherMap)
  │   └─ emits telemetry ──► Pulse
  │
  ├─ Hearth.ArtPipeline
  │   └─ consumes ──► HoneyDrunk.AI (image generation, with strong prompt control)
  │
  └─ Hearth.Authoring (internal)
      └─ consumes ──► Auth, Vault, Pulse
```

### Boundary impact on existing Nodes

| Node | Change | Notes |
|---|---|---|
| **HoneyDrunk.Notify** | Hearth.Backend becomes a consumer of Notify (transactional email path). No contract change — Notify already supports this shape. The tenant for Hearth's email is `hearth` (a single tenant in Notify Cloud's multi-tenant model). | Backwards-compatible. Hearth.Backend is internal-to-the-studio relative to Notify Cloud's pricing — it does not hit the public Notify Cloud Stripe surface. |
| **HoneyDrunk.Communications** | Same as Notify — Hearth.Backend consumes Communications for cadence/quiet-hours of the (rare) push notifications Hearth sends. | Hearth's notification volume is low — Yearly Artifact ready, account/billing, and absolutely no streak-style nudges. |
| **HoneyDrunk.Auth** | New consumer (Hearth.Backend) on the JWT validation path. No new auth surface. Hearth.Backend authenticates users via Auth's JWT path, not via Notify Cloud's API key path. | Hearth users authenticate with email/password (Apple Sign In, Google Sign In — provider-slot path through Auth). |
| **HoneyDrunk.Vault** | Per-tenant scoping pattern (introduced for Notify Cloud) extended to host Hearth's per-user encryption keys. Hearth uses tenant-scoped Vault paths with `tenant-{userId}-{secretName}` shape. | Reuse of Notify Cloud's pattern — the Grid-wide multi-tenant primitives ADR (per PDR-0002) already established this. |
| **HoneyDrunk.AI / IModelRouter** | Hearth becomes the highest-volume consumer of `IModelRouter` at v1 (Tomoe letters). New routing policy: `creative-letter` task class with quality tier "high," cost ceiling per request, content-not-retained policy. | The routing layer's architecture (per PDR-0001) accommodates this. |
| **HoneyDrunk.Pulse** | Hearth.Backend is a major new telemetry source. Per-user telemetry tags must be **anonymized at ingest** — Pulse never sees journal content; structural events only. | Hearth's telemetry is content-free. The discipline lives in the Hearth.Backend telemetry emitter, not in Pulse's collector. |

### What does NOT change

- Core Nodes (Kernel, Transport, Data) — no contract changes.
- Notify Cloud's commercial surface — Hearth is internal-to-the-studio relative to Notify Cloud and does not hit the public API.
- HoneyHub's internal-control-plane role.
- Architectural invariants 1–36+. Vault's tenant-scoped-secret pattern (Invariant 9a) was established by PDR-0002; Hearth reuses it.

### Tech stack — load-bearing decisions

These are decisions the PDR commits to; the follow-up ADRs codify the technical contracts.

#### Mobile

- **iOS first.** SwiftUI native. Core ML for the on-device sentiment classifier and theme tracker. WeatherKit for weather sync.
- **Android in v1.5.** Likely Kotlin + Jetpack Compose. Cross-platform frameworks (Flutter, .NET MAUI, React Native) are evaluated and rejected for v1: the watercolor render pipeline and the on-device ML pipeline both benefit from native platform APIs, and the cross-platform overhead is not worth the engineering velocity for a small mobile team.

#### Backend

- **.NET on Azure Container Apps**, reusing the Grid's existing infrastructure (Auth, Vault, Notify, Communications, Pulse). This is the **correct choice** despite the surface temptation to greenfield in a different stack — reusing the Grid's auth, vault, telemetry, and notification primitives saves months of work and keeps Hearth on the studio's deployment, observability, and security posture.
- **Hearth.Backend** is deployed to Azure Container Apps under ADR-0015's pattern. Single region (East US) at v1, multi-region in v2.
- **Storage:** Azure SQL for relational data (accounts, subscriptions, friend graph, town state). Azure Blob Storage with E2EE for reflective text and photos. Redis for short-term caches.

#### Art pipeline

The watercolor town render is the highest-art-pipeline-risk surface. Three options were considered:

1. **Pre-rendered with conditional layers.** A small library of base watercolor town backgrounds, with weather, palette, and time-of-day rendered as composable layers. The user's house and shops are placed as 2D sprites. This is the simplest and ships first.
2. **Procedural generation.** A 2D engine that paints the town from rules — building positions, watercolor strokes, lighting. More work; more flexibility; risks looking procedural rather than hand-painted.
3. **AI-generated in-the-loop.** Each town view is image-generated server-side from a prompt that encodes the user's town state. Highest quality if prompt engineering is right; highest cost; highest risk of inconsistency between sessions.

**Selected for v1: Option 1 (pre-rendered with conditional layers), with hand-painted base assets and procedural placement of user-specific elements.** The aesthetic is hand-painted; the procedural composition is bounded. Option 3 (AI-generated) is a v2 exploration — specifically for the Yearly Artifact cover, where a per-user unique illustration justifies the per-user generation cost.

This decision is load-bearing on the consumer-app portfolio's identity. Hearth's art is hand-painted. Future Apps-sector products inherit this commitment unless they explicitly justify otherwise.

#### Tomoe LLM

- **HoneyDrunk.AI's IModelRouter** routes Tomoe letter generation. The default model is a frontier instruction-tuned model (Claude 4.5/5, GPT-5, or equivalent at launch — the routing layer abstracts which).
- **The system prompt is the moat.** A 2,000–3,000 word system prompt, version-controlled in `HoneyDrunk.Hearth.Backend`, that defines Tomoe's persona, hard constraints, examples of acceptable and unacceptable letters, and the response format. This prompt is the literary asset of the product.
- **Two-pass generation:** the first pass generates the letter; the second pass (a different prompt, possibly a different model) evaluates against the guardrails. Failed letters are silently dropped; persistent failures log to Pulse for human review.

#### Print-on-demand provider

- **Lulu** (provisional). Mature API, hardcover quality at the bar Hearth needs, US + international fulfillment. Decision deferred to a follow-up Yearly Artifact ADR after a side-by-side print-quality test against Blurb and Printify Pro.

#### Stripe

- **Stripe** for subscription billing. Same pattern Notify Cloud uses (per PDR-0002 / ADR-0027). Reusing the studio's Stripe integration shape across products.

---

## Product Implications

### Tier shape and progression

| Stage | Tier | Buyer | Hook |
|---|---|---|---|
| Discovery | Hearth Free | Curious user, self-improvement-app skeptic | The town. "Build one small part of your day." |
| Activation | Hearth Snow ($54/yr) | The user who has used reflections/practices for 4 weeks and started caring about the town | Tomoe. "She's been waiting to write to you." |
| Ritual | Yearly Artifact ($34) | Snow subscribers in their first January | "Your year, in your hands." |
| Founding | Founding Townsfolk ($199 lifetime) | Early adopters who want to fund the studio | The unique founding-resident NPC + lifetime access |
| Future | Hearth Family / Hearth Premium | (Phase 4+; not committed in v1) | TBD |

### Customer acquisition

Hearth's audience is **paying-consumer aesthetic-first / growth-curious**: the audience that already pays for Day One, Finch, Bear, Things, Halide, Procreate, Spiritfarer, Stardew Valley. This is a real audience and is reachable through specific channels:

- **Editorial App Store coverage.** The single highest-impact channel for an aesthetic-first iOS app. Apple regularly features apps with strong design and emotional concept; Hearth's aesthetic is exactly the surface Apple's editorial team has rewarded historically.
- **TikTok and Instagram.** Aesthetic short-form content (the town under different weather, Tomoe's letters being read aloud, a year-in-the-town time-lapse). The aesthetic is the marketing.
- **Reddit** — `r/selfimprovement`, `r/getmotivatedbuddies`, `r/Journaling`, `r/productivity` — high-quality posts about the no-streaks / no-XP-grind thesis.
- **Niche newsletters and blogs.** The Recommendo, Sidebar, The Browser, design-adjacent newsletters that cover beautiful software.
- **YouTube** — long-form videos about journaling that touch on Hearth as an example. The user can pay for sponsored placements with two or three high-affinity creators.
- **Build-in-public on the studio site.** Every public PDR, every public ADR, every devlog. The audience for this overlaps with Notify Cloud's audience modestly; the wider consumer audience comes through Apple editorial and aesthetic short-form.

### Build-in-public alignment

Hearth's build is itself content. The PDR for the no-streaks thesis is a piece of marketing. The art pipeline's open exploration (which print-on-demand provider, which model for Tomoe, which sentiment classifier shape) is a piece of marketing. The studio's commitment to user trust (the Tomoe disclosure, the on-device sentiment commitment) is a piece of marketing.

This is consistent with the manifesto's "Transparency is marketing" stance. Hearth's competitive moat against incumbent self-improvement and journaling apps is not defensible by code secrecy — it is defensible by editorial care, aesthetic commitment, and trust posture, all of which compound when shown publicly.

### Pricing-to-architecture coupling

Pricing tiers map to clean architectural feature surfaces:

- **Free → Snow** is gated by *Tomoe activation* and *Yearly Artifact offer*. Architecturally, this is a subscription-status check at Tomoe's letter-generation orchestrator and at the Yearly Artifact offer surface.
- **Snow → Yearly Artifact** is a separate Stripe one-time purchase, not a tier upgrade. Architecturally, the Yearly Artifact pipeline runs against any user with sufficient entries, regardless of subscription status (a Free user with 50 entries can buy a book).
- **Founding Townsfolk** is a Stripe one-time payment that grants Snow-tier permissions in perpetuity, plus a unique NPC asset visible only in that user's town. Architecturally, the lifetime grant is a permanent flag on the user record.

### App Store economics

Apple takes 15–30% of subscription revenue. At $54/yr Hearth Snow, that is $8–16 per subscriber per year to Apple. This is real margin pressure and is reflected in the pricing decision — $54 is selected partly because it absorbs Apple's cut while still leaving a healthy contribution margin against Tomoe's per-user cost.

The Yearly Artifact ($34) is **not subject to Apple's cut** — it is a physical good fulfilled outside the app, billed via Stripe directly. This is the key economic unlock: the Yearly Artifact is the highest-margin product in the catalog *because* it bypasses the App Store.

(Apple's IAP rules require digital subscriptions to flow through StoreKit. Physical goods are explicitly carved out. The Yearly Artifact is unambiguously a physical good.)

---

## What Does NOT Change

- **The Grid's manifesto.** Hearth is the first consumer commercial product but not a new principle; the studio still ships open-core where the engine has reuse value (the AI sector's contracts, Communications) and keeps consumer-product code (Hearth.Backend, the iOS app, the authoring tool) private.
- **HoneyHub's internal-control-plane role** (per ADR-0003).
- **PDR-0001's Observation and AI Routing decisions** — Hearth is a heavy IModelRouter consumer, validating the routing decision.
- **PDR-0002's Notify Cloud commitment** — Hearth runs in parallel, not in tension.
- **All architectural invariants.**
- **The solo-dev + AI-agents operating model.** Hearth is solo-shipped with AI-agent collaborators, plus a small editorial-and-art collaboration with the user (NPC writing, watercolor base assets) that may involve part-time contractors at v1+.
- **The build-in-public stance.** Hearth's PDRs, ADRs, and devlogs are public. The Hearth.Backend repo is private (consumer-data-adjacent code), the iOS app repo is private, the authoring tool repo is private. The art assets remain proprietary.

---

## Risks

| Risk | Severity | Description |
|---|---|---|
| **Tomoe causes a real harm event** | **High** | A vulnerable user receives a Tomoe letter that lands as harmful, and the failure mode is one the guardrails should have caught. Reputation, regulatory, and ethical exposure. §L hard rule (safety bar — pause Tomoe immediately; sunset Hearth if the failure mode cannot be resolved). |
| **The no-streaks thesis is wrong** | High | Retention without streaks fails. <3% Free→Snow conversion. The category's gamification was correct; Hearth's refusal of it was a category-misread. §L decision point — operator evaluates and chooses extend / pivot, drop to maintenance, or sunset. |
| **Per-user Tomoe generation cost exceeds Snow ARPU** | Medium-High | Frontier-model generation costs at Tomoe's quality bar may be $0.05–$0.20 per letter; at 1–2 letters/week × 52 weeks, that's $2.60–$20.80/year per Snow user. Combined with Apple's cut, margin compresses sharply. Mitigations: smaller models for generation with tone-evaluator filtering; per-user usage caps; gradual cadence reduction. |
| **The art pipeline does not clear the aesthetic bar** | Medium-High | Watercolor done badly is worse than no watercolor. If the v1 town does not feel hand-painted and emotionally resonant, the moat collapses. Mitigation: hand-paint the base assets; aggressive review; commit budget to a watercolor artist at v1 if needed. |
| **iOS App Store editorial does not feature Hearth** | Medium | Editorial coverage is the highest-impact channel; if Apple does not feature, Hearth's reach is constrained to organic and paid channels which are slower. Mitigation: launch ahead of a featured-app submission window; build relationships through TestFlight and submission process. |
| **Founding Townsfolk legal/regulatory exposure** | Medium | Lifetime tiers carry tail liability. State AGs (US) and consumer protection agencies (EU) have shown attention to "lifetime" claims. Mitigation: lawyer-reviewed terms, honest marketing copy, capped at 1000 units. |
| **Sentiment engine produces tone-deaf juxtapositions** | Medium | A user writes about losing a parent; the town renders as a grey thunderstorm; the user reads it as the app being heavy-handed. Mitigation: rule table is hand-tuned; transitions are gradual not abrupt; the absence of summary dashboards keeps the mechanic implicit. |
| **NPC arcs feel canned at second read-through** | Medium | A user who keeps a journal for 18 months sees the same NPC arc cycle. Mitigation: arc cadence is multi-month per NPC and arcs branch into multiple paths; new NPCs ship quarterly post-launch. |
| **Print-on-demand quality fails** | Medium | The Yearly Artifact is the brand artifact. A book that arrives with poor color, weak binding, or thin paper undermines the entire ritual. Mitigation: side-by-side test 3 providers before launch; ship a copy to every team member as part of launch QA; offer reprints liberally for the first year. |
| **Friend towns introduce abuse / safety surface** | Medium | The social mechanic at v2 is where moderation, abuse, and trust failures live. Mitigation: deferred to v2; tightly scoped (postcards only, no journal sharing, no DMs); full safety review before v2 ships. |
| **Solo-dev capacity** | Medium | Hearth is more scope than Notify Cloud. Running both products in parallel may exceed capacity. Mitigation: aggressive v1 cuts; Hearth's launch is timed to follow Notify Cloud's stabilization, not parallel to its launch. |
| **Cross-platform engineering when Android lands** | Low-Medium | Android v1.5 will require porting the on-device ML pipeline, weather sync, and watercolor render. Mitigation: native Android, accepting the porting cost as the price for native quality. |
| **Subscription churn** | Medium | Annual subscriptions have ~30–40% churn at the consumer level. Mitigation: the Yearly Artifact ritual is the renewal nudge — Snow users who buy the book in January are dramatically more likely to renew. |
| **Trust posture failure (data breach)** | Low (probability) / Catastrophic (severity) | Hearth holds the most personal data in the studio's catalog. A breach is catastrophic. Mitigation: E2EE on backups, no server-side journal-content storage beyond the Tomoe generation window, pen-test before launch, security review by a third party at v1.5. |

---

## Mitigations

| Risk | Mitigation |
|---|---|
| Tomoe harm event | Two-pass generation (generator + tone evaluator). Per-letter pre-publish review. Hard guardrails in the system prompt. Safety-routing model for crisis indicators (separate from Tomoe). User-controllable pause. Apologize-and-flag flow. Single-event hard rule at the studio level (kill on real harm event). Public commitment in the privacy policy. |
| No-streaks thesis wrong | Soft launch with 100–500 users via TestFlight + waitlist before public launch. Measure retention shape over the first 3 months. If retention is below industry benchmarks for the comparable consumer subscription apps, evaluate the thesis before scaling marketing. The §L decision-point evaluation gives this 6 months of runway. |
| Tomoe generation cost | Routing-layer cost ceilings per request. A/B testing of model size — start with frontier-class, evaluate whether mid-tier models pass the tone-evaluator at acceptable rates. Monthly per-user cap (e.g., 8 letters/month max under any cadence setting). Per-tier generation budget — Snow gets weekly; future higher tier could get more. |
| Art pipeline | Commit to hand-painting the base assets; budget for a watercolor artist (~$5K–$15K for the v1 asset pack). Procedural composition is bounded; AI-generated images are v2. Aesthetic review before every release. |
| App Store editorial | TestFlight beta submitted 90 days before public launch. Direct outreach to App Store editorial relations (Apple maintains a submission form for app spotlight). Press kit ready; aesthetic short-form social content seeded for the launch week. |
| Founding Townsfolk legal | Lawyer review (1–3 hours of attorney time; ~$500–$1,500). ToS explicitly states wind-down terms. Marketing copy honest about the risk. Cap of 1000. State-AG-conscious language ("lifetime access for as long as Hearth and the studio exist"). |
| Sentiment juxtapositions | Hand-tuned mapping table. Smoothing — environment changes drift over hours/days, not single entries. The product never explains the mapping; the user discovers it. No weekly sentiment summaries. |
| NPC canned-feeling | Arcs are 12+ weeks long. Branching paths within arcs based on theme tracker. Quarterly NPC additions. v3 may explore generative dialogue; v1 holds editorial control. |
| Print-on-demand quality | 3-provider side-by-side test (Lulu, Blurb, Printify Pro) before v1 launches the book commitment. Sample books to user + collaborators. Reprints offered freely in year one. |
| Friend towns abuse | Deferred to v2. Scoped tightly when shipped. Friends connect by mutual code, not discovery. No journal sharing. Postcards have content moderation (image classifier on user-uploaded text). |
| Solo-dev capacity | Hearth v1 follows Notify Cloud's stabilization, not its parallel launch. Aggressive scope cuts. Editorial work (NPCs, watercolor) is the part that may need a part-time contractor; budget exists. |
| Subscription churn | Yearly Artifact ritual is the renewal mechanic. Annual pricing is the dominant offer ($54 vs. $6.99/mo); annual subscribers churn less. Re-engagement emails are gentle, not nagging. |
| Trust posture / breach | E2EE backups; no journal-content server-side persistence. Pen-test at v1.5. Third-party security review before scaling past 10K users. Bug bounty program at v2. |

---

## Consequences

### Short-term (next 9–12 months)

- **Consumer-app taxonomy** is resolved. `constitution/sectors.md` and `catalogs/nodes.json` are updated only if Architecture accepts a dedicated Apps label.
- **New repos** (`HoneyDrunk.Hearth`, `HoneyDrunk.Hearth.Backend`, `HoneyDrunk.Hearth.ArtPipeline`, `HoneyDrunk.Hearth.Authoring`) are scaffolded. Each gets its own standup ADR per the standup-ADR convention.
- **Hearth.Backend ships on Azure Container Apps** under ADR-0015's pattern, with its own Vault, App Configuration, and telemetry stream.
- **HoneyDrunk.AI / IModelRouter** ships its first high-volume external-content workload (Tomoe). The routing-policy surface gets real production pressure.
- **Communications** gains its first consumer-app cadence consumer (Hearth's transactional email).
- **The studio's brand surface expands** — consumer marketing material, App Store presence, social media content. The studio is no longer purely a developer-tools studio.
- **Editorial labor** — NPC arcs, system prompts, the Tomoe persona, watercolor assets — becomes a load-bearing part of the studio's output. Possibly the first part-time contractor engagement (artist + writer).

### Long-term (12+ months post-launch)

If Hearth's §L decision-point evaluation lands on "extend":

- **The consumer-app portfolio is established** as a live, revenue-bearing surface. Future consumer products (Lately, Wayside, a HoneyPlay narrative game) inherit Hearth's patterns: privacy-first, on-device-first, hand-authored-where-it-matters.
- **The studio runs two commercial products** (Notify Cloud + Hearth) on different audiences, different cadences, different revenue shapes. Diversified single-studio risk.
- **Hearth's success funds the AI sector** at consumer scale — the AI sector's nine planned Nodes have a real consumer to pull them forward.
- **The Yearly Artifact economy** matures. The studio sells thousands of hardcovers a year; this is a small but real revenue line and a major brand artifact.
- **Founding Townsfolk obligation** runs for as long as the studio runs — a known liability, sized at 1000 units, manageable.
- **The next consumer app** (Lately or Wayside or HoneyPlay) is plausibly committed in v2.

If Hearth's §L decision-point evaluation lands on "drop to maintenance" or "sunset gracefully" — or if the §L hard rule (Tomoe harm event) fires — the operator chooses the appropriate response:

- **Drop to maintenance** when there is enough engaged usage and the trust posture is intact, but commercial signal is below the bar — keep the app alive for existing users, no marketing, no new feature roadmap, signup may remain open.
- **Sunset gracefully** when neither commercial nor engagement signal supports continued operation, or when the §L hard rule fires. **Hearth is wound down respectfully.** Users get 6 months notice, full export of journal content, refund of recent Snow renewals, refund of unfulfilled Yearly Artifact preorders.
- **Founding Townsfolk** receive a refund pro-rated against an "expected lifetime" framework documented in the ToS.
- **A retrospective PDR** is written documenting what failed (the no-streaks thesis, Tomoe trust, art pipeline, conversion economics).
- **Hearth.Backend, the iOS app, and authoring tools** are archived; the on-device sentiment classifier and the Tomoe prompt structure are kept as research assets.
- **The consumer-app portfolio remains** but is dormant until the next consumer product pursues it.

Either outcome generates more learning than not building Hearth.

---

## Rollout — Phased Approach

### Phase 0: Decision and pre-build (weeks 0–4, starting from PDR acceptance)

- This PDR moves to **Accepted**.
- Standup ADRs for `HoneyDrunk.Hearth`, `HoneyDrunk.Hearth.Backend`, `HoneyDrunk.Hearth.ArtPipeline`, `HoneyDrunk.Hearth.Authoring`.
- Consumer-app taxonomy resolved in `constitution/sectors.md` if needed.
- The Tomoe persona and system prompt v0 are drafted (writing exercise, not engineering).
- The watercolor art direction (color palette, brush style, building shapes, three reference scenes) is locked.
- Print-on-demand provider side-by-side test scheduled (Lulu, Blurb, Printify Pro — order sample 3-up books).

**Exit criteria:** ADRs accepted, art direction locked, Tomoe persona v0 written.

### Phase 1: Hearth.Backend foundation (weeks 4–14)

- `HoneyDrunk.Hearth.Backend` repo scaffolded; deployed to Azure Container Apps internal under ADR-0015's pattern.
- Auth integration (Apple Sign In, Google Sign In paths through `HoneyDrunk.Auth`).
- Vault per-user encryption key issuance.
- Stripe subscription billing wired (test mode).
- Notify integration for transactional email.
- Tomoe generation orchestrator (cron-driven, per-user, weekly cadence at this phase).
- Tomoe system prompt v1 + tone-evaluator pass.
- Pulse telemetry (content-free, structural events only).

**Exit criteria:** Backend can authenticate a user, store an entry, generate a Tomoe letter with two-pass tone evaluation, deliver a transactional email. Internal team uses it daily.

### Phase 2: iOS app v1 (weeks 14–28)

- SwiftUI iOS app scaffolded.
- On-device sentiment classifier (Core ML; trained or fine-tuned from a published baseline).
- On-device theme tracker (clustering over recent entries).
- Town render (pre-rendered base + composable layers; 8 buildings, day/night cycle, weather sync via WeatherKit).
- 2 NPCs with 12-week pre-authored arcs (writing-heavy, the most editorial-labor-intensive part of v1).
- Anniversary mechanic (paper boats on the river).
- Onboarding flow (town name, Tomoe opt-in, privacy disclosures).
- TestFlight build with 100–500 invited users.

**Exit criteria:** TestFlight users complete onboarding, write entries, see the town respond, receive Tomoe letters. Beta retention shape comparable to or better than industry benchmarks. <0.1% reported "this letter hurt me" rate.

### Phase 3: Public launch — soft (weeks 28–32)

- App Store submission. Launch window targeted for early-fall release (October 2026 plausible, depending on Notify Cloud's launch calendar — Hearth must not parallel-launch with Notify Cloud's public launch).
- Marketing site at `hearth.honeydrunkstudios.com` (or final domain).
- Free + Hearth Snow tiers active. Stripe live mode.
- Founding Townsfolk tier active (capped at 1000).
- Yearly Artifact is "coming this December" — committed in marketing, not built yet.

**Exit criteria:** App Store live, paid subscribers signing up, Founding Townsfolk slots filling.

### Phase 4: Yearly Artifact and ritual (weeks 32–48)

- Yearly Artifact pipeline built (PDF generation, Lulu API integration, watercolor cover renderer, NPC interludes, Tomoe's closing letter).
- December launch of the first Yearly Artifact offer (for users with sufficient v1 entries — ~3 months of writing minimum).
- January 2027: first Yearly Artifacts ship. The ritual is real.

**Exit criteria:** First Yearly Artifacts delivered to users with quality at the bar. ≥30% attach rate among eligible Snow subscribers in the first January.

### Phase 5: v1.5 (post-January 2027)

- Tomoe at 2 letters/week (one regular, one higher-quality "deeper letter" pipeline).
- Voice journaling input (with vocal tone affecting town palette).
- Future-self letters (sealed delivery on the chosen date).
- Lanterns at festival time (seasonal feature).
- Android port begins.

### Phase 6: v2 (mid-2027+)

- Friend towns and postcards (the social mechanic, scoped tightly with safety review).
- Handwritten input on tablets with light OCR.
- Additional NPCs (4th, 5th, 6th).
- Generative letter exploration (research; may or may not ship).

### Decision-point review (month 12 post-launch)

- Count registered users (target: 5,000+).
- Measure Free → Snow conversion (target: ≥3%).
- Measure Yearly Artifact attach rate (target: ≥30%).
- Measure per-user gross margin (target: positive).
- Review Tomoe harm-event log (target: zero events that breach the §L hard rule).

If targets are met, Hearth becomes a sustained product line. If targets are missed, the operator applies the §L decision-point matrix (extend / pivot, drop to maintenance, or sunset gracefully). If the Tomoe hard rule has fired at any point during the year, the response is immediate per §L regardless of the other metrics.

---

## Open Questions

| Question | Owner | Notes |
|---|---|---|
| **Final product name.** Hearth is the codename; Yuki was the previous codename. Is "Hearth" the launch name, or is there a final consumer-facing name TBD before App Store submission? | Product / Brand | Default proposed: launch as "Hearth." Tested against trademark availability and consumer-resonance research before App Store submission. |
| **Domain — `hearth.honeydrunkstudios.com` vs. independent brand domain.** | Product | Default proposed: subdomain at v1, consistent with Notify Cloud's choice. Independent domain (e.g., `hearth.app`) revisited if Hearth's §L decision-point evaluation lands on "extend" and the product scales. |
| **Print-on-demand provider final selection** (Lulu vs. Blurb vs. Printify Pro). | Operations | Side-by-side test in Phase 0; decision before Phase 4 build. |
| **Tomoe LLM provider routing policy** — frontier-class only, or mid-tier with tone-evaluator filtering for cost. | AI / Product | Default proposed: frontier-class at v1 launch; mid-tier evaluation as a v1.1 cost optimization once volume is meaningful. |
| **Sentiment classifier — train custom or fine-tune from a published baseline.** | AI / Engineering | Default proposed: fine-tune a published sentiment baseline (HuggingFace's `cardiffnlp/twitter-roberta-base-sentiment-latest`-equivalent or Apple's on-device tone embeddings) on a small hand-labeled journal-text corpus. Training a custom model is overkill at v1 scope. |
| **NPC arc authoring — first-party staff vs. contractor vs. AI-assisted-with-human-edit.** | Editorial / Product | Default proposed: AI-assisted draft with human edit (the user is the editor at v1). Contractor writer engaged for v2's NPC expansion. |
| **Watercolor artist — contractor at v1 vs. AI-generated base assets.** | Art / Product | Default proposed: contractor for the base asset pack (~$5K–$15K). AI-generated is v2 exploration only for per-user uniqueness (Yearly Artifact covers). |
| **Apple Sign In + Google Sign In + email/password — all three at v1, or scope cut to one.** | Engineering | Default proposed: Apple Sign In + email/password at v1; Google Sign In at v1.5. (Apple requires Apple Sign In if any third-party SSO is offered on iOS.) |
| **Friend graph storage shape** — anonymous user IDs only, or display names. | Product / Privacy | Default proposed: anonymous codes for connection (mutual code share), display name optional and town-scoped. v2 decision; flagged here for awareness. |
| **App Store category** — `Lifestyle` vs. `Health & Fitness` vs. `Productivity`. | Product | Default proposed: Lifestyle. Health & Fitness invites a regulatory framing the product does not want; Productivity is the wrong audience. |
| **Refund policy and cancellation flow** — Apple-default vs. studio-supplemented. | Operations | Default proposed: Apple-default for App Store subscriptions; manual case-by-case for Founding Townsfolk and Yearly Artifact pre-orders. |
| **Compliance posture for journal data** — HIPAA-ish (intentionally avoiding, as Hearth is not a health app), GDPR (yes — EU users from day one), CCPA (yes), COPPA (no — 18+ only). | Product / Legal | Default proposed: 18+ only at v1 (avoids COPPA). GDPR + CCPA compliant from launch. Plain-language privacy policy. Not pursuing HIPAA. |

---

## Recommended Follow-Up Artifacts

| Artifact | Type | Purpose |
|---|---|---|
| `HoneyDrunk.Hearth.Backend` standup ADR | ADR | Stands up the backend Node per the standup-ADR convention. Names package families, deployment shape, dependencies on Auth/Vault/Notify/Communications/AI/Pulse, contract surface to the iOS app. |
| `HoneyDrunk.Hearth` (iOS app) standup ADR | ADR | Stands up the iOS app repo. Tech stack (SwiftUI, Core ML), local storage shape, sync protocol, on-device ML pipeline. |
| `HoneyDrunk.Hearth.ArtPipeline` standup ADR | ADR | Stands up the watercolor render pipeline. Asset format, conditional layer composition, Yearly Artifact cover generation pipeline. |
| `HoneyDrunk.Hearth.Authoring` standup ADR | ADR | Internal NPC arc authoring tool. Web app stack, theme taxonomy schema, content-versioning approach. |
| Consumer-app taxonomy addition to `constitution/sectors.md` | Constitution amendment | Decides whether Apps becomes a dedicated sector/sub-sector and defines boundary rules between consumer apps and Ops/Core/AI. |
| Tomoe generation pipeline ADR | ADR | Two-pass generation, system prompt versioning, tone-evaluator pass, safety-routing path for crisis indicators, retention policy for journal-text-in-context. |
| Sentiment-responsive environment engine design doc | Design doc | The mapping table from sentiment vector to environment cues. Smoothing function. Edge cases. |
| NPC arc authoring conventions design doc | Design doc | Theme taxonomy, chapter shape, branching rules, voice guidelines, dialogue review process. |
| Yearly Artifact production ADR | ADR | Print-on-demand provider selection, PDF generation pipeline, NPC interlude generation, Tomoe closing letter pipeline, fulfillment and shipping shape. |
| Hearth privacy policy and trust architecture design doc | Design doc | Plain-language privacy policy. Data classification table (made user-facing). E2EE backup design. Account deletion flow. |
| Hearth pricing and tier feature gates design doc | Design doc | Subscription-status check points, Free→Snow upgrade flow, Founding Townsfolk lifetime grant, Yearly Artifact purchase flow, churn re-engagement (gentle, no streak language). |
| Founding Townsfolk legal terms ADR (or operations doc) | ADR | Lawyer-reviewed terms of service for the lifetime tier. Wind-down language. Refund framework. State-AG-conscious marketing copy. |
| App Store submission and editorial outreach plan | Design doc | Launch calendar, App Store editorial submission, press kit, social-content cadence. |
| Hearth marketing site copy and pricing page design doc | Design doc | The customer-facing surface. Studio brand, pricing, privacy framing, Founding Townsfolk explanation. |
| Hearth retrospective PDR (conditional) | PDR | If Hearth's 12-month §L decision-point evaluation lands on "sunset" (or the §L hard rule fires earlier), the retrospective PDR documents what the wedge missed and informs future consumer-app commitments. |

---

## Next steps

Concrete decisions the user must settle before Hearth scoping issues are filed:

1. **Confirm Hearth as the first consumer app commit.** This PDR is *Proposed*; the user (per ADR-acceptance-workflow) flips it to Accepted via the scope agent on PDR-merge — *not* on first draft. Confirm direction before that flip.
2. **Confirm the no-streaks/no-XP-grind thesis as non-negotiable.** This is the load-bearing differentiation. If the user wants any softening (Finch-style sad-pet missed-day mechanic, or a "town misses you" message), that decision must be made now and reflected in the PDR. Default position in this draft: hard no.
3. **Confirm Tomoe's server-side LLM posture for v1.** The privacy disclosure is loud but real. If the user wants on-device-only at v1 (and accepts a quality tradeoff on Tomoe's letters), that decision changes the architecture and the launch timeline.
4. **Confirm the iOS-first launch over Android-first or cross-platform.** Default in this draft: iOS-first.
5. **Confirm the Founding Townsfolk lifetime tier.** This is the most legally exposing decision in the PDR. If the user wants to drop the lifetime tier and replace it with a multi-year prepaid tier (e.g., "5 years for $149"), that decision is cleaner legally and almost as good operationally.
6. **Confirm the launch sequencing relative to Notify Cloud.** Default: Hearth follows Notify Cloud's stabilization (Notify Cloud public launch is targeted ~2026-09-15 per PDR-0002; Hearth public launch is targeted later in fall 2026 or early 2027). The user should confirm the studio's solo-dev capacity for two parallel commercial products on staggered launch calendars.
7. **Confirm the watercolor-artist contractor budget commitment.** This is the first recurring contractor engagement the studio has committed to. ~$5K–$15K for v1 base asset pack. Authorize before art-direction Phase 0 work begins.
8. **Confirm the editorial-writer commitment for NPC arcs.** Two NPCs at 12 weeks each is ~24 chapters of authored content for v1, plus Tomoe's persona work and the Yearly Artifact NPC interludes. The user (as primary writer) should confirm capacity, or authorize a contractor engagement.
9. **Confirm the final product name.** "Hearth" is the codename; if the launch name is different (or if "Hearth" is unavailable for trademark or App Store reasons), surface this before App Store submission. Default direction: launch as Hearth.
10. **Confirm the Apps-sector addition to the constitution.** Adding a new sector is a constitutional change. Confirm before the sector definition lands in `constitution/sectors.md`.

Once these are settled, the scope agent files standup-ADR packets for the four new repos and the constitution amendment, and the work begins.
