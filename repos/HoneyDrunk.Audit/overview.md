# HoneyDrunk.Audit — Overview

**Sector:** Core
**Version:** TBD (initial release planned 0.1.0 with the standup scaffold)
**Framework:** .NET 10.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Audit`
**Status:** Capability decision accepted; standup not yet executed (governed by the separate standup ADR)

## Purpose

The Grid's single durable, attributable system of record for security and privileged-action events — login attempts, authorization grants and denials, privileged-action execution. It durably records "actor X attempted or executed action Y" and serves that record back for incident reconstruction and forensics.

It is a record substrate, not a control plane and not an observability pipeline. It does not decide whether an action is allowed (that is Auth and Operator). It does not sample, aggregate, or surface health signal (that is Pulse). It owns the durable write, the append-only guarantee enforced at the interface surface, the audit-class retention, and the forensic read surface.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Audit.Abstractions` | Abstractions | `IAuditLog`, `IAuditQuery`, `AuditEntry`. Zero HoneyDrunk dependencies; only `Microsoft.Extensions.*` abstractions permitted. |
| `HoneyDrunk.Audit.Data` | Runtime (backing slot) | Data-backed append-only `IAuditLog` writer and `IAuditQuery` reader over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`; audit-class retention wiring; DI composition. |

## Key Contracts

- `IAuditLog` — append-only write of an `AuditEntry`. No update method, no delete method. Append-only is enforced at the interface surface.
- `IAuditQuery` — time-ordered and filtered read/forensic retrieval over the durable record.
- `AuditEntry` — canonical append-only record: actor, action, context, outcome, correlation id, tenant.

## Design Notes

The boundary rule is sharp: **the recorder is not the actor.** A control plane that can halt, gate, and trip breakers (Operator) must not also be the authoritative ledger that records whether it was right to. The durable audit channel and the observability channel (Pulse) are never merged — observability answers "is the system healthy in aggregate"; audit answers "who did what, when, against what, and was it allowed," durably and attributably.

**Phase-1 honest limitation:** Phase-1 integrity is append-only-by-interface. It is **not** tamper-evident. The `IAuditLog` surface exposes no update or delete, and consumers cannot mutate entries through the contract — but a sufficiently privileged actor with direct store access is not cryptographically prevented from altering history. Hash-chain/WORM tamper-evidence is deliberately deferred behind the now-existing boundary until a stated trigger fires. Do not market or document Phase 1 as tamper-evident.
