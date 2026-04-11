# Key Vault Creation (Azure Portal)

**Applies to:** ADR-0005, ADR-0006.  
**Related invariants:** 17, 19, 22.

## Goal

Create a per-Node Key Vault named `kv-hd-{service}-{env}` in the matching resource group `rg-hd-{service}-{env}` with RBAC authorization, purge protection, and diagnostics routing.

## Portal Breadcrumb

**Azure Portal → Key vaults → + Create → Basics / Access configuration / Networking / Monitoring + tags → Review + create**

## Step-by-step

1. Go to **Key vaults** and select **+ Create**.
2. On **Basics**:
   - Subscription: choose target subscription.
   - Resource group: select `rg-hd-{service}-{env}`.
   - Key vault name: `kv-hd-{service}-{env}`.
3. Validate naming before moving on:
   - Azure Key Vault name max length is **24 chars**.
   - For `kv-hd-{service}-{env}`: `kv-hd-` uses 6 chars and the separator between `{service}` and `{env}` uses 1 char.
   - Budget math: `24 - 6 - 1 = 17`, so `{service}` and `{env}` must total **<= 17 chars** (that is, `{service}.Length + {env}.Length <= 17`) (Invariant 19).
   - If the combined `{service}` and `{env}` segments exceed 17 chars, stop and rename one or both tokens.
4. On **Access configuration**:
   - Permission model: **Azure role-based access control**.
   - Confirm legacy access policy mode is not selected (Invariant 17).
5. On **Networking**:
   - Start with **Public endpoint (all networks)** and firewall defaults.
   - Document this as temporary if Private Link migration is planned later.
6. On **Monitoring + tags**:
   - Add tags for `node`, `env`, and `initiative` as needed.
7. Select **Review + create**, then **Create**.

## Post-create hardening

1. Open the new vault → **Properties**.
2. Verify **Soft delete** is enabled.
3. Verify **Purge protection** is enabled.
4. Open **Diagnostic settings** → **+ Add diagnostic setting**:
   - Name: `kv-audit-to-loganalytics` (or environment naming standard).
   - Send to **Log Analytics workspace**.
   - Workspace: `log-hd-shared-{env}`.
   - Include audit/event categories needed by ADR-0006 monitoring.

## Verification

- Vault exists at `kv-hd-{service}-{env}` in `rg-hd-{service}-{env}`.
- Access configuration shows **Azure RBAC** (not access policies).
- Soft delete + purge protection are enabled.
- Diagnostic setting is active and targets `log-hd-shared-{env}` (Invariant 22).

## Cross references

- [ADR-0005](../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [ADR-0006](../adrs/ADR-0006-secret-rotation-and-lifecycle.md)
- [Invariant 17–22](../constitution/invariants.md)
