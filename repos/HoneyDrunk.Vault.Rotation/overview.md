# HoneyDrunk.Vault.Rotation — Overview

**Sector:** Core  
**Version:** TBD  
**Framework:** TBD  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Vault.Rotation`  
**Status:** Scaffolding in progress  

## Purpose

Tier-2 rotation Function that rotates third-party provider secrets into per-Node Key Vaults on schedule, as defined by ADR-0006.

## Scope boundary — external-SaaS PAT rotation is out of scope (ADR-0083 D1)

Vault.Rotation rotates third-party secrets **the Grid issues to itself via the provider's API**, written into Azure Key Vault (ADR-0006 Tier 2). It does **not** rotate external-SaaS CI/ops credentials — `SONAR_TOKEN`, `NUGET_API_KEY`, GitHub PATs, the OpenClaw webhook signing secret, and similar — which live as GitHub org secrets bound to operator accounts, not in any `kv-hd-*` vault. Those are governed by ADR-0083 (manual rotation with a disciplined inventory + tracking), not by this Node. The sensitive inventory carries a single summary row for the Vault contents this Node governs (`Rotates: automated-elsewhere (ADR-0006)`). See [`infrastructure/reference/sensitive-inventory.md`](../../infrastructure/reference/sensitive-inventory.md).

## References

- [ADR-0006: Secret Rotation and Lifecycle](../../adrs/ADR-0006-secret-rotation-and-lifecycle.md)
- [ADR-0005: Configuration and Secrets Strategy](../../adrs/ADR-0005-configuration-and-secrets-strategy.md)
- [ADR-0083: Sensitive Inventory and External-SaaS Credential Rotation](../../adrs/ADR-0083-external-saas-credential-rotation.md) — the boundary above
