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

# Amend `release-worker.yml` for environment-gated deploy triggers

## Summary
Add a path-filtered push-to-`main` trigger that resolves to `dev`, make the trigger-to-environment mapping explicit in the `resolve` job, and add a `concurrency` block keyed on the resolved environment. Replace the existing "dev-only / tag-only — intentional, not a gap" header framing with the dual-trigger model decided in ADR-0033. Path-scope strictly to `Notify.Worker` sources so the Worker workflow does not redeploy on Functions-only commits (D4).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Notify`

## Target Workflow
**File:** `.github/workflows/release-worker.yml`
**Family:** release (consumer caller of `HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml@main`)

## Motivation
Same motivation as packet 01 (Notify.Functions): remove tag-cutting ceremony from continuous dev deploys to a disposable environment while preserving SemVer-tagged promotion for staging/prod. The Worker line is a Container App (revision-based deploys per ADR-0015) — orthogonal to the trigger-model decision, which is about the consumer `on:` block and the `resolve` mapping.

This is the **D4 correctness twin** of packet 01: in a repo with two deployables (`Notify.Functions` and `Notify.Worker`), each release workflow's path filter must be scoped to **only its own** deployable's source. The Functions filter (packet 01) and the Worker filter (this packet) together enforce that a Functions-only commit does not redeploy the Worker and vice versa.

## Proposed Change

### 1. `on:` block — add path-filtered push trigger
Add a `push: branches: [main]` trigger with a `paths:` filter scoped to **only `Notify.Worker`'s source**. The tag trigger remains unfiltered. `workflow_dispatch` is retained.

```yaml
on:
  push:
    branches: [main]
    paths:
      # Worker deployable source. The Worker Dockerfile lives under
      # HoneyDrunk.Notify.Worker/ — covered by this glob. The .csproj at
      # .Worker/HoneyDrunk.Notify.Worker.csproj is also covered.
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Worker/**'
      # Shared libraries the Worker binary links against (per
      # HoneyDrunk.Notify.Worker.csproj ProjectReference graph): hosting
      # glue, the three provider packages, the three queue packages, and
      # the HostBootstrap shared identity source. A change to any of these
      # produces a runtime behavior change in the deployed Worker binary
      # and must redeploy on main. D3 makes this an active correctness
      # concern, not a fire-and-forget setting.
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Hosting.AspNetCore/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Providers.Email.Smtp/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Providers.Email.Resend/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Providers.Sms.Twilio/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Queue.Abstractions/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Queue.InMemory/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.Queue.AzureStorage/**'
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.HostBootstrap/**'
      # Solution file and the workflow itself.
      - 'HoneyDrunk.Notify/HoneyDrunk.Notify.slnx'
      - '.github/workflows/release-worker.yml'
    tags:
      - 'worker-v*'
  workflow_dispatch:
```

The Functions source (`HoneyDrunk.Notify/HoneyDrunk.Notify.Functions/**`) and Functions-only shared paths (`HoneyDrunk.Notify/**`, `HoneyDrunk.Notify.Abstractions/**`) must **not** be in this filter (D4 — Worker-only commits must not redeploy Functions; the Functions workflow has the symmetric filter for itself). The shared libraries listed above (`HoneyDrunk.Notify.Hosting.AspNetCore`, the three Provider packages, `HoneyDrunk.Notify.HostBootstrap`) are legitimately referenced by **both** the Functions and Worker `.csproj` files — appearing in both workflows' filters is correct and intentional. The three `HoneyDrunk.Notify.Queue.*` packages are Worker-only (not referenced by Functions). D4 disjointness is preserved by the deployable-source-tree paths (`HoneyDrunk.Notify.Worker/**` vs. `HoneyDrunk.Notify.Functions/**`), not by the shared-library paths.

Forward-looking note: `Directory.Build.props` and `Directory.Packages.props` do not currently exist in HoneyDrunk.Notify. If they are added later, the implementing agent must add them to this filter at that time.

### 2. `resolve` job — explicit trigger-to-environment mapping
Replace the hard-coded `environment: dev` resolution with an explicit `target_environment` output. Today both paths resolve to `dev`; the output exists so the staging/prod conditional (D6) is added in one place when those environments are provisioned.

```yaml
  resolve:
    name: Resolve target environment and config
    runs-on: ubuntu-latest
    # ADR-0033 D2: trigger intent is mapped here, once, explicitly.
    # - refs/tags/worker-v*    -> promotion environment (staging / prod when
    #   provisioned; for now resolves to `dev` per ADR-0033 D6).
    # - refs/heads/main        -> dev (continuous deploy of the disposable env).
    # - workflow_dispatch      -> dev (manual escape hatch on the same path).
    environment: dev
    outputs:
      target_environment: dev
      acr-registry: acrhdshared${{ vars.HD_ENV }}.azurecr.io
      container-app: ca-hd-notify-worker-${{ vars.HD_ENV }}
      resource-group: rg-hd-notify-${{ vars.HD_ENV }}
      keyvault-name: kv-hd-notify-${{ vars.HD_ENV }}
      azure-client-id: ${{ vars.AZURE_CLIENT_ID }}
      azure-tenant-id: ${{ vars.AZURE_TENANT_ID }}
      azure-subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
    steps:
      - name: Echo resolved targets
        run: |
          echo "Trigger       : ${{ github.event_name }} / ${{ github.ref }}"
          echo "Environment   : dev"
          echo "Container App : ca-hd-notify-worker-${{ vars.HD_ENV }}"
          echo "Resource Grp  : rg-hd-notify-${{ vars.HD_ENV }}"
          echo "ACR           : acrhdshared${{ vars.HD_ENV }}.azurecr.io"
          echo "Key Vault     : kv-hd-notify-${{ vars.HD_ENV }}"
```

The downstream `deploy` job consumes `needs.resolve.outputs.target_environment` instead of the literal `dev`.

### 3. `concurrency` block — keyed on resolved environment
Same form as packet 01 — separate per-environment key for the dev branch-push path; per-tag key for the tag path; `cancel-in-progress` differs by path.

```yaml
concurrency:
  # Dev branch pushes share a single key and supersede each other (latest main wins).
  # Tag promotions get their own per-ref key and queue (never cancel-in-progress).
  # Single-line expression form is the well-known-safe shape — keep on one line.
  group: release-worker-${{ startsWith(github.ref, 'refs/tags/') && format('tag-{0}', github.ref_name) || 'dev' }}
  cancel-in-progress: ${{ !startsWith(github.ref, 'refs/tags/') }}
```

The group name prefix is `release-worker-` (not `release-functions-`) so the two Notify release workflows do not contend on the same concurrency keys. Each line's concurrency is independent.

### 4. `deploy` job — consume resolved environment + handle branch-push image tag
Change the `deploy` job to pass `environment: ${{ needs.resolve.outputs.target_environment }}` rather than the literal `dev`. The image-tag input today is `${{ github.ref_name }}`, which is the tag name on the tag path and the branch name (`main`) on the push path. The Container App can be deployed with `main` as an image tag for dev, but a tag-equal-to-branch-name across many commits produces ACR overwrites — undesirable. Replace the `image-tag` input with an expression that picks the SemVer tag on the tag path and a SHA-derived tag on the branch path:

```yaml
      # Tag path: use the SemVer tag verbatim (e.g. worker-v0.1.0).
      # Branch path: use a SHA-derived tag (dev-<sha>, full 40-char SHA from
      # github.sha) — image-per-commit rather than a moving `main` tag, so
      # ACR has the artifact-per-deploy trail that revision-based rollback
      # (ADR-0015) expects. Full SHA is intentional: simpler than a short-sha
      # output step, and ACR has no tag-length friction at 40 chars.
      # Single-line expression form is the well-known-safe shape.
      image-tag: ${{ startsWith(github.ref, 'refs/tags/') && github.ref_name || format('dev-{0}', github.sha) }}
```

This is a deploy-mechanics tweak that lives in the consumer caller because the reusable workflow simply takes an `image-tag` input and does not own the tagging policy. It does not violate ADR-0012 — the build/push/revision mechanics inside `job-deploy-container-app.yml` are unchanged; only the input value computed by the caller changes.

### 5. Header comment block — replace dev-only/tag-only framing
Replace the current header (specifically the paragraph ending "A `worker-v*` tag therefore deploys to dev and nothing else — intentional, not a gap.") with the dual-trigger framing, mirroring packet 01's header text but specialized to Worker / `worker-v*` / Container Apps / `ca-hd-notify-worker-{env}`. The "Replaces the previous App Service slot-swap deploy.yml" sentence already in the file is historical context and stays.

```yaml
# Dual-trigger release for Notify.Worker:
#
#  - push to main, path-filtered to Notify.Worker sources  -> dev
#  - worker-v* tag, unfiltered                              -> staging / prod
#                                                              (when provisioned)
#  - workflow_dispatch                                       -> manual escape hatch
#
# Trigger intent is mapped to environment in the `resolve` job (single source).
# The reusable deploy workflow in HoneyDrunk.Actions takes an `environment`
# input and has no opinion about what triggered the caller — trigger policy is
# consumer-owned by construction.
#
# Path filter (D3/D4): scoped to Notify.Worker's own source only. A
# Functions-only commit must not redeploy Worker (the Functions workflow has
# the symmetric filter for itself). HoneyDrunk.Notify has two deployables;
# this filter is the D4 correctness boundary for the Worker side.
#
# Concurrency (D5): keyed on the resolved environment. Dev branch pushes
# supersede in-flight dev deploys (latest main wins). Tag promotions queue
# (cancel-in-progress: false) so a deliberate versioned promotion is never
# silently cancelled by a later one.
#
# Image tag composition: SemVer tag verbatim on the tag path; dev-<sha> on
# the branch path (full 40-char github.sha — not a short-sha). Image-per-commit
# on dev preserves the rollback trail in ACR; moving the `main` tag would not.
#
# The version-of-record rule (CHANGELOG + SemVer tag) is unchanged: a
# push-to-main dev deploy has no version stamp by design and is explicitly
# not a promotion source.
```

The current paragraph framing dev-only/tag-only as "intentional, not a gap" is removed wholesale — superseded.

## Consumer Impact
No consumer impact. This is a consumer release workflow; nothing else consumes it. The upstream `HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml@main` is unchanged.

## Breaking Change?
- [x] No — backward compatible at the trigger level. The `worker-v*` tag trigger still deploys to dev as it does today. The new `main` branch-push trigger is additive. The image-tag change is internal to the workflow and does not break consumer behavior.
- [ ] Yes — consumers need to update their caller workflows

## Affected Files
- `.github/workflows/release-worker.yml` — header comment, `on:` block, `resolve` job (outputs + comment), top-level `concurrency` block, `deploy` job inputs (`environment`, `image-tag`).
- `CHANGELOG.md` — repo-level entry under a dated SemVer section. CHANGELOG version sequencing for HoneyDrunk.Notify across packets 01 and 02 is owned by the dispatch plan (see `dispatch-plan.md` § CHANGELOG sequencing). Do not invent sequencing rules in-packet.

No application code changes. No new packages.

## NuGet Dependencies
None. Workflow-only change.

## Boundary Check
- [x] Workflow-only change. No Transport contract change, no `HoneyDrunk.Actions` change.
- [x] Trigger policy is irreducibly per-consumer-repo. ADR-0012 invariant on reusable workflows preserved.
- [x] Path filter is scoped to **only `Notify.Worker`** — a Functions-only commit must not redeploy Worker, per D4. Symmetric enforcement to packet 01.
- [x] Image-tag derivation lives in the caller (deploy-mechanics input value, not deploy-mechanics logic) — the reusable workflow's build/push/revision/probe/traffic-shift sequence is unchanged.

## Acceptance Criteria
- [ ] `on:` block includes both the path-filtered `push: branches: [main]` trigger and the existing `push: tags: ['worker-v*']` trigger, plus `workflow_dispatch`.
- [ ] The `main` path filter includes `HoneyDrunk.Notify/HoneyDrunk.Notify.Worker/**`, the solution `.slnx`, the workflow file itself, and the shared library projects the Worker binary links against per `HoneyDrunk.Notify.Worker.csproj`'s `ProjectReference` graph: `HoneyDrunk.Notify.Hosting.AspNetCore/**`, `HoneyDrunk.Notify.Providers.Email.Smtp/**`, `HoneyDrunk.Notify.Providers.Email.Resend/**`, `HoneyDrunk.Notify.Providers.Sms.Twilio/**`, `HoneyDrunk.Notify.Queue.Abstractions/**`, `HoneyDrunk.Notify.Queue.InMemory/**`, `HoneyDrunk.Notify.Queue.AzureStorage/**`, `HoneyDrunk.Notify.HostBootstrap/**`. The filter **does not** include any path under `HoneyDrunk.Notify/HoneyDrunk.Notify.Functions/` and **does not** include `HoneyDrunk.Notify/HoneyDrunk.Notify/**` or `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/**` (referenced by Functions only).
- [ ] `Directory.Build.props` / `Directory.Packages.props` are **not** listed in the filter (they do not currently exist in HoneyDrunk.Notify). If they are added later, this filter must be updated at the same time.
- [ ] `resolve` job emits a `target_environment` output (literal `dev` today; explicit-mapping anchor for D6).
- [ ] The `deploy` job consumes `needs.resolve.outputs.target_environment` rather than the literal string `dev`.
- [ ] The `image-tag` input is computed: SemVer tag on the tag path; `dev-<sha>` on the branch path (full 40-char `github.sha`). Verified by inspecting two real deploys (one tag, one main push) — ACR shows two distinct image tags.
- [ ] Top-level `concurrency` block exists with prefix `release-worker-`, group key includes the resolved environment (or `tag-<ref_name>` for the tag path), and `cancel-in-progress` is `true` on the dev branch-push path / `false` on the tag path.
- [ ] Header comment block describes the dual-trigger model and removes the prior "dev-only / tag-only — intentional, not a gap" framing.
- [ ] Test 1 (branch-push path, in-filter): a no-op commit to `HoneyDrunk.Notify/HoneyDrunk.Notify.Worker/README.md` on `main` triggers `release-worker.yml`, resolves to `dev`, builds an image tagged `dev-<sha>` (full 40-char SHA), and rolls a new revision on `ca-hd-notify-worker-dev`.
- [ ] Test 2 (branch-push path, out-of-filter / Functions-only): a no-op commit to `HoneyDrunk.Notify/HoneyDrunk.Notify.Functions/README.md` on `main` does **not** trigger `release-worker.yml`. Verified in the Actions run list for the commit SHA.
- [ ] Test 3 (tag path): pushing a `worker-v*` tag still triggers `release-worker.yml`, resolves to `dev`, deploys with the SemVer tag as the image tag, and the `concurrency` group uses the `tag-<ref_name>` key with `cancel-in-progress: false`.
- [ ] Test 4 (dev supersession): two rapid in-filter pushes to `main` produce two workflow runs in the same `dev` concurrency group; the older run is cancelled.
- [ ] Test 5 (tests-only commit, out-of-filter): a no-op commit under `HoneyDrunk.Notify/HoneyDrunk.Notify.Tests/**` or `HoneyDrunk.Notify/HoneyDrunk.Notify.IntegrationTests/**` on `main` does **not** trigger `release-worker.yml`. Test projects are outside the filter — they affect the PR gate, not the deploy.
- [ ] `CHANGELOG.md` updated per the dispatch plan's CHANGELOG sequencing instructions (`dispatch-plan.md` § CHANGELOG sequencing). No commits under `Unreleased`.
- [ ] No ADR number in workflow header comment, code comments, or `CHANGELOG.md` prose. The packet-data identifier `adr-0033` is acceptable only as packet frontmatter.

## Human Prerequisites
None. The `dev` GitHub Environment, OIDC federated credentials, `acrhdshared{env}`, `cae-hd-{env}`, and `ca-hd-notify-worker-dev` are already in place from the ADR-0015 rollout. Per ADR-0033 D7, `dev` must remain an unprotected GitHub Environment (no required-reviewer rule) — verify in the GitHub Environment settings before merging.

**Branch protection note.** Release workflow runs are **not** required checks on the `main` branch-protection rule. The PR-side checks (`pr.yml`) remain the merge gate; a release that fails *after* merge is a deploy concern, not a branch-protection concern. Do not add `release-worker.yml` to required checks on `main`.

## Referenced ADR Decisions

**ADR-0033 D1 — Trigger model per environment.** Push-to-`main` path-filtered → `dev`; SemVer-shaped tag (`worker-v*`) unfiltered → staging/prod (when provisioned); `workflow_dispatch` retained.

**ADR-0033 D2 — Trigger-to-environment resolution is explicit.** Single mapping point in `resolve`; `target_environment` output.

**ADR-0033 D3 — Path filtering is part of the decision, not optional.** The branch-push trigger carries a `paths:` filter scoped to the Worker's own source plus solution-level build inputs. The tag trigger is unfiltered.

**ADR-0033 D4 — Multi-deployable repos: per-deployable independence.** HoneyDrunk.Notify is the exemplar two-deployable repo. The Worker path filter must not include any `Notify.Functions/**` entry; packet 01's Functions filter must not include any `Notify.Worker/**` entry. Reviewer cross-checks both filters for symmetry.

**ADR-0033 D5 — Concurrency.** Dev path `cancel-in-progress: true`; tag path `cancel-in-progress: false`. Key includes the resolved environment.

**ADR-0033 D7 — `dev` remains an unprotected GitHub Environment by design.** No required-reviewer rule on `dev`.

**ADR-0033 D8 — Relationship to ADR-0012 and ADR-0015.** ADR-0012's invariant on reusable workflows is preserved (deploy mechanics are unchanged in `HoneyDrunk.Actions`). ADR-0015's `Multiple`-revision Container Apps hosting is unchanged. No `catalogs/relationships.json` edge changes.

**ADR-0015 (referenced):** Container Apps revision mode is `Multiple` with explicit traffic splitting on deploy. The branch-push path produces a new revision per commit (image tagged `dev-<sha>`), which is correct for revision-based rollback. Operational consequence per ADR-0033: continuous dev deploys produce Container App inactive revisions at merge cadence. ADR-0015 sets no revision-retention policy; revision GC is named as a follow-up consideration, explicitly out of scope here.

## Dependencies
None. Independent of packets 01 and 03.

## Labels
`ci`, `tier-2`, `ops`, `adr-0033`

## Agent Handoff

**Objective:** Amend `release-worker.yml` in HoneyDrunk.Notify to support environment-gated deploy triggers per ADR-0033 — path-filtered push-to-`main` → `dev`, explicit `resolve` mapping, environment-keyed concurrency, SHA-derived image tag on the branch path. Path-scope strictly to `Notify.Worker` sources so Functions-only commits do not redeploy the Worker.

**Target:** HoneyDrunk.Notify, branch from `main`. CHANGELOG sequencing across packets 01 and 02 is owned by the dispatch plan — follow its instructions.

**Context:**
- Goal: Continuous dev deploys without tag-cutting friction, preserved promotion path for staging/prod.
- Feature: ADR-0033 initiative (`adr-0033-deploy-trigger-model`).
- ADRs: ADR-0033 (this decision), ADR-0012 (CI/CD control plane — unchanged), ADR-0015 (Container Apps hosting — unchanged).

**Acceptance Criteria:** As listed above.

**Dependencies:** None hard. Soft CHANGELOG sequencing with packet 01 is owned by the dispatch plan.

**Constraints:**
- **ADR-0012 invariant — deploy logic in HoneyDrunk.Actions only.** The reusable `job-deploy-container-app.yml@main` is consumed verbatim. The only deploy-mechanics-adjacent change in this packet is the `image-tag` input expression in the caller — this is computing an input value, not implementing deploy logic. Do not inline Azure login, image push, revision creation, traffic shift, or health probe steps.
- **Invariant 8 (secrets in telemetry):** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. The `Echo resolved targets` step echoes only resource names and refs.
- **Invariant 9 (Vault as the only source of secrets):** Vault is the only source of secrets. The trigger-model change does not relax this; the Container App resolves the six Key Vault secrets via Managed Identity at runtime as today.
- **Path-filter correctness (D4):** A Functions-only commit must not redeploy the Worker. The `paths:` list under `push: branches: [main]` must not include any `HoneyDrunk.Notify.Functions/**` entry. Reviewer cross-checks against packet 01's Functions filter for symmetric correctness.
- **Concurrency group prefix is `release-worker-`** (not `release-functions-`) so the two Notify lines have independent concurrency. Tag-path key is `tag-<ref_name>`; branch-path key is `dev`. The expression in the proposed change is the canonical form.
- **Image-tag policy on the branch path is `dev-<sha>`, not `main`.** A moving `main` tag in ACR would overwrite the prior image and remove the revision-rollback trail. SHA-derived tags preserve image-per-commit. The tag path keeps the SemVer tag verbatim (`worker-v0.1.0`, etc.) as the image tag — unchanged from today.
- **Header comment is not optional.** The prior "dev-only / tag-only — intentional, not a gap" sentence must be deleted. The "Replaces the previous App Service slot-swap deploy.yml" historical paragraph stays. No ADR number in the comment per Grid doc convention.
- **Revision accumulation is accepted, not solved here.** ADR-0033's Operational Consequences explicitly name dev revision accumulation as a known follow-up under ADR-0015, low priority. Do not add a revision-GC step to this workflow.

**Key Files:**
- `.github/workflows/release-worker.yml` — the only file authored.
- `CHANGELOG.md` — per dispatch-plan CHANGELOG sequencing instructions.

**Contracts:** None changed. No `catalogs/relationships.json` edge changes.
