---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0015"]
dependencies: ["architecture-container-apps-walkthroughs"]
adrs: ["ADR-0015", "ADR-0005", "ADR-0012"]
wave: 2
initiative: adr-0015-container-apps-rollout
node: honeydrunk-notify
---

# Feature: Release workflow and Azure bring-up for `Notify.Functions`

## Summary
Add a release workflow that publishes `HoneyDrunk.Notify.Functions` and deploys it to an Azure Function App (`func-hd-notify-{env}`) via the reusable `job-deploy-function.yml`. Provision the supporting Azure resources (resource group, Function App, Key Vault access, OIDC federated credential).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Notify`

## Motivation
`Notify.Functions` is the Grid's first Function App deployable. Its code already exists; what's missing is the CI surface that actually deploys it and the Azure resources it runs on. This packet closes that gap.

The release workflow must reuse `HoneyDrunk.Actions` `job-deploy-function.yml` verbatim — no bespoke deploy logic in the Notify repo (ADR-0012, Invariant on reusable workflows).

## Proposed Implementation

### `.github/workflows/release-functions.yml` (new)

Triggered on tag push `functions-v*`. Two jobs:

1. **build** — `dotnet publish src/HoneyDrunk.Notify.Functions/HoneyDrunk.Notify.Functions.csproj -c Release -o ./publish`, upload as artifact `notify-functions`.
2. **deploy** — `uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-function.yml@main` with:
   - `functions-app: func-hd-notify-${{ vars.HD_ENV }}`
   - `resource-group: rg-hd-notify-${{ vars.HD_ENV }}`
   - `artifact-name: notify-functions`
   - `keyvault-name: kv-hd-notify-${{ vars.HD_ENV }}`
   - `keyvault-secrets` covering `Resend--ApiKey`, `Twilio--AccountSid`, `Twilio--AuthToken`, `Smtp--Username`, `Smtp--Password`, `NotifyQueueConnection`
   - `health-check-url: /api/health`
   - Secrets: `azure-client-id`, `azure-tenant-id`, `azure-subscription-id` from repo vars.

Environment strategy: start with `dev` only. Staging / prod gates are a follow-up.

### Azure resource bring-up (Human Prerequisites)

Create the following in the Azure portal before the first release run:

- `rg-hd-notify-dev` resource group (if not already present from the ADR-0005 rollout — check first).
- `kv-hd-notify-dev` Key Vault, seeded with the six secrets listed above. Walkthrough: `infrastructure/key-vault-creation.md`.
- `func-hd-notify-dev` Function App — Linux Consumption, .NET 10 Isolated, system-assigned MI, bootstrap app settings (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT=Development`, `HONEYDRUNK_NODE_ID=honeydrunk-notify`). Walkthrough: `infrastructure/function-app-creation.md` (from packet 01).
- RBAC: `func-hd-notify-dev` MI → `Key Vault Secrets User` on `kv-hd-notify-dev`. Walkthrough: `infrastructure/key-vault-rbac-assignments.md`.
- OIDC federated credential on the Azure AD app registration used by `HoneyDrunk.Notify` CI. Subject: `repo:HoneyDrunkStudios/HoneyDrunk.Notify:environment:dev` (or `:ref:refs/tags/functions-v*` depending on workflow trigger). Grant `Contributor` on `rg-hd-notify-dev`. Walkthrough: `infrastructure/oidc-federated-credentials.md`.
- GitHub Actions environment `dev` on the `HoneyDrunk.Notify` repo, with `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `HD_ENV=dev` as environment variables (not secrets — these are not sensitive).

### `CHANGELOG.md`
Add a changelog entry under Unreleased for "Add release workflow for Notify.Functions."

## Affected Files
- `.github/workflows/release-functions.yml` (new)
- `CHANGELOG.md`
- No application code changes expected. If `Program.cs` or `host.json` need a health endpoint and one does not exist, add a minimal `/api/health` trigger that returns 200.

## NuGet Dependencies

### `HoneyDrunk.Notify.Functions` — additions only if missing
| Package | Notes |
|---|---|
| `HoneyDrunk.Vault.Providers.AzureKeyVault` | Already expected from ADR-0005 rollout. Confirm present. |
| `HoneyDrunk.Vault.Providers.AppConfiguration` | Already expected. Confirm present. |
| `Microsoft.Azure.Functions.Worker.Extensions.Http` | Required if adding the health endpoint. |

No new packages added by this packet unless the health endpoint is absent.

## Boundary Check
- [x] Workflow-only change plus optional health endpoint. No Transport contract change.
- [x] Runtime secret handling unchanged — ADR-0005 bootstrap path already in place.
- [x] Deploy logic lives entirely in `HoneyDrunk.Actions`; this repo only calls the reusable workflow.

## Acceptance Criteria
- [ ] Pushing a `functions-v0.1.0` tag on `main` triggers `release-functions.yml`, publishes the function, and deploys to `func-hd-notify-dev` successfully.
- [ ] Health check endpoint `/api/health` returns 200 on the deployed function.
- [ ] `func-hd-notify-dev` resolves the six Key Vault secrets at runtime via Managed Identity — verified by sending a test notification through a provider.
- [ ] No client secrets anywhere in the workflow — OIDC only.
- [ ] `CHANGELOG.md` updated.
- [ ] Rollback dry-run: redeploy the prior tag successfully (exercises the artifact + deploy path twice).

## Human Prerequisites
- [ ] Provision `rg-hd-notify-dev`, `kv-hd-notify-dev`, and seed the six Key Vault secrets (Resend, Twilio ×2, Smtp ×2, NotifyQueueConnection). Cross-link: [`infrastructure/key-vault-creation.md`](../../../../infrastructure/key-vault-creation.md).
- [ ] Provision `func-hd-notify-dev` via portal per [`infrastructure/function-app-creation.md`](../../../../infrastructure/function-app-creation.md) (created in packet 01 of this initiative).
- [ ] Assign `Key Vault Secrets User` on `kv-hd-notify-dev` to the Function App MI. Cross-link: [`infrastructure/key-vault-rbac-assignments.md`](../../../../infrastructure/key-vault-rbac-assignments.md).
- [ ] Create OIDC federated credential for `HoneyDrunkStudios/HoneyDrunk.Notify` (environment `dev`). Grant `Contributor` on `rg-hd-notify-dev`. Cross-link: [`infrastructure/oidc-federated-credentials.md`](../../../../infrastructure/oidc-federated-credentials.md).
- [ ] Create GitHub Actions environment `dev` on the repo with `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `HD_ENV=dev` as environment variables.
- [ ] Confirm Log Analytics workspace `log-hd-shared-dev` is receiving diagnostics from the new Function App.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service / Function App config at deploy time. Never derived by convention, never hardcoded.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.

## Referenced ADR Decisions

**ADR-0015 (Container Hosting Platform):** Function Apps remain on the Functions hosting plane. Only containerized Nodes move to Container Apps — this packet deploys the Functions side.

**ADR-0005 (Configuration and Secrets Strategy):** Per-Node vault, provider-grouped secret naming (`Resend--ApiKey`, etc.), env-var bootstrap, Managed Identity + RBAC. All of this must be honored verbatim — the release workflow is the enforcement surface.

**ADR-0012 (Grid CI/CD Control Plane):** Deploy logic lives in `HoneyDrunk.Actions`. `release-functions.yml` must call `job-deploy-function.yml` — no local reimplementation.

## Dependencies
- `architecture-container-apps-walkthroughs` (packet 01) — provides the `function-app-creation.md` walkthrough that the Human Prerequisites cross-link into.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0015`

## Agent Handoff

**Objective:** Stand up `Notify.Functions` as the Grid's first deployed Function App via OIDC + Key Vault.
**Target:** HoneyDrunk.Notify, branch from `main`

**Context:**
- Goal: First production deploy of a HoneyDrunk Node that is not a NuGet package.
- Feature: ADR-0015 rollout, Notify deploy track.
- ADRs: ADR-0015 (hosting choice), ADR-0005 (secrets/config), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 walkthroughs merged; human-provisioned Azure resources in place before the first tag push.

**Constraints:**
- **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. Release workflow must not echo secret values in step summaries or error messages.
- **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. Provider credentials (Resend, Twilio, SMTP) must resolve through `ISecretStore` at call time, per the existing ADR-0005 migration.
- **Invariant 17:** One Key Vault per deployable Node per environment. Vault is `kv-hd-notify-{env}`.
- **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. Do not hardcode the vault URI anywhere in the workflow or code. Bootstrap env vars are set on the Function App at portal-provision time and re-asserted by the deploy workflow if drift is detected.

**Key Files:**
- `.github/workflows/release-functions.yml` (new — the only file that must be authored)
- `src/HoneyDrunk.Notify.Functions/Program.cs` — confirm `builder.AddVault()` + `builder.AddAppConfiguration()` present (from ADR-0005 rollout packet 10).
- `src/HoneyDrunk.Notify.Functions/host.json` — no change expected.
- `CHANGELOG.md`

**Contracts:** None changed. This is a deployment surface add, not a runtime contract change.
