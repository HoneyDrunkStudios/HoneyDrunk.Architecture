---
name: Repo Feature
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "infrastructure", "adr-0005"]
dependencies: []
adrs: ["ADR-0005"]
wave: 1
initiative: adr-0005-0006-rollout
node: honeydrunk-actions
---

# Feature: OIDC federated-credential workflow + direct-secret-read cleanup

## Summary
Two CI changes in `HoneyDrunk.Actions` that together move the repo to OIDC-only auth:

1. **Establish the new pattern** — create a reusable OIDC federated-credential deploy workflow and supporting composite actions so every deployable Node has a single shared CI building block.
2. **Clean up the old pattern** — audit and remove every direct secret read (`AZURE_CLIENT_SECRET`, legacy PATs, `secrets.*` references that should now be KV-resolved) from workflows and composites.

Both pieces land in the same repo and make the ADR-0005 OIDC story load-bearing. A human developer would reasonably get both as one sprint story: "establish the new OIDC surface and migrate existing workflows off direct secrets."

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0005 forbids service-principal client secrets. Every deployable Node needs identical OIDC federated-credential login plumbing. Duplicating ~30 lines of YAML across seven Nodes is wasteful and drifts. The reusable workflow in `HoneyDrunk.Actions` is the canonical place for that surface.

Establishing the new workflow without also removing legacy direct secret reads leaves the invariant un-enforceable — `AZURE_CLIENT_SECRET` still works, and any new workflow can quietly fall back to it. The audit step is what makes invariant 9 hold across CI.

## Part A — Reusable OIDC workflow + composite actions

### Proposed Implementation

#### Reusable workflow: `.github/workflows/azure-oidc-deploy.yml`
- Inputs: `client-id`, `tenant-id`, `subscription-id`, `resource-group`, `app-name`, `artifact-name`, `environment`
- Uses `azure/login@v2` with `federated-token: true` (no client secret)
- Pulls the build artifact
- Deploys to Azure App Service / Function App via `azure/functions-action@v1` or `azure/webapps-deploy@v3`
- Optional KV-smoke-test step that resolves one non-secret key from the target vault to verify MI wiring

#### Composite action: `actions/azure-kv-read/action.yml`
- For CI contexts that need to read a single Key Vault secret during a build (sparingly)
- Uses `azure/cli@v2` wrapped with a thin PowerShell / bash step
- Never echoes the value — uses `::add-mask::` and assigns to a GitHub output

#### Composite action: `actions/setup-honeydrunk-dotnet/action.yml` (update existing if present)
- Ensures .NET SDK from `global.json`
- Wires NuGet auth via GitHub Packages OIDC — not PATs

#### Documentation
- `README.md` section describing how downstream repos reference the reusable workflow:
  ```yaml
  jobs:
    deploy:
      uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/azure-oidc-deploy.yml@main
      with: { ... }
      permissions:
        id-token: write
        contents: read
  ```

### Acceptance Criteria — Part A
- [ ] Reusable workflow file exists and is callable from another repo
- [ ] Composite action `azure-kv-read` exists and masks the secret value
- [ ] OIDC login has zero client-secret inputs anywhere in the new surface
- [ ] Workflow successfully deploys at least one test Node (Notify's worker is a good candidate) end-to-end
- [ ] README documents the workflow interface including the required `id-token: write` permission on callers
- [ ] Workflow validates against `actionlint` in CI

## Part B — Direct-secret-read audit and cleanup

### Proposed Implementation
- Enumerate every `.github/workflows/*.yml` and every `actions/*/action.yml`
- Classify each `secrets.*` reference:
  - Non-secret identifier (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_SUBSCRIPTION_ID`, etc.) → move to `vars.*` or environment variables
  - Actual credential → resolve at step time via the `azure-kv-read` composite from Part A
  - Legacy NuGet feed PAT → replace with GitHub Packages OIDC
- Remove every `AZURE_CLIENT_SECRET` from every workflow and from the repo secret store
- Add a lightweight `actionlint` + custom regex check in the Actions repo's own CI that fails if `AZURE_CLIENT_SECRET` or other banned patterns reappear

### Acceptance Criteria — Part B
- [ ] Zero `AZURE_CLIENT_SECRET` references across the repo
- [ ] Every remaining `secrets.*` reference is either (a) a GitHub App token, (b) a KV-resolved credential for local workflow use, or (c) documented as pending migration
- [ ] Lint check wired to repo CI and fails on banned-pattern reintroduction
- [ ] README updated with the banned-patterns list
- [ ] Existing consumer workflows in other repos still work (smoke test via one downstream call)

## Affected Packages
- None (CI / composite actions only)

## Boundary Check
- [x] CI plumbing belongs in HoneyDrunk.Actions per routing rules
- [x] No runtime contract changes
- [x] Meta-cleanup of Actions repo — no downstream consumers affected as long as the reusable workflow contract stays stable

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

> **Invariant 18:** Vault URIs and App Configuration endpoints reach Nodes via environment variables. `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.

## Referenced ADR Decisions

**ADR-0005 (Configuration and Secrets Strategy):** Per-deployable-Node Key Vaults (`kv-hd-{service}-{env}`), `{Provider}--{Key}` secret naming, Managed Identity + Azure RBAC access, three-tier config split (Key Vault for secrets, App Configuration for non-secret config, env vars for bootstrap only), and env-var-driven discovery (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`).
- **§Access:** Runtime uses system-assigned Managed Identity with `Key Vault Secrets User` on own vault only. CI uses OIDC federated credentials with `Key Vault Secrets Officer`. Local dev uses File provider or `DefaultAzureCredential` via `az login`. Access policies and client secrets are forbidden.

## Context
- ADR-0005 §Access
- Invariants 8, 9, 17, 18
- User preference: portal over CLI — this workflow is a CLI surface, so keep it minimal; the portal walkthroughs in `architecture-infra-setup.md` are the primary operational docs

## Dependencies
None (as a packet — Part B builds on Part A within the same PR, so they ship together).

## Labels
`ci`, `tier-2`, `ops`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Ship the new OIDC reusable workflow surface and cleanly retire every direct secret read in the Actions repo, in one coherent change.
**Target:** HoneyDrunk.Actions, branch from `main`
**Context:**
- Goal: Remove client-secret CI auth, deduplicate deployment YAML, and make invariant 9 enforceable across CI
- Feature: Configuration & secrets strategy rollout
- ADRs: ADR-0005 (per-deployable-Node Key Vaults, env-var bootstrap, Managed Identity + RBAC, three-tier config split)

**Acceptance Criteria:**
- [ ] As listed in Part A and Part B sections above

**Dependencies:** None. Per-Node migration packets will consume the reusable workflow after this lands.

**Constraints:**
- No `AZURE_CLIENT_SECRET` anywhere in the repo after this PR
- `id-token: write` permission must be documented as required on callers of the reusable workflow
- Any change to the reusable workflow input interface requires a major version bump — do not break downstream consumers
- Invariant 8 — masked values only in logs; lint output must never echo any secret value
- Invariant 9 — Vault is the only source of secrets; every non-identifier `secrets.*` reference must either move to KV-resolution or be documented

**Key Files:**
- `.github/workflows/azure-oidc-deploy.yml` (new)
- `actions/azure-kv-read/action.yml` (new)
- `actions/setup-honeydrunk-dotnet/action.yml` (update if exists)
- `.github/workflows/*.yml` (audit + clean)
- `actions/*/action.yml` (audit + clean)
- `README.md`

**Contracts:**
- Reusable workflow input interface documented in README
- Banned-patterns list documented in README
