# Dispatch Plan — ADR-0076 Cache Backing: Azure Cache for Redis

**Initiative:** `adr-0076-cache-backing-redis`
**Sector:** Core / cross-cutting
**Governing ADR:** [ADR-0076 — Cache Backing: Azure Cache for Redis with Cost-Aware Sizing](../../../../adrs/ADR-0076-cache-backing-azure-cache-for-redis.md) (Proposed 2026-05-23; flips to Accepted only after every packet in this initiative is closed AND the two upstream paired ADRs — ADR-0058 caching strategy and ADR-0059 Cache Node standup — are themselves Accepted. Status-flip is post-merge housekeeping, not a packet action.)
**Companion ADRs:**
- [ADR-0058 — Grid-Wide Caching Strategy](../../../../adrs/ADR-0058-grid-wide-caching-strategy.md) (commits the `ICacheStore<T>` contract in `HoneyDrunk.Kernel.Abstractions` and `InMemoryCacheStore<T>` in `HoneyDrunk.Kernel`). Merged into Architecture via PR #301.
- [ADR-0059 — Stand Up the HoneyDrunk.Cache Node](../../../../adrs/ADR-0059-stand-up-honeydrunk-cache-node.md) (stands up the Cache Node repo and the empty placeholder scaffold). Merged into Architecture via PR #323.
**Trigger:** ADR-0076 in the Proposed queue. ADR-0058 D8 explicitly deferred the first-distributed-backing decision; ADR-0059 stood up the Node home for that decision; ADR-0076 fills the deferred decision. The first consumer (Notify Cloud's multi-replica horizon per ADR-0027) is the imminent forcing function — without a backing decision, the first consumer's pick becomes the de-facto Grid default by precedent.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Cache`)
**Site sync required:** No (backing-implementation work; no Studios website content depends on a Redis adapter package shipping. The catalogs row updates are internal.)
**Rollback plan:**
- **Pre-tag rollback** (before `HoneyDrunk.Cache 0.1.0` is pushed): `git revert` per PR. Architecture-side packets revert cleanly (catalog rows + walkthrough doc). Cache packets 03–05 revert the entire `HoneyDrunk.Cache.Redis` package; the placeholder Adapters project from the standup is unaffected. Packet 02 (human-only Azure provisioning) is undone by deleting the dev Azure Cache for Redis instance in the portal.
- **Post-tag rollback** (after `HoneyDrunk.Cache 0.1.0` is pushed to NuGet but before any consumer composes it): packages are immutable; prefer fix-forward as `0.1.1`. The cost-bearing Azure resource (the dev Redis instance) remains until manually deleted regardless of NuGet state.
- **No consumers yet.** Notify Cloud multi-replica and Communications shared cache are both downstream of this initiative; neither has composed `HoneyDrunk.Cache.Redis` at the time these packets land. Rollback at this stage costs only the operator's afternoon of provisioning work.
- **`file-work-items.yml` lifecycle gotcha:** after this initiative's packets have moved through The Hive, hive-sync may move source packet files from `active/` to `completed/` per invariant 37. A `git revert` only undoes code changes, not packet-file moves. If a revert is needed after lifecycle moves, restore the packet files manually as part of the revert PR.

## Sequencing Against Upstream Gates

ADR-0076 sits downstream of two paired upstream ADRs whose acceptance initiatives committed code this ADR depends on. Concretely:

- **ADR-0058 acceptance committed `ICacheStore<T>` to `HoneyDrunk.Kernel.Abstractions`** (PR #301 merged). The Redis backing implements this contract. Without the contract in place, packet 03 has nothing to implement against.
- **ADR-0059 acceptance committed the `HoneyDrunk.Cache` repo and the placeholder `HoneyDrunk.Cache.Adapters` project** (PR #323 merged). The Redis backing ships as the first real package in this repo. Without the repo and scaffold in place, packet 03 has no Node home to land in.

Both upstream merges are confirmed at scoping time. This initiative inherits a green-light state.

**The `dependencies:` frontmatter in this initiative refers only to packets within this initiative.** Cross-initiative dependencies are not supported by `file-work-items.yml` — the Human Prerequisites section on each packet describes the gating upstream state (issue numbers, repo state, package versions) instead. The filing pipeline relies on the packets being filed in dependency order; the human-prerequisite text catches anything that would otherwise be a missing edge.

## Summary

ADR-0076 commits Azure Cache for Redis as the canonical first distributed-cache backing for `HoneyDrunk.Cache`, with per-environment cost-aware sizing (Basic C0 for dev, Standard C1 for staging/prod baseline), Redis-protocol-only discipline (no Azure-Redis modules), `allkeys-lru` as the default eviction policy, provider abstraction held (alternate backings permitted per ADR-0058 D5), self-hosted Redis on Container Apps permitted as a cost-pressured per-Node alternative (D7), and explicit handling for Restricted-tier values that bypass Standard-tier Redis's at-rest-encryption gap via application-layer encryption (D6).

Six packets land the work:

1. **00 — Architecture: Accept ADR-0076** — flip Status from Proposed to Accepted once the initiative's PRs have merged. The Status-flip itself is post-merge housekeeping in this packet's body, mirroring the pattern from prior backing-decision ADRs.
2. **01 — Architecture: Catalogs + tech-stack updates + provisioning walkthrough** — update `catalogs/contracts.json` (record the `ICacheStore<T>` Redis backing as a planned module), `catalogs/grid-health.json` (add dev/staging/prod Azure Cache for Redis instance rows), `catalogs/modules.json` (add `cache-redis` row for the new `HoneyDrunk.Cache.Redis` package, Seed signal); update `infrastructure/reference/tech-stack.md` Redis row from "Future" to "Stood up; backing implementation in progress"; author `infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md` covering Basic C0 (dev) / Standard C1 (staging/prod) creation, daily ingest cap, connection-string-into-Vault flow, eviction-policy verification, encryption-in-transit confirmation.
3. **02 — Architecture: Provision `dev` Azure Cache for Redis Basic C0 (human-only)** — execute the walkthrough from packet 01 for `dev`. Create the Basic C0 instance (`redis-hd-dev`); set the eviction policy to `allkeys-lru`; verify TLS-only access; defer connection-string Vault seeding until the first consumer's Vault is the target (Notify Cloud's `kv-hd-notify-cloud-dev` or Communications's `kv-hd-comms-dev` — whichever lands first).
4. **03 — Cache: Implement `HoneyDrunk.Cache.Redis` (`RedisCacheStore<T>` + DI registration)** — first/version-bumping packet on the `HoneyDrunk.Cache` solution. Add `src/HoneyDrunk.Cache.Redis/` project. Implement `RedisCacheStore<T>` against `ICacheStore<T>` from `HoneyDrunk.Kernel.Abstractions`, backed by `StackExchange.Redis`. `AddHoneyDrunkCacheRedis<T>` extension. Standard Redis protocol commands only (no `RediSearch`, no `RedisJSON`, no `RedisTimeSeries` — D3). System.Text.Json for value serialization (D3). Tag-to-key index using standard Redis sets. Unit tests against an InMemory `IConnectionMultiplexer` fake. Version bump `0.0.1` → `0.1.0` on the `HoneyDrunk.Cache` solution (first real implementation; alignment-bump on the placeholder `HoneyDrunk.Cache.Adapters` per invariant 27).
5. **04 — Cache: Telemetry + health contributor + error-reporter facade wiring** — add `IHealthContributor` reporting connection state, hit/miss counters, and connection-pool depth via Kernel's telemetry primitives (per ADR-0040 D6 — telemetry flows one-way to Pulse, no runtime dependency on Pulse). Wire `IErrorReporter` (per ADR-0045 D3) for connection failures, command timeouts, deserialization errors. No version bump (appends to in-progress `0.1.0` started by packet 03).
6. **05 — Cache: Classification-aware encrypted value wrapper for Restricted-tier values** — Per ADR-0076 D6 + ADR-0049: any cached value carrying Restricted-tier material must be application-layer-encrypted when stored in a Standard-tier Redis (Premium is not adopted, so at-rest encryption is the consumer's responsibility). Add `IEncryptedCacheValue` opt-in surface in `HoneyDrunk.Cache.Redis` letting consumers explicitly mark a value as Restricted-tier — the backing then routes the value through AES-GCM with a Vault-resolved key before write and decrypts on read. No version bump (appends to `0.1.0`).

**No invariants packet.** Per the explicit ADR-0076 text ("No new Grid-wide invariants introduced. Conventions enforced at packet authoring and review"), this initiative adds zero rows to `constitution/invariants.md`. The Redis-protocol-only discipline (D3), the `allkeys-lru` default (D4), the per-environment sizing rubric (D2), and the classification-aware caching rule (D6) all live as ADR text + per-packet acceptance criteria, not as Grid-wide invariants. This matches ADR-0059's "None at stand-up" stance and is a deliberate restraint against invariant proliferation for decisions that affect one Node's backing.

## Wave Diagram

```
Wave 1: Architecture acceptance + catalogs + provisioning walkthrough
   ├─ Architecture: 00-architecture-adr-0076-acceptance
   │     No upstream dependencies.
   ├─ Architecture: 01-architecture-catalogs-and-walkthrough
   │     Blocked by: work-item:00
   └─ Architecture: 02-architecture-provision-dev-redis  (human-only)
         Blocked by: work-item:01

Wave 2: Cache.Redis implementation
   └─ Cache: 03-cache-redis-implementation
         Blocked by: work-item:01 (walkthrough must exist for the package README to cross-reference;
                                catalog rows must be in place so module identity is established)
                     work-item:02 (dev Redis instance must exist for the unit-test composition path
                                and the eventual smoke verification; NOT strictly required to compile
                                or pass unit tests since those run against an InMemory IConnectionMultiplexer
                                fake — but the Human Prerequisites describe why packet 02 should land first)

Wave 3: Cache.Redis hardening (parallel-able)
   ├─ Cache: 04-cache-redis-telemetry-and-health
   │     Blocked by: work-item:03
   └─ Cache: 05-cache-redis-classification-encryption
         Blocked by: work-item:03
```

Packets 04 and 05 modify the same `HoneyDrunk.Cache.Redis` project but in distinct surfaces (health/telemetry vs. encrypted-value wrapper). They are not strictly serialized by file conflict; the agent merging the second of the two should expect to rebase on the first. The dispatch plan does not force a serialization order — whichever wins the file-write race lands first, and the other rebases.

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 00 | [Accept ADR-0076 — Cache Backing Azure Cache for Redis](./00-architecture-adr-0076-acceptance.md) | Architecture | 1 | Agent | — |
| 01 | [Register Redis backing in catalogs, update tech-stack, author provisioning walkthrough](./01-architecture-catalogs-and-walkthrough.md) | Architecture | 1 | Agent | work-item:00 |
| 02 | [Provision `dev` Azure Cache for Redis Basic C0 instance (human-only)](./02-architecture-provision-dev-redis.md) | Architecture (tracking issue) | 1 | Human | work-item:01 |
| 03 | [Implement `HoneyDrunk.Cache.Redis` — `RedisCacheStore<T>` on StackExchange.Redis + DI extension](./03-cache-redis-implementation.md) | HoneyDrunk.Cache | 2 | Agent | work-item:01, work-item:02 |
| 04 | [Wire Redis backing telemetry, health contributor, and IErrorReporter failure path](./04-cache-redis-telemetry-and-health.md) | HoneyDrunk.Cache | 3 | Agent | work-item:03 |
| 05 | [Add classification-aware encrypted-value wrapper for Restricted-tier values](./05-cache-redis-classification-encryption.md) | HoneyDrunk.Cache | 3 | Agent | work-item:03 |

## Phase Mapping (ADR-0076 decisions → packets)

| Decision | Packet(s) |
|---|---|
| D1 — Azure Cache for Redis as default distributed-cache backing; `HoneyDrunk.Cache.Redis` package; `StackExchange.Redis`; managed-identity preferred / access-key fallback via Vault | 01 (walkthrough), 02 (provision), 03 (package + DI) |
| D2 — Per-environment sizing rubric (Basic C0 dev / Standard C1 staging / Standard prod baseline; no Premium) | 01 (walkthrough documents rubric), 02 (executes Basic C0 for dev) |
| D3 — Redis-protocol-only; no RediSearch, RedisJSON, RedisTimeSeries, RedisGraph, RedisBloom; System.Text.Json for serialization | 03 (acceptance criteria forbid module-specific commands; serializer is System.Text.Json) |
| D4 — Default eviction policy is `allkeys-lru` | 01 (walkthrough records the default), 02 (sets the policy on the dev instance), 03 (README documents the assumption; the backing does not configure server-side eviction — it is set on the Azure resource) |
| D5 — Provider abstraction held (alternate backings permitted; Azure Cache for Redis is default not only) | 03 (README notes the per-Node escape valve; package name `HoneyDrunk.Cache.Redis` reflects backing identity, not exclusivity) |
| D6 — Operational discipline: telemetry via Pulse, errors via App Insights, cost monitoring, DR tier 2, classification-aware Restricted-tier handling | 04 (telemetry + health + IErrorReporter), 05 (classification-aware encrypted wrapper) |
| D7 — Self-hosted Redis on Container Apps permitted for cost-pressured deployments | 01 (walkthrough documents the escape valve as an alternative path; no implementation in this initiative — the default backing is Azure Cache for Redis) |
| D8 — Out of scope (cache-invalidation lanes, per-Node key conventions, Cosmos-with-TTL, read/write-through patterns, multi-region cache replication, cluster mode) | All packets explicitly note the out-of-scope items in their Boundary Check sections; no follow-up packet here |

## Filing-order rule

Packet 03's body cross-references the walkthrough (`infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md`) and the catalog rows landed by packet 01. Filed packets are immutable (invariant 24). Therefore:

**Packet 01 must be filed, its PR merged, and the walkthrough + catalog rows actually on `main` before packet 03 is filed.**

In practice:

1. Push packets 00, 01, 02 (they may travel together — packet 01's `dependencies: ["work-item:00"]` and packet 02's `dependencies: ["work-item:01"]` wire the blocking edges automatically).
2. Wait for packet 01's PR to merge so `infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md` exists and the catalog rows reflect the backing decision.
3. Wait for packet 02 to close (the dev Azure Cache for Redis instance must exist before packet 03's smoke-verification acceptance criteria can be satisfied; unit tests run against the InMemory fake so they don't strictly need the instance).
4. Push packets 03, 04, 05 in the same push or staggered — 04 and 05 both depend on `work-item:03` only.

**Packets 01 and 03 cannot be filed in the same push.** Packet 03 must reach a state where the walkthrough and catalog rows exist; the file-work-items pipeline does not block on prior packet merges within the same push, so the filing order matters.

## Asymmetry vs ADR-0058 and ADR-0059

Three deliberate asymmetries relative to the upstream paired ADRs are worth recording:

1. **No invariants packet.** ADR-0058's acceptance initiative landed three caching invariants (per-Node-opaque caches, tenant-key isolation, classification inheritance). ADR-0059 added zero. ADR-0076 adds zero. The backing-decision ADR enforces its conventions at the packet-acceptance-criteria layer, not at the Grid-wide constitutional invariant layer — the rules apply to one Node's backing, not to every Node.

2. **Vault namespace ownership lives with the consumer, not the Cache Node.** Per invariant 17 ("One Key Vault per deployable Node per environment. Library-only Nodes have no vault. ... `HoneyDrunk.Cache` ... has no vault."), the Cache Node has no `kv-hd-cache-{env}` Key Vault. The Redis connection strings, when used, live in the **consumer Node's** Vault — `kv-hd-notify-cloud-{env}` for Notify Cloud, `kv-hd-comms-{env}` for Communications, etc. The provisioning walkthrough (packet 01) documents this; the dev-provisioning packet (packet 02) defers connection-string Vault seeding until the first consumer's Vault is the target. The ADR text (line 159) references `kv-hd-cache-{env}` but that is an artifact of pre-refine-pass thinking and contradicts invariant 17 — the packets correct it.

3. **Per-environment sizing is mostly walkthrough work, not code work.** Most of the per-environment decision (Basic C0 / Standard C1 / Standard prod baseline) lives in the walkthrough and the human-executed portal step; the .NET code is environment-agnostic — it takes a connection string and behaves correctly. This is the right separation: code does not know its environment; the Vault-stored connection string does.

## What This Initiative Does **NOT** Deliver

- **A staging or prod Azure Cache for Redis instance.** Per ADR-0053 (the environments-standup ADR), staging and prod environments are still in flight. Packet 02 provisions `dev` only. The walkthrough is authored to cover all three environments so future provisioning is a repeat execution, not a new packet.
- **The first consumer composing the Redis backing.** Notify Cloud multi-replica and Communications shared cache are downstream feature packets against the consuming Node at the time their workload demands a distributed cache. This initiative ships the package; the composition lives in a future Notify Cloud or Communications packet. The connection-string-into-consumer-Vault step happens in that future packet, not in packet 02.
- **Managed-identity authentication wiring on the .NET side.** Per ADR-0076 D1, managed identity is preferred where Azure Cache for Redis supports it (Standard tier and above). The first consumer composition packet handles the consumer-side `DefaultAzureCredential` / Entra-based connection wiring; the `HoneyDrunk.Cache.Redis` package supports both managed-identity and access-key paths but does not itself wire credentials — that is host-time work at the composing Node.
- **The Communications consumer composition or Notify Cloud consumer composition.** Each is a separate feature packet against the consuming Node.
- **Self-hosted Redis on Container Apps.** Permitted per D7 but not implemented. If a future cost-pressured deployment chooses self-host, that is a separate packet against the consuming Node.
- **Cosmos-with-TTL or Postgres-with-TTL backings.** Permitted per ADR-0058 D5 + ADR-0076 D5 but not implemented. Each is a separate future packet when a workload chooses it.
- **HTTP / output response caching.** Per ADR-0059 §Unblocks. Likely paired with the Gateway standup. Not in scope here.
- **Cache invariants.** Per ADR-0076 §"Invariants" ("No new Grid-wide invariants introduced.").
- **Premium-tier provisioning.** Per ADR-0076 D2 + the alternatives-considered section. Premium tier is held in reserve; this initiative does not provision any Premium-tier instance.
- **Cost-monitoring dashboard wiring.** Per ADR-0076 D6 references ADR-0052 (cost governance). Wiring lives in a separate cost-governance dashboard packet; this initiative records that Redis spend should appear on it (packet 01 grid-health row), not the dashboard work itself.

## Notes

- **No Azure provisioning beyond the dev instance in this initiative.** Per ADR-0053, staging and prod environments are still standing up. Packet 02 provisions `dev`. Staging/prod follow when those environments exist, as repeat executions of the walkthrough.
- **Cache repo is public per the standing default.** Per memory `project_repos_public_by_default`, `HoneyDrunk.Cache` is public. The Redis backing is substrate, not commercial product — no revenue carve-out. No PII storage at the Cache layer (cached values are by-construction classified by the consumer); no compliance carve-out beyond the application-layer encryption in packet 05. Public is correct.
- **No ADR numbers in user-facing docs or code comments.** Per memory `feedback_no_adr_in_docs`. The `HoneyDrunk.Cache.Redis` package README explains what the backing does and what its operational shape is, without citing "ADR-0076" or "ADR-0058" in the narrative. Runtime / packet-data references (catalog entries, frontmatter, this dispatch plan, CHANGELOG entries) cite ADRs by number freely.
- **No commits under CHANGELOG Unreleased.** Per memory `feedback_no_unreleased_commits`. Packet 03's first commit lands under `## [0.1.0] - YYYY-MM-DD`, not `## Unreleased`. The tag push happens after merge; the version section in CHANGELOG is dated and SemVer-bumped before the commit.
- **No manual packet filing.** Per memory `feedback_no_manual_packet_filing`. `file-work-items.yml` auto-files on push to `main`. Do not run `gh issue create` against these packets.
- **Cache → Kernel edge direction (one-way, strict).** The Redis backing's `RedisCacheStore<T>` references `HoneyDrunk.Kernel.Abstractions` for `ICacheStore<T>`. Kernel does not reference any `HoneyDrunk.Cache.*` package. This matches ADR-0058 D2 + ADR-0059's leaf-node posture.
- **`IStartupHook` lives in `HoneyDrunk.Kernel.Abstractions.Lifecycle`.** Verified existing. The Redis backing wires a startup-warmup connection probe via `IStartupHook` to fail fast at host startup if the Redis instance is unreachable — same pattern as Vault's startup warmup per `HoneyDrunk.Vault`'s established discipline.
- **`IErrorReporter` lives in HoneyDrunk.Pulse per ADR-0045 D3.** A thin facade over the existing `IErrorSink` Pulse surface. Packet 04 references it for connection failures, command timeouts, and deserialization errors. Cache → Pulse is one-way (Cache emits, Pulse consumes); no runtime dependency on Pulse beyond the Abstractions package per the established Cache → Pulse boundary.
- **Telemetry attributes per ADR-0040 D6.** High-cardinality identifiers (cache keys, tenant ids) go on traces / logs, never on metrics. Hit rate, miss rate, eviction count, latency p50/p95/p99, connection-pool depth are the metric surface; cache keys are trace attributes only.
- **Data classification per ADR-0049.** Restricted-tier values get the application-layer encryption treatment in packet 05. Internal-tier and Tenant-tier values get standard Redis storage (encryption-in-transit, not at-rest in Standard tier — accepted per ADR-0076 D6).
- **The Adapters placeholder project stays.** The `HoneyDrunk.Cache.Adapters` placeholder from the ADR-0059 standup is not removed by this initiative. It carries the alignment-bump version with the rest of the solution per invariant 27. If a future initiative removes it as obsolete, that is a separate cleanup packet — not work for this initiative.

## Status-flip handling

ADR-0076 stays at `Status: Proposed` for the duration of packet 00's PR (the acceptance packet does the body work but the Status flip is the post-merge step). The Status flip happens after every packet in this initiative has reached Done **and** the two upstream paired ADRs (ADR-0058, ADR-0059) are themselves Accepted.

**Three gates on the ADR-0076 Status flip:**

1. All six packets in this initiative are Done.
2. ADR-0058 is Accepted. (Confirmed at scoping time — PR #301 merged.)
3. ADR-0059 is Accepted. (Confirmed at scoping time — PR #323 merged.)

Gates 2 and 3 are already satisfied. Gate 1 unblocks when the initiative completes.

The flip is a one-line edit to `adrs/ADR-0076-cache-backing-azure-cache-for-redis.md` line 3 (`**Status:** Proposed` → `**Status:** Accepted`), plus any matching update to `adrs/README.md` if it carries a per-ADR Status entry, plus a CHANGELOG note. The hive-sync agent's ADR auto-acceptance loop may also reconcile this on its next run if it is delayed.

## Filing

The `file-work-items.yml` workflow in `HoneyDrunk.Architecture` triggers automatically on push to `generated/work-items/active/**/*.md`. No `gh issue create` commands in this dispatch plan — the pipeline handles filing, project-board addition, field population, and `addBlockedBy` wiring from the `dependencies:` frontmatter on each packet. Verify after push by checking The Hive (org Project #4) for the new items and their blocking edges.

The exception is packet 02 (the human chore), which is human-executed in the Azure Portal. Its acceptance criteria are satisfied when the dev Redis instance is live and the operator updates `catalogs/grid-health.json` to reflect the provisioned state.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board AND `HoneyDrunk.Cache 0.1.0` is published to NuGet AND ADR-0076 has been flipped to Accepted, the entire `active/adr-0076-cache-backing-redis/` folder moves to `archive/adr-0076-cache-backing-redis/` in a single commit. Partial archival is forbidden.

The hive-sync agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep that follows after the whole folder reaches `Done`.
