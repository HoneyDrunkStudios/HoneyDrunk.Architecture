---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0085", "wave-3"]
dependencies: ["packet:02"]
adrs: ["ADR-0085"]
accepts: []
source: strategic
generator: scope
wave: 3
initiative: adr-0085-docs-sync
node: honeydrunk-architecture
---

# Phase 3 — broaden `docs-sync` auto-fix to catalog references and dead intra-repo Markdown links

## Summary
Activate Phase 3 of the ADR-0085 rollout: update the active-phase guard in `.claude/agents/docs-sync.md` to add **catalog-reference drift (D3 #4)** and **dead intra-repo Markdown links** to the permitted auto-fix categories. The Phase-3 scope expansion is restricted to rewrites where the **target's new location is determinable** from `catalogs/nodes.json` (rename-aware link rewrites) — ambiguous link targets remain `note`-level in the report. Symbol drift (#3), dependency-graph drift (#5), and agent-instruction drift (#6) **remain report-only + fallback-packet** at Phase 3.

## Context
ADR-0085 D8 Phase 3 says: "Broaden auto-fix to catalog references and dead links. Auto-fix scope expands to category 4 (catalog-reference drift: rename-aware link rewrites) and dead intra-repo Markdown links where the target's new location is determinable from `catalogs/nodes.json`. Categories 3 (symbol drift), 5 (dependency-graph drift), and 6 (agent-instruction drift) remain report-only + fallback `proposed/` packet path."

The Phase-3 scope expansion is gated on Phase 2 working — the dispatch plan's Wave-2 exit criterion (PR-metadata gates passing, branch-naming working, idempotency holding, operator's PR-review workload acceptable) must be met before this packet's PR merges.

Catalog-reference rewrites are still mechanical: the rewrite is exact-string substitution from the canonical name in `catalogs/nodes.json`. Dead intra-repo Markdown link rewrites are also mechanical when the rename is unambiguous (a single move recorded in `catalogs/nodes.json` or git history with high confidence). Where the new location is **not** determinable, the agent surfaces a `note` in the report — it does not guess.

## Scope
- `.claude/agents/docs-sync.md` — update the **active-phase guard**: bump active phase from 2 to 3; expand `PERMITTED_AUTO_FIX_CATEGORIES` to `["version-drift", "catalog-reference-drift", "dead-intra-repo-link"]`; document the "target's new location must be determinable from `catalogs/nodes.json`" qualifier for dead-link rewrites; unambiguous cases stay `note` in the report.
- `.claude/agents/docs-sync.md` — flesh out the **catalog-reference-drift auto-fix logic**: when prose or a Markdown link refers to `HoneyDrunkStudios/{Repo}`, a Node name, or a contract name, and the catalog now shows that name renamed/moved/archived, rewrite the prose/link using the canonical name from `catalogs/nodes.json`. ADR references that are now `Superseded` remain `note` only per D3 (they are still valid history). Unresolvable references (the target does not exist anywhere) stay `warn` in the report — surfaced for human action, not auto-removed.
- `.claude/agents/docs-sync.md` — flesh out the **dead-intra-repo-link auto-fix logic**: for a broken Markdown link to a file path within the same repo, if the target file's new location is determinable (via `catalogs/nodes.json` Node-rename record, or git history with a unique rename pointer), rewrite the link. If the new location is not determinable, leave the link alone and emit a `note` in the report. **Cross-repo Markdown links are out of scope at Phase 3** (they would require cross-repo file lookup which is its own complexity bucket).
- `constitution/agent-capability-matrix.md` — update the `docs-sync` row's "Produces" column to reflect the expanded Phase-3 auto-fix scope (version drift + catalog-reference rewrites + dead intra-repo link rewrites).
- `generated/docs-sync-reports/README.md` — append a Phase-3 note documenting the new auto-fix categories and the "target's new location must be determinable" qualifier; describe the `note`-level disposition for ambiguous cases.

## Proposed Implementation

### Active-phase guard update
The Phase-2 guard permitted only `version-drift`. The Phase-3 update:

```
ACTIVE PHASE: 3 (Phase 3 per ADR-0085 D8 — auto-fix broadened to catalog references and dead intra-repo links)
PERMITTED AUTO-FIX CATEGORIES: ["version-drift", "catalog-reference-drift", "dead-intra-repo-link"]
REPORT-ONLY CATEGORIES (Phase 3): ["missing-required-artifact", "symbol-reference-drift",
                                   "dependency-graph-drift", "agent-instruction-drift"]
FALLBACK PACKET PATH (Phase 3): ["symbol-reference-drift", "dependency-graph-drift",
                                 "agent-instruction-drift"] — write to
                                 generated/issue-packets/proposed/{YYYY-MM-DD}-{repo}-docs-{slug}.md
QUALIFIER (dead-intra-repo-link): only auto-fix when target's new location is determinable from
                                  catalogs/nodes.json or git rename history; otherwise emit `note`
                                  in the report and leave the link alone.
```

### Catalog-reference-drift auto-fix logic
Detection (already in Phase 1 reports per D3 #4): Markdown link or prose reference to `HoneyDrunkStudios/{Repo}`, a Node name, an ADR number, or a contract name where the target doesn't resolve in the corresponding catalog or filesystem.

Phase-3 auto-fix scope (subset of detection):
- **Renamed Node** (e.g., `HoneyDrunk.Old` → `HoneyDrunk.New`): rewrite using the canonical name from `catalogs/nodes.json`. The catalog is the source of truth for the rename map.
- **Renamed contract** (e.g., type `IOldThing` listed in `catalogs/contracts.json` was renamed to `INewThing`): rewrite prose references to use the new name. Only auto-fix when the rename map is recorded in the catalog; never guess from string-similarity.
- **Moved file** (referenced by Markdown link, target moved within the same repo): rewrite the link path. Only auto-fix when the new location is unambiguous.
- **Superseded ADR**: stays `note` in the report — not rewritten. Superseded ADRs are still valid history per D3 #4.
- **Truly unresolvable reference** (target does not exist anywhere): stays `warn` in the report — surfaced for human action. The agent does not delete the reference.

### Dead-intra-repo-link auto-fix logic
Detection (already in Phase 1 reports as part of D3 #4): Markdown link to a file path inside the same repo where the target file no longer exists.

Phase-3 auto-fix scope:
- If `catalogs/nodes.json` records the file's new location (e.g., a directory rename as part of a Node restructure), rewrite the link.
- If git history shows a unique rename for the file (`git log --follow` returns a single rename pointer), rewrite the link.
- If neither path is available, leave the link alone and emit a `note` in the report ("dead link, no determinable new location — human action required").
- **Cross-repo Markdown links** (e.g., `../HoneyDrunk.Notify/README.md` or absolute URLs to other repos) are explicitly **out of scope at Phase 3** — they would require cross-repo file lookup which is its own complexity bucket, deferred to a future ADR.

### Idempotency
Both auto-fix categories must satisfy D7's idempotency rule: re-running the agent on a repo where the fix already landed must produce no diff. For catalog-reference rewrites this is trivial (the rewrite uses the canonical name; re-reading finds no drift). For dead-link rewrites it is also trivial (the rewritten link points at a real file; re-reading finds no dead link).

### Capability-matrix update
- `docs-sync` row's "Produces" column: update the cross-repo PR scope qualifier from "(Phase 2+, version drift only at v2)" to "(Phase 3+, version drift + catalog-reference + dead-intra-repo-link rewrites at v3)".
- No new line in the Artifact Map (the cross-repo PRs were already added in Phase 2; only the per-PR auto-fix categories widen).

### Report-directory README update
Append a Phase-3 section to `generated/docs-sync-reports/README.md` noting:
- As of Phase 3, the per-Node sections now include catalog-reference and dead-intra-repo-link rewrites under the PR's auto-fixed list.
- Ambiguous link targets (no determinable new location) are listed under `note`-level findings in each Node's section.

## Affected Files
- `.claude/agents/docs-sync.md`
- `constitution/agent-capability-matrix.md`
- `generated/docs-sync-reports/README.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo (the runtime cross-repo PRs are post-merge, not part of this packet).
- [x] No new runtime dependency between Nodes.
- [x] No `HoneyDrunk.Actions` change.

## Acceptance Criteria
- [ ] `.claude/agents/docs-sync.md` active-phase guard reads Phase 3; `PERMITTED_AUTO_FIX_CATEGORIES` expanded to include `catalog-reference-drift` and `dead-intra-repo-link`; the `"target's new location must be determinable"` qualifier is documented for dead-link rewrites
- [ ] The catalog-reference-drift auto-fix logic is documented with the four cases: renamed Node, renamed contract, moved file, Superseded ADR (`note` only), truly unresolvable (`warn` only — no auto-delete)
- [ ] The dead-intra-repo-link auto-fix logic is documented with the `catalogs/nodes.json` + git-rename-history sources of truth, the cross-repo carve-out, and the `note`-disposition fallback
- [ ] Idempotency rule is reaffirmed for both new auto-fix categories
- [ ] `constitution/agent-capability-matrix.md` `docs-sync` row's "Produces" column reflects the expanded Phase-3 auto-fix scope
- [ ] `generated/docs-sync-reports/README.md` has a Phase-3 section describing the new auto-fix categories and the `note`-disposition for ambiguous cases
- [ ] The repo-level `CHANGELOG.md` carries an entry for this Phase-3 activation
- [ ] No README update required at repo root (internal agent rollout step)

## Human Prerequisites
- [ ] Confirm Phase 2's exit criterion (PR-metadata gates passing, branch-naming working, idempotency holding, operator's PR-review workload acceptable) is met over at least 4 weekly runs before this packet's PR merges. If Phase 2 has not stabilized, defer this packet's merge.
- [ ] After this packet's PR merges, watch the first 4 weekly Phase-3 runs closely: confirm catalog-reference rewrites are correct (no false-positive renames), dead-link rewrites land at the right new location, and the `note`-disposition fires for ambiguous cases instead of guessing. If false-positive renames occur, revert this packet (the guard reverts to Phase 2) and re-scope Phase 3 with the failure mode documented before re-attempting.

## Dependencies
- `packet:02` — **hard**. Phase 2 must be observed working before Phase 3 broadens the auto-fix scope.

## Referenced ADR Decisions

**ADR-0085 D3 #4 (Catalog-reference drift)** — Markdown link or prose reference to `HoneyDrunkStudios/{Repo}`, a Node name, an ADR number, or a contract name where the target doesn't resolve in the corresponding catalog or filesystem. Severity for unresolved references: `warn`. Cross-references to Superseded ADRs: `note` only (they are still valid history).
**ADR-0085 D7** — Auto-fix idempotency: every fix the agent applies must be idempotent. Catalog-reference rewrites and dead-link rewrites satisfy this trivially.
**ADR-0085 D8 Phase 3** — Auto-fix scope expands to category 4 (catalog-reference drift: rename-aware link rewrites) and dead intra-repo Markdown links where the target's new location is determinable from `catalogs/nodes.json`. Categories 3, 5, 6 remain report-only + fallback `proposed/` packet path.

## Constraints
> **ADR-0085 D4 (verbatim qualifier):** The bias is mechanical, exact-string drift is auto-fixed in the PR; anything requiring editorial judgment is surfaced for human action.

> **ADR-0085 D7 (auto-fix idempotency, verbatim):** Every auto-fix the agent applies must be idempotent — running the same fix twice produces no diff.

- **Never guess a rename from string-similarity.** Only auto-fix when the rename map is recorded in `catalogs/nodes.json` (for Nodes/contracts) or unambiguous in `git log --follow` (for moved files).
- **Cross-repo Markdown links are out of scope at Phase 3.** Deferred to a future ADR if the operator wants them.
- **Truly unresolvable references stay `warn`.** The agent does not delete a reference whose target cannot be found — that is an editorial decision for the human.
- **The Phase-3 active-phase guard reverts to Phase 2 cleanly.** If this packet is reverted, the agent silently narrows back to the version-drift-only auto-fix scope.
- **PR metadata for this packet's implementation PR:** `Authorship: agent-claude-code` + `Packet: HoneyDrunkStudios/HoneyDrunk.Architecture#<issue-number>` once filed.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0085`, `wave-3`

## Agent Handoff

**Objective:** Activate Phase 3 of ADR-0085: broaden the `docs-sync` auto-fix scope to include catalog-reference rewrites and dead-intra-repo-link rewrites where the target's new location is determinable; keep symbol drift, dependency-graph drift, and agent-instruction drift report-only.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land Phase 3 of ADR-0085 after Phase 2's exit criterion is met.
- Feature: Grid-Wide Documentation Currency Agent rollout, Phase 3.
- ADRs: ADR-0085 (D3 #4 + D7 + D8 Phase 3).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — hard.

**Constraints:**
- Active-phase guard caps auto-fix at version drift + catalog refs + dead intra-repo links — no scope creep.
- Never guess a rename from string-similarity; require catalog or git-history evidence.
- Cross-repo Markdown links out of scope at Phase 3.
- Truly unresolvable references stay `warn`, not auto-deleted.

**Key Files:**
- `.claude/agents/docs-sync.md` (active-phase guard + new auto-fix-logic sections)
- `constitution/agent-capability-matrix.md`
- `generated/docs-sync-reports/README.md`

**Contracts:** None changed.
