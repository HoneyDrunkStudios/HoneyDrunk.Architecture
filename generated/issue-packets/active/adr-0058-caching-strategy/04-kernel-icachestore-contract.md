---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0058", "wave-3"]
dependencies: ["packet:01"]
adrs: ["ADR-0058"]
wave: 3
initiative: adr-0058-caching-strategy
node: honeydrunk-kernel
---

# Add ICacheStore<T> to HoneyDrunk.Kernel.Abstractions

## Summary
Add the ADR-0058 D2 `ICacheStore<T>` contract to `HoneyDrunk.Kernel.Abstractions`: a minimal, generic, async cache surface (`GetAsync`, `SetAsync`, `RemoveAsync`, `RemoveByTagAsync`), value-typed by `T`, with optional TTL and optional tag set on `SetAsync`. Pure contract — zero HoneyDrunk runtime dependencies. **Version-bumping packet for the `HoneyDrunk.Kernel` solution** (`0.7.0` → `0.8.0`, additive minor bump). The `InMemoryCacheStore<T>` runtime implementation lands in packet 05.

## Context
ADR-0058 commits a Grid-wide caching contract for the cache-as-leak-vector and per-Node-drift problems documented in its Context. The contract lives in `HoneyDrunk.Kernel.Abstractions` because Kernel is the zero-dependency contract layer every Node already consumes — the same placement precedent as `IGridContext`, `TenantId`, `IIdempotencyStore`, and (recently) `IPulseSignalEnvelope`.

This packet adds the **contract only** — the `ICacheStore<T>` interface. The runtime implementation (`InMemoryCacheStore<T>`) and the DI registration extension live in packet 05 in the `HoneyDrunk.Kernel` runtime package. Splitting contract-from-runtime keeps `HoneyDrunk.Kernel.Abstractions` honest under invariant 1 (Abstractions have zero runtime dependencies on other HoneyDrunk packages, and only `Microsoft.Extensions.*` *abstractions* are permitted — `Microsoft.Extensions.Caching.Memory` is **not** an abstraction package and must not land here).

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (.NET 10.0), two packages: `HoneyDrunk.Kernel.Abstractions` (zero-dependency contracts) and `HoneyDrunk.Kernel` (runtime). This packet is the **first packet on the `HoneyDrunk.Kernel` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.7.0` → `0.8.0`; new feature, additive contract, no break). Packet 05 (also Kernel) appends to the in-progress `[0.8.0]` CHANGELOG and ships the runtime backing.

## Scope
- `HoneyDrunk.Kernel.Abstractions` — new contract:
  - `ICacheStore<T>` — async generic cache interface with four methods (`GetAsync`, `SetAsync`, `RemoveAsync`, `RemoveByTagAsync`).
- Both non-test `.csproj` files in the solution version-bumped to `0.8.0` (invariant 27).
- `HoneyDrunk.Kernel.Abstractions` package `CHANGELOG.md` and `README.md` updated to reflect the new contract.
- `HoneyDrunk.Kernel` package CHANGELOG receives an alignment-bump version entry but no per-package noise for the runtime package (no functional change in this packet — that lands in packet 05).
- Repo-level `CHANGELOG.md` gets a new `[0.8.0]` entry dated to the merge.

## Proposed Implementation
1. **`ICacheStore<T>`** — interface in `HoneyDrunk.Kernel.Abstractions`, generic in `T`. Exact shape from ADR-0058 D2:

   ```csharp
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

   - `GetAsync` returns the cached value or `null`. No "load if missing" sugar at v1 — consumers compose that pattern themselves. (A `GetOrSetAsync` helper is explicitly deferred per ADR-0058 D8/Alternatives; do NOT add it here.)
   - `SetAsync` accepts optional `ttl` and optional `tags`. Tags are the prefix-style/family-style invalidation primitive. The contract does not interpret tags — backings do.
   - `RemoveAsync` invalidates by exact key.
   - `RemoveByTagAsync` invalidates every value associated with a tag.
2. Full XML documentation on every member (invariant 13). The XML doc must include:
   - On the interface: the per-Node-opaque rule (invariant 82 / D1), the tenant-key isolation discipline (invariant 83 / D5 — call site is responsible), and the classification-inheritance reminder (invariant 84 / D6).
   - On each method: standard parameter/return docs; on `SetAsync` specifically, note that `tags` may be `null` for tag-free caches and that an empty collection is treated the same as `null`.
3. **No additional types in this packet.** No `CacheKey` record, no `CachedValue<T>` wrapper, no `CacheOptions` configuration record. The contract is the four methods plus the `T` type parameter — anything richer waits for a real consumer to motivate it.
4. **Version-bump both `.csproj` files to `0.8.0`** in one commit (invariant 27). Add a repo-level `[0.8.0]` CHANGELOG entry. Add a per-package CHANGELOG entry to `HoneyDrunk.Kernel.Abstractions` (real change: new contract surface). The `HoneyDrunk.Kernel` runtime package gets no per-package CHANGELOG entry in **this** packet (no functional change yet — packet 05 adds the runtime code and its entry); it is still version-bumped to `0.8.0` to keep the solution aligned (invariant 27), with no noise entry (invariant 12/27).
5. Update `HoneyDrunk.Kernel.Abstractions/README.md` — the public API surface gained `ICacheStore<T>`; document it in the API-surface section.

## Affected Files
- `HoneyDrunk.Kernel.Abstractions/` — new file for `ICacheStore<T>` per the repo's file-per-type convention.
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — version bump `0.7.0` → `0.8.0`.
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` — version bump `0.7.0` → `0.8.0` (alignment).
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `HoneyDrunk.Kernel.Abstractions/README.md`.
- Repo-level `CHANGELOG.md`.
- The repo's existing unit-test project (e.g. `HoneyDrunk.Kernel.Tests`) — minimal shape test for the contract: an inline test fake (`Substitute.For<ICacheStore<int>>()` per the NSubstitute test stack) that verifies the methods are callable with the expected parameter shapes. Full behavioral tests live in packet 05 against `InMemoryCacheStore<T>`.

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` *abstractions* packages. The `ICacheStore<T>` contract uses only `System.Threading.Tasks` (`ValueTask`, `CancellationToken`) and `System.Collections.Generic` (`IReadOnlyCollection<string>`) — both BCL, no package needed. `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`).
- **`HoneyDrunk.Kernel`** — no new `PackageReference` in this packet (runtime code lands in packet 05).
- The unit-test project follows the repo's existing test stack (per ADR-0047: xUnit v2 + NSubstitute + AwesomeAssertions + coverlet); no new packages added by this packet beyond what the test project already references.

## Boundary Check
- [x] `ICacheStore<T>` is a Kernel contract per ADR-0058 D2 ("ships in `HoneyDrunk.Kernel.Abstractions`"). Routing rule "context, GridContext, NodeContext, ... CorrelationId → HoneyDrunk.Kernel" and the ADR's explicit placement both map here.
- [x] No dependency on `HoneyDrunk.Transport`, `HoneyDrunk.Cache`, or any other HoneyDrunk runtime package (invariant 4 — DAG with Kernel at the root).
- [x] Contracts only; the runtime InMemory backing (packet 05) is a separate packet.
- [x] `Microsoft.Extensions.Caching.Memory` is NOT introduced on `HoneyDrunk.Kernel.Abstractions` (invariant 1 — only `Microsoft.Extensions.*` *abstractions* are permitted; `Memory` is a runtime package).
- [x] No exposure of `ICacheStore<T>` from any other Node's `Abstractions` package (invariant 82 — caches are per-Node-opaque; the contract lives in Kernel.Abstractions where every Node already consumes it).

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `ICacheStore<T>` with exactly the four members (`GetAsync`, `SetAsync`, `RemoveAsync`, `RemoveByTagAsync`) at the ADR-0058 D2 signatures
- [ ] `SetAsync` accepts optional `TimeSpan? ttl` and optional `IReadOnlyCollection<string>? tags` parameters
- [ ] `GetAsync` returns `ValueTask<T?>` — nullable in the type system regardless of `T`'s nullability annotations
- [ ] No `GetOrSetAsync` method on the contract (deferred per ADR-0058 D8 / Alternatives)
- [ ] All public members have XML documentation including the three caching invariants the call site must respect (tenant-keying, classification inheritance, no cross-Node reach-in)
- [ ] `HoneyDrunk.Kernel.Abstractions` has zero runtime `PackageReference` on any HoneyDrunk package (invariant 1); only `Microsoft.Extensions.*` *abstractions* and the BCL are referenced
- [ ] Both non-test `.csproj` files in the solution are at version `0.8.0` in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.8.0]` entry dated to the merge
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` has a `[0.8.0]` entry describing the `ICacheStore<T>` contract surface
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` gets NO entry in this packet (no functional change here; alignment bump only per invariants 12/27)
- [ ] `HoneyDrunk.Kernel.Abstractions/README.md` documents `ICacheStore<T>` in the public-API section
- [ ] The `pr-core.yml` tier-1 gate and the Kernel contract-shape canary pass — the new contract is additive, paired with the `0.8.0` bump
- [ ] No exposure of `ICacheStore<T>` from any other Node's package — the contract lives exclusively in `HoneyDrunk.Kernel.Abstractions`

## Human Prerequisites
- [ ] After this packet merges, a human pushes the `HoneyDrunk.Kernel` `0.8.0` release tag so the NuGet package is on the feed before any downstream consumer (initially none in this initiative — but Notify Cloud / Communications follow-ups will pull on it). Agents merge code but never tag or publish — this is the standing Grid release-cadence rule.

## Referenced ADR Decisions
**ADR-0058 D2 — `ICacheStore<T>` ships in `HoneyDrunk.Kernel.Abstractions`.** Four methods: `GetAsync(string key, CancellationToken ct = default)`; `SetAsync(string key, T value, TimeSpan? ttl = null, IReadOnlyCollection<string>? tags = null, CancellationToken ct = default)`; `RemoveAsync(string key, CancellationToken ct = default)`; `RemoveByTagAsync(string tag, CancellationToken ct = default)`. The contract is value-typed by `T`; backings serialize and deserialize at the boundary. This is a deliberate departure from `IDistributedCache`'s `byte[]` posture and an alignment with `HybridCache`'s typed posture.

**ADR-0058 D8 / Alternatives — `GetOrSetAsync` deferred.** The minimal v1 surface (`Get`/`Set`/`Remove`/`RemoveByTag`) is intentionally tight. Consumers compose the load-if-missing pattern themselves at call sites where the source semantics matter. Shipping `GetOrSetAsync` at v1 risks baking in a stampede-protection policy that is not the right shape for every workload.

**ADR-0058 D1 — Caches are per-Node, internal, and opaque across Node boundaries.** A cache is an implementation detail of the Node that owns the cached data. No Node reaches into another Node's cache through `Abstractions`, through composition, or through any other surface. There is no `ICacheStore<T>` exposed on any Node's `Abstractions` package; the contract lives in `HoneyDrunk.Kernel.Abstractions`, where every Node already takes a dependency.

**ADR-0058 D4 — InMemory reference implementation ships in Kernel.** `HoneyDrunk.Kernel` ships `InMemoryCacheStore<T>` alongside the contract, backed by `IMemoryCache` from `Microsoft.Extensions.Caching.Memory`. **No new runtime dependency on `Microsoft.Extensions.Caching.Memory` at the abstraction layer.** `Microsoft.Extensions.Caching.Memory` is allowed on `HoneyDrunk.Kernel` (runtime), not on `HoneyDrunk.Kernel.Abstractions`. The contract sits in Abstractions; the InMemory implementation lands in packet 05.

**ADR-0058 Operational Consequences.** "Kernel.Abstractions versioning ticks minor. Per ADR-0035 cascade procedure, the additive `ICacheStore<T>` contract requires every downstream Node to either bump its Kernel.Abstractions reference at the cascade-window or stay pinned at the prior minor. No compile-time break."

## Constraints
- **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.**
  > Only `Microsoft.Extensions.*` abstractions are permitted.

  `Microsoft.Extensions.Caching.Memory` is **not** an abstractions package — it carries a runtime `MemoryCache` implementation. Do NOT add it to `HoneyDrunk.Kernel.Abstractions`. The InMemory backing lands in packet 05 in the `HoneyDrunk.Kernel` runtime package.
- **Invariant 4 — No circular dependencies. The dependency graph is a DAG. Kernel is always at the root.**
  Do not reference `HoneyDrunk.Cache`, `HoneyDrunk.Transport`, or any other HoneyDrunk runtime package from `HoneyDrunk.Kernel.Abstractions`.
- **Invariant 13 — All public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards` analyzers. The XML doc must inline the three caching invariants (82 per-Node-opaque, 83 tenant-keying, 84 classification inheritance) so call-site authors see the rules without leaving the IDE.
- **Invariant 27 — All projects in a solution share one version and move together.** Both `.csproj` files go to `0.8.0` in one commit. Partial bumps are forbidden. This is the bumping packet; packet 05 appends to the CHANGELOG only.
- **Invariant 12 — Per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Kernel.Abstractions` gets an entry; `HoneyDrunk.Kernel` (alignment bump only here) gets none.
- **Invariant 82 (new this initiative, packet 01) — Caches are per-Node, internal, and never crossed through `Abstractions`.**
  > A Node's cache is an implementation detail behind its public contracts; no consumer reaches into another Node's cache. Cache hit/miss/eviction telemetry is operational signal (Pulse channel), not a public surface. There is no `ICacheStore<T>` exposed on any Node's `Abstractions` package — the contract lives in `HoneyDrunk.Kernel.Abstractions` and is consumed from there.

  The contract goes in Kernel.Abstractions and nowhere else.
- **No `GetOrSetAsync` at v1** (per ADR-0058 D8 / Alternatives — deferred deliberately).
- **No `HybridCache` adoption.** Do not reference `Microsoft.Extensions.Caching.Hybrid` (ADR-0058 D8 / Alternatives — explicitly rejected at v1).
- **Naming: interface keeps the `I`.** `ICacheStore<T>` — the Grid naming rule applies (interfaces retain `I`; records drop it).

## Labels
`feature`, `tier-2`, `core`, `adr-0058`, `wave-3`

## Agent Handoff

**Objective:** Add the ADR-0058 `ICacheStore<T>` contract to `HoneyDrunk.Kernel.Abstractions` and bump the `HoneyDrunk.Kernel` solution to `0.8.0`.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the Grid-wide caching contract that the InMemory backing (packet 05) and every future consumer (Communications, Notify Cloud, etc. — in their own follow-up initiatives) compile against.
- Feature: ADR-0058 Grid-Wide Caching Strategy rollout, Wave 3 (the contract foundation).
- ADRs: ADR-0058 D1/D2/D4/D8 (primary), ADR-0035 (additive minor-bump policy), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — invariants 82/83/84 live in `constitution/invariants.md` before the contract references them in XML doc as canonical rules.

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency (invariant 1). No `Microsoft.Extensions.Caching.Memory` here — that lands in packet 05 on the runtime package.
- Four methods only — no `GetOrSetAsync`, no `HybridCache` adoption.
- Bump both non-test `.csproj` files to `0.8.0` in one commit (invariant 27). This is the bumping packet for `HoneyDrunk.Kernel` in this initiative.
- XML doc inlines the three caching invariants (per-Node-opaque, tenant-keying, classification inheritance) so call-site authors see them.

**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/` — new file for `ICacheStore<T>`.
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.
- Both `.csproj` files for the version bump.
- The existing unit-test project — a minimal shape test using NSubstitute.

**Contracts:**
- `ICacheStore<T>` (new interface) — Grid-wide per-Node cache. `GetAsync` / `SetAsync` / `RemoveAsync` / `RemoveByTagAsync`. No other types in this packet.
