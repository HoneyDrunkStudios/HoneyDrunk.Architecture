---
id: loop-0005-backlog-reactive
title: Backlog generation — Reactive source
status: active
autonomy_tier: A
owner: operator
trigger: "event-driven, continuous (drift / CVE / incident / canary), severity-gated"
write_mode: pr
governing_decisions: [ADR-0093, ADR-0043, ADR-0086, ADR-0084]
runner_job: config/jobs/hive-sync.psd1   # reactive conversion rides the hive-sync run; CVE/incident/canary emitters feed it
created: 2026-06-09
last_validated: 2026-06-09
revalidation_cadence: as reactive emitters (CVE, incident, canary) mature
---

# loop-0005-backlog-reactive — Backlog generation, Reactive source

> Converts events the Grid emits — drift, security CVEs, logged incidents, canary
> failures past grace — into packets, severity-gating only the *delay*, not the triage
> itself (ADR-0043 D4 Reactive, D6). Deduplication is its single most important quality
> control: reactive sources are the easiest to spam.

## Anatomy

| Part | This loop |
|------|-----------|
| **trigger** | Continuous / event-driven: `hive-sync` drift at severity ≥ medium; ADR-0009 nightly scan high+ CVE; a new entry in `generated/incidents/`; a canary failing past its grace window |
| **inputs** | `drift-report.md`; the nightly CVE scan; `generated/incidents/`; canary run state |
| **synthesizer** | `hive-sync` / `scope` — one packet per actionable item, severity carried into frontmatter |
| **gate** | Human triage at the weekly briefing; `priority: urgent` items are surfaced **out-of-band** (not skipped) |
| **feedback_sink** | `generated/issue-packets/proposed/` (`source: reactive`); `generated/briefings/urgent.md` (rolling) for urgent items; Discord routing per `constitution/alert-routing.md` |
| **stop** | **Done:** one deduped packet per actionable event. **Stuck:** no new actionable events → no-op. **Over-budget:** runner timeout. |

## Governance envelope

- **budget:** rides the runner cadence; bounded per run
- **kill_switch:** disable the hive-sync job + the upstream emitter (CVE scan / canary) it reacts to
- **idempotency:** **dedup before create** — check existing `proposed/`+`active/` packets covering the same finding (the load-bearing quality control for this source)
- **blast radius:** low–medium (writes to `proposed/` + `urgent.md`; urgent CVEs touch security-alert routing)

## Success Definition

- **Done-when:** every actionable event (drift ≥ medium, high+ CVE, incident, canary-past-grace) has exactly one `proposed/` packet; urgent items additionally appear in `generated/briefings/urgent.md`.
- **Still-true:** no duplicate packet for an already-covered finding; low-severity drift stays in the report only; every packet carries `source` + `generator`; urgent routing follows `alert-routing.md` (`#security-alerts` for CVE, `#ops-alerts` for incidents).
- **Out-of-bounds:** must not promote to `active/`; must not file issues; must not let the weekly cadence delay an urgent security/incident item (D6 out-of-band escape hatch).
- **Escalate-when:** severity classification is unclear; an event maps to multiple findings; dedup is ambiguous (surface rather than silently merge).

## Cost & token accounting

- **fidelity:** Codex — exact tokens, USD derived (ADR-0092)
- **per-run cost ceiling:** bounded per run; anomaly-flag a burst that 5×'s trailing median (a spam signal)
- **cost-per-outcome target:** cost per actioned reactive item; dedup keeps this low
- **attribution:** per-run, attributed to the Reactive source / `hive-sync`
- **model right-sizing:** triage/classification can use a cheaper model; escalate to a stronger one only for ambiguous items

## Heartbeat & loop-health

- **heartbeat emits:** last run, events seen, packets created, duplicates suppressed, urgent items routed, cost
- **revalidation:** as reactive emitters mature (ADR-0043 Phase 4 expands beyond drift to CVEs, incidents, canaries)
- **escalation style:** weekly digest for ordinary items; **out-of-band interrupt** for `priority: urgent`

## Notes / history

- 2026-06-09: backfilled as an LDR under ADR-0093. Records the ADR-0043 Reactive source as a first-class loop. Per ADR-0043, drift conversion rides the `hive-sync` run today; CVE/incident/canary emitters feed in as they mature (Phase 4).
