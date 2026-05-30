---
name: CI Change
type: ci-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-1", "ci-cd", "ops", "adr-0011", "wave-1"]
dependencies: ["Actions#NN — labels-as-code config + seed-labels.yml (packet 05a)", "Architecture#NN — ADR-0011 acceptance (packet 01)"]
adrs: ["ADR-0011"]
wave: 1
initiative: adr-0011-code-review-pipeline
node: honeydrunk-actions
---

# Feature: Fan out the `out-of-band` label across the eleven Grid repos

## Summary
Apply the `out-of-band` label (defined in packet 05a's `.github/config/labels.yml`) to every active Grid repo so that PRs lacking a packet link (per invariant 32) can be tagged consistently. Implementation: add a `seed-labels-fanout.yml` workflow in `HoneyDrunk.Actions` that takes a list of target repos and applies the labels-as-code config to each, using a PAT (provisioned by the human as a Human Prerequisite) authorised to write labels on the eleven repos. Trigger it once via `workflow_dispatch` to seed the initial label.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions` (the fan-out workflow lives where labels-as-code lives, per ADR-0012's "Actions as CI/CD control plane" stance).

## Motivation
Packet 05a ships labels-as-code (`.github/config/labels.yml`) and the per-repo `seed-labels.yml` reusable workflow. But the reusable workflow only applies labels to the **calling** repo — it cannot reach across repo boundaries on its own. To make `out-of-band` exist on every Grid repo today, something has to dispatch the workflow (or call `gh label` directly) against each of the eleven repos.

Three options were considered:
1. **Per-repo dispatcher commits.** Commit a thin `seed-labels.yml` dispatcher into each of the eleven repos. Each dispatcher is two lines and uses each repo's own `GITHUB_TOKEN`. Eleven separate one-line PRs is a lot of orchestration cost for a one-time seeding.
2. **One-shot bash script run by the human.** The human runs `gh label create out-of-band --color ed7d31 --description "…" --repo HoneyDrunkStudios/<repo>` against each repo from their local shell. Fast for the first label but throws away the labels-as-code mechanism — every future label rerun is a new bash script, not a workflow.
3. **A fan-out workflow in HoneyDrunk.Actions** that uses a PAT scoped to the eleven repos to call `gh label create/edit` against each. Reuses labels-as-code, agent-authorable end-to-end, future labels reuse the same workflow.

This packet ships option 3. The PAT setup is the only Human Prerequisite; the workflow itself is agent work.

## Proposed Implementation

### A. Provision the cross-repo PAT (Human Prerequisite)

The fan-out workflow needs a token that can `gh label create/edit` against the eleven Grid repos. The default `GITHUB_TOKEN` in HoneyDrunk.Actions is scoped to HoneyDrunk.Actions only. Options for the cross-repo token:

- **Fine-grained PAT** (preferred) — owned by the user, scoped to the eleven repos under `HoneyDrunkStudios`, with `Contents: Read` and `Issues: Write`. One-year expiry; rotation is a future concern (ADR-0009 rotation territory).
- **GitHub App installed on the eleven repos with `issues:write`** — more durable but heavier setup. Skip for v1; the fine-grained PAT is fine for a one-shot fan-out plus occasional reruns.

Stored as a HoneyDrunk.Actions repo secret named `LABELS_FANOUT_PAT`. The Human Prerequisite section captures the click-through; this is the single portal step.

### B. Fan-out workflow

Create `.github/workflows/seed-labels-fanout.yml` in `HoneyDrunk.Actions`:

```yaml
# ==============================================================================
# Seed Labels — Fan-out across the Grid
# ==============================================================================
# Purpose:
#   Applies the labels declared in .github/config/labels.yml to every Grid
#   repo enumerated below. Triggered manually via workflow_dispatch.
#   Idempotent — re-runs are safe.
#
#   Cross-repo writes use the LABELS_FANOUT_PAT secret (a fine-grained PAT
#   scoped to the eleven repos with Issues:Write). The default GITHUB_TOKEN
#   only has access to HoneyDrunk.Actions itself and cannot reach the others.
#
# Triggers:
#   workflow_dispatch only — a one-shot seeding tool, not a CI gate.
# ==============================================================================

name: Seed Labels — Fan-out

on:
  workflow_dispatch:
    inputs:
      target-repos:
        description: >-
          Comma-separated list of repo names (without owner prefix) to apply
          labels to. Default is the eleven active Grid repos. Override to seed
          a single repo for testing.
        required: false
        type: string
        default: 'HoneyDrunk.Kernel,HoneyDrunk.Transport,HoneyDrunk.Vault,HoneyDrunk.Vault.Rotation,HoneyDrunk.Auth,HoneyDrunk.Web.Rest,HoneyDrunk.Data,HoneyDrunk.Pulse,HoneyDrunk.Notify,HoneyDrunk.Actions,HoneyDrunk.Architecture'

permissions:
  contents: read

jobs:
  fanout:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout HoneyDrunk.Actions (for labels.yml)
        uses: actions/checkout@v4

      - name: Apply labels to each target repo
        env:
          GH_TOKEN: ${{ secrets.LABELS_FANOUT_PAT }}
          TARGETS: ${{ inputs.target-repos }}
        shell: bash
        run: |
          set -euo pipefail

          LABELS_FILE=.github/config/labels.yml
          COUNT=$(yq '.labels | length' "$LABELS_FILE")
          echo "Applying $COUNT label(s) to repos: $TARGETS"

          IFS=',' read -ra REPOS <<< "$TARGETS"
          for REPO in "${REPOS[@]}"; do
            REPO_TRIMMED=$(echo "$REPO" | tr -d '[:space:]')
            FULL_REPO="HoneyDrunkStudios/${REPO_TRIMMED}"
            echo "--- ${FULL_REPO} ---"

            for i in $(seq 0 $((COUNT - 1))); do
              NAME=$(yq ".labels[$i].name" "$LABELS_FILE")
              COLOR=$(yq ".labels[$i].color" "$LABELS_FILE")
              DESCRIPTION=$(yq ".labels[$i].description" "$LABELS_FILE")

              if gh label list --repo "$FULL_REPO" --json name --jq '.[].name' | grep -qx "$NAME"; then
                echo "  [update] $NAME on $FULL_REPO"
                gh label edit "$NAME" --color "$COLOR" --description "$DESCRIPTION" --repo "$FULL_REPO"
              else
                echo "  [create] $NAME on $FULL_REPO"
                gh label create "$NAME" --color "$COLOR" --description "$DESCRIPTION" --repo "$FULL_REPO"
              fi
            done
          done

          echo "Fan-out complete."
```

Notes:
- The default `target-repos` value enumerates the eleven repos. The user can override it via `workflow_dispatch` to test against a single repo first.
- The workflow uses `LABELS_FANOUT_PAT`, not `GITHUB_TOKEN`. The token has `Issues: Write` on each of the eleven repos.
- Idempotent — running twice produces the same end state.
- HoneyDrunk.Studios is **excluded** from the default list (it is not a .NET repo and ADR-0011 D11 / invariant 32 are scoped to the .NET PR pipeline today).

### C. Document the fan-out workflow

Add a one-line entry to `HoneyDrunk.Actions/README.md` under the "Workflows" or equivalent section, briefly describing `seed-labels-fanout.yml` as the cross-repo apply mechanism for `labels.yml`.

## Affected Files
- `.github/workflows/seed-labels-fanout.yml` (new)
- `README.md` (root): one-line addition under the workflows / configuration section
- `CHANGELOG.md` (root): append entry to the in-progress version describing the fan-out workflow

## NuGet Dependencies
None.

## Boundary Check
- [x] Workflow file lives in `HoneyDrunk.Actions`. Routing rule "workflow, CI, GitHub Actions, pipeline, PR check, release → HoneyDrunk.Actions" applies.
- [x] The cross-repo writes go through a token (the PAT) — they do not commit code into the eleven target repos. Labels are repo-metadata, not code; this respects the per-repo code-ownership boundary.
- [x] No invariant violation. The label is the surface invariant 32 references.
- [x] PAT is a Human Prerequisite, scoped narrowly to `Issues: Write` on the eleven specific repos.

## Acceptance Criteria
- [ ] `.github/workflows/seed-labels-fanout.yml` exists in `HoneyDrunk.Actions` with the shape specified above
- [ ] Workflow is `workflow_dispatch`-only (no `pull_request` or `push` triggers — it is a one-shot seeding tool, not a CI gate)
- [ ] Default `target-repos` input lists the eleven active Grid repos: HoneyDrunk.Kernel, HoneyDrunk.Transport, HoneyDrunk.Vault, HoneyDrunk.Vault.Rotation, HoneyDrunk.Auth, HoneyDrunk.Web.Rest, HoneyDrunk.Data, HoneyDrunk.Pulse, HoneyDrunk.Notify, HoneyDrunk.Actions, HoneyDrunk.Architecture
- [ ] HoneyDrunk.Studios is **not** in the default list
- [ ] Workflow uses `LABELS_FANOUT_PAT` (not `GITHUB_TOKEN`) for cross-repo writes
- [ ] Permissions block declares only `contents: read` (the cross-repo writes happen via the PAT in env, not via the workflow's permissions)
- [ ] Workflow is idempotent (running twice leaves state unchanged)
- [ ] After the human triggers the workflow once, the `out-of-band` label exists with color `ed7d31` and the configured description on every one of the eleven repos in the default list
- [ ] HoneyDrunk.Studios does NOT have the label (verify by browsing `https://github.com/HoneyDrunkStudios/HoneyDrunk.Studios/labels`)
- [ ] Repo-level `CHANGELOG.md`: append entry to the in-progress version describing the fan-out workflow (or to whatever entry packet 02 / 03 / 05a opened on the same wave — invariants 12 and 27)
- [ ] No per-package `CHANGELOG.md` updates (no package changes)
- [ ] `actionlint` clean

## Human Prerequisites

- [ ] **Provision the `LABELS_FANOUT_PAT` PAT.** Click-through:
  1. Go to `https://github.com/settings/personal-access-tokens/new` (fine-grained PAT settings).
  2. Token name: `HoneyDrunk Labels Fan-out`. Expiration: 1 year.
  3. Resource owner: `HoneyDrunkStudios`.
  4. Repository access: "Only select repositories" → choose the eleven: HoneyDrunk.Kernel, HoneyDrunk.Transport, HoneyDrunk.Vault, HoneyDrunk.Vault.Rotation, HoneyDrunk.Auth, HoneyDrunk.Web.Rest, HoneyDrunk.Data, HoneyDrunk.Pulse, HoneyDrunk.Notify, HoneyDrunk.Actions, HoneyDrunk.Architecture. **Do not include HoneyDrunk.Studios.**
  5. Permissions: Repository permissions → `Issues: Read and write`. Everything else default (Read-only or No access).
  6. Generate the token. Copy the value (it is shown once).
  7. In `HoneyDrunk.Actions`'s repo settings → Secrets and variables → Actions → New repository secret. Name: `LABELS_FANOUT_PAT`. Value: the token. Save.
- [ ] **Trigger the fan-out workflow once.** After this packet's PR merges and the PAT secret exists:
  1. Go to `https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/actions/workflows/seed-labels-fanout.yml`.
  2. Click "Run workflow" → leave default `target-repos` → "Run workflow."
  3. Wait for completion. Inspect logs for any `[create]` or `[update]` lines.
- [ ] **Verify the eleven repos** at `https://github.com/HoneyDrunkStudios/<repo>/labels` show `out-of-band` with color `ed7d31` and the configured description.
- [ ] **Confirm Studios excluded** at `https://github.com/HoneyDrunkStudios/HoneyDrunk.Studios/labels` does NOT show `out-of-band`.

## Dependencies
- **Actions#NN** — Packet 05a (labels-as-code config + reusable seed-labels.yml). Hard dependency: this packet's fan-out workflow reads `.github/config/labels.yml` shipped by 05a.
- **Architecture#NN** — Packet 01 (ADR-0011 acceptance). Soft dependency: invariant 32 ("must carry the `out-of-band` label") is the rationale for fanning out the label.

## Downstream Unblocks
- The review agent's out-of-band detection (per ADR-0011 D9) can now report a finding when an out-of-band PR lacks the label, instead of having to suggest "create this label first."
- Wave-2 onboarding packets (06, 07) can rely on the label existing on Kernel and Web.Rest from day one.
- Future label additions in `labels.yml` re-trigger the same fan-out workflow with one click — no per-label engineering work.

## Referenced ADR Decisions

**ADR-0011 (Code Review and Merge Flow):**
- **D9 (out-of-band PRs):** A PR that does not link to a packet is out-of-band. They must carry the `out-of-band` label.
- **Follow-up Work bullet:** "Add the `out-of-band` label to each Grid repo's label set — trivial, automatable via a repo-setup script." This packet (with 05a) is exactly that bullet.

**ADR-0012 (HoneyDrunk.Actions as Grid CI/CD Control Plane):** Names `HoneyDrunk.Actions/.github/config/` as the home for shared tool config and `.github/workflows/` as the home for cross-repo CI orchestration. The fan-out workflow lives where the config lives.

## Referenced Invariants

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR is treated as out-of-band, must carry the `out-of-band` label, and receives a degraded review in which the agent runs against the Grid context only (invariants, boundaries, relationships, diff) without a packet-scope check.

> **Invariant 9 (secrets):** Vault is the only source of secrets. *(Reframed for CI: `LABELS_FANOUT_PAT` is a CI-runtime PAT stored as a GitHub repo secret. It is not application-runtime data; the invariant applies to application code reading secrets at runtime, not to CI workflows reading repo-level secrets via the `secrets.` context.)*

## Constraints
- **`workflow_dispatch` only.** Do not add `pull_request` or `push` triggers — this is a one-shot seeding tool, not a CI gate that should run on every PR.
- **PAT, not `GITHUB_TOKEN`.** Default `GITHUB_TOKEN` is scoped to HoneyDrunk.Actions only and cannot write labels on other repos. Do not try to use `secrets.GITHUB_TOKEN` here — it will silently fail with permission errors against other repos.
- **PAT scope is narrow.** `Issues: Write` only, on the eleven specific repos. No org-admin scope, no `Contents: Write`, no `Pull requests: Write`. Anything broader is a security regression.
- **Studios excluded from defaults.** Even if a future change broadens the default list, do not add Studios without a separate explicit decision.
- **Idempotent.** The workflow must produce the same end state when run twice.
- **`actionlint` clean.**

## Labels
`chore`, `tier-1`, `ci-cd`, `ops`, `adr-0011`, `wave-1`

## Agent Handoff

**Objective:** Ship `.github/workflows/seed-labels-fanout.yml` in `HoneyDrunk.Actions` — a `workflow_dispatch`-triggered cross-repo apply that uses the `LABELS_FANOUT_PAT` secret to call `gh label create/edit` against each of the eleven enumerated Grid repos, applying the labels-as-code config from packet 05a's `labels.yml`. Single PR in HoneyDrunk.Actions; the human provisions the PAT (Human Prerequisite) and triggers the workflow once after merge.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make `out-of-band` exist on every Grid repo so invariant 32 enforcement is mechanical.
- Feature: ADR-0011 Code Review Pipeline rollout.
- ADRs: ADR-0011 (D9, Follow-up Work bullet), ADR-0012 (Actions config home).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Actions#NN — Packet 05a (labels-as-code config + reusable seed-labels.yml). Hard.
- Architecture#NN — Packet 01 (ADR-0011 acceptance). Soft.

**Constraints:**
- `workflow_dispatch` only — no `pull_request` or `push` triggers.
- Use `LABELS_FANOUT_PAT` for cross-repo writes; the default `GITHUB_TOKEN` cannot reach other repos.
- Default target-repos list excludes HoneyDrunk.Studios.
- Idempotent.
- Permissions block: `contents: read` only.
- `actionlint` clean.

**Key Files:**
- `.github/workflows/seed-labels-fanout.yml` (new)
- `.github/config/labels.yml` (existing — shipped by packet 05a)
- `.github/workflows/seed-labels.yml` (existing — shipped by packet 05a; not called from the fan-out, but documented as the related sibling)
- `README.md` (root)
- `CHANGELOG.md` (root)

**Contracts:**
- Secret name: `LABELS_FANOUT_PAT`. Renaming would invalidate the human's PAT setup.
- Default target-repos list: the eleven Grid repos minus Studios. Any addition or removal is a deliberate scope change that warrants a follow-up packet.
