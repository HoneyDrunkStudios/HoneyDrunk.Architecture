# Azure Naming Conventions

Canonical naming rules for all Azure resources in the HoneyDrunk Grid.

**Last Updated:** 2026-04-25

---

## Principles

- Every resource name encodes **what it is**, **who owns it**, and **which environment** it belongs to.
- Use the short prefix `hd` for HoneyDrunk core services. Other apps (e.g., HoneyHub) use their own prefix.
- Keep names short — many Azure resources have strict character limits (storage accounts: 24 chars, Key Vaults: 24 chars).
- Use kebab-case with hyphens where allowed. Use lowercase alphanumeric only where hyphens are forbidden (storage accounts).

---

## General Pattern

```
{resource-type}-{app-prefix}-{service}-{environment}
```

| Segment | Description | Examples |
|---------|-------------|----------|
| `resource-type` | Azure resource abbreviation (see table below) | `rg`, `kv`, `func`, `app`, `st`, `plan` |
| `app-prefix` | App-level prefix | `hd` (HoneyDrunk core), `hh` (HoneyHub) |
| `service` | Node or service short name | `notify`, `pulse`, `shared` |
| `environment` | Target environment | `dev`, `stg`, `prod` |

---

## Resource Type Prefixes

| Azure Resource | Prefix | Max Length | Allowed Characters |
|----------------|--------|-----------|-------------------|
| Resource Group | `rg` | 90 | Alphanumeric, hyphens, underscores, periods |
| Key Vault | `kv` | 24 | Alphanumeric, hyphens |
| Function App | `func` | 60 | Alphanumeric, hyphens |
| App Service | `app` | 60 | Alphanumeric, hyphens |
| App Service Plan | `plan` | 60 | Alphanumeric, hyphens |
| Storage Account | `st` | 24 | **Lowercase alphanumeric only** (no hyphens) |
| App Registration (Entra ID) | `sp` | — | Any |
| Container Registry | `acr` | 50 | **Lowercase alphanumeric only** (no hyphens) |
| Container Apps Environment | `cae` | 32 | Alphanumeric, hyphens |
| Container App | `ca` | 32 | Alphanumeric, hyphens |

---

## Naming Examples — HoneyDrunk Core (`hd`)

| Resource | Pattern | Dev Example |
|----------|---------|-------------|
| Resource Group (per-Node) | `rg-hd-{service}-{env}` | `rg-hd-notify-dev` |
| Resource Group (platform-shared) | `rg-hd-platform-{env}` | `rg-hd-platform-dev` |
| Key Vault | `kv-hd-{service}-{env}` | `kv-hd-notify-dev` |
| Function App | `func-hd-{service}-{env}` | `func-hd-notify-dev` |
| App Service | `app-hd-{service}-{env}` | `app-hd-web-dev` |
| App Service Plan | `plan-hd-{service}-{env}` | `plan-hd-web-dev` |
| Storage Account | `sthd{service}{env}` | `sthdnotifydev` |
| App Registration | `sp-hd-{service}-{env}` | `sp-hd-notify-dev` |
| Container Registry (shared) | `acrhdshared{env}` | `acrhdshareddev` |
| Container Apps Environment (shared) | `cae-hd-{env}` | `cae-hd-dev` |
| Container App | `ca-hd-{service}-{env}` | `ca-hd-notify-dev` |

**Notes:**

- The Container Registry and Container Apps Environment are **provisioned once per environment** and shared across every containerized Node (Invariant 35). Hence no `{service}` segment in the Container Registry name (`shared` substitutes for it under Azure's no-hyphen ACR constraint) and no `{service}` segment in the CAE name. Both live in `rg-hd-platform-{env}`. See ADR-0015.
- Container Apps inherit the per-Node `{service}` pattern and live in `rg-hd-{service}-{env}` alongside their Key Vault.

## Naming Examples — HoneyHub (`hh`)

| Resource | Pattern | Dev Example |
|----------|---------|-------------|
| Resource Group | `rg-hh-{service}-{env}` | `rg-hh-web-dev` |
| Key Vault | `kv-hh-{service}-{env}` | `kv-hh-web-dev` |
| Storage Account | `sthh{service}{env}` | `sthhwebdev` |

---

## Subscriptions

Subscriptions are organized by **app** and **environment**:

| Subscription | Scope |
|-------------|-------|
| `honeydrunk-dev` | All HoneyDrunk core services — development |
| `honeydrunk-stg` | All HoneyDrunk core services — staging |
| `honeydrunk-prod` | All HoneyDrunk core services — production |
| `honeyhub-dev` | HoneyHub resources — development |

Add new subscriptions as apps or environments are introduced.

## Regions

Every resource within an environment lives in the **same region** unless a stronger requirement (compliance, end-user latency) overrides it. Cross-region resources inside one environment add egress cost, latency, and feature-availability surprises.

| Environment | Region | Notes |
|-------------|--------|-------|
| `dev` | **East US 2** | Default. Broad service availability and first-wave feature rollouts. |
| `stg` | TBD — match `prod` when chosen | |
| `prod` | TBD | Pick when production rollout begins. |

---

## GitHub Environment Variable Naming

Variables set in GitHub Actions environments:

| Variable | Convention | Example |
|----------|-----------|---------|
| Function App name | `{NODE}_FUNCTION_APP_NAME` | `NOTIFY_FUNCTION_APP_NAME` |
| App Service name | `{NODE}_APP_NAME` | `WEB_APP_NAME` |
| Container App name | `{NODE}_CONTAINER_APP_NAME` | `NOTIFY_WORKER_CONTAINER_APP_NAME` |
| Resource group | `AZURE_RESOURCE_GROUP` | `rg-hd-notify-dev` |
| Key Vault name | `AZURE_KEYVAULT_NAME` | `kv-hd-notify-dev` |
| Client ID | `AZURE_CLIENT_ID` | (GUID) |
| Tenant ID | `AZURE_TENANT_ID` | (GUID) |
| Subscription ID | `AZURE_SUBSCRIPTION_ID` | (GUID) |
| ACR registry | `ACR_REGISTRY` | `acrhdshareddev.azurecr.io` |
| Container Apps Environment | `AZURE_CONTAINER_APPS_ENV` | `cae-hd-dev` |
| Key Vault secrets list | `{NODE}_KEYVAULT_SECRETS` | Newline-separated secret names |

---

## How to Update This File

- **New resource type:** Add to the Resource Type Prefixes table and provide a naming example.
- **New app prefix:** Add a Naming Examples section for the new app.
- **New environment:** Update the Subscriptions table.
- **Naming exception:** Document in a Known Exceptions section (follow the pattern in `constitution/naming-conventions.md`).
