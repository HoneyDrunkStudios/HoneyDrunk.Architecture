---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Data
labels: ["feature", "tier-2", "core", "adr-0042", "wave-3"]
dependencies: ["work-item:02"]
adrs: ["ADR-0042"]
wave: 3
initiative: adr-0042-idempotency
node: honeydrunk-data
---

# Implement the default Cosmos-backed IIdempotencyStore

## Summary
Implement the default Cosmos-backed `IIdempotencyStore` from ADR-0042 D2 — a small Cosmos container, partition key = consumer-group, key-value of `IdempotencyKey → (FirstSeenAt, Outcome)` with Cosmos native TTL — plus an InMemory `IIdempotencyStore` for unit/in-process tests and DI registration extensions.

## Context
ADR-0042 D2 says dedup state "lives in `HoneyDrunk.Data` backing per consumer's choice (a small Cosmos container, Redis-class cache, or a Postgres table is acceptable)" and names a default Cosmos-backed implementation (small Cosmos container, partition key = consumer-group). The `IIdempotencyStore` contract itself is shipped by packet 02 in `HoneyDrunk.Kernel.Abstractions`. This packet implements the default Cosmos backing and an InMemory backing.

> **Package names — pinned.** The ADR's prose floats the name `HoneyDrunk.Kernel.Idempotency.Cosmos`, but that crosses the one-repo-per-Node naming convention (invariant 11): a backing that ships out of the `HoneyDrunk.Data` repo carries a `HoneyDrunk.Data.*` name. The packages are therefore **`HoneyDrunk.Data.Idempotency.Cosmos`** and **`HoneyDrunk.Data.Idempotency.InMemory`** — a new provider package family in the `HoneyDrunk.Data` repo, consistent with the existing `HoneyDrunk.Data.*` provider naming (`HoneyDrunk.Data.SqlServer`, `HoneyDrunk.Data.Outbox`, etc.). The contract is still Kernel's; the *backing* is a Data provider, exactly the abstraction/runtime split invariant 3 describes. Register both packages under `honeydrunk-data` in the catalogs. There is no A/B choice — use these names.

`HoneyDrunk.Data` is a live Node at v0.3.0 (per the Grid v0.4 Stabilization tracker) with the package family `HoneyDrunk.Data.Abstractions`, `HoneyDrunk.Data`, `HoneyDrunk.Data.EntityFramework`, `HoneyDrunk.Data.SqlServer`, `HoneyDrunk.Data.Outbox`, `HoneyDrunk.Data.Outbox.Dispatcher`, `HoneyDrunk.Data.Migrations`, `HoneyDrunk.Data.Testing`. This packet adds new provider package(s); per invariant 27 it bumps the whole `HoneyDrunk.Data` solution to a new minor version. Confirm `HoneyDrunk.Data`'s current version at execution time and bump to the next minor.

ADR-0042 D4 sets the TTL: 7 days standard, 30 days for billing/audit consumer-groups, configured per consumer-group at registration — the store does not hardcode it. Cosmos native container TTL plus per-item TTL override is the natural mechanism: set the container's default TTL and override per item when a consumer-group registers a longer window.

This packet creates new .NET projects — they need `CHANGELOG.md` and `README.md` from the first commit (invariant 12).

> **Unpark trigger for ADR-0047 packet 12.** ADR-0047 parks an `IIdempotencyStore` Cosmos contract-test packet (its packet 12) "until ADR-0042 is Accepted and the Cosmos backing exists." This packet 03 makes that contract-test target **buildable** — it ships the `HoneyDrunk.Data.Idempotency.Cosmos` backing package. The unpark trigger for ADR-0047 packet 12 is therefore "ADR-0042 Accepted (packet 00) **+** the Cosmos backing package exists (this packet, 03 merged)" — it is **not** "the contract test is written." Writing the contract test is ADR-0047 packet 12's own job; this packet only delivers the package it tests against.

## Scope
- New project `HoneyDrunk.Data.Idempotency.Cosmos` implementing `IIdempotencyStore` over an Azure Cosmos DB container.
- New project `HoneyDrunk.Data.Idempotency.InMemory` implementing `IIdempotencyStore` in-memory for unit and in-process integration tests (invariant 15 — tests use InMemory providers, never external services).
- DI registration extensions (`AddCosmosIdempotencyStore`, `AddInMemoryIdempotencyStore`) consistent with the repo's existing `Add*` extension convention.
- Unit tests covering claim/read/complete semantics, lease expiry, the already-completed fast path, and TTL behaviour (against the InMemory store and a Cosmos emulator or a Testcontainers/Cosmos-emulator integration project if the repo's test tiers support it).
- `CHANGELOG.md` + `README.md` for each new project; per-package CHANGELOG for changed existing packages only; repo-level `CHANGELOG.md` new version entry.

## Proposed Implementation
1. **`HoneyDrunk.Data.Idempotency.Cosmos`** — `CosmosIdempotencyStore : IIdempotencyStore`:
   - Backed by a Cosmos container; **partition key = consumer-group** (ADR-0042 D2). The store instance is constructed bound to one consumer-group; that value is the partition key for all its items.
   - Item shape: `id` = the `IdempotencyKey` value; `consumerGroup` = partition key; `firstSeenAt`; `state` (`Claimed` / `Completed`); `leaseExpiresAt`; `outcome` (the serialized `IdempotencyOutcome`, present only when `Completed`); `ttl` (Cosmos native TTL in seconds).
   - `TryClaim(key, ttl)` — attempt to create the item in `Claimed` state with an optimistic-concurrency guard (Cosmos `CreateItem` with conflict handling, or an `ETag`-guarded upsert). If the item already exists and is `Claimed` and the lease has not expired → return a claim indicating "already claimed, not yet completed" so the consumer defers. If it exists and is `Completed` → return the completed claim with its outcome. If it exists and is `Claimed` but the lease expired → take over the lease.
   - `Read(key)` — point-read by `id` within the consumer-group partition; return `null` if absent.
   - `Complete(claim, outcome)` — `ETag`-guarded update flipping `state` to `Completed` and writing the `outcome`.
   - TTL: set the per-item `ttl` field from the `TimeSpan` passed to `TryClaim` (D4: 7 days standard, 30 days billing/audit — the *caller* supplies it; the store does not hardcode). The container's default TTL should be enabled so items expire.
   - Cosmos credentials/connection resolve via Vault per invariant 9 — the store takes the connection from configuration injected at composition; it does not read a connection string from environment directly. Match the repo's existing pattern for how `HoneyDrunk.Data.SqlServer` gets its connection.
2. **`HoneyDrunk.Data.Idempotency.InMemory`** — `InMemoryIdempotencyStore : IIdempotencyStore` backed by a `ConcurrentDictionary` keyed by `(consumerGroup, IdempotencyKey)`, with lease/TTL honoured against an injected `TimeProvider` (so tests can advance time without `Thread.Sleep` — invariant 51). This is what packet 07's canary and every consumer's unit tests run against.
3. **DI extensions** — `AddCosmosIdempotencyStore(consumerGroup, ttl, ...)` and `AddInMemoryIdempotencyStore(consumerGroup, ttl)` on `IServiceCollection`, registering a consumer-group-bound `IIdempotencyStore`.
4. **Tests** — `*.Tests.Unit` covering: `TryClaim` on a fresh key returns a claimable claim; a second `TryClaim` on the same key+group while `Claimed` returns the defer signal; `TryClaim` after `Complete` returns the completed outcome without re-claiming; lease expiry allows re-claim; `Complete` is `ETag`/state guarded. If the repo has Tier 2b container-backed integration tests (per ADR-0047), add a Cosmos-emulator-backed integration test for `CosmosIdempotencyStore`; otherwise the Cosmos store is exercised by the canary in packet 07 and an integration follow-up.
5. **Versioning** — bump every non-test `.csproj` in the `HoneyDrunk.Data` solution to the next minor version in one commit (invariant 27). New projects ship with `CHANGELOG.md` + `README.md`. Existing packages that did not functionally change get the alignment bump but no per-package CHANGELOG noise (invariant 12/27). Repo-level `CHANGELOG.md` gets a new version entry.

## Affected Files
- `HoneyDrunk.Data.Idempotency.Cosmos/` — new project: `CosmosIdempotencyStore`, DI extension, `.csproj`, `CHANGELOG.md`, `README.md`.
- `HoneyDrunk.Data.Idempotency.InMemory/` — new project: `InMemoryIdempotencyStore`, DI extension, `.csproj`, `CHANGELOG.md`, `README.md`.
- `HoneyDrunk.Data.Idempotency.Cosmos.Tests.Unit/` and `HoneyDrunk.Data.Idempotency.InMemory.Tests.Unit/` (or the repo's test-project convention) — unit tests.
- The `HoneyDrunk.Data` `.slnx` — register the new projects.
- Every non-test `.csproj` in the solution — version bump.
- Repo-level `CHANGELOG.md`.

## NuGet Dependencies
- **`HoneyDrunk.Data.Idempotency.Cosmos`** (new project):
  - `HoneyDrunk.Kernel.Abstractions` — version `0.8.0` (provides `IIdempotencyStore`, `IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome` — shipped by packet 02).
  - `Microsoft.Azure.Cosmos` — the Cosmos SDK.
  - `Microsoft.Extensions.DependencyInjection.Abstractions` and `Microsoft.Extensions.Options` — for the `Add*` extension and options binding.
  - `HoneyDrunk.Standards` — required on every new .NET project (`PrivateAssets: all`).
- **`HoneyDrunk.Data.Idempotency.InMemory`** (new project):
  - `HoneyDrunk.Kernel.Abstractions` — version `0.8.0`.
  - `Microsoft.Extensions.DependencyInjection.Abstractions`.
  - `HoneyDrunk.Standards` (`PrivateAssets: all`).
- **Test projects** — the repo's existing unit-test stack (per ADR-0047: xUnit v2 + NSubstitute + AwesomeAssertions + coverlet). If a Cosmos-emulator integration test is added, `Testcontainers` per the repo's Tier 2b convention. `HoneyDrunk.Standards` on each (`PrivateAssets: all`).

## Boundary Check
- [x] The dedup-store *backing* is data-access infrastructure. Routing rule "repository, unit of work, EF Core, ... data access → HoneyDrunk.Data" maps the implementation here. ADR-0042 D2 explicitly says the backing "lives in `HoneyDrunk.Data`".
- [x] The `IIdempotencyStore` *contract* stays in `HoneyDrunk.Kernel.Abstractions` (packet 02) — this packet only implements it. Invariant 3: a provider package depends on the contract package, consumes only the exported interface.
- [x] No new cross-Node runtime edge — `HoneyDrunk.Data` already consumes `HoneyDrunk.Kernel.Abstractions`.

## Acceptance Criteria
- [ ] `CosmosIdempotencyStore` implements `IIdempotencyStore` with Cosmos partition key = consumer-group
- [ ] `TryClaim` creates a `Claimed` item with optimistic concurrency; a concurrent second claim on the same key+group while `Claimed` returns a defer signal, not a second claim
- [ ] `TryClaim` after `Complete` returns the recorded `IdempotencyOutcome` without re-claiming (the dedup fast path)
- [ ] An expired lease allows a subsequent `TryClaim` to take over
- [ ] `Complete` is `ETag`/state-guarded so a stale claim cannot overwrite a completed item
- [ ] Per-item Cosmos TTL is set from the `TimeSpan` passed to `TryClaim` — the store does not hardcode 7 or 30 days (ADR-0042 D4: caller supplies it per consumer-group)
- [ ] Cosmos connection resolves from injected configuration, not a directly-read environment variable (invariant 9)
- [ ] `InMemoryIdempotencyStore` implements `IIdempotencyStore` with the same semantics, honouring lease/TTL against an injected `TimeProvider`
- [ ] `AddCosmosIdempotencyStore` and `AddInMemoryIdempotencyStore` DI extensions register a consumer-group-bound `IIdempotencyStore`
- [ ] Unit tests cover claim/read/complete, defer-on-claimed, completed-fast-path, lease expiry, and TTL; no `Thread.Sleep` in test code (invariant 51)
- [ ] Both new projects ship `CHANGELOG.md` and `README.md` from the first commit (invariant 12); `README.md` documents install + public API
- [ ] Every non-test `.csproj` in the `HoneyDrunk.Data` solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry; per-package CHANGELOGs updated only for packages with functional changes (the two new packages); no alignment-bump noise on unchanged packages
- [ ] The `pr-core.yml` tier-1 gate passes
- [ ] The packages are named `HoneyDrunk.Data.Idempotency.Cosmos` and `HoneyDrunk.Data.Idempotency.InMemory` and registered under `honeydrunk-data` in the catalogs

## Human Prerequisites
- [ ] Provision an Azure Cosmos DB account for dedup state per environment (`dev`, `stg`, `prod`) when the first consumer-group goes live — ADR-0042 Operational Consequences: "a new Azure resource per environment per consumer-group ... cost is minor (single-digit dollars/month)." Use the cheapest viable tier (serverless Cosmos is the natural fit for low-volume dedup state — pay-per-request, scales to near-zero idle cost). Follow the Grid's portal-walkthrough convention; cross-link to the infrastructure walkthrough doc if one exists. This is a deploy-time action — the code work in this packet does not require the live account (tests run against InMemory / the Cosmos emulator).
- [ ] Seed the Cosmos connection/credentials into the relevant Node Key Vault(s) so `ISecretStore` can resolve them at composition time — the consumer Nodes (Notify, Communications, Audit) each compose their own store binding; the connection is a per-environment secret.
- [ ] Grant the consuming Container Apps' Managed Identities the Cosmos data-plane RBAC role on the dedup account.

## Referenced ADR Decisions
**ADR-0042 D2 — Dedup state, per consumer-group, durable Tier 1.** Lives in `HoneyDrunk.Data` backing; the default is a small Cosmos container, partition key = consumer-group — shipped here as `HoneyDrunk.Data.Idempotency.Cosmos`. Alternative backings (Redis-class, Postgres) are pluggable; this packet ships the Cosmos default and an InMemory test backing.

**ADR-0042 D4 — TTL.** 7 days standard, 30 days billing/audit. TTLs are configured per consumer-group at registration, not per message. The Kernel's default is 7 days; consumers override. The store honours whatever `TimeSpan` the caller passes to `TryClaim`.

**ADR-0042 Operational Consequences.** "The default Cosmos dedup container is a new Azure resource per environment per consumer-group. At Grid scale this is a small number; cost is minor (single-digit dollars/month in dev/staging/prod combined)." "The `IdempotentMessageHandler<T>` base introduces a small latency penalty per message (one extra round-trip to the dedup store). At Cosmos's single-digit-ms latency, this is acceptable."

## Constraints
- **Invariant 3 — provider packages depend on the contract package, consume only exported interfaces.** `CosmosIdempotencyStore` depends on `HoneyDrunk.Kernel.Abstractions` for `IIdempotencyStore`; it does not reach into Kernel internals.
- **Invariant 9 — Vault is the only source of secrets.** The Cosmos connection is resolved from injected configuration (sourced from `ISecretStore`), never read directly from an environment variable or the Cosmos SDK's own config.
- **Invariant 15 — unit/in-process tests never depend on external services.** Hence the InMemory store. Cosmos-emulator-backed tests, if added, are the Tier 2b container exception per ADR-0047 D4.
- **Invariant 27 — one version across the solution.** Bump every non-test `.csproj` in `HoneyDrunk.Data` together.
- **Invariant 12 — new projects ship `CHANGELOG.md` + `README.md` from the first commit; per-package CHANGELOGs only for changed packages.**
- **Invariant 51 — no `Thread.Sleep` in test code.** Lease/TTL tests advance an injected `TimeProvider`.
- **Records drop the `I`; interfaces keep it** — `IdempotencyKey` etc. are records consumed as-is from Kernel.

## Labels
`feature`, `tier-2`, `core`, `adr-0042`, `wave-3`

## Agent Handoff

**Objective:** Implement the default Cosmos-backed `IIdempotencyStore` and an InMemory test backing in `HoneyDrunk.Data`.

**Target:** `HoneyDrunk.Data`, branch from `main`.

**Context:**
- Goal: Give every async consumer a durable, per-consumer-group dedup store and a test double.
- Feature: ADR-0042 Idempotency Contract rollout, Wave 3 (parallel with packet 04).
- ADRs: ADR-0042 D2/D4 (primary), ADR-0047 (test tiers), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `HoneyDrunk.Kernel.Abstractions` `0.8.0` must publish `IIdempotencyStore`, `IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome` before this packet compiles.

**Constraints:**
- Package names are pinned: `HoneyDrunk.Data.Idempotency.Cosmos` and `HoneyDrunk.Data.Idempotency.InMemory`; register both under `honeydrunk-data`.
- Cosmos connection via `ISecretStore`/injected config, never a raw env read (invariant 9).
- InMemory store for unit tests; lease/TTL against an injected `TimeProvider`, no `Thread.Sleep`.
- Bump the whole solution to one new minor version (invariant 27). New projects get `CHANGELOG.md` + `README.md`.

**Key Files:**
- `HoneyDrunk.Data.Idempotency.Cosmos/` and `HoneyDrunk.Data.Idempotency.InMemory/` — new projects.
- The `.slnx`, every non-test `.csproj`, repo-level `CHANGELOG.md`.

**Contracts:**
- Implements `IIdempotencyStore` (from `HoneyDrunk.Kernel.Abstractions` `0.8.0`) — `TryClaim` / `Read` / `Complete`. No contract change; implementation only.
