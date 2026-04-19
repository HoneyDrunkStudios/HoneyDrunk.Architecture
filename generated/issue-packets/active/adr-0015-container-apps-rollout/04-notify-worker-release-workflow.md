---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0015"]
dependencies: ["architecture-container-apps-walkthroughs", "actions-deploy-container-app-workflow"]
adrs: ["ADR-0015", "ADR-0005", "ADR-0012"]
wave: 2
initiative: adr-0015-container-apps-rollout
node: honeydrunk-notify
---

# Feature: Release workflow and Azure bring-up for `Notify.Worker` on Azure Container Apps

## Summary
Add a release workflow that builds `HoneyDrunk.Notify.Worker` as a container image, pushes to `acrhdshared{env}`, and deploys to `ca-hd-notify-worker-{env}` via the new reusable `job-deploy-container-app.yml`. Provision the supporting Azure resources.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Notify`

## Motivation
`Notify.Worker` is a background worker (`Microsoft.NET.Sdk.Worker`) with an existing Dockerfile targeting `mcr.microsoft.com/dotnet/runtime:10.0`. ADR-0015 picks Azure Container Apps as its host because its workload shape — a queue-driven worker that spends most time idle — benefits directly from KEDA-based scale-to-zero and revision-based rollbacks. This packet wires the release pipeline and provisions the Container App.

## Proposed Implementation

### `.github/workflows/release-worker.yml` (new)

Triggered on tag push `worker-v*`. Uses the reusable Container App workflow:

```yaml
uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml@main
with:
  build-context: src/HoneyDrunk.Notify.Worker
  image-name: honeydrunk-notify-worker
  image-tag: ${{ github.ref_name }}
  acr-registry: acrhdshared${{ vars.HD_ENV }}.azurecr.io
  container-app: ca-hd-notify-worker-${{ vars.HD_ENV }}
  resource-group: rg-hd-notify-${{ vars.HD_ENV }}
  keyvault-name: kv-hd-notify-${{ vars.HD_ENV }}
  keyvault-secrets: |
    Resend--ApiKey
    Twilio--AccountSid
    Twilio--AuthToken
    Smtp--Username
    Smtp--Password
    NotifyQueueConnection
  health-check-url: /health
  traffic-shift-mode: full
secrets:
  azure-client-id: ${{ vars.AZURE_CLIENT_ID }}
  azure-tenant-id: ${{ vars.AZURE_TENANT_ID }}
  azure-subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

### Dockerfile review

`src/HoneyDrunk.Notify.Worker/Dockerfile` already exists. Confirm it matches ADR-0015 conventions:

- Multi-stage build using `mcr.microsoft.com/dotnet/sdk:10.0` for build stage.
- Runtime stage uses `mcr.microsoft.com/dotnet/runtime:10.0`.
- Non-root user in the runtime stage (`USER app` or equivalent — add if missing).
- No secrets baked into the image.
- Exposes a port for the health probe if the worker does not already expose one.

Add a minimal HTTP health listener to the worker if none exists (tiny `WebApplication.CreateBuilder` alongside the `Host.CreateApplicationBuilder` or a background `IHostedService` bound to the default Container Apps port `8080`). Return 200 when the `BackgroundService` has started. Keep it minimal — this is only for the deploy health probe.

### KEDA scale rule

The Container App is created with a KEDA scale rule on the Notify queue (Azure Storage Queue or Service Bus — match the transport in `NotifyQueueConnection`). Scale 0 → 10 on queue depth. Configured once at Container App creation time in the portal; documented in Human Prerequisites.

### `CHANGELOG.md`
Add entry under Unreleased for "Add release workflow for Notify.Worker Container App."

## Affected Files
- `.github/workflows/release-worker.yml` (new)
- `src/HoneyDrunk.Notify.Worker/Dockerfile` (review; adjust to ADR-0015 conventions if needed)
- `src/HoneyDrunk.Notify.Worker/Program.cs` (add minimal health listener if not present)
- `CHANGELOG.md`

## NuGet Dependencies

### `HoneyDrunk.Notify.Worker` — additions only if missing
| Package | Notes |
|---|---|
| `HoneyDrunk.Vault.Providers.AzureKeyVault` | Already expected from ADR-0005 rollout. Confirm present. |
| `HoneyDrunk.Vault.Providers.AppConfiguration` | Already expected. Confirm present. |
| `Microsoft.AspNetCore.App` (framework reference) | Required if adding the minimal health listener. |

## Boundary Check
- [x] Runtime secret handling unchanged — ADR-0005 migration already in place.
- [x] No Transport contract change. Worker consumes existing queue contract.
- [x] Deploy logic lives entirely in `HoneyDrunk.Actions`; this repo only calls the reusable workflow.
- [x] Dockerfile changes (if any) align with ADR-0015 container conventions.

## Acceptance Criteria
- [ ] Pushing a `worker-v0.1.0` tag on `main` triggers `release-worker.yml`, builds and pushes the image to `acrhdshareddev`, creates a new revision on `ca-hd-notify-worker-dev` at 0% traffic, health-probes, and shifts traffic to 100%.
- [ ] `/health` returns 200 on the deployed revision's direct FQDN.
- [ ] Queue depth > 0 in the dev environment causes the Container App to scale up from zero via KEDA; depth returns to 0 triggers scale-to-zero within the configured cooldown.
- [ ] The worker consumes a test message end-to-end: enqueue → worker pulls → provider sends → queue message deleted.
- [ ] Rollback: manually shift traffic back to the previous revision; traffic cuts over within seconds without redeploy.
- [ ] No client secrets in the workflow — OIDC only.
- [ ] `CHANGELOG.md` updated.

## Human Prerequisites
- [ ] `acrhdshareddev` and `cae-hd-dev` provisioned per packet 01 walkthroughs.
- [ ] `rg-hd-notify-dev`, `kv-hd-notify-dev` provisioned (shared with packet 03 if Notify.Functions lands first).
- [ ] `ca-hd-notify-worker-dev` Container App provisioned via portal per [`infrastructure/container-app-creation.md`](../../../../infrastructure/container-app-creation.md):
  - Resource group: `rg-hd-notify-dev`
  - Environment: `cae-hd-dev`
  - System-assigned MI
  - Image: `acrhdshareddev.azurecr.io/honeydrunk-notify-worker:bootstrap` (placeholder — replaced on first deploy). Pre-push a hello-world image tagged `bootstrap` if needed to create the app before the first real deploy.
  - Revision mode: `Multiple`
  - Ingress: enabled on port 8080 (for health probe), internal-only if the worker does not need public reachability.
  - Env vars: `AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT=Development`, `HONEYDRUNK_NODE_ID=honeydrunk-notify-worker`
  - KEDA scale rule on `NotifyQueueConnection` queue depth (0 → 10, queue length threshold 5).
- [ ] RBAC: `ca-hd-notify-worker-dev` MI → `Key Vault Secrets User` on `kv-hd-notify-dev` and `AcrPull` on `acrhdshareddev`.
- [ ] OIDC federated credential for `HoneyDrunkStudios/HoneyDrunk.Notify` (environment `dev`, or existing credential if shared with packet 03) granted `Container Apps Contributor` on `rg-hd-notify-dev` and `AcrPush` on `acrhdshareddev`.
- [ ] GitHub Actions environment `dev` on the repo has `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `HD_ENV=dev`.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`. Notify.Worker shares the Notify Node's vault: `kv-hd-notify-{env}`.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. Never derived by convention, never hardcoded.

> **Invariant 34 (proposed):** Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`. Notify.Worker: `ca-hd-notify-worker-{env}` (13 chars including hyphens — within Invariant 19 limit).

> **Invariant 35 (proposed):** One shared Container Apps Environment (`cae-hd-{env}`) and one shared Azure Container Registry (`acrhdshared{env}`) serve every containerized Node. Notify.Worker reuses both.

> **Invariant 36 (proposed):** Container App revision mode is `Multiple` with explicit traffic splitting on deploy.

## Referenced ADR Decisions

**ADR-0015 (Container Hosting Platform):** Azure Container Apps, Multiple revision mode, KEDA scaling, shared CAE and ACR, system-assigned MI with AcrPull + Key Vault Secrets User, OIDC for CI with AcrPush + Container Apps Contributor.

**ADR-0005 (Configuration and Secrets Strategy):** Env-var bootstrap, per-Node vault, provider-grouped secret naming. All enforced by the reusable workflow and the Container App env-var configuration.

**ADR-0012 (Grid CI/CD Control Plane):** Deploy logic lives in `HoneyDrunk.Actions`. This packet consumes `job-deploy-container-app.yml` from packet 02 — no local reimplementation.

## Dependencies
- `architecture-container-apps-walkthroughs` (packet 01) — provides the Container App creation walkthrough.
- `actions-deploy-container-app-workflow` (packet 02) — provides the reusable workflow this packet calls.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0015`

## Agent Handoff

**Objective:** Ship `Notify.Worker` as a production Container App with KEDA scaling and revision-based rollout.
**Target:** HoneyDrunk.Notify, branch from `main`

**Context:**
- Goal: First containerized deployable on the Grid. Template for `Pulse.Collector` in the same wave.
- Feature: ADR-0015 rollout.
- ADRs: ADR-0015 (hosting), ADR-0005 (secrets), ADR-0012 (CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01 and 02 merged. Human-provisioned Container App in place before the first tag push.

**Constraints:**
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. Worker must honor this during queue processing — do not log full payloads if they may carry credentials.
- **Invariant 9:** Vault is the only source of secrets. All provider credentials resolve through `ISecretStore` at call time.
- **Invariant 17:** Vault is `kv-hd-notify-{env}`, shared with `Notify.Functions`.
- **Invariant 34 (proposed):** Container App name `ca-hd-notify-worker-{env}`. Never deviate.
- **Invariant 36 (proposed):** Revision mode must remain `Multiple`. The workflow will fail fast if single-revision mode is detected — do not attempt to work around it.

**Key Files:**
- `.github/workflows/release-worker.yml` (new — primary authoring target)
- `src/HoneyDrunk.Notify.Worker/Dockerfile` (review; align to conventions)
- `src/HoneyDrunk.Notify.Worker/Program.cs` (add health endpoint if missing)
- `CHANGELOG.md`

**Contracts:** None changed.
