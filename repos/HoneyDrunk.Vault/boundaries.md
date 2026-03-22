# HoneyDrunk.Vault — Boundaries

## What Vault Owns

- Unified secret access via `ISecretStore`
- Multi-provider support with automatic fallback (registration order priority)
- In-memory caching with configurable TTL
- Resilience policies (retry, circuit breaker)
- Provider Slot pattern (`ISecretProvider` interface)
- Secure telemetry (never logs secret values)
- `SecretIdentifier`, `SecretValue`, `VaultResult<T>` models

## What Vault Does NOT Own

- **Secret storage backends** — Provider packages own Azure/AWS/File specifics
- **Application-level configuration** — Vault provides `IConfigProvider`, apps define their config models
- **Authentication** — Token management belongs in Auth. Vault stores keys, Auth validates tokens.
- **Encryption** — Vault retrieves secrets, not encrypts/decrypts data at rest
