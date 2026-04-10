---
name: Repo Feature
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "infrastructure", "adr-0006"]
dependencies: ["actions-oidc-federated-credentials-workflow"]
adrs: ["ADR-0006"]
wave: 2
initiative: adr-0005-0006-rollout
node: honeydrunk-actions
---

# Feature: Deploy-gate composite action that checks secret rotation SLA before release

## Summary
Add a composite action under `HoneyDrunk.Actions` that queries Log Analytics for secret-age telemetry and blocks the deploy job if any secret on the target Node's vault is past its tier SLA — operationalizing invariant 20.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0006 Tier 5 says a secret older than its SLA triggers an alert and **blocks deploys** on the owning Node. Invariant 20 codifies it. Without an automated gate, this becomes aspirational — the gate must live in CI and be composable across every Node's deploy workflow.

## Proposed Implementation

### Composite action: `actions/check-rotation-sla/action.yml`
- Inputs: `workspace-id` (`log-hd-shared-{env}`), `vault-name`, `environment`
- Uses `azure/cli@v2` with an already-authenticated OIDC session (so this composite must be called *after* `azure/login@v2`)
- Runs a KQL query against Log Analytics pulling the age of every secret in the target vault against the tier SLA table
- Exits non-zero if any secret is past SLA without an active exception record
- Exception mechanism: a custom table `SecretRotationExceptions_CL` in Log Analytics with `secretName`, `expiresAt`, `reason` — query joins on this to allow short-term overrides
- Outputs a summary table to `$GITHUB_STEP_SUMMARY` listing every checked secret + age + status

### Integrate with the reusable deploy workflow
- Update `azure-oidc-deploy.yml` to optionally run this composite before the deploy step, gated on input `check-sla: true` (default true)
- Document the exception table schema in README

## Affected Packages
- None (CI only)

## Boundary Check
- [x] Deploy gating is a CI concern — belongs in Actions
- [x] Reads from `log-hd-shared-{env}`, does not write — safe cross-Node coupling

## Acceptance Criteria
- [ ] Composite action exists and is callable from any workflow
- [ ] KQL query returns expected results against a seeded test workspace
- [ ] Non-zero exit blocks the deploy when a test secret is seeded past SLA
- [ ] Exception table join permits overrides correctly
- [ ] Summary output renders in the GitHub Actions run UI
- [ ] README documents integration + exception schema

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. Tier 1 (Azure-native): ≤ 30 days. Tier 2 (third-party via rotation Function): ≤ 90 days. Certificates: auto-renewed 30 days before expiry. Exceptions must be logged in Log Analytics. See ADR-0006.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. Required for rotation SLA monitoring, unauthorized access alerting, and audit. See ADR-0006.

## Referenced ADR Decisions

**ADR-0006 (Secret Rotation and Lifecycle):** Five-tier rotation model — Azure-native rotation (≤30d), third-party rotation via `HoneyDrunk.Vault.Rotation` Function (≤90d), Event Grid cache invalidation on `SecretNewVersionCreated`, audit via Log Analytics, and deploy-blocking rotation SLAs.
- **§Tier 4:** Diagnostic settings on every Key Vault route to shared Log Analytics. Alert rules for approaching expiry, rotation failure, unauthorized access, unexpected identity access. Dashboard for secret age vs SLA.
- **§Tier 5:** Rotation SLAs — Azure-native ≤30d, third-party ≤90d, certificates auto-renewed ≥30d before expiry. Exceeding SLA blocks deploys until resolved.

## Context
- ADR-0006 §Tier 4, §Tier 5
- Invariant 20 — rotation SLA
- Invariant 22 — diagnostic settings routed to Log Analytics (prerequisite)

## Dependencies
- `2026-04-09-actions-oidc-federated-credentials-workflow.md`
- `2026-04-09-architecture-infra-portal-walkthroughs.md` (the Log Analytics workspace must exist first)

## Labels
`ci`, `tier-2`, `ops`, `infrastructure`, `adr-0006`

## Agent Handoff

**Objective:** Enforce rotation SLA at deploy time so invariant 20 isn't aspirational.
**Target:** HoneyDrunk.Actions, branch from `main`
**Context:**
- Goal: Operationalize the SLA gate from ADR-0006
- Feature: Rotation lifecycle rollout
- ADRs: ADR-0006 (Secret Rotation and Lifecycle)

**Acceptance Criteria:** As listed above

**Dependencies:** OIDC workflow packet must land first; Log Analytics workspace must exist in each environment

**Constraints:**
- Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. The KQL query must never select or log secret *values*, only names and ages.
- Composite action must be idempotent and side-effect-free

**Key Files:**
- `actions/check-rotation-sla/action.yml` (new)
- `.github/workflows/azure-oidc-deploy.yml` (update to wire in the gate)
- `README.md`

**Contracts:** Composite action input interface
