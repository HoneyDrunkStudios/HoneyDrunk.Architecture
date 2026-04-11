# HoneyDrunk.Vault.Rotation — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **HoneyDrunk.Kernel** | Runtime patterns | Standard Node runtime dependency |
| **HoneyDrunk.Vault** | `ISecretStore` and vault workflows | Rotator bootstrap secret access |

## Downstream Touchpoints

| Node | What It Receives |
|------|-------------------|
| **Deployable Nodes** | Rotated third-party secrets in per-Node Key Vaults |

## Status

Scaffolding in progress; endpoint and invalidation contracts tracked by ADR-0006 rollout.
