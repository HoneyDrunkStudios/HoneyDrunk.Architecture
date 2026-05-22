---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0042", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0042"]
accepts: ["ADR-0042"]
wave: 1
initiative: adr-0042-idempotency-contract-for-async-boundaries
node: honeydrunk-architecture
---

# Register the idempotency contract surface in the Grid catalogs

## Summary
Record ADR-0042's new contract surface as catalog data: register `IGridMessageEnvelope`, `IIdempotencyStore`, `IdempotentMessageHandler<T>`, `IGridMessagePublisher`, `IPulseSignalEnvelope`, and the supporting records (`IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome`) under the `honeydrunk-kernel` Node in `catalogs/contracts.json` (appended to that node block's `interfaces` array), append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array in `catalogs/relationships.json`, and update the `consumes_detail` for the Nodes that gain a new dependency on the contract.

## Context
ADR-0042 D1/D2/D3/D5 add new contracts to `HoneyDrunk.Kernel.Abstractions`: the `IGridMessageEnvelope` envelope (with the `IdempotencyKey` property), the `IIdempotencyStore` dedup-state interface, the `IdempotentMessageHandler<T>` consumer base, the `IGridMessagePublisher` producer helper, and the `IPulseSignalEnvelope` carve-out type (D7). The Grid catalogs are the discoverability surface — `catalogs/contracts.json` registers each Node's contracts in its node block's `interfaces` array, and `catalogs/relationships.json` lists each Node's contract names under `exposes.contracts`. (Note: `catalogs/nodes.json` has **no** `exposes` field — the `exposes` object lives on relationships.json entries.) This packet keeps both catalogs accurate so the implementation packets (02–07) and any downstream Node have an accurate contract/dependency graph to read.

ADR-0042 D2 also names the default Cosmos-backed `IIdempotencyStore` implementation, shipped from `HoneyDrunk.Data`. Packet 03 ships it as `HoneyDrunk.Data.Idempotency.Cosmos` (and `HoneyDrunk.Data.Idempotency.InMemory`) — consistent with the existing `HoneyDrunk.Data.*` provider family. This packet records only the **contract** surface in `honeydrunk-kernel`; it does NOT register the Cosmos backing package. Packet 03 registers its own packages under `honeydrunk-data`.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/contracts.json` — locate the node block whose `node` value is `honeydrunk-kernel`; append the new contract entries from ADR-0042 D1/D2/D3/D5/D7 to that block's `interfaces` array.
- `catalogs/relationships.json` — append the new type names to the `honeydrunk-kernel` entry's `exposes.contracts` array; and update the `consumes_detail` for `honeydrunk-notify`, `honeydrunk-communications`, `honeydrunk-audit`, and `honeydrunk-data` to list the new Kernel contracts they consume, matching the existing `consumes_detail` shape. No new Node-to-Node *edge* is created (every affected Node already consumes `HoneyDrunk.Kernel.Abstractions`).
- `catalogs/nodes.json` — **not edited.** nodes.json entries have no `exposes` field; the contract surface lives in relationships.json and contracts.json.

## Proposed Implementation
1. **`catalogs/contracts.json`** — locate the node block whose `node` value is `honeydrunk-kernel` (do not rely on line numbers). Append entries to that block's `interfaces` array, matching the existing `{ "name", "kind", "description" }` shape:
   - `IGridMessageEnvelope` — `kind: interface` — "Envelope for async domain-event messages. Carries the mandatory IdempotencyKey in user-properties alongside Grid context. Additive to the existing Kernel envelope surface."
   - `IIdempotencyStore` — `kind: interface` — "Consumer-side dedup state, scoped per consumer-group. TryClaim / Read / Complete over IdempotencyKey to (FirstSeenAt, Outcome). Default backing is a small Cosmos container."
   - `IdempotentMessageHandler` — `kind: type` — "Abstract base encoding the claim, process, complete consumer pattern once for every async consumer. Generic over the message type."
   - `IGridMessagePublisher` — `kind: interface` — "Producer helper that publishes with retry and never regenerates the IdempotencyKey across retries."
   - `IPulseSignalEnvelope` — `kind: interface` — "Separate envelope for Pulse non-domain-event signals. Type-level carve-out from IGridMessageEnvelope; carries no IdempotencyKey and is exempt from the mandatory-key rule."
   - `IdempotencyKey` — `kind: type` — "Record. The opaque string idempotency key produced once at message origination. UUID v4 by default; deterministic keys allowed."
   - `IdempotencyClaim` — `kind: type` — "Record. A claim on an IdempotencyKey for a consumer-group: the key, claim timestamp, lease/TTL, and completion state."
   - `IdempotencyOutcome` — `kind: type` — "Record/enum. The recorded result of processing a claimed message (Succeeded, Failed) plus a small outcome payload for reply derivation."
   - Drop the leading `I` from record names per the Grid naming rule; interfaces keep the `I`. `IdempotentMessageHandler` is a class — no `I`.
2. **`catalogs/relationships.json`** — append `IGridMessageEnvelope`, `IIdempotencyStore`, `IdempotentMessageHandler`, `IGridMessagePublisher`, `IPulseSignalEnvelope`, `IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome` to the `honeydrunk-kernel` entry's `exposes.contracts` array. Do not touch existing entries. Then, for `honeydrunk-notify`, `honeydrunk-communications`, `honeydrunk-audit`, and `honeydrunk-data`, extend the `consumes_detail["honeydrunk-kernel"]` array with the new contract names each consumes (Notify/Communications consume `IGridMessageEnvelope`, `IGridMessagePublisher`, `IdempotentMessageHandler`; Audit consumes `IdempotentMessageHandler`, `IIdempotencyStore`; Data consumes `IIdempotencyStore` to implement the Cosmos backing). Do not add a new top-level edge — the `honeydrunk-kernel` `consumed_by` list already includes all four.
3. **`catalogs/nodes.json`** — no edit. nodes.json has no `exposes` field; do not invent one.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`

## NuGet Dependencies
None. This packet touches only catalog JSON; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data only — the Kernel/Data/Notify/Communications code lands in packets 02–07.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers all eight new contracts in the `honeydrunk-kernel` node block's `interfaces` array, matching the existing entry shape
- [ ] `catalogs/relationships.json` `honeydrunk-kernel` entry lists all eight new type names in `exposes.contracts`, with all existing entries untouched
- [ ] `catalogs/relationships.json` `consumes_detail` for `honeydrunk-notify`, `honeydrunk-communications`, `honeydrunk-audit`, `honeydrunk-data` lists the new Kernel contracts each consumes
- [ ] `catalogs/nodes.json` is NOT modified (it has no `exposes` field)
- [ ] No new top-level Node-to-Node edge is created (the dependency on `HoneyDrunk.Kernel.Abstractions` already exists for all four Nodes)
- [ ] The Cosmos backing packages are NOT registered here (packet 03 registers `HoneyDrunk.Data.Idempotency.Cosmos` / `.InMemory` under `honeydrunk-data`)
- [ ] No invariant change in this packet (invariants land in packet 00)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0042 D1 — `IGridMessageEnvelope.IdempotencyKey`.** The key shape is exposed via `IGridMessageEnvelope.IdempotencyKey` in `HoneyDrunk.Kernel.Abstractions`, additive to the existing envelope. All async producers and consumers go through this envelope.

**ADR-0042 D2 — `IIdempotencyStore`.** `ValueTask<IdempotencyClaim> TryClaim(IdempotencyKey key, TimeSpan ttl); ValueTask<IdempotencyClaim?> Read(IdempotencyKey key); ValueTask Complete(IdempotencyClaim claim, IdempotencyOutcome outcome);` — in `HoneyDrunk.Kernel.Abstractions`.

**ADR-0042 D3/D5 — `IdempotentMessageHandler<T>` and `IGridMessagePublisher`.** The consumer base and producer helper, both shipped by Kernel.

**ADR-0042 D7 — `IPulseSignalEnvelope`.** The Pulse signal envelope is a separate type, not `IGridMessageEnvelope`; this is enforced at the type level.

**ADR-0042 Consequences — Affected Nodes.** "`HoneyDrunk.Kernel` — primary affected Node ... `HoneyDrunk.Data` — provides the default Cosmos-backed `IIdempotencyStore` implementation." Packet 03 ships it as `HoneyDrunk.Data.Idempotency.Cosmos`.

## Constraints
- **Records drop the `I`, interfaces keep it.** Grid-wide naming rule: `IdempotencyKey` / `IdempotencyClaim` / `IdempotencyOutcome` (records), `IGridMessageEnvelope` / `IIdempotencyStore` / `IGridMessagePublisher` / `IPulseSignalEnvelope` (interfaces). `IdempotentMessageHandler` is a class — no `I`.
- **Do not register the Cosmos backing packages.** Packet 03 ships and registers `HoneyDrunk.Data.Idempotency.Cosmos` / `.InMemory` under `honeydrunk-data`. This packet records only the contract surface in `honeydrunk-kernel`.
- **No new Node-to-Node edge.** Every affected Node already consumes `HoneyDrunk.Kernel.Abstractions`. The contracts are additive; only `consumes_detail` is enriched, not the edge list.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0042`, `wave-1`

## Agent Handoff

**Objective:** Register ADR-0042's idempotency contract surface in the Grid catalogs.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the contract/dependency catalogs accurate so implementation packets 02–07 read a correct graph.
- Feature: ADR-0042 Idempotency Contract rollout, Wave 1.
- ADRs: ADR-0042 D1/D2/D3/D5/D7 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0042 should be Accepted before its contract surface is recorded as catalog data.

**Constraints:**
- Records drop the `I`; interfaces keep it; `IdempotentMessageHandler` is a class.
- Do not register the Cosmos backing packages — packet 03 owns that.
- No new top-level Node-to-Node edge — only `consumes_detail` enrichment.
- nodes.json is NOT edited — it has no `exposes` field.

**Key Files:**
- `catalogs/contracts.json` — new entries in the `honeydrunk-kernel` block's `interfaces` array.
- `catalogs/relationships.json` — `honeydrunk-kernel` `exposes.contracts` + `consumes_detail` enrichment. nodes.json is NOT touched.

**Contracts:** None changed — this packet only records catalog metadata for contracts that packet 02 implements. The contract entries land in `contracts.json`'s `interfaces` array and `relationships.json`'s `exposes.contracts`; `nodes.json` is untouched.
