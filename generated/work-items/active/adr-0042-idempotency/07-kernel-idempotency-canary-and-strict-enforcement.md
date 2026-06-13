---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "canary", "adr-0042", "wave-5"]
dependencies: ["work-item:04", "work-item:05", "work-item:06"]
adrs: ["ADR-0042"]
wave: 5
initiative: adr-0042-idempotency
node: honeydrunk-kernel
---

# Add the ADR-0042 idempotency canary and flip the mandatory-key check on

## Summary
Add the ADR-0042 D9 canary to `HoneyDrunk.Kernel.Tests.Canaries` — publish a message twice with the same `IdempotencyKey`, assert the side effect happened exactly once, assert the dedup-store recorded the key with its outcome, and assert a post-TTL replay re-executes — and flip the D1 mandatory-`IdempotencyKey` check from rollout-tolerant to strict, since the producer rollout (packets 05, 06) has closed.

## Context
ADR-0042 D9 specifies a canary in `HoneyDrunk.Kernel.Tests.Canaries`. ADR-0042 D10 says the canary's mandatory-attribute check (D1: messages without an `IdempotencyKey` are rejected at the consumer) **flips on after the rollout completes** — and the rollout is the producer amendments in packets 05 (Notify) and 06 (Communications). This packet is sequenced last, in Wave 5, so it lands only after both producer rollouts have merged. It is the packet that closes the transitional accommodation.

`HoneyDrunk.Kernel.Tests.Canaries` is named directly by ADR-0042 D9 — the canary lives in the Kernel repo's canary project (invariant 14: canary tests validate cross-Node boundaries). This packet adds the canary test and, in `IdempotentMessageHandler<T>` (shipped by packet 04), changes the keyless-message behaviour from "process anyway, no dedup" (the D10 transitional accommodation) to "reject — poison-letter trace" (the D1 strict policy).

This packet is the third packet on the `HoneyDrunk.Kernel` solution in this initiative — per invariant 27 it does NOT bump the version again (packet 02 set `0.8.0`); it appends to the in-progress `[0.8.0]` CHANGELOG. The strict-enforcement change is a behaviour change within the same `0.8.0` line — note it clearly in the CHANGELOG.

> **Sequencing note for the executor.** This packet flips strict enforcement on. If, at execution time, the Notify (packet 05) or Communications (packet 06) producer rollouts have NOT all merged and deployed, flipping strict enforcement will poison-letter their still-keyless messages. The `dependencies:` array hard-blocks this packet behind packets 05 and 06, so it cannot file until they are filed — but filing is not deploying. Before flipping the strict check, confirm packets 05 and 06 are merged AND their producers are emitting keys in every environment the canary runs. If a producer is mid-rollout, ship the canary test in this packet but keep the strict flip behind a config switch and flag the flip as a follow-up step. State the rollout status in the PR.

## Scope
- `HoneyDrunk.Kernel.Tests.Canaries` — the ADR-0042 D9 idempotency canary.
- `HoneyDrunk.Kernel` runtime — change `IdempotentMessageHandler<T>`'s keyless-message handling from rollout-tolerant to strict (reject + poison-letter trace), per ADR-0042 D1/D10.
- `HoneyDrunk.Kernel/CHANGELOG.md` `[0.8.0]` entry appended; repo-level `CHANGELOG.md` `[0.8.0]` entry appended.

## Proposed Implementation
1. **The canary** — in `HoneyDrunk.Kernel.Tests.Canaries`, a canary test that, per ADR-0042 D9:
   - Publishes a message **twice with the same `IdempotencyKey`** to a test consumer (a test `IdempotentMessageHandler<T>` subclass with a counting side effect).
   - Asserts the consumer's side effect happened **exactly once**.
   - Asserts the dedup-store contains the key with the recorded `IdempotencyOutcome`.
   - **Replays the same key after the TTL window expires** and asserts the side effect happens **again** (TTL is real, not infinite) — drive TTL expiry via the injected `TimeProvider` on the InMemory `IIdempotencyStore`, never `Thread.Sleep` (invariant 51).
   - Run against the InMemory `IIdempotencyStore` (from packet 03) so the canary is deterministic and has no external dependency (invariant 15).
2. **Strict mandatory-key enforcement** — in `IdempotentMessageHandler<T>`, change the keyless-envelope path. Packet 04 made a keyless envelope skip claim/complete and process directly (D10 transitional). This packet flips it: a keyless or empty-`IdempotencyKey` envelope is **rejected** — the handler emits a poison-letter trace and does not process (ADR-0042 D1: "production messages are dropped with a poison-letter trace"). Per the sequencing note, gate the flip behind a config switch if any producer rollout is still in flight; otherwise make strict the default. The transitional path from packet 04 is removed or left only as the explicit opt-out config.
3. **Canary for the keyless-rejection path** — extend the canary (or add a second canary) asserting that a message published WITHOUT an `IdempotencyKey` is rejected/poison-lettered by a strict handler, not processed.
4. **CHANGELOG** — append to the in-progress `[0.8.0]` entries in both the repo-level `CHANGELOG.md` and `HoneyDrunk.Kernel/CHANGELOG.md`: the canary, and the strict mandatory-key enforcement (note it as a behaviour change closing the D10 rollout). No version bump (invariant 27 — packet 02 owns the bump).
5. If `HoneyDrunk.Kernel.Tests.Canaries` does not yet exist as a project, create it (invariant 14 — canary projects validate cross-Node boundaries; the Kernel→async-consumer idempotency contract is exactly such a boundary). A new project ships `CHANGELOG.md` + `README.md` from the first commit (invariant 12) — though for a test/canary project a brief README is sufficient.

## Affected Files
- `HoneyDrunk.Kernel.Tests.Canaries/` — the idempotency canary test(s); the project itself if it does not exist.
- `HoneyDrunk.Kernel/IdempotentMessageHandler.cs` — strict keyless-envelope handling.
- `HoneyDrunk.Kernel/CHANGELOG.md`, repo-level `CHANGELOG.md` — `[0.8.0]` entries appended.

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Tests.Canaries`** — the repo's existing test/canary stack (ADR-0047: xUnit v2 + NSubstitute + AwesomeAssertions + coverlet). Project reference (or `PackageReference`) to `HoneyDrunk.Kernel` (in-solution) and to `HoneyDrunk.Data.Idempotency.InMemory` (the InMemory `IIdempotencyStore`, version from packet 03) — test/canary code may reference it; invariant 16 forbids test code *in* runtime packages, not the reverse. `HoneyDrunk.Standards` (`PrivateAssets: all`) if the project is newly created.
- **`HoneyDrunk.Kernel`** — no new `PackageReference`; the strict-enforcement change is internal logic.

## Boundary Check
- [x] ADR-0042 D9 names `HoneyDrunk.Kernel.Tests.Canaries` directly — the canary lives in the Kernel repo.
- [x] The strict-enforcement change is to `IdempotentMessageHandler<T>` in the `HoneyDrunk.Kernel` runtime package, where the base handler ships (packet 04).
- [x] No version bump — same `0.8.0` line as packets 02 and 04 (invariant 27).
- [x] Canary uses the InMemory store — no external dependency (invariant 15).

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Tests.Canaries` contains a canary that publishes a message twice with the same `IdempotencyKey` and asserts the side effect happened exactly once
- [ ] The canary asserts the dedup-store contains the key with the recorded `IdempotencyOutcome`
- [ ] The canary replays the same key after TTL expiry (driven via `TimeProvider`) and asserts the side effect runs again — TTL is real, not infinite
- [ ] A canary asserts a keyless message is rejected/poison-lettered by a strict `IdempotentMessageHandler<T>`, not processed
- [ ] `IdempotentMessageHandler<T>`'s keyless-envelope path is flipped from rollout-tolerant (packet 04) to strict reject + poison-letter trace, per ADR-0042 D1
- [ ] If any producer rollout (packet 05 / 06) is still deploying at execution time, the strict flip is behind a config switch and the PR states the rollout status; otherwise strict is the default
- [ ] The canary runs deterministically against the InMemory `IIdempotencyStore` with no external dependency; no `Thread.Sleep` (invariant 51)
- [ ] No version bump — the solution stays at `0.8.0`
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` and repo-level `CHANGELOG.md` `[0.8.0]` entries are appended with the canary and the strict-enforcement behaviour change
- [ ] If `HoneyDrunk.Kernel.Tests.Canaries` is newly created, it ships with a brief `README.md`
- [ ] The `pr-core.yml` tier-1 gate passes and the new canary is green

## Human Prerequisites
- [ ] Before this packet's strict-enforcement flip reaches production: confirm the Notify (packet 05) and Communications (packet 06) producer rollouts are merged AND deployed in every environment, so no producer is still emitting keyless messages. ADR-0042 D10: the mandatory-attribute check flips on "after the rollout completes." If a producer is mid-deploy, keep the flip behind the config switch until the rollout closes. This is a deploy-sequencing judgment, not a code action — the canary test itself is environment-independent.

## Referenced ADR Decisions
**ADR-0042 D9 — Canary.** A canary in `HoneyDrunk.Kernel.Tests.Canaries`: publishes a message twice with the same `IdempotencyKey`; asserts the side effect happened exactly once; asserts the dedup-store contains the key with the outcome; replays the same key after the TTL window and asserts the side effect happens again. Runs in every environment per ADR-0033 deploy validation.

**ADR-0042 D1 — Mandatory key, strict.** "Messages without an `IdempotencyKey` are rejected at the consumer side (canary-enforced; production messages are dropped with a poison-letter trace)."

**ADR-0042 D10 — Backward compatibility.** During the rollout, consumers tolerate keyless messages. "The canary's mandatory-attribute check (D1) flips on after the rollout completes. This is the only transitional accommodation; once the rollout closes, the canary enforces strict policy."

## Constraints
- **Invariant 14 — canary tests validate cross-Node boundaries.** The idempotency contract is a Kernel→async-consumer boundary; the canary belongs in `HoneyDrunk.Kernel.Tests.Canaries`.
- **Invariant 15 — unit/in-process tests never depend on external services.** The canary uses the InMemory `IIdempotencyStore`.
- **Invariant 51 — no `Thread.Sleep` in test code.** TTL expiry is driven via `TimeProvider`.
- **Invariant 27 — one version across the solution.** No bump here; packet 02 owns the `0.8.0` bump; append to the CHANGELOG.
- **Strict flip is sequenced after the producer rollout.** ADR-0042 D10 — do not poison-letter still-keyless producers. Gate behind a config switch if any rollout is mid-flight.

## Labels
`feature`, `tier-2`, `core`, `canary`, `adr-0042`, `wave-5`

## Agent Handoff

**Objective:** Add the ADR-0042 D9 idempotency canary and flip `IdempotentMessageHandler<T>`'s mandatory-key check to strict.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Enforce the idempotency contract with a canary and close the D10 transitional keyless-tolerance accommodation.
- Feature: ADR-0042 Idempotency Contract rollout, Wave 5 (final wave).
- ADRs: ADR-0042 D1/D9/D10 (primary), ADR-0033 (canaries run per-environment), ADR-0047 (canary stack), ADR-0008.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:04` — `IdempotentMessageHandler<T>` is the type whose keyless path is flipped to strict.
- `work-item:05` — Notify producers must emit keys before strict enforcement, or they get poison-lettered.
- `work-item:06` — Communications producers must emit keys before strict enforcement.

**Constraints:**
- Canary uses the InMemory store (invariant 15); no `Thread.Sleep` (invariant 51).
- No version bump (invariant 27) — append to the `0.8.0` CHANGELOG.
- Sequence the strict flip after the producer rollout deploys (ADR-0042 D10) — gate behind a config switch if any rollout is mid-flight; state status in the PR.

**Key Files:**
- `HoneyDrunk.Kernel.Tests.Canaries/` — the canary test(s).
- `HoneyDrunk.Kernel/IdempotentMessageHandler.cs` — strict keyless handling.
- `HoneyDrunk.Kernel/CHANGELOG.md`, repo-level `CHANGELOG.md`.

**Contracts:** None changed — this packet adds a canary and changes internal `IdempotentMessageHandler<T>` behaviour within the existing `0.8.0` contract surface.
