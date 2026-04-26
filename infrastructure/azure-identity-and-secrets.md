# Azure Identity & Secrets

How the HoneyDrunk Grid handles authentication, authorization, and secret management in Azure.

**Last Updated:** 2026-03-28

---

## Authentication Strategy

### GitHub Actions to Azure (OIDC)

All deployments use **OIDC federated identity** — no stored client secrets. Each service has its own App Registration in Entra ID with a federated credential that trusts GitHub Actions.

```
GitHub Actions (OIDC token)
    -> Entra ID (validates federated credential)
        -> Azure (Contributor on resource group, Key Vault Secrets Officer on vault)
```

**Why OIDC over Service Principal secrets:**
- No secrets to rotate or leak
- Scoped to a specific GitHub repo + environment combination
- Azure's recommended approach for CI/CD

### Fallback: Service Principal

If OIDC is unavailable (e.g., self-hosted runners without OIDC support), the deploy workflows fall back to `AZURE_CLIENT_SECRET`. This should be avoided in production.

---

## Identity Per Service

Each deployable service gets its own App Registration. This follows the Grid's per-service isolation principle.

| Service | App Registration | Federated Subject |
|---------|-----------------|-------------------|
| Notify.Functions | `sp-hd-notify-dev` | `repo:HoneyDrunkStudios/HoneyDrunk.Notify:environment:development` |
| Pulse.Collector | `sp-hd-pulse-dev` | `repo:HoneyDrunkStudios/HoneyDrunk.Pulse:environment:development` |

### Federated Credential Configuration

For each App Registration, create a federated credential with:

| Field | Value |
|-------|-------|
| Issuer | `https://token.actions.githubusercontent.com` |
| Subject | `repo:HoneyDrunkStudios/{repo}:environment:{environment}` |
| Audience | `api://AzureADTokenExchange` |

### RBAC Assignments

Each service's App Registration needs:

| Role | Scope | Purpose |
|------|-------|---------|
| Contributor | Resource Group (`rg-hd-{service}-{env}`) | Deploy Function Apps, App Services, manage resources |
| Key Vault Secrets Officer | Key Vault (`kv-hd-{service}-{env}`) | Read secrets at deploy time, write app settings |

---

## Key Vault Strategy

### One Vault Per Service Per Environment

Each service gets its own Key Vault in its own resource group:

```
rg-hd-notify-dev/
    kv-hd-notify-dev      <- only Notify secrets

rg-hd-pulse-dev/
    kv-hd-pulse-dev       <- only Pulse secrets
```

**Why per-service:**
- Blast radius — compromised identity only sees its own secrets
- Simple RBAC — one identity, one vault
- Independent rotation — updating Notify secrets cannot break Pulse
- Matches the Grid's node independence (Invariant #1)

All Key Vaults use **Azure RBAC** for access control (not the legacy access policies).

---

## Secret Naming

### Key Vault Secret Names

Use double-hyphen (`--`) as a section separator within Key Vault. Azure Functions and ASP.NET Core map `--` to `:` in configuration binding.

| Pattern | Example | Maps To (in app config) |
|---------|---------|------------------------|
| `{Provider}--{Key}` | `Resend--ApiKey` | `Resend:ApiKey` |
| `{Provider}--{Key}` | `Twilio--AccountSid` | `Twilio:AccountSid` |
| `{Provider}--{Key}` | `Twilio--AuthToken` | `Twilio:AuthToken` |
| `{ConnectionName}` | `NotifyQueueConnection` | `NotifyQueueConnection` |

### Rules

- PascalCase for all segments (`Resend--ApiKey`, not `resend--api-key`)
- Use `--` for hierarchy, never `/` or `.` (Key Vault doesn't allow those in secret names)
- Connection strings use a flat name without `--` (`NotifyQueueConnection`)
- Provider secrets group by provider name (`Twilio--AccountSid`, `Twilio--AuthToken`)

---

## Current Secrets by Service

### Notify.Functions (`kv-hd-notify-dev`)

| Secret Name | Purpose | Source |
|-------------|---------|--------|
| `NotifyQueueConnection` | Azure Storage Queue connection string | Storage Account (`sthdnotifydev`) |
| `Resend--ApiKey` | Resend transactional email API key | resend.com dashboard |
| `Twilio--AccountSid` | Twilio account SID | twilio.com console |
| `Twilio--AuthToken` | Twilio auth token | twilio.com console |

### Pulse.Collector (`kv-hd-pulse-dev`)

| Secret Name | Purpose | Source |
|-------------|---------|--------|
| Configurable via `COLLECTOR_KEYVAULT_SECRETS` | Per-environment | Set in GitHub environment variables |

---

## GitHub Environment Configuration

Each GitHub repo with deployable services configures **Environments** (Settings -> Environments) with these variables:

### Required Variables (per environment)

| Variable | Purpose | Example (dev) |
|----------|---------|---------------|
| `AZURE_CLIENT_ID` | App Registration client ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_TENANT_ID` | Entra ID tenant ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `AZURE_RESOURCE_GROUP` | Target resource group | `rg-hd-notify-dev` |
| `AZURE_KEYVAULT_NAME` | Key Vault name | `kv-hd-notify-dev` |

### Service-Specific Variables

| Variable | Repo | Example |
|----------|------|---------|
| `NOTIFY_FUNCTION_APP_NAME` | HoneyDrunk.Notify | `func-hd-notify-dev` |
| `NOTIFY_WORKER_CONTAINER_APP_NAME` | HoneyDrunk.Notify | `ca-hd-notify-worker-dev` |
| `COLLECTOR_CONTAINER_APP_NAME` | HoneyDrunk.Pulse | `ca-hd-pulse-dev` |
| `ACR_REGISTRY` | HoneyDrunk.Notify, HoneyDrunk.Pulse | `acrhdshareddev.azurecr.io` |
| `AZURE_CONTAINER_APPS_ENV` | HoneyDrunk.Notify, HoneyDrunk.Pulse | `cae-hd-dev` |
| `COLLECTOR_KEYVAULT_SECRETS` | HoneyDrunk.Pulse | Newline-separated secret names |

### Repository-Level Secrets (not environment-scoped)

| Secret | Repos | Purpose |
|--------|-------|---------|
| `NUGET_API_KEY` | All Node repos | NuGet.org publishing |
| `CONTAINER_REGISTRY_USERNAME` | Pulse | GHCR/ACR login |
| `CONTAINER_REGISTRY_PASSWORD` | Pulse | GHCR/ACR token |

---

## How to Update This File

- **New service:** Add its App Registration, federated credential, RBAC assignments, and Key Vault secrets.
- **New secret:** Add to the service's secrets table and update [deployment-map.md](deployment-map.md).
- **New environment:** Duplicate the federated credential with the new environment subject.
- **Auth method change:** Update the Authentication Strategy section.
