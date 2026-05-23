# ADR-0044 Phase 1 Pilot Evidence

**Status:** Pending pilot PR merge and first live review request
**Pilot repo:** `HoneyDrunk.Architecture`
**Runner:** `openclaw-codex`
**Transport:** cron/poll fallback first; webhook later

## Pilot Wiring

This repo opts into ADR-0044 Phase 1 with:

- `.honeydrunk-review.yaml`
- `.github/workflows/grid-review-request.yml`

The workflow calls `HoneyDrunk.Actions/.github/workflows/job-review-request.yml@main` on pull request `opened`, `synchronize`, and `ready_for_review` events.

The pilot is advisory only. It must not become a required branch-protection check during Phase 1.

## Current Transport Choice

Phase 1 starts with fallback transport only:

- GitHub Actions emits the `grid-review-request` payload.
- The OpenClaw webhook URL is intentionally empty until the receiver and signing secret are provisioned.
- The workflow uploads `review-request.json` as an artifact and posts the machine-readable replay pointer comment.
- OpenClaw cron/poll discovers pending Architecture review requests and runs the Grid Review Runner.

## OpenClaw Polling Window

Temporary cron/poll cadence:

```text
*/15 8-21 * * * America/New_York
0 22 * * * America/New_York
```

Interpretation:

- Poll every 15 minutes.
- Start at 8:00 AM Eastern.
- Run the final daily poll at 10:00 PM Eastern.
- Polling is Architecture-only for the Phase 1 pilot.

## Webhook Cutover Rule

When the OpenClaw webhook receiver is live and `OPENCLAW_GRID_REVIEW_WEBHOOK_URL` plus `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` are configured:

1. Enable webhook delivery for the caller workflow.
2. Verify a real Architecture PR request reaches OpenClaw by webhook.
3. Disable the temporary cron/poll job.
4. Record the cutover evidence in this file or a follow-up note.

Cron/poll is a temporary fallback transport, not the long-term primary path.

## Go/No-Go Evidence Checklist

- [ ] `.honeydrunk-review.yaml` exists with `enabled: true` and `runner: openclaw-codex`.
- [ ] Architecture PR workflow invokes `job-review-request.yml`.
- [ ] Draft PRs do not request review.
- [ ] `skip-review` PRs do not request review.
- [ ] A real/test Architecture PR receives a Grid Review Runner comment.
- [ ] Re-running on the same head SHA does not duplicate review work.
- [ ] OpenClaw-offline behavior is advisory/pending, not a hard failure.
- [ ] Phase 1 go/no-go result is recorded.
