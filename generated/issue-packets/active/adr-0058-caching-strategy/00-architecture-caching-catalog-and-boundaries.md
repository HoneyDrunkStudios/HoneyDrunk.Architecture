---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0058", "wave-1"]
dependencies: []
adrs: ["ADR-0058"]
wave: 1
initiative: adr-0058-caching-strategy
node: honeydrunk-architecture
---

# Register the ADR-0058 caching contract surface in catalogs and boundary docs

## Summary
Record the new `ICacheStore<T>` contract surface in `catalogs/contracts.json` and `catalogs/relationships.json` under `honeydrunk-kernel`, list the new contracts in `repos/HoneyDrunk.Kernel/boundaries.md`, add the ADR-0058 D9 grandfather note to `repos/HoneyDrunk.Vault/overview.md`, and register the `adr-0058-caching-strategy` initiative in `initiatives/active-initiatives.md`. Catalog and governance-doc work only — no code, no .NET project.

## Context
ADR-0058 commits a Grid-wide `ICacheStore<T>` contract in `HoneyDrunk.Kernel.Abstractions` (D2) and an `InMemoryCacheStore<T>` reference implementation in `HoneyDrunk.Kernel` (D4). The Grid catalogs are the discoverability surface — `catalogs/contracts.json` registers each Node's contracts in its node block's `interfaces` array, and `catalogs/relationships.json` lists each Node's contract names under `exposes.contracts`. This packet keeps both catalogs accurate and lands the related boundary-doc notes so the Kernel code packets (04 + 05 in this initiative) read a correct graph at execution time.

ADR-0058 D9 grandfathers four existing caches (Vault, Auth, AI cost-rate, FeatureFlags). Vault's cache is the most operationally interesting — it pairs an in-memory backing with an Event Grid system-topic invalidation lane per ADR-0006 — and ADR-0058's "Catalog and Constitution Obligations" explicitly calls for `repos/HoneyDrunk.Vault/overview.md` to record the grandfather posture so future readers know the Vault cache is not forced onto `ICacheStore<T>`. This packet adds that note.

This is a docs/catalog packet. No code, no .NET project. The Kernel code lands in packets 04 and 05.

## Scope
- `catalogs/contracts.json` — locate the node block whose `node` value is `honeydrunk-kernel`; append two entries to its `interfaces` array for `ICacheStore<T>` and `InMemoryCacheStore<T>` per the existing entry shape. (The catalog precedent under `honeydrunk-transport` records the generic interface *with* its type parameter — `IMessageHandler<T>` — so this packet records `ICacheStore<T>` and `InMemoryCacheStore<T>` with `<T>` preserved.)
- `catalogs/relationships.json` — append `ICacheStore` and `InMemoryCacheStore` to the `honeydrunk-kernel` entry's `exposes.contracts` array. Do not touch any other entry; no new Node-to-Node edge is created (every consuming Node already consumes `HoneyDrunk.Kernel.Abstractions`).
- `repos/HoneyDrunk.Kernel/boundaries.md` — add `ICacheStore<T>` and `InMemoryCacheStore<T>` to the "What Kernel Owns" list per ADR-0058's "Catalog and Constitution Obligations": "Update `repos/HoneyDrunk.Kernel/boundaries.md` to list `ICacheStore<T>` and `InMemoryCacheStore<T>` among Kernel's owned contracts."
- `repos/HoneyDrunk.Vault/overview.md` — add the ADR-0058 D9 grandfather note: the Vault in-memory + Event Grid invalidation cache stays as is; if a future change to Vault's secret-cache backing is warranted, that change should land on `ICacheStore<T>`, but the trigger is "we are changing Vault's cache anyway," not "ADR-0058 forced a retrofit." Place the note in whatever section of `overview.md` already describes the cache (or, if no such section exists today, add a brief "Caching posture" subsection just after the existing capability descriptions).
- `initiatives/active-initiatives.md` — register the `adr-0058-caching-strategy` initiative with the packet checklist for this folder, sequenced after the existing "In Progress" entries.
- `constitution/invariant-reservations.md` — **claim a 3-invariant block for ADR-0058** by reading the file's **Active Reservations** table, picking the next free triple above the highest existing reservation (per the file's "How a packet 00 claims a block" procedure), and appending a row of the form `{N1}–{N3} | ADR-0058 | Proposed | Caching invariants (ICacheStore opacity, tenant-key isolation, classification inheritance). Packet 00 at <this path>. Block claimed at max(invariants.md, existing reservations) + 1.` The exact numbers `{N1}/{N2}/{N3}` resolve at edit time against the current state of the reservations table. Packet 01 reads this row to populate its three invariant numbers; do not hardcode 82/83/84.

The ADR-0058 obligation also lists Auth's JWT cache, AI's cost-rate cache, and FeatureFlags's request-scoped cache as grandfathered. **Do not add catalog or repo-doc entries for those four Nodes unless their existing repo docs already discuss caching.** Auth and AI's `repos/{name}/overview.md` may or may not warrant a one-sentence note; the executor decides at edit time. **FeatureFlags is not a stood-up Node** — no catalog entry exists for it and none should be added. ADR-0058's grandfather list for FeatureFlags is forward-looking, not a current catalog obligation.

## Proposed Implementation
1. **`catalogs/contracts.json`** — locate the node block whose `node` value is `honeydrunk-kernel` (do not rely on line numbers — the file may have shifted). Append entries to that block's `interfaces` array, matching the existing `{ "name", "kind", "description" }` shape. The catalog precedent under `honeydrunk-transport` is `IMessageHandler<T>` (the type parameter is preserved in the catalog `name`), so:
   - `ICacheStore<T>` — `kind: interface` — "Generic per-Node cache contract. Get / Set / Remove / RemoveByTag over typed values. Tenant-key isolation and data-classification inheritance are call-site disciplines per ADR-0058 D5 and D6; the contract itself is shape-only."
   - `InMemoryCacheStore<T>` — `kind: type` — "Reference implementation of ICacheStore<T> over Microsoft.Extensions.Caching.Memory. Shipped in `HoneyDrunk.Kernel` runtime per ADR-0058 D4. Distributed backings live in HoneyDrunk.Cache per ADR-0059."
   - Names follow the Grid naming rule (interfaces retain `I`; classes drop it). `ICacheStore<T>` is the interface; `InMemoryCacheStore<T>` is a concrete class. Both keep the `<T>` type parameter in the catalog `name` per the `IMessageHandler<T>` precedent.
2. **`catalogs/relationships.json`** — append `ICacheStore<T>` and `InMemoryCacheStore<T>` to the `honeydrunk-kernel` entry's `exposes.contracts` array (type parameter preserved, matching the `contracts.json` entries above). Do not touch any other entry. No `consumes_detail` enrichment is needed here — no current Node consumes the new contracts yet (Notify Cloud, Communications, and others will adopt them in their own follow-up initiatives, not in this one).
3. **`repos/HoneyDrunk.Kernel/boundaries.md`** — in the "What Kernel Owns" list, add a bullet describing `ICacheStore<T>` and `InMemoryCacheStore<T>` as Kernel-owned. Match the existing bullet style (concise, descriptive, no ADR ID in the bullet text — the file's existing bullets don't carry them).
4. **`repos/HoneyDrunk.Vault/overview.md`** — add the grandfather note. Suggested wording (the executor may adapt to local style):
   > **Caching posture.** Vault carries an in-memory secret cache fronting Azure Key Vault, with two-tier invalidation: a TTL fallback plus an Event Grid system-topic webhook on `Microsoft.KeyVault.SecretNewVersionCreated` (per the rotation lifecycle work). Under the Grid-wide caching strategy this cache is **grandfathered** — it pre-dates `ICacheStore<T>` and works correctly. If a future change to Vault's secret-cache backing is warranted, the migration should land on `ICacheStore<T>`; until then, the existing in-memory + Event Grid flow is the canonical pattern.
   Do not name ADR-0058 in the prose (per the user's "no ADR numbers in docs or comments" preference). The frontmatter / metadata of `overview.md` may retain its existing ADR refs if any.
5. **`initiatives/active-initiatives.md`** — register the `adr-0058-caching-strategy` initiative with the wave structure and packet checklist for this folder, modeled on the existing entries. Sample shape (adapt to the file's current style):

   ```markdown
   ### ADR-0058 Grid-Wide Caching Strategy
   **Status:** In Progress
   **Scope:** Architecture, Kernel
   **Initiative:** `adr-0058-caching-strategy`
   **Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
   **Description:** Ship the Grid-wide `ICacheStore<T>` contract and `InMemoryCacheStore<T>` reference implementation per ADR-0058. Catalog registration, three new invariants (numbers `{N1}/{N2}/{N3}` — claimed from `constitution/invariant-reservations.md` at packet 01 authoring time), ADR-0028 D2 matrix update, agent-checklist updates, contract in Kernel.Abstractions, runtime InMemory backing in Kernel. Existing caches grandfathered per ADR-0058 D9.

   **Tracking (Wave 1 — governance + catalog):**
   - [ ] Architecture: Catalog registration + Kernel/Vault boundary notes (packet 00)
   - [ ] Architecture: Three caching invariants `{N1}/{N2}/{N3}` (packet 01)

   **Tracking (Wave 2 — documentation follow-ups):**
   - [ ] Architecture: ADR-0028 D2 "Cache Invalidation" row (packet 02)
   - [ ] Architecture: scope.md + review.md caching checklist (packet 03)

   **Tracking (Wave 3 — Kernel contract):**
   - [ ] Kernel: `ICacheStore<T>` in Kernel.Abstractions (`0.8.0` bump) (packet 04)

   **Tracking (Wave 4 — Kernel runtime):**
   - [ ] Kernel: `InMemoryCacheStore<T>` in Kernel runtime (packet 05)

   **Exit criteria:** ADR-0058 status-flip housekeeping completes (Proposed → Accepted) once ADR-0059 is also Accepted and the Kernel `0.8.0` release has shipped.
   ```

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `repos/HoneyDrunk.Kernel/boundaries.md`
- `repos/HoneyDrunk.Vault/overview.md`
- `initiatives/active-initiatives.md`
- `constitution/invariant-reservations.md` — append the ADR-0058 reservation row claiming a 3-invariant block at `max(invariants.md, existing reservations) + 1`.

## NuGet Dependencies
None. This packet touches only Markdown and JSON; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] No new top-level Node-to-Node edge — every consuming Node already consumes `HoneyDrunk.Kernel.Abstractions`.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers `ICacheStore<T>` and `InMemoryCacheStore<T>` (type parameter preserved per the `IMessageHandler<T>` precedent under `honeydrunk-transport`) in the `honeydrunk-kernel` node block's `interfaces` array, matching the existing entry shape
- [ ] `catalogs/relationships.json` `honeydrunk-kernel` entry lists `ICacheStore<T>` and `InMemoryCacheStore<T>` in `exposes.contracts`, with all existing entries untouched
- [ ] `repos/HoneyDrunk.Kernel/boundaries.md` lists `ICacheStore<T>` and `InMemoryCacheStore<T>` among Kernel's owned contracts in the "What Kernel Owns" section
- [ ] `repos/HoneyDrunk.Vault/overview.md` carries a grandfather-posture note describing the existing in-memory + Event Grid Vault cache as not forced onto `ICacheStore<T>`; the note does not cite ADR-0058 by number in prose
- [ ] `initiatives/active-initiatives.md` registers the `adr-0058-caching-strategy` initiative with the packet checklist for this folder, sequenced into the file's existing "In Progress" structure
- [ ] `constitution/invariant-reservations.md` carries a new Active Reservations row for ADR-0058 claiming a 3-invariant block at the next free triple above the highest existing reservation, pointing at this packet's path
- [ ] No edits to `catalogs/nodes.json` (the `exposes` field lives in `relationships.json`, not `nodes.json`)
- [ ] No new top-level Node-to-Node edge in `relationships.json`
- [ ] No catalog or repo-doc edits for FeatureFlags (it is not a stood-up Node)
- [ ] No invariant change in this packet (invariants land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0058 D1 — Caching is per-Node, internal, and opaque across Node boundaries.** A cache is an implementation detail of the Node that owns the cached data. No Node reaches into another Node's cache through `Abstractions`, through composition, or through any other surface. The contract lives in `HoneyDrunk.Kernel.Abstractions` (D2), where every Node already takes a dependency; Nodes that need caching consume it from there.

**ADR-0058 D2 — `ICacheStore<T>` ships in `HoneyDrunk.Kernel.Abstractions`.** A minimal, generic, async surface with four methods (`GetAsync`, `SetAsync`, `RemoveAsync`, `RemoveByTagAsync`), value-typed by `T`. The contract is additive on Kernel.Abstractions (minor bump per ADR-0035).

**ADR-0058 D4 — InMemory reference implementation ships in Kernel.** `HoneyDrunk.Kernel` ships `InMemoryCacheStore<T>` alongside the contract, backed by `IMemoryCache` from `Microsoft.Extensions.Caching.Memory`. The Cache Node (ADR-0059) is the home for distributed backings.

**ADR-0058 D9 — Grandfather existing caches; no mandatory retrofit.** Vault's in-memory + Event Grid invalidation flow, Auth's JWT validation cache, AI's cost-rate-table cache, and FeatureFlags's request-scoped cache stay as they are. New caches in any Node should use `ICacheStore<T>`. Existing caches may migrate during normal evolution.

**ADR-0058 Catalog and Constitution Obligations.** The ADR explicitly lists: add `ICacheStore<T>` to `catalogs/contracts.json` under `honeydrunk-kernel`; update `repos/HoneyDrunk.Kernel/boundaries.md` to list `ICacheStore<T>` and `InMemoryCacheStore<T>` among Kernel's owned contracts; update `repos/HoneyDrunk.Vault/overview.md` to note the grandfather posture.

## Constraints
- **Names: `ICacheStore<T>` (interface) and `InMemoryCacheStore<T>` (class).** Grid-wide naming rule: interfaces retain the `I` prefix; classes / records drop it. The generic type parameter `<T>` is preserved in the catalog `name` field, matching the existing precedent of `IMessageHandler<T>` in `honeydrunk-transport`'s entry.
- **No new top-level Node-to-Node edge in `relationships.json`.** Every affected Node already consumes `HoneyDrunk.Kernel.Abstractions`. The new contracts are additive; only `exposes.contracts` is enriched.
- **`catalogs/nodes.json` is not edited.** It has no `exposes` field; the contract surface lives in `relationships.json` and `contracts.json`.
- **No ADR ID in `repos/HoneyDrunk.Vault/overview.md` prose** (per the user's "no ADR numbers in docs or comments" preference). The grandfather note describes the posture without citing ADR-0058 by number.
- **No retrofit packets for Auth, AI, or FeatureFlags.** Their caches are grandfathered (ADR-0058 D9); FeatureFlags is not even a stood-up Node and gets no catalog entry.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0058`, `wave-1`

## Agent Handoff

**Objective:** Register the ADR-0058 caching contract surface in the Grid catalogs and supporting boundary docs, and register the initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the contract/dependency catalogs accurate so packets 04 and 05 (the Kernel contract + runtime) read a correct graph at execution time, and record the Vault grandfather posture so future readers know the Vault cache is not forced onto `ICacheStore<T>`.
- Feature: ADR-0058 Grid-Wide Caching Strategy rollout, Wave 1.
- ADRs: ADR-0058 D1/D2/D4/D9 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Use the names `ICacheStore<T>` and `InMemoryCacheStore<T>` in the catalogs (the `<T>` type parameter is preserved, matching the `IMessageHandler<T>` precedent under `honeydrunk-transport`).
- Do NOT edit `catalogs/nodes.json` — it has no `exposes` field.
- Do NOT create a new top-level Node-to-Node edge — every consuming Node already consumes Kernel.Abstractions.
- Do NOT add catalog or repo-doc entries for FeatureFlags (not a stood-up Node).
- Do NOT cite ADR-0058 by number in the Vault overview prose; describe the posture instead.

**Key Files:**
- `catalogs/contracts.json` — new entries in the `honeydrunk-kernel` block's `interfaces` array (keep `<T>` in the catalog `name`).
- `catalogs/relationships.json` — `honeydrunk-kernel` `exposes.contracts` enrichment (keep `<T>`).
- `repos/HoneyDrunk.Kernel/boundaries.md` — add to "What Kernel Owns".
- `repos/HoneyDrunk.Vault/overview.md` — add the grandfather note.
- `initiatives/active-initiatives.md` — register the initiative.
- `constitution/invariant-reservations.md` — append the ADR-0058 3-invariant reservation row at the next free triple above the highest existing reservation.

**Contracts:** None changed. Catalog metadata only — the actual `ICacheStore<T>` contract lands in `HoneyDrunk.Kernel.Abstractions` via packet 04.
