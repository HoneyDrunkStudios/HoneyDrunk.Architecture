---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0042", "wave-4"]
dependencies: ["work-item:04"]
adrs: ["ADR-0042"]
wave: 4
initiative: adr-0042-idempotency
node: honeydrunk-notify
---

# Roll out the idempotency envelope to HoneyDrunk.Notify async producers and consumers

## Summary
Amend `HoneyDrunk.Notify`'s async producers to attach an `IdempotencyKey` at the message-construction site and its async consumers to derive from `IdempotentMessageHandler<T>` (ADR-0042 D10 rollout). Where Notify has a natural deterministic input, use the `notify-send:<tenant>:<external-id>` deterministic-key form (ADR-0042 D5).

## Context
ADR-0042 D10 names `HoneyDrunk.Notify` as one of the two existing async producers amended in a rollout packet to emit the `IdempotencyKey`. ADR-0042 Context observes that "Notify's delivery pipeline tolerates duplicates by virtue of provider-side dedup (most ESPs reject duplicate `Message-ID`s)" — so Notify is not broken today, but it has no Grid-contract idempotency model, and once the contract is live every async producer must conform so the canary's mandatory-key check (flipped on by packet 07) does not poison-letter Notify's messages.

Scope note: ADR-0028 D2/D3 (Notify intake → Notify worker via `HoneyDrunk.Notify.Queue.*`, an Azure Storage Queue) is an **in-Node** queue, and ADR-0028's boundaries doc disclaims it as not-a-Transport-hop. ADR-0042's contract binds "every message published on the default Service Bus topic / queue." The executor must, at the start of this packet, **audit which of Notify's async hops are domain-event boundaries bound by ADR-0042**:
- Notify's *internal* intake→worker Storage Queue hop is in-Node commodity work (ADR-0028 use case #3). ADR-0042 D2's dedup-state concept still applies if a redelivered intake message could cause a tenant-visible double-send — and it could (a duplicate notification *is* a side effect a tenant cares about, per ADR-0042 D7's carve-out boundary test). So the intake→worker handler SHOULD adopt `IdempotentMessageHandler<T>` even though the hop is a Storage Queue, not Service Bus. The `IdempotencyKey` rides the message body/properties regardless of backing.
- Any Service-Bus-backed hop Notify produces or consumes (e.g. a future `BillingEvent` emit, or a cross-Node consume) is squarely bound by D1.
The executor should enumerate Notify's actual async hops in the PR description and state which adopt the contract and why.

`HoneyDrunk.Notify` is a live Node (Notify v0.2.0 released per the Notification Subsystem Launch tracker). This packet is the first (and only) packet on the `HoneyDrunk.Notify` solution in this initiative — per invariant 27 it bumps the whole solution to the next minor version.

## Scope
- Notify async **producers** — attach a `IdempotencyKey` to every domain-event message at the construction site (ADR-0042 D5: at construction, never at publish; reuse across retries). Use deterministic keys (`notify-send:<tenant>:<external-id>`) where a natural external id exists; UUID v4 otherwise.
- Notify async **consumers/handlers** — derive the relevant message handlers from `IdempotentMessageHandler<T>` (packet 04). Compose an `IIdempotencyStore` (the Cosmos store from packet 03, or InMemory for tests) bound to Notify's consumer-group, with the **standard 7-day TTL** (ADR-0042 D4 — Notify is not billing or audit).
- Publish through `IGridMessagePublisher` (packet 04) so retries never regenerate the key.
- Host composition wiring for the `IIdempotencyStore` and `IGridMessagePublisher`.
- Version bump across the `HoneyDrunk.Notify` solution; CHANGELOG/README updates.

## Proposed Implementation
1. **Audit** Notify's async hops; record in the PR which are ADR-0042 domain-event boundaries (see Context).
2. **Producers** — at each message-construction site, populate `IGridMessageEnvelope.IdempotencyKey`. For a send triggered by a request that carries a tenant + an external/client-supplied id, use the deterministic form `notify-send:<tenant>:<external-id>` (ADR-0042 D5/D1 — deterministic keys make replay observable). Where no natural deterministic input exists, `IdempotencyKey.NewRandom()`. The key must be generated **once** and persisted with the producer's local "I sent this" record if Notify keeps one (ADR-0042 D5: "persist the key in the producer's local state if the producer needs to know whether its own publish succeeded").
3. **Consumers** — change the relevant handler(s) to derive from `IdempotentMessageHandler<T>`; move the existing side-effecting logic into the `ProcessAsync` override; return an appropriate `IdempotencyOutcome`. The base handler does claim/dedup/complete. Any downstream message Notify emits from inside a handler derives its key via `envelope.IdempotencyKey.Derive(relationship)` — never a fresh key (ADR-0042 D3).
4. **Composition** — register an `IIdempotencyStore` for Notify's consumer-group with TTL 7 days, and an `IGridMessagePublisher`, in Notify's host DI. Default backing: the Cosmos store (`AddCosmosIdempotencyStore`) in deployed environments, InMemory in tests.
5. **Tests** — unit/integration tests asserting: a duplicate inbound message produces exactly one send; a producer retry re-emits the same key; a deterministic-input send produces the same key on replay. Use the InMemory `IIdempotencyStore`; no `Thread.Sleep` (invariant 51).
6. **Versioning** — bump every non-test `.csproj` in the `HoneyDrunk.Notify` solution to the next minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` new version entry; per-package CHANGELOGs only for packages with functional changes.

## Affected Files
- Notify producer/handler source files for the in-scope async hops.
- Notify host composition / DI registration.
- Every non-test `.csproj` in the solution — version bump.
- Repo-level `CHANGELOG.md`; per-package CHANGELOGs for changed packages.
- Notify test project(s) — new idempotency tests.

## NuGet Dependencies
- The relevant Notify runtime project(s) gain or update:
  - `HoneyDrunk.Kernel` — version `0.8.0` (provides `IdempotentMessageHandler<T>`, `IGridMessagePublisher`). If Notify already references `HoneyDrunk.Kernel`, update the version; otherwise add it.
  - `HoneyDrunk.Kernel.Abstractions` — `0.8.0` (transitively, or explicit if Notify references it directly today).
- Notify's **host/composition** project gains:
  - `HoneyDrunk.Data.Idempotency.Cosmos` — the version published by packet 03 (for deployed-environment composition).
- Notify's **test** project(s) gain:
  - `HoneyDrunk.Data.Idempotency.InMemory` — the version published by packet 03 (test-time `IIdempotencyStore`).
- `HoneyDrunk.Standards` is already on every Notify project; no change.
- Confirm exact current versions at execution time — packets 03 and 04 set them.

## Boundary Check
- [x] All code change is in `HoneyDrunk.Notify` — its own producers, consumers, and host composition. Routing rule "notification, email, SMS, ... notify, channel → HoneyDrunk.Notify" maps here.
- [x] No contract change — Notify consumes `IdempotentMessageHandler<T>` / `IGridMessagePublisher` / `IIdempotencyStore` as shipped by packets 02–04.
- [x] Preference/cadence/suppression decision logic is NOT touched — that is Communications' boundary (invariant 41). This packet only touches Notify's delivery-mechanics async hops.

## Acceptance Criteria
- [ ] The PR description enumerates Notify's async hops and states which adopt the ADR-0042 contract and why
- [ ] Every in-scope Notify async producer attaches an `IdempotencyKey` to the message envelope at the construction site, not at the publish site
- [ ] Deterministic keys (`notify-send:<tenant>:<external-id>`) are used where a natural external id exists; `IdempotencyKey.NewRandom()` otherwise
- [ ] A producer retry re-emits the same `IdempotencyKey` (verified — publish goes through `IGridMessagePublisher`)
- [ ] In-scope Notify consumers derive from `IdempotentMessageHandler<T>`; side-effecting logic moved into `ProcessAsync`
- [ ] A duplicate inbound message produces exactly one delivery side effect (unit/integration-tested)
- [ ] Notify's host composes an `IIdempotencyStore` for Notify's consumer-group with TTL = 7 days (ADR-0042 D4 standard — Notify is not billing/audit)
- [ ] Any downstream message Notify emits from a handler derives its key via `IdempotencyKey.Derive` — never a fresh key
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry; per-package CHANGELOGs updated only for packages with functional changes
- [ ] `README.md` updated if the public API surface or composition story changed
- [ ] Tests contain no `Thread.Sleep` (invariant 51)
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Publish the upstream NuGet packages before this packet can compile.** This packet's projects reference `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` `0.8.0` (packets 02 + 04) and `HoneyDrunk.Data.Idempotency.Cosmos` / `.InMemory` (packet 03). Those artifacts exist on the package feed only after a human pushes a git release tag in each repo — **agents never tag or publish.** Before this Wave-4 packet starts: (1) at the Wave 2→3 boundary, tag/release `HoneyDrunk.Kernel` `0.8.0` (carries `HoneyDrunk.Kernel.Abstractions` `0.8.0` from packet 02 and the runtime types from packet 04 — release once both have merged); (2) at the Wave 3→4 boundary, tag/release the `HoneyDrunk.Data` solution version that ships `HoneyDrunk.Data.Idempotency.Cosmos` / `.InMemory` (packet 03). Wave 4 cannot build against unpublished packages.
- [ ] The Cosmos dedup account (provisioned per packet 03's Human Prerequisites) must exist in each environment Notify deploys to before Notify's deployed composition can resolve the Cosmos `IIdempotencyStore`. Notify's consumer-group gets the 7-day-TTL container/configuration.
- [ ] The Cosmos connection secret must be seeded into `kv-hd-notify-{env}` so Notify's `ISecretStore` can resolve it (invariant 9).
- [ ] Notify's Container App / Function Managed Identity needs the Cosmos data-plane RBAC role on the dedup account.
- The code work in this packet does not require the live Cosmos account — tests run against the InMemory store. It does, however, require the upstream packages above to be published.

## Referenced ADR Decisions
**ADR-0042 D5 — Producer responsibilities.** Generate and attach the key at the message-construction site, never at the broker-publish site. Use deterministic keys when possible (`notify-send:<tenant>:<external-id>`). Persist the key in the producer's local state if it needs to know its own publish succeeded.

**ADR-0042 D3 — Consumer pattern + downstream-key derivation.** Consumers use `IdempotentMessageHandler<T>`; a downstream message's key is `SHA256(inbound:relationship)` of the inbound key.

**ADR-0042 D4 — TTL.** Standard 7 days. Notify is neither billing nor audit, so 7 days applies.

**ADR-0042 D7 — Carve-out boundary test.** "If a re-delivered message could cause a side effect a tenant or auditor would care about, it is a domain event and bound by this ADR." A duplicate notification is exactly such a side effect — Notify's send hops are in scope regardless of whether the backing is Service Bus or Storage Queue.

**ADR-0042 D10 — Rollout.** Notify is one of the two existing producers amended to emit the key. During the overall rollout, consumers tolerate keyless messages; the canary's mandatory check flips on (packet 07) after the rollout closes.

## Constraints
- **Invariant 41 — preference/cadence/suppression logic lives in Communications, not Notify.** This packet touches only Notify's delivery-mechanics async hops; do not move or add decision logic.
- **Invariant 9 — Vault is the only source of secrets.** The Cosmos connection resolves via `ISecretStore`.
- **Invariant 27 — one version across the solution.** Bump every non-test `.csproj` together.
- **Invariant 51 — no `Thread.Sleep` in test code.**
- **ADR-0042 D5 — the key is generated once.** Never regenerate on retry. Publish through `IGridMessagePublisher` so the retry loop reuses the key.

## Labels
`feature`, `tier-2`, `ops`, `adr-0042`, `wave-4`

## Agent Handoff

**Objective:** Make `HoneyDrunk.Notify`'s async producers emit an `IdempotencyKey` and its consumers derive from `IdempotentMessageHandler<T>`.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Bring Notify into conformance with the ADR-0042 idempotency contract before the canary's mandatory-key check flips on.
- Feature: ADR-0042 Idempotency Contract rollout, Wave 4 (parallel with packet 06 Communications).
- ADRs: ADR-0042 D3/D4/D5/D7/D10 (primary), ADR-0028 (Notify's queue is in-Node), ADR-0008.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:04` — `IdempotentMessageHandler<T>` and `IGridMessagePublisher` ship in `HoneyDrunk.Kernel` `0.8.0`.
- (Soft) `work-item:03` — the Cosmos `IIdempotencyStore` is needed for deployed composition and the InMemory store for tests; both ship together in packet 03. If packet 03's package versions are not yet available at execution time, flag and coordinate.

**Constraints:**
- Decision logic stays in Communications (invariant 41) — touch only Notify delivery hops.
- Key generated once at construction, reused on retry (D5); publish via `IGridMessagePublisher`.
- 7-day TTL (D4 standard).
- Bump the whole solution one minor version (invariant 27).

**Key Files:**
- Notify producer/handler source for the in-scope async hops; Notify host composition.
- Every non-test `.csproj`; repo-level `CHANGELOG.md`.

**Contracts:** None changed — Notify consumes `IdempotentMessageHandler<T>`, `IGridMessagePublisher`, `IIdempotencyStore` as shipped by packets 02–04.
