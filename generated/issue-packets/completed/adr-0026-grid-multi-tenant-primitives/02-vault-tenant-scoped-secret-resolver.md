---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault
labels: ["feature", "tier-2", "core", "docs", "adr-0026", "wave-2"]
dependencies: ["Kernel#NN — Grid multi-tenant primitives (packet 01) — Wave 1 lead"]
adrs: ["ADR-0026"]
wave: 2
initiative: adr-0026-grid-multi-tenant-primitives
node: honeydrunk-vault
---

# Feature: Per-tenant secret scoping pattern + TenantScopedSecretResolver in HoneyDrunk.Vault

## Summary
Add `HoneyDrunk.Vault/docs/Tenancy.md` documenting the `tenant-{tenantId}-{secretName}` per-tenant scoping convention. Add `TenantScopedSecretResolver` to the `HoneyDrunk.Vault` runtime package — a thin composition layer over `ISecretStore` that resolves tenant-scoped secrets and falls back to the Node's standard path when `TenantId.IsInternal` is true. **No contract change to `ISecretStore`.** Bump Vault to its next minor version.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault`

## Motivation
PDR-0002 (Notify Cloud) needs per-tenant secret scoping so a Pro-tier customer can BYO a Resend key, stored in the Notify Cloud vault under a tenant-scoped slot. ADR-0026 D5 commits to a **naming convention plus a thin resolver wrapper**, not a change to `ISecretStore`'s contract — tenancy is a usage pattern, symmetric with how Vault treats environment scoping today.

This packet ships step 2 of ADR-0026 D9 ordering. It depends on the Kernel packet (#01) for the typed `TenantId` and the `IsInternal` predicate; without those the resolver cannot short-circuit on internal traffic.

## Proposed Implementation

### A. `HoneyDrunk.Vault/docs/Tenancy.md` (new)

Author a docs page describing the per-tenant secret scoping convention. Match the style of the existing `docs/` files (Architecture.md, AzureKeyVault.md, etc.). Sections:

1. **Why tenant scoping is a usage pattern, not a contract.** `ISecretStore` stays a primitive. Tenancy is a composition pattern Nodes opt into. Symmetric with environment scoping. Nodes that have no per-tenant secrets ignore the resolver entirely.

2. **Naming convention.** Within a Node's vault `kv-hd-{service}-{env}` (per Invariant 17: One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}` with Azure RBAC), per-tenant secrets are named `tenant-{tenantId}-{secretName}`. Examples (use plausible but obviously-fake ULIDs in the docs — never copy a real production tenant value):
   - `tenant-01H2X3Y4Z5...XYZ-resend-api-key` — Pro-tier tenant's BYO Resend key in `kv-hd-notify-cloud-{env}`.
   - `tenant-01H2X3Y4Z5...XYZ-twilio-auth-token` — same tenant's BYO Twilio token.
   - `resend-api-key` (no `tenant-` prefix) — the Node-managed shared key used by `Internal`-tenant traffic and by Free/Starter tenants who haven't set their own.

3. **Length budget.** ULIDs are 26 characters. Combined with the `tenant-` prefix (7 chars) and the secret-name suffix, they fit within Azure Key Vault's 127-character secret-name limit comfortably (94 characters left for the suffix). Document this so authors don't invent shorter "tenant id" representations.

4. **Internal default.** `TenantScopedSecretResolver.ResolveAsync(TenantId.Internal, secretName, ...)` short-circuits to the shared secret name (`secretName`, no `tenant-` prefix). Internal callers see no behavior change.

5. **Fallback semantics.** For non-internal tenants, the resolver tries `tenant-{tenantId}-{secretName}` first; if absent, it falls back to `secretName` (the shared key). This is the explicit behavior — Free/Starter tenants share the Node's managed key. Pro-tier tenants who set their own override the shared key by populating the `tenant-{tenantId}-{secretName}` slot.

6. **Invariants the pattern honors.** Inline the relevant text:
   - Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced (Vault telemetry rule).
   - Vault is the only source of secrets — no Node reads tenant-scoped secrets directly from provider SDKs.
   - Applications must never pin to a specific secret version. The resolver passes through to `ISecretStore` which always resolves the latest version.
   - Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.
   - Per-secret rotation tier applies as today: a tenant-scoped Resend key is a Tier 2 third-party secret with the same ≤90-day rotation SLA.

   **Telemetry of tenant-scoped secret names.** Vault telemetry traces secret IDENTIFIERS (allowed by Invariant 8 — identifiers are not values). Tenant-scoped identifiers contain the tenant ULID — a customer-identity bytes-marker — embedded in the secret name (e.g., a trace span attribute reading `secret.identifier="tenant-01H2X3Y4Z5...XYZ-resend-api-key"`). This is intentional and acceptable in the v1 design because:
     - **(a) Vault telemetry is internal-only.** Vault diagnostic settings route to the shared HoneyDrunk Log Analytics workspace; no customer-facing dashboard surfaces Vault telemetry directly.
     - **(b) Operational correlation requires the tenant ULID.** Vault rotation tooling (`HoneyDrunk.Vault.Rotation`) and on-call investigation need to correlate rotations and access patterns to specific tenants — the tenant ULID in the identifier is the join key that enables that.
     - **(c) Customer-facing dashboards never expose Vault telemetry directly.** Pulse customer-facing surfaces (when they exist) consume `BillingEvent`s and tenant-scoped trace tags — they do not surface Vault diagnostic settings.
     - **(d) Tenant ULIDs are not personally identifying on their own.** They are opaque IDs minted by `TenantId.NewId()`; mapping a ULID to a customer name requires access to the tenant onboarding store, which itself has access controls.

   If a future requirement emerges to redact tenant ULIDs in Vault telemetry traces (e.g., a stricter privacy posture for an enterprise customer or a regulatory regime change), the redaction pattern lives in `HoneyDrunk.Vault/Telemetry/` and is non-blocking for v1. The redaction would be a transformation applied to span attributes before sink emission — out of scope for this packet.

7. **Worked example.** Walk through "Pro-tier tenant `01H2X3...` provisions their own Resend key for Notify Cloud's `dev` environment":
   - Operator sets the secret `tenant-01H2X3...-resend-api-key` in `kv-hd-notify-cloud-dev`.
   - Notify Cloud's intake layer resolves the key via `TenantScopedSecretResolver.ResolveAsync(tenantId, "resend-api-key", ct)`.
   - The resolver returns the tenant-scoped value because the slot is populated.
   - Pro-tier tenant's Resend usage hits their account, not the shared key.
   - If the tenant later removes the slot, the resolver's fallback returns the Node's shared key automatically — no Notify Cloud code change required.

8. **What this is NOT.** Does not change `ISecretStore`. Does not change the existing `IConfigProvider`, `IVaultClient`, or `ISecretProvider` surfaces. Does not introduce a new provider package. Does not change rotation tier handling (`HoneyDrunk.Vault.Rotation` continues to write rotated values into the Node's vault under whatever name the rotator wrote them — tenant-scoped rotation, if it ever lands, is a separate ADR).

### B. `TenantScopedSecretResolver` in the `HoneyDrunk.Vault` runtime

The resolver composes the real `HoneyDrunk.Vault.Abstractions.ISecretStore` contract:

```csharp
public interface ISecretStore
{
    Task<SecretValue> GetSecretAsync(SecretIdentifier identifier, CancellationToken cancellationToken = default);
    Task<VaultResult<SecretValue>> TryGetSecretAsync(SecretIdentifier identifier, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<SecretVersion>> ListSecretVersionsAsync(string secretName, CancellationToken cancellationToken = default);
}
```

Behavioral contract per Vault: `GetSecretAsync` throws `SecretNotFoundException` (or Vault's equivalent) on miss; `TryGetSecretAsync` returns a `VaultResult<SecretValue>` whose `IsSuccess`/`Value` discriminate hit vs. miss. `SecretValue` is a record carrying `Identifier`, `Value` (string), and `Version`. `SecretIdentifier` has a single-string-name constructor (`new SecretIdentifier("resend-api-key")`).

The resolver mirrors ADR-0026 D5 pseudocode, with production-grade hardening (input validation, `ConfigureAwait(false)`, XML docs):

```csharp
namespace HoneyDrunk.Vault.Tenancy;

using HoneyDrunk.Kernel.Abstractions.Identity;
using HoneyDrunk.Vault.Abstractions;
using HoneyDrunk.Vault.Models;

/// <summary>
/// Composes <see cref="ISecretStore"/> to resolve secrets that may be tenant-scoped
/// or shared. Internal-tenant callers receive the shared secret directly.
/// Non-internal tenants try the tenant-scoped slot first and fall back to the
/// shared slot when the tenant has not provisioned its own value. This is a
/// usage pattern over the existing ISecretStore contract — it does not change
/// the contract, and it does not introduce a new provider.
/// </summary>
public sealed class TenantScopedSecretResolver(ISecretStore secretStore)
{
    public async Task<SecretValue> ResolveAsync(
        TenantId tenantId,
        string secretName,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(secretName);

        if (tenantId.IsInternal)
        {
            return await secretStore.GetSecretAsync(
                new SecretIdentifier(secretName),
                cancellationToken).ConfigureAwait(false);
        }

        // Try tenant-scoped first; fall back to shared if absent.
        // Fallback is the explicit behavior — Free/Starter tenants share the Node's
        // managed key; Pro-tier tenants override by populating the tenant-scoped slot.
        var tenantScoped = await secretStore.TryGetSecretAsync(
            new SecretIdentifier($"tenant-{tenantId}-{secretName}"),
            cancellationToken).ConfigureAwait(false);

        return tenantScoped.IsSuccess
            ? tenantScoped.Value!
            : await secretStore.GetSecretAsync(
                new SecretIdentifier(secretName),
                cancellationToken).ConfigureAwait(false);
    }
}
```

Compose against the real shapes shown above — if the actual `VaultResult<T>` exposes a different success predicate name (e.g. `Succeeded` instead of `IsSuccess`) or `SecretIdentifier` requires a factory call instead of a direct ctor, adapt minimally to match the on-disk types in `HoneyDrunk.Vault/Models/`. The shape above matches what ADR-0026 D5 was reconciled against.

DI extension (e.g., in `HoneyDrunk.Vault/Extensions/`): add an `AddTenantScopedSecretResolver()` method that registers the resolver as a scoped or singleton service (singleton is safe — the resolver holds no per-request state and `ISecretStore` is itself a long-lived service).

### C. Tests

Add tests in `HoneyDrunk.Vault.Tests` (or whichever test project the runtime package uses):

1. **Internal-tenant short-circuit.** With an `InMemorySecretStore` containing only `resend-api-key`, calling `resolver.ResolveAsync(TenantId.Internal, "resend-api-key", default)` returns the shared value. The `InMemorySecretStore` records that no `tenant-*` lookup was attempted.

2. **Tenant-scoped slot present.** With `InMemorySecretStore` containing `tenant-01HZ...-resend-api-key` and `resend-api-key` (different values), calling `resolver.ResolveAsync(new TenantId("01HZ..."), "resend-api-key", default)` returns the tenant-scoped value, NOT the shared one.

3. **Tenant-scoped slot absent — fallback.** With `InMemorySecretStore` containing only `resend-api-key`, calling `resolver.ResolveAsync(new TenantId("01HZ..."), "resend-api-key", default)` returns the shared value via fallback.

4. **Both absent — propagate.** With an empty `InMemorySecretStore`, calling `resolver.ResolveAsync(new TenantId("01HZ..."), "resend-api-key", default)` throws `SecretNotFoundException` (or whatever Vault's missing-secret exception type is — verify in `HoneyDrunk.Vault/Exceptions/`).

5. **Logging discipline.** Verify (via a test logger or observation hook) that no secret value appears in any log emitted by the resolver. Only secret names / identifiers are logged. This enforces Invariant 8 at the resolver layer.

### D. Coordinated version bump

Per Invariant 27, every project in the `HoneyDrunk.Vault` solution moves to the same new version. Vault is currently at `0.3.0` per the on-disk `HoneyDrunk.Vault.csproj` (verified at packet authoring). Bump to `0.4.0` (minor — additive new public type + new docs page, no breaking change to `ISecretStore`). Update every `.csproj` in the solution to `0.4.0`. Repo-level `CHANGELOG.md` gets a new `0.4.0` entry. Per-package `CHANGELOG.md` for `HoneyDrunk.Vault/` is updated to describe the new resolver and Tenancy docs. Provider-package `CHANGELOG.md`s (`HoneyDrunk.Vault.Providers.AzureKeyVault/`, `Aws/`, `File/`, `Configuration/`, `InMemory/`, `AppConfiguration/`) and `HoneyDrunk.Vault.EventGrid/` get NO entries — they have no actual code changes and per Invariant 12 alignment-only bumps must not add noise entries.

### E. README touch-up

Update `HoneyDrunk.Vault/README.md` (the per-package README, next to the `.csproj`) to add a "Tenant-Scoped Secrets" subsection that links to the new `docs/Tenancy.md`. Do NOT include the ADR ID in the README per the no-ADR-in-docs convention.

If the repo-root `README.md` enumerates docs, link the new page from there too.

## Affected Files

- `HoneyDrunk.Vault/docs/Tenancy.md` (new)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Tenancy/TenantScopedSecretResolver.cs` (new)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/` — `AddTenantScopedSecretResolver()` extension (locate the existing DI extension file at execution; add the extension there or in a new `TenancyServiceCollectionExtensions.cs`)
- Test project (`HoneyDrunk.Vault.Tests` or equivalent) — five new tests per section C
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault.csproj` — version bump to `0.4.0`
- Every other `.csproj` in the Vault solution — version bump to `0.4.0` (Invariant 27)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/CHANGELOG.md` (per-package) — actual changes documented
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/README.md` (per-package) — link to docs/Tenancy.md
- Repo-root `CHANGELOG.md` — new `0.4.0` entry
- Repo-root `README.md` — link to docs/Tenancy.md if the README indexes docs
- `HoneyDrunk.Kernel.Abstractions` PackageReference in Vault's `.csproj` — bump to the version produced by packet 01 (likely `0.5.0` — verify against packet 01's actual published version)

## NuGet Dependencies

- `HoneyDrunk.Kernel.Abstractions` — already referenced; bump the version constraint to the version produced by packet 01 (target `0.5.0`).

No other `<PackageReference>` additions. The resolver is a pure composition layer; it brings no new third-party deps.

## Boundary Check
- [x] All edits in `HoneyDrunk.Vault`. Routing rule "vault, secret, ISecretStore, key vault, ..." → `HoneyDrunk.Vault` matches.
- [x] No change to `ISecretStore`. Tenancy is layered ON TOP via composition. Vault's contract surface is unchanged.
- [x] No change to provider packages. The resolver works against any `ISecretStore` implementation (Azure Key Vault, AWS, File, InMemory) without provider-side changes.
- [x] Honors Vault's existing invariants: secret values never logged; Vault remains the only source of secrets; no version pinning (resolver passes through to `ISecretStore`'s latest-version semantics).
- [x] `HoneyDrunk.Vault` already depends on `HoneyDrunk.Kernel.Abstractions` (per `relationships.json` `consumes_detail`). No new transitive runtime dependencies on consumers (Invariant 2 holds).

## Acceptance Criteria

- [ ] `HoneyDrunk.Vault/docs/Tenancy.md` exists and follows the existing `docs/` style (matches `Architecture.md`, `AzureKeyVault.md` shape).
- [ ] Tenancy.md documents the `tenant-{tenantId}-{secretName}` naming convention with three concrete worked examples (Resend, Twilio, shared fallback).
- [ ] Tenancy.md documents the 127-character Key Vault secret-name budget and confirms the `tenant-{ULID}-{name}` form fits.
- [ ] Tenancy.md documents the Internal-tenant short-circuit (Internal → shared name, no `tenant-` prefix).
- [ ] Tenancy.md documents the fallback semantics (try tenant-scoped, fall back to shared).
- [ ] Tenancy.md inlines the relevant Vault invariants (no logging of values; Vault is the only secret source; never version-pin; diagnostics to Log Analytics; rotation tier applies per secret).
- [ ] Tenancy.md includes the **"Telemetry of tenant-scoped secret names"** subsection documenting (a) Vault telemetry is internal-only, (b) tenant ULIDs in identifiers are intentional for operational correlation, (c) customer-facing dashboards do not expose Vault telemetry, (d) tenant ULIDs are opaque IDs not personally identifying on their own, and (e) future redaction would live in `HoneyDrunk.Vault/Telemetry/` if a stricter posture is required (non-blocking for v1).
- [ ] Tenancy.md walks through the worked Pro-tier scenario (operator-provisioned tenant slot → resolver returns scoped value → tenant removes slot → resolver falls back).
- [ ] `TenantScopedSecretResolver` exists in `HoneyDrunk.Vault.Tenancy` (or chosen namespace) with the shape documented above. Public API has XML docs (Invariant 13).
- [ ] Resolver consumes `ISecretStore` via composition; does not modify or replace it.
- [ ] DI extension (e.g., `AddTenantScopedSecretResolver()`) registers the resolver and is documented in Tenancy.md.
- [ ] All five tests from section C pass.
- [ ] No secret values appear in any log emitted by the resolver (verifiable via test).
- [ ] Every `.csproj` in the Vault solution moves from `0.3.0` to `0.4.0` in a single commit (Invariant 27).
- [ ] Repo-level `CHANGELOG.md` has a new `0.4.0` entry covering the new tenancy docs and resolver.
- [ ] Per-package `CHANGELOG.md` for `HoneyDrunk.Vault/` updated. Provider packages get NO `CHANGELOG.md` entries (alignment-only bump — Invariant 12).
- [ ] Per-package `README.md` for `HoneyDrunk.Vault/` links to `docs/Tenancy.md`.
- [ ] Vault's `.csproj` reference to `HoneyDrunk.Kernel.Abstractions` is bumped to the version produced by packet 01.
- [ ] No change to `ISecretStore`, `IConfigProvider`, `IVaultClient`, or `ISecretProvider`. Verify with `git diff HoneyDrunk.Vault/Abstractions/`.
- [ ] All canary tests green; full unit-test suite green.

## Human Prerequisites
- [ ] **Confirm packet 01 (Kernel) merged and published.** This packet imports `TenantId.Internal` and `TenantId.IsInternal` from `HoneyDrunk.Kernel.Abstractions` 0.5.0+. If packet 01 is not merged + published when this packet runs, the build fails on the `IsInternal` reference.
- [ ] No portal / Azure work for this packet. The `tenant-{tenantId}-{secretName}` slots are populated by Notify Cloud / consumer Nodes when they ship — not by this packet. Tenancy.md documents the operator workflow but does not require any tenant slots to exist for the tests to pass (tests use `InMemorySecretStore`).
- [ ] No human bikeshed. The naming convention is settled by ADR-0026 D5 — no new color choices.

## Dependencies
- **Kernel#NN — Grid multi-tenant primitives (packet 01).** Hard dependency: `TenantId.Internal` and `TenantId.IsInternal` are imported here. Must be merged and the resulting NuGet version published before this packet can build green.

## Downstream Unblocks
- Notify Cloud's intake layer can compose `TenantScopedSecretResolver` to resolve per-tenant Resend / Twilio keys. (Notify Cloud standup ADR will reference this resolver.)
- Communications inherits the strong type via `IGridContext`; if Communications ever needs per-tenant secrets, this resolver is the pattern.
- Architecture catalog packet (#04) — flips ADR-0026 to Accepted only after packet 01 + this packet + the Architecture catalog packet all merge.

## Referenced Invariants

> **Invariant 8 (Secrets & Trust):** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. **Why it matters here:** The resolver must not log resolved secret values — only the `tenant-{tenantId}-{secretName}` identifier when emitting telemetry. A test verifies this.

> **Invariant 9 (Secrets & Trust):** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`. **Why it matters here:** The resolver composes `ISecretStore` — it does not read provider SDKs directly. Tenant-scoped secrets remain inside the per-Node Key Vault.

> **Invariant 12 (Packaging):** Semantic versioning with CHANGELOG and README. Two tiers: repo-level (mandatory) and per-package (only when the package has functional changes — no noise entries for alignment bumps). **Why it matters here:** Repo-level `CHANGELOG.md` gets a `0.4.0` entry. Only `HoneyDrunk.Vault/` gets a per-package CHANGELOG entry; the five provider packages get none (alignment-only).

> **Invariant 13 (Packaging):** All public APIs have XML documentation. **Why it matters here:** `TenantScopedSecretResolver` and its public methods carry XML docs.

> **Invariant 17 (Infrastructure):** One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Library-only Nodes have no vault. **Why it matters here:** The Tenancy.md naming convention nests inside this rule. Per-tenant slots live in the consumer Node's vault (e.g., `kv-hd-notify-cloud-{env}`), not in a separate "tenants vault."

> **Invariant 21 (Infrastructure):** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`. **Why it matters here:** The resolver passes through to `ISecretStore.GetSecretAsync(...)` / `TryGetSecretAsync(...)` which already resolves the latest version. No version-pinning logic added.

> **Invariant 22 (Infrastructure):** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace. **Why it matters here:** Tenant-scoped secrets are covered by the Node's vault diagnostics — no per-tenant diagnostics setup needed.

> **Invariant 27 (Versioning):** All projects in a solution share one version and move together. **Why it matters here:** Vault solution moves `0.3.0 → 0.4.0` in one commit. Provider packages bump version but get no per-package CHANGELOG noise.

> **Invariant 31 (Code Review):** Every PR traverses the tier-1 gate before merge. **Why it matters here:** Vault's `pr-core.yml` must pass before merge.

## Referenced ADR Decisions

**ADR-0026 (Grid Multi-Tenant Primitives) D5 — Per-tenant Vault scoping is a usage pattern, not a contract change.**
- `ISecretStore` stays a primitive. Tenancy is composition.
- Naming convention: within `kv-hd-{service}-{env}`, per-tenant secrets are `tenant-{tenantId}-{secretName}`.
- `TenantScopedSecretResolver` lives in the `HoneyDrunk.Vault` runtime package (not Abstractions, because it composes `ISecretStore`).
- Internal-tenant short-circuit returns the shared name path (the Node's existing behavior).
- Non-internal: try tenant-scoped first, fall back to shared (Free/Starter tier sharing).
- All existing Vault invariants apply — no logging of values, only ISecretStore reads, no version pinning, diagnostics to Log Analytics, rotation tier per secret.

**ADR-0026 D9 — Ordering.** Vault docs and `TenantScopedSecretResolver` land second, after the Kernel half (packet 01) is merged and published.

**ADR-0006 (Tier-2 Secret Rotation) — context only.** Tenant-scoped Resend / Twilio keys are Tier 2 (third-party, ≤90-day SLA) just like the Node's shared keys. No change to rotation tooling — the rotator continues to write rotated values into the same Key Vault under whatever name the rotator was configured with. Tenant-scoped rotation, if it ever lands, is a future ADR.

## Constraints

- **No change to `ISecretStore`.** This is the load-bearing invariant of D5. Verify with `git diff HoneyDrunk.Vault/Abstractions/` — the diff must be empty.
- **No new provider package.** The resolver works against any existing `ISecretStore` implementation. Do not create `HoneyDrunk.Vault.Providers.Tenancy` or similar.
- **Compose against the real `ISecretStore` shapes shown in the Proposed Implementation.** The interface takes `SecretIdentifier`, not raw strings, and `TryGetSecretAsync` returns `VaultResult<SecretValue>`. Cross-check `HoneyDrunk.Vault/Models/SecretIdentifier.cs`, `SecretValue.cs`, and `VaultResult.cs` at execution and adapt minimally if a member name differs from `IsSuccess`/`Value` — the ADR D5 pseudocode was reconciled against these shapes, but the on-disk types remain the source of truth.
- **The `tenant-` prefix is literal.** Do not parameterize it (no `TenancyOptions.Prefix = "tenant-"`); the convention is fixed by ADR-0026 D5 and parameterizing invites drift across consumer Nodes.
- **No ADR ID in code comments or README.** Per the no-ADR-in-docs convention, the new XML docs and README sections do NOT mention `ADR-0026`. Tenancy.md is a docs file under `HoneyDrunk.Vault/docs/` and follows the same rule — describe the pattern; do not link to the ADR. (Packet runtime data — this file, frontmatter, CHANGELOG — does reference the ADR.)
- **Internal short-circuit must skip the tenant-scoped lookup entirely.** Do not "try tenant-scoped first, fall back" for internal callers — that wastes a Key Vault round-trip on every internal call. The `IsInternal` predicate is checked first and the resolver goes straight to the shared name path.
- **Coordinated bump on every `.csproj`.** Provider packages (`AzureKeyVault`, `Aws`, `File`, `Configuration`, `InMemory`, `AppConfiguration`) and `HoneyDrunk.Vault.EventGrid` all bump to `0.4.0` per Invariant 27, but their per-package `CHANGELOG.md` files get NO entries (Invariant 12 — no alignment-bump noise).

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0026`, `wave-2`

## Agent Handoff

**Objective:** Ship the Vault half of ADR-0026 step 2 — `docs/Tenancy.md` documenting the `tenant-{tenantId}-{secretName}` convention and a `TenantScopedSecretResolver` runtime composition layer over `ISecretStore`. No contract change. Coordinated solution-wide bump to `0.4.0`.

**Target:** `HoneyDrunk.Vault`, branch from `main`.

**Context:**
- Goal: Make per-tenant secret scoping a first-class Grid pattern without changing Vault's contract surface.
- Feature: ADR-0026 Grid Multi-Tenant Primitives, step 2 of D9 ordering.
- ADRs: ADR-0026 (multi-tenant primitives, D5 + D8 + D9), ADR-0006 (Tier-2 rotation context only).
- PDR: PDR-0002 (Notify Cloud) — Pro-tier customers BYO their Resend / Twilio keys via tenant-scoped slots.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Kernel#NN — Grid multi-tenant primitives (packet 01). Hard. Provides `TenantId.Internal` + `TenantId.IsInternal`.

**Constraints:** Per Constraints section above. Specifically:
- No change to `ISecretStore`. Verify with diff.
- Compose against the real `ISecretStore` shape (`SecretIdentifier` + `VaultResult<SecretValue>`) — the ADR D5 pseudocode is reconciled with this shape, but cross-check on-disk types in `HoneyDrunk.Vault/Models/` for any member-name drift.
- `tenant-` prefix is literal — not parameterized.
- No ADR ID in code / README / Tenancy.md.
- Internal short-circuit skips the tenant-scoped lookup entirely (no wasted round-trip).
- Coordinated `0.3.0 → 0.4.0` bump on every `.csproj`. Provider packages bump but get no CHANGELOG noise.

**Inlined Invariant Text (for review without leaving the target repo):**

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level CHANGELOG mandatory; per-package CHANGELOG only when the package has functional changes.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 17:** One Key Vault per deployable Node per environment, named `kv-hd-{service}-{env}`, with Azure RBAC enabled.

> **Invariant 21:** Applications must never pin to a specific secret version. All secret reads resolve the latest version via `ISecretStore`.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.

> **Invariant 27:** All projects in a solution share one version and move together.

> **Invariant 31:** Every PR traverses the tier-1 gate before merge.

**Key Files:**
- `HoneyDrunk.Vault/docs/Tenancy.md` (new)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Abstractions/ISecretStore.cs` (READ-ONLY for reference; do NOT edit)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Models/SecretIdentifier.cs` (read for actual constructor shape)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Models/SecretValue.cs` (read)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Models/VaultResult.cs` (read for `IsSuccess` / `Value` shape)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Tenancy/TenantScopedSecretResolver.cs` (new)
- `HoneyDrunk.Vault/HoneyDrunk.Vault/HoneyDrunk.Vault/Extensions/` — DI extension addition
- Test project — five new tests
- All `.csproj` files in the Vault solution (version bump)
- Per-package `CHANGELOG.md` and root-level `CHANGELOG.md`

**Contracts:**
- `TenantScopedSecretResolver.ResolveAsync(TenantId tenantId, string secretName, CancellationToken cancellationToken) → Task<SecretValue>` (or chosen return type — `SecretValue` recommended for caller flexibility)
- No change to `ISecretStore`, `IConfigProvider`, `IVaultClient`, `ISecretProvider`.
