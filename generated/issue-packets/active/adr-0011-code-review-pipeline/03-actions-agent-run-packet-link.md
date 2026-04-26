---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ci-cd", "ops", "adr-0011", "wave-1"]
dependencies: ["Architecture#NN — ADR-0011 acceptance (packet 01)"]
adrs: ["ADR-0011", "ADR-0008"]
wave: 1
initiative: adr-0011-code-review-pipeline
node: honeydrunk-actions
---

# Feature: Inject packet link into agent-authored PR bodies in `agent-run.yml`

## Summary
Amend the cloud agent-execution workflow `agent-run.yml` so that when an agent opens a PR for an issue packet, the PR body always contains a fully-resolved link to the packet file in `HoneyDrunk.Architecture`. This makes invariant 32 ("agent-authored PRs must link to their packet in the PR body") mechanically enforced for every agent-authored PR.

The packet uses two complementary mechanisms:
1. **Prompt-side instruction (soft, primary path).** When `packet-path` is supplied, the workflow appends a structured "Packet: <permalink>" instruction to the agent's prompt envelope so well-behaved agents include the line directly.
2. **Workflow-side post-hoc assert (hard, mechanical guarantee).** After the agent finishes, a new "Assert PR-body packet link" step locates any PR the agent opened on the run's branch and uses `gh pr edit` to ensure the `> Packet: <permalink>` line is present in the PR body. The workflow is the source of truth — invariant 32 enforcement does not depend on the LLM remembering its instructions.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
Invariant 32 (now live after packet 01 lands) requires every agent-authored PR to link to its packet. The review agent uses that link to resolve the packet, which is its primary scope anchor (ADR-0011 D3). Today, whether the link appears depends on the agent's prompt discipline — it is not a property of the workflow.

`agent-run.yml` is the single entrypoint for cloud-driven agent work in the Grid (per its own header comment block). It already accepts an `agent` input and resolves a prompt from `.claude/agents/{agent}.md`. What it does not do is communicate the **target packet** to the agent in a structured way that survives into the PR body. This packet closes that gap.

The naive form ("just tell the agent to include the line") is a soft enforcement — it makes invariant 32 contingent on the model following instructions, which is exactly the drift mode ADR-0011 is trying to prevent. To harden it, the workflow itself asserts the line into the PR body after the agent completes. The agent's instruction is still useful (it gives the model a chance to author the link in the right place naturally) but it is no longer the only line of defence. The workflow is the mechanical guarantor of invariant 32.

## Proposed Implementation

### A. Add a `packet-path` input

In `.github/workflows/agent-run.yml`, add a new optional input alongside `agent`, `prompt`, and `checkout-target`:

```yaml
      packet-path:
        description: >-
          Optional path to the issue packet file (relative to HoneyDrunk.Architecture
          root, e.g. generated/issue-packets/active/adr-0011-code-review-pipeline/02-actions-job-sonarcloud-workflow.md).
          When set, the workflow injects a "Packet: <permalink>" line into the
          agent's prompt envelope so any PR opened by the agent links back to
          the packet (per invariant 32 in HoneyDrunk.Architecture).
        required: false
        type: string
        default: ''
```

### B. Resolve the packet permalink

In the existing **Resolve prompt** step, before assembling the prompt, compute the GitHub permalink to the packet file. The permalink format is:

```
https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/<architecture-ref>/<packet-path>
```

Use `${{ inputs.architecture-ref }}` (which already defaults to `main`) so the link tracks the same ref the workflow checked out. Computing it in shell is safer than constructing it in `${{ }}` interpolation when `packet-path` is empty:

```yaml
      - name: Resolve packet link
        id: packet
        env:
          PACKET_PATH: ${{ inputs.packet-path }}
          ARCH_REF: ${{ inputs.architecture-ref }}
        run: |
          set -euo pipefail
          if [[ -n "${PACKET_PATH}" ]]; then
            LINK="https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/${ARCH_REF}/${PACKET_PATH}"
            echo "link=${LINK}" >> "$GITHUB_OUTPUT"
            echo "has-packet=true" >> "$GITHUB_OUTPUT"
            # Verify the file exists in the checked-out Architecture tree
            if [[ ! -f "${PACKET_PATH}" ]]; then
              echo "::warning::packet-path '${PACKET_PATH}' was supplied but the file does not exist at the resolved Architecture ref. The PR will still be opened, but the packet link will 404. Verify packet-path matches the on-disk path."
            fi
          else
            echo "has-packet=false" >> "$GITHUB_OUTPUT"
          fi
```

The warning case is intentional: the workflow does not fail when the packet file is missing, because that would block hotfix-style or out-of-band agent runs that legitimately have no packet. It logs a warning and continues, and the resulting PR will not link to a packet — which downstream tooling (the review agent, the human) will recognize as out-of-band per ADR-0011 D9.

### C. Inject the link into the agent's prompt

Modify the existing **Resolve prompt** step (it currently assembles the agent or direct-prompt envelope and writes it to `$GITHUB_OUTPUT`) so that when `packet-path` is supplied, the envelope ends with a structured instruction:

```yaml
      - name: Resolve prompt
        id: resolve
        env:
          AGENT: ${{ inputs.agent }}
          PROMPT: ${{ inputs.prompt }}
          HAS_PACKET: ${{ steps.packet.outputs.has-packet }}
          PACKET_LINK: ${{ steps.packet.outputs.link }}
          PACKET_PATH: ${{ inputs.packet-path }}
        run: |
          set -euo pipefail

          # Build the base envelope (existing logic — unchanged in shape)
          if [[ -n "${AGENT}" ]]; then
            BASE="You are the **${AGENT}** agent. Read your full instructions from \`.claude/agents/${AGENT}.md\` first, then execute your full workflow as described there."
          else
            BASE="${PROMPT}"
          fi

          # When a packet is supplied, append a structured instruction.
          # The agent must include this exact "Packet:" line in any PR body it opens.
          if [[ "${HAS_PACKET}" == "true" ]]; then
            PACKET_INSTRUCTION="

          ---

          **Issue packet for this run:** \`${PACKET_PATH}\`
          **Packet permalink:** ${PACKET_LINK}

          When you open a pull request for this work, include the following line verbatim in the PR body (this satisfies invariant 32 in HoneyDrunk.Architecture and is what the review agent uses to resolve the packet as the primary scope anchor):

          > Packet: ${PACKET_LINK}

          If you cannot include the link for any reason, label the PR \`out-of-band\` and explain why in the PR body."
            FULL_PROMPT="${BASE}${PACKET_INSTRUCTION}"
          else
            FULL_PROMPT="${BASE}"
          fi

          {
            echo "prompt<<EOF_PROMPT"
            printf '%s' "${FULL_PROMPT}"
            echo ""
            echo "EOF_PROMPT"
          } >> "$GITHUB_OUTPUT"
```

The existing **Resolve prompt** step already exists in `agent-run.yml`; this is a refactor of that step, not a new step. Preserve the existing branching between `agent` and `prompt` modes — only the post-envelope packet instruction is new.

### D. Optional: caller convenience hint

In the workflow header comment block, add a usage example showing the new input:

```yaml
# Usage example (named agent + packet):
#   jobs:
#     execute:
#       uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/agent-run.yml@main
#       with:
#         agent: execute
#         packet-path: generated/issue-packets/active/adr-0011-code-review-pipeline/02-actions-job-sonarcloud-workflow.md
#         checkout-target: HoneyDrunkStudios/HoneyDrunk.Actions
#       secrets:
#         anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
#         github-token: ${{ secrets.AGENT_RUN_TOKEN }}
```

Match the style of the two existing usage examples in the header.

### E. Post-hoc assert step — the mechanical guarantor

The prompt-injection in step C is best-effort soft enforcement. To make invariant 32 mechanically reliable regardless of LLM behaviour, add a new step **after** the agent run steps (after both `Run agent — Claude` and `Run agent — Codex`, conditional on `inputs.packet-path` being non-empty) that locates the PR the agent opened on this run's branch and asserts the `> Packet: <permalink>` line into the PR body via `gh pr edit`.

Step shape:

```yaml
      - name: Assert PR-body packet link
        if: ${{ inputs.packet-path != '' }}
        env:
          GH_TOKEN: ${{ secrets.github-token }}
          PACKET_LINK: ${{ steps.packet.outputs.link }}
          PACKET_PATH: ${{ inputs.packet-path }}
          CHECKOUT_TARGET: ${{ inputs.checkout-target }}
        shell: bash
        run: |
          set -euo pipefail

          if [[ -z "${CHECKOUT_TARGET}" ]]; then
            echo "::notice::No checkout-target — agent ran in Architecture-only mode; PR-body assert skipped (no target repo to inspect)."
            exit 0
          fi

          # The agent runs in target-repo/ (set by the Checkout target repo step).
          # Find any PR opened from the current branch on the target repo.
          cd target-repo

          BRANCH=$(git branch --show-current || true)
          if [[ -z "${BRANCH}" || "${BRANCH}" == "main" ]]; then
            echo "::notice::Agent did not open a feature branch (current=${BRANCH:-detached}); no PR to assert."
            exit 0
          fi

          # Find the PR opened from this branch in the target repo.
          PR_NUMBER=$(gh pr list --repo "${CHECKOUT_TARGET}" --head "${BRANCH}" --state open --json number --jq '.[0].number // empty')
          if [[ -z "${PR_NUMBER}" ]]; then
            echo "::notice::Agent did not open a PR on branch '${BRANCH}' in ${CHECKOUT_TARGET}; nothing to assert."
            exit 0
          fi

          # Read current PR body. If the exact link line is already present, no-op.
          BODY=$(gh pr view "${PR_NUMBER}" --repo "${CHECKOUT_TARGET}" --json body --jq '.body // ""')
          EXPECTED_LINE="> Packet: ${PACKET_LINK}"

          if printf '%s\n' "${BODY}" | grep -Fxq "${EXPECTED_LINE}"; then
            echo "PR #${PR_NUMBER} already contains the packet link line; no edit needed."
            exit 0
          fi

          # Otherwise, prepend the packet-link block to the PR body.
          NEW_BODY=$(printf '%s\n\n---\n\n%s\n' "${EXPECTED_LINE}" "${BODY}")
          echo "Asserting packet link on PR #${PR_NUMBER} in ${CHECKOUT_TARGET}."
          gh pr edit "${PR_NUMBER}" --repo "${CHECKOUT_TARGET}" --body "${NEW_BODY}"
```

Notes on the assert step:

- **Idempotent.** If the agent's PR body already contains the exact `> Packet: <permalink>` line (because the prompt-side injection worked), the step exits with no edit. If the line is missing, the step prepends a packet-link block and an `---` separator, preserving the agent's original body underneath.
- **Soft on edge cases.** No PR found, detached HEAD, no `checkout-target`, or main-branch run all produce a `::notice::` and exit 0 — the workflow does not fail on these states. They represent legitimate non-PR-opening agent runs (governance syncs, summarisations, etc.).
- **Permission requirements.** The step uses `gh pr edit` against `inputs.checkout-target`. The token in `secrets.github-token` must have `pull-requests: write` on the target repo. The `agent-run.yml` workflow already declares `permissions: pull-requests: write` and consumers already pass a token with this scope, so no new permission is required.
- **Branch detection.** `git branch --show-current` returns the agent's working branch (the branch it pushed to before opening the PR). If the agent did not push or did not open a PR, the `gh pr list --head` call returns empty and the step no-ops.
- **The line format must match exactly.** `> Packet: <permalink>` (greater-than sign, space, `Packet:`, space, full URL). The grep is `-Fxq` (literal whole-line match) — no fuzzy matching. If the agent inserts a different format (`Packet: <link>` without the quote, or `**Packet:** <link>`, etc.), the step inserts the canonical form alongside the agent's variant. The review agent's parser keys on the canonical form, so both forms coexisting is harmless.

### F. No change to other callers

Do **not** edit any caller of `agent-run.yml` in this packet. The `packet-path` input is optional with an empty default, so existing callers continue to work unchanged. Callers that pass a packet (the file-packets driver, future packet-execution workflows) opt in by supplying the input.

## Affected Files
- `.github/workflows/agent-run.yml` (edit — add input, resolve-packet step, prompt-envelope amendment, post-hoc assert step, header example)
- `CHANGELOG.md` (root): append entry under in-progress version
- `README.md` (root): no change expected; this is a new optional input + post-hoc step on an existing workflow, not a new workflow

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Routing rule "workflow, CI, GitHub Actions, pipeline, PR check, release → HoneyDrunk.Actions" applies.
- [x] No code changes in other repos. The Architecture-side convention ("PR bodies must link to packets") is documented; this packet enforces it on the cloud side without requiring any other repo to change.
- [x] No new cross-Node dependency. `agent-run.yml` continues to be the single agent-execution entrypoint; this packet only adds an optional input.

## Acceptance Criteria
- [ ] `.github/workflows/agent-run.yml` declares a new optional input `packet-path` with description and default `''`
- [ ] A new "Resolve packet link" step exists that computes the permalink (`https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/<architecture-ref>/<packet-path>`) only when `packet-path` is non-empty
- [ ] The "Resolve packet link" step warns (does not fail) when `packet-path` is supplied but the file is missing at the resolved ref
- [ ] The existing "Resolve prompt" step is amended to append a structured packet instruction (the `> Packet: …` quoted line + an `out-of-band` fallback hint) only when `packet-path` is non-empty
- [ ] The amended prompt envelope produces the exact line `> Packet: <permalink>` as a quoted markdown block — the review agent's packet-resolution logic depends on this format
- [ ] **A new "Assert PR-body packet link" step exists**, gated `if: ${{ inputs.packet-path != '' }}`, that runs after the agent run steps. It locates the PR the agent opened on the current branch in `inputs.checkout-target` and asserts the `> Packet: <permalink>` line into the PR body via `gh pr edit`. The step is the mechanical guarantor of invariant 32 — the workflow, not the LLM, is the source of the line.
- [ ] The assert step is **idempotent**: if the PR body already contains the exact line, no edit is performed.
- [ ] The assert step is **soft on edge cases**: missing PR, no checkout-target, detached HEAD, or main-branch run all produce a `::notice::` and exit 0 (no failure).
- [ ] The assert step uses `gh pr edit --body` to prepend the canonical link block; the agent's original body is preserved below an `---` separator.
- [ ] When `packet-path` is empty, the workflow behaves identically to today (existing callers keep working — both the resolve and assert steps no-op).
- [ ] When `packet-path` is supplied but invalid (file missing at ref), the resolve step logs `::warning::` and continues; the assert step still runs against whatever permalink was constructed.
- [ ] Header comment block contains a new usage example that demonstrates `packet-path` and notes the post-hoc assert behaviour.
- [ ] Permissions block is unchanged — `agent-run.yml` already declares `permissions: pull-requests: write`, which the assert step's `gh pr edit` requires; no broader permission needed.
- [ ] Repo-level `CHANGELOG.md`: append a new line under the in-progress version's `Changed` (or `Added`) section describing the new input AND the post-hoc assert step. If packet 02 has already opened a new in-progress version entry on the same wave, append to that entry instead of opening a second one (invariants 12 and 27 — partial bumps forbidden, alignment-only entries forbidden)
- [ ] No per-package `CHANGELOG.md` updates (this is a workflow change, not a package change)
- [ ] `actions-ci.yml` (or whatever lints `.github/workflows/`) passes

## Human Prerequisites
None. This packet is a workflow edit in `HoneyDrunk.Actions`. No portal action, no secret seeding.

The first caller that actually exercises the new input is the next packet that ships the file-packets / packet-execution driver — not in this initiative. Until then, the input remains optional and unused, which is the correct pre-rollout state.

## Dependencies
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft dependency: invariant 32 is the rationale referenced in the PR-body instruction text. Sequence packet 01 first.

## Downstream Unblocks
- Future packet-execution workflows (not in this initiative) that drive `agent-run.yml` from a packet pointer can satisfy invariant 32 mechanically — the workflow asserts the line, not the LLM.
- The review agent (local-only per ADR-0011 D10) gains a stable packet-link convention to parse — quoted markdown block starting with `Packet: `.
- Future hardening (e.g. signed packet-link assertions, automatic `out-of-band` label application when `packet-path` is empty) can layer onto the same step structure without re-architecting.

## Referenced ADR Decisions

**ADR-0011 (Code Review and Merge Flow):**
- **D3 (artifact contracts):** "Input 'packet file (via issue link)' is non-negotiable for the review agent." The PR body must link to the packet file; the review agent resolves the link, reads the packet, and uses it as the primary scope anchor. PRs whose body does not link to a packet are out-of-band per D9.
- **D9 (out-of-band PRs):** A PR that does not link to a packet is out-of-band. Out-of-band PRs still traverse the full pipeline; the review agent's packet-loading step is skipped. They must carry the `out-of-band` label.
- **D10 (review agent local-only):** The review agent runs locally via Claude Code, not as a cloud workflow. The packet link the review agent reads is the same link this workflow injects — local execution and cloud injection meet at the PR body.

**ADR-0008 (Work Tracking and Execution Flow):**
- **D8 (cloud agent execution):** The cloud agent execution workflow checks out both the target repo and `HoneyDrunk.Architecture`. This packet does not change that — `agent-run.yml` already does it. What this packet adds is structured packet metadata in the agent's prompt envelope so the resulting PR carries the link forward.

## Referenced Invariants

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR is treated as out-of-band, must carry the `out-of-band` label, and receives a degraded review in which the agent runs against the Grid context only (invariants, boundaries, relationships, diff) without a packet-scope check.

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. *(The link this workflow injects is to the packet file at the agent's checkout ref — stable for the duration of that execution. Post-merge, the file may be archived per ADR-0008 D10; the permalink continues to resolve via Git history.)*

## Constraints
- **Optional input, default empty.** All existing callers must keep working unchanged. Do not add a `required: true` flag.
- **Warn, do not fail, on a missing packet file.** Failing would prevent legitimate out-of-band agent runs.
- **Use `${{ inputs.architecture-ref }}` for the permalink branch.** Hardcoding `main` would silently break runs that pin to a tag or a specific SHA.
- **Preserve the existing "Resolve prompt" step branching between `agent` and `prompt` modes.** The packet instruction is appended after the base envelope, regardless of which mode produced the base.
- **The injected line format is a quoted markdown block: `> Packet: <permalink>`.** The review agent parses this exact shape. Plain text or different bullet style breaks the contract. Both the prompt-side instruction and the post-hoc assert step must produce the same canonical form.
- **The post-hoc assert step is the mechanical guarantor.** The prompt-side instruction is best-effort soft enforcement and may be ignored by the model; the assert step ensures invariant 32 holds regardless. Do not delete the assert step in a future "simplification" — it carries the load.
- **The assert step is idempotent and soft on edge cases.** Missing PR, no checkout-target, detached HEAD, main-branch run → `::notice::` and exit 0. Existing PR with the line already → no-op. Existing PR without the line → prepend canonical block.
- **`gh` and `jq` are preinstalled on `ubuntu-latest`.** The assert step relies on this; do not introduce additional installation steps.
- **Do not change the workflow's `permissions:` block.** `pull-requests: write` is already declared and is sufficient for `gh pr edit`. Adding write permissions for unrelated reasons is out of scope.
- **No secrets read added.** This packet adds no new secret consumption — the assert step uses `secrets.github-token` which is already declared.

## Labels
`feature`, `tier-2`, `ci-cd`, `ops`, `adr-0011`, `wave-1`

## Agent Handoff

**Objective:** Add a `packet-path` input to `agent-run.yml` plus two complementary mechanisms: (1) a prompt-envelope injection that instructs the agent to include the `> Packet: <permalink>` line in the PR body, and (2) a post-hoc "Assert PR-body packet link" step that mechanically asserts the line into the PR body via `gh pr edit` after the agent finishes. The assert step is the load-bearing guarantor of invariant 32 — the workflow is the source of the line, not the LLM. Optional input (default empty); no failure on missing file or missing PR (notice/warn and continue); no permission changes; no caller changes.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make invariant 32 ("agent-authored PRs must link to their packet") mechanical rather than a per-prompt convention.
- Feature: ADR-0011 Code Review Pipeline rollout.
- ADRs: ADR-0011 (D3 packet-as-scope-anchor, D9 out-of-band degradation, D10 local review agent reads same link), ADR-0008 (D8 cloud execution workflow context).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft dependency on invariant-32 going live.

**Constraints:**
- Optional input, default empty. Existing callers unaffected.
- Warn (do not fail) on missing packet file. Notice (do not fail) when there is no PR to edit.
- Use `${{ inputs.architecture-ref }}` to construct the permalink branch.
- Preserve agent vs prompt branching in the existing "Resolve prompt" step.
- The injected line must be exactly `> Packet: <permalink>` as a quoted markdown block — review agent parses this format. Both prompt-side and post-hoc-assert paths emit the same canonical form.
- The post-hoc assert step is the mechanical guarantor of invariant 32; do not remove it in favour of "the prompt is enough" — the prompt is best-effort and the LLM can ignore it.
- The assert step is idempotent — running twice on the same PR leaves it unchanged.
- No new permissions (`pull-requests: write` already declared), no new secrets (`secrets.github-token` already declared).
- `gh` and `jq` are preinstalled on `ubuntu-latest` — do not add install steps.

**Key Files:**
- `.github/workflows/agent-run.yml` (the only workflow file edited)
- `CHANGELOG.md` (root)

**Contracts:**
- New convention: PR bodies opened by `agent-run.yml` runs that supply `packet-path` will contain `> Packet: <permalink>`. The review agent's packet-resolution logic in `.claude/agents/review.md` consumes this format. Do not change the format casually — it is the cloud-side half of an unwritten contract with the local-side review agent.
