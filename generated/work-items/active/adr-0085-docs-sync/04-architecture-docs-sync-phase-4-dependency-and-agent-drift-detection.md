---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0085", "wave-4"]
dependencies: ["work-item:03"]
adrs: ["ADR-0085"]
accepts: []
source: strategic
generator: scope
wave: 4
initiative: adr-0085-docs-sync
node: honeydrunk-architecture
---

# Phase 4 — add dependency-graph and agent-instruction drift detection (report-only + fallback packets)

## Summary
Activate Phase 4 of the ADR-0085 rollout: enable detection of **dependency-graph drift (D3 #5)** and **agent-instruction drift (D3 #6)**. Both categories emit findings into the per-run report and follow the fallback `proposed/` packet path for editorial work — **neither category is auto-fixed at Phase 4**. The higher false-positive risk of these categories (prose phrasing is variable; named convention may be paraphrased and miss a Grep) means the report is the validation surface before any auto-fix authority is considered.

## Context
ADR-0085 D8 Phase 4 says: "Add dependency-graph and agent-instruction drift detection. Categories 5 and 6 begin emitting findings (still report-only + fallback packets). Higher false-positive risk because prose phrasing is variable; the report is the validation surface before any auto-fix authority is considered."

These categories were defined in D3 from Phase 1 but **detection was deferred** because they have higher false-positive risk than the four categories Phase 1 covered (existence, version drift, symbol drift, catalog drift). The Phase-4 activation is the agent learning to look at the prose-vs-catalog disagreement on dependencies and the prose-vs-`.claude/agents/`-directory disagreement on agent names — and recording what it finds.

Auto-fix authority for these categories is **not granted at Phase 4 and not committed by this packet**. The mechanical-vs-editorial distinction makes both categories inherently editorial: dependency claims in prose are typically narrative ("Notify depends on Vault for secret resolution") rather than enumeration ("Notify consumes: Vault"), and agent-instruction prose names workflows that may have been renamed but conceptually preserved. Any future auto-fix authority would need a dedicated ADR amendment.

## Scope
- `.claude/agents/docs-sync.md` — update the **active-phase guard**: bump active phase from 3 to 4. **Permitted auto-fix categories do not change** (still `["version-drift", "catalog-reference-drift", "dead-intra-repo-link"]`). The Phase-4 change is *detection scope*, not *auto-fix scope*: categories 5 and 6 join the report-only + fallback-packet path.
- `.claude/agents/docs-sync.md` — flesh out the **dependency-graph-drift detection logic** (D3 #5): for each Node, compare prose mentions in the README to the `consumes` array in `catalogs/relationships.json`. Two directions: (a) the README names a consumed Node not in the `consumes` array (`warn`), (b) the `consumes` array contains a Node the README is silent about (`note`). The directionality matters — the first is a likely-stale-prose finding (the dep was removed but the README still mentions it); the second is a likely-incomplete-prose finding (the dep was added but the README never caught up).
- `.claude/agents/docs-sync.md` — flesh out the **agent-instruction-drift detection logic** (D3 #6): for each `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` in scope, check three things: (a) named agents exist in `.claude/agents/` of the Architecture repo (`note` if not — the named agent may have been renamed or removed), (b) named workflows/conventions are not Superseded by an Accepted ADR (`note` if Superseded), (c) named `.github/workflows/*.yml` reusable workflows still exist in `HoneyDrunk.Actions` (`note` if removed). All severities are `note` because prose phrasing is variable and false positives are expected to be higher in this category.
- `.claude/agents/docs-sync.md` — confirm the **fallback packet path** for both new categories: when a finding lands and is not deduped against an existing un-triaged packet, write a `generated/work-items/proposed/{YYYY-MM-DD}-{repo}-docs-{slug}.md` packet per the Phase-2 dedup discipline.
- `constitution/agent-capability-matrix.md` — update the `docs-sync` row's "Consumes" column to confirm `catalogs/relationships.json` and the `.claude/agents/` directory of `HoneyDrunk.Architecture` are now in the read set; "Produces" column does not change (auto-fix scope unchanged).
- `generated/docs-sync-reports/README.md` — append a Phase-4 note documenting the new detection categories and the explicit "report-only + fallback packets, no auto-fix" disposition.

## Proposed Implementation

### Active-phase guard update

```
ACTIVE PHASE: 4 (Phase 4 per ADR-0085 D8 — detection added for categories 5 and 6; auto-fix scope unchanged)
PERMITTED AUTO-FIX CATEGORIES: ["version-drift", "catalog-reference-drift", "dead-intra-repo-link"]  (unchanged from Phase 3)
DETECTION CATEGORIES (all phases): ["missing-required-artifact", "version-drift",
                                    "symbol-reference-drift", "catalog-reference-drift",
                                    "dependency-graph-drift",            # new at Phase 4
                                    "agent-instruction-drift"]           # new at Phase 4
REPORT-ONLY CATEGORIES (Phase 4): ["missing-required-artifact", "symbol-reference-drift",
                                   "dependency-graph-drift", "agent-instruction-drift"]
FALLBACK PACKET PATH (Phase 4): ["symbol-reference-drift", "dependency-graph-drift",
                                 "agent-instruction-drift"] — write to
                                 generated/work-items/proposed/{YYYY-MM-DD}-{repo}-docs-{slug}.md
```

### Dependency-graph-drift detection logic (D3 #5)
For each Node, the agent:
1. Reads `catalogs/relationships.json` and extracts the Node's `consumes` array.
2. Reads the Node's root `README.md` and grep-scans for mentions of other Node names (the canonical list comes from `catalogs/nodes.json`).
3. Compares the two sets:
   - Prose mentions Node X but `consumes` does not list X → `warn` ("README claims dependency on X, catalog does not — likely stale prose").
   - `consumes` lists Node Y but README is silent about Y → `note` ("Catalog records dependency on Y, README does not mention it — likely incomplete prose").
4. Both findings land in the per-run report's per-Node section.
5. The `warn`-severity finding goes through the fallback packet path on the next run if not addressed; the `note`-severity finding does not auto-generate a packet (consistent with the editorial-only nature of "README is incomplete").

### Agent-instruction-drift detection logic (D3 #6)
For each `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` in scope:
1. Extract named agents (via regex/heuristic: phrases like "the `<name>` agent", `\.claude/agents/<name>\.md`, etc.).
2. For each named agent, check that `.claude/agents/<name>.md` exists in `HoneyDrunk.Architecture`. If not, emit a `note`.
3. Extract named workflows/conventions (via regex/heuristic): phrases like "per `<workflow>` workflow", `.github/workflows/<name>.yml`, etc.
4. For each named workflow, check it exists in `HoneyDrunk.Actions/.github/workflows/`. If not, emit a `note`.
5. Extract named conventions/ADR references that are now `Superseded` (Accepted ADR with `**Status:** Superseded`). Emit `note`.

All severities `note` because prose phrasing is variable; the agent should err on the side of surfacing findings for human review rather than asserting a violation.

### Fallback packet path for Phase-4 categories
- **Symbol-reference drift (#3)** — already in scope since Phase 1 as report-only; the fallback-packet path was already established in Phase 2 (packet 02). No change at Phase 4.
- **Dependency-graph drift (#5)** — `warn` findings go through the fallback-packet path; `note` findings are report-only.
- **Agent-instruction drift (#6)** — all findings are `note` and report-only. The agent does **not** auto-generate `proposed/` packets for `note`-only findings (this would over-spam the human's triage queue). Operator decides at the weekly briefing whether any `note` is worth promoting to a packet.

### Capability-matrix update
- `docs-sync` row's "Consumes" column: add `catalogs/relationships.json` and `.claude/agents/` (Architecture-repo directory) to the read set if not already listed.
- "Produces" column: unchanged (auto-fix scope unchanged).
- Decision Tree: unchanged.

### Report-directory README update
Append a Phase-4 section to `generated/docs-sync-reports/README.md`:
- As of Phase 4, the per-Node sections include `dependency-graph-drift` and `agent-instruction-drift` findings.
- Both categories are **detection-only** at Phase 4 — neither is auto-fixed. The fallback-packet path is used for `warn`-severity dependency-graph findings; `note`-only findings stay in the report and surface in the weekly briefing.
- False-positive expectations are higher for these categories than for the four Phase-1 categories; operator should calibrate the report against actual drift before considering any auto-fix authority for these categories in a future ADR amendment.

## Affected Files
- `.claude/agents/docs-sync.md`
- `constitution/agent-capability-matrix.md`
- `generated/docs-sync-reports/README.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] No new runtime dependency between Nodes.
- [x] No `HoneyDrunk.Actions` change.

## Acceptance Criteria
- [ ] `.claude/agents/docs-sync.md` active-phase guard reads Phase 4; `PERMITTED_AUTO_FIX_CATEGORIES` is unchanged from Phase 3; the detection-category list now includes `dependency-graph-drift` and `agent-instruction-drift`
- [ ] The dependency-graph-drift detection logic is documented with the two directions (`warn` for prose-mentions-not-in-catalog, `note` for catalog-lists-not-in-prose) and the per-Node-section report disposition
- [ ] The agent-instruction-drift detection logic is documented with the three checks (named agents exist in `.claude/agents/`, named workflows exist in `HoneyDrunk.Actions/.github/workflows/`, named ADRs not Superseded), all severities `note`
- [ ] The fallback-packet path policy is explicit: `warn` findings go through the path, `note`-only findings stay in the report (no auto-packet to avoid spamming the triage queue)
- [ ] `constitution/agent-capability-matrix.md` `docs-sync` row's "Consumes" column lists `catalogs/relationships.json` and the Architecture-repo `.claude/agents/` directory
- [ ] `generated/docs-sync-reports/README.md` has a Phase-4 section describing the new detection categories and the explicit "no auto-fix" disposition
- [ ] The repo-level `CHANGELOG.md` carries an entry for this Phase-4 activation
- [ ] No README update required at repo root

## Human Prerequisites
- [ ] Confirm Phase 3's exit criterion (catalog-reference rewrites and dead-intra-repo-link rewrites land cleanly with zero false-positive regressions over four weekly runs) is met before this packet's PR merges.
- [ ] After this packet's PR merges, watch the first 4 weekly Phase-4 runs closely: confirm the false-positive rate on dependency-graph and agent-instruction drift findings is **manageable in the weekly briefing** (a triage queue that becomes unsalvageable will defeat the purpose). If the report is over-noisy, tighten the detection heuristics in a follow-up packet rather than reverting Phase 4 wholesale — the detection value is real even if heuristics need tuning.

## Dependencies
- `work-item:03` — **hard**. Phase 3 must be observed working before Phase 4 broadens the detection scope. The Phase-3 catalog-reference reasoning underlies the Phase-4 dependency-graph reasoning (same catalog-driven approach).

## Referenced ADR Decisions

**ADR-0085 D3 #5 (Dependency-graph drift)** — A Node's README naming a consumed Node not in its `consumes` array in `catalogs/relationships.json` (`warn` for missing-from-catalog), or a Node's `consumes` array containing a Node the README is silent about (`note` for missing-from-README).
**ADR-0085 D3 #6 (Agent-instruction drift)** — `AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md` referencing an agent that no longer exists in `.claude/agents/`, naming a workflow/convention an Accepted ADR has superseded, or naming a `.github/workflows/*.yml` reusable workflow that no longer exists in `HoneyDrunk.Actions`. All severities `note`.
**ADR-0085 D7 (editorial-finding packet dedup, verbatim):** Before writing a new `proposed/` packet for a Node (the fallback path), the agent checks for an existing un-triaged packet with `generator: docs-sync` covering the same Node and the same finding category. If found, the existing packet is left alone (Invariant 24 protects packets from agent edits post-creation) and a one-line note is added to the run report.
**ADR-0085 D8 Phase 4** — Categories 5 and 6 begin emitting findings (still report-only + fallback packets). Higher false-positive risk because prose phrasing is variable; the report is the validation surface before any auto-fix authority is considered.

## Constraints
> **Invariant 24:** Work items are immutable once filed as a GitHub Issue. (Applied here: the fallback-packet dedup rule from Phase 2 is preserved — the agent does not edit existing un-triaged `proposed/` packets on subsequent runs.)

> **ADR-0085 D3 #6 (severity, verbatim):** All severities `note`. (Applied: the agent does not auto-generate `proposed/` packets for `note`-only findings; the operator decides at the weekly briefing whether any `note` is worth promoting.)

- **Detection-only at Phase 4 for the two new categories.** No auto-fix authority granted. The active-phase guard's `PERMITTED_AUTO_FIX_CATEGORIES` does not include `dependency-graph-drift` or `agent-instruction-drift`.
- **`note`-only findings are report-only.** They do not auto-generate `proposed/` packets — this would spam the triage queue and defeat ADR-0043's quality-control discipline.
- **Heuristic tightening, not phase revert.** If false-positive rates are too high, the response is to tighten the detection heuristics in a follow-up packet, not to revert this packet — the detection value (knowing the drift exists) is real even when heuristics need tuning.
- **PR metadata for this packet's implementation PR:** `Authorship: agent-claude-code` + `Work Item: HoneyDrunkStudios/HoneyDrunk.Architecture#<issue-number>` once filed.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0085`, `wave-4`

## Agent Handoff

**Objective:** Activate Phase 4 of ADR-0085: enable detection of dependency-graph drift (#5) and agent-instruction drift (#6); keep both report-only + fallback-packet for `warn` (dep-graph) and report-only-only for `note` (everywhere else in the two new categories).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land Phase 4 of ADR-0085 after Phase 3's exit criterion is met.
- Feature: Grid-Wide Documentation Currency Agent rollout, Phase 4.
- ADRs: ADR-0085 (D3 #5, D3 #6, D7, D8 Phase 4).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:03` — hard.

**Constraints:**
- Detection-only at Phase 4 for the two new categories; auto-fix scope unchanged.
- `note`-only findings stay in the report, do not auto-generate `proposed/` packets.
- Heuristic tightening is the response to over-noise, not phase revert.

**Key Files:**
- `.claude/agents/docs-sync.md` (active-phase guard + new detection-logic sections)
- `constitution/agent-capability-matrix.md`
- `generated/docs-sync-reports/README.md`

**Contracts:** None changed.
