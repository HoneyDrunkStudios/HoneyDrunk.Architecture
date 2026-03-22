# HoneyDrunk.Kernel — Integration Points

How other Nodes integrate with Kernel.

## Downstream Consumers

| Node | What It Uses | How |
|------|-------------|-----|
| **Transport** | `IGridContext`, `CorrelationId`, context mappers | Propagates GridContext in transport envelopes |
| **Vault** | Lifecycle hooks, health contributors, telemetry | Registers startup hooks for provider validation |
| **Auth** | Telemetry, health, lifecycle | Registers signing key preload as startup hook |
| **Web.Rest** | `IOperationContext.CorrelationId` | Writes correlation ID to response headers |
| **Data** | `ITenantAccessor`, correlation tagging | Tags SQL commands with CorrelationId |
| **Pulse** | `ITraceEnricher`, Grid context | Enriches OpenTelemetry spans with Grid metadata |
| **Notify** | Context propagation | Carries GridContext through notification pipeline |

## Registration Pattern

```csharp
// Every Node that uses Kernel must call this first
builder.Services.AddHoneyDrunkNode(nodeDescriptor);

// Then register Node-specific services
builder.Services.AddHoneyDrunkTransportCore(...);
builder.Services.AddVault(...);
```

## Context Flow

```
HTTP Request → HttpContextMapper.Extract() → GridContext
  → IOperationContext (scoped)
  → Transport publish → MessagingContextMapper.Embed() → Envelope Headers
  → Consumer → MessagingContextMapper.Extract() → new GridContext (child)
```
