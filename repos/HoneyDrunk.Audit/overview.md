# HoneyDrunk.Audit — Overview

**Sector:** Core
**Version:** TBD (initial release planned 0.1.0 with the standup scaffold)
**Framework:** .NET 10.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Audit`
**Status:** Capability decision accepted; standup not yet executed (governed by the separate standup ADR)

## Purpose

The Grid's single durable, attributable system of record for security, privileged-action, activity, system, integration, and data-change events — login attempts, authorization grants and denials, privileged-action execution, workflow starts, purchases, agent/operator decisions, integration callbacks, and entity create/update/delete records. It durably records "actor X attempted or executed action Y" and "actor X changed record Y" and serves that record back for incident reconstruction and forensics.

It is a record substrate, not a control plane and not an observability pipeline. It does not decide whether an action is allowed (that is Auth and Operator). It does not sample, aggregate, or surface health signal (that is Pulse). It owns the durable write, the append-only guarantee enforced at the interface surface, the audit-class retention, and the forensic read surface.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Audit.Abstractions` | Abstractions | `IAuditLog`, `IAuditQuery`, `AuditEntry`, and supporting category/outcome/target/change value types. Near-minimal; only the ADR-permitted `HoneyDrunk.Kernel.Abstractions` dependency for `TenantId`. |
| `HoneyDrunk.Audit.Data` | Runtime (backing slot) | Data-backed append-only `IAuditLog` writer and `IAuditQuery` reader over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`; audit-class retention wiring; DI composition. |

## Key Contracts

- `IAuditLog` — append-only write of an `AuditEntry`. No update method, no delete method. Append-only is enforced at the interface surface.
- `IAuditQuery` — time-ordered and filtered read/forensic retrieval over the durable record.
- `AuditEntry` — canonical append-only record envelope: category, event name/action, actor, target/resource, outcome, correlation id, tenant, metadata, and optional data-change details.
- `AuditCategory` / `AuditOutcome` — explicit event family and result values.
- `AuditTarget` — resource/entity/workflow/integration target identity.
- `AuditChange` — optional per-field data-change detail with redaction flag.

## Design Notes

The event taxonomy is intentionally broad but bounded: activity/security/system events and data-change events share one ledger and one `AuditEntry` envelope, but they use explicit categories and target/change value types so row mutations do not get buried as opaque context strings. Sensitive before/after data must be redacted before append; Audit is not a secret store.

The boundary rule is sharp: **the recorder is not the actor.** A control plane that can halt, gate, and trip breakers (Operator) must not also be the authoritative ledger that records whether it was right to. The durable audit channel and the observability channel (Pulse) are never merged — observability answers "is the system healthy in aggregate"; audit answers "who did what, when, against what, and was it allowed," durably and attributably.

**Phase-1 honest limitation:** Phase-1 integrity is append-only-by-interface. It is **not** tamper-evident. The `IAuditLog` surface exposes no update or delete, and consumers cannot mutate entries through the contract — but a sufficiently privileged actor with direct store access is not cryptographically prevented from altering history. Hash-chain/WORM tamper-evidence is deliberately deferred behind the now-existing boundary until a stated trigger fires. Do not market or document Phase 1 as tamper-evident.
