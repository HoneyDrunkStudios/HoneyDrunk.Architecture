# HoneyDrunk Review Config Schema

**File:** `.honeydrunk-review.yaml`  
**Schema version:** v1  
**Status:** ADR-0086 local-worker schema  
**Related:** [ADR-0044](../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md), [ADR-0086 Grid Agent Runner](../infrastructure/workers/grid-agent-runner/README.md), [PR review rules](./pr-review-rules.md)

## Purpose

`.honeydrunk-review.yaml` is the per-repo opt-in file for the ADR-0044 / ADR-0086 Grid-aware code review runner.

GitHub Actions is only the enqueue rail. The default reasoning runner is the ADR-0086 pull-based local worker, using `.claude/agents/review.md` as the canonical prompt source and `copilot/pr-review-rules.md` as the severity taxonomy reference.

The file must be present and `enabled: true` before `HoneyDrunk.Actions/.github/workflows/job-review-request.yml` requests review for a repository.

## v1 Schema

```yaml
enabled: true
runner: local-worker         # local-worker | api-ci; default is local-worker
severity_floor: Suggest      # Suggest | Request Changes | Block
skip_paths:
  - "**/*.Designer.cs"
  - "**/*.g.cs"
  - "**/generated/**"
cost_cap_per_pr_usd: 0.00    # v1 subscription-backed default; API fallback must set explicit non-zero cap
```

## Fields

### `enabled`

Required boolean.

- `true` — the repo opts in to Grid review requests.
- `false` — the repo is explicitly disabled; the workflow should skip without failure.
- missing file or missing field — treated as disabled for Phase 1.

### `runner`

Required string.

Allowed values:

- `local-worker` — default runner. GitHub Actions queues review work through labels/comments; the ADR-0086 local worker polls, claims, reviews, and comments back on the PR.
- `api-ci` — reserved future fallback. This is not default v1 behavior and must not be used without an explicit ADR/packet updating the execution posture, cost cap, and secret requirements.

Do not configure Sonnet/Opus/OpenAI model names in this file. Per-repo model selection is not part of the schema because the runner invokes the canonical review agent through the approved worker substrate, not a model API call from GitHub Actions.

### `severity_floor`

Required string.

Allowed values:

- `Suggest`
- `Request Changes`
- `Block`

The severity floor controls which findings the runner surfaces in the PR comment. It does not make the review blocking and does not change branch protection.

`Suggest` is the recommended Phase 1 value for `HoneyDrunk.Architecture` so the pilot can show the full advisory signal while the runner is still being validated.

### `skip_paths`

Optional array of glob strings.

Paths matching these globs may be excluded from review-request significance checks or treated as low-signal by the runner. Typical skips are generated files, designer files, and compiled/generated docs outputs.

Skipping a path does not override Grid invariants. If a skipped path is the only changed surface but the PR also changes behavior through generation inputs, the runner may still review the PR through the source files.

### `cost_cap_per_pr_usd`

Required decimal.

For `local-worker`, the default is:

```yaml
cost_cap_per_pr_usd: 0.00
```

`0.00` means the repo expects the subscription-backed local-worker path and no per-token API spend from GitHub Actions.

If a future `api-ci` fallback is explicitly enabled, this field must be set to a non-zero cap and the enabling packet must document the budget and secret requirements. API-backed execution is not a required v1 dependency.

## Skip Behavior

The caller workflow must skip without failure when:

- the PR is a draft;
- the PR has the `skip-review` label;
- `.honeydrunk-review.yaml` is missing;
- `enabled` is not `true`;
- the same PR head SHA has already reached a terminal reviewed/skipped state.

The review remains advisory. Local-worker unavailable behavior must produce pending/replay evidence, not fail branch protection.

## Reviewed Head SHA and Idempotency

ADR-0044 D1 defines the idempotency key:

```text
owner/repo#pr@headSha
```

The runner records the reviewed head SHA. A PR should be reviewed once per head SHA. Re-running the workflow for the same head SHA must not produce duplicate review work or duplicate PR comments.

A new commit changes the head SHA and is eligible for a new review request.

## PR Comment Output

The runner posts the verdict as a normal GitHub PR comment using the format in `.claude/agents/review.md`. Phase 1 does not require a blocking check-run or required status check.

If the worker is unavailable, the queued label/comment state remains the durable replay surface. A later worker run uses the same idempotency path.

## ADR-0044 Cross-References

- **ADR-0044 D1, superseded in part by ADR-0086** — GitHub Actions requests Grid-aware review; under ADR-0086 this is a label/comment queue consumed by the local worker. Duplicate events converge by idempotency key.
- **ADR-0044 D4** — `.honeydrunk-review.yaml` is the repo-local opt-in/config surface.
- **ADR-0044 D5** — review remains advisory in Phase 1 and must not become required branch protection.
- **ADR-0086 runner contract** — [`infrastructure/workers/grid-agent-runner/README.md`](../infrastructure/workers/grid-agent-runner/README.md) defines the successor pull-based local-worker runtime.

## Minimal Phase 1 Config for HoneyDrunk.Architecture

```yaml
enabled: true
runner: local-worker
severity_floor: Suggest
skip_paths:
  - "**/*.Designer.cs"
  - "**/*.g.cs"
  - "**/generated/**"
cost_cap_per_pr_usd: 0.00
```

## Breaking Change History

- **2026-05-26 / ADR-0086:** `runner: openclaw-codex` was removed and replaced by `runner: local-worker` as the default. The `api-ci` fallback remains reserved for an explicit future opt-in.
- **2026-05-30 / ADR-0088:** the OpenClaw runtime contract files were retired; the ADR-0086 Grid Agent Runner is the live runner documentation.
