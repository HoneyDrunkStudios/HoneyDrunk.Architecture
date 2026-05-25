---
name: Infrastructure Provisioning
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "infrastructure", "cache", "human-only", "adr-0076", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0076", "ADR-0053", "ADR-0005"]
accepts: ADR-0076
wave: 1
initiative: adr-0076-cache-backing-redis
node: honeydrunk-cache
---

# Provision `dev` Azure Cache for Redis Basic C0 instance (`redis-hd-dev`) — human-only

## Summary
Execute `infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md` (authored in packet 01) for the `dev` environment. Create the `redis-hd-dev` Basic C0 instance (~$16/mo, 250 MB, single instance, no HA, no managed-identity auth — uses access keys per Basic-tier limitation). Set eviction policy `allkeys-lru`. Verify TLS-only access, non-SSL port disabled, Redis modules disabled, persistence disabled. **Do NOT seed the connection string into a Vault as part of this packet** — Cache has no Vault per invariant 17, and the first-consumer Vault target (Notify Cloud's `kv-hd-notify-cloud-dev` or Communications's `kv-hd-comms-dev`) is not yet known. The connection-string Vault seeding lands in the first consumer composition packet, not here. The operator notes the connection-string value in a secure local note in the meantime.

`Actor=Human` — Azure portal work, no agent path.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (tracking issue; the substantive work is in the Azure subscription, not in the repo).

## Motivation

ADR-0076 D2 commits Basic C0 as the dev-environment tier (~$16/mo, sufficient for single-developer scale; no HA needed because dev is single-replica anyway). The forcing function is packet 03's smoke-verification step: a live Redis instance against which the operator can confirm `RedisCacheStore<T>` round-trips a real value end-to-end before the package ships. Unit tests run against an InMemory `IConnectionMultiplexer` fake and pass without a live instance — but the smoke verification needs a real Redis.

Per the user's standing preferences (`feedback_provision_when_needed`, `feedback_default_cheapest_azure_tier`):
- Provision when first needed (the smoke verification is the trigger).
- Default cheapest viable tier — Basic C0 covers dev workload without HA cost.

Per ADR-0053, staging and prod environments are still in flight; this packet provisions dev only.

## Proposed Work (human-executed, Azure Portal)

Execute the walkthrough authored in packet 01 (`infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md`) for `{env}=dev`:

1. **Pre-create cost confirmation.** Confirm the Review + create blade shows ~$16/mo for Basic C0. If it shows anything materially higher (e.g., $80+ which would indicate Standard tier was picked, or $300+ which would indicate Premium), STOP and re-select the tier.

2. **Basics blade:**
   - Subscription: target subscription.
   - Resource group: `rg-hd-dev` or the equivalent dev RG per the broader Grid convention.
   - DNS name: `redis-hd-dev`.
   - Region: `East US` (or whatever region the dev Container Apps environment lives in — colocate for latency).
   - Cache SKU: **Basic C0**.

3. **Networking blade:**
   - Connectivity: **Public Endpoint** (Basic tier limitation; VNet integration not available on Basic).
   - Minimum TLS version: **1.2**.
   - Non-SSL port: **Disabled**.

4. **Advanced blade:**
   - Access keys: **Enabled** (Basic tier does not support managed identity — access keys are the only path).
   - Microsoft Entra Authentication: Not available on Basic — skip.
   - Eviction policy: **allkeys-lru** (confirm or set per ADR-0076 D4).
   - Cluster: Disabled (not available on Basic).
   - Redis modules: **None enabled**. Do NOT enable RediSearch, RedisJSON, RedisTimeSeries, RedisGraph, or RedisBloom.
   - Persistence: Disabled.

5. **Tags blade:** Add `env=dev`, `node=honeydrunk-cache`, `purpose=cache-backing`.

6. **Review + create:** Confirm cost, click Create. Provisioning takes ~15-20 minutes.

7. **Post-create verification:**
   - Verify Properties show Eviction Policy `allkeys-lru`.
   - Verify Non-SSL port `Disabled`, Minimum TLS `1.2`.
   - Open Access keys blade; copy the Primary connection string (the full string ending in `,ssl=True,abortConnect=False`) into a secure local note. Do NOT paste it into a config file, commit it, screenshot it, or print it to a terminal session that may be captured by clipboard managers / scrollback.

8. **Smoke verification (manual, optional — at the operator's discretion):** Using `redis-cli` or the Azure Portal's Console, run `PING` and verify `PONG`; run `SET test:hello world` then `GET test:hello` and verify the value round-trips. The smoke verification is OPTIONAL — its purpose is operator confidence that the instance is reachable; packet 03's automated smoke step covers the same ground more rigorously.

9. **Update `catalogs/grid-health.json`:** Flip the `redis-hd-dev` row's `state` from `not-provisioned` to `provisioned`. Add the actual resource ID and provisioning date to the row's `notes` field. This is a small repo edit committed alongside this packet's tracking issue close.

## Connection-string handling — deferred to consumer composition

**Do NOT seed the Redis connection string into any Vault as part of this packet.** Per invariant 17, `HoneyDrunk.Cache` has no Vault (it is a library Node). The connection string belongs in the **first consumer Node's Vault** when that consumer composes the Redis backing — either `kv-hd-notify-cloud-dev` (per ADR-0027 multi-replica composition, when that packet runs) or `kv-hd-comms-dev` (per ADR-0019 preference cache composition).

The operator holds the connection-string value in a secure local note (1Password, macOS Keychain, Windows Credential Manager, or equivalent) for the interim period between this packet's completion and the first consumer composition packet's execution. At the time the first consumer composition packet runs, the operator:

1. Opens the consumer Node's Vault in the Azure Portal.
2. Creates a secret named per the consumer Node's overview convention (likely `redis-connection-string` or similar — defer to that Node's documentation).
3. Pastes the connection string from the secure local note.
4. Clears the secure local note (the secret now lives where it belongs).

This avoids creating a transient Cache-owned Vault that would violate invariant 17. The cost is one extra step at the first consumer composition; the benefit is invariant-correctness throughout.

If the operator strongly prefers to seed the secret into a Vault *now* rather than holding it in a local note, the only invariant-correct option is to create the consumer Node's Vault now (if it doesn't already exist) and seed the secret there. **Do NOT create a `kv-hd-cache-{env}` Vault under any circumstances** — invariant 17 forbids it.

## Affected Files

- `catalogs/grid-health.json` — flip the `redis-hd-dev` row's `state` from `not-provisioned` to `provisioned`; add resource ID and provisioning date to `notes`.
- The Azure subscription — the actual `redis-hd-dev` Basic C0 instance (not a repo artifact).
- Repo-level `CHANGELOG.md` — entry under the current in-progress version section noting the dev Redis instance was provisioned.

## NuGet Dependencies

None. This packet has no .NET project.

## Boundary Check

- [x] The `grid-health.json` flip lives in `HoneyDrunk.Architecture` — correct home for infra catalog metadata.
- [x] No code change in any repo.
- [x] Azure resource lands in the Azure subscription (vendor surface, not a Node).
- [x] **No `kv-hd-cache-{env}` Vault created.** Per invariant 17. Cache has no Vault. The walkthrough's consumer-Vault routing is honored.
- [x] No connection-string Vault seeding in this packet — deferred to the first consumer composition packet per the rationale above.
- [x] No staging or prod provisioning — `dev` only (per ADR-0053 staging/prod are in flight).

## Acceptance Criteria

- [ ] `redis-hd-dev` exists in the Azure subscription, Basic C0 tier, ~$16/mo, in the matching dev resource group
- [ ] Region matches the dev Container Apps environment's region (colocated for latency)
- [ ] Minimum TLS version is `1.2`, Non-SSL port is `Disabled`
- [ ] Eviction Policy is `allkeys-lru` (per ADR-0076 D4)
- [ ] Cluster mode is `Disabled` (Basic tier limitation; matches default)
- [ ] Redis modules are NOT enabled — verify the Advanced settings show no modules active (per ADR-0076 D3)
- [ ] Persistence is `Disabled` (per ADR-0076 D3)
- [ ] Tags applied: `env=dev`, `node=honeydrunk-cache`, `purpose=cache-backing`
- [ ] Access keys (Primary connection string) noted by the operator in a secure local mechanism (1Password / Keychain / Credential Manager / equivalent) — NOT in repo, NOT in CHANGELOG, NOT in a config file, NOT in a screenshot (invariant 8)
- [ ] **`catalogs/grid-health.json` `redis-hd-dev` row flipped to `state: provisioned`** with the actual resource ID and provisioning date added to the `notes` field. Connection string is NOT written to the row — only operational metadata
- [ ] Repo-level `CHANGELOG.md` has an entry under the current in-progress version section noting that the dev Redis instance was provisioned
- [ ] **No `kv-hd-cache-{env}` Key Vault created** (per invariant 17 — Cache has no Vault)
- [ ] **No connection-string secret written to any Vault as part of this packet** — connection-string Vault seeding is deferred to the first consumer composition packet against the consumer Node's own Vault

## Human Prerequisites

This entire packet is `Actor=Human`. Specifically:

- [ ] Packet 01 of this initiative complete — `infrastructure/walkthroughs/azure-cache-for-redis-provisioning.md` exists in the Architecture repo; the operator follows it during portal work.
- [ ] Azure Portal access to the subscription with rights to create Azure Cache for Redis resources in the `rg-hd-dev` resource group.
- [ ] The dev resource group (`rg-hd-dev` or equivalent) exists.
- [ ] Acceptance of the ~$16/mo Azure charge for the Basic C0 instance.
- [ ] Secure local secret-storage mechanism (1Password, macOS Keychain, Windows Credential Manager, or equivalent) for the interim holding of the Primary connection string until the first consumer composition packet seeds it into the consumer Node's Vault.
- [ ] **Decision:** Whether to defer connection-string Vault seeding to the first consumer composition packet (recommended — invariant-correct, one extra step at composition time) OR to seed into an already-existing consumer Vault now (if `kv-hd-notify-cloud-dev` or `kv-hd-comms-dev` already exists at this packet's execution time). Document the decision in the PR body. **Do NOT create a `kv-hd-cache-{env}` Vault under any circumstances** — invariant 17 forbids it.

## Referenced ADR Decisions

**ADR-0076 D1 — Azure Cache for Redis as default distributed-cache backing:** Per-environment instance `redis-hd-{env}`. Same region as the Container Apps environment. Access-key auth on Basic tier (managed identity not available; falls back to access keys per ADR-0005).

**ADR-0076 D2 — Per-environment sizing rubric:** Basic C0 for dev (~$16/mo, 250 MB, 1 instance, no HA). Resists over-provisioning. Standard tier is the prod baseline, not the dev tier.

**ADR-0076 D3 — Redis-protocol-only; no Azure-Redis modules:** Modules NOT enabled at provisioning time. Persistence NOT enabled (cache values are by-construction ephemeral).

**ADR-0076 D4 — Default eviction policy is `allkeys-lru`:** Verified or set during the Advanced settings step.

**ADR-0053 — Per-environment branching and release cadence:** Only `dev` is provisioned at this initiative's time. Staging and prod are gated on the environments standing up under ADR-0053.

**ADR-0005 — Vault and Key Vault naming + Vault-as-only-secret-source:** Connection-string Vault seeding happens at the first consumer composition packet's execution against the consumer Node's own Vault (`kv-hd-notify-cloud-dev` or `kv-hd-comms-dev`). The consumer Node resolves it via `ISecretStore` per invariant 9.

## Constraints

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The Primary connection string is a secret. It never enters the repo, the CHANGELOG, a config file, a screenshot, or a commit. The operator holds it in a secure local mechanism (1Password / Keychain / Credential Manager).

> **Invariant 9 — Vault is the only source of secrets.** When the first consumer Node composes the Redis backing, it resolves the connection string via `ISecretStore` — never from an environment variable holding the raw string or from a provider SDK default.

> **Invariant 17 — One Key Vault per deployable Node per environment.** Named `kv-hd-{service}-{env}` with Azure RBAC. **Library Nodes have no Vault.** `HoneyDrunk.Cache` is a library Node per ADR-0059 — **no `kv-hd-cache-{env}` Vault is created by this packet.** The connection string belongs in the consumer Node's Vault; if the consumer Vault does not yet exist, the operator holds the connection string in a secure local mechanism until the consumer composition packet seeds it.

> **Invariant 19 — Service names in Azure resource naming must be ≤ 13 characters.** `redis-hd-{env}` complies (the broader Grid convention for resource naming).

> **Invariant 21 — Applications must never pin to a specific secret version.** When the consumer Node resolves the Redis connection string, it resolves the latest version via `ISecretStore`. The operator does NOT pin to a specific version when seeding (the seed creates version 1; future rotations create version 2, 3, etc., and the consumer resolves "latest" by default).

- **Basic C0, not Standard or Premium.** The pre-create cost confirmation catches any tier-selection error. Standard tier is for staging/prod baseline. Premium NOT adopted per ADR-0076 D2 alternatives.
- **`allkeys-lru` eviction policy.** Per ADR-0076 D4.
- **Portal-only.** Per the user's standing preference for Azure Portal over CLI.
- **No Vault seeding in this packet.** Deferred to first consumer composition.
- **No staging or prod provisioning.** Per ADR-0053 — those environments are in flight.
- **No `## Unreleased` block in CHANGELOG.** Per memory `feedback_no_unreleased_commits`. Entry lands under the current in-progress dated version section.

## Dependencies

- `packet:01` — the provisioning walkthrough must exist for the operator to execute it.

## Labels

`feature`, `tier-2`, `infrastructure`, `cache`, `human-only`, `adr-0076`, `wave-1`

## Agent Handoff

This packet is `Actor=Human`. The human-executed steps are documented in the Proposed Work section above. After the operator completes the portal work and updates `catalogs/grid-health.json`, they close the tracking issue.

**Objective:** Provision the `dev` Azure Cache for Redis Basic C0 instance per the walkthrough authored in packet 01. Flip the `grid-health.json` row to `provisioned`. Hold the connection string in a secure local mechanism until the first consumer composition packet seeds it into the consumer Node's Vault.

**Target:** Tracked against `HoneyDrunk.Architecture`; the Azure work is human-executed in the Azure Portal. `Actor=Human` — `human-only` label set. The `grid-health.json` flip is a small repo edit committed alongside the issue close.

**Context:**
- Goal: Stand up the dev Redis instance so packet 03's smoke verification has a real backend to test against.
- Feature: ADR-0076 acceptance initiative, Wave 1, Packet 02.
- ADRs: ADR-0076 D1/D2/D3/D4 (the backing decision being executed), ADR-0053 (only dev — staging/prod are in flight), ADR-0005 (consumer-Vault seeding deferred to consumer composition).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — the walkthrough must exist.

**Constraints:**

- **Basic C0 for dev.** Not Standard, not Premium. Pre-create cost confirmation catches errors.
- **`allkeys-lru` eviction.** Verified or set during Advanced settings.
- **No modules, no persistence.** Per ADR-0076 D3.
- **No `kv-hd-cache-{env}` Vault.** Per invariant 17. Cache has no Vault.
- **No connection-string Vault seeding in this packet.** Operator holds in secure local mechanism until first consumer composition.
- **`grid-health.json` row flipped to `provisioned`** with resource ID + date in `notes`; connection string NEVER written to the row.
- **Dev only.** No staging or prod work.

**Key Files:**
- `catalogs/grid-health.json` — flip the `redis-hd-dev` row's `state` from `not-provisioned` to `provisioned`; add resource ID + date to `notes`.
- `CHANGELOG.md` (repo root) — entry under current in-progress version noting the dev Redis provisioning.

**Contracts:**

This packet does not author or modify any contracts. Azure resource provisioning + small repo edit.
