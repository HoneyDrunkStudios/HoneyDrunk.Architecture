# HoneyDrunk.Auth — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **Kernel** | `HoneyDrunk.Kernel` | Telemetry, health, lifecycle hooks |
| **Vault** | `HoneyDrunk.Vault` | Signing key retrieval via `ISecretStore` |
| **Audit** | `HoneyDrunk.Audit.Abstractions` | Emits durable token-validation and authorization decisions through `IAuditLog`; host composes the backing store. Auth does not depend on `HoneyDrunk.Audit.Data`. |

## Downstream Consumers

| Node | What It Uses | How |
|------|-------------|-----|
| **Web.Rest** | `IAuthenticatedIdentityAccessor` | Shapes 401/403 responses |
