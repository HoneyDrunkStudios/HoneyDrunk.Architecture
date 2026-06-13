---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "adr-0055", "wave-4"]
dependencies: ["work-item:02", "work-item:04"]
adrs: ["ADR-0055", "ADR-0012"]
wave: 4
initiative: adr-0055-feature-flags
node: honeydrunk-actions
---

# Author job-featureflags-validate.yml reusable workflow and the Roslyn analyzer for flag-string discovery

## Summary
Author the reusable workflow `job-featureflags-validate.yml` in `HoneyDrunk.Actions` plus a Roslyn analyzer NuGet package that statically discovers literal flag strings in `IFeatureGate.IsEnabledAsync(...)` / `GetVariantAsync<...>(...)` call sites and validates them against each consuming Node's `featureflags.json` per ADR-0055 D6. Together they make the dual-validation gate (every used flag is registered; every registered flag is used or `expected_orphan: true`) a hard CI gate, and enforce the naming convention (D5), category coherence (D6), and release-flag expiry (D7).

## Context
ADR-0055 D6 commits to per-Node `featureflags.json` files with CI validation. The validation has two halves:
- **Static analysis** (Roslyn) — scans the assembly for literal-string calls to `IFeatureGate.IsEnabledAsync` and `GetVariantAsync<T>` and emits a diagnostic for each undeclared flag literal. Variable-fed flag names produce a separate warning (per D6: "Variable-fed flag names are flagged as a separate warning — they defeat static analysis and should be avoided").
- **Registry inspection** (the workflow) — parses `featureflags.json`, validates the schema (against the document packet 02 ships), enforces the naming regex per D5, enforces category coherence per D6 ("declared `category` matches the prefix in `name`"), enforces release-flag expiry per D7 (today's date past `expires_on` fails CI), and warns on permission/operational `annual_review_due` past today (warning, not failure).

ADR-0012 makes `HoneyDrunk.Actions` the Grid's CI/CD control plane. Reusable workflows live at `.github/workflows/job-*.yml`. Per the established pattern in ADR-0042 packet 07's canary and ADR-0040's reusable workflows, this packet adds a new reusable workflow callable from any Node's `pr-core.yml` flow.

The Roslyn analyzer is a NuGet package. Where it lives — `HoneyDrunk.Actions` or `HoneyDrunk.Standards` — is a judgment call. **Default to `HoneyDrunk.Actions`** per ADR-0012's CI-control-plane framing (this is CI tooling, like the `job-api-compatibility.yml` analyzer): the analyzer ships as a workflow-consumed artifact, not as a standard-on-every-project analyzer. The executor confirms at edit time whether `HoneyDrunk.Standards` already ships StyleCop/EditorConfig-style analyzers (it does — see existing standards) and whether dropping the feature-flag analyzer into Standards fits the mental model. If Standards is the better fit at edit time, the analyzer lives there with a brief explanation in the PR; otherwise, it lives in `HoneyDrunk.Actions`.

This packet ships both: the workflow YAML (in Actions) and the analyzer NuGet (in Actions or Standards). Both are CI-time artifacts; neither is a runtime package consumed by any Node's deployed code.

## Scope
- `.github/workflows/job-featureflags-validate.yml` — new reusable workflow callable from any Node's `pr-core.yml` flow.
- A new `HoneyDrunk.Actions.FeatureFlagsAnalyzer` (or `HoneyDrunk.Standards.FeatureFlagsAnalyzer`, depending on the executor's edit-time decision) Roslyn analyzer project + NuGet package.
- A consumer-usage doc update — `docs/consumer-usage.md` (or whichever doc the existing reusable workflows reference) documents how to call `job-featureflags-validate.yml` and how to opt the analyzer into a project.
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## Proposed Implementation
1. **`job-featureflags-validate.yml`** — a reusable workflow with the following inputs:
   - `featureflags-json-glob` (string, default `'src/**/featureflags.json'`) — glob to locate the Node's `featureflags.json` file(s). Most Nodes have one; mono-repos (none today) could have several.
   - `schema-url` (string, default `'https://schemas.honeydrunkstudios.com/featureflags-v1.json'`) — the schema to validate against (packet 02 ships it). If Studios is not yet serving the URL, the workflow falls back to the in-repo path; the consuming Node configures this. Default points to the published URL.
   - `today` (string, optional) — overridable "today" date for testability. Defaults to the workflow run timestamp.

   The workflow does:
   a. Locate every `featureflags.json` matching the glob.
   b. For each file, validate it against `featureflags-v1.json` using a JSON Schema validator (the workflow ships a small validation script — pick a Node.js or Python validator that runs in GitHub Actions; consult what existing schema-validating workflows in the repo use, or use `ajv-cli` for JSON Schema).
   c. For each flag entry: verify the `name` matches the regex `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$`; verify `category` matches the prefix in `name`.
   d. For `category: release`: verify `expires_on` is non-null; verify today's date is on or before `expires_on` (a release flag past `expires_on` fails CI with a message naming the flag and the days-past expiry).
   e. For `category: permission` and `operational`: verify `annual_review_due` is non-null; if today's date is past `annual_review_due`, emit a `::warning::` (does NOT fail CI per D7) with the flag name and days-past-due.
   f. Verify `category: release` does not carry `annual_review_due`; verify `category: permission`/`operational` does not carry a non-null `expires_on`.
   g. Emit a summary table in the workflow job summary (the GitHub Actions `$GITHUB_STEP_SUMMARY` markdown surface) listing every flag, its category, its lifecycle state (active / expires-in-N-days / review-due-in-N-days / past-due).
   h. The workflow does NOT run the Roslyn analyzer — the analyzer runs inside the Node's `dotnet build` step (because it ships as a PackageReference); the workflow validates the registry, and the analyzer separately validates the call sites. Both halves of D6 are then enforced, in their respective phases.

   The workflow is consumed by adding the following to a Node's `.github/workflows/pr-core.yml` (the per-Node tier-1 gate per invariant 31):
   ```yaml
   featureflags-validate:
     uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-featureflags-validate.yml@main
     with:
       featureflags-json-glob: 'src/**/featureflags.json'
   ```

2. **`HoneyDrunk.Actions.FeatureFlagsAnalyzer`** (or the Standards-hosted equivalent) — a Roslyn analyzer NuGet package.
   - **Targets:** `netstandard2.0` (Roslyn analyzers run in the .NET Framework MSBuild host even when the target project is .NET 10; the analyzer must target `netstandard2.0` per the standard Roslyn pattern).
   - **Dependencies:** `Microsoft.CodeAnalysis.CSharp.Workspaces` (latest stable supported by the .NET 10 toolchain).
   - **Analyzer rules:**
     - **HFF001 (Error)** — "Feature flag '{name}' is not registered in featureflags.json." Triggers on a literal-string call to `IFeatureGate.IsEnabledAsync("...")` or `GetVariantAsync<T>("...", default)` where the literal string is not present in any `featureflags.json` discovered in the consuming project's source tree (the analyzer reads `featureflags.json` from the project's directory tree at analysis time via `AdditionalFiles`).
     - **HFF002 (Warning)** — "Feature flag argument is not a literal string; static analysis cannot verify it is registered." Triggers on variable-fed flag names. Per ADR-0055 D6: "Variable-fed flag names are flagged as a separate warning — they defeat static analysis and should be avoided."
     - **HFF003 (Warning)** — "Feature flag name '{name}' does not match the {category}.{node}.{feature} pattern." Triggers on a literal-string flag name that doesn't match the regex. (The workflow catches this too at the registry level; the analyzer catches it at the call site if a developer somehow declared a malformed flag in `featureflags.json` and used it — defense in depth.)
     - **HFF004 (Warning)** — "Direct `IFeatureManager` consumption is discouraged; use `IFeatureGate` (ADR-0055 invariant)." Triggers on any reference to `Microsoft.FeatureManagement.IFeatureManager` or `IFeatureManagerSnapshot` outside `HoneyDrunk.FeatureFlags` itself. (Optional — ship if the implementation is tractable; otherwise defer to a follow-up. The ADR-0055 invariant is enforced by the review agent per D13 regardless.)
   - The analyzer reads `featureflags.json` files via the `AdditionalFiles` MSBuild item — projects opt into static analysis by adding the `featureflags.json` file with `<AdditionalFiles Include="featureflags.json" />` in their `.csproj` (the analyzer NuGet's `.targets` file does this automatically when the NuGet is referenced).
   - **`.targets` and `.props` files** — package the analyzer with auto-wiring for `featureflags.json` discovery. Consult the existing analyzer packaging in `HoneyDrunk.Standards` (e.g., the StyleCop wiring) for the pattern.
   - **Test project** — `HoneyDrunk.Actions.FeatureFlagsAnalyzer.Tests` (or under Standards): xUnit unit tests using `Microsoft.CodeAnalysis.Testing` for each diagnostic rule (positive + negative cases for HFF001/002/003; optional HFF004 if shipped).

3. **Consumer opt-in.** Document in `docs/consumer-usage.md` (or wherever the existing reusable-workflow consumer doc lives — confirm at edit time) the two ways a Node opts in:
   - **Workflow** — add the `featureflags-validate` job to `.github/workflows/pr-core.yml` calling `job-featureflags-validate.yml@main`.
   - **Analyzer** — add a `PackageReference` to the analyzer NuGet (whichever name lands) with `PrivateAssets: all`; the analyzer's `.targets` auto-discovers `featureflags.json`. Document the analyzer's diagnostic IDs (HFF001/002/003/(004)) so developers know what to expect.

4. **Releasing the analyzer NuGet.** Consult the existing release flow in `HoneyDrunk.Actions` (or Standards if the analyzer lands there) — analyzers are NuGet packages with their own version, released by tag like any other NuGet. The version is independent of the consuming projects. v0.1.0 baseline.

5. **`docs/consumer-usage.md`** — append a section: "Feature-Flag Validation (ADR-0055)." Cover the workflow call site, the analyzer opt-in, the registry shape (point to packet 02's schema doc), the diagnostic IDs, and an example of a flag declaration + use + the resulting CI behaviour.

## Affected Files
- `.github/workflows/job-featureflags-validate.yml` (new)
- The analyzer project tree (new) — under `HoneyDrunk.Actions/analyzers/HoneyDrunk.Actions.FeatureFlagsAnalyzer/` or under `HoneyDrunk.Standards/` if the executor places it there.
- The analyzer test project (new).
- `docs/consumer-usage.md` (or equivalent) — new section.
- The repo `CHANGELOG.md` if the repo keeps one for the workflow / analyzer surface.

## NuGet Dependencies
**The analyzer project** (new):
- `Microsoft.CodeAnalysis.CSharp.Workspaces` (latest stable supported by .NET 10)
- `Microsoft.CodeAnalysis.Analyzers` (latest)
- `HoneyDrunk.Standards` (`PrivateAssets: all`) — if Standards ships and this project picks it up; confirm at edit time

**The analyzer test project** (new):
- The ADR-0047 test stack: xUnit v2, NSubstitute, AwesomeAssertions, coverlet
- `Microsoft.CodeAnalysis.CSharp.Workspaces`
- `Microsoft.CodeAnalysis.Testing.Verifiers.XUnit` (or the current testing helper supported by Roslyn)
- `HoneyDrunk.Standards` (`PrivateAssets: all`)

**The reusable workflow** — no .NET project; uses GitHub Actions runners.

## Boundary Check
- [x] `HoneyDrunk.Actions` (or Standards) is the correct repo per ADR-0012 (CI/CD control plane) and the existing analyzer-NuGet-packaging pattern.
- [x] No code change in any Node — the analyzer ships as a NuGet that Nodes opt into; the workflow ships as a reusable that Nodes opt into.
- [x] No runtime dependency on any Node — Roslyn analyzers run in the MSBuild host, not in deployed code.

## Acceptance Criteria
- [ ] `.github/workflows/job-featureflags-validate.yml` exists as a reusable workflow with the inputs `featureflags-json-glob`, `schema-url`, `today`
- [ ] The workflow validates every located `featureflags.json` against the published JSON Schema and emits a structured failure for: schema violation; flag name not matching the regex; category prefix mismatching declared `category`; release flag past `expires_on`; release flag without `expires_on`; permission/operational flag with a non-null `expires_on`
- [ ] The workflow emits a `::warning::` (not a failure) for permission/operational flags past `annual_review_due` per D7
- [ ] The workflow renders a markdown summary of every flag's state in the GitHub Actions job summary
- [ ] The Roslyn analyzer NuGet package exists, targets `netstandard2.0`, and ships diagnostics HFF001 (Error) and HFF002 (Warning) at minimum; HFF003 and HFF004 are optional v0.1 additions
- [ ] HFF001 fires on a literal-string `IFeatureGate.IsEnabledAsync("undeclared.flag.name")` call where the literal is not in any discovered `featureflags.json`
- [ ] HFF002 fires on a variable-fed flag-name call (e.g. `IsEnabledAsync(myFlagVar)`)
- [ ] The analyzer reads `featureflags.json` via `AdditionalFiles`; the packaged `.targets` auto-wires this so consuming projects don't manually add the include
- [ ] Analyzer unit tests use `Microsoft.CodeAnalysis.Testing` for positive and negative cases of each shipped diagnostic
- [ ] `docs/consumer-usage.md` (or equivalent) documents the workflow call site, the analyzer opt-in, the diagnostic IDs, and a worked example
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow / analyzer surface
- [ ] Existing consumers of the deploy/PR workflows are unaffected — the new workflow and the new analyzer are opt-in

## Human Prerequisites
- [ ] After this packet's PR merges, a human publishes the analyzer NuGet to the package feed (analyzers are NuGet packages; agents never tag — invariant 27). Until publication, downstream Nodes opting into the analyzer reference it from a local source or wait. Packet 07 (Notify pilot) needs the analyzer published before it can opt in.

## Referenced ADR Decisions
**ADR-0055 D6 — Per-Node `featureflags.json` with CI validation.** A new `job-featureflags-validate.yml` in HoneyDrunk.Actions enforces: every flag used in code is registered (Roslyn analyzer); every registered flag is used in code or marked `expected_orphan: true`; naming convention (D5); category coherence; release-flag expiry; permission/operational annual-review-due warnings.

**ADR-0055 D6 — Roslyn analyzer.** "A static analyzer (custom Roslyn rule) scans the assembly for `IFeatureGate.IsEnabledAsync('...')` and `GetVariantAsync<...>('...')` calls; any literal flag string not present in `featureflags.json` fails the build. (Variable-fed flag names are flagged as a separate warning — they defeat static analysis and should be avoided.)"

**ADR-0055 D7 — Release-flag expiry; permission/operational warnings.** Release flags fail CI on expiry; permission/operational past `annual_review_due` produce a warning (not blocker). The workflow respects this asymmetry.

**ADR-0055 D5 — Naming regex.** `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$`. Both the workflow (registry side) and the analyzer (call-site side) check this.

**ADR-0012 — Actions as the CI/CD control plane.** Reusable workflows live here; analyzers ship as part of the CI tooling surface.

## Constraints
- **Analyzers target `netstandard2.0`.** Roslyn analyzers run in the .NET Framework MSBuild host; the standard requirement.
- **Opt-in, backward-compatible.** Both the workflow and the analyzer are opt-in. Existing Nodes are unaffected until they choose to call the workflow or reference the analyzer NuGet.
- **Don't run the Roslyn analyzer inside the workflow.** The analyzer runs inside `dotnet build` because it ships as a PackageReference; the workflow handles the registry side. The two halves run in their respective phases (build for the analyzer, the reusable workflow for the registry).
- **`expected_orphan` is the escape hatch for the "every registered flag is used" check.** ADR-0055 D6 names this explicitly. The workflow honors it: a registered flag with `expected_orphan: true` does NOT fail CI even if the Roslyn analyzer doesn't see a literal-string call site (e.g., the flag is consumed only by the operator dashboard reading the registry list).
- **Don't depend on Studios serving the schema URL at workflow time.** Default to `https://schemas.honeydrunkstudios.com/featureflags-v1.json`; if it 404s, the workflow falls back to the in-repo path under `HoneyDrunk.Architecture/schemas/`. The fallback path is configurable via the `schema-url` input.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `adr-0055`, `wave-4`

## Agent Handoff

**Objective:** Author the `job-featureflags-validate.yml` reusable workflow and the `HoneyDrunk.Actions.FeatureFlagsAnalyzer` Roslyn analyzer NuGet so per-Node `featureflags.json` registries and literal-string flag calls in code are statically validated per ADR-0055 D6.

**Target:** `HoneyDrunk.Actions`, branch from `main`. (Or `HoneyDrunk.Standards`, if the executor decides at edit time that Standards is the better fit for the analyzer NuGet — document the choice in the PR.)

**Context:**
- Goal: Make the dual validation (registry + call site) a hard CI gate, with the warning-vs-error asymmetry ADR-0055 D7 names (release expires = error; permission/operational review-due = warning).
- Feature: ADR-0055 Feature Flag rollout, Wave 4.
- ADRs: ADR-0055 D5/D6/D7 (primary), ADR-0012 (Actions as CI/CD control plane), ADR-0047 (test stack for the analyzer's test project).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — the `featureflags-v1.json` schema exists and is the validation target.
- `work-item:04` — `IFeatureGate` exists in `HoneyDrunk.Kernel.Abstractions` so the analyzer has a concrete contract to scan calls against.

**Constraints:**
- Analyzer targets `netstandard2.0`.
- Workflow and analyzer are opt-in, backward-compatible.
- `expected_orphan: true` is the escape hatch in the dual-validation; honor it.
- Schema URL is configurable with a fallback to in-repo path.

**Key Files:**
- `.github/workflows/job-featureflags-validate.yml`
- `analyzers/HoneyDrunk.Actions.FeatureFlagsAnalyzer/` (or under Standards)
- The analyzer test project
- `docs/consumer-usage.md` (or equivalent)

**Contracts:**
- The analyzer scans `IFeatureGate.IsEnabledAsync(string)` and `IFeatureGate.GetVariantAsync<T>(string, T)` call sites — confirm method signatures against packet 04's shipped `IFeatureGate` at edit time.
- The workflow reads `featureflags.json` matching the `featureflags-v1.json` schema shipped by packet 02.
