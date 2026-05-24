---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "adr-0053", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0053", "ADR-0044"]
accepts: ["ADR-0053"]
wave: 2
initiative: adr-0053-release-cadence
node: honeydrunk-actions
---

# Author the stale-PR alert and 30-day auto-close workflows per D6

## Summary
Author two scheduled Actions workflows for branch-lifetime discipline per ADR-0053 D6: (1) `nightly-pr-stale-alert.yml` — comments on every open PR that has had no commits in 7 days (stale alert; no automatic closure); (2) `weekly-pr-auto-close.yml` — closes every open PR that has had no activity in 30 days unless it carries the `flagged-keep-open` label. Both workflows live in `HoneyDrunk.Actions` and are reusable across every Grid repo via `workflow_call`.

## Context
ADR-0053 D6 reads: "Target: feature branches merge within 5 working days of first commit. Stale alert: A PR with no commits in 7 days is flagged stale by an Actions workflow (a comment on the PR; no automatic closure at this stage). Auto-close: A branch with no PR activity in 30 days is auto-closed by an Actions workflow unless tagged `flagged-keep-open`. The branch is deleted; the work can re-open under a new branch."

The forcing function (ADR-0053 D6): AI-authored PRs bottleneck on the single human reviewer. Branch lifetime is the only flow-control lever a one-developer-plus-agents shop has; setting it short is deliberate. The 30-day auto-close prevents zombie branches; the `flagged-keep-open` escape hatch handles legitimate long-running work (e.g. the Kernel Adoption Alignment initiative spanned weeks — those PRs get the tag).

The two workflows are reusable across every Grid repo. Each Grid repo's `.github/workflows/` calls them on a schedule (nightly for stale-alert; weekly for auto-close) — the consumer wiring is documented in `docs/consumer-usage.md`. The Grid's existing nightly/weekly cadence (per the existing `nightly-deps.yml`, `nightly-security.yml`, `weekly-governance.yml`) is the precedent.

**This is a workflow/YAML packet. No .NET project.** `HoneyDrunk.Actions` is not a versioned .NET solution — no version bump, no `## NuGet Dependencies`-driven project change. The repo's `CHANGELOG.md` is updated per the existing repo convention.

**The `flagged-keep-open` label is part of the labels-as-code seed.** The label needs to exist in every Grid repo for the auto-close workflow to recognize it. ADR-0044's labels-as-code workflow (per `adr-0044-cloud-code-review` packet 08 — `seed-labels-fanout.yml`) is the seeding mechanism; this packet's acceptance criteria include "the `flagged-keep-open` label is added to the labels-as-code seed list" so the next labels-fanout run propagates it Grid-wide.

## Scope
- `.github/workflows/nightly-pr-stale-alert.yml` (new) — reusable workflow that comments on open PRs with no commits in 7 days.
- `.github/workflows/weekly-pr-auto-close.yml` (new) — reusable workflow that closes open PRs with no activity in 30 days unless `flagged-keep-open`.
- `.github/labels.json` (or the equivalent labels-as-code source — `seed-labels.json` if that is the canonical file in `HoneyDrunk.Actions`) — add the `flagged-keep-open` label entry so the next labels-fanout run propagates it Grid-wide.
- `docs/consumer-usage.md` — document how a Grid repo wires the two workflows (a `nightly-pr-stale-alert.yml` consumer caller; a `weekly-pr-auto-close.yml` consumer caller; both `workflow_call`-based and short).
- The repo `CHANGELOG.md` — dated SemVer entry.

## Proposed Implementation
1. **`nightly-pr-stale-alert.yml` — reusable workflow:**
   - Trigger: `workflow_call` only. Consumers schedule it.
   - Reads every open PR in the calling repo via `gh pr list --state open --json number,updatedAt,labels,headRefName,author`.
   - Filters for PRs where the most recent commit's `committedDate` is older than 7 days. (Use `gh pr view <n> --json commits` and inspect the head commit.) PRs with the `flagged-keep-open` label are skipped (no stale comment on a tagged PR).
   - For each matching PR, checks whether the workflow has already posted a stale comment in the last 24 hours (idempotency — the workflow runs nightly; do not spam). The check uses a hidden marker string in the comment body (e.g. `<!-- pr-stale-alert -->`).
   - On a new match, posts a comment via `gh pr comment` with the marker, the PR's age, and a short note: "This PR has had no commits in 7 days. Per ADR-0053 D6 the 5-day branch-lifetime target has been missed. Either push a commit, request review, or add the `flagged-keep-open` label if this PR is legitimately long-running. PRs with no activity in 30 days are auto-closed by `weekly-pr-auto-close.yml`."
2. **`weekly-pr-auto-close.yml` — reusable workflow:**
   - Trigger: `workflow_call` only. Consumers schedule it weekly.
   - Reads every open PR in the calling repo via `gh pr list`.
   - Filters for PRs where the most recent activity (commits, comments, reviews — `updatedAt` is the canonical signal) is older than 30 days **and** the PR does not carry the `flagged-keep-open` label.
   - For each matching PR, posts a "closing per ADR-0053 D6" comment with a hidden marker (`<!-- pr-auto-close -->`), then closes the PR via `gh pr close --comment` (or `gh pr close` after the comment). The branch is deleted via `gh api -X DELETE ...` (the auto-close behavior per ADR-0053 D6: "The branch is deleted; the work can re-open under a new branch").
   - The closing comment cites the auto-close rule and notes that the work can re-open under a new branch.
3. **Labels-as-code seeding.** Add the `flagged-keep-open` label to whichever file is the canonical labels-as-code source in `HoneyDrunk.Actions` (likely the same source the `seed-labels-fanout.yml` workflow from `adr-0044-cloud-code-review` packet 08 consumes). The label color/description fields follow the existing conventions in that file. Acceptance criterion: the label is recognized by the next labels-fanout run on every Grid repo.
4. **Consumer-usage docs.** `docs/consumer-usage.md` gets two short examples — one for `nightly-pr-stale-alert.yml` (a consumer caller workflow that triggers nightly via `on: schedule: cron: '0 2 * * *'`); one for `weekly-pr-auto-close.yml` (a consumer caller workflow that triggers weekly via `on: schedule: cron: '0 3 * * 1'` — Monday morning UTC).
5. **Permissions.** Both workflows declare `permissions: pull-requests: write, contents: write` (the auto-close workflow needs `contents: write` for the branch deletion). No new credential is required; `GITHUB_TOKEN` covers both.
6. **Dry-run input.** Both workflows accept an optional `dry-run: boolean` workflow_call input (default `false`). When `dry-run` is true, the workflow lists what it *would* do (in the run log) but does not post comments, close PRs, or delete branches. Useful for the first execution on every repo so the operator sees the candidate list before the workflow goes live.

## Affected Files
- `.github/workflows/nightly-pr-stale-alert.yml` (new)
- `.github/workflows/weekly-pr-auto-close.yml` (new)
- `.github/labels.json` (or the equivalent labels-as-code source — name confirmed at edit time)
- `docs/consumer-usage.md`
- The repo `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — the workflows are reusable across every Grid repo per ADR-0012.
- [x] No code change in any Node — Node repos consume the workflows via `workflow_call`; the per-Node wiring lands on each Node's own schedule.

## Acceptance Criteria
- [ ] `nightly-pr-stale-alert.yml` exists as a `workflow_call`-only reusable workflow that comments on open PRs with no commits in 7 days; PRs carrying `flagged-keep-open` are skipped
- [ ] The stale-alert workflow uses a hidden marker in the comment body to avoid double-posting on subsequent runs (idempotent within 24 hours)
- [ ] `weekly-pr-auto-close.yml` exists as a `workflow_call`-only reusable workflow that closes open PRs with no activity in 30 days unless `flagged-keep-open`; the workflow posts a comment with the closing rationale and deletes the branch
- [ ] Both workflows accept an optional `dry-run: boolean` input (default `false`) that logs the candidate list without taking action
- [ ] Both workflows declare the minimum required permissions and use the existing `GITHUB_TOKEN` — no new credential, no secret in the workflow (invariant 8)
- [ ] The `flagged-keep-open` label is added to the labels-as-code source in `HoneyDrunk.Actions` so the next labels-fanout run propagates it Grid-wide
- [ ] `docs/consumer-usage.md` documents both workflows with a sample consumer caller (one nightly, one weekly)
- [ ] The repo `CHANGELOG.md` is updated per the existing convention with a dated SemVer entry
- [ ] No `.csproj` version bump — workflow-only

## Human Prerequisites
- [ ] No portal step required to land this packet itself.
- [ ] After this packet merges, the labels-fanout workflow runs (or is triggered manually) so the `flagged-keep-open` label propagates to every Grid repo before the auto-close workflow is wired onto any Node repo. Without the label, the auto-close workflow's `flagged-keep-open` escape hatch is silently ineffective.
- [ ] The operator wires the two workflows into each Grid repo's `.github/workflows/` on a schedule. The recommended initial run is `dry-run: true` for one week per repo so the candidate list is reviewed before the workflows go live; flip to `dry-run: false` after review.

## Referenced ADR Decisions
**ADR-0053 D6 — Branch lifetime: 5-day target / 7-day stale / 30-day auto-close.** "A PR with no commits in 7 days is flagged stale (a comment on the PR; no automatic closure at this stage). A branch with no PR activity in 30 days is auto-closed unless tagged `flagged-keep-open`. The branch is deleted; the work can re-open under a new branch."

**ADR-0053 D6 — Forcing function rationale.** "AI-authored PRs are bottlenecked on the human reviewer. The longer the queue grows, the harder it is to reason about which PR depends on which; the more drift accumulates between feature branches and `main`; the more rework Codex has to do on stale work. The 5-day target is a flow-control mechanism."

**ADR-0044 — Labels-as-code seed.** The `seed-labels-fanout.yml` workflow propagates label definitions from the canonical labels-as-code source to every Grid repo. The new `flagged-keep-open` label rides this mechanism.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** The workflows use `GITHUB_TOKEN`; no DSN, instrumentation key, or credential is committed.

> **Invariant 11 — One repo per Node.** The reusable workflows live in `HoneyDrunk.Actions`; consumer wiring is a per-repo caller workflow, not duplicate logic.

- **Idempotent stale-alert.** The workflow uses a hidden marker in the comment body to avoid double-posting. Multiple nightly runs against the same stale PR result in one comment, not many.
- **Dry-run by default for the first run.** The `dry-run` input exists specifically so the operator can review the candidate list before the workflows take action. The recommended first-execution path is documented in `docs/consumer-usage.md`.
- **The `flagged-keep-open` escape hatch must be Grid-wide before auto-close goes live.** The labels-fanout run is a hard prerequisite for the auto-close consumer wiring; the consumer-usage doc states this explicitly.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `adr-0053`, `wave-2`

## Agent Handoff

**Objective:** Author the two scheduled workflows for branch-lifetime discipline per ADR-0053 D6 — `nightly-pr-stale-alert.yml` and `weekly-pr-auto-close.yml` — and add the `flagged-keep-open` label to the labels-as-code seed.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Pressure the PR queue toward the 5-day target with a 7-day stale comment and a 30-day auto-close, per ADR-0053 D6's flow-control rationale.
- Feature: ADR-0053 Environments, Branching, and Release Cadence rollout, Wave 2.
- ADRs: ADR-0053 D6 (primary), ADR-0044 (labels-as-code seed mechanism).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0053 should be Accepted before its branch-lifetime workflows land.

**Constraints:**
- Reusable `workflow_call` only — consumer wiring on a schedule lives in each Grid repo's caller.
- Idempotent stale-alert with a hidden marker.
- `dry-run` input default `false`; recommended first execution per repo is `dry-run: true` for one week.
- `flagged-keep-open` label propagates Grid-wide via the labels-fanout mechanism before auto-close goes live.
- Minimum required permissions; reuse `GITHUB_TOKEN`.

**Key Files:**
- `.github/workflows/nightly-pr-stale-alert.yml` (new)
- `.github/workflows/weekly-pr-auto-close.yml` (new)
- The labels-as-code source file
- `docs/consumer-usage.md`
- `CHANGELOG.md`

**Contracts:** None — workflow inputs only.
