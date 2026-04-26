# Azure Container Registry Creation (Azure Portal)

**Applies to:** ADR-0015.
**Related invariants:** 22, 35.

> [!IMPORTANT]
> **Provision once per environment.** A single shared Azure Container Registry serves every containerized Node within an environment. Per-Node registries are forbidden without a follow-up ADR (Invariant 35).

## Goal

Create the shared Azure Container Registry `acrhdshared{env}` (Basic SKU) in the platform resource group `rg-hd-platform-{env}`, with admin user disabled, diagnostics routed to the shared Log Analytics workspace, and ready to receive image pushes from CI and pulls from every Container App in the environment.

## Portal Breadcrumb

**Azure Portal → Container registries → + Create → Basics / Networking / Encryption / Tags → Review + create**

## Step-by-step

1. Confirm the platform resource group exists:
   - **Resource groups → rg-hd-platform-{env}**. Create it (same region as the rest of the environment) if missing. See [Container Apps Environment creation](container-apps-environment-creation.md) for the reasoning behind the shared platform RG.
2. Go to **Container registries** and select **+ Create**.
3. On **Basics**:
   - Subscription: target `honeydrunk-{env}`.
   - Resource group: `rg-hd-platform-{env}`.
   - Registry name: `acrhdshared{env}` (alphanumeric only, 5–50 chars, globally unique).
   - Location: same region as the rest of the environment.
   - **Domain name label scope**: **Unsecure**. The other modes (Tenant Reuse / Subscription Reuse / Resource Group Reuse) append a hash to the login server (e.g. `acrhdshareddev-h6c4hbgehkguffe.azurecr.io`) to prevent post-deletion domain squatting. The Grid documents the plain `acrhdshareddev.azurecr.io` form across naming conventions, packets, and workflows; switching to a Secure mode would force renaming all of those for a threat that does not apply to a registry we do not plan to delete.
   - **Use availability zones**: leave **unchecked**. Greyed out on Basic anyway — the feature is Premium-only.
   - Pricing plan: **Basic**.
   - **Role assignment permissions mode**: **RBAC Registry Permissions**. The alternative ("RBAC Registry + ABAC Repository Permissions") allows scoping `AcrPull` / `AcrPush` to specific repositories within the registry. With one shared registry, every image authored in-house, and no cross-tenant trust boundary, ABAC adds setup complexity to every per-Container-App role assignment for no real security gain — a compromised Node MI extracts no additional value from pulling a sibling Node's image. Revisit if the registry ever hosts customer-supplied or otherwise untrusted images.
4. Validate naming before continuing:
   - ACR names are alphanumeric only (no hyphens), 5–50 chars, globally unique.
   - `acrhdshared{env}` evaluates to e.g. `acrhdshareddev` (14 chars) — comfortably inside the limit.
5. On **Networking**:
   - Connectivity method: **Public access — All networks**. Container Apps pull over the public endpoint by default; private-link migration is a separate decision tracked outside this packet.
6. On **Encryption**:
   - Customer-managed keys: **Disabled** (Basic SKU does not support CMK; do not upgrade just for that without a follow-up ADR).
7. Add tags `env={env}` and `purpose=platform-shared` (do not tag a single `node` — this registry serves every containerized Node).
8. Select **Review + create**, then **Create**.

## Post-create hardening

1. Open the registry → **Settings → Access keys**.
   - Confirm **Admin user** is **Disabled**. Enable it only as a deliberate break-glass step and disable it again immediately afterward; record the incident.
2. Open **Monitoring → Diagnostic settings → + Add diagnostic setting**:
   - Name: `acr-audit-to-loganalytics`.
   - Categories: `ContainerRegistryLoginEvents`, `ContainerRegistryRepositoryEvents`, and **AllMetrics**.
   - Send to **Log Analytics workspace** = `log-hd-shared-{env}` (Invariant 22).
3. Open **Services → Repositories**. Empty at create time — images appear as Nodes push their first builds.
4. Plan RBAC. Assignments are made on a per-consumer basis when each Container App is created — this registry receives:
   - `AcrPull` for every Container App's system-assigned Managed Identity (see [Container App creation](container-app-creation.md)).
   - `AcrPush` for every GitHub Actions OIDC principal that publishes images (see [OIDC federated credentials](oidc-federated-credentials.md) — extend the existing federated credentials with the new role on this registry).

## Verification

- `acrhdshared{env}` exists in `rg-hd-platform-{env}` with SKU **Basic**.
- **Admin user** is **Disabled**.
- Diagnostic setting routes login + repository events to `log-hd-shared-{env}` (Invariant 22).
- No per-Node ACR exists in any other resource group for this environment (Invariant 35).
- Registry name passes ACR's 5–50 alphanumeric constraint.

## Cross references

- [ADR-0015: Container Hosting Platform](../adrs/ADR-0015-container-hosting-platform.md)
- [Container Apps Environment creation](container-apps-environment-creation.md)
- [Container App creation](container-app-creation.md)
- [OIDC federated credentials](oidc-federated-credentials.md)
- [Log Analytics workspace and alerts](log-analytics-workspace-and-alerts.md)
- [Grid Invariants](../constitution/invariants.md) — 22, 35.
