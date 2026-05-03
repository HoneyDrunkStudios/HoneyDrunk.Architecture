---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "docs", "infrastructure", "adr-0015"]
dependencies: []
adrs: ["ADR-0015"]
wave: 1
initiative: adr-0015-container-apps-rollout
node: honeydrunk-architecture
---

# Feature: Infrastructure walkthroughs for Function App, ACR, Container Apps Environment, and Container App

## Summary
Add portal-first walkthroughs for every new Azure resource introduced by ADR-0015. Update `infrastructure/README.md` to index them, and append Invariants 34–36 to `constitution/invariants.md`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
The Grid's first three deployables (Wave 2 of this initiative) need provisioning steps documented before they can stand up. Existing walkthroughs cover Key Vault, RBAC, OIDC, App Configuration, Event Grid, and Log Analytics — none cover compute resources. Without these, per-Node release packets cannot reference authoritative portal flows and every bring-up reinvents the click path.

## Proposed Implementation

Add four new walkthroughs under `infrastructure/`, each matching the existing portal-first style (goal → portal breadcrumb → step-by-step → post-create hardening → references):

- `infrastructure/function-app-creation.md` — Create a `func-hd-{service}-{env}` Function App in `rg-hd-{service}-{env}`, Linux consumption plan, .NET 10 isolated, system-assigned Managed Identity, diagnostics to `log-hd-shared-{env}`, bootstrap app settings seeded (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`, `ASPNETCORE_ENVIRONMENT`, `HONEYDRUNK_NODE_ID`).
- `infrastructure/container-registry-creation.md` — Create shared `acrhdshared{env}` (Basic SKU) once per environment. Enable admin user only if explicitly required for a break-glass scenario; otherwise leave off. Diagnostics to shared Log Analytics.
- `infrastructure/container-apps-environment-creation.md` — Create shared `cae-hd-{env}` Container Apps Environment once per environment. Consumption-only workload profile. Diagnostics to shared Log Analytics. Pre-create the resource group `rg-hd-platform-{env}` if a shared platform RG does not yet exist; document that choice clearly.
- `infrastructure/container-app-creation.md` — Create a per-Node `ca-hd-{service}-{env}` Container App in `rg-hd-{service}-{env}`, attached to the shared `cae-hd-{env}`, pulling from `acrhdshared{env}`. System-assigned MI, `AcrPull` on ACR, `Key Vault Secrets User` on its own vault (cross-link to `key-vault-rbac-assignments.md`). Ingress enabled for HTTP/gRPC as appropriate. Revision mode `Multiple`. Bootstrap env vars seeded.

Update `infrastructure/README.md`:
- Add the four new walkthroughs to the Walkthrough Index in provisioning order (ACR → Container Apps Environment are platform-shared prerequisites; Function App / Container App are per-Node).
- Add ADR-0015 to the References section.

Update `constitution/invariants.md`:
- Append Invariants 34, 35, 36 with text from ADR-0015 §Consequences / New Invariants.

Update `catalogs/nodes.json` or equivalent if Node metadata carries hosting platform (check during implementation; if no such field exists, do not invent one in this packet).

## Affected Files
- `infrastructure/function-app-creation.md` (new)
- `infrastructure/container-registry-creation.md` (new)
- `infrastructure/container-apps-environment-creation.md` (new)
- `infrastructure/container-app-creation.md` (new)
- `infrastructure/README.md`
- `constitution/invariants.md`

## NuGet Dependencies
None. Docs-only packet.

## Boundary Check
- [x] Pure documentation and constitution changes. No Node runtime code touched.
- [x] No contract change. No cross-repo cascade.

## Acceptance Criteria
- [ ] Four walkthroughs exist under `infrastructure/`, each following the existing portal-first structure (Goal / Portal Breadcrumb / Step-by-step / Post-create hardening / References).
- [ ] Each walkthrough cross-links to the relevant prerequisite walkthroughs (e.g., Container App creation links to ACR, CAE, Key Vault, RBAC, and OIDC pages).
- [ ] `infrastructure/README.md` indexes all four with one-line descriptions, in provisioning order.
- [ ] ADR-0015 is listed in the References section of `infrastructure/README.md`.
- [ ] Invariants 34, 35, 36 appear in `constitution/invariants.md` with the exact wording from ADR-0015.
- [ ] At least one environment (`dev`) has `acrhdshared{env}` and `cae-hd-{env}` provisioned in the portal during authoring, so the walkthroughs reflect real click paths — these resources are not reverted after the PR lands.
- [ ] Naming conventions in every walkthrough respect Invariant 19 (13-char service name cap) and the ACR 5–50 alphanumeric constraint.

## Human Prerequisites
- [ ] None for authoring the Function App / Container App walkthroughs — they describe flows that Wave 2 packets exercise.
- [ ] For the ACR and Container Apps Environment walkthroughs, **provision the real `dev` resources in the portal** as the author walks through the steps. This is how the docs become accurate. Use `rg-hd-platform-dev` (create if missing).
- [ ] Confirm your Azure subscription permits creating ACR (Basic SKU) and Container Apps Environment resources before starting. Cost impact: ~$5/mo ACR + $0 CAE Consumption baseline.

## Referenced Invariants

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

> **Invariant 19:** Service names in Azure resource naming must be ≤ 13 characters, so they fit within Azure's 24-character Key Vault name limit.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.

> **Invariant 34 (proposed):** Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`, one per Node per environment, with system-assigned Managed Identity. See ADR-0015.

> **Invariant 35 (proposed):** One shared Container Apps Environment (`cae-hd-{env}`) and one shared Azure Container Registry (`acrhdshared{env}`) serve every containerized Node within a given environment. Per-Node compute environments or registries are forbidden without a follow-up ADR. See ADR-0015.

> **Invariant 36 (proposed):** Container App revision mode is `Multiple` with explicit traffic splitting on deploy. Single-revision mode is forbidden — it removes the rollback seam. See ADR-0015.

## Referenced ADR Decisions

**ADR-0015 (Container Hosting Platform):** Azure Container Apps for containerized Nodes, shared Container Apps Environment and ACR per environment, per-Node Container App with system-assigned MI, revision mode `Multiple` with traffic shift on deploy.

**ADR-0005 (Configuration and Secrets Strategy):** Per-Node Key Vault, env-var bootstrap (`AZURE_KEYVAULT_URI`, `AZURE_APPCONFIG_ENDPOINT`), Managed Identity + Azure RBAC. Every new compute walkthrough must set the bootstrap env vars at create time.

## Dependencies
None. First packet in the initiative.

## Labels
`feature`, `tier-2`, `docs`, `infrastructure`, `adr-0015`

## Agent Handoff

**Objective:** Produce four portal-first walkthroughs and update the invariants to make ADR-0015 actionable for Wave 2.
**Target:** HoneyDrunk.Architecture, branch from `main`

**Context:**
- Goal: Unblock the first three deployables on the Grid.
- Feature: ADR-0015 Container Apps rollout.
- ADRs: ADR-0015 (hosting platform), ADR-0005 (secrets / env-var bootstrap), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:** None upstream. Downstream: packets 02–05 in this initiative consume these walkthroughs.

**Constraints:**
- **Invariant 19:** Service names in Azure resource naming must be ≤ 13 characters, so they fit within Azure's 24-character Key Vault name limit. Every example name in every walkthrough must pass this check.
- **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. Walkthroughs that create compute resources must set the same diagnostics target.
- **Invariant 34 (proposed):** Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`, one per Node per environment, with system-assigned Managed Identity. Walkthrough must enforce this exact naming and MI assignment.
- **Invariant 35 (proposed):** One shared Container Apps Environment (`cae-hd-{env}`) and one shared Azure Container Registry (`acrhdshared{env}`) serve every containerized Node within a given environment. Walkthroughs for those two resources must document "provision once per environment — reuse for every Node."
- **Invariant 36 (proposed):** Container App revision mode is `Multiple` with explicit traffic splitting on deploy. Walkthrough for Container App creation must select `Multiple` revision mode and show how to inspect current traffic splits.

**Key Files:**
- `infrastructure/function-app-creation.md` (new)
- `infrastructure/container-registry-creation.md` (new)
- `infrastructure/container-apps-environment-creation.md` (new)
- `infrastructure/container-app-creation.md` (new)
- `infrastructure/README.md`
- `constitution/invariants.md`
- Existing walkthroughs (`key-vault-creation.md`, `key-vault-rbac-assignments.md`, `oidc-federated-credentials.md`, `log-analytics-workspace-and-alerts.md`) for cross-linking and style matching.

**Contracts:** None changed.
