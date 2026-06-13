---
id: loop-0002-backlog-strategic
title: Backlog generation — Strategic source
status: active
autonomy_tier: A
owner: operator
trigger: "schedule: after hive-sync (acceptance/age detection)"
write_mode: pr
governing_decisions: [ADR-0093, ADR-0043, ADR-0086]
runner_job: infrastructure/workers/grid-agent-runner/config/jobs/backlog-strategic-scope.psd1
created: 2026-06-09
last_validated: 2026-06-09
revalidation_cadence: on any ADR-0043 cadence/prompt amendment
---

# loop-0002-backlog-strategic — Backlog generation, Strategic source

> Turns Accepted (or stale-Proposed) decisions into scoped implementation packets, so an
> ADR/PDR moving to Accepted no longer waits on a human to remember to decompose it
> (ADR-0043 D4 Strategic).

## Anatomy

| Part | This loop |
|------|-----------|
| **trigger** | The `backlog-strategic-scope` runner job, scheduled after `loop-0001`; fires on ADR/PDR status changes to `Accepted` (or a `Proposed` decision aged past 14 days) with missing implementation packets |
| **inputs** | `adrs/`/`pdrs/` frontmatter + acceptance signals from hive-sync; `generated/work-items/**` (to detect missing packets); catalogs, repo boundaries |
| **synthesizer** | `scope`-like decomposition via `prompts/backlog-strategic-scope.md` (one packet per implied implementation step; one dispatch plan per multi-repo rollout) |
| **gate** | Human `proposed/` → `active/` triage at the weekly briefing; `refine` runs against any dispatch plan implying > 3 packets before packets land |
| **feedback_sink** | `generated/work-items/proposed/` packets (each carrying `source: strategic` + `generator`) and a per-run source report |
| **stop** | **Done:** the acceptance/age scan completes and proposed packets are written. **Stuck:** no actionable decisions → no-op run. **Over-budget:** runner timeout. |

## Governance envelope

- **budget:** runner job timeout; one pass per schedule tick
- **kill_switch:** `Enabled = $false` in the job spec / unregister the task
- **idempotency:** dedup against existing `proposed/`+`active/` packets for the same decision before writing (no duplicate decomposition)
- **blast radius:** low (writes only to `proposed/`; agents never self-promote to `active/`)

## Success Definition

- **Done-when:** every newly-Accepted decision with no implementing packets has either a `proposed/` packet (or dispatch plan) or an explicit "no work implied" note in the source report.
- **Still-true:** all output is `proposed/` only; every packet carries `source` + `generator` frontmatter (ADR-0043 invariant); no GitHub issue is created by this loop.
- **Out-of-bounds:** must not promote `proposed/` → `active/`; must not file issues; must not scope unaccepted work (the 14-day age-out surfaces "accept or kill", it does not authorize decomposition of un-accepted decisions).
- **Escalate-when:** a decision's decomposition is ambiguous or implies > 3 packets (route through `refine` before landing); conflicting direction across decisions (surface at the weekly briefing — the ADR wins).

## Cost & token accounting

- **fidelity:** Codex — exact tokens, USD derived (ADR-0092)
- **per-run cost ceiling:** one decomposition pass; anomaly-flag a run that 5×'s trailing median
- **cost-per-outcome target:** cost per usable proposed packet < the manual cost of scoping it
- **attribution:** per-run, attributed to the Strategic source / `scope`
- **model right-sizing:** strong-enough model for decomposition; `cfo` (ADR-0046) reviews cost at the weekly ROI pass

## Heartbeat & loop-health

- **heartbeat emits:** last run, packets proposed, decisions scanned, cost
- **revalidation:** on any ADR-0043 amendment to cadence, prompt strictness, or dedup
- **escalation style:** weekly-briefing digest; no interrupt (Strategic is not time-critical)

## Notes / history

- 2026-06-09: backfilled as an LDR under ADR-0093. Records the ADR-0043 Strategic source as a first-class loop.
