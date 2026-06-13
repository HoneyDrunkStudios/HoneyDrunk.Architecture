---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Infrastructure
labels: ["feature", "tier-2", "ops", "infrastructure", "adr-0077", "wave-3"]
dependencies: ["work-item:11", "work-item:13"]
adrs: ["ADR-0077", "ADR-0015", "ADR-0012"]
wave: 3
initiative: adr-0077-iac-bicep
node: honeydrunk-infrastructure
---

# Author the platform/ shared-foundation Bicep templates (closes the shared-layer provisioning gap)

> **NEW packet introduced by the ADR-0077 amendment (2026-06-02).** It also absorbs the residue of the now-DEAD packet 02 (`Architecture#386`, the `acrhdbicep` ACR portal walkthrough): the `rg-hd-platform-shared` resource-group decision migrates here as the platform layer's home. The registry portal walkthrough itself dies (no `acrhdbicep`); the RG decision survives because `platform/` needs a home. Issue `Architecture#386` is closed as superseded by this packet (the registry-provisioning scope is dropped; the RG-home decision lives here).

## Summary
Author the `platform/` shared-foundation Bicep templates in `HoneyDrunk.Infrastructure` — the FIRST-CLASS home for shared/foundational Azure resources not owned by any single Node: the shared Container Apps Environment (`cae-hd-{env}`), the shared image ACR (`acrhdshared{env}`), the shared Log Analytics workspace, the shared Service Bus namespace, and networking. This closes the original ADR's gap where the shared layer had no provisioning home and Nodes consumed it via hand-pasted ARM resource IDs. Author `platform/main.bicep` + `platform/parameters.{env}.bicepparam` consuming the modules from packet 13, with the per-env shared resources declared and their resource IDs exported as deploy outputs so per-Node leaf templates can reference them.

## Context
The original ADR-0077 had a gap: the shared layer (shared Container Apps Environment, shared image ACR, Log Analytics, shared Service Bus) had no provisioning home. Nodes consumed those resources via hand-pasted ARM resource IDs in their `parameters.{env}.bicepparam` files. The amendment (2026-06-02) creates `platform/` as the first-class home: shared/foundational resources are declared here, and their resource IDs become the canonical reference for every per-Node leaf template.

Per the amendment, the recommended home is the **`rg-hd-platform-shared`** resource group (floated in the original dispatch plan, confirmed by the amendment's D8 revisit). Note the env model: the shared image ACR and Container Apps Environment are **per-environment** (`acrhdshared{env}`, `cae-hd-{env}` per invariant 35) and live in `rg-hd-platform-{env}`; truly environment-agnostic shared substrate (if any) lives in `rg-hd-platform-shared`. The platform layer's `main.bicep` is parameterized by `env`, like every other deploy.

The shared image ACR and Container Apps Environment **already exist** for at least `dev` (per the existing `container-registry-creation.md` and `container-apps-environment-creation.md` portal walkthroughs). Per ADR-0077 D6 (grandfather/opportunistic-import, unchanged by the amendment), this packet does NOT force-recreate them — it authors the `platform/` templates that *declare* them, and the existing live resources are imported to Bicep opportunistically (packet 17's import playbook is the procedure). For resources that do NOT yet exist (e.g. the shared Log Analytics workspace if not yet provisioned, or staging/prod platform resources), the template provisions them on first deploy.

This packet authors the templates; the actual `az deployment` apply is operator-gated (Human Prerequisite) per ADR-0033's environment approval gates.

## Scope
- `platform/main.bicep` (new) — composes the shared-foundation modules: Container Apps Environment, image ACR, Log Analytics, Service Bus namespace, networking (as needed). Exports the resource IDs as outputs.
- `platform/parameters.dev.bicepparam` (new) — per-env shared-resource sizing/region/naming for `dev`.
- `platform/parameters.staging.bicepparam` (new) — for `staging`.
- `platform/parameters.prod.bicepparam` (new) — for `prod`.
- `platform/README.md` (updated from the packet-11 stub) — documents the shared-foundation layer, the `rg-hd-platform-{env}` / `rg-hd-platform-shared` RG model, the grandfather/import posture for existing resources, and how per-Node leaf templates reference the exported resource IDs.
- `modules/observability/logAnalyticsWorkspace.bicep` (new) — if not already in packet 13's set; the shared workspace is a platform resource (`log-hd-shared-{env}` or per the existing naming).
- `modules/compute/containerAppEnvironment.bicep` (new) — the shared `cae-hd-{env}` module.
- `modules/data/containerRegistry.bicep` (new) — the shared image `acrhdshared{env}` module (the per-environment container-image ACR per invariant 35 — NOT a Bicep-module registry).
- Repo `CHANGELOG.md` — append the platform layer under `## [Unreleased]`.

## Proposed Implementation
1. **Platform modules.** Author the three platform-specific modules not in packet 13's app-facing set: `containerAppEnvironment.bicep` (`cae-hd-{env}`), `containerRegistry.bicep` (`acrhdshared{env}` image ACR — invariant 35), `logAnalyticsWorkspace.bicep` (`log-hd-shared-{env}`). Apply D3 naming/tagging. These reuse the same local-path-reference convention.
2. **`platform/main.bicep`.** Compose the shared-foundation modules with local-path references (`'../modules/compute/containerAppEnvironment.bicep'`, etc.). Declare: the Container Apps Environment, the image ACR, the Log Analytics workspace, the shared Service Bus namespace, and any networking. Compose the `tags` object with `hd:node: 'honeydrunk-infrastructure'` (the platform layer is owned by the Infrastructure Node, not by any application Node), `hd:cost-center: 'core-infra'`, `hd:adr: 'ADR-0077'`. Export every shared resource's `id` as a deploy output.
3. **`platform/parameters.{env}.bicepparam`.** Per-env values: env, region, sizing, the `rg-hd-platform-{env}` target. No secret values (D7).
4. **Grandfather existing resources.** Document in `platform/README.md` that `acrhdshared{dev}` and `cae-hd-dev` already exist and are imported opportunistically per ADR-0077 D6 (cross-reference packet 17). The template is authored to *match* the existing resources so the first deploy is a no-op import, not a recreate. **Research the safe import/what-if path at execution time** (`az deployment group what-if` before apply).
5. **Exported IDs are the canonical reference.** Document that per-Node leaf templates (`nodes/{node}/`) reference these exported IDs — not hand-pasted ARM strings. This is the gap-closing payoff.
6. **CHANGELOG.** Append the platform layer entry under `## [Unreleased]`.

## Affected Files
- `platform/main.bicep` (new)
- `platform/parameters.dev.bicepparam` (new)
- `platform/parameters.staging.bicepparam` (new)
- `platform/parameters.prod.bicepparam` (new)
- `platform/README.md` (updated)
- `modules/compute/containerAppEnvironment.bicep` (new)
- `modules/data/containerRegistry.bicep` (new)
- `modules/observability/logAnalyticsWorkspace.bicep` (new)
- `CHANGELOG.md` (updated)

## NuGet Dependencies
None. Bicep templates only; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Infrastructure`. `platform/` is this repo's owned shared-foundation surface per the amendment.
- [x] The shared image ACR (`acrhdshared{env}`) is the per-environment container-image registry (invariant 35) — NOT a Bicep-module registry (which is dropped). The naming similarity is coincidental; these are different resources.
- [x] No per-Node leaf template authored here (those reference the platform outputs at their own touchpoints).

## Acceptance Criteria
- [ ] `platform/main.bicep` declares the shared Container Apps Environment (`cae-hd-{env}`), the shared image ACR (`acrhdshared{env}`, invariant 35), the shared Log Analytics workspace, and the shared Service Bus namespace, composed from local-path module references
- [ ] `platform/main.bicep` exports each shared resource's `id` as a deploy output (the canonical reference for per-Node leaf templates)
- [ ] `platform/parameters.{dev,staging,prod}.bicepparam` exist with per-env values and no secret values (D7)
- [ ] `platform/README.md` documents the `rg-hd-platform-{env}` / `rg-hd-platform-shared` RG model, the D6 grandfather/import posture for existing `acrhdshared{dev}` / `cae-hd-dev`, and the exported-ID reference convention that closes the hand-pasted-ARM-ID gap
- [ ] The platform modules (`containerAppEnvironment`, `containerRegistry`, `logAnalyticsWorkspace`) apply D3 naming/tagging with `hd:node: honeydrunk-infrastructure`, `hd:cost-center: core-infra`
- [ ] The template is authored to MATCH existing live resources (no force-recreate); `what-if` discipline documented for the import-as-no-op path (D6)
- [ ] No `acrhdbicep`, `bicep-publish.yml`, `modules/v{N}.{N}.{N}`, or `br:` reference anywhere — the only ACR is the per-env image ACR `acrhdshared{env}`
- [ ] Repo `CHANGELOG.md` records the platform layer under `## [Unreleased]`
- [ ] `bicep lint` passes against the root `bicepconfig.json`

## Human Prerequisites
- [ ] Confirm / create the `rg-hd-platform-{env}` resource group(s) the platform layer deploys into (the per-env shared resources already imply `rg-hd-platform-dev` exists from the prior portal walkthroughs; confirm staging/prod RGs before their first platform deploy). The agent cannot create resource groups.
- [ ] Grant the Actions OIDC-federated deploy identity (used by `job-deploy-bicep.yml`) Contributor (or scoped equivalent) on `rg-hd-platform-{env}` so `platform/main.bicep` can be applied. Portal RBAC assignment — agent cannot perform.
- [ ] Run `az deployment group what-if` against the existing `dev` platform resources and review the diff BEFORE the first apply, to confirm the import is a no-op (not a recreate) per ADR-0077 D6. Operator judgment call.
- [ ] Apply the platform deploy per environment via `job-deploy-bicep.yml` behind ADR-0033 environment approval gates. The first apply is operator-gated.

## Referenced ADR Decisions
**ADR-0077 amendment (2026-06-02) — `platform/` is the NEW shared-foundation home.** Shared Container Apps Environment, shared image ACR `acrhdshared{env}`, Log Analytics, shared Service Bus, networking — declared in `platform/`, closing the gap where the shared layer had no provisioning home and was consumed via hand-pasted ARM IDs. Recommended home: `rg-hd-platform-shared` (per-env shared resources live in `rg-hd-platform-{env}`).

**ADR-0077 D6 (unchanged) — grandfather / opportunistic import.** Existing manually-provisioned `acrhdshared{dev}` / `cae-hd-dev` are not recreated; the platform template matches them and they import opportunistically (export → decompile → reconcile → adopt; `what-if` before apply).

**ADR-0077 D7 (unchanged) — secrets in Bicep.** No secret values in `platform/` templates or param files.

**ADR-0015 / invariant 35 — one shared Container Apps Environment (`cae-hd-{env}`) and one shared image ACR (`acrhdshared{env}`) per environment.** The platform layer declares exactly these. (Invariant 35 stands unchanged under the amendment — no Bicep-module ACR carve-out, registry dropped.)

**ADR-0033 — environment-gated deploys.** The platform apply is gated per environment via GitHub `environment:` approval.

## Constraints
- **The only ACR is the per-env image ACR.** `acrhdshared{env}` is the container-image registry (invariant 35). There is NO Bicep-module registry — `acrhdbicep` is dropped. Do not create or reference it.
- **Grandfather, don't recreate.** Existing `dev` platform resources import as no-ops; the template matches them. `what-if` before apply.
- **Platform owned by the Infrastructure Node.** Tag `hd:node: honeydrunk-infrastructure`, `hd:cost-center: core-infra` — the platform layer is not owned by any application Node.
- **Exported IDs are the contract.** Per-Node leaf templates reference the platform's exported resource IDs, not hand-pasted ARM strings. Document this as the gap-closing payoff.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `adr-0077`, `wave-3`

## Agent Handoff

**Objective:** Author the `platform/` shared-foundation templates (`main.bicep` + per-env params) declaring the shared Container Apps Environment, image ACR, Log Analytics, and Service Bus, exporting their IDs — closing the hand-pasted-ARM-ID gap. Grandfather existing `dev` resources via `what-if`.

**Target:** `HoneyDrunk.Infrastructure`, branch from `main`.

**Context:**
- Goal: Give the shared layer a first-class provisioning home and a canonical ID-reference surface for per-Node templates.
- Feature: ADR-0077 IaC — Bicep rollout (amended 2026-06-02), Wave 3.
- ADRs: ADR-0077 + 2026-06-02 amendment (primary), ADR-0015/invariant 35 (shared CAE + image ACR), ADR-0033 (env gates), D6 (grandfather/import).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:11` — the `platform/` directory + root `bicepconfig.json` must exist.
- `work-item:13` — the app-facing modules (the platform layer reuses the module conventions; serviceBusNamespace from packet 13 is consumed for the shared SB namespace).

**Constraints:**
- The only ACR is the per-env image ACR `acrhdshared{env}` (invariant 35); no `acrhdbicep`.
- Grandfather existing `dev` resources (`what-if` before apply); do not recreate.
- Platform tagged `hd:node: honeydrunk-infrastructure`.
- Exported IDs are the canonical reference for per-Node templates.

**Key Files:**
- `platform/main.bicep`, `platform/parameters.{dev,staging,prod}.bicepparam`, `platform/README.md`
- `modules/compute/containerAppEnvironment.bicep`, `modules/data/containerRegistry.bicep`, `modules/observability/logAnalyticsWorkspace.bicep`
- `CHANGELOG.md`

**Contracts:** The platform's exported resource IDs (Container Apps Environment ID, image ACR ID, Log Analytics workspace ID, Service Bus namespace ID) are the consumable surface per-Node leaf templates reference.
