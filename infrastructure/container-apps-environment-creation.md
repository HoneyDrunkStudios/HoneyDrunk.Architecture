# Container Apps Environment Creation (Azure Portal)

**Applies to:** ADR-0015.
**Related invariants:** 22, 35.

> [!IMPORTANT]
> **Provision once per environment.** A single shared Container Apps Environment hosts every containerized Node within an environment. Per-Node environments are forbidden without a follow-up ADR (Invariant 35).

## Goal

Create the shared Container Apps Environment `cae-hd-{env}` in the platform resource group `rg-hd-platform-{env}` with the Consumption-only workload profile and diagnostics routed to the shared Log Analytics workspace `log-hd-shared-{env}`.

> [!IMPORTANT]
> **The Azure portal does not expose a standalone Create flow for Container Apps Environments.** The **Container Apps Environments** list blade is view-only — there is no "+ Create" button. The Marketplace does not surface a "Container Apps Environment" tile, and the global-search Services result for "Container Apps Environments" routes to the same view-only list.
>
> **The portal's intended path is to create the environment inline as part of creating the first Container App in that environment.** Provision it together with the first per-Node Container App (e.g. `ca-hd-notify-worker-{env}`) using the **Create new environment** side panel on the Container App Create form. This walkthrough's settings populate that side panel — not a standalone form.
>
> If you need the environment to exist *before* any Container App (e.g. to validate logs flow), the only portal-aligned workaround is a throwaway Container App that you delete after the environment provisions. The Azure CLI alternative is `az containerapp env create` from Cloud Shell. Both are documented at the bottom of this walkthrough as fallbacks; the default path is inline-with-first-Container-App.

## Portal Breadcrumb

**Azure Portal → Container Apps → + Create → Container App → Basics → Container Apps environment → Create new → (side panel: Basics / Workload profiles / Monitoring / Networking)**

## Step-by-step

### 1) Ensure the platform resource group exists

The Container Apps Environment and the shared Container Registry are platform-level resources — they do not belong to any single Node. They live together in a shared platform resource group:

```
rg-hd-platform-{env}
```

This is a deliberate choice over reusing an existing per-Node RG (e.g. `rg-hd-notify-dev`):

- Lifecycles diverge — a Node RG can be torn down for a rebuild, but the platform RG must persist.
- Access boundaries diverge — every containerized Node's CI principal needs `AcrPush` and the Environment's link, none should require write access on a sibling Node's RG.
- Cost ownership is clearer — `rg-hd-platform-{env}` carries the shared ACR + CAE bill, separately from per-Node spend.

To create it: **Resource groups → + Create → Subscription = `honeydrunk-{env}` → Resource group = `rg-hd-platform-{env}` → Region = same as the rest of the environment**. Skip if it already exists.

### 2) Create the Container Apps Environment (inline with first Container App)

The standard portal path: when you create the first containerized Node's Container App (e.g. `ca-hd-notify-worker-{env}`), use the **Create new environment** side panel on the Container App Create form. The fields below populate that side panel.

1. Open the Container App Create form: top-bar global search → **Container Apps** (singular) → **+ Create → Container App**.
2. On the parent Container App **Basics** tab, set Region to match the rest of the environment (e.g. East US 2 for `dev`). The side panel inherits this region.
3. Find **Container Apps environment** below the Region field. Click **Create new**.
4. The side panel opens with four tabs: **Basics**, **Workload profiles**, **Monitoring**, **Networking**.

**Side panel — Basics:**
- Environment name: `cae-hd-{env}`.
- Zone redundancy: **Disabled** (zone redundancy requires VNet integration; not in scope for `dev`/`stg`).

**Side panel — Workload profiles:**
- Plan type: **Consumption only**. Do not add dedicated workload profiles — the Grid's deployables are bursty and run inside the free Consumption grant. Adding a dedicated profile is a separate cost decision and would require a follow-up ADR.

**Side panel — Monitoring:**
- **Logs destination**: **Azure Log Analytics**.
- **Log Analytics workspace**: `log-hd-shared-{env}` (Invariant 22).
- Application Insights instrumentation key: leave unset; Nodes that need Application Insights wire it themselves through ADR-0005 config.

**Side panel — Networking:**
- **Public Network Access**: **Enable**. The environment must be reachable from the public internet for Container App ingress; ingress can still be restricted per-app later.
- **Use your own virtual network**: **No**. Bringing your own VNet changes the egress and Private-Link surface and would require a follow-up ADR.
- **Enable private endpoints**: greyed out (requires public access disabled). Skip.

**Naming validation:** `cae-hd-{env}` evaluates to e.g. `cae-hd-dev` (10 chars). Container Apps Environment names allow up to 32 chars, alphanumeric and hyphens. Comfortably inside the limit.

Click **Create** at the bottom of the side panel. The side panel closes; the parent Container App form's Container Apps environment dropdown now shows `cae-hd-{env}` (status "Provisioning..." for ~3–5 minutes).

**The environment provisions only when the parent Container App's Review + create succeeds.** Closing the parent Container App form before submitting it discards the queued environment creation. Continue completing the Container App fields per [Container App creation](container-app-creation.md), then click **Review + create** on the parent form.

After the deployment completes, the environment exists as an independent resource and persists if the Container App is later deleted.

> [!NOTE]
> **Tags on the environment** can't be set from the side panel. Apply `env={env}` and `purpose=platform-shared` tags after creation: navigate to the Environment → **Tags → Add → Apply**. Do not tag a single `node` — this environment hosts every containerized Node.

### Fallbacks for standalone environment creation

If you genuinely need the environment before the first real Container App (e.g. to validate logs flow with a placeholder), there are two workarounds:

**A. Throwaway Container App** — complete the Container App Create form with throwaway values:
- Container app name: `ca-temp-bootstrap`
- Image: `mcr.microsoft.com/azuredocs/aci-helloworld:latest`
- Ingress: Disabled
- Min replicas: 0; Max replicas: 1

After Review + create succeeds, delete `ca-temp-bootstrap` from the resource group. The environment remains.

**B. Azure CLI from Cloud Shell** — open the `>_` Cloud Shell from the portal toolbar and run:

```bash
az containerapp env create \
  --name cae-hd-{env} \
  --resource-group rg-hd-platform-{env} \
  --location {region} \
  --logs-destination log-analytics \
  --logs-workspace-id $(az monitor log-analytics workspace show \
    --resource-group rg-hd-platform-{env} \
    --workspace-name log-hd-shared-{env} \
    --query customerId -o tsv) \
  --logs-workspace-key $(az monitor log-analytics workspace get-shared-keys \
    --resource-group rg-hd-platform-{env} \
    --workspace-name log-hd-shared-{env} \
    --query primarySharedKey -o tsv)
```

Provisioning takes ~3 minutes. Then verify in the **Container Apps Environments** list and apply tags via the portal.

The fallbacks exist because the portal does not currently expose a standalone Create flow. Both paths produce the same managedEnvironments resource.

## Post-create hardening

1. Open the Environment → **Settings → Logs**.
   - Confirm `log-hd-shared-{env}` is the configured workspace and **Log destination** is `azure-monitor`.
2. Open **Settings → Workload profiles**.
   - Confirm only **Consumption** is listed.
3. Open **Settings → Custom domains / Certificates**.
   - Empty at create time. Domain bindings happen per Container App, not at the Environment.
4. Verify the Environment's default domain shows up under **Overview → Domain**. This becomes the suffix for every Container App FQDN inside the environment (e.g. `<app>.<random>.<region>.azurecontainerapps.io`).

## Verification

- `cae-hd-{env}` exists in `rg-hd-platform-{env}`.
- Workload profile list contains only **Consumption**.
- Logs route to `log-hd-shared-{env}` (Invariant 22).
- No second Container Apps Environment exists in the environment for any Node (Invariant 35).
- Environment name passes the 32-char alphanumeric/hyphen limit.

## Cross references

- [ADR-0015: Container Hosting Platform](../adrs/ADR-0015-container-hosting-platform.md)
- [Container Registry creation](container-registry-creation.md)
- [Container App creation](container-app-creation.md)
- [Log Analytics workspace and alerts](log-analytics-workspace-and-alerts.md)
- [Grid Invariants](../constitution/invariants.md) — 22, 35.
