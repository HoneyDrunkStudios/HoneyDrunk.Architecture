---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0085", "wave-6"]
dependencies: ["work-item:05"]
adrs: ["ADR-0085", "ADR-0044"]
accepts: []
source: strategic
generator: scope
wave: 6
initiative: adr-0085-docs-sync
node: honeydrunk-architecture
---

# Phase 6 — finalize Friday cadence, decide D9 invariant candidates A/B/C, revisit Authorship-enum

## Summary
Finalize the ADR-0085 rollout. This packet does three things in one PR:
1. **Cadence finalization** — confirm or adjust the weekly Friday cadence based on 90+ days of observation from Phases 1–5. Update ADR-0085 D6 if the cadence changes.
2. **D9 invariant decisions** — decide each of the three candidate invariants A, B, C individually (accept or reject with rationale). Add accepted candidates to `constitution/invariants.md` with the next free numbers. Update Invariant 12 prose if Candidate A is accepted (it amends, rather than adds, an invariant).
3. **Authorship-enum revisit** — decide whether to add `agent-docs-sync` to the `pr-core.yml` Authorship enum. Status-quo is `agent-claude-code` + OOB-reason. If the decision is to add `agent-docs-sync`, this packet does NOT make the `HoneyDrunk.Actions` change itself — it files a follow-up packet against `HoneyDrunk.Actions` per the convention that `HoneyDrunk.Actions` changes are their own packet.

This is the **terminal packet** in the ADR-0085 initiative. When this PR merges, every packet in the initiative reaches `Done` and the entire `active/adr-0085-docs-sync/` folder is eligible for the `hive-sync` archive move to `completed/`.

## Context
ADR-0085 D8 Phase 6 says: "Confirm Friday cadence and OpenClaw integration. If 90-day observation shows weekly is too aggressive or too lax, adjust here. Decide D9 invariant candidates. Decide whether to add `agent-docs-sync` as a first-class `pr-core.yml` Authorship enum value (revisits the D4 metadata decision in light of observed PR volume and operator preference)."

ADR-0085 D9 names three candidate invariants:
- **Candidate A:** "Every Node has a non-empty root `README.md` and `CHANGELOG.md`, validated weekly." Already implied by Invariant 12; if accepted, the prose of Invariant 12 is amended to name `docs-sync`. No new numbered invariant.
- **Candidate B:** "`docs-sync`'s cross-repo write authority is bounded to: (a) one PR per repo per weekly run, (b) auto-edits limited to the file categories in D2, (c) auto-fix categories limited to the per-phase D8 scope active at the time." Locks in the architectural decision against drift; symmetric to ADR-0014 D4's `hive-sync` constraint.
- **Candidate C:** "Mechanical cross-repo reconciliation by named central agents (`hive-sync`, `site-sync`, `docs-sync`) is permitted without packet routing; editorial cross-repo work routes through `generated/work-items/proposed/`." Formalizes the distinction made in D4 between mechanical and editorial work.

Each candidate is decided independently — accept all three, reject all three, or any combination. The operator decides based on whether the rigidity of an invariant is worth the predictability for each candidate.

This is `Actor=Agent` for the doc work (cadence note, invariant additions, ADR amendment, follow-up-packet authoring) — the *decisions* themselves are human (recorded in the PR body or in a brief operator-decision section in the ADR amendment).

## Scope
- `adrs/ADR-0085-grid-wide-documentation-currency-agent.md` — append an "Amendment 1 (Phase 6 finalization)" section recording (a) the cadence decision (kept Friday weekly, or adjusted with rationale), (b) which D9 candidates were accepted/rejected with rationale, (c) the Authorship-enum decision (status quo or follow-up packet filed). Do not change the ADR's Status (it is already Accepted).
- `constitution/invariants.md` — if Candidate B is accepted: add a new numbered invariant with the next free number (per ADR-0044 acceptance pattern — scan the whole file for the highest invariant number, not just the physical tail). If Candidate C is accepted: add another new numbered invariant. If Candidate A is accepted: amend the prose of **Invariant 12** to name `docs-sync` as the weekly validator (no new numbered invariant; this is an amendment).
- `.claude/agents/docs-sync.md` — update the active-phase guard if the cadence changed; otherwise no change. Update the agent's "Why this is permitted to write cross-repo" section to reference the new numbered invariant (if Candidate C lands).
- `constitution/agent-capability-matrix.md` — confirm the `docs-sync` row is at terminal scope (all auto-fix categories from Phases 2–5 active). No further wave qualifiers.
- `generated/docs-sync-reports/README.md` — append a Phase-6 note recording the cadence decision and any invariant additions.
- **If the Authorship-enum decision is to add `agent-docs-sync`:** create a new standalone packet at `generated/work-items/proposed/standalone/{YYYY-MM-DD}-actions-add-agent-docs-sync-authorship-enum.md` targeting `HoneyDrunkStudios/HoneyDrunk.Actions` (and document the cross-reference in the Amendment 1 section of ADR-0085). Do NOT make the `HoneyDrunk.Actions` change in this packet.
- `initiatives/active-initiatives.md` — mark the `adr-0085-docs-sync` initiative as ready-to-archive once this packet's PR merges (the `hive-sync` agent handles the actual archive move per invariant 37).

## Proposed Implementation

### Cadence finalization
Read the per-run reports in `generated/docs-sync-reports/` covering the prior 90+ days. Assess:
- Did Friday land fixes before the weekend gap? (Operational goal of the Friday-slot choice in D6.)
- Did the report surface usefully in `netrunner`'s Monday briefing? (Per ADR-0043 D5 / D8.)
- Was the weekly PR-review workload acceptable, or did docs-sync PRs accumulate? (Per the Operational Consequences section of ADR-0085.)
- Was the auto-fix false-positive rate acceptable across all five auto-fix categories?

Record the decision in ADR-0085's new Amendment 1 section. If the cadence changes (e.g., to bi-weekly), update D6 accordingly. If it stays Friday weekly, the Amendment 1 section just records the confirmation.

### D9 invariant decisions

For each of A, B, C, in the Amendment 1 section, record: **Accepted** or **Rejected**, with a one-paragraph rationale.

If **Candidate A (Accepted):**
- Amend Invariant 12 prose to name `docs-sync` as the weekly validator. Concretely: append a sentence to Invariant 12 — "Weekly validation of the existence and structural correctness of these files is performed by the `docs-sync` agent per ADR-0085."
- No new numbered invariant.

If **Candidate B (Accepted):**
- Find the highest invariant number in `constitution/invariants.md` (scan the whole file — the file is topic-grouped and not contiguously numbered; the physical tail is not always the max).
- Assign the next free number. Add the invariant verbatim from D9: "`docs-sync`'s cross-repo write authority is bounded to: (a) one PR per repo per weekly run, (b) auto-edits limited to the file categories in D2 of ADR-0085, (c) auto-fix categories limited to the per-phase D8 scope of ADR-0085 active at the time." Reference ADR-0085 D4.

If **Candidate C (Accepted):**
- Find the next free invariant number (after Candidate B's if also accepted).
- Add the invariant verbatim from D9: "Mechanical cross-repo reconciliation by named central agents (`hive-sync`, `site-sync`, `docs-sync`) is permitted without packet routing; editorial cross-repo work routes through `generated/work-items/proposed/`." Reference ADR-0085 D4 and ADR-0043 D3.

The PR body must list which invariant numbers were assigned and note the `hive-sync` reconciliation expectation (per the ADR-0044 acceptance precedent).

### Authorship-enum revisit
Two outcomes:
- **Status quo (`agent-claude-code` + OOB-reason).** No `HoneyDrunk.Actions` change. Amendment 1 records the decision and the rationale (typically: PR volume was bounded enough that the one-line OOB-reason cost is acceptable; the operational equivalence held).
- **Add `agent-docs-sync`.** Create the standalone packet at `generated/work-items/proposed/standalone/{YYYY-MM-DD}-actions-add-agent-docs-sync-authorship-enum.md` targeting `HoneyDrunk.Actions`. The packet covers: adding the enum value to `pr-core.yml` Job 7 (Authorship Check), updating any consumer pr-core gates that hard-code the enum list, updating the post-merge audit workflow, and updating `.claude/agents/docs-sync.md` to switch from `Authorship: agent-claude-code` to `Authorship: agent-docs-sync`. The standalone packet inherits ADR-0085's Amendment 1 as its primary reference.

**Enum-switch transaction sequence (when `agent-docs-sync` is added).** The order of operations is load-bearing — any deviation produces a window in which the agent's PRs fail `pr-core` (because the consumer's `pr-core.yml` has not republished the new enum value yet). Strict three-step sequence:

1. **The follow-up packet (filed into `proposed/standalone/` by this packet) authors the PR against `HoneyDrunk.Actions`** that adds `agent-docs-sync` to `pr-core.yml`'s `Authorship:` allowed list. The PR also bumps the `HoneyDrunk.Actions` version per its CHANGELOG cadence.
2. **That PR merges and `pr-core.yml` is republished** (the new enum value is now accepted across the Grid by every consumer repo's next `pr.yml` run, because `pr.yml` calls `pr-core.yml@main`).
3. **Only after step 2** does `.claude/agents/docs-sync.md` switch its declared authorship from `agent-claude-code` to `agent-docs-sync` for new run PRs. This switch is the LAST commit in the transaction.

Reversing steps 2 and 3 — switching the agent's declared authorship before the `pr-core.yml` republish — would cause every subsequent docs-sync PR to fail `pr-core` Job 7 until the consumer repo's next workflow run. Operators must enforce the sequence; the follow-up packet's body should reproduce this three-step list as a procedural constraint.

### Capability-matrix update
- `docs-sync` row's "Produces" column: drop the per-phase qualifiers (e.g., "(Phase 2+, version drift only at v2)") since the rollout is complete. Replace with the terminal scope description: "cross-repo PRs (version-drift + catalog-reference + dead-intra-repo-link + root-README skeleton auto-fixes; symbol/dep-graph/agent-instruction findings report-only)."
- If Candidate C lands, the Execution Rules paragraph that lists cross-repo-PR-authorized agents now references the new invariant by number.

### Report-directory README update
Append a Phase-6 section noting the cadence decision, the invariant additions (with numbers), and the Authorship-enum decision.

### Initiative archive trigger
Update `initiatives/active-initiatives.md` to mark `adr-0085-docs-sync` as `**Status:** Complete — ready to archive`. The `hive-sync` agent moves the initiative block from `active-initiatives.md` to `archived-initiatives.md` on its next scheduled run per invariant 37 and ADR-0014. The `active/adr-0085-docs-sync/` folder moves to `completed/adr-0085-docs-sync/` per ADR-0008 D10 via the same hive-sync pass.

## Affected Files
- `adrs/ADR-0085-grid-wide-documentation-currency-agent.md` (Amendment 1 section)
- `constitution/invariants.md` (conditional on Candidates A/B/C decisions; Candidate A amends Invariant 12, B and C add new numbered invariants)
- `.claude/agents/docs-sync.md` (active-phase guard if cadence changed; cross-repo-write rationale section if Candidate C lands)
- `constitution/agent-capability-matrix.md` (terminal-scope description)
- `generated/docs-sync-reports/README.md` (Phase-6 note)
- `generated/work-items/proposed/standalone/{YYYY-MM-DD}-actions-add-agent-docs-sync-authorship-enum.md` (conditional, only if the Authorship-enum decision is to add the value)
- `initiatives/active-initiatives.md` (mark initiative complete)

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo (the Authorship-enum follow-up, if any, is a *separate* packet against `HoneyDrunk.Actions` that this packet only files into `proposed/`).
- [x] No new runtime dependency between Nodes.
- [x] No direct `HoneyDrunk.Actions` change in this packet.

## Acceptance Criteria
- [ ] ADR-0085 carries an "Amendment 1 (Phase 6 finalization)" section recording the cadence decision, the three D9 candidate decisions (each Accept or Reject with rationale), and the Authorship-enum decision (status quo or follow-up filed)
- [ ] ADR-0085's Status is unchanged (already Accepted)
- [ ] `constitution/invariants.md` reflects the D9 decisions: Candidate A (if accepted) amends Invariant 12's prose to name `docs-sync` as the weekly validator; Candidate B (if accepted) is added with the next free invariant number; Candidate C (if accepted) is added with the next free invariant number after B
- [ ] The PR body lists which invariant numbers were assigned (so the `hive-sync` reconciliation has visibility)
- [ ] `.claude/agents/docs-sync.md` active-phase guard is updated only if the cadence changed; the cross-repo-write rationale section references the new invariant number(s) if Candidate C landed
- [ ] `constitution/agent-capability-matrix.md` `docs-sync` row's "Produces" column reflects the terminal scope (per-phase qualifiers removed); Execution Rules references the new invariant number(s) if Candidate C landed
- [ ] `generated/docs-sync-reports/README.md` has a Phase-6 section recording the cadence decision, invariant additions, and Authorship-enum decision
- [ ] If the Authorship-enum decision is to add `agent-docs-sync`: a standalone packet exists at `generated/work-items/proposed/standalone/{YYYY-MM-DD}-actions-add-agent-docs-sync-authorship-enum.md` targeting `HoneyDrunk.Actions`; this packet does NOT make any `HoneyDrunk.Actions` change directly
- [ ] `initiatives/active-initiatives.md` marks `adr-0085-docs-sync` as `**Status:** Complete — ready to archive`; the archive move itself is `hive-sync`'s responsibility on the next run
- [ ] The repo-level `CHANGELOG.md` carries an entry for this Phase-6 finalization (Amendment 1; invariant decisions; Authorship-enum decision)
- [ ] No README update required at repo root

## Human Prerequisites
- [ ] **Make the three D9 candidate decisions.** Each is independent — accept or reject with rationale per candidate. The agent records the decision but the human makes it.
- [ ] **Make the cadence decision.** Based on the 90+ days of run reports, confirm Friday weekly or adjust with rationale.
- [ ] **Make the Authorship-enum decision.** Based on observed PR volume from Phases 2–5, decide status-quo or follow-up packet.
- [ ] **Confirm the invariant numbers assigned** (if B and/or C are accepted). Scan the entire `constitution/invariants.md` for the highest number — the file is topic-grouped, the physical tail is not always the max. The `hive-sync` agent reconciles final numbering after merge.
- [ ] **Confirm the initiative is genuinely complete** before marking the active-initiatives entry as ready-to-archive — all packets 01, 01a, 02–05 must be Done and all five prior phase exit criteria met. The dispatch plan's Wave-6 exit criterion governs.

## Dependencies
- `work-item:05` — **hard**. Phase 5 must be observed working before Phase 6 finalizes. The 90-day observation window starts at Phase 1 go-live, but Phase 5 lands the last auto-fix category and Phase 6 needs Phase 5's run reports as input to the cadence and invariant decisions.

## Referenced ADR Decisions

**ADR-0085 D6** — Cadence: weekly, Friday; full sweep, not event-driven; OpenClaw scheduled trigger with manual dispatch. The Phase-6 cadence finalization revisits this in light of 90+ days of observation.
**ADR-0085 D8 Phase 6** — Confirm Friday cadence + OpenClaw integration. Decide D9 invariant candidates. Decide whether to add `agent-docs-sync` to `pr-core.yml` Authorship enum.
**ADR-0085 D9** — Three candidate invariants A/B/C, each independently decidable. Candidate A amends Invariant 12. Candidates B and C add new numbered invariants.
**ADR-0044 D6 (Authorship enum)** — Existing enum on `pr-core.yml`. Adding a new value is a coordinated change across `HoneyDrunk.Actions/.github/workflows/pr-core.yml` and every consumer pr-core gate plus the post-merge audit workflow.
**ADR-0044 (acceptance-packet precedent)** — Invariant-numbering reconciliation pattern: scan the whole file for the highest number (the file is topic-grouped and not contiguously numbered); assign the next free pair; record the assignment in the PR body for `hive-sync` reconciliation.

## Constraints
> **Invariant 12 (current text, target of Candidate A amendment):** Semantic versioning with CHANGELOG and README. Breaking changes bump major. New features bump minor. Fixes bump patch. Changelogs follow Keep a Changelog format. Two tiers: Repo-level `CHANGELOG.md` (mandatory); per-package `CHANGELOG.md` (updated only when the specific package has functional changes). Every package directory must also contain a `README.md`. New projects must have both files from the first commit.

> **ADR-0085 D9 (verbatim framing):** Three invariants are candidates, none committed in this ADR. The Proposed status is deliberate: the operator should decide whether each constraint is worth the rigidity before it becomes Grid law. The decision lives in the Phase 6 acceptance packet.

> **ADR-0043 D3 (verbatim, referenced by Candidate C):** Agents never self-promote `proposed/` → `active/`. (Candidate C, if accepted, formalizes this rule as explicitly scoped to packet promotion — not all cross-repo writes — which preserves D3 exactly where it matters.)

- **Acceptance precedes flip pattern does not apply here.** ADR-0085 is already Accepted (from packet 01); Amendment 1 is appended to an Accepted ADR. The ADR's Status does not change.
- **Each D9 candidate is decided independently.** Accept-all, reject-all, or any mix.
- **Invariant numbering pattern from ADR-0044.** Scan the entire `constitution/invariants.md` file for the highest invariant number; assign the next free number(s) for accepted candidates; record assignments in the PR body for `hive-sync` reconciliation.
- **No direct `HoneyDrunk.Actions` change.** If the Authorship-enum decision is to add `agent-docs-sync`, this packet files a standalone packet against `HoneyDrunk.Actions` — it does not make the change itself. This honors the operator's "one PR per repo per initiative" rule and the convention that `HoneyDrunk.Actions` changes are their own scoped work.
- **Initiative archive is `hive-sync`'s responsibility** per invariant 37. This packet marks the initiative `**Status:** Complete — ready to archive` in `active-initiatives.md`; the archive move happens on the next `hive-sync` run.
- **PR metadata for this packet's implementation PR:** `Authorship: agent-claude-code` + `Work Item: HoneyDrunkStudios/HoneyDrunk.Architecture#<issue-number>` once filed.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0085`, `wave-6`

## Agent Handoff

**Objective:** Finalize the ADR-0085 rollout: cadence decision, D9 invariant decisions (A, B, C each), Authorship-enum decision. Append Amendment 1 to ADR-0085. Mark the initiative ready-to-archive. If the Authorship-enum decision is to add `agent-docs-sync`, file a standalone follow-up packet against `HoneyDrunk.Actions`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land Phase 6 of ADR-0085 — the terminal packet in the initiative.
- Feature: Grid-Wide Documentation Currency Agent rollout, Phase 6.
- ADRs: ADR-0085 (D6, D8 Phase 6, D9), ADR-0044 (D6 Authorship enum, acceptance-packet invariant-numbering precedent), ADR-0014 (hive-sync archive responsibility), ADR-0043 (D3 referenced by Candidate C).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:05` — hard.

**Constraints:**
- Each D9 candidate decided independently.
- Invariant numbering follows ADR-0044's scan-for-highest pattern.
- No direct `HoneyDrunk.Actions` change in this packet; follow-up packet files into `proposed/standalone/` if the Authorship-enum decision is to add `agent-docs-sync`.
- Initiative archive is `hive-sync`'s responsibility — this packet marks the initiative complete, not archived.

**Key Files:**
- `adrs/ADR-0085-grid-wide-documentation-currency-agent.md` (Amendment 1)
- `constitution/invariants.md` (conditional on D9 decisions)
- `.claude/agents/docs-sync.md`
- `constitution/agent-capability-matrix.md`
- `generated/docs-sync-reports/README.md`
- `generated/work-items/proposed/standalone/{YYYY-MM-DD}-actions-add-agent-docs-sync-authorship-enum.md` (conditional)
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
