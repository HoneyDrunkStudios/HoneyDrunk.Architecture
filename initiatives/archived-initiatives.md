# Archived Initiatives

Completed and cancelled initiatives. Active and planned work lives in [active-initiatives.md](active-initiatives.md).

---

## Completed

### Grid CI/CD Control Plane (ADR-0012)
**Status:** Complete
**Scope:** Architecture, Actions
**Completed:** 2026-05-27
**Initiative:** `adr-0012-grid-cicd-control-plane`
**Description:** ADR-0012 is accepted and its follow-up rollout has landed: the repo catalog carries tracked workflows, HoneyDrunk.Actions owns the grid-health aggregator and shared CI/CD documentation, the direct-CLI and action-pin inventories are current, caller workflow permissions were audited across the Grid, and the Node 20 deprecated-action bump has shipped.

**Tracking:**
- [x] Architecture#443: Accept ADR-0012, finalize invariants 37-41, register initiative, and reconcile review discipline.
- [x] Architecture#443: Add the GitHub profile workflow-failure notification runbook.
- [x] Architecture#444: Add `tracked_workflows` coverage to the repo catalog.
- [x] Actions#131: Author the grid-health aggregator.
- [x] Actions#131: Refresh canonical consumer permissions documentation.
- [x] Actions#131: Author the action-pin inventory.
- [x] Actions#131: Complete the D4 direct-CLI retrofit audit.
- [x] Architecture#447: Add the caller-workflow permissions audit.
- [x] Actions#153: Bump Node 20 deprecated actions and update pin inventory.
- [x] Architecture#448 and cross-repo follow-ups: grant missing caller permissions surfaced by the audit.

---

### Architecture Command Center
**Status:** Complete  
**Scope:** Architecture  
**Completed:** 2026-03-28  
**Description:** HoneyDrunk.Architecture stood up as the central command center. Catalogs, routing rules, issue templates, copilot instructions, per-repo context docs, and Azure infrastructure documentation all in place.  

---

## Cancelled

### ~~HoneyDrunk.Tools~~ (Scrapped)
**Status:** Cancelled  
**Scope:** Ops  
**Description:** Originally planned as a separate CLI for scanning, accessibility checks, and CI automation. Decision made to implement this logic directly as composite actions within HoneyDrunk.Actions instead.  
