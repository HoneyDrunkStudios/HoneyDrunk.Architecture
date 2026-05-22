---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["feature", "tier-2", "ops", "adr-0042", "wave-4"]
dependencies: ["packet:04"]
adrs: ["ADR-0042"]
wave: 4
initiative: adr-0042-idempotency
node: honeydrunk-communications
---

# Roll out the idempotency envelope to HoneyDrunk.Communications async boundaries

## Summary
Give `HoneyDrunk.Communications` a documented idempotency model: amend its async producers to attach an `IdempotencyKey` at the message-construction site and its async consumers to derive from `IdempotentMessageHandler<T>` (ADR-0042 D10 rollout). Bridge in-process domain events to async correctly per ADR-0042 D8.

## Context
ADR-0042 Context calls out that "Communications has no documented idempotency model" — and names Communications as one of the two existing async producers amended in the rollout (D10). Communications is the orchestration layer above Notify (ADR-0013/0019): it resolves message intent, checks preferences and cadence, records a decision-log entry, then delegates to Notify.

Two ADR-0028 facts shape this packet's scope:
- **ADR-0028 D4** — the `ICommunicationOrchestrator` → `INotificationSender` hop is **in-process at v1** (Communications takes a first-class runtime dependency on `HoneyDrunk.Notify.Abstractions`). An in-process call is **not** an async broker boundary — ADR-0042 D8 exempts in-process events. So the Communications→Notify hop itself does NOT get the idempotency contract today.
- **ADR-0028 D7** — Communications' internal intent→preference→cadence→send pipeline is an **in-process MediatR-style fan-out** (ADR-0028 use case #7). Also exempt under ADR-0042 D8.

So what IS in scope? ADR-0042 D8 is precise: in-process events are exempt, **but** "consumers that bridge from in-process to async must attach an `IdempotencyKey` at the bridge point." The executor must audit Communications' actual async surface:
- Any **inbound async message** Communications consumes (a cross-Node command/event that arrives over Service Bus) — that consumer derives from `IdempotentMessageHandler<T>`.
- Any **outbound async message** Communications produces (e.g. if Communications publishes a domain event when it dispatches, or any future cross-Node emit) — that producer attaches an `IdempotencyKey` at construction.
- The **bridge point** — where Communications takes an in-process trigger and turns it into an async message — is where the key is attached (D8).
If, at audit time, Communications has **zero** async broker boundaries today (everything is in-process per ADR-0028 D4/D7), then this packet's substantive work is: (a) ensure the in-process→async bridge seam is correctly set up so that *when* the Communications→Notify split to Service Bus happens (ADR-0028 D4's named future), the key is attached at the bridge; (b) wire the `IGridMessagePublisher` / `IdempotentMessageHandler<T>` plumbing so it is composed and ready; (c) document Communications' idempotency model (closing the "no documented idempotency model" gap from the ADR Context). The executor must state in the PR which case Communications is in and scope the work accordingly — do not invent async hops that do not exist.

`HoneyDrunk.Communications` is a live Node (the Kernel-adoption tracker shows Communications#14 closed against it). Confirm the solution's current version at execution time. This packet is the only packet on the `HoneyDrunk.Communications` solution in this initiative — per invariant 27 it bumps the whole solution to the next minor version.

## Scope
- Audit Communications' async boundaries; record findings in the PR.
- For each real inbound async consumer — derive from `IdempotentMessageHandler<T>`.
- For each real outbound async producer (or the in-process→async bridge seam) — attach an `IdempotencyKey` at construction (D5/D8); publish via `IGridMessagePublisher`.
- Compose an `IIdempotencyStore` bound to Communications' consumer-group with the **standard 7-day TTL** (ADR-0042 D4 — Communications is not billing/audit).
- Document Communications' idempotency model (closing the ADR Context gap).
- Version bump across the `HoneyDrunk.Communications` solution; CHANGELOG/README updates.

## Proposed Implementation
1. **Audit** — enumerate Communications' async hops. State in the PR: (a) which hops are async broker boundaries bound by ADR-0042 D1; (b) which are in-process and exempt under D8; (c) where the in-process→async bridge point is (D8).
2. **Inbound async consumers** — derive each from `IdempotentMessageHandler<T>`; move side-effecting logic into `ProcessAsync`; return an `IdempotencyOutcome`.
3. **Outbound async producers / bridge** — attach `IGridMessageEnvelope.IdempotencyKey` at the message-construction site. ADR-0042 D8: at the in-process→async bridge, attach the key — derive it deterministically from a stable in-process identity where one exists (e.g. a message-intent id), `IdempotencyKey.NewRandom()` otherwise. Publish through `IGridMessagePublisher`.
4. **Decision-log interaction** — Communications records a decision-log entry per orchestrated send via `ICommunicationDecisionLog` (invariant 42). If a decision-log entry corresponds 1:1 with a send, its identity is a good deterministic input for the `IdempotencyKey` — but do not change the decision-log contract; only consume its identity. Note: the decision-log entry itself is an in-process write, not an async message, so it is not bound by ADR-0042.
5. **Composition** — register an `IIdempotencyStore` for Communications' consumer-group (TTL 7 days) and an `IGridMessagePublisher` in the host DI. Cosmos backing in deployed environments, InMemory in tests.
6. **Documentation** — add a section to Communications' README (or its boundaries/architecture doc) stating Communications' idempotency model: which boundaries carry keys, the TTL, the in-process exemption, the bridge rule. This closes the "no documented idempotency model" gap ADR-0042 Context flags.
7. **Tests** — duplicate inbound async message → exactly one orchestration side effect; a producer/bridge retry → same key. InMemory store; no `Thread.Sleep` (invariant 51).
8. **Versioning** — bump every non-test `.csproj` in the solution to the next minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` new version entry; per-package CHANGELOGs only for changed packages.

## Affected Files
- Communications producer/consumer source for the in-scope async hops (or the bridge seam).
- Communications host composition / DI registration.
- Communications `README.md` (or boundaries/architecture doc) — the idempotency-model section.
- Every non-test `.csproj` — version bump.
- Repo-level `CHANGELOG.md`; per-package CHANGELOGs for changed packages.
- Communications test project(s).

## NuGet Dependencies
- The relevant Communications runtime project(s) gain or update:
  - `HoneyDrunk.Kernel` — version `0.8.0` (`IdempotentMessageHandler<T>`, `IGridMessagePublisher`). Note: the Kernel-adoption initiative dropped Communications' *runtime* Kernel dependency where avoidable — but `IdempotentMessageHandler<T>` is a runtime base class, so the project(s) that host async handlers do need `HoneyDrunk.Kernel` at runtime. Confine the runtime reference to the host/handler project, not the `Abstractions` package.
  - `HoneyDrunk.Kernel.Abstractions` — `0.8.0` (`IGridMessageEnvelope`, `IIdempotencyStore`, `IdempotencyKey`).
- Communications' **host/composition** project gains `HoneyDrunk.Data.Idempotency.Cosmos` (version from packet 03).
- Communications' **test** project(s) gain `HoneyDrunk.Data.Idempotency.InMemory` (version from packet 03).
- `HoneyDrunk.Standards` is already on every project; no change.
- Confirm exact current versions at execution time.

## Boundary Check
- [x] All code change is in `HoneyDrunk.Communications` — its own async producers/consumers and host composition. Routing maps Communications-orchestration work here.
- [x] No contract change — Communications consumes the ADR-0042 contracts as shipped by packets 02–04.
- [x] Delivery mechanics stay in Notify (invariant 41) — this packet does not touch Notify; the Communications→Notify hop stays in-process per ADR-0028 D4 and is exempt under ADR-0042 D8.
- [x] `ICommunicationDecisionLog` / `IMessageIntent` / `ICadencePolicy` contracts are NOT modified — the decision-log shape canary (invariant 43) stays green.

## Acceptance Criteria
- [ ] The PR description enumerates Communications' async hops and classifies each as ADR-0042-bound, in-process-exempt, or the in-process→async bridge point
- [ ] Every in-scope inbound async consumer derives from `IdempotentMessageHandler<T>`; side-effecting logic moved into `ProcessAsync`
- [ ] Every in-scope outbound async producer (or the bridge seam) attaches an `IdempotencyKey` at the message-construction site (D5/D8)
- [ ] A producer/bridge retry re-emits the same `IdempotencyKey` (publish via `IGridMessagePublisher`)
- [ ] A duplicate inbound async message produces exactly one orchestration side effect (unit/integration-tested)
- [ ] Communications' host composes an `IIdempotencyStore` for its consumer-group with TTL = 7 days (ADR-0042 D4 standard)
- [ ] The Communications→Notify in-process hop is NOT given the contract (correctly exempt per ADR-0028 D4 / ADR-0042 D8) — and the PR says so explicitly
- [ ] `ICommunicationDecisionLog`, `IMessageIntent`/`MessageIntent`, `ICadencePolicy`, `IPreferenceStore` contracts are unchanged (invariant 43 canary stays green)
- [ ] Communications' README / architecture doc gains an idempotency-model section, closing the "no documented idempotency model" gap
- [ ] Every non-test `.csproj` is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry; per-package CHANGELOGs updated only for changed packages
- [ ] Tests contain no `Thread.Sleep` (invariant 51)
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Publish the upstream NuGet packages before this packet can compile.** This packet's projects reference `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` `0.8.0` (packets 02 + 04) and `HoneyDrunk.Data.Idempotency.Cosmos` / `.InMemory` (packet 03). Those artifacts exist on the package feed only after a human pushes a git release tag in each repo — **agents never tag or publish.** Before this Wave-4 packet starts: (1) at the Wave 2→3 boundary, tag/release `HoneyDrunk.Kernel` `0.8.0` (carries `HoneyDrunk.Kernel.Abstractions` `0.8.0` from packet 02 and the runtime types from packet 04 — release once both have merged); (2) at the Wave 3→4 boundary, tag/release the `HoneyDrunk.Data` solution version that ships `HoneyDrunk.Data.Idempotency.Cosmos` / `.InMemory` (packet 03). Wave 4 cannot build against unpublished packages.
- [ ] The Cosmos dedup account (provisioned per packet 03) must exist in each environment Communications deploys to before Communications' deployed composition resolves the Cosmos `IIdempotencyStore`. Communications' consumer-group gets a 7-day-TTL container/configuration.
- [ ] The Cosmos connection secret must be seeded into Communications' Key Vault so `ISecretStore` can resolve it (invariant 9). Note: ADR-0028 D4 says Notify Cloud composes Notify Cloud + Communications + Notify in the same Container App at v1 — if Communications shares Notify's host/Vault, the seeding is the same secret as packet 05's. The executor should confirm the deployment topology.
- [ ] The hosting Container App's Managed Identity needs the Cosmos data-plane RBAC role on the dedup account.
- The code work does not require the live account — tests run against the InMemory store.

## Referenced ADR Decisions
**ADR-0042 D8 — In-process events are exempt; the bridge attaches the key.** In-process events do not cross a broker and are not bound by the contract. But "consumers that bridge from in-process to async must attach an `IdempotencyKey` at the bridge point."

**ADR-0042 D5 — Producer responsibilities.** Key attached at the message-construction site, not the publish site; reused on retry.

**ADR-0042 D4 — TTL.** Standard 7 days; Communications is not billing/audit.

**ADR-0042 D10 — Rollout.** Communications is one of the two existing producers amended in the rollout.

**ADR-0028 D4 — Communications → Notify is in-process at v1.** Communications takes a first-class runtime dependency on `HoneyDrunk.Notify.Abstractions`; the call is in-process, not over a broker. The Service Bus split is a named future. So today the Communications→Notify hop is exempt under ADR-0042 D8; the bridge seam is set up so the key is attached when that split happens.

**ADR-0028 D7 — Communications' internal pipeline is in-process MediatR-style.** Intent→preference→cadence→send within Communications is in-process fan-out — exempt under ADR-0042 D8.

## Constraints
- **Invariant 41 — preference/cadence/suppression logic lives in Communications; delivery mechanics in Notify.** This packet does not touch Notify and does not move decision logic.
- **Invariant 42 — every orchestrated send records a decision-log entry.** Do not regress this; the decision-log entry may be a deterministic-key input but its contract is unchanged.
- **Invariant 43 — Communications hot-path contract-shape canary.** Do not change `ICommunicationOrchestrator`, `IMessageIntent`/`MessageIntent`, `IPreferenceStore`, `ICadencePolicy` shapes.
- **Invariant 9 — Vault is the only source of secrets.**
- **Invariant 27 — one version across the solution.**
- **Invariant 51 — no `Thread.Sleep` in test code.**
- **Do not invent async hops.** If Communications is fully in-process today (per ADR-0028 D4/D7), scope the work to the bridge seam + composition + documentation, and say so in the PR.

## Labels
`feature`, `tier-2`, `ops`, `adr-0042`, `wave-4`

## Agent Handoff

**Objective:** Give `HoneyDrunk.Communications` a documented idempotency model and bring its real async boundaries onto the ADR-0042 contract.

**Target:** `HoneyDrunk.Communications`, branch from `main`.

**Context:**
- Goal: Close the "Communications has no documented idempotency model" gap and conform its async surface before the canary's mandatory-key check flips on.
- Feature: ADR-0042 Idempotency Contract rollout, Wave 4 (parallel with packet 05 Notify).
- ADRs: ADR-0042 D4/D5/D8/D10 (primary), ADR-0028 D4/D7 (Communications is in-process at v1), ADR-0008.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:04` — `IdempotentMessageHandler<T>`, `IGridMessagePublisher` in `HoneyDrunk.Kernel` `0.8.0`.
- (Soft) `packet:03` — Cosmos `IIdempotencyStore` for deployed composition, InMemory for tests.

**Constraints:**
- Audit the real async surface; do not invent hops. The Communications→Notify hop is in-process and exempt (ADR-0028 D4 / ADR-0042 D8).
- Decision logic stays in Communications, delivery in Notify (invariant 41); do not touch the hot-path contract shapes (invariant 43).
- 7-day TTL (D4); bump the whole solution one minor version (invariant 27).

**Key Files:**
- Communications async producer/consumer source (or the bridge seam); host composition.
- Communications README / architecture doc — idempotency-model section.
- Every non-test `.csproj`; repo-level `CHANGELOG.md`.

**Contracts:** None changed — Communications consumes the ADR-0042 contracts from packets 02–04; its own hot-path contracts are untouched.
