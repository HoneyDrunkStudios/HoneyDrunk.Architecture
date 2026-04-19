---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0015"]
dependencies: ["architecture-container-apps-walkthroughs", "actions-deploy-container-app-workflow"]
adrs: ["ADR-0015", "ADR-0005", "ADR-0012"]
wave: 2
initiative: adr-0015-container-apps-rollout
node: honeydrunk-pulse
---

# Feature: Release workflow and Azure bring-up for `Pulse.Collector` on Azure Container Apps

## Summary
Add a release workflow that builds `Pulse.Collector` as a container image, pushes to `acrhdshared{env}`, and deploys to `ca-hd-pulse-{env}` via `job-deploy-container-app.yml`. Provision the supporting Azure resources including gRPC-capable ingress.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Pulse`

## Motivation
`Pulse.Collector` is a gRPC service (`Microsoft.NET.Sdk.Web` with Dockerfile using `mcr.microsoft.com/dotnet/aspnet:10.0`). ADR-0015 selects Container Apps specifically to get first-class gRPC / HTTP-2 support through its built-in ingress — App Service's HTTP-2 story was a key factor in the decision. This packet exercises that choice end-to-end.

## Proposed Implementation

### `.github/workflows/release-collector.yml` (new)

Triggered on tag push `collector-v*`. Uses `job-deploy-container-app.yml`:

```yaml
uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-container-app.yml@main
with:
  build-context: src/Pulse.Collector
  image-name: honeydrunk-pulse-collector
  image-tag: ${{ github.ref_name }}
  acr-registry: acrhdshared${{ vars.HD_ENV }}.azurecr.io
  container-app: ca-hd-pulse-${{ vars.HD_ENV }}
  resource-group: rg-hd-pulse-${{ vars.HD_ENV }}
  keyvault-name: kv-hd-pulse-${{ vars.HD_ENV }}
  keyvault-secrets: |
    PulseIngestSigningKey
  # gRPC health probe is HTTP-based on /health; Pulse.Collector exposes both gRPC and a REST health endpoint.
  health-check-url: /health
  traffic-shift-mode: full
secrets:
  azure-client-id: ${{ vars.AZURE_CLIENT_ID }}
  azure-tenant-id: ${{ vars.AZURE_TENANT_ID }}
  azure-subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

Note the Container App name is `ca-hd-pulse-{env}` not `ca-hd-pulse-collector-{env}` — `Pulse.Collector` is currently the only deployable in the Pulse Node, so the Node-level name applies. If a second containerized Pulse deployable appears later, the existing app is renamed via a follow-up ADR.

### Dockerfile review

`src/Pulse.Collector/Dockerfile` already exists. Confirm it matches ADR-0015 conventions:
- Multi-stage build, `sdk:10.0` → `aspnet:10.0`.
- Non-root user in runtime stage (`USER app` — add if missing).
- `EXPOSE 8080` for HTTP/2 traffic (gRPC).
- `ASPNETCORE_URLS=http://+:8080` in runtime environment.

### gRPC ingress configuration

Container Apps ingress for gRPC requires:
- Transport: `http2`
- Target port: 8080
- External ingress if clients are outside the Container Apps Environment, internal otherwise. For Pulse.Collector's initial bring-up, default to **external** to simplify client testing — tighten to internal-only in a follow-up once client topology is settled.

### Health endpoint

Pulse.Collector must expose a REST `/health` endpoint in addition to its gRPC service. If one doesn't exist, add a minimal `MapGet("/health", () => Results.Ok())` in `Program.cs`. Container Apps' HTTP probes target this, not the gRPC service directly.

### `CHANGELOG.md`
Add entry under Unreleased.

## Affected Files
- `.github/workflows/release-collector.yml` (new)
- `src/Pulse.Collector/Dockerfile` (review and align)
- `src/Pulse.Collector/Program.cs` (add `/health` endpoint if missing)
- `CHANGELOG.md`

## NuGet Dependencies

### `Pulse.Collector` — additions only if missing
| Package | Notes |
|---|---|
| `HoneyDrunk.Vault.Providers.AzureKeyVault` | Already expected from ADR-0005 rollout. Confirm present. |
| `HoneyDrunk.Vault.Providers.AppConfiguration` | Already expected. Confirm present. |
| `Grpc.AspNetCore` | Confirm present — this is the gRPC service framework. |

No new packages unless `/health` endpoint requires nothing beyond `WebApplication` builder (which is already in place via `Microsoft.NET.Sdk.Web`).

## Boundary Check
- [x] Runtime secret handling unchanged. ADR-0005 migration already in place.
- [x] gRPC contracts unchanged.
- [x] Deploy logic lives in `HoneyDrunk.Actions`; this repo only calls the reusable workflow.
- [x] Ingress configured for HTTP/2 at Container App level — no application code change required for HTTP/2.

## Acceptance Criteria
- [ ] Pushing a `collector-v0.1.0` tag on `main` triggers `release-collector.yml`, builds and pushes the image, creates a new revision at 0% traffic, health-probes, and shifts traffic to 100%.
- [ ] `/health` returns 200 on the deployed revision's direct FQDN.
- [ ] A gRPC client can call an RPC method against the Container App's ingress hostname over HTTPS (HTTP/2).
- [ ] `PulseIngestSigningKey` resolves at runtime via Managed Identity — verified by a signed telemetry sample being accepted.
- [ ] Scale behavior: send 0 RPCs for configured cooldown → Container App scales to 0 replicas. Sending RPCs causes cold start and scale up.
- [ ] Rollback: shift traffic back to previous revision; gRPC calls cut over within seconds.
- [ ] No client secrets in the workflow — OIDC only.
- [ ] `CHANGELOG.md` updated.

## Human Prerequisites
- [ ] `acrhdshareddev` and `cae-hd-dev` provisioned per packet 01 walkthroughs.
- [ ] `rg-hd-pulse-dev` and `kv-hd-pulse-dev` provisioned per [`infrastructure/key-vault-creation.md`](../../../../infrastructure/key-vault-creation.md). Seed `PulseIngestSigningKey` in the vault.
- [ ] `ca-hd-pulse-dev` Container App provisioned via portal per [`infrastructure/container-app-creation.md`](../../../../infrastructure/container-app-creation.md):
  - Resource group: `rg-hd-pulse-dev`
  - Environment: `cae-hd-dev`
  - System-assigned MI
  - Image: `acrhdshareddev.azurecr.io/honeydrunk-pulse-collector:bootstrap` (placeholder; pre-push hello-world if needed for first provisioning)
  - Revision mode: `Multiple`
  - **Ingress: External, transport `http2`, target port 8080**
  - Env vars: `AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT=Development`, `HONEYDRUNK_NODE_ID=honeydrunk-pulse`, `ASPNETCORE_URLS=http://+:8080`
  - Scale: min replicas 0, max 5, HTTP concurrency rule (e.g. 10 concurrent requests).
- [ ] RBAC: `ca-hd-pulse-dev` MI → `Key Vault Secrets User` on `kv-hd-pulse-dev` and `AcrPull` on `acrhdshareddev`.
- [ ] OIDC federated credential for `HoneyDrunkStudios/HoneyDrunk.Pulse` (environment `dev`) granted `Container Apps Contributor` on `rg-hd-pulse-dev` and `AcrPush` on `acrhdshareddev`.
- [ ] GitHub Actions environment `dev` on the repo with `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `HD_ENV=dev`.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 17:** One Key Vault per deployable Node per environment. Pulse's vault: `kv-hd-pulse-{env}`.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. Never derived by convention, never hardcoded.

> **Invariant 34 (proposed):** Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`. Pulse: `ca-hd-pulse-{env}`.

> **Invariant 35 (proposed):** One shared Container Apps Environment (`cae-hd-{env}`) and one shared Azure Container Registry (`acrhdshared{env}`).

> **Invariant 36 (proposed):** Container App revision mode is `Multiple` with explicit traffic splitting on deploy.

## Referenced ADR Decisions

**ADR-0015 (Container Hosting Platform):** Container Apps selected specifically for first-class gRPC support; Multiple revision mode; shared CAE and ACR; system-assigned MI; OIDC for CI.

**ADR-0005 (Configuration and Secrets Strategy):** Env-var bootstrap, per-Node vault, `{Provider}--{Key}` secret naming (here: flat `PulseIngestSigningKey` — Node-internal, not provider-grouped).

**ADR-0012 (Grid CI/CD Control Plane):** Deploy logic in `HoneyDrunk.Actions`. This packet consumes `job-deploy-container-app.yml` from packet 02.

## Dependencies
- `architecture-container-apps-walkthroughs` (packet 01) — Container App creation walkthrough.
- `actions-deploy-container-app-workflow` (packet 02) — reusable workflow.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0015`

## Agent Handoff

**Objective:** Ship `Pulse.Collector` as a production gRPC Container App — the Grid's first externally reachable service.
**Target:** HoneyDrunk.Pulse, branch from `main`

**Context:**
- Goal: Exercise the gRPC-on-Container-Apps path that the ADR was written to enable.
- Feature: ADR-0015 rollout.
- ADRs: ADR-0015 (hosting), ADR-0005 (secrets), ADR-0012 (CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packets 01 and 02 merged. Human-provisioned Container App with HTTP/2 ingress in place before the first tag push.

**Constraints:**
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. Do not log `PulseIngestSigningKey` anywhere under any circumstances.
- **Invariant 9:** Vault is the only source of secrets. Signing key resolves through `ISecretStore` at verification time.
- **Invariant 17:** Vault is `kv-hd-pulse-{env}`.
- **Invariant 34 (proposed):** Container App name `ca-hd-pulse-{env}`. Node-level name since Collector is currently the only containerized Pulse deployable.
- **Invariant 35 (proposed):** Reuse `cae-hd-{env}` and `acrhdshared{env}` — do not create Pulse-specific ones.
- **Invariant 36 (proposed):** Revision mode `Multiple`. Workflow will fail fast if single-revision.

**Key Files:**
- `.github/workflows/release-collector.yml` (new — primary authoring target)
- `src/Pulse.Collector/Dockerfile` (review; align to conventions)
- `src/Pulse.Collector/Program.cs` (add `/health` if missing)
- `CHANGELOG.md`

**Contracts:** gRPC service contracts in `Pulse.Collector` unchanged.
