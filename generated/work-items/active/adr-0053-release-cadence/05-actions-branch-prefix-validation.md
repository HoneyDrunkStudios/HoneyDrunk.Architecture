---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "adr-0053", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0053", "ADR-0032", "ADR-0044", "ADR-0011"]
accepts: ["ADR-0053"]
wave: 2
initiative: adr-0053-release-cadence
node: honeydrunk-actions
---

# Add branch-prefix validation to `pr-core.yml` per D5

## Summary
Amend `pr-core.yml` in `HoneyDrunk.Actions` with a branch-prefix validation step that asserts the PR's head branch matches the canonical prefix set from ADR-0053 D5: human prefixes `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `release/`; AI prefixes `codex/`, `copilot/`, `claude/`. PRs from `main`, from forks, and from Dependabot are exempt. The check is advisory in Phase 1 (warning) and flips to a hard failure in Phase 2 once every Grid repo's open branches are conforming.

## Context
ADR-0053 D5 commits the canonical branch-prefix convention. The PR-validation policy (ADR-0032) and the AI-PR discipline ADR (ADR-0044) both *presume* the prefix convention to route their respective review checklists. ADR-0053 D5 makes the convention explicit and adds: "**The CI workflow filters in HoneyDrunk.Actions (per ADR-0012) can fan out different jobs by prefix (e.g., AI-authored branches may run additional review canaries).**"

The validation step lives in `pr-core.yml` — the tier-1 gate per ADR-0011 D2 / invariant 31. It runs on every PR (every PR traverses tier 1 before merge), so the prefix check sees every branch that ever opens a PR.

**Two-phase rollout for the validation severity.**
- **Phase 1 (this packet)** — the check runs as a **warning** that emits a `::warning::` annotation in the PR-summary section but does not fail the workflow. The reason: at the moment this packet lands, open PRs may already exist with non-conforming branch names; failing them would block merges and force a renaming pass. The warning surfaces the deviation and gives the operator time to either rename the branch or accept the deviation as a one-off.
- **Phase 2 (later)** — flip the check to **error** severity once every Grid repo's open PRs are conforming. The flip is a one-line change in `pr-core.yml`; a follow-up packet (not in this initiative) authors it.

The check's regex covers the full D5 set plus `release/` for the D4 carve-out (release branches are permitted for emergency hotfix isolation). Dependabot's auto-generated branches (`dependabot/...`) are explicitly exempt because Dependabot is third-party and the prefix is not under operator control. Fork PRs are also exempt because the head branch lives in a fork and the operator does not own the fork's naming.

**This is a workflow/YAML packet. No .NET project.** `HoneyDrunk.Actions` is not a versioned .NET solution — no version bump. The repo's `CHANGELOG.md` is updated per the existing repo convention.

## Scope
- `.github/workflows/pr-core.yml` — add a `branch-prefix-validation` step (warning-severity in Phase 1).
- `docs/consumer-usage.md` — document the prefix set and the Phase 1/Phase 2 severity rollout.
- The repo `CHANGELOG.md` — dated SemVer entry.

## Proposed Implementation
1. **New step in `pr-core.yml`.** Add a step (or a small job, depending on the file's structure — match the existing organization) that:
   - Reads the PR's head branch name from the `pull_request` event (`github.head_ref`).
   - Skips the check on:
     - Fork PRs: `github.event.pull_request.head.repo.full_name != github.repository`.
     - Dependabot: `github.actor == 'dependabot[bot]'` or `github.head_ref` starts with `dependabot/`.
     - The `main` branch itself (which should never open a PR-into-`main`, but handle the edge case).
   - Asserts `github.head_ref` matches the regex:
     ```
     ^(feat|fix|chore|docs|refactor|release|codex|copilot|claude)/.+
     ```
     Note: `claude/{agent-slug}-{token}` per D5 still matches `^claude/.+` — the agent-slug and token are part of the path.
   - On a miss in **Phase 1**: emit a `::warning::` annotation with text like "Branch name `<name>` does not match the canonical prefix set from ADR-0053 D5 (`feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `release/`, `codex/`, `copilot/`, `claude/`). The check is currently advisory; it will flip to a hard failure in Phase 2. See `docs/consumer-usage.md` for the rollout plan." Exit code 0 — the workflow does not fail.
   - On a match: log "Branch prefix OK: `<name>` matches the canonical set" and exit 0.
2. **Severity-flip plan documented in `docs/consumer-usage.md`.** The doc records the prefix set, the Phase 1 warning behavior, the conditions for the Phase 2 flip ("every Grid repo's open PRs conform"), and a note that the flip is a one-line `pr-core.yml` change.
3. **The check is part of the orchestration `pr-core.yml`** — it does not replace any existing job; it is additive. Existing tier-1 jobs (build, unit tests, analyzers, vulnerability scan, secret scan per invariant 31) are unchanged.
4. **Permissions.** The step needs no special permission — `github.head_ref` is available on the `pull_request` event without authentication.

## Affected Files
- `.github/workflows/pr-core.yml`
- `docs/consumer-usage.md`
- The repo `CHANGELOG.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — `pr-core.yml` lives here per ADR-0012 and is the Grid's tier-1 gate per ADR-0011.
- [x] No code change in any Node — `pr-core.yml` is reusable; the check rides on every Grid repo's existing PR pipeline.

## Acceptance Criteria
- [ ] `pr-core.yml` carries a branch-prefix validation step that matches the D5 regex (`^(feat|fix|chore|docs|refactor|release|codex|copilot|claude)/.+`)
- [ ] The step emits a `::warning::` annotation on a miss in Phase 1; it does **not** fail the workflow
- [ ] Fork PRs are skipped (`head.repo.full_name != github.repository`)
- [ ] Dependabot is skipped (`github.actor == 'dependabot[bot]'` or branch starts with `dependabot/`)
- [ ] The step has no impact on existing tier-1 jobs (build, unit tests, analyzers, vulnerability scan, secret scan) — additive only
- [ ] `docs/consumer-usage.md` documents the prefix set, the Phase 1 warning behavior, and the Phase 2 severity-flip plan (one-line change in `pr-core.yml`)
- [ ] The repo `CHANGELOG.md` is updated per the existing convention with a dated SemVer entry
- [ ] No new credential, no secret in the workflow (invariant 8)
- [ ] No `.csproj` version bump — workflow-only

## Human Prerequisites
- [ ] None to land this packet itself. After it merges, the warning surfaces on every non-conforming open PR Grid-wide. The operator's follow-up: either rename non-conforming branches or accept the warning as one-off until the Phase 2 flip.
- [ ] Phase 2 (the severity flip from warning to error) is a separate follow-up packet, not in this initiative. It lands when every Grid repo's open PRs conform.

## Referenced ADR Decisions
**ADR-0053 D5 — Branch-naming convention.** Human prefixes `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`; AI prefixes `codex/`, `copilot/`, `claude/{agent-slug}-{token}`; `release/{node}-{semver}` permitted for emergency hotfix isolation per D4. "The CI workflow filters in HoneyDrunk.Actions (per ADR-0012) can fan out different jobs by prefix."

**ADR-0053 D16 Phase 4 — Branch-lifetime tooling.** "Stale-PR alert workflow (D6); auto-close-after-30-days workflow (D6); branch-prefix validation in CI (D5)." Packet 04 ships the first two; this packet ships the third.

**ADR-0032 — PR validation policy.** Tier-1 gate jobs run on every PR; this packet adds a step to the orchestrator.

**ADR-0044 — AI-PR discipline.** The branch prefix is one signal the review-routing logic in `pr-core.yml` (and downstream cloud agents) inspects to route the AI-vs-human review checklist.

**ADR-0011 — Code review and merge flow.** `pr-core.yml` is the tier-1 gate per invariant 31; the branch-prefix check is additive to the existing tier-1 jobs.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** The branch-prefix check needs no credential; nothing is committed.

> **Invariant 31 — Every PR traverses the tier-1 gate before merge.** The branch-prefix check is *part of* the tier-1 gate — it runs on every PR via `pr-core.yml`. Phase 1 makes the check advisory (warning); Phase 2 makes it blocking.

- **Phase 1 is advisory only.** A `::warning::` annotation, never a workflow failure. The severity flip to a hard error is a separate Phase 2 follow-up packet.
- **Fork and Dependabot exempt.** The operator does not control the fork's branch naming or Dependabot's auto-generated branches; the check skips both.
- **Additive to existing tier-1 jobs.** No existing job is renamed or removed.
- **Plain regex match.** No fuzzy matching, no auto-rename suggestion in Phase 1 — the warning text suffices.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `adr-0053`, `wave-2`

## Agent Handoff

**Objective:** Add a branch-prefix validation step to `pr-core.yml` per ADR-0053 D5; advisory-only in Phase 1; the Phase 2 severity flip is a follow-up.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Surface non-conforming branch names on every PR so operators see the deviation; the warning is the lever, the Phase 2 flip is the long-run enforcement.
- Feature: ADR-0053 Environments, Branching, and Release Cadence rollout, Wave 2.
- ADRs: ADR-0053 D5/D16 Phase 4 (primary), ADR-0032 (PR validation policy), ADR-0044 (AI-PR discipline), ADR-0011 (tier-1 gate).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0053 should be Accepted before its branch-prefix check lands.

**Constraints:**
- Phase 1 is advisory (`::warning::`), never a workflow failure.
- Fork PRs and Dependabot exempt.
- Additive to existing tier-1 jobs; no rename or removal.
- Plain regex match; no fuzzy matching in Phase 1.

**Key Files:**
- `.github/workflows/pr-core.yml`
- `docs/consumer-usage.md`
- `CHANGELOG.md`

**Contracts:** None — workflow step only.
