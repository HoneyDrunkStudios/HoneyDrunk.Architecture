---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["ci", "tier-2", "meta", "adr-0044", "wave-1"]
dependencies: ["packet:03", "packet:04", "packet:05"]
adrs: ["ADR-0044"]
accepts: ["ADR-0044"]
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Enable the cloud reviewer on HoneyDrunk.Architecture (Phase 1 pilot)

## Summary
Enable the cloud-wired reviewer on `HoneyDrunk.Architecture` only — the Phase-1 pilot repo — by authoring `.honeydrunk-review.yaml` with `enabled: true` and a caller workflow that invokes `job-review-agent.yml` on `pull_request` events. This is the Phase-1 go/no-go: verify the cost model and output quality on the lowest-blast-radius repo before Phase 2 starts.

## Target Workflow
**File:** `.github/workflows/pr-review.yml` (new caller in the Architecture repo) and `.honeydrunk-review.yaml` (repo root)
**Family:** manual / pr-core caller

## Motivation
ADR-0044 D11 Phase 1 enables the cloud reviewer on `HoneyDrunk.Architecture` only — the lowest blast radius, since architecture PRs are predominantly docs and catalogs. The phase's exit criterion is "the cloud-wired agent's verdicts are at least as useful as the local agent's, at acceptable cost." If that bar is missed, Phase 2 does not start. No discipline changes (D6/D7/D8/D9) activate in Phase 1.

## Proposed Change

### `.honeydrunk-review.yaml` at the Architecture repo root
Author per the v1 schema (packet 05's doc):
```yaml
enabled: true
severity_floor: Suggest
skip_paths:
  - "**/generated/**"
  - "**/*.g.cs"
model: sonnet
cost_cap_per_pr_usd: 5.00
```
`skip_paths` is tuned for a docs/catalog repo — `generated/` (issue packets, drafts, audits) is excluded so the reviewer focuses on constitution, ADRs, catalogs, and agent definitions.

### Caller workflow
A new `.github/workflows/pr-review.yml` in `HoneyDrunk.Architecture` that:
- Triggers on `pull_request` types `opened`, `synchronize`, `ready_for_review`.
- Calls `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-review-agent.yml@<pinned-ref>` via `workflow_call`.
- Passes the Anthropic/GitHub-App secrets through from the repo/org secrets surface populated in packet 02.

### Phase-1 verification
- Run the reviewer on several real Architecture-repo PRs (or a test PR).
- Record the per-PR cost and a quality comparison against the local `review` agent's verdict on the same diff.
- Document the Phase-1 go/no-go outcome — this feeds the Phase-2 decision and the dispatch plan's wave-boundary note.

## Consumer Impact
- Only `HoneyDrunk.Architecture` is affected. No other repo gets the reviewer in Phase 1.
- Every non-draft, non-`skip-review` PR on the Architecture repo now receives an advisory review comment.

## Breaking Change?
- [ ] Yes
- [x] No — advisory only; the check is non-required and never blocks a merge.

## Acceptance Criteria
- [ ] `.honeydrunk-review.yaml` exists at the Architecture repo root with `enabled: true` and docs-repo-tuned `skip_paths`
- [ ] `.github/workflows/pr-review.yml` exists and calls `job-review-agent.yml` at a pinned ref on `pull_request` opened/synchronize/ready_for_review
- [ ] The reviewer posts an advisory comment on a real or test PR; the check run is non-required
- [ ] Per-PR cost is recorded and is within the D5 expectation
- [ ] A Phase-1 go/no-go outcome is documented (quality vs the local agent, cost) — recorded in the PR body and surfaced for the dispatch-plan wave-boundary update
- [ ] No D6/D7/D8/D9 discipline behavior is active (Phase 1 is reviewer-only)

## Human Prerequisites
- [ ] Confirm the pinned `job-review-agent.yml` ref to call (tag or SHA)
- [ ] Verify the Anthropic/GitHub-App secrets from packet 02 are present on the Architecture repo's secrets surface (or inherited from org secrets)
- [ ] Review the Phase-1 cost and quality data and make the Phase-1 → Phase-2 go/no-go decision before any Phase-2 packet is filed

## Dependencies
- `packet:03` — `job-review-agent.yml` (**hard** — the caller invokes it).
- `packet:04` — `review.md` D3 rubric (**hard** — the reviewer must run against the twenty-category rubric for a meaningful Phase-1 quality signal).
- `packet:05` — `.honeydrunk-review.yaml` schema doc (soft — the config is authored against the schema).

## Referenced ADR Decisions

**ADR-0044 D11 Phase 1** — MVP on one pilot repo: build `job-review-agent.yml`, enable on `HoneyDrunk.Architecture` only (lowest blast radius), verify cost model and output quality, no discipline changes. Exit criterion: cloud verdicts at least as useful as the local agent's, at acceptable cost. Miss the bar → Phase 2 does not start.
**ADR-0044 D4** — `.honeydrunk-review.yaml` with `enabled: true` is the opt-in gate.
**ADR-0044 D5** — Cost expectation $40-100/month Grid-wide; per-PR cap $5.

## Constraints
- **Phase 1 is reviewer-only.** Do not activate authorship classification, PR-size discipline, multi-perspective review, or sampling audit — those are Phases 2-4.
- **Architecture repo only.** No other repo gets a `.honeydrunk-review.yaml` in this packet.
- **Advisory check.** Never make the review check required.

## Labels
`ci`, `tier-2`, `meta`, `adr-0044`, `wave-1`

## Agent Handoff

**Objective:** Enable the cloud reviewer on `HoneyDrunk.Architecture` — author `.honeydrunk-review.yaml` (`enabled: true`) and a `pr-review.yml` caller for `job-review-agent.yml`. Verify Phase-1 cost and quality.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Phase-1 pilot — prove the cloud reviewer's capability and cost on the lowest-blast-radius repo before Phase 2.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 1.
- ADRs: ADR-0044 (D11 Phase 1, D4, D5).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — `job-review-agent.yml` (hard).
- `packet:04` — `review.md` D3 rubric (hard).
- `packet:05` — schema doc (soft).

**Constraints:**
- Phase 1 is reviewer-only; no discipline changes.
- Architecture repo only; advisory check.

**Key Files:**
- `.honeydrunk-review.yaml` (new, repo root)
- `.github/workflows/pr-review.yml` (new)

**Contracts:** Consumes `job-review-agent.yml` (`workflow_call`) and the `.honeydrunk-review.yaml` v1 schema.
