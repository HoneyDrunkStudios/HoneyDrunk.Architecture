# HoneyDrunk.Vault — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **Kernel** | `HoneyDrunk.Kernel` | Lifecycle hooks, health, telemetry |

## Downstream Consumers

| Node | What It Uses | How |
|------|-------------|-----|
| **Auth** | `ISecretStore` | Retrieves JWT signing keys |
| **Pulse** | `ISecretStore` | Retrieves sink credentials |
| **Service Nodes** | `ISecretStore`, `IConfigProvider` | Application-level secret and config access |
