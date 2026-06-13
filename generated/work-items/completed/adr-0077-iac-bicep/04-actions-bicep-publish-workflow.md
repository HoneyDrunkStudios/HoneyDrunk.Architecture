---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "infrastructure", "adr-0077", "wave-3"]
dependencies: ["work-item:02", "work-item:03"]
adrs: ["ADR-0077", "ADR-0012"]
wave: 3
initiative: adr-0077-iac-bicep
node: honeydrunk-actions
---

# Author bicep-publish.yml — the reusable workflow that publishes modules to acrhdbicep on tagged release

> **STATUS — DEAD (2026-06-02).** Filed as `Actions#119` (OPEN, unmerged). The ADR-0077 amendment (2026-06-02) DROPS the cross-repo Bicep module registry in full — no `acrhdbicep` ACR, no `bicep-publish.yml`, no `modules/v{N}.{N}.{N}` SemVer-tag-publish flow. Modules in the consolidated `HoneyDrunk.Infrastructure` repo are consumed by local relative path; there is nothing to publish. This packet has no successor — its entire purpose is gone. Retained for traceability; do not execute it. Close `Actions#119` as obsolete (registry dropped per ADR-0077 amendment). See `dispatch-plan.md`.

## Summary
Author `.github/workflows/bicep-publish.yml` in `HoneyDrunk.Actions` — the reusable workflow that runs `az bicep publish` for each Bicep module under `bicep/modules/` against the `acrhdbicep` Azure Container Registry on tagged release per ADR-0077 D2. Trigger: tag push of the form `modules/v{N}.{N}.{N}` (or `workflow_dispatch` for manual republish). Authenticated via the existing Actions OIDC federation. Publishes only modules whose files changed since the previous tag (best-effort) or all modules if change detection is not feasible.

## Context
ADR-0077 D2 commits the publish flow:

> Module authors edit `HoneyDrunk.Actions/bicep/modules/` and tag a semantic-version release (`modules/v1.2.0` style). A reusable `bicep-publish` workflow in `HoneyDrunk.Actions` runs `az bicep publish` for each changed module against the target registry on tag.

The workflow runs against `acrhdbicep` (provisioned by packet 02). It authenticates via the existing Actions OIDC-federated service principal (which has `AcrPush` per packet 02). It iterates over the modules under `bicep/modules/` and publishes each with the tag's SemVer as the immutable tag.

**Tag shape.** `modules/v{N}.{N}.{N}` (e.g. `modules/v1.0.0`, `modules/v1.1.0`). The `modules/` prefix distinguishes module tags from any future repo-level tags (the repo itself is not versioned today; this leaves room).

**Module versioning.** All modules in a tag receive the same SemVer. This is a simplification — if a single module changes, the tag bumps all modules' published versions. Consumers can either pin per-module (`br:acrhdbicep.azurecr.io/modules/compute/containerApp:1.0.0`) or to the most recent tag at consumption time. The simplification is intentional — per-module SemVer tracking with selective publish is a small library-management problem the Grid does not need to solve at v1. Document this in the workflow's comments and in the library README (packet 03).

**Trigger.** Push of a tag matching `modules/v*.*.*`. Plus `workflow_dispatch` for manual republish (useful for re-running against a failed publish).

**OIDC authentication.** Reuse the existing Actions OIDC federation pattern (per `oidc-federated-credentials.md`). The workflow needs `id-token: write` and `contents: read` permissions; it does not need `packages: write` (we are pushing to ACR, not GHCR).

**`az bicep publish` invocation.** For each `bicep/modules/{concern}/{name}.bicep`:
```
az bicep publish \
  --file bicep/modules/{concern}/{name}.bicep \
  --target br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver} \
  --documentation-uri https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/blob/main/bicep/modules/{concern}/{name}.bicep \
  --with-source
```
The `--with-source` flag embeds the original Bicep source in the published artifact — useful for `az bicep restore`'s decompile-on-demand. Cost: a few KB per module; negligible.

**Change detection.** v1: publish every module on every tag. v2 (deferred): detect changed files via `git diff` between the current tag and the previous `modules/v*` tag and publish only changed modules. The v1 simplification is cheap (publishing ~6 small Bicep files takes seconds) and avoids the change-detection complexity.

`HoneyDrunk.Actions` is the CI/CD control plane per ADR-0012; reusable workflows live in `.github/workflows/`. This is a workflow/YAML packet — no .NET project. The repo `CHANGELOG.md` (if it keeps one for the workflow surface) is updated per the repo convention.

## Scope
- `.github/workflows/bicep-publish.yml` (new) — the reusable workflow.
- `docs/` — if the repo keeps a consumer-usage doc for reusable workflows, add a section documenting `bicep-publish.yml`.
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## Proposed Implementation
1. **Workflow header.**
   ```yaml
   name: Bicep modules publish

   on:
     push:
       tags:
         - 'modules/v*.*.*'
     workflow_dispatch:
       inputs:
         version:
           description: 'SemVer to republish as (e.g., 1.0.1). Required for workflow_dispatch.'
           required: true
           type: string

   permissions:
     id-token: write
     contents: read
   ```
2. **Single job: `publish`.**
   - Runs on `ubuntu-latest`.
   - Steps:
     1. `actions/checkout@v4` — `ref` = the tag for push, the branch for dispatch.
     2. **Derive the SemVer.** For tag push: strip the `modules/v` prefix from `${{ github.ref_name }}` (`modules/v1.0.0` → `1.0.0`). For dispatch: use `${{ inputs.version }}`.
     3. **Azure login via OIDC.** Use `azure/login@v2` with `client-id`, `tenant-id`, `subscription-id` sourced from the existing repo secrets / variables that the other deploy workflows already use (the Actions OIDC-federated identity per `oidc-federated-credentials.md`).
     4. **Enumerate modules.** Use `find bicep/modules -type f -name '*.bicep'` (or a `bash` loop) to discover modules. Skip `*.tests.bicep` files.
     5. **Publish each module.** For each discovered `.bicep` file, derive the target path (`modules/{concern}/{name}` from the file path) and run the `az bicep publish` invocation documented above with `--with-source`.
     6. **Summary.** Print a final summary listing each module → its target registry path → the SemVer published. Write the summary to `$GITHUB_STEP_SUMMARY` so consumers see it on the workflow run page.
3. **Reusability shape.** The workflow is consumed via `workflow_call` so other repos (in principle) could publish modules to `acrhdbicep`. v1 only the Actions repo publishes — but the `workflow_call` shape keeps the door open. Reference the existing reusable workflows (`job-deploy-container-app.yml`, etc.) for the input shape.
4. **Failure modes.**
   - **Tag already published.** `az bicep publish` against an immutable tag in ACR fails by design — the workflow surfaces the error cleanly and exits non-zero. Republishing requires a SemVer bump.
   - **No modules found.** If `bicep/modules/` has no `.bicep` files (this initiative's state at packet 03 merge — module files land in packet 05), the workflow logs "no modules to publish" and exits 0. This makes the workflow safe to wire before modules exist.
   - **OIDC auth failure.** Surface the Azure error; do not retry. Operator intervention (re-check role assignments per packet 02) is the right response.
5. **Docs.** If `docs/` has a reusable-workflow consumer guide, add a section documenting `bicep-publish.yml`: the trigger shape, the SemVer derivation, the secret/variable references, and the workflow_dispatch fallback path.

## Affected Files
- `.github/workflows/bicep-publish.yml` (new)
- `docs/` — if a consumer-usage doc exists for reusable workflows, extend it
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface

## NuGet Dependencies
None. `HoneyDrunk.Actions` ships GitHub Actions YAML — no .NET project is created or modified.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — ADR-0077 D2 names this exact workflow location; ADR-0012 makes Actions the CI/CD control plane.
- [x] The workflow consumes the `acrhdbicep` registry (provisioned by packet 02) and the OIDC federation (existing).
- [x] No code change in any Node — workflow YAML only.

## Acceptance Criteria
- [ ] `.github/workflows/bicep-publish.yml` exists, triggers on `push.tags: modules/v*.*.*` and on `workflow_dispatch` (with a `version` input), and uses `permissions: { id-token: write, contents: read }`
- [ ] The workflow authenticates to Azure via `azure/login@v2` using the existing OIDC-federated identity — no static secrets in the workflow or repo (invariant 8)
- [ ] The workflow derives the SemVer from the tag (strip `modules/v` prefix) on tag push, or from the `version` input on dispatch
- [ ] The workflow enumerates `bicep/modules/**/*.bicep` (skipping `*.tests.bicep`) and runs `az bicep publish --file {path} --target br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver} --with-source --documentation-uri {github-blob-url}` for each
- [ ] The workflow writes a summary of published modules to `$GITHUB_STEP_SUMMARY`
- [ ] If `bicep/modules/` has no `.bicep` files, the workflow logs "no modules to publish" and exits 0 — safe to wire before modules exist
- [ ] Republishing an existing tag fails cleanly (`az bicep publish` against an immutable tag returns non-zero) and the workflow surfaces the error
- [ ] The workflow shape is `workflow_call`-callable (i.e., the trigger surface and the input shape do not preclude future reuse from another repo)
- [ ] `docs/` consumer-usage doc (if it exists) documents `bicep-publish.yml`: trigger, SemVer derivation, OIDC requirement, dispatch fallback
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow surface
- [ ] No actual module is published by this packet — packet 05 ships and tags the first module set (`modules/v1.0.0`)

## Human Prerequisites
- [ ] `acrhdbicep` exists and the Actions OIDC identity has `AcrPush` on it — both delivered by packet 02. The workflow does not need any portal click to land, but it will not produce a successful publish until packet 02 has provisioned the registry and assigned the role. Until then the workflow can be merged safely — it will only execute on a `modules/v*` tag, and packet 05 is what files the first tag.

## Referenced ADR Decisions
**ADR-0077 D2 — Publish flow.** "Module authors edit `HoneyDrunk.Actions/bicep/modules/` and tag a semantic-version release (`modules/v1.2.0` style). A reusable `bicep-publish` workflow in `HoneyDrunk.Actions` runs `az bicep publish` for each changed module against the target registry on tag. Module consumers reference the registry path with an immutable version: `br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}`."

**ADR-0077 D7 — Deploy / publish identity has provisioning rights, not secret-read rights.** The OIDC-federated identity has `AcrPush` on `acrhdbicep`, scoped to the registry. It cannot read Vault secrets; it cannot push to `acrhdshared{env}` (the image registry).

**ADR-0012 — Actions is the Grid CI/CD control plane.** Reusable workflows in `.github/workflows/` are the Grid's CI/CD surface.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** OIDC authentication is the only credential path. No `AZURE_CREDENTIALS` JSON blob, no ACR access key, no registry password in the workflow or repo.

- **OIDC-only.** The workflow uses the existing Actions OIDC federation — do not introduce a new service principal or a stored credential.
- **Immutable tags.** ACR enforces tag immutability. Republishing requires a SemVer bump; the workflow surfaces the error cleanly.
- **Safe to wire before modules exist.** A run on an empty `bicep/modules/` tree logs "no modules to publish" and exits 0. The workflow merge does not depend on packet 05's module set being authored.
- **All modules share the tag's SemVer.** Per-module SemVer tracking with selective publish is deferred (small library-management problem, deferred to v2). Document this in the workflow comments.
- **`workflow_call` reusability shape.** The workflow shape does not preclude future reuse from another repo, even if v1 only the Actions repo publishes.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `infrastructure`, `adr-0077`, `wave-3`

## Agent Handoff

**Objective:** Author `.github/workflows/bicep-publish.yml` — the reusable workflow that publishes Bicep modules under `bicep/modules/` to `acrhdbicep` on `modules/v*.*.*` tag push.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make the Bicep modules library publishable on tag, so packet 05's first module set has a path to the registry.
- Feature: ADR-0077 IaC — Bicep rollout, Wave 3.
- ADRs: ADR-0077 D2/D7 (primary), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `acrhdbicep` exists with the Actions OIDC identity granted `AcrPush`. The workflow can merge before packet 02 is executed (it will only run on a `modules/v*` tag, and that tag is filed by packet 05); but the first successful execution requires packet 02 to be done.
- `work-item:03` — `bicep/modules/` directory tree exists. The workflow safely no-ops on an empty tree, so the strict need is only "the directory exists" — `work-item:03` delivers that.

**Constraints:**
- OIDC-only — no stored credential in the workflow or repo (invariant 8).
- ACR tags are immutable — republish requires a SemVer bump.
- Safe to wire before modules exist — `bicep/modules/` empty → exit 0.
- All modules in a tag share the tag's SemVer — per-module SemVer deferred to v2.
- `workflow_call` reusability shape preserved.

**Key Files:**
- `.github/workflows/bicep-publish.yml` (new)
- `docs/` consumer-usage doc (if it exists)

**Contracts:**
- Workflow trigger: `push.tags: modules/v*.*.*`, `workflow_dispatch.inputs.version`.
- Workflow contract for consumers: tag a `modules/v{N}.{N}.{N}` → modules under `bicep/modules/` are published to `br:acrhdbicep.azurecr.io/modules/{concern}/{name}:{semver}` with `--with-source`.
