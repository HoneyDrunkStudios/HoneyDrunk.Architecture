# OpenClaw Grid Review Runner

**Status:** ADR-0044 Phase 1 runtime contract
**Owner:** HoneyDrunk.Architecture
**Related:** ADR-0044, ADR-0011, ADR-0012, ADR-0005, ADR-0006
**Tracking:** Architecture#179

## Packet 02b acceptance mapping

This document satisfies ADR-0044 packet 02b by defining:

- the OpenClaw/Codex runner runtime contract;
- `.claude/agents/review.md` as the canonical prompt source;
- the signed webhook receiver contract, including HMAC/timestamp verification, replay window, size cap, response codes, and secret storage;
- the review request payload schema;
- durable request state, idempotency, and reviewed-head-SHA behavior;
- webhook-primary delivery plus cron/poll replay fallback;
- advisory failure behavior when OpenClaw is offline; and
- the v1 rule that no Anthropic/OpenAI model API key is required.

The concrete webhook URL and signing-secret value are intentionally not recorded here. They are deployment secrets required before wiring `job-review-request.yml` in HoneyDrunk.Actions.

## Goal

The Grid Review Runner is the OpenClaw-hosted execution surface for automatic Grid-aware PR review.

GitHub Actions is the trigger rail. OpenClaw/Codex is the reasoning runtime. The runner consumes the same `.claude/agents/review.md` prompt source used by local/manual review, loads the same Architecture context, comments back on the PR, and records the reviewed head SHA so unchanged diffs are not reviewed repeatedly.

## Phase-1 transport

Phase 1 is **webhook-first**.

1. A caller repo invokes `HoneyDrunk.Actions/.github/workflows/job-review-request.yml` on PR `opened`, `synchronize`, and `ready_for_review` events.
2. The workflow applies skip rules: draft PR, `skip-review` label, `.honeydrunk-review.yaml` missing or `enabled: false`, or already-reviewed head SHA if state is visible.
3. The workflow emits one review-request JSON payload.
4. The workflow signs the payload and posts it to the OpenClaw webhook endpoint.
5. The OpenClaw receiver verifies the request, persists it durably, and queues the runner.
6. The runner checks out/updates the target repo and `HoneyDrunk.Architecture`, invokes Codex with `.claude/agents/review.md`, and posts the advisory verdict back to the PR.

Cron/poll is retained as a replay/fallback path only. It discovers the same payload from an artifact or machine-readable PR comment and submits it through the same idempotency/state path.

## Endpoint contract

Recommended endpoint path:

```text
POST /github/grid-review-request
```

The concrete host URL is deployment-specific and must not be committed to the repo. For Phase 1 it may be exposed through a tunnel or relay, but the endpoint must never be public without signature verification.

Required request headers:

```text
Content-Type: application/json
X-HoneyDrunk-Event: grid-review-request
X-HoneyDrunk-Delivery: <unique delivery id / GitHub run id>
X-HoneyDrunk-Timestamp: <unix epoch seconds>
X-HoneyDrunk-Signature-256: sha256=<hex hmac>
```

Signature input:

```text
<timestamp>.<raw request body bytes>
```

Signature algorithm: HMAC-SHA256 using the configured webhook signing secret.

Replay window: 5 minutes from `X-HoneyDrunk-Timestamp`.

Default body size cap: 256 KiB. The workflow payload is metadata only; PR diffs are loaded by the runner from GitHub, not embedded in the webhook.

## Secret storage

The webhook signing secret follows ADR-0005/ADR-0006 secret discipline. Recommended secret name:

```text
webhook-github-grid-review-signing-secret
```

For Phase 1, the same secret value is configured in:

- the caller workflow environment/repo secret used by `job-review-request.yml`; and
- the OpenClaw receiver secret store.

Do not log the secret or full webhook body. Logs may include delivery id, repo, PR number, head SHA, payload byte count, and a SHA-256 hash prefix of the body.

## Request payload

The payload shape is versioned. Add fields compatibly; breaking changes require a new `schemaVersion`.

```json
{
  "schemaVersion": 1,
  "event": "grid-review-request",
  "idempotencyKey": "HoneyDrunkStudios/HoneyDrunk.Architecture#123@abcdef123456",
  "repo": {
    "owner": "HoneyDrunkStudios",
    "name": "HoneyDrunk.Architecture",
    "fullName": "HoneyDrunkStudios/HoneyDrunk.Architecture",
    "cloneUrl": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture.git"
  },
  "pullRequest": {
    "number": 123,
    "headSha": "abcdef123456",
    "baseRef": "main",
    "headRef": "feature/example",
    "isDraft": false,
    "author": "octocat",
    "url": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/pull/123"
  },
  "authorship": {
    "class": "agent-codex",
    "source": "pr-body"
  },
  "changeSummary": {
    "changedFiles": 6,
    "additions": 120,
    "deletions": 30,
    "files": ["adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md"]
  },
  "context": {
    "packetUrl": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/170",
    "packetPath": "generated/issue-packets/active/adr-0044-cloud-code-review/01-architecture-adr-0044-acceptance.md",
    "adrs": ["ADR-0044"],
    "node": "honeydrunk-architecture"
  },
  "config": {
    "enabled": true,
    "runner": "openclaw-codex",
    "riskClass": "normal"
  },
  "callback": {
    "mode": "github-pr-comment",
    "prCommentsUrl": "https://api.github.com/repos/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/123/comments",
    "checksUrl": "https://api.github.com/repos/HoneyDrunkStudios/HoneyDrunk.Architecture/check-runs"
  }
}
```

## Idempotency and state

Idempotency key:

```text
owner/repo#pr@headSha
```

The receiver must persist the request before runner execution. A durable state record should track:

- idempotency key;
- delivery id;
- repo / PR / head SHA;
- received timestamp;
- state: `received`, `queued`, `running`, `commented`, `failed`, `skipped`;
- last error, if any;
- PR comment id or URL, if posted.

Duplicate deliveries for the same idempotency key must not create duplicate review comments. They may return success with the existing state or a conflict/in-flight response depending on the current state.

Reviewed-head-SHA tracking is the runner's stop condition: if the same PR head SHA has already reached `commented` or an explicit `skipped` terminal state, the runner does not review again unless manually replayed with a force flag.

## Response codes

The webhook receiver uses a narrow response envelope:

- `202 Accepted` — signature valid; request persisted and queued or already known.
- `400 Bad Request` — malformed payload, missing required fields, timestamp outside replay window.
- `401 Unauthorized` — missing or invalid signature.
- `409 Conflict` — same idempotency key is currently running and cannot accept another concurrent execution.
- `413 Payload Too Large` — body exceeds cap.
- `5xx` — receiver/storage failure; GitHub Action may fall back to artifact/comment replay.

The review remains advisory. A failed or unavailable receiver must not fail branch protection.

## Runner context loading

The runner mirrors ADR-0011 D4 and loads:

1. `constitution/invariants.md`
2. governing ADRs referenced in packet/frontmatter
3. `catalogs/relationships.json`
4. `catalogs/contracts.json`
5. for each target repo: `repos/{node}/overview.md`, `boundaries.md`, `invariants.md`
6. `copilot/pr-review-rules.md`
7. the packet file or GitHub issue body linked from the PR
8. the PR diff

The canonical prompt remains `.claude/agents/review.md`. Do not fork the prompt into workflow YAML or a separate runner-only prompt.

## GitHub auth

For v1, local `gh` authentication is acceptable for:

- checking out/updating target repos;
- reading PR metadata and diffs;
- posting advisory comments;
- updating optional advisory check/status state.

A narrowly scoped GitHub App can replace local `gh` auth later if operational pressure justifies it. No Anthropic/OpenAI model API key is required for v1.

## PR comment write safety

Grid Review comments must post the rendered Markdown body, never a local path or shell shorthand. When using `gh`, prefer `gh issue comment <pr> --repo <owner/repo> --body-file <file>`. If using `gh api`, verify the exact file-body syntax before writing. Do not use `--body @<file>`; that posts the literal path in some command shapes. Before any write, assert the outgoing body starts with the Grid Review metadata/header and does not start with `@`, `C:\`, `/tmp/`, or another temp-file path. If the guard fails, do not post the PR comment; mark the local review state `failed` with the reason.

Follow-up reviews should be incremental: diff the previous reviewed head to the current head, verify prior findings as resolved/still-open/waived, and deeply review only changed files plus directly impacted contracts/boundaries. They should not repeat a full review of unchanged files unless the delta changes a boundary or invariant.

## Offline and fallback behavior

If OpenClaw is offline or the webhook endpoint is unreachable, `job-review-request.yml` should:

1. mark the review request as advisory pending/unavailable;
2. upload the exact same payload as an artifact or post it in a machine-readable PR comment;
3. avoid failing the PR check;
4. allow OpenClaw cron/poll to discover and replay the request later.

Manual replay submits the stored payload through the same idempotency path. Replay with the same idempotency key is safe; forced re-review requires an explicit operator action and should update the existing comment rather than spamming a new one when possible.
