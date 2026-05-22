# Handoff — Wave 2: Contract Foundation

**Initiative:** `adr-0042-idempotency-contract-for-async-boundaries`
**Wave transition:** Wave 1 (governance + catalog) → Wave 2 (contract foundation)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 landed

- **Packet 00** — ADR-0042 flipped to **Accepted**. Three new invariants added to `constitution/invariants.md` under a new `## Idempotency Invariants` section, numbered **75, 76, 77** (pre-reserved for ADR-0042; current verified max is 51):
  1. **75** — Every async domain-event message carries an `IdempotencyKey` (Pulse/telemetry carve-outs).
  2. **76** — Dedup state lives per consumer-group, with a TTL (7 days standard, 30 days billing/audit).
  3. **77** — Downstream message keys are deterministically derived from the originating key.
- **Packet 01** — the idempotency contract surface (`IGridMessageEnvelope`, `IIdempotencyStore`, `IdempotentMessageHandler`, `IGridMessagePublisher`, `IPulseSignalEnvelope`, `IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome`) registered in `catalogs/contracts.json` and `catalogs/nodes.json` under `honeydrunk-kernel`.

ADR-0042's decisions are now live rules. Packet 02 implements the contracts the catalog already advertises.

## What Wave 2 must deliver (packet 02)

Build the idempotency contract surface in **`HoneyDrunk.Kernel`** (live Node, currently v0.7.0, .NET 10.0):

- **`HoneyDrunk.Kernel.Abstractions`** — add `IGridMessageEnvelope`, `IPulseSignalEnvelope`, `IIdempotencyStore`, `IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome`. Pure records/interfaces — zero HoneyDrunk runtime dependencies (invariant 1).
- This is the **version-bumping packet**: bump every non-test `.csproj` in the solution `0.7.0` → `0.8.0` in one commit (invariant 27).

## Interface signatures for downstream packets

`IIdempotencyStore` — the shape packets 03/04/05/06 consume:
```
public interface IIdempotencyStore
{
    ValueTask<IdempotencyClaim> TryClaim(IdempotencyKey key, TimeSpan ttl);
    ValueTask<IdempotencyClaim?> Read(IdempotencyKey key);
    ValueTask Complete(IdempotencyClaim claim, IdempotencyOutcome outcome);
}
```

`IdempotencyKey` — a record wrapping a non-empty string. Two factory paths:
- `IdempotencyKey.NewRandom()` — UUID v4-shaped key (ADR-0042 D1 default).
- `key.Derive(string relationship)` — deterministic `SHA256(key.Value + ":" + relationship)`. This is the primitive ADR-0042 D3 (`SHA256(inbound:relationship)`) and D6 (`SHA256(request:reply)`) require. Packet 04's base handler and packets 05/06's producers all call `Derive` for downstream/reply keys — never a fresh key.

`IGridMessageEnvelope` — the async domain-event envelope; exposes `IdempotencyKey IdempotencyKey { get; }` plus Grid context. Immutable.

`IPulseSignalEnvelope` — a **separate** interface; does NOT inherit `IGridMessageEnvelope`, carries NO `IdempotencyKey`. ADR-0042 D7's carve-out, enforced at the type level.

`IdempotencyClaim` — record: the key, `FirstSeenAt`, lease expiry, a `Claimed`/`Completed` discriminator, and the `IdempotencyOutcome` when completed.

`IdempotencyOutcome` — record: a `Succeeded`/`Failed` status plus a small optional payload (for the D6 reply-derivation case). Keep it small.

## Frozen / do-not-touch

- **`ITransportEnvelope`** (in `HoneyDrunk.Transport`) is a *different* envelope at a different layer — the Transport wire wrapper. `IGridMessageEnvelope` is the Kernel-level domain envelope. Do NOT modify `ITransportEnvelope`, do NOT reference `HoneyDrunk.Transport` from `HoneyDrunk.Kernel` (invariant 4 — Transport depends on Kernel, never the reverse). The two-envelope reconciliation is a noted follow-up, not packet 02's concern.
- Existing Kernel context contracts (`IGridContext`, `TenantId`, `CorrelationId`, etc.) — `IGridMessageEnvelope` *composes* the existing context surface; do not fork a parallel context model (invariant 5/6).

## Invariants binding Wave 2

- **Invariant 1** — `HoneyDrunk.Kernel.Abstractions` has zero runtime dependencies on other HoneyDrunk packages; only `Microsoft.Extensions.*` abstractions permitted. `IdempotencyKey.Derive`'s SHA256 comes from the BCL — no package. No runtime logic in Abstractions.
- **Invariant 4** — the dependency graph is a DAG; Kernel is at the root. No reference to `HoneyDrunk.Transport` or any other HoneyDrunk runtime package.
- **Invariant 13** — all public APIs have XML documentation.
- **Invariant 27** — all projects in a solution share one version and move together. Packet 02 is the bumping packet: bump every non-test `.csproj` to `0.8.0` in one commit. Partial bumps are forbidden. Packets 04 and 07 (also Kernel) append to the CHANGELOG only.
- **Naming rule** — records drop the `I` (`IdempotencyKey`, `IdempotencyClaim`, `IdempotencyOutcome`); interfaces keep it (`IGridMessageEnvelope`, `IIdempotencyStore`, `IPulseSignalEnvelope`).

## Acceptance gate for the wave

Packet 02's PR passes the `pr-core.yml` tier-1 gate and the Kernel contract-shape canary (the new contracts are additive, paired with the `0.8.0` bump). `HoneyDrunk.Kernel` is at `0.8.0` with the idempotency contract surface shipped in `HoneyDrunk.Kernel.Abstractions`. Wave 3 (packet 03 in `HoneyDrunk.Data`, packet 04 in `HoneyDrunk.Kernel`) can then start in parallel.

**Human package release at the Wave 2→3 boundary — agents never tag.** Packet 03 builds against `HoneyDrunk.Kernel.Abstractions` `0.8.0`; that artifact reaches the package feed only after a human pushes a git release tag on `HoneyDrunk.Kernel`. After packet 02 merges, a human must tag/release `HoneyDrunk.Kernel` `0.8.0` so packet 03 can compile. (Packet 04 also targets `0.8.0`; the runtime package must likewise be published before Wave 4 — see the Wave-4 handoff.)
