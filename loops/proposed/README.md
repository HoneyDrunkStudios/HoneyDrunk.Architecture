# Proposed loops — agent landing zone

Agent-authored Loop Definition Record (LDR) candidates land here. They are **not active
loops** until a human promotes them into `loops/`.

**The authorship gate (`[Firm]`, ADR-0093 D6):** agents may write LDR candidates into
this directory; **only a human moves an LDR from `proposed/` to `loops/`.** This is the
single load-bearing fleet-safety control — the same `proposed/` → `active/` discipline
ADR-0043 uses for issue packets. Loop creation is never self-service for an agent,
including loops that would spawn loops.

To propose a loop: copy [`../LDR-TEMPLATE.md`](../LDR-TEMPLATE.md) to
`loop-NNNN-{slug}.md` (next free `NNNN`; ids are never reused), fill every field, and
leave it here for the operator to review, refine, or promote at the weekly briefing.

_No proposed loops yet — the queue is clear._
