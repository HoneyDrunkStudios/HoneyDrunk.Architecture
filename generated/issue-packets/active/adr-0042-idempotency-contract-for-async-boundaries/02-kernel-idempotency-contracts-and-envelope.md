---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0042", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0042"]
wave: 2
initiative: adr-0042-idempotency-contract-for-async-boundaries
node: honeydrunk-kernel
---

# Add the idempotency contract surface to HoneyDrunk.Kernel.Abstractions

## Summary
Add the ADR-0042 idempotency contract surface to `HoneyDrunk.Kernel.Abstractions`: the `IGridMessageEnvelope` envelope with a mandatory `IdempotencyKey`, the `IIdempotencyStore` consumer-side dedup interface, the `IPulseSignalEnvelope` carve-out type, and the supporting records (`IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome`). All pure contracts — zero HoneyDrunk runtime dependencies. This is the version-bumping packet for the `HoneyDrunk.Kernel` solution.

## Context
ADR-0042 commits a Grid-wide idempotency contract for async domain-event boundaries. Azure Service Bus (ADR-0028's default broker) has at-least-once delivery; without a Grid-level contract each Node solves duplicate-handling ad-hoc and drifts. ADR-0042 D1/D2/D7 place the contract surface in `HoneyDrunk.Kernel.Abstractions` because Kernel is the zero-dependency contract layer every Node already consumes — the same placement precedent as `IGridContext`, `TenantId`, and the lifecycle hooks.

This packet adds **contracts only** — the interfaces, records, and the envelope shape. The runtime base handler and publisher helper (`IdempotentMessageHandler<T>`, `IGridMessagePublisher`) land in packet 04 in the `HoneyDrunk.Kernel` runtime package; the Cosmos `IIdempotencyStore` backing lands in packet 03. Splitting contract-from-runtime keeps `HoneyDrunk.Kernel.Abstractions` honest under invariant 1 (Abstractions have zero runtime dependencies on other HoneyDrunk packages).

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (.NET 10.0), two packages: `HoneyDrunk.Kernel.Abstractions` (zero-dependency contracts) and `HoneyDrunk.Kernel` (runtime). This packet is the **first packet on the `HoneyDrunk.Kernel` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.7.0` → `0.8.0`; new feature, additive contracts, no break). Packet 04 (also Kernel) appends to the in-progress `[0.8.0]` CHANGELOG entry.

> **Envelope-placement note for the executor.** ADR-0042 D1 is explicit that `IGridMessageEnvelope` is "additive to the existing envelope" and lives in `HoneyDrunk.Kernel.Abstractions`. Note `HoneyDrunk.Transport` already ships an `ITransportEnvelope` (the immutable transport message wrapper). These are **two different envelopes at two different layers** — `IGridMessageEnvelope` is the Kernel-level domain-event envelope carrying the `IdempotencyKey` and Grid context; `ITransportEnvelope` is the Transport-level wire wrapper. ADR-0042 is the authority: build `IGridMessageEnvelope` in Kernel.Abstractions as the ADR states. Do not modify `ITransportEnvelope` and do not take a dependency on `HoneyDrunk.Transport` from Kernel (that would invert the dependency graph — Transport depends on Kernel, never the reverse). If the relationship between the two envelopes needs reconciling, that is a follow-up, not this packet's concern.

## Scope
- `HoneyDrunk.Kernel.Abstractions` — new contract types:
  - `IdempotencyKey` — record wrapping the opaque string key.
  - `IGridMessageEnvelope` — interface for async domain-event messages, exposing `IdempotencyKey` plus the Grid context already carried by the existing Kernel envelope surface.
  - `IPulseSignalEnvelope` — separate interface for Pulse non-domain-event signals; carries no `IdempotencyKey`.
  - `IIdempotencyStore` — consumer-side dedup interface.
  - `IdempotencyClaim` — record: the claimed key, claim timestamp, lease/TTL, completion state.
  - `IdempotencyOutcome` — record carrying the outcome (`Succeeded` / `Failed`) plus a small outcome payload.
- Both `.csproj` files in the solution version-bumped to `0.8.0` (invariant 27).
- `HoneyDrunk.Kernel.Abstractions` package `CHANGELOG.md` and `README.md` updated.
- Repo-level `CHANGELOG.md` gets a new `[0.8.0]` entry.

## Proposed Implementation
1. **`IdempotencyKey`** — a `record` (or `readonly record struct`) wrapping a non-empty `string Value`. Validate non-empty at construction. Provide a `Derive(string relationship)` method that returns a new `IdempotencyKey` whose value is the lowercase hex of `SHA256(this.Value + ":" + relationship)` — this is the deterministic-derivation primitive ADR-0042 D3/D6 require (`SHA256(inbound:relationship)`, `SHA256(request:reply)`). Provide a `NewRandom()` factory returning a UUID v4-shaped key (D1 default).
2. **`IGridMessageEnvelope`** — interface exposing at minimum `IdempotencyKey IdempotencyKey { get; }` plus the Grid context the existing Kernel async-message surface already carries (`CorrelationId`, `TenantId`, etc. — match the shape of whatever envelope/context contract Kernel already exposes for messaging; do not invent a parallel context model — invariant 5/6). The envelope is immutable.
3. **`IPulseSignalEnvelope`** — a separate interface, deliberately NOT inheriting `IGridMessageEnvelope` and deliberately NOT exposing an `IdempotencyKey`. ADR-0042 D7: the carve-out is enforced at the type level. XML-doc it explicitly as the non-domain-event signal envelope, exempt from the idempotency contract.
4. **`IIdempotencyStore`** — interface with exactly the three members from ADR-0042 D2:
   ```
   ValueTask<IdempotencyClaim> TryClaim(IdempotencyKey key, TimeSpan ttl);
   ValueTask<IdempotencyClaim?> Read(IdempotencyKey key);
   ValueTask Complete(IdempotencyClaim claim, IdempotencyOutcome outcome);
   ```
   XML-doc the per-consumer-group scoping: the store instance is bound to one consumer-group; the partition/scoping key is a backing concern (D2 names Cosmos partition key = consumer-group), not a contract parameter.
5. **`IdempotencyClaim`** — record carrying the `IdempotencyKey`, `FirstSeenAt` (the ADR's term), the claim lease expiry, and a state discriminator (`Claimed` vs `Completed`). When `Completed`, it also carries the `IdempotencyOutcome`.
6. **`IdempotencyOutcome`** — record carrying an outcome status (`Succeeded` / `Failed` — an enum or discriminator) plus an optional small payload (`string` or `byte[]`) for the reply-derivation case (D6). Keep it small — ADR-0042 D2 calls it "a small outcome record."
7. All public types get full XML documentation (invariant 13).
8. Version-bump both `.csproj` files to `0.8.0`. Add a repo-level `[0.8.0]` CHANGELOG entry. Add a per-package CHANGELOG entry to `HoneyDrunk.Kernel.Abstractions` (it has real changes). The `HoneyDrunk.Kernel` runtime package gets no per-package CHANGELOG entry in *this* packet (no functional change yet — packet 04 adds the runtime code and its entry); it is still version-bumped to `0.8.0` to keep the solution aligned (invariant 27), with no noise entry (invariant 12/27).
9. Update `HoneyDrunk.Kernel.Abstractions/README.md` — the public API surface gained the idempotency contracts; document them in the API-surface section.

## Affected Files
- `HoneyDrunk.Kernel.Abstractions/` — new contract type files (one per type per the repo's existing file-per-type convention).
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — version bump.
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` — version bump (alignment).
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `HoneyDrunk.Kernel.Abstractions/README.md`.
- Repo-level `CHANGELOG.md`.
- `HoneyDrunk.Kernel.Abstractions.Tests` (or the repo's equivalent unit-test project) — tests for `IdempotencyKey` construction, `Derive` determinism, `NewRandom` uniqueness.

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` abstractions; `IdempotencyKey.Derive` uses `System.Security.Cryptography.SHA256` from the BCL — no package needed. `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`).
- **`HoneyDrunk.Kernel`** — no new `PackageReference` in this packet (runtime code lands in packet 04).
- The unit-test project follows the repo's existing test stack; no new packages introduced by this packet beyond what the test project already references.

## Boundary Check
- [x] `IGridMessageEnvelope`, `IIdempotencyStore`, `IPulseSignalEnvelope`, and the idempotency records are Kernel contracts per ADR-0042 D1/D2/D7. Routing rule "context, GridContext, NodeContext, ... CorrelationId → HoneyDrunk.Kernel" and the ADR's explicit placement both map here.
- [x] No dependency on `HoneyDrunk.Transport` — the dependency graph is Transport → Kernel, never the reverse (invariant 4, DAG).
- [x] Contracts only; the Cosmos backing (packet 03) and the runtime handler/publisher (packet 04) are separate packets.

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `IGridMessageEnvelope` with a `IdempotencyKey IdempotencyKey` member and immutable Grid context
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `IPulseSignalEnvelope` as a separate interface that does NOT inherit `IGridMessageEnvelope` and does NOT expose an `IdempotencyKey`
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `IIdempotencyStore` with exactly the three members `TryClaim`, `Read`, `Complete` with the ADR-0042 D2 signatures
- [ ] `IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome` are records; `IdempotencyKey` validates non-empty at construction
- [ ] `IdempotencyKey.Derive(relationship)` returns a deterministic `SHA256`-derived key; the same inputs produce the same output (unit-tested)
- [ ] `IdempotencyKey.NewRandom()` returns a UUID v4-shaped key; two calls produce different keys (unit-tested)
- [ ] All new public types have XML documentation
- [ ] `HoneyDrunk.Kernel.Abstractions` has zero runtime `PackageReference` on any HoneyDrunk package (invariant 1)
- [ ] Both non-test `.csproj` files in the solution are at version `0.8.0` in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.8.0]` entry dated to the merge
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` has a `[0.8.0]` entry describing the idempotency contract surface
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` gets NO entry (no functional change in this packet — alignment bump only, per invariant 12/27)
- [ ] `HoneyDrunk.Kernel.Abstractions/README.md` documents the new idempotency contracts in the public-API section
- [ ] The `pr-core.yml` tier-1 gate and the Kernel contract-shape canary pass — the new contracts are additive, paired with the `0.8.0` bump

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0042 D1 — Mandatory `IdempotencyKey`, exposed via `IGridMessageEnvelope`.** A string-shaped key in user-properties; produced once at origination, reused on retry; UUID v4 by default, deterministic keys allowed; opaque to the broker, separate from Service Bus `MessageId`. Exposed via `IGridMessageEnvelope.IdempotencyKey` in `HoneyDrunk.Kernel.Abstractions`, additive to the existing envelope.

**ADR-0042 D2 — `IIdempotencyStore`.** Three members: `ValueTask<IdempotencyClaim> TryClaim(IdempotencyKey key, TimeSpan ttl)`, `ValueTask<IdempotencyClaim?> Read(IdempotencyKey key)`, `ValueTask Complete(IdempotencyClaim claim, IdempotencyOutcome outcome)`. Store is separate per consumer-group and durable at Tier 1.

**ADR-0042 D3 — Deterministic downstream keys.** When a consumer emits a downstream message, the downstream key is `SHA256(inbound:relationship)` of the inbound key — `IdempotencyKey.Derive` is that primitive.

**ADR-0042 D6 — Reply key derivation.** A reply message's key is `SHA256(request:reply)` of the request's key — also `IdempotencyKey.Derive`.

**ADR-0042 D7 — Pulse carve-out enforced at the type level.** Pulse signals ride `IPulseSignalEnvelope`, a separate type from `IGridMessageEnvelope`; they carry no `IdempotencyKey`.

**ADR-0042 Operational Consequences.** "Kernel.Abstractions gains new interfaces; per ADR-0035 this is an additive minor bump (additions on new interfaces, not on existing ones). No breaking change."

## Constraints
- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** Only `Microsoft.Extensions.*` abstractions permitted. `IdempotencyKey.Derive`'s SHA256 comes from the BCL — no package. No runtime logic (no JSON loading, no DI) in Abstractions.
- **Invariant 4 — the dependency graph is a DAG; Kernel is at the root.** Do not reference `HoneyDrunk.Transport` or any other HoneyDrunk runtime package. `IGridMessageEnvelope` is a Kernel-level contract distinct from Transport's `ITransportEnvelope`.
- **Invariant 13 — all public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards` analyzers.
- **Invariant 27 — all projects in a solution share one version and move together.** Both `.csproj` files go to `0.8.0` in one commit. Partial bumps are forbidden. This is the bumping packet; packet 04 appends to the CHANGELOG only.
- **Invariant 12 — per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Kernel.Abstractions` gets an entry; `HoneyDrunk.Kernel` (alignment bump only here) gets none.
- **Records drop the `I`; interfaces keep it.** `IdempotencyKey` / `IdempotencyClaim` / `IdempotencyOutcome` are records; `IGridMessageEnvelope` / `IIdempotencyStore` / `IPulseSignalEnvelope` are interfaces.

## Labels
`feature`, `tier-2`, `core`, `adr-0042`, `wave-2`

## Agent Handoff

**Objective:** Add the ADR-0042 idempotency contract surface to `HoneyDrunk.Kernel.Abstractions` and bump the `HoneyDrunk.Kernel` solution to `0.8.0`.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the contracts every other packet in this initiative compiles against.
- Feature: ADR-0042 Idempotency Contract rollout, Wave 2 (the foundation).
- ADRs: ADR-0042 D1/D2/D3/D6/D7 (primary), ADR-0035 (additive minor-bump policy), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0042 Accepted and its three invariants live before the contracts are built against them.

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency (invariant 1). No reference to `HoneyDrunk.Transport`.
- `IGridMessageEnvelope` is a Kernel contract, distinct from Transport's `ITransportEnvelope`. Do not modify `ITransportEnvelope`; do not invert the dependency graph.
- Bump both non-test `.csproj` files to `0.8.0` in one commit (invariant 27). This is the bumping packet for `HoneyDrunk.Kernel` in this initiative.
- Records drop the `I`; interfaces keep it.

**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/` — new contract type files.
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.
- Both `.csproj` files for the version bump.

**Contracts:**
- `IGridMessageEnvelope` (new interface) — async domain-event envelope, exposes `IdempotencyKey`.
- `IPulseSignalEnvelope` (new interface) — Pulse signal carve-out, no `IdempotencyKey`.
- `IIdempotencyStore` (new interface) — `TryClaim` / `Read` / `Complete`.
- `IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome` (new records).
