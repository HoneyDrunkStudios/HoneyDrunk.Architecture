# HoneyDrunk.Transport — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **Kernel** | `HoneyDrunk.Kernel.Abstractions` | `IGridContext`, `CorrelationId`, context mappers |

## Downstream Consumers

| Node | What It Uses | How |
|------|-------------|-----|
| **Web.Rest** | `ITransportEnvelope` | Maps envelope to ApiResult |
| **Data** | `ITransportPublisher` | Outbox dispatcher publishes via Transport |
| **Notify** | Transport patterns | Follows envelope and middleware patterns |
