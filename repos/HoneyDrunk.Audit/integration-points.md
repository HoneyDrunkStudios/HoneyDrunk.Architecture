# HoneyDrunk.Audit — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **HoneyDrunk.Kernel** | `IGridContext`, lifecycle hooks, health/readiness, `ITelemetryActivityFactory` (`HoneyDrunk.Kernel`) | Every audit write is context-aware; an audit entry without correlation and tenant is unattributable, which defeats the substrate's purpose. Audit emits its own operational telemetry via Kernel's telemetry factory. |
| **HoneyDrunk.Data** | `IRepository`, `IUnitOfWork` (`HoneyDrunk.Data.Abstractions`) | The append-only write/read path and the audit-class retention both sit on Data's transactional surface — the same surface Operator's audit log already sat on before the relocation. Data-layer emitters may later record create/update/delete audit events through `IAuditLog` when redaction policy is explicit. |

## Telemetry (no runtime dependency)

| Node | Direction | Notes |
|------|-----------|-------|
| **HoneyDrunk.Pulse** | Audit emits → Pulse observes | One-way by contract. Audit emits operational telemetry (write latency, query latency, append throughput). Audit has **no runtime dependency on Pulse**. Audit *records* are not telemetry and never flow to Pulse — the durable audit channel and the observability channel stay separate. |

## Downstream Consumers

| Node | Contract Used | Status |
|------|---------------|--------|
| **HoneyDrunk.Auth** | `IAuditLog` (`HoneyDrunk.Audit.Abstractions`) | Wired in Auth PR #24 as the first emitter. Records token-validation outcomes and authorization grants/denials additively to existing OTel traces, on a separate durable channel. Auth's identity-out-of-traces invariant is untouched. |
| **HoneyDrunk.Operator** | `IAuditLog`, `IAuditQuery` (`HoneyDrunk.Audit.Abstractions`) | Reclassified from owner to consumer/emitter. Continues recording its AI-runtime decisions by emitting `AuditEntry` against the `IAuditLog` it now consumes. |
| **Future Data-change emitters** | `IAuditLog` (`HoneyDrunk.Audit.Abstractions`) | Record entity/resource create/update/delete events with `AuditCategory.DataChange`, `AuditTarget`, and redacted `AuditChange` details. |

## Boundary Notes

- Downstream Nodes consume `HoneyDrunk.Audit.Abstractions` only — never the `HoneyDrunk.Audit.Data` runtime, never the store directly. Composition (store backing, retention policy) is a host-time concern.
- Audit runs under its **own dedicated managed identity**, distinct from Auth's and Operator's. The recorder authenticating as itself — not borrowing an emitter's identity — keeps the audit write path attributable and keeps the recorder/actor trust boundary intact at the infrastructure layer, not only at the contract layer.
- Key Vault and App Configuration access for the audit-class retention configuration is scoped to Audit's own identity. The retention value is sourced from App Configuration, never hardcoded.
- Before/after values in data-change events are redacted by the emitter before append; Audit persists what it is given and is not a secret store.
