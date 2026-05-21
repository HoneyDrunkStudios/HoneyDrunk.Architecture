# HoneyDrunk.Audit — Boundaries

## What Audit Owns

- The durable write of a security, activity, system, integration, privileged-action, or data-change event (`IAuditLog`)
- The append-only guarantee, enforced at the interface surface — no update method, no delete method
- The audit-class retention policy — long, lossless, policy-governed; distinct from observability retention
- The forensic read surface (`IAuditQuery`) — time-ordered and filtered reads for incident reconstruction and a future tenant-facing forensics surface
- The canonical `AuditEntry` envelope — category, event name/action, actor, target/resource, outcome, correlation id, tenant, metadata, and optional data-change details

## What Audit Does NOT Own

- **Deciding whether an action is allowed** — that is HoneyDrunk.Auth (authentication, authorization) and HoneyDrunk.Operator (gates, breakers, cost guards). Audit records the outcome; it does not produce it.
- **Observability / health signal** — sampled, aggregate, retention-bounded telemetry belongs in Pulse. Audit records are not telemetry and never flow to Pulse.
- **Secret/PII redaction decisions** — emitters must redact sensitive before/after values before append. Audit stores durable records; it is not responsible for deciding which domain fields are safe to persist in clear text.
- **Tamper-evidence (Phase 1)** — hash-chain/WORM is deferred behind the boundary. Phase 1 is append-only-by-interface only.
- **An external/tenant-facing read path (Phase 1)** — the deployable tenant-facing forensics Service is deferred behind the boundary. Phase-1 reads are internal via `IAuditQuery`.
- **The store backing choice in production** — composition (which store backend, which retention policy) is a host-time concern. Downstream Nodes compile against `HoneyDrunk.Audit.Abstractions` only.

## Boundary Decision Tests

- Is this **deciding allow/deny**? → Auth or Operator.
- Is this **recording that a security/privileged/activity/system/integration event happened, durably and attributably**? → Audit.
- Is this **recording that an entity/resource was created, updated, or deleted, with actor/time/target/changed fields**? → Audit, with redaction before append.
- Is this **aggregate health/observability signal**? → Pulse.
- Is this **mutating or deleting an existing audit record**? → forbidden — the contract exposes no such method.
- Is this **a cryptographic tamper-evidence guarantee**? → deferred behind the boundary; not a Phase-1 capability.
