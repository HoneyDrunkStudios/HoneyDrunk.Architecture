---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "cache", "adr-0059"]
dependencies: []
adrs: ["ADR-0059", "ADR-0058"]
accepts: ADR-0059
wave: 1
initiative: adr-0059-cache-standup
node: honeydrunk-cache
---

# Chore: Register HoneyDrunk.Cache's standup decisions in Architecture catalogs, sectors, tech-stack, roadmap, and create the repos/HoneyDrunk.Cache/ context folder

## Summary
Reflect ADR-0059's stand-up decisions in the canonical Architecture catalogs and reference docs. Add `honeydrunk-cache` to `catalogs/nodes.json` (Core sector, empty contracts, library Node), `catalogs/relationships.json` (empty `consumes` at standup — matches scaffold's no-PackageReference state per packet 03; empty `consumed_by`; `consumed_by_planned` with Notify Cloud and Communications; add `honeydrunk-cache` to Kernel's `consumed_by_planned` array — it stays in `consumed_by_planned` and is moved to `consumed_by` only when the first backing actually takes the `HoneyDrunk.Kernel.Abstractions` PackageReference), and `catalogs/grid-health.json` (seed entry with scaffold packet and GitHub repo creation as active blockers). **No `modules.json` entry at standup** — the placeholder ships no runtime code and `modules.json`'s `type` enum is `abstractions | runtime | provider | testing` with no `placeholder` variant; defer the module row until the first backing ships actual runtime code. Update `constitution/sectors.md` Core table to include Cache. Move the Cache row in `infrastructure/reference/tech-stack.md` out of "Planned Nodes" to the current Nodes section, and update the "Redis / distributed cache" row in the Future Backings section to reflect the stand-up. Update `initiatives/roadmap.md` to remove the Cache line from the Future Nodes list. Create the `repos/HoneyDrunk.Cache/` context folder with `overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md`, and `active-work.md` stubs matching the template used by `repos/HoneyDrunk.Audit/` and `repos/HoneyDrunk.Communications/` (those folders carry `integration-points.md`; `active-work.md` is added here even though Audit/Communications skipped it — the scope agent's standing convention is to seed both at standup so the first feature packet has files to edit rather than create). Add an "ADR-0059 HoneyDrunk.Cache Standup" entry to `initiatives/active-initiatives.md`.

ADR-0059 stays at `Status: Proposed` for this packet — the Status flip is a separate post-merge housekeeping step the scope agent handles after the entire initiative completes AND ADR-0058 is also Accepted, per the user's standing ADR acceptance workflow.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0059 establishes that `HoneyDrunk.Cache` is the Core sector's home for distributed-cache backing implementations of the `ICacheStore<T>` contract committed by ADR-0058 in `HoneyDrunk.Kernel.Abstractions`. None of that has reached the catalogs yet. Until it does:

- Every downstream consumer (Notify Cloud multi-replica, Communications shared cache, future AI cache uses) reads stale or inconsistent metadata when scoping their own work — there is no `honeydrunk-cache` to point at in their `consumes_planned`.
- The grid-health aggregator has no row to track the Node against.
- The sector table in `constitution/sectors.md` does not list Cache as a Core Node, so the boundary "what sector owns distributed-cache backings" is undefined in the canonical sector doc.
- The `infrastructure/reference/tech-stack.md` and `initiatives/roadmap.md` still describe Cache as a planned/future Node that does not exist yet, which after stand-up is stale.
- The scaffold packet (packet 03 of this initiative) has no `repos/HoneyDrunk.Cache/` context folder to cross-reference from its README.

Eight specific drift items must be resolved in this work-item:

1. **`catalogs/nodes.json` has no `honeydrunk-cache` entry.** Add one with Core sector, Seed signal, empty contracts list (the implemented contract lives in `HoneyDrunk.Kernel.Abstractions`), library-Node framing in `long_description`, and tags reflecting the substrate role.
2. **`catalogs/relationships.json` has no `honeydrunk-cache` entry.** Add one with `consumes: []` at standup (the placeholder scaffold ships no `HoneyDrunk.*` PackageReference other than `HoneyDrunk.Standards` per packet 03 — making this empty keeps the relationship graph synchronized with the actual `.csproj` state and avoids the apparent contradiction with packet 03), empty `consumed_by`, and `consumed_by_planned: ["honeydrunk-notify-cloud", "honeydrunk-communications"]` per ADR-0059 D6. The Cache → Kernel edge is captured in `consumes_detail` commentary so the planned coupling is visible without overstating the actual day-one PackageReference state. The first backing implementation packet adds `honeydrunk-kernel` to `consumes` in the same edit that adds the `HoneyDrunk.Kernel.Abstractions` PackageReference.
3. **`catalogs/grid-health.json` has no `honeydrunk-cache` row.** Add a Seed-state row with the scaffold packet and GitHub repo creation as `active_blockers`; add `honeydrunk-cache` to the `summary.blocked_nodes` array.
4. **`catalogs/modules.json` gets NO new entry at standup.** The placeholder ships no runtime code and the schema enum is `abstractions | runtime | provider | testing` with no `placeholder` variant. Adding a `runtime` row for an empty placeholder would misrepresent the day-one state. Defer the modules entry until the first backing implementation packet, which ships actual runtime code and a meaningful module identity (likely `cache-adapters-redis` or similar — the backing-specific naming is decided at that packet's time).
5. **`constitution/sectors.md` Core table does not include Cache.** Add a Cache row after Audit, with `Signal: Seed` and a responsibility line describing the distributed-cache backing home.
6. **`infrastructure/reference/tech-stack.md` describes Cache as a planned Node (line ~205: `| Cache | Core | Distributed caching abstraction |`) and the Redis row (line ~185: `| Redis / distributed cache | Future | HoneyDrunk.Cache abstraction |`) reflects pre-standup state.** Move the Cache row out of "Planned Nodes (no code yet)" — either delete it or relocate it into a "Stood up, awaiting first backing" subsection if the doc's preferred shape supports that. Update the Redis row to reflect that the Node is stood up but no backing is implemented yet.
7. **`initiatives/roadmap.md` line ~68 still lists `HoneyDrunk.Cache — Distributed caching abstraction` under the "Future" section.** Remove it, or relocate to a "Stood up, not yet implemented" subsection per the dispatch plan's roadmap-shape note.
8. **`repos/HoneyDrunk.Cache/` context folder does not exist.** Create it with `overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md`, and `active-work.md` stubs matching the template used by `repos/HoneyDrunk.Audit/` and `repos/HoneyDrunk.Communications/`. Those folders carry `overview.md`, `boundaries.md`, `invariants.md`, and `integration-points.md` (none currently carry `active-work.md`); this packet seeds `active-work.md` as well so the first feature packet has a file to edit rather than create from scratch.

In addition this work-item:

- Adds an "ADR-0059 HoneyDrunk.Cache Standup" entry to `initiatives/active-initiatives.md` under `## In Progress`.

The ADR Status flip (Proposed → Accepted) is intentionally **not** in this packet. Per the user's standing ADR acceptance workflow, the scope agent flips Status only after the entire initiative's PRs have merged AND ADR-0058 is also Accepted. This is a separate housekeeping step that runs after packets 01 / 02 / 03 are all closed AND ADR-0058 has reached Accepted — not a line-edit on this packet.

## Proposed Implementation

### `catalogs/nodes.json` — new `honeydrunk-cache` entry

Add a new entry to the `nodes` array, placed alphabetically/topologically near other Core Nodes (a reasonable position is after `honeydrunk-audit` and before `honeydrunk-pulse`, mirroring where Cache sits in the substrate). The full entry:

```json
{
  "id": "honeydrunk-cache",
  "type": "node",
  "name": "HoneyDrunk.Cache",
  "public_name": "HoneyDrunk.Cache",
  "short": "Distributed-cache backing host for the Grid",
  "description": "Home for distributed-cache backing implementations of the Grid's ICacheStore<T> contract (committed in HoneyDrunk.Kernel.Abstractions per ADR-0058). Hosts Redis-class adapters, Cosmos-with-TTL adapters, Postgres-with-TTL adapters, and any future backing a consuming Node composes at host time when its workload demands a distributed cache. Cache is a backing host, not a contract owner — it declares no abstractions; it implements an abstraction declared elsewhere.",
  "sector": "Core",
  "signal": "Seed",
  "cluster": "substrate",
  "energy": 0,
  "priority": 0,
  "flow": 0,
  "tags": ["cache", "distributed-cache", "backing", "provider", "substrate"],
  "links": {
    "repo": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Cache"
  },
  "long_description": {
    "overview": "HoneyDrunk.Cache is the Core sector's single Node that owns distributed-cache backing implementations of ICacheStore<T>. It is the analog of HoneyDrunk.Data (which hosts persistence-store backings) and HoneyDrunk.Transport provider packages (which host broker-specific backings). The Grid pattern: contract in Kernel.Abstractions, reference plumbing in Kernel, distributed/provider implementations in a dedicated Node. Cache hosts the distributed/provider half of that pattern for caching.",
    "why_it_exists": "Distributed cache backings need a home. They do not belong in Kernel (which keeps its surface tight to abstractions and InMemory reference plumbing). They do not belong in each consuming Node (which would N-times duplicate the backing code). They do not belong in HoneyDrunk.Data (whose remit is persistence stores, not cache stores — durability and consistency are different from cache semantics). HoneyDrunk.Cache is the right home, stood up front-loaded per the charter so the first backing has a Node-shaped landing pad when the first real consumer pulls on a distributed cache.",
    "primary_audience": "Internal Nodes whose workload demands a distributed cache: Notify Cloud (likely first consumer — API key validation cache and tenant-tier cache convergence across multi-replica), Communications (shared preference / cadence cache), future AI workloads that outgrow the per-Node cost-rate cache.",
    "value_props": [
      "Single Node home for distributed cache backings",
      "Contract/runtime split — consumers compile against Kernel.Abstractions, compose backings at host time",
      "Provider-pattern: Redis, Cosmos-with-TTL, Postgres-with-TTL backings ship as sibling adapter packages",
      "Backings observe consumer-chosen invalidation lanes (in-process, Service Bus, Event Grid)",
      "Empty on day one by design — first backing arrives when first consumer activates it"
    ],
    "monetization_signal": "Internal-first Core primitive. Pure substrate; no commercial product surface.",
    "roadmap_focus": "Stand up the Node and CI on an empty solution (ADR-0059). First distributed backing arrives when the first real consumer pulls on it — likely Notify Cloud multi-replica or Communications shared cache. Backing choice (Redis-class vs Cosmos-with-TTL vs Postgres-with-TTL) deferred to the first feature packet.",
    "grid_relationship": "Consumes Kernel (ICacheStore<T> contract from Kernel.Abstractions; IGridContext, lifecycle, telemetry). Emits its own operational telemetry consumed by Pulse — no runtime dependency on Pulse. No Grid-internal downstream consumers at stand-up (Cache is a leaf in the dependency graph from its own side). Planned consumers when the first backing ships: Notify Cloud, Communications.",
    "integration_depth": "low",
    "demo_path": "Future: compose a distributed backing into a Container App host → write through ICacheStore<T> → observe entries across replicas. At stand-up: empty solution, CI green, no demo path yet.",
    "signal_quote": "The empty room with the right lighting.",
    "stability_tier": "seed",
    "impact_vector": "operational scale"
  },
  "foundational": false,
  "strategy_base": 8,
  "tier": "none",
  "time_pressure": 0,
  "done": false,
  "cooldown_days": 14
}
```

Notes:
- `signal: "Seed"` matches Audit, AI, Capabilities, and other recently-stood-up Nodes at empty-scaffold state.
- `foundational: false` — Cache is substrate but not foundational in the way Kernel/Transport/Auth are. It's a backing host, activated when a consumer pulls on it.
- `strategy_base: 8` — modest priority. No active consumer demanding the backing yet, so strategy points reflect the front-loaded nature.
- `tags` — `cache`, `distributed-cache`, `backing`, `provider`, `substrate` per ADR-0059 §Catalog obligations (line 217).

### `catalogs/relationships.json` — new `honeydrunk-cache` entry

Add a new entry to the `nodes` array. Placed near the other Core Nodes, a reasonable position is immediately after the `honeydrunk-audit` block. The full entry:

```json
{
  "id": "honeydrunk-cache",
  "consumes": [],
  "consumes_planned": ["honeydrunk-kernel"],
  "consumed_by": [],
  "consumed_by_planned": ["honeydrunk-notify-cloud", "honeydrunk-communications"],
  "blocked_by": [],
  "exposes": {
    "contracts": [],
    "packages": ["HoneyDrunk.Cache.Adapters"]
  },
  "consumes_detail": {
    "honeydrunk-kernel": ["ICacheStore<T>", "IGridContext", "IStartupHook", "IHealthContributor", "ITelemetryActivityFactory", "HoneyDrunk.Kernel.Abstractions"]
  }
}
```

Notes:
- **`consumes` is empty at standup.** The placeholder scaffold ships no `HoneyDrunk.*` PackageReference other than `HoneyDrunk.Standards` (per packet 03's "no `HoneyDrunk.Kernel.Abstractions` reference at this stage"). To keep `relationships.json` synchronized with the actual `.csproj` state and avoid the contradiction that "Cache consumes Kernel" while no Kernel reference exists in the scaffold, the `consumes` array is empty. The first backing implementation packet adds `honeydrunk-kernel` to `consumes` in the same edit that adds the `HoneyDrunk.Kernel.Abstractions` PackageReference.
- **`consumes_planned: ["honeydrunk-kernel"]`** captures the role-defining intent: Cache's eventual backings *will* consume Kernel.Abstractions to implement `ICacheStore<T>`. If `relationships.json` does not currently carry a `consumes_planned` field, add it on this row only — it is a forward-compatible addition that mirrors the existing `consumed_by_planned` shape. If a downstream consumer of `relationships.json` chokes on the unknown field, fall back to leaving `consumes_planned` out and relying on `consumes_detail.honeydrunk-kernel` to carry the planned-coupling note. Verify schema consumers at edit time.
- **`exposes.contracts` is empty.** Per ADR-0059 D6, Cache does not declare its own contracts — `ICacheStore<T>` lives in `HoneyDrunk.Kernel.Abstractions`. The contract Cache implements appears in `consumes_detail.honeydrunk-kernel`, not in `exposes.contracts`.
- **`exposes.packages` has one entry**, `HoneyDrunk.Cache.Adapters`, the day-one placeholder per ADR-0059 D3 + D8. Future backings (`HoneyDrunk.Cache.Adapters.Redis`, `HoneyDrunk.Cache.Adapters.Cosmos`, etc.) are added to this array when their packets land — not in this initiative.
- **`consumed_by_planned`** lists the two most likely first consumers per ADR-0059 §If Accepted (line 14) + §D6 commentary. Notify Cloud (multi-replica API key validation cache and tenant-tier cache convergence) is the most likely; Communications (shared preference / cadence cache) is the alternate. AI is **not** in `consumed_by_planned` per ADR-0059 D3 ("Unlikely first trigger: AI sector").
- **`consumed_by` is empty** — no Grid-internal downstream consumer exists at stand-up per ADR-0059 D9 (Cache is a leaf in the dependency graph from its own side).
- **`consumes_detail.honeydrunk-kernel`** still names the Kernel types Cache's future backings will consume — this captures intent for the dependency map without claiming a current PackageReference. When the first backing adds the actual reference, both `consumes` and `consumes_detail` reflect the same state.

Also update `honeydrunk-kernel`'s `consumed_by_planned` array (currently at line 7, includes a list of planned downstream Nodes — `honeydrunk-ai`, `honeydrunk-capabilities`, `honeydrunk-agents`, `honeydrunk-memory`, `honeydrunk-knowledge`, `honeydrunk-flow`, `honeydrunk-operator`, `honeydrunk-audit`, `honeydrunk-observe`). Add `honeydrunk-cache` to that array. **`honeydrunk-cache` stays in Kernel's `consumed_by_planned` until the first backing implementation actually takes the `HoneyDrunk.Kernel.Abstractions` PackageReference** — only then does it move from `consumed_by_planned` to `consumed_by`. The Audit pattern (Audit was in Kernel's `consumed_by_planned` before the first Audit project took the Kernel reference, then moved to `consumed_by`) is the exact precedent.

### `catalogs/grid-health.json` — new `honeydrunk-cache` row + `summary.blocked_nodes` update

Add a new row to the `nodes` array. Placed near the other Core Nodes (a reasonable position is immediately after the `honeydrunk-audit` row, mirroring the catalog ordering). The full row:

```json
{
  "id": "honeydrunk-cache",
  "name": "HoneyDrunk.Cache",
  "sector": "Core",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": ["GitHub repo not yet created (Architecture#NN — packet 02 of adr-0059-cache-standup)", "Scaffold packet (Cache#NN — packet 03 of adr-0059-cache-standup) not yet executed"],
  "notes": "ADR-0059 standup ADR Proposed 2026-05-23 (Status flip to Accepted is a separate post-merge housekeeping step after the initiative completes AND ADR-0058 is Accepted). Catalog surface registered with empty contracts list — Cache implements ICacheStore<T> which lives in HoneyDrunk.Kernel.Abstractions per ADR-0058 D2. Awaiting GitHub repo creation (human-only) and scaffold execution: HoneyDrunk.Cache.Adapters placeholder project (no backing implementations on day one), Standards wiring, CI without contract-shape canary (Cache owns no contracts to freeze)."
}
```

The `summary.blocked_nodes` list at lines 335-345 currently lists empty/seed Nodes that are blocked. Add `honeydrunk-cache` to that array, alphabetically positioned (after `honeydrunk-audit` if Audit's status changes back to blocked, otherwise positioned by surrounding context). Confirm at edit time which adjacent rows make sense — the exact position is not load-bearing.

### `catalogs/modules.json` — no entry added at standup

**No new module entry is added in this packet.** The placeholder `HoneyDrunk.Cache.Adapters` project ships no runtime code (no `.cs` files per packet 03, or a single empty `Properties/AssemblyInfo.cs` marker file only). The `modules.json` schema enum is `abstractions | runtime | provider | testing` — there is no `placeholder` variant. Adding a `runtime` row for an empty placeholder would misrepresent the day-one state and pollute downstream readers of `modules.json` (e.g. the grid-health aggregator, package matrix generators) with a row that has no real package behind it.

Defer the modules entry until the **first backing implementation packet**, which:
1. Ships actual runtime code (a Redis-class, Cosmos-with-TTL, or Postgres-with-TTL adapter).
2. Has a meaningful module identity (likely `cache-adapters-redis`, `cache-adapters-cosmos`, or similar — the backing-specific naming is decided at that packet's time).
3. Carries a real `version` reflecting the first shippable backing.

If at edit time a strong case exists for documenting a new `placeholder` type in the `modules.json` schema to give pre-implementation Nodes a home, that is a separate ADR/initiative — not this packet's scope. The default for this packet is **no row**.

The grid-health row added in `grid-health.json` is sufficient to surface the Cache Node's existence to the aggregator; `modules.json` is for packaged shippable units, of which Cache has zero at standup.

### `constitution/sectors.md` — Core table includes Cache

The Core table at lines 5-19 currently ends with the **Audit** row:

```
| **Audit** | Seed | Grid-wide durable, attributable security and action record — append-only by interface, audit-class retention, forensic read surface |
```

Add a new row immediately after Audit:

```
| **Cache** | Seed | Distributed-cache backing host for the Grid — Redis-class, Cosmos-with-TTL, Postgres-with-TTL backings of the ICacheStore<T> contract committed in HoneyDrunk.Kernel.Abstractions |
```

No other changes to `sectors.md` — Ops/Meta/AI/Creator sectors are untouched.

### `infrastructure/reference/tech-stack.md` — update two rows

**(a) Planned Nodes table (lines 196-205) — remove the Cache row.** Current text at line 205:

```
| Cache | Core | Distributed caching abstraction |
```

Remove that line entirely. The Cache Node is now stood up, so it does not belong in "Planned Nodes (no code yet)". The other rows in that table (Agent Kit, Orchestrator, HoneyHub, Gateway, Jobs) stay.

**(b) Future Backings table — update the Redis row (line ~185).** Current text:

```
| Redis / distributed cache | Future | HoneyDrunk.Cache abstraction |
```

Replace with:

```
| Redis / distributed cache | Future (first-consumer-gated) | HoneyDrunk.Cache Node stood up empty per ADR-0059; first distributed backing ships when first consumer (likely Notify Cloud multi-replica or Communications shared cache) pulls on it. Backing choice (Redis-class vs. Cosmos-with-TTL vs. Postgres-with-TTL) deferred to the first feature packet. |
```

The row stays in the Future section because the actual Redis dependency is still future — the Node home exists, but no Redis adapter has shipped yet. The `Target` column ("Future") is qualified to "first-consumer-gated" to capture the trigger.

If the doc carries a separate "Stood up, awaiting first backing" subsection (it does not at scoping time), that's the alternate home for the row. Default is to leave it in Future with the qualified target.

### `initiatives/roadmap.md` — update the Future list

Line 68 currently reads:

```
- HoneyDrunk.Cache — Distributed caching abstraction
```

Remove it. The "Future" section (lines 62-72) lists Nodes that have not yet been stood up. Cache no longer qualifies — it has been stood up by ADR-0059. The other entries stay (Sim, Gateway, Jobs, HoneyNet, HoneyPlay, Cyberware, Forge).

If a new "Stood up, not yet implemented" subsection makes sense to add to capture Cache alongside Sim/Flow/Evals etc., that's an alternate path. Default is to remove the row entirely — the Node now has its own catalog entries (nodes.json, relationships.json, grid-health.json, modules.json) and a sectors-table row, which is sufficient to surface its existence. The roadmap is for work-not-yet-started, and stand-up has occurred.

### `repos/HoneyDrunk.Cache/` — new context folder

Create the folder with **five** new files: `overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md`, and `active-work.md`. The template is `repos/HoneyDrunk.Audit/` and `repos/HoneyDrunk.Communications/` — both currently carry `overview.md`, `boundaries.md`, `invariants.md`, and `integration-points.md` (neither carries `active-work.md`). This packet seeds `active-work.md` as well, so the first feature packet (the first distributed-cache backing implementation) has a file to edit rather than create from scratch. The Audit/Communications folders can pick up an `active-work.md` retroactively when their next feature packet runs — not in scope for this initiative.

#### `repos/HoneyDrunk.Cache/overview.md`

```markdown
# HoneyDrunk.Cache — Overview

**Sector:** Core
**Version:** 0.0.0
**Framework:** .NET 10.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Cache`
**Status:** Standup ADR Proposed (ADR-0059); scaffold pending. No backing implementations yet.

## Purpose

The Core sector's single Node that owns distributed-cache backing implementations of the `ICacheStore<T>` contract. The contract itself lives in `HoneyDrunk.Kernel.Abstractions`; the reference in-memory plumbing lives in `HoneyDrunk.Kernel`. This Node is the home for Redis-class adapters, Cosmos-with-TTL adapters, Postgres-with-TTL adapters, and any future backing a consuming Node composes at host time when its workload demands a distributed cache.

Cache is the analog of `HoneyDrunk.Data` (which hosts persistence-store backings) and `HoneyDrunk.Transport` provider packages (which host broker-specific backings). The Grid pattern: contract in Kernel.Abstractions, reference plumbing in Kernel, distributed/provider implementations in a dedicated Node.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Cache.Adapters` | Runtime placeholder | Day-one project carrying the .NET version, analyzers, and CI wiring so CI has something to build. No backing implementations. Future backings ship as sibling packages (e.g. `HoneyDrunk.Cache.Adapters.Redis`, `HoneyDrunk.Cache.Adapters.Cosmos`, `HoneyDrunk.Cache.Adapters.Postgres`) when their feature packets land. |

## Key Contracts

None owned by this Node. Cache implements `ICacheStore<T>` (declared in `HoneyDrunk.Kernel.Abstractions`). It declares no abstractions of its own.

## Design Notes

The Node is **front-loaded** — stood up before the first Grid consumer pulls on a distributed cache. The charter §"What this charter licenses" justifies this: substrate work is the work, not "premature optimization." Eight prior Node standups (Agents, Knowledge, Memory, Evals, Flow, Sim, Operator, Audit) set the precedent.

The Node is **a backing host, not a contract owner.** It does not declare `ICacheStore<T>`; it implements it. The lines are sharp:

- **What Cache owns:** distributed-cache backing implementations (Redis adapter, Cosmos-TTL adapter, Postgres-TTL adapter, etc.), each shipping as a `HoneyDrunk.Cache.Adapters.{Backing}` package; adapter-specific configuration shapes; adapter-specific operational telemetry.
- **What Cache does NOT own:** the `ICacheStore<T>` contract (lives in Kernel.Abstractions); the `InMemoryCacheStore<T>` reference implementation (lives in Kernel); cache instances (every Node instantiates its own through DI composition); cache invalidation policy or lane choice (per-Node, per-cache); tenant-key discipline (consumer-side concern); data classification (cached values inherit the consumer's classification).

**Phase-1 honest limitation:** No backing implementations on day one. The scaffold is the empty room with the right lighting. The first backing arrives when the first real consumer (likely Notify Cloud multi-replica or Communications shared cache) pulls on a distributed cache. The choice between Redis-class, Cosmos-with-TTL, and Postgres-with-TTL is deferred to the first feature packet — pre-deciding it now would freeze a choice without a real workload to validate against.
```

#### `repos/HoneyDrunk.Cache/boundaries.md`

```markdown
# HoneyDrunk.Cache — Boundaries

## What Cache Owns

- Distributed-cache backing implementations of `ICacheStore<T>` (Redis adapter, Cosmos-TTL adapter, Postgres-TTL adapter, etc.), each shipping as a `HoneyDrunk.Cache.Adapters.{Backing}` package
- Adapter-specific configuration shapes (connection strings, TTL defaults, serialization choices) as records consumed at host-time DI registration
- Adapter-specific operational telemetry — connection health, hit/miss/eviction metrics — emitted to Pulse via Kernel's `ITelemetryActivityFactory`

## What Cache Does NOT Own

- **The `ICacheStore<T>` contract itself.** That lives in `HoneyDrunk.Kernel.Abstractions`. Cache implements; it does not declare.
- **The `InMemoryCacheStore<T>` reference implementation.** That lives in `HoneyDrunk.Kernel`. Cache hosts distributed backings only.
- **Cache instances.** Every Node that needs a cache instantiates its own through DI composition; the cached data belongs to the consuming Node. Cache provides the *backing*, not the *cache*. Same boundary Vault uses: Vault owns the secret cache; Key Vault stores the secret.
- **Cache invalidation policy or lane choice.** Each cache chooses one of three named lanes (in-process, Service Bus topic, Event Grid system topic). The lane choice is per-Node, per-cache; Cache backings observe whatever invalidation the consumer issues.
- **Tenant-key discipline.** Tenant-scoping is a property of the value, not of the backing. The backing stores what it's given; the consuming Node is responsible for tenant-keying the cache keys.
- **Data classification.** Cached values inherit the classification of their source. The backing must support encryption-at-rest for Restricted-tier workloads; the consuming Node is responsible for understanding what classification its cached values carry.
- **HTTP / output response caching.** That is a separate concern likely paired with the Gateway standup. Cache's role today is distributed `ICacheStore<T>` backings only.
- **Cache instances' lifecycle.** Composition (which backing is active, which connection string is used) is a host-time concern resolved at application startup. Cache packages do not self-register or self-compose.

## Boundary Decision Tests

- Is this **declaring a new caching contract**? → No — `ICacheStore<T>` is in Kernel.Abstractions, where Grid-wide primitives live.
- Is this **implementing a distributed-cache backing** (Redis, Cosmos with TTL, Postgres with TTL, etc.)? → Cache.
- Is this **implementing the reference in-memory cache**? → Kernel (`InMemoryCacheStore<T>`).
- Is this **deciding which backing to use, or wiring the cache instance into a host**? → consumer Node, at host-time DI composition.
- Is this **invalidating a cache or choosing an invalidation lane**? → consumer Node.
- Is this **tenant-keying a cache or classifying cached data**? → consumer Node.
- Is this **HTTP / output response caching**? → Out of scope for Cache today; future Gateway-paired concern.
```

#### `repos/HoneyDrunk.Cache/invariants.md`

```markdown
# HoneyDrunk.Cache — Invariants

Cache-specific invariants (supplements `constitution/invariants.md`).

1. **Cache declares no abstractions of its own.**
   `ICacheStore<T>` lives in `HoneyDrunk.Kernel.Abstractions`. Cache implements it; it does not declare it. No `HoneyDrunk.Cache.Abstractions` package — adding one would force every Node consuming caching to take a runtime dependency on the Cache Node's abstraction package, including Nodes that compose only the InMemory backing (which lives in Kernel). The dependency direction is wrong.

2. **Cache is a backing host, not a cache instance.**
   The Node provides distributed-cache backings as adapter packages. Cache instances are composed by the consuming Node at host time; the cached data belongs to the consuming Node. Same boundary Vault uses: Vault owns the secret cache; Key Vault stores the secret.

3. **No backing implementations on day one.**
   Per ADR-0059 D3 + D8, the scaffold is the empty room with the right lighting — a single placeholder project carrying the .NET version, analyzers, and CI wiring. The first backing arrives when the first real consumer pulls on a distributed cache; the choice between Redis-class, Cosmos-with-TTL, and Postgres-with-TTL is deferred to the first feature packet.

4. **Cache emits operational telemetry one-way to Pulse.**
   Connection health, hit/miss/eviction metrics, and other adapter operational signals flow via Kernel's `ITelemetryActivityFactory`. Cache has no runtime dependency on Pulse; the direction is one-way by contract.

5. **Tenant-key discipline is the consuming Node's responsibility, not Cache's.**
   The backing stores what it's given. Tenant-scoping is a property of the value, not of the backing. Cached values inherit the classification of their source; the consuming Node is responsible for tenant-keying cache keys and for understanding what classification its cached values carry.

6. **Cache is a leaf in the dependency graph from its own side at stand-up.**
   No Grid-internal downstream consumer exists at stand-up — every existing cache in the Grid is either grandfathered (Vault, Auth, AI cost-rate, FeatureFlags per ADR-0058 D9) or has not yet been introduced. The Cache Node's consumers, when they arrive, take the dependency edge.

_Cache introduces no constitutional invariants at stand-up. The cache-related invariants (per-Node-opaque caches; tenant-key isolation; classification inheritance) are committed by ADR-0058 in `HoneyDrunk.Kernel.Abstractions`, not by ADR-0059. If ADR-0058's acceptance work promotes any of those to constitutional invariants, the numbers will be assigned by that initiative and referenced here when they land._

## Status

Standup ADR Proposed. Scaffold pending. No backing implementations yet.
```

#### `repos/HoneyDrunk.Cache/integration-points.md`

```markdown
# HoneyDrunk.Cache — Integration Points

## Upstream Dependencies (at standup)

None at standup. The placeholder `HoneyDrunk.Cache.Adapters` project carries no `HoneyDrunk.*` PackageReference other than `HoneyDrunk.Standards`. When the first backing implementation lands, that packet adds `HoneyDrunk.Kernel.Abstractions` as the upstream dependency (for `ICacheStore<T>`, `IGridContext`, lifecycle hooks, `ITelemetryActivityFactory`).

## Upstream Dependencies (planned, when first backing ships)

| Node | Contract | Usage |
|------|----------|-------|
| **HoneyDrunk.Kernel** | `ICacheStore<T>`, `IGridContext`, lifecycle hooks, `ITelemetryActivityFactory` (`HoneyDrunk.Kernel.Abstractions`) | Cache backings implement `ICacheStore<T>` (declared in Kernel.Abstractions per ADR-0058 D2). Operational telemetry — connection health, hit/miss/eviction metrics — flows via Kernel's telemetry factory. |

## Telemetry (no runtime dependency, planned for first backing)

| Node | Direction | Notes |
|------|-----------|-------|
| **HoneyDrunk.Pulse** | Cache backings emit → Pulse observes | One-way by contract. Adapter operational telemetry flows via Kernel's `ITelemetryActivityFactory`. Cache has **no runtime dependency on Pulse**. Cached values are not telemetry and never flow to Pulse — the cache backing and the observability channel stay separate. No telemetry-emitting code exists at standup. |

## Downstream Consumers (at standup)

None. Cache is a leaf in the dependency graph from its own side at standup per ADR-0059 D9. Every existing cache in the Grid is either grandfathered (Vault, Auth, AI cost-rate, FeatureFlags per ADR-0058 D9) or has not yet been introduced.

## Downstream Consumers (planned, when first backing ships)

| Node | Contract Used | Status |
|------|---------------|--------|
| **HoneyDrunk.Notify (Cloud variant)** | `ICacheStore<T>` (`HoneyDrunk.Kernel.Abstractions`) | Likely first consumer — API key validation cache and tenant-tier cache convergence across multi-replica. Not wired at standup. |
| **HoneyDrunk.Communications** | `ICacheStore<T>` (`HoneyDrunk.Kernel.Abstractions`) | Alternate first consumer — shared preference / cadence cache. Not wired at standup. |
| **Future AI workloads** | `ICacheStore<T>` (`HoneyDrunk.Kernel.Abstractions`) | When per-Node cost-rate caches outgrow process-local scope. Not the first trigger per ADR-0059 D3. |

## Boundary Notes

- Downstream Nodes consume `HoneyDrunk.Kernel.Abstractions` (for the `ICacheStore<T>` contract) and a chosen `HoneyDrunk.Cache.Adapters.{Backing}` package (for the distributed backing at host time). Composition (which backing is active, which connection string is used) is a host-time concern.
- Cache backings observe consumer-chosen invalidation lanes (in-process, Service Bus topic, Event Grid system topic). The lane choice is per-Node, per-cache; Cache backings respond to whatever invalidation the consumer issues.
- Tenant-key discipline is the consuming Node's responsibility. The backing stores what it's given; the consumer is responsible for tenant-keying cache keys.
- Each Cache backing's host-time configuration (connection string, TTL defaults, serialization) is resolved through the consumer Node's App Configuration / Key Vault setup, not Cache's. Cache packages do not self-register or self-compose.

## Status

Standup. No integrations active yet. This file fills in as backings ship and consumers wire.
```

#### `repos/HoneyDrunk.Cache/active-work.md`

```markdown
# HoneyDrunk.Cache — Active Work

## Status

**Standup phase.** No active feature work yet. The Node has been catalog-registered (ADR-0059 standup initiative — three packets:  catalog/context-folder registration, GitHub repo creation, scaffold). After the scaffold packet merges, the next active-work entry will be the first backing implementation packet (Redis-class, Cosmos-with-TTL, or Postgres-with-TTL — chosen when the first real consumer pulls on a distributed cache).

## Recently Completed

_None._ The Node is at standup. This file fills in as feature packets land.

## In Progress

_None._

## Planned (next likely work)

| Trigger | Likely Backing | Likely Consumer |
|---------|----------------|------------------|
| First Notify Cloud multi-replica rollout demanding API-key-validation cache convergence | Redis-class (Azure Cache for Redis), Cosmos-with-TTL, or Postgres-with-TTL — TBD at packet time | HoneyDrunk.Notify (Cloud variant) |
| First Communications shared preference / cadence cache | Same options as above | HoneyDrunk.Communications |

The choice of first backing is **deferred to the first feature packet** per ADR-0059 D3 — pre-deciding it now would freeze a choice without a real workload to validate against.

## Known Blockers

None at standup. The first backing's packet will surface its own prerequisites (Azure resource provisioning walkthrough, host-time DI composition decisions, invalidation-lane choice for the consuming Node).
```

### `initiatives/active-initiatives.md` — new entry

Add a new entry under `## In Progress`. The exact position is not load-bearing; placement immediately after the most recent standup-ADR entry (whichever that is at edit time — likely ADR-0044, ADR-0047, or similar) keeps the section topically grouped. The entry:

```markdown
### ADR-0059 HoneyDrunk.Cache Standup
**Status:** In Progress
**Scope:** Architecture, HoneyDrunk.Cache (new repo)
**Initiative:** `adr-0059-cache-standup`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Stand up `HoneyDrunk.Cache` as the Core sector's home for distributed-cache backing implementations of `ICacheStore<T>` per ADR-0059. Catalog reconciliation (add Cache to nodes/relationships/grid-health/modules; Core sector table; tech-stack and roadmap), human-only repo creation, and the scaffold packet (single placeholder project, no backing implementations on day one, CI without contract-shape canary). Front-loaded per the charter — no consumer demanding a distributed backing yet; the first feature packet will activate the first backing (Redis-class vs Cosmos-with-TTL vs Postgres-with-TTL) when the first consumer (likely Notify Cloud multi-replica or Communications shared cache) pulls on one.

**Tracking:**
- [ ] Architecture#NN: Catalog registration + context folder + sectors/tech-stack/roadmap updates (packet 01)
- [ ] Architecture#NN: Create HoneyDrunk.Cache GitHub repo (human-only — packet 02)
- [ ] Cache#NN: Scaffold HoneyDrunk.Cache — solution, placeholder project, Standards wiring, CI without canary, README/CHANGELOG/LICENSE (packet 03)

**Pairing note:** ADR-0059 is paired with ADR-0058 (Grid-Wide Caching Strategy — commits `ICacheStore<T>` to `Kernel.Abstractions` and `InMemoryCacheStore<T>` to `Kernel`). Both are Proposed at this initiative's filing time. Packet execution can proceed regardless of ADR-0058's Status; the ADR-0059 Status flip waits until ADR-0058 is also Accepted (per ADR-0059's "Done When" gate).

> **Sync (2026-MM-DD):** Initiative scoped today. Packets 01-02 ready to file in Wave 1/2; packet 03 (Cache scaffold) parked on packet 01 merging (so `repos/HoneyDrunk.Cache/` exists) and packet 02 completing (so the GitHub repo exists and the local working tree is cloned).
```

Replace `2026-MM-DD` in the sync line with the date this packet's PR merges.

### `adrs/ADR-0059-stand-up-honeydrunk-cache-node.md` — no edit in this packet

The ADR file is **not** edited in this packet. The Status flip (Proposed → Accepted) is **not** part of this packet. Per the user's standing rule, the scope agent flips Status only after the entire initiative's PRs have merged AND ADR-0058 is also Accepted. That is a separate post-merge housekeeping step. ADR-0059 stays Proposed throughout this run.

### `CHANGELOG.md` (Architecture repo)

Append to the current in-progress version section (per memory `feedback_no_unreleased_commits` — no entries under `## Unreleased`; use the existing dated SemVer-bumped section or create a new one if this commit bumps the version):

`Architecture: Register ADR-0059 standup decisions in catalogs (new honeydrunk-cache row in nodes.json with Core sector and empty contracts list; new honeydrunk-cache row in relationships.json with consumes Kernel and consumed_by_planned [notify-cloud, communications]; new honeydrunk-cache row in grid-health.json with scaffold and repo-creation as active blockers; new cache-adapters module in modules.json). Add Cache row to constitution/sectors.md Core table. Move Cache out of infrastructure/reference/tech-stack.md Planned Nodes and update the Redis-distributed-cache row to reflect Node stood up but no backing yet. Remove HoneyDrunk.Cache from initiatives/roadmap.md Future list (Node now stood up). Create repos/HoneyDrunk.Cache/ context folder with overview.md, boundaries.md, invariants.md stubs. Add ADR-0059 initiative entry to initiatives/active-initiatives.md In Progress section. ADR-0059 stays Proposed in this packet — the Status flip is a separate post-merge housekeeping step requiring ADR-0058 to also be Accepted.`

## Affected Files
- `catalogs/nodes.json` (new `honeydrunk-cache` entry)
- `catalogs/relationships.json` (new `honeydrunk-cache` entry with `consumes: []` and `consumes_planned: ["honeydrunk-kernel"]`; add `honeydrunk-cache` to `honeydrunk-kernel.consumed_by_planned`)
- `catalogs/grid-health.json` (new `honeydrunk-cache` row; add to `summary.blocked_nodes`)
- `constitution/sectors.md` (Core table — add Cache row after Audit)
- `infrastructure/reference/tech-stack.md` (Planned Nodes — remove Cache row; Future Backings — update Redis row)
- `initiatives/roadmap.md` (Future section — remove Cache line)
- `repos/HoneyDrunk.Cache/overview.md` (new file)
- `repos/HoneyDrunk.Cache/boundaries.md` (new file)
- `repos/HoneyDrunk.Cache/invariants.md` (new file)
- `repos/HoneyDrunk.Cache/integration-points.md` (new file)
- `repos/HoneyDrunk.Cache/active-work.md` (new file)
- `initiatives/active-initiatives.md` (new entry under `## In Progress`)
- `CHANGELOG.md` (entry under the current dated SemVer-bumped section)

**Not edited by this work-item:**
- `catalogs/modules.json` — no entry at standup; deferred until the first backing implementation ships actual runtime code (see body for rationale).
- `adrs/ADR-0059-stand-up-honeydrunk-cache-node.md` and `adrs/README.md` — the Status flip is deferred to post-merge housekeeping.
- `constitution/invariant-reservations.md` — ADR-0059 commits zero new invariants at standup, so no reservation row is needed (the file is the coordination point for invariant numbering and only takes claims from ADRs that add invariants).

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No code changes anywhere; metadata + repo-context-folder doc only.
- [x] No new design decisions invented — every edit traces to ADR-0059 (D1 / D3 / D6 / D8 / §If Accepted) or to standard catalog patterns from prior standups (AI, Capabilities, Audit, Communications).
- [x] No `HoneyDrunk.Cache.Abstractions` package invented — Cache declares no abstractions (per repos/HoneyDrunk.Cache/invariants.md item 1 in this packet's body).
- [x] No `ICacheStore<T>` contract authored in this packet — that lives in Kernel.Abstractions per ADR-0058 (separate initiative).
- [x] No edits to `adrs/ADR-0059-stand-up-honeydrunk-cache-node.md` in this packet. The Status flip is a separate post-merge housekeeping step per the user's standing ADR acceptance workflow.

## Acceptance Criteria

- [ ] `catalogs/nodes.json` has a new `honeydrunk-cache` entry with `sector: "Core"`, `signal: "Seed"`, `tags` including `cache`, `distributed-cache`, `backing`, `provider`, `substrate`, and a `long_description` block matching the body of this packet.
- [ ] `catalogs/relationships.json` has a new `honeydrunk-cache` entry with `consumes: ["honeydrunk-kernel"]`, `consumed_by: []`, `consumed_by_planned: ["honeydrunk-notify-cloud", "honeydrunk-communications"]`, `exposes.contracts: []`, `exposes.packages: ["HoneyDrunk.Cache.Adapters"]`, and a `consumes_detail.honeydrunk-kernel` array including `ICacheStore<T>`.
- [ ] `catalogs/relationships.json` `honeydrunk-kernel.consumed_by_planned` array includes `honeydrunk-cache` (in addition to its existing planned consumers).
- [ ] `catalogs/grid-health.json` has a new `honeydrunk-cache` row with `signal: "Seed"`, `version: "0.0.0"`, `canary_status: "none"`, `last_release: null`, and `active_blockers` listing both the GitHub-repo-creation blocker (packet 02) and the scaffold blocker (packet 03).
- [ ] `catalogs/grid-health.json` `summary.blocked_nodes` array includes `honeydrunk-cache`.
- [ ] `catalogs/modules.json` has a new `cache-adapters` entry with `nodeId: "honeydrunk-cache"`, `name: "HoneyDrunk.Cache.Adapters"`, `type: "runtime"` (or `placeholder` if such a type exists in the doc — PR body notes which), `version: "0.0.0"`.
- [ ] `constitution/sectors.md` Core table includes a new Cache row positioned after the Audit row, with `Signal: Seed` and the distributed-cache backing-host responsibility line.
- [ ] `infrastructure/reference/tech-stack.md` Planned Nodes table no longer contains the `| Cache | Core | Distributed caching abstraction |` row.
- [ ] `infrastructure/reference/tech-stack.md` Future Backings table's `Redis / distributed cache` row reflects the stand-up (Node stood up empty per ADR-0059; first backing first-consumer-gated; backing choice deferred to first feature packet).
- [ ] `initiatives/roadmap.md` Future section no longer contains the `- HoneyDrunk.Cache — Distributed caching abstraction` line.
- [ ] `repos/HoneyDrunk.Cache/` folder exists with three files: `overview.md`, `boundaries.md`, `invariants.md`. Each matches the structure used by `repos/HoneyDrunk.Audit/` and `repos/HoneyDrunk.Communications/` for the same files, with content adapted to Cache's role per ADR-0059.
- [ ] `repos/HoneyDrunk.Cache/overview.md` `Status` line reads `Standup ADR Proposed (ADR-0059); scaffold pending. No backing implementations yet.`
- [ ] `repos/HoneyDrunk.Cache/boundaries.md` "What Cache Does NOT Own" section explicitly names: `ICacheStore<T>` contract (lives in Kernel.Abstractions), `InMemoryCacheStore<T>` (lives in Kernel), cache instances (consumer DI composition), invalidation policy/lane choice (consumer), tenant-key discipline (consumer), data classification (consumer).
- [ ] `repos/HoneyDrunk.Cache/invariants.md` carries six repo-local invariants matching the body of this packet (no abstractions of own; backing host not instance; no implementations day one; one-way Pulse telemetry; tenant-keying is consumer's; leaf at stand-up). The trailing paragraph notes that no constitutional invariants are introduced at stand-up per ADR-0059 §New invariants.
- [ ] `initiatives/active-initiatives.md` includes a new "ADR-0059 HoneyDrunk.Cache Standup" block under `## In Progress`.
- [ ] `adrs/ADR-0059-stand-up-honeydrunk-cache-node.md` is **not** modified by this packet. Verify the file is unchanged in the diff. The Status header stays `Proposed` — the flip is deferred to post-merge housekeeping after the initiative completes AND ADR-0058 is Accepted.
- [ ] `CHANGELOG.md` entry appended under the current dated SemVer-bumped section (not under `## Unreleased` per memory `feedback_no_unreleased_commits`). The CHANGELOG entry must **not** claim a Status flip — the ADR stays Proposed in this packet's diff.
- [ ] PR body explicitly notes: (1) all catalog rows added, (2) constitutional sectors and tech-stack and roadmap reconciled, (3) repos/HoneyDrunk.Cache/ context folder created with three stubs, (4) ADR-0059 stays Proposed (no Status flip in this packet — gated on ADR-0058 acceptance and on initiative completion), (5) no `HoneyDrunk.Cache.Abstractions` package invented (Cache declares no abstractions; the implemented contract lives in `Kernel.Abstractions` per ADR-0058 D2).
- [ ] No file under `catalogs/`, `constitution/`, `infrastructure/`, `initiatives/`, or `repos/HoneyDrunk.Cache/` references `HoneyDrunk.Cache.Abstractions` as a package — verify with grep that the string does not appear. (Cache does not ship an Abstractions package; references to it would be drift.)

## Human Prerequisites

None for this packet. ADR-0058 does NOT need to be Accepted before this packet executes — the catalog rows describe the Cache Node's role, which is well-defined by ADR-0059 alone. The ADR-0058 dependency is on the ADR-0059 Status flip (post-merge housekeeping), not on this packet.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Cache does not ship an Abstractions package at all. The contract Cache implements (`ICacheStore<T>`) lives in `HoneyDrunk.Kernel.Abstractions`, where Grid-wide primitives live. This packet's catalog edits reflect that: `exposes.contracts: []` in `relationships.json`, and the `repos/HoneyDrunk.Cache/invariants.md` first invariant states explicitly that Cache declares no abstractions of its own.

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Cache consumes Kernel; nothing in `HoneyDrunk.Cache.*` is referenced back from Kernel. This packet's `relationships.json` edit adds the `honeydrunk-cache → honeydrunk-kernel` edge in one direction only.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Cache is its own Node, hence its own repo (created by packet 02). This packet's catalog edits register it as a separate Node row.

## Referenced ADR Decisions

**ADR-0059 D1 (Cache Node ownership):** HoneyDrunk.Cache is the Core sector's single Node owning distributed-cache backing implementations of `ICacheStore<T>`. It is a backing host, not a contract owner. The catalog edits in this packet reflect this — `exposes.contracts: []` in `relationships.json` and empty contracts list in `nodes.json`.

**ADR-0059 D3 (Initial scaffolding boundary):** First PR produces an empty solution with a single placeholder project (`HoneyDrunk.Cache.Adapters`) per the "lean default" option. No backing implementations on day one. The `modules.json` edit in this packet reflects this — one module entry, version `0.0.0`, type `runtime` (placeholder for the backing-axis family).

**ADR-0059 D6 (Boundaries):** Cache consumes `HoneyDrunk.Kernel.Abstractions` and emits telemetry one-way to Pulse. Owns no contracts. `consumed_by` is empty at stand-up; `consumed_by_planned` includes Notify Cloud and Communications (the two most likely first consumers). The `relationships.json` edit in this packet captures this exact shape.

**ADR-0059 D7 (Catalog updates required):** The exact catalog and reference-doc updates required at acceptance — `nodes.json`, `relationships.json`, `grid-health.json`, `modules.json`, `sectors.md`, `tech-stack.md`, `roadmap.md`, and `repos/HoneyDrunk.Cache/` folder creation. This packet executes that checklist (line 134-147 of ADR-0059).

**ADR-0059 §New invariants ("None at stand-up"):** No new constitutional invariants are introduced at stand-up. The cache-related invariants are committed by ADR-0058. This packet adds no entries to `constitution/invariants.md`.

**ADR-0058 D2 (paired prerequisite for ADR-0059 Status flip):** `ICacheStore<T>` lives in `HoneyDrunk.Kernel.Abstractions`. ADR-0058 commits this; this packet's catalog edits reflect it (Cache `exposes.contracts: []` because the contract lives elsewhere). ADR-0058 must be Accepted before ADR-0059 can flip Accepted — but that gate is on the post-merge housekeeping, not on this packet's execution.

## Dependencies

None. This packet is the foundation of the initiative — it can land before the scaffold packet exists, because the catalog surface is design-decided already in ADR-0059. Packets 02 and 03 reference this one as `work-item:01`.

## Labels

`chore`, `tier-2`, `architecture`, `cache`, `adr-0059`

## Agent Handoff

**Objective:** Register `HoneyDrunk.Cache` in the canonical Architecture catalogs (`nodes.json`, `relationships.json`, `grid-health.json`, `modules.json`), the Core sector table (`constitution/sectors.md`), the tech-stack and roadmap reference docs, and create the `repos/HoneyDrunk.Cache/` context folder with `overview.md`, `boundaries.md`, `invariants.md`. Add an initiative entry to `initiatives/active-initiatives.md`. **Do not edit `adrs/ADR-0059-stand-up-honeydrunk-cache-node.md` in this packet** — the Status flip is a separate post-merge housekeeping step gated on initiative completion AND on ADR-0058 acceptance.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Catalog drift / absence is the bottleneck that blocks downstream consumers (Notify Cloud, Communications) and the grid-health aggregator from referencing the Cache Node. This packet adds the missing entries.
- Feature: ADR-0059 standup initiative, Wave 1, Packet 01.
- ADRs: ADR-0059 (this packet implements the catalog half of its "If Accepted" checklist). ADR-0058 (the paired Grid-wide caching strategy ADR that commits the `ICacheStore<T>` contract Cache implements — also Proposed at this packet's filing time).

**Acceptance Criteria:** As listed above.

**Dependencies:** None — this packet runs first.

**Constraints:**

- **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — Cache does not ship an Abstractions package. The contract Cache implements lives in `HoneyDrunk.Kernel.Abstractions`. Do not invent a `HoneyDrunk.Cache.Abstractions` row in any catalog; do not write "Abstractions" into `repos/HoneyDrunk.Cache/overview.md` Key Packages table. The Cache Node has exactly one package family at stand-up: `HoneyDrunk.Cache.Adapters` (the placeholder).
- **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — The `relationships.json` edit adds the `honeydrunk-cache → honeydrunk-kernel` edge in one direction. Do not add Cache to Kernel's `consumes` array — Kernel does not consume Cache; Cache consumes Kernel.
- **Invariant 11:** One repo per Node. — Cache is a separate Node and gets its own repo. Packet 02 creates it. This packet's catalog rows register Cache as a separate Node entry.
- **No ADR Status flip in this packet.** ADR-0059 stays at `Status: Proposed`. The flip is a separate post-merge housekeeping step the scope agent runs after the entire initiative completes AND ADR-0058 is also Accepted, per the user's standing ADR acceptance workflow. Do not edit the ADR header in this PR.
- **No `HoneyDrunk.Cache.Abstractions` package.** Cache declares no abstractions of its own. The implemented contract lives in `HoneyDrunk.Kernel.Abstractions`. Verify with grep that `HoneyDrunk.Cache.Abstractions` does not appear in any file edited by this packet — if it does, the catalog row is drifted from ADR-0059 D6.
- **Pulse is one-way.** Cache emits telemetry one-way to Pulse with no runtime dependency. The `relationships.json` and `nodes.json` `grid_relationship` strings describe this exactly. Do not add Pulse to Cache's `consumes` array; do not add Cache to Pulse's `consumes` array.
- **Front-loaded standup is intentional.** Cache has no current Grid consumer pulling on a distributed cache. The standup is justified by the charter §"What this charter licenses" and by eight prior front-loaded Node standups. The `consumed_by` array stays empty; `consumed_by_planned` lists the two most likely first consumers per ADR-0059 D3 / D6 (Notify Cloud, Communications).
- **No invariants packet in this initiative.** ADR-0059 explicitly commits no new constitutional invariants at stand-up. This packet does not edit `constitution/invariants.md`. The repo-local `repos/HoneyDrunk.Cache/invariants.md` file (created by this packet) declares Cache-specific invariants that supplement (not extend) the constitution.

**Key Files:**

- `catalogs/nodes.json` — add new `honeydrunk-cache` entry per the body
- `catalogs/relationships.json` — add new `honeydrunk-cache` entry; add `honeydrunk-cache` to `honeydrunk-kernel.consumed_by_planned`
- `catalogs/grid-health.json` — add new `honeydrunk-cache` row; add to `summary.blocked_nodes`
- `catalogs/modules.json` — add new `cache-adapters` entry
- `constitution/sectors.md` — Core table — add Cache row after Audit
- `infrastructure/reference/tech-stack.md` — Planned Nodes table — remove Cache row; Future Backings table — update Redis row
- `initiatives/roadmap.md` — Future section — remove Cache line
- `repos/HoneyDrunk.Cache/overview.md` — new file per the body
- `repos/HoneyDrunk.Cache/boundaries.md` — new file per the body
- `repos/HoneyDrunk.Cache/invariants.md` — new file per the body
- `initiatives/active-initiatives.md` — new entry under `## In Progress`
- `CHANGELOG.md` — append under the current dated SemVer-bumped section

`adrs/ADR-0059-stand-up-honeydrunk-cache-node.md`, `adrs/README.md`, and `constitution/invariants.md` are explicitly **not** edited in this packet.

**Contracts:**

This packet does not author any contracts. It registers a Node that hosts implementations of a contract (`ICacheStore<T>`) declared in `HoneyDrunk.Kernel.Abstractions` by ADR-0058. No `.cs` files are touched.
