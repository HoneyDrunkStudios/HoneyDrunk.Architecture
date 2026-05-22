---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-2", "meta", "openclaw", "adr-0044", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0044"]
accepts: ["ADR-0044"]
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
supersedes: ["packet:02"]
---

# Define the OpenClaw/Codex Grid Review Runner runtime

## Summary
Replace the originally scoped Anthropic/GitHub-App credential packet with an Architecture-owned OpenClaw/Codex runner definition and runbook. The runner is the v1 reasoning brain for ADR-0044: GitHub Actions requests reviews; OpenClaw runs Codex against `.claude/agents/review.md`; the runner comments back on the PR and records the reviewed head SHA.

## Context
ADR-0044 now chooses a subscription-backed OpenClaw/Codex runtime for v1 instead of an Anthropic API-backed GitHub Action. This avoids a new per-token review bill and keeps PR diff review in the Studio's local OpenClaw/Codex path by default. The previously filed packet 02 (GitHub App + Anthropic key) is superseded by this packet.

## Scope
- Add Architecture documentation/config for the Grid Review Runner, e.g. `infrastructure/openclaw/grid-review-runner.md`.
- Define the review request payload consumed by the runner: repo, PR number, head SHA, authorship class, changed-file summary, packet link, and `.honeydrunk-review.yaml` settings.
- Define reviewed-head-SHA state storage under the OpenClaw workspace or Architecture-managed state file.
- Document both trigger modes:
  - webhook/request delivery from `job-review-request.yml`;
  - cron/poll fallback for open PRs when webhook delivery is unavailable.
- Document local auth expectations: `gh` auth is acceptable for v1; a narrowly scoped GitHub App/webhook credential is optional.

## NuGet Dependencies
None. Markdown/config only.

## Acceptance Criteria
- [ ] OpenClaw/Codex runner runtime is documented/configured in Architecture
- [ ] The runner consumes `.claude/agents/review.md` as the canonical prompt source
- [ ] The review request payload schema is documented
- [ ] Reviewed head SHA tracking is specified so unchanged PRs are not re-reviewed
- [ ] Webhook and cron/poll trigger modes are both documented
- [ ] The doc explicitly says no Anthropic API key is required for v1
- [ ] The doc names the advisory failure behavior when OpenClaw is offline

## Human Prerequisites
- [ ] Confirm whether Phase 1 uses webhook delivery first or cron/poll fallback first.

## Dependencies
- `packet:01` — ADR-0044 acceptance/amendment (soft).

## Referenced ADR Decisions
- ADR-0044 D1 — GitHub Actions as trigger rail; OpenClaw/Codex as runner.
- ADR-0044 D2 — runner context loading mirrors local invocation.
- ADR-0044 D5 — subscription-backed cost guardrails.

## Constraints
- Do not provision or require an Anthropic API key for v1.
- Do not make review a required blocking check.
- Keep runtime behavior provider-neutral enough that a future API-backed fallback can be added deliberately.

## Agent Handoff

**Objective:** Add the Architecture-side OpenClaw/Codex Grid Review Runner runtime doc/config that supersedes the old Anthropic credential packet.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Key Files:**
- `infrastructure/openclaw/grid-review-runner.md` (new; exact path may be adjusted if an existing OpenClaw infrastructure directory exists)
- `.claude/agents/review.md` (reference only; do not change unless packet 04 is in scope)
