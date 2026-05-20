---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["ci", "tier-2", "ops", "adr-0033"]
dependencies: []
adrs: ["ADR-0033", "ADR-0012", "ADR-0015"]
accepts: ["ADR-0033"]
wave: 1
initiative: adr-0033-deploy-trigger-model
node: honeydrunk-notify
---

# Amend `release-functions.yml` for environment-gated deploy triggers

## Summary
Add a path-filtered push-to-`main` trigger that resolves to `dev`, make the trigger-to-environment mapping explicit in the `resolve` job, and add a `concurrency` block keyed on the resolved environment. Replace the existing "dev-only / tag-only — intentional, not a gap" header framing with the dual-trigger model decided in ADR-0033.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Notify`

## Target Workflow
**File:** `.github/workflows/release-functions.yml`
**Family:** release (consumer caller of `HoneyDrunk.Actions/.github/workflows/job-deploy-function.yml@main`)

## Motivation
The Notify.Functions release line currently fires only on `functions-v*` tag pushes plus `workflow_dispatch`. For a disposable `dev` environment under a continuous solo-dev + AI-agent merge cadence, requiring a tag per dev deploy is friction with no payoff — `dev` is never a promotion source, so its version-of-record is irrelevant there. Tag-gating must remain in place for `staging`/`prod` (when those are provisioned) because the CHANGELOG + SemVer tag is the version-of-record and the rollback target. ADR-0033 resolves this by adding a second trigger (push-to-`main`, path-filtered → `dev`) alongside the existing tag trigger and making the mapping explicit.

The reusable deploy workflow in `HoneyDrunk.Actions` is unchanged — it already accepts an `environment` input and has no opinion about what triggered the caller. Trigger policy belongs in the consumer `on:` block and cannot be centralized through `workflow_call` (this is the structural reason ADR-0012's invariant on reusable workflows is not violated).

## Proposed Change

### 1. `on:` block — add path-filtered push trigger
Add a `push: branches: [main]` trigger with a `paths:` filter scoped to **only `Notify.Functions`'s source**. The tag trigger remains unfiltered (a deliberately pushed tag is always deploy-intent). `workflow_dispatch` is retained as the manual escape hatch for both paths.

```yaml
on:
  push:
    branches: [main]
    paths:
      # Functions deployable source (the .csproj at .Functions/HoneyDrunk.Notify.Functions.csproj
      # is already covered by this glob — no standalone .csproj entry needed).
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Functions/**'
      # Shared libraries the Functions binary links against (per
      # HoneyDrunk.Notify.Functions.csproj ProjectReference graph): runtime
      # core, abstractions, hosting glue, the three provider packages, and
      # the HostBootstrap shared identity source. A change to any of these
      # produces a runtime behavior change in the deployed Functions binary
      # and must redeploy on main. D3 makes this an active correctness
      # concern, not a fire-and-forget setting.
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Hosting.AspNetCore/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Providers.Email.Smtp/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Providers.Email.Resend/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Providers.Sms.Twilio/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.HostBootstrap/**'
      # Solution file and the workflow itself.
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.slnx'
      - '.github/workflows/release-functions.yml'
    tags:
      - 'functions-v*'
  workflow_dispatch:
```

The Worker source (`HoneyDrunk.Notify/HoneyDrunk.Notify.Worker/**`) and Worker-only shared paths (`HoneyDrunk.Notify.Queue.*/**`) must **not** be in this filter (D4 — Functions-only commits must not redeploy the Worker; the Worker workflow has the symmetric filter for itself). The shared libraries listed above (`HoneyDrunk.Notify`, `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Notify.Hosting.AspNetCore`, the three Provider packages, `HoneyDrunk.Notify.HostBootstrap`) are legitimately referenced by **both** the Functions and Worker `.csproj` files — appearing in both workflows' filters is correct and intentional. D4 disjointness is preserved by the deployable-source-tree paths (`HoneyDrunk.Notify.Functions/**` vs. `HoneyDrunk.Notify.Worker/**`), not by the shared-library paths.

Forward-looking note: `Directory.Build.props` and `Directory.Packages.props` do not currently exist in the HoneyDrunk.Notify repo. If they are added later (centralized package versioning, shared MSBuild properties), the implementing agent must add them to this filter at that time — they would affect the build of every project in the solution.

### 2. `resolve` job — explicit trigger-to-environment mapping
The `resolve` job is the single place trigger intent is mapped to a target environment. Today it hard-codes `environment: dev`. Replace that with an explicit conditional resolution emitting a `target_environment` output that all downstream jobs consume.

```yaml
  resolve:
    name: Resolve target environment and config
    runs-on: ubuntu-latest
    # ADR-0033 D2: trigger intent is mapped here, once, explicitly.
    # - refs/tags/functions-v*  -> promotion environment (staging / prod when
    #   provisioned; for now, no tag-driven promotion is wired beyond dev — a
    #   tag still resolves to `dev` until the environment value is decided per
    #   ADR-0033 D6 at staging/prod stand-up).
    # - refs/heads/main         -> dev (continuous deploy of the disposable env).
    # - workflow_dispatch       -> dev (manual escape hatch on the same path).
    environment: dev
    outputs:
      target_environment: dev
      functions-app: func-hd-notify-${{ vars.HD_ENV }}
      resource-group: rg-hd-notify-${{ vars.HD_ENV }}
      keyvault-name: kv-hd-notify-${{ vars.HD_ENV }}
      azure-client-id: ${{ vars.AZURE_CLIENT_ID }}
      azure-tenant-id: ${{ vars.AZURE_TENANT_ID }}
      azure-subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
    steps:
      - name: Echo resolved targets
        run: |
          echo "Trigger      : ${{ github.event_name }} / ${{ github.ref }}"
          echo "Environment  : dev"
          echo "Function App : func-hd-notify-${{ vars.HD_ENV }}"
          echo "Resource Grp : rg-hd-notify-${{ vars.HD_ENV }}"
          echo "Key Vault    : kv-hd-notify-${{ vars.HD_ENV }}"
```

The `target_environment: dev` output is the explicit-mapping anchor: today both paths resolve to `dev`, but the value lives in the `outputs:` block — not implicitly via `vars.HD_ENV` — so the staging/prod conditional (D6) is added in one place when those environments are provisioned. The downstream `deploy` job consumes `needs.resolve.outputs.target_environment` instead of the literal string `dev`.

### 3. `concurrency` block — keyed on resolved environment
Add a top-level `concurrency` block that keys on the resolved environment so dev churn never cancels a staging/prod promotion (D5). Dev (branch-push path) sets `cancel-in-progress: true` to supersede in-flight dev deploys; tag path sets `cancel-in-progress: false` so deliberate versioned promotions queue rather than being silently cancelled.

```yaml
concurrency:
  # Dev branch pushes share a single key and supersede each other (latest main wins).
  # Tag promotions get their own per-ref key and queue (never cancel-in-progress).
  # Single-line expression form is the well-known-safe shape — GitHub Actions
  # expression parsing across newlines inside ${{ }} has bitten projects in
  # the past. Keep this on one line.
  group: release-functions-${{ startsWith(github.ref, 'refs/tags/') && format('tag-{0}', github.ref_name) || 'dev' }}
  cancel-in-progress: ${{ !startsWith(github.ref, 'refs/tags/') }}
```

### 4. `deploy` job — consume resolved environment
Change the `deploy` job to pass `environment: ${{ needs.resolve.outputs.target_environment }}` to the reusable workflow rather than the literal `dev`. No other inputs change. The reusable workflow's behavior is unchanged.

The existing `build` job's structure and `needs:` chain is unchanged — it fires under both triggers (branch push and tag push) and its restore/build/test/publish/upload-artifact sequence stays as-is. The trigger-model change is purely in the `on:` block, the `resolve` job's outputs, the top-level `concurrency` block, and the `deploy` job's `environment` input.

**No `image-tag` adjustment in this packet.** Functions deploy publishes a `.zip` artifact (via `actions/upload-artifact`) consumed by `job-deploy-function.yml`, not a tagged container image. Packets 02 and 03 add a SHA-derived branch-path image tag for their respective Container App deployables — that machinery does not apply here.

### 5. Header comment block — replace dev-only/tag-only framing
Replace the existing header lines (currently "A `functions-v*` tag therefore deploys to dev and nothing else — intentional, not a gap.") with the dual-trigger framing per ADR-0033:

```yaml
# Dual-trigger release for Notify.Functions:
#
#  - push to main, path-filtered to Notify.Functions sources  -> dev
#  - functions-v* tag, unfiltered                              -> staging / prod
#                                                                 (when provisioned)
#  - workflow_dispatch                                          -> manual escape hatch
#
# Trigger intent is mapped to environment in the `resolve` job (single source).
# The reusable deploy workflow in HoneyDrunk.Actions takes an `environment`
# input and has no opinion about what triggered the caller — trigger policy is
# consumer-owned by construction (ADR-0012 invariant on reusable workflows
# is unchanged: the `on:` block cannot be centralized through workflow_call).
#
# Path filter (D3/D4): scoped to Notify.Functions' own source only. A
# Worker-only commit must not redeploy Functions (the Worker workflow has the
# symmetric filter for itself).
#
# Concurrency (D5): keyed on the resolved environment. Dev branch pushes
# supersede in-flight dev deploys (latest main wins). Tag promotions queue
# (cancel-in-progress: false) so a deliberate versioned promotion is never
# silently cancelled by a later one.
#
# The version-of-record rule (CHANGELOG + SemVer tag) is unchanged: a
# push-to-main dev deploy has no version stamp by design and is explicitly
# not a promotion source.
```

The previous `# Environment scope: dev only, by design.` paragraph is removed wholesale — it is superseded.

## Consumer Impact
No consumer impact. This is a consumer release workflow; nothing else consumes it. `HoneyDrunk.Actions/.github/workflows/job-deploy-function.yml@main` is the upstream and is unchanged.

## Breaking Change?
- [x] No — backward compatible at the trigger level. The existing `functions-v*` tag trigger still deploys to dev as it does today. The new `main` branch-push trigger is additive.
- [ ] Yes — consumers need to update their caller workflows

## Affected Files
- `.github/workflows/release-functions.yml` — header comment, `on:` block, `resolve` job (outputs + comment), top-level `concurrency` block, `deploy` job input.
- `CHANGELOG.md` — repo-level entry for "ADR-0033: environment-gated deploy triggers for Notify.Functions."

No application code changes. No new packages.

## NuGet Dependencies
None. This is a workflow-only change; no `.csproj` files are touched.

## Boundary Check
- [x] Workflow-only change. No Transport contract change, no `HoneyDrunk.Actions` change (the reusable workflow is consumed as-is).
- [x] Trigger policy is irreducibly per-consumer-repo (a `workflow_call` reusable workflow cannot own the caller's `on:` block) — the ADR-0012 invariant on reusable workflows is preserved exactly as written.
- [x] Path filter is scoped to **only `Notify.Functions`** — a Worker-only commit must not redeploy Functions, per D4. This is enforced here in the Functions filter; the symmetric enforcement lives in the Worker workflow (packet 02).

## Acceptance Criteria
- [ ] `on:` block includes both the path-filtered `push: branches: [main]` trigger and the existing `push: tags: ['functions-v*']` trigger, plus `workflow_dispatch`.
- [ ] The `main` path filter includes `HoneyDrunk.Notify/HoneyDrunk.Notify.Functions/**`, the solution `.slnx`, the workflow file itself, and the shared library projects the Functions binary links against per `HoneyDrunk.Notify.Functions.csproj`'s `ProjectReference` graph: `HoneyDrunk.Notify/**`, `HoneyDrunk.Notify.Abstractions/**`, `HoneyDrunk.Notify.Hosting.AspNetCore/**`, `HoneyDrunk.Notify.Providers.Email.Smtp/**`, `HoneyDrunk.Notify.Providers.Email.Resend/**`, `HoneyDrunk.Notify.Providers.Sms.Twilio/**`, `HoneyDrunk.Notify.HostBootstrap/**`. The filter **does not** include any path under `HoneyDrunk.Notify/HoneyDrunk.Notify.Worker/` or under any `HoneyDrunk.Notify.Queue.*` package (Worker-only).
- [ ] No standalone `HoneyDrunk.Notify.Functions.csproj` entry in the filter — the file is at `HoneyDrunk.Notify/HoneyDrunk.Notify.Functions/HoneyDrunk.Notify.Functions.csproj` and is already covered by the project-directory glob.
- [ ] `Directory.Build.props` / `Directory.Packages.props` are **not** listed in the filter (they do not currently exist in HoneyDrunk.Notify). If they are added later, this filter must be updated at the same time.
- [ ] `resolve` job emits a `target_environment` output (literal `dev` today; explicit-mapping anchor for future staging/prod conditional per D6).
- [ ] The `deploy` job consumes `needs.resolve.outputs.target_environment` rather than the literal string `dev`.
- [ ] Top-level `concurrency` block exists, group key includes the resolved environment (or `tag-<ref_name>` for the tag path), and `cancel-in-progress` is `true` on the dev branch-push path / `false` on the tag path.
- [ ] Header comment block describes the dual-trigger model and explicitly removes the prior "dev-only / tag-only — intentional, not a gap" framing.
- [ ] Test 1 (branch-push path, in-filter): a no-op commit to `HoneyDrunk.Notify/HoneyDrunk.Notify.Functions/README.md` on `main` (or equivalent in-filter file) triggers `release-functions.yml`, resolves to `dev`, and runs through to a successful deploy.
- [ ] Test 2 (branch-push path, out-of-filter / Worker-only): a no-op commit to `HoneyDrunk.Notify/HoneyDrunk.Notify.Worker/README.md` on `main` does **not** trigger `release-functions.yml`. Verified by inspecting the Actions run list for the commit SHA.
- [ ] Test 3 (tag path): pushing a `functions-v*` tag still triggers `release-functions.yml`, resolves to `dev`, deploys, and the `concurrency` group uses the `tag-<ref_name>` key with `cancel-in-progress: false`.
- [ ] Test 4 (dev supersession): two rapid in-filter pushes to `main` produce two workflow runs in the same `dev` concurrency group; the older run is cancelled by GitHub Actions ("Canceled" in the Actions UI). The latest `main` wins.
- [ ] Test 5 (tests-only commit, out-of-filter): a no-op commit under `HoneyDrunk.Notify/HoneyDrunk.Notify.Tests/**` or `HoneyDrunk.Notify/HoneyDrunk.Notify.IntegrationTests/**` on `main` does **not** trigger `release-functions.yml`. Test projects are explicitly outside the filter — they affect the gate (PR `pr.yml`) but not the deploy.
- [ ] `CHANGELOG.md` updated under the appropriate dated version section (no commits under `Unreleased` — move to a dated SemVer section before merge, per the no-Unreleased-commits convention). This is a CI/workflow change — no `.csproj` version bump.
- [ ] No ADR number appears in the workflow header comment, code comments, or `CHANGELOG.md` prose. The runtime packet-data reference `adr-0033` is acceptable only as packet-data identifier in this packet's frontmatter.

## Human Prerequisites
None. The `dev` GitHub Environment, OIDC federated credentials, and Azure resources for `func-hd-notify-dev` are already in place from the ADR-0015 rollout. ADR-0033 D7 explicitly mandates that the `dev` environment remain unprotected (no required-reviewer rule), so no environment-protection change is needed; verify in the GitHub Environment settings that `dev` has no required reviewers before merging.

**Branch protection note.** Release workflow runs are **not** required checks on the `main` branch-protection rule. The PR-side checks (`pr.yml`) remain the merge gate; a release that fails *after* merge is a deploy concern (revert PR or hot-fix), not a branch-protection concern. Do not add the new dual-trigger release workflow to required checks on `main` — doing so would block merges while waiting for a post-merge deploy.

## Referenced ADR Decisions

**ADR-0033 D1 — Trigger model per environment.** Each consumer release workflow gains a second trigger alongside its existing tag trigger: push to `main` path-filtered → `dev`; SemVer-shaped tag unfiltered → staging/prod (when provisioned); `workflow_dispatch` retained as the manual escape hatch for both paths.

**ADR-0033 D2 — Trigger-to-environment resolution is explicit.** The `resolve` job is the single place trigger intent is mapped to a target environment. A tag ref resolves the promotion environment; a `main` branch push resolves `dev`. The mapping is an explicit conditional/output in `resolve`, not inferred implicitly from `vars.HD_ENV` and not scattered across jobs.

**ADR-0033 D3 — Path filtering is part of the decision, not optional.** The `push: branches: [main]` trigger carries a `paths:` filter scoped to **that deployable's own source** — its project directory and `.csproj`, plus solution-level inputs that affect its build. The tag trigger is **not** path-filtered: a deliberately pushed tag is always deploy-intent.

**ADR-0033 D4 — Multi-deployable repos: per-deployable independence.** In HoneyDrunk.Notify (two deployables: `Notify.Functions` on `functions-v*` / `Notify.Functions/`, and `Notify.Worker` on `worker-v*` / `Notify.Worker/`), each release workflow's push-to-`main` path filter is scoped to **only its own** deployable's source. A Functions-only commit must not redeploy the Worker, and vice versa.

**ADR-0033 D5 — Concurrency.** Each release workflow declares a `concurrency` group whose key includes the **resolved environment**, so dev churn can never cancel a staging/prod promotion. Dev (branch-push path): `cancel-in-progress: true`. Tag (promotion path): `cancel-in-progress: false`.

**ADR-0033 D7 — `dev` remains an unprotected GitHub Environment by design.** A required-reviewer protection rule on the `dev` GitHub Environment would block push-to-`main` deploys on approval, defeating the purpose of D1. Environment protection rules are the mechanism for `staging`/`prod` only.

**ADR-0033 D8 — Relationship to ADR-0012 and ADR-0015.** This decision clarifies ADR-0012 without changing any of its invariants: trigger policy is consumer-workflow-owned (the `on:` block, inherently per-repo); deploy mechanics remain control-plane-owned. No `catalogs/relationships.json` edge changes — this is CI trigger policy, not a Node contract or dependency-graph change. No `HoneyDrunk.Actions` PR is part of this initiative.

## Dependencies
None. This packet does not depend on packets 02 or 03 — the three workflow amendments are independent and can land in any order.

## Labels
`ci`, `tier-2`, `ops`, `adr-0033`

## Agent Handoff

**Objective:** Amend `release-functions.yml` in HoneyDrunk.Notify to support environment-gated deploy triggers per ADR-0033 — path-filtered push-to-`main` → `dev` alongside the existing tag-driven promotion path, with explicit `resolve` mapping and environment-keyed concurrency.

**Target:** HoneyDrunk.Notify, branch from `main`.

**Context:**
- Goal: Remove tag-cutting ceremony from continuous dev deploys while preserving SemVer-tagged promotion for staging/prod (when provisioned).
- Feature: ADR-0033 initiative (`adr-0033-deploy-trigger-model`).
- ADRs: ADR-0033 (this decision), ADR-0012 (CI/CD control plane — unchanged), ADR-0015 (hosting — unchanged).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- **ADR-0012 invariant — deploy logic in HoneyDrunk.Actions only.** `release-functions.yml` must continue to consume `HoneyDrunk.Actions/.github/workflows/job-deploy-function.yml@main` for deploy mechanics. No deploy logic (Azure login, artifact handling, traffic shift, health probe) may be inlined into this workflow. Trigger policy (the `on:` block, the `resolve` mapping, the `concurrency` block) is consumer-owned by construction and is the only surface this packet edits.
- **Invariant 8 (secrets in telemetry):** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. The workflow's `Echo resolved targets` step must continue to echo only resource names and refs — never secret values.
- **Invariant 9 (Vault as the only source of secrets):** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. The trigger-model change does not relax this; provider credentials still resolve through the existing Vault bootstrap on the Function App.
- **Path-filter correctness (D4):** A Worker-only commit must not redeploy Functions. The `paths:` list under `push: branches: [main]` must not include any `HoneyDrunk.Notify.Worker/**` entry. Reviewer checks both this packet's filter and packet 02's (Worker) filter for symmetric correctness.
- **Concurrency key composition (D5):** The `concurrency.group` expression must produce a different key for the tag path than for any dev branch-push path. A naive `group: release-functions-${{ github.ref }}` is wrong because rapid main pushes would still queue each other if `github.ref` differs per commit (it does not — `refs/heads/main` is stable — but the failure mode to avoid is folding tag and branch into the same key). The expression shown under D5 above is the canonical form.
- **No version-of-record drift.** Push-to-`main` dev deploys have no version stamp by design. The deploy artifact for the dev path is identified by commit SHA only. Do not introduce a tag-on-push or `version` input to compensate — that would resurrect tag-cutting friction and defeat D1.
- **Header comment is not optional.** The replacement header text must be in place; the prior "dev-only / tag-only — intentional, not a gap" sentence must be deleted. The ADR explicitly supersedes that framing (D8 / Follow-up Work). No ADR number in the comment per Grid doc convention.

**Key Files:**
- `.github/workflows/release-functions.yml` — the only file authored.
- `CHANGELOG.md` — repo-level entry under a dated SemVer section (not under `Unreleased`).

**Contracts:** None changed. This is CI trigger policy, not a Node contract or dependency-graph change. No `catalogs/relationships.json` edge changes.
