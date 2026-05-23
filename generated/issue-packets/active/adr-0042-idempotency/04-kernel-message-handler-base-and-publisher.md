---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0042", "wave-3"]
dependencies: ["packet:02"]
adrs: ["ADR-0042"]
wave: 3
initiative: adr-0042-idempotency
node: honeydrunk-kernel
---

# Add IdempotentMessageHandler<T> and IGridMessagePublisher to the Kernel runtime

## Summary
Add the runtime half of ADR-0042 to the `HoneyDrunk.Kernel` runtime package: the `IdempotentMessageHandler<T>` base class encoding the claim → process → complete consumer pattern (ADR-0042 D3), and the `IGridMessagePublisher` helper that publishes with retry and never regenerates the `IdempotencyKey` (ADR-0042 D5). Append to the in-progress `[0.8.0]` CHANGELOG entry that packet 02 opened.

## Context
Packet 02 ships the ADR-0042 *contracts* in `HoneyDrunk.Kernel.Abstractions`. This packet ships the *runtime pattern* in the `HoneyDrunk.Kernel` package: the shared consumer base every async consumer derives from, and the producer helper every async producer publishes through. ADR-0042 D3 is explicit that the claim/process/complete pattern is "encoded once in a shared `IdempotentMessageHandler<T>` base" — so it is built once, in Kernel, not re-implemented per Node.

This packet is the **second packet on the `HoneyDrunk.Kernel` solution in this initiative**. Per invariant 27, packet 02 already bumped the solution to `0.8.0`; this packet does NOT bump again — it appends to the in-progress `[0.8.0]` CHANGELOG entry and adds a per-package CHANGELOG entry to `HoneyDrunk.Kernel` (which now has real functional changes). Coordinate the working branch with packet 02's: land 02 first (or rebase 04 onto 02's merge) so `0.8.0` is consistent.

The `IdempotentMessageHandler<T>` base depends on `IIdempotencyStore` (a Kernel.Abstractions contract) — it does not depend on any concrete backing. The backing is composed at the host (the Cosmos store from packet 03, or the InMemory store for tests) — this is the abstraction/runtime split (invariant 2: runtime packages depend on Abstractions).

`IGridMessagePublisher` is described by ADR-0042 D5 as "a helper that handles publish-with-retry and never regenerates the key." It is a thin wrapper. The actual broker send is a Transport concern (`ITransportPublisher`) — but **Kernel must not depend on `HoneyDrunk.Transport`** (invariant 4: Transport depends on Kernel, never the reverse). See the implementation note below for how the publisher delegates the send without inverting the graph.

## Scope
- `HoneyDrunk.Kernel` (runtime package) — new types:
  - `IdempotentMessageHandler<T>` — abstract base encoding claim → process → complete.
  - `IGridMessagePublisher` interface + a default implementation `GridMessagePublisher`.
- Unit tests for both, against the InMemory `IIdempotencyStore` (from packet 03) or a Kernel-local test fake.
- `HoneyDrunk.Kernel/CHANGELOG.md` gets a `[0.8.0]` per-package entry; repo-level `CHANGELOG.md` `[0.8.0]` entry is appended to (not newly created — packet 02 created it).
- `HoneyDrunk.Kernel/README.md` updated for the new runtime API surface.

## Proposed Implementation
1. **`IdempotentMessageHandler<T>`** — abstract class, generic over the message type `T`. Constructor takes an `IIdempotencyStore` and the configured TTL (`TimeSpan`). It exposes a `sealed` public `HandleAsync(IGridMessageEnvelope envelope, T message, CancellationToken)` that runs the ADR-0042 D3 pattern:
   1. **Claim** — `TryClaim(envelope.IdempotencyKey, ttl)`. If the result indicates the key is already claimed and not yet completed → return a "defer" result (the consumer returns the message to the broker for redelivery after the lease expires). If the key is **already completed** → return the recorded `IdempotencyOutcome` *without* calling the subclass's processing method — this is the dedup payoff.
   2. **Process** — call the abstract `protected abstract ValueTask<IdempotencyOutcome> ProcessAsync(IGridMessageEnvelope envelope, T message, CancellationToken)` that the subclass implements. All side effects (DB writes, HTTP calls, downstream emits) happen in the subclass override.
   3. **Complete** — `Complete(claim, outcome)` with the outcome `ProcessAsync` returned.
   - Provide a `protected` helper for the D3 downstream-key rule: when a subclass emits a downstream message, it derives the downstream key as `envelope.IdempotencyKey.Derive(relationship)` (`IdempotencyKey.Derive` ships in packet 02). Document that the subclass must use this, never a fresh key, for any downstream emit.
   - **Keyless-message tolerance (ADR-0042 D10).** During the producer rollout, a message may arrive with no `IdempotencyKey`. The base handler must tolerate this: if `envelope.IdempotencyKey` is absent/empty, skip claim/complete entirely and call `ProcessAsync` directly — "process exactly as today, no dedup." This is the only transitional accommodation; it stays until the rollout closes (packet 07 flips the canary's mandatory check on). Gate the behaviour behind a documented flag or make it the default — match what packet 07's canary expects.
2. **`IGridMessagePublisher`** — interface with a `PublishAsync(IGridMessageEnvelope envelope, CancellationToken)`-shaped member, plus a `GridMessagePublisher` default implementation. The publisher:
   - **Never regenerates the key.** The `IdempotencyKey` is already on the `envelope` (the producer attached it at the message-construction site per D5). The publisher's retry loop re-sends the *same* envelope — same key — on every attempt.
   - Wraps publish-with-retry (a bounded retry with backoff) around an injected send delegate.
   - **Does not depend on `HoneyDrunk.Transport`.** Implementation note: the publisher takes the actual broker send as an injected delegate or a small Kernel-defined `IMessageSendChannel` abstraction — the host wires Transport's `ITransportPublisher` into it at composition time. Kernel defines the seam; Transport (which already depends on Kernel) supplies the implementation. This preserves the DAG (invariant 4). Do NOT add a `PackageReference` to `HoneyDrunk.Transport` from `HoneyDrunk.Kernel`.
3. **Unit tests** — `IdempotentMessageHandler<T>`: a fresh key runs `ProcessAsync` once and completes; a second `HandleAsync` with the same key returns the recorded outcome and does NOT call `ProcessAsync` again (assert exactly-once via a call counter); a claimed-not-completed key returns the defer result; a keyless envelope calls `ProcessAsync` directly with no claim. `GridMessagePublisher`: a retry does not change the key (assert the send delegate receives the same `IdempotencyKey` on every attempt). Use the InMemory `IIdempotencyStore` or a Kernel-local fake; no `Thread.Sleep` (invariant 51) — drive retry/lease timing with an injected `TimeProvider`.
4. **Versioning** — do NOT bump versions; packet 02 already set the solution to `0.8.0`. Append the runtime additions to the existing repo-level `[0.8.0]` CHANGELOG entry. Add a `[0.8.0]` entry to `HoneyDrunk.Kernel/CHANGELOG.md` (this package now has real changes). Update `HoneyDrunk.Kernel/README.md`.

## Affected Files
- `HoneyDrunk.Kernel/` — `IdempotentMessageHandler.cs`, `GridMessagePublisher.cs`, `IGridMessagePublisher.cs` (and the send-channel seam type if introduced).
- `HoneyDrunk.Kernel/CHANGELOG.md`, `HoneyDrunk.Kernel/README.md`.
- Repo-level `CHANGELOG.md` — append to the existing `[0.8.0]` entry.
- The Kernel unit-test project — new tests.

## NuGet Dependencies
- **`HoneyDrunk.Kernel`** — no new HoneyDrunk `PackageReference`. It already references `HoneyDrunk.Kernel.Abstractions` (now `0.8.0`, in-solution). It must NOT add `HoneyDrunk.Transport`. May add `Microsoft.Extensions.Resilience` or use a hand-rolled bounded retry — prefer whatever the repo already uses for retry/resilience; if nothing exists, a small hand-rolled bounded retry avoids a new dependency. State the choice in the PR.
- **Kernel unit-test project** — the repo's existing test stack (ADR-0047: xUnit v2 + NSubstitute + AwesomeAssertions + coverlet). If the InMemory `IIdempotencyStore` from packet 03 is used as the test double, add a `PackageReference`/project reference to `HoneyDrunk.Data.Idempotency.InMemory` *in the test project only* (test code may reference it; invariant 16 forbids test code in runtime packages, not the reverse). Alternatively use a Kernel-local in-test fake to avoid the cross-repo test dependency — prefer the local fake to keep the Kernel test project self-contained, and state the choice in the PR.

## Boundary Check
- [x] `IdempotentMessageHandler<T>` and `IGridMessagePublisher` are the runtime encoding of ADR-0042 D3/D5; ADR-0042 explicitly places them in Kernel ("the Kernel ships an `IGridMessagePublisher` helper", "encoded once in a shared `IdempotentMessageHandler<T>` base").
- [x] No `PackageReference` to `HoneyDrunk.Transport` — the publisher takes the broker send as an injected seam (invariant 4, DAG preserved).
- [x] Runtime code in the `HoneyDrunk.Kernel` runtime package, not in `Abstractions` (invariant 1/2).

## Acceptance Criteria
- [ ] `IdempotentMessageHandler<T>` is an abstract class with a `sealed` public `HandleAsync` and a `protected abstract ProcessAsync`
- [ ] A fresh key runs `ProcessAsync` exactly once and `Complete`s the claim (unit-tested with a call counter)
- [ ] A repeat `HandleAsync` with an already-completed key returns the recorded `IdempotencyOutcome` and does NOT call `ProcessAsync` (exactly-once dedup, unit-tested)
- [ ] A claimed-but-not-completed key returns a defer result (the message goes back to the broker)
- [ ] A keyless envelope (ADR-0042 D10 rollout case) calls `ProcessAsync` directly with no claim/complete — "process exactly as today, no dedup"
- [ ] A `protected` downstream-key helper derives downstream keys via `IdempotencyKey.Derive(relationship)`; the base handler documents that subclasses must never use a fresh key for a downstream emit
- [ ] `IGridMessagePublisher` / `GridMessagePublisher` publishes with bounded retry and reuses the same `IdempotencyKey` on every retry attempt (unit-tested — the send delegate sees the same key each attempt)
- [ ] `HoneyDrunk.Kernel` has NO `PackageReference` to `HoneyDrunk.Transport` (invariant 4)
- [ ] No version bump in this packet — the solution stays at `0.8.0` from packet 02
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` has a `[0.8.0]` entry for the new runtime types
- [ ] Repo-level `CHANGELOG.md` `[0.8.0]` entry is extended (not duplicated) with the runtime additions
- [ ] `HoneyDrunk.Kernel/README.md` documents `IdempotentMessageHandler<T>` and `IGridMessagePublisher`
- [ ] Unit tests contain no `Thread.Sleep` (invariant 51); retry/lease timing uses an injected `TimeProvider`
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0042 D3 — Consumer pattern: claim, process, complete.** Encoded once in a shared `IdempotentMessageHandler<T>` base. (1) Claim with the configured TTL; if already claimed and not completed, defer. (2) If already completed, return the recorded outcome without re-executing side effects. (3) Process — side effects happen here. (4) Complete with the outcome. Side-effect ordering: a downstream message's key is `SHA256(inbound:relationship)` of the inbound key.

**ADR-0042 D5 — Producer responsibilities.** Producers generate/attach the key at the message-construction site, never at the broker-publish site. "The Kernel ships an `IGridMessagePublisher` helper that handles publish-with-retry and never regenerates the key."

**ADR-0042 D10 — Backward compatibility.** During the rollout, consumers tolerate messages without a key (treat as effectively-not-idempotent: process exactly as today, no dedup). The canary's mandatory-attribute check flips on after the rollout completes.

**ADR-0042 Operational Consequences.** "The `IdempotentMessageHandler<T>` base introduces a small latency penalty per message (one extra round-trip to the dedup store)."

## Constraints
- **Invariant 2 — runtime packages depend on Abstractions, never on another runtime package at the same layer.** `HoneyDrunk.Kernel` depends on `HoneyDrunk.Kernel.Abstractions`.
- **Invariant 4 — DAG; Kernel is at the root.** `HoneyDrunk.Kernel` must NOT take a `PackageReference` on `HoneyDrunk.Transport`. The publisher takes the broker send as an injected seam; the host wires Transport in.
- **Invariant 27 — one version across the solution.** Packet 02 already bumped to `0.8.0`; this packet does NOT bump again — it appends to the in-progress `[0.8.0]` CHANGELOG.
- **Invariant 51 — no `Thread.Sleep` in test code.** Retry/lease tests drive an injected `TimeProvider`.
- **Invariant 13 — all public APIs have XML documentation.**
- **Keyless tolerance is transitional only.** ADR-0042 D10: it is the single transitional accommodation; packet 07 flips the canary's mandatory-key enforcement on once the producer rollout closes.

## Labels
`feature`, `tier-2`, `core`, `adr-0042`, `wave-3`

## Agent Handoff

**Objective:** Add `IdempotentMessageHandler<T>` and `IGridMessagePublisher` to the `HoneyDrunk.Kernel` runtime package.

**Target:** `HoneyDrunk.Kernel`, branch from `main` (after packet 02 has merged — rebase if needed so `0.8.0` is consistent).

**Context:**
- Goal: Ship the claim/process/complete consumer base and the retry-safe publisher once, in Kernel, so every async Node reuses them.
- Feature: ADR-0042 Idempotency Contract rollout, Wave 3 (parallel with packet 03).
- ADRs: ADR-0042 D3/D5/D10 (primary), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — `IIdempotencyStore`, `IGridMessageEnvelope`, `IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome` ship in `HoneyDrunk.Kernel.Abstractions` `0.8.0`. Packet 04 shares the `HoneyDrunk.Kernel` solution with packet 02 — land 02 first or rebase onto its merge.

**Constraints:**
- No `PackageReference` to `HoneyDrunk.Transport` (invariant 4) — publisher takes the send as an injected seam.
- No version bump — packet 02 set `0.8.0`; append to the in-progress `[0.8.0]` CHANGELOG.
- Keyless-message tolerance is transitional (D10) — base handler processes keyless envelopes without dedup.
- No `Thread.Sleep` in tests; drive timing with `TimeProvider`.

**Key Files:**
- `HoneyDrunk.Kernel/IdempotentMessageHandler.cs`, `GridMessagePublisher.cs`, `IGridMessagePublisher.cs`.
- `HoneyDrunk.Kernel/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.

**Contracts:**
- `IGridMessagePublisher` (new interface in `HoneyDrunk.Kernel` runtime) — retry-safe publish that never regenerates the key.
- `IdempotentMessageHandler<T>` (new abstract class in `HoneyDrunk.Kernel` runtime) — claim/process/complete base.
- Consumes `IIdempotencyStore`, `IGridMessageEnvelope`, `IdempotencyKey` from `HoneyDrunk.Kernel.Abstractions` `0.8.0`.
