---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "adr-0015"]
dependencies: []
adrs: ["ADR-0015", "ADR-0012"]
wave: 1
initiative: adr-0015-container-apps-rollout
node: honeydrunk-actions
---

# CI Change: Reusable workflow `job-deploy-container-app.yml` for Azure Container Apps

## Summary
Add a reusable GitHub Actions workflow that builds an image, pushes to the shared ACR, creates a new revision on a target Container App at 0% traffic, health-probes the revision, and shifts traffic to 100% on success. Mirror the contract shape of the existing `job-deploy-function.yml` and `job-deploy-container.yml`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0015 picks Azure Container Apps as the hosting platform for containerized Nodes. `HoneyDrunk.Actions` already ships reusable workflows for Function Apps (`job-deploy-function.yml`) and App Service containers (`job-deploy-container.yml`), but nothing for Container Apps. Without this workflow, every consumer repo (Notify, Pulse, and every future containerized Node) would have to author the full deploy path from scratch — violating ADR-0012, which names Actions as the Grid's CI/CD control plane and the canonical home for reusable deploy steps.

## Proposed Implementation

Add one reusable workflow and its supporting composite action.

### `.github/workflows/job-deploy-container-app.yml`

Contract modeled on `job-deploy-function.yml`:

**Inputs (workflow_call):**
- `runs-on` (default `ubuntu-latest`)
- `container-image` — full image reference already built and pushed (e.g. `acrhdshareddev.azurecr.io/honeydrunk-notify-worker:v1.2.3`). If `build-context` is set, the workflow builds and pushes instead of consuming a pre-built reference.
- `build-context` (optional) — path to Dockerfile directory. When set, the workflow builds the image with the tag derived from `image-name` + `image-tag` and pushes to `acr-registry`.
- `image-name` — short image name (e.g. `honeydrunk-notify-worker`). Required when `build-context` is set.
- `image-tag` — explicit tag (e.g. `v1.2.3`). Required when `build-context` is set.
- `dockerfile` (default `Dockerfile`) — Dockerfile path relative to `build-context`.
- `acr-registry` — ACR login server (e.g. `acrhdshareddev.azurecr.io`).
- `container-app` — target Container App name (e.g. `ca-hd-notify-worker-dev`).
- `resource-group` — target resource group.
- `revision-suffix` (default derived from `github.run_id`) — suffix appended to the new revision name for traceability.
- `health-check-url` (optional) — absolute URL or path relative to the revision's FQDN. Empty to skip.
- `health-check-timeout` (default `120`) — seconds to wait for health check to pass.
- `startup-wait` (default `15`) — seconds to wait after revision provisioning before probing.
- `traffic-shift-mode` (default `full`) — one of `full` (100% to new revision on health success), `canary:N` (N% to new revision, remainder to current), or `hold` (leave at 0%, require manual shift). Canary and hold modes are for future work; full is the only mode expected in Wave 2.
- `keyvault-name` (optional) — Key Vault to fetch secrets from for runtime config application.
- `keyvault-secrets` (optional) — newline-separated secrets to apply as Container App env vars. Format `SECRET_NAME` or `SECRET_NAME=ENV_VAR_NAME`.
- `actions-ref` (default `main`) — git ref of `HoneyDrunk.Actions` to check out for composite actions.

**Secrets:**
- `azure-client-id`, `azure-tenant-id`, `azure-subscription-id` (OIDC — required)
- `azure-client-secret` (SP fallback — discouraged, emit warning if used)

**Outputs:**
- `revision-name`
- `revision-fqdn`
- `deployment-status` (`success` | `health-check-failed` | `deploy-failed`)

**Steps:**
1. Checkout `HoneyDrunk.Actions` at `actions-ref` into `.actions`.
2. Detect auth method (OIDC vs SP) — reuse the existing pattern from `job-deploy-function.yml`.
3. Azure login via `azure/login@v2`.
4. If `build-context` is set: `docker login` to ACR via `.actions/.github/actions/azure/acr-login`, `docker build`, `docker push`. Resolve the full `container-image` reference for downstream steps.
5. If `keyvault-name` + `keyvault-secrets` provided: fetch via `.actions/.github/actions/azure/keyvault-fetch`, then apply to the Container App via `az containerapp update --set-env-vars`.
6. Deploy the revision via `.actions/.github/actions/azure/deploy-container-app` (new composite — see below).
7. Health-probe the revision FQDN.
8. Shift traffic per `traffic-shift-mode`.
9. Write a job summary table (image, revision, FQDN, traffic percent, status).
10. On any failure past step 6: leave traffic on previous revision, emit a `::error::` with rollback guidance.

**Permissions:** `contents: read`, `id-token: write`.

### `.github/actions/azure/deploy-container-app/action.yml` (new composite)

Inputs: `app-name`, `resource-group`, `image`, `revision-suffix`, `startup-wait`.

Steps:
1. `az containerapp revision copy --name $app --resource-group $rg --image $image --revision-suffix $suffix` — creates a new revision at 0% traffic (revision mode `Multiple` is required on the target app — enforced in the walkthrough).
2. Poll `az containerapp revision show` until `properties.runningState == "Running"` or `startup-wait` + health-check-timeout expires.
3. Echo the new revision name and FQDN to outputs.

### `examples/deploy-container-app.yml` (new)

Consumer-facing example mirroring `examples/deploy-function-app.yml`. Build job publishes Docker image artifact or produces the Dockerfile context; deploy job calls `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml@main` with the right inputs. Include commented-out examples for Key Vault secret injection and canary traffic mode.

### `docs/consumer-usage.md` (update)

Add a section for `job-deploy-container-app.yml` alongside the existing Function App / App Service Container entries.

## Affected Files
- `.github/workflows/job-deploy-container-app.yml` (new)
- `.github/actions/azure/deploy-container-app/action.yml` (new)
- `examples/deploy-container-app.yml` (new)
- `docs/consumer-usage.md`
- `CHANGELOG.md`

## NuGet Dependencies
None. This is a GitHub Actions workflow change — no .NET packages touched.

## Boundary Check
- [x] Additive change only. Existing `job-deploy-function.yml` and `job-deploy-container.yml` unchanged.
- [x] No contract change on consumer repos — new workflow is opt-in.
- [x] Composite action lives under `.github/actions/azure/`, consistent with existing Azure composites.

## Acceptance Criteria
- [ ] `job-deploy-container-app.yml` exists and is callable via `workflow_call` from consumer repos.
- [ ] `azure/deploy-container-app` composite action exists and is referenced by the workflow.
- [ ] `examples/deploy-container-app.yml` exists and reflects real consumer usage (build → call reusable workflow).
- [ ] `docs/consumer-usage.md` documents inputs, outputs, secrets, and traffic-shift modes.
- [ ] CI smoke test in `HoneyDrunk.Actions` itself invokes the new workflow against a throwaway Container App in `rg-hd-platform-dev` and verifies a successful deploy + traffic shift. If infra for this is not yet available, skip the smoke test and note it as a follow-up issue.
- [ ] `CHANGELOG.md` updated.
- [ ] Existing Function App and App Service Container workflows continue to pass their own smoke tests.

## Human Prerequisites
- [ ] `acrhdshareddev` and `cae-hd-dev` must be provisioned before the smoke test can run. These are provisioned in packet 01 of this initiative.
- [ ] A throwaway Container App (`ca-hd-ci-smoke-dev`) in `rg-hd-platform-dev` attached to `cae-hd-dev`, pulling a hello-world image from `acrhdshareddev`. Created once in the portal; reused by the smoke test on every run.
- [ ] OIDC federated credential on the `HoneyDrunk.Actions` repo granting the GitHub Actions identity `AcrPush` on `acrhdshareddev` and `Container Apps Contributor` on the smoke Container App.

## Referenced Invariants

> **Invariant 34 (proposed):** Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`, one per Node per environment, with system-assigned Managed Identity. See ADR-0015.

> **Invariant 35 (proposed):** One shared Container Apps Environment (`cae-hd-{env}`) and one shared Azure Container Registry (`acrhdshared{env}`) serve every containerized Node within a given environment. Per-Node compute environments or registries are forbidden without a follow-up ADR. See ADR-0015.

> **Invariant 36 (proposed):** Container App revision mode is `Multiple` with explicit traffic splitting on deploy. Single-revision mode is forbidden — it removes the rollback seam. See ADR-0015.

## Referenced ADR Decisions

**ADR-0015 (Container Hosting Platform):** Revision mode `Multiple` with traffic shift on deploy; OIDC federated credentials extended to include `AcrPush` on shared ACR and `Container Apps Contributor` on the target app.

**ADR-0012 (Grid CI/CD Control Plane):** Reusable deploy workflows live in `HoneyDrunk.Actions`. Consumer repos must not reimplement deploy steps locally — they call the reusable workflow.

## Dependencies
None. Can run in parallel with packet 01 (walkthroughs). Smoke test depends on `acrhdshareddev` + `cae-hd-dev` from packet 01 but the workflow code does not.

## Labels
`ci`, `tier-2`, `adr-0015`

## Agent Handoff

**Objective:** Make Container Apps deploys a one-line call from any consumer repo.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Provide the reusable CI surface that Notify and Pulse (Wave 2) will call.
- Feature: ADR-0015 Container Apps rollout.
- ADRs: ADR-0015 (hosting platform), ADR-0012 (Actions as control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. Wave 2 packets consume this workflow.

**Constraints:**
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. The workflow must never echo secret values in step summaries or `::debug::` output. Keyvault-fetch must use `::add-mask::` on retrieved values.
- **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. Runtime secrets reach the Container App only via Key Vault references or env vars sourced from Key Vault — the workflow must never pass secrets as literal strings.
- **Invariant 34 (proposed):** Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`. Reject input `container-app` values that do not match this pattern with a clear error.
- **Invariant 36 (proposed):** Container App revision mode is `Multiple`. The workflow must fail fast (with a clear message) if the target Container App is in Single revision mode.

**Key Files:**
- `.github/workflows/job-deploy-function.yml` — style reference (input shape, auth detection, step summary).
- `.github/workflows/job-deploy-container.yml` — style reference (ACR handling, keyvault integration).
- `.github/actions/azure/acr-login/action.yml` — reuse as-is for ACR auth.
- `.github/actions/azure/keyvault-fetch/action.yml` — reuse as-is for secret fetch.
- `examples/deploy-function-app.yml` — consumer example shape.

**Contracts:** New workflow contract — inputs/outputs/secrets as listed in Proposed Implementation. Treat as v1 stable surface for Wave 2 consumers.
