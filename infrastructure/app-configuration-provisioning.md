# App Configuration Provisioning (Azure Portal)

**Applies to:** ADR-0005, ADR-0006.  
**Related invariants:** 18, 20, 21, 22.

## Goal

Provision shared App Configuration `appcs-hd-shared-{env}` for non-secret config, per-Node label partitioning, and Key Vault references.

## Portal Breadcrumb

**Azure Portal → App Configuration → + Create → Configuration explorer / Feature manager / Access control (IAM) / Diagnostic settings**

## Step-by-step

### 1) Create the App Configuration instance

Walk the Create wizard tab-by-tab.

**Basics tab:**
- Subscription: target `honeydrunk-{env}`.
- Resource group: `rg-hd-platform-{env}`.
- Location: same region as the rest of the environment (e.g. East US 2 for `dev`).
- Resource name: `appcs-hd-shared-{env}`. Scope is one shared instance per environment — do **not** create one per Node.
- Pricing tier: see **Tier Selection** below.

**Access settings tab — important:**
- **Enable access keys**: **unchecked**. Forces every consumer to authenticate via Microsoft Entra ID + Managed Identity. Aligns with the no-shared-keys posture in ADR-0005 (Invariants 17 and 18). If access keys remain enabled, runtime code or operators may eventually fall back to them and silently bypass RBAC.
- **Azure Resource Manager Authentication Mode**: **Pass-through (Recommended)**. Requires both ARM-plane and data-plane RBAC for ARM-driven access (portal, CLI, ARM templates). The alternative ("Local") lets ARM access bypass data-plane RBAC, which would punch a hole in the MI-only model.

**Networking tab:**
- **Access options**: **Automatic** (default). Public access stays enabled while no private endpoint is attached, and auto-disables if one is added later. Don't pick **Enabled** explicitly — Automatic prevents the "added a private endpoint but forgot to disable public" footgun.
- **Private Access**: leave empty. Private endpoint provisioning is a separate decision; adding one here would block Function App / Container App access until VNet integration and private DNS are wired.
- **Azure Resource Manager Private Network Access**: leave **unchecked**.

**Encryption tab:** leave **Microsoft-managed keys** (the only option on Free/Developer; CMK is Standard+).

**Tags tab:** `env={env}` and `purpose=platform-shared`. Do not tag a single `node` — this store serves every Node.

**Review + create → Create.** Provisioning takes ~30–60 seconds.

### Tier Selection

App Configuration has **four** tiers: Free, Developer, Standard, Premium.

| Tier | Monthly base | Included quota | Overage | Storage | SLA | Soft-delete | Private Link |
|------|--------------|----------------|---------|---------|-----|-------------|--------------|
| Free | $0 | 1,000/day (hard 429 cap) | n/a | 10 MB | none | no | no |
| **Developer** | ~$3.60 | 3,000/day | $0.40 / 10K | 500 MB | none | no | yes |
| Standard | ~$36 | 200,000/day | $0.06 / 10K | 1 GB | 99.95% | yes | yes |
| Premium | ~$288 (incl. 1 replica) | 1.6M/day | $0.06 / 10K | 4 GB | 99.99% | yes | yes |

**Why Free is too tight even for solo-dev:** A Function App + a couple of Container Apps with default 30-second sentinel-key polling burn ~5,800 requests/day for change monitoring alone. Free's 1,000/day cap returns hard `HTTP 429` for the rest of the day once exceeded — every config read fails until midnight UTC.

**Why Developer is the right default for non-prod:** $3.60/month base buys 3,000 requests/day included plus cheap overage ($0.40 per 10K). Realistic dev usage lands at $4–$7/month total. Developer remains cheaper than Standard up to ~900,000 requests/month (~30K/day), well above any solo-dev workload.

**Why Standard for prod:** Soft-delete is the load-bearing prod feature — accidental delete of a configuration store with active Key Vault references would otherwise be unrecoverable. 99.95% SLA, geo-replication, and CMK are nice-to-haves on top.

**Recommendation:**

| Environment | Tier | Realistic monthly cost |
|-------------|------|------------------------|
| `dev` | **Developer** | $3.60–$7 |
| `stg` | **Developer** | $3.60–$7 |
| `prod` | **Standard** | ~$36+ |

**Upgrade path:** Free → Developer → Standard → Premium are supported in-place. **Downgrades require recreating the store**, so don't overshoot. Verify current rates on [the Azure pricing page](https://azure.microsoft.com/en-us/pricing/details/app-configuration/) before any cost-sensitive provisioning — published rates shift over time.

### 2) Populate per-Node configuration

Open the instance → **Configuration explorer**. Create key-values for each Node using labels matching `HONEYDRUNK_NODE_ID`.

- Example: key `Notify:Email:FromAddress`, value `noreply@honeydrunk.io`, label `honeydrunk-notify`.
- Example: key `Auth:Jwt:Issuer`, value `https://auth.honeydrunk.local`, label `honeydrunk-auth`.

### 3) Wire bootstrap endpoint into consuming services

Set `AZURE_APPCONFIG_ENDPOINT` as an app setting on every consuming Function App / Container App at deploy time (Invariant 18). The walkthroughs for those resources cover this.

### 4) Feature flags

Configure **Feature manager** entries for any runtime flags. Same per-Node label convention applies.

### 5) Key Vault references for secret-adjacent values

For values that point at secrets, create **Key Vault references**:

- Use **+ Create → Key Vault reference**.
- Reference the secret URI (unversioned preferred — pinning a version breaks rotation propagation per Invariant 21).
- Runtime resolution uses the consuming app's managed identity path.

### 6) Diagnostics

**Diagnostic settings → + Add diagnostic setting**. Route logs and metrics to `log-hd-shared-{env}` (Invariant 22).

### 7) RBAC

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
