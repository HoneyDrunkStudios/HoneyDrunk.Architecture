---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "openclaw", "adr-0044", "wave-1"]
dependencies: ["packet:01", "packet:02b"]
adrs: ["ADR-0044"]
accepts: ["ADR-0044"]
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-actions
supersedes: ["packet:03"]
---

# Build job-review-request.yml — the GitHub trigger rail for the OpenClaw reviewer

## Summary
Replace the originally scoped `job-review-agent.yml` Anthropic/Claude runtime with a lightweight reusable workflow, `job-review-request.yml`, that decides whether a PR should request Grid review and emits/delivers a request for the OpenClaw/Codex Grid Review Runner.

## Target Workflow
**File:** `.github/workflows/job-review-request.yml`
**Family:** pr-core / advisory review trigger

## Motivation
ADR-0044 now keeps reasoning-heavy review in OpenClaw/Codex and uses GitHub Actions as the cheap rail. The workflow should not invoke Anthropic, Claude Agent SDK, or any model API directly. It should collect PR metadata, apply skip/enable rules, and deliver a request to OpenClaw or leave a durable artifact for OpenClaw cron/poll pickup.

## Proposed Change
1. Add reusable workflow `job-review-request.yml`.
2. Trigger from caller workflows on `pull_request` opened/synchronize/ready_for_review.
3. Skip when:
   - PR is draft;
   - PR has `skip-review`;
   - `.honeydrunk-review.yaml` is absent or `enabled: false`;
   - current head SHA was already marked reviewed if that state is available to the workflow.
4. Produce a request payload with repo, PR number, head SHA, author class, changed-file summary, packet link, config, and callback/comment target.
5. Delivery:
   - preferred: POST to an OpenClaw webhook URL if configured;
   - fallback: upload artifact and/or post a machine-readable advisory comment that OpenClaw cron can discover.
6. Set/report advisory status only. Do not fail branch protection if OpenClaw is offline.

## NuGet Dependencies
None. GitHub Actions workflow only.

## Acceptance Criteria
- [ ] `job-review-request.yml` exists in HoneyDrunk.Actions
- [ ] It contains no Anthropic, Claude Agent SDK, or model API invocation
- [ ] It applies draft, `skip-review`, and `.honeydrunk-review.yaml enabled` skip rules
- [ ] It emits the documented review request payload
- [ ] It supports webhook delivery and durable fallback artifact/comment delivery
- [ ] It reports advisory pending/unavailable state when OpenClaw is offline
- [ ] `docs/consumer-usage.md` documents how repos call the workflow
- [ ] `docs/CHANGELOG.md` records the new workflow

## Human Prerequisites
- [ ] Choose webhook-first vs artifact/comment-first delivery for Phase 1.
- [ ] If webhook-first, provide the OpenClaw webhook URL/secret through GitHub Actions secrets.

## Dependencies
- `packet:02b` — runner payload/schema and runtime behavior (hard).

## Referenced ADR Decisions
- ADR-0044 D1 — `job-review-request.yml` is the trigger rail, not the reasoning brain.
- ADR-0044 D5 — subscription-backed default; no per-token API bill for v1.

## Constraints
- Do not call Anthropic/OpenAI APIs from GitHub Actions in v1.
- Do not make review a required blocking check.
- Preserve reusable-workflow factoring per ADR-0012.

## Agent Handoff

**Objective:** Build the reusable GitHub Actions trigger rail for the OpenClaw/Codex Grid Review Runner.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Key Files:**
- `.github/workflows/job-review-request.yml` (new)
- `docs/consumer-usage.md`
- `docs/CHANGELOG.md`
