---
title: Decide the loop-fleet live-state index surface (loops/state.json vs catalog vs Pulse)
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
wave: 1
initiative: standalone
node: honeydrunk-architecture
tier: 3
labels: ["chore", "tier-3", "meta", "loop-engineering", "reactive", "anti-entropy"]
dependencies: []
adrs: ["ADR-0093", "ADR-0086"]
source: reactive
generator: claude
---

# Decide the loop-fleet live-state index surface

## Summary

ADR-0093's loop substrate ships the *static* fleet registry (`loops/` + the LDRs) but
leaves the *live-state* surface — "what is the fleet doing right now" — an explicit open
question. Pick where per-loop runtime state lives so future loop-health/observability work
has one authoritative target instead of three candidates.

## Context

Surfaced by the ADR-0086 Grid Review advisory verdict on PR #603 (non-blocking suggestion,
[Source: Claude]) and already documented as deferred in two places by that same PR:

- **`loops/README.md` → "Live-state index"** — "The 'what is the fleet doing right now'
  live-state surface (per-loop last run, success rate, escalation count, cost) is an open
  question deferred to a substrate follow-up (ADR-0093 Open Questions): it may live here as
  `loops/state.json`, in a catalog, or in Pulse."
- **`constitution/loop-engineering.md`** — names "a single fleet registry surface (`loops/`
  plus a live-state index)" as fleet-readiness posture, without binding the index location.

Until this is decided, per-loop heartbeat is read ad hoc from the runner state/logs and the
Pulse loop-health metrics named in each LDR — workable for the six Tier-A loops, but it does
not scale to the parallel fleet ADR-0093 is built for, and it blocks any "loop console"
(HoneyHub P6) that needs one queryable source.

## Scope

Decide, as an **ADR-0093 amendment / Open-Questions resolution**, where the loop live-state
index lives, weighing at minimum:

- **`loops/state.json` (in-repo)** — simplest; co-located with the LDRs; but it is mutable
  runtime state in a governance repo (tension with the "Architecture holds static topology"
  boundary) and would need a writer (the runner) committing to it.
- **A catalog (`catalogs/*.json`)** — consistent with `grid-health.json`'s "live Node health"
  precedent (already runner/hive-sync-updated); reuses the existing catalog-drift machinery.
- **Pulse (telemetry backend)** — the natural home for time-series success-rate/cost/escalation
  metrics (each LDR already names Pulse loop-health metrics); but it is not a cheap point-in-time
  "fleet snapshot" lookup and adds a query dependency.

A blended answer is allowed (e.g. point-in-time snapshot in a catalog/`state.json`;
time-series in Pulse) — but the deliverable is **one named authoritative surface per concern**,
recorded in ADR-0093 and reflected in `loops/README.md`.

## Acceptance Criteria

- ADR-0093 Open Questions updated with the decision (which surface owns the live-state index,
  who writes it, and the update cadence).
- `loops/README.md` "Live-state index" section updated from "open question" to the chosen
  surface, with a pointer.
- If a new file/catalog field is introduced, the corresponding catalog/drift-report
  expectations are noted (no orphaned surface).

## Notes

- Reactive-source packet (ADR-0043 D4): agent-generated, awaiting human triage. Do not promote
  to `active/` without the operator's decision on the architectural question above.
- Low urgency: the six Tier-A loops are human-gated (`WriteMode=pr`), so the absence of a
  unified live-state index is not yet load-bearing. It becomes load-bearing when loops graduate
  above Tier A or when the HoneyHub Loop Console (ADR-0093 D9 / HoneyHub P6) is built.
