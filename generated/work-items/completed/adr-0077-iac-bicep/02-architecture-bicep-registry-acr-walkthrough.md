---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0077", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0077", "ADR-0015"]
accepts: ["ADR-0077"]
wave: 2
initiative: adr-0077-iac-bicep
node: honeydrunk-architecture
---

# Author the Bicep registry ACR walkthrough and provision acrhdbicep

> **STATUS — SUPERSEDED / DEAD (2026-06-02).** Filed as `Architecture#386` (OPEN, unmerged). The ADR-0077 amendment (2026-06-02) DROPS the cross-repo Bicep module registry in full — there is no `acrhdbicep` ACR to provision, so this packet's portal walkthrough + provisioning scope is dead. The one surviving residue — the `rg-hd-platform-shared` resource-group decision — migrates to packet 14 (the new `platform/` shared-foundation packet), which needs a home. This packet is retained for traceability; do not execute it. Close `Architecture#386` as superseded by packet 14. See `dispatch-plan.md`.

## Summary
Author `infrastructure/walkthroughs/bicep-registry-acr-creation.md` — an Azure-Portal UI walkthrough for creating the shared `acrhdbicep` Azure Container Registry that hosts the Grid's published Bicep modules per ADR-0077 D2 — and execute it: provision the `acrhdbicep` registry in `rg-hd-platform-shared`, grant the Actions OIDC-federated identity `AcrPush` on it (so `bicep-publish.yml` can push modules), and grant per-environment Container App deploy identities `AcrPull` (or scope `AcrPull` more broadly to the deploy identities used by `job-deploy-bicep.yml` consumers). This is `Actor=Human` — Azure resource creation is portal work and the operator prefers UI walkthroughs over CLI.

## Context
ADR-0077 D2 commits a **dedicated** Bicep modules registry, distinct from the per-environment container-image registry `acrhdshared{env}` (invariant 35). The Bicep registry is **environment-agnostic** — a single registry across `dev`/`staging`/`prod` — because Bicep modules are environment-agnostic templates; per-environment module registries would force version-bump-and-republish per environment for no security gain.

**Why a new resource group.** The container-image ACR `acrhdshared{env}` and the Container Apps environment `cae-hd-{env}` live in `rg-hd-platform-{env}` per [container-registry-creation.md](../../../../infrastructure/walkthroughs/container-registry-creation.md) and [container-apps-environment-creation.md](../../../../infrastructure/walkthroughs/container-apps-environment-creation.md) — those are per-environment platform resources. The Bicep registry is **not** per-environment, so it does not belong in `rg-hd-platform-{env}`. Recommendation: a new `rg-hd-platform-shared` resource group for non-environment-scoped shared resources (the Bicep registry, and any future shared substrate). The walkthrough records the RG decision; if the operator prefers a different RG, document the choice.

**Naming.** `acrhdbicep` — alphanumeric, globally unique, 11 chars — comfortably inside the ACR name limit (5–50 chars, alphanumeric only). No environment suffix per its environment-agnostic role.

**Cheapest viable tier.** **Basic SKU.** The Bicep registry's storage and bandwidth requirements are minimal (Bicep modules are small text files, not multi-GB container images). The shared container-image ACR uses Basic too per the existing walkthrough; same posture here. Show the estimated cost before the Create click — Basic is ~$0.167/day = ~$5/month. The walkthrough documents that estimate.

**RBAC.** Two role assignments needed up-front:
- The Actions OIDC-federated identity needs `AcrPush` on the registry so the `bicep-publish.yml` workflow (packet 04) can push modules on tag.
- The Actions OIDC-federated identity (or whichever per-environment deploy identity `job-deploy-bicep.yml` uses) needs `AcrPull` so per-Node `main.bicep` templates can resolve `br:acrhdbicep.azurecr.io/modules/...` references at deploy time.

In the current single-subscription posture, the same Actions OIDC identity handles both push (publish) and pull (deploy). The walkthrough records this and the per-role assignment pattern.

This packet authors a walkthrough doc **and** executes it (provisioning is one-time, environment-agnostic — no `dev`/`staging`/`prod` repetition unlike the per-environment walkthroughs). No code, no .NET project.

## Scope
- `infrastructure/walkthroughs/bicep-registry-acr-creation.md` (new) — the Azure Portal UI walkthrough.
- `catalogs/grid-health.json` — flip the `acrhdbicep` entry from `not-provisioned` to `provisioned` once the registry is live (entry added by packet 01).
- The Azure subscription — the actual `acrhdbicep` registry, the `rg-hd-platform-shared` resource group (if it does not already exist), and the RBAC role assignments.

## Proposed Work (human-executed, Azure Portal)
Author the walkthrough to cover, and then execute, the following:

1. **Platform-shared resource group.** Create `rg-hd-platform-shared` if it does not exist. Location: a single canonical region (recommended: the same region as the operator's primary `dev` deployments — record the choice). Tags `purpose=platform-shared`; do not tag `env` since this RG is environment-agnostic.
2. **`acrhdbicep` Azure Container Registry.** Portal breadcrumb: **Container registries → + Create**. On **Basics**:
   - Subscription: the Grid's subscription.
   - Resource group: `rg-hd-platform-shared`.
   - Registry name: `acrhdbicep` (alphanumeric, globally unique, 11 chars — inside the ACR limit).
   - Location: same as `rg-hd-platform-shared`.
   - Domain name label scope: **Unsecure** (consistent with the existing `acrhdshared{env}` walkthrough — the Grid documents the plain `acrhdbicep.azurecr.io` form across naming conventions; switching to Secure would force renaming).
   - Pricing plan: **Basic** (show the estimated cost — ~$5/month — before the Create click).
   - Role assignment permissions mode: **RBAC Registry Permissions** (no ABAC; consistent with the existing image ACR's posture).
3. **Networking, Encryption, Tags.** Networking → Public access — All networks (consistent with the existing image ACR; private-link is a separate decision). Encryption → CMK disabled (Basic SKU does not support CMK). Tags: `purpose=platform-shared`, `hd:adr=ADR-0077`. Do not tag `env`.
4. **Post-create hardening.**
   - Open the registry → **Settings → Access keys**. Confirm **Admin user** is **Disabled**.
   - Open **Monitoring → Diagnostic settings → + Add diagnostic setting**. Name `acrhdbicep-audit-to-loganalytics`. Categories `ContainerRegistryLoginEvents`, `ContainerRegistryRepositoryEvents`, AllMetrics. Send to `log-hd-shared-{env}` — for an environment-agnostic registry, pick the `dev` workspace (or whichever workspace the operator designates for shared-resource audit). Document the choice. Invariant 22 (Key Vaults must have diagnostic settings) does not literally apply to ACR, but the same audit-routing discipline is the right shape.
5. **RBAC assignments.**
   - **`AcrPush` for the Actions OIDC-federated identity.** Open the registry → **Access control (IAM) → + Add → Add role assignment**. Role `AcrPush`. Assignees: the Actions OIDC-federated service principal (the same identity used by the deploy workflows per the existing `oidc-federated-credentials.md` walkthrough). Scope: the `acrhdbicep` registry.
   - **`AcrPull` for the deploy path.** Same `+ Add role assignment`. Role `AcrPull`. Assignees: the deploy identity used by `job-deploy-bicep.yml` consumers. If this is the same Actions OIDC identity (current single-subscription posture), assign once. If a future split deploys per-environment with per-environment identities, document the multi-assignment shape.
6. **Update `grid-health.json`.** Flip the `acrhdbicep` entry from `not-provisioned` to `provisioned`. Record the actual resource group name if it differs from the recommended `rg-hd-platform-shared`.

## Affected Files
- `infrastructure/walkthroughs/bicep-registry-acr-creation.md` (new)
- `catalogs/grid-health.json` — `acrhdbicep` entry flipped to `provisioned`.

## NuGet Dependencies
None. This packet has no .NET project — it is an Azure-Portal walkthrough plus a catalog update.

## Boundary Check
- [x] The walkthrough doc and `grid-health.json` update live in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs and catalog metadata.
- [x] No code change in any repo.
- [x] Azure resources land in the Azure subscription (a vendor surface, not a Node).

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/bicep-registry-acr-creation.md` exists as a step-by-step Azure-Portal UI walkthrough covering the `rg-hd-platform-shared` resource group creation, the `acrhdbicep` Basic-SKU registry creation, the diagnostic-settings routing, the `AcrPush` role assignment for the Actions OIDC identity, and the `AcrPull` role assignment for the deploy path
- [ ] The walkthrough shows the estimated cost before the Create click (~$5/month Basic SKU) and documents the resource-group decision (recommended: `rg-hd-platform-shared`)
- [ ] The walkthrough explicitly distinguishes `acrhdbicep` from the per-environment `acrhdshared{env}` container-image registry (different purpose, different scope, separate resource)
- [ ] The `acrhdbicep` registry exists in the Azure subscription, Basic SKU, admin user disabled
- [ ] Diagnostic settings route ACR audit events to a Log Analytics workspace (the walkthrough records which workspace was chosen)
- [ ] The Actions OIDC-federated identity has `AcrPush` on the registry, scoped to the registry
- [ ] The deploy identity has `AcrPull` on the registry (in the current single-subscription posture this is the same Actions OIDC identity)
- [ ] `catalogs/grid-health.json` `acrhdbicep` entry is flipped to `provisioned` with the actual resource group name recorded
- [ ] No connection string, registry password, or any secret value appears in the walkthrough or anywhere in the repo (invariant 8) — the Bicep workflows authenticate via OIDC, not via stored credentials
- [ ] The registry has no images / modules at create time — packet 05 publishes the first module set (`modules/v1.0.0`)

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Azure Portal access to the subscription with rights to create resource groups and Container Registries.
- [ ] A decision on the resource-group location (recommended: same region as primary `dev` deployments).
- [ ] A decision on which Log Analytics workspace receives the registry's audit events (for an environment-agnostic registry the `dev` workspace is a reasonable default; the walkthrough records the choice).
- [ ] The Actions OIDC-federated service principal exists per the existing `oidc-federated-credentials.md` walkthrough — confirm before assigning `AcrPush` / `AcrPull`. If it does not yet exist for this scope, create it as part of this packet's portal work or note it as a prerequisite.
- [ ] Acceptance of the Azure charges (~$5/month Basic SKU; within the operator's lean Azure-spend posture).

## Referenced ADR Decisions
**ADR-0077 D2 — Bicep registry on Azure Container Registry, distinct from the image ACR.** Bicep modules are environment-agnostic templates; a single shared registry across environments is the right shape. The registry is named `acrhdbicep` and is distinct from the per-environment container-image registry `acrhdshared{env}` per invariant 35.

**ADR-0077 D7 — Bicep templates never contain secret values; deploy identity has provisioning rights, not secret-read rights.** The registry-side enforcement is the OIDC-federated identity scoped to `AcrPush` / `AcrPull` on the registry, not to broader secret-read scopes.

**ADR-0015 — Container Apps and the container-image ACR (`acrhdshared{env}`).** The per-environment image ACR is the precedent for the ACR-creation walkthrough; the Bicep registry walkthrough mirrors its shape with the key differences noted (environment-agnostic, different RG, different name).

**Invariant 35 — One shared Container Apps Environment and one shared Azure Container Registry per environment.** The per-environment image ACR is `acrhdshared{env}`. The Bicep registry `acrhdbicep` is a separate, environment-agnostic resource. Packet 00's invariant 35 reconciliation clarifies the distinction; this packet operationalizes it.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The registry's access keys are not used — the Bicep workflows authenticate via the OIDC-federated identity, not via stored credentials. Admin user disabled, no access-key copy-paste into config files.

> **Invariant 17 — One Key Vault per deployable Node per environment.** Not directly applicable (the Bicep registry is not a Vault), but the same discipline — no shared identities across Nodes, no Node references another Node's Vault. The Actions OIDC identity is the Actions Node's deploy identity; it has scoped access to `acrhdbicep` for push / pull, nothing more.

> **Invariant 22 — Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.** Literally applies to Key Vaults, not ACR — but the same diagnostic-routing discipline is the right shape for the Bicep registry.

- **Provision once, environment-agnostic.** No `dev`/`staging`/`prod` repetition — a single shared registry.
- **Basic SKU.** Cheapest viable tier (per the lean-Azure-spend posture); show cost before Create.
- **Portal-only, UI walkthrough.** No Bicep, no ARM, no CLI — the operator's portal-over-CLI preference. (The irony of using portal to provision the Bicep registry is acknowledged — D6's grandfather pattern explicitly anticipates this: the substrate has to bootstrap somewhere, and that bootstrap is operator-executed portal work.)
- **Distinct from `acrhdshared{env}`.** The walkthrough explicitly clarifies this so a future executor does not conflate the two.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0077`, `wave-2`

## Agent Handoff

**Objective:** Author the `bicep-registry-acr-creation.md` walkthrough and provision `acrhdbicep` in the Azure subscription with the necessary RBAC assignments for push (publish workflow) and pull (deploy workflow).

**Target:** Tracked against `HoneyDrunk.Architecture`; the Azure work is human-executed in the Azure Portal. `Actor=Human` — `human-only` label set. The walkthrough doc lands in `infrastructure/walkthroughs/`.

**Context:**
- Goal: Stand up the Bicep modules registry so packet 04's `bicep-publish.yml` workflow has a target to push to and packet 05's first module set has a registry to land in.
- Feature: ADR-0077 IaC — Bicep rollout, Wave 2.
- ADRs: ADR-0077 D2/D7 (primary), ADR-0015 (image ACR — the analogous walkthrough), invariant 35 (per-environment image ACR — the Bicep registry is a carve-out).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0077 should be Accepted (and invariant 35 reconciled) before its registry is provisioned.

**Constraints:**
- Environment-agnostic — provision once, not per-environment.
- Basic SKU — cheapest viable; show cost before Create.
- Portal-only UI walkthrough — no Bicep/ARM/CLI.
- Distinct from `acrhdshared{env}` — the walkthrough explicitly clarifies this.
- Admin user disabled; OIDC-federated identity is the only authenticated principal (invariant 8).
- Diagnostic settings route to Log Analytics — same discipline as Key Vaults per invariant 22 (literally applies to Vaults, but the routing pattern carries).

**Key Files:**
- `infrastructure/walkthroughs/bicep-registry-acr-creation.md` (new)
- `catalogs/grid-health.json`

**Contracts:** None — Azure resources, no code.
