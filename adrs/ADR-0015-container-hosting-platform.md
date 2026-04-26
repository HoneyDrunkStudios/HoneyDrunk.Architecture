# ADR-0015: Container Hosting Platform for Deployable Nodes

**Status:** Accepted
**Date:** 2026-04-18
**Deciders:** HoneyDrunk Studios
**Sector:** Infrastructure

## Context

ADR-0005 settled configuration and secrets. ADR-0012 named `HoneyDrunk.Actions` as the Grid's CI/CD control plane. What has not yet been decided is **where containerized Nodes run in Azure**.

The Grid is about to produce its first non-NuGet deployables. Three deployable shapes are in flight:

- **Notify.Functions** — Azure Functions v4 isolated worker (Function App).
- **Notify.Worker** — `Microsoft.NET.Sdk.Worker` background service, containerized (Dockerfile present).
- **Pulse.Collector** — ASP.NET Core gRPC service, containerized (Dockerfile present).

Function Apps have a clear target. The two containerized workloads do not. Azure offers several viable hosts:

- App Service for Linux Containers (classic, slot-based, HTTP-metric scaling, Always On required for workers).
- Azure Container Apps (KEDA-native, scale-to-zero, first-class gRPC, revision-based traffic splits).
- Azure Container Instances (single-container, no scaling story).
- AKS (full Kubernetes — operationally disproportionate for current scale).

`HoneyDrunk.Actions` already ships `job-deploy-function.yml` for Function Apps and `job-deploy-container.yml` for App Service Linux Containers. There is **no** reusable workflow for Azure Container Apps. Picking a platform determines whether we reuse the existing container workflow or author a new one.

## Decision

### Containerized Nodes run on Azure Container Apps

Every containerized deployable Node in the Grid runs on **Azure Container Apps** (Consumption plan) unless an explicit exception is ratified in a follow-up ADR. Function Apps remain on the Azure Functions hosting plane as decided by their runtime shape — this ADR does not change that.

**Why Container Apps over App Service for Linux Containers:**

| Dimension | App Service (Linux Containers) | Container Apps |
|---|---|---|
| gRPC / HTTP/2 end-to-end | Awkward; Front Door / App Gateway compounds it | First-class, native through built-in ingress |
| Scaling model for workers | HTTP-metric only, requires Always On | KEDA — queue depth, event sources, custom metrics |
| Idle cost | Paid 24/7 per plan tier | Scale-to-zero on Consumption |
| Traffic management | Slots (fixed plan cost per slot) | Revisions — built-in blue/green and percentage canary |
| Forward direction | Mature but low new-investment | Microsoft's current containerized-PaaS investment |

For the Grid's actual workloads — a queue-driven worker (Notify.Worker) and a gRPC service (Pulse.Collector) — Container Apps matches every relevant shape. App Service would require Always On billing for the worker and painful HTTP/2 plumbing for gRPC.

**Cost note.** At the Grid's current scale (solo developer, low/bursty traffic), Container Apps Consumption is expected to stay inside or near the monthly free grant (~180K vCPU-seconds, ~360K GiB-seconds, 2M requests). Equivalent App Service coverage would bill ~$15–$70 per plan per environment continuously. Cost does not block this decision.

### Shared Container Apps Environment per environment

One Container Apps Environment hosts every containerized Node per environment:

```
cae-hd-{env}
```

The environment is the VNet / log-workspace / quota boundary. Per-Node environments were rejected: they multiply fixed resource cost, fragment the log aggregation point, and deliver no additional isolation because identity boundaries already live at Managed Identity and Key Vault (ADR-0005). Tenant isolation between Container Apps inside one environment is sufficient for the Grid's trust model.

The environment routes diagnostics to the shared Log Analytics workspace `log-hd-shared-{env}` (ADR-0005 / Invariant 22).

### Shared Azure Container Registry per environment

One Azure Container Registry stores every Node's images per environment:

```
acrhdshared{env}
```

Azure Container Registry names are alphanumeric only, 5–50 chars, globally unique — hence the compressed form. Per-Node registries were rejected: image storage is not a security boundary (each Container App uses its own Managed Identity to pull, and image tags encode the Node), fixed SKU cost multiplies with little benefit, and a shared registry simplifies vulnerability-scan aggregation.

SKU: **Basic** per environment initially. Upgrade to Standard if retention, geo-replication, or webhook throughput demands it.

### One Container App per deployable Node per environment

Each containerized Node gets exactly one Container App per environment:

```
ca-hd-{service}-{env}
```

This mirrors the existing `rg-hd-{service}-{env}` / `kv-hd-{service}-{env}` pattern 1:1 (ADR-0005, Invariants 17 and 19). The 13-char service-name ceiling (Invariant 19) already covers this name form.

Each Container App runs with a system-assigned Managed Identity granted:
- `Key Vault Secrets User` on its own `kv-hd-{service}-{env}` only.
- `AcrPull` on the shared ACR.

Bootstrap env vars (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT`, `HONEYDRUNK_NODE_ID`) are set as Container App environment variables at deploy time, matching the contract in ADR-0005. No change to the bootstrap surface inside application code.

### Revision strategy — `Multiple` with traffic splitting

Container Apps run in `Multiple` revision mode by default. Deploys create a new revision with 0% traffic, the deploy pipeline runs a health probe against the revision's direct FQDN, and traffic is shifted to 100% on success. Failed health check leaves the old revision serving.

Single-revision mode was rejected because it forces in-place replacement without a rollback seam.

### GitHub Actions deploys via OIDC

CI/CD uses GitHub OIDC federated credentials granted:
- `Contributor` on the target Container App (or more narrowly, `Container Apps Contributor`).
- `AcrPush` on the shared ACR.

This extends the OIDC model already established in ADR-0005 §Access — no new credential tier.

A new reusable workflow `job-deploy-container-app.yml` lands in `HoneyDrunk.Actions`. It mirrors the existing `job-deploy-function.yml` contract: take a built image reference, push to ACR, create a new Container App revision, probe, then shift traffic.

### Dockerfile conventions

Containerized Nodes ship a `Dockerfile` at the repo root or next to the deployable `.csproj`. Baseline:

- Multi-stage build — `mcr.microsoft.com/dotnet/sdk:10.0` for build, `mcr.microsoft.com/dotnet/aspnet:10.0` (web) or `.../runtime:10.0` (worker) for runtime.
- Non-root user in the runtime stage.
- Expose `8080` for HTTP; gRPC listens on the same port via ASP.NET Core.
- No secrets or config baked into the image. All runtime state comes from env vars + Key Vault per ADR-0005.

## Consequences

### Affected Nodes

- **HoneyDrunk.Notify** — `Notify.Functions` deploys as a Function App (unchanged). `Notify.Worker` deploys as a Container App. Dockerfile already present; release workflow to be added.
- **HoneyDrunk.Pulse** — `Pulse.Collector` deploys as a Container App. Dockerfile already present; release workflow to be added.
- **HoneyDrunk.Actions** — Adds `job-deploy-container-app.yml` reusable workflow plus supporting composite actions (`azure/deploy-container-app`, possibly reusing `azure/acr-login`).
- **HoneyDrunk.Architecture** — Adds infrastructure walkthroughs for Function App, ACR, Container Apps Environment, and Container App creation.
- **HoneyDrunk.Vault** — No code change. Existing bootstrap contract is honored verbatim.

### New Invariants

The following invariants are proposed for addition to `constitution/invariants.md`:

34. **Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`, one per Node per environment, with system-assigned Managed Identity.** See ADR-0015.
35. **One shared Container Apps Environment (`cae-hd-{env}`) and one shared Azure Container Registry (`acrhdshared{env}`) serve every containerized Node within a given environment.** Per-Node compute environments or registries are forbidden without a follow-up ADR. See ADR-0015.
36. **Container App revision mode is `Multiple` with explicit traffic splitting on deploy.** Single-revision mode is forbidden — it removes the rollback seam. See ADR-0015.

### Operational Consequences

- Basic SKU ACR adds a small fixed monthly cost per environment (~$5 at time of writing). Budget accordingly.
- Container Apps Environment is free, but Log Analytics ingestion from Container Apps diagnostics is billed through the shared workspace. Apply log sampling and level discipline.
- Container image vulnerability scanning runs in CI before push (`HoneyDrunk.Actions` `security/vulnerability-scan` composite). Pushed images are the SBoM record.
- Rollback path: shift traffic on the Container App back to the previous revision. No image republish required.
- Walkthroughs for provisioning live in `infrastructure/`, not in this ADR.

## Alternatives Considered

### App Service for Linux Containers

Rejected. The existing `job-deploy-container.yml` targets this platform and would avoid new workflow work, but the workload fit is poor: worker Always On billing, awkward gRPC plumbing, coarser traffic management via slots, and no KEDA-style autoscaling. The one-time cost of a new reusable workflow is worth paying.

### Azure Container Instances

Rejected. ACI is single-container with no built-in scaling or revision model. It targets batch / one-shot workloads, not long-running services. Using it for the Grid's deployables would rebuild primitives Container Apps already provides.

### AKS

Rejected. Full Kubernetes is operationally disproportionate for a solo developer at current scale. Container Apps is built on AKS internally — moving to raw AKS later is an available escape hatch if scale demands it. No reason to take on that surface now.

### Per-Node Container Apps Environments

Rejected. A Container Apps Environment is the VNet and log-workspace boundary. Multiplying it per Node fragments log aggregation, raises fixed cost, and provides no security boundary beyond what Managed Identity and Key Vault isolation already deliver (ADR-0005). A shared environment with per-Node Container Apps matches the isolation model already in the Grid.

### Per-Node Azure Container Registries

Rejected. Container images are not a trust boundary — pull authorization sits on the Managed Identity, and image integrity is verified at runtime. Per-Node registries multiply fixed SKU cost without a commensurate benefit, and they fragment vulnerability-scan aggregation.

### Single-revision Container App mode

Rejected. Single-revision mode replaces the running revision in place with no rollback seam. Multiple-revision mode with traffic splitting is the standard production pattern and matches the slot-deploy semantics already used for Function Apps.

### Dapr integration

Deferred. Container Apps supports Dapr sidecars for pub/sub, state, and service invocation. The current Grid uses explicit queue contracts (`HoneyDrunk.Transport`) and does not benefit from Dapr abstractions today. Reconsider when a cross-Node pub/sub pattern emerges that does not fit the existing Transport model.
