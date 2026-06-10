---
name: HoneyHub Launch Blog Post
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
work_repo: tatteddev/tatteddev-blog
labels: ["feature", "tier-1", "meta", "distribution-90", "honeyhub"]
dependencies: ["packet:08", "packet:09"]
adrs: ["PDR-0011"]
source: human
generator: scope
wave: 3
initiative: distribution-90
node: none
actor: agent
---

# Feature: Write and publish the HoneyHub v0.1.0 launch post on tatteddev.com

> **Work location:** the content lands in `tatteddev/tatteddev-blog` (personal account, outside the org GitHub App's installation — the 2026-06-09 filing run got HTTP 403 there). The issue is tracked here in HoneyDrunk.Architecture; the implementing PR opens in the blog repo and links back to this issue.

## Summary
Write the launch post for HoneyHub v0.1.0 on tatteddev.com: what it is in plain terms, why it exists, the 2-minute demo embedded, an honest "what works / what doesn't" section, and links to the release and the BYOK cloud-execution waitlist. This post is the canonical launch URL that the Show HN and subreddit submissions (packet 11) point to.

## Context
Distribution 90 Wave 3. The blog has a 12-post back-catalog but has never announced a release. The launch post is the hub of the launch funnel: demo (09) embeds here, release (08) links from here, waitlist (05) and newsletter (04) capture from here. Drafted by an agent, voice-edited and published by the operator.

## Content requirements
- **Ground before jargon:** open with the concrete problem (you kicked off a coding-agent session and then had to leave your desk), not with "the Grid" or internal product taxonomy. Public readers do not know Grid internals; explain what HoneyHub is in plain terms before using its proper name conventions.
- **What it is:** free, local-first cockpit for the agent CLIs you already pay for (Claude Code, Codex; Copilot best-effort) — phone + desktop, one shared UI, your own machines, your own sessions.
- **The demo embedded** near the top (packet 09's video).
- **Honest scope section:** what v0.1.0 does (claude.local end-to-end, pairing/allowlists, local store, usage display) and what it does not (Codex/Copilot adapter status as actually shipped, no editor, no terminal, packaging caveats). PDR-0011's honest-capability-flags principle applies to marketing copy.
- **Quick start:** the same path as the README, abbreviated; link to the repo for the full version.
- **One trust paragraph:** local-first, your auth never leaves your machine; the optional future hosted lane is BYO-API-key only (links the packet-05 waitlist page).
- **Calls to action (exactly three, in order):** try v0.1.0 (release link), join the BYOK cloud waitlist (packet 05's page), subscribe (packet 04's form, which already renders at end-of-post).

## Human Prerequisites
- [ ] Operator voice/edit pass and publish approval (the agent drafts; the operator owns the byline).
- [ ] Demo video URL available (packet 09).

## Acceptance Criteria
- [ ] Post lives in `app/src/content/blog/` with correct frontmatter matching existing posts; builds clean (`npm run build`).
- [ ] Demo embedded; release, waitlist, and repo links all resolve.
- [ ] Honest-scope section present; no claims beyond what v0.1.0 ships.
- [ ] Operator approved and published; URL recorded in the Distribution 90 metrics log entry for that week.

## Dependencies
- `packet:08` — release exists to link.
- `packet:09` — demo exists to embed.

## Downstream Unblocks
Packet 11 (submissions point at this URL).

## Agent Handoff

**Objective:** Draft the launch post as an Astro content entry, ready for the operator's voice pass.
**Target:** `tatteddev/tatteddev-blog`, branch from `main`.
**Context:**
- Goal: Distribution 90 Wave 3 — the canonical launch URL for HoneyHub v0.1.0.
- This repo is outside the HoneyDrunkStudios org; standard Astro site under `app/`.

**Acceptance Criteria:** as listed above.

**Dependencies:** packets 08 and 09 Done.

**Constraints:**
- Voice rules (hard): **no em dashes**; **no "it's not X, it's Y" negate-then-correct constructions**; vary the intro relative to recent posts (do not open with the "I run a studio's worth of services by myself" boilerplate); ground before jargon.
- Honesty: no staged numbers, no fabricated testimonials, no overclaiming adapter support.
- Exactly the three CTAs listed; no popups.

**Key Files:**
- `app/src/content/blog/<slug>.md` (new; match existing posts' frontmatter shape per `app/src/content.config.ts`)

**Contracts:** None.
