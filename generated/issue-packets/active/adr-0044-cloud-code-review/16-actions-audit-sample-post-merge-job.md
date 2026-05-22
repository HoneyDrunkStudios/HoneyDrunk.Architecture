---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0044", "wave-4"]
dependencies: ["packet:03", "packet:08", "packet:15"]
adrs: ["ADR-0044", "ADR-0043"]
accepts: ["ADR-0044"]
wave: 4
initiative: adr-0044-cloud-code-review
node: honeydrunk-actions
---

# Build the D9 audit-sample post-merge labeling and audit job

## Summary
Build the post-merge job that selects every Nth agent-authored merged PR, labels it `audit-sample`, runs `/ultrareview` against the merged diff, and commits the audit report to `generated/post-merge-audits/` in `HoneyDrunk.Architecture` — activating ADR-0044 D9's sampling audit (Phase 4).

## Target Workflow
**File:** a new post-merge workflow (e.g. `.github/workflows/job-audit-sample.yml`) and its caller wiring
**Family:** post-merge / manual

## Motivation
ADR-0044 D9 establishes a post-merge sampling audit that measures the review process's own quality — without this loop, review-process drift would surface only as production incidents. D11 Phase 4 activates D9. The job: select every Nth agent-authored merged PR (N=10 to start, tunable via the weekly briefing per ADR-0043), label it `audit-sample`, run `/ultrareview` against the merged diff, commit the report, and convert `Block`/`Request Changes` findings into Reactive packets.

## Proposed Change

### Selection + labeling
- Triggered on PR `closed` with `merged == true`.
- The job determines the PR's authorship class (from the `Authorship:` line — only `agent-*` and `mixed` PRs are eligible; `human` PRs are not sampled, per D9 "every Nth agent-authored merged PR").
- It maintains a counter of agent-authored merges; every Nth (N=10 default, read from a single configurable constant — the weekly briefing tunes it per ADR-0043) the PR is selected.
- The selected PR is labeled `audit-sample` (the label exists Grid-wide via packet 08).

### Audit run
- For a selected PR, the job runs `/ultrareview` against the merged PR's diff (deeper multi-agent cloud review, billed separately per D8's `/ultrareview` reference).
- The output is committed to `HoneyDrunkStudios/HoneyDrunk.Architecture` at `generated/post-merge-audits/{YYYY-MM-DD}-{repo}-{pr-number}.md` (directory created by packet 15). The commit uses the GitHub App token from packet 02 (the App has Contents: Read on Architecture — **the commit needs Contents: Write**; see Human Prerequisites — the App's permission must be widened, or a separate write-scoped credential used).

### Reactive-packet conversion
- Findings at `Block` or `Request Changes` severity become Reactive packets per ADR-0043's Reactive source taxonomy. If ADR-0043's Reactive pipeline is live, emit into it; if not, the job opens a tracking issue tagged for Reactive-packet scoping and the dispatch plan notes the dependency.

## Consumer Impact
- Every repo's merged agent PRs are eligible for sampling — but only 1-in-N is audited, so per-repo cost impact is small.
- Audit reports accumulate in `HoneyDrunk.Architecture/generated/post-merge-audits/`.

## Breaking Change?
- [ ] Yes
- [x] No — post-merge, additive; does not affect the PR pipeline or merges.

## Acceptance Criteria
- [ ] A post-merge job triggers on PR `closed` + `merged`, eligible only for `agent-*`/`mixed` authorship
- [ ] Every Nth eligible PR (N=10 default, single configurable constant) is labeled `audit-sample`
- [ ] The job runs `/ultrareview` against the selected merged PR's diff
- [ ] The audit report commits to `HoneyDrunk.Architecture/generated/post-merge-audits/{YYYY-MM-DD}-{repo}-{pr-number}.md`
- [ ] `Block`/`Request Changes` findings convert to Reactive packets (via ADR-0043's pipeline if live, else a tracking issue)
- [ ] `docs/CHANGELOG.md` updated; `docs/consumer-usage.md` notes the post-merge audit job
- [ ] N is documented as tunable via the weekly briefing per ADR-0043

## Human Prerequisites
- [ ] **Widen the GitHub App permissions** — packet 02's App has Contents: Read on `HoneyDrunk.Architecture`; committing audit reports needs Contents: Write. Either widen that App's permission or provision a separate write-scoped credential for the audit-commit step. Update `infrastructure/review-agent-credentials-setup.md` accordingly.
- [ ] Confirm `/ultrareview` is available as an invocable surface from CI and confirm its separate billing is acceptable within the D5 cost ceiling
- [ ] Decide the initial N (D9 says 10) and where the constant lives

## Dependencies
- `packet:03` — `job-review-agent.yml` (soft — shares the Claude Agent SDK runtime and credential plumbing).
- `packet:08` — Grid-wide labels (**hard** — `audit-sample` must exist before the job applies it).
- `packet:15` — `generated/post-merge-audits/` directory (**hard** — the audit report has nowhere to commit without it).

## Referenced ADR Decisions

**ADR-0044 D9** — Every Nth agent-authored merged PR (N=10, tunable via the weekly briefing) is `audit-sample`-labeled at merge; the audit runs `/ultrareview`; output commits to `generated/post-merge-audits/{YYYY-MM-DD}-{repo}-{pr-number}.md`; `Block`/`Request Changes` findings become Reactive packets per ADR-0043; the audit measures review-process quality, feeding back into `review.md` and the ADR.
**ADR-0044 D11 Phase 4** — D9 activates in Phase 4.
**ADR-0043** — Reactive source taxonomy; the weekly briefing tunes N.

## Constraints
> **Invariant 8:** Secret values never appear in logs. The GitHub App credentials and Anthropic key used by the audit job must never be echoed.

> **Invariant 9:** Vault is the only source of secrets. The audit-commit credential is resolved from Vault via the CI secrets surface.

- **Only agent-authored PRs are sampled.** `human` PRs are not part of the D9 population.
- **N is a single configurable constant.** The weekly briefing tunes it; do not hardcode it in multiple places.
- The cross-repo commit needs write scope — do not assume packet 02's read-only App suffices.

## Labels
`ci`, `tier-2`, `ops`, `adr-0044`, `wave-4`

## Agent Handoff

**Objective:** Build the D9 post-merge `audit-sample` job — select every Nth agent-authored merged PR, label it, run `/ultrareview`, commit the report to `generated/post-merge-audits/`, and convert serious findings to Reactive packets.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Activate D9's sampling audit so the review process measures its own quality.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 4.
- ADRs: ADR-0044 (D9, D11 Phase 4), ADR-0043 (Reactive source, briefing-tuned N).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` (soft), `packet:08` (hard), `packet:15` (hard).

**Constraints:**
- Only agent PRs sampled; N is one configurable constant; the cross-repo commit needs write scope.

**Key Files:**
- `.github/workflows/job-audit-sample.yml` (new)
- `docs/CHANGELOG.md`, `docs/consumer-usage.md`

**Contracts:** Commits to `HoneyDrunk.Architecture/generated/post-merge-audits/`; consumes the `audit-sample` label and the `/ultrareview` surface.
