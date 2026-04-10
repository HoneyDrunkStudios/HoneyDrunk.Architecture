---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Studios
labels: ["feature", "tier-2", "meta", "infrastructure", "adr-0005"]
dependencies: []
adrs: ["ADR-0005", "ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: honeydrunk-studios
---

# Feature: Migrate HoneyDrunk.Studios (Next.js) secrets to Key Vault references via App Service config

## Summary
Move the Studios website's production secrets (if any) into `kv-hd-studios-{env}`, surface them to the Next.js runtime via App Service application settings with Key Vault references, remove any secrets from `.env.production` / repo, and adopt OIDC-based CI deploys. Studios is not a .NET Node — it does not consume `HoneyDrunk.Vault`, so the migration shape is different from the Core-Node packets.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Studios`

## Motivation
ADR-0005 applies to every deployable Node, including the Next.js website. Studios doesn't use `ISecretStore` (not a .NET host), so the idiomatic path is Azure App Service application settings that *are* Key Vault references — the Managed Identity resolves them server-side, and the Next.js runtime reads them as plain `process.env.*`. This keeps Studios in compliance with invariants 17 and 18 without dragging .NET dependencies into the site.

## Proposed Implementation

### Provisioning (documented, follows portal walkthroughs)
- `kv-hd-studios-{env}` vault (service name `studios` = 7 chars, fits budget)
- System-assigned Managed Identity on the App Service
- `Key Vault Secrets User` on its own vault only

### Application settings (App Service → Configuration)
- For each production secret used by Next.js at runtime, create an App Setting whose value is a Key Vault reference:
  ```
  @Microsoft.KeyVault(SecretUri=https://kv-hd-studios-{env}.vault.azure.net/secrets/{SecretName}/)
  ```
- Non-secret settings (feature flags, analytics IDs that are public, etc.) stay as plain App Settings — not in App Configuration, since Studios isn't a .NET host. Document the boundary clearly.

### Repo cleanup
- Remove any secrets from `.env.production`, `.env`, or any committed config file
- Ensure `.env*.local` is gitignored (if not already)
- Audit `next.config.*` for hardcoded tokens

### CI
- GitHub Actions workflow uses the reusable `azure-oidc-deploy.yml` from `HoneyDrunk.Actions`
- No `AZURE_CLIENT_SECRET` in secrets

### Documentation
- Add `docs/deployment.md` explaining the KV-reference pattern, since the shape differs from the .NET Nodes

## Affected Packages
- None (Next.js app + CI)

## Boundary Check
- [x] Studios is a deployable Node and in-scope for ADR-0005
- [x] Idiomatic Next.js pattern respected — no forced .NET dependencies
- [x] Invariants 17 (own vault), 18 (env-driven via App Settings) honored

## Acceptance Criteria
- [ ] `kv-hd-studios-{env}` vault documented with per-env reference list
- [ ] Every runtime secret resolved via KV reference in App Service config
- [ ] Zero secrets in committed files (audit `.env*`, `next.config.*`, `vercel.json` if present)
- [ ] CI uses OIDC reusable workflow — no client secrets
- [ ] `docs/deployment.md` explains the pattern and cross-links ADR-0005
- [ ] A test deploy to staging succeeds end-to-end

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.

## Referenced ADR Decisions

**ADR-0005 (Configuration and Secrets Strategy):** Per-deployable-Node Key Vaults (`kv-hd-{service}-{env}`), `{Provider}--{Key}` secret naming, Managed Identity + Azure RBAC access, three-tier config split (Key Vault for secrets, App Configuration for non-secret config, env vars for bootstrap only), and env-var-driven discovery (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`).
- **§Bootstrap:** `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service application settings at deploy time. `AddVault(...)` reads the vault URI; `AddAppConfiguration(...)` reads the App Config endpoint. Both use `DefaultAzureCredential`. Convention-based derivation from Node name was rejected.
- **§Isolation:** Each deployable Node gets one Key Vault per environment (`kv-hd-{service}-{env}`), mirroring `rg-hd-{service}-{env}` 1:1. No shared vault. 24-char Azure limit means service names ≤ 13 chars.
- **§Access:** Runtime uses system-assigned Managed Identity with `Key Vault Secrets User` on own vault only. CI uses OIDC federated credentials with `Key Vault Secrets Officer`. Local dev uses File provider or `DefaultAzureCredential` via `az login`. Access policies and client secrets are forbidden.

## Context
- ADR-0005 §Isolation, §Bootstrap
- Invariants 17, 18
- User preference: portal over CLI — provisioning follows the architecture walkthroughs

## Dependencies
- `2026-04-09-architecture-infra-portal-walkthroughs.md` (vault creation + KV-reference walkthrough)
- `2026-04-09-actions-oidc-federated-credentials-workflow.md` (CI)

## Labels
`feature`, `tier-2`, `meta`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Make the Studios website compliant with ADR-0005 via App Service KV references.
**Target:** HoneyDrunk.Studios, branch from `main`
**Context:**
- Goal: Extend ADR-0005 to non-.NET deployable Nodes
- Feature: Configuration & secrets strategy rollout
- ADRs: ADR-0005 (Configuration and Secrets Strategy)

**Acceptance Criteria:** As listed above

**Dependencies:** Portal walkthroughs + OIDC workflow packets

**Constraints:**
- Invariant 17 — One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Own vault, not shared.
- Invariant 18 — Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. App Settings are the env-var surface here.
- Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. Never commit secrets.
- No ISecretStore / AddVault dependency on .NET libraries

**Key Files:**
- `.env*` files (audit + clean)
- `next.config.*`
- `.github/workflows/*.yml`
- `docs/deployment.md` (new)

**Contracts:** None changed.
