---
name: Repo Feature
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "infrastructure", "adr-0005"]
dependencies: []
adrs: ["ADR-0005"]
wave: 1
---

# Feature: Reusable OIDC federated-credential workflow + KV-access composite actions

## Summary
Create a reusable GitHub Actions workflow and composite actions under `HoneyDrunk.Actions` that implement OIDC federated-credential login to Azure, scoped Key Vault read access, and a deploy-to-App-Service step — so every deployable Node can consume a single shared CI building block instead of reinventing the wheel.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0005 forbids service-principal client secrets (invariant-aligned). Every deployable Node needs identical OIDC federated-credential login plumbing. Duplicating 30 lines of YAML across seven Nodes is wasteful and drifts. A reusable workflow in `HoneyDrunk.Actions` is the canonical place.

## Proposed Implementation

### Reusable workflow: `.github/workflows/azure-oidc-deploy.yml`
- Inputs: `client-id`, `tenant-id`, `subscription-id`, `resource-group`, `app-name`, `artifact-name`, `environment`
- Uses `azure/login@v2` with `federated-token: true` (no client secret)
- Pulls the build artifact
- Deploys to Azure App Service / Function App via `azure/functions-action@v1` or `azure/webapps-deploy@v3`
- Optional KV-smoke-test step that resolves one non-secret key from the target vault to verify MI wiring

### Composite action: `actions/azure-kv-read/action.yml`
- For CI contexts that need to read a single Key Vault secret during a build (sparingly)
- Uses `azure/cli@v2` wrapped with a thin PowerShell / bash step
- Never echoes the value — uses `::add-mask::` and assigns to a GitHub output

### Composite action: `actions/setup-honeydrunk-dotnet/action.yml` (update existing if present)
- Ensures .NET SDK from `global.json`
- Wires NuGet auth via GitHub Packages OIDC — not PATs

### Documentation
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

## Affected Packages
- None (CI / composite actions only)

## Boundary Check
- [x] CI plumbing belongs in HoneyDrunk.Actions per routing rules
- [x] No runtime contract changes

## Acceptance Criteria
- [ ] Reusable workflow file exists and is callable from another repo
- [ ] Composite action `azure-kv-read` exists and masks the secret value
- [ ] OIDC login has zero client-secret inputs anywhere in the codebase
- [ ] Workflow successfully deploys at least one test Node (Notify's worker is a good candidate) end-to-end
- [ ] README documents the workflow interface
- [ ] Workflow validates against `actionlint` in CI

## Context
- ADR-0005 §Access — CI / Deploy section
- Invariant 17, 18
- User preference: portal over CLI (this workflow is a CLI surface, so keep it minimal — the portal walkthroughs are the primary docs)

## Dependencies
None. Can run in Wave 1 in parallel with Vault work. Per-Node migration packets will consume this.

## Labels
`ci`, `tier-2`, `ops`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Give every Node a single shared OIDC-authenticated deployment workflow.
**Target:** HoneyDrunk.Actions, branch from `main`
**Context:**
- Goal: Remove client-secret CI auth and deduplicate deployment YAML
- Feature: Configuration & secrets strategy rollout
- ADRs: ADR-0005

**Acceptance Criteria:** As listed above

**Dependencies:** None

**Constraints:**
- No `AZURE_CLIENT_SECRET` anywhere
- `id-token: write` permission must be documented as required on callers
- Invariant 8 — masked values only

**Key Files:**
- `.github/workflows/azure-oidc-deploy.yml` (new)
- `actions/azure-kv-read/action.yml` (new)
- `actions/setup-honeydrunk-dotnet/action.yml` (update if exists)
- `README.md`

**Contracts:** Reusable workflow input interface documented in README.
