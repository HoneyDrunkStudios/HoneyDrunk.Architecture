---
title: ADR-0043 Tactical Node Audit Source
purpose: Tactical node-audit backlog source scheduled job prompt
version: "1.0"
last_modified: 2026-06-03
author: agent-codex
job_id: backlog-tactical-audit
related_agents:
  - node-audit
  - scope
tags:
  - adr-0043
  - backlog-generation
  - tactical
---

# ADR-0043 Tactical Node Audit Source

You are running as the ADR-0086 `backlog-tactical-audit` scheduled job for `HoneyDrunk.Architecture`.

Objective: audit the next due Live Node, write a durable audit report, and create proposed packets for high-confidence actionable findings.

## Load First

Read:

1. `adrs/ADR-0043-continuous-backlog-generation-strategy.md`
2. `.claude/agents/node-audit.md`
3. `.claude/agents/scope.md`
4. `copilot/issue-authoring-rules.md`
5. `initiatives/audit-rotation.md`
6. `catalogs/nodes.json`
7. `catalogs/relationships.json`
8. `catalogs/contracts.json`
9. `catalogs/compatibility.json`
10. Relevant `repos/{node}/` Architecture context
11. Existing packets under `generated/issue-packets/{proposed,active,completed}/`

Then walk the selected Node repository on disk if it exists next to this Architecture checkout.

## Select Node

Choose the first rotation row with a blank `Last audited`. If all rows have a date, choose the oldest `Last audited`. If the selected repo is unavailable locally, write a skipped report explaining the missing path and do not update `Last audited`.

## Branch And PR

Create or reuse branch `chore/backlog-tactical-audit-{YYYY-MM-DD}`. Open or update one PR against `main` if files change. PR body must include:

- `Authorship: agent-codex`
- `Out-of-band reason: ADR-0043 backlog-tactical-audit scheduled runner job`
- Node audited, verdict, packet count, and skipped/dedupe count

## Work

1. Run the node-audit rubric against the selected Node.
2. Write `generated/audits/{node}-{YYYY-MM-DD}.md` using the node-audit output format.
3. For Blocking and Changes Requested findings that are concrete and packet-able, create proposed packets:
   - Land in `generated/issue-packets/proposed/{YYYY-MM-DD}-{repo-short}-{description}.md`.
   - Include `source: tactical` and `generator: node-audit`.
   - Cite the audit report path in Context.
   - Include full relevant invariant/boundary text in Constraints.
4. Dedupe against existing proposed, active, and completed packets.
5. Update only the selected row's `Last audited` and `Last report` columns in `initiatives/audit-rotation.md` after a successful audit.

## Constraints

- Do not move packets to `active/`.
- Do not create GitHub issues or mutate The Hive board.
- Do not fix the audited repo directly.
- Do not create packets for low-confidence suggestions; leave them in the report.
- If the audit finds a committed secret, do not quote the value. Create only a redacted urgent packet and route it through the report.
