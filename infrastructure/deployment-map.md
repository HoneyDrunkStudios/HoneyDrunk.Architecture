# Deployment Map

Where everything in the Grid lives, how it gets there, and what secrets it needs.

**Last Updated:** 2026-03-22

---

## Node Packages (Libraries)

All Node libraries publish to **NuGet.org** via `NUGET_API_KEY`.

| Node | Packages | Signal |
|------|----------|--------|
| Kernel | `HoneyDrunk.Kernel`, `HoneyDrunk.Kernel.Abstractions` | Live |
| Transport | `HoneyDrunk.Transport`, `HoneyDrunk.Transport.AzureServiceBus`, `HoneyDrunk.Transport.StorageQueue`, `HoneyDrunk.Transport.InMemory` | Live |
| Vault | `HoneyDrunk.Vault`, `HoneyDrunk.Vault.Providers.*` | Live |
| Auth | `HoneyDrunk.Auth`, `HoneyDrunk.Auth.Abstractions`, `HoneyDrunk.Auth.AspNetCore` | Live |
| Web.Rest | `HoneyDrunk.Web.Rest`, `HoneyDrunk.Web.Rest.Abstractions`, `HoneyDrunk.Web.Rest.AspNetCore` | Live |
| Data | `HoneyDrunk.Data` | Live |
| Pulse | `HoneyDrunk.Pulse.Contracts` | Seed |
| Notify | `HoneyDrunk.Notify`, `HoneyDrunk.Notify.Abstractions` | Seed |

CI trigger: tag push (`v*`) → build → test → pack → publish.

---

## Deployable Services

These are the running processes. See `catalogs/services.json` for the canonical list.

### Pulse.Collector

| Attribute | Value |
|-----------|-------|
| Runtime | .NET 10.0 (dotnet-isolated) |
| Hosting | Azure App Service (container) |
| Container Registry | GHCR (`ghcr.io/honeydrunkstudios/pulse-collector`) — overrideable to ACR via `vars.ACR_REGISTRY` |
| Dockerfile | `Pulse.Collector/Dockerfile` |
| Ports | 8080, 8081 |
| Deployment Pattern | Build image → push to registry → deploy to staging slot → health check (`/healthz`) → swap to production |
| Gated | `vars.DEPLOY_COLLECTOR == 'true'` |

### Notify.Functions

| Attribute | Value |
|-----------|-------|
| Runtime | .NET 10.0 (dotnet-isolated) |
| Hosting | Azure Functions |
| Environments | `development`, `staging`, `production` |
| Deployment Pattern | Build → deploy to Function App → inject Key Vault secrets |
| Queue Config | Polling 5ms, batch size 16, max dequeue 10, visibility timeout 2min |
| Local Dev | Azure Storage Emulator (`UseDevelopmentStorage=true`) |

### Notify.Worker

| Attribute | Value |
|-----------|-------|
| Runtime | .NET 10.0 |
| Hosting | Container (Docker) |
| Status | Active |

### Studios Website

| Attribute | Value |
|-----------|-------|
| Runtime | Next.js 16 |
| Hosting | Vercel |
| Deployment | Auto-deploy via Vercel Git integration (no GitHub Actions) |
| Build | `npm run build` → `.next` output |
| Security Headers | `X-Content-Type-Options`, `X-Frame-Options`, `X-XSS-Protection` |

---

## Reusable Deploy Workflows (HoneyDrunk.Actions)

Consumer repos call these instead of writing their own deploy logic.

| Workflow | Purpose | Key Inputs |
|----------|---------|------------|
| `release.yml` | NuGet publish + optional container build | `project-path`, `enable-nuget-publish`, `enable-container-build`, `container-image-name` |
| `job-deploy-function.yml` | Azure Functions deployment | `functions-app`, `resource-group`, optional slot + health check + Key Vault |
| `job-deploy-container.yml` | Container → Azure App Service | `container-image`, `acr-registry`, `app-name`, `resource-group`, optional slot swap + health check |

All deploy workflows support staging slot → swap pattern with configurable health checks.

---

## Environments

| Environment | Purpose | Config Source |
|-------------|---------|---------------|
| `development` | Local and dev cloud resources | `local.settings.json`, Azure Storage Emulator |
| `staging` | Pre-production validation | Azure App Service staging slots, Key Vault |
| `production` | Live | App Service production slots, Key Vault |

Environment-specific configuration is managed through GitHub Actions environment variables and Azure Key Vault at deploy time — not checked into source.

---

## Secrets and Authentication

### Azure Authentication

OIDC (preferred) or Service Principal:

| Variable | Scope | Purpose |
|----------|-------|---------|
| `vars.AZURE_CLIENT_ID` | Notify, Pulse | Azure OIDC / SP identity |
| `vars.AZURE_TENANT_ID` | Notify, Pulse | Azure AD tenant |
| `vars.AZURE_SUBSCRIPTION_ID` | Notify | Azure subscription |
| `secrets.AZURE_CLIENT_SECRET` | Pulse (fallback) | SP secret when OIDC unavailable |

### Container Registry

| Secret | Purpose |
|--------|---------|
| `secrets.CONTAINER_REGISTRY_USERNAME` | GHCR or ACR login |
| `secrets.CONTAINER_REGISTRY_PASSWORD` | GHCR or ACR token |

### NuGet Publishing

| Secret | Purpose |
|--------|---------|
| `secrets.NUGET_API_KEY` | Push packages to NuGet.org |

### Runtime Secrets (Key Vault)

Injected at deploy time, never in source:

| Key Vault Secret | Service | Maps To |
|------------------|---------|---------|
| `NotifyQueueConnection` | Notify.Functions | Queue connection string |
| `Resend--ApiKey` | Notify.Functions | `RESEND_API_KEY` |
| `Twilio--AccountSid` | Notify.Functions | `TWILIO_ACCOUNT_SID` |
| `Twilio--AuthToken` | Notify.Functions | `TWILIO_AUTH_TOKEN` |
| `vars.COLLECTOR_KEYVAULT_SECRETS` | Pulse.Collector | Configurable per environment |

---

## How to Update This File

- **New service added:** Add a section under Deployable Services and update `catalogs/services.json`.
- **New secret required:** Add to the Secrets table and document the Key Vault key name.
- **New environment:** Add to the Environments table.
- **Deployment pattern changed:** Update the relevant service section and check if `HoneyDrunk.Actions` workflows need changes.
