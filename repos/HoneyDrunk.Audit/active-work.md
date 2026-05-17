# HoneyDrunk.Audit — Active Work

**Last Updated:** 2026-05-17
**Status:** Capability decision accepted; standup pending

## Current

- Architecture-side acceptance of the capability/decision (this PR — catalog registration, sectors row, ADR index flip, ADR-0018 additive amendment, context folder, trackers)

## Next (Standup — separate initiative, governed by the standup ADR)

- Create the `HoneyDrunk.Audit` public GitHub repo
- Scaffold `HoneyDrunk.Audit.slnx` with `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data` and matching `.Tests` projects
- Author the three frozen contracts (`IAuditLog`, `IAuditQuery`, `AuditEntry`)
- Data-backed append-only store over `IRepository`/`IUnitOfWork`; audit-class retention hook (App Config-sourced)
- The Node's own managed identity (per-Node isolation)
- In-memory `IAuditLog`/`IAuditQuery` fixture (internal to the test project)
- Contract-shape canary on all three contracts in CI

## Deferred (behind the now-existing boundary — each gated on a stated trigger)

- Hash-chain / WORM tamper-evidence — trigger: a compliance, customer-contract, or incident-class requirement for provable tamper-evidence
- The deployable tenant-facing forensics read Service — trigger: a concrete tenant-facing requirement to expose forensic reads externally; built over the existing `IAuditQuery` with no contract change

## Emitter Wiring (separate follow-up packets, governed by the standup ADR)

- HoneyDrunk.Auth wired as the first emitter (additive to its existing OTel traces; identity-out-of-traces invariant untouched)
- HoneyDrunk.Operator reconciled from owner to consumer/emitter of the relocated contracts
