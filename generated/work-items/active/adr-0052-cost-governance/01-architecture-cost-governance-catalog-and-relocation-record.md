---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0052", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0052", "ADR-0016"]
accepts: ["ADR-0052"]
wave: 1
initiative: adr-0052-cost-governance
node: honeydrunk-architecture
---

# Record the cost-governance contract surface and the ICostLedger Kernel relocation in catalogs

## Summary
Record ADR-0052's contract decisions as catalog data: register the new cost-governance contracts (`ICostLedger`, `CostEvent`, `CostCategory`, `BudgetExceededException`, `BudgetOverride`, supporting record types) in `catalogs/contracts.json` under the **Kernel** Node per ADR-0052 D7, and mark the existing `ICostLedger` entry under `honeydrunk-ai` as **relocating-to-kernel** so the catalog reflects the relocation pending packets 03/04. Record the D8 capture-vs-log boundary for cost events and the D13 cross-ADR links where the Grid keeps cross-cutting policy notes.

## Context
ADR-0052 D7 commits `ICostLedger` to **`HoneyDrunk.Kernel`** (the abstraction only — interface, event shape, exception types, configuration record). This is consistent with the Kernel-thin-shell principle: Kernel owns the contract every Node consumes, no concrete implementation. The concrete implementation lives in **`HoneyDrunk.AI` for v1** (D7), and graduates to a dedicated `HoneyDrunk.CostLedger` Node when non-AI categories grow material or a second writer Node appears.

**Catalog reality at edit time:** `catalogs/contracts.json` already carries an `ICostLedger` entry under `honeydrunk-ai`:

```
{ "name": "ICostLedger", "kind": "interface",
  "description": "Per-call token and cost accounting surface. Cost-rate tables sourced from Azure App Configuration via Vault's IConfigProvider — never hardcoded." }
```

The implementing code is `HoneyDrunk.AI.Abstractions/ICostLedger.cs` (live, two members: `RecordAsync(InferenceCost)` and `GetSummaryAsync(scope, since)`). ADR-0052 D7's preview shape is **wider** (five members: `RecordCostAsync(CostEvent)`, `GetMonthToDateAsync(category)`, `IsHardCapBreachedAsync(category)`, `GetActiveOverrideAsync(category)`, `QueryAsync(query)`) and **carries a category-scoped, cross-cost-source event model** rather than an inference-only one. The new contract is the canonical one going forward; the existing AI-side contract becomes a wrapper or is removed entirely in packet 04. This packet records the relocation in the catalog ahead of the code change.

**Catalog schema ground truth — read before editing.**
- `catalogs/contracts.json` has the shape `{_meta, contracts:[{node, node_name, package, status, interfaces:[...]}]}`. The `honeydrunk-kernel` entry already exists; add the new cost-governance contracts to its `interfaces` list (or, if the catalog convention separates packages, a `HoneyDrunk.Kernel.Abstractions` Kernel entry — match the existing convention).
- `catalogs/grid-health.json` node entries carry **only** `signal`/`version`/`canary_status`/`last_release`/`active_blockers`/`notes` (plus a top-level `_meta` and `summary`). There is **no** cost/budget readout in `grid-health.json`, and **no place** for per-category cap state. **Do not edit `grid-health.json` in this packet** — the daily-roll-up signal and cap state live in the ledger and the monthly report (D9), not the grid-health catalog.
- `catalogs/nodes.json` has no `exposes` field; node exposure lives in `relationships.json`. This packet does not touch either.

**No new Azure resource registered here.** ADR-0052 D8 uses Cosmos (single-region, write-mostly) but the Cosmos account / container is provisioned by the AI Node's standup (ADR-0016) or as a follow-up — not in this catalog packet. The Bicep that defines the App Insights anomaly alert rules (D10) is also out of scope here; it lands in a deferred packet gated on ADR-0018 Operator scaffold.

**Cost-budgets file pointer.** ADR-0052 D2 names `business/context/cost-budgets.json` as the budget config. That file is created in packet 02; this packet's catalog work points at it as the canonical location, but does not create it.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/contracts.json` — register the cost-governance contract surface under `honeydrunk-kernel` (per ADR-0052 D7); mark the existing `ICostLedger` under `honeydrunk-ai` as relocating to Kernel pending packets 03/04.
- A cross-cutting policy note for the D7 implementation home / promotion path and the D13 cross-ADR links — placed where the Grid keeps such notes (match the existing convention).

## Proposed Implementation
1. **`catalogs/contracts.json` — register the Kernel contracts.** Add to the `honeydrunk-kernel` Node's `interfaces` list:
   - `ICostLedger` (interface) — the cost ledger contract per ADR-0052 D7. Five members per the D7 preview: `RecordCostAsync(CostEvent)`, `GetMonthToDateAsync(category)`, `IsHardCapBreachedAsync(category)`, `GetActiveOverrideAsync(category)`, `QueryAsync(query)`. Describe it as the Grid's single source of truth for cost accounting and the hot-path kill-switch read; lives in `HoneyDrunk.Kernel.Abstractions`; v1 implementation lives in `HoneyDrunk.AI` per D7. Mark `planned` if the catalog tracks per-interface status (packet 03 lands the code).
   - `CostEvent` (record) — the cost-event shape; carries `Category`, `Amount`, `Timestamp`, `Source` (discriminated: `LlmInferenceSource` / `AzureInfraSource` / `SaasSource` / `CiSource` / `DomainSource`), optional `TenantId` (per ADR-0026, D5), optional `AgentId` / `AgentRunId` (D6), `Environment` (D12), and a `CorrelationId`.
   - `CostCategory` (enum-shaped record or enum) — the five categories per ADR-0052 D1: `AiInference`, `AzureInfrastructure`, `ThirdPartySaas`, `DomainCertRegistrar`, `GitHubActionsMinutes`.
   - `BudgetExceededException` (exception type) — the kill-switch synchronous throw per D4; sealed; non-transient; carries category / cap / actual / correlation id.
   - `BudgetOverride` (record) — operator override per D11; carries the category, operator identity, reason text, issued-at, expires-at, and a revoke timestamp if revoked early.
   - `IBudgetConfigProvider` (interface) — abstracts reading `business/context/cost-budgets.json` (or its runtime equivalent loaded via Vault's `IConfigProvider` per ADR-0016 D5). Single member: `ValueTask<BudgetConfig> GetAsync(CancellationToken)`. Returns the per-category soft/hard caps and the per-category anomaly thresholds.
   - `BudgetConfig` (record) — the resolved budget configuration shape: per-category soft cap, hard cap, anomaly multipliers (hour-over-hour, day-over-day); per-environment overlay for the D12 dev caps.
   - `CostQuery` (record) — the query shape `QueryAsync` consumes: category, date range, optional `TenantId` / `AgentId` filters.
   Match the existing per-interface shape on the `honeydrunk-kernel` `contracts.json` record.
2. **`catalogs/contracts.json` — record the relocation on the AI entry.** Mark the existing `honeydrunk-ai` `ICostLedger` entry. Two acceptable shapes — match whatever convention `contracts.json` uses for relocating contracts (check the file at edit time):
   - Option A: amend the existing entry's description to read "**Relocating to `HoneyDrunk.Kernel.Abstractions` per ADR-0052 D7 (packet 03). After packet 04, this entry is removed.**" and append `"status": "relocating"` if the catalog convention supports per-interface status.
   - Option B: leave the existing entry as-is and add a `_relocations` block at the top level (if `contracts.json` already has one) recording the move from `honeydrunk-ai` to `honeydrunk-kernel`.
   Pick whichever option matches the existing file convention; do not invent a new shape. **Do not delete the AI entry in this packet** — packets 03 and 04 are the code-level relocation; the catalog mirrors the code, and a catalog entry that names a non-existent contract is a worse defect than a relocation note.
3. **No `grid-health.json` edit.** That file's node-entry schema has no cost / budget readout — see the schema note. Skip it entirely.
4. **D7 implementation-home note** — record the implementation-home decision and the promotion path (Kernel-abstraction / AI-implementation v1; graduates to `HoneyDrunk.CostLedger` Node when non-AI categories grow material or a second writer appears) as a cross-cutting policy note in the Grid's established location for such notes.
5. **D13 cross-ADR links** — record the ADR-0052 ↔ ADR-0016 (operator-configurable rates), ADR-0030 (override audit), ADR-0037 (per-tenant attribution), ADR-0041 (model approval gate vs spend gate), ADR-0045 (`IErrorReporter` surface), ADR-0018 (Operator hosts the CLI/aggregator/dashboard), ADR-0036 (tier-2 backup), ADR-0026 (`TenantId`) cross-links. Match the existing convention for cross-cutting cross-ADR notes.

## Affected Files
- `catalogs/contracts.json`
- A cost-governance policy note in the established cross-cutting-notes location (D7 implementation home + D13 cross-ADR links).

## NuGet Dependencies
None. This packet touches only catalog JSON and Markdown; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data only — the contract code lands in packet 03; the AI-side relocation lands in packet 04.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers `ICostLedger`, `CostEvent`, `CostCategory`, `BudgetExceededException`, `BudgetOverride`, `IBudgetConfigProvider`, `BudgetConfig`, `CostQuery` under the `honeydrunk-kernel` Node, each described per the D7 preview shape, marked `planned` if the catalog tracks per-interface status
- [ ] The existing `ICostLedger` entry under `honeydrunk-ai` is marked as relocating to Kernel (per ADR-0052 D7), using the existing catalog convention; the entry is **not** deleted in this packet (packets 03/04 do the code move; the catalog reflects code state)
- [ ] `catalogs/grid-health.json` is **not** edited — its node-entry schema has no cost/budget readout
- [ ] The D7 implementation home (`HoneyDrunk.Kernel` abstraction + `HoneyDrunk.AI` v1 implementation) and the promotion path to a dedicated `HoneyDrunk.CostLedger` Node are recorded as a cross-cutting policy note in the Grid's established location
- [ ] The D13 cross-ADR links (ADR-0016, ADR-0018, ADR-0026, ADR-0030, ADR-0036, ADR-0037, ADR-0041, ADR-0045) are recorded in the cross-cutting notes
- [ ] No invariant change in this packet (the three cost-governance invariants land in packet 00)
- [ ] No `business/context/cost-budgets.json` in this packet (packet 02)
- [ ] No `generated/cost-reports/` directory in this packet (packet 07)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0052 D7 — `ICostLedger` lives in `HoneyDrunk.Kernel`; v1 implementation in `HoneyDrunk.AI`.** Kernel owns the contract every Node consumes, no concrete implementation (Kernel-thin-shell principle). AI hosts the v1 implementation because AI inference is the dominant cost line, AI already owns the dispatcher and token-rate configuration (ADR-0016 D5), and co-locating means the kill-switch read is in-process with the dispatcher. Non-AI categories (Azure infra, SaaS, CI, domain/cert) are externally sourced via the Operator aggregator (D14 Phase 2) writing the same `ICostLedger` shape. Promotion: when non-AI categories grow material, or when a second writer appears, `HoneyDrunk.CostLedger` graduates to its own Node — interface in Kernel unchanged.

**ADR-0052 D7 preview shape.** `RecordCostAsync(CostEvent)`, `GetMonthToDateAsync(category)`, `IsHardCapBreachedAsync(category)`, `GetActiveOverrideAsync(category)`, `QueryAsync(query)`. Final method names and shapes are finalized in packet 03.

**ADR-0052 D1 — Five cost categories.** Azure infrastructure, AI inference, third-party SaaS, domain/cert/registrar, GitHub Actions minutes. No cross-subsidy.

**ADR-0052 D5 / D6 — `TenantId` / `AgentId` / `AgentRunId` dimensions.** Every cost event carries an optional `TenantId` (ADR-0026's opaque primitive). AI inference events additionally carry `AgentId` (ADR-0051's stable identifier) and `AgentRunId` (per-invocation correlation).

**ADR-0052 D12 — `Environment` dimension.** Every event carries an `Environment` field (`prod` / `dev` / `staging` / `local`). Local events are recorded but exempt from caps.

**ADR-0052 D13 cross-ADR links.** ADR-0016 (operator-configurable rates), ADR-0018 (Operator hosts CLI/aggregator/dashboard), ADR-0026 (TenantId), ADR-0030 (override audit), ADR-0036 (tier-2 backup), ADR-0037 (per-tenant attribution → future Billing Node), ADR-0041 (model approval gate; this ADR is the spend gate), ADR-0045 (`IErrorReporter` surface for breach events).

## Constraints
- **Match existing catalog conventions.** The new Kernel entries mirror the existing per-interface entries on the `honeydrunk-kernel` `contracts.json` record. Do not invent fields the catalog does not use.
- **Do not delete the AI `ICostLedger` entry.** This packet records the relocation; the code move lands in packets 03/04. Deleting the entry ahead of the code would leave the catalog ahead of the live shape — a worse defect than a relocation note. Packet 04 removes the entry as part of the AI-side migration.
- **Do not edit `grid-health.json`.** Its node-entry schema has no cost/budget readout.
- **No invented contract members.** The cost-governance shapes are the D7 preview; do not add fields or methods beyond what the ADR names.
- **No `cost-budgets.json` in this packet.** The config file lands in packet 02.
- **No App Insights resource entry.** ADR-0052 D2 anomaly alerts reuse ADR-0040's App Insights resource; this packet adds no resource entry.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0052`, `wave-1`

## Agent Handoff

**Objective:** Register the cost-governance contracts in `catalogs/contracts.json` under the Kernel Node, mark the existing AI `ICostLedger` entry as relocating, and record the D7 implementation home and D13 cross-ADR links.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Record ADR-0052's contract surface and the relocation of `ICostLedger` from AI to Kernel as catalog data, ahead of the code change in packets 03/04.
- Feature: ADR-0052 Cost Governance rollout, Wave 1.
- ADRs: ADR-0052 D1/D5/D6/D7/D12/D13 (primary), ADR-0016 (the operator-configurable rates D5 ties to).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0052 should be Accepted before its decisions are recorded as catalog data.

**Constraints:**
- Register the new contracts under `honeydrunk-kernel`, matching the existing per-interface shape.
- Mark — do not delete — the existing AI `ICostLedger` entry; packet 04 deletes it as part of the AI-side migration.
- No invented contract members; the cost-governance shapes are the D7 preview.
- Do not edit `grid-health.json`; its node-entry schema has no cost/budget readout.

**Key Files:**
- `catalogs/contracts.json`
- The cross-cutting-notes location (for the D7 implementation-home and D13 cross-ADR notes).

**Contracts:** `ICostLedger`, `CostEvent`, `CostCategory`, `BudgetExceededException`, `BudgetOverride`, `IBudgetConfigProvider`, `BudgetConfig`, `CostQuery` registered as catalog metadata under the Kernel Node (the code is packet 03).
