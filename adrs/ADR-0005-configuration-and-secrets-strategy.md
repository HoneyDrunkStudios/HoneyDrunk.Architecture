# ADR-0005: Configuration and Secrets Strategy

**Status:** Accepted  
**Date:** 2026-04-09  
**Deciders:** HoneyDrunk Studios  
**Sector:** Infrastructure

## Context

HoneyDrunk Studios is moving from ad-hoc local configuration to a production-grade Azure footprint. Each deployable Node gets its own resource group (`rg-hd-{service}-{env}`), and ADR-0001 already established the Node-vs-Service boundary. What has not been decided, until now, is:

- Where secrets live in Azure (one vault, many vaults, what shape)
- How secrets are named so `IOptions<T>` binding stays clean
- How runtime and CI processes authenticate to the vault
- Where non-secret configuration lives (appsettings? env vars? a dedicated store?)
- How Nodes discover the vault in the first place

Invariants 8 and 9 already pin down that secret values must never leak and that `ISecretStore` is the only source of secrets. This ADR fills in the concrete Azure strategy that sits under those invariants.

## Decision

### Isolation — per-deployable-Node, per-environment Key Vaults

Each deployable Node in Azure gets exactly one Key Vault per environment, named:

```
kv-hd-{service}-{env}
```

This mirrors `rg-hd-{service}-{env}` 1:1. Library-only Nodes (`HoneyDrunk.Kernel`, `HoneyDrunk.Vault`, `HoneyDrunk.Transport`, `HoneyDrunk.Architecture`) have no deployable runtime and therefore get no vault. There is no shared vault. If a genuinely cross-Node secret ever appears, a dedicated `kv-hd-shared-{env}` will be added deliberately — not implicitly.

**Constraint — 24-char vault name limit.** Azure caps Key Vault names at 24 characters. With the `kv-hd-` prefix (6) and `-{env}` suffix worst case `-stage` (6), `{service}` must stay at or below **13 characters**. Service naming across the Grid is bound by this ceiling.

### Secret naming — `{Provider}--{Key}` PascalCase

Secrets follow a provider-grouped convention so they bind cleanly to `IOptions<T>`:

| Kind | Example |
|---|---|
| Provider credential | `Resend--ApiKey`, `Twilio--AccountSid`, `OpenAI--ApiKey` |
| Flat connection string | `NotifyQueueConnection` |
| Node-internal secret | `JwtSigningKey`, `WebhookSigningSecret` |

The `--` separator is the Azure-safe encoding of the .NET config `:` delimiter. `Resend--ApiKey` binds to `ResendOptions.ApiKey` via standard configuration providers. `ISecretStore.GetSecretAsync("Resend--ApiKey")` uses the same logical name 1:1 — no translation layer.

### Access — Managed Identity + Azure RBAC

- **Runtime:** Every Function App / App Service runs with a system-assigned Managed Identity. That identity is granted `Key Vault Secrets User` on **its own vault only**. No cross-vault access.
- **CI / Deploy:** GitHub Actions uses OIDC federated credentials, one per `{repo, environment}` pair, granted `Key Vault Secrets Officer` on the target vault only.
- **Local dev (default):** `HoneyDrunk.Vault.Providers.File` reads a gitignored `secrets/dev-secrets.json`. This is the zero-friction path.
- **Local dev (fallback):** `DefaultAzureCredential` via `az login` for cases where a developer needs to hit the real dev vault.
- **Forbidden:** Legacy access policies. Service principal client secrets (they would themselves need rotating). All new vaults are created with `enableRbacAuthorization = true`.

### Three-tier configuration split

Configuration is split across three stores with a hard rule for placement:

> **If it would be a leak in a log, it belongs in Key Vault. Otherwise, App Configuration. Environment variables are bootstrap only.**

| Tier | Store | Contents |
|---|---|---|
| Secrets | `kv-hd-{service}-{env}` | API keys, connection strings with credentials, signing keys, certificates |
| Non-secret config | `appcs-hd-shared-{env}` (Azure App Configuration, shared) | Feature flags, timeouts, non-sensitive URLs, cache TTLs, cross-Node config. Label-per-Node partitioning. Key Vault references for secret-adjacent config. Read-only at runtime via Managed Identity. |
| Bootstrap | App Service application settings (environment variables) | `AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT`, `HONEYDRUNK_NODE_ID`. Nothing else. |

**Trade-off acknowledged.** A shared `appcs-hd-shared-{env}` slightly bends the per-service isolation model established for resource groups and vaults. This is deliberate: it is read-only from every Node's perspective (writes gated to CI via a separate role), label-partitioned per Node, and its blast radius is bounded to non-secret configuration. The win — feature flags, cross-Node config unification, and runtime toggles without redeploy — is worth the scoped exception.

### Bootstrap — env vars set at deploy time

`AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service application settings at deploy time. Neither value is a secret. From that point forward, Managed Identity handles auth and no further wiring is required.

Convention-based derivation of the vault URI from the Node name was rejected: it would couple application code permanently to the Azure naming scheme. Env-var injection keeps the binding explicit and replaceable.

`HoneyDrunkBuilderExtensions.AddVault(...)` reads `AZURE_KEYVAULT_URI`. A sibling `AddAppConfiguration(...)` extension reads `AZURE_APPCONFIG_ENDPOINT`. Both use `DefaultAzureCredential` and work identically in dev, CI, and Azure.

## Consequences

### Affected Nodes

- **HoneyDrunk.Vault** — `HoneyDrunkBuilderExtensions.AddVault` must honor `AZURE_KEYVAULT_URI`. Add `AddAppConfiguration` extension. File provider remains the local-dev default.
- **HoneyDrunk.Kernel** — No direct impact; `IGridContext` and config binding stay as-is.
- **Every deployable Node** — Gains a `kv-hd-{service}-{env}` vault per environment and a system-assigned Managed Identity. Must be updated to read bootstrap env vars, not hardcoded endpoints.
- **HoneyDrunk.Architecture** — Infrastructure docs must carry the portal walkthroughs for vault creation, RBAC assignment, App Configuration setup, and OIDC federated credential wiring.

### New Invariants

The following invariants must be added to `constitution/invariants.md`:

17. **Each deployable Node in Azure has exactly one Key Vault per environment, named `kv-hd-{service}-{env}`, with Azure RBAC enabled and no access policies.**
18. **Vault URIs and App Configuration endpoints reach Nodes via environment variables (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`) — never via convention, never hardcoded.**
19. **Service names in Azure resource naming must be ≤ 13 characters, so they fit within Azure's 24-character Key Vault name limit.**

### Operational Consequences

- Service naming across the Grid is now bound by the 13-char ceiling. Any future Node whose name exceeds it must be shortened before it reaches Azure.
- CI pipelines for every deployable Node must be updated to use OIDC federated credentials instead of client-secret service principals.
- A shared `appcs-hd-shared-{env}` App Configuration resource must be provisioned per environment, with Managed Identity access granted per Node.
- Portal walkthroughs for vault creation, RBAC, App Configuration, and OIDC wiring belong in `infrastructure/` docs, not in this ADR.
- Walkthrough index: [Infrastructure Walkthroughs](../infrastructure/README.md).

## Alternatives Considered

### Central vault (`kv-hd-central-{env}`)

Rejected. Violates per-service isolation. A breach of one Node's identity would expose every Node's secrets. Resource group isolation would be undermined by a shared secret store.

### Per-Sector vaults (e.g., `kv-hd-infra-{env}`, `kv-hd-ai-{env}`)

Rejected. Sector boundaries shift as the Grid evolves — ADR-level resource naming must not depend on classifications that may be re-drawn. Also conflicts with the existing resource group layout, which is per-Node.

### Per-Node vaults plus a shared vault from day one

Rejected for now. No current cross-Node secret exists that would justify it. Adding `kv-hd-shared-{env}` later is cheap; removing it after it has accreted secrets is not. Defer until a real case appears.

### Flat secret names (`ResendApiKey`, `TwilioAccountSid`)

Rejected. Loses the `IOptions<T>` provider-grouped binding pattern. Every options class would need custom binding logic.

### `hd-{node}-{env}-{purpose}` secret names

Rejected. The vault itself already encodes Node and environment via its name. Repeating that information inside every secret key is noise that also burns Azure's 127-char secret name budget.

### Service principal with client secret

Rejected. The client secret itself becomes a secret that needs rotating, creating a recursive problem. Managed Identity removes the credential entirely.

### Access policies

Rejected. Azure is actively moving away from access policies toward RBAC. New vaults should be RBAC-only from day one.

### appsettings.json only, no App Configuration

Rejected. The user explicitly wants enterprise-grade configuration: feature flags without redeploy, runtime toggles, cross-Node config unification. appsettings alone cannot deliver this. The scoped exception to per-service isolation is the worthwhile price.

### Convention-based vault URI derivation

Rejected. Deriving `kv-hd-{HONEYDRUNK_NODE_ID}-{ASPNETCORE_ENVIRONMENT}.vault.azure.net` from code would couple application binaries to Azure's naming scheme forever. Env-var injection keeps the boundary explicit and swappable.
