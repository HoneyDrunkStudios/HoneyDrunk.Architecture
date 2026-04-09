---
name: Repo Feature
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "infrastructure", "adr-0005"]
dependencies: ["actions-oidc-federated-credentials-workflow"]
adrs: ["ADR-0005"]
wave: 2
initiative: adr-0005-0006-rollout
node: honeydrunk-actions
---

# Feature: Audit HoneyDrunk.Actions workflows and composites for direct secret reads

## Summary
Sweep every workflow and composite action in `HoneyDrunk.Actions` for direct secret reads (GitHub Actions `secrets.*` that should now come from Key Vault, or any `AZURE_CLIENT_SECRET` left over) and replace with the OIDC + `azure-kv-read` pattern from the reusable workflow.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0005 requires that secrets live in Key Vault, not in GitHub Actions repo secrets. Identifiers like `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_SUBSCRIPTION_ID` are non-secret and stay as repo / environment variables. Actual credentials (signing keys, provider tokens used *during* a workflow step) must be resolved via `azure-kv-read` against the target vault. This is the cleanup pass that makes the OIDC reusable workflow actually load-bearing.

## Proposed Implementation
- Enumerate every `.github/workflows/*.yml` and every `actions/*/action.yml`
- Classify each `secrets.*` reference:
  - Non-secret identifier (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, etc.) → move to `vars.*` or environment variables
  - Actual credential → resolve at step time via `azure-kv-read` composite
  - Legacy NuGet feed PAT → replace with GitHub Packages OIDC
- Remove every `AZURE_CLIENT_SECRET` from every workflow and from the repo secret store
- Add a lightweight `actionlint` + custom regex check in the Actions repo's own CI that fails if `AZURE_CLIENT_SECRET` or other banned patterns reappear

## Affected Packages
- None (CI only)

## Boundary Check
- [x] Meta-cleanup of Actions repo — no downstream consumers affected as long as the reusable workflow contract stays stable

## Acceptance Criteria
- [ ] Zero `AZURE_CLIENT_SECRET` references across the repo
- [ ] Every remaining `secrets.*` reference is either (a) a GitHub App token, (b) a KV-resolved credential for local workflow use, or (c) documented as pending migration
- [ ] Lint check wired to repo CI
- [ ] README updated with the banned-patterns list
- [ ] Existing consumer workflows in other repos still work (smoke test via one downstream call)

## Context
- ADR-0005 §Access
- Invariant 9 — Vault is the only source of secrets

## Dependencies
- `2026-04-09-actions-oidc-federated-credentials-workflow.md` (must land first — provides the replacement surface)

## Labels
`ci`, `tier-2`, `ops`, `infrastructure`, `adr-0005`

## Agent Handoff

**Objective:** Eliminate direct secret reads from HoneyDrunk.Actions.
**Target:** HoneyDrunk.Actions, branch from `main`
**Context:**
- Goal: Make ADR-0005 invariant 9 enforceable across CI
- Feature: Configuration & secrets strategy rollout
- ADRs: ADR-0005

**Acceptance Criteria:** As listed above

**Dependencies:** OIDC reusable workflow packet

**Constraints:**
- Do not break existing downstream consumers — any change to the reusable workflow input interface requires a major version bump
- Invariant 8 — lint output must never echo any secret value

**Key Files:**
- `.github/workflows/*.yml`
- `actions/*/action.yml`
- `README.md`

**Contracts:** Stability of `azure-oidc-deploy.yml` reusable workflow inputs.
