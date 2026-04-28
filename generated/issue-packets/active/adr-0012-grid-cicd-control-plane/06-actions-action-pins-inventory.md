---
name: CI Change
type: ci-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-1", "ci-cd", "ops", "docs", "adr-0012", "wave-1"]
dependencies: []
adrs: ["ADR-0012"]
wave: 1
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-actions
---

# CI Change: Author `docs/action-pins.md` — third-party action pin inventory (D10)

## Summary
Author `HoneyDrunk.Actions/docs/action-pins.md` as the inventory of every third-party GitHub Action pin used across the reusable workflows in `HoneyDrunk.Actions/.github/workflows/`. Each entry lists the action, the current pinned version, the deprecation deadline if known, and a status (`Current` / `Deprecated-with-deadline` / `Superseded`). This implements ADR-0012 D10. The inventory is hand-maintained; a future weekly-workflow extension that auto-diffs the inventory against the actual workflow files is named in the ADR's Unresolved Consequences (Gap 5) but is not part of this packet.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
The Node 20 deprecation warnings from `actions/checkout@v4`, `setup-dotnet@v4`, `upload-artifact@v4`, and `github/codeql-action/*@v3` were a recurring operational burden in the runs that triggered ADR-0012. Each deprecation is a small bump across many workflow files, with deadlines several months out, making it easy to defer until something breaks. The inventory consolidates "what is pinned where, what is its expiry status" into a single place that gets updated on every PR that bumps an action.

This packet is the **reference state** that packet 09 (Node 20 bump) reads and updates in the same PR. Without the inventory, packet 09 has nothing to update; with it, the inventory becomes the authoritative answer to "did we get all the actions in this bump?"

## Proposed Implementation

### `docs/action-pins.md` (new)

**Structure:**

1. **Header.** Title, purpose (one paragraph), update protocol ("any PR that bumps an action version updates this file in the same PR; stale entries are a review-agent observation").

2. **Inventory table.** Columns:
   - **Action** — full path, e.g. `actions/checkout`.
   - **Current pin** — exact version string, e.g. `v4`.
   - **Deprecation deadline** — date or `none` or `unknown`.
   - **Status** — one of `Current`, `Deprecated-with-deadline`, `Superseded`.
   - **Successor** — for Superseded entries, the replacement action+version. Empty for Current.
   - **Notes** — short, optional. Use for "Node 20 runtime; replace before 2026-09-16" or similar.

   Initial population is a scan of all `.github/workflows/*.yml` files plus all composite actions under `.github/actions/**/action.yml`. Use `grep -h 'uses:' .github/workflows/*.yml .github/actions/**/action.yml | sort -u` (or equivalent) to enumerate. Only third-party actions are listed — actions starting with `./` (local composites) are excluded.

   Expected entries based on the current state of `HoneyDrunk.Actions/.github/workflows/`:
   - `actions/checkout` — `v4` — 2026-09-16 (Node 20 EOL) — `Deprecated-with-deadline` — Successor: `v5` (when released; track in Notes if not yet released).
   - `actions/setup-dotnet` — `v4` — 2026-09-16 — `Deprecated-with-deadline` — Successor: `v5`.
   - `actions/setup-node` — `v4` — 2026-09-16 — `Deprecated-with-deadline` — Successor: `v5`.
   - `actions/upload-artifact` — `v4` — 2026-09-16 — `Deprecated-with-deadline` — Successor: `v5`.
   - `actions/download-artifact` — `v4` — 2026-09-16 — `Deprecated-with-deadline` — Successor: `v5`.
   - `actions/cache` — current pin from workflow files — Status per upstream.
   - `github/codeql-action/init` — `v3` — 2026-09-16 — `Deprecated-with-deadline` — Successor: `v4`.
   - `github/codeql-action/analyze` — `v3` — `Deprecated-with-deadline` — Successor: `v4`.
   - `github/codeql-action/upload-sarif` — `v3` — `Deprecated-with-deadline` — Successor: `v4`.
   - `azure/login` — current pin — Status per upstream.
   - Any other third-party action present in the workflows.

   The executing agent must verify the actual current pins from the live workflow files before populating; the list above is the scope agent's expected set, not the verified state.

3. **Update protocol.** Short bulleted section:
   - Any PR that adds, removes, or changes an action pin updates this file in the same PR.
   - Bumping a `Deprecated-with-deadline` entry to its successor flips Status to `Current` and clears the Deadline (or sets it to `none` until a new deprecation is announced).
   - Removing an action entirely (e.g. switching from a marketplace wrapper to direct CLI per invariant 38) deletes the row.
   - The review agent observes "PR changes a `uses:` line but does not update `action-pins.md`" as Request Changes.

4. **Cross-references:**
   - Invariant 38 (direct-CLI policy — third-party wrappers forbidden, this inventory only covers permitted exceptions).
   - ADR-0012 D10 (the decision this implements).
   - Gap 5 in ADR-0012 Unresolved Consequences (the future automated-diff workflow this inventory enables).

### `docs/CHANGELOG.md` (or repo-root)

Append entry referencing ADR-0012 D10 and this packet.

### Cross-link from `.github/workflows/README.md` (if exists)

If a workflows-area README exists, link to `docs/action-pins.md` from it. If not, skip — do not create.

### Update `.claude/agents/review.md` — out of scope here

The Request Changes rule for "PR changes `uses:` without updating `action-pins.md`" is a sensible review observation but adding it to `review.md` is **not** part of this packet — it is part of packet 01 (ADR-0012 acceptance) which already amends `review.md` with the caller-permissions rule. If desired, file a separate follow-up packet to add the inventory-staleness rule. Do not bundle here; that would create a cross-repo PR for a small inventory addition.

## Affected Files
- `docs/action-pins.md` (new)
- `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) — entry
- `.github/workflows/README.md` — optional link (only if file exists)

## NuGet Dependencies
None. Docs only.

## Boundary Check
- [x] Single-repo, doc-only edit.
- [x] No workflow YAML changes (those are packet 09's job).
- [x] No new contract surface.

## Acceptance Criteria
- [ ] `docs/action-pins.md` exists with the four sections (header, inventory table, update protocol, cross-references).
- [ ] The inventory table lists every third-party action used across `.github/workflows/*.yml` and composite actions under `.github/actions/**/action.yml`. Local (`./`) composite references are excluded.
- [ ] Each row has all six columns populated. Unknown deadlines are `unknown`, not blank.
- [ ] Node 20 deprecated actions (`actions/checkout`, `setup-dotnet`, `setup-node`, `upload-artifact`, `download-artifact`, `github/codeql-action/*`) carry deadline `2026-09-16` and status `Deprecated-with-deadline`.
- [ ] The update protocol section is present and explicit.
- [ ] Cross-references to invariant 38, ADR-0012 D10, and Gap 5 are present.
- [ ] `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) updated.
- [ ] If `.github/workflows/README.md` exists, it links to `action-pins.md`.

## Human Prerequisites
None. Fully delegable docs work.

## Referenced Invariants

> **Invariant 38 (post-acceptance numbering — see packet 01):** Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

The inventory only enumerates the **permitted exceptions** (first-party `actions/*`, `github/codeql-action/*`, `azure/*`). If the executing agent finds a third-party non-permitted wrapper still in use, that is a separate finding — file as a follow-up issue and exclude from the inventory.

## Referenced ADR Decisions

**ADR-0012 D10 (Action-pin inventory):** "`HoneyDrunk.Actions/docs/action-pins.md` lists every third-party action pin used across the reusable workflows, with its current version, the deprecation deadline if known, and a status (Current / Deprecated-with-deadline / Superseded). Updating this file is part of any PR that bumps an action version; stale entries are a review-agent observation."

**ADR-0012 Gap 5 (Action-pin deprecations are still tracked manually):** "The hand-maintained inventory (D10) is sufficient for now. Optional future enhancement: a weekly workflow that parses `uses:` pins and cross-references against a hand-maintained deprecation calendar." This packet ships the hand-maintained inventory; the weekly diff workflow is explicitly out of scope.

## Dependencies
- Soft-blocked by packet 01 for invariant 38 numbering.
- **Hard-blocks packet 09** (Node 20 actions bump). Packet 09's PR updates this inventory in the same commit; without the inventory existing, packet 09 has nothing to update.

## Labels
`chore`, `tier-1`, `ci-cd`, `ops`, `docs`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Stand up the third-party action pin inventory that ADR-0012 D10 mandates.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Land the static-state complement to the runtime-state grid-health aggregator. The inventory tracks "what should we be bumping" while the aggregator tracks "what is failing right now."
- Feature: ADR-0012 Grid CI/CD Control Plane, D10 mechanism.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Soft-blocked by packet 01.
- **Hard-blocks packet 09.**

**Constraints:**
- **Invariant 38 (post-acceptance):** The inventory only enumerates permitted exceptions to the direct-CLI policy. If a non-permitted third-party wrapper is still in use, that is a defect — file as a follow-up issue, do not add it to the inventory as if it were normal.
- **Verify before populating.** The expected entries listed above are the scope agent's best estimate. The executing agent must run `grep -h 'uses:' .github/workflows/*.yml .github/actions/**/action.yml | sort -u` (or equivalent) and reconcile with the table before publishing.
- **Deadline accuracy.** Node 20 EOL is 2026-09-16 per GitHub's announcement. Verify against the GitHub Actions runner release notes before publishing — if the date has shifted, use the current date. Set `unknown` for actions without a published deadline rather than guessing.

**Key Files:**
- `.github/workflows/*.yml` — read-only references for current pins.
- `.github/actions/**/action.yml` — read-only references for composite-action pins.
- `docs/CHANGELOG.md` — append entry.
- `docs/consumer-usage.md` — pattern reference for doc style and cross-linking.

**Contracts:** No code or schema contracts. The inventory format is the operator-facing contract; future changes to the column shape are reviewed against operator readability.
