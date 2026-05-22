---
name: Architecture Decision
type: architecture-decision
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-1", "meta", "adr-0044", "wave-4"]
dependencies: ["packet:04", "packet:09"]
adrs: ["ADR-0044", "ADR-0014"]
accepts: ["ADR-0044"]
wave: 4
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Wire hive-sync to detect drift between D3 and the agent files' category lists

## Summary
Update the `hive-sync` agent definition so its reconciliation pass detects drift between ADR-0044 D3's twenty-category rubric and the category lists referenced in `review.md`, `scope.md`, `adr-composer.md`, `pdr-composer.md`, `refine.md`, and `node-audit.md` — and surfaces any divergence in the drift report.

## Context
ADR-0044 D3 states: "Drift between this D3 and any agent file is an anti-pattern; `hive-sync` (per ADR-0014) reconciles." The rubric is bound by D3, but its per-category execution detail and the per-agent subset references live in seven agent files (packets 04 and 09). Over time, an edit to one agent file's category list, or a D3 amendment that does not propagate, creates silent drift. This packet makes that drift detectable — it adds the D3↔agent-file consistency check to `hive-sync`'s reconciliation mandate.

## Scope
- `.claude/agents/hive-sync.md` (or wherever the `hive-sync` agent definition lives) — add the D3 drift-detection responsibility.

## Proposed Implementation
Add a section to the `hive-sync` agent definition specifying a new reconciliation check:
- **Source of truth:** ADR-0044 D3's twenty named categories (and their bound questions).
- **Targets checked:** the category lists / D3-referencing sections in `.claude/agents/review.md`, `scope.md`, `adr-composer.md`, `pdr-composer.md`, `refine.md`, `node-audit.md`.
- **What counts as drift:**
  - A category named in D3 but missing from `review.md`'s rubric.
  - A category referenced in an upstream agent file that does not exist in D3 (renamed or removed without a D3 amendment).
  - A category-name or numbering mismatch between `review.md` and an upstream agent file.
- **Output:** drift findings surface in `hive-sync`'s drift report (`initiatives/drift-report.md` or the equivalent), the same surface ADR-0014 reconciliation already feeds.
- State that `hive-sync` *reports* the drift; it does not auto-edit the ADR or the agent files — reconciliation is a human/scope decision.

## Affected Files
- `.claude/agents/hive-sync.md` (the `hive-sync` agent definition)

## NuGet Dependencies
None. This packet edits a Markdown agent-definition file; no .NET project is created or modified.

## Boundary Check
- [x] `.claude/agents/` is the single source of truth for agent definitions (ADR-0007); lives in `HoneyDrunk.Architecture`. Correct repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] The `hive-sync` agent definition has a section specifying the D3↔agent-file drift-detection check
- [ ] The check names ADR-0044 D3 as the source of truth and the six agent files as the targets
- [ ] The three drift conditions (missing category, orphan category, name/numbering mismatch) are specified
- [ ] The check is stated to *report* drift into the drift report, not auto-edit
- [ ] The section references ADR-0014 as the governing reconciliation mandate

## Human Prerequisites
None. Pure Architecture-repo agent-definition edit.

## Dependencies
- `packet:04` — `review.md` rubric (**hard** — the drift check compares against the rubric authored there).
- `packet:09` — upstream agent D3 sections (**hard** — the drift check compares against the category-subset sections authored there).

## Referenced ADR Decisions

**ADR-0044 D3** — "Drift between this D3 and any agent file is an anti-pattern; `hive-sync` reconciles." Updates to the rubric are D3 amendments propagating via agent-file updates.
**ADR-0044 Follow-up Work** — "Wire `hive-sync` to detect drift between D3 and any agent file's referenced category list, per ADR-0014's reconciliation mandate."
**ADR-0014** — `hive-sync`'s reconciliation mandate; the drift report is its output surface.

## Constraints
- **Report, do not auto-fix.** `hive-sync` surfaces drift; reconciliation is a human/scope decision.
- The check compares against the exact category names/numbering authored in `review.md` (packet 04).

## Labels
`docs`, `tier-1`, `meta`, `adr-0044`, `wave-4`

## Agent Handoff

**Objective:** Add a D3↔agent-file drift-detection check to the `hive-sync` agent definition.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make rubric drift detectable so the twenty-category standard stays coherent across seven agent files.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 4.
- ADRs: ADR-0044 (D3), ADR-0014 (hive-sync reconciliation).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:04` — `review.md` rubric (hard).
- `packet:09` — upstream agent D3 sections (hard).

**Constraints:**
- Report, do not auto-fix; compare against `review.md`'s exact category names.

**Key Files:**
- `.claude/agents/hive-sync.md`

**Contracts:** None.
