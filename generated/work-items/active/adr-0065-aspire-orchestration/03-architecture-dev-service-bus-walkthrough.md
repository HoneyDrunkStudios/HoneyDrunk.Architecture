---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0065", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0065", "ADR-0028", "ADR-0005", "ADR-0052"]
wave: 3
initiative: adr-0065-aspire-orchestration
node: honeydrunk-architecture
---

# Author the dev Service Bus provisioning walkthrough and provision sb-hd-dev + dev App Configuration

## Summary
Author `infrastructure/walkthroughs/dev-service-bus-namespace-provisioning.md` — an Azure-Portal UI walkthrough for creating the `sb-hd-dev` Service Bus namespace (Basic tier, the cheapest viable starting point per the operator's standing tier preference) — and execute it: create the namespace, document the per-session-subscription convention (including manual cleanup of orphaned subscriptions), and seed the connection string into Vault for retrieval by `dotnet user-secrets` and `AddGridServiceBusDev`. **Also provision the dev App Configuration resource** that Notify's AppHost (packet 04) consumes via `AddGridAppConfigDev` — the existing `infrastructure/walkthroughs/app-configuration-provisioning.md` is the authority; this packet executes it for the `dev` environment in the same human session so Wave 4 has both prerequisites in place. This is `Actor=Human` — Azure resource creation is portal work and the developer prefers UI walkthroughs over CLI.

## Context
ADR-0065 D9 commits real dev Service Bus (no in-process broker shim — the InMemory broker's semantics differ from ASB in load-bearing ways). The decision: one dev namespace `sb-hd-dev` is provisioned at the time the first ASB-using Node needs it (per the `feedback_provision_when_needed` preference). That moment is now: Notify's AppHost (packet 04) composes `AddGridServiceBusDev`, which resolves a connection string from `dotnet user-secrets` and creates per-session subscriptions on AppHost launch. Without the namespace, Notify's local-dev inner loop has no broker.

ADR-0065 D9's specifics:
- **One namespace**: `sb-hd-dev`.
- **Basic tier**: the operator's `feedback_default_cheapest_azure_tier` preference. Basic supports queues + topics with subscriptions (the shape ADR-0028 commits for the Grid's default broker) — Standard tier is only justified by per-message scheduling, topic-with-subscription filters, or messages larger than 256 KB, none of which are required for v1.
- **Per-session subscriptions**: developers create one ASB subscription per dev session (named by user / machine / process), so concurrent dev sessions do not interfere. Aspire's `AddGridServiceBusDev` extension (packet 02) creates the per-session subscription on AppHost launch.
- **Cost**: ~$10/month, recorded against the studio's Azure budget per ADR-0052.

The walkthrough sits in `infrastructure/walkthroughs/` alongside the existing infra walkthroughs (`log-analytics-workspace-and-alerts.md`, `key-vault-creation.md`, etc. — see sibling walkthroughs as reference for structure and tone). It is the operator-targeted UI walkthrough for portal-only provisioning. No code, no .NET project, no Bicep.

> **Topic strategy is ADR-0028's authority.** The per-Grid-topic strategy (one ASB topic per Grid topic) is ADR-0028 D5's decision; this packet's walkthrough may document the topic naming pattern but does NOT create topics — topics are created by the Nodes that publish to them (or by the AppHost on first launch, if the AppHost composes topic-creation in its `AddGridServiceBusDev` wiring). The walkthrough creates the namespace and the access keys; topics are downstream concerns.

## Scope
- `infrastructure/walkthroughs/dev-service-bus-namespace-provisioning.md` (new) — the Azure Portal UI walkthrough.
- `catalogs/grid-health.json` (if a `dev-service-bus` resource entry is appropriate) — flip to `provisioned` once the namespace is live. If `grid-health.json` has no slot for dev infra resources, skip the catalog update and record the provisioning in the walkthrough doc instead.
- The Azure subscription — the actual `sb-hd-dev` namespace, the per-Grid-topic stubs (deferred to consumers), and the Vault secret (not repo artifacts).
- **Dev App Configuration resource — provisioned in this same human session** by following the existing `infrastructure/walkthroughs/app-configuration-provisioning.md` for `env=dev`. Notify's AppHost (packet 04) composes `AddGridAppConfigDev` which resolves a connection string at launch; without the resource, packet 04 launch fails. The App Configuration walkthrough already exists — this packet executes it; it does not re-author it.

NOT in scope:
- Per-Node Key Vault provisioning — covered by existing `infrastructure/walkthroughs/key-vault-creation.md`. Notify's vault provisioning, if not already done, rides with packet 04's Human Prerequisites. The dev Service Bus connection string goes into Notify's `kv-hd-notify-dev` once Notify's vault exists.
- Dev Key Vault provisioning — D3 names dev Key Vault as a real dev resource. It is provisioned per `feedback_provision_when_needed` by the first Node that needs it; Notify's `kv-hd-notify-dev` rides with packet 04's Human Prerequisites if it does not yet exist. Not bundled into this walkthrough.
- Re-authoring `app-configuration-provisioning.md` — it already exists. This packet **executes** it for `env=dev`, but does not edit it.
- Production Service Bus provisioning — ADR-0028's responsibility (or a future scoped initiative). This packet provisions `dev` only.

## Proposed Work (human-executed, Azure Portal)
Author the walkthrough to cover, and then execute, the following:

1. **Namespace creation** — create a Service Bus namespace in the Azure Portal:
   - Name: `sb-hd-dev` (per `hd` convention; ≤13-char service name "sb-hd-dev" → "hd-dev" or per the existing naming pattern — confirm against invariant 19 and existing namespaces if any).
   - Resource group: the `dev` resource group (match existing `dev` resources' group).
   - Region: the existing `dev` region.
   - **Pricing tier: Basic.** Show the estimated cost (~$0.05/million operations + ~$10/month base; Basic includes 13M operations/month) before the Create click — the operator's `feedback_default_cheapest_azure_tier` preference.
   - No zone redundancy (Basic doesn't support it; this is a dev namespace).
2. **Connection string into Vault** — copy the namespace's primary connection string (`RootManageSharedAccessKey` or a scoped policy if the operator prefers) and store it in the relevant Key Vault. The walkthrough documents two valid placements:
   - **Per-Node Key Vault** (preferred): the connection string lives in each consuming Node's `kv-hd-{service}-dev` and is resolved at AppHost launch via the consuming Node's Key Vault.
   - **Shared dev Key Vault** (alternative): if a single shared `kv-hd-shared-dev` exists for dev-broker-style shared resources, the secret may live there with Read RBAC granted to each consuming Node's developer principal.
   - The walkthrough records the chosen placement and documents the rationale. **Recommendation: per-Node Key Vault**, consistent with invariant 17 (one Key Vault per deployable Node per environment). The Notify AppHost (packet 04) will pull from `kv-hd-notify-dev`.
3. **`dotnet user-secrets` seeding** — separately, the walkthrough documents the developer's local seeding step: `dotnet user-secrets set "ConnectionStrings:ServiceBus" "<connection-string>" --project Notify.AppHost`. This is the AppHost-level seeding the developer runs once on a fresh box; `AddGridServiceBusDev` (packet 02) resolves the connection string from user-secrets at AppHost launch.
4. **Per-session subscription convention** — the walkthrough documents the per-developer-session naming convention (`{user}-{machine}-{process-id}` or similar — the exact form to align with `AddGridServiceBusDev`'s implementation in packet 02). Subscriptions are created at AppHost launch and deleted on AppHost shutdown by Aspire's extension (lifecycle hook — see packet 02); no manual portal subscription creation is required for normal flow.
5. **Manual cleanup of orphaned subscriptions** — the walkthrough documents how to clear orphans when the lifecycle-hook delete fails (process killed, network blip, namespace temporarily unreachable). Steps: open the Azure Portal → `sb-hd-dev` namespace → the relevant topic → Subscriptions blade → review subscriptions older than a single dev session, delete any that no longer match a running developer's `{user}-{machine}-{process-id}`. Suggested cadence: once a week or whenever a developer notices stale entries. Provide the equivalent Service Bus Explorer path as an alternative for users in that blade.
6. **Provision the dev App Configuration resource** — follow `infrastructure/walkthroughs/app-configuration-provisioning.md` for `env=dev`. This is a separate Azure resource creation in the same human session as the Service Bus namespace. The App Configuration endpoint URI goes into `kv-hd-notify-dev` (per the App Configuration walkthrough's convention) so Notify's AppHost can resolve it via `AddGridAppConfigDev`.
7. **Verify** — confirm the namespace shows in the Azure Portal, the Shared Access Policy keys are readable, and (optionally) a test message round-trips via the portal's "Service Bus Explorer" blade. Confirm the dev App Configuration resource exists and its endpoint URI is stored in the relevant vault.
8. **Update `grid-health.json` or the dispatch-plan deferred list** — if `grid-health.json` carries a slot for dev infra resources, flip the `sb-hd-dev` entry to `provisioned` and (if a slot exists) the `dev-app-configuration` entry. If not, record the provisioning facts in this packet's PR description and the dispatch plan.

The walkthrough is structured to be re-runnable for a future staging/prod Service Bus when those environments stand up (per ADR-0033) — same shape, different environment name. This packet executes `dev` only.

## Affected Files
- `infrastructure/walkthroughs/dev-service-bus-namespace-provisioning.md` (new)
- `catalogs/grid-health.json` (only if it has a dev-infra slot; otherwise no edit)

NOT touched by this work-item:
- Any .NET project (no code change).
- Production Service Bus walkthroughs (ADR-0028 / future scope).
- Notify's or Pulse's repos (those are Wave 4 packets).

## NuGet Dependencies
None. This packet has no .NET project — it is an Azure-Portal walkthrough plus an Azure resource creation.

## Boundary Check
- [x] The walkthrough doc lives in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs.
- [x] No code change in any repo.
- [x] Azure resource lands in the Azure subscription (a vendor surface, not a Node).
- [x] No production resource provisioned — `dev` only (per `feedback_provision_when_needed` and ADR-0033).

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/dev-service-bus-namespace-provisioning.md` exists as a step-by-step Azure-Portal UI walkthrough covering namespace creation, Basic tier selection (with estimated cost shown before the Create click), connection-string copy, Vault placement decision and rationale, the `dotnet user-secrets` seeding command, the per-session subscription naming convention, **and the manual cleanup steps for orphaned subscriptions when the lifecycle-hook delete fails**
- [ ] The walkthrough is parameterised for environment so it can be re-run for staging/prod when those environments stand up (this packet executes `dev` only)
- [ ] The `sb-hd-dev` Service Bus namespace exists in the Azure subscription, Basic tier, in the `dev` resource group
- [ ] **The dev App Configuration resource exists** (provisioned via the existing `infrastructure/walkthroughs/app-configuration-provisioning.md` for `env=dev`) and its endpoint URI is stored in `kv-hd-notify-dev`
- [ ] The connection string is stored as a secret in the chosen Key Vault (per-Node `kv-hd-notify-dev` recommended; shared dev vault acceptable if documented) — never in a config file, never committed (invariants 8, 9)
- [ ] No connection string, shared-access-key value, or any secret value appears in the walkthrough or anywhere in the repo (invariant 8)
- [ ] The user-secrets seeding command documented in the walkthrough uses the exact key `ConnectionStrings:ServiceBus` (matching `AddGridServiceBusDev`'s configuration lookup in packet 02)
- [ ] If `catalogs/grid-health.json` carries dev-infra slots, the `sb-hd-dev` and dev App Configuration entries read `provisioned`; if not, both provisioning facts are recorded in the PR description and the dispatch plan
- [ ] Recurring cost (~$10/month Basic for ASB) recorded against the studio's Azure budget per ADR-0052; the dev App Configuration cost (Free tier if eligible, otherwise the lowest viable tier per `feedback_default_cheapest_azure_tier`) is recorded the same way

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Azure Portal access to the subscription with rights to create Service Bus namespaces **and App Configuration resources** in the `dev` resource group.
- [ ] A decision on the connection-string Vault placement (per-Node `kv-hd-notify-dev` vs shared dev vault). Recommendation: per-Node.
- [ ] If per-Node placement is chosen and Notify's `kv-hd-notify-dev` does not yet exist, create it per [`infrastructure/walkthroughs/key-vault-creation.md`](../../../../infrastructure/walkthroughs/key-vault-creation.md) before storing the connection string. (Notify is a live Node; its dev vault may already exist — verify first.)
- [ ] Acceptance of the ~$10/month recurring Service Bus charge (within the studio's Azure budget per ADR-0052), plus the dev App Configuration tier cost (Free or lowest viable; show the estimate before the Create click).
- [ ] Confirmation of the namespace name against `hd` naming convention and ≤13-char service-name rule (invariant 19).

## Referenced ADR Decisions
**ADR-0065 D9 — Windows-first: real dev Service Bus.** One namespace `sb-hd-dev`, Basic tier, per-session subscriptions, dotnet user-secrets for connection-string resolution. The InMemory broker shim was considered and rejected — its semantics differ from ASB in ways that produce bugs that pass local CI and fail in production.

**ADR-0028 D5 — Default shared Service Bus namespace and topic strategy.** The Grid uses one shared Service Bus namespace per environment with one topic per Grid topic; ADR-0065 D9's `sb-hd-dev` is the dev incarnation of that shape. Note ADR-0028 is still **Proposed** — soft consistency dependency.

**ADR-0005 — Vault and Key Vault naming.** One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}`. The Service Bus connection string lives in the consuming Node's Vault (per-Node placement recommended).

**ADR-0052 — Cost governance.** The ~$10/month recurring Basic-tier ASB cost is recorded against the studio's Azure budget.

**ADR-0033 — Deploy trigger model.** `dev` is the live environment now; staging/prod stand up later. This packet provisions `dev` only; staging/prod are re-runs of this walkthrough when they exist.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The Service Bus connection string is a secret. It never enters the repo, the walkthrough, a config file, or a commit. Only the *fact* of provisioning is recorded.

> **Invariant 9 — Vault is the only source of secrets.** Consuming Nodes resolve the connection string via `ISecretStore` (or via `dotnet user-secrets` at AppHost-launch time, which is the local-dev equivalent under D9).

> **Invariant 17 — One Key Vault per deployable Node per environment.** Per-Node placement of the connection string in `kv-hd-notify-dev` (and any other consuming Node's vault) is the recommended path.

> **Invariant 19 — Service names in Azure resource naming ≤ 13 characters.** `sb-hd-dev` is 9 chars — fits. Confirm against any existing `hd` ASB namespaces.

- **Provision `dev` only.** Staging and prod are deferred. The walkthrough is parameterised for re-run.
- **Basic tier.** The operator's standing tier preference is "default cheapest viable"; Basic is sufficient for v1. Standard only justified by per-message scheduling, subscription filters, or large messages.
- **Portal-only, UI walkthrough.** No Bicep, no ARM, no CLI — the operator's portal-over-CLI preference. Click-by-click.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0065`, `wave-3`

## Agent Handoff

**Objective:** Author the dev Service Bus provisioning walkthrough and provision `sb-hd-dev` so Notify's and Pulse's AppHosts (Wave 4) can resolve a real broker. **Also provision the dev App Configuration resource in the same human session** (via the existing `infrastructure/walkthroughs/app-configuration-provisioning.md`) so Notify's AppHost can resolve `AddGridAppConfigDev` at launch.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Unblock the first multi-service local-dev composition (Notify + Pulse) by providing the only resource the AppHosts cannot fake — real Service Bus.
- Feature: ADR-0065 Multi-Service Local Dev Orchestration rollout, Wave 3 (infra provisioning).
- ADRs: ADR-0065 D9 (primary), ADR-0028 D5 (topic strategy), ADR-0005 (Vault/Key Vault placement), ADR-0052 (cost recording), ADR-0033 (env scope).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0065 Accepted before the dev ASB namespace is provisioned in its name.

**Constraints:**
- Provision `dev` only; staging/prod deferred (ADR-0033).
- Basic tier (cheapest viable per the operator's tier preference) for ASB; Free or lowest-viable tier for App Configuration.
- Connection string into Vault, never the repo (invariants 8, 9).
- Portal-only walkthrough; no CLI or Bicep.
- Use the existing `app-configuration-provisioning.md` walkthrough for the App Configuration step — do not re-author it.

**Key Files:**
- `infrastructure/walkthroughs/dev-service-bus-namespace-provisioning.md` (new)
- `infrastructure/walkthroughs/app-configuration-provisioning.md` (existing — followed, not edited)
- `catalogs/grid-health.json` (only if a dev-infra slot exists)

**Contracts:** None changed — infra provisioning + walkthrough doc only.
