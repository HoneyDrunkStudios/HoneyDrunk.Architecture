# ADR-0076: Cache Backing — Azure Cache for Redis with Cost-Aware Sizing

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

[ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) committed the Grid-wide caching strategy — `ICacheStore<T>` in Kernel.Abstractions, InMemory reference in Kernel, **multiple distributed backings acceptable per-Node**. [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md) stood up `HoneyDrunk.Cache` as the home for distributed-backing implementations of `ICacheStore<T>` (Redis-class, Cosmos-with-TTL, Postgres-with-TTL, etc.) — to be implemented when the first consumer pulls on them.

This ADR fills the **first-distributed-backing decision** that ADR-0058 D8 explicitly deferred:

> The Cache Node's first concrete implementation … is a separate feature packet that lands when the first consumer (likely Notify Cloud multi-replica or Communications shared cache) pulls on it.

The first consumer is approaching: Notify Cloud's multi-replica horizon is the canonical trigger per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D3, and the Communications preference cache is a near-term follow-on per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md). Without a backing decision, the first consumer picks unilaterally — and the choice becomes the de-facto Grid default by precedent.

The forcing functions converging now:

- **[ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) Notify Cloud GA** is the imminent first consumer. The API key validation cache and tenant-tier cache cross the multi-replica boundary when Notify Cloud scales past one Container App replica.
- **[ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) Communications preference cache** is a near-term follow-on; the per-recipient preference read is on the hot path for every orchestrated send.
- **[ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md)** committed Service Bus and Event Grid as the cross-Node messaging substrate. Cache invalidation lane 2 ([ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D7) consumes those backings; the choice of cache backing should not require a separate transport backing.
- **[ADR-0015](./ADR-0015-container-hosting-platform.md)** committed Azure Container Apps. The cache backing should compose naturally with the Container Apps environment, the managed-identity story, and the cost-aware Azure posture the Grid already runs.
- **Cost discipline matters.** The charter ([`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids" item 1) explicitly warns against architecture-as-procrastination; over-investing in Redis tiers above what the workload needs is the same failure mode in cost form. Per-environment sizing matters.

This ADR commits the first distributed cache backing for the Cache Node: **Azure Cache for Redis**, with per-environment cost-aware sizing, eviction-policy defaults, and an explicit no-Azure-Redis-modules discipline that keeps the protocol portable.

The charter framing makes the cost-aware sizing posture explicit ([`constitution/charter.md`](../constitution/charter.md) §"What this charter licenses"):

> Spend on the foundation.

— but only where the foundation actually serves the cool stuff. Default dev to Basic C0 (~$16/mo); buy production capacity when production demands it; do not pay for Premium tier when Standard is sufficient.

## Decision

### D1 — Azure Cache for Redis is the default distributed-cache backing

**Azure Cache for Redis** is the canonical distributed-cache implementation of `HoneyDrunk.Cache`'s `ICacheStore<T>` backing slot. Every Node that needs distributed caching composes against the Azure Cache for Redis backing by default; the per-Node escape valve from [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D3 (alternate backings per workload) is preserved but not the first answer.

The committed shape:

- **`HoneyDrunk.Cache.Redis`** as the package — the `ICacheStore<T>` implementation built on `StackExchange.Redis` (the .NET-ecosystem standard Redis client).
- **Azure Cache for Redis** as the runtime backing (Azure-managed Redis offering; same Azure subscription as the rest of the Grid per [ADR-0015](./ADR-0015-container-hosting-platform.md)).
- **Per-environment instance** per [ADR-0053](./ADR-0053-environments-branching-and-release-cadence.md): `redis-hd-{env}` (Naming aligned with the existing `hd-` prefix convention per [Invariant 19](../constitution/invariants.md)).
- **Managed-identity authentication** where Azure Cache for Redis supports it (Standard tier and above support Entra-based auth); access-key-based auth as fallback per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) with keys in Vault.
- **Same Azure region** as the Container Apps environment that consumes it — colocated for latency.

**Why Azure Cache for Redis:**

- **Operational simplicity for a solo-dev shop.** Azure-managed Redis means no Redis-server patching, no failover orchestration, no backup-and-restore discipline, no version-upgrade dance. The operator does not have a Redis-on-call rotation; this is the right operational posture.
- **Native Azure integration.** Same subscription, same managed-identity story, same RBAC, same telemetry pipeline as Container Apps. Standing up a Redis instance is one Bicep template per [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) and one Vault secret entry.
- **Redis protocol is well-understood by every consumer.** `StackExchange.Redis` is the .NET-ecosystem default; AI-assistance gradient is deep; the patterns are well-known.
- **Pricing tiers cover the Grid's actual range.** Basic C0 (~$16/mo) for dev; Standard C1 (~$80/mo) for staging; Standard tier baseline for prod with sizing per Node load. No Premium-tier-required workload exists today.
- **Cache-invalidation Lane 2 (per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D7) composes naturally.** Service Bus delivers invalidation events; the consuming Node calls `RemoveByTagAsync` on its Redis cache. No bespoke pub-sub-on-Redis pattern needed.

The negative form: self-hosted Redis on Container Apps is not the default (D2); Azure Cosmos with TTL is not the default; KeyDB / DragonflyDB / Garnet are not adopted; managed Redis from other vendors (Upstash, Redis Cloud) is not adopted.

### D2 — Per-environment sizing rubric

Per-environment instance sizing balances cost against workload reality. The Grid's defaults:

| Environment | Tier | Approximate cost | Capacity | Rationale |
|---|---|---|---|---|
| **dev** | Basic C0 | ~$16/mo | 250 MB, 1 instance | Single dev environment; no HA needed; fits any expected dev workload |
| **staging** | Standard C1 | ~$80/mo | 1 GB, with replication | HA-shaped to match prod's behavior for realistic testing |
| **prod** | Standard tier baseline; per-Node sizing | starts at ~$80/mo (C1); grows per workload | per-Node load | First production cache is C1; size up to C2 / C3 / C4 as workload data justifies |

**Sizing principles:**

- **Start at the minimum tier per environment.** Resist over-provisioning. Add capacity when telemetry shows it.
- **Standard tier is the prod baseline.** Standard tier provides primary/replica replication, automatic failover, and the managed-identity auth that Basic does not support. Basic is unsuitable for any production-impacting cache.
- **Premium tier is not adopted by default.** Premium tier (clustering, Redis modules, persistence, VNet injection) carries 5-10x the Standard tier cost. The Grid does not need any of those capabilities at MVP scale. Premium is held in reserve for the workload that specifically justifies it.
- **Per-Node sizing is the prod story.** As the Grid grows, individual Nodes may need their own dedicated Redis instances (e.g., the audit-query cache for forensic reads might warrant its own C2 instance independent of the API-key cache). The default is **shared per environment**; per-Node-dedicated instances are the per-Node decision when the workload justifies it.

**Cost evolution.** The dev + staging baseline is ~$96/mo. The prod baseline is ~$80/mo per shared instance. The total cache substrate cost at MVP is ~$176/mo — non-trivial but justifiable as substrate for an actively-scaling Grid. Cost-pressure inflections (production cache instance scaling up past C2, multiple per-Node prod instances) trigger reviews under [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)'s governance discipline.

### D3 — Redis-protocol-only, no Azure-Redis modules

Every consumer of the cache uses **standard Redis protocol commands** through `StackExchange.Redis`. **Azure-specific Redis features (Azure-Redis-Modules, Redis Enterprise features, Azure-only persistence configurations) are not used.**

The discipline:

- **No `RediSearch` module usage.** Search workloads route to a future Search backing (per the [`charter-aware draft`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 7.1 `HoneyDrunk.Search` candidate), not to Redis modules.
- **No `RedisJSON` module usage.** Cached complex objects serialize via the standard pattern (System.Text.Json → string → Redis), not via the JSON module.
- **No `RedisTimeSeries`, `RedisGraph`, `RedisBloom` module usage.** Those are specialized capabilities; the Grid does not need them; adopting them would couple the cache backing to Azure's specific module support.
- **No reliance on Azure-managed Redis persistence configurations.** Cache values are by-construction ephemeral; the Grid does not rely on Redis persistence to durable storage. If a future workload needs durable key-value storage, that is a different backing (likely Cosmos DB, not Redis).

**Why protocol-only:** This is the **cheap vendor-exit hedge**. Redis-the-protocol is widely implemented (open-source Redis, KeyDB, Dragonfly, Garnet, Valkey, Redis Cloud, every cloud-managed Redis offering); Azure's specific module set is not portable. Restricting consumer code to standard Redis commands means a future migration off Azure Cache for Redis (to Redis on Container Apps, to KeyDB, to Valkey when its trajectory matures) is a managed-service swap, not a code rewrite.

This matches the broader Azure-deep-but-protocol-portable posture the Grid adopts across vendor lock-in concerns, now committed as the Grid's chosen vendor posture in [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md); the canonical Azure governance file is [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md), which resolves the future-playbook pointer the [`charter-aware draft`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 2.1 named.

### D4 — Default eviction policy is `allkeys-lru`

The default Redis eviction policy across every Grid Redis instance is **`allkeys-lru`** (least-recently-used across all keys).

The reasoning:

- **The Grid's cache values are cache-shaped, not state-shaped.** Eviction under memory pressure is expected behavior; losing the least-recently-used value is the right loss.
- **`allkeys-lru` is the broadly-correct default for cache workloads.** Redis's `volatile-lru` (only evict TTL-bearing keys) is wrong when not every consumer remembers to set a TTL; `allkeys-lru` is forgiving and matches "cache, not source-of-truth" semantics.
- **The Cache Node ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) does not store source-of-truth data.** Cached values can always be regenerated from their source (Vault, Communications preference store, AI cost-rate App Configuration, etc.). Eviction is acceptable.

**Per-Node override is permitted.** A specific cache instance can override the policy if its workload justifies it. The default applies absent override.

### D5 — Provider abstraction is held; Azure Cache for Redis is the default, not the only

Per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D3, multiple backings can coexist in the Grid. This ADR's commitment is to **Azure Cache for Redis as the default**; per-Node alternative backings are permitted:

- **Cosmos DB with TTL** for cache values that have strong TTL semantics and benefit from Cosmos's existing access in a Node that already has a Cosmos backing.
- **Postgres with TTL** for cache values that already-live in Postgres and benefit from co-location.
- **Self-hosted Redis on Container Apps** for cost-pressured deployments where Azure Cache for Redis's managed-service premium does not earn its keep (per D7).
- **InMemory** for any Node that does not need cross-replica coordination, per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D4.

The default is what new Nodes pick without justification; alternatives require a per-Node argument in their scaffolding packet.

### D6 — Operational discipline

The Redis instances run under standard Grid operational discipline:

- **Telemetry** via the Pulse pipeline per [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) — hit rate, miss rate, evictions, latency p50/p95/p99, connection pool depth.
- **Error tracking** via Azure App Insights per [ADR-0045](./ADR-0045-grid-wide-error-tracking.md) — connection failures, command timeouts, deserialization errors.
- **Cost monitoring** per [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) — per-environment Redis spend on the cost-governance dashboard.
- **DR posture** per [ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md) — cache instances are Tier 2 (operational; loss is non-catastrophic; recovery is automatic on next-cache-warmup). No backup-and-restore discipline needed; per D1's cache-not-state framing.
- **No PII / Restricted-tier values in cache without classification-aware handling.** Per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D6 (classification inheritance) and [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md), any cached value carrying Restricted-tier material requires the per-Node encryption-at-rest discipline. Azure Cache for Redis Standard tier supports encryption in transit by default; encryption at rest is Premium-only at the time of this ADR. **Restricted-tier values are not stored in Standard-tier Azure Cache for Redis without per-value encryption at the application layer.** Premium-tier instances are considered when a workload requires Restricted-tier caching at scale.

### D7 — Self-hosted Redis on Container Apps is permitted for cost-pressured deployments

The cost-aware posture acknowledges that Azure Cache for Redis carries a managed-service premium. **Self-hosting Redis on Container Apps is permitted as a per-Node alternative** when the cost premium does not earn its keep — typically:

- Pre-production environments with predictable low load.
- Specific Nodes whose cache workload is small and well-understood and where the cost saving justifies the operational discipline of self-hosting.

The permission carries explicit operational obligations:

- **The Node owns the self-hosted Redis container's lifecycle** — Redis version, security patches, configuration tuning.
- **No HA** unless the Node implements it. Self-hosted Redis on a single Container App replica is a single point of failure; consumers must tolerate cache flush on Redis restart.
- **No replication, no failover, no managed backups.** All of those are managed-service capabilities; choosing self-host trades them off.

The default remains Azure Cache for Redis; self-host is the explicit-justified exception. The grandfather posture for self-hosted Redis matches every grandfather pattern in the Grid: stays where it is unless a natural migration moment surfaces.

### D8 — Out of scope

The following are explicitly **not** decided by this ADR:

- **Cache-invalidation lanes.** Owned by [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D7. This ADR does not re-decide.
- **Per-Node cache key conventions.** Owned by [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D5 (tenant-keying) and per-Node design.
- **Cosmos-with-TTL backing.** Permitted per D5; the implementation is a separate packet when the first consumer pulls on it.
- **Read-through / write-through cache patterns.** Per-Node design decision; not Grid-wide.
- **Multi-region cache replication.** Out of scope at MVP; reconsidered when a multi-region deployment exists.
- **Redis cluster mode.** Standard tier does not support clustering; Premium tier does. The Grid does not need clustering at MVP; reconsidered when a workload exceeds Standard tier's capacity ceiling.

## Consequences

### Affected Nodes

- **[`HoneyDrunk.Cache`](../adrs/ADR-0059-stand-up-honeydrunk-cache-node.md)** — primary affected Node. Ships `HoneyDrunk.Cache.Redis` as the first distributed backing.
- **[ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) Notify Cloud** — the first likely consumer at multi-replica scale. API key validation cache and tenant-tier cache compose against `HoneyDrunk.Cache.Redis` when the multi-replica deployment lands.
- **[ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) Communications** — preference cache and decision-log cache compose against `HoneyDrunk.Cache.Redis` when introduced.
- **[ADR-0058](./ADR-0058-grid-wide-caching-strategy.md)** — D8's deferred decision is now resolved. The ADR-0058 commitment that "the first distributed backing in `HoneyDrunk.Cache.*` ships when the first consumer pulls on it" is satisfied by this ADR's pick + the follow-up implementation packet.
- **[`HoneyDrunk.Vault`](../repos/HoneyDrunk.Vault/overview.md)** — Redis access keys (when used) and connection strings live in `kv-hd-cache-{env}` per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md). Per-Node access patterns route through the Cache Node's runtime composition.
- **HoneyDrunk.Actions** — the future Bicep deploy workflow per [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) provisions the per-environment Redis instances.

### Invariants

No new Grid-wide invariants introduced. Conventions enforced at packet authoring and review:

- **New Nodes needing distributed cache use `HoneyDrunk.Cache.Redis` as the default backing.**
- **Cache code uses standard Redis protocol commands only; Azure-specific Redis modules are forbidden by default.** (Codifies D3.)
- **Default eviction policy is `allkeys-lru`.** (Codifies D4.)
- **Per-environment sizing follows D2's rubric.** Premium tier requires explicit justification.
- **Restricted-tier values are not cached in Standard tier without application-layer encryption.** (Codifies D6.)

### Operational Consequences

- **The first distributed cache instance ships under managed-Azure-service discipline.** No Redis-server-ops burden on the operator; Azure handles patching, failover (Standard+), backup (Standard+).
- **Per-environment cost is bounded and predictable.** ~$96/mo for dev + staging + initial prod; scales with prod workload.
- **Vendor-exit posture is preserved by D3.** Code uses standard Redis protocol; a future migration to Redis on Container Apps, to KeyDB, to Valkey, or to a different managed-Redis provider is a backing swap, not a code rewrite.
- **The Cache Node's first backing is no longer a future-state concern.** Consumer Nodes know what they compose against.
- **Cache misses on replica restarts are bounded.** Standard tier's primary/replica replication means a single-replica restart does not flush the cache; multi-AZ-failure events would.
- **AI-assistance gradient is preserved.** `StackExchange.Redis` is the .NET-ecosystem default; AI tools have deep pattern recognition; no off-gradient choices.

### Follow-up Work

- Ship `HoneyDrunk.Cache.Redis` package implementation (first Cache Node packet).
- Provision per-environment Redis instances via Bicep per [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md).
- Notify Cloud multi-replica deployment composes `HoneyDrunk.Cache.Redis` at host time (Notify Cloud packet).
- Communications preference cache composes `HoneyDrunk.Cache.Redis` when introduced.
- Per-Node operational dashboards (hit rate, miss rate, latency) land via Pulse per [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md).
- The vendor-exit playbook for Azure (per [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md), canonical home [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md)) cites D3 as the hedge that pre-pays the migration cost for the Cache for Redis surface specifically.
- Watch list: Azure Cache for Redis pricing changes; Valkey project maturity (open-source Redis fork after the Redis license change); managed-Valkey offerings; Premium-tier necessity (current answer: not needed).

## Alternatives Considered

### Self-host Redis on Container Apps as the default

Considered. The argument: cheapest possible Redis (just the Container App cost), maximum control, no managed-service premium.

Rejected as the default per D1's operational-simplicity reasoning. The solo-dev shop does not have the operational discipline (or the time) to be a Redis operator. Self-host is permitted per D7 for cost-pressured deployments where the operator has explicitly traded the managed-service capability for the cost saving. As a default, the managed service wins.

### Garnet (Microsoft's high-performance Redis-compatible server)

Considered. Garnet is Microsoft Research's Redis-protocol-compatible server with claimed higher throughput and lower latency than Redis. Could potentially be self-hosted with better performance than self-hosted Redis.

Rejected as immature in 2026. Garnet was released in 2024; ecosystem adoption is thin; AI-assistance gradient is shallow; production-trajectory is unproven. The Grid's many-decade horizon ([`constitution/charter.md`](../constitution/charter.md)) favors the boring well-understood choice. Reconsidered if Garnet's trajectory matures and Microsoft's stewardship continues.

### KeyDB (multi-threaded Redis fork)

Considered. KeyDB is a multi-threaded Redis fork with strong performance characteristics. Open-source.

Rejected as an immediate choice. Ecosystem thinner than Redis proper; managed-service availability on Azure is non-existent (would require self-hosting). A self-hosted KeyDB on Container Apps is a more complex operational story than Azure Cache for Redis with similar protocol semantics. If the Grid moves to self-hosted Redis later, KeyDB is a credible candidate; today it doesn't earn its keep over the managed Azure offering.

### DragonflyDB (modern Redis-compatible server)

Considered. DragonflyDB has strong performance benchmarks and supports the Redis protocol.

Rejected per commercial-license concerns. DragonflyDB's license (BSL — Business Source License) carries commercial-use restrictions that match the broader pattern this Grid avoids per [ADR-0074](./ADR-0074-testing-library-stack.md)'s stewardship principle. The Grid is a commercial entity; BSL-licensed dependencies are hostile by default for the many-decade horizon.

### Azure Cosmos DB with TTL as the default distributed cache

Considered. Cosmos DB supports TTL on items; could serve cache-shaped data; integrates with the broader Azure posture.

Rejected as the default. Cosmos DB's strengths (global distribution, multiple consistency models, document-database semantics) are not what cache workloads need. Cosmos DB request-unit cost for high-frequency cache operations would exceed Redis cost meaningfully. Held as a per-Node alternative per D5 for Nodes that already have a Cosmos backing and benefit from co-location; not the Grid default.

### Use multiple Redis instances per Node (per-Node dedicated instances) from day one

Considered. The argument: per-Node cache isolation eliminates cross-Node noisy-neighbor concerns from day one.

Rejected as premature. The Grid does not have a per-Node cache workload at MVP that justifies the per-Node-dedicated-instance cost (each new instance is ~$80/mo at C1). The shared-per-environment posture defers per-Node-dedicated decisions to when telemetry shows it's needed. Per D2, scaling up the shared instance is the first answer; per-Node dedicated instances are the second answer; both are cheaper than pre-provisioning per-Node instances pre-emptively.

### Use Redis Cloud (Redis Inc.'s managed offering) instead of Azure Cache for Redis

Considered. Redis Cloud is the canonical managed-Redis-from-Redis-Inc offering; supports more Redis features; deeper Redis-expertise stewardship.

Rejected. Adds a vendor relationship outside the Azure subscription; managed-identity story is weaker (would require alternative auth); cost premium relative to Azure's offering does not earn its keep at MVP scale. Azure Cache for Redis covers the Grid's needs.

### Skip the ADR; let the first Cache consumer (Notify Cloud) pick

Considered. The argument: backing choice is a Cache Node implementation detail; let the first consumer make the decision.

Rejected. The first consumer's pick becomes the de-facto Grid default by precedent. The Cache Node ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) exists precisely to make the backing decision once and let consumers compose. Skipping the ADR pushes the substrate-level decision down to a per-consumer level — exactly the drift the Cache Node was stood up to prevent.

### Adopt Premium tier from day one (for managed-identity, persistence, clustering)

Considered. Premium tier supports all Azure Cache for Redis features; future-proofs.

Rejected on cost grounds. Premium tier carries 5-10x the Standard tier cost ($300+/mo per instance vs. ~$80/mo) for capabilities the Grid does not currently need: clustering (not needed at single-region MVP), persistence (cache values are by-construction ephemeral per D1), VNet injection (not needed at current network posture), managed-identity auth (Standard tier now supports this on newer SKUs). Pre-paying for capability the Grid doesn't use is exactly the architecture-as-procrastination failure mode the charter warns against.

### Adopt an open-source Redis fork pre-emptively given Redis's 2024 license change concerns

Considered. Redis Inc. moved Redis from BSD-3-Clause to SSPL/RSAL in 2024; community concerns about the license trajectory are real. Adopting a fork (Valkey, KeyDB) pre-emptively avoids future migration pain.

Held in watch-list, not adopted. Azure Cache for Redis runs on Redis-the-server (the licensed version); Microsoft has indicated continued investment in Azure Cache for Redis. The license change does not affect Azure customers consuming the managed service. The community-fork landscape is still settling (Valkey just launched; KeyDB's trajectory is uncertain post-Redis-license-change). Per D3, the protocol-portable discipline pre-pays the migration cost if and when Azure Cache for Redis's trajectory turns hostile; pre-emptive forking before the wider ecosystem settles would be premature.

## References

- [`constitution/charter.md`](../constitution/charter.md) — cost-aware discipline, many-decade horizon, vendor-exit honesty
- [`constitution/invariants.md`](../constitution/invariants.md) — invariant 17 (per-Node Vault namespaces), invariant 19 (naming prefix `hd`)
- [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) — credentials via Vault
- [ADR-0015](./ADR-0015-container-hosting-platform.md) — Container Apps (Redis colocates)
- [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) — Communications preference cache (near-term consumer)
- [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) — Notify Cloud (first consumer at multi-replica)
- [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md) — Service Bus / Event Grid (cache invalidation Lane 2)
- [ADR-0036](./ADR-0036-disaster-recovery-and-backup-policy.md) — DR tier (Cache is Tier 2)
- [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md) — Pulse telemetry (cache hit/miss/latency)
- [ADR-0045](./ADR-0045-grid-wide-error-tracking.md) — error tracking (Redis errors)
- [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) — classification inheritance (Restricted in Redis)
- [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) — cost governance
- [ADR-0053](./ADR-0053-environments-branching-and-release-cadence.md) — per-environment naming
- [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) — caching strategy (this ADR fills D8's deferred backing decision)
- [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md) — Cache Node (this ADR ships its first backing)
- [ADR-0077](./ADR-0077-infrastructure-as-code-bicep.md) — Bicep for IaC (Redis provisioning)
- [ADR-0080](./ADR-0080-vendor-lock-in-posture-and-exit-readiness-hedges.md) — vendor lock-in posture umbrella (resolves the future-playbook footnote)
- [`governance/vendor-postures/azure.md`](../governance/vendor-postures/azure.md) — Azure exit-playbook canonical home (stub at acceptance; full per-surface content deferred)
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 2.1 — vendor-exit playbook surfacing observation (resolved by ADR-0080)
