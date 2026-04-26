# Function App Creation (Azure Portal)

**Applies to:** ADR-0005, ADR-0015.
**Related invariants:** 17, 18, 19, 22, 34.

## Goal

Create a per-Node Linux consumption Function App named `func-hd-{service}-{env}` in `rg-hd-{service}-{env}` running .NET 10 isolated, with a system-assigned Managed Identity, diagnostics routed to the shared Log Analytics workspace, and the Grid bootstrap app settings (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT`, `HONEYDRUNK_NODE_ID`) seeded at create time.

## Portal Breadcrumb

**Azure Portal → Function App → + Create → Hosting / Storage / Networking / Monitoring / Deployment + Tags → Review + create**

## Step-by-step

1. Go to **Function App** and select **+ Create → Function App**.
2. On **Basics**:
   - Subscription: target `honeydrunk-{env}`.
   - Resource group: `rg-hd-{service}-{env}`.
   - Function App name: `func-hd-{service}-{env}`.
   - Hosting option: **Consumption**.
   - Runtime stack: **.NET**.
   - Version: **10 (isolated worker model)**.
   - Region: pick the same region as the Node's other resources.
   - Operating system: **Linux**.
3. Validate naming before continuing:
   - Function App name max is 60 chars; `func-hd-` uses 8, the separator between `{service}` and `{env}` uses 1. Budget allows 51 for `{service}{env}`, but Invariant 19 caps `{service}` at 13 chars regardless. Stay inside that ceiling.
4. On **Storage**:
   - Storage account: create new, name `sthd{service}{env}` (lowercase alphanumeric, ≤ 24 chars per the storage-account naming rule).
5. On **Networking**:
   - Start with **Public access enabled**. If a private-endpoint migration is planned, document it in the Node's deployment-map entry rather than wiring it here.
6. On **Monitoring**:
   - Application Insights: **Yes**.
   - Log Analytics workspace: `log-hd-shared-{env}` (Invariant 22).
7. On **Deployment**:
   - Continuous deployment: **Disable**. Deploys land via the `HoneyDrunk.Actions` reusable workflow (`job-deploy-function.yml`) over OIDC — the portal-side GitHub integration is not used.
8. Add tags `node={node-id}` and `env={env}`.
9. Select **Review + create**, then **Create**.

## Post-create hardening

1. Open the Function App → **Settings → Identity → System assigned**.
   - Switch **Status** to **On** and save. Record the principal ID.
2. Grant the system-assigned MI `Key Vault Secrets User` on the Node's vault (`kv-hd-{service}-{env}`). Follow [Key Vault RBAC assignments](key-vault-rbac-assignments.md).
3. Open **Settings → Environment variables → App settings** (formerly Configuration) and add the Grid bootstrap settings:
   - `AZURE_KEYVAULT_URI` = `https://kv-hd-{service}-{env}.vault.azure.net/`
   - `AZURE_APPCONFIG_ENDPOINT` = `https://appcs-hd-shared-{env}.azconfig.io`
   - `ASPNETCORE_ENVIRONMENT` = `Development` / `Staging` / `Production` to match `{env}`.
   - `HONEYDRUNK_NODE_ID` = the Node's catalog id (e.g. `honeydrunk-notify`).
   - Save and let the app restart.
4. Open **Monitoring → Diagnostic settings → + Add diagnostic setting**:
   - Name: `func-audit-to-loganalytics`.
   - Categories: `FunctionAppLogs` and **AllMetrics**.
   - Send to **Log Analytics workspace** = `log-hd-shared-{env}`.
5. Confirm **TLS/SSL settings → Minimum inbound TLS version** is **1.2** or higher.
6. Under **Authentication**, leave anonymous-by-default unless the Node's contract requires App Service Authentication. Token validation is owned by `HoneyDrunk.Auth` per Invariant 10.

## Verification

- `func-hd-{service}-{env}` exists in `rg-hd-{service}-{env}`.
- Identity blade shows a system-assigned MI; the principal has `Key Vault Secrets User` on `kv-hd-{service}-{env}`.
- All four bootstrap app settings are set and visible (Invariant 18). No secret values are stored as raw app settings — only the URI/endpoint pointers and identifiers.
- Diagnostic setting routes `FunctionAppLogs` to `log-hd-shared-{env}` (Invariant 22).
- Service-name segment is ≤ 13 chars (Invariant 19).

## Cross references

- [ADR-0005: Configuration and Secrets Strategy](../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [ADR-0015: Container Hosting Platform](../adrs/ADR-0015-container-hosting-platform.md)
- [Key Vault creation](key-vault-creation.md)
- [Key Vault RBAC assignments](key-vault-rbac-assignments.md)
- [OIDC federated credentials](oidc-federated-credentials.md)
- [App Configuration provisioning](app-configuration-provisioning.md)
- [Log Analytics workspace and alerts](log-analytics-workspace-and-alerts.md)
- [Grid Invariants](../constitution/invariants.md) — 17, 18, 19, 22, 34.
