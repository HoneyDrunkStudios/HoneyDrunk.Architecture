---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ci-cd", "meta", "adr-0032", "wave-1"]
dependencies: []
adrs: ["ADR-0032"]
wave: 1
initiative: adr-0032-pr-validation-policy
node: honeydrunk-actions
---

# CI Change: Blocking coverage gate + non-blocking outdated-NuGet summary section in `pr-core.yml`

## Summary
Convert the decorative coverage number in the PR Validation Summary into a **blocking gate** for test-bearing repos (patch ≥ 75%, no-regress vs. committed `.github/coverage-baseline.json`, flat 70% absolute floor, clean skip when no test project), and add a **non-blocking ⚠️ outdated-NuGet** section to the same summary — all implemented once in the `HoneyDrunk.Actions` reusable workflows and consumed by every Node via `workflow_call`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
Today `pr-core.yml`'s `pr-summary` job calls the `pr/generate-summary` composite action with `include-coverage: 'true'`, producing a "Code Coverage: X%" line that is purely informational. A separate reusable workflow `job-coverage-analysis.yml` exists but is (a) **not wired into** `pr-core.yml`, (b) only emits `::warning::` and never fails (its `passed=false` output is dead — nothing consumes it), and (c) measures only whole-solution coverage, with no patch coverage and no regression detection. The net effect: a PR can add a large block of untested code, the summary prints a number, and nothing blocks the merge. In a Grid where AI agents author most implementation, an advisory coverage signal erodes one untested PR at a time.

Separately, outdated (non-vulnerable) NuGet packages have no PR-time surface at all — the author never sees "while you're here, these are behind" without leaving the PR.

This packet closes both gaps in one workflow change, owned by the Actions control plane. Policy lives once in Actions; Nodes get it for free.

## Architecture decisions this packet implements (the executor has no access to the ADR)

The governing ADR (`adr-0032` in runtime packet-data terms) decides the following. They are binding on this implementation:

- **The gate applies only to solutions containing at least one unit test project.** "Contains a test project" is detected from the solution/project graph: a `.Tests` or `.Canary` project (per the Grid testing invariant — tests live only in `.Tests`/`.Canary` projects), **or** a non-empty coverage assembly that survives the existing ReportGenerator filter `-assemblyfilters:+*;-*.Tests`. When **no** test project is present, the gate is **skipped entirely**, the PR is **not blocked on coverage**, and the summary states exactly **`Coverage gate: skipped (no test projects)`** so the skip is visible, never silent.
- **When the gate applies, three conditions are evaluated. A PR fails validation if ANY ONE is violated:**
  - **D1 — Patch coverage ≥ 75%.** Changed and added executable lines in the PR diff must be ≥ 75% covered. Deleted lines do not count. Denominator = coverable added/changed lines in the diff; numerator = the subset the test run covered. **75% is a tunable workflow input named `patch-coverage-threshold`, default `75`** — a caller may override per-repo; the Grid-wide default is changed by editing the reusable workflow default. Adjusting it is a tier-2 CI config change, not an architecture change — no new ADR for tuning.
  - **D2 — No-regress.** Total solution line coverage on the PR must be **≥ the repo's last recorded coverage**, read from a committed file **`.github/coverage-baseline.json`** at the caller repo root (containing at minimum the last accepted total line-coverage percentage and the commit SHA it was measured at). A PR that lowers whole-solution coverage relative to the prior baseline fails even if its own patch coverage is fine. If the baseline file is **absent** (first-ever run / newly test-bearing repo), the no-regress condition is **treated as satisfied** for that run and the post-merge step seeds the file. Absence is a one-time bootstrap state, not a recurring escape hatch.
  - **D3 — Absolute floor.** Total solution line coverage must be **≥ 70%**, a single flat Grid-wide number, exposed as workflow input `absolute-coverage-floor`, default `70`. Repos currently below 70% **will fail this condition (go red) by design** until backfilled — that red state is the intended forcing function and must not be suppressed with a per-repo or ramping floor.
- **Post-merge baseline ratchet.** On a successful push to the default branch (post-merge), a step in the reusable workflow rewrites `.github/coverage-baseline.json` with the new measured total + commit SHA and commits it back to the default branch as a bot commit (contents-write scoped, `[skip ci]`-style so the commit-back does not re-trigger CI). A PR that improves coverage thereby ratchets the baseline up on merge; a PR that must legitimately lower coverage edits the baseline file **in the same PR** as an explicit reviewable diff.
- **OQ3 — commit-back must not race.** The post-merge commit-back can race rapidly-merged PRs. The commit-back step **must** use rebase-and-retry or a "skip if no change" guard — **a naive `git push` is explicitly forbidden** by this packet. Concretely: fetch + rebase the baseline change onto the latest default-branch tip and retry on push rejection (bounded retries, e.g. 3), and short-circuit with no commit if the recomputed baseline value is byte-identical to what is already committed.
- **D4 — outdated NuGet never fails the build.** The presence of newer (non-vulnerable) package versions **must not** fail `pr-core.yml`, must not produce a failing check, and must not affect the coverage gate. This is a hard constraint, restated so update detection cannot be accidentally coupled to a failing exit code. (Vulnerable packages continue to block at High+ via the existing `dependency-scan` job — unchanged by this packet.)
- **D5 — non-blocking ⚠️ outdated-packages section.** The PR Validation Summary gains a ⚠️ section listing outdated packages as `PackageName: current → latest`. Its presence **never** changes the summary's pass/fail icon and **never** sets a failing check. It is the PR-time mirror of the durable per-repo issue maintained by packet 02.

## Wire-vs-fold decision (resolved here — do not re-litigate at execution time)

**Decision: fold the coverage-gate logic into `pr-core.yml`'s existing `pr-summary` job; do NOT wire `job-coverage-analysis.yml` into the tier-1 path.**

Rationale:
- `job-coverage-analysis.yml` is a separate `workflow_call` job with its own `actions/download-artifact` of `coverage-reports` and its own ReportGenerator pass. Wiring it as an 8th `needs:` job in `pr-core.yml` would (a) duplicate the artifact download the `pr-summary` job *already* does (`coverage-reports-${{ inputs.runs-on }}` → `TestResults`), (b) re-run ReportGenerator a second time, and (c) split the verdict across a job boundary, forcing a fragile `needs.coverage.outputs.passed` plumbing that the current `job-coverage-analysis.yml` does not even expose as a job output (it only writes a step output). The `pr-summary` job already has the coverage Cobertura XML in `TestResults`, already checks out `HoneyDrunk.Actions`, and already owns the summary markdown — it is the natural home for the verdict.
- The patch-coverage computation needs the **PR diff**, which `pr-summary` can obtain (`git diff` against the PR base) without a second checkout dance. `job-coverage-analysis.yml` has no diff context today and would need it added anyway.
- ADR-0011's tiered-jobs factoring says reusable workflows orchestrate steps; steps do one thing. Coverage gating is one thing and it belongs adjacent to where the coverage artifact already lands. Keeping it in `pr-summary` preserves the single-verdict semantics and the parallelism `pr-core.yml` already exploits across its other six jobs.

**Disposition of `job-coverage-analysis.yml`:** it is left in the repo but **deprecated in place** — add a top-of-file comment marking it superseded by the `pr-core.yml` `pr-summary` coverage gate (cite the runtime packet-data identifier `adr-0032`, **not** the ADR number, per Grid doc convention) and noting it is retained only for any external/manual caller until a follow-up removes it. Do not delete it in this packet (removing a `workflow_call` entrypoint is a separate blast-radius concern). Do not extend it.

## Proposed Implementation

### A. New coverage-gate logic, folded into `pr-core.yml`'s `pr-summary` job

Add workflow inputs to `pr-core.yml`'s `on.workflow_call.inputs`:

```yaml
patch-coverage-threshold:
  description: 'Minimum % of added/changed executable lines that must be covered (D1). Tunable; no ADR needed to change.'
  required: false
  type: number
  default: 75

absolute-coverage-floor:
  description: 'Flat Grid-wide minimum total line coverage % (D3). Policy intent: stays flat across the Grid.'
  required: false
  type: number
  default: 70
```

In the `pr-summary` job, **after** the existing `Download coverage reports artifact (if exists)` step and **before** `Generate PR summary`, add a step `Coverage gate` that:

1. **Detects test-bearing-ness.** Determine whether the solution contains at least one `.Tests`/`.Canary` project, OR whether the ReportGenerator pass over the downloaded Cobertura with `-assemblyfilters:+*;-*.Tests` yields a non-empty covered assembly set. If not test-bearing → set `gate=skipped`, emit nothing that fails, and record the literal summary line `Coverage gate: skipped (no test projects)`. Stop here for this step (do not evaluate D1–D3).
2. **Computes total line coverage** from the Cobertura XML already in `TestResults` (reuse the ReportGenerator JsonSummary path the existing `job-coverage-analysis.yml` uses, or parse `line-rate` from `coverage.cobertura.xml` directly the way `pr/generate-summary` already does — be consistent with one method and document it inline).
3. **Computes patch coverage (D1).** Obtain the PR diff of added/changed lines (`git diff --unified=0` against the PR base ref — the base is available as `github.event.pull_request.base.sha`; ensure the base is fetched). Intersect added/changed executable line numbers per file with the per-line hit data in the Cobertura report. `patch_covered / patch_coverable * 100`. If `patch_coverable == 0` (the diff touches no executable lines — e.g. docs/markdown/yaml only), D1 is **treated as satisfied** (vacuously — there is nothing to cover). Emit `Patch coverage: N% (M/K changed executable lines)` or `Patch coverage: n/a (no executable lines changed)`.
4. **Evaluates D2 (no-regress).** Read `.github/coverage-baseline.json` from the caller checkout. If absent → D2 satisfied (bootstrap), record `Baseline: none (bootstrap — will be seeded on merge)`. If present → parse the recorded total; D2 fails if `current_total < recorded_total` (strict; equal is OK — "≥").
5. **Evaluates D3 (floor).** D3 fails if `current_total < absolute-coverage-floor`.
6. **Verdict.** If `gate=skipped` → pass, no effect on icon. Else the gate **fails** (non-zero, propagated as a job failure that turns the check red) if **any** of D1/D2/D3 is violated. The failing reason(s) must be explicit in the summary, e.g. `Coverage gate: FAILED — patch 61% < 75% (D1); total 64% < 70% floor (D3)`. If all satisfied → `Coverage gate: passed — patch N%, total T% (baseline B%, floor 70%)`.
7. **The gate's pass/fail must drive the overall PR check result.** Extend the existing `Determine overall status` step so a coverage-gate failure sets `icon=:x:` / `status=Failed` exactly like a failed `build-and-test`. The coverage verdict is binding for test-bearing repos (per the new invariant this ADR adds on acceptance).

### B. Post-merge baseline ratchet (new job in `pr-core.yml` OR a sibling reusable workflow step)

Because `pr-core.yml` runs on `workflow_call` triggered by consumers on `pull_request`, the post-merge ratchet must run on **push to the default branch**, not on the PR. Add a guarded job `coverage-baseline-ratchet` to `pr-core.yml` that:

- `if:` runs only when `github.event_name == 'push'` and `github.ref == 'refs/heads/' + default branch`. (Consumers already invoke `pr-core.yml` on `pull_request`; this packet additionally documents — in `docs/consumer-usage.md`, see below — that consumers should also invoke it on `push` to the default branch for the ratchet to fire. If a consumer only wires `pull_request`, the ratchet simply never runs and the baseline never seeds — the gate then permanently treats D2 as bootstrap-satisfied for that repo, which is safe but means D2 is inert there; call this out in consumer-usage docs.)
- Recomputes total line coverage from a fresh test run's Cobertura (the push build's coverage artifact).
- Writes `.github/coverage-baseline.json` with `{ "totalLineCoverage": <number>, "commit": "<sha>", "measuredAtUtc": "<iso8601>" }`.
- **OQ3-safe commit-back:** `git add .github/coverage-baseline.json`; if `git diff --cached --quiet` (no change) → exit 0 with no commit. Else commit with message `chore: ratchet coverage baseline to <pct>% [skip ci]`, then `git fetch origin <default>` + `git rebase origin/<default>` + `git push`, retrying the fetch/rebase/push up to 3 times on push rejection; on exhausted retries, log a warning and exit 0 (the next post-merge run self-heals — do not fail the push build over a baseline race).
- Permissions: this job needs `contents: write`. Scope it to the job, not the workflow top level (the rest of `pr-core.yml` stays `contents: read`).

### C. Extend `pr/generate-summary` composite action for the coverage-gate verdict and the ⚠️ outdated-NuGet section (D5)

`pr/generate-summary/action.yml` currently prints `### :bar_chart: Code Coverage: X%` only when a number is present. Extend it with two new optional inputs and corresponding rendering:

```yaml
coverage-gate-verdict:
  description: 'Pre-computed coverage-gate verdict line (e.g. "passed — patch 82%, total 76% ...", "skipped (no test projects)", or "FAILED — patch 61% < 75% (D1)")'
  required: false
  default: ''
outdated-packages-markdown:
  description: 'Pre-rendered non-blocking outdated-NuGet section body (PackageName: current → latest lines), or empty if none/not collected'
  required: false
  default: ''
```

Rendering rules:
- If `coverage-gate-verdict` is non-empty, render a `### Coverage Gate` block showing the verdict line verbatim (the caller — the `Coverage gate` step in `pr-core.yml` — composes the exact wording so the policy text lives in one place). When the verdict starts with `FAILED`, render it with a `:x:`; with `skipped` render `:fast_forward:`; with `passed` render `:white_check_mark:`. The icon here is **decorative within the section**; the *overall* summary icon is still driven by the `Determine overall status` step in `pr-core.yml` (B/A.7 above), not by this composite.
- If `outdated-packages-markdown` is non-empty, render a `### :warning: Outdated Packages (non-blocking)` block followed by the provided lines and the literal sentence `These do not block this PR. Tracked per-repo in the 📦 Outdated Dependencies issue.` This section's presence **must never** change the pass/fail icon (enforce by construction — this composite does not compute the overall icon).

**Source of the outdated-package list at PR time:** run `dotnet list <target> package --outdated --format json` (or reuse the existing `deps/report-dotnet` composite action which already produces this) inside the `pr-summary` job as a `continue-on-error: true` step whose failure or emptiness simply yields an empty `outdated-packages-markdown`. It must be impossible for this step to fail the job (D4): wrap it so a non-zero exit is swallowed and produces empty output.

### D. `docs/consumer-usage.md` update

Document: the two new inputs (`patch-coverage-threshold`, `absolute-coverage-floor`), the `.github/coverage-baseline.json` artifact (what it is, that it is bot-maintained, that a deliberate regression is a hand-edit in the same PR), the requirement to also trigger `pr-core.yml` on `push` to the default branch for the ratchet, and the explicit note that a repo wiring only `pull_request` leaves D2 inert (bootstrap-satisfied) but D1/D3 still active.

## Affected Files
- `.github/workflows/pr-core.yml` (new inputs, `Coverage gate` step, `coverage-baseline-ratchet` job, status wiring)
- `.github/actions/pr/generate-summary/action.yml` (new inputs + rendering for the verdict block and the ⚠️ outdated section)
- `.github/workflows/job-coverage-analysis.yml` (deprecation header comment only — not deleted, not extended)
- `docs/consumer-usage.md`
- `CHANGELOG.md` (Actions repo root)

## NuGet Dependencies
None. Pure GitHub Actions / shell / `dotnet` CLI already available on the runner. `dotnet-reportgenerator-globaltool` is already installed by the existing coverage path.

## Boundary Check
- [x] Lives in `HoneyDrunk.Actions` — the Grid CI/CD control plane; PR-validation policy belongs here once, consumed by every Node.
- [x] No per-repo policy logic added; thresholds are reusable-workflow inputs.
- [x] No code contract surface; behavioral contract is the summary shape + the gate exit semantics.
- [x] `.github/coverage-baseline.json` is written **in consumer repos** by the reusable workflow, not in Actions itself — consistent with "the code lives where the work lives."

## Acceptance Criteria
- [ ] `pr-core.yml` exposes `patch-coverage-threshold` (default `75`) and `absolute-coverage-floor` (default `70`) as `workflow_call` inputs.
- [ ] A `Coverage gate` step runs in the `pr-summary` job, after the coverage-artifact download, before summary generation.
- [ ] When the solution has no `.Tests`/`.Canary` project and no non-empty covered assembly, the gate is skipped, the PR is not blocked on coverage, and the summary contains the literal line `Coverage gate: skipped (no test projects)`.
- [ ] When test-bearing: D1 evaluated as patch coverage of added/changed executable lines from the PR diff vs. `patch-coverage-threshold`; a diff touching no executable lines is treated as D1-satisfied with `Patch coverage: n/a (no executable lines changed)`.
- [ ] When test-bearing: D2 reads `.github/coverage-baseline.json`; absent ⇒ satisfied + summary says bootstrap; present ⇒ fails if current total < recorded total (equal passes).
- [ ] When test-bearing: D3 fails if current total < `absolute-coverage-floor`.
- [ ] A violation of **any** of D1/D2/D3 fails the PR check (red), with the specific failing condition(s) named verbatim in the summary; all-satisfied produces an explicit pass line with patch %, total %, baseline %, floor %.
- [ ] The coverage-gate failure propagates through the `Determine overall status` step so the overall summary icon and the required-check conclusion are `Failed` (binding for test-bearing repos).
- [ ] A `coverage-baseline-ratchet` job runs only on push to the default branch, rewrites `.github/coverage-baseline.json` (`totalLineCoverage`, `commit`, `measuredAtUtc`), and commits it back with `[skip ci]` in the message.
- [ ] The commit-back uses fetch + rebase + bounded retry (≤3) and a "skip if no change" guard; a naive `git push` is **not** used; an exhausted-retry race logs a warning and exits 0 (does not fail the push build).
- [ ] The `coverage-baseline-ratchet` job declares job-scoped `contents: write`; the rest of `pr-core.yml` remains `contents: read`.
- [ ] `pr/generate-summary` accepts `coverage-gate-verdict` and `outdated-packages-markdown`; renders a `### Coverage Gate` block and a `### :warning: Outdated Packages (non-blocking)` block; neither block changes the overall pass/fail icon.
- [ ] The PR-time outdated-package collection step is `continue-on-error`/exit-swallowed such that it can **never** fail the `pr-summary` job or set a failing check (D4 verified by deliberately breaking the step locally and confirming the job still passes).
- [ ] `job-coverage-analysis.yml` carries a top-of-file deprecation comment referencing the runtime packet-data identifier `adr-0032` (not the ADR number) and is otherwise unchanged (not deleted, not extended).
- [ ] `docs/consumer-usage.md` documents the two inputs, the baseline file, the push-trigger requirement for the ratchet, and the "pull_request-only ⇒ D2 inert" caveat.
- [ ] Repo-level `CHANGELOG.md` gets a new version entry (this is the bumping packet for this initiative on the Actions solution) summarizing the coverage gate + outdated-NuGet summary section.
- [ ] No ADR number appears in any workflow comment, README prose, or `consumer-usage.md` body (runtime packet-data identifier `adr-0032` is acceptable only as a packet-data reference, not embedded in shipped doc/code prose).

## Human Prerequisites
- [ ] **Branch protection re-confirmation.** After this lands, for each test-bearing repo, the `PR Core` required status check now carries a binding coverage verdict. No portal change is required (the check name is unchanged), but the operator should be aware that test-bearing repos under 70% will start failing the required check until their backfill packet (this initiative, packets 03+) lands. This is intended per the ADR.
- [ ] **No secret provisioning required.** The post-merge ratchet uses the default `GITHUB_TOKEN` with job-scoped `contents: write`; no PAT is needed for same-repo commit-back.

The code-change critical path is fully delegable. Actor=Agent.

## Dependencies
None. This is the lead packet of the initiative and is independent of the per-repo backfill. The backfill packets (03+) are blocked by this one (the gate must exist before "go green against the gate" is meaningful), but this packet is blocked by nothing.

## Labels
`feature`, `tier-2`, `ci-cd`, `meta`, `adr-0032`, `wave-1`

## Agent Handoff

**Objective:** Ship the blocking coverage gate (D1–D3, skip-when-no-tests) and the non-blocking ⚠️ outdated-NuGet summary section in the `HoneyDrunk.Actions` reusable PR-validation workflow.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Convert the decorative PR coverage number into a binding gate for test-bearing repos and surface outdated packages at PR time without blocking.
- Feature: Grid-wide PR Validation Policy (runtime packet-data id `adr-0032`), Part 1 (coverage gate) + Part 2 D4/D5 (NuGet flagging).
- ADRs: ADR-0032 (metadata only — executor has no access; all binding decisions are inlined above).

**Acceptance Criteria:** As listed above.

**Dependencies:** None — lead packet.

**Constraints:**
- **The gate applies only to solutions with at least one unit test project.** No-test solutions skip the gate entirely; the PR is not blocked on coverage; the summary must literally say `Coverage gate: skipped (no test projects)` so the skip is visible, not silent.
- **D4 — available (non-vulnerable) NuGet updates never fail validation.** The outdated-package detection step must be structurally incapable of failing the job or setting a failing check. Vulnerable packages continue to block via the existing `dependency-scan` job (do not touch that).
- **OQ3 — the post-merge baseline commit-back must use rebase-and-retry / skip-if-no-change.** A naive `git push` is explicitly forbidden. An exhausted race retry must not fail the push build (the next run self-heals).
- **Grid testing invariant (inlined):** "No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only." Use this as the basis for test-project detection.
- **Grid versioning invariant (inlined):** "Semantic versioning with CHANGELOG and README. ... Repo-level `CHANGELOG.md` ... Every version that ships must have an entry here." This is the bumping packet for the Actions solution in this initiative.
- **Doc convention:** do not embed the ADR number in workflow comments, README prose, or `consumer-usage.md`. The runtime packet-data identifier `adr-0032` is acceptable only as a packet-data reference.
- Fold the gate into `pr-core.yml`'s `pr-summary` job. Do **not** wire `job-coverage-analysis.yml` into the tier-1 path; deprecate it in place with a header comment only.

**Key Files:**
- `.github/workflows/pr-core.yml` — the `pr-summary` job already downloads the coverage artifact and checks out Actions; the gate folds in here. Reference its `Determine overall status` step for status wiring.
- `.github/actions/pr/generate-summary/action.yml` — already parses Cobertura `line-rate`; extend with the two new inputs.
- `.github/workflows/job-coverage-analysis.yml` — ReportGenerator + JsonSummary parsing pattern to reuse for total-coverage computation; deprecate, do not extend.
- `.github/actions/deps/report-dotnet/action.yml` — reuse for the PR-time outdated-package list (already produces `current → latest` data).
- `.github/workflows/nightly-deps.yml` — reference for how `report-dotnet` is invoked.

**Contracts:** No code/NuGet contract. Behavioral contracts: (1) the gate exit semantics (any of D1/D2/D3 violated ⇒ red, for test-bearing repos only); (2) the summary block shapes (`### Coverage Gate`, `### :warning: Outdated Packages (non-blocking)`); (3) `.github/coverage-baseline.json` shape `{ totalLineCoverage, commit, measuredAtUtc }` — this is the consumer-repo artifact every other repo's gate reads.
