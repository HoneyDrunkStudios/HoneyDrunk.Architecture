---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ai", "docs", "adr-0041", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0041"]
accepts: ["ADR-0041"]
wave: 1
initiative: adr-0041-model-registry
node: honeydrunk-architecture
---

# Register the model-registry contract surface and AI Abstractions additions in the Grid catalogs

## Summary
Record ADR-0041's new contract surface as catalog data: append `IModelRegistry`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`, and `IApprovalStateWriter` to the `interfaces` array of the `honeydrunk-ai` block in `catalogs/contracts.json`, append the new type names to the `honeydrunk-ai` entry's `exposes.contracts` array in `catalogs/relationships.json`, and record the model-registry approval-workflow policy (provider set, approval lifecycle, canary cadence) as a cross-cutting AI-sector policy note.

## Context
ADR-0041 D1 adds a new interface `IModelRegistry` and five new records/enums to `HoneyDrunk.AI.Abstractions`. The Grid catalogs are the discoverability surface. **Catalog schema ground truth — verify before editing:**
- `catalogs/contracts.json` has shape `{ "_meta": {...}, "contracts": [ { "node", "node_name", "package", "status", "interfaces": [...] } ] }`. Each Node has one block; new contract types append to that block's `interfaces` array. The `honeydrunk-ai` block already registers the Node's contracts (`IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`, etc.).
- `catalogs/relationships.json` carries the dependency graph; each Node entry has the keys `id, consumes, consumed_by, consumed_by_planned, blocked_by, exposes, consumes_detail`. The `exposes` object contains a `contracts` array. **This is where the exposed-contract list lives — `catalogs/nodes.json` has no `exposes` field at all.**
- `catalogs/nodes.json` carries Node versions and metadata only — it is NOT touched by this packet.

This packet keeps the contracts catalog and the relationships graph accurate so the implementation packets (02–05) and any downstream AI-sector standup have an accurate dependency/contract graph to read.

ADR-0041 D2 also defines an approval-workflow policy (the initial approved provider set, the `Preview`/`Approved`/`Deprecated` lifecycle, the 14-day preview window, the asymmetry between adding a provider vs. adding a model). That policy is cross-cutting AI-sector governance and should be recorded where the Grid keeps such notes so future "add a model" packets have a canonical reference.

ADR-0041's Consequences section also names `catalogs/ai-models.json` (an optional Grid-wide mirror of `models.json`) as **deferred to a follow-up** — do NOT create it in this packet.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/contracts.json` — locate the `honeydrunk-ai` block by its `node` value and append the seven new contract entries to that block's `interfaces` array.
- `catalogs/relationships.json` — append the new type names to the `honeydrunk-ai` entry's `exposes.contracts` array.
- A cross-cutting AI-sector policy note for the approval workflow — placed where the Grid keeps such notes (match the existing convention; check `business/context/`, an `infrastructure/reference/` dir, or an existing AI-sector policy doc rather than inventing a location).

## Proposed Implementation
1. **`catalogs/contracts.json`** — locate the `honeydrunk-ai` block by its `node` value (`"node": "honeydrunk-ai"`); do not rely on line numbers — the file shifts. Append seven entries to that block's `interfaces` array, matching the shape of the entries already in that `interfaces` array:
   - `IModelRegistry` — interface — "Source of truth for registered models. Exposes GetRegistered, GetById, and GetByCapability over the declarative models.json catalog."
   - `IApprovalStateWriter` — interface — "Constrained writer for the only runtime mutation of the registry: canary-driven ApprovalState flips. Cannot add or remove registrations."
   - `ModelRegistration` — record — "A registered model: ModelId, ProviderId, ModelCapabilityDeclaration, CostProfile, ApprovalState, RoutingHints."
   - `ProviderRegistration` — record — "A registered provider: name, transport, Vault auth reference, default headers, data-egress policy, retention, region policy."
   - `CostProfile` — record — "Per-token costs (input/output/cached) plus the MaxBudgetPerCallUsd per-call ceiling enforced by the router."
   - `ApprovalState` — enum — "Approved | Preview | Deprecated. Deprecated models stay queryable for replay but are rejected on new dispatch."
   - `RoutingHints` — record — "Opaque policy-axis hints consumed by IRoutingPolicy (latency tier, geographic preference); distinct from ModelCapabilityDeclaration which is capability-axis."
   - Read an existing entry in the `honeydrunk-ai` block's `interfaces` array first and mirror its exact field shape; do not invent a `{name,kind,description}` shape if the array uses different keys. Drop the leading `I` from record names per the Grid naming rule; interfaces keep the `I`.
2. **`catalogs/relationships.json`** — append `IModelRegistry`, `IApprovalStateWriter`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints` to the `honeydrunk-ai` entry's `exposes.contracts` array. Do not touch the existing entries. (`catalogs/nodes.json` is NOT touched — it has no `exposes` field; the exposed-contract list lives only in `relationships.json`.) Note: `models.json` is a data file inside the `HoneyDrunk.AI` package, not a separate package.
3. **Approval-workflow policy note** — record ADR-0041 D2/D3/D4 as a cross-cutting AI-sector policy note: the initial approved provider set (Anthropic, OpenAI, Azure OpenAI, `local` placeholder), the `Preview`/`Approved`/`Deprecated` lifecycle and its transition rules, the 14-day production preview window, the 60-day deprecation + 30-day no-traffic removal rule, and the provider-vs-model asymmetry (new provider = ADR amendment, new model = packet). Place it in the established cross-cutting-notes location.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- An AI-sector approval-workflow policy note in the established cross-cutting-notes location.

## NuGet Dependencies
None. This packet touches only catalog JSON and Markdown; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data only — the AI code itself lands in packets 02–05.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers all seven new contracts (`IModelRegistry`, `IApprovalStateWriter`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`) in the `honeydrunk-ai` block's `interfaces` array, matching the shape of the entries already in that array
- [ ] `catalogs/relationships.json` `honeydrunk-ai` entry lists all seven new type names in `exposes.contracts`, with all existing entries untouched
- [ ] `catalogs/nodes.json` is NOT modified (it has no `exposes` field)
- [ ] `models.json` is NOT registered as a package anywhere (it is a data file inside `HoneyDrunk.AI`)
- [ ] `catalogs/ai-models.json` is NOT created (deferred per ADR-0041 Consequences)
- [ ] The ADR-0041 D2/D3/D4 approval workflow is recorded as a cross-cutting AI-sector policy note in the established location
- [ ] No invariant change in this packet (invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0041 D1 — Registry contract surface.** `IModelRegistry` in `HoneyDrunk.AI.Abstractions` exposes `GetRegistered()`, `GetById(ModelId)`, `GetByCapability(CapabilityPredicate)`. New records: `ModelRegistration` (ModelId, ProviderId, ModelCapabilityDeclaration, CostProfile, ApprovalState, RoutingHints), `ProviderRegistration`, `CostProfile` (per-token costs + `MaxBudgetPerCallUsd`), `ApprovalState` enum (Approved/Preview/Deprecated), `RoutingHints`. Plus `IApprovalStateWriter` — the constrained writer.

**ADR-0041 D2 — Approved providers.** Initial set: Anthropic, OpenAI, Azure OpenAI, and a `local` placeholder (no models at v1). Adding a provider is an ADR amendment; adding a model under an approved provider is a packet.

**ADR-0041 D4 — Adding a model: packet workflow.** Register at `Preview` + add canary + CI gates on canary pass + 14-day production preview + follow-up packet flips to `Approved`. Removal is a `Deprecated` flip, then a separate packet after 60 days at `Deprecated` and 30 days of no router traffic.

**ADR-0041 Consequences.** "`HoneyDrunk.Architecture` — `catalogs/contracts.json` registers the new AI Abstractions surface; `catalogs/ai-models.json` (optional mirror of `models.json` for cross-Grid discoverability) deferred to a follow-up."

## Constraints
- **Catalog schema ground truth.** `catalogs/contracts.json` is `{_meta, contracts:[{node,node_name,package,status,interfaces:[...]}]}` — new types append to the matching Node block's `interfaces` array. The `exposes.contracts` array lives in `catalogs/relationships.json`, NOT `catalogs/nodes.json` (which has no `exposes` field). Locate the `honeydrunk-ai` block by its `node` value; do not trust line numbers.
- **Records drop the `I`, interfaces keep it.** Grid-wide naming rule: `ModelRegistration` (record), `IModelRegistry` (interface). `ApprovalState` is an enum — no `I`.
- **`models.json` is data, not a package.** It is a JSON file shipped inside the `HoneyDrunk.AI` package. Do not register it as a package.
- **Do not create `catalogs/ai-models.json`.** ADR-0041 explicitly defers the Grid-wide mirror to a follow-up.
- **`RoutingHints` is policy-axis, not capability-axis.** ADR-0041 D1 is explicit that `RoutingHints` is deliberately separate from `ModelCapabilityDeclaration`. Keep the catalog descriptions reflecting that distinction.

## Labels
`feature`, `tier-2`, `ai`, `docs`, `adr-0041`, `wave-1`

## Agent Handoff

**Objective:** Register ADR-0041's new contract surface and the approval-workflow policy in the Grid catalogs.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the contract/dependency catalogs accurate so implementation packets 02–05 and any downstream AI-sector standup read a correct graph.
- Feature: ADR-0041 AI Model Registry and Approval Workflow rollout, Wave 1.
- ADRs: ADR-0041 D1/D2/D4 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0041 should be Accepted before its contract surface is recorded as catalog data.

**Constraints:**
- Catalog schema: new contract types append to the `honeydrunk-ai` block's `interfaces` array in `catalogs/contracts.json`; the `exposes.contracts` array lives in `catalogs/relationships.json` (not `nodes.json`). Locate blocks by `node` value, not line number.
- Records drop the `I`; interfaces keep it; `ApprovalState` is an enum.
- `models.json` is a data file inside `HoneyDrunk.AI`, not a package.
- Do not create `catalogs/ai-models.json` — deferred.

**Key Files:**
- `catalogs/contracts.json`
- `catalogs/relationships.json`

**Contracts:** None changed — this packet only records metadata for contracts that packet 02 implements.
