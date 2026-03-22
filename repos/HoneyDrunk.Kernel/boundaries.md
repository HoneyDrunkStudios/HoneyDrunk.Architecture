# HoneyDrunk.Kernel — Boundaries

## What Kernel Owns

- Three-tier context model (Grid → Node → Operation)
- Lifecycle orchestration (startup, shutdown, health, readiness)
- Configuration foundation (hierarchical scoping)
- Agent interop (serialization, execution contexts)
- Telemetry hooks (enrichers, log scopes)
- Identity grammar (strongly-typed ID primitives)
- Service discovery primitives (Node descriptors, capabilities, manifests)

## What Kernel Does NOT Own

- **BCL wrappers** — No `IClock`, `IIdGenerator`, `ILogSink`. Use BCL directly.
- **Transport** — Messaging, envelopes, middleware belong in HoneyDrunk.Transport.
- **Secrets** — Secret access belongs in HoneyDrunk.Vault.
- **HTTP/REST** — Response shaping, exception mapping belong in HoneyDrunk.Web.Rest.
- **Data access** — Repositories, unit of work, EF Core belong in HoneyDrunk.Data.
- **Authentication** — Token validation, authorization belong in HoneyDrunk.Auth.
- **Telemetry backends** — Sink implementations belong in HoneyDrunk.Pulse.
- **Business logic** — Kernel is infrastructure, not domain logic.

## Boundary Decision Tests

Before adding something to Kernel, ask:

1. Is this a **Grid-specific** primitive that other Nodes need? → Kernel
2. Is this a **general-purpose utility** available in BCL? → Use BCL directly
3. Does this belong to a specific **protocol or provider**? → Downstream Node
4. Would this create a **non-trivial dependency** in Kernel.Abstractions? → Don't add it
