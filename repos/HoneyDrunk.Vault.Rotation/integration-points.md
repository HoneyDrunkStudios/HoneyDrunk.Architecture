# HoneyDrunk.Vault.Rotation — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **HoneyDrunk.Kernel** | Runtime patterns | Standard Node runtime dependency |
| **HoneyDrunk.Vault** | `ISecretStore` and vault workflows | Rotator bootstrap secret access |

## Downstream Touchpoints (Operational — not package dependencies)

The rotator holds Azure RBAC write scope on each Node's Key Vault and rotates third-party secrets in place. This is an **infrastructure relationship only**; Vault.Rotation does not take a code or package dependency on these Nodes.

| Target Node | Key Vault (example, dev) | Relationship |
|-------------|--------------------------|--------------|
| **HoneyDrunk.Auth** | `kv-hd-auth-dev` | Writes rotated secrets |
| **HoneyDrunk.Web.Rest** | `kv-hd-webrest-dev` | Writes rotated secrets |
| **HoneyDrunk.Data** | `kv-hd-data-dev` | Writes rotated secrets |
| **HoneyDrunk.Notify** | `kv-hd-notify-dev` | Writes rotated secrets |
| **HoneyDrunk.Pulse** | `kv-hd-pulse-dev` | Writes rotated secrets |
| **HoneyDrunk.Actions** | `kv-hd-actions-dev` | Writes rotated secrets |
| **HoneyDrunk.Studios** | `kv-hd-studios-dev` | Writes rotated secrets |

> These relationships are **not** captured in `catalogs/relationships.json` because they are operational write-scopes, not code/package dependencies. See ADR-0006 for the rotation scope model.

## Status

Scaffolding in progress; endpoint and invalidation contracts tracked by ADR-0006 rollout.
