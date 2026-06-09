---
name: HoneyHub Launch Submissions
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
work_repo: tatteddev/tatteddev-blog
labels: ["feature", "tier-1", "meta", "distribution-90", "honeyhub"]
dependencies: ["packet:05", "packet:08", "packet:10"]
adrs: ["PDR-0011"]
source: human
generator: scope
wave: 4
initiative: distribution-90
node: none
actor: agent
---

# Feature: Draft HoneyHub launch submissions (Show HN + subreddits) for operator click-to-submit

> **Work location:** the drafts land in `tatteddev/tatteddev-blog` (personal account, outside the org GitHub App's installation — the 2026-06-09 filing run got HTTP 403 there). The issue is tracked here in HoneyDrunk.Architecture; the implementing PR opens in the blog repo and links back to this issue.

## Summary
Draft the submission texts for the HoneyHub v0.1.0 launch — one Show HN and 1–2 relevant subreddits — committed as a reviewable file in the blog repo. The operator reviews, edits, and clicks submit. Drafting is agent work; submitting is irreversibly public and stays human.

## Context
Distribution 90 Wave 4, the exposure step. The org has had zero launch announcements ever; this is the first. Submissions point at the launch post (packet 10) or the repo (Show HN convention prefers the repo/demo directly — draft both variants and let the operator choose). Storage choice: a `drafts/` folder at the repo root of `tatteddev/tatteddev-blog` — outside `app/`, so Astro never builds it; it keeps launch copy versioned next to the post it supports without adding any new process surface to Architecture.

## Deliverables
`drafts/honeyhub-launch-submissions.md` containing:

1. **Show HN** — title (HN-convention: "Show HN: HoneyHub – drive Claude Code from your phone, free and local-first" or similar, ≤ 80 chars, no clickbait), URL variant A (repo) and B (launch post), plus the first-comment text: what it is, why built, what's honest-rough, tech stack (Rust bridge + PWA), direct ask for feedback. HN culture notes inline: founder-voice, no marketing tone, respond-fast plan.
2. **Subreddit picks with rationale (propose, operator confirms):** r/ClaudeAI (the tool drives Claude Code; highest affinity) and r/selfhosted (local-first, your-own-machines angle). For each: title, body adapted to that community's norms, flair suggestion, and that subreddit's self-promotion rules summarized (the agent must check each subreddit's current rules and note them in the draft).
3. **Timing & logistics block:** suggested submission window (HN weekday morning US time), the rule that demo + waitlist + release links must all be live first, and a reminder to watch threads for the first 3–4 hours to respond.

## Human Prerequisites
- [ ] Review and edit all drafts (the words go out under the operator's name).
- [ ] Pick Show HN URL variant (repo vs post) and confirm subreddit choices.
- [ ] Click-to-submit each one and stay responsive in-thread for the first hours.
- [ ] Record submission links + outcomes in that week's metrics-log entry.

## Acceptance Criteria
- [ ] `drafts/honeyhub-launch-submissions.md` committed with all three sections above.
- [ ] Every claim in the drafts is true of shipped v0.1.0 (cross-check against packet 08's release notes — no overclaiming).
- [ ] Subreddit self-promotion rules verified current and summarized per pick.
- [ ] Operator submitted Show HN + at least one subreddit; links recorded in the metrics log.

## Dependencies
- `packet:05` — the waitlist must be live before traffic is driven (PDR-0011 §5's probe needs the funnel connected).
- `packet:08` — the release must exist.
- `packet:10` — the launch post must be published.

## Agent Handoff

**Objective:** Draft submission-ready Show HN + subreddit texts as a single reviewable markdown file.
**Target:** `tatteddev/tatteddev-blog`, branch from `main`.
**Context:**
- Goal: Distribution 90 Wave 4 — first-ever public launch announcement; operator clicks submit.

**Acceptance Criteria:** as listed above.

**Dependencies:** packets 05, 08, 10 Done.

**Constraints:**
- The agent never submits anywhere — drafts only. Click-to-submit is exclusively the operator's.
- Voice: founder-plain, no marketing tone, no em dashes, no "it's not X, it's Y" constructions; honest about v0.1.0 roughness (HN rewards it).
- Verify subreddit rules against the live subreddits at drafting time, not from memory.

**Key Files:**
- `drafts/honeyhub-launch-submissions.md` (new; `drafts/` is outside `app/` and is not built)

**Contracts:** None.
