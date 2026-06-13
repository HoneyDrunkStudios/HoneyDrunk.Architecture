---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "infrastructure", "adr-0077", "wave-5"]
dependencies: ["work-item:05"]
adrs: ["ADR-0077", "ADR-0012", "ADR-0033"]
wave: 5
initiative: adr-0077-iac-bicep
node: honeydrunk-actions
---

# Author job-deploy-bicep.yml — the reusable workflow that applies a Node's main.bicep per environment

> **STATUS — SUPERSEDED (2026-06-02) by packet 16.** Filed as `Actions#121` (OPEN, unmerged). The workflow STAYS in `HoneyDrunk.Actions` per ADR-0012, but the ADR-0077 amendment (2026-06-02) changes its inputs: it applies templates from `HoneyDrunk.Infrastructure` (`nodes/{node}/main.bicep`, `platform/main.bicep`) whose modules resolve by local relative path — no `acrhdbicep` registry auth, no `br:` resolution — and deploys on the infra cadence decoupled from app release tags. Packet 16 carries the corrected workflow. This packet is retained for traceability; do not execute it. Close `Actions#121` as superseded by packet 16. See `dispatch-plan.md`.

## Summary
Author `.github/workflows/job-deploy-bicep.yml` in `HoneyDrunk.Actions` — the reusable deploy workflow that runs `az deployment group create` (or `az deployment sub create` for subscription-scoped resources) on a Node's `infra/main.bicep` with the appropriate `parameters.{env}.bicepparam` per ADR-0077 D4. Consumed via `workflow_call` by per-Node release workflows. Authenticates via the existing Actions OIDC federation. Runs `bicep lint` and `bicep build` as preflight steps, then applies the deployment.

## Context
ADR-0077 D4 commits the deploy shape:

> **`main.bicep`** — the entry-point template per Node (composes module references). **`parameters.{env}.bicepparam`** — per-environment parameter values (sizing, naming, regional pinning). **CI per-environment job** runs `az deployment group create` (or `az deployment sub create` for subscription-scoped resources) with the appropriate parameter file.

The workflow is the per-Node infrastructure deploy artifact. Consuming repos (per-Node release workflows) call it like:
```yaml
jobs:
  deploy-infra:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-bicep.yml@main
    with:
      env: dev
      template-path: infra/main.bicep
      parameters-path: infra/parameters.dev.bicepparam
      deployment-scope: resourceGroup
      resource-group: rg-hd-{node}-dev
    permissions:
      id-token: write
      contents: read
```

**Deployment scope.** Two scopes are needed v1:
- `resourceGroup` — the most common scope; `az deployment group create`. Requires a `resource-group` input.
- `subscription` — for subscription-scoped resources (resource group creation itself, subscription-level role assignments); `az deployment sub create`. Requires a `location` input. The `resource-group` input is ignored in this mode.

Other scopes (`management-group`, `tenant`) are deferred — the Grid does not provision at those scopes today.

**Preflight: lint + build.** Before the deploy, run `bicep lint` against the template (using the inherited `bicepconfig.json`) and `bicep build` to surface any compile errors. Failing either step fails the deploy without touching Azure.

**Idempotent What-If preview.** ADR-0077 D4 does not require a What-If gate, but it is cheap and prevents surprises. Run `az deployment {scope} what-if` as a non-blocking step that prints to the job summary. Operator can review the What-If output on the workflow run page before approving the actual apply (if the consuming workflow uses an `environment` requirement for approval gates, which is the recommended pattern for staging/prod).

**Approval gates are the consumer's concern.** This workflow does not impose an approval gate; the consuming per-Node release workflow uses GitHub `environment:` to gate `staging` and `prod` per ADR-0033. The deploy-bicep workflow runs whatever scope+template it is called with; the safety rails are at the trigger surface (only release tags trigger; only the per-environment Action's `environment` lets it actually apply).

**Outputs.** The workflow surfaces the Azure deployment's outputs (resource IDs, FQDNs, etc. — whatever the consumer's `main.bicep` outputs) as workflow outputs, so a downstream job in the consumer workflow can wire them. Use the `azure/cli` action's stdout JSON capture pattern.

**Outputs are scrubbed of `secureString` / `secureObject` typed entries before being surfaced.** Bicep's `output` JSON carries each output's declared type. The workflow filters out any output whose `type` is `secureString` or `secureObject` before assigning the remainder to `deployment-outputs`. Modules and per-Node templates that need to surface a secret value MUST do so by writing the secret into Vault inside the template (via a `keyVaultSecret` resource) and outputting the Vault secret URI / id only — never the secret value itself. This is defense-in-depth on top of invariant 85; even if a module author mistakenly declares a `@secure() output`, the workflow does not relay it to the calling workflow's run logs.

**Safe-to-call shape.** The workflow is `workflow_call`-callable from any HoneyDrunk repo; existing patterns (`job-deploy-container-app.yml`) are the precedent for shape, inputs, secrets passthrough, and outputs.

`HoneyDrunk.Actions` is the CI/CD control plane per ADR-0012. This is a workflow/YAML packet — no .NET project, no NuGet. The repo `CHANGELOG.md` is updated per the repo convention.

## Scope
- `.github/workflows/job-deploy-bicep.yml` (new) — the reusable deploy workflow.
- `docs/` — if the repo keeps a consumer-usage doc for reusable workflows, add a section documenting `job-deploy-bicep.yml` with the input shape and an example consumer invocation.
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## Proposed Implementation
1. **Workflow header.**
   ```yaml
   name: Deploy Bicep template

   on:
     workflow_call:
       inputs:
         env:
           type: string
           required: true
           description: 'Target environment (dev|staging|prod).'
         template-path:
           type: string
           required: true
           description: 'Path (relative to the consumer repo root) of the entry Bicep template (typically infra/main.bicep).'
         parameters-path:
           type: string
           required: true
           description: 'Path of the .bicepparam file (typically infra/parameters.{env}.bicepparam).'
         deployment-scope:
           type: string
           required: true
           description: 'resourceGroup or subscription. Other scopes are not supported v1.'
         resource-group:
           type: string
           required: false
           description: 'Required when deployment-scope=resourceGroup. Ignored otherwise.'
         location:
           type: string
           required: false
           description: 'Required when deployment-scope=subscription. The Azure region for the deployment metadata.'
         what-if:
           type: boolean
           default: true
           description: 'Run az deployment what-if as a preflight; print to job summary; non-blocking.'
       outputs:
         deployment-outputs:
           description: 'JSON object of the Azure deployment outputs.'
           value: ${{ jobs.deploy.outputs.outputs }}

   permissions:
     id-token: write
     contents: read
   ```
2. **Single job: `deploy`.** Runs on `ubuntu-latest`. Steps:
   1. `actions/checkout@v4` — the consumer repo's checkout (the calling workflow's `${{ github.workspace }}` is what `template-path` and `parameters-path` resolve against).
   2. **Validate inputs.** If `deployment-scope=resourceGroup` and `resource-group` is empty, fail fast with a clear message. Same for `subscription` / `location`.
   3. **Azure OIDC login.** `azure/login@v2` with `client-id`, `tenant-id`, `subscription-id` sourced from the existing repo secrets pattern. (The consumer repo passes these via `secrets: inherit`; document this in the consumer-usage doc.)
   4. **`bicep lint`.** Run `az bicep lint --file ${{ inputs.template-path }}`. Fail on any `error`-severity finding (the `bicepconfig.json` resolution picks up the consumer repo's config; if the consumer has none, Bicep falls back to defaults — which is acceptable since per-Node templates do not duplicate the Actions repo's `bicepconfig.json`).
   5. **`bicep build`.** Run `az bicep build --file ${{ inputs.template-path }}`. Fail on compile error.
   6. **What-If preflight** (gated on `inputs.what-if == true`). Run `az deployment {scope} what-if` with the appropriate args; capture the output and write it to `$GITHUB_STEP_SUMMARY`. Non-blocking.
   7. **Deploy.** Run `az deployment group create` (for `resourceGroup`) or `az deployment sub create` (for `subscription`) with `--template-file`, `--parameters @{parameters-path}`. Use `--name "${{ github.run_id }}-${{ inputs.env }}"` so the deployment name is unique and traceable. Capture stdout JSON.
   8. **Capture outputs (scrub secureString / secureObject).** Parse the deployment's outputs from the captured JSON. Filter the outputs object to exclude any entry whose `type` is `secureString` or `secureObject` — those are dropped silently with a single summary line in `$GITHUB_STEP_SUMMARY` listing the dropped output names (without their values). Assign the filtered object to the job output `outputs` for the workflow output `deployment-outputs`. Implementation: `jq` filter like `. | with_entries(select(.value.type | ascii_downcase | IN(\"securestring\", \"secureobject\") | not))` against the `properties.outputs` object.
   9. **Summary.** Write a final summary (template path, env, deployment name, key outputs) to `$GITHUB_STEP_SUMMARY`.
3. **Reusability shape.** `workflow_call` only — no direct push / PR / tag trigger on this workflow. It is called by per-Node release workflows after the build/test stages succeed.
4. **Failure modes.**
   - **Bicep lint error-severity.** Fail before touching Azure.
   - **Bicep build error.** Fail before touching Azure.
   - **What-If preflight error.** Surface, do not fail (What-If can fail for valid templates if the target resource group does not exist yet; the actual deploy will create it).
   - **Azure deployment error.** Surface the Azure error JSON cleanly; exit non-zero. Operator intervention required.
   - **Missing inputs.** Fail fast at step 2 with a clear message.
5. **Docs.** Author or extend `docs/consumer-usage.md` with a section: how to call `job-deploy-bicep.yml` from a per-Node release workflow, the recommended job structure (build → test → deploy-infra → deploy-app), and the environment-approval pattern per ADR-0033.

## Affected Files
- `.github/workflows/job-deploy-bicep.yml` (new)
- `docs/consumer-usage.md` (or equivalent) — consumer-usage section
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface

## NuGet Dependencies
None. Workflow YAML — no .NET project.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — ADR-0077 D1 names the Actions reusable deploy workflow; ADR-0012 confirms Actions as the CI/CD control plane.
- [x] No code change in any Node — workflow YAML only.
- [x] Consumer repos own their `infra/main.bicep` + `parameters.{env}.bicepparam` — this workflow is the deploy artifact only.

## Acceptance Criteria
- [ ] `.github/workflows/job-deploy-bicep.yml` exists, is `workflow_call`-only, and takes the documented inputs (`env`, `template-path`, `parameters-path`, `deployment-scope`, optional `resource-group` / `location`, optional `what-if`)
- [ ] The workflow exposes a `deployment-outputs` output containing the Azure deployment's JSON outputs, **scrubbed of any entry whose `type` is `secureString` or `secureObject`** — those entries are dropped silently (a summary line in `$GITHUB_STEP_SUMMARY` lists the dropped output names without their values). A test deployment with a `@secure() output` MUST NOT surface that output's value in `deployment-outputs` or in the workflow run log.
- [ ] The workflow authenticates via `azure/login@v2` and the existing OIDC-federated identity — no static secrets in the workflow or repo (invariant 8)
- [ ] Pre-flight: `bicep lint` runs on the template; `error`-severity findings fail the workflow before Azure is touched
- [ ] Pre-flight: `bicep build` runs on the template; compile errors fail the workflow before Azure is touched
- [ ] When `what-if=true`, `az deployment {scope} what-if` runs and writes its output to `$GITHUB_STEP_SUMMARY` (non-blocking)
- [ ] When `deployment-scope=resourceGroup` and `resource-group` is empty, the workflow fails fast with a clear message; same for `subscription` and `location`
- [ ] The deployment name is `${{ github.run_id }}-${{ inputs.env }}` (or equivalent unique-and-traceable shape) so the deployment is identifiable in the Azure activity log
- [ ] The workflow writes a deploy summary (template, env, deployment name, key outputs) to `$GITHUB_STEP_SUMMARY`
- [ ] Approval / environment gates are NOT imposed by this workflow — the consuming per-Node workflow uses GitHub `environment:` per ADR-0033 for staging / prod
- [ ] `docs/consumer-usage.md` (or equivalent) has a section documenting how to call the workflow, the recommended consumer job structure, and the environment-approval pattern
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow surface
- [ ] No per-Node `infra/main.bicep` exists in the Actions repo as a result of this packet — this packet is the deploy artifact; per-Node templates land in the consuming Nodes

## Human Prerequisites
- [ ] The first **consuming** use of this workflow waits on the per-Node `infra/main.bicep` + `parameters.{env}.bicepparam` existing in a Node's repo. That per-Node work happens at each Node's next significant infrastructure touchpoint per D6 — not here. The workflow can merge and stand idle until the first consumer wires it.

## Referenced ADR Decisions
**ADR-0077 D4 — Per-environment deployment.** "`main.bicep` entry point per Node. `parameters.{env}.bicepparam` per-environment values. CI per-environment job runs `az deployment group create` (or `az deployment sub create`) with the parameter file." This packet is the reusable workflow that does that.

**ADR-0077 D7 — Deploy identity has provisioning rights, not secret-read rights.** The OIDC-federated identity has resource-provisioning RBAC on the target subscription / resource groups; it does not have `Key Vault Secrets User`. Bicep templates resolve secrets at runtime via Vault references; the deploy identity never sees the secret value.

**ADR-0033 — Environment-gated deploy trigger model.** The consuming per-Node release workflow uses `environment:` to gate staging / prod approvals. This workflow stays scope-pure: deploy what you are given, where you are told to.

**ADR-0012 — Actions is the Grid CI/CD control plane.** Reusable deploy workflows in `.github/workflows/` are the Grid's CI/CD surface.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** OIDC-only authentication. The deploy identity has `Contributor` (or scoped equivalents) on the target subscription / RG, not `Key Vault Secrets User` — so even if a template accidentally tried to read a secret, AAD denies it.

- **`workflow_call` only.** No direct push / PR / tag trigger on this workflow. Called by per-Node release workflows.
- **Preflight before Azure.** `bicep lint` + `bicep build` first; failing either does not touch Azure.
- **Approval gates are the consumer's concern.** Do not impose an `environment:` requirement here; the consumer uses `environment:` per ADR-0033.
- **What-If is non-blocking.** It surfaces the diff to the summary; it does not gate the apply.
- **Two scopes only v1.** `resourceGroup` and `subscription`. `management-group` and `tenant` deferred.
- **Outputs scrubbed of `secureString` / `secureObject` before surfacing.** Defense-in-depth on top of invariant 85; the workflow drops secret-typed outputs even if a module mistakenly declares one.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `infrastructure`, `adr-0077`, `wave-5`

## Agent Handoff

**Objective:** Author `.github/workflows/job-deploy-bicep.yml` — the reusable deploy workflow that applies a Node's `infra/main.bicep` + `parameters.{env}.bicepparam` per environment via `az deployment {scope} create`, with `bicep lint` and `bicep build` preflights.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Ship the per-Node deploy artifact so consuming Node release workflows can apply Bicep templates per environment.
- Feature: ADR-0077 IaC — Bicep rollout, Wave 5.
- ADRs: ADR-0077 D4/D7 (primary), ADR-0033 (environment-gated deploys — consumer's concern), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:05` — the first module set exists and is published to `acrhdbicep`, so per-Node `main.bicep` templates the workflow deploys can resolve module references. Strictly the workflow can land before any module is published (it deploys whatever template it is given), but the dependency keeps the wave sequencing honest — packet 05 is the realistic precursor to a meaningful first consumer.

**Constraints:**
- `workflow_call` only.
- OIDC-only authentication (invariant 8).
- `bicep lint` + `bicep build` preflight before any Azure call.
- What-If is non-blocking.
- Approval gates are the consumer's concern (ADR-0033).
- Two scopes v1: `resourceGroup`, `subscription`.

**Key Files:**
- `.github/workflows/job-deploy-bicep.yml` (new)
- `docs/consumer-usage.md` (or equivalent)

**Contracts:**
- Workflow inputs: `env`, `template-path`, `parameters-path`, `deployment-scope`, optional `resource-group` / `location`, optional `what-if`.
- Workflow outputs: `deployment-outputs` (JSON object of Azure deployment outputs).
- Trigger: `workflow_call` only.
