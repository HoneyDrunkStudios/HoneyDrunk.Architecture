---
id: loop-0001-hive-sync
title: Hive–Architecture reconciliation (hive-sync)
status: active
autonomy_tier: A
owner: operator
trigger: "schedule: Mon/Wed/Fri 09:00 local"
write_mode: pr
governing_decisions: [ADR-0093, ADR-0014, ADR-0086]
runner_job: config/jobs/hive-sync.psd1
created: 2026-06-09
last_validated: 2026-06-09
revalidation_cadence: quarterly, or on any change to hive-sync's mutation surface
---

# loop-0001-hive-sync — Hive–Architecture reconciliation

> Keeps the Architecture repo a complete mirror of The Hive's live issue state:
> reconciles initiative tracking, moves completed packets, tracks non-initiative board
> items, surfaces the Proposed-ADR/PDR queue, auto-accepts decisions whose implementing
> work is closed, syncs README index columns, and reports drift. The canonical scheduled
> reconciliation loop (ADR-0014).

## Anatomy

| Part | This loop |
|------|-----------|
| **trigger** | ADR-0086 runner schedule (Mon/Wed/Fri 09:00 local); manual dispatch available |
| **inputs** | `filed-packets.json`; `gh` issue states; GraphQL Hive board state; all `catalogs/*.json`; `adrs/ADR-*.md` + `pdrs/PDR-*.md` frontmatter; `initiatives/` files |
| **synthesizer** | `.claude/agents/hive-sync.md` run via Codex on the runner (state-delta between Architecture files and live Hive → reconciliation edits) |
| **gate** | Human review of the reconciliation PR (Tier A) |
| **feedback_sink** | The reconciliation PR: updated `initiatives/` files, packet moves (`active/`→`completed/`), `board-items.md`, `proposed-adrs.md`, `drift-report.md`, bounded catalog reconciliation, README index Status/Date |
| **stop** | **Done:** PR opened/updated for the run. **Stuck:** single-pass job — a failed run escalates via the runner. **Over-budget:** 45-min timeout. |

## Governance envelope

- **budget:** `TimeoutMinutes = 45`; one run per schedule tick; `MaxMissedRuns = 2`
- **kill_switch:** set `Enabled = $false` in `config/jobs/hive-sync.psd1` or unregister the Task Scheduler task
- **idempotency:** one date-based branch per run; `ConcurrencyKey = "hive-sync"`; the PR is updated in place, not duplicated
- **blast radius:** low–medium (Architecture-repo files only; **never** mutates The Hive board)

## Success Definition

- **Done-when:** the reconciliation PR exists/updates with the run's changes and `initiatives/drift-report.md` (the job's `OutputContract.LatestOutput`) is regenerated.
- **Still-true:** no Hive board mutation (read-only wrt the board); only hive-sync's enumerated mutation surfaces are touched; coverage/canaries are not in scope for this loop but the PR must pass Architecture-repo CI.
- **Out-of-bounds:** must not edit `current-focus.md` (netrunner owns it) or netrunner's narrative/ordering columns; must not edit `grid-health.json`/`nodes.json`/`relationships.json`/`contracts.json` beyond the derived reconciliation fields; must not create issues; must not auto-add catalog rows; must not flip `Accepted → Proposed`; must respect `MAX_FLIPS_PER_RUN`.
- **Escalate-when:** a packet→decision mapping is ambiguous; drift cannot be classified into a known category; flip candidates exceed `MAX_FLIPS_PER_RUN` (surface as "Pending Flip", do not flip).

## Cost & token accounting

- **fidelity:** Codex — exact tokens, USD **derived** from operator rates (ADR-0092)
- **per-run cost ceiling:** bounded in practice by the 45-min timeout; flag a run that 5×'s its trailing-median cost (ADR-0052 anomaly rule)
- **cost-per-outcome target:** one reconciliation PR per run; cheap relative to manual reconciliation of initiative state
- **attribution:** per-run, attributed to `hive-sync`
- **model right-sizing:** Codex default; no high-reasoning model required for mechanical reconciliation

## Heartbeat & loop-health

- **heartbeat emits:** last run, PR opened/updated, drift-item count, flips this run, cost
- **revalidation:** quarterly, or whenever hive-sync's authorized mutation surface changes (that is itself an ADR-level decision)
- **escalation style:** runner Discord summary to `#hive-activity`; anomalies/failures surface out-of-band

## Notes / history

- 2026-06-09: backfilled as an LDR under ADR-0093 (Tier-A substrate). No behavior change — this records the loop that ADR-0014 already runs.
