---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "infrastructure", "adr-0077", "wave-5"]
dependencies: ["packet:03"]
adrs: ["ADR-0077", "ADR-0012"]
wave: 5
initiative: adr-0077-iac-bicep
node: honeydrunk-actions
---

# Add bicep lint to pr-core.yml so PRs touching .bicep or .bicepparam files fail on linter / build-params violations

## Summary
Amend `.github/workflows/pr-core.yml` in `HoneyDrunk.Actions` with a Bicep validation job that runs `bicep lint` against every changed `.bicep` file and `bicep build-params` against every changed `.bicepparam` file in a PR per ADR-0077 D3. Fails the PR on any `error`-severity linter finding (per the `bicepconfig.json` shipped by packet 03) or any `build-params` validation error. Skips cleanly when the PR touches no Bicep files. Applies to PRs in `HoneyDrunk.Actions` (where the modules library lives) and is `workflow_call`-callable so per-Node `pr-core.yml` consumers inherit the gate when their Node has Bicep templates.

> **`bicep lint` does NOT accept `.bicepparam` files.** The CLI's `lint` subcommand operates on `.bicep` template files only — passing a `.bicepparam` file fails the command. Parameter files are validated by `bicep build-params --file <file>.bicepparam`, which expands and type-checks the parameter file against its referenced template. This packet handles the two file kinds with two CLI invocations.

## Context
ADR-0077 D3 commits the enforcement gate:

> **Enforcement:** Bicep linter rules in `bicepconfig.json` flag missing required tags and non-conformant names. CI (per ADR-0012) runs `bicep lint` and fails the PR if linter rules violate.

The Grid's PR-time gate is `pr-core.yml` per ADR-0011 (the canonical Tier-1 gate workflow in `HoneyDrunk.Actions`). Adding a `bicep lint` step there gives per-Node PRs (which call `pr-core.yml` from their own `pr-core.yml`) the gate for free when they have Bicep files; PRs without Bicep files skip the step cleanly.

**Where the rules live.** Packet 03 ships `bicep/bicepconfig.json` in `HoneyDrunk.Actions`. For the Actions repo's own PRs, the config is resolved by Bicep's standard file-system search (templates under `bicep/modules/` find the sibling `bicep/bicepconfig.json`). For per-Node PRs, the per-Node repo can either ship its own `bicepconfig.json` (recommended at first, copying the Actions one) or — if Bicep's config-file resolution allows it — fall back to defaults. Document the per-Node ownership of `bicepconfig.json` in the Bicep template scaffold pattern (packet 08).

**Change detection.** The job runs `bicep lint` on `.bicep` files changed in the PR and `bicep build-params` on `.bicepparam` files changed in the PR. Determine the diff base via this resolution order:
1. `inputs.base-ref` (when set by the calling workflow — required for `workflow_call` consumers whose own context does not naturally expose the PR base SHA).
2. `${{ github.event.pull_request.base.sha }}` (when the workflow runs in a PR event context).
3. `${{ github.event.merge_group.base_sha }}` (when the workflow runs in a merge-queue context).
4. Hard fail with a clear message if none resolve.

`${{ github.event.pull_request.base.sha }}` is the natural path when `pr-core.yml` is triggered on `pull_request` directly. When `job-bicep-lint.yml` is called via `workflow_call` from a consumer's `pr-core.yml`, propagation of `github.event.pull_request.base.sha` depends on the calling workflow's own trigger event — for cases where the consumer workflow is triggered by a non-PR event (manual dispatch, scheduled run, release tag) the base SHA is not present in `github.event`. The `inputs.base-ref` input is the fallback for those cases (consumer passes `base-ref: ${{ github.event.pull_request.base.sha }}` explicitly, or any other ref appropriate to the consumer's flow).

If the diff is empty (no Bicep files touched), the job logs "no Bicep files changed" and exits 0. This keeps the gate fast and avoids re-validating unchanged modules.

**Severity policy.** Fail the PR on any `error`-severity finding from `bicepconfig.json`. `warning`-severity findings are surfaced in the summary but do not fail the build (operator can tighten to error later, per Grid convention for warnings-vs-errors evolution).

**Reusability shape.** Two surfaces:
1. **Direct integration in the Actions repo's `pr-core.yml`** — the Actions repo's own PRs run the step against the modules library.
2. **`workflow_call` shape** — extract the linter logic into a small reusable job (`job-bicep-lint.yml`) that the existing per-Node `pr-core.yml` consumers can opt into. **Recommended approach:** add the reusable `job-bicep-lint.yml` and have `pr-core.yml` consume it; per-Node repos that have Bicep templates add a single `bicep-lint` job to their own `pr-core.yml` consuming `job-bicep-lint.yml`. This keeps the gate composable.

**Bicep CLI availability.** GitHub-hosted `ubuntu-latest` runners do not ship Bicep CLI by default, but `az bicep` is bundled with the `azure-cli` package which IS on `ubuntu-latest`. Use `az bicep install` (idempotent) at the top of the job to ensure the latest Bicep is present. No additional install action needed.

`HoneyDrunk.Actions` is the CI/CD control plane per ADR-0012. This is a workflow/YAML packet — no .NET project, no NuGet.

## Scope
- `.github/workflows/job-bicep-lint.yml` (new) — reusable lint job, `workflow_call`-callable.
- `.github/workflows/pr-core.yml` (amend) — call the new reusable job for the Actions repo's own PRs.
- `docs/consumer-usage.md` (or equivalent) — document how per-Node `pr-core.yml` consumers opt into the gate.
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## Proposed Implementation
1. **`job-bicep-lint.yml`** — new reusable workflow.
   ```yaml
   name: Bicep lint

   on:
     workflow_call:
       inputs:
         paths:
           type: string
           default: '**/*.bicep,**/*.bicepparam'
           description: 'Comma-separated glob patterns to consider. Defaults to all Bicep files in the repo.'
         fail-on-warnings:
           type: boolean
           default: false
           description: 'Treat warning-severity findings as failures. Default false; tighten per-repo later.'
         base-ref:
           type: string
           required: false
           default: ''
           description: 'Optional explicit diff base ref/SHA. When unset, falls back to github.event.pull_request.base.sha then github.event.merge_group.base_sha. Required when the calling workflow_call context does not expose a PR base (e.g. manual dispatch, non-PR triggers).'

   permissions:
     contents: read
   ```
   Single job: `lint`. Runs on `ubuntu-latest`. Steps:
   1. `actions/checkout@v4` with `fetch-depth: 0` (needed for the base-vs-head diff).
   2. **Resolve diff base.** Resolution order: `inputs.base-ref` → `github.event.pull_request.base.sha` → `github.event.merge_group.base_sha`. If none resolve, exit non-zero with a clear message naming `inputs.base-ref` as the required fallback.
   3. **Resolve changed Bicep files.** Use `git diff --name-only $BASE_REF HEAD -- '*.bicep' '*.bicepparam'` (intersected with `inputs.paths` if non-default). Partition the result into two lists: `BICEP_FILES` (`.bicep`) and `BICEPPARAM_FILES` (`.bicepparam`). If both are empty, log "no Bicep files changed" and exit 0.
   4. **Install Bicep.** `az bicep install`. Idempotent; ensures latest.
   5. **Lint each changed `.bicep` file.** Loop over `BICEP_FILES`. For each, run `az bicep lint --file {path} --diagnostics-format sarif > lint-{i}.sarif`. Capture exit codes. **Do NOT pass `.bicepparam` files to `lint`** — the CLI rejects them.
   6. **Build-params each changed `.bicepparam` file.** Loop over `BICEPPARAM_FILES`. For each, run `az bicep build-params --file {path} --stdout > /dev/null`. Capture exit codes. Non-zero exit means parameter-file shape or referenced-template type mismatch — surface to the summary table and fail.
   7. **Aggregate findings.** Parse the SARIF outputs; count `error` and `warning` severities. Combine with the `build-params` exit codes. Write a summary table to `$GITHUB_STEP_SUMMARY` listing per-file findings (with a column distinguishing `lint` vs `build-params` source).
   8. **Fail or pass.** If any `error`-severity lint finding or any `build-params` failure exists, exit non-zero. If `fail-on-warnings=true` and any `warning`-severity finding exists, exit non-zero. Otherwise exit 0.
2. **Amend `pr-core.yml`.** Add a `bicep-lint` job that calls `job-bicep-lint.yml@main` (or the appropriate ref) with default inputs. The job is in parallel with the existing tier-1 build/test jobs — no sequencing.
3. **Document the consumer pattern.** In `docs/consumer-usage.md`, add a section: "Adding `bicep lint` to your Node's `pr-core.yml`." Show the minimal block (just the `bicep-lint: uses: ...job-bicep-lint.yml@main`). Note that per-Node repos with no Bicep templates do not need to wire it; the gate is opt-in by inclusion.
4. **Update the repo `CHANGELOG.md`** if it keeps one for the workflow surface.

## Affected Files
- `.github/workflows/job-bicep-lint.yml` (new)
- `.github/workflows/pr-core.yml` (amend — new `bicep-lint` job)
- `docs/consumer-usage.md` (consumer-pattern section)
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface

## NuGet Dependencies
None. Workflow YAML — no .NET project.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — ADR-0077 D3 names CI per ADR-0012; ADR-0012 places the gate in Actions.
- [x] `pr-core.yml` is the canonical Tier-1 gate per ADR-0011 — the right place to add the linter step.
- [x] No code change in any Node — workflow YAML only.

## Acceptance Criteria
- [ ] `.github/workflows/job-bicep-lint.yml` exists, is `workflow_call`-callable, takes optional `paths`, `fail-on-warnings`, and `base-ref` inputs, and uses `permissions: { contents: read }`
- [ ] The reusable workflow checks out with `fetch-depth: 0` and resolves changed `.bicep` / `.bicepparam` files via `git diff` against the resolved base ref (`inputs.base-ref` → `github.event.pull_request.base.sha` → `github.event.merge_group.base_sha`; hard fail with a clear message if none resolve)
- [ ] If no Bicep files are changed, the workflow logs "no Bicep files changed" and exits 0 — fast skip on PRs that do not touch Bicep
- [ ] `az bicep install` is invoked once (idempotent) to ensure latest Bicep on the runner
- [ ] `az bicep lint --diagnostics-format sarif` runs against each changed `.bicep` file ONLY (the `lint` subcommand does not accept `.bicepparam`); SARIF outputs are aggregated
- [ ] `az bicep build-params --file <path> --stdout > /dev/null` runs against each changed `.bicepparam` file; non-zero exit fails the workflow
- [ ] A summary table is written to `$GITHUB_STEP_SUMMARY` listing per-file findings (severity + rule + message + tool source `lint` or `build-params`)
- [ ] Any `error`-severity lint finding or any `build-params` failure fails the workflow
- [ ] `warning`-severity findings fail the workflow only when `fail-on-warnings=true` (default `false`)
- [ ] `.github/workflows/pr-core.yml` calls `job-bicep-lint.yml` as a parallel job — runs alongside the existing Tier-1 checks, not after
- [ ] `docs/consumer-usage.md` documents the consumer opt-in pattern with a minimal example for per-Node `pr-core.yml`, including when to pass `base-ref` explicitly (non-PR-event triggers)
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow surface
- [ ] An intentionally bad Bicep file in a test PR (e.g. a hardcoded `connectionString` literal, or a resource name not matching the prefix convention) causes the new job to fail; a clean PR passes
- [ ] An intentionally bad `.bicepparam` file (e.g. parameter shape that does not match the referenced template's declared parameters) causes the new job to fail via `build-params`; a clean parameter file passes

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0077 D3 — Linter rules enforced by CI.** "CI (per ADR-0012) runs `bicep lint` and fails the PR if linter rules violate." This packet implements that gate. The rules themselves ship in packet 03's `bicepconfig.json`.

**ADR-0011 — Code review pipeline (Tier-1 gate).** `pr-core.yml` is the canonical Tier-1 gate; new gates land there as parallel jobs.

**ADR-0012 — Actions is the Grid CI/CD control plane.** Reusable workflows live in `.github/workflows/`.

**Invariant 31 — Every PR traverses the Tier-1 gate before merge.** `bicep lint` becomes part of the gate when a PR touches Bicep files; the skip-on-no-Bicep behavior keeps it gracefully no-op otherwise.

## Constraints
- **Reusable shape.** Extract the lint logic into `job-bicep-lint.yml` so per-Node `pr-core.yml` consumers can opt in.
- **Fast skip on no-Bicep.** A PR that touches no `.bicep` / `.bicepparam` files exits 0 in seconds. The gate adds zero cost to non-IaC PRs.
- **Fail on errors; warn on warnings.** `error`-severity findings fail; `warning` does not unless `fail-on-warnings=true` is set per-consumer.
- **No secret access.** The lint job runs `bicep lint` on source files only; it does not need Azure auth (`permissions: { contents: read }` only).
- **Parallel, not sequential.** The new job runs in parallel with the existing Tier-1 jobs in `pr-core.yml` — no `needs:` chain.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `infrastructure`, `adr-0077`, `wave-5`

## Agent Handoff

**Objective:** Add the `bicep lint` PR gate as a new reusable workflow `job-bicep-lint.yml` and wire it into the Actions repo's own `pr-core.yml` (in parallel with existing Tier-1 jobs).

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Enforce ADR-0077 D3's linter gate at PR time across the Grid (Actions for its own modules; per-Node repos opt in via consumer pattern).
- Feature: ADR-0077 IaC — Bicep rollout, Wave 5.
- ADRs: ADR-0077 D3 (primary), ADR-0011 (Tier-1 gate), ADR-0012 (Actions as CI/CD control plane), invariant 31 (Tier-1 gate is mandatory).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — `bicep/bicepconfig.json` exists so the linter has rules to apply. The reusable workflow itself does not depend on the modules existing; it lint any Bicep file the PR touches.

**Constraints:**
- Reusable `job-bicep-lint.yml`, `workflow_call`-only.
- Fast skip on no-Bicep PRs.
- Fail on `error`; warn on `warning` (opt-in via `fail-on-warnings`).
- `permissions: { contents: read }` only — no Azure auth.
- Parallel in `pr-core.yml`, not sequential.

**Key Files:**
- `.github/workflows/job-bicep-lint.yml` (new)
- `.github/workflows/pr-core.yml` (amend)
- `docs/consumer-usage.md`

**Contracts:**
- Workflow inputs: `paths` (default `'**/*.bicep,**/*.bicepparam'`), `fail-on-warnings` (default `false`), `base-ref` (default `''`, optional fallback for the diff base when the workflow_call context does not expose `github.event.pull_request.base.sha`).
- Trigger: `workflow_call` only.
- Behavior: fail on `error`-severity `bicep lint` findings; fail on any `bicep build-params` non-zero exit; otherwise pass. `lint` runs on `.bicep`; `build-params` runs on `.bicepparam` (the CLI's `lint` subcommand does not accept `.bicepparam`).
