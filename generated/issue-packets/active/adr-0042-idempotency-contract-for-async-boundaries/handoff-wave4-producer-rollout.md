# Handoff — Wave 4: Producer Rollout

**Initiative:** `adr-0042-idempotency-contract-for-async-boundaries`
**Wave transition:** Wave 3 (backing + runtime) → Wave 4 (producer rollout)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Waves 2–3 landed

- **Packet 02** — `HoneyDrunk.Kernel` `0.8.0`. `HoneyDrunk.Kernel.Abstractions` ships `IGridMessageEnvelope`, `IPulseSignalEnvelope`, `IIdempotencyStore`, `IdempotencyKey` (with `NewRandom()` and `Derive(relationship)`), `IdempotencyClaim`, `IdempotencyOutcome`.
- **Packet 03** — `HoneyDrunk.Data` ships the default Cosmos-backed `IIdempotencyStore` and an InMemory test store, with `Add*` DI extensions. The packages are `HoneyDrunk.Data.Idempotency.Cosmos` and `HoneyDrunk.Data.Idempotency.InMemory` (pinned names — registered under `honeydrunk-data`).
- **Packet 04** — `HoneyDrunk.Kernel` runtime ships `IdempotentMessageHandler<T>` (claim → process → complete) and `IGridMessagePublisher` (retry-safe publish, never regenerates the key). Same `0.8.0` line.

The full ADR-0042 contract, backing, and runtime base are now available. Wave 4 conforms the two existing async producers.

## What Wave 4 must deliver (packets 05, 06 — parallel, different repos)

Bring `HoneyDrunk.Notify` (packet 05) and `HoneyDrunk.Communications` (packet 06) onto the idempotency contract — the two existing async producers ADR-0042 D10 names for the rollout.

**Both packets first audit their Node's actual async hops** and record the findings in the PR. Do not invent async boundaries that do not exist.

## The pattern each producer rollout applies

**Producer side (ADR-0042 D5):**
- Attach `IGridMessageEnvelope.IdempotencyKey` at the **message-construction site**, never at the broker-publish site (which would regenerate on retry).
- Use a **deterministic key** where a natural input exists — Notify: `notify-send:<tenant>:<external-id>`; Communications: a stable message-intent / decision-log identity. `IdempotencyKey.NewRandom()` otherwise.
- Publish through `IGridMessagePublisher` so the retry loop reuses the same key.

**Consumer side (ADR-0042 D3):**
- Derive the handler from `IdempotentMessageHandler<T>`; move side-effecting logic into the `protected abstract ProcessAsync` override; return an `IdempotencyOutcome`.
- The base handler does claim → dedup → complete. A duplicate inbound message hits the already-completed fast path and the side effect runs **exactly once**.
- Any downstream message emitted from a handler derives its key via `envelope.IdempotencyKey.Derive(relationship)` — never a fresh key.

**Composition:**
- Register an `IIdempotencyStore` bound to the Node's consumer-group, **TTL = 7 days** (ADR-0042 D4 standard — neither Notify nor Communications is billing or audit). Cosmos backing in deployed environments, InMemory in tests.

## Per-packet scoping notes

**Packet 05 — Notify.** Notify's intake→worker hop is an in-Node Storage Queue (ADR-0028 D2 row 3 / D3). It is still in scope for `IdempotentMessageHandler<T>` because a redelivered intake message could cause a tenant-visible double-send — and ADR-0042 D7's carve-out test ("a side effect a tenant would care about") makes a duplicate notification a domain event regardless of the Storage-Queue backing. The `IdempotencyKey` rides the message regardless of broker. Notify's pre-existing ESP-side dedup is not a substitute for the Grid contract.

**Packet 06 — Communications.** Per ADR-0028 D4, the Communications→Notify hop is **in-process at v1** — and ADR-0042 D8 exempts in-process events. Per ADR-0028 D7, Communications' internal intent→preference→cadence pipeline is also in-process and exempt. So packet 06's substantive work may be small: audit for real async broker boundaries, set up the in-process→async **bridge seam** so the key is attached at the bridge (D8) for when the Communications→Notify Service Bus split happens, wire the composition, and **document Communications' idempotency model** (closing the "no documented idempotency model" gap from the ADR Context). If Communications has zero async broker hops today, packet 06 says so explicitly and scopes to bridge + composition + docs.

## Frozen / do-not-touch

- **Notify (packet 05)** — do not touch preference/cadence/suppression decision logic; that is Communications' boundary (invariant 41). Touch only Notify's delivery-mechanics async hops.
- **Communications (packet 06)** — do not change `ICommunicationOrchestrator`, `IMessageIntent`/`MessageIntent`, `IPreferenceStore`, `ICadencePolicy` shapes; the Communications hot-path contract-shape canary (invariant 43) must stay green. Do not regress the per-send decision-log entry (invariant 42).

## Invariants binding Wave 4

- **Invariant 9** — Vault is the only source of secrets. The Cosmos connection resolves via `ISecretStore` / injected config, never a raw env read.
- **Invariant 27** — each packet bumps its whole solution one minor version in one commit (packet 05 → `HoneyDrunk.Notify`; packet 06 → `HoneyDrunk.Communications`). These are separate solutions from `HoneyDrunk.Kernel` — each gets its own bump.
- **Invariant 41** — preference/cadence/suppression logic in Communications; delivery mechanics in Notify. Neither packet crosses this.
- **Invariant 43** — Communications hot-path contract-shape canary; packet 06 must not drift those shapes.
- **Invariant 51** — no `Thread.Sleep` in test code; drive lease/TTL timing with an injected `TimeProvider`.

## Human Prerequisites carried into Wave 4

**Publish the upstream NuGet packages first — agents never tag or publish.** Wave 4 compiles against `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` `0.8.0` (packets 02 + 04) and `HoneyDrunk.Data.Idempotency.Cosmos` / `HoneyDrunk.Data.Idempotency.InMemory` (packet 03). Those artifacts reach the package feed only after a human pushes a git release tag in each repo:
- **Wave 2→3 boundary** — after packets 02 and 04 have merged, tag/release `HoneyDrunk.Kernel` `0.8.0` so both the Abstractions and runtime packages are on the feed (the Abstractions package must be published before packet 03 itself can build).
- **Wave 3→4 boundary** — after packet 03 merges, tag/release the `HoneyDrunk.Data` solution version shipping the two `HoneyDrunk.Data.Idempotency.*` packages.

Wave 4 cannot build against unpublished packages — confirm both releases are on the feed before packets 05/06 start.

The Cosmos dedup account must be provisioned per environment (packet 03's Human Prerequisites), the connection secret seeded into each Node's Key Vault, and the hosting Container App / Function Managed Identity granted Cosmos data-plane RBAC — before the deployed composition can resolve the Cosmos `IIdempotencyStore`. The code work in packets 05/06 does not require the live account — tests run against the InMemory store. Note (ADR-0028 D4): Notify Cloud composes Notify Cloud + Communications + Notify in the same Container App at v1 — if Communications shares Notify's host/Vault, the connection secret is the same one. Confirm the deployment topology.

## Acceptance gate for the wave

Packets 05 and 06 each pass the `pr-core.yml` tier-1 gate; each enumerates its Node's async hops in the PR; each producer attaches keys at construction and each in-scope consumer derives from `IdempotentMessageHandler<T>`; each composes a 7-day-TTL `IIdempotencyStore`; each solution is bumped one minor version. Communications' idempotency model is documented. Once both merge, Wave 5 (packet 07 — the canary and the strict mandatory-key flip) can start — and per ADR-0042 D10 the strict flip should reach production only after both producer rollouts are deployed everywhere.
