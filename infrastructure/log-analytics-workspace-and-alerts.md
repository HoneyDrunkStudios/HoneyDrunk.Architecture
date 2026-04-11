# Log Analytics Workspace and Alerting (Azure Portal)

**Applies to:** ADR-0006 Tier 4.  
**Related invariants:** 20, 22.

## Goal

Provision `log-hd-shared-{env}` and configure alerts for rotation SLA and security anomalies.

## Portal Breadcrumb

**Azure Portal → Log Analytics workspaces → + Create → Azure Monitor → Alerts → + Create**

## Step-by-step

### 1) Create shared workspace

1. Go to **Log Analytics workspaces** → **+ Create**.
2. Name: `log-hd-shared-{env}`.
3. Pick environment-appropriate resource group and region.
4. Create workspace.

### 2) Ensure Key Vault diagnostics feed workspace

1. For each `kv-hd-{service}-{env}` vault, open **Diagnostic settings**.
2. Confirm diagnostic setting routes to `log-hd-shared-{env}`.
3. If missing, add it (see [Key Vault creation walkthrough](key-vault-creation.md)).

### 3) Create alert rules

In **Azure Monitor → Alerts → + Create → Alert rule**, create rules for:

1. **Secret approaching expiry** (Tier SLA threshold windows).
2. **Rotation policy failure** (rotation jobs/errors).
3. **Unauthorized access attempt** (failed/forbidden secret access).
4. **Secret accessed by unexpected identity** (principal drift from expected MI).

For each rule:
- Set action group target.
- Set severity.
- Set evaluation frequency/window.
- Document suppression/exception process when needed.

Example starter queries (adapt table names to your diagnostic schema):

- Secret approaching expiry:
  ```kusto
  AzureDiagnostics
  | where ResourceType == "VAULTS" and OperationName has "SecretNearExpiry"
  | summarize count() by Resource, bin(TimeGenerated, 1h)
  ```
- Unauthorized access attempt:
  ```kusto
  AzureDiagnostics
  | where ResourceType == "VAULTS" and ResultType in ("Forbidden", "Unauthorized")
  | summarize attempts = count() by identity_claim_appid_g, Resource, bin(TimeGenerated, 15m)
  ```

### 4) Dashboard

1. Create or import Azure Monitor workbook/dashboard for **secret age vs SLA**.
2. Pin workspace-backed visuals for Tier-1 (<=30d) and Tier-2 (<=90d) coverage.

## Verification

- `log-hd-shared-{env}` exists and receives Key Vault diagnostics.
- All four alert classes are enabled and action-group routed.
- Dashboard/workbook shows secret-age vs SLA for current environment.
- Exception handling path is documented for SLA breaches (Invariant 20).

## Cross references

- [ADR-0006 Tier 4 and SLA model](../adrs/ADR-0006-secret-rotation-and-lifecycle.md)
- [Invariant 20 and 22](../constitution/invariants.md)
