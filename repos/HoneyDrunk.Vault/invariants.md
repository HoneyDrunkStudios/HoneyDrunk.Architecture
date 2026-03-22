# HoneyDrunk.Vault — Invariants

1. **Secret values never appear in logs, traces, or telemetry.** Only identifiers.
2. **Vault is the only source of secrets.** No Node reads secrets from env vars or config files directly.
3. **Provider fallback order matches registration order.** First registered provider is tried first.
4. **`GetSecretAsync()` throws `SecretNotFoundException` when not found.** Use `TryGetSecretAsync()` for non-throwing access.
5. **Provider errors are wrapped in `VaultOperationException`.** Consumers see consistent error types.
6. **Cache keys are secret names.** Cache invalidation is per-secret-name.
