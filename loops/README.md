# Loops — the Grid loop registry

This directory is the **fleet registry surface** for loop engineering: one Loop
Definition Record (LDR) per loop, the same first-class move the Grid made for ADRs,
PDRs, and BDRs. The governing decision is
[ADR-0093](../adrs/ADR-0093-loop-engineering-closed-loop-agent-orchestration.md); the
doctrine is [`constitution/loop-engineering.md`](../constitution/loop-engineering.md).

A **loop** is a feedback control system that invokes an agent: triggered by state, it
synthesizes a scoped prompt, runs a bounded agent, evaluates the output against a gate,
writes the result back so the next iteration is better, and stops on a terminal
condition. An automation with a trigger and a synthesizer but **no gate and no feedback
sink is not a loop — it is a cron job** (it stays on GitHub Actions cron per ADR-0068,
not here).

## Layout

```text
loops/
├── README.md            ← this file (the live registry index)
├── LDR-TEMPLATE.md      ← copy this to author a new LDR
├── loop-NNNN-{slug}.md  ← active, human-promoted loops
└── proposed/            ← agent-authored loop candidates awaiting human promotion
```

**Authorship gate (`[Firm]`, ADR-0093 D6):** agents may propose loops into `proposed/`;
**only a human promotes a loop into `loops/`.** This is the load-bearing fleet-safety
control — it is what stops a fleet of agents from silently spinning up autonomous loops.

## Active loops

| LDR | Loop | Trigger | Tier | Gate | Governing decision |
|-----|------|---------|------|------|--------------------|
| [loop-0001](loop-0001-hive-sync.md) | Hive reconciliation (`hive-sync`) | schedule (Mon/Wed/Fri) | A | human review of the reconciliation PR | ADR-0014 |
| [loop-0002](loop-0002-backlog-strategic.md) | Backlog — Strategic source | schedule, after `hive-sync` | A | human `proposed/`→`active/` triage | ADR-0043 |
| [loop-0003](loop-0003-backlog-tactical.md) | Backlog — Tactical Node audit | schedule (weekly rotation) | A | human triage of audit findings | ADR-0043 |
| [loop-0004](loop-0004-backlog-opportunistic.md) | Backlog — Opportunistic Scout | schedule (weekly, monthly guard) | A | human triage incl. "kill" | ADR-0043 |
| [loop-0005](loop-0005-backlog-reactive.md) | Backlog — Reactive (drift/CVE/incident/canary) | event-driven, severity-gated | A | human triage; urgent out-of-band | ADR-0043 |
| [loop-0006](loop-0006-pr-activity-autofix.md) | PR-activity autofix build loop | event (CI/review on watched PR) | A | CI green + human review/merge | ADR-0086 / ADR-0044 |

> All six v1 loops are **Tier A (human-gated)**. Tier B (eval-gated) is blocked on the
> Evals Node (ADR-0023); Tier C (self-tuning) is future. See the autonomy ladder in the
> doctrine.

## Proposed loops

See [`proposed/`](proposed/). Empty until an agent proposes a loop candidate.

## Live-state index

The "what is the fleet doing right now" live-state surface (per-loop last run, success
rate, escalation count, cost) is an open question deferred to a follow-up packet
(ADR-0093 Open Questions → `generated/issue-packets/proposed/2026-06-09-architecture-loop-fleet-live-state-index.md`):
it may live here as `loops/state.json`, in a catalog, or in Pulse. This substrate does not
decide it. Until then, per-loop heartbeat is read from the runner state/logs and the Pulse
loop-health metrics named in each LDR.
