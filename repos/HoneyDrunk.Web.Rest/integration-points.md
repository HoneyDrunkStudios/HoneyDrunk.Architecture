# HoneyDrunk.Web.Rest — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **Kernel** | `HoneyDrunk.Kernel.Abstractions` | `IOperationContext.CorrelationId` |
| **Transport** | `HoneyDrunk.Transport` | `ITransportEnvelope` to `ApiResult` mapping |
| **Auth** | `HoneyDrunk.Auth` | `IAuthenticatedIdentityAccessor` for 401/403 shaping |
