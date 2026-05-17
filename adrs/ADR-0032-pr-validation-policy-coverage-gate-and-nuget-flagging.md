# ADR-0032: Grid-Wide PR Validation Policy — Coverage Gate and NuGet Update Flagging

**Status:** Proposed
**Date:** 2026-05-17
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

ADR-0012 names `HoneyDrunk.Actions` as the Grid CI/CD control plane: the reusable workflows every Grid repo consumes via `workflow_call` are the single implementation point, and shared policy lands once in Actions rather than drifting across eleven-plus repos. ADR-0011 names `pr-core.yml` as the tier-1 PR gate (build, tests, analyzers, vulnerability scan, secret scan). ADR-0009 governs package scanning and draws the line that *vulnerable* packages block PRs (High+) while merely *outdated* packages are a non-blocking maintenance concern surfaced out-of-band, and explicitly rejects per-package Dependabot PRs in favor of grouped `nightly-deps` automation for a solo developer with eleven-plus repos.

Two gaps remain in that picture, and both are policy decisions that belong in one ADR because both are PR-validation behavior owned by the Actions control plane:

**1. Coverage is reported but not gated.** Today `pr-core.yml`'s `pr-summary` job generates the PR Validation Summary via the `pr/generate-summary` composite action with `include-coverage: 'true'`, producing a "Code Coverage: X%" line. A separate reusable workflow `job-coverage-analysis.yml` also exists and computes total line/branch coverage against a `coverage-threshold` input (default 80), but it (a) is *not wired into* `pr-core.yml`, (b) only emits a `::warning::` and never fails — `passed=false` does not propagate to a failing check, and (c) measures only whole-solution coverage, with no notion of patch coverage (did *this PR's changed lines* get tested) and no notion of regression (did total coverage *drop* relative to the last known good). The net effect: a PR can add a large block of untested code, the summary prints a coverage number, and nothing blocks the merge. For a Grid where AI agents author most implementation, "tests are advisory" means coverage erodes silently.

**2. Outdated NuGet packages have no single tracked surface per repo.** Per ADR-0009 D3/D5, `nightly-deps.yml` runs weekly, reports outdated packages as artifacts and a step summary, and does *not* create per-package PRs (`create-update-prs: false`, no Dependabot). But the report lives only in workflow artifacts and a run summary — there is no durable, in-place, per-repo surface a human or agent can look at to answer "what's behind in this repo right now," and the PR Validation Summary says nothing about outdated packages at all. ADR-0009 already decided the *blocking* posture (outdated never blocks); what is missing is the *visibility* mechanism, analogous to how ADR-0012 D6 made pipeline health centrally visible without making it blocking.

This ADR resolves both as one PR Validation Policy, owned by the Actions control plane, implemented once in the reusable workflows, consumed by every Node. Sector is **Meta**, consistent with ADR-0009, ADR-0011, and ADR-0012: this is process architecture for the Grid's execution machinery, not system topology.

This ADR depends on ADR-0009 (Accepted — the outdated-vs-vulnerable split and the no-Dependabot, grouped-nightly-deps posture), ADR-0011 (Proposed — `pr-core.yml` is the tier-1 gate and the PR Validation Summary is the single place a human looks first), and ADR-0012 (Proposed — Actions is the CI/CD control plane and the reusable workflow is the single implementation point).

## Decision

The PR Validation Policy has two parts: a **blocking coverage gate** (Part 1) and **non-blocking NuGet update flagging** (Part 2). Both are implemented in the reusable workflows in `HoneyDrunk.Actions` and consumed by every Node via `workflow_call`; no per-repo policy logic is added.

### Part 1 — Coverage gate (blocking)

The PR Validation Summary already reports build status, test pass/fail, and a "Code Coverage: X%" line. This ADR adds a **coverage gate** that runs as part of the `pr-core.yml` tier-1 path. The gate evaluates three conditions. A PR **fails validation if any one of the three is violated**.

The gate applies **only to solutions that contain at least one unit test project**. A solution with no test projects skips the gate entirely and the PR is not blocked on coverage. This is deliberate: it does not punish repos that have no tests yet, and it does not force test scaffolding as a precondition for unrelated work. "Contains a test project" is detected from the solution/project graph (a `.Tests` or `.Canary` project per invariant 16, or a project producing a coverage assembly that survives the existing `-assemblyfilters:+*;-*.Tests` ReportGenerator filter being non-empty). When no test project is present, the summary states "Coverage gate: skipped (no test projects)" so the skip is visible, not silent.

When the gate does apply, the three conditions are:

#### D1 — Patch coverage ≥ 75% (tunable parameter)

Changed and added lines in the PR diff must be at least **75%** covered by tests. Deleted lines do not count. The denominator is the set of executable (coverable) added/changed lines in the diff; the numerator is the subset of those lines the test run covered.

**75% is a stated, tunable policy parameter, not a hard architectural constant.** It is surfaced as a workflow input (proposed name `patch-coverage-threshold`, default `75`) so it can be adjusted Grid-wide by editing the reusable workflow's default, or per-repo by a caller override, without a new ADR. Adjusting it is a CI configuration change (tier 2), not an architecture decision. The patch threshold is set deliberately *above* the 70% absolute floor (D3) because new code is the cheapest code to test (it is being written right now, with the author in context), and holding new code to a higher bar than the whole-solution floor is the mechanism that *drives* total coverage upward over time rather than merely holding it at the floor.

#### D2 — No-regress: total solution coverage must not drop below the repo's last recorded coverage

Total solution coverage on the PR must be **greater than or equal to** the repo's last recorded coverage value. A PR that lowers whole-solution coverage relative to the prior baseline fails the gate, even if its own patch coverage is acceptable (this catches deleting tests, or adding code paths that dilute the ratio without the diff itself being undertested).

The workflow needs a place to read the previous coverage from. **The mechanism is a committed baseline file: `.github/coverage-baseline.json` at the caller repo root**, containing at minimum the last accepted total line-coverage percentage and the commit SHA it was measured at. The gate reads this file on PR runs to obtain the prior value. On a successful push to the default branch (post-merge), a step in the reusable workflow rewrites `.github/coverage-baseline.json` with the new measured total and commits it back to the default branch (a `[skip ci]`-style bot commit, contents-write scoped). A PR that legitimately improves coverage thereby ratchets the baseline up on merge; a PR that legitimately must lower coverage (rare, e.g. removing a whole subsystem) updates the baseline file *in the same PR* as an explicit, reviewable diff — making the regression a conscious, audited act rather than a silent slide.

If the baseline file is absent (first-ever run for a repo, or a newly test-bearing repo), the no-regress condition is treated as satisfied for that run, and the post-merge step seeds the file. Absence is a one-time bootstrap state, not an escape hatch — once seeded, the file exists and the condition is live.

Rejected mechanism for the prior value: **reading the last successful default-branch run's coverage via `gh api` / artifacts.** Workflow artifacts have a retention window (30 days here) and run history is queryable but not atomically versioned with the code. A committed baseline file versions the number *with the commit it describes*, makes the ratchet visible in `git log`, makes a deliberate regression a reviewable diff, and has no API-rate or retention dependency. This mirrors ADR-0012 D2's reasoning for committed shared config over release-asset/raw-URL config.

#### D3 — Absolute floor: total solution coverage ≥ 70% (flat, Grid-wide)

Total solution coverage must be **≥ 70%**. This is a single flat Grid-wide number, not per-repo and not ratcheting. It is a workflow input (proposed name `absolute-coverage-floor`, default `70`) for the same tunability reason as D1, but the policy intent is that it stays flat across the Grid.

**Repos currently below 70% will fail this condition (go red) until their coverage is backfilled. This is intended and accepted.** The red state is the signal that drives the backfill work; suppressing it with a per-repo ratchet or a lower starting number would defeat the purpose. This ADR does **not** introduce a per-repo floor or a phased ramp for D3 — the floor is 70%, flat, now.

### Part 2 — NuGet update flagging (non-blocking)

#### D4 — Available NuGet updates never fail the build

Consistent with ADR-0009 (outdated ≠ vulnerable; outdated is a maintenance concern with no SLA and no PR block), the presence of newer package versions **must not** fail `pr-core.yml`, must not produce a failing check, and must not affect the coverage gate. This is a hard constraint, restated here so the implementing workflow change cannot accidentally couple update detection to a failing exit code.

#### D5 — PR Validation Summary gains a non-blocking ⚠️ outdated-packages section

The PR Validation Summary (generated by the `pr/generate-summary` composite action, consumed in `pr-core.yml`'s `pr-summary` job) gains a non-blocking ⚠️ section listing outdated packages as `PackageName: current → latest`. This section is informational only: its presence never changes the summary's pass/fail icon and never sets a failing check. It is the PR-time mirror of the durable per-repo surface in D6 — it tells the author "while you're here, these are behind" without gating their unrelated change.

#### D6 — `nightly-deps` maintains a single grouped tracking issue per repo

The existing `nightly-deps.yml` workflow (ADR-0009 D3/D5; `create-update-prs` stays `false`, no Dependabot, no per-package PRs) is extended to **open or update exactly one grouped tracking issue per repo** enumerating all outdated packages (`PackageName: current → latest`, grouped by project where useful). One issue per repo, found-or-created by a stable title (proposed: `📦 Outdated Dependencies`), body fully replaced in place on every run — the same idempotent find-or-update-by-stable-title pattern ADR-0012 D6 uses for the `🕸️ Grid Health` issue. **Not one issue per package. Not one PR per package.** When the outdated set becomes empty, the issue is closed automatically; when packages fall behind again, it is reopened/recreated under the same title. This is the durable, in-place, per-repo visibility surface ADR-0009 implied but never named.

The issue lives in the repo whose packages are outdated (the code lives where the work lives, per invariant 23), is created/updated by `nightly-deps.yml` running in that repo, and requires the `issues: write` caller permission already part of the canonical `nightly-deps.yml` caller `permissions:` block in ADR-0012 D5.

## Consequences

### Architectural / Process Consequences

- **The PR Validation Summary becomes a gate, not just a report, for test-bearing repos.** Today coverage is decorative. After this ADR, a test-bearing repo's PR can fail solely on coverage (patch < 75%, total regressed, or total < 70%). The summary remains the single place a human looks first (ADR-0011 D8); it now carries a binding verdict for the coverage dimension.
- **Repos with no test projects are unaffected.** The skip condition is explicit and visible in the summary. No repo is forced to scaffold tests as a side effect of this policy.
- **A new committed artifact, `.github/coverage-baseline.json`, exists in every test-bearing repo.** It is bot-maintained on default-branch merges and human-editable only as a deliberate, reviewed regression. It is small, versioned with the code, and visible in `git log`.
- **`nightly-deps` gains a write responsibility** (one grouped issue per repo) on top of its current report/artifact output. This is consistent with ADR-0009's grouped, low-noise, no-Dependabot posture and ADR-0012's idempotent-issue pattern.
- **Outdated packages remain explicitly non-blocking** at PR time, preserving the ADR-0009 outdated-vs-vulnerable boundary. Vulnerable packages continue to block per ADR-0009 (unchanged by this ADR).
- **Policy lives once in Actions.** The thresholds (75% patch, 70% floor) and the gate logic are in the reusable workflows; Nodes consume them via `workflow_call` and get the policy for free, per ADR-0012 D1. Tuning a threshold Grid-wide is a one-line default change in Actions, not an eleven-repo edit.
- This is a **Tier 2** change per `catalogs/flow_tiers.json` ("CI workflow changes" — plan-then-execute, PR-reviewed, no new ADR required for subsequent threshold tuning).

### Required Follow-Up Work (scoped as separate issue packets — not written here)

Accepting this ADR creates the following implementation obligations. Each is a discrete issue packet authored by the scope agent; this ADR does not write the packets.

1. **Change the reusable PR validation workflow in `HoneyDrunk.Actions`.** Wire a coverage-gate step into `pr-core.yml`'s tier-1 path (likely by promoting/replacing `job-coverage-analysis.yml` so it computes patch coverage from the PR diff, reads/writes `.github/coverage-baseline.json`, enforces D1–D3 with a *failing* exit code instead of `::warning::`, and skips cleanly when no test project is present), and extend the `pr/generate-summary` composite action to render the coverage-gate verdict and the non-blocking ⚠️ outdated-packages section (D5).
2. **Change `nightly-deps.yml`** to open/update/close the single grouped per-repo `📦 Outdated Dependencies` tracking issue (D6), reusing the existing `deps/report-dotnet` / `deps/consolidate-reports` composite actions for the package data and the ADR-0012-D6-style find-or-update-by-stable-title pattern for the issue.
3. **Per-repo coverage backfill** for every test-bearing repo currently under the 70% absolute floor (D3). Each such repo goes red on first run of the new gate by design; the backfill packets are the work that drives the red back to green. Scope is per-repo and sized against each repo's current gap; not enumerated here.

### New Invariant (added on acceptance)

On acceptance, the implementing packet adds the following invariant to `constitution/invariants.md`. **The invariant number is assigned by the implementing packet at acceptance, not fixed here**, per the established workflow where final invariant numbers are assigned when an initiative lands. Numbers **44** (audit-emission boundary) and **45–46** are already reserved by the ADR-0030 / ADR-0031 audit-substrate initiative and must not be reused here; this invariant takes the next free number after those reservations (47 unless an intervening ADR lands first). The implementing packet must run a hard number-collision scan against `constitution/invariants.md` before committing and place the invariant in the appropriate themed section, consistent with the file's section organization:

> **Test-bearing repos enforce the coverage gate at PR time.** For any solution containing at least one unit test project, a PR fails tier-1 validation if patch coverage is below the policy threshold, total coverage regressed below the committed `.github/coverage-baseline.json` value, or total coverage is below the Grid-wide absolute floor. Solutions with no test projects skip the gate. Available (non-vulnerable) NuGet updates never fail validation; they surface as a non-blocking PR-summary section and a single grouped per-repo tracking issue. See ADR-0032.

This invariant takes effect when this ADR is accepted (status flips to Accepted after the implementing PR merges, per the established ADR workflow — it is **not** Accepted on first draft).

## Open Questions / Flagged Inconsistencies

**OQ2 — Patch 75% vs. floor 70% interaction during backfill.** A repo below the 70% floor will fail D3 on every PR until backfilled, *even for PRs whose own patch coverage clears 75%*. This is the intended forcing function (D3 says so explicitly), but it means that during the backfill window, the patch gate (D1) is effectively dead weight for sub-floor repos — every PR fails on D3 regardless of D1. Not a defect, but implementers should not be surprised that D1's signal is masked by D3 until a repo crosses the floor. No change requested; noted so the backfill packets can sequence floor-crossing work first.

**OQ3 — Baseline file write contention.** D2's post-merge bot commit to `.github/coverage-baseline.json` on the default branch can race with rapidly merged PRs (commit-back lands after the next PR already branched off the old baseline). Low probability for a solo developer's merge cadence, and self-healing (the next post-merge run rewrites it), but the implementing packet should use a rebase-and-retry or "skip if no change" guard on the commit-back step rather than a naive push. Implementation detail, flagged so it is not discovered as a flaky-CI incident later.

## Alternatives Considered

### Make coverage advisory (warn-only), as it is today

Rejected. This is the status quo (`job-coverage-analysis.yml` emits `::warning::` and never fails). In a Grid where AI agents author most implementation, an advisory coverage signal is one nobody is contractually forced to act on, and coverage erodes one untested PR at a time. The whole point of this ADR is to convert the existing decorative number into a gate. Advisory posture is correct for LLM-reviewer stages (ADR-0011 D5) because they are non-deterministic and cost money per run; coverage is deterministic and free, so the cost/correctness trade-off that justifies advisory for the review agent does not apply here.

### Per-repo or ratcheting absolute floor instead of a flat 70%

Rejected by explicit user direction. A per-repo or phased floor would let sub-70% repos stay green and remove the pressure that drives backfill. The flat 70% with intended red states *is* the mechanism. The no-regress condition (D2) already provides per-repo ratcheting *upward* from each repo's own baseline; D3 is the flat floor that no repo may sit below long-term. The two together give "never go backward from where you are" (D2) plus "everyone must reach at least here" (D3) without a per-repo floor.

### Read prior coverage from the last successful default-branch run (artifacts / `gh api`) instead of a committed baseline file

Rejected. Artifacts expire (30-day retention here); run history is queryable but the number is not versioned atomically with the commit it describes, a deliberate regression is invisible in `git diff`, and there is a `gh api` rate/availability dependency. A committed `.github/coverage-baseline.json` versions the number with its commit, makes the ratchet auditable in `git log`, makes an intentional regression a reviewed PR diff, and has no external dependency — the same reasoning ADR-0012 D2 used to prefer committed shared config over release-asset/raw-URL config.

### One tracking issue per outdated package, or per-package update PRs (Dependabot)

Rejected, and already rejected by ADR-0009 D5. A solo developer with eleven-plus repos and dozens of dependencies each would drown in per-package issues or PRs. D6's single grouped per-repo issue, updated in place by stable title, is the minimum-noise surface consistent with ADR-0009's grouped-nightly-deps posture and ADR-0012 D6's idempotent-issue pattern.

### Block PRs on available (non-vulnerable) package updates

Rejected, and contradicts ADR-0009. Outdated-without-CVE is a maintenance concern with no SLA; blocking on it creates constant friction with zero security benefit. Vulnerable packages already block at High+ per ADR-0009; that boundary is unchanged here. D4 restates the non-blocking constraint precisely so the implementing workflow cannot accidentally couple update detection to a failing exit code.

### A single combined "quality gate" workflow merging coverage, Sonar, and deps

Rejected on the same factoring grounds as ADR-0012 D-rejected-monolith and ADR-0011's tiered-jobs decision. Reusable workflows orchestrate steps; steps do one thing. Coverage gating, SonarCloud (ADR-0011 D11, separate slot), and dependency flagging have different blocking postures (blocking / blocking-on-public / non-blocking respectively) and different cadences (PR / PR / weekly nightly). Collapsing them into one job loses the independent pass/fail semantics and the parallelism `pr-core.yml` already exploits.
