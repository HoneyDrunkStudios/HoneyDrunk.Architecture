---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-2", "ci-cd", "ops", "adr-0012", "wave-2"]
dependencies: ["06-actions-action-pins-inventory"]
adrs: ["ADR-0012"]
wave: 2
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-actions
---

# CI Change: Bump Node 20 deprecated actions to v5 across all reusable workflows + update pin inventory

## Summary
Bump every Node 20-runtime action across `HoneyDrunk.Actions/.github/workflows/*.yml` and `.github/actions/**/action.yml` to its v5 (Node 24) successor in a single PR. Update `docs/action-pins.md` (created by packet 06) in the same PR so the inventory reflects the new state. The Node 20 EOL date is 2026-09-16 per GitHub Actions runner deprecation. Today's date is 2026-04-26, so there is comfortable lead time — but the bump is bundled now to remove the recurring deprecation warning noise from every nightly run and to flush the v5 stack before any v5-specific behavior surprises arrive.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0012 D10 names the action-pin inventory and ADR-0012's Follow-up Work names the Node 20 bump explicitly: "Bump Node 20 deprecated actions across all reusable workflows: `actions/checkout@v4 → v5` when released, `setup-dotnet@v4 → v5`, `upload-artifact@v4 → v5`, `codeql-action@v3 → v4`. Deadline is 2026-09-16 for Node 20 removal; not urgent but should land before the deadline via a single PR in `HoneyDrunk.Actions`. Updates the pin inventory (D10) in the same PR."

The packet runs in Wave 2 because it must update the pin inventory in the same PR, and the inventory must exist (packet 06) for that update to be possible.

## Proposed Implementation

### Pre-flight: confirm v5 availability

Before editing, verify each successor version is actually released:
- `actions/checkout@v5`
- `actions/setup-dotnet@v5`
- `actions/setup-node@v5`
- `actions/upload-artifact@v5`
- `actions/download-artifact@v5`
- `actions/cache@v5` (if cache pin is on v4)
- `github/codeql-action/init@v4`
- `github/codeql-action/analyze@v4`
- `github/codeql-action/upload-sarif@v4`

If any v5 is not yet GA at the time of execution:
- For first-party `actions/*`: keep v4, document in `docs/action-pins.md` with status `Deprecated-with-deadline` and the deadline. File a follow-up issue to re-attempt when v5 ships. Do not block this packet on a not-yet-released successor — bump what is available and defer the rest.
- For `github/codeql-action`: same pattern. CodeQL tends to ship its v-bumps around the runtime EOL window.

The pre-flight check is a `curl https://github.com/actions/checkout/releases/latest` (or equivalent for each action) — verify the latest release tag matches `v5` (or whatever successor is documented in the inventory).

### Bulk replacement across workflow files

Apply each version replacement across:
- `.github/workflows/*.yml`
- `.github/actions/**/action.yml`

Replacements to make (only where the v5 was confirmed available in the pre-flight):
- `actions/checkout@v4` → `actions/checkout@v5`
- `actions/setup-dotnet@v4` → `actions/setup-dotnet@v5`
- `actions/setup-node@v4` → `actions/setup-node@v5`
- `actions/upload-artifact@v4` → `actions/upload-artifact@v5`
- `actions/download-artifact@v4` → `actions/download-artifact@v5`
- `actions/cache@v4` → `actions/cache@v5` (if applicable)
- `github/codeql-action/init@v3` → `github/codeql-action/init@v4`
- `github/codeql-action/analyze@v3` → `github/codeql-action/analyze@v4`
- `github/codeql-action/upload-sarif@v3` → `github/codeql-action/upload-sarif@v4`

Use `sed -i 's|actions/checkout@v4|actions/checkout@v5|g'` per replacement, applied across all matching files. Run each replacement separately (not as one regex) so the diff is clean and reviewable.

### Read each successor's release notes

For each bumped action, read the v4→v5 (or v3→v4) release notes via `curl https://api.github.com/repos/<owner>/<repo>/releases/tags/<tag>`. Note any breaking changes that affect input shapes. Adjust workflow files if a breaking change applies. Document any non-trivial change in the PR body.

Common breaking-change patterns to watch for (informed by past v3→v4 jumps):
- Renamed inputs (`actions/upload-artifact` v3→v4 changed merge-multiple semantics; v4→v5 may change other defaults).
- Removed defaults (`actions/setup-node` periodically tightens version-spec defaults).
- New required inputs (rare but possible).

If a breaking change forces a workflow re-author beyond a one-line `@v4`→`@v5` swap, file a follow-up packet for that specific workflow rather than expanding this packet's scope. The first-pass goal is "all v5 swaps that are mechanical."

### Update `docs/action-pins.md`

Per packet 06's update protocol: any PR that bumps an action version updates the inventory in the same PR. For each bumped row:
- Update `Current pin` from `v4` to `v5` (or `v3` to `v4` for CodeQL).
- Flip `Status` from `Deprecated-with-deadline` to `Current`.
- Clear `Deprecation deadline` (set to `none` or to the next published deprecation if known).
- Clear `Successor` (set to empty for Current-status rows).

For any row whose successor was NOT available at pre-flight: leave `Status: Deprecated-with-deadline` but add a Notes entry: "v5 not yet released as of <date>; re-bump in follow-up <link-to-issue>."

### Post-flight: trigger smoke tests

After the PR merges to `main` of `HoneyDrunk.Actions`, the operator manually triggers via `workflow_dispatch`:
- `nightly-security.yml` against one Grid repo (Kernel is a good first target).
- `nightly-deps.yml` against the same repo.
- `pr-core.yml` runs automatically on the PR; observe its run.

For each smoke test:
- Confirm the run completes with `conclusion: success`.
- Confirm no new deprecation warnings appear in the workflow logs (search log output for `node20`, `deprecation`, `deprecated`).

If a smoke test fails or surfaces a new deprecation warning, file a follow-up issue in `HoneyDrunk.Actions` with the specific failure or warning. Do not revert this PR; the failure surfaces the next migration target.

### `docs/CHANGELOG.md` (or repo-root)

Append entry referencing ADR-0012 D10 and this bump. List which actions were bumped and which were deferred (if any).

## Affected Files
- `.github/workflows/*.yml` — every file containing a `uses:` line for any of the bumped actions (read with `grep -l 'actions/checkout@v4\|actions/setup-dotnet@v4\|...' .github/workflows/*.yml`)
- `.github/actions/**/action.yml` — every composite action file similarly affected
- `docs/action-pins.md` — inventory reflects new state
- `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) — entry

## NuGet Dependencies
None.

## Boundary Check
- [x] Single-repo edit, scoped to action version bumps.
- [x] No semantic changes to workflow logic — only `@v4`→`@v5` swaps (and any small input-shape adjustments forced by breaking changes, documented per swap).
- [x] Inventory file (packet 06's deliverable) updated atomically with the workflow edits.

## Acceptance Criteria
- [ ] Pre-flight confirms each bumped action's successor is GA at execution time. Successors not yet released are documented and deferred (no half-bump in the same PR).
- [ ] Every `actions/checkout@v4` is replaced with `actions/checkout@v5` (or current target) across workflows and composite actions.
- [ ] Every `actions/setup-dotnet@v4`, `setup-node@v4`, `upload-artifact@v4`, `download-artifact@v4`, `cache@v4` (if pinned to v4) similarly replaced.
- [ ] Every `github/codeql-action/{init|analyze|upload-sarif}@v3` similarly replaced with `@v4`.
- [ ] `docs/action-pins.md` updated to reflect every bumped row's new state (current pin, status, cleared deadline, cleared successor).
- [ ] PR body documents any breaking change found in release notes and how this PR addresses it (or, if breaking change requires further work, the follow-up issue link).
- [ ] Smoke tests post-merge: `nightly-security.yml` and `nightly-deps.yml` against at least Kernel report `conclusion: success` with no new deprecation warnings in logs.
- [ ] `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) updated.
- [ ] If any bumped action's successor was unavailable at pre-flight, a follow-up issue is filed and linked from `docs/action-pins.md`'s Notes column for that row.

## Human Prerequisites
- [ ] **Smoke-test trigger.** After PR merge, the operator (or agent if cross-repo `workflow_dispatch` permissions allow) triggers the post-merge smoke tests. The smoke runs are not part of the PR itself — they verify that callers in other repos still pass with the new versions. If the agent's GitHub identity cannot dispatch workflows in other repos, the operator does it manually via the Actions tab.
- [ ] **Optional: cross-repo update of caller pins.** Most callers reference `HoneyDrunk.Actions`'s reusable workflows by `@main`, which means this PR's merge auto-applies to every caller. If any caller pins by SHA or version tag, that caller's pin must be bumped in a follow-up per-repo packet. The audit doc from packet 08 catalogs caller pins; cross-reference it.

## Referenced Invariants

> **Invariant 38 (post-acceptance numbering — see packet 01):** Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

The actions bumped in this packet are first-party (`actions/*`, `github/codeql-action/*`) — the permitted exceptions. The bump does not introduce new third-party wrappers.

## Referenced ADR Decisions

**ADR-0012 D10 (Action-pin inventory):** "Updating this file is part of any PR that bumps an action version; stale entries are a review-agent observation." This packet is the prototypical inventory-update PR; the inventory and the workflow files move together.

**ADR-0012 Follow-up Work — Node 20 deprecation:** "Bump Node 20 deprecated actions across all reusable workflows: `actions/checkout@v4 → v5` when released, `setup-dotnet@v4 → v5`, `upload-artifact@v4 → v5`, `codeql-action@v3 → v4`. Deadline is 2026-09-16 for Node 20 removal; not urgent but should land before the deadline via a single PR in `HoneyDrunk.Actions`. Updates the pin inventory (D10) in the same PR."

**ADR-0012 D4 (Direct CLI exceptions):** First-party actions are permitted. The bump targets are all first-party.

## Dependencies
- **Hard-blocked by packet 06** (`docs/action-pins.md` inventory). Without the inventory, this packet has no file to update in the same PR — and ADR-0012 D10 requires inventory and workflow to move together.
- Soft-blocked by packet 01 for invariant 38 numbering.

## Labels
`chore`, `tier-2`, `ci-cd`, `ops`, `adr-0012`, `wave-2`

## Agent Handoff

**Objective:** Bump every Node 20-runtime action to its v5 successor and refresh the pin inventory in one atomic PR.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Land the Node 20 deprecation bump before the 2026-09-16 EOL and remove the recurring warning noise from nightly runs.
- Feature: ADR-0012 Grid CI/CD Control Plane, D10 mechanism + Follow-up Work.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- **Hard-blocked by packet 06** — inventory must exist to be updated.

**Constraints:**
- **Atomic PR.** Workflow edits and inventory update must move together. Do not split into separate PRs.
- **Pre-flight v5 availability check.** Do not bump to a successor that is not yet GA. If a v5 is missing, leave the v4 row in the inventory as `Deprecated-with-deadline`, file a follow-up issue, and document the deferral in the PR body. Half-bumps are legal as long as every deferred bump is tracked.
- **Read release notes per-bump.** Breaking changes between v4 and v5 (or v3 and v4) are possible. Each bump is reviewed against its release notes; non-trivial breaking changes that affect this codebase trigger a per-workflow re-author or a follow-up packet. The first-pass goal is mechanical swaps.
- **Invariant 38 (post-acceptance):** All bumped actions are first-party; the bump introduces no new third-party wrappers. If during the bump a marketplace wrapper is encountered, do **not** bump it as part of this packet — that is a D4 retrofit concern (file a follow-up referencing packet 07's audit doc).

**Key Files:**
- `.github/workflows/*.yml` — all workflows (read-write).
- `.github/actions/**/action.yml` — all composite actions (read-write).
- `docs/action-pins.md` — inventory (read-write); updated atomically with the workflow edits.
- `docs/CHANGELOG.md` — append entry.

**Contracts:** No code or schema contracts. The action versions are external dependencies; pin updates are tracked in the inventory.
