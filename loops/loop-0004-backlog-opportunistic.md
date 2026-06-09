---
id: loop-0004-backlog-opportunistic
title: Backlog generation — Opportunistic Scout
status: active
autonomy_tier: A
owner: operator
trigger: "schedule: weekly scheduler with a monthly guard"
write_mode: pr
governing_decisions: [ADR-0093, ADR-0043, ADR-0086]
runner_job: config/jobs/backlog-opportunistic-scout.psd1
created: 2026-06-09
last_validated: 2026-06-09
revalidation_cadence: on any ADR-0043 cadence amendment
---

# loop-0004-backlog-opportunistic — Backlog generation, Opportunistic Scout

> Surveys Grid capabilities and the market on a monthly cadence and surfaces ranked
> opportunities — either as PDR drafts (feeding back into the Strategic source) or as
> direct in-scope improvement packets (ADR-0043 D4 Opportunistic). Deliberately monthly:
> Scout fatigue is real.

## Anatomy

| Part | This loop |
|------|-----------|
| **trigger** | The `backlog-opportunistic-scout` runner job — weekly scheduler with a monthly guard so it effectively fires once a month |
| **inputs** | Grid capabilities (catalogs, contracts, current focus), market/landscape scan |
| **synthesizer** | `product-strategist` Scout mode → `pdr-composer` when a finding rises to product level, via `prompts/backlog-opportunistic-scout.md` |
| **gate** | Human triage — ranked opportunities; high-ranked → PDR drafts; lower-ranked → direct packets or parked for re-evaluation |
| **feedback_sink** | `generated/scout-reports/{YYYY-MM-DD}.md` + `proposed/` packets or PDR-request packets (`source: opportunistic`) |
| **stop** | **Done:** scout report written with ranked opportunities (incl. any "kill" recs). **Stuck:** monthly guard not yet elapsed → no-op. **Over-budget:** runner timeout. |

## Governance envelope

- **budget:** runner job timeout; effectively one substantive pass per month
- **kill_switch:** `Enabled = $false` / unregister the task
- **idempotency:** monthly guard prevents weekly re-runs; dedup proposed packets against existing backlog
- **blast radius:** low (writes to `generated/scout-reports/` + `proposed/` only)

## Success Definition

- **Done-when:** a `generated/scout-reports/{date}.md` exists with ranked opportunities; high-ranked items have PDR-request packets, in-scope items have `proposed/` packets.
- **Still-true:** the report explicitly includes a "kill / build nothing right now" recommendation when warranted (avoids the "anything is better than nothing" failure mode); every packet carries `source` + `generator`.
- **Out-of-bounds:** must not promote to `active/`; must not file issues; must not commit the studio to a product direction (PDR drafts go to the human, then the Strategic source on acceptance).
- **Escalate-when:** an opportunity is genuinely ambiguous in value (surface it ranked, not pre-decided); a finding implies a charter-level portfolio decision.

## Cost & token accounting

- **fidelity:** Codex — exact tokens, USD derived (ADR-0092)
- **per-run cost ceiling:** one monthly scout pass; anomaly-flag a run that 5×'s trailing median
- **cost-per-outcome target:** cost per pursued opportunity; a Scout that never yields a pursued opportunity over several months is a retire candidate at the weekly ROI pass
- **attribution:** per-run, attributed to the Opportunistic source / `product-strategist`
- **model right-sizing:** strong model for survey + ranking; `cfo` (ADR-0046) reviews cost

## Heartbeat & loop-health

- **heartbeat emits:** last substantive run, opportunities surfaced, opportunities pursued, cost
- **revalidation:** on any ADR-0043 cadence change; watch for Scout fatigue (low signal → lengthen cadence before adding sources)
- **escalation style:** weekly-briefing digest

## Notes / history

- 2026-06-09: backfilled as an LDR under ADR-0093. Records the ADR-0043 Opportunistic source as a first-class loop.
