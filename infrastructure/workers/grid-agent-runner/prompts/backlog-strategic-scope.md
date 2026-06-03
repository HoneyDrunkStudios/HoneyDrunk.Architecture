---
title: ADR-0043 Strategic Backlog Source
purpose: Strategic backlog source scheduled job prompt
version: "1.0"
last_modified: 2026-06-03
author: agent-codex
job_id: backlog-strategic-scope
related_agents:
  - scope
tags:
  - adr-0043
  - backlog-generation
  - strategic
---

# ADR-0043 Strategic Backlog Source

You are running as the ADR-0086 `backlog-strategic-scope` scheduled job for `HoneyDrunk.Architecture`.

Objective: find Accepted ADR/PDR decisions that need implementation packets and create reviewable proposed packets under `generated/issue-packets/proposed/`.

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
2. `copilot/issue-authoring-rules.md`
3. `.claude/agents/scope.md`
4. `initiatives/proposed-adrs.md`
5. `initiatives/drift-report.md`
6. `generated/issue-packets/filed-packets.json`
7. Existing packets under `generated/issue-packets/{proposed,active,completed}/`
8. ADR/PDR README indexes and all Accepted ADRs/PDRs that appear unimplemented

## Branch And PR

Create or reuse branch `chore/backlog-strategic-scope-{YYYY-MM-DD}`. Open or update one PR against `main` if files change. PR body must include:

- `Authorship: agent-codex`
- `Out-of-band reason: ADR-0043 backlog-strategic-scope scheduled runner job`
- Summary of decisions scanned, packets created, and skipped dedupes

If no changes are needed, exit cleanly without a PR.

## Work

1. Build a decision inventory for Accepted ADRs/PDRs.
2. Build a packet index from `generated/issue-packets/{proposed,active,completed}/**/*.md`, including `adrs:`, `accepts:`, title, target repo, and slug.
3. Identify Accepted decisions with missing or obviously incomplete implementation packet coverage. Prefer explicit signals from `initiatives/drift-report.md` and `initiatives/proposed-adrs.md` when present.
4. For each uncovered decision, perform a scope-style decomposition:
   - Target exactly one repo per packet.
   - Include dependencies using `dependencies:` schema.
   - Include `source: strategic` and `generator: scope`.
   - Include `adrs:` with the governing decision ID.
   - Include `accepts:` only when the packet gates acceptance of a still-Proposed decision. For already Accepted decisions, use `adrs:` only.
   - Land packets in `generated/issue-packets/proposed/{YYYY-MM-DD}-{repo-short}-{description}.md`.
5. Dedupe before writing. Do not create a packet if a proposed, active, or completed packet already covers the same decision and work item.
6. Write a source report to `generated/briefings/{YYYY-MM-DD}-strategic-source.md`.

## Source Report Format

```markdown
# Strategic Backlog Source - {YYYY-MM-DD}

## Summary
- Decisions scanned: {N}
- Decisions requiring packets: {N}
- Proposed packets created: {N}
- Dedupe skips: {N}

## Decisions Scoped
- **{ADR/PDR ID}**: {title} -> {packet links}

## Skipped
- **{ADR/PDR ID}**: {reason}

## Notes For Weekly Briefing
- {brief note, or `_None._`}
```

## Constraints

- Do not move packets to `active/`.
- Do not create GitHub issues or mutate The Hive board.
- Do not edit filed packets.
- Do not fabricate implementation scope where the decision is too ambiguous; write a single proposed packet to clarify or compose the missing decision instead.
- Keep generated packets self-contained for target-repo execution.
