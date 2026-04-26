---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.Rest
labels: ["feature", "tier-2", "ci-cd", "core", "adr-0011", "wave-2"]
dependencies: ["Actions#NN — job-sonarcloud.yml (packet 02)", "Architecture#NN — SonarCloud organization setup (packet 04)"]
adrs: ["ADR-0011"]
wave: 2
initiative: adr-0011-code-review-pipeline
node: honeydrunk-web-rest
---

# Feature: Onboard HoneyDrunk.Web.Rest to SonarCloud (ASP.NET Core variant template)

## Summary
Onboard `HoneyDrunk.Web.Rest` as the second SonarCloud template — same shape as the Kernel onboarding (packet 06) but adjusted for an ASP.NET Core middleware-and-conventions package family. Add `sonar-project.properties`, wire `pr.yml`, import the project into SonarCloud, add branch-protection check.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Web.Rest`

## Motivation
Per ADR-0011's "one packet per active repo" follow-up bullet, every public Grid repo gets its own onboarding packet. Web.Rest is chosen as the second template because:

1. **Different shape from Kernel.** Kernel is a pure library + Abstractions + tests. Web.Rest ships an ASP.NET Core integration package (`HoneyDrunk.Web.Rest.AspNetCore`) that has a different surface area — middleware, exception filters, MVC conventions. The SonarCloud configuration patterns for ASP.NET Core (e.g. how to handle request-pipeline coverage, how to exclude generated `Microsoft.AspNetCore.*` glue) are slightly different from a pure library.
2. **Two-package family.** Like several Grid repos, Web.Rest has both Abstractions and AspNetCore packages. The coverage-exclusion pattern for "Abstractions are interfaces, exclude" generalizes; the ASP.NET Core test patterns establish the second template.
3. **Tier-2 candidate.** Web.Rest's `stability_tier` is `beta` per `nodes.json`. Sonar findings on a beta-tier Node are useful for hardening before promotion to stable.

This packet is structurally identical to packet 06 — only the project key, working dir, and exclusions differ. The dispatch plan tracks them as parallel packets in Wave 2; together they cover the two dominant Grid repo shapes.

## Proposed Implementation

### A. Add `sonar-project.properties`

**File location is critical.** Create `sonar-project.properties` **inside the inner project subdir** at `HoneyDrunk.Web.Rest/sonar-project.properties` (relative to the git root). This is the same directory that contains `HoneyDrunk.Web.Rest.slnx`, `HoneyDrunk.Web.Rest.Abstractions/`, `HoneyDrunk.Web.Rest.AspNetCore/`, `HoneyDrunk.Web.Rest.Tests/`, and `HoneyDrunk.Web.Rest.Canary/`. It is **not** at the git repo root next to `LICENSE` and `README.md`.

Why: Web.Rest's `pr.yml` runs the reusable workflow with `working-directory: 'HoneyDrunk.Web.Rest'` (verified in `.github/workflows/pr.yml`). The `dotnet-sonarscanner` discovers `sonar-project.properties` from the working directory it begins from, not the git repo root. From inside the working directory the scanner uses, the file path is `./sonar-project.properties`.

Paths inside `sonar-project.properties` are relative to that same working directory (`HoneyDrunk.Web.Rest/` from git root). So `sonar.sources=HoneyDrunk.Web.Rest.Abstractions,HoneyDrunk.Web.Rest.AspNetCore` resolves to the inner package directories at `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Abstractions/` and `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/`.

Content:

```properties
# SonarCloud project configuration for HoneyDrunk.Web.Rest.
#
# This file lives at HoneyDrunk.Web.Rest/sonar-project.properties (inside the
# inner project subdir, next to HoneyDrunk.Web.Rest.slnx). All sonar.sources /
# sonar.tests paths are relative to that subdir, which matches the
# working-directory the reusable job-sonarcloud.yml runs from.

sonar.organization=honeydrunkstudios
sonar.projectKey=honeydrunkstudios_HoneyDrunk.Web.Rest
sonar.projectName=HoneyDrunk.Web.Rest

# Sources — both packages, relative to the working directory (HoneyDrunk.Web.Rest/)
sonar.sources=HoneyDrunk.Web.Rest.Abstractions,HoneyDrunk.Web.Rest.AspNetCore

# Tests — both .Tests and .Canary projects exist on disk (verified 2026-04-26).
# Web.Rest does have a canary project, unlike Kernel; this asymmetry is intentional.
sonar.tests=HoneyDrunk.Web.Rest.Tests,HoneyDrunk.Web.Rest.Canary

# Coverage
sonar.cs.opencover.reportsPaths=**/coverage.opencover.xml

# Exclusions — generated, build artifacts, designer files
sonar.exclusions=**/obj/**,**/bin/**,**/*.Designer.cs

# Coverage exclusions:
# - Abstractions: interfaces only, coverage % is not informative
# - AspNetCore middleware extension methods that wrap framework calls
sonar.coverage.exclusions=**/HoneyDrunk.Web.Rest.Abstractions/**,**/Extensions/ServiceCollectionExtensions.cs,**/Extensions/ApplicationBuilderExtensions.cs

# New Code — inherit organization default (30 days)
```

The exact source / test directories were verified against the repo on `2026-04-26`: Web.Rest has four projects under `HoneyDrunk.Web.Rest/` — `HoneyDrunk.Web.Rest.Abstractions`, `HoneyDrunk.Web.Rest.AspNetCore`, `HoneyDrunk.Web.Rest.Tests`, `HoneyDrunk.Web.Rest.Canary`. If the layout has changed by execution time, correct the values to match the current `.slnx` and directory tree. The `coverage.exclusions` paths are reasonable defaults for ASP.NET Core integration packages but should be confirmed by reading the actual extension method file names — if `Extensions/ServiceCollectionExtensions.cs` is not the real path inside `HoneyDrunk.Web.Rest.AspNetCore/`, correct it.

### B. Wire `pr.yml`

Web.Rest's existing `pr.yml` (mirror of Kernel's pattern) calls `pr-core.yml@main`. Add the `sonarcloud` job after `pr-core.yml` succeeds, identical in shape to packet 06's wiring with Web.Rest values:

```yaml
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
      working-directory: 'HoneyDrunk.Web.Rest'   # confirm against actual layout
      project-path: 'HoneyDrunk.Web.Rest.slnx'   # confirm against actual file name
      sonar-organization: 'honeydrunkstudios'
      sonar-project-key: 'honeydrunkstudios_HoneyDrunk.Web.Rest'
      coverage-artifact-name: 'coverage-reports-ubuntu-latest'
    secrets:
      sonar-token: ${{ secrets.SONAR_TOKEN }}
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

The `pr-core` job above is unchanged from Web.Rest's existing `pr.yml` — only the `sonarcloud` job is added.

### C. Import the project into SonarCloud

After the SonarCloud GitHub App is on Web.Rest (per packet 04, step 4), follow the same import flow as packet 06 with `HoneyDrunk.Web.Rest` substituted: SonarCloud → Analyze new project → GitHub → HoneyDrunkStudios/HoneyDrunk.Web.Rest → "With GitHub Actions" → confirm project key `honeydrunkstudios_HoneyDrunk.Web.Rest` → New Code default 30 days.

### D. Branch protection — add SonarCloud check (after first run, not before)

This step requires GitHub repo admin and is a Human Prerequisite with **strict ordering**: branch protection can only reference a check that has run at least once. If the rule is added before SonarCloud has published its first check, GitHub rejects the rule. Sequence:

1. **Merge this packet's PR.** The `sonarcloud` job is now wired into `pr.yml`.
2. **Wait for the first SonarCloud-enabled PR to run** (this can be a follow-up PR or any new PR after the merge). On the first run, the SonarCloud GitHub App publishes a check.
3. **Open the PR's "Checks" tab** and read the **exact check name** the SonarCloud App is publishing. Historically this has been "SonarCloud Code Analysis" but **do not paste this string blindly** — copy the literal string from the live Checks UI.
4. At `https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.Rest/settings/branches`, edit the `main` branch protection rule (or create one if missing).
5. Under "Require status checks to pass before merging," paste the exact check name from step 3.
6. Save.

## Affected Files
- `HoneyDrunk.Web.Rest/sonar-project.properties` (new — inner project subdir, next to `HoneyDrunk.Web.Rest.slnx`; **not** the git repo root)
- `.github/workflows/pr.yml` (edit — add `sonarcloud` job)
- `CHANGELOG.md` (root): entry under in-progress version

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Web.Rest`.
- [x] Reusable workflow boundary preserved — Web.Rest only configures inputs.
- [x] No invariant violation. Tier 1 unchanged; tier 2 SonarCloud added on top.
- [x] No secrets read or written in the repo.

## Acceptance Criteria
- [ ] `sonar-project.properties` exists at `HoneyDrunk.Web.Rest/sonar-project.properties` (inside the inner project subdir, next to `HoneyDrunk.Web.Rest.slnx`) — **not** at the git repo root. The path the scanner reads it from is `./sonar-project.properties` relative to the `working-directory: 'HoneyDrunk.Web.Rest'` that `pr.yml` already sets.
- [ ] File contains project key `honeydrunkstudios_HoneyDrunk.Web.Rest`
- [ ] `sonar.sources` lists both `HoneyDrunk.Web.Rest.Abstractions` and `HoneyDrunk.Web.Rest.AspNetCore` (or whatever the actual project directory names are after verification)
- [ ] `sonar.tests` reflects the actual test project layout
- [ ] `sonar.coverage.exclusions` excludes the Abstractions package and any ASP.NET Core wrapper extension files (verified to exist before exclusion is added)
- [ ] `.github/workflows/pr.yml` has a new `sonarcloud` job with `needs: pr-core` and the correct project key / working dir / project path inputs
- [ ] Permissions block on the new job is minimal: `contents: read`, `checks: write`, `pull-requests: write`
- [ ] Repo-level `CHANGELOG.md`: append a SonarCloud onboarding entry to the in-progress version (or open one if no in-progress version exists; per invariants 12 and 27)
- [ ] No per-package `CHANGELOG.md` updates
- [ ] First PR after merge produces a SonarCloud check (verify before merging)
- [ ] Branch-protection rule on `main` has the SonarCloud check name as a required check, where the check name is **the literal string observed in the first SonarCloud-enabled PR's Checks tab** (historically "SonarCloud Code Analysis" but verify before pasting). Human Prerequisite.

## Human Prerequisites
- [ ] **Confirm SonarCloud GitHub App is on `HoneyDrunk.Web.Rest`** (covered by packet 04).
- [ ] **Confirm `SONAR_TOKEN` org secret includes Web.Rest** in Selected repositories (covered by packet 04).
- [ ] **Import project into SonarCloud:** SonarCloud → Analyze new project → GitHub → HoneyDrunk.Web.Rest → "With GitHub Actions". Verify project key auto-resolves to `honeydrunkstudios_HoneyDrunk.Web.Rest`.
- [ ] **Trigger first analysis** by pushing the PR. Verify SonarCloud project page shows results.
- [ ] **Add the SonarCloud check to branch protection on `main`** — but only **after** the first SonarCloud-enabled PR has run. GitHub rejects branch-protection rules that reference checks which have never run. Sequence: (1) open a PR after merge; (2) on the PR's "Checks" tab, read the literal check name the SonarCloud GitHub App publishes (historically "SonarCloud Code Analysis", but verify each time — do not paste blindly); (3) at `https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.Rest/settings/branches`, edit the `main` rule, paste the observed check name, save.
- [ ] **Document any initial findings** as an issue or note for future remediation; do not relax the gate to force a pass on legacy code.

## Dependencies
- Actions#NN — `job-sonarcloud.yml` (packet 02). Hard.
- Architecture#NN — SonarCloud organization setup (packet 04). Hard.
- Soft dependency on packet 01 for invariant references.

This packet **does not** depend on packet 06 (Kernel onboarding). The two run in parallel within Wave 2 — they are independent template repos targeted at two different repo shapes.

## Downstream Unblocks
- Together with packet 06, this packet establishes the two canonical onboarding shapes (pure library / ASP.NET Core integration). Wave-3 deferred fan-out (Transport, Vault, Auth, Data, Pulse, Notify, Vault.Rotation, Actions) replicates whichever shape applies — most are pure-library shape (use packet 06 as template); Auth.AspNetCore-style packages (if any sub-packages exist that mirror the Web.Rest split) use packet 07 as template.

## Referenced ADR Decisions

**ADR-0011 (Code Review and Merge Flow):**
- **D2 (tier model, fail-fast cheap-first):** SonarCloud only runs after tier 1 passes — `needs: pr-core` enforces this.
- **D11 (SonarCloud chosen):** Public repos: SonarCloud enabled; quality gate is a required branch-protection check.
- **D11 (Contract):** Same as packet 06.

**ADR-0009 (Package Scanning Policy):** Same precedent — reusable workflow in Actions, called from consumer `pr.yml`.

## Referenced Invariants

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. *(The PR opened by this packet must include the `> Packet: <permalink>` line per packet 03's mechanism.)*

> **Invariant 27 (versioning):** All projects in a solution share one version and move together. *(No version bump required for CI wiring; CHANGELOG entry only.)*

## Constraints
- **Tier-1 must pass first.** `needs: pr-core` is mandatory.
- **Reuse coverage artifact.** Do not re-run `dotnet test`.
- **Project key format:** `honeydrunkstudios_HoneyDrunk.Web.Rest` (or whatever SonarCloud auto-generates on import).
- **Permissions minimal:** `contents: read`, `checks: write`, `pull-requests: write`.
- **Verify project layout before committing.** Source dir, test dir, project path, and the specific extension files listed in `coverage.exclusions` must all exist.
- **Coverage exclusions for ASP.NET Core glue.** The Abstractions exclusion is canonical; the wrapper extension exclusions are repo-specific and must be confirmed against the real file paths.
- **Do not bypass the quality gate.** Initial findings on a beta-tier Node are expected; document and remediate, do not relax.

## Labels
`feature`, `tier-2`, `ci-cd`, `core`, `adr-0011`, `wave-2`

## Agent Handoff

**Objective:** Onboard `HoneyDrunk.Web.Rest` to SonarCloud as the ASP.NET Core variant template — `sonar-project.properties` covers both Abstractions and AspNetCore packages with appropriate coverage exclusions; `pr.yml` adds a `sonarcloud` job chained `needs: pr-core` calling `job-sonarcloud.yml`; project imported into SonarCloud; branch-protection check added.

**Target:** `HoneyDrunk.Web.Rest`, branch from `main`.

**Context:**
- Goal: Second canonical SonarCloud onboarding template (ASP.NET Core variant; complements packet 06's pure-library variant).
- Feature: ADR-0011 Code Review Pipeline rollout.
- ADRs: ADR-0011 (D2 tier model + D11 SonarCloud + Follow-up Work bullet), ADR-0009 (precedent).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Actions#NN — `job-sonarcloud.yml` (packet 02). Hard.
- Architecture#NN — SonarCloud organization setup walkthrough + portal work (packet 04). Hard.
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft.

**Constraints:**
- `needs: pr-core` mandatory.
- Reuse coverage artifact.
- Project key matches SonarCloud's auto-generated value (verify; do not invent).
- Permissions minimal: `contents: read`, `checks: write`, `pull-requests: write`.
- Verify all paths in `sonar-project.properties` against the real `.slnx` and directory tree before committing.
- Coverage exclusions for Abstractions (interface-only) and ASP.NET Core wrapper extension files (verify the file paths exist).
- Do not relax the quality gate.

**Key Files:**
- `HoneyDrunk.Web.Rest/sonar-project.properties` (new — inner project subdir, next to the `.slnx`; **not** at git root)
- `.github/workflows/pr.yml` (edit)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.slnx` (read for layout)
- `CHANGELOG.md` (root)

**Contracts:**
- Project key `honeydrunkstudios_HoneyDrunk.Web.Rest`. Renaming would orphan SonarCloud history.
- Job name `sonarcloud` in `pr.yml` (matching packet 06 for consistency).
- Branch-protection check name: literal string from the first run's Checks tab (historically "SonarCloud Code Analysis"; verify and copy, do not paste blindly).
- File location: `HoneyDrunk.Web.Rest/sonar-project.properties` (inner project subdir, not git root). The scanner discovers it from the working directory `pr.yml` runs in.
