---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ci-cd", "ops", "adr-0011", "wave-1"]
dependencies: ["Architecture#NN — ADR-0011 acceptance (packet 01)"]
adrs: ["ADR-0011"]
wave: 1
initiative: adr-0011-code-review-pipeline
node: honeydrunk-actions
---

# Feature: Author `job-sonarcloud.yml` reusable workflow for tier-2 SonarCloud analysis

## Summary
Add a new reusable workflow `job-sonarcloud.yml` in `HoneyDrunk.Actions` that runs `dotnet-sonarscanner` against a .NET repo, publishes coverage to SonarCloud, and reports the SonarCloud quality gate as a check run. The workflow is invoked from each public repo's `pr.yml` (after that repo onboards in Wave 2 / Wave 3) and is gated to only fire on `pull_request` events and pushes to `main`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0011 D11 names SonarCloud as the third-party static analysis tool for tier-2 of the PR review pipeline. The decision contract is fully specified — the workflow plumbing is the only remaining piece. Without `job-sonarcloud.yml` in `HoneyDrunk.Actions`, every per-repo onboarding packet (Kernel, Web.Rest, and the deferred fan-out across the eight remaining .NET repos) would have to inline its own scanner invocation, which violates the existing convention that PR jobs are reusable workflows in Actions and consumer repos call them via `workflow_call`.

This packet ships the workflow alone. It does **not** wire it into `pr-core.yml` and does **not** onboard any specific repo — those are downstream packets. Shipping it standalone keeps the scope tight and lets the per-repo onboarding packets (06, 07, …) reference a real workflow file at the time they author their `sonar-project.properties`.

## Proposed Implementation

Create `.github/workflows/job-sonarcloud.yml` in `HoneyDrunk.Actions` following the structure and conventions of the existing `job-*.yml` reusable workflows (`job-build-and-test.yml`, `job-static-analysis.yml`, `job-codeql.yml`, etc. — all in `.github/workflows/` and exposed via `workflow_call`).

### Workflow shape

```yaml
# ==============================================================================
# Job: SonarCloud Static Analysis (Tier 2)
# ==============================================================================
# Purpose:
#   Run SonarCloud (Sonar Scanner for .NET) against a HoneyDrunk .NET repo,
#   upload coverage from the unit-test run, and report the SonarCloud quality
#   gate as a PR check.
#
# Tier:
#   Tier 2 of the PR review pipeline. Required check on public repos.
#
# CALLER TRIGGER CONTRACT (load-bearing — read this if you are wiring a new caller):
#   This workflow is `workflow_call`-only. It MUST only be invoked from a
#   caller workflow whose `on:` block fires on `pull_request` events or `push`
#   events to `main` — not on every feature-branch push, not on tags, not on
#   schedule, not on workflow_dispatch from arbitrary refs.
#
#   The job below carries an `if:` guard that refuses to run when this
#   constraint is violated, so a misconfigured caller will produce a no-op
#   skipped job rather than burning a SonarCloud run on every feature-branch
#   push. Per ADR-0011 D11 cost discipline.
#
# Cost discipline:
#   - pull_request and push:main only — enforced by both the caller's `on:`
#     block AND the job-level `if:` guard below
#   - Median PR run target: under 60 seconds
#   - Coverage report reused from job-build-and-test.yml output (no second
#     dotnet test run)
# ==============================================================================

name: Job — SonarCloud

on:
  workflow_call:
    inputs:
      dotnet-version:
        description: 'The .NET SDK version to use'
        required: false
        type: string
        default: '10.0.x'
      runs-on:
        description: 'GitHub runner'
        required: false
        type: string
        default: 'ubuntu-latest'
      working-directory:
        description: 'Working directory'
        required: false
        type: string
        default: '.'
      project-path:
        description: 'Solution or project path (auto-detected if blank)'
        required: false
        type: string
        default: ''
      sonar-organization:
        description: 'SonarCloud organization key (e.g. honeydrunkstudios)'
        required: true
        type: string
      sonar-project-key:
        description: 'SonarCloud project key (e.g. honeydrunkstudios_HoneyDrunk.Vault)'
        required: true
        type: string
      sonar-host-url:
        description: 'SonarCloud host URL'
        required: false
        type: string
        default: 'https://sonarcloud.io'
      coverage-artifact-name:
        description: 'Name of the coverage artifact uploaded by job-build-and-test.yml'
        required: false
        type: string
        default: 'coverage-reports-ubuntu-latest'
    secrets:
      sonar-token:
        description: 'SONAR_TOKEN — org-level secret scoped to HoneyDrunkStudios'
        required: true
      github-token:
        description: 'GitHub token for PR decoration'
        required: false

permissions:
  contents: read
  pull-requests: write
  checks: write

jobs:
  sonarcloud:
    runs-on: ${{ inputs.runs-on }}
    # Trigger guard — defence in depth for ADR-0011 D11 cost discipline.
    # Refuses to run when invoked from a misconfigured caller. The expected
    # caller `on:` block is `pull_request` and `push: branches: [main]`.
    # If a caller wires this workflow into a feature-branch push or a tag,
    # this guard reports a skipped job rather than spending a SonarCloud run.
    if: ${{ github.event_name == 'pull_request' || (github.event_name == 'push' && github.ref == 'refs/heads/main') }}

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # SonarCloud needs full history for blame

      - name: Set up .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ inputs.dotnet-version }}

      - name: Set up Java (required by Sonar Scanner)
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Cache SonarCloud packages
        uses: actions/cache@v4
        with:
          path: ~/.sonar/cache
          key: ${{ runner.os }}-sonar
          restore-keys: ${{ runner.os }}-sonar

      - name: Cache SonarCloud scanner
        id: cache-sonar-scanner
        uses: actions/cache@v4
        with:
          path: ./.sonar/scanner
          key: ${{ runner.os }}-sonar-scanner
          restore-keys: ${{ runner.os }}-sonar-scanner

      - name: Install SonarCloud scanner
        if: steps.cache-sonar-scanner.outputs.cache-hit != 'true'
        shell: bash
        run: |
          mkdir -p ./.sonar/scanner
          dotnet tool update dotnet-sonarscanner --tool-path ./.sonar/scanner

      - name: Download coverage artifact (if exists)
        uses: actions/download-artifact@v4
        with:
          name: ${{ inputs.coverage-artifact-name }}
          path: TestResults
        continue-on-error: true

      - name: Begin SonarCloud analysis
        working-directory: ${{ inputs.working-directory }}
        env:
          SONAR_TOKEN: ${{ secrets.sonar-token }}
          GITHUB_TOKEN: ${{ secrets.github-token || github.token }}
        shell: bash
        run: |
          ./.sonar/scanner/dotnet-sonarscanner begin \
            /k:"${{ inputs.sonar-project-key }}" \
            /o:"${{ inputs.sonar-organization }}" \
            /d:sonar.host.url="${{ inputs.sonar-host-url }}" \
            /d:sonar.token="${SONAR_TOKEN}" \
            /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml"

      - name: Build
        working-directory: ${{ inputs.working-directory }}
        shell: bash
        run: |
          if [ -n "${{ inputs.project-path }}" ]; then
            dotnet build "${{ inputs.project-path }}" --configuration Release
          else
            dotnet build --configuration Release
          fi

      - name: End SonarCloud analysis
        working-directory: ${{ inputs.working-directory }}
        env:
          SONAR_TOKEN: ${{ secrets.sonar-token }}
        shell: bash
        run: |
          ./.sonar/scanner/dotnet-sonarscanner end /d:sonar.token="${SONAR_TOKEN}"
```

### Notes the executor must observe

- **No `actions-ref` input.** Other reusable workflows in the suite expose `actions-ref` because they consume sub-actions from `HoneyDrunk.Actions` itself. This workflow does not — its only external consumers are `actions/checkout`, `actions/setup-dotnet`, `actions/setup-java`, `actions/cache`, and `actions/download-artifact`, all of which pin to upstream versions, not to `HoneyDrunk.Actions`. Adding `actions-ref` here would be misleading. If a future revision adds a sub-action that needs a configurable ref, introduce the input then; do not reserve it speculatively.
- **Use the existing `job-build-and-test.yml` output for coverage.** Do not re-run `dotnet test` inside this workflow. The cost-discipline budget in ADR-0011 D11 is "median PR run under 60 seconds" — running tests twice violates that. The `coverage-artifact-name` input lets the caller point at whichever artifact name `job-build-and-test.yml` published.
- **`fetch-depth: 0` is mandatory.** SonarCloud requires full git history for blame attribution. This is documented in SonarCloud's own onboarding docs and is a frequent first-time-setup gotcha.
- **Java is mandatory.** The Sonar Scanner CLI is JVM-based even when scanning .NET. Use Temurin 17 (current LTS); revisit if SonarCloud bumps requirements.
- **Caching has two layers.** (1) `~/.sonar/cache` is the scanner's own download cache. (2) `./.sonar/scanner` is the scanner binary itself, installed via `dotnet tool update`. Both are needed for sub-60-second median runs.
- **Permissions:** `contents: read`, `pull-requests: write`, `checks: write`. The PR-decoration step is part of `dotnet-sonarscanner end`'s built-in PR analysis when `GITHUB_TOKEN` is in the env.
- **Secrets contract:** `SONAR_TOKEN` is **required**. `GITHUB_TOKEN` is optional (falls back to `github.token`).
- **Do NOT add this workflow to `pr-core.yml`** in this packet. That wiring lives in the per-repo onboarding packets (06, 07, and the Wave-3 fan-out), because not every repo onboards at the same time.

### Documentation update

Add a one-line entry to `examples/` if there is a precedent (`examples/library-ci-jobs.yml`-style); otherwise add a usage example as a fenced block in the workflow's header comment block. Match whichever pattern the existing `job-codeql.yml` uses.

## Affected Files
- `.github/workflows/job-sonarcloud.yml` (new)
- Optional: `examples/sonarcloud-usage.yml` if the existing examples convention warrants one (audit `examples/` first; if `job-codeql.yml` has no example file, mirror that and skip)
- `CHANGELOG.md` (repo-level): append entry under in-progress version
- `README.md` (repo-level): if there is a "Available Reusable Workflows" section listing `job-build-and-test.yml`, `job-codeql.yml`, etc., add `job-sonarcloud.yml` to it. If no such section, skip.

## NuGet Dependencies
None. The workflow installs `dotnet-sonarscanner` via `dotnet tool update` into a cache path; no project-level `<PackageReference>` is added.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. The keyword routing rule "workflow, CI, GitHub Actions, pipeline, PR check, release → HoneyDrunk.Actions" maps exactly here.
- [x] No code change in any consuming repo. The wiring into a consumer's `pr.yml` is downstream (per-repo onboarding packets 06, 07, …).
- [x] No new cross-Node dependency. `HoneyDrunk.Actions` continues to be a CI toolkit with no Grid runtime consumers.

## Acceptance Criteria
- [ ] `.github/workflows/job-sonarcloud.yml` exists in `HoneyDrunk.Actions` with the shape specified above
- [ ] Workflow exposes `workflow_call` with the inputs and secrets enumerated above
- [ ] `SONAR_TOKEN` is the only required secret; `github-token` is optional and falls back to `github.token`
- [ ] `fetch-depth: 0` is set on the checkout step
- [ ] Java 17 (Temurin) is installed before the scanner runs
- [ ] Both Sonar caches (`~/.sonar/cache` and `./.sonar/scanner`) are configured
- [ ] Coverage artifact is downloaded from a previous job's upload (`coverage-artifact-name` input) — the workflow does not re-run `dotnet test`
- [ ] PR decoration is enabled by passing `GITHUB_TOKEN` to the scanner steps
- [ ] Permissions block declares `contents: read`, `pull-requests: write`, `checks: write` (no other permissions)
- [ ] Workflow is **not** referenced from `pr-core.yml` in this PR
- [ ] Job-level `if:` guard is present on the `sonarcloud` job: `if: ${{ github.event_name == 'pull_request' || (github.event_name == 'push' && github.ref == 'refs/heads/main') }}`. This is defence-in-depth for ADR-0011 D11's "pull_request and push:main only" rule, so a misconfigured caller produces a skipped job rather than a paid SonarCloud run.
- [ ] Header comment block contains a **CALLER TRIGGER CONTRACT** section documenting the expected caller `on:` block (`pull_request`, `push: branches: [main]`) and noting that the job-level `if:` guard enforces it as defence in depth.
- [ ] Repo-level `CHANGELOG.md`: a new in-progress version entry is created (or appended to, if the prior packet in this initiative already opened one) with a line under `Added` describing the new reusable workflow (per the rule that the first packet in a solution-initiative bumps version, subsequent packets append to the same entry — invariants 12 and 27)
- [ ] Repo-level `README.md`: workflow-list section updated if such a section exists; otherwise skipped (invariant 12)
- [ ] No per-package `CHANGELOG.md` updates required — this is a workflow file, not a package change
- [ ] `.github/workflows/job-sonarcloud.yml` lints clean under `actionlint` (HoneyDrunk.Actions' own `actions-ci.yml` PR check exercises this)

## Human Prerequisites
- [ ] **`SONAR_TOKEN` org-level secret must exist** before this workflow can be exercised by a consumer. Provisioning is covered by packet 04 (SonarCloud organization setup walkthrough). Until packet 04's walkthrough is followed and the secret is provisioned at the org level, this workflow can be merged but cannot run successfully against a real PR. That is acceptable — packet 04 is on the same wave and will land alongside.

## Dependencies
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft dependency: this packet's text references invariants 31 and 33 as live rules. If packet 01 lands first, the references are accurate. If this packet lands first, the references read against (Proposed)-qualifier text. Sequence with packet 01 first.

## Downstream Unblocks
- `06-kernel-sonarcloud-onboarding.md` — Kernel's `pr.yml` will call this reusable workflow.
- `07-web-rest-sonarcloud-onboarding.md` — Web.Rest's `pr.yml` will call this reusable workflow.
- Wave-3 deferred fan-out — Transport, Vault, Auth, Data, Pulse, Notify, Vault.Rotation, Actions all call this same workflow.

## Referenced ADR Decisions

**ADR-0011 (Code Review and Merge Flow):**
- **D2 (tier model):** Tier 1 = build/tests/analyzers/vuln/secret (required). Tier 2 = integration tests + SonarCloud (SonarCloud required on public repos). Tier 3 = LLM reviewers. Tier 4 = E2E. Tier 5 = human.
- **D11 (SonarCloud chosen):** Free for public HoneyDrunk repos. Quality gate is a required branch-protection check on public repos. Native GitHub PR decoration. `dotnet-sonarscanner` CLI used. PR decoration via `SONAR_TOKEN` org secret.
- **D11 contract for the SonarCloud stage:**
  - **Input:** source tree, `sonar-project.properties` at the repo root, coverage report from stage 2 (unit tests), PR diff
  - **Output:** required PR check (quality gate status), inline PR annotations
  - **Owner:** new `job-sonarcloud.yml` in `HoneyDrunk.Actions`, called from `pr-core.yml` tier 2 (wiring lives in per-repo onboarding packets, not in `pr-core.yml`)
  - **Secrets:** `SONAR_TOKEN` as an org secret scoped to `HoneyDrunkStudios`
  - **Cost discipline:** runs only on `pull_request` events and pushes to `main`. Median PR run under 60 seconds.

**ADR-0009 (Package Scanning Policy)** is the precedent for "PR gate jobs are reusable workflows in HoneyDrunk.Actions, called by consumers via `workflow_call`." This packet follows that precedent exactly — `job-sonarcloud.yml` lives where `job-dependency-scan.yml` and `job-codeql.yml` already live.

## Referenced Invariants

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. Bypassing tier 1 via force-push to `main` or admin override is forbidden except for `hotfix-infra` scenarios where the gate itself is broken.

> **Invariant 9 (secrets):** Vault is the only source of secrets. *(Reframed for CI context — `SONAR_TOKEN` lives as a GitHub org-level secret, accessed via the `secrets.` context. This is the GitHub-native equivalent of Vault for CI runtime; the invariant applies to application code reading secrets at runtime, not to CI workflows reading org-level secrets via the `secrets.` context. Calling this out so the executor does not invent a Vault read path inside CI.)*

## Constraints
- **Do not wire this workflow into `pr-core.yml`.** Wiring is per-repo, in each consuming repo's `pr.yml`. `pr-core.yml` is a per-repo orchestrator and adding SonarCloud there would force every repo (including private repos that ADR-0011 D11 explicitly excludes) to fire the workflow.
- **Do not re-run `dotnet test` inside this workflow.** Coverage comes from `job-build-and-test.yml`'s artifact. Cost budget: under 60 seconds median.
- **Use exact secret name `SONAR_TOKEN`.** This is the name documented in packet 04's walkthrough and in SonarCloud's own onboarding docs. Renaming creates a future-rename hazard for the org-secret.
- **Do not commit any token, key, or organization-specific value.** The `sonar-organization` and `sonar-project-key` values are workflow inputs supplied by callers; they are not hardcoded.
- **Permissions block stays minimal:** `contents: read`, `pull-requests: write`, `checks: write`. Anything broader is a finding.
- **`fetch-depth: 0` is non-negotiable.** Shorter depths break SCM blame attribution and silently degrade SonarCloud's PR decoration.
- **Job-level `if:` trigger guard is non-negotiable.** Per ADR-0011 D11, "the stage must only run on `pull_request` events and pushes to `main`. Not on every feature-branch push, not on tags." Caller-side enforcement (the consuming workflow's `on:` block) is the primary line of defence; the job-level `if:` guard is the secondary defence-in-depth line — it ensures a misconfigured caller produces a skipped no-op rather than a paid SonarCloud run on every feature-branch push.
- **Caller trigger contract documented in header.** The CALLER TRIGGER CONTRACT block in the workflow's header comment is the contract surface for new callers; it must stay in sync with the `if:` guard expression.

## Labels
`feature`, `tier-2`, `ci-cd`, `ops`, `adr-0011`, `wave-1`

## Agent Handoff

**Objective:** Ship `.github/workflows/job-sonarcloud.yml` as a new reusable workflow in `HoneyDrunk.Actions` that runs SonarCloud against a .NET repo, reuses coverage from `job-build-and-test.yml`, and exposes the SonarCloud quality gate as a PR check. Do not wire it into `pr-core.yml`. Do not onboard any specific repo here.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Provide the per-repo SonarCloud onboarding packets (Wave 2 + deferred Wave 3) with a real reusable workflow to call.
- Feature: ADR-0011 Code Review Pipeline rollout.
- ADRs: ADR-0011 (primary, D2 tier model + D11 SonarCloud choice), ADR-0009 (precedent for "PR gate jobs are reusable workflows"), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft dependency; sequence with 01 first to keep invariant references live.

**Constraints:**
- **Tier-1 gate is required, tier-2 SonarCloud is required only on public repos** (invariant 31, ADR-0011 D11). The workflow ships ready to run; per-repo wiring decides where it actually fires.
- Do not re-run `dotnet test` inside this workflow — reuse coverage artifact from `job-build-and-test.yml`.
- `fetch-depth: 0` on checkout. Java 17 Temurin. Two Sonar caches.
- Permissions minimal: `contents: read`, `pull-requests: write`, `checks: write`.
- `SONAR_TOKEN` is a required secret; provisioning is packet 04, not this packet.
- Do not commit any token, organization key, or project key as a hardcoded value.

**Key Files:**
- `.github/workflows/job-sonarcloud.yml` (new)
- `.github/workflows/job-build-and-test.yml` (existing — reference its coverage artifact name)
- `.github/workflows/job-codeql.yml` (existing — style reference)
- `.github/workflows/job-dependency-scan.yml` (existing — style reference)
- `CHANGELOG.md` (root)
- `README.md` (root) — if it has a "Reusable Workflows" listing section

**Contracts:** None changed.
