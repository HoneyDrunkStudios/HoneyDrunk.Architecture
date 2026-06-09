---
title: ADR-0043 Tactical Audit Rotation
status: Active
last_updated: 2026-06-03
owner: backlog-tactical-audit runner job
source_adr: ADR-0043
---

# ADR-0043 Tactical Audit Rotation

This file records the weekly Node rotation for ADR-0043's Tactical backlog source. The runner selects the first row with a blank `Last audited`; after the first full pass, it selects the oldest `Last audited` date.

Rules:

- Audit one Live Node per weekly run.
- Write the audit report to `generated/audits/{node}-{YYYY-MM-DD}.md`.
- Create proposed packets only for actionable, high-confidence findings.
- Proposed packets use `source: tactical` and `generator: node-audit`.
- Update only the `Last audited` and `Last report` columns after a successful run.
- Seed Nodes enter the rotation when they become Live.

| Order | Node | Repo | Last audited | Last report |
|---:|---|---|---|---|
| 1 | HoneyDrunk.Kernel | HoneyDrunk.Kernel | 2026-06-09 | generated/audits/HoneyDrunk.Kernel-2026-06-09.md |
| 2 | HoneyDrunk.Transport | HoneyDrunk.Transport |  |  |
| 3 | HoneyDrunk.Vault | HoneyDrunk.Vault |  |  |
| 4 | HoneyDrunk.Auth | HoneyDrunk.Auth |  |  |
| 5 | HoneyDrunk.Web.Rest | HoneyDrunk.Web.Rest |  |  |
| 6 | HoneyDrunk.Data | HoneyDrunk.Data |  |  |
| 7 | HoneyDrunk.Notify | HoneyDrunk.Notify |  |  |
| 8 | HoneyDrunk.Communications | HoneyDrunk.Communications |  |  |
| 9 | HoneyDrunk.Actions | HoneyDrunk.Actions |  |  |
| 10 | HoneyDrunk.Architecture | HoneyDrunk.Architecture |  |  |
| 11 | HoneyDrunk.Standards | HoneyDrunk.Standards |  |  |
| 12 | HoneyDrunk.Studios | HoneyDrunk.Studios |  |  |
