# ADR-0012: HoneyDrunk.Actions as the Grid CI/CD Control Plane

**Status:** Proposed
**Date:** 2026-04-13
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

On the night of 2026-04-12 into 2026-04-13, the nightly security scan of `HoneyDrunk.Vault` failed. Investigating the failure surfaced not one bug but a cluster of five, and walking that cluster revealed a structural gap that is not Vault-specific:

1. **Six false-positive gitleaks findings** flagged documentation placeholder API keys — `"test-api-key-12345"`, `"my-api-key-12345"`, and a 32-char hex AKV secret-version identifier shown in an example code block. The gitleaks ruleset in use was the unmodified default; there was no allowlist anywhere in the Grid. Every repo that ships the same code examples in docs — and several already do — will hit the same six false positives on every run.

2. **A broken gitleaks invocation.** The reusable `nightly-security.yml` in `HoneyDrunk.Actions` called `gitleaks/gitleaks-action@v2` with `with: args: --full-history --report-format sarif --report-path ./security-reports/secrets-scan.sarif`. The `gitleaks-action@v2` input schema does not accept `args:`. The flags were silently dropped, gitleaks ran with defaults, and no SARIF file was produced. The first observable failure was a downstream `upload-sarif` step erroring with "path does not exist." The action's own job summary reported "0 secrets" while the gitleaks binary's console output reported 6 leaks — the same run disagreeing with itself. The defect had been silent for as long as the workflow had existed.

3. **A real build failure at CodeQL time.** `HoneyDrunk.Vault.slnx` carried `<Build Solution="Debug|*" Project="false" />` on the `AppConfiguration` provider project. Local IDE work resolved ProjectReferences regardless. The nightly SAST job, which runs `dotnet build <slnx>` with no special flags, honored the solution-file Build flag and skipped AppConfiguration. `HoneyDrunk.Vault.Tests` has a ProjectReference to AppConfiguration; its compile failed with "The type or namespace name 'AppConfiguration' does not exist in the namespace 'HoneyDrunk.Vault.Providers'". CodeQL's analyze step ran against an incomplete build and reported "0 findings" — not because the code was clean, but because the analyzer never saw it.

4. **Caller-workflow permission mismatches in seven places across six repos.** Reusable workflows in `HoneyDrunk.Actions` declare the `permissions:` they need at the workflow-file level, but under `workflow_call` the callee's block is purely documentary — the job token's effective permissions are determined by the **caller**. Where the caller omitted a `permissions:` block, the repo's default token scope applied (`contents:read, issues:none, security-events:none, pull-requests:none`) and workflow-load validation failed with "requesting 'issues: write, security-events: write', but is only allowed 'issues: none, security-events: none'." This fired at load time, not at run time, and it fired on every scheduled trigger.

5. **Zero grid-wide visibility.** Every one of the above failures had been firing for at least one night in at least one repo. None of them had produced a signal the solo developer saw. They were discovered only when the human manually opened the Actions tab of a single repo and began clicking into runs. There was no aggregated view, no failure digest, no notification channel. The entire discovery mechanism was "a human noticed."

The throughline of the five failures is not "gitleaks is misconfigured" or "the slnx has a typo." Those are symptoms. The throughline is this: **the Grid's CI/CD is already a distributed system, but it is being operated as eleven independent repositories.** Shared pipeline configuration lives implicitly in the form of reusable workflow files that each caller trusts blindly; each tool runs on its defaults; each caller declares its own `permissions:` block (or forgets to); each pipeline's health is visible only from that pipeline's own run page.

This is tolerable at one repo, marginally workable at three, and actively hostile at eleven. The Grid is at eleven today and growing. The first agent-authored PRs from the ADR-0005 / ADR-0006 Wave 1 rollout are about to land — a rollout that will exercise every reusable workflow across every repo repeatedly, and whose failure modes will surface first through exactly the pipeline-visibility channel that does not exist.

Prior ADRs have each carved out a control plane for a specific Grid concern. ADR-0002 named `HoneyDrunk.Architecture` as the command center for cross-repo coordination. ADR-0007 named `.claude/agents/` as the single source of truth for agent definitions. ADR-0008 named the org Project board as the source of truth for work tracking. ADR-0011 named `pr-core.yml` (shared from `HoneyDrunk.Actions`) as the tier-1 PR gate. Each decision collapsed a distributed-by-default concern onto a single named location.

This ADR generalizes that pattern to **CI/CD configuration and pipeline observability** and names `HoneyDrunk.Actions` as the control plane for both. `HoneyDrunk.Actions` already holds the reusable workflows; this ADR extends its remit to also hold the shared *configuration* those workflows consume, and the *observability* mechanism by which the operator learns that any pipeline in the Grid has failed.

Sector is **Meta**, same as ADR-0002, ADR-0008, and ADR-0011: this is process architecture for the Grid's execution machinery, not system topology. This ADR does not depend on ADR-0010 (the observation layer, still Proposed) — pipeline observability is CI/CD mechanics, separate from the runtime observation layer ADR-0010 addresses.

## Decision

Code execution in the Grid is governed by ten bound sub-decisions. Together they name `HoneyDrunk.Actions` as the CI/CD control plane, define the shared-configuration mechanism and how it is consumed by reusable workflows, establish the caller-side contracts that reusable workflows require, and name the pipeline-observability mechanism by which the operator learns of failure.

### D1 — `HoneyDrunk.Actions` is the Grid CI/CD control plane

`HoneyDrunk.Actions` is the single named location for:

- **Reusable workflows** that every Grid repo consumes via `workflow_call` (already the case for `pr-core.yml`, `nightly-security.yml`, `nightly-deps.yml`, `publish.yml`).
- **Shared configuration** consumed by those workflows — gitleaks rules, CodeQL query packs, dotnet-format rules, Trivy IaC policy, and any future tool configuration that should not drift across repos. See D2.
- **Grid pipeline observability** — the aggregator workflow that assembles CI/CD state across every Grid repo into a single human-readable surface. See D6.
- **Composite actions** used by those workflows (already at `.github/actions/`).

Rejected as alternate locations:

- **Per-repo configuration**, the current state. This is what the nightly-scan incident exposed as unworkable at eleven repos.
- **`HoneyDrunk.Architecture`** as the config location. Architecture is the source of truth for *system topology*; CI/CD mechanics are a different sector. Mixing them blurs the "what kind of thing is this" line that every other Grid decision has been careful to draw.
- **A dedicated `HoneyDrunk.CIConfig` repo.** Premature. The mechanism in D2 works with a subdirectory of an existing repo, and `HoneyDrunk.Actions` is the repo with the clearest ownership for anything whose consumer is a reusable workflow. Split only if the shared-config surface grows large enough to dominate Actions.

### D2 — Shared CI configuration lives at `.github/config/`, consumed via runtime checkout

Reusable workflows that need shared configuration perform two steps, in order:

1. **Checkout the caller repo** as usual (`actions/checkout@v4`).
2. **Checkout `HoneyDrunk.Actions` into a sibling path** (`.github/actions-repo/`, matching the convention already used by reusable workflows for loading composite actions). The checkout ref is controlled by the caller via the `actions-ref` input (default `main`).

The reusable workflow then references the shared config by path: `.github/actions-repo/.github/config/<tool>.<ext>`. The file's format is whatever the tool's native config format is — TOML for gitleaks, YAML for Trivy, `.props` or `.editorconfig` for MSBuild-family tools. Configuration is **not** abstracted behind a grid-specific schema; the file is whatever the upstream tool consumes, so that upgrading the tool does not require a concurrent abstraction update.

The directory structure under `.github/config/` is flat today and will remain flat until a concrete reason to nest it appears. Current contents (as of this ADR landing):

- `.github/config/gitleaks.toml` — shared gitleaks allowlist (see D8)
- `.github/config/repo-to-node.yml` — pre-existing, repo-to-Node catalog consumed by composite actions

Future additions: CodeQL query packs, Trivy IaC policy, dotnet-format allowlists, etc. Each addition is a discrete sub-packet under this ADR's follow-up work.

Rejected alternate mechanisms:

- **Inlining config as workflow inputs.** Inputs are for per-caller variation; shared config is by definition not per-caller. Inlining makes the workflow file the schema, which fails any tool whose native config is more expressive than GitHub Actions' `inputs:` block (which is all of them).
- **Pulling config from a release asset or GitHub raw URL.** Adds a network dependency, does not version with the consuming workflow, and loses the ability to atomically update workflow + config in a single PR.
- **Git submodules.** Rejected on "fewer moving parts" grounds — submodules are harder to reason about than a second `actions/checkout` step, and the latter has exactly the semantics we want.

### D3 — Caller repos may override shared config with a repo-local file at repo root

If a caller repo needs a per-repo exception to a shared configuration — say, a gitleaks allowlist for a file pattern unique to that repo — it commits a `.gitleaks.toml` at its own repo root. The reusable workflow's "resolve config" step checks for a repo-local file first, and if present, uses it; otherwise, it falls back to the shared file under `.github/actions-repo/.github/config/`.

The repo-local file is expected to `extend` the shared one (`[extend] path = "../.github/actions-repo/.github/config/gitleaks.toml"` or equivalent), so that the per-repo override is a superset of the grid-wide baseline rather than a replacement. This is convention, not tooling enforcement. A per-repo config that fully replaces the baseline is legal but strongly discouraged; a review agent finding against that pattern is a Suggest-grade observation.

Rejected alternative: **merge the repo-local file into the shared file at runtime**. Too magical. The caller explicitly owns its override by committing the file; the reusable workflow does not do hidden merging.

### D4 — Reusable workflows invoke tool CLIs directly, not marketplace wrapper actions

The `gitleaks/gitleaks-action@v2` incident exposed a general failure mode: marketplace actions wrap CLI tools with their own input schemas, and when a caller passes a flag the wrapper's schema does not recognize, GitHub Actions silently drops the input. The wrapped CLI runs with its defaults, which do not match intent, and the first observable failure is downstream. The runtime disagreement between the tool's console output and the action's own summary is a second-order symptom of the same root cause: the wrapper and the binary have divergent views of what ran.

Policy: reusable workflows in `HoneyDrunk.Actions` invoke tool CLIs directly via `run:` shell steps, installing the CLI at a pinned version in the same step. The install is cheap (a single `curl`/`tar`/`mv`, or `dotnet tool install`, or equivalent), the flags passed to the CLI are the flags documented by the tool itself, and any breaking change in the tool's flags becomes visible at the next version bump — reviewable in a PR diff, not silently absorbed.

The only marketplace actions retained are:

- **First-party GitHub actions** — `actions/checkout`, `actions/setup-dotnet`, `actions/setup-node`, `actions/upload-artifact`, `actions/download-artifact`, `actions/cache`. These are maintained by GitHub, have stable schemas, and have no meaningful CLI equivalent that could replace them.
- **`github/codeql-action/*`** — CodeQL's init/analyze/upload-sarif wrappers. The CodeQL CLI exists but the action handles GitHub-side plumbing (SARIF category routing, GitHub Advanced Security upload) that would be tedious to replicate. First-party, stable.
- **Composite actions inside `HoneyDrunk.Actions`** — under our own control, live-reviewed, not third-party.

Third-party wrappers (`gitleaks-action`, `trivy-action`, `sonar-scanner-action`, `checkov-action`, etc.) are **rejected**. Each is replaced by a direct CLI invocation in the reusable workflow. The one-time cost of migrating is recovered on the first flag-drift incident the CLI pattern prevents.

Rejected alternative: **use `gitleaks-action@v2` properly, via the env-var inputs it actually supports.** This would fix the specific incident but leaves the general failure mode open: the next wrapper action with a schema mismatch causes the next silent failure. Direct CLI is strictly more durable.

### D5 — Caller workflows declare a `permissions:` block that is a superset of the callee's

Under `workflow_call`, the reusable (callee) workflow's `permissions:` block is purely documentary — the effective job token permissions are determined by the **caller**. A caller that omits `permissions:` inherits the repository's default token scope, which in the default GitHub Actions configuration is restrictive (`contents:read`, all other write scopes `none`). Any reusable workflow that requests a `write` scope the caller has not granted fails at workflow-load time with a validation error, before a single step runs.

Policy: every caller workflow that consumes a reusable workflow from `HoneyDrunk.Actions` declares a top-level `permissions:` block whose scopes are a superset of the callee's declared needs. The canonical pattern for the three most common callees:

```yaml
# For nightly-security.yml callers
permissions:
  contents: read
  security-events: write
  issues: write

# For nightly-deps.yml callers
permissions:
  contents: write
  pull-requests: write

# For pr-core.yml callers
permissions:
  contents: read
  pull-requests: write
  checks: write
  security-events: write
```

These are baselines. A caller that grants *more* than the callee needs is legal but should be avoided (principle of least privilege applied to the token scope). A caller that grants less is broken at workflow-load time and the grid-health aggregator (D6) will report it as failing with a distinctive "invalid workflow file" signature.

This decision is documentary enough to feel obvious, but the incident that triggered this ADR fired because it was not documented anywhere. Codifying it here makes it findable when the next repo is added to the Grid.

Rejected alternative: **grant the permissions at the callee level and hope GitHub honors it.** GitHub does not; the callee's block is ignored for token-scope purposes under `workflow_call`. This is a documented GitHub Actions behavior, not a bug.

### D6 — Grid Health aggregator workflow in `HoneyDrunk.Actions`

A new scheduled workflow `HoneyDrunk.Actions/.github/workflows/grid-health-report.yml` runs daily at `30 3 * * *` UTC — thirty minutes after the latest scheduled nightly workflow trigger across the Grid, chosen so that every nightly has had a reasonable chance to finish before the aggregator reads its state. The workflow:

1. **Reads the canonical repo list** from `HoneyDrunk.Architecture/repos/*.json` via `gh api`. This catalog is already maintained per ADR-0008 and the Architecture repo conventions; this ADR re-mandates that adding a new Grid repo requires adding it to the catalog, because otherwise the aggregator cannot see it.
2. **For each repo, fetches the latest run** of each tracked workflow via `gh api /repos/{owner}/{repo}/actions/workflows/{workflow}/runs?per_page=1`. Tracked workflows are: `nightly-security.yml`, `nightly-deps.yml`, `publish.yml`, and any repo-specific scheduled workflow the repo's catalog entry declares under a new `tracked_workflows` key. `pr-core.yml` is **excluded** because its state is per-PR, not time-scheduled, and belongs on the PR surface (ADR-0011 D1).
3. **Classifies each (repo, workflow) pair** as:
   - **Pass** — latest run `conclusion == "success"` within the expected staleness window (24h for daily schedules, 8 days for weekly).
   - **Fail** — latest run `conclusion == "failure"` or `"cancelled"` or `"timed_out"`.
   - **Stale** — latest run is outside the expected staleness window (i.e., the schedule did not fire, or fired but was cancelled before starting). This catches "the workflow is broken in a way that prevents it from running" — the exact failure mode of the caller-permissions bug in this ADR's Context.
   - **Missing** — the workflow file is declared in the repo catalog but has no runs at all. Catches misconfiguration at repo-add time.
4. **Assembles a markdown report** with a table: rows = repos, columns = tracked workflows, cells = Pass / Fail / Stale / Missing, with links to the most recent run. Overall Grid status in the header: "🟢 all green", "🟡 N stale/missing", or "🔴 N failures".
5. **Updates a single GitHub issue** in `HoneyDrunk.Actions` titled exactly `🕸️ Grid Health` (stable title, so find-or-create is idempotent). The issue body is fully replaced with the current report on every run. "Last updated" timestamp is in the body; a stale timestamp is itself a signal that the aggregator is broken, and since the issue lives in the same repo as the aggregator, the feedback loop is inside one notification surface.
6. **Opens a per-repo issue** in the *affected repo* for every newly-red (repo, workflow) pair, with stable title `[grid-health] {workflow} failing`. Closes the issue automatically when the pair returns to Pass. Title stability makes the open/close idempotent — the next run of the aggregator recognizes its own prior issues by title and edits them rather than creating duplicates.

The aggregator itself has the same reporting surface applied recursively: if the aggregator workflow fails, the single `🕸️ Grid Health` issue stops updating, and the stale timestamp is the signal. Per-failure email from D7 also covers aggregator failures like any other failed workflow.

Rejected alternatives:

- **Writing to `grid-health.json` in `HoneyDrunk.Architecture`.** That file exists per the 2026-04-12 architecture repo additions and is a *design-time* snapshot of grid topology health (do the repos exist, do the invariants hold, are the catalogs in sync). Pipeline run state is operational, not architectural, and mixing the two would make the file a hybrid — half-static, half-liveness-probe — with no clear consumer. The aggregator issue and the architecture snapshot are separate surfaces because they answer separate questions.
- **Slack or Discord integration.** No current channel matches, and D7 covers per-failure real-time notification via a mechanism that already exists. Named as a future extension if HoneyDrunk Studios operations grow beyond one human.
- **A dedicated dashboard web app.** Premature. A GitHub issue is a stable URL, renders on mobile, is searchable, is notifiable, and has zero hosting cost. Building a dashboard to serve the same information for a single operator would be a solid week of work for no net gain.
- **A GitHub Actions status badge per workflow in each repo's README.** Badges exist for per-workflow status and are fine at the per-repo level, but they do not aggregate, do not detect staleness, do not detect missing runs, and do not open/close issues on state changes. Useful as a per-repo README decoration, complementary to the aggregator, not a substitute.

### D7 — GitHub profile notifications are the real-time notification mechanism

Complementary to D6 (which is batch, daily), real-time per-failure notification is delivered by the operator's GitHub profile notification settings. The solo developer configures **Settings → Notifications → Actions → "Only notify for failed workflows"** on their GitHub account. This delivers one email per failed workflow run at the moment the run completes, across every repo the operator watches (which for the solo dev is all of `HoneyDrunkStudios/*`).

The two mechanisms divide responsibility cleanly:

- **D7 (profile notifications):** real-time, per-failure, email. Answers "did something just break?"
- **D6 (grid-health aggregator):** daily, batch, single surface. Answers "what is the current state of everything?" and catches staleness / missing runs that D7 cannot see (D7 only fires when a workflow *runs* and fails — a workflow that silently fails to run at all fires no email).

D7 is a user-side configuration decision, not a code change. It is named here because the ADR is the complete story of pipeline visibility and the mechanism is not optional — without D7, a failure during the day is invisible until the next D6 run up to 24 hours later.

Rejected alternative: **rely on D6 alone, without D7.** The 24-hour batch cadence is too slow for real-time awareness during active development. A mid-day workflow failure would be invisible until the next aggregator run.

### D8 — Gitleaks configuration is shared and allowlist-scoped to docs

The immediate trigger for this ADR. Resolved concretely:

- **Shared config** at `HoneyDrunk.Actions/.github/config/gitleaks.toml`. Extends the gitleaks default ruleset via `[extend] useDefault = true`.
- **Two `[[allowlists]]`**, both with `condition = "AND"`:
  1. Documentation placeholder API keys and secrets — regex matches `(test|my|your|example|sample|demo|fake|placeholder|dummy|changeme|xxxx+)[-_]?(api[-_]?key|secret|token)[-_]?\w*`, scoped via `paths` to `*.md` and `docs/**`.
  2. 32-char hex identifiers in docs — regex `[a-f0-9]{32}`, also scoped to `*.md` and `docs/**`. Catches example AKV secret-version IDs and similar.
- The `condition = "AND"` is load-bearing: gitleaks allowlists default to OR semantics when both `paths` and `regexes` are specified, which would allowlist every markdown file entirely. The AND keeps the scope tight: allowlist only when both the path matches docs AND the regex matches a known placeholder shape. A real secret leaking into source code is still caught.
- **The reusable `nightly-security.yml`** installs the gitleaks CLI at pinned version `8.21.2` in a `run:` step, then invokes `gitleaks detect --config <resolved-path> --source . --report-format sarif --report-path ./security-reports/secrets-scan.sarif --redact --exit-code 0`. Findings are evaluated in a separate step (same script as before) and SARIF is uploaded to GitHub Advanced Security. `--exit-code 0` is deliberate: the aggregator classifies findings separately and the workflow should not fail-fast on them, because that would leave the GitHub Security tab without the SARIF it needs.

The config file is authoritative for the shared allowlist and is not duplicated in this ADR; read it at `HoneyDrunk.Actions/.github/config/gitleaks.toml`. This ADR describes the *shape* of the shared configuration mechanism; the content is in the file.

### D9 — Caller-workflow scaffolding is documented in an Actions-repo runbook

The canonical caller workflow for each reusable workflow is documented in `HoneyDrunk.Actions/docs/consumer-usage.md` (a file referenced by existing reusable-workflow headers — this ADR re-mandates that it stays current). The runbook shows, for each reusable workflow: the correct `permissions:` block (per D5), the minimum set of `with:` inputs for a plain-vanilla .NET Grid repo, and the required `secrets:` passthroughs. A new Grid repo is onboarded by copying the relevant scaffolds from the runbook.

Rejected alternative: **a `create-repo.sh` script that scaffolds the caller workflows automatically.** Good idea in principle; blocked on the repo-creation workflow being manual through the portal today (per the user's "prefer portal over CLI" convention). Revisit when portal automation for repo creation is set up.

### D10 — CodeQL action pin, Node version pin, and action-version upgrades are tracked in a single Actions-repo inventory

The Node 20 deprecation warnings from `actions/checkout@v4`, `actions/setup-dotnet@v4`, `actions/upload-artifact@v4`, `github/codeql-action/*@v3`, and similar are a recurring operational burden. Each deprecation is a small bump across many workflow files, and the deadline is always several months out, making it easy to defer until one breaks.

Policy: `HoneyDrunk.Actions/docs/action-pins.md` lists every third-party action pin used across the reusable workflows, with its current version, the deprecation deadline if known, and a status (Current / Deprecated-with-deadline / Superseded). Updating this file is part of any PR that bumps an action version; stale entries are a review-agent observation. The aggregator (D6) does not track this file — it is a static inventory, not a runtime state — but a follow-up could add a weekly workflow that parses action versions from the repo's workflow files and diffs against the inventory.

This decision exists because the Node 20 warnings surfaced in the same failing-nightly run that triggered this ADR, and the lack of a tracking mechanism for "actions that need to be bumped" is a smaller instance of the same visibility gap D6 addresses at the run-state level. The pin inventory is the static-state complement to the run-state aggregator.

## Consequences

### Architectural Consequences

- **`HoneyDrunk.Actions` gains a non-workflow responsibility.** The repo's remit grows from "reusable workflows and composite actions" to include "shared tool configuration and grid-wide pipeline observability." Its `README.md` must be updated to reflect the expanded scope, and its directory layout now has `/.github/config/` as a load-bearing directory rather than an incidental one.
- **A new load-bearing dependency on `HoneyDrunk.Architecture/repos/`.** The grid-health aggregator (D6) reads the repo catalog to know which repos to poll. Adding a new Grid repo without adding it to the catalog means the aggregator cannot see it, and ADR-0011's tier-1 gates will still run but failures will be invisible to D6. This makes the repo catalog load-bearing for *operational* visibility, not just *architectural* book-keeping.
- **Reusable workflows gain a standard "checkout Actions repo for shared config" step** in any job that needs shared configuration. This adds ~2 seconds per job for the sparse checkout. Already a pattern for loading composite actions; now also for configuration.
- **Caller workflows in every Grid repo become thinner** in one respect (configuration is delegated) and more explicit in another (permissions are declared explicitly per D5). Net complexity: slightly lower, because the explicit permissions block is the kind of thing you stop writing incorrectly once you've seen it fail.

### Grid CI/CD Invariants

The following invariants must be added to `constitution/invariants.md` under a new **Grid CI/CD Invariants** section, numbered 34 onwards. Invariants 1–28 are the existing enforcement surface; 29–30 are reserved for ADR-0010; 31–33 are ADR-0011's code review invariants; 34 onwards are this ADR's.

34. **`HoneyDrunk.Actions` is the source of truth for shared CI/CD configuration.** Shared tool configurations (gitleaks rules, CodeQL query packs, Trivy policy, dotnet-format rules, etc.) live under `HoneyDrunk.Actions/.github/config/`. Caller repos do not duplicate these files; they consume them via reusable-workflow checkout at job runtime. A caller repo may commit a `.<tool>.<ext>` at its root as a per-repo override, which is expected to extend the shared baseline rather than replace it. See ADR-0012 D2, D3.

35. **Reusable workflows invoke tool CLIs directly.** Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

36. **Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions.** Callers that omit `permissions:` inherit the repository default, which is insufficient for any reusable workflow that requests a `write` scope. Validation failure is not detected until the next scheduled run; grid-health (invariant 37) is the safety net. See ADR-0012 D5.

37. **Grid pipeline health is centrally visible.** The `HoneyDrunk.Actions` `🕸️ Grid Health` issue is the single canonical view of CI/CD state across the Grid, updated at least daily by the grid-health aggregator. Staleness of that issue is itself a signal — the aggregator's own failure surfaces as the issue not updating. Real-time per-failure notification is separately delivered by the operator's GitHub profile notification settings ("Only notify for failed workflows"), and both mechanisms are mandatory. See ADR-0012 D6, D7.

38. **New Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time.** The grid-health aggregator reads the repo catalog to know which repos to poll; a repo missing from the catalog is invisible to grid observability. This invariant re-mandates the existing ADR-0008 / architecture-repo convention from the CI/CD visibility angle. See ADR-0012 D6.

### Process Consequences

- **Adding a new shared tool configuration** is a PR to `HoneyDrunk.Actions` that adds a file under `.github/config/` and updates the consuming reusable workflow to reference it. No per-repo follow-up is required — the next scheduled run of each caller workflow picks up the new config automatically via the runtime checkout. This is the main payoff of D2.
- **Adding a new repo to the Grid** requires it to appear in `HoneyDrunk.Architecture/repos/` (already ADR-0008 convention) *and* in that file to list any repo-specific scheduled workflows the aggregator should track under a new `tracked_workflows` key. Without this, grid-health sees the repo but not its pipelines.
- **Onboarding a new caller workflow** uses the scaffolds in `HoneyDrunk.Actions/docs/consumer-usage.md` (D9). A caller that is not mechanically copied from the scaffold is a review-agent observation (Suggest-grade).
- **When a tool's CLI flags change between versions**, the reusable workflow's pinned version must be bumped deliberately in a PR, with the flag change visible in the diff. This is the protection D4 buys: no more silent drift from a marketplace action's input schema changing under us.
- **The operator must configure GitHub profile notifications** once per GitHub account (D7). This is a one-time setup step, not a recurring process, and is documented in a follow-up runbook.

### Follow-up Work

None of the following is part of this ADR's initial landing. Each is discrete follow-up and should be scoped separately via the scope agent.

- **Author `grid-health-report.yml`** in `HoneyDrunk.Actions/.github/workflows/`. Implements D6 end-to-end: read repo catalog, poll `gh api`, classify, render markdown, find-or-create `🕸️ Grid Health` issue, find-or-create per-repo failure issues. Single packet; medium complexity (mostly shell + `gh api` + a small classification script).
- **Add a `tracked_workflows` key** to each repo's entry in `HoneyDrunk.Architecture/repos/`. Bulk edit across 11 repo files; trivial.
- **Author `HoneyDrunk.Actions/docs/consumer-usage.md`** with canonical caller-workflow scaffolds for `pr-core.yml`, `nightly-security.yml`, `nightly-deps.yml`, and `publish.yml`. D9. Single packet; small.
- **Author `HoneyDrunk.Actions/docs/action-pins.md`** as the pin inventory per D10. Initial population is a scan of current workflow files; ongoing maintenance is a PR-review convention. Single packet; small.
- **Retrofit existing reusable workflows** to install their tool CLIs directly per D4. The gitleaks step is already done in this ADR's landing. Remaining: any other reusable workflow that wraps a third-party CLI via a marketplace action. Audit in a follow-up packet, migrate per-workflow.
- **Audit caller-workflow `permissions:` blocks** across every Grid repo per D5, using the canonical set in the runbook (D9) as the expected state. The seven known mismatches from the triggering incident are fixed in this session; a one-time audit confirms nothing else is silently broken. Small packet.
- **Extend the Vault gitleaks fix to every repo** by landing the shared config (already done in this ADR) and re-running nightly-security across all 11 repos to confirm the false-positive class is gone. No per-repo action needed; the shared config automatically applies.
- **Document the GitHub profile notification setup (D7)** in a short runbook at `HoneyDrunk.Architecture/infrastructure/github-notifications.md`. Trivial, one-time.
- **Amend `.claude/agents/review.md`** with a new observation rule: "Caller workflow that omits `permissions:` while calling a reusable workflow is a Request Changes." Ties D5 enforcement into the code-review gate from ADR-0011.
- **Bump Node 20 deprecated actions** across all reusable workflows: `actions/checkout@v4 → v5` when released, `setup-dotnet@v4 → v5`, `upload-artifact@v4 → v5`, `codeql-action@v3 → v4`. Deadline is 2026-09-16 for Node 20 removal; not urgent but should land before the deadline via a single PR in `HoneyDrunk.Actions`. Updates the pin inventory (D10) in the same PR.

## Unresolved Consequences

These are known gaps in the ADR-0012 design that have been identified but not yet resolved. Named here so agents reading this ADR know what they cannot rely on today.

### Gap 1 — The grid-health aggregator does not yet exist

**Promised (D6):** a `grid-health-report.yml` workflow aggregates CI/CD run state across every Grid repo into a single issue in `HoneyDrunk.Actions`, with per-repo issues opened and closed idempotently on failure/recovery.

**Current state:** not built. The mechanism is fully specified in D6. The canonical repo list exists in `HoneyDrunk.Architecture/repos/` and is readable via `gh api`. `gh run list` and `gh api /repos/.../actions/workflows/.../runs` are the primitives the aggregator will use.

**Contract when built:** see D6. No contract ambiguity remains; this is purely implementation work.

**Impact until resolved:** pipeline visibility falls back to D7 (GitHub profile notifications) alone. D7 covers real-time awareness of failures that actually run, but does *not* cover staleness (workflows that should have run and didn't) or missing runs (workflows declared but never executed). The specific failure mode of the caller-permissions incident — a workflow that fails at workflow-load time before it can fire an email — is invisible without D6. The D7 partial mitigation is enough to unblock operations but not enough to be durable.

**Priority:** high. First follow-up packet under this ADR.

### Gap 2 — Shared configuration is only wired for gitleaks today

**Promised (D2):** shared CI configuration lives at `HoneyDrunk.Actions/.github/config/` and is consumed by reusable workflows via runtime checkout. The mechanism is general.

**Current state:** only `gitleaks.toml` exists and is consumed. CodeQL runs on its default query pack. Trivy IaC runs on default policy. `dotnet-format` is invoked without a shared config. The HoneyDrunk.Standards analyzers are shipped as a NuGet package rather than as a `.github/config/` file, which is a legitimate alternate mechanism (see "Rejected alternate mechanisms" in D2) — but any future tool whose config is a file rather than a package goes through `.github/config/`.

**Impact until resolved:** the next tool-level false-positive or misconfiguration has no central place to land. Each is a discrete follow-up packet; the mechanism to land them is already in place.

**Priority:** medium. Extend per tool as friction appears, not preemptively.

### Gap 3 — Caller-workflow permissions audit is manual

**Promised (D5):** every caller workflow declares a superset of the callee's permissions.

**Current state:** the seven broken callers found during the triggering incident are fixed (Auth security+deps, Vault deps, Web.Rest deps; Data / Kernel / Transport were already correct; the remaining callers were verified in-session). No automated check verifies that a new caller added after today will match the invariant.

**Contract when built:** a linting step — potentially in `pr-core.yml`, potentially in the grid-health aggregator — that parses every caller workflow's `permissions:` block against the set of reusable workflows it calls, using the reusable-workflow's own `permissions:` declaration as the source of truth. Fails (or warns) on mismatch. The grid-health aggregator already surfaces the *runtime* symptom (a workflow stuck at workflow-load failure classified as Stale); the lint surfaces the *static* symptom at PR time.

**Impact until resolved:** a new repo added to the Grid can ship with a broken caller workflow that fails only at first scheduled run, at which point D6 catches it. The grid-health safety net is sufficient to keep the bug small, but earlier detection is cheap.

**Priority:** low. Grid growth rate is slow enough that the scaffold-from-runbook pattern (D9) plus the grid-health safety net (D6) is sufficient. Revisit if a second broken caller appears post-fix.

### Gap 4 — The aggregator's repo catalog dependency is only loosely enforced

**Promised (D6, invariant 38):** new Grid repos appear in `HoneyDrunk.Architecture/repos/` at creation time, including any repo-specific scheduled workflows under a new `tracked_workflows` key.

**Current state:** the convention exists; the enforcement does not. Adding a repo to GitHub without adding it to the catalog is possible and silent. The aggregator simply does not see the new repo.

**Contract when built:** a weekly reconciliation step — either inside the grid-health aggregator itself or as a separate Architecture-repo workflow — that lists repos in the `HoneyDrunkStudios` GitHub org via `gh api`, diffs against the catalog, and reports missing entries in the Grid Health issue as a new "🟡 Catalog drift" section. Non-trivial because it needs org-scoped `gh api` access.

**Impact until resolved:** a new repo is invisible to grid observability until someone remembers to catalog it. Mitigation: the repo-creation runbook (follow-up above) includes the catalog update as a step.

**Priority:** low. Follow-up if catalog drift is observed in practice.

### Gap 5 — Action-pin deprecations are still tracked manually

**Promised (D10):** `HoneyDrunk.Actions/docs/action-pins.md` lists every third-party action pin with its deprecation status.

**Current state:** the file does not yet exist. Deprecation warnings (like the Node 20 warnings that surfaced in this ADR's triggering incident) are detected only by reading workflow run logs.

**Contract when built (optional):** a weekly workflow in `HoneyDrunk.Actions` that parses all `.github/workflows/*.yml` files, extracts `uses: <action>@<version>` pins, and cross-references against a hand-maintained deprecation calendar. Reports drift in the Grid Health issue as a new "📅 Action deprecations" section. Medium complexity, but every step is scripting.

**Impact until resolved:** deprecations are noticed only when a warning appears in a run log, usually long after the warning was first emitted. The cost of a missed deprecation is the grace period GitHub provides, which for Node 20 is several months. Not urgent.

**Priority:** low. The hand-maintained inventory (D10) is sufficient for now.

## Alternatives Considered

### Each repo owns its own CI configuration

Rejected. This is the status quo, and the triggering incident is the direct evidence that it does not scale. Shared configuration in N places drifts against itself on any timescale longer than a weekend. The per-repo model is viable only when "each repo" is one or two; the Grid is already at eleven and growing. Every prior Grid control-plane ADR (ADR-0002, ADR-0007, ADR-0008, ADR-0011) collapsed the same kind of distributed-by-default concern onto a single named location, and this ADR is the CI/CD-mechanics version of the same move.

### Pull shared configuration from `HoneyDrunk.Architecture` instead of `HoneyDrunk.Actions`

Rejected on sector grounds. `HoneyDrunk.Architecture` is the source of truth for **system topology** — what Nodes exist, how they relate, what invariants bind them, which ADRs govern which Nodes, what the catalogs say about relationships and contracts. `HoneyDrunk.Actions` is the source of truth for **pipeline mechanics** — how CI runs, what tools it uses, how those tools are configured, how workflows chain. A gitleaks allowlist regex is pipeline mechanics. A CodeQL query pack is pipeline mechanics. Putting them in Architecture would blur the sector boundary that every other Grid decision has been careful to draw, and would invite the same confusion for every future shared-config decision ("is this an architecture file or an actions file?"). Keeping the two repos cleanly separated by concern is cheap; blending them is not.

A softer version of this alternative was: "put shared config in Architecture because the repo catalog is already there, and the aggregator needs the catalog anyway." Rejected — the aggregator *reading* Architecture does not imply the config *living* in Architecture. Reader-writer separation is preserved.

### A dedicated `HoneyDrunk.CIConfig` repo

Rejected as premature. The mechanism in D2 works with a subdirectory of an existing repo, and the existing repo with the clearest ownership is `HoneyDrunk.Actions` (every caller already checks it out to load composite actions). A dedicated repo would add one more repo to clone, one more place for drift, one more GitHub repo to maintain access on, and would fragment the "where do CI/CD decisions land" answer for no concrete benefit at today's scale. If the shared-config surface grows to tens of files spanning many independent tools with conflicting release cadences, reconsider.

### Use `gitleaks/gitleaks-action@v2` properly via its env-var inputs

Rejected. The root-cause fix for the specific incident would be to replace `with: args: ...` with the env vars `gitleaks-action` actually reads (`GITLEAKS_CONFIG`, `GITLEAKS_ENABLE_COMMENTS`, etc.). This works for gitleaks specifically but leaves D4 unresolved: the next marketplace-action schema mismatch causes the next silent failure, and we have no policy guarding against it. The direct-CLI pattern is more code but is a durable policy and answers the general question, not just the specific instance.

### Grid health via status page or dashboard web app

Rejected as premature. A GitHub issue renders at a stable URL, shows up in the GitHub mobile app, supports @-mentions for urgent escalation, is notifiable via profile settings (D7), is searchable, and has zero hosting cost. Building a dashboard to serve the same information would require choosing a hosting platform, provisioning identity for the operator to log in, deciding on a retention policy, and operating it indefinitely — all for a single operator who is already in the GitHub UI all day. The issue-based UX is sufficient until the operator count grows beyond one. If a dashboard ever becomes justified, its data source is still the same aggregator workflow; the aggregator just writes to a different sink.

### Slack / Discord integration for failure notifications

Rejected for now. D7 (GitHub profile notifications) already delivers per-failure email at the moment of failure using a mechanism that exists and costs nothing to configure. A Slack/Discord integration would require a webhook, a channel, a bot identity, and a per-operator subscription. If HoneyDrunk Studios operations grow to multiple humans, reconsider by adding a webhook step to the grid-health aggregator; the aggregator step that writes the issue can equally well post a webhook payload. Today it is one operator, who reads email, and adding a third notification channel is overkill.

### Enforce caller permissions via a required lint check at PR time

Rejected for now and named as Gap 3. The lint is a small amount of Python or `yq` parsing the `permissions:` block of each caller workflow and comparing against the callee's own declared permissions. At today's growth rate, one-repo-a-year, the cost of writing and maintaining the lint outweighs the rarity of the bug it catches. Flagged as a follow-up if a second broken caller appears after this ADR's cleanup; the grid-health aggregator is the safety net that makes this decision reversible cheaply.

### Track CI/CD state in the existing `HoneyDrunk.Architecture/catalogs/grid-health.json`

Rejected on sector grounds, same as "pull shared config from Architecture." The existing `grid-health.json` is a **design-time** snapshot of topology health — do the repos declared in `repos/` actually exist on GitHub, do invariants 1–28 hold, are the catalogs internally consistent. It answers questions about the *structure* of the Grid as defined in `HoneyDrunk.Architecture`. Pipeline run state is operational — it answers questions about *what happened last night* — and operational state churns on a different cadence (daily), lives in a different system of record (GitHub Actions runs), and has different consumers (the operator looking at a failing workflow, not the agent validating grid topology). Mixing them into one file would produce a hybrid that serves neither purpose well. The aggregator issue and the topology snapshot are separate surfaces because they answer separate questions — and any agent consuming one would not want the other mixed in.

### A single reusable "full-pipeline" workflow that embeds all tools

Rejected. This was tried implicitly by the original `gitleaks-action` wrapping, and it failed — because embedding a tool in a workflow hides the tool's interface behind the workflow's interface, and the two drift. The correct factoring is: reusable workflows orchestrate *steps*; steps invoke *tools*; tools are configured by *files*; files live in `.github/config/` and are consumed at runtime. Each layer is single-purpose. A monolithic workflow collapses the factoring and regresses the durability gains from D2 and D4.

### Block failing workflows from being scheduled at all via branch protection

Rejected as not a thing. Branch protection is about PRs, not scheduled workflows. There is no GitHub primitive for "block this schedule from firing if the last run failed." The closest equivalent is a `workflow_dispatch`-only trigger and a manual re-enable, which defeats the purpose of running nightly. Grid health (D6) is the right answer: let failing schedules continue to fail (or stall), detect the state, surface it to the operator, and act.
