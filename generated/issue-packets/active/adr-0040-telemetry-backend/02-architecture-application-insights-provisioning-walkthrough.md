---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0040", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0040", "ADR-0005"]
accepts: ["ADR-0040"]
wave: 1
initiative: adr-0040-telemetry-backend
node: honeydrunk-architecture
---

# Author the App Insights provisioning walkthrough and provision the dev telemetry resource

## Summary
Author `infrastructure/walkthroughs/application-insights-provisioning.md` — an Azure-Portal UI walkthrough for creating the workspace-based Application Insights resource and its backing Log Analytics workspace per ADR-0040 D1 — and execute it for the `dev` environment: create the `dev` Application Insights resource, create or reuse the backing Log Analytics workspace, and seed the connection string into Vault. This is `Actor=Human` — Azure resource creation is portal work and the developer prefers UI walkthroughs over CLI.

## Context
ADR-0040 D1 names Application Insights as the telemetry backend with per-environment resources. The "Operational Consequences" section states: "The App Insights resources need provisioning per environment (Azure Portal); a one-time setup, then Vault-stored connection strings." Per the operator's standing preference, infra provisioning is done through the Azure Portal UI, not Bicep/ARM/CLI — so this packet delivers a portal walkthrough.

**Provision-when-needed.** ADR-0040 D1 names three environments (`dev`, `staging`, `prod`), but staging and prod are still in flight per ADR-0033 (the ADR's Follow-up Work says so explicitly). This packet provisions **only `dev`** — the environment that exists now and that the Pulse implementation packets (03–05, 07) will test against. The walkthrough is authored to cover all three environments so staging/prod provisioning is a repeat execution when those environments stand up; it is not duplicated as separate packets now.

**Cheapest viable tier.** Workspace-based Application Insights bills by the backing Log Analytics workspace's ingestion. For `dev`, use the workspace's Pay-As-You-Go pricing tier with the daily cap set low — App Insights' included free quota (5GB ingest/month) covers `dev` volume at single-developer scale. The walkthrough shows the estimated cost before the Create click and documents setting a daily ingestion cap as the cost guard.

**Log Analytics workspace reuse.** ADR-0040 D3 specifies *one* Log Analytics workspace holding traces, metrics, logs, and the Audit custom table. A `log-hd-shared-{env}` workspace already exists per ADR-0006 (see `infrastructure/walkthroughs/log-analytics-workspace-and-alerts.md`). The walkthrough must decide and document: either back the App Insights resource onto the existing `log-hd-shared-{env}` workspace, or create a dedicated telemetry workspace. **Recommendation: a dedicated telemetry workspace** — ADR-0006's `log-hd-shared` carries Key Vault diagnostic logs and rotation-SLA data with its own retention expectations, and ADR-0040 D3's per-table retention (730d Audit table) is cleaner to manage on a workspace dedicated to application telemetry. The walkthrough records the decision and its rationale; if the operator chooses reuse instead, the walkthrough documents that path.

This packet authors a walkthrough doc **and** executes it for `dev`. The doc lives in `infrastructure/walkthroughs/` (sibling to `log-analytics-workspace-and-alerts.md`, `key-vault-creation.md`, etc.). No code, no .NET project.

## Scope
- `infrastructure/walkthroughs/application-insights-provisioning.md` (new) — the Azure Portal UI walkthrough.
- `catalogs/grid-health.json` — flip the `dev` App Insights resource entry from `not-provisioned` to `provisioned` once the `dev` resource is live (entry added by packet 01).
- The Azure subscription — the actual `dev` App Insights resource, its backing Log Analytics workspace, and the Vault secret (not repo artifacts).

## Proposed Work (human-executed, Azure Portal)
Author the walkthrough to cover, and then execute for `dev`, the following:

1. **Backing Log Analytics workspace** — create a telemetry-dedicated workspace (recommended; or reuse `log-hd-shared-dev` if the operator prefers — document the choice). Name per the `hd` convention and the ≤13-char service-name rule where it applies (invariant 19). Pick the `dev` resource group and region. Pay-As-You-Go pricing tier.
2. **Application Insights resource** — create a **workspace-based** App Insights resource (the classic non-workspace mode is retired by Azure). Name per the `hd` convention. Point it at the workspace from step 1. Set the resource's data retention to 90 days (the D3 trace/log standard). Note that the per-table 730-day Audit retention is configured separately in packet 06.
3. **Daily ingestion cap** — set a low daily cap on the workspace (cost guard per D10's $100/month ceiling). Document the recommended `dev` cap value.
4. **Connection string into Vault** — copy the App Insights **connection string** (the modern replacement for the bare instrumentation key) and store it in the Key Vault for `HoneyDrunk.Pulse` — the Node that runs the telemetry export (the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider lives in the Pulse runtime). Per ADR-0005, one Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}`. Store the connection string as a secret; never paste it into a config file or commit it. The Pulse runtime resolves it via `ISecretStore` (invariant 9 — Vault is the only source of secrets).
5. **Verify** — confirm the resource shows in the Azure Portal, the Application Map / Logs blades load, and a test telemetry item (the portal's built-in availability test or a manual KQL query against an empty table) round-trips.
6. **Update `grid-health.json`** — flip the `dev` entry to `provisioned`.

The walkthrough additionally documents the staging/prod repeat (the same steps, different environment), so those are a re-execution when ADR-0033's staging/prod environments stand up — not new packets.

## Affected Files
- `infrastructure/walkthroughs/application-insights-provisioning.md` (new)
- `catalogs/grid-health.json` — `dev` App Insights resource entry flipped to `provisioned`.

## NuGet Dependencies
None. This packet has no .NET project — it is an Azure-Portal walkthrough plus a catalog update.

## Boundary Check
- [x] The walkthrough doc and the `grid-health.json` update live in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs and catalog metadata.
- [x] No code change in any repo.
- [x] Azure resources land in the Azure subscription (a vendor surface, not a Node).

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/application-insights-provisioning.md` exists as a step-by-step Azure-Portal UI walkthrough covering the Log Analytics workspace, the workspace-based App Insights resource, the daily ingestion cap, and the Vault connection-string seeding
- [ ] The walkthrough records the workspace decision (dedicated telemetry workspace vs reuse of `log-hd-shared-{env}`) with rationale
- [ ] The walkthrough shows the estimated cost before the Create click and documents the recommended daily ingestion cap (D10 cost guard)
- [ ] The walkthrough covers all three environments (`dev`/`staging`/`prod`) as repeat executions; staging/prod are not provisioned in this packet (ADR-0033 — those environments are still in flight)
- [ ] The `dev` App Insights resource and its backing Log Analytics workspace exist in the Azure subscription, workspace-based mode, 90-day resource retention
- [ ] The `dev` App Insights connection string is stored as a secret in the Pulse Node's `kv-hd-{service}-dev` Key Vault — never in a config file, never committed (invariants 8, 9)
- [ ] `catalogs/grid-health.json` `dev` App Insights resource entry is flipped to `provisioned`
- [ ] No connection string, instrumentation key, or any secret value appears in the walkthrough or anywhere in the repo (invariant 8)

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Azure Portal access to the subscription with rights to create Log Analytics workspaces and Application Insights resources in the `dev` resource group.
- [ ] A decision on the backing-workspace choice — dedicated telemetry workspace (recommended) vs reuse of `log-hd-shared-dev`.
- [ ] The `kv-hd-{service}-dev` Key Vault for `HoneyDrunk.Pulse` (the Node that runs the telemetry export) must exist (per ADR-0005; see [`key-vault-creation.md`](../../../../infrastructure/walkthroughs/key-vault-creation.md)) so the connection string has a home. If Pulse's vault does not yet exist, create it as part of this packet's portal work or note it as a prerequisite.
- [ ] Confirmation of the concrete Azure resource names against the `hd` naming convention — feed these back to packet 01 so `grid-health.json` carries the real names.
- [ ] Acceptance of the Azure ingestion charges (within the $0–30/month v1 estimate; `dev` is expected to sit inside the free quota).

## Referenced ADR Decisions
**ADR-0040 D1 — Backend: Azure Monitor + Application Insights.** Per-environment App Insights resources keep dev noise out of prod dashboards. Resources provisioned per environment; instrumentation keys (modern: connection strings) live in Vault per ADR-0005.

**ADR-0040 D3 — Retention.** Traces 90 days, metrics 93 days, logs 90 days standard / 730 days for Audit-sourced logs. One Log Analytics workspace; the Audit 730-day retention is a per-table policy configured separately (packet 06).

**ADR-0040 D10 — Cost ceiling.** $100/month ceiling; realistic v1 cost $0–30/month. App Insights' free quota (5GB ingest/month) is sufficient for current `dev`/prod volume.

**ADR-0005 — Vault and Key Vault naming.** One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}`, Azure RBAC enabled. Vault URIs reach Nodes via the `AZURE_KEYVAULT_URI` environment variable. Service names ≤13 characters (invariant 19).

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The App Insights connection string is a secret. It never enters the repo, the walkthrough, a config file, or a commit. Only the *fact* of provisioning is recorded.

> **Invariant 9 — Vault is the only source of secrets.** The Pulse runtime resolves the App Insights connection string via `ISecretStore`, never from an environment variable holding the raw string or a provider SDK default.

> **Invariant 17 — One Key Vault per deployable Node per environment.** Named `kv-hd-{service}-{env}` with Azure RBAC. The connection string goes into the `HoneyDrunk.Pulse` Node's Key Vault — Pulse runs the telemetry export.

- **Provision `dev` only.** Staging and prod are in flight per ADR-0033. The walkthrough covers all three as repeat executions; this packet executes `dev`.
- **Workspace-based App Insights.** Classic (non-workspace) App Insights is retired by Azure — create the resource in workspace-based mode.
- **Portal-only, UI walkthrough.** No Bicep, no ARM, no CLI — the operator's portal-over-CLI preference. Click-by-click.
- **Cheapest viable tier.** Pay-As-You-Go with a low daily ingestion cap for `dev`. Show the cost before the Create click.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0040`, `wave-1`

## Agent Handoff

**Objective:** Author the App Insights provisioning walkthrough and provision the `dev` telemetry resource (App Insights + backing Log Analytics workspace + Vault connection string).

**Target:** Tracked against `HoneyDrunk.Architecture`; the Azure work is human-executed in the Azure Portal. `Actor=Human` — `human-only` label set. The walkthrough doc lands in `infrastructure/walkthroughs/`.

**Context:**
- Goal: Stand up the `dev` Application Insights resource so the Pulse telemetry-export implementation (packets 03–05, 07) has a real backend to ship to and test against.
- Feature: ADR-0040 Telemetry Backend and Retention rollout, Wave 1.
- ADRs: ADR-0040 D1/D3/D10 (primary), ADR-0005 (Key Vault naming, Vault-as-only-secret-source), ADR-0033 (staging/prod environments still in flight — `dev` only here).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0040 should be Accepted before its backend is provisioned.

**Constraints:**
- `dev` only — staging/prod are deferred per ADR-0033.
- Workspace-based App Insights, not classic.
- Connection string into Vault — never in the repo, never in a config file (invariants 8, 9).
- Portal-only UI walkthrough — no Bicep/ARM/CLI.
- Cheapest viable tier — Pay-As-You-Go, low daily cap; show cost before Create.

**Key Files:**
- `infrastructure/walkthroughs/application-insights-provisioning.md` (new)
- `catalogs/grid-health.json`

**Contracts:** None — Azure resources, no code.
