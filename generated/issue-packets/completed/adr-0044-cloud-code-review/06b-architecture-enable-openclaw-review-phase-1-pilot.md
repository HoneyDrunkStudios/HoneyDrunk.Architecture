---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["ci", "tier-2", "meta", "openclaw", "adr-0044", "wave-1"]
dependencies: ["packet:02b", "packet:03b", "packet:04", "packet:05b"]
adrs: ["ADR-0044", "ADR-0011"]
accepts: ["ADR-0044"]
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
supersedes: ["packet:06"]
---

# Enable the OpenClaw/Codex reviewer on HoneyDrunk.Architecture (Phase 1 pilot)

## Summary
Enable ADR-0044 Phase 1 on the Architecture repo using the OpenClaw/Codex Grid Review Runner and `job-review-request.yml` trigger rail. This supersedes the originally filed packet 06 that assumed a cloud model runtime in GitHub Actions.

## Scope
- Add `.honeydrunk-review.yaml` to `HoneyDrunk.Architecture` with `enabled: true`, `runner: openclaw-codex`, `severity_floor: Suggest`, and appropriate `skip_paths`.
- Add/extend the Architecture PR review caller workflow to invoke `job-review-request.yml` on pull_request opened/synchronize/ready_for_review.
- Confirm the OpenClaw runner can receive/pick up review requests for Architecture PRs.
- Verify the runner comments a review verdict and records the reviewed head SHA.
- Document Phase 1 go/no-go evidence in the PR body or a small Architecture note.

## NuGet Dependencies
None. YAML/docs only.

## Acceptance Criteria
- [ ] `.honeydrunk-review.yaml` exists with `enabled: true` and `runner: openclaw-codex`
- [ ] Architecture PR workflow invokes `job-review-request.yml`
- [ ] Draft PRs and `skip-review` PRs do not request review
- [ ] A real/test Architecture PR receives a Grid Review Runner comment
- [ ] Re-running on the same head SHA does not duplicate review work
- [ ] OpenClaw-offline behavior is advisory/pending, not a hard failure
- [ ] Phase 1 go/no-go evidence is recorded

## Human Prerequisites
- [ ] Confirm OpenClaw runner is available for the pilot window.
- [ ] Confirm whether the pilot uses webhook or cron/poll pickup.

## Dependencies
- `packet:02b` — OpenClaw runner runtime definition (hard)
- `packet:03b` — `job-review-request.yml` trigger rail (hard)
- `packet:04` — review rubric in `review.md` (hard)
- `packet:05b` — OpenClaw-aware review config schema doc (soft)

## Referenced ADR Decisions
- ADR-0044 D1/D2/D5/D11 Phase 1.
- ADR-0011 D5 advisory posture.

## Constraints
- Do not use Anthropic API for the Phase 1 pilot.
- Do not make the review check required.
- Do not fan out to other repos until the Phase 1 go/no-go is documented.

## Agent Handoff

**Objective:** Enable ADR-0044 Phase 1 on `HoneyDrunk.Architecture` using the OpenClaw/Codex runner and validate automatic PR review without per-token API spend.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Key Files:**
- `.honeydrunk-review.yaml` (new)
- `.github/workflows/pr-review.yml` or existing PR workflow caller
- Phase 1 evidence note, if needed
