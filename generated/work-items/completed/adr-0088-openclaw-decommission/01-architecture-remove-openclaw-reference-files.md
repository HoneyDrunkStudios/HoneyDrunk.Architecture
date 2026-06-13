---
name: Infrastructure
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infrastructure", "adr-0088", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0088", "ADR-0086"]
accepts: []
wave: 2
initiative: adr-0088-openclaw-decommission
node: honeydrunk-architecture
---

# Remove the `infrastructure/openclaw/*` reference files; tombstone the runner README pointers

## Summary
Remove the two OpenClaw reference files under `infrastructure/openclaw/` — `grid-review-runner.md` (the superseded OpenClaw/Codex webhook-receiver review-runtime contract) and `hive-sync.md` (the OpenClaw/Honeyclaw `hive-sync` runtime contract). Both describe a runtime that no longer exists; their successors are `infrastructure/workers/grid-agent-runner/` and the runner job specs. Update the predecessor pointers in `infrastructure/workers/grid-agent-runner/README.md` (lines 81–82) from "superseded contract" references to tombstone form so they are not orphaned links.

## Context
ADR-0088 D3 Group 2 step 5: "Remove the `infrastructure/openclaw/` reference files: `grid-review-runner.md` and `hive-sync.md`. Both describe a runtime that no longer exists; their successors are `infrastructure/workers/grid-agent-runner/` and the runner job specs. A one-line tombstone pointer may be left in `infrastructure/workers/grid-agent-runner/README.md` (which already references `infrastructure/openclaw/grid-review-runner.md` as the superseded contract — that pointer is updated, not orphaned)."

Note the distinction from ADR-0086 packet 08: that packet *marked* `grid-review-runner.md` with a supersession banner and preserved it as a historical record while OpenClaw was still partly live. ADR-0088 completes the teardown — OpenClaw is fully gone, so the historical contract files are **removed** (the ADR record is the durable history; an `infrastructure/openclaw/` reference contract for a runtime that no longer exists is drift). If ADR-0086 packet 08 has already landed the banner edits, this packet supersedes them by deleting the files.

This is a docs-only packet. `Actor=Agent`. It is filed in Wave 2 (after acceptance) but does **not** depend on the operator runtime teardown (packet 02) — removing a stale doc is independent of disabling the live process. The dependency is only `work-item:00` (acceptance).

## Scope
- Delete `infrastructure/openclaw/grid-review-runner.md`.
- Delete `infrastructure/openclaw/hive-sync.md`.
- If the `infrastructure/openclaw/` directory becomes empty after both deletions, remove the directory (or leave a single `README.md` tombstone if the repo convention prefers an explicit "this directory is retired" marker — see Decision Point).
- Edit `infrastructure/workers/grid-agent-runner/README.md` lines 81–82:
  - Before: `- `infrastructure/openclaw/grid-review-runner.md` records the superseded OpenClaw review runner contract.` and `- `infrastructure/openclaw/hive-sync.md` records the predecessor hive-sync runtime contract.`
  - After: a single tombstone line, e.g. `- The OpenClaw review-runner and hive-sync runtime contracts (formerly `infrastructure/openclaw/grid-review-runner.md` and `infrastructure/openclaw/hive-sync.md`) were removed when OpenClaw was decommissioned per ADR-0088; this runner and its job specs are their successors.`
- If `infrastructure/README.md` (or another index file) enumerates the OpenClaw reference docs, remove those entries.

## Decision Point — directory tombstone vs. clean removal
ADR-0088 D3 step 5 says "A one-line tombstone pointer **may** be left." This packet's default is **clean removal of the files** plus the **runner-README tombstone line** (which is the durable pointer). The `infrastructure/openclaw/` directory is removed if empty. Rationale: the runner README already carries the historical pointer; a second tombstone file in `infrastructure/openclaw/` would be redundant. If the operator prefers an explicit directory-level marker, leave `infrastructure/openclaw/README.md` with one line pointing at the runner — but do not leave the full contract files.

## Proposed Implementation
1. Delete `infrastructure/openclaw/grid-review-runner.md` and `infrastructure/openclaw/hive-sync.md`.
2. Rewrite the two predecessor-pointer bullets in `infrastructure/workers/grid-agent-runner/README.md` (lines 81–82) as the single tombstone line above. Do not leave dead links to the removed files.
3. Grep the repo for any other intra-repo links to `infrastructure/openclaw/grid-review-runner.md` or `infrastructure/openclaw/hive-sync.md` and rewrite or remove them so no dead links remain (`infrastructure/README.md`, any walkthrough cross-links, any ADR body links that are *pointers* rather than historical references — do NOT edit ADR-0044/0079/0081/0086 bodies; if those carry links, leave them as historical record per ADR-0088 D2, but verify they do not now 404 in a way the docs-currency convention forbids — a historical reference to a removed file is acceptable; a live "see this contract" pointer is not).
4. Remove the `infrastructure/openclaw/` directory if it is empty after the deletions.
5. Update `CHANGELOG.md`.

## Affected Files
- `infrastructure/openclaw/grid-review-runner.md` (deleted)
- `infrastructure/openclaw/hive-sync.md` (deleted)
- `infrastructure/openclaw/` directory (removed if empty, or a one-line README tombstone per Decision Point)
- `infrastructure/workers/grid-agent-runner/README.md` (lines 81–82 rewritten)
- `infrastructure/README.md` (if it enumerates the OpenClaw docs)
- `CHANGELOG.md`

## NuGet Dependencies
None. Markdown/file removal only; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` under `infrastructure/`.
- [x] No code change in any repo.
- [x] No cross-Node runtime dependency.
- [x] `constitution/invariants.md` is NOT edited.
- [x] ADR-0044 / ADR-0079 / ADR-0081 / ADR-0086 bodies are NOT edited (historical references in those ADRs are preserved per ADR-0088 D2; only live "see this contract" pointers elsewhere are rewritten).
- [x] No secret, inventory, walkthrough, or node-standup-matrix change here (those are packets 03 / 04).

## Acceptance Criteria
- [ ] `infrastructure/openclaw/grid-review-runner.md` no longer exists in the repo
- [ ] `infrastructure/openclaw/hive-sync.md` no longer exists in the repo
- [ ] `infrastructure/workers/grid-agent-runner/README.md` lines 81–82 are rewritten to a tombstone line that does not link to the removed files
- [ ] No dead intra-repo links to the two removed files remain anywhere in the repo (verified by grep for `openclaw/grid-review-runner` and `openclaw/hive-sync`)
- [ ] The `infrastructure/openclaw/` directory is either removed (if empty) or carries only a one-line tombstone README (no full contract files)
- [ ] If `infrastructure/README.md` enumerated the OpenClaw docs, those entries are removed
- [ ] `constitution/invariants.md` is unchanged
- [ ] ADR-0044 / ADR-0079 / ADR-0081 / ADR-0086 bodies are unchanged
- [ ] CHANGELOG.md records the removal of the OpenClaw reference files and the runner-README tombstone

## Human Prerequisites
None. This is pure file/docs work delegable end-to-end to the agent.

## Dependencies
- `work-item:00` — ADR-0088 acceptance (the teardown decision must be live before reference files are removed).

## Referenced ADR Decisions
**ADR-0088 D3 Group 2 step 5 — Remove the `infrastructure/openclaw/` reference files.** Both describe a runtime that no longer exists; their successors are `infrastructure/workers/grid-agent-runner/` and the runner job specs. A one-line tombstone pointer may be left in the runner README (which already references the superseded contract — that pointer is updated, not orphaned).

**ADR-0088 D2 — Cross-reference ADR-0086; do not re-supersede ADR-0044 / ADR-0079.** Historical references in those ADRs are preserved; this packet does not edit their bodies.

## Constraints
- **Remove, do not merely banner.** Unlike ADR-0086 packet 08 (which preserved the file with a supersession banner while OpenClaw was partly live), ADR-0088 fully retires OpenClaw, so the contract files are deleted. The ADR is the durable historical record.
- **No orphaned links.** The runner README pointer (lines 81–82) must be rewritten to a tombstone line, not left pointing at deleted files.
- **Do not edit ADR-0044 / 0079 / 0081 / 0086 bodies.** Historical references there stay as the record (ADR-0088 D2).
- **Do not touch the secret, the inventory row, the walkthrough, or the node-standup matrix here.** Those retire in packets 03 (deletion) and 04 (inventory triplet) under the invariant-103 gate.
- **Do not disable the live OpenClaw process here.** That is packet 02 (operator chore). This packet only removes stale docs.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `infrastructure`, `adr-0088`, `wave-2`

## Agent Handoff

**Objective:** Delete the two `infrastructure/openclaw/*` reference files and rewrite the runner README predecessor pointers to a tombstone line, leaving no dead links.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Complete D3 Group 2 step 5 — remove the OpenClaw runtime-contract docs now that OpenClaw is being torn down.
- Feature: ADR-0088 OpenClaw decommission, Wave 2 (D3 Group 2).
- ADRs: ADR-0088 (primary, D3 Group 2 step 5), ADR-0086 (the successor runner; referenced, not edited).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0088 acceptance.

**Constraints:**
- Remove the files; do not just banner them.
- No orphaned links — rewrite the runner README pointers (lines 81–82).
- Do not edit ADR-0044 / 0079 / 0081 / 0086 bodies.
- No secret / inventory / walkthrough / matrix change here.
- Do not disable the live OpenClaw process (that is packet 02).

**Key Files:**
- `infrastructure/openclaw/grid-review-runner.md` (delete)
- `infrastructure/openclaw/hive-sync.md` (delete)
- `infrastructure/workers/grid-agent-runner/README.md` (lines 81–82)
- `infrastructure/README.md` (if it indexes the OpenClaw docs)
- `CHANGELOG.md`

**Contracts:** None.
