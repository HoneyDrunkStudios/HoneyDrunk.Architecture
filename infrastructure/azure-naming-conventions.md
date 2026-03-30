# Azure Naming Conventions

Canonical naming rules for all Azure resources in the HoneyDrunk Grid.

**Last Updated:** 2026-03-28

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
| Container Registry | `cr` | 50 | **Lowercase alphanumeric only** (no hyphens) |

---

## Naming Examples — HoneyDrunk Core (`hd`)

| Resource | Pattern | Dev Example |
|----------|---------|-------------|
| Resource Group | `rg-hd-{service}-{env}` | `rg-hd-notify-dev` |
| Key Vault | `kv-hd-{service}-{env}` | `kv-hd-notify-dev` |
| Function App | `func-hd-{service}-{env}` | `func-hd-notify-dev` |
| App Service | `app-hd-{service}-{env}` | `app-hd-pulse-dev` |
| App Service Plan | `plan-hd-{service}-{env}` | `plan-hd-pulse-dev` |
| Storage Account | `sthd{service}{env}` | `sthdnotifydev` |
| App Registration | `sp-hd-{service}-{env}` | `sp-hd-notify-dev` |

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

---

## GitHub Environment Variable Naming

Variables set in GitHub Actions environments:

| Variable | Convention | Example |
|----------|-----------|---------|
| Function App name | `{NODE}_FUNCTION_APP_NAME` | `NOTIFY_FUNCTION_APP_NAME` |
| App Service name | `{NODE}_APP_NAME` | `COLLECTOR_APP_NAME` |
| Resource group | `AZURE_RESOURCE_GROUP` | `rg-hd-notify-dev` |
| Key Vault name | `AZURE_KEYVAULT_NAME` | `kv-hd-notify-dev` |
| Client ID | `AZURE_CLIENT_ID` | (GUID) |
| Tenant ID | `AZURE_TENANT_ID` | (GUID) |
| Subscription ID | `AZURE_SUBSCRIPTION_ID` | (GUID) |
| ACR registry | `ACR_REGISTRY` | `crhddev.azurecr.io` |
| Key Vault secrets list | `{NODE}_KEYVAULT_SECRETS` | Newline-separated secret names |

---

## How to Update This File

- **New resource type:** Add to the Resource Type Prefixes table and provide a naming example.
- **New app prefix:** Add a Naming Examples section for the new app.
- **New environment:** Update the Subscriptions table.
- **Naming exception:** Document in a Known Exceptions section (follow the pattern in `constitution/naming-conventions.md`).
