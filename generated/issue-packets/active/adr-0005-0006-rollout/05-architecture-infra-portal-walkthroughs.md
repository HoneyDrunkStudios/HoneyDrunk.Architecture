---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "infrastructure", "docs", "adr-0005", "adr-0006"]
dependencies: []
adrs: ["ADR-0005", "ADR-0006"]
wave: 1
---

# Feature: Portal walkthroughs for Key Vault, App Configuration, Event Grid, OIDC, Log Analytics

## Summary
Write portal (Azure Portal UI) walkthroughs in `infrastructure/` for every piece of plumbing ADR-0005 and ADR-0006 require, so the solo dev can stand up a new deployable Node end-to-end without touching CLI.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0005 Operational Consequences and ADR-0006 New Dependencies explicitly defer portal walkthroughs to `infrastructure/` docs. The user prefers Azure Portal UI over CLI — so these walkthroughs are the actual operational contract, not nice-to-haves. Without them, no Node can actually migrate to the new bootstrap.

## Proposed Implementation
Add/update documents under `HoneyDrunk.Architecture/infrastructure/`:

1. **`infrastructure/key-vault-creation.md`** — Portal walkthrough for creating `kv-hd-{service}-{env}`:
   - Resource group selection (`rg-hd-{service}-{env}`)
   - Name validation (24-char limit, 13-char service budget)
   - **RBAC authorization enabled, access policies disabled** (screenshot the toggle)
   - Soft delete + purge protection on
   - Networking defaults (public endpoint + firewall for now; note Private Link as future)
   - Diagnostic settings → route to `log-hd-shared-{env}` (invariant 22)

2. **`infrastructure/key-vault-rbac-assignments.md`** — Portal walkthrough for assigning:
   - `Key Vault Secrets User` to the Node's system-assigned Managed Identity (scoped to that vault only)
   - `Key Vault Secrets Officer` to the GitHub Actions OIDC federated identity (scoped to that vault only)
   - `Key Vault Secrets Officer` to `HoneyDrunk.Vault.Rotation`'s MI on every vault it rotates into
   - Verification steps: "Access control (IAM) → Check access" for each principal

3. **`infrastructure/oidc-federated-credentials.md`** — Portal walkthrough for creating OIDC federated credentials for GitHub Actions:
   - App registration → Federated credentials → Add credential → GitHub Actions preset
   - `{repo, environment}` pair per credential — one per Node per environment
   - Subject format: `repo:HoneyDrunkStudios/{RepoName}:environment:{env}`
   - No client secret issued — critical
   - How to wire the resulting client ID / tenant ID into the repo's GitHub environment secrets (these are non-secret identifiers)

4. **`infrastructure/app-configuration-provisioning.md`** — Portal walkthrough for provisioning `appcs-hd-shared-{env}`:
   - One shared instance per environment, not per Node
   - Enable Managed Identity auth
   - Create per-Node labels matching `HONEYDRUNK_NODE_ID`
   - Feature flag section setup
   - Key Vault references: how to add them and which MI is used to resolve
   - Diagnostic settings → Log Analytics
   - RBAC: `App Configuration Data Reader` to each Node MI, `App Configuration Data Owner` to CI OIDC identities

5. **`infrastructure/event-grid-subscriptions-on-keyvault.md`** — Portal walkthrough for subscribing to `Microsoft.KeyVault.SecretNewVersionCreated`:
   - On each `kv-hd-{service}-{env}` vault: Events → Add Event Subscription
   - Filter to `Microsoft.KeyVault.SecretNewVersionCreated` only
   - Endpoint: the consuming Node's webhook URL (internal, MI-auth or webhook secret per ADR-0006 Tier 3)
   - Dead-lettering config
   - Validation handshake verification

6. **`infrastructure/log-analytics-workspace-and-alerts.md`** — Portal walkthrough for:
   - Creating `log-hd-shared-{env}` Log Analytics workspace
   - Wiring KV diagnostic settings to it (cross-link to walkthrough 1)
   - Creating alert rules:
     - Secret approaching expiry (per ADR-0006 Tier 4)
     - Rotation policy failure
     - Unauthorized access attempt
     - Secret accessed by unexpected identity
   - Pointing to an Azure Monitor dashboard template for secret-age vs SLA

Cross-link all six from a new `infrastructure/README.md` index and from the existing ADR-0005 and ADR-0006 "Operational Consequences" sections via edits.

## Affected Packages
- None (docs only)

## Boundary Check
- [x] Infrastructure walkthroughs live in HoneyDrunk.Architecture per ADR-0005 Affected Nodes
- [x] No code changes to any other repo
- [x] Portal-first presentation aligns with user preference captured in memory

## Acceptance Criteria
- [ ] All six documents exist under `infrastructure/`
- [ ] Each walkthrough is step-by-step portal UI instructions (no CLI as primary path; CLI optional in an appendix at most)
- [ ] Screenshots or explicit menu-path breadcrumbs for every step
- [ ] Each document cross-links ADR-0005 and/or ADR-0006 and the relevant invariants (17–22)
- [ ] `infrastructure/README.md` index lists all six with one-line summaries
- [ ] 13-char service-name constraint called out on the KV creation walkthrough
- [ ] RBAC walkthrough explicitly forbids legacy access policies with a callout box

## Context
- ADR-0005 §Access, §Three-tier config, §Operational Consequences
- ADR-0006 §Tier 3, §Tier 4, §New dependencies
- Invariants 17–22
- User preference: portal over CLI (memory: `feedback_portal_over_cli.md`)

## Dependencies
None — pure docs. Unblocks every per-Node migration packet and the Vault.Rotation scaffold packet.

## Labels
`feature`, `tier-2`, `meta`, `infrastructure`, `docs`, `adr-0005`, `adr-0006`

## Agent Handoff

**Objective:** Produce six portal walkthroughs that fully cover the ADR-0005/0006 infrastructure story.
**Target:** HoneyDrunk.Architecture, branch from `main`
**Context:**
- Goal: Make the new config & rotation story operable by the solo dev via portal only
- Feature: Configuration/rotation rollout
- ADRs: ADR-0005, ADR-0006

**Acceptance Criteria:**
- [ ] As listed above

**Dependencies:** None — foundational docs.

**Constraints:**
- Portal-first, CLI only as appendix
- No fabricated screenshots — if the agent can't verify UI paths, write breadcrumb text instructions instead
- Every walkthrough must terminate in a "verification" section so the user knows when it worked

**Key Files:**
- `infrastructure/key-vault-creation.md` (new)
- `infrastructure/key-vault-rbac-assignments.md` (new)
- `infrastructure/oidc-federated-credentials.md` (new)
- `infrastructure/app-configuration-provisioning.md` (new)
- `infrastructure/event-grid-subscriptions-on-keyvault.md` (new)
- `infrastructure/log-analytics-workspace-and-alerts.md` (new)
- `infrastructure/README.md` (new or updated)

**Contracts:** None (docs only)
