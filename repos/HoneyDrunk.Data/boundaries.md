# HoneyDrunk.Data — Boundaries

## What Data Owns
- Repository contracts and EF Core implementations
- Unit of work pattern with DbContext coordination
- Tenant identity access (`ITenantAccessor` via Kernel context)
- Correlation tagging in SQL commands
- Transactional outbox with lease-based concurrency
- Outbox dispatcher with retry and exponential backoff

## What Data Does NOT Own
- **Business entities** — Applications define their own entities
- **Migration authoring** — Applications write their own EF migrations
- **Transport publishing** — Outbox dispatcher uses Transport to publish, but Transport owns messaging
- **Tenant resolution strategy** — Applications must implement `ITenantResolutionStrategy`
