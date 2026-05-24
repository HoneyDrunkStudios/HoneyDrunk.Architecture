---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0069", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0069"]
accepts: ["ADR-0069"]
wave: 1
initiative: adr-0069-currency-handling
node: honeydrunk-architecture
---

# Register the Money / CurrencyCode contract surface in the Grid catalogs

## Summary
Record ADR-0069's new contract surface as catalog data: register `Money`, `CurrencyCode`, `CurrencyMismatchException`, and `UnknownCurrencyCodeException` under the `honeydrunk-kernel` Node in `catalogs/contracts.json` (appended to that node block's `interfaces` array), and append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array in `catalogs/relationships.json`. Update the `consumes_detail` for the Nodes that gain a new dependency on the contract — at this initiative's scope, only `honeydrunk-ai` consumes it as part of packet 03 (the cost-ledger migration to D10). The Web.Rest converter wiring in packet 05 consumes the same Kernel contracts already broadcast on its existing edge, so the type names are added to its `consumes_detail` too.

## Context
ADR-0069 D1/D9 add new contract types to `HoneyDrunk.Kernel.Abstractions`: the `Money` record (carrying `decimal Amount` and a `CurrencyCode`), the `CurrencyCode` record struct (an ISO 4217 alpha-3 validated value), and two exception types (`CurrencyMismatchException` for D2's currency-mismatch arithmetic, `UnknownCurrencyCodeException` for D4's construction failure). The Grid catalogs are the discoverability surface — `catalogs/contracts.json` registers each Node's contracts in its node block's `interfaces` array, and `catalogs/relationships.json` lists each Node's contract names under `exposes.contracts`. (Note: `catalogs/nodes.json` has **no** `exposes` field — the `exposes` object lives on relationships.json entries.)

The `MoneyJsonConverter` (D9's System.Text.Json converter) ships in the **`HoneyDrunk.Kernel` runtime package**, not `HoneyDrunk.Kernel.Abstractions` — invariant 1 keeps Abstractions free of runtime serialization classes (packet 02 owns this placement; the ADR-text says "ships in `HoneyDrunk.Kernel.Abstractions`" and is amended at acceptance in packet 00). As a converter, it is an implementation detail of the `Money` public type, not a separate contract surface — it is registered indirectly via the `Money` type's documented serialization shape. The `MoneyJsonConverter` class itself is **not** added as a separate `contracts.json` entry; the `consumes_detail` for `honeydrunk-web-rest` (which references the runtime package to register the converter) is captured at packet 05's wiring step, not as a new contract here.

This packet keeps both catalogs accurate so the implementation packets (02–05) and any downstream Node have an accurate contract/dependency graph to read.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/contracts.json` — locate the node block whose `node` value is `honeydrunk-kernel`; append the new contract entries from ADR-0069 D1/D2/D4 to that block's `interfaces` array.
- `catalogs/relationships.json` — append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array; and update the `consumes_detail` for `honeydrunk-ai` (packet 03 migrates `InferenceCost.EstimatedCost` and `CostSummary.TotalCost` from `decimal` to `Money`) and `honeydrunk-web-rest` (packet 05 wires the Money converter). No new top-level Node-to-Node edge is created — both Nodes already consume `HoneyDrunk.Kernel.Abstractions`.
- `catalogs/nodes.json` — **not edited.** nodes.json entries have no `exposes` field; the contract surface lives in relationships.json and contracts.json.

## Proposed Implementation
1. **`catalogs/contracts.json`** — locate the node block whose `node` value is `honeydrunk-kernel` (do not rely on line numbers; the file's existing entries for `IGridContext`, `TenantId`, `CorrelationId`, etc. are the precedent shape). Append entries to that block's `interfaces` array, matching the existing `{ "name", "kind", "description" }` shape:
   - `Money` — `kind: type` — "Record. Carries `decimal Amount` and a `CurrencyCode`. Internal representation of monetary values across the Grid. Arithmetic operators throw `CurrencyMismatchException` on cross-currency operations (no implicit FX). `Money.ToString()` returns locale-independent machine-readable text (e.g. `\"123.45 USD\"`). JSON shape is `{\"amount\": \"...\", \"currency\": \"...\"}` via the System.Text.Json converter shipped in the same package."
   - `CurrencyCode` — `kind: type` — "Readonly record struct. ISO 4217 alpha-3 currency code (uppercase). Construction validates against the seed list (USD, EUR, GBP, JPY, CAD, AUD, CHF); unknown codes throw `UnknownCurrencyCodeException`. Per-currency metadata (default decimal places — 2 for fiat, 3 for JOD/BHD/KWD/OMR/TND, 0 for JPY) lives alongside the codes."
   - `CurrencyMismatchException` — `kind: type` — "Thrown by `Money` arithmetic and comparison operators when two `Money` operands carry different `CurrencyCode` values. No implicit FX conversion."
   - `UnknownCurrencyCodeException` — `kind: type` — "Thrown by `CurrencyCode` construction when the input is not in the seed list of supported ISO 4217 alpha-3 codes."
   - Drop the leading `I` from these names — `Money`, `CurrencyCode`, `CurrencyMismatchException`, `UnknownCurrencyCodeException` are records / record structs / exception classes, never interfaces.
   - Do **not** add `MoneyJsonConverter` as a separate entry — it is an implementation detail of `Money`, not a public contract.
2. **`catalogs/relationships.json`** — append `Money`, `CurrencyCode`, `CurrencyMismatchException`, `UnknownCurrencyCodeException` to the `honeydrunk-kernel` entry's `exposes.contracts` array. Do not touch existing entries. Then:
   - For `honeydrunk-ai`, extend `consumes_detail["honeydrunk-kernel"]` with `Money`, `CurrencyCode` (packet 03 migrates the cost ledger).
   - For `honeydrunk-web-rest`, extend `consumes_detail["honeydrunk-kernel"]` with `Money` (packet 05 wires the converter).
   - Do not add a new top-level edge — `consumed_by`/`consumes` lists already include all four Nodes.
3. **`catalogs/nodes.json`** — no edit. nodes.json has no `exposes` field; do not invent one.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`

## NuGet Dependencies
None. This packet touches only catalog JSON; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data only — the Kernel/AI/Web.Rest code lands in packets 02, 03, 05.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers `Money`, `CurrencyCode`, `CurrencyMismatchException`, `UnknownCurrencyCodeException` in the `honeydrunk-kernel` node block's `interfaces` array, matching the existing entry shape
- [ ] `MoneyJsonConverter` is NOT added as a separate contracts.json entry (it is an implementation detail of `Money`, not a public contract)
- [ ] `catalogs/relationships.json` `honeydrunk-kernel` entry lists `Money`, `CurrencyCode`, `CurrencyMismatchException`, `UnknownCurrencyCodeException` in `exposes.contracts`, with all existing entries untouched
- [ ] `catalogs/relationships.json` `consumes_detail["honeydrunk-kernel"]` for `honeydrunk-ai` lists `Money`, `CurrencyCode`; for `honeydrunk-web-rest` lists `Money`
- [ ] `catalogs/nodes.json` is NOT modified (it has no `exposes` field)
- [ ] No new top-level Node-to-Node edge is created (the dependency on `HoneyDrunk.Kernel.Abstractions` already exists for both Nodes)
- [ ] No invariant change in this packet (ADR-0069 adds no numbered invariants — see packet 00's "On invariants" section)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0069 D1 — `Money` placement.** A new public record `Money` and a `readonly record struct CurrencyCode` live in `HoneyDrunk.Kernel.Abstractions.Money` (or a similarly-named namespace settled by packet 02). Both are net-new public surface; both are records (drop the `I`).

**ADR-0069 D2 — `CurrencyMismatchException`.** Arithmetic and comparison operators on `Money` throw `CurrencyMismatchException` when the two operands' `CurrencyCode` values differ. No implicit FX conversion.

**ADR-0069 D4 — `UnknownCurrencyCodeException`.** `CurrencyCode` construction with a code not on the seed list throws `UnknownCurrencyCodeException` at the point of construction.

**ADR-0069 D9 (amended at acceptance — see packet 00) — `MoneyJsonConverter` ships in `HoneyDrunk.Kernel` (runtime).** The ADR text says "ships in `HoneyDrunk.Kernel.Abstractions`" but the converter is runtime serialization logic and invariant 1 keeps Abstractions free of it. Packet 02 places `MoneyJsonConverter` in the runtime package; packet 00 amends D9's wording at acceptance. As an implementation detail it is **not** a separate catalog entry — its presence is documented by `Money`'s description.

**ADR-0069 D10 — AI cost-ledger Money adoption.** ADR-0052's in-memory cost-rate cache is updated to `Money(rate, CurrencyCode.Usd)` — this is the `honeydrunk-ai` consumer added to `consumes_detail`.

## Constraints
- **Records drop the `I`.** `Money`, `CurrencyCode`, `CurrencyMismatchException`, `UnknownCurrencyCodeException` — no `I` prefix.
- **Do not register `MoneyJsonConverter` separately.** It is an implementation detail of `Money`. Documenting `Money`'s JSON shape in its description is sufficient.
- **Do not register `Money.Zero` / `Money.Usd` / etc.** They are static factory members on `Money`, not separate contract entries.
- **No new Node-to-Node edge.** Both consuming Nodes already consume `HoneyDrunk.Kernel.Abstractions`. The contracts are additive; only `consumes_detail` is enriched.
- **nodes.json is NOT edited** — it has no `exposes` field; do not invent one.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0069`, `wave-1`

## Agent Handoff

**Objective:** Register ADR-0069's `Money`/`CurrencyCode` contract surface in the Grid catalogs.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the contract/dependency catalogs accurate so implementation packets 02–05 read a correct graph.
- Feature: ADR-0069 Currency Handling rollout, Wave 1.
- ADRs: ADR-0069 D1/D2/D4/D9/D10 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0069 should be Accepted before its contract surface is recorded as catalog data.

**Constraints:**
- Records drop the `I`; `Money`/`CurrencyCode` are records / record structs.
- Do not register `MoneyJsonConverter` as a separate entry — it is an implementation detail.
- Do not register static factory members (`Money.Zero`, `Money.Usd`) — they are not separate contracts.
- No new top-level Node-to-Node edge — only `consumes_detail` enrichment.
- nodes.json is NOT edited — it has no `exposes` field.

**Key Files:**
- `catalogs/contracts.json` — new entries in the `honeydrunk-kernel` block's `interfaces` array.
- `catalogs/relationships.json` — `honeydrunk-kernel` `exposes.contracts` + `consumes_detail` enrichment for `honeydrunk-ai` and `honeydrunk-web-rest`. nodes.json is NOT touched.

**Contracts:** None changed — this packet only records catalog metadata for contracts that packet 02 implements.
