---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "ci-cd", "adr-0068", "wave-2"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0068", "ADR-0015", "ADR-0012", "ADR-0033"]
wave: 2
initiative: adr-0068-background-jobs
node: honeydrunk-actions
---

# Author `job-deploy-container-apps-job.yml` reusable workflow for Azure Container Apps Jobs deploys

## Summary
Add a new reusable workflow `job-deploy-container-apps-job.yml` to `HoneyDrunk.Actions` for deploying Azure Container Apps **Jobs** (the scheduled / event-triggered Jobs surface, not the long-running Container Apps the existing `job-deploy-container-app.yml` workflow targets). The workflow follows the same OIDC-federation, ACR-build-push, Key Vault-backed runtime secrets, and validation patterns the existing container-app deploy workflow uses, with a Jobs-specific shape: schedule-or-event trigger, replica policy, retry policy, and KEDA scaler wiring.

## Context
ADR-0068 D3 pins Azure Container Apps Jobs as the substrate for cross-Node recurring orchestration. The ADR's "If Accepted" follow-up checklist names: "Add a `job-deploy-container-apps-job.yml` reusable workflow to `HoneyDrunk.Actions` — Container Apps Jobs need a deploy workflow analogous to `job-deploy-container.yml` (which deploys Container Apps, not Jobs); the new workflow handles Jobs-specific shape (schedule-or-event trigger, replica policy, retry policy)."

Per ADR-0012, `HoneyDrunk.Actions` is the Grid's CI/CD control plane — reusable workflows live there. The existing deploy workflows in the repo (`.github/workflows/`):
- `job-deploy-container-app.yml` — Azure Container Apps deploy (long-running Container Apps per ADR-0015 — Notify.Functions/Worker, Pulse.Collector, future Notify Cloud).
- `job-deploy-container.yml` — generic container deploy (the ADR follow-up text references this one's name).
- `job-deploy-function.yml` — Azure Function App deploy (Vault.Rotation grandfathered substrate per ADR-0068 D7).

The new `job-deploy-container-apps-job.yml` is the Jobs-shaped sibling. The Container Apps Jobs Azure surface differs from Container Apps in:
1. **Trigger** — schedule (cron) OR event (KEDA scaler), not always-on traffic.
2. **Replica policy** — `replicaCompletionCount`, `parallelism`, `replicaTimeout` instead of HTTP ingress + scale rules.
3. **Retry policy** — `replicaRetryLimit` at the platform level; per-job override allowed (ADR-0068 D7: default 3 retries, 1m/5m/25m exponential backoff).
4. **No traffic shifting** — Jobs don't have revisions in the Container-App sense; each job execution is a discrete replica.
5. **No health probe at deploy time** — the deploy succeeds when the Jobs resource is provisioned/updated; runtime health is reported per-execution by the Job, not gate-checked at deploy.

The workflow **reuses** the existing OIDC federation, the existing ACR build/push step, the existing Key Vault secret-reference pattern, and the existing managed-identity wiring — same Azure surface as Container Apps proper (per ADR-0015's shared Container Apps Environment + shared ACR). The differences are in the Container Apps Jobs-specific `az containerapp job` CLI calls and the trigger/replica/retry shape.

**This is a workflow/YAML packet. No .NET project.** `HoneyDrunk.Actions` is not a versioned .NET solution — no version bump.

## Scope
- `.github/workflows/job-deploy-container-apps-job.yml` — new reusable workflow.
- `docs/consumer-usage.md` (or the equivalent docs the deploy workflows reference) — document the new workflow's inputs, the schedule-vs-event trigger choice, and the per-job retry override.
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## Proposed Implementation
1. **Author `job-deploy-container-apps-job.yml`** as a `workflow_call` reusable workflow, modelled on `job-deploy-container-app.yml`'s shape. Required inputs:
   - `runs-on` (optional, default `ubuntu-latest`) — same as the sibling workflow.
   - `container-image` (optional) / `build-context` (optional) / `image-name` (optional) / `image-tag` (optional) / `dockerfile` (optional, default `Dockerfile`) — same build-or-supplied-image branch as the sibling.
   - `acr-registry` (required) — same ACR convention (`acrhdshared{env}.azurecr.io`).
   - `containerapps-job` (required) — target Container Apps Job name. Must validate against the `caj-hd-{service}-{env}` convention (ADR-0068 D3; invariant `{N2}` once promoted — the second of the four ADR-0068 invariants claimed in packet 01 from `constitution/invariant-reservations.md`).
   - `resource-group` (required).
   - `containerapps-environment` (required) — the Container Apps Environment (`cae-hd-{env}`) the Job lives in (shared with Container Apps per invariant 35).
   - `azure-client-id`, `azure-tenant-id`, `azure-subscription-id` (required) — OIDC federation, same as sibling.
   - `trigger-type` (required) — one of `Schedule`, `Event`, `Manual`. Drives whether the workflow sets `triggerType: Schedule` (with `cronExpression`) or `triggerType: Event` (with KEDA scaler config) on the Jobs resource.
   - `cron-expression` (optional) — required iff `trigger-type == Schedule`. Validated to be **5-field** (no seconds) per ADR-0063 D6.
   - `event-scaler-config-path` (optional) — required iff `trigger-type == Event`. Path to a YAML/JSON snippet describing the KEDA scaler (Service Bus, Event Grid, Storage Queue, custom) and `pollingInterval` / `minReplicas` / `maxReplicas`.
   - `replica-completion-count` (optional, default `1`) — `replicaCompletionCount`.
   - `parallelism` (optional, default `1`).
   - `replica-timeout-seconds` (optional, default `1800`) — 30-minute default; per-job override allowed.
   - `replica-retry-limit` (optional, default `3`) — ADR-0068 D7 default (3 retries; 1m/5m/25m exponential backoff is implicit Container Apps Jobs platform behaviour for the retry-limit case, but the default schedule can be overridden per-job).
   - `secrets-from-keyvault` (optional) — same Key Vault-backed runtime secrets pattern as the sibling workflow.
   - `app-insights-resource-id` (optional) — same as the sibling. If supplied, the post-deploy step calls the App Insights release annotations API per ADR-0045 D6 (the existing `job-deploy-container-app.yml` already does this — pattern is reused).
   - `app-insights-release-annotation` (optional boolean, default `false`) — gate the release-annotation step, same as the sibling.
2. **Steps in the workflow:**
   - **Validate** — assert `containerapps-job` matches `^caj-hd-[a-z0-9-]{1,13}-(dev|stg|prod)$` (invariant `{N2}` + invariant 19's 13-character service-name limit; tighten the upper bound if the Container Apps Jobs platform cap proves lower at packet 02's verification prerequisite). Fail the workflow if not.
   - **Authenticate** via OIDC (same `azure/login@v2` action and federated credential pattern as the sibling).
   - **Build and push** to ACR (if `build-context` is set) — reuse the sibling's build/push step verbatim.
   - **Provision or update the Job** via `az containerapp job create` / `az containerapp job update` with the right `--trigger-type`, `--cron-expression` or `--scale-rule-*` (KEDA), `--replica-completion-count`, `--parallelism`, `--replica-timeout`, `--replica-retry-limit`, `--secrets`, and `--registry-server` arguments.
   - **No health probe step** — Jobs don't have a deploy-time health probe (they aren't running yet; they trigger on schedule/event). Document this in the workflow header comment so callers don't expect one.
   - **Release annotation** (gated on `app-insights-release-annotation == true`) — call the App Insights release-annotation API (current supported `az monitor app-insights` / ARM path; legacy `aisvc.visualstudio.com` endpoint fallback only). Same pattern as the sibling. The annotation tags the deploy moment with the deployable name + SemVer.
3. **No-secret-in-the-workflow** — all auth via OIDC; secrets are pulled from Key Vault into the Container Apps Job's `secrets` collection by reference. Workflow logs never carry secret values (invariant 8).
4. **Header comment** — mirror the existing `job-deploy-container-app.yml` header: Purpose, Responsibilities, Target ("Repos with cross-Node recurring or event-triggered jobs deploying to Azure Container Apps Jobs per ADR-0068"), Usage Example (or pointer to `docs/consumer-usage.md`).
5. **Docs** — update `docs/consumer-usage.md` with a Container-Apps-Jobs example block: schedule-triggered (e.g. Communications cadence at `*/30 * * * *`) and event-triggered (Service Bus queue depth). Cross-link from the sibling Container-App workflow docs so a reader looking at one finds the other.

## Affected Files
- `.github/workflows/job-deploy-container-apps-job.yml` (new file)
- `docs/consumer-usage.md` (or the equivalent referenced docs)
- The repo `CHANGELOG.md` if the repo keeps one for the workflow surface.

## NuGet Dependencies
None. `HoneyDrunk.Actions` deploy workflows are GitHub Actions YAML — no .NET project is created or modified.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the correct repo — ADR-0068's follow-up checklist names "the `HoneyDrunk.Actions` reusable deploy workflows" explicitly. ADR-0012 makes Actions the CI/CD control plane.
- [x] The reusable workflow surface is the right shape — consuming repos call it from their own release workflows; the Container Apps Jobs deploy is a shared deploy-time concern.
- [x] No code change in any Node — per-Node job binaries land in packet 04 (Communications) and packet 03 (Notify, in-Node so no Container Apps Job deploy).
- [x] The Vault.Rotation Functions-timer-trigger workflow is **not** modified — Vault.Rotation is grandfathered per ADR-0068 D7.

## Acceptance Criteria
- [ ] `.github/workflows/job-deploy-container-apps-job.yml` exists as a reusable `workflow_call` workflow with all the inputs listed in Proposed Implementation
- [ ] The workflow validates `containerapps-job` against the `caj-hd-{service}-{env}` pattern, including the 13-character service-name limit (invariant 19)
- [ ] The workflow supports both `Schedule` (cron) and `Event` (KEDA scaler) trigger types, with `Manual` available as a `triggerType: Manual` shape; cron strings are validated as 5-field (no seconds — ADR-0063 D6)
- [ ] Replica policy inputs (`replica-completion-count`, `parallelism`, `replica-timeout-seconds`, `replica-retry-limit`) all have safe defaults; `replica-retry-limit` defaults to **3** per ADR-0068 D7
- [ ] OIDC federation reused from the existing pattern — no new credential or service principal
- [ ] Key Vault-backed runtime secrets pass through to the Job's `secrets` collection by reference; no secret value appears in the workflow file or workflow logs (invariant 8)
- [ ] Release-annotation step is included and gated on `app-insights-release-annotation == true` + non-empty `app-insights-resource-id`; uses `az monitor app-insights` / ARM as the default mechanism; legacy `aisvc` endpoint fallback only — same as the sibling `job-deploy-container-app.yml`
- [ ] No deploy-time health probe — documented in the header comment that Jobs don't have one
- [ ] `docs/consumer-usage.md` includes a schedule-triggered example and an event-triggered example
- [ ] Header comment mirrors `job-deploy-container-app.yml`'s structure (Purpose / Responsibilities / Target / Usage Example) and cites ADR-0068
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow surface
- [ ] Existing deploy workflows (`job-deploy-container-app.yml`, `job-deploy-container.yml`, `job-deploy-function.yml`) are **not** modified — this packet only adds a new workflow

## Human Prerequisites
- [ ] **Container Apps Jobs portal-side requires no Studio-wide one-time provisioning** — the existing `cae-hd-{env}` Container Apps Environment already supports Jobs alongside Container Apps; the shared ACR (`acrhdshared{env}`) already serves Job images. There is **no separate environment to provision**. The first consuming Job's deploy (packet 04 — Communications cadence) creates its own `caj-hd-comms-cadence-{env}` Job resource via this workflow.
- [ ] The OIDC federated credential the existing deploy workflows use already covers the resource scope needed for `Microsoft.App/jobs/*` provisioning, because Container Apps Jobs live under the same `Microsoft.App` resource provider as Container Apps proper. **Verify** in the Azure portal at packet 02 first-use time: the deploy identity has at least `Container Apps Contributor` (or `Contributor`) on the resource group. If it does not, a one-time RBAC grant via the portal is needed before any Job deploy. This is the portal click the operator performs; the workflow itself just calls `az`.
- [ ] **Verify the actual Azure Container Apps Jobs resource-name length limit** before locking the regex. Invariant 19 ("13-character service-name limit") was derived from Azure Container Apps proper (`ca-hd-{service}-{env}` pattern). The Azure platform enforces a per-resource-type max length on `Microsoft.App/jobs/*` that may or may not match the Container Apps limit. Confirm via the [`Microsoft.App/jobs` resource reference](https://learn.microsoft.com/en-us/azure/templates/microsoft.app/jobs) (or via an `az containerapp job create --help` smoke test that intentionally hits the limit) what the actual cap is for the **full** resource name (`caj-hd-{service}-{env}` — 7 fixed chars + service + 1 dash + env). Document the constraint in this packet's PR description with the relationship to invariant 19:
  - If the Jobs limit ≥ the Container Apps limit: invariant 19's 13-character cap on `{service}` carries over unchanged; the workflow's regex `^caj-hd-[a-z0-9-]{1,13}-(dev|stg|prod)$` is correct.
  - If the Jobs limit < the Container Apps limit: tighten the regex to the lower cap and flag a follow-up to record the Jobs-specific cap (either as a refinement to invariant 19 or as a new invariant tied to ADR-0068's `{N2}`). Note in the PR that the discrepancy was discovered at this verification step.
- [ ] No App Insights resource is provisioned by this packet; the release-annotation step gates on a caller-supplied `app-insights-resource-id` (ADR-0040 provisions the resource).

## Referenced ADR Decisions
**ADR-0068 D3 — Cross-Node Container Apps Jobs.** Every cross-Node recurring or event-driven job runs on Azure Container Apps Jobs. Trigger shapes: schedule-triggered (cron, 5-field UTC) or event-triggered (KEDA scaler — Service Bus queue depth, Event Grid event arrival, Storage Queue length, custom scaler). Naming: `caj-hd-{service}-{env}` with the 13-character service-name limit (invariant 19).

**ADR-0068 D7 — Retry policy defaults.** Container Apps Jobs default: 3 retries, exponential 1m/5m/25m backoff. Per-job override allowed in the manifest. Final failure emits `JobFailure` audit entry per ADR-0030 and raises error per ADR-0045.

**ADR-0068 "If Accepted" follow-up.** "Add a `job-deploy-container-apps-job.yml` reusable workflow to `HoneyDrunk.Actions` — Container Apps Jobs need a deploy workflow analogous to `job-deploy-container.yml` (which deploys Container Apps, not Jobs); the new workflow handles Jobs-specific shape (schedule-or-event trigger, replica policy, retry policy)."

**ADR-0015 — Container Apps shared Environment and ACR.** Per invariant 35, one shared `cae-hd-{env}` Environment and one shared `acrhdshared{env}` ACR serve every containerized resource in a given environment — Container Apps **and** Container Apps Jobs.

**ADR-0012 — Actions as CI/CD control plane.** Reusable workflows live in `HoneyDrunk.Actions`. Consuming repos' release workflows call them.

**ADR-0033 — Tag→environment mapping.** SemVer tags drive environment; the workflow takes the deployable's version as an input (same convention as the sibling).

**ADR-0063 D6 — Cron format.** 5-field UTC. The workflow validates input.

**ADR-0045 D6 — Release annotation.** App Insights release-annotation API call after a successful deploy; use the current supported mechanism (`az monitor app-insights` / ARM). Same pattern the existing container-app workflow uses (packet 04 of `adr-0045-grid-wide-error-tracking`).

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow files.** The annotation API call is OIDC/AAD-authenticated. No DSN, instrumentation key, connection string, or any secret value is committed to a workflow or the repo.

> **Invariant 35 — Shared Container Apps Environment and ACR per environment.** Container Apps Jobs reuse the existing `cae-hd-{env}` Environment and `acrhdshared{env}` registry; the workflow does not provision new platform-level resources.

- **Use the current supported `az` surface.** `az containerapp job` was GA in 2023; the workflow uses it directly. If a more recent surface (Bicep module, ARM-only path) becomes preferred during execution, the workflow's `az` calls can be swapped for an equivalent; the contract (the workflow's inputs/outputs) does not change.
- **No deploy-time health probe.** Container Apps Jobs don't run at deploy time; there's nothing to probe until the schedule or event fires. The workflow header documents this so consumers don't expect probe-based gating.
- **No new credential.** The existing OIDC federation covers Microsoft.App/jobs/* — if not, the portal RBAC fix is a Human Prerequisite, not a workflow change.
- **Backward-compatible — additive workflow.** This is a new file; existing deploy workflows are untouched. Existing consumers are unaffected.
- **Validation, not best-effort.** Inputs that drive Azure resource names (`containerapps-job`) are regex-validated at workflow start; the workflow fails fast with a clear message rather than failing on an `az` error later.

## Labels
`feature`, `tier-2`, `ops`, `ci-cd`, `adr-0068`, `wave-2`

## Agent Handoff

**Objective:** Author the `job-deploy-container-apps-job.yml` reusable workflow for Container Apps Jobs deploys.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Land the deploy substrate that packet 04 (Communications cadence Job) will use; make subsequent cross-Node Container Apps Jobs deploys a near-mechanical `workflow_call`.
- Feature: ADR-0068 Background Job and Recurring Work Substrate rollout, Wave 2.
- ADRs: ADR-0068 D3/D7 (primary), ADR-0015 (Container Apps platform), ADR-0012 (Actions as CI/CD control plane), ADR-0033 (tag→environment mapping), ADR-0063 D6 (cron 5-field UTC), ADR-0045 D6 (release annotation reused).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft; ADR-0068's reference and catalog updates land first so consumers reading the boundary docs see the substrate decision.

**Constraints:**
- Name validation regex `^caj-hd-[a-z0-9-]{1,13}-(dev|stg|prod)$` (invariant `{N2}` + invariant 19); tighten upper bound if the Container Apps Jobs platform cap proves lower at the verification prerequisite.
- 5-field UTC cron validated (ADR-0063 D6).
- OIDC reused; no new credential.
- No deploy-time health probe.
- No secret in the workflow (invariant 8).
- Replica retry limit defaults to 3 (ADR-0068 D7).
- Existing deploy workflows untouched.

**Key Files:**
- `.github/workflows/job-deploy-container-apps-job.yml` (new).
- `.github/workflows/job-deploy-container-app.yml` (sibling — read for OIDC/ACR/Key-Vault/release-annotation pattern; do NOT modify).
- `docs/consumer-usage.md` (new examples added).

**Contracts:** None — workflow inputs only.
