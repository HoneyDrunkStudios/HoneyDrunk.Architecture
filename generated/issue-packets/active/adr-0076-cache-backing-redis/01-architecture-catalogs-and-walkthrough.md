---
name: Architecture Catalog Registration + Walkthrough
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "infrastructure", "cache", "adr-0076", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0076", "ADR-0058", "ADR-0059", "ADR-0053", "ADR-0005"]
accepts: ADR-0076
wave: 1
initiative: adr-0076-cache-backing-redis
node: honeydrunk-architecture
---

# Chore: Register Redis backing in catalogs, update tech-stack, author Azure Cache for Redis provisioning walkthrough

## Summary
Reflect ADR-0076's backing decision in the canonical Architecture catalogs, the tech-stack reference doc, and a new infrastructure walkthrough. Add a `cache-redis` row to `catalogs/modules.json` (Seed, runtime, owned by `honeydrunk-cache`) covering the new `HoneyDrunk.Cache.Redis` package that packet 03 will ship. Add `dev` / `staging` / `prod` Azure Cache for Redis instance entries to `catalogs/grid-health.json` (`dev` as `not-provisioned` for now — flipped to `provisioned` by packet 02; `staging` / `prod` recorded as `not-provisioned-environment-pending` per ADR-0053). Update the contracts catalog if it tracks `ICacheStore<T>` backing implementations (add the Redis backing as a known implementation). Update `infrastructure/reference/tech-stack.md` Redis row from "Future / HoneyDrunk.Cache abstraction" to "Standing up — Azure Cache for Redis adapter in progress (`HoneyDrunk.Cache.Redis`)." Author `infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md` covering per-environment sizing (Basic C0 dev, Standard C1 staging/prod), the `allkeys-lru` eviction-policy default, TLS-only access verification, encryption-in-transit confirmation, the **consumer-Vault** connection-string seeding flow (NOT a `kv-hd-cache-{env}` Vault — Cache is a library Node with no Vault per invariant 17), and the self-hosted-on-Container-Apps alternative path documented per ADR-0076 D7.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

ADR-0076 commits Azure Cache for Redis as the canonical first distributed-cache backing for `HoneyDrunk.Cache`. None of that has reached the catalogs or the reference docs yet. Until it does:

- `catalogs/modules.json` does not list the `HoneyDrunk.Cache.Redis` package; downstream Notify Cloud / Communications scoping has nothing concrete to point at.
- `catalogs/grid-health.json` does not show the per-environment Redis instances on the Grid-health readout; cost tracking and provisioning state have no row.
- `infrastructure/reference/tech-stack.md`'s "Future Backings" Redis row reads as if no decision has been made; the operator-facing reference is stale.
- No walkthrough document exists for provisioning Azure Cache for Redis in the Azure Portal — packet 02 (the human portal step) has nothing to execute against.

This packet closes those drift items in a single edit:

1. **`catalogs/modules.json`** — add a `cache-redis` row owned by `honeydrunk-cache`, `type: runtime`, signal Seed, naming reflects the package identity. The placeholder `cache-adapters` row (if any was added by the ADR-0059 standup) stays as-is — the Adapters placeholder project continues to exist per invariant 27 alignment.
2. **`catalogs/grid-health.json`** — add three Azure Cache for Redis instance rows: `redis-hd-dev` (state `not-provisioned`, will flip to `provisioned` after packet 02), `redis-hd-staging` (state `not-provisioned-environment-pending` per ADR-0053), `redis-hd-prod` (same). Also add `honeydrunk-cache` to any module-level state lists where the `HoneyDrunk.Cache.Redis` package's stand-up signal should land.
3. **`catalogs/contracts.json`** — if the file tracks `ICacheStore<T>` backing implementations (it should, per ADR-0058's acceptance work), add the Azure Cache for Redis backing as a known implementation row under `ICacheStore<T>` with `package: HoneyDrunk.Cache.Redis`, `owner: honeydrunk-cache`, `signal: seed`. If the file does not yet carry per-backing rows, defer this edit — the contracts catalog edit can land in a follow-up if the schema is not yet in place. The packet's acceptance criteria mark this as a conditional edit.
4. **`infrastructure/reference/tech-stack.md`** — update the Redis row. Pre-state likely reads something like `| Redis / distributed cache | Future | HoneyDrunk.Cache abstraction |`; post-state reads `| Azure Cache for Redis | Standing up | HoneyDrunk.Cache.Redis (StackExchange.Redis) — Basic C0 dev, Standard C1 staging/prod baseline |`.
5. **`infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md`** — new walkthrough document (see below).
6. **`initiatives/active-initiatives.md`** — add an `ADR-0076 Cache Backing Azure Cache for Redis` entry under `## In Progress`.

## Proposed Implementation

### `catalogs/modules.json` — new `cache-redis` entry

Add a new entry to the `modules` array (or whatever shape the file uses) owned by `honeydrunk-cache`:

```json
{
  "id": "cache-redis",
  "type": "runtime",
  "owner": "honeydrunk-cache",
  "package": "HoneyDrunk.Cache.Redis",
  "signal": "Seed",
  "tags": ["cache", "redis", "distributed-cache", "stackexchange-redis"],
  "description": "Azure Cache for Redis backing implementation of ICacheStore<T> (declared in HoneyDrunk.Kernel.Abstractions). Built on StackExchange.Redis. Standard Redis protocol commands only — no RediSearch, RedisJSON, RedisTimeSeries, or other Azure-Redis modules per ADR-0076 D3."
}
```

If the file's existing schema does not include `package` or `tags`, drop those keys and use the equivalent fields the schema does carry. Conform to the file's existing pattern; do not invent new top-level keys.

### `catalogs/grid-health.json` — three new Redis instance entries + module state

Add three entries to whatever section of the file tracks Azure resources by environment. Approximate shape (conform to the file's actual schema at edit time):

```json
{
  "id": "redis-hd-dev",
  "type": "azure-resource",
  "kind": "azure-cache-for-redis",
  "tier": "basic-c0",
  "environment": "dev",
  "owner": "honeydrunk-cache",
  "state": "not-provisioned",
  "estimated_monthly_cost_usd": 16,
  "notes": "Provisioned by packet 02 of adr-0076-cache-backing-redis initiative. Basic C0 (~$16/mo, 250 MB). Eviction policy allkeys-lru per ADR-0076 D4. TLS-only access. No managed-identity auth on Basic tier — falls back to access keys stored in the FIRST CONSUMER Node's Vault (Notify Cloud's kv-hd-notify-cloud-dev or Communications's kv-hd-comms-dev — whichever lands first), NOT a kv-hd-cache-{env} Vault (Cache is a library Node with no Vault per invariant 17)."
},
{
  "id": "redis-hd-staging",
  "type": "azure-resource",
  "kind": "azure-cache-for-redis",
  "tier": "standard-c1",
  "environment": "staging",
  "owner": "honeydrunk-cache",
  "state": "not-provisioned-environment-pending",
  "estimated_monthly_cost_usd": 80,
  "notes": "Provisioned when staging environment stands up (gated on ADR-0053). Standard C1 (~$80/mo, 1 GB, primary/replica). Eviction policy allkeys-lru. Managed-identity auth supported on Standard tier. Connection string lives in the first-consumer's Vault (kv-hd-notify-cloud-staging or kv-hd-comms-staging) when that consumer composes; NOT a Cache-owned Vault."
},
{
  "id": "redis-hd-prod",
  "type": "azure-resource",
  "kind": "azure-cache-for-redis",
  "tier": "standard-c1-or-larger",
  "environment": "prod",
  "owner": "honeydrunk-cache",
  "state": "not-provisioned-environment-pending",
  "estimated_monthly_cost_usd": 80,
  "notes": "Provisioned when prod environment stands up (gated on ADR-0053). Starts at Standard C1 (~$80/mo). Scales to C2/C3/C4 per workload data. Premium tier NOT adopted by default — held in reserve per ADR-0076 D2 alternatives. Managed-identity auth via consumer Node. Connection string lives in the first-consumer's prod Vault."
}
```

Also add `cache-redis` to the `summary.module_states` section (or equivalent) reflecting the Seed signal for the new module.

### `catalogs/contracts.json` — Redis backing as known `ICacheStore<T>` implementation (conditional)

If the file tracks per-contract implementations under an `ICacheStore<T>` entry (it should, per ADR-0058's acceptance work; verify at edit time), add a row:

```json
{
  "implementation_id": "cache-store-redis",
  "contract": "ICacheStore<T>",
  "package": "HoneyDrunk.Cache.Redis",
  "owner": "honeydrunk-cache",
  "signal": "Seed",
  "kind": "distributed-backing",
  "notes": "Azure Cache for Redis backing per ADR-0076. Default distributed backing for Grid Nodes needing cross-replica cache coordination. Per-Node alternatives (Cosmos with TTL, Postgres with TTL, self-hosted Redis on Container Apps) permitted per ADR-0058 D5 / ADR-0076 D5 / D7."
}
```

If `contracts.json` does not yet carry per-contract implementation tracking, skip this edit and note it in the PR body — it can land as a follow-up when the contracts catalog gains that schema.

### `infrastructure/reference/tech-stack.md` — Redis row update

Find the row currently describing Redis (likely something like `| Redis / distributed cache | Future | HoneyDrunk.Cache abstraction |` from the ADR-0059 standup). Replace with shape matching the table's existing column layout. Recommended text:

```markdown
| Azure Cache for Redis | Standing up | HoneyDrunk.Cache.Redis (StackExchange.Redis) — Basic C0 dev, Standard C1 staging/prod baseline; allkeys-lru eviction; Redis-protocol-only (no Azure-Redis modules); managed-identity on Standard+, access-key fallback via consumer-Node Vault. |
```

If the table has different columns, conform to whatever the existing shape is — the goal is the row reflects the backing decision is made and the implementation is in progress.

### `initiatives/active-initiatives.md` — new entry

Add under `## In Progress`:

```markdown
- **ADR-0076 Cache Backing: Azure Cache for Redis** — first distributed-cache backing for `HoneyDrunk.Cache`. Six packets: ADR acceptance marker, catalog + walkthrough (this packet), dev portal provisioning, `HoneyDrunk.Cache.Redis` implementation, telemetry + health + error-reporter wiring, classification-aware encrypted-value wrapper. Initiative folder: `generated/issue-packets/active/adr-0076-cache-backing-redis/`.
```

### `infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md` — new walkthrough

Author a Portal-UI walkthrough modeled on the existing siblings in `infrastructure/walkthroughs/` (`key-vault-creation.md`, `application-insights-provisioning.md`, `container-app-creation.md`). Structure:

```markdown
# Azure Cache for Redis Provisioning (Azure Portal)

**Applies to:** ADR-0076, ADR-0058, ADR-0059, ADR-0005 (consumer-Vault secret seeding).
**Related invariants:** 17 (Cache has no Vault — connection strings live in consumer Node Vaults), 19 (naming prefix `hd`), 21 (no version pinning on resolved secrets).

## Goal

Provision a per-environment Azure Cache for Redis instance named `redis-hd-{env}` with:
- **Basic C0** tier for `dev` (~$16/mo, 250 MB, single instance, no HA, no managed-identity auth — uses access keys).
- **Standard C1** tier for `staging` (~$80/mo, 1 GB, primary/replica, managed-identity auth supported).
- **Standard C1** baseline for `prod` (size up to C2/C3/C4 per workload data; Premium tier NOT adopted by default).

Eviction policy `allkeys-lru` (per ADR-0076 D4). Redis-protocol-only commands; no Azure-Redis modules enabled. TLS-only access.

## Portal Breadcrumb

**Azure Portal → Azure Cache for Redis → + Create → Basics / Networking / Advanced / Tags → Review + create**

## Pre-create cost confirmation

Before clicking Create, the Portal shows the estimated monthly cost on the Review + create blade. Confirm the number matches the expected tier:
- Basic C0: ~$16/mo (dev).
- Standard C1: ~$80/mo (staging / prod baseline).
- Premium tier: $300+/mo per instance. NOT adopted by default per ADR-0076 D2 — if the Portal estimate shows a Premium-tier cost, STOP and re-check the tier selection.

(Per the user's standing preference for Portal UI walkthroughs and cheapest-viable Azure tier defaults.)

## Step-by-step

### Basics blade

1. Subscription: choose target subscription.
2. Resource group: choose the target environment's resource group (`rg-hd-{env}` per the broader Grid convention, or the specific Cache-related RG if one exists).
3. DNS name: `redis-hd-{env}` (e.g., `redis-hd-dev`).
4. Region: same as the Container Apps environment that will consume the cache (`East US` for the dev environment unless otherwise specified — colocate for latency).
5. Cache SKU: per the table above. `dev` → **Basic C0**. `staging` / `prod` → **Standard C1** baseline.

### Networking blade

6. Connectivity method: **Public Endpoint** for dev and staging (no VNet integration on Basic tier; staging/prod can move to Private Endpoint later if compliance pressure justifies — out of scope here per ADR-0076 D8).
7. TLS settings: **Minimum TLS version 1.2**. Non-SSL port: **Disabled** (no plaintext access).

### Advanced blade

8. Access keys: **Enabled** for dev (Basic tier does not support managed-identity auth). For staging/prod (Standard tier), keep access keys enabled as a fallback but plan to use managed identity on the consumer side.
9. Microsoft Entra Authentication: **Enabled** on Standard / Premium tiers (skip on Basic — not available). The consumer Node's managed identity gets `Data Contributor` role on the cache resource at the time the consumer Node composes — that is the consumer's Vault / RBAC work, not this packet's.
10. Eviction policy: confirm or set to **allkeys-lru** (per ADR-0076 D4).
11. Cluster: **Disabled** (Standard tier does not support clustering; Premium does and is out of scope per ADR-0076 D8).
12. Redis modules: **None enabled**. Do NOT enable RediSearch, RedisJSON, RedisTimeSeries, RedisGraph, or RedisBloom (per ADR-0076 D3).
13. Persistence: **Disabled** for dev. For staging/prod (Standard tier), persistence is also disabled — Grid cache values are by-construction ephemeral per ADR-0076 D1; no persistence backing needed.

### Tags blade

14. Add tags:
    - `env={env}` (e.g. `env=dev`)
    - `node=honeydrunk-cache`
    - `purpose=cache-backing`
    (Per the user's standing lean tag scheme — `env` always; `node` for per-Node; never `initiative`.)

### Review + create

15. Confirm the estimated monthly cost matches expectations.
16. Click **Create**.
17. Provisioning takes ~15-20 minutes. Wait for the resource to reach Running state in the portal.

## Post-create verification

1. Open the new cache resource → **Properties**.
2. Verify Eviction Policy reads `allkeys-lru`. (If it does not — Portal sometimes defaults to `volatile-lru` on Basic tier — set it explicitly via **Advanced settings**.)
3. Verify **Non-SSL port** is `Disabled` and **Minimum TLS version** is `1.2`.
4. Open **Access keys** blade. Two keys (Primary / Secondary) are shown. Copy the **Primary connection string** (the full string ending in `,ssl=True,abortConnect=False`). Do not paste it anywhere outside this step.

## Consumer-Vault connection-string seeding

> **Cache is a library Node with no Vault** (invariant 17 — library Nodes such as Kernel, Vault, Transport, Architecture have no Vault). There is no `kv-hd-cache-{env}` Key Vault. The Redis connection string lives in the **first consumer Node's** Vault — whichever Node first composes the Redis backing (most likely `HoneyDrunk.Notify.Cloud` per ADR-0027 multi-replica, or `HoneyDrunk.Communications` per ADR-0019 preference cache).

1. Identify the first consumer's Vault name per its own ADR (`kv-hd-notify-cloud-{env}` or `kv-hd-comms-{env}` — verify the actual ≤13-char service-name token from the consumer's standup ADR).
2. Open that Vault in the Azure Portal → **Secrets** → **+ Generate/Import**.
3. Secret name: `redis-connection-string` (or whatever name the consumer Node's overview / runtime convention uses for its cache connection string — defer to the consumer's standup ADR if it specifies one).
4. Secret value: paste the connection string copied above.
5. Click **Create**.
6. Verify the secret exists; do NOT print it back to the terminal or screenshot it (per invariant 8 — secret values never appear in logs, traces, exceptions, or telemetry).
7. Confirm the consumer Node's host code path resolves the secret via `ISecretStore` per invariant 9, never pinning to a version per invariant 21.

If no consumer is provisioning the Redis instance at this time (e.g., dev provisioning happens before any consumer composes), the connection string is **not seeded** during packet 02; instead the operator notes the access-key value in a secure local note and seeds it into the consumer's Vault at the time the consumer Node's composition packet runs. This avoids creating a transient Cache-owned Vault that would violate invariant 17.

## Self-hosted Redis on Container Apps (alternative per ADR-0076 D7)

Permitted per ADR-0076 D7 as a per-Node alternative when the managed-service premium does not earn its keep. The walkthrough documents the existence of this path but does not detail the steps — that is a separate walkthrough authored at the time a Node actually chooses self-host. The default remains Azure Cache for Redis as documented above.

If a future Node opts for self-host:
- Container App owns the Redis container lifecycle (Redis version, patches, configuration tuning).
- No HA unless the Node implements it (single-replica self-host is a single point of failure; consumers must tolerate cache flush on Redis restart).
- No replication, no failover, no managed backups.
- Authoring the self-host walkthrough is that Node's packet, not this packet's.

## Per-environment repeat execution

This walkthrough is parameterized on `{env}`. Repeat the steps for `staging` and `prod` when those environments stand up per ADR-0053. The tier selection differs (Basic C0 → Standard C1 → Standard C1+); everything else is identical.

## Cross references

- [ADR-0076](../../adrs/ADR-0076-cache-backing-azure-cache-for-redis.md) — backing decision, sizing rubric, eviction policy, classification handling.
- [ADR-0058](../../adrs/ADR-0058-grid-wide-caching-strategy.md) — Grid-wide caching strategy; ICacheStore<T> contract.
- [ADR-0059](../../adrs/ADR-0059-stand-up-honeydrunk-cache-node.md) — Cache Node home.
- [ADR-0053](../../adrs/ADR-0053-environments-branching-and-release-cadence.md) — per-environment naming; staging/prod environments in flight.
- [ADR-0005](../../adrs/ADR-0005-configuration-and-secrets-strategy.md) — Vault as only source of secrets; consumer-Vault seeding pattern.
- [ADR-0049](../../adrs/ADR-0049-data-classification-pii-handling-and-retention-schedule.md) — data classification; Restricted-tier handling for cached values (application-layer encryption per ADR-0076 D6, implemented by packet 05).
- [Invariants 17, 19, 21](../../constitution/invariants.md).
- [key-vault-creation.md](./key-vault-creation.md) — sibling walkthrough for the consumer Node's Vault.
```

## Affected Files

- `catalogs/modules.json` — add `cache-redis` row.
- `catalogs/grid-health.json` — add three Azure Cache for Redis instance rows (`redis-hd-dev`, `redis-hd-staging`, `redis-hd-prod`) and the module state for `cache-redis`.
- `catalogs/contracts.json` — conditional row addition for the Redis backing implementation (verify schema at edit time; skip if not yet supported).
- `infrastructure/reference/tech-stack.md` — Redis row update.
- `infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md` — new file.
- `initiatives/active-initiatives.md` — new entry under `## In Progress`.
- Repo-level `CHANGELOG.md` — entry under the current in-progress version section.

## NuGet Dependencies

None. This packet has no .NET project.

## Boundary Check

- [x] All work inside `HoneyDrunk.Architecture`. No other Grid repos affected.
- [x] **No `kv-hd-cache-{env}` Vault row anywhere.** Per invariant 17, Cache is a library Node with no Vault. The walkthrough explicitly routes connection-string ownership to consumer Node Vaults.
- [x] No edit to `catalogs/nodes.json` (the `honeydrunk-cache` Node entry from the ADR-0059 standup is correct — this packet does not modify it).
- [x] No edit to `catalogs/relationships.json` (the `consumed_by_planned` edges from the ADR-0059 standup are correct; the first real consumer will move the edge to `consumed_by` when it composes).
- [x] No edit to the ADR file itself (packet 00 handled the acceptance-tracking marker; the Status flip is post-merge housekeeping).
- [x] No edit to `constitution/invariants.md` (ADR-0076 commits no new invariants).

## Acceptance Criteria

- [ ] `catalogs/modules.json` has a new `cache-redis` row owned by `honeydrunk-cache`, `type: runtime` (or schema equivalent), Seed signal, referencing the `HoneyDrunk.Cache.Redis` package
- [ ] `catalogs/grid-health.json` has three Azure Cache for Redis instance rows (`redis-hd-dev` with state `not-provisioned`, `redis-hd-staging` with state `not-provisioned-environment-pending`, `redis-hd-prod` with state `not-provisioned-environment-pending`)
- [ ] **None of the new `grid-health.json` rows reference a `kv-hd-cache-{env}` Vault.** Per invariant 17 — Cache has no Vault. Connection strings live in consumer-Node Vaults; the `notes` fields document this explicitly
- [ ] `catalogs/contracts.json` Redis backing row added if the file's schema supports per-contract implementations; PR body documents the decision and notes if the edit was skipped pending schema evolution
- [ ] `infrastructure/reference/tech-stack.md` Redis row updated from `Future` to `Standing up — HoneyDrunk.Cache.Redis (StackExchange.Redis)` shape
- [ ] `infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md` exists as a step-by-step Azure-Portal UI walkthrough covering per-environment sizing (Basic C0 dev / Standard C1 staging / prod), eviction policy `allkeys-lru`, TLS-only access, Redis modules **disabled**, persistence **disabled**, and the consumer-Vault connection-string seeding flow
- [ ] The walkthrough explicitly states that Cache has no Vault per invariant 17 and routes connection-string ownership to consumer Node Vaults (Notify Cloud's `kv-hd-notify-cloud-{env}` or Communications's `kv-hd-comms-{env}`)
- [ ] The walkthrough shows the estimated monthly cost confirmation step before Create (Basic C0 ~$16/mo, Standard C1 ~$80/mo; Premium NOT adopted)
- [ ] The walkthrough documents the self-hosted-on-Container-Apps alternative path (per ADR-0076 D7) as permitted but not detailed — pointing to a future per-Node walkthrough if/when a Node opts for self-host
- [ ] The walkthrough covers per-environment repeat execution (parameterized on `{env}`) so future staging/prod provisioning is a re-execution, not a new packet
- [ ] `initiatives/active-initiatives.md` has an `ADR-0076 Cache Backing Azure Cache for Redis` entry under `## In Progress`
- [ ] Repo-level `CHANGELOG.md` has an entry under the current in-progress version section (NOT `## Unreleased`) describing the catalog + walkthrough work
- [ ] No connection string, instrumentation key, or any secret value appears in the walkthrough or anywhere in the repo (invariant 8)
- [ ] No Azure resource provisioned by this packet — provisioning is packet 02's territory

## Human Prerequisites

- [ ] Packet 00 of this initiative complete — the acceptance-tracking marker is on the ADR file.
- [ ] No portal action required for this packet (the Azure resource provisioning is packet 02). The walkthrough authored here is what packet 02 executes.
- [ ] None of this initiative's substantive code work happens until packet 03; this packet is documentation + catalogs only.

## Referenced ADR Decisions

**ADR-0076 D1 — Azure Cache for Redis as default distributed-cache backing:** `HoneyDrunk.Cache.Redis` is the package name (literal text from D1); StackExchange.Redis is the client; Azure-managed Redis is the runtime backing; per-environment instances named `redis-hd-{env}`; managed-identity preferred, access-key fallback through Vault per ADR-0005; same region as the Container Apps environment.

**ADR-0076 D2 — Per-environment sizing rubric:** Basic C0 dev (~$16/mo), Standard C1 staging (~$80/mo, HA-shaped), Standard C1 prod baseline (scales to C2/C3/C4 per workload). Premium tier NOT adopted by default — held in reserve. Walkthrough documents the rubric; packet 02 executes for dev.

**ADR-0076 D3 — Redis-protocol-only; no Azure-Redis modules:** No RediSearch, no RedisJSON, no RedisTimeSeries, no RedisGraph, no RedisBloom. No reliance on Azure-managed Redis persistence. The discipline is the cheap vendor-exit hedge — protocol-portable for future migration to KeyDB / Valkey / Dragonfly / Redis on Container Apps. Walkthrough's Advanced blade explicitly disables modules.

**ADR-0076 D4 — Default eviction policy is `allkeys-lru`:** Cache values are cache-shaped, not state-shaped; eviction under memory pressure is expected; LRU across all keys is the broadly-correct default. Walkthrough records the default; packet 02 verifies/sets the policy on the dev instance.

**ADR-0076 D7 — Self-hosted Redis on Container Apps permitted:** Walkthrough documents the existence of this alternative path; does not detail steps — that is a separate per-Node walkthrough when a Node opts in.

**ADR-0053 — Per-environment branching and release cadence:** Staging and prod environments are in flight; only dev is provisioned at the time this initiative lands. The walkthrough is authored for all three environments as repeat executions.

**ADR-0005 — Vault and Key Vault naming + Vault-as-only-secret-source:** Connection strings live in the consumer Node's Vault (`kv-hd-notify-cloud-{env}` or `kv-hd-comms-{env}` — whichever first composes). Cache has no Vault. Consumer host code resolves via `ISecretStore` per invariant 9, never pinning to a secret version per invariant 21.

## Constraints

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The Redis connection string is a secret. It never enters the repo, the walkthrough body, a config file, or a commit. Only the *fact* of provisioning is recorded.

> **Invariant 9 — Vault is the only source of secrets.** The consumer Node resolves the Redis connection string via `ISecretStore` at the time it composes the Redis backing — never from an environment variable holding the raw string or from a provider SDK default.

> **Invariant 17 — One Key Vault per deployable Node per environment.** Named `kv-hd-{service}-{env}` with Azure RBAC. **Library Nodes (Kernel, Vault, Transport, Architecture) have no Vault.** `HoneyDrunk.Cache` is a library Node per ADR-0059 — no `kv-hd-cache-{env}` Vault exists or is provisioned. The Redis connection string lives in the consumer Node's Vault. This invariant is the load-bearing reason for the walkthrough's consumer-Vault seeding section; the catalog rows reflect it; the ADR text's reference to `kv-hd-cache-{env}` on line 159 is a pre-refine-pass artifact this packet does not reproduce.

> **Invariant 19 — Service names in Azure resource naming must be ≤ 13 characters.** `redis-hd-{env}` uses 9 chars for `redis-hd-` and the separator before `{env}`; the `{env}` token (`dev`, `staging`, `prod`) fits comfortably within Azure's broader naming length limits for cache resources. (Redis cache name limit is 63 characters; this is just for naming-convention consistency with the Grid's `hd-` prefix.)

> **Invariant 21 — Applications must never pin to a specific secret version.** When the consumer Node resolves the Redis connection string, it resolves the latest version via `ISecretStore`. Pinning would break Event Grid cache invalidation if the connection string ever rotates.

- **Per-environment sizing.** Basic C0 for dev, Standard C1 baseline for staging/prod. No Premium tier provisioning. The walkthrough's pre-create cost confirmation step catches any tier-selection error.
- **`allkeys-lru` eviction policy is the Grid default.** Per ADR-0076 D4.
- **Portal-only, UI walkthrough.** Per the user's standing preference for Azure Portal over CLI. No Bicep, no ARM, no CLI commands in the walkthrough.
- **No persistence enabled.** Per ADR-0076 D3 — cache values are by-construction ephemeral; no Redis persistence backing.
- **No Redis modules enabled.** Per ADR-0076 D3 — protocol-portable.

## Dependencies

- `packet:00` — packet 00's acceptance-tracking marker on the ADR file should land first so this packet's CHANGELOG entry references a consistent state.

## Labels

`chore`, `tier-2`, `architecture`, `infrastructure`, `cache`, `adr-0076`, `wave-1`

## Agent Handoff

**Objective:** Land the catalog updates (`modules.json` row, `grid-health.json` three Redis-instance rows, optional `contracts.json` row), the tech-stack reference update (Redis row from Future to Standing up), the new `azure-cache-for-redis-provisioning.md` walkthrough, the active-initiatives entry, and the CHANGELOG entry. **No portal action; no .NET code; no ADR-body changes.**

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make ADR-0076's backing decision visible in the canonical Grid catalogs and reference docs so downstream packets (Notify Cloud composition, Communications composition, future Cosmos backing) can scope against a consistent surface.
- Feature: ADR-0076 acceptance initiative, Wave 1, Packet 01.
- ADRs: ADR-0076 (the backing decision being recorded), ADR-0058 + ADR-0059 (paired upstream prerequisites — both Accepted), ADR-0053 (environments in flight — only dev is provisioned by this initiative), ADR-0005 (consumer-Vault secret seeding pattern).

**Acceptance Criteria:** As listed above.

**Dependencies:** `packet:00`.

**Constraints:**

- **Invariant 17:** One Key Vault per deployable Node per environment. Library Nodes have no Vault. `HoneyDrunk.Cache` is a library Node — no `kv-hd-cache-{env}` Vault. Connection strings live in the consumer Node's Vault. The walkthrough must route this correctly; the catalog rows must not reference a Cache-owned Vault.
- **Invariant 19:** Service names ≤ 13 characters in Azure resource naming. `redis-hd-{env}` complies.
- **Invariant 8 / 9 / 21:** Secret values never in repo/logs/traces; Vault is the only source; never pin to a secret version. The walkthrough text honors all three.
- **No `## Unreleased` block in CHANGELOG.** Per memory `feedback_no_unreleased_commits`. Entry lands under the current in-progress version section.
- **Cheapest viable tier.** Basic C0 dev, Standard C1 staging/prod baseline; Premium NOT adopted. The walkthrough's pre-create cost confirmation enforces this.
- **No portal action in this packet.** That is packet 02. Author the walkthrough; do not execute it.
- **No `ADR-0076` or `ADR-0058` citation in user-facing prose.** Per memory `feedback_no_adr_in_docs`, the walkthrough body explains what the operator does in plain English. Cross-reference ADRs in the "Cross references" section at the foot of the doc only.

**Key Files:**
- `catalogs/modules.json` — add `cache-redis` row.
- `catalogs/grid-health.json` — add three Redis-instance rows; update module state for `cache-redis`.
- `catalogs/contracts.json` — conditional Redis-backing row (verify schema; skip if not yet supported, document in PR body).
- `infrastructure/reference/tech-stack.md` — Redis row update.
- `infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md` — new file (full walkthrough body per the template above).
- `initiatives/active-initiatives.md` — new entry.
- `CHANGELOG.md` (repo root) — entry under current in-progress version.

**Contracts:**

This packet does not author or modify any contracts. Catalog metadata and human-facing infrastructure documentation only.
