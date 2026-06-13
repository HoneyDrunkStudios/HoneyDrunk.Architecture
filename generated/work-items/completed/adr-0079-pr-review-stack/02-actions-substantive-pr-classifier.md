---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "meta", "adr-0079", "wave-2"]
dependencies: ["work-item:00", "work-item:01"]
adrs: ["ADR-0079", "ADR-0044", "ADR-0012"]
accepts: ["ADR-0079"]
wave: 2
initiative: adr-0079-pr-review-stack
node: honeydrunk-actions
---

# Add the ADR-0079 D3 substantive-PR classifier to the PR-review workflow and expose `is_substantive` as a workflow output

## Summary
Add the ADR-0079 D3 substantive-PR classifier to `HoneyDrunk.Actions`'s PR-review workflow surface — a mechanical file-path-glob check that compares a PR's changed files against the canonical safe-list (`*.md`, `*.mdx`, `*.txt`, `docs/**`, `LICENSE*`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `docs/assets/**`) and surfaces a boolean `is_substantive` output that downstream jobs (packet 03's Reviewer 4 trigger) consume to gate themselves.

## Target Workflow
**Files:** `.github/workflows/job-review-request.yml` (and/or its caller `pr-core.yml` — choose the surface where the boolean has the widest correct consumer reach; if both must change to expose the output to the caller, change both).
**Family:** pr-core / review-request.

## Motivation
ADR-0079 D3 commits the substantive-PR classifier as the cost-discipline mechanism for Reviewer 4 — the fourth (Anthropic-native Claude Code) reviewer runs only when the PR is substantive. The classifier is mechanical: a file-path-glob check against the canonical safe-list. Per invariant `{N2}` (packet 00), the classifier carries no LLM judgment, no label-based override, no commit-message escape.

The canonical safe-list lives in **packet 01's cross-cutting policy note** in the `HoneyDrunk.Architecture` repo (single source of truth). The practical default for this workflow — which runs in `HoneyDrunk.Actions`, a sibling repo — is to **embed a documented copy of the safe-list in-workflow** with an explicit `# Source: HoneyDrunk.Architecture/business/context/<safe-list-policy-note>.md` header comment, and to **add a drift-detection CI check** that flags any divergence between the in-workflow copy and the canonical policy note. A cross-repo runtime read of the policy note on every PR is operationally awkward (auth, latency, failure modes) and is not the preferred shape; in-workflow copy + drift CI is the practical default and is the approach this packet specifies.

`HoneyDrunk.Actions` already owns the PR-review trigger rail (`job-review-request.yml` per ADR-0044 packet 03b; `pr-core.yml` aggregates the PR-time jobs per ADR-0012 making Actions the Grid's CI/CD control plane). This packet adds the classifier as a new step (or new job in `pr-core.yml` if the placement is cleaner) and exposes `is_substantive` as a workflow output.

This is a workflow/YAML packet. No .NET project.

## Proposed Change

### Classifier step (mechanical)
A new step that:
1. Reads the safe-list from the in-workflow copy (the practical default — see Motivation). The in-workflow copy carries a `# Source: HoneyDrunk.Architecture/business/context/<safe-list-policy-note>.md` header comment naming the canonical policy note as the source of truth. A separate CI check (see Drift detection below) flags any divergence between the in-workflow copy and the canonical note.
2. Enumerates the PR's changed files via `gh pr diff --name-only` or the equivalent GitHub event payload field.
3. Sets `is_substantive=true` if **any** changed file fails to match **any** safe-list glob; otherwise `is_substantive=false`.
4. Emits `is_substantive` and a list of "files outside safe-list" (for diagnostic logging) as workflow outputs.

The classifier must:
- Apply the safe-list globs case-sensitively or insensitively to match how GitHub normalizes paths (research the convention at execution time; document the choice).
- Treat a deleted file the same as an added or modified file (a deletion of a code file is still a substantive change; a deletion of a docs-only file is still trivial).
- Treat a rename as the union of the source path and the destination path (a rename moving a code file to `docs/` is substantive on the source path).
- Handle the empty-diff edge case (e.g. an empty draft PR or a PR with only commit-message changes) by defaulting to `is_substantive=false` and logging the empty-diff observation — the safe-list's "no file outside the safe-list" rule maps cleanly.

### Output surfacing
`is_substantive` is a workflow output on `job-review-request.yml` so:
- `pr-core.yml` consumers can read it.
- Packet 03's Reviewer 4 trigger workflow gates itself on `needs.<classifier-job>.outputs.is_substantive == 'true'`.
- Diagnostic logging surfaces the list of files outside the safe-list when `is_substantive=true` (helpful when a docs PR turned substantive because of an unintended addition).

### No new credentials, no new secrets
The classifier reads the safe-list (a public-repo file) and the PR's changed files (via the existing `github-token` already used by `job-review-request.yml`). No new credential, no new secret.

### Existing reviewer behavior unchanged
Reviewers 1 (Copilot), 2 (CodeRabbit), and 3 (Grid-aware via Codex/OpenClaw) continue to run on **every** non-draft PR. Per ADR-0079 D9 ("trivial-PR Reviewer 1/2/3 suppression" is explicitly out of scope), the classifier output is consumed **only** by Reviewer 4's trigger (packet 03). Reviewers 1–3 are not gated.

### Drift detection (required — in-workflow copy is the practical default)
The in-workflow safe-list copy is the practical default for the cross-repo case (see Motivation). A separate CI check must flag drift between the workflow's copy and the canonical policy note. This is the same drift-detection pattern ADR-0044 packet 17 established for the D3 review rubric — re-use that pattern's shape (a small script that fetches the canonical source and diffs against the in-workflow copy; fail the check on any difference).

## Consumer Impact
- Existing consumers of `job-review-request.yml` and `pr-core.yml` are unaffected — the classifier step is additive; the new output is consumed only when explicitly read.
- No PR will see any reviewer behavior change as a direct consequence of this packet — the classifier is wired but no downstream gate consumes it yet (packet 03 is the first consumer).
- Diagnostic logging surfaces the classification on every PR (useful for an operator audit and for verifying the safe-list matches intent).

## Breaking Change?
- [ ] Yes
- [x] No — additive classifier step; new workflow output; no behavior change for existing consumers.

## Acceptance Criteria
- [ ] `job-review-request.yml` (or `pr-core.yml`, whichever exposes the output cleanly to consumers) carries a classifier step that reads the in-workflow safe-list copy and outputs `is_substantive` as a boolean
- [ ] The in-workflow safe-list copy carries a `# Source: HoneyDrunk.Architecture/business/context/<safe-list-policy-note>.md` header comment naming the canonical policy note as the source of truth
- [ ] A drift-detection CI check flags any divergence between the in-workflow copy and the canonical policy note (re-use the ADR-0044 packet 17 drift-detection pattern shape)
- [ ] The classifier handles deletions (same as adds/modifies), renames (union of source and destination paths), and empty diffs (default `is_substantive=false`) correctly
- [ ] Diagnostic logging surfaces the list of files outside the safe-list when `is_substantive=true`
- [ ] No new credential or secret is introduced — the classifier reads the in-workflow safe-list copy and the PR's changed files (via the existing `github-token`)
- [ ] No change to Reviewers 1, 2, or 3 — they continue to run on every non-draft PR (ADR-0079 D9)
- [ ] `is_substantive` is exposed as a workflow output that packet 03's Reviewer 4 trigger can consume
- [ ] `docs/consumer-usage.md` (or the equivalent referenced docs) is updated to document the new output
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow surface
- [ ] Existing consumers of the deploy/review workflows are unaffected — additive change only

## Human Prerequisites
- [ ] None for the workflow edit itself.
- [ ] The first **consumer** of `is_substantive` is packet 03's Reviewer 4 trigger; until packet 03 lands and is enabled, this packet's output is informational only.

## Referenced ADR Decisions
**ADR-0079 D3 — Substantive-PR classifier safe-list.** Any PR whose entire changeset is inside `*.md`, `*.mdx`, `*.txt`, `docs/**`, `LICENSE*`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `docs/assets/**` is trivial. Any file outside makes the PR substantive. Mechanical classifier — no LLM judgment, no per-PR override.

**ADR-0079 D9 — Trivial-PR Reviewer 1/2/3 suppression is out of scope.** Reviewers 1, 2, and 3 continue to run on every non-draft PR; only Reviewer 4 (packet 03) is gated on `is_substantive`.

**ADR-0012 — `HoneyDrunk.Actions` is the Grid's CI/CD control plane.** The reusable workflows for PR review are Actions's surface. New cross-cutting CI gates land here.

**Invariant `{N2}` (packet 00) — Substantive-PR classifier is the safe-list in ADR-0079 D3; per-PR override is forbidden.** The classifier carries no label-based override, no commit-message escape, no LLM judgment.

**Invariant 8 (referenced) — Secret values never appear in workflow files.** The classifier authenticates via the existing `github-token`; no new credential is added; no DSN, instrumentation key, or API key is committed.

## Constraints
> **Invariant 31 — Every PR traverses the tier-1 gate before merge.** The classifier is additive — it must not become a required check that can block a merge. Workflow output only.

> **Invariant `{N2}` — Substantive-PR classifier is the safe-list; per-PR override is forbidden.** The classifier is mechanical — no label, no commit-message, no LLM judgment can flip the output. Any future change to the safe-list must come from amending ADR-0079 + updating packet 01's policy note + updating the in-workflow copy in the same coordinated PR set.

- **One source of truth for the safe-list.** The canonical safe-list lives in packet 01's policy note (`HoneyDrunk.Architecture/business/context/`). The in-workflow copy in this packet is a drift-checked mirror, not a parallel source. Drift detection is required, not optional.
- **No new credential.** Reuse `github-token`. No DSN, no API key.
- **Additive, backward-compatible.** Existing consumers of `job-review-request.yml` / `pr-core.yml` are unaffected — the classifier step is new; the output is new; no existing input or output changes shape.
- **Diagnostic logging.** Every PR gets a one-line classification log entry; substantive PRs additionally log the list of files outside the safe-list.

## Labels
`ci`, `tier-2`, `meta`, `adr-0079`, `wave-2`

## Agent Handoff

**Objective:** Add the ADR-0079 D3 substantive-PR classifier as a step in the PR-review workflow surface; expose `is_substantive` as a workflow output for packet 03 (Reviewer 4 trigger) to consume.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Wire the mechanical classifier that distinguishes substantive from trivial PRs. The classifier is the cost-discipline mechanism for Reviewer 4 (per ADR-0079 D2/D3/D6).
- Feature: ADR-0079 Multi-Perspective PR Review Stack rollout, Wave 2.
- ADRs: ADR-0079 D3/D9 (primary), ADR-0044 (the PR-review-workflow baseline), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — hard. The classifier's policy backing (the `{N2}` safe-list-classifier invariant) lands in packet 00.
- `work-item:01` — hard. The canonical safe-list policy note is packet 01's deliverable; this packet's in-workflow copy mirrors it and the drift CI fails against it.

**Constraints:**
- Canonical safe-list in packet 01's policy note; the in-workflow copy is a drift-checked mirror (in-workflow copy + drift CI is the practical default for this cross-repo case).
- Mechanical classifier — no LLM judgment, no per-PR override (invariant `{N2}`).
- No new credential, no new secret (invariant 8).
- Additive, backward-compatible — existing consumers unaffected.

**Key Files:**
- `.github/workflows/job-review-request.yml` (and/or `.github/workflows/pr-core.yml`).
- `docs/consumer-usage.md` (or the equivalent referenced docs).
- `CHANGELOG.md` (if maintained for the workflow surface).

**Contracts:** Exposes `is_substantive` as a workflow output. Packet 03 consumes it.
