---
name: CI Change
type: ci-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-1", "ci-cd", "ops", "adr-0011", "wave-1"]
dependencies: ["Architecture#NN — ADR-0011 acceptance (packet 01)"]
adrs: ["ADR-0011"]
wave: 1
initiative: adr-0011-code-review-pipeline
node: honeydrunk-actions
---

# Feature: Labels-as-code source-of-truth + reusable seed-labels workflow

## Summary
Establish the labels-as-code mechanism: add a `labels.yml` source-of-truth in `HoneyDrunk.Actions/.github/config/` and a `seed-labels.yml` reusable workflow that applies the label set to whatever repo invokes it. Initial label set is the single `out-of-band` label that invariant 32 references.

This packet ships only the config and workflow in `HoneyDrunk.Actions`. The cross-repo apply step (running the workflow against the eleven Grid repos) lives in the sibling packet **05b**, because a cross-repo apply requires either (a) a PAT scoped to the eleven repos plus a fan-out workflow, or (b) per-repo dispatcher commits — both of which are real cross-repo work that does not belong in this single-repo packet.

## Target Repo
`HoneyDrunk.Actions` (the workflow + config). The label is then applied to each Grid repo via the workflow's manual trigger from the consumer side. This packet is filed in `HoneyDrunk.Actions` because the label-as-code source-of-truth and the apply-mechanism live there per ADR-0012's "Actions as CI/CD control plane" stance.

## Motivation
Invariant 32 (now live after packet 01) says: *"Agent-authored PRs must link to their packet in the PR body. … Absent the link, the PR is treated as out-of-band, must carry the `out-of-band` label, and receives a degraded review."*

For that label-bearing path to work, **the label must exist on every repo before any PR needs it**. Today the label exists on no repo. Manually creating it via the GitHub UI on every repo is the kind of drift the Grid is built to avoid: someone creates `out-of-band` on Vault but `out_of_band` on Auth, casing differs across repos, and the review agent's "missing label" finding starts firing for the wrong reason.

ADR-0011's Follow-up Work bullet names this work explicitly: *"Add the `out-of-band` label to each Grid repo's label set — trivial, automatable via a repo-setup script."*

This packet is the smallest viable label-as-code system: one YAML file lists the labels, one reusable workflow applies them, and the rollout to today's repos is a manual `workflow_dispatch` per repo (matching how the existing `repo-to-node.yml` config is consumed). It does not aim to be a complete repo-bootstrap framework — that would be its own ADR and out of scope for this initiative.

## Proposed Implementation

### A. Label source-of-truth

Create `.github/config/labels.yml` in `HoneyDrunk.Actions`. Match the YAML pattern of the existing `.github/config/repo-to-node.yml` (simple top-level keys, alphabetical, comments where useful). Initial content:

```yaml
# Grid label set
# Source-of-truth for labels applied to every active HoneyDrunk repo.
# Apply via the seed-labels.yml reusable workflow.
#
# Conventions:
#   - kebab-case names
#   - Lowercase
#   - Hex colors without leading '#'

labels:
  - name: out-of-band
    color: ed7d31
    description: >-
      PR was not authored from a scope-agent packet; review agent runs without
      packet-scope context (per ADR-0011 D9, invariant 32).
```

Start with just `out-of-band`. Future labels (e.g. `human-only`, `wave-1`, sector tags) can be added in follow-up packets without changing the schema. Do not bundle an aspirational mega-list of labels into this packet — the goal is the single label invariant 32 references.

### B. Reusable workflow

Create `.github/workflows/seed-labels.yml` in `HoneyDrunk.Actions`. Shape:

```yaml
# ==============================================================================
# Seed Labels
# ==============================================================================
# Purpose:
#   Reusable workflow that ensures every label declared in
#   .github/config/labels.yml exists on the calling repo with the right color
#   and description. Idempotent — safe to re-run.
#
# Triggers:
#   workflow_call (from a consuming repo's seed-labels.yml dispatcher)
#   workflow_dispatch (in HoneyDrunk.Actions itself, for testing)
# ==============================================================================

name: Seed Labels

on:
  workflow_call:
    inputs:
      labels-source-ref:
        description: 'Git ref of HoneyDrunk.Actions to read labels.yml from'
        required: false
        type: string
        default: 'main'
    secrets:
      github-token:
        description: 'Token with issues:write on the target repo'
        required: true
  workflow_dispatch:

permissions:
  issues: write

jobs:
  seed:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout HoneyDrunk.Actions (for labels.yml)
        uses: actions/checkout@v4
        with:
          repository: HoneyDrunkStudios/HoneyDrunk.Actions
          ref: ${{ inputs.labels-source-ref || 'main' }}
          path: actions-repo

      - name: Apply labels
        env:
          GH_TOKEN: ${{ secrets.github-token || github.token }}
        shell: bash
        run: |
          set -euo pipefail

          # Parse labels.yml using yq (preinstalled on ubuntu-latest)
          LABELS_FILE=actions-repo/.github/config/labels.yml
          COUNT=$(yq '.labels | length' "$LABELS_FILE")
          echo "Applying $COUNT label(s) from $LABELS_FILE"

          for i in $(seq 0 $((COUNT - 1))); do
            NAME=$(yq ".labels[$i].name" "$LABELS_FILE")
            COLOR=$(yq ".labels[$i].color" "$LABELS_FILE")
            DESCRIPTION=$(yq ".labels[$i].description" "$LABELS_FILE")

            # Idempotent create-or-update via gh
            if gh label list --json name --jq '.[].name' | grep -qx "$NAME"; then
              echo "Updating existing label: $NAME"
              gh label edit "$NAME" --color "$COLOR" --description "$DESCRIPTION"
            else
              echo "Creating label: $NAME"
              gh label create "$NAME" --color "$COLOR" --description "$DESCRIPTION"
            fi
          done
```

Notes:
- `yq` is preinstalled on `ubuntu-latest` GitHub runners; no extra setup required.
- `gh label list/create/edit` is the documented gh CLI for label management.
- The workflow is idempotent — running it twice produces the same end state.
- Permissions are minimal: `issues: write` is sufficient for label CRUD.

### C. Index the labels file

Add a one-line entry to `HoneyDrunk.Actions/README.md` (or to a `.github/config/README.md` if one exists) listing `labels.yml` under "Configuration files" alongside the existing `repo-to-node.yml`.

## Affected Files

In HoneyDrunk.Actions (this packet's PR — single repo):
- `.github/config/labels.yml` (new)
- `.github/workflows/seed-labels.yml` (new)
- `README.md` (root): one-line addition under "Configuration files" / equivalent
- `CHANGELOG.md` (root): append entry to the in-progress version

No cross-repo work in this packet. Cross-repo apply lives in packet 05b.

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits are in `HoneyDrunk.Actions` (the CI toolkit). Routing rule "workflow, CI, GitHub Actions, pipeline, PR check, release → HoneyDrunk.Actions" applies.
- [x] No cross-repo work in this packet. Cross-repo apply is packet 05b's scope.
- [x] No invariant violation. The `out-of-band` label is the surface invariant 32 references.
- [x] No secrets read or written.

## Acceptance Criteria
- [ ] `.github/config/labels.yml` exists in `HoneyDrunk.Actions` with at least the `out-of-band` label (kebab-case name, lowercase, hex color `ed7d31` without `#`, descriptive text)
- [ ] `.github/workflows/seed-labels.yml` exists in `HoneyDrunk.Actions` and is idempotent (running twice leaves state unchanged)
- [ ] The workflow uses `yq` (preinstalled) to parse `labels.yml` and `gh label` CRUD to apply
- [ ] Permissions block declares only `issues: write` (no broader permissions)
- [ ] Workflow is reusable via `workflow_call` and also invokable directly via `workflow_dispatch` in `HoneyDrunk.Actions`
- [ ] `README.md` (root): a one-line addition references `labels.yml` as a configuration source-of-truth alongside `repo-to-node.yml`
- [ ] Repo-level `CHANGELOG.md`: new in-progress entry (or appended to whichever entry packet 02 / 03 already opened on the same wave) describing the new config and workflow
- [ ] No per-package `CHANGELOG.md` updates (no package changes)
- [ ] No additional labels beyond `out-of-band` are seeded in this packet (one-label-at-a-time is intentional; future labels are future packets)
- [ ] `actionlint` is clean on the new workflow
- [ ] Self-test: triggering `seed-labels.yml` via `workflow_dispatch` in `HoneyDrunk.Actions` itself successfully applies the `out-of-band` label to that repo. This single-repo smoke test validates the workflow without depending on the cross-repo apply (packet 05b) being filed yet.

## Human Prerequisites

- [ ] After this packet's PR merges, manually trigger `seed-labels.yml` once via `workflow_dispatch` in the HoneyDrunk.Actions repo's Actions UI. This is the smoke test — it confirms the workflow runs end-to-end and applies `out-of-band` to HoneyDrunk.Actions itself before packet 05b fans the workflow out to the other ten repos.

Cross-repo apply across the eleven repos is **not** in this packet — see packet 05b.

## Dependencies
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft dependency on invariant 32 being live.

## Downstream Unblocks
- **Packet 05b** (cross-repo apply across the eleven Grid repos) is hard-blocked on this packet because it dispatches the workflow this packet ships.
- The review agent's out-of-band detection (per ADR-0011 D9) can report a finding once 05b lands and the label exists on every repo.
- Future label-as-code additions (e.g. `human-only` standardization, sector tags) become trivial extensions to `labels.yml`.

## Referenced ADR Decisions

**ADR-0011 (Code Review and Merge Flow):**
- **D9 (out-of-band PRs):** A PR that does not link to a packet is out-of-band. Out-of-band PRs still traverse the full pipeline; the review agent's packet-loading step is skipped. They must carry the `out-of-band` label.
- **Follow-up Work bullet:** "Add the `out-of-band` label to each Grid repo's label set — trivial, automatable via a repo-setup script." This packet is exactly that bullet.

**ADR-0012 (HoneyDrunk.Actions as Grid CI/CD Control Plane):** Names `HoneyDrunk.Actions/.github/config/` as the right home for shared tool config. `labels.yml` follows this pattern.

## Referenced Invariants

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR is treated as out-of-band, must carry the `out-of-band` label, and receives a degraded review in which the agent runs against the Grid context only (invariants, boundaries, relationships, diff) without a packet-scope check.

## Constraints
- **One label this packet, more later.** Do not pad `labels.yml` with aspirational labels. Future labels are future packets.
- **Idempotent apply.** The workflow must produce the same end state when run twice. Run-once side effects (e.g. opening an issue when a label is created) are out of scope.
- **Minimal permissions.** Only `issues: write`. No `contents: write`, no `pull-requests: write` here.
- **Single-repo scope.** This packet does not reach into other repos. Cross-repo apply is packet 05b.
- **No secrets in the workflow.** `secrets.github-token` is the only secret consumed, and it is the standard `GITHUB_TOKEN` already available in every consumer.
- **`actionlint` clean.** Match the discipline of the other workflows in `.github/workflows/`.

## Labels
`chore`, `tier-1`, `ci-cd`, `ops`, `adr-0011`, `wave-1`

## Agent Handoff

**Objective:** Ship `.github/config/labels.yml` (single label `out-of-band` for now) and a reusable `.github/workflows/seed-labels.yml` workflow in `HoneyDrunk.Actions`. Single-repo packet — cross-repo apply across the eleven Grid repos lives in sibling packet 05b. The smoke test is triggering `seed-labels.yml` via `workflow_dispatch` in HoneyDrunk.Actions itself (Human Prerequisite, post-merge).

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make invariant 32's `out-of-band` label exist consistently across the Grid.
- Feature: ADR-0011 Code Review Pipeline rollout.
- ADRs: ADR-0011 (D9, Follow-up Work bullet), ADR-0012 (Actions config home).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft dependency.

**Constraints:**
- Single label this packet (`out-of-band`); no aspirational fan-out into a label catalogue.
- Idempotent workflow.
- Permissions: `issues: write` only.
- Single-repo scope — cross-repo apply is packet 05b.
- The label color is `ed7d31` (orange/amber — distinct from sector colors and from `human-only` if it is later added).
- `actionlint` clean.

**Key Files:**
- `.github/config/labels.yml` (new)
- `.github/workflows/seed-labels.yml` (new)
- `.github/config/repo-to-node.yml` (existing — style reference)
- `README.md` (root)
- `CHANGELOG.md` (root)

**Contracts:**
- `out-of-band` label name (kebab-case, lowercase). Renaming would break the review agent's expectations.
