---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0086", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0086", "ADR-0044", "ADR-0012"]
accepts: []
wave: 1
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-actions
---

# Rewrite job-review-request.yml as managed-label normalization plus enqueue

## Summary
Rewrite the reusable workflow `HoneyDrunk.Actions/.github/workflows/job-review-request.yml` from its current webhook-emitting form (signed HMAC POST to an OpenClaw endpoint, plus artifact/comment fallback) to the managed-label-normalizing and label-and-comment-emitting form ADR-0086 D2 specifies: apply deterministic Grid-owned PR labels, add `needs-agent-review` to the PR (always, on every triggering event), and upsert a single structured queue comment carrying the review-request payload with `head_sha` edited in place on every `synchronize`. The webhook delivery step, signature generation step, signing-secret input, and Cloudflare/OpenClaw URL input are removed. The cheap Action consumes no LLM tokens — its job is exclusively to normalize PR metadata and enqueue.

## Target Workflow
**File:** `.github/workflows/job-review-request.yml` (in-place rewrite)
**Family:** pr-core caller (consumer repos invoke this from their `pr.yml` per ADR-0012's reusable-workflow model)

## Motivation
ADR-0086 D1 commits the pull-based local worker as the canonical Grid Review Runner transport: the cheap GitHub Action normalizes managed PR labels, enqueues a review request by labelling and commenting on the PR, and then exits; a local worker on the home server polls GitHub and runs the agent under subscription-backed CLIs. The inbound webhook is removed. The Cloudflare Tunnel for review traffic is removed. OpenClaw is removed from the review path entirely.

The label normalization step is included here because it is the same GitHub Actions metadata surface as the queue label. It closes the "some PRs get good tags and some do not" gap by making the Actions rail responsible for deterministic labels derived from packet metadata, ADR references, title/body, and changed files.

The current `job-review-request.yml` (the workflow that landed via Actions PR #99 / ADR-0044 packet 03b) carries the inverse architecture: it signs a payload with an HMAC secret and POSTs to an OpenClaw webhook URL, falling back to a durable artifact + machine-readable comment when delivery fails. Every line of that webhook plumbing — the `openclaw-webhook-url` input, the `openclaw-webhook-secret` secret, the "Deliver signed webhook request" step, the HMAC generation Python block, and the curl POST — is removed by this packet and replaced with the label+comment form.

This is the load-bearing CI change of Phase A. Packet 07 (the Phase-A cutover on Architecture) consumes this rewritten workflow.

## Proposed Change

### Inputs and secrets
**Remove:**
- `openclaw-webhook-url` (input)
- `openclaw-webhook-secret` (secret)
- The `upload-fallback-artifact` and `post-fallback-comment` inputs (the artifact/comment fallback is no longer needed — the label + queue comment ARE the queue, not a fallback). The `artifact-name` input also goes.

**Keep:**
- `runs-on` (input, default `ubuntu-latest`).
- `review-config-path` (input, default `.honeydrunk-review.yaml`).
- `github-token` (secret) — still required for PR-metadata reads, label edits, and the queue-comment upsert. Consumer repos must pass `${{ secrets.GITHUB_TOKEN }}` (or a more-scoped token if desired); the workflow's `permissions:` block widens to include `pull-requests: write` and `issues: write` (label and comment writes).

### Permissions block
```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

(Previously `pull-requests: read`. The PR-level write permission is what the label-add and comment-upsert API calls require.)

### Step sequence
1. **Validate pull request context** — unchanged. Skip on missing `pull_request` context, skip on draft PR.
2. **Checkout repository** — unchanged. Needed to read `.honeydrunk-review.yaml`.
3. **Evaluate skip rules and config** — unchanged. Skip on `skip-review` label, missing config, or `enabled: false`.
4. **Build queue payload** (renamed from "Build review request payload") — same JSON payload shape as today (repo, PR number, head SHA, author class per ADR-0044 D6 `Authorship:` extraction, changed-file summary, packet link extraction, resolved `.honeydrunk-review.yaml` settings, `runner` from the config — values now constrained to `local-worker` / `api-ci` per ADR-0086 D5 packet 04). The payload is the body of the queue comment, not a wire format anymore.
5. **NEW — Resolve managed PR labels** — derive Grid-owned labels from the PR title/body, linked packet body/frontmatter when available, ADR references, changed-file paths, authorship, and current config. Managed labels include `adr-*`, `tier-*`, `wave-*`, initiative labels, `meta`, `docs`, `ci`, `bug`, `enhancement`, `dependencies`, `chore`, `security`, `breaking-change`, `refactor`, `test`, `infra`, `automation`, `human-only`, `blocked`, `superseded`, `new-node`, `catalog`, `contracts`, `scaffolding`, and review-state labels. The resolver must preserve human labels outside the managed set.
6. **NEW — Ensure managed labels exist on the repo** — idempotent create/update from labels-as-code (`.github/config/labels.json`) before application. This centralizes the label vocabulary instead of relying on every caller to pre-seed perfectly.
7. **NEW — Apply managed labels to the PR** — add missing managed labels and remove stale labels only within the explicit managed set. Do not remove arbitrary human labels. This runs before enqueue so the worker and humans see normalized metadata immediately.
8. **NEW — Ensure `needs-agent-review` label exists on the repo** — idempotent create via `gh label create --force` or the equivalent GitHub API call. ADR-0086 D2 step 1: "creating the label on first use per the existing label-setup pattern." This is a safety net; the Grid-wide fan-out (packet 06) seeds the label on every enabled repo proactively, but a caller repo invoking this workflow before the fan-out lands still gets the label created on first run.
9. **NEW — Add `needs-agent-review` label to the PR** — always, on every triggering event, including `synchronize` events where `agent-review-in-progress` may already be present. Per ADR-0086 D2 step 1: "The Action always adds this label on every triggering event — including `synchronize` events fired while the PR is currently `agent-review-in-progress`. The label is therefore both the queue index and the invalidation signal for in-flight claims; see D3 step 5."
10. **NEW — Upsert the structured queue comment** — search the PR's existing comments for a previous queue comment by an opaque marker the workflow embeds (e.g. `<!-- honeydrunk-grid-review-queue:v1 -->`). If found, edit it in place; otherwise create a new comment. The comment body carries the queue payload as a fenced JSON block plus a human-readable summary. The `head_sha` field is the canonical "what SHA needs review" at any moment — ADR-0086 D2 step 2: "edits the comment's `head_sha` field in place on every triggering event — the comment is upserted, not duplicated. This makes the comment the canonical source of 'what SHA needs review' at any moment, which D3 step 5's head-SHA invalidation check relies on."
11. **REMOVE — Deliver signed webhook request** (the HMAC + curl POST step).
12. **REMOVE — Record webhook not configured.**
13. **REMOVE — Upload fallback review request artifact** (the artifact fallback is dropped; the queue comment is the audit trail).
14. **REMOVE — Post machine-readable fallback comment** (replaced by the queue comment upsert).
15. **Summarize skipped request** — unchanged in shape; record the skip reason in `$GITHUB_STEP_SUMMARY`.
16. **Summarize queued request** — adapt: instead of webhook delivery status, record "labels normalized; queued via label + comment upsert", the idempotency key (`owner/repo#pr@headSha`), and the comment URL (or the PR URL anchored to the comment).

### Queue comment shape
Use an opaque HTML-comment marker so the upsert step can find the prior comment idempotently:

```markdown
<!-- honeydrunk-grid-review-queue:v1
idempotencyKey: <owner>/<repo>#<pr>@<head_sha>
head_sha: <head_sha>
schemaVersion: 1
-->

🔎 **Queued for Grid Review Runner**

This PR is in the local-worker review queue. The home-server worker will pick it up on its next tick (typical cadence: 60–120 s during operator working hours). When the review completes, the worker will post a separate verdict comment and swap the `needs-agent-review` / `agent-review-in-progress` labels to `agent-reviewed` or `changes-requested-by-agent`.

<details>
<summary>Queue payload (machine-readable)</summary>

```json
{
  "schemaVersion": 1,
  "event": "grid-review-request",
  "idempotencyKey": "...",
  "repo": { ... },
  "pullRequest": { "number": ..., "headSha": "...", ... },
  "authorship": { "class": "...", "source": "..." },
  "changeSummary": { ... },
  "context": { "workItemUrl": "...", "adrs": [...] },
  "config": { "enabled": true, "runner": "local-worker" }
}
```
</details>
```

The fields preserved from the current payload (Authorship line extraction, packet URL/path detection, ADR matching, change summary, runner read from config) carry forward. The `callback.mode` and webhook-related fields are dropped.

The worker (packet 03) parses the JSON block to consume the queue, then edits the comment to add `claimed_by` / `claimed_at` / `head_sha` per ADR-0086 D3 step 3 — that mutation is the worker's, not this workflow's. This workflow only ever inserts or updates the `head_sha` and the queue payload.

### Idempotency
The label-add is idempotent (adding `needs-agent-review` when it's already present is a no-op). The comment upsert is idempotent (it finds and edits the prior comment by marker, or creates if absent). The labels carry the queue protocol state per ADR-0086 D3; the comment carries the audit trail. The same `owner/repo#pr@headSha` idempotency key from ADR-0044 D1 is preserved.

### Documentation and consumer impact
- `docs/CHANGELOG.md` — entry noting the breaking-change behavior of `job-review-request.yml` (inputs and secrets removed; permissions block widened).
- `docs/consumer-usage.md` — caller snippet updated: drop `openclaw-webhook-url` / `openclaw-webhook-secret` from the example; show the widened `permissions:` block the caller must declare (per invariant 39, callers' permissions block must be a superset of the reusable workflow's); document the managed-label set and "does not remove human labels" rule.
- `README.md` — update the `job-review-request.yml` row to describe the new managed-label-normalization + label/comment form.

### What this packet does NOT do
- Does **not** add the managed label vocabulary to the labels-as-code fan-out — packet 06 owns worker labels plus the central metadata labels this workflow can apply.
- Does **not** decommission the Cloudflare Tunnel hostname or rotate the OpenClaw webhook-signing secret in Vault — packet 08 owns that at Phase A → Phase B cutover.
- Does **not** edit any consumer repo's `pr-review.yml` caller — Architecture's caller flip happens in packet 07; the Phase-B fan-out callers happen in packet 09.

## Consumer Impact
- **Existing consumers (today: only `HoneyDrunk.Architecture`'s `pr-review.yml`)** must stop passing the `openclaw-webhook-url` input and `openclaw-webhook-secret` secret to this workflow. The Architecture caller is updated in packet 07 (Phase-A cutover); no other repo consumes this workflow today.
- **The `permissions:` block on the caller must widen** to include `pull-requests: write` and `issues: write` (per invariant 39). Packet 07 makes this change on Architecture; packet 09 fans it out.

## Breaking Change?
- [x] Yes — inputs/secrets removed; permissions widened. Existing callers must update.
- [ ] No

## Acceptance Criteria
- [ ] `.github/workflows/job-review-request.yml` no longer accepts the `openclaw-webhook-url` input or the `openclaw-webhook-secret` secret
- [ ] The workflow's `permissions:` block is `contents: read`, `pull-requests: write`, `issues: write`
- [ ] On every triggering `pull_request` event (`opened`, `synchronize`, `ready_for_review`; not `draft`), and when the skip rules pass, the workflow adds `needs-agent-review` to the PR — including when `agent-review-in-progress` is already present
- [ ] Before enqueue, the workflow resolves managed PR labels from PR title/body, linked packet frontmatter/body, ADR references, changed files, authorship, and config
- [ ] The workflow creates or updates missing managed labels from labels-as-code before applying them
- [ ] The workflow adds missing managed labels and removes stale labels only inside the explicit managed set; arbitrary human labels outside that set are preserved
- [ ] The workflow ensures `needs-agent-review` exists on the repo's label set (idempotent create); the same is not required for `agent-review-in-progress` / `agent-reviewed` / `changes-requested-by-agent` because those are added by the worker post-claim
- [ ] The workflow upserts a single queue comment per PR carrying the queue payload (JSON) plus a human-readable summary. The opaque HTML-comment marker `<!-- honeydrunk-grid-review-queue:v1 ... -->` makes the upsert idempotent.
- [ ] The queue comment's `head_sha` is edited in place on every `synchronize` event — the comment is the canonical source of "what SHA needs review."
- [ ] No HMAC signing step, no `curl` POST, no webhook-delivery branch remains in the workflow
- [ ] No artifact upload step remains (the queue comment is the audit trail)
- [ ] `docs/CHANGELOG.md` entry recorded the breaking-input change
- [ ] `docs/consumer-usage.md` updated: drops the webhook inputs from the example, shows the widened `permissions:` block, documents that the consumer must call this workflow on `pull_request` `opened`/`synchronize`/`ready_for_review` (skip on draft), and documents the managed-label set
- [ ] `README.md` updated to describe the new managed-label-normalization + label/comment form of `job-review-request.yml`
- [ ] The workflow's skip-rule semantics are unchanged: `skip-review` label, missing `.honeydrunk-review.yaml`, `enabled: false`, draft PR — all four still cause a clean skip (no label added, no comment posted)

## Human Prerequisites
- [ ] Confirm the four new worker labels are seeded across the Grid via packet 06 (or at least on `HoneyDrunk.Architecture` for Phase A) before packet 07's cutover lands — the workflow's `gh label create --force` for `needs-agent-review` is a safety net, but pre-seeding via the labels-as-code fan-out is the canonical path.
- [ ] After this packet lands, the existing Architecture caller (`pr-review.yml`) must be updated by packet 07 to drop the webhook inputs and widen its `permissions:` block.

## Dependencies
- `work-item:01` — ADR-0086 acceptance (soft; references ADR-0086 D2/D3 as live rules).

## Referenced ADR Decisions

**ADR-0086 D1** — Pull-based local worker is the canonical Grid Review Runner transport. The cheap GitHub Action emits label + comment; the local worker on the home server polls and executes. The Action consumes no LLM tokens. No inbound webhook, no tunnel for review traffic, no OpenClaw on the review path.

**ADR-0086 D2** — Enqueue mechanism is GitHub-native (label + queue comment). The Action performs two GitHub API operations: add `needs-agent-review` (always, on every triggering event, including `synchronize` events while `agent-review-in-progress` is current — the label is both the queue index and the invalidation signal); upsert a structured queue comment carrying the review-request payload (with `head_sha` edited in place on every triggering event — the comment is the canonical "what SHA needs review"). Optional richer payload via a workflow artifact is permitted as a polish phase but v1 must work with label+comment alone.

**ADR-0086 D2 managed labels amendment** — The Action normalizes Grid-owned PR labels centrally before enqueue. It may reconcile labels inside the managed set, but it must not remove arbitrary human-applied labels.

**ADR-0086 D3 step 5** — Head-SHA invalidation. The cheap Action's per-event behaviour (re-add `needs-agent-review` + update queue comment `head_sha`) is what the worker's pre-flight and post-flight head-SHA checks rely on. The worker reads the comment's `head_sha` before and after each CLI invocation; mismatch → discard the stale verdict, release the claim. This workflow's job is to keep the comment's `head_sha` accurate at all times — the worker depends on that.

**ADR-0044 D6 (preserved)** — Authorship classification via the PR-body `Authorship:` line. The current workflow already extracts it; the rewrite preserves the extraction logic verbatim, just moves it into the queue comment.

**ADR-0012 D5 (invariant 39)** — Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's. This workflow's `permissions:` widens from `pull-requests: read` to `pull-requests: write` + `issues: write`; callers must widen accordingly.

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. The workflow logs only structured fields (repo, PR number, head SHA, label name) — never tokens.

> **Invariant 9:** Vault is the only source of secrets. The workflow consumes only the standard `GITHUB_TOKEN` passed by the caller; no external secrets after the webhook-signing-secret removal.

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. The review enqueueing is tier-3 and advisory — it does not become a required check and does not alter the tier-1 gate.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. This workflow does not load agent context — it enqueues. The worker (packet 03) loads context; that loading is governed by `.claude/agents/review.md`.

> **Invariant 39:** Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions. Callers omitting `permissions:` inherit the repository default and will fail on the label/comment write — packet 07's Architecture caller and packet 09's fan-out callers must declare the wider block.

- **No HMAC, no signed payload, no curl POST.** ADR-0086 D1 is explicit: the inbound webhook is removed entirely. Do not leave the webhook step as `if: false` — delete it.
- **The label add is always, every triggering event.** Even when `agent-review-in-progress` is already on the PR. This is the invalidation signal the worker's head-SHA check depends on (ADR-0086 D3 step 5).
- **The queue comment is upserted, not appended.** The opaque HTML-comment marker is the idempotency key for the upsert; the workflow must find and edit the prior comment, never create a duplicate.
- **The Action never invokes any LLM.** Cost is the GitHub Actions minute floor — a single label write, a single comment write, exit. No LLM tokens are consumed in the cloud path by design (ADR-0086 D2).
- **Managed-label normalization is bounded.** The workflow owns only its declared managed set and preserves human labels outside that set.

## Labels
`ci`, `tier-2`, `ops`, `adr-0086`, `wave-1`

## Agent Handoff

**Objective:** Rewrite `job-review-request.yml` from webhook-emitting to managed-label-normalizing and label-and-comment-emitting per ADR-0086 D2. Remove the webhook inputs, secret, signing logic, and curl POST. Add bounded managed-label normalization, the always-re-add `needs-agent-review` semantics, and the idempotent queue-comment upsert with `head_sha` edited in place.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Ship the label+comment enqueue rail so Architecture's caller (packet 07) and the Phase-B fan-out (packet 09) can consume it.
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase A.
- ADRs: ADR-0086 (primary, D1/D2/D3), ADR-0044 D6 (authorship extraction preserved), ADR-0012 D5 / invariant 39 (caller permissions superset rule).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0086 acceptance (soft).

**Constraints:**
- No HMAC, no signed payload, no curl POST — the webhook delivery step is deleted, not conditionally disabled.
- Normalize only managed labels; preserve arbitrary human labels.
- The label add is unconditional on every triggering event, even when `agent-review-in-progress` is already present.
- The queue comment is upserted idempotently by an opaque HTML-comment marker; never duplicated.
- The Action consumes no LLM tokens.

**Key Files:**
- `.github/workflows/job-review-request.yml` (in-place rewrite)
- `docs/CHANGELOG.md`
- `docs/consumer-usage.md`
- `README.md`

**Contracts:** Produces a `needs-agent-review` label on the PR and a single upserted queue comment with the opaque marker. Consumed by the worker (packet 03) which parses the queue payload, edits the comment to add claim metadata, and posts the verdict comment. The `.honeydrunk-review.yaml` schema (packet 04 in this initiative) is the per-repo config the workflow reads.
