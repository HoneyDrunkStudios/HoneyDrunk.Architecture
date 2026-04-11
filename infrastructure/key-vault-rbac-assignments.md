# Key Vault RBAC Assignments (Azure Portal)

**Applies to:** ADR-0005, ADR-0006.  
**Related invariants:** 17, 20, 21, 22.

> [!WARNING]
> **Legacy Key Vault access policies are forbidden.** Use Azure RBAC only. Do not add or retain access policies for new rollout work.

## Goal

Assign least-privilege Key Vault roles for runtime, CI, and rotation workflows.

## Portal Breadcrumb

**Azure Portal → Key vaults → kv-hd-{service}-{env} → Access control (IAM) → Add role assignment / Check access**

## Step-by-step

### 1) Runtime access (Node managed identity)

1. Open vault `kv-hd-{service}-{env}`.
2. Go to **Access control (IAM)** → **Add role assignment**.
3. Role: **Key Vault Secrets User**.
4. Assign access to: **Managed identity**.
5. Select the Node's **system-assigned managed identity**.
6. Scope remains this vault only.
7. Save.

### 2) CI access (GitHub Actions OIDC identity)

1. In same vault IAM, add role assignment.
2. Role: **Key Vault Secrets Officer**.
3. Assign access to: **User, group, or service principal**.
4. Pick the App Registration/service principal tied to the repo/environment OIDC federated credential.
5. Keep scope at this vault only.
6. Save.

### 3) Rotation access (HoneyDrunk.Vault.Rotation MI)

1. For each target vault that receives rotated third-party secrets, open **Access control (IAM)**.
2. Add role assignment:
   - Role: **Key Vault Secrets Officer**.
   - Principal: **HoneyDrunk.Vault.Rotation** system-assigned managed identity.
   - Scope: current target vault.
3. Repeat for each deployable target vault.

## Verification (required)

For each principal, run **Access control (IAM) → Check access**:

- Node MI resolves to **Key Vault Secrets User**.
- CI OIDC principal resolves to **Key Vault Secrets Officer**.
- Vault.Rotation MI resolves to **Key Vault Secrets Officer** on each target vault.
- No legacy access policies are present.

## Cross references

- [ADR-0005 Access model](../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [ADR-0006 Tier 2 + Tier 4](../adrs/ADR-0006-secret-rotation-and-lifecycle.md)
- [Invariant 17–22](../constitution/invariants.md)
