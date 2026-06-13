---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0058", "wave-4"]
dependencies: ["work-item:04"]
adrs: ["ADR-0058"]
wave: 4
initiative: adr-0058-caching-strategy
node: honeydrunk-kernel
---

# Add InMemoryCacheStore<T> reference implementation to HoneyDrunk.Kernel runtime

## Summary
Implement the ADR-0058 D4 `InMemoryCacheStore<T>` reference implementation in the `HoneyDrunk.Kernel` runtime package, backed by `IMemoryCache` from `Microsoft.Extensions.Caching.Memory`. Includes the DI registration extension (`AddInMemoryCacheStore<T>`), a tag-to-key index for `RemoveByTagAsync`, and unit tests covering Get/Set/Remove/RemoveByTag/TTL/tag-invalidation semantics. Appends to the in-progress `[0.8.0]` CHANGELOG from packet 04 — no new version bump.

## Context
ADR-0058 D4 commits an InMemory reference implementation of `ICacheStore<T>` in `HoneyDrunk.Kernel` (the runtime package, not Abstractions). The rationale:

- Removes friction for the first consumer — register the InMemory backing in one line at host composition.
- Consistent with how Kernel already ships other reference plumbing (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`, `InMemoryIdempotencyStore`, and the InMemory Transport provider).
- `Microsoft.Extensions.Caching.Memory` is allowed on `HoneyDrunk.Kernel` (the runtime package) but **not** on `HoneyDrunk.Kernel.Abstractions` (which keeps its zero-dependency stance per invariant 1).
- Test invariant alignment — invariant 15 forbids unit-test dependencies on external services and points consumers at InMemory providers. Shipping the InMemory cache in Kernel means every Node's tests have a working backing out of the box, with no per-Node fixture.

Packet 04 shipped the `ICacheStore<T>` contract and bumped the `HoneyDrunk.Kernel` solution to `0.8.0`. This packet adds the runtime implementation and appends to the in-progress `[0.8.0]` CHANGELOG entry (invariant 27 — subsequent packets on the same solution version append to the existing entry, do not bump again).

## Scope
- `HoneyDrunk.Kernel` runtime package — new types:
  - `InMemoryCacheStore<T>` — `IMemoryCache`-backed implementation of `ICacheStore<T>` from `HoneyDrunk.Kernel.Abstractions`.
  - Internal tag-to-key index supporting `RemoveByTagAsync`.
  - `AddInMemoryCacheStore<T>` extension method on `IServiceCollection` for DI registration.
- `HoneyDrunk.Kernel` package `CHANGELOG.md` updated (per-package entry — packet 04 left this empty; this packet fills it under `[0.8.0]`).
- Repo-level `CHANGELOG.md` `[0.8.0]` entry receives an append describing the InMemory backing.
- Unit tests covering Get/Set/Remove/RemoveByTag, TTL expiry, tag-invalidation, and concurrent Set/Get correctness.

## Proposed Implementation
1. **`InMemoryCacheStore<T>`** — a class in `HoneyDrunk.Kernel` implementing `ICacheStore<T>`:
   - Backed by an injected `IMemoryCache` (allow each `InMemoryCacheStore<T>` to share a single `MemoryCache` per host or hold its own; default to the shared `IMemoryCache` from DI).
   - `GetAsync(string key, CancellationToken ct)` — synchronous `IMemoryCache.TryGetValue` wrapped in `ValueTask.FromResult`. Return `default(T?)` if absent.
   - `SetAsync(string key, T value, TimeSpan? ttl, IReadOnlyCollection<string>? tags, CancellationToken ct)` — call `IMemoryCache.Set` with the value; if `ttl` is non-null, set `AbsoluteExpirationRelativeToNow`; if `tags` is non-null and non-empty, update the internal tag-to-key index (each tag maps to a `HashSet<string>` of keys, protected by appropriate concurrency). Return `ValueTask.CompletedTask`.
   - `RemoveAsync(string key, CancellationToken ct)` — call `IMemoryCache.Remove(key)` and remove the key from any tag indexes it appears in. Return `ValueTask.CompletedTask`.
   - `RemoveByTagAsync(string tag, CancellationToken ct)` — look up the tag's key set; for each key, call `IMemoryCache.Remove`; clear the tag entry. Return `ValueTask.CompletedTask`.
2. **Tag-to-key index** — `ConcurrentDictionary<string, ConcurrentDictionary<string, byte>>` (the inner dictionary acts as a thread-safe set; the `byte` value is a placeholder). When a `Set` adds tags, append the key to each tag's inner set. When a `Remove` or `RemoveByTag` invalidates, prune the indexes. Eviction via TTL also needs to prune the index — register an `IMemoryCache` post-eviction callback that drops the key from any tag set it appears in.
3. **`AddInMemoryCacheStore<T>`** — extension method on `IServiceCollection`. Registers `ICacheStore<T>` as a singleton resolving to `InMemoryCacheStore<T>`. Ensures `Microsoft.Extensions.Caching.Memory`'s `AddMemoryCache()` is called if not already (idempotent via `TryAdd*`). Pattern modelled on the existing `AddInMemory*` extensions for SecretStore / Broker / Queue.
4. **Unit tests** in the repo's existing test project (`HoneyDrunk.Kernel.Tests`):
   - `GetAsync` on a missing key returns `null` / `default(T?)`.
   - `SetAsync` then `GetAsync` returns the set value.
   - `SetAsync` with a `ttl` followed by time advancement past the TTL returns absent. Use an injected `TimeProvider` or `Microsoft.Extensions.Caching.Memory`'s `ISystemClock` shim — no `Thread.Sleep` (invariant 51).
   - `RemoveAsync` invalidates a specific key.
   - `SetAsync` with `tags` then `RemoveByTagAsync` invalidates every key associated with the tag.
   - `RemoveByTagAsync` on a non-existent tag is a no-op (no exception).
   - `SetAsync` with an empty `tags` collection behaves the same as `null` (no tag-index entries added).
   - Concurrent Set/Get correctness on a small number of threads — no deadlock, no torn writes (light test, not a load test).
5. **CHANGELOG updates** — append to the existing `[0.8.0]` entries (do NOT create a new version section):
   - Repo-level `CHANGELOG.md` `[0.8.0]` section: add a line for the runtime `InMemoryCacheStore<T>` reference implementation + DI extension.
   - `HoneyDrunk.Kernel/CHANGELOG.md`: create the `[0.8.0]` per-package entry (packet 04 left this empty per invariant 12); describe the new `InMemoryCacheStore<T>` + `AddInMemoryCacheStore<T>` surface.
6. **README** — update `HoneyDrunk.Kernel/README.md` (the runtime package README) to document the new InMemory cache backing in the public-API / DI-registration section.

## Affected Files
- `HoneyDrunk.Kernel/` — new file for `InMemoryCacheStore<T>` per the repo's file-per-type convention; new file (or extension on an existing file) for the `AddInMemoryCacheStore<T>` DI extension.
- `HoneyDrunk.Kernel.Tests/` — new test class with the cases enumerated above.
- `HoneyDrunk.Kernel/CHANGELOG.md` — new `[0.8.0]` per-package entry.
- `HoneyDrunk.Kernel/README.md` — DI / public-API section append.
- Repo-level `CHANGELOG.md` — append to the in-progress `[0.8.0]` entry.

## NuGet Dependencies
- **`HoneyDrunk.Kernel`** — new `PackageReference`:
  - `Microsoft.Extensions.Caching.Memory` (latest .NET 10.0.x — match the version pin pattern visible in the repo's existing `Microsoft.Extensions.*` references, e.g. `10.0.5` at the time of writing for the other extensions packages).
  - `Microsoft.Extensions.DependencyInjection.Abstractions` is already referenced (existing); no addition needed.
  - `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`).
- **`HoneyDrunk.Kernel.Tests`** — no new packages beyond the existing test stack (xUnit v2 + NSubstitute + AwesomeAssertions + coverlet per ADR-0047). If `TimeProvider` is needed for TTL tests and the test project does not yet reference `Microsoft.Bcl.TimeProvider` (or whatever the BCL surface is in .NET 10.0), confirm at edit time whether it is needed.

## Boundary Check
- [x] `InMemoryCacheStore<T>` is the reference implementation of `ICacheStore<T>` per ADR-0058 D4 ("ships in `HoneyDrunk.Kernel`"). The implementation lives in the runtime package; the contract lives in Abstractions.
- [x] `Microsoft.Extensions.Caching.Memory` is added to the `HoneyDrunk.Kernel` runtime package only — NOT to `HoneyDrunk.Kernel.Abstractions` (invariant 1).
- [x] No dependency on `HoneyDrunk.Cache`, `HoneyDrunk.Transport`, or any other HoneyDrunk runtime package — Kernel sits at the root of the DAG (invariant 4).
- [x] No exposure of `InMemoryCacheStore<T>` on any other Node's `Abstractions` package (invariant 82 — caches are per-Node-opaque).

## Acceptance Criteria
- [ ] `InMemoryCacheStore<T>` implements `ICacheStore<T>` from `HoneyDrunk.Kernel.Abstractions` `0.8.0`
- [ ] `GetAsync` returns `null` / `default(T?)` for a missing key and the set value for a present key
- [ ] `SetAsync` honours `ttl` (post-expiry `GetAsync` returns absent); tests use an injected `TimeProvider` or `ISystemClock`, NOT `Thread.Sleep` (invariant 51)
- [ ] `SetAsync` honours `tags`; `RemoveByTagAsync` invalidates every key associated with the tag
- [ ] `SetAsync` with an empty `tags` collection behaves the same as `null` (no index entries)
- [ ] `RemoveAsync` invalidates the specific key and prunes it from any tag indexes
- [ ] `RemoveByTagAsync` on a non-existent tag is a no-op (no exception)
- [ ] Post-eviction (TTL or capacity-driven), keys are pruned from tag indexes via an `IMemoryCache` post-eviction callback
- [ ] `AddInMemoryCacheStore<T>` registers `ICacheStore<T>` as a singleton; idempotent registration of `AddMemoryCache()` if not already present
- [ ] Unit tests cover Get / Set / Remove / RemoveByTag, TTL expiry, empty-tags behaviour, non-existent-tag-no-op, concurrent Set/Get correctness; no `Thread.Sleep` in any test (invariant 51)
- [ ] `Microsoft.Extensions.Caching.Memory` is added to `HoneyDrunk.Kernel` runtime `.csproj` only — NOT to `HoneyDrunk.Kernel.Abstractions.csproj` (invariant 1)
- [ ] Both non-test `.csproj` files in the solution stay at version `0.8.0` (already bumped in packet 04 — do NOT bump again; invariant 27)
- [ ] Repo-level `CHANGELOG.md` `[0.8.0]` entry receives an append describing the runtime backing — no new version section
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` gets a `[0.8.0]` per-package entry describing `InMemoryCacheStore<T>` + the DI extension (this packet, not packet 04, fills it)
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` is NOT amended in this packet (packet 04 owns the abstractions entry; no functional change to that package here)
- [ ] `HoneyDrunk.Kernel/README.md` documents the new InMemory cache backing in the DI / public-API section
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] Packet 04's `HoneyDrunk.Kernel` `0.8.0` release tag has been pushed by a human so the published `HoneyDrunk.Kernel.Abstractions` `0.8.0` package is available on the NuGet feed before this packet's CI build attempts to consume it. (If both packets land in the same release cycle and the human releases `0.8.0` after both merges, this is fine — but the runtime build in this packet must be able to resolve `ICacheStore<T>` against the source-of-truth Abstractions package. The shared-solution case typically resolves via the solution-internal project reference, in which case no separate release is needed before this PR builds; verify at edit time.)

## Referenced ADR Decisions
**ADR-0058 D4 — InMemory reference implementation ships in Kernel.** `HoneyDrunk.Kernel` ships `InMemoryCacheStore<T>` alongside the contract, backed by `IMemoryCache` from `Microsoft.Extensions.Caching.Memory`. The rationale: removes friction for the first consumer; consistent with how Kernel already ships other reference plumbing (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`, `InMemoryIdempotencyStore`, the InMemory Transport provider); no new runtime dependency on `Microsoft.Extensions.Caching.Memory` at the abstraction layer (it is allowed on `HoneyDrunk.Kernel`, not on `HoneyDrunk.Kernel.Abstractions`); test invariant alignment per invariant 15.

**ADR-0058 D2 — `ICacheStore<T>` ships in `HoneyDrunk.Kernel.Abstractions`.** The four methods (`GetAsync`, `SetAsync`, `RemoveAsync`, `RemoveByTagAsync`); value-typed by `T`. Backings serialize and deserialize at the boundary. The InMemory backing does not need serialization — values are stored in-process — but it must respect the contract's typed shape.

**ADR-0058 D3 — Multiple backings are acceptable; in-memory is the default.** The InMemory backing is the default and the assumed baseline for every Node today. Distributed backings (Cache Node, per ADR-0059) are per-Node, per-workload choices activated when a workload pulls on them. This packet ships the default; distributed backings are out of scope here.

**ADR-0058 D6 — Data classification inheritance.** The InMemory backing is in-process memory, encrypted by the host's memory protection (the standard .NET in-process posture), and is acceptable for Restricted values within the bounds of a single trust boundary. The InMemory backing implementation itself does not encrypt values explicitly — the host process boundary is the trust boundary. Document this in the README so consumers understand the InMemory backing's classification posture.

**Invariant 15 — Unit tests and in-process integration tests never depend on external services.** `InMemoryCacheStore<T>` is the InMemory provider for the cache surface; every Node's tests use it directly, no per-Node fixture needed.

**Invariant 51 — Test code contains no `Thread.Sleep`.** TTL tests advance an injected `TimeProvider` or `ISystemClock`.

## Constraints
- **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** `Microsoft.Extensions.Caching.Memory` is a runtime dependency, not an Abstractions one — it goes on `HoneyDrunk.Kernel`, not on `HoneyDrunk.Kernel.Abstractions`.
- **Invariant 4 — No circular dependencies; the dependency graph is a DAG with Kernel at the root.** Do not reference `HoneyDrunk.Cache` or any other HoneyDrunk runtime package.
- **Invariant 13 — All public APIs have XML documentation.** `InMemoryCacheStore<T>` and `AddInMemoryCacheStore<T>` get full XML doc.
- **Invariant 27 — All projects in a solution share one version and move together.** The `0.8.0` bump happened in packet 04; **do NOT bump again** in this packet. Both `.csproj` files stay at `0.8.0`. Append to the existing `[0.8.0]` CHANGELOG entries.
- **Invariant 12 — Per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Kernel` gets its `[0.8.0]` per-package entry here (real functional change: new InMemory backing). `HoneyDrunk.Kernel.Abstractions` does NOT get an entry in this packet (no functional change to that package).
- **Invariant 15 — InMemory provider for tests.** This is the canonical test backing for every Node's cache-using unit tests; ensure the surface is test-friendly (injectable `IMemoryCache`, optional `TimeProvider`).
- **Invariant 51 — No `Thread.Sleep` in test code.** Use `TimeProvider` / `ISystemClock`.
- **Invariant 82 (caches per-Node-opaque) — InMemory backing stays in `HoneyDrunk.Kernel`.** Do not export it from any other Node's `Abstractions` package.
- **No `HybridCache` adoption** (ADR-0058 D8 / Alternatives — explicitly deferred at v1).
- **No distributed backing here.** The Cache Node (ADR-0059) is the home for Redis / Cosmos-TTL / Postgres-TTL backings; this packet ships InMemory only.

## Labels
`feature`, `tier-2`, `core`, `adr-0058`, `wave-4`

## Agent Handoff

**Objective:** Implement the `InMemoryCacheStore<T>` reference implementation of `ICacheStore<T>` in the `HoneyDrunk.Kernel` runtime, register it via DI, and ship unit tests covering the full contract semantics including TTL and tag invalidation.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Give every Node a working in-process cache backing out of the box, with the same shape as every future distributed backing (Cache Node / ADR-0059). The InMemory backing is the canonical test fixture for any consumer's unit tests per invariant 15.
- Feature: ADR-0058 Grid-Wide Caching Strategy rollout, Wave 4.
- ADRs: ADR-0058 D4 (primary), ADR-0058 D2 (the contract this implements), ADR-0008 (packet conventions), ADR-0047 (test stack), invariants 1/4/12/13/15/27/51/82.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:04` — `HoneyDrunk.Kernel.Abstractions` `0.8.0` ships `ICacheStore<T>` before this packet implements it.

**Constraints:**
- `Microsoft.Extensions.Caching.Memory` goes on `HoneyDrunk.Kernel` runtime, NOT on `HoneyDrunk.Kernel.Abstractions` (invariant 1).
- Do NOT bump the solution version — that happened in packet 04. Append to the in-progress `[0.8.0]` CHANGELOG.
- Tag-to-key index must be thread-safe and pruned on TTL/capacity eviction via post-eviction callback.
- Tests use `TimeProvider` / `ISystemClock` — no `Thread.Sleep` (invariant 51).
- Caches are per-Node-opaque (invariant 82); the backing lives in Kernel and is consumed by composition, not by re-export from any other Node's Abstractions.

**Key Files:**
- `HoneyDrunk.Kernel/` — new `InMemoryCacheStore<T>` + DI extension.
- `HoneyDrunk.Kernel.Tests/` — new test class with the cases above.
- `HoneyDrunk.Kernel/CHANGELOG.md` — new `[0.8.0]` per-package entry.
- `HoneyDrunk.Kernel/README.md` — DI / public-API section append.
- Repo-level `CHANGELOG.md` `[0.8.0]` entry — append.
- `HoneyDrunk.Kernel.csproj` — new `Microsoft.Extensions.Caching.Memory` `PackageReference`.

**Contracts:**
- Implements `ICacheStore<T>` (from `HoneyDrunk.Kernel.Abstractions` `0.8.0`). Adds `InMemoryCacheStore<T>` class and `AddInMemoryCacheStore<T>` DI extension to the `HoneyDrunk.Kernel` runtime. No new contracts.
