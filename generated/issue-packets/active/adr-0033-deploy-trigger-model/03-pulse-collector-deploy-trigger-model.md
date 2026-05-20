---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["ci", "tier-2", "ops", "adr-0033"]
dependencies: []
adrs: ["ADR-0033", "ADR-0012", "ADR-0015"]
accepts: ["ADR-0033"]
wave: 1
initiative: adr-0033-deploy-trigger-model
node: honeydrunk-pulse
---

# Amend `release-collector.yml` for environment-gated deploy triggers

## Summary
Add a path-filtered push-to-`main` trigger that resolves to `dev`, make the trigger-to-environment mapping explicit in the `resolve` job, and add a `concurrency` block keyed on the resolved environment. Replace the existing dev-only/tag-only header framing with the dual-trigger model decided in ADR-0033. HoneyDrunk.Pulse is a single-deployable repo, so D4 (per-deployable independence) is trivially satisfied — the path filter is scoped to `Pulse.Collector`'s source plus solution-level inputs, with no sibling-deployable exclusion concern.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Pulse`

## Target Workflow
**File:** `.github/workflows/release-collector.yml`
**Family:** release (consumer caller of `HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml@main`)

## Motivation
Same motivation as packets 01 and 02 in this initiative: remove tag-cutting ceremony from continuous dev deploys to a disposable environment while preserving SemVer-tagged promotion for staging/prod. Pulse.Collector is a gRPC Container App; the trigger-model change is orthogonal to the hosting decision and applies uniformly across the three deployable lines.

D4 is trivially satisfied for this workflow because HoneyDrunk.Pulse has only one deployable today. The path filter still gets scoped tightly to Pulse.Collector's source under D3 (path filtering is part of the decision, not optional) — so if a second Pulse deployable is added later, the existing filter is already correct.

## Proposed Change

### 1. `on:` block — add path-filtered push trigger
Add a `push: branches: [main]` trigger with a `paths:` filter scoped to Pulse.Collector's source plus solution-level inputs that affect its build. The tag trigger remains unfiltered. `workflow_dispatch` is retained.

```yaml
on:
  push:
    branches: [main]
    paths:
      # Collector deployable source. Dockerfile and proto files live under
      # Pulse.Collector/ — covered by this glob.
      - 'HoneyDrunk.Pulse/Pulse.Collector/**'
      # Pulse libraries the Collector binary links against (per
      # HoneyDrunk.Pulse.Collector.csproj ProjectReference graph): contracts,
      # telemetry abstractions, telemetry OpenTelemetry pipeline, and all
      # telemetry sink packages (AzureMonitor, Loki, Mimir, PostHog, Sentry,
      # Tempo — covered by the .Sink.* glob, which also catches Sink.Shared).
      # A change to any of these produces a runtime behavior change in the
      # deployed Collector binary and must redeploy on main.
      - 'HoneyDrunk.Pulse/HoneyDrunk.Pulse.Contracts/**'
      - 'HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Abstractions/**'
      - 'HoneyDrunk.Pulse/HoneyDrunk.Telemetry.OpenTelemetry/**'
      - 'HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.*/**'
      # Solution file and the workflow itself.
      - 'HoneyDrunk.Pulse/HoneyDrunk.Pulse.slnx'
      - '.github/workflows/release-collector.yml'
    tags:
      - 'collector-v*'
  workflow_dispatch:
```

Forward-looking note: `Directory.Build.props` and `Directory.Packages.props` do not currently exist in HoneyDrunk.Pulse. If they are added later (centralized package versioning, shared MSBuild properties), the implementing agent must add them to this filter at the same time — they would affect the build of every project in the solution.

The library set above was reconciled against `HoneyDrunk.Pulse.Collector.csproj`'s `ProjectReference` graph at scope time. The Sink glob `HoneyDrunk.Telemetry.Sink.*/**` covers `Sink.AzureMonitor`, `Sink.Loki`, `Sink.Mimir`, `Sink.PostHog`, `Sink.Sentry`, `Sink.Tempo`, and `Sink.Shared` — all sink packages present in the repo. A path filter that is too narrow makes dev silently stop auto-deploying on a meaningful change (a fail-safe no-op per ADR-0033 Operational Consequences, but invisible to grid-health today); a filter that is too wide costs only an extra dev revision per unrelated commit. The Sink-glob is a deliberate lean-slightly-wide call to preserve future sink additions automatically.

### 2. `resolve` job — explicit trigger-to-environment mapping
Replace the hard-coded `environment: dev` resolution with an explicit `target_environment` output. Pulse uses underscore-named outputs in its `resolve` block (a deliberate choice noted in the existing file comment to avoid hyphenated-context-key ambiguity in dot-notation) — keep that convention.

```yaml
  resolve:
    name: Resolve target environment and config
    runs-on: ubuntu-latest
    # ADR-0033 D2: trigger intent is mapped here, once, explicitly.
    # - refs/tags/collector-v*  -> promotion environment (staging / prod when
    #   provisioned; for now resolves to `dev` per ADR-0033 D6).
    # - refs/heads/main         -> dev (continuous deploy of the disposable env).
    # - workflow_dispatch       -> dev (manual escape hatch on the same path).
    environment: dev
    # Output names use underscores (not hyphens). Dot-notation access
    # (needs.resolve.outputs.acr_registry) is unambiguous this way — avoids
    # any reader/linter doubt about hyphenated context keys. Convention
    # established before this packet; preserved.
    outputs:
      target_environment: dev
      acr_registry: acrhdshared${{ vars.HD_ENV }}.azurecr.io
      container_app: ca-hd-pulse-${{ vars.HD_ENV }}
      resource_group: rg-hd-pulse-${{ vars.HD_ENV }}
      keyvault_name: kv-hd-pulse-${{ vars.HD_ENV }}
      azure_client_id: ${{ vars.AZURE_CLIENT_ID }}
      azure_tenant_id: ${{ vars.AZURE_TENANT_ID }}
      azure_subscription_id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
    steps:
      - name: Echo resolved targets
        run: |
          echo "Trigger       : ${{ github.event_name }} / ${{ github.ref }}"
          echo "Environment   : dev"
          echo "Container App : ca-hd-pulse-${{ vars.HD_ENV }}"
          echo "Resource Grp  : rg-hd-pulse-${{ vars.HD_ENV }}"
          echo "ACR           : acrhdshared${{ vars.HD_ENV }}.azurecr.io"
          echo "Key Vault     : kv-hd-pulse-${{ vars.HD_ENV }}"
```

The downstream `deploy` job consumes `needs.resolve.outputs.target_environment` instead of the literal `dev`.

### 3. `concurrency` block — keyed on resolved environment
Same form as packets 01 and 02. Prefix is `release-collector-`.

```yaml
concurrency:
  # Dev branch pushes share a single key and supersede each other (latest main wins).
  # Tag promotions get their own per-ref key and queue (never cancel-in-progress).
  # Single-line expression form is the well-known-safe shape — keep on one line.
  group: release-collector-${{ startsWith(github.ref, 'refs/tags/') && format('tag-{0}', github.ref_name) || 'dev' }}
  cancel-in-progress: ${{ !startsWith(github.ref, 'refs/tags/') }}
```

### 4. `deploy` job — consume resolved environment + SHA-derived image tag on branch path
Mirror the packet 02 change to `image-tag`: SemVer tag verbatim on the tag path; `dev-<sha>` on the branch path. Image-per-commit on dev preserves the ACR rollback trail (ADR-0015 Container Apps `Multiple` revision mode depends on it).

```yaml
      # Tag path: use the SemVer tag verbatim (e.g. collector-v0.1.0).
      # Branch path: use a SHA-derived tag (dev-<sha>, full 40-char SHA from
      # github.sha) — image-per-commit rather than a moving `main` tag, so
      # ACR has the artifact-per-deploy trail that revision-based rollback
      # (ADR-0015) expects. Full SHA is intentional: simpler than a short-sha
      # output step, and ACR has no tag-length friction at 40 chars.
      # Single-line expression form is the well-known-safe shape.
      image-tag: ${{ startsWith(github.ref, 'refs/tags/') && github.ref_name || format('dev-{0}', github.sha) }}
```

The `environment` input becomes `${{ needs.resolve.outputs.target_environment }}`. Reusable-workflow input names stay hyphenated (`environment`, `image-tag`, etc.) — the underscore/hyphen split is consumer outputs vs. reusable-workflow inputs and stays as the file's existing comment explains.

### 5. Header comment block — replace dev-only/tag-only framing
The current header text frames the dev-only/tag-only scope implicitly via "Push a tag like `collector-v0.1.0` to … deploy". Replace it with the dual-trigger framing. The "Replaces the previous App Service slot-swap deploy.yml" sentence is historical context and stays.

```yaml
# Dual-trigger release for Pulse.Collector:
#
#  - push to main, path-filtered to Pulse.Collector sources  -> dev
#  - collector-v* tag, unfiltered                             -> staging / prod
#                                                                (when provisioned)
#  - workflow_dispatch                                         -> manual escape hatch
#
# Trigger intent is mapped to environment in the `resolve` job (single source).
# The reusable deploy workflow in HoneyDrunk.Actions takes an `environment`
# input and has no opinion about what triggered the caller — trigger policy is
# consumer-owned by construction.
#
# Path filter (D3): scoped to Pulse.Collector's own source plus the Pulse
# libraries it links against, plus solution-level build inputs. HoneyDrunk.Pulse
# has a single deployable today, so D4 (per-deployable independence) is
# trivially satisfied; if a second Pulse deployable is added later, this
# filter is already correctly scoped.
#
# Concurrency (D5): keyed on the resolved environment. Dev branch pushes
# supersede in-flight dev deploys (latest main wins). Tag promotions queue
# (cancel-in-progress: false) so a deliberate versioned promotion is never
# silently cancelled by a later one.
#
# Image tag composition: SemVer tag verbatim on the tag path; dev-<sha> on
# the branch path (full 40-char github.sha — not a short-sha). Image-per-commit
# on dev preserves the rollback trail in ACR for revision-based rollback.
#
# The version-of-record rule (CHANGELOG + SemVer tag) is unchanged: a
# push-to-main dev deploy has no version stamp by design and is explicitly
# not a promotion source.
```

The current paragraph that does not exist verbatim ("dev-only / tag-only — intentional, not a gap" framing is implicit in this file rather than spelled out as in the Notify files) is superseded by the dual-trigger framing. Any sentence implying tag-only scope is removed.

## Consumer Impact
None. Consumer release workflow; not consumed by anything else.

## Breaking Change?
- [x] No — backward compatible at the trigger level. The `collector-v*` tag trigger still deploys to dev as today. The new `main` branch-push trigger is additive. Image-tag change is internal.
- [ ] Yes — consumers need to update their caller workflows

## Affected Files
- `.github/workflows/release-collector.yml` — header comment, `on:` block, `resolve` job (outputs + comment), top-level `concurrency` block, `deploy` job inputs.
- `CHANGELOG.md` — repo-level entry under a dated SemVer section.

No application code changes. No new packages.

## NuGet Dependencies
None. Workflow-only change.

## Boundary Check
- [x] Workflow-only change. No `HoneyDrunk.Actions` change.
- [x] Trigger policy is irreducibly per-consumer-repo. ADR-0012 invariant on reusable workflows preserved.
- [x] D4 trivially satisfied (single deployable). D3 filter is still tight per the path-filtering-is-part-of-the-decision rule.
- [x] Image-tag derivation is a caller-side input value, not deploy mechanics.

## Acceptance Criteria
- [ ] `on:` block includes both the path-filtered `push: branches: [main]` trigger and the existing `push: tags: ['collector-v*']` trigger, plus `workflow_dispatch`.
- [ ] The `main` path filter includes `HoneyDrunk.Pulse/Pulse.Collector/**`, the solution `.slnx`, the workflow file itself, and the Pulse library projects that the Collector binary links against per `HoneyDrunk.Pulse.Collector.csproj`'s `ProjectReference` graph: `HoneyDrunk.Pulse.Contracts/**`, `HoneyDrunk.Telemetry.Abstractions/**`, `HoneyDrunk.Telemetry.OpenTelemetry/**`, and the `HoneyDrunk.Telemetry.Sink.*/**` glob (covering AzureMonitor, Loki, Mimir, PostHog, Sentry, Tempo, and Sink.Shared).
- [ ] `Directory.Build.props` / `Directory.Packages.props` are **not** listed in the filter (they do not currently exist in HoneyDrunk.Pulse). If they are added later, this filter must be updated at the same time.
- [ ] `resolve` job emits a `target_environment` output (literal `dev` today; explicit-mapping anchor for D6). Underscore-naming convention preserved.
- [ ] The `deploy` job consumes `needs.resolve.outputs.target_environment` rather than the literal string `dev`.
- [ ] The `image-tag` input is computed: SemVer tag on the tag path; `dev-<sha>` on the branch path (full 40-char `github.sha`). Verified by inspecting two real deploys — ACR shows two distinct image tags.
- [ ] Top-level `concurrency` block exists with prefix `release-collector-`, group key includes the resolved environment (or `tag-<ref_name>` for the tag path), and `cancel-in-progress` is `true` on the dev branch-push path / `false` on the tag path.
- [ ] Header comment block describes the dual-trigger model and removes any framing implying tag-only scope. The "Replaces the previous App Service slot-swap deploy.yml" historical paragraph stays.
- [ ] Test 1 (branch-push path, in-filter): a no-op commit to `HoneyDrunk.Pulse/Pulse.Collector/README.md` on `main` triggers `release-collector.yml`, resolves to `dev`, builds an image tagged `dev-<sha>` (full 40-char SHA), and rolls a new revision on `ca-hd-pulse-dev`.
- [ ] Test 2 (branch-push path, out-of-filter): a no-op commit to a Pulse repo file outside the filter set (e.g. a doc-only edit under `HoneyDrunk.Pulse/docs/` if such a path exists, or any file in the repo root that is not in the filter) does **not** trigger `release-collector.yml`. Verified in the Actions run list for the commit SHA.
- [ ] Test 3 (tag path): pushing a `collector-v*` tag still triggers `release-collector.yml`, resolves to `dev`, deploys with the SemVer tag as the image tag, and the `concurrency` group uses the `tag-<ref_name>` key with `cancel-in-progress: false`.
- [ ] Test 4 (dev supersession): two rapid in-filter pushes to `main` produce two workflow runs in the same `dev` concurrency group; the older run is cancelled.
- [ ] Test 5 (tests-only commit, out-of-filter): a no-op commit under `HoneyDrunk.Pulse/Pulse.Tests/**` on `main` does **not** trigger `release-collector.yml`. Test projects are outside the filter — they affect the PR gate, not the deploy.
- [ ] `CHANGELOG.md` updated under a dated SemVer section. No commits under `Unreleased`.
- [ ] No ADR number in workflow header comment, code comments, or `CHANGELOG.md` prose. Packet-data identifier `adr-0033` acceptable only in frontmatter.

## Human Prerequisites
None. The `dev` GitHub Environment, OIDC federated credentials, `acrhdshared{env}`, `cae-hd-{env}`, and `ca-hd-pulse-dev` are already in place from the ADR-0015 rollout. Per ADR-0033 D7, `dev` must remain an unprotected GitHub Environment — verify in the GitHub Environment settings before merging.

**Branch protection note.** Release workflow runs are **not** required checks on the `main` branch-protection rule. The PR-side checks (`pr.yml`) remain the merge gate; a release that fails *after* merge is a deploy concern, not a branch-protection concern. Do not add `release-collector.yml` to required checks on `main`.

## Referenced ADR Decisions

**ADR-0033 D1 — Trigger model per environment.** Push-to-`main` path-filtered → `dev`; SemVer-shaped tag (`collector-v*`) unfiltered → staging/prod (when provisioned); `workflow_dispatch` retained.

**ADR-0033 D2 — Trigger-to-environment resolution is explicit.** Single mapping point in `resolve`; `target_environment` output.

**ADR-0033 D3 — Path filtering is part of the decision, not optional.** The branch-push trigger carries a `paths:` filter scoped to Pulse.Collector's own source plus the libraries it links against plus solution-level build inputs. The tag trigger is unfiltered.

**ADR-0033 D4 — Multi-deployable repos: per-deployable independence.** Trivially satisfied — HoneyDrunk.Pulse has a single deployable. Filter is still tight per D3.

**ADR-0033 D5 — Concurrency.** Dev path `cancel-in-progress: true`; tag path `cancel-in-progress: false`. Key includes the resolved environment.

**ADR-0033 D6 — Stated promotion model for staging/prod (deferred but decided).** When `staging`/`prod` are provisioned, a `collector-v*` tag cut from a `main` commit that has already been dev-deployed and observed will rebuild from the tagged source through the same reusable deploy workflow. Identical-artifact promotion is explicitly deferred. This packet does not implement staging/prod resolution; it leaves the explicit-mapping anchor (`target_environment` output) in place for that future change.

**ADR-0033 D7 — `dev` remains an unprotected GitHub Environment by design.**

**ADR-0033 D8 — Relationship to ADR-0012 and ADR-0015.** ADR-0012 invariant on reusable workflows preserved (deploy mechanics unchanged). ADR-0015's `Multiple`-revision Container Apps hosting unchanged. No `catalogs/relationships.json` edge changes.

**ADR-0015 (referenced):** Container Apps revision mode is `Multiple` with explicit traffic splitting on deploy. The branch-push path produces a new revision per commit, which is the correct shape for revision-based rollback. ADR-0033 Operational Consequences names dev revision accumulation as a known follow-up under ADR-0015, low priority — not solved here.

## Dependencies
None. Independent of packets 01 and 02 (different repo, no shared state).

## Labels
`ci`, `tier-2`, `ops`, `adr-0033`

## Agent Handoff

**Objective:** Amend `release-collector.yml` in HoneyDrunk.Pulse to support environment-gated deploy triggers per ADR-0033 — path-filtered push-to-`main` → `dev`, explicit `resolve` mapping, environment-keyed concurrency, SHA-derived image tag on the branch path.

**Target:** HoneyDrunk.Pulse, branch from `main`.

**Context:**
- Goal: Continuous dev deploys without tag-cutting friction, preserved promotion path for staging/prod.
- Feature: ADR-0033 initiative (`adr-0033-deploy-trigger-model`).
- ADRs: ADR-0033 (this decision), ADR-0012 (CI/CD control plane — unchanged), ADR-0015 (Container Apps hosting — unchanged).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- **ADR-0012 invariant — deploy logic in HoneyDrunk.Actions only.** The reusable `job-deploy-container-app.yml@main` is consumed verbatim. The only deploy-mechanics-adjacent change is the `image-tag` input expression in the caller — computing an input value is not implementing deploy logic.
- **Invariant 8 (secrets in telemetry):** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. The `Echo resolved targets` step echoes only resource names and refs.
- **Invariant 9 (Vault as the only source of secrets):** Vault is the only source of secrets. The trigger-model change does not relax this; Pulse.Collector resolves its Key Vault secrets via Managed Identity at runtime as today.
- **Path filter scope correctness (D3):** The filter must include Pulse.Collector's source and the library projects Pulse.Collector links against. The library set in the proposed filter was reconciled against `HoneyDrunk.Pulse.Collector.csproj`'s `ProjectReference` entries at scope time. Re-verify at implementation time before committing — a too-narrow filter causes silent dev no-deploys on meaningful library changes (fail-safe but invisible per ADR-0033 Operational Consequences). When in doubt, lean slightly wide on the library set; the cost is an extra dev revision per unrelated commit, which is bounded.
- **Underscore-naming convention in `resolve` outputs is preserved.** The existing file uses `acr_registry`, `container_app`, etc. — deliberate per the in-file comment. The new `target_environment` output follows the same convention. Reusable-workflow input names on the `deploy` job remain hyphenated; the underscore/hyphen split is consumer-outputs vs. reusable-workflow-inputs and stays.
- **Concurrency group prefix is `release-collector-`.** Independent of Notify's release lines.
- **Image-tag policy on the branch path is `dev-<sha>`, not `main`.** Moving the `main` tag in ACR would erase the per-commit rollback trail.
- **Header comment is not optional.** Any sentence implying tag-only/dev-only scope is removed. The "Replaces the previous App Service slot-swap deploy.yml" historical paragraph stays. No ADR number in the comment per Grid doc convention.
- **Revision accumulation accepted, not solved here.** ADR-0033 Operational Consequences names this as a known follow-up under ADR-0015, low priority. No revision-GC step.

**Key Files:**
- `.github/workflows/release-collector.yml` — the only file authored.
- `CHANGELOG.md` — repo-level entry under a dated SemVer section.

**Contracts:** None changed. No `catalogs/relationships.json` edge changes.
