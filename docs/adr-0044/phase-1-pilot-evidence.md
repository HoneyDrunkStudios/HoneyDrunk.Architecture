# ADR-0044 Phase 1 Pilot Evidence

**Status:** Superseded by ADR-0086 local-worker Phase A pilot
**Pilot repo:** `HoneyDrunk.Architecture`
**Runner:** `local-worker`
**Transport:** GitHub label/comment queue, polled by the ADR-0086 runner

## Pilot Wiring

This repo opts into ADR-0044 Phase 1 with:

- `.honeydrunk-review.yaml`
- `.github/workflows/grid-review-request.yml`

The workflow calls `HoneyDrunk.Actions/.github/workflows/job-review-request.yml@main` on pull request `opened`, `synchronize`, and `ready_for_review` events.

The pilot is advisory only. It must not become a required branch-protection check during Phase 1.

## Current Transport Choice

ADR-0086 replaces the OpenClaw webhook/fallback transport with a GitHub-native queue:

- GitHub Actions applies `needs-agent-review`.
- GitHub Actions upserts a `honeydrunk-grid-review-queue:v1` PR comment containing the current `head_sha`.
- The local worker polls for queued PRs, claims one by replacing `needs-agent-review` with `agent-review-in-progress`, runs the subscribed local CLI review, and posts one advisory verdict.
- Head-SHA advancement is detected by comparing both the queue comment and the live PR head before posting a verdict.

## Local Worker Polling Window

Default Task Scheduler cadence:

```text
grid-review: every 60 seconds, at startup, and at logon
```

Interpretation:

- Polling is Architecture-only for the Phase 1 pilot.
- The workflow is advisory only; branch protection must not require the review verdict during Phase A.

## Cutover Rule

When the ADR-0086 local worker is live:

1. Verify a real Architecture PR receives `needs-agent-review` plus the queue comment.
2. Verify the worker claims the PR and replaces the label with `agent-review-in-progress`.
3. Verify the worker posts one advisory verdict for the recorded head SHA.
4. Record the cutover evidence in this file or a follow-up note.

The old OpenClaw review-path cron/webhook transport is superseded by ADR-0086 and should remain disabled after cutover.

## Go/No-Go Evidence Checklist

- [ ] `.honeydrunk-review.yaml` exists with `enabled: true` and `runner: local-worker`.
- [ ] Architecture PR workflow invokes `job-review-request.yml`.
- [ ] Draft PRs do not request review.
- [ ] `skip-review` PRs do not request review.
- [ ] A real/test Architecture PR receives `needs-agent-review` plus the queue comment.
- [ ] The local worker claims the PR and posts a Grid Review Runner comment.
- [ ] Re-running on the same head SHA does not duplicate review work.
- [ ] Synchronizing a new commit updates the queue comment `head_sha` and re-adds `needs-agent-review`.
- [ ] Phase 1 go/no-go result is recorded.
