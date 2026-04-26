# Container App Creation (Azure Portal)

**Applies to:** ADR-0005, ADR-0015.
**Related invariants:** 17, 18, 19, 22, 34, 35, 36.

## Goal

Create a per-Node Container App named `ca-hd-{service}-{env}` in `rg-hd-{service}-{env}`, attached to the shared Container Apps Environment `cae-hd-{env}`, pulling images from the shared registry `acrhdshared{env}`. The app runs with a system-assigned Managed Identity holding `AcrPull` on the shared ACR and `Key Vault Secrets User` on its own `kv-hd-{service}-{env}`. Ingress is enabled for HTTP/gRPC as the Node's contract requires. Revision mode is **Multiple**, and the four Grid bootstrap env vars (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT`, `HONEYDRUNK_NODE_ID`) are seeded at create time.

## Prerequisites

Before this walkthrough, the following must already exist in the target environment:

- `rg-hd-{service}-{env}` and `kv-hd-{service}-{env}` ([Key Vault creation](key-vault-creation.md)).
- `cae-hd-{env}` ([Container Apps Environment creation](container-apps-environment-creation.md)).
- `acrhdshared{env}` ([Container Registry creation](container-registry-creation.md)).
- `log-hd-shared-{env}` ([Log Analytics workspace and alerts](log-analytics-workspace-and-alerts.md)).
- An OIDC federated credential for the Node's CI principal ([OIDC federated credentials](oidc-federated-credentials.md)).
- A built image pushed to `acrhdshared{env}.azurecr.io/{service}:{tag}` (or use the `mcr.microsoft.com/azuredocs/aci-helloworld:latest` placeholder during portal authoring; the first real revision arrives via CI).

## Portal Breadcrumb

**Azure Portal → Container Apps → + Create → Container App → Basics / Container / Ingress / Tags → Review + create**

## Step-by-step

1. Go to **Container Apps** and select **+ Create → Container App**.
2. On **Basics**:
   - Subscription: `honeydrunk-{env}`.
   - Resource group: `rg-hd-{service}-{env}`.
   - Container app name: `ca-hd-{service}-{env}`.
   - Region: same as `cae-hd-{env}`.
   - Container Apps Environment: select existing **`cae-hd-{env}`** (Invariant 35 — do not create a new environment here).
3. Validate naming before continuing:
   - Container App name max is 32 chars, alphanumeric and hyphens.
   - For `ca-hd-{service}-{env}`: `ca-hd-` is 6 chars and the separator between `{service}` and `{env}` is 1, so `{service}` + `{env}` must total ≤ 25. Invariant 19 caps `{service}` at 13 chars regardless — stay inside that ceiling.
4. On **Container**:
   - Use quickstart image: **No**.
   - Image source: **Azure Container Registry**.
   - Registry: `acrhdshared{env}` (Invariant 35).
   - Image: `{service}` (e.g. `notify-worker`, `pulse-collector`).
   - Image tag: pin to a specific tag for the bootstrap revision; CI will manage subsequent revisions.
   - Authentication during create: pick **Managed identity** if the system-assigned MI already exists; otherwise use **Admin credentials** for the bootstrap pull only and switch to MI immediately after create (see Post-create hardening). Admin credentials in this position are an intentional one-shot — do not leave them.
   - CPU / Memory: start at **0.25 vCPU / 0.5 GiB**. Scale up only with telemetry to back the change.
   - **Environment variables** — add now so the first revision boots with the Grid bootstrap contract (Invariant 18):
     - `AZURE_KEYVAULT_URI` = `https://kv-hd-{service}-{env}.vault.azure.net/`
     - `AZURE_APPCONFIG_ENDPOINT` = `https://appcs-hd-shared-{env}.azconfig.io`
     - `ASPNETCORE_ENVIRONMENT` = `Development` / `Staging` / `Production` to match `{env}`.
     - `HONEYDRUNK_NODE_ID` = the Node's catalog id (e.g. `honeydrunk-notify`).
5. On **Ingress**:
   - For an HTTP or gRPC service (e.g. `Pulse.Collector`): **Enabled**.
     - Ingress traffic: **Accepting traffic from anywhere** (or internal-only if the Node is downstream-only).
     - Target port: `8080`.
     - Transport: **HTTP/2** for gRPC; **Auto** for HTTP/1.1.
   - For a queue-driven worker (e.g. `Notify.Worker`): **Disabled**. Workers do not accept inbound traffic; scaling is KEDA-driven against queue depth (configured after create).
6. Tags: `node={node-id}` and `env={env}`.
7. Select **Review + create**, then **Create**.

## Post-create hardening

### 1) System-assigned Managed Identity

1. Open the new app → **Settings → Identity → System assigned**.
2. Set **Status** to **On** and save. Record the principal ID.

### 2) RBAC for image pull

1. Open `acrhdshared{env}` → **Access control (IAM) → + Add role assignment**.
2. Role: **AcrPull**.
3. Assign access to: **Managed identity** → select the Container App's system-assigned MI.
4. Scope: this registry.
5. Save.
6. Back on the Container App → **Application → Containers → Edit and deploy**, switch image **Authentication** to **Managed identity** if it was set to admin credentials during create. Save — this creates a new revision authenticated via the MI.

### 3) RBAC for Key Vault

1. Open `kv-hd-{service}-{env}` → **Access control (IAM) → + Add role assignment**.
2. Role: **Key Vault Secrets User**.
3. Assign access to: **Managed identity** → the Container App's system-assigned MI.
4. Scope: this vault only.
5. Save. (Detailed flow: [Key Vault RBAC assignments](key-vault-rbac-assignments.md).)

### 4) Revision mode and traffic management

1. Open the app → **Revisions and replicas**.
2. Confirm **Revision mode** is **Multiple** (Invariant 36). If it is **Single**, change it to **Multiple** and save — single-revision mode removes the rollback seam.
3. Confirm the bootstrap revision shows **100% traffic**. The deploy workflow will create future revisions at **0%**, probe, then shift to **100%**.

### 5) Diagnostics

Container Apps Environment-level diagnostics already flow to `log-hd-shared-{env}` (see [Container Apps Environment creation](container-apps-environment-creation.md)). On the Container App itself:

1. Open **Monitoring → Diagnostic settings → + Add diagnostic setting** (if available — the Environment-level setting covers this for most categories).
2. Confirm `ContainerAppConsoleLogs` and `ContainerAppSystemLogs` flow to `log-hd-shared-{env}` (Invariant 22).

### 6) Scale rules (workers only)

For workers (e.g. `Notify.Worker`):

1. Open **Application → Scale and replicas**.
2. **Min replicas**: `0` (scale-to-zero).
3. **Max replicas**: start at `3`; raise with telemetry.
4. Add a **Custom** rule of type `azure-servicebus` (or `azure-queue`, matching the Node's transport) targeting the queue the worker drains. Reference the queue's connection via Key Vault secret URL — do not paste the connection string.

## Verification

- `ca-hd-{service}-{env}` exists in `rg-hd-{service}-{env}` and is bound to `cae-hd-{env}` (Invariant 35).
- System-assigned MI is **On**; the principal has **AcrPull** on `acrhdshared{env}` and **Key Vault Secrets User** on `kv-hd-{service}-{env}`.
- All four bootstrap env vars are set on the latest revision (Invariant 18).
- Revision mode is **Multiple** and the active revision shows the expected traffic split (Invariant 36).
- Container logs reach `log-hd-shared-{env}` (Invariant 22).
- Service-name segment is ≤ 13 chars (Invariant 19).

## Cross references

- [ADR-0005: Configuration and Secrets Strategy](../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [ADR-0015: Container Hosting Platform](../adrs/ADR-0015-container-hosting-platform.md)
- [Key Vault creation](key-vault-creation.md)
- [Key Vault RBAC assignments](key-vault-rbac-assignments.md)
- [Container Apps Environment creation](container-apps-environment-creation.md)
- [Container Registry creation](container-registry-creation.md)
- [OIDC federated credentials](oidc-federated-credentials.md)
- [App Configuration provisioning](app-configuration-provisioning.md)
- [Log Analytics workspace and alerts](log-analytics-workspace-and-alerts.md)
- [Grid Invariants](../constitution/invariants.md) — 17, 18, 19, 22, 34, 35, 36.
