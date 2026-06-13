---
name: CI Change
type: ci-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-1", "ops", "adr-0086", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0086", "ADR-0044"]
accepts: []
wave: 1
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-actions
---

# Add worker and managed PR labels Grid-wide

## Summary
Add the ADR-0086 worker-state labels and the central managed PR-label vocabulary to the labels-as-code config in `HoneyDrunk.Actions/.github/config/labels.json`, then fan them out across every Grid repo via the existing `seed-labels-fanout.yml` pattern that landed under the ADR-0011 / ADR-0044 rollouts. The worker labels are the protocol state the pull-based local worker reads and writes per ADR-0086 D2 / D3. The managed PR labels are the bounded label set packet 05 may normalize from packet metadata, ADR references, changed files, and PR title/body.

## Target Workflow
**File:** `.github/config/labels.json` (config edit) and `.github/workflows/seed-labels-fanout.yml` (re-run; no shape change)
**Family:** manual / labels-as-code

## Motivation
ADR-0086 D2 / D3 define the four labels the pull-based local worker uses as both queue index and protocol state:
- `needs-agent-review` — the queue index. Added by `job-review-request.yml` (packet 05) on every triggering `pull_request` event. The worker polls against this label.
- `agent-review-in-progress` — the claim marker. Added by the worker on swap-claim, removed on complete or claim-invalidation.
- `agent-reviewed` — the success terminal state. Added by the worker on verdict post when there are no `Block` / `Request Changes` findings.
- `changes-requested-by-agent` — the changes-requested terminal state. Added by the worker on verdict post when one or more findings are at `Block` / `Request Changes` severity.

The existing labels-as-code config in `HoneyDrunk.Actions/.github/config/labels.json` already carries `audit-sample`, `large-pr`, `out-of-band`, `skip-review` (ADR-0044 packet 08). This packet extends that config with the four new worker labels **and** the managed metadata labels packet 05 can apply. Without these labels in labels-as-code, the new normalizer would either create unmanaged labels opportunistically or be forced to limit itself to a too-small vocabulary; both outcomes make PR metadata driftier than it needs to be.

Adding these labels Grid-wide before any repo is actually enabled is safe — labels are passive; they have no effect until a workflow uses them. Phase B fan-out (packet 09) flips repos to `runner: local-worker`; until that happens, the labels just sit there.

## Proposed Change

### Worker label definitions to add to `.github/config/labels.json`
```json
{
  "name": "needs-agent-review",
  "color": "1d76db",
  "description": "PR is in the Grid Review Runner queue; the pull-based local worker will pick it up on its next tick (ADR-0086 D2)."
},
{
  "name": "agent-review-in-progress",
  "color": "fbca04",
  "description": "Local worker has claimed the PR and is running the review. Stale claims (no progress > 15 min) are swept back to needs-agent-review (ADR-0086 D3)."
},
{
  "name": "agent-reviewed",
  "color": "0e8a16",
  "description": "Local worker posted a clean Grid review verdict (no Block / Request Changes findings)."
},
{
  "name": "changes-requested-by-agent",
  "color": "b60205",
  "description": "Local worker posted a Grid review verdict with one or more Block / Request Changes findings."
}
```

Color picks rationale:
- `1d76db` blue — queued/in-flight; distinct from `audit-sample`'s purple and `large-pr`'s yellow.
- `fbca04` yellow — work in progress. Matches `large-pr`'s yellow palette family; they don't collide because they apply to disjoint phases.
- `0e8a16` green — clean pass.
- `b60205` red — changes requested.

If any color collides with an existing label in the palette, the implementing agent picks the nearest acceptable alternative; record the chosen colors in the PR body.

### Managed PR-label vocabulary to add to `.github/config/labels.json`
Add or verify definitions for the labels packet 05 is allowed to normalize:

- `meta` — architecture/governance/catalog/process work.
- `docs` — documentation-only or documentation-primary changes.
- `ci` — GitHub Actions, build, release, or workflow changes.
- `bug` — defect fix.
- `enhancement` — product or capability improvement.
- `dependencies` — package, tool, SDK, or dependency update.
- `chore` — maintenance work that is not a feature, bug, or refactor.
- `security` — security-sensitive code, configuration, or process changes.
- `breaking-change` — public API, schema, workflow contract, or behavior change requiring consumer action.
- `refactor` — behavior-preserving structural change.
- `test` — test-only or test-infrastructure change.
- `infra` — GitHub Apps, Vault, Azure, local worker, Task Scheduler, deployment plumbing.
- `automation` — agent, bot, scheduled-runner, or automated workflow behavior.
- `human-only` — work requiring manual portal/account/operator action.
- `blocked` — work that cannot proceed until an external/manual prerequisite clears.
- `superseded` — issue/packet/PR replaced by newer scoped work.
- `new-node` — new Grid Node or repo standup work.
- `catalog` — Architecture catalog/index changes.
- `contracts` — public abstractions/API contracts or compatibility surface.
- `scaffolding` — initial repo/node/project setup.

Pattern labels are also part of the managed set, but are created on demand from packet metadata rather than pre-enumerated exhaustively:

- `adr-*`
- `tier-*`
- `wave-*`
- initiative labels, e.g. `adr-0086-pull-based-local-worker-grid-review`

The implementing Actions PR may choose exact colors, but should keep the palette readable and avoid reusing a color for semantically opposite states. Descriptions must be present for every concrete label.

### Fan-out
Re-run `seed-labels-fanout.yml` (`workflow_dispatch`) to apply the labels across every Grid repo — the same repo set the ADR-0044 packet 08 fan-out used. The fan-out workflow is idempotent: existing labels are updated only according to labels-as-code; missing labels are created on each repo; reruns do not error.

The fan-out covers all repos in the `repo-to-node.yml` mapping (per ADR-0011 / ADR-0044 pattern). The labels become present on every Grid repo whether or not that repo will ever enable the reviewer — that's fine; unused labels are harmless.

### Documentation
- `docs/CHANGELOG.md` — entry noting the worker labels and managed PR-label vocabulary.

### What this packet does NOT do
- Does **not** edit any workflow file. `job-review-request.yml` is packet 05's concern.
- Does **not** add labels to any specific PR. The workflows handle that at runtime.

## Consumer Impact
- Every Grid repo gains the worker labels and managed PR-label vocabulary. Purely additive except for labels-as-code description/color reconciliation on labels the Grid owns.

## Breaking Change?
- [ ] Yes
- [x] No — additive label seeding via the established idempotent fan-out.

## Acceptance Criteria
- [ ] `.github/config/labels.json` defines `needs-agent-review`, `agent-review-in-progress`, `agent-reviewed`, `changes-requested-by-agent` with colors and descriptions
- [ ] `.github/config/labels.json` defines the concrete managed PR labels: `meta`, `docs`, `ci`, `bug`, `enhancement`, `dependencies`, `chore`, `security`, `breaking-change`, `refactor`, `test`, `infra`, `automation`, `human-only`, `blocked`, `superseded`, `new-node`, `catalog`, `contracts`, `scaffolding`
- [ ] The packet 05 normalizer documents how pattern labels (`adr-*`, `tier-*`, `wave-*`, initiative labels) are created from labels-as-code defaults when first observed
- [ ] `seed-labels-fanout.yml` has been run and the worker labels plus concrete managed PR labels exist on every Grid repo (verified by browsing each repo's `/labels` page or via a scripted check)
- [ ] The fan-out remains idempotent — re-running it does not error or duplicate
- [ ] `docs/CHANGELOG.md` updated noting the worker labels, managed PR-label vocabulary, and the ADR-0086 reference

## Human Prerequisites
- [ ] Confirm the `LABELS_FANOUT_PAT` (or whichever token the existing fan-out uses) is still valid and scoped to the full repo set; refresh if expired
- [ ] Trigger the `seed-labels-fanout.yml` `workflow_dispatch` run after the labels-as-code config PR merges
- [ ] Verify the fan-out run completed cleanly before packet 05's `job-review-request.yml` rewrite ships and starts adding `needs-agent-review` or managed metadata labels to PRs

## Dependencies
- `work-item:01` — ADR-0086 acceptance (soft; the labels exist to support the protocol ADR-0086 D2/D3 describes).

## Referenced ADR Decisions

**ADR-0086 D2** — Enqueue mechanism is GitHub-native (label + queue comment). `needs-agent-review` is the primary index the worker polls against.

**ADR-0086 D3** — Claim protocol uses label swap as the atomic primitive. `agent-review-in-progress` is the claim marker; `agent-reviewed` and `changes-requested-by-agent` are the terminal states.

**ADR-0086 Affected Nodes — "Every `enabled` repo"** — Gets the worker labels and managed PR-label vocabulary via the existing label-setup pattern. Existing labels are preserved unless they are inside the managed set and labels-as-code updates their description/color.

**ADR-0044 packet 08 (already shipped)** — Established the labels-as-code config + `seed-labels-fanout.yml` pattern for `audit-sample` / `large-pr` / `out-of-band` / `skip-review`. This packet extends the same pattern; no new mechanism.

## Constraints
- **Use the existing labels-as-code pattern.** Do not invent a new mechanism or a parallel fan-out workflow.
- **The fan-out must stay idempotent.** Re-running it must not error or duplicate.
- **Colors must not collide.** If any chosen color matches an existing label in the palette, pick an adjacent acceptable color and record the choice in the PR body.

## Labels
`chore`, `tier-1`, `ops`, `adr-0086`, `wave-1`

## Agent Handoff

**Objective:** Add the worker labels (`needs-agent-review`, `agent-review-in-progress`, `agent-reviewed`, `changes-requested-by-agent`) and managed PR-label vocabulary to the labels-as-code config, then fan them out Grid-wide via the existing `seed-labels-fanout.yml`.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Pre-seed the worker labels and concrete managed PR labels on every Grid repo before packet 05's `job-review-request.yml` rewrite lands and starts applying normalized PR labels.
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase A.
- ADRs: ADR-0086 (D2/D3), ADR-0044 packet 08 (the existing pattern this packet extends).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0086 acceptance (soft).

**Constraints:**
- Reuse the existing labels-as-code / fan-out pattern; keep it idempotent.
- Colors must not collide with existing palette entries.

**Key Files:**
- `.github/config/labels.json`
- `.github/workflows/seed-labels-fanout.yml` (run, no shape change)
- `docs/CHANGELOG.md`

**Contracts:** None.
