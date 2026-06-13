---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "infrastructure", "human-only", "adr-0055", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0055", "ADR-0005"]
accepts: ["ADR-0055"]
wave: 1
initiative: adr-0055-feature-flags
node: honeydrunk-architecture
---

# Extend the App Configuration walkthrough with the feature-flag surface; seed dev/staging/prod/ci labels

## Summary
Extend the existing `infrastructure/walkthroughs/app-configuration-provisioning.md` with a new section covering ADR-0055 D2's feature-flag surface and D9's label conventions (`dev` defaults on, `staging` / `prod` / `ci` default off), and apply the walkthrough's label-seeding step in the existing `dev` App Configuration resource. This is `Actor=Human` — Azure resource changes are portal work and the developer prefers UI walkthroughs over CLI per the standing convention.

## Context
ADR-0055 D2 commits to **Azure App Configuration's feature-flags surface** as the v1 backend — leveraging the App Configuration resource **already provisioned per ADR-0005**. ADR-0055 D9 inverts the production safety default for the dev environment: `dev` flags default on, `staging` / `prod` / `ci` flags default off. The mechanism is per-label `enabled` definitions in App Configuration (the `dev`-labeled flag value carries `"enabled": true`; the `staging`/`prod`/`ci`-labeled values carry `"enabled": false`). CI validation (packet 06) enforces that every flag has both a `dev` and a non-dev label defined.

App Configuration's feature-flag surface is a first-class resource type inside the existing App Configuration account — no new Azure resource, no new billing line, no new secret. The portal work is small: confirm the App Configuration account exists for `dev` (it does per ADR-0005), enable/locate the Feature Manager view, seed the label conventions per D9, and document the workflow for adding new flags going forward.

The existing walkthrough lives at `infrastructure/walkthroughs/app-configuration-provisioning.md`. This packet **extends** it with a feature-flag section rather than authoring a separate doc — the two surfaces (config and flags) live in the same App Configuration resource and are best documented together. ADR-0055 D12 names the flag/config boundary; documenting both in one walkthrough keeps the boundary visible.

**Provision-when-needed.** ADR-0055 D14 Phase 1 says "the App Configuration label conventions per D9." `dev` is the environment that exists now. `staging` and `prod` are still in flight per ADR-0033; their feature-flag label conventions are seeded when those environments stand up. The walkthrough covers all four labels (`dev`, `staging`, `prod`, `ci`) so the future seeding is a repeat execution, not a new packet.

This packet authors the walkthrough section **and** executes the `dev` label seeding. No code, no .NET project.

## Scope
- `infrastructure/walkthroughs/app-configuration-provisioning.md` — append a new section "Feature-Flag Surface (ADR-0055)" covering the Feature Manager view, the four labels (`dev`/`staging`/`prod`/`ci`), how to add a new flag, and how to set its per-label default state per D9.
- The dev Azure App Configuration resource — apply the D9 label conventions (this is the portal work).
- `catalogs/grid-health.json` — optionally update the `honeydrunk-featureflags` entry's notes to record that the App Configuration feature-flag surface is provisioned/seeded for `dev` (the entry itself is added by packet 01).

## Proposed Work (human-executed, Azure Portal)
Author the walkthrough section to cover, and then execute for `dev`, the following:

1. **Locate the dev App Configuration resource.** From ADR-0005's existing walkthrough, the dev App Configuration resource is `appcs-hd-shared-dev` (or whatever the existing walkthrough names it — confirm at the existing walkthrough). Open the resource in the Azure Portal.
2. **Open the Feature Manager view.** App Configuration's left nav has a Feature Manager entry. This is the feature-flag surface — distinct from Configuration Explorer, which holds typed config (the D12 boundary).
3. **Document the four labels.** ADR-0055 D9 names four environment labels: `dev`, `staging`, `prod`, `ci`. App Configuration uses labels to scope key values per environment (the same pattern ADR-0005 commits to for config). The walkthrough documents that every flag definition lives at **four label-scoped versions** — one per environment — and that the `dev` label's value carries `"enabled": true` by default while the others carry `"enabled": false`.
4. **Document the new-flag workflow.** Adding a new flag is a two-step:
   - In `featureflags.json` for the consuming Node (per packet 02's schema; per ADR-0055 D6), declare the flag with all its metadata (`name`, `category`, `description`, `owner`, `created`, `expires_on` for release / `annual_review_due` for permission/operational).
   - In the Portal Feature Manager, create the flag, then for each of the four labels (`dev`, `staging`, `prod`, `ci`) set the per-environment enabled state per D9 (dev on, others off — unless this is a permission flag, in which case all start off and tenants are added explicitly).
   - The walkthrough should show what the JSON in App Configuration looks like for a flag with the `TenantTargeting` filter (per ADR-0055 D3 example).
5. **Apply the label conventions for `dev` now.** No flags exist yet (packet 07's Notify pilot is the first). The seeding for `dev` is essentially: confirm the Feature Manager view loads, confirm the resource accepts label-scoped flag values, and record in the walkthrough that the resource is ready. There is no first flag to create in this packet.
6. **Document the access pattern.** ADR-0055 D2 says App Configuration push-refresh via Event Grid. The walkthrough notes that consuming hosts subscribe to App Configuration's Sentinel + Event Grid push-refresh so flag changes propagate in seconds, no app restart. This is a runtime/composition concern (packet 05 implements it in `HoneyDrunk.FeatureFlags`) but documenting it in the walkthrough closes the loop for the operator.
7. **Document the Managed Identity access.** ADR-0005 commits to Managed Identity access to App Configuration; no new secret rotates for the flag surface. The walkthrough confirms the dev App Configuration resource grants the appropriate Reader role to the Managed Identity of every consuming Node (Notify per packet 07, others over time). If the role assignment is not yet wired, the walkthrough documents the portal step to add it.

The section is authored to cover all four environments (`dev` now, `staging` / `prod` when ADR-0033 environments stand up). The `ci` label is unusual — `ci` is not a *deployed* environment; it is a label the CI test fixture (`InMemoryFeatureGate` per packet 04) loads when tests need to assert flag-off behavior explicitly. Document this clearly: `ci` is a tooling label, not a deployed environment, and its flag values are loaded into the test fixture by the unit-test setup code.

## Affected Files
- `infrastructure/walkthroughs/app-configuration-provisioning.md` — new "Feature-Flag Surface (ADR-0055)" section appended.
- The dev Azure App Configuration resource — portal-applied label conventions (not a repo artifact).
- `catalogs/grid-health.json` — optional notes update on `honeydrunk-featureflags`.

## NuGet Dependencies
None. This packet has no .NET project — it is an Azure-Portal walkthrough extension plus portal seeding.

## Boundary Check
- [x] The walkthrough extension and the optional `grid-health.json` update live in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs and catalog metadata.
- [x] No code change in any repo.
- [x] Portal work lands in the Azure subscription (a vendor surface, not a Node).

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/app-configuration-provisioning.md` has a new "Feature-Flag Surface (ADR-0055)" section covering: locating the Feature Manager view, the four labels (`dev`/`staging`/`prod`/`ci`), the new-flag workflow (declare in `featureflags.json` → create in portal → set per-label enabled state per D9), the `TenantTargeting` filter JSON shape, the Event Grid push-refresh pattern, and the Managed Identity access pattern
- [ ] The section explicitly documents D9's inversion: `dev` defaults on, `staging` / `prod` / `ci` default off; permission flags are an exception (all start off, tenants added explicitly)
- [ ] The section documents that `ci` is a tooling label loaded into `InMemoryFeatureGate` test fixtures, not a deployed environment
- [ ] The section is authored to cover all four environments; only `dev` is seeded in this packet (staging / prod when ADR-0033 environments land — repeat execution, not a new packet)
- [ ] The dev App Configuration resource's Feature Manager view loads in the Portal and the resource accepts label-scoped flag values
- [ ] Managed Identity Reader access on the dev App Configuration resource is confirmed for the Managed Identities of every Node planned to consume flags in this initiative (Notify per packet 07; Operator per packet 08 once Operator stands up)
- [ ] No secret, instrumentation key, or connection string appears in the walkthrough or anywhere in the repo (invariant 8 — Vault is the only source of secrets per invariant 9)

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Azure Portal access to the subscription with rights to read/write the dev App Configuration resource.
- [ ] The dev App Configuration resource must exist per ADR-0005 (it does — confirm via the existing `app-configuration-provisioning.md` walkthrough).
- [ ] Confirmation of Managed Identity Reader role assignments for every consuming Node's Managed Identity. If a consuming Node's Managed Identity does not exist yet (e.g., FeatureFlags' own MI when it stands up via packet 05), the assignment is deferred until that Node lands; record the dependency in the walkthrough.
- [ ] No actual flags are created in this packet — packet 07 (Notify pilot) creates the first flag.

## Referenced ADR Decisions
**ADR-0055 D2 — Backend: Azure App Configuration's feature-flags surface.** First-class feature-flag model inside the App Configuration resource; label-based environment scoping consistent with ADR-0005; built-in targeting filters (percentage, time-window, custom); push-refresh via Event Grid; no new vendor relationship.

**ADR-0055 D9 — Local-dev affordances: dev defaults on, others default off.** Encoded via per-label `enabled` values in App Configuration. The `dev` label's flag value carries `"enabled": true`; `staging` / `prod` / `ci` labels carry `"enabled": false` unless explicitly enabled. CI validation (packet 06) enforces that every flag has both a `dev` and a non-dev label defined.

**ADR-0055 D3 — `TenantTargetingFilter` JSON shape.** The walkthrough documents the on-the-wire shape (the `client_filters` block with `TenantTargeting` filter parameters `tenants`, `tiers`, `default_rollout_percentage`).

**ADR-0005 — App Configuration is the config backend.** Same resource holds both config (Configuration Explorer) and flags (Feature Manager). Access is Managed Identity per ADR-0005.

## Constraints
- **No new resource.** ADR-0055 D2 explicitly leverages the existing App Configuration resource — do not create a separate flags-only resource.
- **No secret in the walkthrough or the repo.** App Configuration is Managed-Identity-accessed per ADR-0005 (invariant 9 — Vault is the only source of secrets, applied to App Configuration's authentication). No connection string is needed for the flag surface.
- **The `ci` label is tooling, not infrastructure.** Document this clearly — the `ci` label is consumed by `InMemoryFeatureGate` test fixtures in the test process, not by a deployed `ci` environment.
- **Permission flags exception to D9.** D9's "dev defaults on" applies to release and operational flags. Permission flags default off in *every* environment including dev — they encode tenant entitlement and "dev defaults on" would inappropriately grant entitlement to every dev-environment caller. Document this.

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `human-only`, `adr-0055`, `wave-1`

## Agent Handoff

**Objective:** Extend the App Configuration walkthrough with the feature-flag surface section and seed the D9 label conventions in the dev App Configuration resource.

**Target:** `HoneyDrunk.Architecture`, branch from `main`. (And Azure Portal — the dev App Configuration resource.)

**Context:**
- Goal: Document the feature-flag surface as part of the existing App Configuration walkthrough so the operator has one place to read for both config and flags; apply the D9 inversion to the dev resource.
- Feature: ADR-0055 Feature Flag rollout, Wave 1.
- ADRs: ADR-0055 D2/D3/D9/D12 (primary), ADR-0005 (App Configuration as the backend), ADR-0033 (staging/prod environments in flight — deferred).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0055 should be Accepted before its walkthrough section lands.

**Constraints:**
- No new Azure resource — extend the existing App Configuration resource per ADR-0005.
- No secret in walkthrough or repo (invariants 8, 9).
- `ci` label is tooling; permission flags default off in every environment including dev.

**Key Files:**
- `infrastructure/walkthroughs/app-configuration-provisioning.md` — new section appended.
- `catalogs/grid-health.json` — optional notes update.

**Contracts:** None — portal/infra work.
