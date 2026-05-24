# Dispatch Plan — ADR-0058: Grid-Wide Caching Strategy

**Initiative:** `adr-0058-caching-strategy`
**ADR:** ADR-0058 (Proposed — see "Status flip handling" below)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0058 commits the Grid's response to ungoverned per-Node cache drift: a Grid-wide `ICacheStore<T>` contract in `HoneyDrunk.Kernel.Abstractions`, an `InMemoryCacheStore<T>` reference implementation in `HoneyDrunk.Kernel`, three new invariants (caches are per-Node opaque; tenant-key isolation; data-classification inheritance), the three named invalidation lanes (in-process, Service Bus topic, Event Grid system topic), and a deliberate grandfather clause for the four existing caches (Vault, Auth, AI cost-rate, FeatureFlags). The ADR is paired with ADR-0059, which stands up `HoneyDrunk.Cache` as the home for distributed backings; **this initiative does not include the Cache Node scaffold** — that work lives in ADR-0059's own initiative folder.

This initiative delivers: catalog registration of the new contract surface under `honeydrunk-kernel`; the three new invariants (numbers **82, 83, 84**) and the initiative registration; a "Cache Invalidation" row update to ADR-0028's use-case → backing matrix (D7 follow-up); the coupled `scope.md` / `review.md` checklist additions (per invariant 33); the `ICacheStore<T>` contract in `HoneyDrunk.Kernel.Abstractions`; and the `InMemoryCacheStore<T>` reference implementation in the `HoneyDrunk.Kernel` runtime.

**6 packets across 4 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`). All 6 `Actor=Agent`, 0 `Actor=Human`. No `human-only` label, no Human Prerequisites of substance (the Kernel cascade packets are pure code work; tests run InMemory).

## Trigger

ADR-0058 is Proposed with no scope. Forcing functions from the ADR's Context: Vault, Auth, AI, and FeatureFlags each carry ad-hoc caches with no shared contract; Notify Cloud's multi-replica horizon (PDR-0002) needs a backing-swappable seam before it scales past a single Container App replica; Communications's preference / cadence cache (per ADR-0019) lands on a Grid-wide contract or invents another N-th one; AI's cost-rate cache (ADR-0016 D5) is the third bespoke shape. The ADR commits the contract, the InMemory reference, and the three invariants; this initiative ships them.

## Scope Detection

**Multi-repo, two Nodes.** The contract lands in `HoneyDrunk.Kernel.Abstractions` (the zero-dependency contract layer per the existing precedent set by `IGridContext`, `TenantId`, and `IIdempotencyStore`); the reference InMemory implementation lands in `HoneyDrunk.Kernel`. `HoneyDrunk.Architecture` carries the governance (invariants), the catalog registration, the ADR-0028 D2 matrix update, the Vault overview grandfather note, the Kernel boundaries update, and the coupled `scope.md` / `review.md` checklist additions.

**Contract is additive — no forced downstream cascade.** Per ADR-0058 Operational Consequences and ADR-0035, the new `ICacheStore<T>` surface is **additive** on `HoneyDrunk.Kernel.Abstractions` (additive minor bump). Downstream Nodes are not *forced* to update — they adopt `ICacheStore<T>` when their own caches are introduced or migrated. ADR-0058 D9 grandfathers the four existing caches (Vault, Auth, AI cost-rate, FeatureFlags) — no retrofit campaign. The first real adopters (Communications preference cache, Notify Cloud API-key cache) come in their own initiatives, not here.

**Cache Node scaffold is out of scope** — that work belongs to the paired ADR-0059 initiative (`HoneyDrunk.Cache` standup). `InMemoryCacheStore<T>` ships in `HoneyDrunk.Kernel` per ADR-0058 D4; the distributed backings are the Cache Node's concern, not this initiative's.

## Pairing with ADR-0059 — explicit cross-initiative coupling

ADR-0058 and ADR-0059 are **paired ADRs**. From ADR-0058 D1/D3/D4 and ADR-0059's "If Accepted" checklist:

- ADR-0058 commits the `ICacheStore<T>` contract and the InMemory reference implementation. Both live in `HoneyDrunk.Kernel`.
- ADR-0059 stands up `HoneyDrunk.Cache` as the home for **distributed** backing implementations of that contract. No backings ship at standup; the Node is the empty room with the right lighting.
- Both ADRs stay Proposed together; neither lands alone.

The scope-agent acceptance rule from ADR-0058's "Catalog and Constitution Obligations":

> The scope agent flips Status → Accepted **after the paired ADR-0059 is also accepted** and the Kernel cascade packet for the new contract has landed.

This initiative is the **Kernel cascade packet set** referenced above. ADR-0059's initiative is a separate folder (`adr-0059-cache-node-standup`, when filed) and not part of this dispatch plan.

**No cross-initiative `dependencies:` edges from this initiative.** All packets here either depend on each other (`packet:NN`) or stand alone. The ADR-0059 initiative — if it lands first — does not block any packet here, because the InMemory reference implementation lives in Kernel and does not need the Cache Node to exist. Conversely, ADR-0059's scaffold packet may reference the `HoneyDrunk.Kernel.Abstractions` version this initiative bumps to, but expressing that is ADR-0059's job, not this one's.

## Status flip handling — separate post-merge housekeeping

**This initiative does NOT include an acceptance packet.** Per the user's standing ADR acceptance workflow and the explicit text of ADR-0058's "Catalog and Constitution Obligations," the scope agent flips Status → Accepted as a separate housekeeping step after **two** conditions are met:

1. ADR-0059 is Accepted (the paired Cache Node standup ADR).
2. The Kernel cascade packets in this initiative (packets 04 and 05) have merged and the Kernel `0.8.0` (or whatever the bumped version turns out to be) release has been published.

Until both conditions hold, ADR-0058 stays Proposed. **No packet in this folder edits the ADR status.** The status flip happens via a small Architecture-only PR run by the scope agent post-merge, outside this initiative.

The invariants and catalog registration **do not** wait for the status flip — they land in Wave 1 here so the Kernel code packets in Wave 3 can reference them as live rules.

## Wave Diagram

### Wave 1 (governance + catalog — no dependencies among themselves; can travel together)
- [ ] **00** — Architecture: register the `ICacheStore<T>` + `InMemoryCacheStore<T>` contract surface in `catalogs/contracts.json`, update `relationships.json` `exposes.contracts`, update `repos/HoneyDrunk.Kernel/boundaries.md` to list the new contracts, add the Vault grandfather note to `repos/HoneyDrunk.Vault/overview.md`, register the initiative in `initiatives/active-initiatives.md`. `Actor=Agent`.
- [ ] **01** — Architecture: add the three new ADR-0058 invariants (numbers **82, 83, 84**) to `constitution/invariants.md`. `Actor=Agent`. Blocked by: 00 (initiative registered first so the invariants reference a known initiative slug).

### Wave 2 (architecture documentation follow-ups — parallel with Wave 1, but sequenced after 00 for tidy filing)
- [ ] **02** — Architecture: add the "Cache Invalidation" row to ADR-0028's D2 use-case → backing matrix and mirror the row into `repos/HoneyDrunk.Transport/integration-points.md`. `Actor=Agent`. Blocked by: 00.
- [ ] **03** — Architecture: update `.claude/agents/scope.md` and `.claude/agents/review.md` with the ADR-0058 D5/D6/D7 caching checklist obligations (per invariant 33's coupling rule). `Actor=Agent`. Blocked by: 00, 01.

### Wave 3 (Kernel contract foundation)
- [ ] **04** — Kernel: add `ICacheStore<T>` and the supporting types to `HoneyDrunk.Kernel.Abstractions`; **version-bumping packet for the `HoneyDrunk.Kernel` solution** (`0.7.0` → `0.8.0`, additive minor bump per ADR-0035). `Actor=Agent`. Blocked by: 01.

### Wave 4 (Kernel runtime reference implementation)
- [ ] **05** — Kernel: add `InMemoryCacheStore<T>` to the `HoneyDrunk.Kernel` runtime package (backed by `Microsoft.Extensions.Caching.Memory`) and the DI registration extension; appends to the in-progress `[0.8.0]` CHANGELOG (no new version bump). `Actor=Agent`. Blocked by: 04.

Packets within a wave run in parallel. Wave 1's 00 and 01 are technically sequenceable (01 references the initiative reg from 00), and Wave 2's 02 and 03 only need 00. Wave 3 and Wave 4 share the `HoneyDrunk.Kernel` solution and must sequence: 04 is the bumping packet that ships the contract; 05 appends to the in-progress `[0.8.0]` CHANGELOG and ships the InMemory backing in the runtime package.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Catalog registration + Kernel/Vault boundary notes](./00-architecture-caching-catalog-and-boundaries.md) | Architecture | Agent | 1 | — |
| 01 | [Three caching invariants (82, 83, 84)](./01-architecture-caching-invariants.md) | Architecture | Agent | 1 | 00 |
| 02 | [ADR-0028 D2 matrix — Cache Invalidation row](./02-architecture-adr-0028-cache-invalidation-row.md) | Architecture | Agent | 2 | 00 |
| 03 | [scope.md + review.md caching checklist](./03-architecture-scope-review-caching-checklist.md) | Architecture | Agent | 2 | 00, 01 |
| 04 | [`ICacheStore<T>` in Kernel.Abstractions (0.8.0 bump)](./04-kernel-icachestore-contract.md) | Kernel | Agent | 3 | 01 |
| 05 | [`InMemoryCacheStore<T>` in Kernel runtime](./05-kernel-inmemory-cachestore-runtime.md) | Kernel | Agent | 4 | 04 |

## Invariant Numbering — pre-assigned at 82, 83, 84

The three new ADR-0058 invariants take pre-assigned numbers **82, 83, 84**. The verified current maximum in `constitution/invariants.md` is **53**; numbers above that are part of a pre-reserved cross-ADR allocation:

- 54-56: ADR-0034
- 57-59: ADR-0035
- 60-61: ADR-0036
- 62-64: ADR-0037
- 65-66: ADR-0038
- 67-68: ADR-0039
- 69-71: ADR-0040
- 72-74: ADR-0041
- 75-77: ADR-0042
- 78-79: ADR-0043
- 80: ADR-0045
- 81: ADR-0046

ADR-0058 lands **outside** the prior 12-ADR batch (it was authored 2026-05-23, eight days after the batch closed). Numbers 82-84 are the next free triple above the batch's reservations and are assigned here. **If any invariant in the 81-and-below batch shifts upward between this dispatch plan and packet 01's merge, the executor adjusts 82/83/84 accordingly — never reuse a number.** Packet 01 carries this rule.

The three invariants come from ADR-0058 Consequences/Invariants:

- **82** — Caches are per-Node, internal, and never crossed through `Abstractions`. (ADR-0058 D1; "Dependency Invariants" section)
- **83** — Any cache holding tenant-scoped data keys by `TenantId` using the `tenant-{tenantId}-{logical-key}` convention. (ADR-0058 D5; "Multi-Tenant Boundary Invariants" section)
- **84** — Cached values inherit the classification of their source per ADR-0049. (ADR-0058 D6; new "Data Classification Invariants" section, or appended after invariant 49 in an appropriate topic group)

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 04 is the first packet on the solution in this initiative; it bumps every non-test `.csproj` from the current version (`0.7.0` per the Grid v0.4 tracker — confirm at execution time) to the next **minor** version `0.8.0` (new feature: the `ICacheStore<T>` contract surface; additive, no break). Packet 05 appends to the in-progress `[0.8.0]` CHANGELOG only (invariant 27). Per-package CHANGELOGs: `HoneyDrunk.Kernel.Abstractions` gets an entry from packet 04 (new contract); `HoneyDrunk.Kernel` gets an entry from packet 05 (runtime `InMemoryCacheStore<T>` + DI extension).
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance edits only (packets 00, 01, 02, 03).

## Cross-Cutting Concerns

### `HybridCache` and the deferral story

ADR-0058 D8 deliberately defers `HybridCache` adoption. `Microsoft.Extensions.Caching.Hybrid` is the closest .NET ecosystem analog to `ICacheStore<T>`, but the ADR rejects committing to it directly because (1) it is still settling at the time of the ADR and (2) its always-layered local+remote stance does not fit ADR-0058 D1's per-Node-opaque shape. **Do not import `Microsoft.Extensions.Caching.Hybrid` in any packet in this initiative.** If a future ADR makes `ICacheStore<T>` a thin facade over `HybridCache`, that ADR re-opens the question; this initiative does not.

### `IMemoryCache` is allowed in Kernel runtime, never in Kernel.Abstractions

ADR-0058 D4 is explicit: `Microsoft.Extensions.Caching.Memory` is permitted on `HoneyDrunk.Kernel` (runtime) and is the implementation backing for `InMemoryCacheStore<T>`. It is **not permitted** on `HoneyDrunk.Kernel.Abstractions` — that package keeps its zero-HoneyDrunk-runtime stance per invariant 1, and only `Microsoft.Extensions.*` *Abstractions* are allowed there. Packet 04 (contract) adds no new `PackageReference`; packet 05 (runtime) adds `Microsoft.Extensions.Caching.Memory` to the Kernel runtime package.

### Tag-based invalidation — backing-level concern, contract-level commitment

The `ICacheStore<T>` contract per ADR-0058 D2 commits `SetAsync(... IReadOnlyCollection<string>? tags ...)` and `RemoveByTagAsync(string tag, ...)`. The InMemory backing implements tags by maintaining a private tag-to-key index — straightforward, no external state. Distributed backings (Redis, Cosmos) may have native tag support or may carry the index themselves; that is each backing's concern. **Packet 04 commits the contract shape; packet 05 implements tags in the InMemory backing.** The Cache Node's first distributed backing will implement them in its own packet (out of scope here).

### Three named invalidation lanes — committed in ADR-0058 D7, implemented per-cache

ADR-0058 D7 names the three lanes (in-process direct invocation, Service Bus topic via Transport, Event Grid system topic). No code lands here for the lanes themselves — they are operational discipline applied per-cache by the consuming Node. Packet 02 records the discipline in ADR-0028's D2 matrix as a "Cache Invalidation" row so it is canonically documented before the first real cache adopts it.

### Existing caches are grandfathered — no retrofit packets here

ADR-0058 D9 commits the grandfather clause: Vault's in-memory + Event Grid invalidation flow, Auth's JWT validation cache, AI's cost-rate-table cache, and FeatureFlags's request-scoped cache **stay as they are**. New caches use `ICacheStore<T>`; existing caches **may** migrate during natural evolution but are not forced. **No retrofit packet for any of those four caches appears in this initiative.** Packet 00 records the grandfather posture in `repos/HoneyDrunk.Vault/overview.md` (the most prominent of the four, with the most operationally interesting cache); the other three are noted in their respective `repos/{node}/overview.md` files only if those files already discuss their caches — Auth's JWT cache and AI's cost-rate cache may or may not warrant a sentence, decided at packet 00's execution time. **FeatureFlags is not a stood-up Node**; ADR-0058's reference to it is forward-looking and no catalog edit is needed.

### Site sync

No site-sync flag. ADR-0058 is internal Core-sector infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packet 00 (catalog/boundaries):** revert the PR. The new contract entries leave `contracts.json` / `relationships.json`; the Kernel `boundaries.md` and Vault `overview.md` notes revert. No runtime impact.
- **Packet 01 (invariants):** revert the PR. Invariants 82-84 leave `constitution/invariants.md`. The invariants are governance, not enforced at runtime; reverting them does not break the contract that packet 04 ships, but the contract becomes ungoverned until re-applied — note this in the revert.
- **Packet 02 (ADR-0028 D2 matrix row):** revert the PR. The "Cache Invalidation" row leaves the matrix; the Transport `integration-points.md` mirror reverts. Docs only — no runtime impact.
- **Packet 03 (scope.md / review.md checklists):** revert the PR. The new checklist items leave both agents. Review-agent and scope-agent context-loading divergence (invariant 33) is restored — note this in the revert; the next packet that touches either agent should re-apply.
- **Packet 04 (Kernel.Abstractions contract):** revert the PR; the `HoneyDrunk.Kernel` solution rolls back `0.8.0` → `0.7.0`. The contracts are additive — no consuming Node depends on them at runtime until it composes them, so the revert is contained to `HoneyDrunk.Kernel`.
- **Packet 05 (Kernel runtime InMemory backing):** revert the PR; `InMemoryCacheStore<T>` leaves the `HoneyDrunk.Kernel` runtime. Additive — the revert is contained to `HoneyDrunk.Kernel`. The contract from packet 04 stays; consumers can ship their own InMemory backing locally until re-applied. No external regression.

The full initiative is reversible at any point with no cross-Node blast radius. Every packet's worst-case rollback is a single PR revert in either `HoneyDrunk.Architecture` or `HoneyDrunk.Kernel`.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

The post-merge ADR status flip (Proposed → Accepted, gated on ADR-0059 acceptance + the Kernel `0.8.0` release) is a separate scope-agent housekeeping step, not a packet in this folder.
