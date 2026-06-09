---
id: loop-0003-backlog-tactical
title: Backlog generation — Tactical Node audit
status: active
autonomy_tier: A
owner: operator
trigger: "schedule: weekly (Node-of-the-week rotation)"
write_mode: pr
governing_decisions: [ADR-0093, ADR-0043, ADR-0086]
runner_job: config/jobs/backlog-tactical-audit.psd1
created: 2026-06-09
last_validated: 2026-06-09
revalidation_cadence: on any change to the audit rotation or node-audit definition
---

# loop-0003-backlog-tactical — Backlog generation, Tactical Node audit

> Runs a whole-Node health audit on a rotating Node each week and turns the findings the
> operator elects to act on into packets (ADR-0043 D4 Tactical). Keeps the dormant audit
> surface running on a cadence instead of only when invoked.

## Anatomy

| Part | This loop |
|------|-----------|
| **trigger** | The `backlog-tactical-audit` runner job, weekly; Node selected by the rotation in `initiatives/audit-rotation.md` (12 live Nodes / quarter) |
| **inputs** | The week's Node: `repos/{node}/*`, governing ADRs, catalogs, repo code on disk |
| **synthesizer** | `node-audit` (opinionated whole-Node findings) → `scope` for any finding the human elects to act on, via `prompts/backlog-tactical-audit.md` |
| **gate** | Human triage — the human picks which findings become `active/`; the audit report is committed regardless |
| **feedback_sink** | `generated/audits/{node}-{YYYY-MM-DD}.md` (always) + `generated/issue-packets/proposed/` packets for actionable findings (`source: tactical`) |
| **stop** | **Done:** audit report written + proposed packets for actionable findings. **Stuck:** Node has no actionable findings → report-only run. **Over-budget:** runner timeout. |

## Governance envelope

- **budget:** runner job timeout; one Node per week
- **kill_switch:** `Enabled = $false` / unregister the task
- **idempotency:** dedup proposed packets against existing `proposed/`+`active/` for the same finding
- **blast radius:** low (writes to `generated/audits/` + `proposed/` only)

## Success Definition

- **Done-when:** the week's `generated/audits/{node}-{date}.md` exists, and every finding the report marks actionable has a `proposed/` packet.
- **Still-true:** "we looked at this Node and chose not to act" still leaves an audit-trail record (report committed even when zero packets graduate); every packet carries `source` + `generator`.
- **Out-of-bounds:** must not promote to `active/`; must not file issues; must not edit the audited Node's repo (Architecture is read-only wrt other repos — findings flow through packets).
- **Escalate-when:** a finding's remediation is ambiguous or cross-Node (route through `scope`/`refine`); a finding contradicts a Strategic ADR direction (surface at the weekly briefing — the ADR wins).

## Cost & token accounting

- **fidelity:** Codex — exact tokens, USD derived (ADR-0092)
- **per-run cost ceiling:** one Node audit; anomaly-flag a run that 5×'s trailing median
- **cost-per-outcome target:** cost per actioned finding < manual audit cost
- **attribution:** per-run, attributed to the Tactical source / `node-audit`
- **model right-sizing:** audit reasoning benefits from a strong model; `cfo` (ADR-0046) reviews at the weekly ROI pass

## Heartbeat & loop-health

- **heartbeat emits:** last run, Node audited, findings raised, findings actioned, cost
- **revalidation:** when the rotation list or `node-audit` definition changes; Seed Nodes enter the rotation as they scaffold
- **escalation style:** weekly-briefing digest

## Notes / history

- 2026-06-09: backfilled as an LDR under ADR-0093. Records the ADR-0043 Tactical source as a first-class loop.
