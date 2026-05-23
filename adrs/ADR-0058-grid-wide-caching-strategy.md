# ADR-0058: Grid-Wide Caching Strategy

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

The Grid has accumulated caches in several Nodes without a unified contract or a shared story for invalidation, tenant isolation, classification, or backing selection. Audit of what exists today:

- **[`HoneyDrunk.Vault`](../repos/HoneyDrunk.Vault/overview.md)** carries an in-memory secret cache fronting Azure Key Vault. Invalidation is two-tier: a TTL fallback plus an Event Grid system-topic webhook on `Microsoft.KeyVault.SecretNewVersionCreated` per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) and [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md). The cache is internal — `ISecretStore` consumers never reach into it. Invariant 21 ("applications must never pin to a specific secret version") exists precisely because pinning would break this cache's invalidation pathway.
- **`HoneyDrunk.Auth`** caches JWT validation artifacts (signing keys, JWKS documents) per its own internal policy. Not exposed.
- **`HoneyDrunk.AI`** caches a cost-rate-table snapshot used by `ICostLedger`, sourced from App Configuration per [ADR-0016 D5](./ADR-0016-stand-up-honeydrunk-ai-node.md) and Invariant 45. Internal, refreshable, never exposed.
- **`HoneyDrunk.FeatureFlags` request-scoped cache** (per the ADR-0055 feature-flag strategy) caches evaluation results inside a single request. Internal.

None of these caches share a contract. None of them know about each other. None of them can be swapped from in-memory to distributed without rewriting their internals against a different surface. There is also no Grid-level statement of how a tenant-scoped cached value must be keyed, how a cache invalidation crosses a Node boundary, or how a cached PII value inherits its source's classification.

Several near-term forcing functions converge on this gap:

- **Notify Cloud's multi-replica horizon.** PDR-0002 commits Notify Cloud at low hundreds of paying tenants at the Pro ceiling. Once the wrapper scales beyond a single Container App replica, any per-process cache (API key validation results, tenant tier descriptors, rate-limit policy) becomes a divergence source. A shared backing is needed, and the seam to that backing should be a contract every Node already speaks.
- **Communications preference / cadence reads** ([ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md)) are on the hot path for every orchestrated send. Reading per-recipient preferences from `IPreferenceStore` on every send becomes the bottleneck the moment Notify Cloud crosses tens of recipients per second. A preference cache is the obvious mitigation, and it needs the same shape as every other cache.
- **AI cost-ledger reads and AI capability-declaration reads** per [ADR-0016 D5](./ADR-0016-stand-up-honeydrunk-ai-node.md) already live in a cache; that cache should be expressible through a Grid-wide contract instead of bespoke.
- **The Cache Node is being stood up alongside this ADR** (paired in [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)). Without a Grid-wide contract decided first, the Cache Node has nothing to implement against; without the Node, the contract has no canonical home for backing implementations beyond an InMemory reference.

The constitution explicitly licenses this kind of substrate work. From [`constitution/charter.md`](../constitution/charter.md) §"What this charter licenses":

> Time invested in ADRs, invariants, substrate hygiene, and architectural correctness is not "premature optimization" or "procrastinating on shipping." It is the work.

This ADR decides the per-Node-opaque boundary, the abstraction shape, the multi-backing posture, the InMemory reference implementation question, the tenant-key isolation invariant, the data-classification inheritance rule, the three invalidation lanes, and what is out of scope (HTTP/output caching, specific provider selection, the Cache Node's first implementation).

The companion ADR-0059 stands up `HoneyDrunk.Cache` as the home for distributed-cache backing implementations of the contract this ADR commits. Acceptance is paired: this ADR alone, without a Node to host the backings, would leave the contract homeless past InMemory; the Node alone, without a contract, would have nothing to implement.

## Decision

### D1 — Caching is per-Node, internal, and opaque across Node boundaries

A cache is an implementation detail of the Node that owns the cached data. No Node reaches into another Node's cache through `Abstractions`, through composition, or through any other surface. Consumers see the cached Node's contracts — `ISecretStore`, `IPreferenceStore`, `ICostLedger`, and so on — and the cache lives behind those surfaces, invisible.

This reaffirms constitution **Invariant 3** ("Provider packages depend on their parent Node's contracts, not internal implementation details") for the cache case specifically: a Node's cache is an internal implementation detail and never appears in the public contract surface. The decision test: if a downstream consumer needs to know whether their request hit the cache, the cache has leaked the abstraction. Cache hit ratios are operational telemetry (per Pulse), not a public surface.

The negative form: there is no `ICacheStore<T>` exposed on any Node's `Abstractions` package. The contract lives in `HoneyDrunk.Kernel.Abstractions` (D2), where every Node already takes a dependency; Nodes that need caching consume it from there.

### D2 — `ICacheStore<T>` ships in `HoneyDrunk.Kernel.Abstractions`

The contract is a minimal, generic, async surface modeled on the patterns the .NET ecosystem has already converged on (`IMemoryCache`, `IDistributedCache`, `HybridCache`). The intent is to borrow proven shapes, not reinvent them.

```
public interface ICacheStore<T>
{
    ValueTask<T?> GetAsync(string key, CancellationToken ct = default);

    ValueTask SetAsync(
        string key,
        T value,
        TimeSpan? ttl = null,
        IReadOnlyCollection<string>? tags = null,
        CancellationToken ct = default);

    ValueTask RemoveAsync(string key, CancellationToken ct = default);

    ValueTask RemoveByTagAsync(string tag, CancellationToken ct = default);
}
```

Four methods, no more at v1:

- `GetAsync` — return the cached value or `null`. No "load if missing" sugar at v1; consumers compose that pattern themselves. (A `GetOrSetAsync` helper may be added in a later additive bump if usage justifies it; deferring keeps the contract minimal.)
- `SetAsync` — store a value with an optional TTL and an optional tag set. Tags are how prefix-style or family-style invalidation is expressed without baking key syntax into the contract.
- `RemoveAsync` — invalidate by exact key.
- `RemoveByTagAsync` — invalidate every value associated with a tag. Backings without native tag support implement this by maintaining a tag-to-key index; backings with native support (Redis, Cosmos with appropriate indexing) use it directly.

The contract is **value-typed by `T`**. Backings serialize and deserialize at the boundary; consumers see typed values. This is a deliberate departure from `IDistributedCache`'s `byte[]` posture (which forces every consumer to own its own serialization) and an alignment with `HybridCache`'s typed posture (which is where the .NET ecosystem is heading at the time of this ADR).

The shape applies the grid-wide naming rule (interfaces retain the `I` prefix; records drop it). Per Invariant 35 / [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md), this contract is additive on Kernel.Abstractions (minor bump). It does not collide with any existing Kernel surface.

### D3 — Multiple backings are acceptable; in-memory is the default

Backings live in a per-Node-choice posture. This deliberately mirrors the **`IIdempotencyStore` pattern from [ADR-0042 D2](./ADR-0042-idempotency-contract-for-async-boundaries.md)** — the Grid commits the contract in Kernel.Abstractions; backings (Cosmos, Redis-class, Postgres-with-TTL) ship as separate packages and are composed per-Node at host time.

The committed posture:

- **In-memory is the default and the assumed baseline for every Node today.** Every Node that needs a cache can compose against `InMemoryCacheStore<T>` (D4) and ship without standing up infrastructure. This matches the Grid's current scale — a single Container App replica per Node, no horizontal coordination requirement.
- **Distributed backings are a per-Node choice activated when a workload pulls on them.** Notify Cloud crossing multi-replica is the canonical first trigger. When it lands, that Node composes a Redis-class or Cosmos-with-TTL backing at host time; no other Node changes.
- **Multiple backings can coexist in the same Grid.** Vault's secret cache may stay InMemory + Event Grid invalidation; Notify Cloud's API key cache may go Redis; Communications's preference cache may go Cosmos-with-TTL; AI's cost-rate cache may stay InMemory. Per-Node, per-workload, no Grid-wide harmonization required.

The provider-slot pattern is the same one Vault, Transport, Audit, AI, and IdempotencyStore use. The Cache Node ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) is the home for the distributed backing packages — InMemory may live alongside in Kernel (D4), but everything beyond it lives in `HoneyDrunk.Cache.*` packages.

The cost story stays correct because the default backing is InMemory: a Node that does not need distributed caching pays nothing for the contract beyond the Kernel reference it already has.

### D4 — InMemory reference implementation ships in Kernel

`HoneyDrunk.Kernel` ships `InMemoryCacheStore<T>` alongside the contract, backed by `IMemoryCache` from `Microsoft.Extensions.Caching.Memory`. The rationale:

- **Removes friction for the first consumer.** A Node that wants `ICacheStore<T>` should be able to register the InMemory backing in one line at host composition, the same way it registers `IIdempotencyStore`'s InMemory variant today.
- **Consistent with how Kernel already ships other reference plumbing.** Kernel ships `InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`, `InMemoryIdempotencyStore`, and the InMemory Transport provider. The InMemory cache fits the established pattern.
- **No new runtime dependency on Microsoft.Extensions.Caching.Memory at the abstraction layer.** `Microsoft.Extensions.Caching.Memory` is allowed on `HoneyDrunk.Kernel` (the runtime package), not on `HoneyDrunk.Kernel.Abstractions` (which keeps its zero-dependency stance per Invariant 1). The contract sits in Abstractions; the InMemory implementation sits in Kernel proper.
- **Test invariant alignment.** Invariant 15 forbids unit-test dependencies on external services and points consumers at InMemory providers. Shipping the InMemory cache in Kernel means every Node's tests have a working backing out of the box, with no per-Node fixture.

The Cache Node ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) is the home for **distributed** backings (Redis adapter, Cosmos-TTL adapter, Postgres-TTL adapter, etc.) when workloads pull on them. The InMemory reference is the only backing that lives in Kernel; everything else lives in Cache.

### D5 — Tenant-key isolation invariant

Any cache that holds tenant-scoped data **must** prefix-key by `TenantId`. The committed key shape mirrors Vault's pattern (`tenant-{tenantId}-{secretName}`):

```
{cache-purpose}:tenant-{tenantId}:{logical-key}
```

For example: `notify-cloud-apikey:tenant-01JX...:hash-abc123`, `communications-pref:tenant-01JX...:recipient-rcp_xyz`.

For the `TenantId.Internal` sentinel (per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md)), the prefix may collapse to the node-level convention without `tenant-` interpolation — the convention is identical to Vault's secret-path convention for Internal secrets.

This is the single most likely source of a cross-tenant data leak. A cache without tenant prefixing serves tenant A's value to tenant B's request whenever a key collides — and the moment two tenants choose the same logical identifier (an email address, a recipient ID, a username), they collide. The invariant closes that hole.

Enforcement: the cache backing itself does not interpret the key — it stores what it's given. The discipline lives at the **call site**. The `security` specialist agent (per [ADR-0046 D2](./ADR-0046-specialist-review-agents.md)) and the review-agent checklist (per [ADR-0044 D3](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)) gain a checkpoint: "is this cache key tenant-scoped where the value is tenant-scoped?" A Node-specific canary may project this into a compile-time check by routing tenant-scoped reads through a `TenantScopedCacheStore<T>` adapter (analogous to Vault's `TenantScopedSecretResolver` per Invariant 9a), but the adapter is per-Node and not forced by this ADR.

The invariant text (proposed for `constitution/invariants.md`, numbering finalized at acceptance):

> Any cache holding tenant-scoped data must key by `TenantId` using the `tenant-{tenantId}-{logical-key}` convention. `TenantId.Internal` collapses to the node-level convention. Tenant-scoping is a property of the value being cached, not of the backing.

### D6 — Data classification inheritance

Cached values inherit the classification of their source per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md). A cache that holds Restricted-tier or Sensitive-PII material inherits Restricted-tier handling rules from ADR-0049 D1:

- Encrypted at rest in tenant-isolated backings.
- Forbidden in observability / telemetry channels (cache *contents* are never logged; cache hit/miss telemetry per Pulse may carry only the key — and only the key when the key itself is not PII).
- Subject to the right-to-erasure mechanics ADR-0049 D6 commits — a cache holding a value about a subject who exercises erasure must invalidate that value on receipt of the erasure event, not wait for TTL expiry.

Inherited Confidential-tier values follow the Confidential handling rules; Internal-tier values follow Internal rules. The cache is a transmission medium for the source's classification, not a laundering surface that converts Restricted to Internal by virtue of being a copy.

This binds the cache contract into the data-classification regime that ADR-0049 commits and prevents a subtle pattern where Restricted data leaks out of a Node's primary store, into the cache, and from there into observability or into a cross-classification channel.

The Cache Node ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) backing implementations must support encryption-at-rest for Restricted-tier workloads. The InMemory backing is in-process memory — it is encrypted by the host's memory protection, which is the standard .NET in-process posture, and is acceptable for Restricted values within the bounds of a single trust boundary.

### D7 — Three named cache-invalidation lanes

Invalidation crosses a Node boundary by exactly one of three named lanes. The choice is made per cache, per workload, by the Node that owns the cache.

**Lane 1 — In-process direct invocation.**
The cache lives in the same process as the writer; invalidation is a direct call on `ICacheStore<T>.RemoveAsync` (or `RemoveByTagAsync`) at the write site. Used when reader and writer co-locate. Communications's preference cache, when introduced, is the canonical example — the preference write and the cache invalidation share a process.

**Lane 2 — In-Grid domain events via Service Bus topic through Transport.**
The writer publishes a domain event over the default Service Bus topic per [ADR-0028 D2](./ADR-0028-event-driven-architecture-and-messaging.md); subscribers in other Nodes receive the event and invalidate their own caches. Used when reader and writer cross a Node boundary. The classic shape: Notify Cloud publishes `TenantTierChanged`; Communications subscribes and invalidates its cached tenant-tier descriptors.

The domain event itself follows the existing ADR-0028 D2 pattern; it carries an `IdempotencyKey` per [ADR-0042 D1](./ADR-0042-idempotency-contract-for-async-boundaries.md), so a re-delivered invalidation is dedup'd at the consumer's `IdempotentMessageHandler<T>` boundary and does not produce double work.

**Lane 3 — Infrastructure-emitted events via Event Grid system topic.**
Used when the trigger for invalidation is an Azure-managed resource event (a secret rotated, a blob written, a configuration value changed) per [ADR-0028 D6](./ADR-0028-event-driven-architecture-and-messaging.md). The Vault rotation cache-invalidation flow (per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) Tier 3) is the canonical, already-live example: Key Vault's `Microsoft.KeyVault.SecretNewVersionCreated` event delivers via Event Grid to a Vault webhook, which calls into `IInvalidate` (per ADR-0006's required follow-up) and the local cache drops the affected key.

The three lanes are mutually exclusive per cache, by design. A cache that needs to react to both an in-Grid domain event and an Azure-resource event chooses one as the primary lane and the other as a degenerate input (e.g., Vault's cache is primarily Lane 3, and any in-Grid hint to "drop this key" is implemented internally as a same-process Lane 1 call). The decision is per-cache, by the owning Node.

**A follow-up update to [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md) adds a "Cache Invalidation" row to its use-case → backing matrix**, calling out these three lanes explicitly. The update lands as a packet against the Architecture repo when this ADR flips to Accepted.

### D8 — Out of scope, with explicit follow-up pointers

This ADR is deliberately scoped to **per-Node application-level caching**. The following are explicitly out of scope, each pointed at a follow-up artifact:

- **HTTP / output response caching** at Web.Rest, the future Gateway Node, or the Cloudflare edge ([ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md)). Output caching is a different shape — keyed by URL plus vary headers, governed by `Cache-Control` semantics, owned by the edge layer. It deserves its own ADR, likely tied to the Gateway standup. This ADR does not preclude it; it does not commit anything about it either.
- **Provider selection for any specific Node's distributed cache.** Redis-class vs. Cosmos-with-TTL vs. Postgres-with-TTL is a per-Node, per-workload decision made when the workload pulls on a distributed backing. The Cache Node ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) is the home for those backings; the choice is made per first-real-consumer.
- **The Cache Node's first concrete implementation.** This ADR commits the contract; ADR-0059 stands up the Node as the home for backings; the first backing implementation is a separate feature packet that lands when the first consumer (likely Notify Cloud multi-replica or Communications shared cache) pulls on it.
- **`HybridCache` adoption.** Microsoft's `HybridCache` (in preview / GA at the time of this ADR per .NET 9+) is the closest .NET ecosystem analog to D2's shape. It is intentionally not adopted as the binding contract because committing the Grid to a Microsoft.Extensions surface that is still settling would constrain backing choices to those that fit `HybridCache`'s extension model. If `HybridCache` stabilizes and the ecosystem converges, a future ADR may make `ICacheStore<T>` a thin facade over it. Until then, the Grid's contract is its own.

### D9 — Grandfather existing caches; no mandatory retrofit

Existing caches keep what they have:

- **Vault's in-memory + Event Grid invalidation flow** stays as is. The cache pre-dates `ICacheStore<T>` and works correctly; retrofitting it adds risk for no immediate benefit. If a future change to Vault's secret-cache backing is warranted, that change should land on `ICacheStore<T>` — but the trigger is "we're changing Vault's cache anyway," not "this ADR forced a retrofit."
- **Auth's JWT validation cache** stays as is. Same reasoning.
- **AI's cost-rate-table cache** stays as is.
- **FeatureFlags's request-scoped cache** stays as is.

**New caches in any Node SHOULD use `ICacheStore<T>`.** When Communications introduces its preference cache, when Notify Cloud introduces its API key cache, when any future Node introduces a cache — that cache is composed against `ICacheStore<T>`. The contract is the default for new work.

**Existing caches MAY migrate during normal evolution.** If Vault's cache is being reworked for an unrelated reason (a new feature, a bug fix that touches the cache internals), the migration is welcome. Forced migration is not. The grandfather clause prevents this ADR from triggering a fleet-wide retrofit campaign.

## Consequences

### Affected Nodes

- **[`HoneyDrunk.Kernel`](../repos/HoneyDrunk.Kernel/overview.md)** — primary affected Node. Gains `ICacheStore<T>` in Kernel.Abstractions (D2) and `InMemoryCacheStore<T>` in the runtime package (D4). Additive minor bump per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md); no breaking change.
- **`HoneyDrunk.Cache`** — stood up in the paired [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md). Home for distributed backing implementations of `ICacheStore<T>`. No contracts of its own; no implementations on day one. First implementation lands via a separate feature packet when the first consumer pulls on it.
- **`HoneyDrunk.Communications`** — first likely consumer at scale. The preference / cadence cache, when introduced, composes `ICacheStore<T>`. Choice of backing (InMemory vs. distributed) is per-Node at host-time composition.
- **`HoneyDrunk.Notify.Cloud`** — first likely consumer of a distributed backing. API key validation cache and tenant-tier cache compose `ICacheStore<T>`; the backing choice flips to distributed when multi-replica deployment lands.
- **`HoneyDrunk.Vault`, `HoneyDrunk.Auth`, `HoneyDrunk.AI`, `HoneyDrunk.FeatureFlags`** — grandfathered under D9. No mandatory change. May migrate during normal evolution.
- **`HoneyDrunk.Transport`** — affected indirectly: Lane 2 (D7) routes cache-invalidation domain events through the default Service Bus topic. No change to Transport itself; the lane uses existing primitives.
- **[`HoneyDrunk.Architecture`](../README.md)** — catalog and constitution updates per "Catalog and Constitution Obligations" below.

### Invariants

Proposed for `constitution/invariants.md` (numbering finalized at acceptance):

- **Caches are per-Node, internal, and never crossed through `Abstractions`.** A Node's cache is an implementation detail behind its public contracts; no consumer reaches into another Node's cache. (D1)
- **Any cache holding tenant-scoped data keys by `TenantId` using the `tenant-{tenantId}-{logical-key}` convention.** Tenant-scoping is a property of the value, not of the backing. (D5)
- **Cached values inherit the classification of their source per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md).** Caches holding Restricted or Sensitive PII material respect Restricted-tier storage and observability rules. (D6)

The third invariant strengthens [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md)'s classification regime; the second extends [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md)'s tenant-keying discipline; the first reaffirms Invariant 3's boundary-preservation rule against the specific risk of cache-as-leak.

### Operational Consequences

- **Kernel.Abstractions versioning ticks minor.** Per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) cascade procedure, the additive `ICacheStore<T>` contract requires every downstream Node to either bump its Kernel.Abstractions reference at the cascade-window or stay pinned at the prior minor. No compile-time break.
- **InMemory cache cost is zero.** It's a `MemoryCache` instance per Node — the same allocation pattern every Node already uses internally.
- **Distributed backing cost is per-Node, on-demand.** No infrastructure provisioned by this ADR; the first cache that needs Redis-class backing triggers the first provisioning packet against the Cache Node.
- **Lane 2 cache-invalidation events consume the default Service Bus namespace** (per [ADR-0028 D5](./ADR-0028-event-driven-architecture-and-messaging.md), shared per environment). No new namespace, no new cost line.
- **Lane 3 already-paid.** Event Grid system topics are billed per-event at $0.60/M; Vault's existing flow proves the cost is negligible at the Grid's scale.
- **Telemetry channel discipline.** Cache hit/miss/eviction metrics flow to Pulse per existing OTel patterns. Cache *contents* never appear in telemetry — Invariant 8's "secrets never appear in logs/traces/exceptions/telemetry" rule extends naturally to cached secret values, cached PII, and any cached Restricted-tier material.
- **Right-to-erasure mechanics.** ADR-0049 D6 commits the right-to-erasure surface; D6 above binds caches to it. When a Node owns a cache of Restricted/PII values about a subject and an erasure event arrives, the Node invalidates the affected keys on the erasure handler. The mechanism is per-Node and uses one of the three lanes; the obligation is global.

### Catalog and Constitution Obligations

Filed as follow-up packets when the scope agent dispatches execution against this ADR:

- [ ] Add `ICacheStore<T>` to `catalogs/contracts.json` under `honeydrunk-kernel`'s contract list, with `kind: "interface"`.
- [ ] Add the three new invariants (D1, D5, D6 forms above) to `constitution/invariants.md` under their respective sections (Dependency / Multi-Tenant Boundary / Data).
- [ ] Update [`ADR-0028`](./ADR-0028-event-driven-architecture-and-messaging.md)'s use-case → backing matrix with a "Cache Invalidation" row enumerating the three lanes (D7).
- [ ] Update `repos/HoneyDrunk.Kernel/boundaries.md` to list `ICacheStore<T>` and `InMemoryCacheStore<T>` among Kernel's owned contracts.
- [ ] Update `repos/HoneyDrunk.Vault/overview.md` to note that the Vault cache is grandfathered under D9 and may migrate during future evolution, not forced.
- [ ] Update `.claude/agents/scope.md` and `.claude/agents/review.md` checklists per Invariant 33 (coupled context-loading): when a packet introduces a new cache, the reviewer checks tenant-keying (D5), classification inheritance (D6), and that the invalidation lane is named (D7).
- [ ] The scope agent flips Status → Accepted after the paired [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md) is also accepted and the Kernel cascade packet for the new contract has landed.

### Follow-up Work

- Implement `ICacheStore<T>` in `HoneyDrunk.Kernel.Abstractions` (1 packet against Kernel).
- Implement `InMemoryCacheStore<T>` in `HoneyDrunk.Kernel` (same packet or sibling).
- Stand up `HoneyDrunk.Cache` per [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md) (scaffold packet against the new repo, after ADR-0059 is Accepted).
- First distributed backing in `HoneyDrunk.Cache.*` ships when the first consumer pulls on it (separate packet, deferred — no current consumer needs a distributed cache today).
- [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md) "Cache Invalidation" row update (1 packet against Architecture).
- Communications preference / cadence cache, when introduced, composes `ICacheStore<T>` (per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) follow-up work, not part of this ADR's packet set).
- HTTP / output response caching ADR (separate, likely paired with the Gateway standup; not on this ADR's cascade).

## Alternatives Considered

### Commit `HybridCache` (Microsoft.Extensions.Caching.Hybrid) as the Grid contract instead of declaring `ICacheStore<T>`

Considered. `HybridCache` (.NET 9+) is Microsoft's converged surface that unifies in-process and distributed caching with typed values, tag invalidation, and stampede protection. It is the closest the .NET ecosystem has to what D2 commits, and adopting it directly would save the work of declaring a new abstraction.

Rejected for two reasons. First, `HybridCache` is still settling at the time of this ADR — it is GA in .NET 9 but its extension model and the backing-provider story are still maturing in the ecosystem. Committing the Grid to a contract that is still being tuned upstream forces the Grid to either pin to a specific .NET version or carry surface churn. Second, `HybridCache`'s opinionated stance on "always layered — local plus remote" is great for the workload it targets (web-scale read-heavy caching) but does not fit the per-Node-opaque shape D1 commits. The Grid wants the contract; it does not want `HybridCache`'s layering policy baked into every Node's cache decision.

A future ADR may make `ICacheStore<T>` a thin facade over `HybridCache` if the ecosystem converges. The current commitment is the contract, owned by the Grid.

### Force every existing cache to migrate to `ICacheStore<T>`

Considered. The argument: uniformity is valuable, and grandfather clauses produce technical-debt sediment.

Rejected per D9's reasoning. The existing caches work correctly. Migration risk per cache outweighs the uniformity benefit at the Grid's current scale, where the existing caches are five in total and each is isolated behind its owning Node's contracts. Migration may be welcomed during natural evolution, but a campaign of forced retrofits is exactly the architecture-as-procrastination failure mode the charter forbids in §"What this charter forbids" item 2.

### Centralize all caching in `HoneyDrunk.Cache` (caches owned by the Cache Node, not by each Node)

Considered. The opposing model: a Node that wants caching delegates the entire cache to a central Cache service; the Node's contracts return cached values transparently through some remote call.

Rejected. This violates D1 (caches are internal to the Node that owns the cached data) and breaks Invariant 3 (boundary preservation). It also produces a coordination chokepoint — every cache decision becomes a cross-Node concern. The Cache Node is the home for *backing implementations*, not for cache *ownership*. The data lives in the consuming Node; the backing lives where the backing lives. Same separation Vault uses (Vault owns the secret cache; Key Vault stores the secret).

### Per-Node abstractions instead of a Grid-wide `ICacheStore<T>`

Considered. Each Node that needs a cache declares its own contract specific to its data (`ISecretCache`, `IPreferenceCache`, etc.) and the Cache Node provides backings for each.

Rejected. The N-contract explosion produces exactly the per-Node-drift this ADR exists to prevent. Every new cache invents its own surface, every backing implements N contracts, and the testing-fixture story compounds. The Grid-wide contract is the cheaper substrate decision.

### Skip the contract and let each Node use `IMemoryCache` / `IDistributedCache` directly

Considered. Microsoft.Extensions already ships these surfaces; the Grid could just adopt them without an additional layer.

Rejected. `IMemoryCache` is in-process only; `IDistributedCache` is byte-array-typed and forces every consumer to own serialization. Neither expresses tag-based invalidation. Neither carries any tenant or classification discipline. Committing the Grid to those surfaces directly means every Node that wants tag invalidation, type safety, or tenant prefixing carries the cost of either subsetting Microsoft's contract or wrapping it locally — at which point we have N local wrappers instead of one Grid wrapper, which is the failure mode of the previous alternative.

### Ship the InMemory backing in `HoneyDrunk.Cache` (the Node), not in Kernel

Considered. The argument: keep Kernel's surface tight; let the Cache Node own all backings including InMemory.

Rejected per D4. The InMemory backing is the testing-fixture default per Invariant 15 — every Node's tests need it. Putting it in the Cache Node means every test project across the Grid acquires a transitive dependency on the Cache Node just to compose its tests against an InMemory cache. That is the same anti-pattern Kernel's other InMemory providers exist to prevent. InMemory in Kernel is the established Grid pattern; the Cache Node owns the distributed backings.

### Defer cache-invalidation lanes (D7) to a future ADR

Considered. The argument: D7 could be a follow-up; this ADR could commit only the contract.

Rejected. The lanes are the load-bearing operational discipline. Without naming them, the first cross-Node cache invalidation invents an ad-hoc pattern that becomes the de-facto Grid standard by precedent. Three named lanes — and the rule that each cache picks one — is what makes the contract operational, not just declarative.

### Add a "load-if-missing" `GetOrSetAsync` method to the contract at v1

Considered. The pattern is convenient — `var value = await cache.GetOrSetAsync(key, async ct => await source.LoadAsync(ct), ttl, ct);` — and is what `HybridCache` exposes as its primary API.

Deferred, not rejected. The minimal v1 surface (Get/Set/Remove/RemoveByTag) is intentionally tight; consumers compose the load-if-missing pattern themselves at call sites where the source semantics matter. If usage shows that every Node ends up writing the same wrapper, a follow-up additive bump (`GetOrSetAsync`) is the right answer. Shipping it at v1 risks baking in a stampede-protection policy that is not the right shape for every workload (e.g., Vault's load-if-missing path is gated by a per-secret lease, not a per-key one).

### Mandate distributed backing for every Node from day one

Considered. The argument: future-proof every Node against multi-replica horizons.

Rejected. The cost is real — even the cheapest distributed backing carries per-Node infrastructure, configuration, and operational burden — and the benefit is zero today, since no Node currently runs multi-replica. The Grid's current scale supports InMemory everywhere. The contract is what lets the migration happen per-Node, per-workload, without re-architecture; mandating distributed upfront violates the "provision Azure resources when first needed" preference for no operational reason.

### Skip the data-classification inheritance rule (D6) and let consumers manage it per-cache

Considered. The argument: D6 is implicit — if the value is classified, its copy in the cache is also classified.

Rejected. Implicit invariants are the ones reviewers miss. ADR-0049 commits the classification regime; this ADR makes the regime concrete for the specific case of cached copies. Stating it explicitly closes a class of subtle bug where a Restricted value lands in an InMemory cache that leaks into a log line "for debugging" and now Restricted material is in observability. The reviewer agent's checklist (per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 category 9 Security) catches it because D6 makes the rule namable.
