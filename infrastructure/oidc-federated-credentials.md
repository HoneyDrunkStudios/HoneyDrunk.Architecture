# OIDC Federated Credentials for GitHub Actions (Azure Portal)

**Applies to:** ADR-0005.  
**Related invariants:** 17, 18.

## Goal

Create Azure AD federated credentials for GitHub Actions so CI can access Azure resources without client secrets.

## Portal Breadcrumb

**Azure Portal → Microsoft Entra ID → App registrations → {app} → Federated credentials → + Add credential**

## Step-by-step

1. Open or create the App Registration used by the target repo pipeline.
2. Go to **Federated credentials** and choose **+ Add credential**.
3. Scenario: **GitHub Actions deploying Azure resources** preset.
4. Configure one credential per `{repo, environment}` pair:
   - Organization: `HoneyDrunkStudios`
   - Repository: `{RepoName}`
   - Environment: `{env}`
5. Subject should resolve to:
   - `repo:HoneyDrunkStudios/{RepoName}:environment:{env}`
6. Save credential.
7. Repeat for each Node/environment pair.

## Critical guardrails

- Do **not** create a client secret for this flow.
- OIDC trust + federated credential replaces client-secret auth.

## Wire identifiers into GitHub environment variables

In GitHub repo → **Settings → Environments → {env} → Variables**:

- Add `AZURE_CLIENT_ID` (App registration client ID)
- Add `AZURE_TENANT_ID` (Tenant ID)
- Add `AZURE_SUBSCRIPTION_ID` (Subscription ID)

These are non-sensitive identifiers and must be stored as **environment variables**, not secrets. Reserve **environment secrets** for sensitive material (e.g., `NUGET_API_KEY`, registry credentials).

## Verification

- Federated credential exists for each intended `{repo, environment}`.
- Subject string matches `repo:HoneyDrunkStudios/{RepoName}:environment:{env}`.
- Pipeline login step succeeds via OIDC without client-secret material.

## Cross references

- [ADR-0005 Operational Consequences](../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [Invariant 17–19](../constitution/invariants.md)
