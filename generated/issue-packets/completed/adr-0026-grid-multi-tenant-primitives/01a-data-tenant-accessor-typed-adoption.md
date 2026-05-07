---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Data
labels: ["chore", "tier-2", "core", "adr-0026", "wave-1"]
dependencies: ["Kernel#NN — Grid multi-tenant primitives (packet 01)"]
adrs: ["ADR-0026"]
wave: 1
initiative: adr-0026-grid-multi-tenant-primitives
node: honeydrunk-data
coordinated_with: ["HoneyDrunk.Kernel", "HoneyDrunk.Transport", "HoneyDrunk.Web.Rest", "HoneyDrunk.Pulse"]
---

# Chore: Adapt KernelTenantAccessor to Kernel 0.5.0 typed IOperationContext.TenantId

## Summary
After the lead Kernel packet (#01) promotes `IOperationContext.TenantId` from `string?` to non-nullable `TenantId` (Kernel-typed), `HoneyDrunk.Data/Tenancy/KernelTenantAccessor.cs` no longer compiles against published Kernel 0.5.0. This packet adapts the single callsite (line 36 today) so Data continues to expose its own `HoneyDrunk.Data.Abstractions.Tenancy.TenantId` (string-backed) to consumers, while consuming the Kernel-typed value as its source. Coordinated solution-wide minor bump on `HoneyDrunk.Data` (`0.4.0 → 0.5.0`).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Data`

## Motivation
ADR-0026 D2 promotes `IGridContext.TenantId` and `IOperationContext.TenantId` from `string?` to typed `TenantId` (the Kernel.Abstractions ULID record struct). The lead Kernel packet (#01) ships that promotion as part of Kernel 0.5.0. `HoneyDrunk.Data` reads `IOperationContext.TenantId` in exactly one place — `KernelTenantAccessor.GetCurrentTenantId()` (file `HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data/Tenancy/KernelTenantAccessor.cs`, line 36) — to translate it into Data's own `HoneyDrunk.Data.Abstractions.Tenancy.TenantId` (a different record struct, string-backed, used internally by Data's tenant-aware persistence layer).

Today's code:
```csharp
var tenantId = context.TenantId;
return string.IsNullOrWhiteSpace(tenantId) ? default : TenantId.FromString(tenantId);
```

After Kernel 0.5.0, `context.TenantId` is typed `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` (non-nullable, defaulted to `Internal` at Grid entry). The `string.IsNullOrWhiteSpace` check no longer compiles, and the `null` discriminator no longer makes sense — the equivalent now is "is this the Internal sentinel?"

This packet ships the Data half of the coordinated Wave 1. It merges in the same wave as Kernel 0.5.0; the merge order is "Kernel first, then this packet as soon as Kernel publishes."

## Proposed Implementation

### A. Adapt `KernelTenantAccessor.GetCurrentTenantId()`

`HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data/Tenancy/KernelTenantAccessor.cs`:

The method's contract (return Data's own `TenantId` representing "the current tenant" or `default` for "no tenant"):

```csharp
public TenantId GetCurrentTenantId()
{
    var context = _operationContextAccessor.Current;
    if (context is null)
    {
        return default;
    }

    // After Kernel 0.5.0, context.TenantId is the typed Kernel TenantId
    // (non-nullable, defaulted to Internal when no X-Tenant-Id header was present).
    // Translate Internal → Data's "no tenant" (default), real tenant → string-backed
    // Data TenantId.
    var kernelTenantId = context.TenantId;
    return kernelTenantId.IsInternal
        ? default
        : TenantId.FromString(kernelTenantId.ToString());
}
```

Imports update: add `using KernelTenantId = HoneyDrunk.Kernel.Abstractions.Identity.TenantId;` (or use the fully-qualified name inline) to disambiguate from Data's own `HoneyDrunk.Data.Abstractions.Tenancy.TenantId`. The two types share a name; the file already imports `HoneyDrunk.Data.Abstractions.Tenancy` so Data's `TenantId` is the unqualified one. The Kernel one needs the alias or the fully-qualified path.

Semantically: the existing code returned `default` when the string was null/whitespace. The new code returns `default` when the Kernel value is `Internal`. The two map to the same intent — "this is internal/non-tenanted Grid traffic; Data should not apply tenant-scoped filtering." The `IsInternal` predicate is the type-safe equivalent of the old null-check.

### B. Adapt any other callsites that read `IOperationContext.TenantId` or `IGridContext.TenantId` as a string

Verify at execution with `rg "context\.TenantId|gridContext\.TenantId|operationContext\.TenantId" --type cs` across the Data repo. The packet authoring grep shows `KernelTenantAccessor.cs` line 36 as the only callsite. If new callsites have appeared since packet authoring, apply the same `IsInternal`-translates-to-`default` pattern.

### C. Coordinated version bump

Per Invariant 27, every project in the `HoneyDrunk.Data` solution moves to `0.5.0`:
- `HoneyDrunk.Data/HoneyDrunk.Data` — actual change (this packet's adapter)
- `HoneyDrunk.Data.Abstractions` — alignment-only
- `HoneyDrunk.Data.AspNetCore` — alignment-only
- `HoneyDrunk.Data.EntityFramework` — alignment-only
- `HoneyDrunk.Data.SqlServer` — alignment-only
- `HoneyDrunk.Data.Migrations` — alignment-only
- `HoneyDrunk.Data.Outbox` + `Outbox.Abstractions` + `Outbox.Dispatcher` — alignment-only
- `HoneyDrunk.Data.Testing` — alignment-only
- `HoneyDrunk.Data.Canary` + `HoneyDrunk.Data.Tests` — test projects

Bump the `<Version>` in each `.csproj` from `0.4.0` to `0.5.0`. Bump the `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions` `<PackageReference>` versions in every `.csproj` that references them from `0.4.0` to `0.5.0` (verified targets: `HoneyDrunk.Data.csproj`).

Per Invariant 12 — repo-level `CHANGELOG.md` gets a new `0.5.0` entry covering the typed-`TenantId` adoption. Per-package `CHANGELOG.md` updates ONLY for `HoneyDrunk.Data/` (the package with actual change). All other packages get NO per-package CHANGELOG entries (alignment-only — Invariant 12 prohibits noise entries).

### D. Tests

Update or add tests in `HoneyDrunk.Data.Tests/Tenancy/KernelTenantAccessorTests.cs` (or wherever the existing accessor tests live — verify at execution; create the test file if it doesn't exist):

1. **Internal-tenant context returns Data's `default` TenantId.** Construct an `IOperationContext` whose `TenantId` is `Kernel.TenantId.Internal`. Assert `accessor.GetCurrentTenantId() == default`.

2. **Non-internal-tenant context returns Data's string-backed TenantId carrying the ULID.** Construct an `IOperationContext` with a known Kernel `TenantId` (e.g., `TenantId.NewId()` minted in test setup). Assert `accessor.GetCurrentTenantId().Value == kernelTenantId.ToString()`.

3. **Null OperationContextAccessor.Current returns `default`.** Pre-existing behavior; verify it still holds after the type change.

Existing tests that asserted the old `string.IsNullOrWhiteSpace`-based behavior need updating to construct contexts with the typed `Kernel.TenantId` instead of strings.

### E. README touch-up

If `HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data/README.md` mentions tenant-aware data access patterns, verify the example code reflects the new typed Kernel surface. If no example references tenancy, no edit needed. Do NOT include the ADR ID in the README.

## Affected Files

- `HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data/Tenancy/KernelTenantAccessor.cs` (edit — line 36 area; add alias / fully-qualified Kernel TenantId)
- `HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data.Tests/Tenancy/KernelTenantAccessorTests.cs` (new or edit)
- All `.csproj` files in the Data solution (version bump `0.4.0 → 0.5.0`)
- `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel` PackageReference versions in every `.csproj` that references them — bump to `0.5.0`
- `HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data/CHANGELOG.md` (per-package — actual change)
- Repo-root `CHANGELOG.md` — new `0.5.0` entry
- Per-package `CHANGELOG.md` for non-changed packages — NO entries (Invariant 12)
- Per-package `README.md` for `HoneyDrunk.Data/` — only if the existing README references the now-obsolete `string?` pattern

## NuGet Dependencies

- `HoneyDrunk.Kernel` PackageReference: bump from `0.4.0` to `0.5.0` (the version produced by Wave 1 packet 01).
- `HoneyDrunk.Kernel.Abstractions` PackageReference: bump from `0.4.0` to `0.5.0`.

No new package additions.

## Boundary Check
- [x] All edits in `HoneyDrunk.Data`. Routing rule "data, persistence, repository, unit-of-work, EntityFramework, tenant-aware data, outbox" → `HoneyDrunk.Data` matches.
- [x] No change to `HoneyDrunk.Data.Abstractions` contract surface. Data's own `TenantId` (string-backed) is preserved unchanged. Only the internal translation from Kernel's typed `TenantId` to Data's string-backed `TenantId` adapts.
- [x] No change to `ITenantAccessor` shape. `GetCurrentTenantId()` still returns Data's `TenantId`.
- [x] Honors Invariant 5 (GridContext present in scoped operation) — accessor reads `IOperationContextAccessor.Current` as today.
- [x] No new transitive runtime dependencies (Invariant 2). Already depends on `HoneyDrunk.Kernel.Abstractions`; only the version constraint moves.

## Acceptance Criteria

- [ ] `KernelTenantAccessor.GetCurrentTenantId()` compiles against published `HoneyDrunk.Kernel.Abstractions` 0.5.0.
- [ ] The method translates Kernel's `TenantId.IsInternal` → Data's `default` `TenantId`.
- [ ] The method translates a non-internal Kernel `TenantId` → Data's string-backed `TenantId.FromString(kernelTenantId.ToString())`.
- [ ] `using` directives or fully-qualified type names disambiguate the two `TenantId` types in the file.
- [ ] Three new / updated tests in `HoneyDrunk.Data.Tests/Tenancy/KernelTenantAccessorTests.cs` (Internal → default, real tenant → ULID-backed, null context → default) pass.
- [ ] Existing tests that constructed contexts with `string?` TenantId are updated to construct with typed `Kernel.TenantId`.
- [ ] Every `.csproj` in the Data solution moves from `0.4.0` to `0.5.0` in a single commit (Invariant 27).
- [ ] `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions` PackageReference versions in every Data `.csproj` that references them are bumped to `0.5.0`.
- [ ] Repo-level `CHANGELOG.md` has a new `0.5.0` entry covering the Kernel 0.5.0 adoption (one-line pointer is sufficient — the change is mechanical).
- [ ] Per-package `CHANGELOG.md` for `HoneyDrunk.Data/` updated. No entries for `Abstractions`, `AspNetCore`, `EntityFramework`, `SqlServer`, `Migrations`, `Outbox*`, `Testing`, `Canary`, `Tests` (alignment-only — Invariant 12).
- [ ] `git diff HoneyDrunk.Data.Abstractions/` shows ONLY version bumps (no contract change).
- [ ] All canary tests green; full unit-test suite green.
- [ ] No public-API surface change to `ITenantAccessor` or Data's own `TenantId` record struct. Verify with `git diff HoneyDrunk.Data.Abstractions/Tenancy/`.

## Human Prerequisites
- [ ] **Confirm packet 01 (Kernel) merged AND `HoneyDrunk.Kernel.Abstractions` 0.5.0 + `HoneyDrunk.Kernel` 0.5.0 published.** This packet imports the typed `IOperationContext.TenantId` shape; if the upstream package is not published when this packet's PR builds, the build fails on `context.TenantId` — Cysharp `Ulid` cannot be cast to `string`, and `IsInternal` does not exist.
- [ ] **Coordinated merge in Wave 1.** This packet's PR merges within the same wave as Kernel 0.5.0 (typically same day). The dispatch operator coordinates merge order: Kernel first, then this packet as soon as Kernel publishes.
- [ ] No portal / Azure work. NuGet-only library packet.

## Dependencies
- **Kernel#NN — Grid multi-tenant primitives (packet 01).** Hard. Kernel 0.5.0 must be published to the Grid's NuGet feed before this packet's PR builds green.

## Downstream Unblocks
- Wave 1 closure — once this packet merges (alongside the other Wave 1 sister packets), Kernel 0.5.0 has working consumers and Wave 2 (Vault) can begin.
- Communications, Notify Cloud, and any other future Node consuming Data inherit the typed Kernel `TenantId` propagation automatically.

## Referenced Invariants

> **Invariant 2 (Dependency):** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. **Why it matters here:** Only the existing `HoneyDrunk.Kernel.Abstractions` reference's version moves; no new package edges introduced.

> **Invariant 5 (Context):** GridContext must be present in every scoped operation. **Why it matters here:** `KernelTenantAccessor` reads from `IOperationContextAccessor.Current`; the typed `TenantId` is part of that contract, populated by Kernel's middleware/mappers.

> **Invariant 12 (Packaging):** Semantic versioning with CHANGELOG and README — repo-level mandatory; per-package only when the package has functional changes (no noise entries for alignment bumps). **Why it matters here:** Repo-level `CHANGELOG.md` gets a `0.5.0` entry; only `HoneyDrunk.Data/` gets a per-package entry; Abstractions, AspNetCore, EntityFramework, SqlServer, Migrations, Outbox*, Testing, Canary, Tests get NO entries.

> **Invariant 13 (Packaging):** All public APIs have XML documentation. **Why it matters here:** No public API surface change; existing XML docs on `ITenantAccessor` and `KernelTenantAccessor` stand.

> **Invariant 26 (Work Tracking):** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. **Why it matters here:** Section above documents the Kernel/Kernel.Abstractions version bump.

> **Invariant 27 (Versioning):** All projects in a solution share one version and move together. **Why it matters here:** Every Data `.csproj` moves `0.4.0 → 0.5.0` in one commit; only the changed package's per-package CHANGELOG sees an entry.

> **Invariant 31 (Code Review):** Every PR traverses the tier-1 gate before merge.

> **Invariant 32 (Code Review):** Agent-authored PRs must link to their packet in the PR body.

## Referenced ADR Decisions

**ADR-0026 (Grid Multi-Tenant Primitives):**
- **D2 — `IGridContext.TenantId` is promoted from `string?` to `TenantId` (non-nullable).** This packet adapts Data's only consumer of the property (`KernelTenantAccessor`) to the typed shape.
- **D9 — Coordinated Wave 1.** This packet is one of four downstream sister packets in Wave 1 (Data, Transport, Web.Rest, Pulse). Each ships its own PR and version bump but merges in the same wave as Kernel 0.5.0.
- **Negative consequences — blast radius inventory.** ADR-0026 names `KernelTenantAccessor.cs` as one of the four file-level callsites that need adaptation. This packet covers exactly that file.

## Constraints

- **Do NOT change Data's own `TenantId` type.** `HoneyDrunk.Data.Abstractions.Tenancy.TenantId` (string-backed record struct) is unchanged. Only the internal translation in `KernelTenantAccessor` adapts.
- **Do NOT change `ITenantAccessor` shape.** The interface still returns Data's `TenantId`. The translation is internal.
- **Disambiguate the two `TenantId` types.** With `using HoneyDrunk.Data.Abstractions.Tenancy;` and the new `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` reference, both types share a name. Use a `using KernelTenantId = HoneyDrunk.Kernel.Abstractions.Identity.TenantId;` alias inside `KernelTenantAccessor.cs` (or fully-qualify inline). Pick one and apply consistently.
- **`IsInternal` translates to `default` Data TenantId.** This is the semantic preservation — the old `string.IsNullOrWhiteSpace` check returned `default` for "no tenant"; the new `IsInternal` check returns `default` for "Grid-internal traffic." Both mean "Data should not apply tenant-scoped filtering."
- **No new NuGet dependencies.** Only the existing `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions` `<PackageReference>` versions move. Verify no new `<PackageReference>` lines added.
- **No ADR ID in code comments / README.**
- **Coordinated bump on every `.csproj`.** Provider/sub-package CHANGELOGs stay quiet (Invariant 12); only `HoneyDrunk.Data/` gets a per-package entry.

## Labels
`chore`, `tier-2`, `core`, `adr-0026`, `wave-1`

## Agent Handoff

**Objective:** Adapt `HoneyDrunk.Data`'s single Kernel-tenant consumer (`KernelTenantAccessor.cs`) to Kernel 0.5.0's typed `IOperationContext.TenantId`. Coordinated solution-wide bump to `0.5.0`. Sister packet to the lead Kernel packet (#01) in Wave 1.

**Target:** `HoneyDrunk.Data`, branch from `main`.

**Context:**
- Goal: Mechanical adaptation to the typed Kernel `TenantId` shape; preserve Data's own `TenantId` contract.
- Feature: ADR-0026 Grid Multi-Tenant Primitives, Wave 1 (coordinated multi-repo bump).
- ADRs: ADR-0026 (multi-tenant primitives, D2 + D9 + Negative Consequences blast radius).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Kernel#NN — Grid multi-tenant primitives (packet 01). Hard. Kernel 0.5.0 published before this PR builds.

**Constraints:** Per Constraints section above. Specifically:
- No change to Data's `TenantId` or `ITenantAccessor` shape.
- Disambiguate the two `TenantId` types via alias or fully-qualified name.
- `IsInternal` translates to `default`.
- Coordinated `0.4.0 → 0.5.0` bump on every Data `.csproj`. Per-package CHANGELOG only for `HoneyDrunk.Data/`.
- No ADR ID in code / README.

**Inlined Invariant Text (for review without leaving the target repo):**

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer.

> **Invariant 5:** GridContext must be present in every scoped operation.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level CHANGELOG mandatory; per-package CHANGELOG only when the package has functional changes (no noise entries for alignment bumps).

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section.

> **Invariant 27:** All projects in a solution share one version and move together.

> **Invariant 31:** Every PR traverses the tier-1 gate before merge.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

**Key Files:**
- `HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data/Tenancy/KernelTenantAccessor.cs`
- `HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data.Abstractions/Tenancy/TenantId.cs` (READ-ONLY for reference; do NOT edit)
- `HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data.Abstractions/Tenancy/ITenantAccessor.cs` (READ-ONLY for reference; do NOT edit)
- `HoneyDrunk.Data/HoneyDrunk.Data/HoneyDrunk.Data.Tests/Tenancy/KernelTenantAccessorTests.cs` (new or edit)
- All `.csproj` files in the Data solution (version + Kernel/Kernel.Abstractions PackageReference bump)
- Per-package `CHANGELOG.md` for `HoneyDrunk.Data/` only
- Repo-root `CHANGELOG.md`

**Contracts:**
- No change to `ITenantAccessor` (`HoneyDrunk.Data.Abstractions.Tenancy.ITenantAccessor`).
- No change to `HoneyDrunk.Data.Abstractions.Tenancy.TenantId` (string-backed).
- Internal: `KernelTenantAccessor` now consumes typed `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` from `IOperationContext.TenantId`.
