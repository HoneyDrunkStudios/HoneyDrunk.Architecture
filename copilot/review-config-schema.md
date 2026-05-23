# HoneyDrunk Review Config Schema

**File:** `.honeydrunk-review.yaml`  
**Schema version:** v1  
**Status:** ADR-0044 Phase 1 pilot schema  
**Related:** [ADR-0044](../adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md), [OpenClaw Grid Review Runner](../infrastructure/openclaw/grid-review-runner.md), [PR review rules](./pr-review-rules.md)

## Purpose

`.honeydrunk-review.yaml` is the per-repo opt-in file for the ADR-0044 Grid-aware code review runner.

GitHub Actions is only the trigger rail. The v1 reasoning runner is OpenClaw/Codex, using `.claude/agents/review.md` as the canonical prompt source and `copilot/pr-review-rules.md` as the severity taxonomy reference.

The file must be present and `enabled: true` before `HoneyDrunk.Actions/.github/workflows/job-review-request.yml` requests review for a repository.

## v1 Schema

```yaml
enabled: true
runner: openclaw-codex       # openclaw-codex | api-ci; v1 default is openclaw-codex
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

- `openclaw-codex` — default v1 runner. GitHub Actions emits a signed request; OpenClaw/Codex performs the review and comments back on the PR.
- `api-ci` — reserved future fallback. This is not default v1 behavior and must not be used without an explicit ADR/packet updating the execution posture, cost cap, and secret requirements.

Do not configure Sonnet/Opus/OpenAI model names in this file for v1. ADR-0044 removed per-repo model selection from the Phase 1 schema because the runner is OpenClaw/Codex, not a model API call from GitHub Actions.

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

For `openclaw-codex`, the Phase 1 default is:

```yaml
cost_cap_per_pr_usd: 0.00
```

`0.00` means the repo expects the subscription-backed OpenClaw/Codex runner and no per-token API spend from GitHub Actions.

If a future `api-ci` fallback is explicitly enabled, this field must be set to a non-zero cap and the enabling packet must document the budget and secret requirements. API-backed execution is not a required v1 dependency.

## Skip Behavior

The caller workflow must skip without failure when:

- the PR is a draft;
- the PR has the `skip-review` label;
- `.honeydrunk-review.yaml` is missing;
- `enabled` is not `true`;
- the same PR head SHA has already reached a terminal reviewed/skipped state.

The review remains advisory. OpenClaw offline/unavailable behavior must produce pending/replay evidence, not fail branch protection.

## Reviewed Head SHA and Idempotency

ADR-0044 D1 defines the idempotency key:

```text
owner/repo#pr@headSha
```

The runner records the reviewed head SHA. A PR should be reviewed once per head SHA. Re-running the workflow for the same head SHA must not produce duplicate review work or duplicate PR comments.

A new commit changes the head SHA and is eligible for a new review request.

## PR Comment Output

The runner posts the verdict as a normal GitHub PR comment using the format in `.claude/agents/review.md`. Phase 1 does not require a blocking check-run or required status check.

If webhook delivery is unavailable, the workflow preserves the same `grid-review-request` payload as an artifact and may post a machine-readable replay pointer comment. OpenClaw cron/poll replay uses the same idempotency path.

## ADR-0044 Cross-References

- **ADR-0044 D1** — GitHub Actions emits the review request; OpenClaw/Codex runs the Grid-aware review; duplicate events converge by idempotency key.
- **ADR-0044 D4** — `.honeydrunk-review.yaml` is the repo-local opt-in/config surface.
- **ADR-0044 D5** — review remains advisory in Phase 1 and must not become required branch protection.
- **Packet 02b runtime contract** — [`infrastructure/openclaw/grid-review-runner.md`](../infrastructure/openclaw/grid-review-runner.md) defines the webhook, payload, HMAC signing, state, replay, and reviewed-head-SHA behavior.

## Minimal Phase 1 Config for HoneyDrunk.Architecture

```yaml
enabled: true
runner: openclaw-codex
severity_floor: Suggest
skip_paths:
  - "**/*.Designer.cs"
  - "**/*.g.cs"
  - "**/generated/**"
cost_cap_per_pr_usd: 0.00
```
