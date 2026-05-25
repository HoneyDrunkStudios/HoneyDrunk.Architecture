---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0053", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0053", "ADR-0005", "ADR-0015", "ADR-0033", "ADR-0077"]
accepts: ["ADR-0053"]
wave: 2
initiative: adr-0053-release-cadence
node: honeydrunk-architecture
---

# Author `infra/{env}/` Bicep modules and the paired environment-provisioning walkthrough; provision `dev`

## Summary
Author the per-environment Bicep modules in `infra/{env}/` (per ADR-0053 D16 Phase 1) covering the resource-group + RBAC + App Configuration + Log Analytics workspace shape from D2, paired with an Azure-Portal UI walkthrough that documents the same shape click-by-click. Execute the walkthrough for `dev` only — provision the `dev` environment. `staging` and `prod` are documented as repeat executions; their provisioning fires when those environments stand up.

## Context
ADR-0053 D16 Phase 1 reads: "Author `infra/{env}/` Bicep modules for `dev`, `staging`, `prod` following the D2 naming convention. Single subscription per D3 v1." ADR-0077 (Infrastructure-as-Code Bicep) is the governing IaC ADR cited by ADR-0053. **ADR-0077 is still Proposed at edit time** — its prose may shift before acceptance. This packet's Bicep follows ADR-0053 D16 Phase 1 directly; references to ADR-0077 throughout this packet are weakened to "ADR-0077 (Proposed)" and the Human Prerequisites list calls out the dependency explicitly. If ADR-0077's prose materially changes between this packet's authoring and its merge, the Bicep is reconciled in a follow-up packet, not in-place here.

**Bicep + walkthrough — both, by design.** The Bicep module is the deploy artefact (versioned, idempotent, the CI hook for provisioning new environments mechanically); the paired Azure-Portal walkthrough is the human-facing review surface and the bootstrap path for the first execution. The operator's standing preference is portal-over-CLI for infra work; ADR-0053 D16 Phase 1 commits Bicep. The reconciliation: write the Bicep so the topology is reproducible; write the walkthrough so the human review and first-execution path is portal-friendly; the two artefacts describe the *same* shape.

**Provision `dev` only.** ADR-0053 D1 names three environments, but D16 Phase 1 ships the Bicep for all three and stages execution. `dev` is provisioned now (it is the immediate blocker on the Notify/Pulse Azure bring-up per `current-focus.md`); `staging` and `prod` provisioning waits until the operator decides to stand them up. The walkthrough covers all three as repeat executions; this packet's *execution* is `dev`.

**Cheapest viable tier.** Per the operator's standing preference, default to the cheapest viable Azure tier (Free/Basic for dev/staging; Standard/Premium only for prod with a concrete reason). Show the estimated cost before the Create click; the walkthrough records the recommended tier and the daily-cap value where the resource supports a cap.

**What lands in the resource group.** Per ADR-0053 D2 and the existing `infrastructure/conventions/azure-naming-conventions.md`, the `dev` environment needs the cross-cutting shared resources at minimum:
- The `dev` resource group itself: `rg-honeydrunk-dev-eastus` (or `rg-hd-platform-dev` per the existing platform-shared pattern — the walkthrough decides and documents the naming alignment between ADR-0053 D2's prose and the existing convention).
- Azure App Configuration (`appcs-hd-dev` or the convention's chosen name) — ADR-0053 D12 and ADR-0005 commit App Configuration as the env-specific configuration store.
- A Log Analytics workspace (`log-hd-shared-dev`) — already provisioned per ADR-0006, but the walkthrough verifies it exists and documents the reuse decision.
- RBAC scopes per D3 v1: environment-level (the deploy workflow's managed identity scoped to the resource group as Contributor; the operator as Owner).

Per-Node resources (Container Apps Environment, ACR, Key Vaults) are not provisioned by this packet — they are owned by the Notify/Pulse Azure bring-up packets in `adr-0015-container-apps-rollout` (`Notify#3`, `Notify#4`, `Pulse#3`). This packet provisions the **environment skeleton** that those packets deploy into.

**Naming-alignment note.** ADR-0053 D2 proposes `rg-honeydrunk-{env}-{region}` and `{node}-{env}-{purpose}` (e.g. `notify-functions-prod-eastus`). The existing `infrastructure/conventions/azure-naming-conventions.md` uses `rg-hd-platform-{env}` for shared platform resources and `rg-hd-{service}-{env}` for per-Node resource groups, with the `hd` short prefix and no region suffix. **The two conventions are not identical.** The walkthrough records the alignment decision: either honor ADR-0053 D2 verbatim (rename existing resource groups to add the region suffix and expand `hd` → `honeydrunk`), or honor the existing convention (and update ADR-0053 D2's text as a follow-up ADR amendment). **Default recommendation: honor the existing convention** — it is already deployed on live resources (the existing `rg-hd-platform-dev`, `kv-hd-notify-dev`, etc.), and the ADR-0053 text was authored without checking the existing convention file. The walkthrough records this as the chosen path and flags ADR-0053's prose as a follow-up amendment.

This packet authors Bicep + the walkthrough **and** executes the `dev` provisioning. No code, no .NET project.

## Scope
- `infra/dev/` (new) — Bicep module(s) for the `dev` environment skeleton: resource group, App Configuration, Log Analytics workspace (or workspace verification if it exists), RBAC scopes per D3 v1.
- `infra/staging/` (new) — Bicep module(s) for the `staging` environment with the same shape (not executed in this packet).
- `infra/prod/` (new) — Bicep module(s) for the `prod` environment with the same shape (not executed in this packet).
- `infrastructure/walkthroughs/environment-provisioning.md` (new) — the Azure-Portal UI walkthrough covering the same shape as the Bicep, for all three environments as repeat executions.
- `infrastructure/conventions/azure-naming-conventions.md` — append a "Per-environment platform" section if the naming alignment decision adds new patterns (only if the walkthrough's decision adds, never edits existing).
- `infrastructure/README.md` — reference the new walkthrough.
- `catalogs/grid-health.json` — record the `dev` environment as `provisioned` once the walkthrough's `dev` execution completes; `staging` and `prod` recorded as `not-provisioned`. Schema follows the pattern from `adr-0040-telemetry-backend` packet 01.

## Proposed Implementation
1. **Authorship is portal-over-CLI for the walkthrough; CLI-over-portal for the Bicep.** The walkthrough is click-by-click in the Azure Portal UI; the Bicep is the same shape expressed as code. They are siblings, not alternates.
2. **Bicep modules — `infra/{env}/main.bicep`** (one per environment) covering:
   - The resource group declaration (or the assumption that the resource group is created externally — Azure subscription rules differ; the walkthrough decides and the Bicep documents).
   - The App Configuration resource (`appcs-hd-{env}` per the existing convention naming pattern).
   - The Log Analytics workspace (re-use the existing `log-hd-shared-{env}` if it exists per ADR-0006; create otherwise).
   - The role assignments per D3 v1: Owner on the resource group → the operator's user principal; Contributor → the deploy workflow's managed identity (the specific identity is the one the existing `azure-oidc-deploy.yml` workflow already uses).
   - Parameter inputs for `environment` (`dev`/`staging`/`prod`), `region` (default `eastus`), and any other per-environment knobs the shape needs.
3. **The walkthrough — `infrastructure/walkthroughs/environment-provisioning.md`** — covers, in order:
   - Pick the subscription (`honeydrunk-dev` for `dev` per the existing convention; the v1 single-subscription model).
   - Create the resource group (or verify it exists if `rg-hd-platform-{env}` already exists from prior ADRs).
   - Create the App Configuration resource (Free tier for `dev`; show the estimated cost before Create).
   - Verify (or create) the shared Log Analytics workspace.
   - Assign RBAC scopes per D3 v1.
   - Record the resource names in `catalogs/grid-health.json`.
   - Document the `staging` and `prod` repeat: same steps, different subscription/environment input.
4. **`dev` execution.** After authoring, execute the walkthrough for `dev`:
   - Confirm the existing `rg-hd-platform-dev` resource group (or create a new `rg-honeydrunk-dev-eastus` per the alignment decision); document which.
   - Provision App Configuration (Free tier for `dev`).
   - Confirm `log-hd-shared-dev` exists and is reachable.
   - Assign RBAC.
   - Flip `catalogs/grid-health.json` `dev` environment entry from `not-provisioned` to `provisioned`.
5. **Naming-alignment decision recorded in the walkthrough.** Either:
   - **Option A (default).** Honor the existing convention (`rg-hd-platform-{env}`, `appcs-hd-{env}`, `log-hd-shared-{env}`); record this in the walkthrough and flag ADR-0053 D2's prose ("`rg-honeydrunk-{env}-{region}`") as a follow-up amendment for ADR-0053 — the existing convention wins because it is already deployed on live resources.
   - **Option B.** Honor ADR-0053 D2 verbatim (`rg-honeydrunk-{env}-{region}`); the implication is renaming existing `rg-hd-*` resource groups, which is a destructive rename and not in this packet's scope. If chosen, record as a follow-up multi-packet rename initiative.
   Default to Option A; document the choice in the PR body.
6. **`catalogs/grid-health.json`** — add an `environments` section (or follow the precedent set by `adr-0040-telemetry-backend` packet 01's App Insights resource entries) with one entry per environment, each carrying `environment` (`dev`/`staging`/`prod`), `subscription` (the subscription name), `resource_group`, `app_configuration`, `log_analytics_workspace`, and `status` (`not-provisioned` | `provisioned`). Flip `dev` to `provisioned` once the walkthrough execution completes.

## Affected Files
- `infra/dev/main.bicep` (new)
- `infra/staging/main.bicep` (new)
- `infra/prod/main.bicep` (new)
- Any shared Bicep modules (e.g. `infra/modules/app-configuration.bicep`) the three environment files share — author as the shape needs.
- `infrastructure/walkthroughs/environment-provisioning.md` (new)
- `infrastructure/README.md` — reference the new walkthrough.
- `infrastructure/conventions/azure-naming-conventions.md` — append-only if the alignment decision adds a pattern.
- `catalogs/grid-health.json` — `environments` section with three entries; `dev` flipped to `provisioned`.

## NuGet Dependencies
None. This packet has no .NET project — Bicep + Markdown + JSON + Azure-Portal work.

## Boundary Check
- [x] All artefacts in `HoneyDrunk.Architecture` — Bicep modules, walkthroughs, conventions, and the grid-health catalog all live here.
- [x] No code change in any Node.
- [x] Azure resources land in the Azure subscription (a vendor surface, not a Node).
- [x] No per-Node resource (Key Vault, Container App, ACR) is touched — those are the Node bring-up packets' concern.

## Acceptance Criteria
- [ ] `infra/dev/main.bicep`, `infra/staging/main.bicep`, `infra/prod/main.bicep` exist with the environment-skeleton shape (resource group / App Configuration / Log Analytics workspace / RBAC per D3 v1)
- [ ] Shared Bicep modules under `infra/modules/` exist where they reduce duplication across the three environment files
- [ ] `infrastructure/walkthroughs/environment-provisioning.md` exists as a step-by-step Azure-Portal UI walkthrough covering the same shape as the Bicep for all three environments as repeat executions
- [ ] The walkthrough records the naming-alignment decision (Option A default; Option B if chosen) and flags ADR-0053 D2 as a follow-up amendment if Option A is taken
- [ ] The walkthrough shows the estimated Azure cost before each Create click; uses Free/Basic tiers for `dev`
- [ ] `infrastructure/README.md` references the new walkthrough
- [ ] The `dev` resource group, App Configuration, Log Analytics workspace verification, and RBAC scopes are live in the Azure subscription
- [ ] `catalogs/grid-health.json` carries an `environments` section with three entries; `dev` is `provisioned`; `staging` and `prod` are `not-provisioned`
- [ ] No secret value, connection string, instrumentation key, or any credential appears in the Bicep, the walkthrough, the catalog, or anywhere in the repo (invariant 8)
- [ ] No `.csproj` version bump (no .NET project)

## Human Prerequisites
This packet's *artefact authoring* (Bicep, walkthrough, catalog update) is fully `Actor=Agent`. The Azure-Portal execution of the walkthrough for `dev` is human work. List:
- [ ] **ADR-0077 (Proposed) dependency.** This packet cites ADR-0077 as the governing IaC ADR but ADR-0077 is still in **Proposed** status at edit time. The packet does not block on ADR-0077's acceptance — the Bicep follows ADR-0053 D16 Phase 1 directly. If ADR-0077's prose changes materially before this packet merges, reconcile the Bicep in a follow-up packet (do not edit in-place). Confirm ADR-0077's status at edit time and weaken/strengthen the citation accordingly.
- [ ] Azure Portal access to the `honeydrunk-dev` subscription with rights to create resource groups, App Configuration resources, and assign RBAC.
- [ ] A decision on the naming-alignment Option A vs Option B before execution; default is Option A (honor the existing `rg-hd-*` convention).
- [ ] Acceptance of the Azure charges for the `dev` resources (Free tier where possible; expected $0–5/month for the environment skeleton at single-developer scale).
- [ ] Confirmation of the concrete resource names — feed these back to `catalogs/grid-health.json` so the catalog carries the real names.
- [ ] A follow-up ADR-0053 D2 prose amendment (Option A path) or a destructive-rename initiative (Option B path) is noted in the PR body as a deferred item.

## Referenced ADR Decisions
**ADR-0053 D1 — Three environments (`dev`, `staging`, `prod`).** Three always-on environments are the v1 commitment.

**ADR-0053 D2 — Resource-group and resource naming.** ADR-0053 D2 proposes `rg-honeydrunk-{env}-{region}` etc.; the existing `infrastructure/conventions/azure-naming-conventions.md` uses `rg-hd-platform-{env}` etc. The walkthrough records the alignment decision; default is to honor the existing convention.

**ADR-0053 D3 — Subscription split deferred; v1 is single-subscription with environment-level RBAC.** This packet does not create a new subscription; it works in the existing `honeydrunk-dev` subscription. The walkthrough documents the RBAC scopes: Owner = operator only on `rg-*-prod-*`; Contributor = deploy workflow's managed identity scoped to the per-environment resource group.

**ADR-0053 D12 — Configuration parity.** Environment-specific configuration lives in Azure App Configuration per ADR-0005. The Bicep provisions the App Configuration resource per environment.

**ADR-0053 D16 Phase 1 — Codify the environments.** "Author `infra/{env}/` Bicep modules for `dev`, `staging`, `prod` following the D2 naming convention. Single subscription per D3 v1."

**ADR-0005 — Vault and App Configuration.** App Configuration is the env-specific configuration store; secrets are in Key Vault per Node (Key Vaults are not provisioned by this packet — they are the Node bring-up packets' concern).

**ADR-0077 (Proposed) — Infrastructure-as-Code Bicep.** Governing IaC ADR cited by ADR-0053 D16 Phase 1. Status at edit time is **Proposed**; this packet does not block on its acceptance, but if its prose changes materially before merge the Bicep is reconciled in a follow-up packet.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** No connection string, no instrumentation key, no Storage Account key, no SAS token, no API key in the Bicep, the walkthrough, the catalog, or any committed file. Bicep `secureString` parameters where secret values are required (none in this packet's shape — App Configuration's read endpoint is a public-DNS URL, not a secret).

> **Invariant 17 — One Key Vault per deployable Node per environment.** No Key Vault is provisioned by this packet — Key Vaults are per-Node, not per-environment-skeleton. The walkthrough cross-links to `infrastructure/walkthroughs/key-vault-creation.md` for the per-Node Vault path.

> **Invariant 18 — Vault URIs and App Configuration endpoints reach Nodes via environment variables.** The App Configuration endpoint provisioned by this packet is consumed by Nodes via `AZURE_APPCONFIG_ENDPOINT`; the walkthrough documents the endpoint URL but never inlines it into a Node-level config file or Bicep parameter.

- **`dev` only.** Execution provisions `dev`; the Bicep and walkthrough cover all three for the repeat path. Do not provision `staging` or `prod` in this packet.
- **Cheapest viable tier.** Free / Basic for `dev`; show the cost before Create. The walkthrough documents the recommended tier per resource.
- **Honor the existing naming convention by default.** Option A (default) honors `rg-hd-platform-{env}` etc.; record the choice in the PR body and flag ADR-0053 D2's prose as a follow-up amendment.
- **Portal walkthrough + Bicep — both authored.** The walkthrough is the human-friendly review surface; the Bicep is the deploy artefact. The two must describe the same shape; if they diverge, the Bicep is corrected (not the walkthrough), and the divergence is recorded.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0053`, `wave-2`

## Agent Handoff

**Objective:** Author the per-environment Bicep modules and the paired Azure-Portal walkthrough; provision the `dev` environment skeleton.

**Target:** `HoneyDrunk.Architecture`, branch from `main`. The Azure work is human-executed in the Azure Portal after the artefacts land.

**Context:**
- Goal: Stand up the `dev` environment skeleton (resource group + App Configuration + Log Analytics verification + RBAC) so the in-flight Notify/Pulse Azure bring-up (per `adr-0015-container-apps-rollout`) has a real environment to deploy into.
- Feature: ADR-0053 Environments, Branching, and Release Cadence rollout, Wave 2.
- ADRs: ADR-0053 D1/D2/D3/D12/D16 Phase 1 (primary), ADR-0005 (Vault/App Configuration), ADR-0015 (Container Apps — the Nodes deploying into this skeleton), ADR-0033 (tag → environment mapping the deploy workflow uses), ADR-0077 (Proposed, IaC Bicep — see Human Prerequisites).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0053 should be Accepted before its environment skeleton is provisioned as live data.

**Constraints:**
- `dev` only — staging/prod Bicep authored but not executed.
- Bicep + walkthrough — both, in this packet.
- Honor the existing `rg-hd-*` naming convention by default (Option A); record the choice in the PR body.
- Cheapest viable tier — Free/Basic for `dev`; show cost before Create.
- No secret in any committed file (invariant 8).

**Key Files:**
- `infra/dev/main.bicep`, `infra/staging/main.bicep`, `infra/prod/main.bicep` (new)
- `infra/modules/` shared Bicep modules (as needed)
- `infrastructure/walkthroughs/environment-provisioning.md` (new)
- `infrastructure/README.md`
- `infrastructure/conventions/azure-naming-conventions.md` (append-only if Option A adds a pattern)
- `catalogs/grid-health.json` — `environments` section

**Contracts:** None — Azure resources and infrastructure docs, no code.
