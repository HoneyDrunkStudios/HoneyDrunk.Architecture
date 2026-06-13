---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "infrastructure", "adr-0077", "wave-3"]
dependencies: ["work-item:18"]
adrs: ["ADR-0077", "ADR-0012", "ADR-0033"]
wave: 3
initiative: adr-0077-iac-bicep
node: honeydrunk-actions
---

# Author job-deploy-bicep.yml — reusable deploy workflow for local-path Bicep templates (no registry)

> **Supersedes packet 06** (`Actions#121`). Packet 06 authored `job-deploy-bicep.yml` assuming per-Node `infra/main.bicep` templates in each Node's repo and modules resolved from the `acrhdbicep` registry (`br:` refs). Under the ADR-0077 amendment (2026-06-02): the workflow STAYS in Actions per ADR-0012, but its inputs change — it applies templates from `HoneyDrunk.Infrastructure` (`nodes/{node}/main.bicep`, `platform/main.bicep`) whose modules resolve by **local relative path** within that repo. No `az acr login` / registry auth step is needed (no registry). Deploys run on the infra cadence, decoupled from application release tags. Issue `Actions#121` is closed as superseded by this packet.

## Summary
Author `.github/workflows/job-deploy-bicep.yml` in `HoneyDrunk.Actions` — the reusable deploy workflow that runs `az deployment group create` (or `az deployment sub create` for subscription-scoped resources) on a Bicep template from `HoneyDrunk.Infrastructure` with the appropriate `parameters.{env}.bicepparam`, per ADR-0077 D4 (as amended). Consumed via `workflow_call` by `HoneyDrunk.Infrastructure`'s deploy workflows. Authenticates via the existing Actions OIDC federation. Runs `bicep lint` + `bicep build` preflight, then `what-if`, then apply. Modules resolve by local relative path within the infra repo checkout — NO registry auth, NO `br:` resolution.

## Context
The amendment keeps the deploy *pipeline* in Actions (ADR-0012) but consolidates the Bicep *content* into `HoneyDrunk.Infrastructure`. The workflow's job is unchanged in spirit; its inputs and resolution model change:
- **Input templates** come from the calling repo's checkout (`HoneyDrunk.Infrastructure`), at paths like `nodes/{node}/main.bicep` or `platform/main.bicep`.
- **Module resolution is local relative path** — because modules (`modules/{concern}/{name}.bicep`) live in the same repo checkout, `bicep build` resolves them from the filesystem. There is NO `az acr login`, NO registry pull, NO `br:acrhdbicep.azurecr.io/...` resolution.
- **Cadence** is the infra repo's own (push to `main` / manual dispatch / an infra tag), decoupled from application release tags — the amendment supersedes the D4 tag-coupling framing.

Consuming caller (in `HoneyDrunk.Infrastructure`):
```yaml
jobs:
  deploy-infra:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
    with:
      env: dev
      template-path: nodes/identity/main.bicep
      parameters-path: nodes/identity/parameters.dev.bicepparam
      deployment-scope: resourceGroup
      resource-group: rg-hd-identity-dev
    permissions:
      id-token: write
      contents: read
```

## Scope
- `.github/workflows/job-deploy-bicep.yml` (new) — the reusable deploy workflow.
- `HoneyDrunk.Actions` `CHANGELOG.md` (if maintained for the workflow surface) — append the new workflow entry.
- Documentation of the workflow's inputs in the Actions workflow README / catalog (the catalog registration is packet 12).

## Proposed Implementation
1. **`workflow_call` inputs:** `env` (required), `template-path` (required — relative to the caller's checkout), `parameters-path` (required), `deployment-scope` (`resourceGroup` | `subscription`, default `resourceGroup`), `resource-group` (required when scope is `resourceGroup`), `location` (required when scope is `subscription`).
2. **Auth:** OIDC federation — `azure/login` with the federated credential (no `AZURE_CREDENTIALS` secret; `id-token: write` permission). Document the caller `permissions:` superset requirement (invariant 39).
3. **Preflight:** `bicep build` the template (resolves local-path modules from the checkout), `bicep lint` (using the infra repo's root `bicepconfig.json`), then `az deployment {group|sub} what-if` to surface the diff in the job log.
4. **Apply:** `az deployment group create` / `az deployment sub create` with the template + bicepparam. Capture outputs.
5. **NO registry step.** Do NOT add `az acr login`, do NOT resolve `br:` references, do NOT reference `acrhdbicep`. Modules are local-path-resolved at `bicep build` time.
6. **Environment gating.** The workflow itself is scope-pure; the `environment:` approval gate (ADR-0033) is declared by the *caller's* job, not inside this reusable workflow. Document this in the workflow header comment.
7. **CHANGELOG / docs** as applicable.

## Affected Files
- `.github/workflows/job-deploy-bicep.yml` (new)
- `CHANGELOG.md` (if maintained)

## NuGet Dependencies
None. GitHub Actions YAML; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions` — the deploy pipeline stays in the CI/CD control plane per ADR-0012.
- [x] The workflow consumes templates from `HoneyDrunk.Infrastructure` at call time; it does not embed Bicep content.
- [x] No registry auth / `br:` resolution (registry dropped).

## Acceptance Criteria
- [ ] `.github/workflows/job-deploy-bicep.yml` is a `workflow_call` reusable workflow with inputs `env`, `template-path`, `parameters-path`, `deployment-scope`, `resource-group`, `location`
- [ ] Authenticates via OIDC federation (`azure/login`, `id-token: write`); no `AZURE_CREDENTIALS` secret
- [ ] Runs `bicep build` + `bicep lint` + `az deployment ... what-if` as preflight before apply
- [ ] Applies via `az deployment group create` (resourceGroup scope) or `az deployment sub create` (subscription scope)
- [ ] Modules resolve by local relative path from the caller's checkout — NO `az acr login`, NO `br:acrhdbicep.azurecr.io` resolution, NO `acrhdbicep` reference anywhere
- [ ] The workflow header documents that the caller declares the `environment:` approval gate (ADR-0033) and a `permissions:` superset (invariant 39)
- [ ] No secret values appear in the workflow or its logs (invariant 8 / D7)
- [ ] `CHANGELOG.md` (if maintained) records the new workflow

## Human Prerequisites
- [ ] Confirm the Actions OIDC-federated deploy identity has Contributor (or scoped equivalent) on the target resource groups (`rg-hd-{node}-{env}`, `rg-hd-platform-{env}`). This is the same identity already used for container deploys; confirm the role scope covers the infra RGs. Portal RBAC — agent cannot perform.

## Referenced ADR Decisions
**ADR-0077 amendment (2026-06-02).** The deploy workflow stays in Actions (ADR-0012); it applies templates from `HoneyDrunk.Infrastructure` with local-path module resolution — no registry, no `br:` refs. Infra deploys on its own cadence, decoupled from application release tags.

**ADR-0077 D4 (cadence amended) — per-environment deployment.** `main.bicep` + `parameters.{env}.bicepparam`; `az deployment group create` per environment.

**ADR-0012 — Actions is the CI/CD control plane.** The deploy workflow belongs here.

**ADR-0033 — environment-gated deploys.** The `environment:` gate is declared by the caller; the reusable workflow is scope-pure.

**Invariant 39 (ADR-0012 D5) — caller permissions superset.** **Invariant 8 / ADR-0077 D7 — no secret values in the workflow or logs.**

## Constraints
- **No registry auth.** Modules are local-path-resolved; do NOT add `az acr login`, `br:` resolution, or any `acrhdbicep` reference. This is the load-bearing change from packet 06.
- **Caller declares the env gate.** Keep the reusable workflow scope-pure; the ADR-0033 `environment:` approval is the caller's job.
- **OIDC only.** No `AZURE_CREDENTIALS` secret.
- **`what-if` before apply.** Surface the diff in the log (supports the D6 grandfather/import safety).

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `infrastructure`, `adr-0077`, `wave-3`

## Agent Handoff

**Objective:** Author `job-deploy-bicep.yml` in Actions — reusable deploy workflow applying `HoneyDrunk.Infrastructure` templates with local-path module resolution, OIDC auth, `what-if` preflight, caller-declared env gates. No registry.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Ship the deploy half of the Bicep pipeline (the pipeline stays in Actions per ADR-0012) adjusted for the consolidated, registry-free infra repo.
- Feature: ADR-0077 IaC — Bicep rollout (amended 2026-06-02), Wave 3.
- ADRs: ADR-0077 + 2026-06-02 amendment (primary), ADR-0012 (pipeline in Actions), ADR-0033 (env gates).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0077 (amended) Accepted. (The workflow ships idle until `HoneyDrunk.Infrastructure` calls it; it does not need packets 13/14 to exist at author time.)

**Constraints:**
- No registry auth, no `br:`, no `acrhdbicep`.
- Caller declares the `environment:` gate; reusable workflow is scope-pure.
- OIDC only; no `AZURE_CREDENTIALS`.
- `what-if` before apply.

**Key Files:**
- `.github/workflows/job-deploy-bicep.yml` (new)
- `CHANGELOG.md` (if maintained)

**Contracts:** The workflow's `workflow_call` input surface (`env`, `template-path`, `parameters-path`, `deployment-scope`, `resource-group`, `location`) is the consumable contract for `HoneyDrunk.Infrastructure`'s deploy workflows.
