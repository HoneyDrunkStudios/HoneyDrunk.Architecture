---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault
labels: ["feature", "tier-2", "core", "infrastructure", "adr-0006"]
dependencies: []
adrs: ["ADR-0006"]
wave: 1
initiative: adr-0005-0006-rollout
node: honeydrunk-vault
version_bump: false
---

# Feature: Event-driven cache invalidation for `SecretCache` on `SecretNewVersionCreated`

## Summary
Add an invalidation path to `HoneyDrunk.Vault.Services.SecretCache` so Azure Event Grid webhooks on `Microsoft.KeyVault.SecretNewVersionCreated` can punch entries out of the cache within seconds of rotation — demoting TTL from primary propagation to a safety net per ADR-0006.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault`

## Motivation
ADR-0006 Tier 3 requires that rotated secrets reach running workloads in seconds, not TTL windows. The current `SecretCache` (`HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Services/SecretCache.cs`) is TTL-only. Without an invalidation path, Event Grid cannot push rotation events into a Node's in-process cache and Tier-1 / Tier-2 rotation stories are incomplete.

This must exist before per-Node migration to App Configuration + Managed Identity lands with rotation guarantees.

## Proposed Implementation
- Introduce `ISecretCacheInvalidator` on `HoneyDrunk.Vault` with at least:
  ```csharp
  void Invalidate(string secretName);
  void InvalidateAll();
  ```
- Have `SecretCache` implement it. Expose the invalidator via DI so consuming Nodes can resolve it from a webhook endpoint.
- Add a thin reusable handler (in `HoneyDrunk.Vault` or a new `HoneyDrunk.Vault.EventGrid` package) that parses the `Microsoft.KeyVault.SecretNewVersionCreated` Event Grid schema and calls `Invalidate(secretName)`. The handler should:
  - Validate Event Grid subscription validation handshake
  - Accept either the CloudEvents or legacy Event Grid schema
  - Never log the secret value; logging the secret name is permitted (invariant 8)
- Provide an endpoint-registration helper: `builder.Services.MapVaultInvalidationWebhook("/internal/vault/invalidate")` for ASP.NET Core hosts and a Functions-friendly handler wrapper for Function App hosts.
- Authenticate the webhook via (a) Event Grid source validation and (b) an internal shared secret read from `ISecretStore` by name `VaultInvalidationWebhookSecret` — not hardcoded, not env-var.

## Affected Packages
- `HoneyDrunk.Vault` (cache + invalidator contract)
- New optional: `HoneyDrunk.Vault.EventGrid` (webhook handler package)

## Versioning

**Bump:** No — packet 01 (`vault-bootstrap-extensions`) already bumped the solution to `0.3.0`. Do not touch any `<Version>` element.

Append your changes to the existing `[0.3.0]` CHANGELOG entry. Do **not** push a git tag.

| Project | Action |
|---|---|
| All solution projects | No change — already at `0.3.0` |
| `HoneyDrunk.Vault.EventGrid` | New — starts at `0.3.0` (set on creation, no bump needed) |

## NuGet Dependencies

### `HoneyDrunk.Vault` — additions to existing project
No new `PackageReference` entries. The `ISecretCacheInvalidator` interface and `SecretCache` changes are within the existing dependency surface.

### New: `HoneyDrunk.Vault.EventGrid`
| Package | Notes |
|---|---|
| `HoneyDrunk.Standards` `0.2.6` (`PrivateAssets: all`) | StyleCop + EditorConfig analyzers — required on every HoneyDrunk .NET project |
| `Azure.Messaging.EventGrid` (latest stable) | Event Grid schema parsing — `EventGridEvent`, `CloudEvent`, subscription validation handshake |
| `Microsoft.Extensions.DependencyInjection.Abstractions` (latest stable) | DI registration helpers for `MapVaultInvalidationWebhook` |
| `Microsoft.AspNetCore.Http.Abstractions` (latest stable) | `IEndpointRouteBuilder` for ASP.NET Core endpoint registration |
| ProjectRef: `HoneyDrunk.Vault` | Resolves `ISecretCacheInvalidator` and `ISecretStore` (webhook auth) |

## Boundary Check
- [x] Cache lives in Vault — invalidator belongs here too
- [x] Webhook parsing is infrastructure glue, not a transport message — no Transport dependency
- [x] No new Node-to-Node runtime dependencies

## Acceptance Criteria
- [ ] `ISecretCacheInvalidator` exists and is DI-registered alongside `SecretCache`
- [ ] `SecretCache.Invalidate(name)` removes only that entry; `InvalidateAll()` clears everything
- [ ] Next `ISecretStore.GetSecretAsync(name)` after invalidation fetches from the provider (verified by test spy)
- [ ] Event Grid handler parses `SecretNewVersionCreated` and extracts the secret name from the `objectName` field of the event data
- [ ] Event Grid subscription validation handshake returns the validation code
- [ ] Webhook rejects unauthenticated requests
- [ ] Invariant 8 verified: no test asserts against a logged secret value
- [ ] Unit tests cover: single invalidation, all-invalidation, Event Grid parse, handshake, auth reject
- [ ] XML docs reference ADR-0006 and invariant 21
- [ ] CHANGELOG updated

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

> **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006.

## Referenced ADR Decisions

**ADR-0006 (Secret Rotation and Lifecycle):** Five-tier rotation model — Azure-native rotation (≤30d), third-party rotation via `HoneyDrunk.Vault.Rotation` Function (≤90d), Event Grid cache invalidation on `SecretNewVersionCreated`, audit via Log Analytics, and deploy-blocking rotation SLAs.
- **§Tier 3:** Each Key Vault has an Event Grid subscription on `SecretNewVersionCreated`. A Function/webhook invalidates the `HoneyDrunk.Vault` cache entry. Next `ISecretStore` read fetches latest version. TTL becomes fallback, not primary mechanism. Apps must never pin to a version.

## Context
- ADR-0006 §Tier 3 — Propagation via Event Grid cache invalidation
- Invariant 21 — applications must never pin to a specific secret version
- Current cache implementation: `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Services/SecretCache.cs`
- Cache options: `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Configuration/VaultCacheOptions.cs`

## Dependencies
None — foundational for rotation.

## Labels
`feature`, `tier-2`, `core`, `infrastructure`, `adr-0006`

## Agent Handoff

**Objective:** Make `SecretCache` invalidatable by Event Grid so rotations propagate in seconds.
**Target:** HoneyDrunk.Vault, branch from `main`
**Context:**
- Goal: Tier-3 rotation propagation from ADR-0006
- Feature: Rotation lifecycle rollout
- ADRs: ADR-0006 (five-tier rotation model, Event Grid cache invalidation, rotation SLAs, audit via Log Analytics)

**Acceptance Criteria:**
- [ ] As listed above

**Dependencies:** None. Blocks all per-Node migration packets that depend on rotation-safe config.

**Constraints:**
- Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. This includes webhook debug output.
- Invariant 21 — Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006. Invalidation is what makes resolving "latest" safe.
- No Kernel runtime dependency change

**Key Files:**
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Services/SecretCache.cs`
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Configuration/VaultCacheOptions.cs`
- New: `HoneyDrunk.Vault.EventGrid/` package

**Contracts:**
- New `ISecretCacheInvalidator` public interface
- New Event Grid handler + endpoint-registration extension
