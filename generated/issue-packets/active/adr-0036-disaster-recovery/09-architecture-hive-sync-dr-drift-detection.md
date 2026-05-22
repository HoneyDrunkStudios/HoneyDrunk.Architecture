---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0036", "wave-3"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0036", "ADR-0014"]
accepts: ["ADR-0036"]
wave: 3
initiative: adr-0036-disaster-recovery
node: honeydrunk-architecture
---

# Extend hive-sync to reconcile dr_tier assignments and overdue restore drills (ADR-0036 D1/D3/D9)

## Summary
Extend the `hive-sync` agent's drift-reconciliation mandate to cover two ADR-0036 concerns: (1) a stateful Node missing a `dr_tier` in `catalogs/grid-health.json` is drift; (2) a Node whose most recent restore-drill log in `generated/restore-drills/` is overdue per its tier cadence is drift — and triggers the tier-affecting tenant-onboarding freeze.

## Context
ADR-0036 D1: "`hive-sync` (ADR-0014) treats a Node holding state without a `dr_tier` as drift." ADR-0036 D9: "`generated/restore-drills/` is the rolling log of drill outcomes; `hive-sync` includes it in drift reconciliation." ADR-0036 D3: "A missed drill is an incident: it triggers a Tier-promotion freeze on the affected Node." Packet 00 added the two DR invariants; packet 01 created the `dr_tier` field; packet 02 created `generated/restore-drills/` and its log schema. This packet wires the `hive-sync` agent so those artifacts are actually reconciled rather than passively present.

`hive-sync` is an agent defined by `.claude/agents/hive-sync.md` in `HoneyDrunk.Architecture`; per ADR-0014 it runs through OpenClaw scheduled/manual execution. This packet updates the agent's instructions — its drift-detection contract — not a .NET project.

## Scope
- `.claude/agents/hive-sync.md` — extend the drift-reconciliation section with the two ADR-0036 checks.
- `initiatives/board-items.md` — note that `dr_tier`-missing and overdue-drill findings are surfaced as board items (per ADR-0014 D3 / invariant 38, non-initiative drift findings land here).

## Proposed Implementation
1. **Extend `hive-sync.md`'s drift-detection contract** with two checks:
   - **`dr_tier` completeness check.** For every Node in `catalogs/grid-health.json` that holds durable state (the operative test: it has a non-null backing, or it appears in any ADR-0036 D1 tier-membership list), confirm a non-null `dr_tier`. A stateful Node with `dr_tier: null` or no field is drift — surface it. Stateless Nodes with explicit `dr_tier: null` are not drift (that is the documented stateless marker from packet 01).
   - **Restore-drill currency check.** For every T0/T1/T2 Node, find the most recent entry for it in `generated/restore-drills/` and compute whether the drill is overdue against the tier cadence:
     - T0: annual drill (overdue if last drill > 12 months ago); semiannual partial spot-check.
     - T1: semiannual drill (overdue if > 6 months).
     - T2: annual drill (overdue if > 12 months).
     A Node with no drill log at all is overdue by definition once the 90-day first-drill grace window has elapsed since ADR-0036's acceptance. **The grace-window anchor is not a hardcoded date** — `hive-sync` must read ADR-0036's accepted-date from the ADR header (`adrs/ADR-0036-disaster-recovery-and-backup-policy.md`, the `**Status:**`/accepted-date line) at runtime and compute `accepted-date + 90 days` as the grace boundary. Do not bake a literal date into `hive-sync.md`. An overdue drill is drift AND triggers the tenant-onboarding-freeze flag — `hive-sync` surfaces the affected Node and the freeze status.
2. **Define how findings surface.** Per ADR-0014 D3 and invariant 38, drift findings that are not packet-originated are mirrored onto The Hive and tracked in `initiatives/board-items.md`. A `dr_tier`-missing finding and an overdue-drill finding each become a board item. Document this in `hive-sync.md` and add the note to `board-items.md`.
3. **Keep it advisory.** Like the other `hive-sync` checks, this is detection + surfacing — `hive-sync` does not itself enforce the freeze (that is an operator decision per ADR-0036 D3). It reports; the human acts.

## Affected Files
- `.claude/agents/hive-sync.md`
- `initiatives/board-items.md`

## NuGet Dependencies
None. This packet edits an agent definition and a Markdown tracking file; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/hive-sync.md` and `initiatives/board-items.md` live in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `.claude/agents/hive-sync.md`'s drift-reconciliation section includes a `dr_tier` completeness check — a stateful Node missing a non-null `dr_tier` is drift; stateless Nodes with explicit `dr_tier: null` are not drift
- [ ] `hive-sync.md` includes a restore-drill currency check with the per-tier overdue windows (T0 annual, T1 semiannual, T2 annual) and the no-log-at-all rule against the 90-day first-drill grace window
- [ ] The grace-window anchor is computed at runtime from ADR-0036's accepted-date read out of the ADR header — `hive-sync.md` does not hardcode a literal date
- [ ] `hive-sync.md` states an overdue drill triggers the tenant-onboarding-freeze flag and surfaces the affected Node + freeze status
- [ ] `hive-sync.md` states the checks are advisory — `hive-sync` detects and surfaces; it does not enforce the freeze
- [ ] `initiatives/board-items.md` documents that `dr_tier`-missing and overdue-drill findings are surfaced as board items per ADR-0014 D3 / invariant 38
- [ ] No change to the `hive-sync` packet-move contract (invariant 37) — this packet adds drift checks, it does not change which directories `hive-sync` moves packets between

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0036 D1.** "`hive-sync` (ADR-0014) treats a Node holding state without a `dr_tier` as drift."

**ADR-0036 D3 — Restore drills are the proof.** A missed drill is an incident; it triggers a Tier-promotion freeze on the affected Node — no new tenants onboarded against a Node whose last drill is overdue. Drill cadences: T0 annual + semiannual spot-check, T1 semiannual, T2 annual.

**ADR-0036 D9.** "`generated/restore-drills/` is the rolling log of drill outcomes; `hive-sync` includes it in drift reconciliation."

**ADR-0036 Follow-up Work.** "Schedule the first Vault and Audit drills within 90 days of this ADR's acceptance" — the 90-day grace window for the no-log-at-all rule. The anchor is ADR-0036's accepted-date, read from the ADR header at runtime, not a hardcoded value.

**ADR-0014 — Hive–Architecture Reconciliation Agent.** `hive-sync` (renamed from `initiatives-sync`) has a broad drift-reconciliation mandate and runs through OpenClaw scheduled/manual execution. D3 / invariant 38: non-initiative drift findings are tracked in `initiatives/board-items.md`.

## Constraints
> **Invariant 60 (added by packet 00) — every Node holding state has a `dr_tier` assignment in `catalogs/grid-health.json`.** This packet wires the `hive-sync` check that enforces detection of violations of that invariant.

> **Invariant 61 (added by packet 00) — a missed restore drill freezes tier-affecting tenant onboarding for the affected Node.** This packet wires the `hive-sync` check that detects an overdue drill and surfaces the freeze.

> **Invariant 38 — the Architecture repo tracks all Hive board items.** Every non-initiative drift finding is represented in `initiatives/board-items.md`.

> **Invariant 37 — `hive-sync` packet-move contract.** `hive-sync` moves closed packets from `active/` to `completed/`. This packet does NOT alter that contract — it only adds drift-detection checks.

- **Advisory, not enforcing.** `hive-sync` detects and surfaces; the operator decides on the freeze (ADR-0036 D3). Do not make `hive-sync` mutate onboarding state.
- **Stateless `dr_tier: null` is not drift** — only stateful Nodes missing a tier are drift. The packet-01 `_meta` documentation defines the stateless marker.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0036`, `wave-3`

## Agent Handoff

**Objective:** Extend the `hive-sync` agent to reconcile `dr_tier` completeness and restore-drill currency, surfacing both as board-item drift findings.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the two packet-00 DR invariants actively reconciled rather than passively documented.
- Feature: ADR-0036 Disaster Recovery rollout, Wave 3.
- ADRs: ADR-0036 (D1/D3/D9, Follow-up Work), ADR-0014 (`hive-sync` mandate, board-items tracking).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — hard. The `dr_tier` field must exist in `grid-health.json` for the completeness check to read.
- `packet:02` — hard. `generated/restore-drills/` and its log schema must exist for the currency check to read.

**Constraints:**
- Advisory only — detect and surface; do not enforce the freeze.
- Stateless `dr_tier: null` is not drift.
- Do not alter the invariant-37 packet-move contract.

**Key Files:**
- `.claude/agents/hive-sync.md`
- `initiatives/board-items.md`

**Contracts:** No runtime contract change — an agent-definition update.
