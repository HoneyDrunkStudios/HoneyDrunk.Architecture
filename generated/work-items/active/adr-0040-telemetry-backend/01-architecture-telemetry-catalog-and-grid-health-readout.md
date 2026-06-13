---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0040", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0040"]
accepts: ["ADR-0040"]
wave: 1
initiative: adr-0040-telemetry-backend
node: honeydrunk-architecture
---

# Record the telemetry backend and retention policy in the Grid catalogs and grid-health readout

## Summary
Record ADR-0040's backend choice and retention policy as catalog data: add the App Insights resources and their per-environment provisioning state to `catalogs/grid-health.json`, register the new `HoneyDrunk.Telemetry.Sampling` package (and the extension of the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider) in `catalogs/relationships.json`, and document the three-signal retention policy where the Grid keeps cross-cutting policy notes.

## Context
ADR-0040 D1 names Application Insights as the telemetry backend with per-environment resources (`hd-dev`, `hd-staging`, `hd-prod`). The "Affected Nodes" section explicitly states: "`HoneyDrunk.Architecture` — `catalogs/grid-health.json` is the readout surface; alert routing list lives in `business/context/`."

This packet makes the catalog reflect that decision so the provisioning state (packet 02), the implementation state (packets 03–05, 07), and the retention configuration (packet 06) have a readout surface to update. It also registers the new `HoneyDrunk.Telemetry.Sampling` package ADR-0040 D4 names so the dependency graph stays accurate.

**Catalog schema ground truth — read before editing.**
- `catalogs/nodes.json` node entries have **only** these fields: `id, type, name, public_name, short, description, sector, signal, cluster, energy, priority, flow, tags, links, long_description, foundational, strategy_base, tier, time_pressure, done, cooldown_days`. There is **no `exposes`, no `packages_planned`, no `version`, no `consumes`** field on a `nodes.json` entry. Do not edit `nodes.json` for package registration — it has nowhere to put a package.
- The `exposes` object (with `contracts` and `packages` / `packages_planned` arrays) lives in **`catalogs/relationships.json`**, under each node's relationship entry. The `honeydrunk-pulse` entry there has `exposes.contracts: ["ITraceSink", "ILogSink", "IMetricsSink"]` and `exposes.packages: ["HoneyDrunk.Pulse.Contracts", "HoneyDrunk.Telemetry.Abstractions", "HoneyDrunk.Telemetry.OpenTelemetry"]`. **`HoneyDrunk.Telemetry.Sink.AzureMonitor` already exists in the Pulse solution** (alongside `Sink.Loki`, `Sink.Mimir`, `Sink.Tempo`, `Sink.Sentry`, `Sink.PostHog`, `Sink.Shared`) — packet 03 *extends* it, it is not a new package.
- `catalogs/grid-health.json` node entries carry `signal/version/canary_status/last_release/active_blockers/notes`. There is **no `sender_reputation_status` field** and no existing telemetry/observability readout — there is no precedent shape to mirror. The telemetry readout this packet adds is a genuinely new structure; define it explicitly (see Proposed Implementation), do not claim a phantom precedent.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/grid-health.json` — add a new, explicitly-defined telemetry/observability section recording the per-environment App Insights resources and their provisioning state, plus the retention policy.
- `catalogs/relationships.json` — add the new `HoneyDrunk.Telemetry.Sampling` package to the `honeydrunk-pulse` entry's `exposes.packages` array. `HoneyDrunk.Telemetry.Sink.AzureMonitor` is an existing solution project, not new — register it in `exposes.packages` as well if it is not already listed (it is part of the shipped Pulse solution).
- `catalogs/contracts.json` — if it exists and tracks per-Node contracts, no new contract is added by this initiative: packet 03 *extends an existing provider* (`HoneyDrunk.Telemetry.Sink.AzureMonitor`) against the existing Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`). No `IObservabilityBackend` contract is created. Make no `contracts.json` edit unless packet 03 confirms a genuinely new contract.
- A cross-cutting policy note for the three-signal retention windows — placed where the Grid keeps such notes (check for `business/context/`, an `infrastructure/reference/` dir, or a policy doc; match the existing convention rather than inventing a location).

## Proposed Implementation
1. **`catalogs/grid-health.json`** — add a new, explicitly-defined observability/telemetry readout entry. There is no existing precedent field — define the structure: an array of per-environment App Insights resource entries, each with an `environment`, a `resource_name`, a `status` enum (`not-provisioned` | `provisioned`), a `log_analytics_workspace` name, and a `retention_summary` string. Record the three v1 App Insights resources:
   - `dev` — `status: not-provisioned`
   - `staging` — `status: not-provisioned`
   - `prod` — `status: not-provisioned`
   Each entry's `retention_summary` records traces 90d / metrics 93d / logs 90d standard, 730d Audit table. Packet 02 flips the `dev` resource to `provisioned`; packet 06 records the Audit-table retention as configured. The concrete `resource_name` values follow the Grid's `hd` Azure naming scheme — use a placeholder name and a note if packet 02 has not finalized them yet.
2. **`catalogs/relationships.json`** — in the `honeydrunk-pulse` relationship entry, append `HoneyDrunk.Telemetry.Sampling` to the `exposes.packages` array. Confirm `HoneyDrunk.Telemetry.Sink.AzureMonitor` is present in `exposes.packages` (it is a shipped solution project); add it if missing. Do **not** edit `honeydrunk-observe` — ADR-0040's amendment moves this work out of Observe; Observe is unaffected.
3. **`catalogs/contracts.json`** — no edit. This initiative adds no new contract; packet 03 extends the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider against the existing `ITraceSink`/`ILogSink`/`IMetricsSink` contracts. If packet 03's reconciliation reveals a genuinely new contract, packet 03 updates `contracts.json` itself.
4. **Retention policy note** — record the D3 table (traces 90d / metrics 93d / logs 90d-standard-730d-Audit) and the D10 cost ceiling ($100/month) as a cross-cutting policy note in the established location.

## Affected Files
- `catalogs/grid-health.json`
- `catalogs/relationships.json` — the `honeydrunk-pulse` entry's `exposes.packages` array.
- A retention/cost policy note in the established cross-cutting-notes location.

## NuGet Dependencies
None. This packet touches only catalog JSON and Markdown; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data only — the Pulse code itself lands in packets 03–05, 07.

## Acceptance Criteria
- [ ] `catalogs/grid-health.json` carries a new, explicitly-defined observability/telemetry readout with the three per-environment App Insights resources seeded at `status: not-provisioned`, each tracking environment, resource name, backing Log Analytics workspace, and retention summary
- [ ] `catalogs/relationships.json` `honeydrunk-pulse` entry's `exposes.packages` array lists `HoneyDrunk.Telemetry.Sampling` (and `HoneyDrunk.Telemetry.Sink.AzureMonitor` if it was missing) — no `honeydrunk-observe` edit
- [ ] No `catalogs/nodes.json` edit — `nodes.json` entries have no package field; package registration is a `relationships.json` concern
- [ ] No `catalogs/contracts.json` edit — this initiative adds no new contract (packet 03 extends an existing provider against existing `ITraceSink`/`ILogSink`/`IMetricsSink`)
- [ ] The three-signal retention policy and the $100/month cost ceiling are recorded as a cross-cutting policy note in the established location
- [ ] No invariant change in this packet (invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0040 D1 — Backend: Azure Monitor + Application Insights.** Per-environment App Insights resources (`hd-dev`, `hd-staging`, `hd-prod`) keep dev noise out of prod dashboards. Resources provisioned via the Azure Portal; connection strings live in Vault per ADR-0005.

**ADR-0040 D3 — Three signal types, three retention windows.** Traces 90 days (Log Analytics workspace). Metrics 93 days (App Insights metrics). Logs 90 days standard / 730 days for Audit-sourced logs. One Log Analytics workspace, a custom table for Audit-sourced logs with a long per-table retention policy.

**ADR-0040 D10 — Cost ceiling.** Realistic v1 cost $0–30/month; $100/month ceiling before reconsideration; tracked in `business/context/`; two consecutive months over the ceiling triggers an ADR amendment.

**ADR-0040 Affected Nodes.** "`HoneyDrunk.Architecture` — `catalogs/grid-health.json` is the readout surface; alert routing list lives in `business/context/`."

## Constraints
- **`HoneyDrunk.Telemetry.Sink.AzureMonitor` already exists.** It is a shipped project in the Pulse solution — packet 03 *extends* it; it is not a new package. The only genuinely new package is `HoneyDrunk.Telemetry.Sampling`.
- **Edit `relationships.json`, not `nodes.json`.** `nodes.json` entries have no package field. Package registration lives in `catalogs/relationships.json` under the `honeydrunk-pulse` entry's `exposes.packages`.
- **No invented catalog structure.** There is no `sender_reputation_status` field and no telemetry precedent in `grid-health.json` — the telemetry readout is a new structure; define it explicitly, do not claim a phantom precedent.
- **Observe is unaffected.** ADR-0040's 2026-05-22 amendment moved this work to Pulse. Do not edit the `honeydrunk-observe` relationship entry.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0040`, `wave-1`

## Agent Handoff

**Objective:** Record ADR-0040's backend, the new `HoneyDrunk.Telemetry.Sampling` package, and the retention policy in the Grid catalogs and grid-health readout.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the provisioning (packet 02), implementation (03–05, 07), and retention-config (06) packets a catalog readout surface to update.
- Feature: ADR-0040 Telemetry Backend and Retention rollout, Wave 1.
- ADRs: ADR-0040 D1/D3/D10 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0040 should be Accepted before its backend is recorded as catalog data.

**Constraints:**
- Catalog schema ground truth: package registration lives in `relationships.json` `exposes`, not `nodes.json`. `grid-health.json` has no telemetry precedent — define a new structure.
- `HoneyDrunk.Telemetry.Sink.AzureMonitor` already exists in the Pulse solution; only `HoneyDrunk.Telemetry.Sampling` is new.
- No `contracts.json` edit — no new contract in this initiative.
- Do not edit the `honeydrunk-observe` entry — Observe is unaffected.

**Key Files:**
- `catalogs/grid-health.json`
- `catalogs/relationships.json`

**Contracts:** None changed — this packet only records metadata.
