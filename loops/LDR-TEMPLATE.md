---
# Loop Definition Record (LDR) — template
# Copy to loops/proposed/loop-NNNN-{slug}.md, fill every field, leave for human promotion.
# See constitution/loop-engineering.md for the doctrine and naming-conventions.md for the id rule.
id: loop-NNNN-{slug}          # stable, never reused; the unit of fleet identity
title: {Human-readable loop name}
status: proposed              # proposed | active | retired
autonomy_tier: A              # A (human-gated) | B (eval-gated) | C (self-tuning)
owner: operator               # accountable human
trigger: {clock or event}     # e.g. "schedule: Mon/Wed/Fri 09:00 local" or "event: CI failed on watched PR"
write_mode: pr                # pr (floor) — artifacts are the write boundary; never authoritative mutation outside a branch/PR
governing_decisions: [ADR-0093]
runner_job: config/jobs/{loop-id}.psd1   # the ADR-0086 job spec, if runner-hosted; else "n/a"
created: YYYY-MM-DD
last_validated: YYYY-MM-DD
revalidation_cadence: {e.g. "quarterly" or "on ADR-0043 amendment"}
---

# {id} — {title}

> One-paragraph statement of what this loop is for and why it exists.

## Anatomy

| Part | This loop |
|------|-----------|
| **trigger** | {what wakes it} |
| **inputs** | {state it reads to decide what to do} |
| **synthesizer** | {agent + prompt template that turns a state-delta into a scoped prompt} |
| **gate** | {the check the output must pass — points at the Success Definition below} |
| **feedback_sink** | {where results are written so the next iteration improves} |
| **stop** | {terminal condition(s): done / stuck / over-budget} |

## Governance envelope

- **budget:** {per-run and per-window cost/iteration cap — ADR-0052}
- **kill_switch:** {the named control that halts this loop; participates in stop-the-world at fleet scale}
- **idempotency:** {the dedup/lease key shape for safe concurrent runs — ADR-0042}
- **blast radius:** {low / medium / high — bounds the autonomy tier per ADR-0087}

## Success Definition

> Executable checks (commands + expected outcomes), **authored separately from the worker.**
> A loop above Tier A requires all four bands complete and machine-checkable.

- **Done-when:** {did the intended thing happen? — the command(s) that prove it}
- **Still-true:** {did nothing else break? — regression/canary/coverage + the per-run cost ceiling}
- **Out-of-bounds:** {what the loop may NOT do to reach green — invariants, boundaries, "don't delete tests", "coverage may not drop"}
- **Escalate-when:** {when the loop may NOT self-certify — unevaluable criterion, conflicting checks, ambiguity → human gate}

## Cost & token accounting

- **fidelity:** {exact | derived | estimated — ADR-0092; declare what the backend gives; never render an estimate as exact}
- **per-run cost ceiling:** {USD or token cap; breaching it is a `still-true` gate failure}
- **cost-per-outcome target:** {loop ROI — retire the loop if it costs more than doing the task by hand}
- **attribution:** {per-loop / per-agent / per-run — ADR-0052 D6}
- **model right-sizing:** {cheapest model that clears the gate — ADR-0041 registry; caching where supported}

## Heartbeat & loop-health

- **heartbeat emits:** last run, success rate, escalation count, cost (via Pulse — ADR-0010/0040)
- **revalidation:** {cadence + what "the loop has rotted" would look like — stale gate, drifted inputs}
- **escalation style:** {digest vs. interrupt; what a good escalation contains — diagnosis + options, not "failed"}

## Notes / history

- {date}: {change}
