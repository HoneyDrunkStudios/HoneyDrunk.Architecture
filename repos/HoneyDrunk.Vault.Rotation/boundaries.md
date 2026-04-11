# HoneyDrunk.Vault.Rotation — Boundaries

## What Vault.Rotation Owns

- Third-party secret rotation orchestration (Tier-2)
- Writing new secret versions to target per-Node Key Vaults
- Rotation telemetry/events needed for SLA monitoring

## What Vault.Rotation Does NOT Own

- Runtime secret consumption (`HoneyDrunk.Vault` owns `ISecretStore`)
- App secret version pinning (forbidden by invariant 21)
- Cross-repo architecture decisions beyond ADR-0006 scope

## Status

Scaffolding in progress; implementation details deferred to scaffold packet.
