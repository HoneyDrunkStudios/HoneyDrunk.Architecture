# HoneyDrunk.Auth — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **Kernel** | `HoneyDrunk.Kernel` | Telemetry, health, lifecycle hooks |
| **Vault** | `HoneyDrunk.Vault` | Signing key retrieval via `ISecretStore` |

## Downstream Consumers

| Node | What It Uses | How |
|------|-------------|-----|
| **Web.Rest** | `IAuthenticatedIdentityAccessor` | Shapes 401/403 responses |
