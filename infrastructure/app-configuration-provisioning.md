# App Configuration Provisioning (Azure Portal)

**Applies to:** ADR-0005, ADR-0006.  
**Related invariants:** 18, 20, 21, 22.

## Goal

Provision shared App Configuration `appcs-hd-shared-{env}` for non-secret config, per-Node label partitioning, and Key Vault references.

## Portal Breadcrumb

**Azure Portal → App Configuration → + Create → Configuration explorer / Feature manager / Access control (IAM) / Diagnostic settings**

## Step-by-step

1. Create App Configuration instance:
   - Name: `appcs-hd-shared-{env}`
   - Scope: one shared instance per environment (not per Node).
2. Open the instance and go to **Configuration explorer**.
3. Create key-values for each Node using labels matching `HONEYDRUNK_NODE_ID`.
4. Set bootstrap endpoint in app settings for consuming services:
   - `AZURE_APPCONFIG_ENDPOINT`
5. Configure **Feature manager** entries for runtime flags.
6. For secret-adjacent values, create **Key Vault references**:
   - Use “+ Create → Key Vault reference”.
   - Reference the secret URI (unversioned preferred).
   - Runtime resolution uses the consuming app's managed identity path.
7. Configure diagnostics:
   - **Diagnostic settings → + Add diagnostic setting**.
   - Route logs/metrics to `log-hd-shared-{env}`.
8. Configure RBAC on App Configuration:
   - Node managed identities: **App Configuration Data Reader**.
   - CI OIDC principals: **App Configuration Data Owner**.

## Verification

- Exactly one `appcs-hd-shared-{env}` exists per environment.
- Labels align with each Node `HONEYDRUNK_NODE_ID`.
- Feature flags visible under Feature manager.
- Key Vault references resolve in runtime for authorized Node MI.
- RBAC role checks confirm Reader for runtime, Owner for CI.
- Diagnostics route to shared Log Analytics workspace.

## Cross references

- [ADR-0005 three-tier split](../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [ADR-0006 Tier 4](../adrs/ADR-0006-secret-rotation-and-lifecycle.md)
- [Invariant 18, 20–22](../constitution/invariants.md)
