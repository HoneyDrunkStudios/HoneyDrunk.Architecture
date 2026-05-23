# ADR-0059: Stand Up the HoneyDrunk.Cache Node — Home for Distributed Cache Backings

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Create `HoneyDrunk.Cache` GitHub repo as **public** (per the build-in-public default for non-revenue Nodes)
- [ ] Add `honeydrunk-cache` entry to `catalogs/nodes.json` with Core sector and empty contracts list (the contract being implemented, `ICacheStore<T>`, lives in Kernel.Abstractions per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D2)
- [ ] Add `honeydrunk-cache` entries to `catalogs/relationships.json` (consumes `honeydrunk-kernel`; no `consumed_by` at stand-up; `consumed_by_planned` includes whichever Node ships the first distributed-cache backing consumer, expected to be `honeydrunk-notify-cloud` for multi-replica or `honeydrunk-communications` for preference caching)
- [ ] Add `honeydrunk-cache` to `catalogs/grid-health.json` and `catalogs/modules.json`
- [ ] Update `constitution/sectors.md` Core-sector entry to include Cache as the home for distributed-cache backing implementations
- [ ] Update `infrastructure/reference/tech-stack.md` — move `Cache | Core | Distributed caching abstraction` from the "Planned Nodes" section (line ~205) to the current Nodes table; update the `Redis / distributed cache | Future | HoneyDrunk.Cache abstraction` row (line ~185) to reflect "HoneyDrunk.Cache — Node stood up, no backing implementations yet"
- [ ] Update `initiatives/roadmap.md` line ~68 — remove `HoneyDrunk.Cache — Distributed caching abstraction` from the "Future" Nodes list, or move it to a "Stood up, not yet implemented" subsection if such a subsection exists or is created
- [ ] Create `repos/HoneyDrunk.Cache/` context folder with `overview.md`, `boundaries.md`, `invariants.md` stubs (matching the template used by `repos/HoneyDrunk.Communications/` and `repos/HoneyDrunk.Audit/`)
- [ ] File the `HoneyDrunk.Cache` scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline via HoneyDrunk.Actions shared workflows, empty solution with no implementations on day one)
- [ ] Scope agent assigns final invariant numbers if any new invariants are promoted from [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) at acceptance time
- [ ] Scope agent flips Status → Accepted after the scaffold packet lands

## Context

`HoneyDrunk.Cache` has lived as a planned Node in [`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md) ("Cache | Core | Distributed caching abstraction") and in [`initiatives/roadmap.md`](../initiatives/roadmap.md) Future section ("HoneyDrunk.Cache — Distributed caching abstraction") since the early Grid catalogs were authored. It does not exist on disk. It is not cataloged in `catalogs/nodes.json`. No code, no contracts, no CI.

The paired [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) commits the `ICacheStore<T>` contract in `HoneyDrunk.Kernel.Abstractions` and an `InMemoryCacheStore<T>` reference implementation in `HoneyDrunk.Kernel`. That ADR also names **distributed cache backings** — Redis-class, Cosmos-with-TTL, Postgres-with-TTL — as the per-Node, per-workload choice that activates when a consumer pulls on it. Those backings need a home. They do not belong in Kernel (which keeps its surface tight to abstractions and InMemory reference plumbing); they do not belong in each consuming Node (which would N-times duplicate the backing code); they do not belong in `HoneyDrunk.Data` (whose remit is persistence stores, not cache stores).

This ADR stands up `HoneyDrunk.Cache` as the canonical home for those backings. The Node is **front-loaded** — stood up now even though no current Grid consumer pulls on a distributed cache.

The constitution explicitly licenses this front-loading. From [`constitution/charter.md`](../constitution/charter.md) §"What this charter licenses":

> Time invested in ADRs, invariants, substrate hygiene, and architectural correctness is not "premature optimization" or "procrastinating on shipping." It is the work.

The same precedent is established across the AI and Audit sector standups: HoneyDrunk.Agents ([ADR-0020](./ADR-0020-stand-up-honeydrunk-agents-node.md)), HoneyDrunk.Knowledge ([ADR-0021](./ADR-0021-stand-up-honeydrunk-knowledge-node.md)), HoneyDrunk.Memory ([ADR-0022](./ADR-0022-stand-up-honeydrunk-memory-node.md)), HoneyDrunk.Evals ([ADR-0023](./ADR-0023-stand-up-honeydrunk-evals-node.md)), HoneyDrunk.Flow ([ADR-0024](./ADR-0024-stand-up-honeydrunk-flow-node.md)), HoneyDrunk.Sim ([ADR-0025](./ADR-0025-stand-up-honeydrunk-sim-node.md)), HoneyDrunk.Operator (ADR-0018), and HoneyDrunk.Audit ([ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md)) were all stood up before downstream consumers materialized. The pattern is established: when a Node has a defined role in the Grid topology and a Grid-wide ADR commits the contract it will implement, the standup ADR lands before the first feature packet. This Node fits that pattern.

The pairing with [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) is sequenced, not coincidental:

```
ADR-0058 Accepted (contract in Kernel.Abstractions, InMemory in Kernel)
  → ADR-0059 Accepted (Cache Node stood up, empty scaffold)
    → First distributed backing ships when first consumer pulls on it
      → Cache Node gains its first implementation
```

The Node does not flip Status → Accepted until the scaffold packet lands and the catalogs reflect the stand-up. The first distributed backing is **not** part of stand-up scope; it lands later as a separate feature packet when a real consumer activates it.

This ADR is the **stand-up decision** for the Cache Node — what it owns, what it does not own, what scaffolds in the first PR, and what does not. It is not a scaffolding packet. Filing the repo, adding CI, and wiring the empty solution all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.Cache is the Core sector's home for distributed cache backing implementations

`HoneyDrunk.Cache` is the single Node in the Core sector that owns **distributed-cache backing implementations** of the `ICacheStore<T>` contract committed in [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D2. It is a backing host, not a contract owner. It declares no new abstractions; it implements an abstraction declared in `HoneyDrunk.Kernel.Abstractions`.

**Node name:** `HoneyDrunk.Cache`
**Sector:** Core
**Purpose:** Distributed-cache backing implementations and adapters for `ICacheStore<T>`. The Node is the home for Redis-class adapters, Cosmos-with-TTL adapters, Postgres-with-TTL adapters, and any future backing that a consuming Node composes at host time when its workload demands a distributed cache.

The Node is the analog of `HoneyDrunk.Data` (which hosts persistence-store backings) and `HoneyDrunk.Transport` provider packages (which host broker-specific backings). The Grid pattern: contract in Kernel.Abstractions, reference plumbing in Kernel, distributed/provider implementations in a dedicated Node.

**Node sector classification:** Core. The Cache Node sits at the same layer as Kernel, Vault, Transport, Data, and Audit — substrate Nodes whose role is to provide foundational primitives for the rest of the Grid. It is not Ops (no operational orchestration), not AI (no inference or agent runtime), not Meta (not about the Grid's self-development). Core is the right sector.

### D2. Front-loaded per the charter; no current consumer required

This stand-up happens **now** even though no current Grid workload pulls on a distributed cache. The justification, on the record, citing [`constitution/charter.md`](../constitution/charter.md) §"What this charter licenses":

> Time invested in ADRs, invariants, substrate hygiene, and architectural correctness is not "premature optimization" or "procrastinating on shipping." It is the work.

The same charter language has licensed every Node standup since the standup-ADR convention was set 2026-04-19. Agents, Knowledge, Memory, Evals, Flow, Sim, Operator, and Audit were all stood up before their first consumers materialized. The Grid's discipline is to commit the substrate **before** the first feature packet pulls on it, so the feature packet is purely mechanical work against a settled foundation rather than substrate work bundled with feature work.

The "provision Azure resources when first needed" preference (per memory) governs **Azure resource provisioning**, not Node standup. No Azure resource is provisioned by this ADR — the Node has no infrastructure on day one. The scaffold is repo + solution + CI + context folder. The first distributed backing is a separate packet, and the Azure resource (Redis cache, Cosmos container, etc.) it requires is provisioned at *that* packet's time, not this one's.

This is the same pattern Notify Cloud ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) followed — stood up empty, scaffolded with no provider implementations, first real implementation arrived in the next packet wave.

### D3. Initial scaffolding boundary — empty repo, catalog entry, README, no implementations on day one

The first PR (a separate scaffold packet, not part of this ADR's text) produces:

- **Solution layout:** `HoneyDrunk.Cache.slnx` with no .csproj files at stand-up beyond the conventional empty solution skeleton, OR with a single empty `HoneyDrunk.Cache.Adapters` placeholder project carrying the .NET version, analyzers, and CI wiring. The scaffold packet decides which is the more reviewable shape; default lean is a single placeholder project so CI has something to build.
- **`HoneyDrunk.Standards` wiring** on every project (analyzers, EditorConfig, `PrivateAssets: all`) per Invariant 26.
- **CI pipeline** consuming [HoneyDrunk.Actions](../../HoneyDrunk.Actions/) shared workflows — build, test, security scan, package scan. Per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md). No contract-shape canary at stand-up (no Cache-owned contracts to canary against — the contract lives in Kernel.Abstractions and is guarded by Kernel's canary surface).
- **`README.md`** at the repo root and per package, describing purpose, installation, and public API surface (Invariant 12).
- **`CHANGELOG.md`** at solution level (Invariant 12). Starts at `0.0.1` with the standup entry.
- **`LICENSE` file** — public repo default (per [`feedback_repos_public_by_default`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_repos_public_by_default.md) — public unless revenue/compliance/experiment). Cache carries no revenue concern, no compliance concern, no commercial-experiment concern; default-public is correct.
- **No implementations.** No Redis adapter. No Cosmos adapter. No Postgres adapter. The scaffold is the empty room with the right lighting; the furniture arrives with the first feature packet.

The first **implementation** (the first distributed backing) is a separate packet. Its trigger is the first real consumer:

- **Most likely first trigger: Notify Cloud multi-replica.** When PDR-0002's tier ceiling pushes Notify Cloud past a single Container App replica, the API key validation cache and the tenant-tier cache must converge across replicas. That converges through a distributed backing.
- **Alternate first trigger: Communications shared cache.** If Communications introduces a preference / cadence cache that's shared between Communications and Notify Cloud (composed in the same Container App today, may split later), a distributed backing is the convergence point.
- **Unlikely first trigger: AI sector.** AI's existing cost-rate cache is small and per-Node; unlikely to be the first distributed-cache need.

The first backing's choice — Redis-class vs. Cosmos-with-TTL vs. Postgres-with-TTL — is **deferred to the first feature packet**. It is a per-workload decision that depends on the first consumer's access pattern, latency target, and operational posture. Pre-deciding it now would freeze a choice without a real workload to validate against.

### D4. Owner — solo dev, agent-collaborative

Per Grid default ([`project_human_only_convention`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_human_only_convention.md)), the Node is solo-dev-owned with AI agents as collaborators. No `human-only` label on the standup work — agent-collaborative is the default. Stand-up scaffolding, future backing implementations, and ongoing maintenance all happen with the studio's normal agent-augmented workflow.

### D5. Visibility — public, per the Grid default

The repo is **public** per [`project_repos_public_by_default`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_repos_public_by_default.md). No revenue carve-out applies (Cache backings are substrate, not commercial product). No compliance carve-out applies (the Node owns no secrets, no PII storage, no audit-bearing surfaces; cached data is the consumer Node's classification, handled at the consumer side per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D6). No experiment carve-out applies (Cache is committed substrate, not exploratory).

This matches the visibility of every other substrate Node: Kernel public, Vault public, Transport public, Data public, Audit public. Notify Cloud is the lone private Node (commercial revenue carve-out per [ADR-0027 D2](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)). Cache stays in the public default.

### D6. Boundaries — consumes Kernel, publishes backing packages, no abstractions of its own, owns no cache instances

The Cache Node's boundaries against the rest of the Grid:

**What Cache owns:**
- Distributed-cache backing implementations of `ICacheStore<T>` (Redis adapter, Cosmos-TTL adapter, Postgres-TTL adapter, etc.), each shipping as a `HoneyDrunk.Cache.Adapters.{Backing}` package.
- Adapter-specific configuration shapes (connection strings, TTL defaults, serialization choices) as records consumed at host-time DI registration.
- Adapter-specific operational telemetry — connection health, hit/miss/eviction metrics — emitted to Pulse via Kernel's `ITelemetryActivityFactory`.

**What Cache does NOT own:**
- The `ICacheStore<T>` contract itself. That lives in `HoneyDrunk.Kernel.Abstractions` per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D2. Cache implements; it does not declare.
- The `InMemoryCacheStore<T>` reference implementation. That lives in `HoneyDrunk.Kernel` per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D4. Cache hosts distributed backings only.
- Cache instances. Every Node that needs a cache instantiates its own through DI composition; the cached data belongs to the consuming Node. Cache provides the *backing*, not the *cache*. Same boundary Vault uses: Vault owns the secret cache; Key Vault stores the secret.
- Cache invalidation policy or lane choice. Per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D7, each cache chooses one of three named lanes (in-process, Service Bus topic, Event Grid system topic). The lane choice is per-Node, per-cache; Cache backings observe whatever invalidation the consumer issues.
- Tenant-key discipline. Per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D5, tenant-scoping is a property of the value, not of the backing. The backing stores what it's given; the consuming Node is responsible for tenant-keying the cache keys.
- Data classification. Per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D6, cached values inherit the classification of their source. The backing must support encryption-at-rest for Restricted-tier workloads; the consuming Node is responsible for understanding what classification its cached values carry.

**Dependency direction (one-way, strict):**

```
HoneyDrunk.Cache
  ├─ consumes ──► HoneyDrunk.Kernel.Abstractions (ICacheStore<T>, IGridContext, lifecycle, telemetry)
  └─ emits telemetry ──► Pulse (one-way; no runtime dependency)
```

Cache does not consume Notify, Communications, AI, Audit, or any other Node. It is a leaf in the dependency graph from its own side; its consumers (whichever Nodes compose its backings at host time) take the dependency edge.

### D7. Catalog updates required — call out, do not edit in this ADR

This ADR identifies the catalog and reference-doc updates required at acceptance. The updates themselves are filed as scope-agent-dispatched packets, not authored in this ADR text:

- **[`catalogs/nodes.json`](../catalogs/nodes.json)** — Add `honeydrunk-cache` entry with Core sector, empty contracts list (the contract being implemented lives in Kernel.Abstractions), `visibility: "public"` (implicit by absence; or explicit if the catalog now defaults to including the field).
- **[`catalogs/relationships.json`](../catalogs/relationships.json)** — Add `honeydrunk-cache` with `consumes: ["honeydrunk-kernel"]`, empty `consumed_by` at stand-up, `consumed_by_planned: ["honeydrunk-notify-cloud", "honeydrunk-communications"]` (the two most likely first consumers of a distributed backing).
- **[`catalogs/grid-health.json`](../catalogs/grid-health.json)** — Add `honeydrunk-cache` row reflecting empty-stand-up state (no packages published, no contract-shape canary, scaffold pending).
- **[`catalogs/modules.json`](../catalogs/modules.json)** — Add the Cache Node entry with no module entries on day one (modules added as backings ship).
- **[`constitution/sectors.md`](../constitution/sectors.md)** — Update the Core sector entry to include Cache as the home for distributed-cache backing implementations.
- **[`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md)** — Move the Cache row out of "Planned Nodes" (line ~205) to the current Nodes section. Update the `Redis / distributed cache | Future | HoneyDrunk.Cache abstraction` row (line ~185) to reflect that the Node is stood up but no backing is implemented yet; the row may stay in "Future" or move to a "Stood up, awaiting first backing" subsection depending on the tech-stack doc's preferred shape.
- **[`initiatives/roadmap.md`](../initiatives/roadmap.md)** — Update line ~68 (`HoneyDrunk.Cache — Distributed caching abstraction` in the "Future" section). Either remove from "Future" entirely (since stand-up has occurred), or move to a "Stood up, not yet implemented" subsection if such a subsection exists or is created in the same edit.
- **`repos/HoneyDrunk.Cache/` folder** — Create with `overview.md`, `boundaries.md`, `invariants.md` stubs matching the template used by [`repos/HoneyDrunk.Audit/`](../repos/HoneyDrunk.Audit/) and [`repos/HoneyDrunk.Communications/`](../repos/HoneyDrunk.Communications/). The standup-ADR convention does not require `active-work.md` or `integration-points.md` at stand-up — those land when the first feature packet runs.

These updates are listed in the follow-up checklist at the top of this ADR.

### D8. Standup checklist — what scaffolds in the first PR

Per the standup-ADR convention, the scaffolding work is a follow-up packet, not part of this ADR's text. But the first PR must produce a known, audited shape so the scaffold is reviewable. The first PR contains:

- **Solution layout:** `HoneyDrunk.Cache.slnx` with a single placeholder project (`HoneyDrunk.Cache.Adapters`) carrying the .NET version, analyzers, and CI wiring — sized so that CI has a project to build but no production code is included.
- **`HoneyDrunk.Standards` wiring** on the placeholder project (analyzers, EditorConfig, `PrivateAssets: all`) per Invariant 26.
- **CI pipeline** consuming [HoneyDrunk.Actions](../../HoneyDrunk.Actions/) shared workflows — build, test, security scan, secret scan, package scan. Per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md).
- **`README.md`** at the repo root describing the Node's purpose (home for distributed `ICacheStore<T>` backings), the contract it implements (link to Kernel.Abstractions), and the absence of implementations on day one.
- **`CHANGELOG.md`** at solution level (Invariant 12). Starts at `0.0.1` with the stand-up entry.
- **`LICENSE` file** — public-default license matching the rest of the public substrate Nodes (consistent with Kernel, Vault, Transport, Data, Audit).
- **No tests beyond an empty unit-test project** — there's no production code to test on day one. Test invariants 14, 15, 16, 50, 51 still apply once the first backing lands.

The scaffold packet does **not** include: any backing implementation (Redis adapter, Cosmos adapter, Postgres adapter), any contract-shape canary (no Cache-owned contracts to guard — the contract lives in Kernel and is canaried by Kernel), any Azure resource provisioning (no infrastructure on day one), any consumer-side wiring (no Node composes against Cache until the first backing exists).

The scaffold proves the repo exists, CI runs green on the empty solution, and the Node is ready for the first feature packet. Production-shape work follows.

### D9. Downstream coupling rule

`HoneyDrunk.Cache` has no Grid-internal downstream consumers at stand-up — every existing cache in the Grid is either grandfathered (Vault, Auth, AI cost-rate, FeatureFlags) per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D9, or has not yet been introduced. The Node is a leaf in the dependency graph from its own side.

When the first consumer arrives (likely Notify Cloud or Communications), the coupling shape is:

```
Consumer Node (e.g., HoneyDrunk.Notify.Cloud)
  ├─ compiles against ──► HoneyDrunk.Kernel.Abstractions (ICacheStore<T>)
  └─ composes at host time ──► HoneyDrunk.Cache.Adapters.{Backing} (the concrete backing)
```

Same abstraction/runtime split applied throughout the Grid (Vault, Transport, AI, Audit, IdempotencyStore). Consumers compile against the Kernel.Abstractions contract; the backing is a host-time DI registration; the consumer's code does not change when the backing swaps from InMemory to a distributed one.

## Consequences

### Implementation — Done When

This ADR is "Done" when all of the following are true:

- [ ] [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) is Accepted (paired prerequisite — the contract this Node implements must exist before the Node has a defined role).
- [ ] `HoneyDrunk.Cache` public repo created.
- [ ] Scaffold packet landed: solution with placeholder project, HoneyDrunk.Standards wiring, CI pipeline, README, CHANGELOG, LICENSE.
- [ ] CI pipeline green on the empty scaffold.
- [ ] `repos/HoneyDrunk.Cache/` context folder exists in the Architecture repo with `overview.md`, `boundaries.md`, `invariants.md`.
- [ ] `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/modules.json` carry the new Node entry.
- [ ] `constitution/sectors.md` Core-sector entry includes Cache.
- [ ] `infrastructure/reference/tech-stack.md` reflects the stand-up.
- [ ] `initiatives/roadmap.md` reflects the stand-up.
- [ ] Scope agent flips Status → Accepted.

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet — unblocks the following:

- **First distributed-cache backing implementation.** When the first real consumer (Notify Cloud multi-replica or Communications shared cache) pulls on a distributed backing, the implementation packet has a home Node to land in. Without this ADR, the first backing packet would block on a Node-or-not decision.
- **Cache-backing-related Azure resource provisioning.** First Redis-class cache instance, first Cosmos container with TTL, or first Postgres table for cache — provisioned through the Cache Node's bicep/terraform/portal walkthrough at the time the first backing lands, not now.
- **Future cache-related ADRs.** HTTP / output response caching (likely paired with the Gateway standup), `HybridCache` adoption or rejection (deferred per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D8), cache-backing-specific operational ADRs (sharding, eviction policy, multi-region replication) — all have a Node-shaped landing pad once Cache is stood up.

### New invariants

None at stand-up. The cache-related invariants (per-Node-opaque caches; tenant-key isolation; classification inheritance) are committed by [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D1/D5/D6, not by this ADR. The Cache Node enforces them by virtue of being where the backings live; it does not declare them.

If future backings introduce backing-specific invariants (e.g., "Redis backings must use TLS"), those land in subsequent ADRs against the Cache Node, not in this stand-up ADR.

### Catalog obligations

`catalogs/nodes.json` does not currently carry an entry for `honeydrunk-cache`. Adding one is straightforward — the schema fields are well-established by every existing Node entry. The new entry carries:
- `id: "honeydrunk-cache"`
- `name: "HoneyDrunk.Cache"`
- `sector: "Core"`
- Empty contracts list at stand-up (the implemented contract lives in Kernel.Abstractions).
- Tags appropriate to the substrate role: `["cache", "distributed-cache", "backing", "provider", "substrate"]`.
- `visibility` either omitted (defaulting to public) or explicit `"public"` per the existing catalog convention.

`catalogs/relationships.json` gains the dependency edges in D6: `consumes: ["honeydrunk-kernel"]`, `consumed_by: []`, `consumed_by_planned: ["honeydrunk-notify-cloud", "honeydrunk-communications"]`. `catalogs/grid-health.json` gains a row reflecting empty-stand-up state. `catalogs/modules.json` gains the Node entry with no modules on day one. `constitution/sectors.md` gains a Cache row in the Core-sector table. `infrastructure/reference/tech-stack.md` moves the Cache row out of Planned. `initiatives/roadmap.md` removes (or relocates) the Cache line from Future.

These reconciliations are tracked in the follow-up work checklist at the top of this ADR.

### Negative

- **A repo with no production code is reviewable surface that future agents and contributors may misread.** An empty `HoneyDrunk.Cache` repo could prompt the question "what does this Node do?" answered only by the README. Mitigation: the README is the answer, and the README links to [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) and this ADR as the canonical references. The studio's documentation discipline carries the load until the first backing lands.
- **Front-loading the standup increments the Grid's "Nodes stood up but not implemented" count.** The roadmap already carries other Nodes in this state (Sim, Flow, Evals, Knowledge prior to their first features). Mitigation: the count is intentional and bounded — the charter §"What this charter forbids" item 2 ("architecture-as-procrastination") is the antibody. The Grid should periodically self-check that the foundation is serving the cool stuff being built on top of it. At the time of this ADR, the foundation work is matched by active feature work in Communications, Audit, Notify Cloud, and the consumer-PDR scout. The check is healthy.
- **The standup creates an obligation to eventually ship a first backing.** If a year passes and no consumer has pulled on a distributed cache, the Node sits empty and the standup looks like a miscall. Mitigation: the Cache standup is cheap (an afternoon's scaffold work) and the substrate cost is low (a public repo, a CI pipeline, no Azure resources). The downside of a miscall is small; the upside of having the Node ready when the first consumer arrives is real.
- **The scaffold packet's "no implementations on day one" stance means the Node's CI surface is minimal at first.** The contract-shape canary that other Nodes' standups commit (per [ADR-0020](./ADR-0020-stand-up-honeydrunk-agents-node.md) D8, [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D8, etc.) is not applicable here — Cache owns no contracts. The first canary surface arrives with the first backing implementation, scoped to that backing's public surface.

## Alternatives Considered

### Put distributed cache backings in `HoneyDrunk.Data`

Considered. `HoneyDrunk.Data` is the Grid's persistence backing host. Adding cache backings to it would reduce Node count.

Rejected. Persistence stores and cache stores have meaningfully different semantic properties — durability, consistency, retention, the right shape of failure mode. A distributed cache backing that loses data on a node restart is fine; a persistence store that does the same is broken. Mixing them in one Node confuses the boundary. The Grid pattern of one substrate-host Node per concern (Vault for secrets, Data for persistence, Audit for audit records, Transport for messaging, Cache for cache backings) keeps the boundaries crisp.

### Put each backing in its own Node (HoneyDrunk.Cache.Redis, HoneyDrunk.Cache.Cosmos, etc.)

Considered. Each backing as its own repo.

Rejected. The N-repo explosion is operational burden for no architectural benefit. The backings share a contract, a Node-level CI pipeline, a per-Node README, and a Node-level CHANGELOG; sharing them in one repo with per-backing `Adapters.{Backing}` packages is the right granularity. Same pattern Transport uses (one repo, multiple provider packages).

### Defer the standup until the first consumer materializes

Considered. The argument: standup work is dead weight until the first backing implementation is ready to land, so why not bundle them?

Rejected per D2 and the standup-ADR convention set 2026-04-19. Bundling scaffold work into a feature packet conflates substrate decisions with feature decisions; the reviewer agent and the scope agent both work better when the two are separated. The convention is well-established across eight prior Node standups and has not produced a problem case. Following it again here is the right call.

### Skip the standup ADR and just scaffold the repo as a "small change"

Considered. The argument: a Node with no production code is light enough to skip the ADR ceremony.

Rejected per the standup-ADR convention. Every empty cataloged Node gets a standup ADR before scaffolding lands. The convention exists because the Node's *role* and *boundary* are the substrate decision, and capturing them in an ADR is what makes future feature packets dispatchable against a settled definition. Skipping the ADR means the first feature packet has to re-litigate "what does the Cache Node own?" and the answer is invented on the fly. The convention prevents that.

### Make HoneyDrunk.Cache a private repo

Considered. The argument: cache backing code could carry operational secrets or performance-tuning advantages.

Rejected per D5. The backings will be standard adapter code over public Azure services (Redis, Cosmos, Postgres). There are no operational secrets in the code itself — secrets live in Vault per Invariant 9. There are no performance-tuning advantages that benefit from privacy — performance is a function of the Azure service tier, not of the adapter code. The build-in-public default applies; making the repo private would be the kind of "drift into startup logic" the charter §"What this charter forbids" item 1 calls out.

### Declare cache-specific abstractions in HoneyDrunk.Cache.Abstractions instead of in Kernel

Considered. The argument: keep Kernel's surface tight; let Cache own its own abstraction package.

Rejected per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D2. The `ICacheStore<T>` contract is a Grid-wide primitive that every Node may consume. Putting it in `HoneyDrunk.Cache.Abstractions` would force every Node that wants caching to take a runtime dependency on the Cache Node's abstraction package — including Nodes that compose only the InMemory backing (which lives in Kernel). The dependency direction is wrong. Kernel.Abstractions is where Grid-wide primitives live; the Cache Node implements them.

### Bundle the first distributed backing into the standup scaffold

Considered. The argument: ship the standup with a working Redis adapter on day one so the Node is not empty.

Rejected per D3. No current consumer pulls on a distributed cache. Shipping a backing without a real consumer means choosing the backing speculatively (Redis vs. Cosmos vs. Postgres) and the choice is unanchored by workload. When the first real consumer arrives, the choice is informed by access pattern and latency target; the choice made today may turn out wrong. Deferring the first backing to the first-consumer packet is the right discipline.

### Stand up Cache without the paired ADR-0058 contract

Considered. The argument: stand up the Node first, decide the contract later.

Rejected. A Node without a defined contract surface has no defined role. The standup ADR's whole job is to commit role and boundary; absent a contract, those are vague. Pairing this ADR with [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) is what gives both ADRs their definition. Either both Accept together or both stay Proposed together; neither lands alone.
