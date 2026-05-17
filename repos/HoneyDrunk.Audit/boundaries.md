# HoneyDrunk.Audit — Boundaries

## What Audit Owns

- The durable write of a security or privileged-action event (`IAuditLog`)
- The append-only guarantee, enforced at the interface surface — no update method, no delete method
- The audit-class retention policy — long, lossless, policy-governed; distinct from observability retention
- The forensic read surface (`IAuditQuery`) — time-ordered and filtered reads for incident reconstruction and a future tenant-facing forensics surface
- The canonical `AuditEntry` shape — actor, action, context, outcome, correlation id, tenant

## What Audit Does NOT Own

- **Deciding whether an action is allowed** — that is HoneyDrunk.Auth (authentication, authorization) and HoneyDrunk.Operator (gates, breakers, cost guards). Audit records the outcome; it does not produce it.
- **Observability / health signal** — sampled, aggregate, retention-bounded telemetry belongs in Pulse. Audit records are not telemetry and never flow to Pulse.
- **Tamper-evidence (Phase 1)** — hash-chain/WORM is deferred behind the boundary. Phase 1 is append-only-by-interface only.
- **An external/tenant-facing read path (Phase 1)** — the deployable tenant-facing forensics Service is deferred behind the boundary. Phase-1 reads are internal via `IAuditQuery`.
- **The store backing choice in production** — composition (which store backend, which retention policy) is a host-time concern. Downstream Nodes compile against `HoneyDrunk.Audit.Abstractions` only.

## Boundary Decision Tests

- Is this **deciding allow/deny**? → Auth or Operator.
- Is this **recording that a security/privileged event happened, durably and attributably**? → Audit.
- Is this **aggregate health/observability signal**? → Pulse.
- Is this **mutating or deleting an existing audit record**? → forbidden — the contract exposes no such method.
- Is this **a cryptographic tamper-evidence guarantee**? → deferred behind the boundary; not a Phase-1 capability.
