---
name: Distribution Metrics Log + Baseline
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "distribution-90"]
dependencies: []
adrs: ["PDR-0011", "PDR-0002"]
source: human
generator: scope
wave: 1
initiative: distribution-90
node: honeydrunk-architecture
actor: agent
---

# Chore: Create the distribution metrics log with NuGet/stars/traffic baseline

## Summary
Create `initiatives/metrics-log.md` in HoneyDrunk.Architecture: a plain markdown log holding the day-0 distribution baseline (per-package NuGet downloads, GitHub stars/forks, traffic placeholder, waitlist count) plus a weekly-entry template. This is the single measurement surface the Distribution 90 weekly loop appends to.

## Context
The 2026-06-09 strategy review found the Grid has never measured external distribution: no download tracking, no traffic data, no signup counts. Distribution 90's day-90 success criteria include "metrics log with 12 weekly entries" — that log must exist before the loop starts (packet 12 builds the loop on top of this file). **Deliberately NOT scoped:** any automation (scheduled jobs, scripts, dashboards). The lightest viable thing is a markdown table updated by hand (or by an agent during the weekly session). Automation is a candidate follow-up only after the manual loop has run for several weeks.

## Scope
- New file: `initiatives/metrics-log.md`
- One-line pointer added to the Distribution 90 entry in `initiatives/active-initiatives.md` (the entry itself already exists on the initiative branch).

## Proposed Implementation
`initiatives/metrics-log.md` contains:

1. **Header** — what this is, owned by the Distribution 90 weekly loop, update cadence (weekly, ~15 min), and the rule that entries are append-only.
2. **Baseline section (Week 0, 2026-06-09)** — captured at authoring time:
   - Per-package NuGet total downloads for every published `HoneyDrunk.*` package (query `https://api.nuget.org/v3/registration5-gz-semver2/{id-lower}/index.json` or the nuget.org package pages; a one-off `nuget.org` search API call `https://azuresearch-usnc.nuget.org/query?q=HoneyDrunk` lists all packages with `totalDownloads` — use that and record the table).
   - GitHub org-wide stars, forks, external issue authors (known from the review: 1 star, 0 forks, 0 external issue authors — verify and record).
   - Web traffic: `n/a — analytics go live this week` placeholder for both domains.
   - Waitlist count: `n/a — waitlist not yet live`; newsletter subscribers: `n/a`.
3. **Weekly entry template** — a fenced example block with: date, NuGet total downloads (delta), tatteddev.com visits, honeydrunkstudios.com visits, stars/forks (delta), waitlist signups, newsletter subscribers, syndicated post shipped (Y/N + link), releases announced, one-line observation.
4. **Entries section** — empty, appended weekly.

## Human Prerequisites
None.

## Acceptance Criteria
- [ ] `initiatives/metrics-log.md` exists with header, Week-0 baseline (real queried numbers for NuGet downloads and GitHub stats, not placeholders), weekly template, and empty entries section.
- [ ] Baseline NuGet table covers every published `HoneyDrunk.*` package on nuget.org with its total download count as of the capture date.
- [ ] The Distribution 90 entry in `initiatives/active-initiatives.md` links to the log.
- [ ] No automation, scripts, or workflow files added.

## Dependencies
None.

## Agent Handoff

**Objective:** Create `initiatives/metrics-log.md` with a real day-0 baseline and a weekly-entry template.
**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.
**Context:**
- Goal: Distribution 90 Wave 1 — the measurement substrate for the weekly loop (packet 12 extends this file with the loop checklist and syndication queue; keep the file structure simple so that addition is clean).

**Acceptance Criteria:** as listed above.

**Dependencies:** none.

**Constraints:**
- Markdown only. No scheduled jobs, no scripts, no new process documents — Distribution 90's guardrail is that it must not become a governance/automation project.
- Append-only discipline for entries (state the rule in the file header); the baseline is written once.
- Agent-authored PRs must link to their packet in the PR body (invariant 32: the review agent resolves the packet via this link as the primary scope anchor; absent the link the PR is treated as out-of-band and receives a degraded review).

**Key Files:**
- `initiatives/metrics-log.md` (new)
- `initiatives/active-initiatives.md` (one-line pointer)

**Contracts:** None.
