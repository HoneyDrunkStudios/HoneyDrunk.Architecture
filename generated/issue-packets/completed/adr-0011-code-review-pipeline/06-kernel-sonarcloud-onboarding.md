---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "ci-cd", "core", "adr-0011", "wave-2"]
dependencies: ["Actions#NN — job-sonarcloud.yml (packet 02)", "Architecture#NN — SonarCloud organization setup (packet 04)"]
adrs: ["ADR-0011"]
wave: 2
initiative: adr-0011-code-review-pipeline
node: honeydrunk-kernel
---

# Feature: Onboard HoneyDrunk.Kernel to SonarCloud (first canonical .NET template)

## Summary
Onboard `HoneyDrunk.Kernel` as the first repo on the Grid's SonarCloud rollout. Add `sonar-project.properties` at the repo root, wire `pr.yml` to invoke the new `job-sonarcloud.yml` reusable workflow from `HoneyDrunk.Actions` after the existing `job-build-and-test.yml` job (so coverage flows through), import the project into SonarCloud via the GitHub App, and add the SonarCloud quality gate as a required branch-protection check on `main`. This packet is the **canonical template** for downstream per-repo onboardings (Web.Rest in packet 07, Wave-3 fan-out for the remaining 8 .NET repos).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Kernel`

## Motivation
ADR-0011 D11 named SonarCloud as the third-party static analysis tool for tier 2 of the PR pipeline, and ADR-0011's Follow-up Work explicitly says "Per-repo SonarCloud onboarding — each public repo adds a `sonar-project.properties` file, imports the project into SonarCloud, and enables the SonarCloud check in branch protection. One packet per active repo."

Kernel is chosen as the first onboarding for three reasons:
1. **Foundation Node.** Kernel is at the root of the dependency graph (`relationships.json` shows zero `consumes`). Making Kernel SonarCloud-clean first means downstream Nodes inherit a clean upstream — quality gate findings on Kernel are contained to Kernel rather than propagating.
2. **Library shape.** Kernel ships the canonical "library + Abstractions + tests" shape that most other Grid repos share. The configuration here becomes the template; Web.Rest (packet 07) covers the ASP.NET Core variant.
3. **Stable.** Kernel is at v0.4.0 stable per `nodes.json`, with canary tests passing. Onboarding to a new tool is most informative when the codebase is not in flux.

## Proposed Implementation

### A. Add `sonar-project.properties`

**File location is critical.** Create `sonar-project.properties` **inside the inner project subdir** at `HoneyDrunk.Kernel/sonar-project.properties` (relative to the git root). This is the same directory that contains `HoneyDrunk.Kernel.slnx`, `HoneyDrunk.Kernel/`, `HoneyDrunk.Kernel.Abstractions/`, and `HoneyDrunk.Kernel.Tests/`. It is **not** at the git repo root next to `LICENSE` and `README.md`.

Why: Kernel's `pr.yml` runs the reusable workflow with `working-directory: 'HoneyDrunk.Kernel'` (verified in `.github/workflows/pr.yml`). The `dotnet-sonarscanner` discovers `sonar-project.properties` from the working directory it begins from, not from the git repo root. If the file is placed at the git root, the scanner will not find it and analysis will run with no project configuration. From inside the working-directory the scanner uses, the file path is `./sonar-project.properties`.

Paths inside `sonar-project.properties` are relative to **that same working directory** (`HoneyDrunk.Kernel/` from git root). So `sonar.sources=HoneyDrunk.Kernel` resolves to the inner runtime project at `HoneyDrunk.Kernel/HoneyDrunk.Kernel/`.

Content:

```properties
# SonarCloud project configuration for HoneyDrunk.Kernel.
# Project imported via the SonarCloud GitHub App; quality gate runs in
# job-sonarcloud.yml (HoneyDrunk.Actions) on every PR and push to main.
#
# This file lives at HoneyDrunk.Kernel/sonar-project.properties (inside the
# inner project subdir, next to HoneyDrunk.Kernel.slnx). All sonar.sources /
# sonar.tests paths are relative to that subdir, which matches the
# working-directory the reusable job-sonarcloud.yml runs from.

sonar.organization=honeydrunkstudios
sonar.projectKey=honeydrunkstudios_HoneyDrunk.Kernel
sonar.projectName=HoneyDrunk.Kernel

# Sources — relative to the working directory (HoneyDrunk.Kernel/)
sonar.sources=HoneyDrunk.Kernel
# Tests — Kernel currently has only HoneyDrunk.Kernel.Tests; no .Canary project
# exists on disk (verified). If a canary project is added later, append it here.
sonar.tests=HoneyDrunk.Kernel.Tests

# Coverage (consumed by job-sonarcloud.yml after job-build-and-test.yml uploads
# the coverlet OpenCover report)
sonar.cs.opencover.reportsPaths=**/coverage.opencover.xml

# Exclusions — generated code and build outputs
sonar.exclusions=**/obj/**,**/bin/**,**/*.Designer.cs

# Coverage exclusions — Abstractions packages contain interfaces only
sonar.coverage.exclusions=**/HoneyDrunk.Kernel.Abstractions/**

# New Code definition — inherits from organization default (30 days)
# Override here only if the Node has a different release cadence than default.
```

The exact source directory paths (`sonar.sources`, `sonar.tests`) must match the actual project layout. The values above were verified against the repo on `2026-04-26` — Kernel has exactly three projects (`HoneyDrunk.Kernel`, `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Kernel.Tests`) under `HoneyDrunk.Kernel/`. If the layout has changed by execution time (e.g. a `Canary` project is added, or `src/HoneyDrunk.Kernel` reorg lands), correct the values to match the current `.slnx` and directory tree before committing.

**Footnote on canary asymmetry:** Web.Rest has both a `.Tests` and `.Canary` project (packet 07 reflects this). Kernel does not have a canary project today. The two packets diverge on `sonar.tests` accordingly — this is intentional and correct. Do not add `HoneyDrunk.Kernel.Canary` to Kernel's `sonar.tests`; the path does not resolve to a project.

### B. Wire `pr.yml`

Kernel's existing `pr.yml` calls `pr-core.yml@main`. Add a second job that invokes `job-sonarcloud.yml` after `pr-core.yml` succeeds, so SonarCloud only runs when tier 1 has passed (per ADR-0011 D2 fail-fast cheap-first):

```yaml
name: PR

on:
  pull_request:
    branches: [ main ]

permissions:
  contents: read

jobs:
  pr-core:
    name: PR Core
    permissions:
      contents: read
      checks: write
      pull-requests: write
      security-events: write
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/pr-core.yml@main
    with:
      dotnet-version: '10.0.x'
      configuration: 'Release'
      runs-on: 'ubuntu-latest'
      working-directory: 'HoneyDrunk.Kernel'
      project-path: 'HoneyDrunk.Kernel.slnx'
      enable-secret-scan: true
      enable-accessibility-check: false
      post-pr-summary: true
      actions-ref: 'main'
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}

  sonarcloud:
    name: SonarCloud
    needs: pr-core
    permissions:
      contents: read
      checks: write
      pull-requests: write
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-sonarcloud.yml@main
    with:
      dotnet-version: '10.0.x'
      runs-on: 'ubuntu-latest'
      working-directory: 'HoneyDrunk.Kernel'
      project-path: 'HoneyDrunk.Kernel.slnx'
      sonar-organization: 'honeydrunkstudios'
      sonar-project-key: 'honeydrunkstudios_HoneyDrunk.Kernel'
      coverage-artifact-name: 'coverage-reports-ubuntu-latest'
    secrets:
      sonar-token: ${{ secrets.SONAR_TOKEN }}
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

Critical wiring details:
- `needs: pr-core` enforces tier-1-before-tier-2 fail-fast (per ADR-0011 D2). SonarCloud is skipped if `pr-core.yml` fails.
- `coverage-artifact-name: 'coverage-reports-ubuntu-latest'` matches the artifact name `pr-core.yml` already publishes.
- `SONAR_TOKEN` flows in from the org-level secret seeded by packet 04.
- `actions-ref: 'main'` follows the existing convention in Kernel's `pr.yml`.

### C. Import the project into SonarCloud

Once the SonarCloud GitHub App is installed on `HoneyDrunkStudios/HoneyDrunk.Kernel` (per packet 04, step 4), the project should auto-appear in the SonarCloud org dashboard at `https://sonarcloud.io/organizations/honeydrunkstudios/projects`. The first-time setup steps (Human Prerequisites below):

1. In SonarCloud, click "Analyze new project" → choose "GitHub" → select `HoneyDrunkStudios/HoneyDrunk.Kernel`.
2. SonarCloud auto-detects the project and creates `honeydrunkstudios_HoneyDrunk.Kernel` as the project key.
3. Choose "With GitHub Actions" as the analysis method (we are not using SonarCloud's own automatic analysis since `job-sonarcloud.yml` runs the scanner).
4. Configure "New Code" definition for the project: leave at organization default (30 days).
5. The first PR run after merging this packet's PR will populate analysis results. Initial findings against the existing v0.4.0 codebase are expected — they are not blockers for this onboarding (ADR-0011 D11 specifies the quality gate becomes enforcing on **new** code, not historical code).

### D. Branch protection — add SonarCloud check (after first run, not before)

This step requires GitHub repo admin and is a Human Prerequisite with **strict ordering**: branch protection can only reference a check that has run at least once. If the rule is added before SonarCloud has published its first check, GitHub rejects the rule with "this check has never run on this branch." So the sequence is:

1. **Merge this packet's PR.** The `sonarcloud` job is now wired into `pr.yml`.
2. **Wait for the first SonarCloud-enabled PR to run** (this can be a follow-up PR or any new PR after the merge). On the first run, the SonarCloud GitHub App publishes a check.
3. **Open the PR's "Checks" tab** and read the **exact check name** the SonarCloud App is publishing. Historically this has been "SonarCloud Code Analysis" but **do not paste this string blindly** — the App's wording can drift across SonarCloud versions or organization config. Copy the literal string from the live Checks UI.
4. Go to `https://github.com/HoneyDrunkStudios/HoneyDrunk.Kernel/settings/branches`.
5. Edit the `main` branch protection rule (or create one if missing).
6. Under "Require status checks to pass before merging," paste the exact check name observed in step 3.
7. Save.

The check is now required. Per ADR-0011 D11, this is the binding part of the SonarCloud onboarding for public repos.

## Affected Files
- `HoneyDrunk.Kernel/sonar-project.properties` (new — inner project subdir, next to `HoneyDrunk.Kernel.slnx`; **not** the git repo root)
- `.github/workflows/pr.yml` (edit — add `sonarcloud` job)
- `CHANGELOG.md` (root): docs entry under in-progress version
- `README.md` (root): no change expected; this is CI wiring, not public API surface

## NuGet Dependencies
None. The Sonar scanner is installed as a tool by the reusable workflow at run time; no project-level `<PackageReference>` is added.

## Boundary Check
- [x] All edits in `HoneyDrunk.Kernel`. Routing rule "context, GridContext, NodeContext, … → HoneyDrunk.Kernel" applies (this is a CI wiring change in Kernel, even though the workflow it invokes lives in HoneyDrunk.Actions).
- [x] The reusable workflow is the abstraction boundary. Kernel only configures inputs (project key, working dir, etc.) — it does not embed any scanner logic.
- [x] No invariant violation. Kernel's existing tier-1 gate via `pr-core.yml` is unchanged; SonarCloud is added as a downstream tier-2 step.
- [x] No secrets read or written in the repo. `SONAR_TOKEN` flows from the org-level GitHub secret.

## Acceptance Criteria
- [ ] `sonar-project.properties` exists at `HoneyDrunk.Kernel/sonar-project.properties` (inside the inner project subdir, next to `HoneyDrunk.Kernel.slnx`) — **not** at the git repo root. The path the scanner reads it from is `./sonar-project.properties` relative to the `working-directory: 'HoneyDrunk.Kernel'` that `pr.yml` already sets.
- [ ] File contains the project key `honeydrunkstudios_HoneyDrunk.Kernel` and the organization key `honeydrunkstudios`
- [ ] `sonar.sources` and `sonar.tests` reflect the actual project layout in the repo (verify against the `.slnx`); commit corrected paths if they differ from the template. As of `2026-04-26`, the verified set is `sonar.sources=HoneyDrunk.Kernel` and `sonar.tests=HoneyDrunk.Kernel.Tests` (no canary project — do **not** add `HoneyDrunk.Kernel.Canary`, it does not exist on disk).
- [ ] `sonar.cs.opencover.reportsPaths` is `**/coverage.opencover.xml`
- [ ] `sonar.coverage.exclusions` excludes `HoneyDrunk.Kernel.Abstractions` (interfaces-only package; coverage % is not informative)
- [ ] `.github/workflows/pr.yml` is amended with a new `sonarcloud` job that:
  - has `needs: pr-core` (so tier-2 only runs after tier-1 passes — fail-fast cheap-first per ADR-0011 D2)
  - calls `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-sonarcloud.yml@main`
  - passes `coverage-artifact-name: 'coverage-reports-ubuntu-latest'` to reuse the existing artifact
  - passes `SONAR_TOKEN` and `GITHUB_TOKEN` as the two secrets `job-sonarcloud.yml` declares
- [ ] The new job's permissions block declares only `contents: read`, `checks: write`, `pull-requests: write` (matching `job-sonarcloud.yml`'s declared minimum)
- [ ] Repo-level `CHANGELOG.md`: a new entry under `Added` (or appended to the in-progress version's existing entry) describing SonarCloud onboarding (invariants 12 and 27)
- [ ] No per-package `CHANGELOG.md` updates (CI wiring change, not a code change to any package)
- [ ] First PR after merge produces a SonarCloud check (verify before merging the PR)
- [ ] Branch-protection rule on `main` has the SonarCloud check name as a required check, where the check name is **the literal string observed in the first SonarCloud-enabled PR's Checks tab** (historically "SonarCloud Code Analysis" but verify before pasting). Human Prerequisite — verify before closing the issue.

## Human Prerequisites

The agent ships the workflow + properties file. The human handles SonarCloud-side import and GitHub branch protection:

- [ ] **Confirm the SonarCloud GitHub App is installed on `HoneyDrunkStudios/HoneyDrunk.Kernel`** (this should already be true if packet 04 was followed; re-confirm at `https://github.com/organizations/HoneyDrunkStudios/settings/installations`).
- [ ] **Confirm `SONAR_TOKEN` is accessible to `HoneyDrunkStudios/HoneyDrunk.Kernel`** — the org-level secret from packet 04 must include Kernel in its "Selected repositories" list. Check at `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions/SONAR_TOKEN`.
- [ ] **Import the project into SonarCloud:** `https://sonarcloud.io/organizations/honeydrunkstudios → Analyze new project → Select HoneyDrunk.Kernel → "With GitHub Actions"`. Confirm project key auto-resolves to `honeydrunkstudios_HoneyDrunk.Kernel`.
- [ ] **Trigger the first analysis run** by pushing the PR. Verify in SonarCloud that the project page shows analysis results and a quality gate verdict.
- [ ] **Add the SonarCloud check to branch protection on `main`** — but only **after** the first SonarCloud-enabled PR has run and published a check. GitHub rejects branch-protection rules that reference checks which have never run. Sequence: (1) open a PR after this packet's PR merges; (2) on the PR's "Checks" tab, read the literal check name the SonarCloud GitHub App publishes (historically "SonarCloud Code Analysis", but verify each time — do not paste blindly); (3) at `https://github.com/HoneyDrunkStudios/HoneyDrunk.Kernel/settings/branches`, edit the `main` rule, paste the observed check name into "Require status checks to pass before merging," save.
- [ ] **Confirm the quality gate is passing** (or note the initial findings if it fails on legacy code). Per ADR-0011 D11, the gate enforces on new code; historical findings are not blockers for this onboarding but should be tracked for future remediation.

If the first run fails for non-legacy reasons (e.g. the `coverage-artifact-name` mismatch), file a follow-up bug-fix packet rather than blocking this onboarding.

## Dependencies
- **Actions#NN** — `job-sonarcloud.yml` reusable workflow (packet 02). Hard dependency: this packet's `pr.yml` calls that workflow by name.
- **Architecture#NN** — SonarCloud organization setup (packet 04). Hard dependency: the org, the GitHub App install on Kernel, and the `SONAR_TOKEN` org secret must all exist before the workflow can run successfully.
- Soft dependency on packet 01 (ADR-0011 acceptance) for invariant references.

## Downstream Unblocks
- This packet is the **template** for packet 07 (Web.Rest, ASP.NET Core variant) and the Wave-3 deferred fan-out (Transport, Vault, Auth, Data, Pulse, Notify, Vault.Rotation, Actions). Each of those packets uses the same shape: `sonar-project.properties` + `pr.yml` job + project import + branch protection.

## Referenced ADR Decisions

**ADR-0011 (Code Review and Merge Flow):**
- **D2 (tier model, fail-fast cheap-first):** Tier 1 (build, tests, analyzers, vuln, secret) must pass before tier 2 is worth spending money on. The `needs: pr-core` wiring enforces this.
- **D11 (SonarCloud chosen):** Public repos: SonarCloud enabled via `job-sonarcloud.yml` called from `pr.yml`; quality gate is a required branch-protection check.
- **D11 (Contract):** Input `sonar-project.properties` at the repo root; coverage report from stage 2 unit tests; PR diff. Output: required PR check + inline annotations. Secret: `SONAR_TOKEN` org-level. Cost discipline: median PR run under 60 seconds.
- **D11 (Quality gate posture):** Default "Sonar way" gate at the organization level; per-repo overrides only if a Node has a documented reason. Kernel uses the org default.

**ADR-0009 (Package Scanning Policy):** Established the pattern of "PR gate jobs are reusable workflows in `HoneyDrunk.Actions`; consumers call them from their `pr.yml`." This packet follows that pattern exactly.

## Referenced Invariants

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. *(Tier 1 is unchanged here; this packet adds tier 2 as an additional required check on top of tier 1, not as a replacement.)*

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. *(The PR opened by this packet must include the `> Packet: <permalink>` line per packet 03's mechanism. Manual confirmation if the human authors the PR locally.)*

> **Invariant 27 (versioning):** All projects in a solution share one version and move together. *(This packet does not change any project's version — it adds CI wiring. No version bump required. The CHANGELOG entry is appended to whatever in-progress version Kernel currently has, or a Docs/Changed-only entry is added if no version bump is in flight.)*

## Constraints
- **Tier-1 must run first.** `needs: pr-core` is mandatory. SonarCloud must not run on a PR that already failed `dotnet build`.
- **Reuse the coverage artifact.** Do not re-run `dotnet test` inside the SonarCloud job — pull the artifact `pr-core.yml` already publishes (`coverage-reports-ubuntu-latest`).
- **Project key format.** `honeydrunkstudios_HoneyDrunk.Kernel` — this is the format SonarCloud auto-generates from the GitHub repo. Do not invent a different key; if SonarCloud generated a different key during import (e.g. it has used a hyphen in some auto-imports), use whatever SonarCloud actually shows on the project page.
- **`fetch-depth: 0` is set inside `job-sonarcloud.yml`** (not in this packet's `pr.yml`). Confirm the reusable workflow already does this — it should; if it does not, the dependency on packet 02 is broken.
- **Permissions block scoped:** `contents: read`, `checks: write`, `pull-requests: write`. Match `job-sonarcloud.yml`'s declared minimum.
- **Working directory and project path** must match Kernel's actual layout — verify by reading the `.slnx` and directory tree before committing.
- **Coverage exclusions:** `HoneyDrunk.Kernel.Abstractions` is excluded — it is interfaces only and coverage % does not measure anything useful there.
- **Do not bypass the quality gate.** If the first run fails on legacy code, document the findings and either accept the New-Code-only gate (default) or open a follow-up packet to remediate. Do not relax the gate to make the gate pass.

## Labels
`feature`, `tier-2`, `ci-cd`, `core`, `adr-0011`, `wave-2`

## Agent Handoff

**Objective:** Onboard `HoneyDrunk.Kernel` to SonarCloud as the first canonical .NET template — `sonar-project.properties` at repo root, `sonarcloud` job in `pr.yml` chained `needs: pr-core` with the `job-sonarcloud.yml` reusable workflow, project imported into SonarCloud, branch protection updated.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Establish the canonical SonarCloud onboarding pattern. Web.Rest (packet 07) replicates it for ASP.NET Core; Wave-3 fan-out replicates it for the remaining 8 .NET repos.
- Feature: ADR-0011 Code Review Pipeline rollout.
- ADRs: ADR-0011 (D2 tier model + D11 SonarCloud + Follow-up Work bullet), ADR-0009 (precedent for "reusable workflows in Actions, called from consumer `pr.yml`").

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Actions#NN — `job-sonarcloud.yml` (packet 02). Hard.
- Architecture#NN — SonarCloud organization setup walkthrough + portal work (packet 04). Hard.
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft (invariant references).

**Constraints:**
- `needs: pr-core` is mandatory — tier-1-then-tier-2 sequencing per ADR-0011 D2.
- Reuse coverage artifact from `pr-core.yml` — never re-run `dotnet test` here.
- Project key: `honeydrunkstudios_HoneyDrunk.Kernel` (or whatever SonarCloud actually generates on import — verify, don't invent).
- Permissions minimal: `contents: read`, `checks: write`, `pull-requests: write`.
- Verify `sonar.sources` and `sonar.tests` against the actual `.slnx` and directory tree.
- Coverage exclusions for `HoneyDrunk.Kernel.Abstractions`.
- Do not bypass or relax the quality gate to force a passing run.

**Key Files:**
- `HoneyDrunk.Kernel/sonar-project.properties` (new — inner project subdir, next to the `.slnx`; **not** at git root)
- `.github/workflows/pr.yml` (edit)
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.slnx` (read for layout verification)
- `CHANGELOG.md` (root) — entry under in-progress version

**Contracts:**
- Project key `honeydrunkstudios_HoneyDrunk.Kernel`. Renaming would orphan SonarCloud history.
- Job name `sonarcloud` in `pr.yml`. Branch protection on `main` references the SonarCloud GitHub App's check name (historically "SonarCloud Code Analysis"); the human reads the literal string from the first run's Checks tab before pasting into branch protection — do not paste blindly.
- File location: `HoneyDrunk.Kernel/sonar-project.properties` (inner project subdir, not git root). The scanner discovers it from the working directory `pr.yml` runs in.
