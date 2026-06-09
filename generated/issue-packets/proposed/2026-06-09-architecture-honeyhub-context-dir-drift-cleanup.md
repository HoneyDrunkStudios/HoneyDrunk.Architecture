---
title: Reconcile repos/HoneyHub vs repos/HoneyDrunk.HoneyHub context drift
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
wave: 1
initiative: standalone
node: honeydrunk-architecture
tier: 3
labels: ["chore", "tier-3", "meta", "honeyhub", "reactive", "anti-entropy"]
dependencies: []
adrs: ["ADR-0003", "ADR-0090", "ADR-0091", "ADR-0092"]
source: reactive
generator: claude
---

# Reconcile repos/HoneyHub vs repos/HoneyDrunk.HoneyHub context drift

## Summary

Two `repos/*` context directories both describe "HoneyHub" with different ownership,
creating boundary-file ambiguity for any agent that loads "HoneyHub context." Reconcile
them, or mark the stale path historical, so future agents do not load the wrong boundary.

## Context

Surfaced by the ADR-0086 Grid Review advisory verdict on PR #603 (anti-entropy finding):

- **`repos/HoneyHub/overview.md`** — "HoneyHub — Control Plane for the HoneyDrunk Grid"
  (the ADR-0003 graph-driven control-plane concept). `Repo:` = `HoneyDrunkStudios/HoneyDrunk.Architecture`;
  boundaries describe Architecture as owning static topology.
- **`repos/HoneyDrunk.HoneyHub/overview.md`** — the **v1 Agent Cockpit Node** (ADR-0090/0091/0092),
  `node: honeydrunk-honeyhub`, `repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub`; boundaries say
  HoneyHub does **not** own authoritative Architecture/catalog state.

`CLAUDE.md` ("For HoneyHub Context") still points at `repos/HoneyHub/`, so an agent following
it loads the older control-plane file rather than the dedicated cockpit Node's context. The two
are conceptually distinct things that share the name "HoneyHub," which is the root of the
ambiguity.

This is **pre-existing drift** — PR #603 (loop engineering + tracker reconciliation) did not
touch either directory. It is filed here as a deliberate **deferral** per the operator's
decision on the PR #603 grid-review verdict (2026-06-09): handle as a separate, focused cleanup
rather than expanding the loop-engineering PR's scope.

## Scope

- Decide the relationship between the ADR-0003 control-plane "HoneyHub" and the ADR-0090+
  cockpit Node "HoneyDrunk.HoneyHub": are they (a) the same effort renamed (control plane is
  historical), (b) distinct surfaces that need disambiguating names, or (c) layers of one
  program. This is an **architectural decision** — if it is not already settled by ADR-0003 vs
  ADR-0090/0091/0092, convert it into an ADR amendment proposal rather than choosing silently.
- Based on that decision, either reconcile the two context dirs, or add a clear
  "historical / superseded-by" banner to the stale `repos/HoneyHub/overview.md` and
  `boundaries.md` pointing at the correct path.
- Update the `CLAUDE.md` "For HoneyHub Context" pointer so agents load the intended file.

## Acceptance Criteria

- An agent loading "HoneyHub context" via `CLAUDE.md` reaches exactly one authoritative,
  non-contradictory boundary file.
- Any retained legacy `repos/HoneyHub/*` file is explicitly marked historical with a pointer to
  the live path, or removed.
- No two `repos/*` files claim conflicting ownership of HoneyHub topology/catalog state.

## Notes

- Reactive-source packet (ADR-0043 D4): agent-generated, awaiting human triage. Do not promote
  to `active/` without the operator's decision on the architectural question above.
