# HoneyDrunk.Vault.Rotation — Invariants

1. Rotator writes secrets to Key Vault and never emits secret values to logs/traces.
2. Rotator identity uses Azure RBAC; legacy access policies are forbidden.
3. Rotator supports SLA enforcement targets from ADR-0006 Tier-2.
4. Consumers resolve latest secret version via `ISecretStore`; rotator never requires version pinning.

## Status

Scaffolding in progress; invariants will be expanded with implementation packet.
