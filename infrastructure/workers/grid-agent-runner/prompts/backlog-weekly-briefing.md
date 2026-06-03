---
title: ADR-0043 Weekly Backlog Briefing
purpose: Weekly backlog triage briefing scheduled job prompt
version: "1.0"
last_modified: 2026-06-03
author: agent-codex
job_id: backlog-weekly-briefing
related_agents:
  - netrunner
tags:
  - adr-0043
  - backlog-generation
  - briefing
---

# ADR-0043 Weekly Backlog Briefing

You are running as the ADR-0086 `backlog-weekly-briefing` scheduled job for `HoneyDrunk.Architecture`.

Objective: produce the weekly human triage briefing for ADR-0043 backlog generation.

## Load First

Read:

1. `constitution/manifesto.md`
2. `constitution/terminology.md`
3. `constitution/invariants.md`
4. `constitution/sectors.md`
5. `constitution/sector-interaction-map.md`
6. `routing/request-types.md`
7. `routing/sdlc.md`

Then read:

1. `adrs/ADR-0043-continuous-backlog-generation-strategy.md`
2. `.claude/agents/netrunner.md`
3. `copilot/issue-authoring-rules.md`
4. `generated/issue-packets/proposed/`
5. `generated/issue-packets/active/`
6. `generated/issue-packets/completed/`
7. `generated/issue-packets/filed-packets.json`
8. `generated/audits/`
9. `generated/scout-reports/`
10. `generated/briefings/urgent.md`
11. `initiatives/current-focus.md`
12. `initiatives/active-initiatives.md`
13. `initiatives/roadmap.md`
14. `initiatives/drift-report.md`
15. `initiatives/board-items.md`

Query GitHub issue states only when needed to identify stale active work. If GitHub access fails, write the briefing with a `GitHub state unavailable` note instead of guessing.

## Branch And PR

Create or reuse branch `chore/backlog-weekly-briefing-{YYYY-MM-DD}`. Open or update one PR against `main` if files change. PR body must include:

- `Authorship: agent-codex`
- `Out-of-band reason: ADR-0043 backlog-weekly-briefing scheduled runner job`
- Counts for new proposed, stale proposed, stale active, urgent, and recommended top three

## Work

Write `generated/briefings/{YYYY-MM-DD}.md` with:

```markdown
# Backlog Briefing - {YYYY-MM-DD}

## Summary
- New proposed packets: {N}
- Completed active packets since last briefing: {N}
- Stale active packets: {N}
- Stale proposed packets: {N}
- Urgent reactive items: {N}

## New Proposed Packets
### Strategic
...
### Tactical
...
### Opportunistic
...
### Reactive
...

## Completed Since Last Briefing
...

## Stale Active Work
...

## Stale Proposed Work
...

## Urgent Reactive Items
...

## Recommended Top 3
1. ...
2. ...
3. ...

## Netrunner Notes
...
```

You may refresh `initiatives/current-focus.md`, `initiatives/roadmap.md`, and `initiatives/active-initiatives.md` only within netrunner's Curator Mode ownership rules. If you do, summarize those edits in `## Netrunner Notes`.

## Constraints

- Do not edit packet contents.
- Do not move packets between lifecycle directories.
- Do not create GitHub issues or mutate The Hive board.
- Do not delete stale proposals; recommend promote, refine, or drop.
- Keep the briefing scannable and concrete.
