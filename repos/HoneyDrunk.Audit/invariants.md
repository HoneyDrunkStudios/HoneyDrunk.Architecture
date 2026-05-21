# HoneyDrunk.Audit — Invariants

Audit-specific invariants (supplements `constitution/invariants.md`).

1. **Audit.Abstractions stays near-minimal and carries only the ADR-permitted Kernel abstraction dependency.**
   `HoneyDrunk.Kernel.Abstractions` is allowed for `TenantId`; Data/Vault/Pulse/Kernel-runtime references live outside Abstractions.

2. **`IAuditLog` is append-only at the interface surface.**
   The contract exposes no update method and no delete method. Append-only is enforced at the interface, not only at the storage layer. Consumers that need retention or archival work off `IAuditQuery`, never by mutating entries.

3. **The recorder is not the actor.**
   Audit records; it never decides whether an action is allowed and never halts, gates, or trips breakers. Those are Auth and Operator concerns.

4. **The durable audit channel and the observability channel are never merged.**
   Auditable security, action, and data-change events are emitted to the Audit substrate via `IAuditLog` on a durable channel separate from observability telemetry. Audit *records* are not telemetry and never flow to Pulse. Audit emits its own operational telemetry (write/query latency, throughput) which Pulse observes one-way — Audit has no runtime dependency on Pulse.

5. **Audit-class retention is distinct from observability retention.**
   Observability retention is short and sampling-tolerant; audit retention is long, lossless, and policy-governed. The two regimes are not shared and not interchangeable. The retention value is sourced from App Configuration via Vault's config provider, never hardcoded.

6. **Phase 1 is append-only-by-interface, NOT tamper-evident.**
   A sufficiently privileged actor with direct store access is not cryptographically prevented from altering history at the storage layer. Hash-chain/WORM tamper-evidence is deferred behind the boundary until a stated trigger fires. The store must never be documented or marketed as tamper-evident at Phase 1.

7. **Downstream Nodes compile only against `HoneyDrunk.Audit.Abstractions`.**
   No runtime dependency on `HoneyDrunk.Audit.Data` in production composition. Composition is a host-time concern.

8. **Sensitive data-change details are redacted before append.**
   `AuditChange` may carry before/after values, but emitters must redact secrets, credentials, tokens, regulated data, and sensitive PII before calling `IAuditLog`. Audit is durable and queryable; it is not a secret store.

_Constitutional invariant 44 (the audit-emission boundary invariant, in `constitution/invariants.md`) is the Grid-level rule this Node exists to enforce. The Audit-specific downstream-coupling and contract-shape-canary invariants are introduced by the standup ADR and assigned their final constitutional numbers when that standup initiative lands._

## Status

Capability/decision accepted. Standup scaffold (repo, packages, contracts, CI, store, managed identity) governed by the separate standup ADR — a distinct initiative not yet executed.
