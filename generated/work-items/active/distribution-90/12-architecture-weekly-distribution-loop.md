---
name: Weekly Distribution Loop Bring-Up
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "distribution-90"]
dependencies: ["work-item:03"]
adrs: ["PDR-0011", "PDR-0002"]
source: human
generator: scope
wave: 2
initiative: distribution-90
node: honeydrunk-architecture
actor: agent
---

# Chore: Establish the weekly distribution loop and syndication queue

## Summary
Extend `initiatives/metrics-log.md` (created by packet 03) with the standing weekly-loop checklist and a syndication queue built from the blog's existing back-catalog (12 posts). This single packet establishes the recurring loop — one syndicated post per week, a 15-minute metrics review, and an announcement for every NuGet release — which then runs ~12 times as checklist reps, deliberately **not** as 12 more packets.

## Context
Distribution 90 D-workstream. The strategy review found zero syndication and zero release announcements ever, despite a quality back-catalog. Recurring work is a loop, not a packet stream: per the initiative guardrails, the reps live as appended checklist entries in the metrics log, and the day-90 success criterion is "≥12 reps completed." This packet builds the track the reps run on.

## Deliverables (all inside `initiatives/metrics-log.md`)
1. **Weekly loop checklist** (a template block copied into each weekly entry):
   - [ ] Syndicate one back-catalog post (HN / relevant subreddit / dev.to — pick per post, drafted for operator approval, operator submits).
   - [ ] 15-minute metrics review: append the week's numbers (NuGet downloads, both domains' traffic, stars/forks, waitlist count, newsletter subscribers).
   - [ ] Any NuGet release this week announced? (newsletter issue + one channel; "none shipped" is a valid checkbox).
   - [ ] One-line observation (what moved, what didn't).
2. **Syndication queue:** a table of the back-catalog posts (title, URL, best-fit channel + why, suggested adapted title, status). Order by expected resonance, operator may reorder. Verify post list against the live `tatteddev/tatteddev-blog` `main` (`app/src/content/blog/`), not a local checkout.
3. **Release-announcement rule (recorded as a loop step, NOT an invariant):** from 2026-06-09, every NuGet release of a Grid package gets a short announcement — a newsletter mention plus one channel (the operator's choice per release). Wire-in note: the release week's loop entry carries it; no automation now.

## Human Prerequisites
- [ ] Confirm dev.to (or an alternative like lobste.rs) as the third syndication channel and create the account if missing (~10 minutes).
- [ ] Approve the proposed syndication order before the first rep.

## Acceptance Criteria
- [ ] `initiatives/metrics-log.md` contains the loop checklist template, the full syndication queue (every live back-catalog post present), and the release-announcement rule.
- [ ] The queue's post list matches the live blog `main` at authoring time.
- [ ] No new files, invariants, agents, or process documents — this all lives inside the existing metrics log.
- [ ] First rep is executable immediately: week-1's queue row has a concrete channel and adapted title ready for operator approval.

## Dependencies
- `work-item:03` — the metrics log must exist.

## Agent Handoff

**Objective:** Add the weekly-loop checklist template, the back-catalog syndication queue, and the release-announcement rule to `initiatives/metrics-log.md`.
**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.
**Context:**
- Goal: Distribution 90 D-workstream — the recurring engine; 12 reps of this loop is half the initiative's day-90 success criteria.

**Acceptance Criteria:** as listed above.

**Dependencies:** packet 03 Done.

**Constraints:**
- Guardrail (from the initiative, not an invariant): no new process/governance documents; the loop lives inside the metrics log. Do not propose automation in this packet.
- Verify cross-repo state (the blog's post list) against live GitHub `main` via `gh api`, never a local sibling checkout.
- Syndication drafts produced during reps follow the blog voice rules (no em dashes, no antithesis constructions, community-appropriate tone); the operator submits — agents never post externally.
- Agent-authored PRs must link to their packet in the PR body (invariant 32).

**Key Files:**
- `initiatives/metrics-log.md`

**Contracts:** None.
