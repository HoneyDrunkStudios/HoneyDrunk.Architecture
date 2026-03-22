# HoneyDrunk.Data — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **Kernel** | `HoneyDrunk.Kernel` | Tenant identity, correlation tagging |
| **Transport** | `HoneyDrunk.Transport` | Outbox dispatcher publishes via `ITransportPublisher` |
