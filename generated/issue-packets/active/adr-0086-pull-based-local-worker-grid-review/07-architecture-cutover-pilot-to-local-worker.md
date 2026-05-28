---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["ci", "tier-2", "meta", "adr-0086", "wave-1"]
dependencies: ["packet:02", "packet:03", "packet:04", "packet:05", "packet:06"]
adrs: ["ADR-0086", "ADR-0044"]
accepts: []
wave: 1
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Cut HoneyDrunk.Architecture over to runner: local-worker (Phase A pilot)

## Summary
Flip the `HoneyDrunk.Architecture` repo's `.honeydrunk-review.yaml` from `runner: openclaw-codex` to `runner: local-worker`, update the repo's `pr-review.yml` caller to drop the now-removed `openclaw-webhook-url` / `openclaw-webhook-secret` inputs and to declare the widened `permissions:` block packet 05's rewritten `job-review-request.yml` requires. Verify Phase-A end-to-end: a real PR receives `needs-agent-review` from the rewritten Action; the local worker (packet 03) claims it via label swap; the worker posts an advisory verdict; the label state lands on `agent-reviewed` or `changes-requested-by-agent`. Record the Phase-A go/no-go in the cutover PR body — this gates Phase B.

## Target Workflow
**File:** `.honeydrunk-review.yaml` (repo root, in-place edit) and `.github/workflows/pr-review.yml` (in-place edit)
**Family:** manual / pr-core caller

## Motivation
ADR-0086 D11 Phase A pilots the pull-based local worker on `HoneyDrunk.Architecture` only — the same lowest-blast-radius repo ADR-0044 D11 Phase 1 used. The exit criterion (D11 Phase A): "verdict quality at least as useful as the manual local-agent invocation, reliable triggers (now meaning 'reliable polling and claim semantics' instead of 'reliable webhook delivery'), and near-zero marginal cost under subscription auth." If that bar is missed, Phase B does not start.

This packet is the cutover. It is the smallest possible change that proves the new transport end-to-end on a real repo.

## Proposed Change

### `.honeydrunk-review.yaml` at the Architecture repo root
Existing content (per ADR-0044 packet 06b):
```yaml
enabled: true
severity_floor: Suggest
skip_paths:
  - "**/generated/**"
  - "**/*.g.cs"
runner: openclaw-codex
cost_cap_per_pr_usd: 5.00
```

After this packet:
```yaml
enabled: true
severity_floor: Suggest
skip_paths:
  - "**/generated/**"
  - "**/*.g.cs"
runner: local-worker
```

Changes:
- `runner: openclaw-codex` → `runner: local-worker` (per ADR-0086 D5).
- `cost_cap_per_pr_usd` removed (it is ignored when `runner: local-worker` per packet 04's schema doc; marginal LLM cost is $0 under subscription auth per ADR-0086 D6).

### `.github/workflows/pr-review.yml` caller
The current caller (per ADR-0044 packet 06b) passes the now-removed `openclaw-webhook-url` input and the `openclaw-webhook-secret` secret to `job-review-request.yml`. Both are dropped. The caller's `permissions:` block must widen to a superset of the rewritten reusable workflow's permissions per invariant 39:

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

The caller's `on:` triggers (`pull_request` types `opened`, `synchronize`, `ready_for_review`) and the `workflow_call` invocation of `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-review-request.yml@<pinned-ref>` are unchanged. The pinned ref bumps to whatever tag/SHA packet 05 lands at — the implementing agent confirms the ref before pushing.

### Phase-A verification (gates Phase B; record in PR body)
After the cutover PR is open and the workflow has run on it, the implementing agent records the following evidence in the PR body before merge — this IS the Phase-A go/no-go gate:

1. **Trigger reliability.** The cutover PR itself fired `job-review-request.yml`; `needs-agent-review` is on the PR; the queue comment is upserted with the correct `head_sha`.
2. **Worker claim.** The local worker's next tick after the queue comment appeared claimed the PR (label swapped from `needs-agent-review` to `agent-review-in-progress`, queue comment edited to record `claimed_by` / `claimed_at` / `head_sha`).
3. **Worker verdict.** The worker completed the review and posted a verdict comment in the `.claude/agents/review.md` format. The label state transitioned to `agent-reviewed` (clean) or `changes-requested-by-agent` (findings).
4. **Head-SHA invalidation handles a push.** Push a no-op commit to the cutover PR (e.g., a CHANGELOG line). Observe: the queue-comment `head_sha` is updated; if the worker was mid-review when the push landed, the stale verdict is discarded and the next tick reviews the new SHA. Record the observed behavior.
5. **Quality vs the local agent.** Run `.claude/agents/review.md` locally on the same PR diff (the manual invocation path). Compare the verdicts. Phase-A exit requires "at least as useful as the manual local-agent invocation" per D11.
6. **Cost.** Confirm marginal LLM cost is $0 (subscription-backed; no `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` set in the worker environment per D4).
7. **Stale-claim sweep.** Either induce a stale claim (manually swap labels and skip the verdict) and observe the next tick recover, or document the stale-claim path was exercised in packet 03's smoke test (`scripts/Test-JobLocally.ps1 -JobId grid-review`).

If any of these fail, **stop** — do not merge the cutover PR. Diagnose against packet 03 (worker), packet 05 (workflow), or packet 02 (App provisioning); revert the cutover PR if necessary. Phase B does not start until the Phase-A bar is met.

### What this packet does NOT do
- Does **not** add `runner: local-worker` to any other repo. Phase B fan-out is packet 09.
- Does **not** decommission the OpenClaw webhook bridge, rotate the webhook-signing secret, or remove the Cloudflare Tunnel hostname. Packet 08 owns that at Phase A → Phase B cutover.
- Does **not** edit `.claude/agents/review.md`. ADR-0086 D1 is explicit.

## Consumer Impact
- Only `HoneyDrunk.Architecture` is affected. No other repo gets the local worker in Phase A.
- Every non-draft, non-`skip-review` PR on `HoneyDrunk.Architecture` now receives an advisory review from the local worker.

## Breaking Change?
- [ ] Yes
- [x] No — same advisory posture; same `.claude/agents/review.md`; only the transport and execution substrate change. The cutover is a single-PR config change.

## Acceptance Criteria
- [ ] `.honeydrunk-review.yaml` at the Architecture repo root carries `runner: local-worker` (and no `cost_cap_per_pr_usd` line)
- [ ] `.github/workflows/pr-review.yml` no longer passes `openclaw-webhook-url` or `openclaw-webhook-secret` to `job-review-request.yml`
- [ ] The caller's `permissions:` block is `contents: read`, `pull-requests: write`, `issues: write`
- [ ] The caller invokes `job-review-request.yml` at the pinned ref where packet 05 landed
- [ ] On the cutover PR itself, the rewritten Action added `needs-agent-review` and upserted the queue comment with the correct `head_sha`
- [ ] The local worker claimed the PR (label swap + queue-comment edit) within the configured cadence
- [ ] The worker posted an advisory verdict comment; the label state transitioned to `agent-reviewed` or `changes-requested-by-agent`
- [ ] A head-SHA invalidation scenario was exercised on the cutover PR (push a no-op commit; observe the queue-comment `head_sha` updates; observe the stale verdict is discarded if mid-review)
- [ ] Verdict quality is at least as useful as the manual local-agent invocation on the same diff (comparison recorded in the PR body)
- [ ] Marginal LLM cost confirmed $0 (subscription-backed CLIs; no `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` set in the worker environment)
- [ ] The Phase-A go/no-go decision is recorded in the PR body — explicit go or stop
- [ ] CHANGELOG.md updated noting the Architecture-repo cutover to `runner: local-worker`

## Human Prerequisites
- [ ] All Wave-1 packets 02–06 must be complete: existing review-agent GitHub App audited and Vault credentials verified (02), runner source landed + installed on the home server + review Task Scheduler entry registered (03), schema doc updated (04), `job-review-request.yml` rewritten (05), worker labels and managed PR labels fanned out (06)
- [ ] The local worker on the home server must be running (Task Scheduler entry from packet 03 active)
- [ ] Confirm the pinned `job-review-request.yml` ref the Architecture caller invokes — this is the tag/SHA after packet 05 merged
- [ ] After the cutover PR opens, manually observe the end-to-end flow (queue comment appears → worker claims → verdict posts → labels transition) before recording the Phase-A go decision
- [ ] If the Phase-A bar is not met, halt the rollout — do not file packet 09 (Phase-B fan-out) or packet 08 (decommission)

## Dependencies
- `packet:02` — existing review-agent GitHub App audit + Vault credential verification (**hard** — the worker can't authenticate to GitHub without these).
- `packet:03` — Worker source + Task Scheduler installation (**hard** — there's no runtime to handle the claim without the worker).
- `packet:04` — Schema doc updated (soft — the `.honeydrunk-review.yaml` edit aligns with the schema; the workflow doesn't strictly require the doc but the operator does).
- `packet:05` — `job-review-request.yml` rewritten to label+comment form (**hard** — the caller's input shape change depends on the reusable workflow's input shape change).
- `packet:06` — Worker labels and managed PR labels fanned out (**hard** for stable behavior — packet 05's `gh label create --force` safety net works on first use but the pre-seed is the canonical path; the worker's label-swap depends on `agent-review-in-progress` existing on the repo when the worker tries to add it).

## Referenced ADR Decisions

**ADR-0086 D5** — `.honeydrunk-review.yaml` `runner:` enum: `local-worker` (default), `api-ci` (preserved), `openclaw-codex` (removed). `cost_cap_per_pr_usd` is ignored under `local-worker` because marginal LLM cost is $0 (D6).

**ADR-0086 D11 Phase A** — Pilot on `HoneyDrunk.Architecture` only. Verify the four labels function, the claim protocol behaves under deliberate worker-restart and stale-claim scenarios, verdict quality matches the OpenClaw-hosted runner's, and marginal cost stays at $0. Exit criterion is the same as ADR-0044 D11 Phase 1's: verdict quality at least as useful as the manual local-agent invocation, reliable triggers (now meaning "reliable polling and claim semantics" instead of "reliable webhook delivery"), and near-zero marginal cost under subscription auth.

**ADR-0086 D6** — Marginal LLM cost stays $0/PR by default under `runner: local-worker`. `api-ci` remains the only path that incurs per-token billing.

**ADR-0086 D7** — Worker availability is advisory. If the worker is offline — operator traveling, home server down, scheduled-task disabled, deliberate maintenance — PRs accumulate in the `needs-agent-review` state and remain mergeable.

**ADR-0044 D11 Phase 1 (reset to ADR-0086 Phase A)** — Lowest-blast-radius pilot. Architecture-repo PRs are predominantly docs and catalogs; a regression on this repo is recoverable cleanly via `git revert`.

**Invariant 39 (ADR-0012 D5)** — Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's. The widened `permissions:` block on the Architecture caller is non-negotiable; omitting it makes the rewritten Action fail on the first label/comment write.

## Constraints
> **Invariant 31:** Every PR traverses the tier-1 gate before merge. The pull-based reviewer is tier-3 and advisory — it does not become a required check and does not alter the tier-1 gate.

> **Invariant 39:** Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions. The widened block on `pr-review.yml` is required.

- **Phase A is reviewer-only on one repo.** Do not enable the local worker on any other repo in this packet; do not edit any other repo's `.honeydrunk-review.yaml`.
- **Advisory check.** Never make the review check required.
- **Phase-A go/no-go gates Phase B.** If the cutover PR's verification fails on any of the seven evidence items, do not file packet 09 (fan-out) or packet 08 (decommission) until the failure is diagnosed and fixed.
- **Do not decommission OpenClaw in this packet.** Packet 08 handles the cutover; the OpenClaw webhook bridge is left running until Phase A is green and packet 08 ships. The Cloudflare Tunnel hostname stays up until packet 08.

## Labels
`ci`, `tier-2`, `meta`, `adr-0086`, `wave-1`

## Agent Handoff

**Objective:** Cut `HoneyDrunk.Architecture` over to `runner: local-worker`. Update the `pr-review.yml` caller to drop the webhook inputs and widen the `permissions:` block. Verify Phase-A end-to-end on the cutover PR itself and record the go/no-go decision in the PR body.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Prove the pull-based local-worker substrate end-to-end on the lowest-blast-radius repo before Phase B starts.
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase A pilot.
- ADRs: ADR-0086 (primary, D5/D6/D7/D11), ADR-0012 D5 / invariant 39 (caller permissions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` (hard), `packet:03` (hard), `packet:05` (hard), `packet:06` (hard); `packet:04` (soft).

**Constraints:**
- Phase A is reviewer-only on one repo; no other `.honeydrunk-review.yaml` is edited.
- Advisory check; never required.
- Phase-A go/no-go gates Phase B.
- Do not decommission OpenClaw here; packet 08 owns that.

**Key Files:**
- `.honeydrunk-review.yaml`
- `.github/workflows/pr-review.yml`
- `CHANGELOG.md`

**Contracts:** Consumes `job-review-request.yml@<pinned-ref>` (via `workflow_call`) and the `.honeydrunk-review.yaml` v1 schema (per packet 04).
