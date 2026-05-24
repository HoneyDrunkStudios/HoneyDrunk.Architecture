---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["feature", "tier-2", "core", "adr-0048", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0048"]
wave: 3
initiative: adr-0048-schema-evolution
node: honeydrunk-standards
---

# Ship `RollbackAttribute` Grid-wide in `HoneyDrunk.Standards`

## Summary
Ship the `RollbackAttribute` and `RollbackStrategy` declarative types per ADR-0048 D10/D12 from `HoneyDrunk.Standards` so every Node already references the canonical definition through its existing `HoneyDrunk.Standards` `PackageReference` (per invariant 26 — every project carries a `PrivateAssets: all` reference on `HoneyDrunk.Standards`). The attribute is informational-only at runtime: it declares each migration class's rollback intent for the `database` specialist agent (per ADR-0048 D13) and human reviewers to read. No runtime behaviour is added.

## Context
ADR-0048 D10/D12 require every EF Core migration class to carry a `[Rollback(Strategy = ..., Notes/Reason = "...")]` attribute. The attribute is **a Grid-wide contract** — every migration-bearing Node references the same type so reviewers, the `database` specialist agent, and any future tooling see one canonical declaration.

ADR-0048 names the attribute but does not pin its home. The first attempted home (in an earlier draft of the Wave-4 Notify annotation packet) was to ship the type inside `HoneyDrunk.Notify.Data`. That placement is a boundary violation per invariants 1 and 2: a Grid-wide contract cannot live inside a specific Node's data package, because every other migration-bearing Node would then either duplicate the type (drift risk) or take a runtime dependency on a Node-specific package (invariant 1 — single Grid-wide contract, no cross-Node runtime edges through Node packages).

**Why `HoneyDrunk.Standards` is the right home.** Per invariant 26, every .NET project in the Grid already carries a `HoneyDrunk.Standards` `PackageReference` with `PrivateAssets: all`. Shipping `RollbackAttribute` from `HoneyDrunk.Standards` means every existing project transitively gains access without adding a single `PackageReference`. The alternative — `HoneyDrunk.Data.Abstractions` — would require every migration-bearing Node to add a new `PackageReference` and bumps the Data repo's release cadence. Standards is the leaner placement.

**The attribute is informational-only.** Per ADR-0048 D12, the attribute is read by reviewers (and the `database` specialist agent, per packet 02) and is NOT enforced at runtime. EF Core does not inspect it; the migration runner does not inspect it; no Roslyn analyzer enforces it (no analyzer is shipped in this packet — that is a deferred follow-up if the operator ever wants compile-time enforcement). The attribute exists as a discipline marker.

**Wave-3 placement.** This packet must land before packet 07 (Notify retroactive annotation), because packet 07's `[Rollback]` decorations reference the canonical type by `using HoneyDrunk.Standards;` (or whatever namespace the type lives in within Standards — see Proposed Implementation). Wave-3 already carries 05 (migrate.yml) and 06 (per-Node README template); 09 joins them. Packets 05/06/09 are independent (different repos) and run in parallel.

This is a tier-2 packet on `HoneyDrunk.Standards` (small public API additions to an existing released package; minor version bump). No runtime behaviour change.

## Scope
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/Migrations/RollbackAttribute.cs` — new public sealed class `RollbackAttribute : Attribute` with `Strategy` (enum), `Notes` (string?), `Reason` (string?) properties.
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/Migrations/RollbackStrategy.cs` — new public enum `RollbackStrategy { ForwardMigration, NonRollback }`.
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/Migrations/` — confirm the file layout at edit time. If `HoneyDrunk.Standards` already groups types under sub-folders by topic, place the two files in a `Migrations/` sub-folder. If not, place them at the project root and prefix the namespace.
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/CHANGELOG.md` — per-package CHANGELOG entry naming the new types.
- `HoneyDrunk.Standards/CHANGELOG.md` (repo-level) — minor version bump entry naming the new public API.
- Every non-test `.csproj` in the Standards solution — minor version bump per invariant 27.
- Optionally a unit test in `HoneyDrunk.Standards.Tests` exercising attribute construction and default values (sanity check; no behavioural assertion beyond construction).

## Proposed Implementation

### 1. Place the types

The actual `HoneyDrunk.Standards` project root on disk is `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/`. Confirm at edit time by `ls` against the repo. The namespace will be `HoneyDrunk.Standards.Migrations` if a `Migrations/` sub-folder is used, otherwise `HoneyDrunk.Standards`. Choose per the repo's existing convention.

```csharp
namespace HoneyDrunk.Standards.Migrations;

/// <summary>
/// Declares the rollback intent for an EF Core migration class per ADR-0048 D10/D12.
/// Read by reviewers and the <c>database</c> specialist agent (ADR-0048 D13); not enforced at runtime.
/// </summary>
[AttributeUsage(AttributeTargets.Class, Inherited = false, AllowMultiple = false)]
public sealed class RollbackAttribute : Attribute
{
    /// <summary>The rollback strategy chosen for this migration.</summary>
    public RollbackStrategy Strategy { get; init; }

    /// <summary>
    /// Free-text notes describing the forward-rollback approach for <see cref="RollbackStrategy.ForwardMigration"/>.
    /// Optional but strongly recommended.
    /// </summary>
    public string? Notes { get; init; }

    /// <summary>
    /// Required when <see cref="Strategy"/> is <see cref="RollbackStrategy.NonRollback"/>.
    /// Free-text explanation of why the migration cannot be rolled back (typically: data-destructive and unrecoverable).
    /// </summary>
    public string? Reason { get; init; }
}
```

```csharp
namespace HoneyDrunk.Standards.Migrations;

/// <summary>
/// Rollback strategies declared by <see cref="RollbackAttribute"/> on EF Core migration classes per ADR-0048 D10.
/// </summary>
public enum RollbackStrategy
{
    /// <summary>
    /// The default. EF Core's generated <c>Down()</c> is not committed to in production; rollback is achieved by
    /// writing a new forward migration that reverses the unwanted change. <see cref="RollbackAttribute.Notes"/>
    /// describes the forward-rollback approach.
    /// </summary>
    ForwardMigration,

    /// <summary>
    /// The migration is data-destructive and cannot be rolled back even by writing a compensating forward migration.
    /// <see cref="RollbackAttribute.Reason"/> is required.
    /// </summary>
    NonRollback,
}
```

### 2. CHANGELOG and version bump

- **Per-package `HoneyDrunk.Standards/CHANGELOG.md`:** add a minor-bump entry naming the new types (this is a new public API surface per invariant 12 — minor bump).
- **Repo-level `CHANGELOG.md`:** add the same minor-bump entry for the Standards solution.
- **Every non-test `.csproj` in the Standards solution:** minor-bump together per invariant 27.

### 3. Optional sanity test

Add a small test class to `HoneyDrunk.Standards.Tests` (path `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards.Tests/Migrations/RollbackAttributeTests.cs` or per the repo's existing convention) verifying:
- `RollbackAttribute` can be constructed with `Strategy = RollbackStrategy.ForwardMigration` and an optional `Notes`.
- `RollbackAttribute` can be constructed with `Strategy = RollbackStrategy.NonRollback` and a `Reason`.
- Default `Strategy` is `ForwardMigration` (the first enum member).
- `AttributeUsage` restricts targets to classes.

No `Thread.Sleep`, no `TimeProvider` needed — these are attribute-construction tests.

### 4. Documentation

Add a short note to `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/README.md` (or the package's existing docs) under a "Migrations" heading naming the two types and citing ADR-0048 D10/D12. Two or three sentences are sufficient; the canonical policy lives in ADR-0048, not in the package README.

## Affected Files
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/Migrations/RollbackAttribute.cs` (new)
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/Migrations/RollbackStrategy.cs` (new)
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/CHANGELOG.md` (per-package entry)
- `HoneyDrunk.Standards/CHANGELOG.md` (repo-level entry)
- Every non-test `.csproj` in the Standards solution (minor-version bump per invariant 27)
- Optionally: `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards.Tests/Migrations/RollbackAttributeTests.cs` (new)
- Optionally: `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/README.md` (short note under a Migrations heading)

## NuGet Dependencies
None new. `RollbackAttribute` and `RollbackStrategy` use only the BCL (`System.AttributeUsageAttribute`, `System.Attribute`).

## Boundary Check
- [x] All edits in `HoneyDrunk.Standards`. Routing rule "standards, conventions, analyzers, shared MSBuild → HoneyDrunk.Standards" maps for Grid-wide declarative types every project already references.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime edge. Every migration-bearing Node already references `HoneyDrunk.Standards` per invariant 26; the new types ride that existing reference transparently.
- [x] No new contract on `relationships.json`. `RollbackAttribute` is a declarative metadata type, not a Node-to-Node interface.
- [x] Grid-wide placement resolves the boundary violation that would have arisen from shipping the attribute inside `HoneyDrunk.Notify.Data` (invariants 1/2).

## Acceptance Criteria
- [ ] `RollbackAttribute` (sealed class, `AttributeUsage(AttributeTargets.Class, Inherited = false, AllowMultiple = false)`) exists in `HoneyDrunk.Standards` with `Strategy`, `Notes`, `Reason` properties
- [ ] `RollbackStrategy` enum exists in `HoneyDrunk.Standards` with members `ForwardMigration` and `NonRollback`
- [ ] Both types are public; XML documentation comments cite ADR-0048 D10/D12
- [ ] `HoneyDrunk.Standards` solution is minor-bumped; every non-test `.csproj` is at the same new version per invariant 27
- [ ] `HoneyDrunk.Standards/CHANGELOG.md` (repo-level) carries the minor-bump entry naming the new public API
- [ ] `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/CHANGELOG.md` (per-package) carries the same entry
- [ ] `HoneyDrunk.Standards`'s build is clean; existing tests still pass
- [ ] If a sanity test is added, it asserts construction with both strategies, default `Strategy = ForwardMigration`, and `AttributeUsage` on classes only
- [ ] No `Thread.Sleep` in any new test code per invariant 51
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0048 D10 — Forward-only rollback by default.** EF Core's `Down()` is generated but not committed to in production. Rollback is achieved by writing a new forward migration that reverses the unwanted change. The `[Rollback]` attribute declares the intent; it is informational, not runtime-enforced.

**ADR-0048 D12 — `[Rollback]` attribute on every migration class.** Two strategies: `ForwardMigration` (default, with optional `Notes`) and `NonRollback` (with required `Reason`). Missing the attribute is a review block per the `database` agent (packet 02).

**ADR-0048 D13 — Specialist `database` agent reads the attribute.** The agent (packet 02) checks for presence and reads the `Notes`/`Reason` for adequacy.

**Invariant 1 — Single Grid-wide contract, no cross-Node runtime edges through Node packages.** `RollbackAttribute` is a Grid-wide declarative type; it must not live inside a specific Node's package. Shipping it from `HoneyDrunk.Standards` (which every project already references via invariant 26) preserves invariant 1.

**Invariant 2 — Cross-Node runtime dependencies flow only through `*.Abstractions` and Grid-wide packages.** `HoneyDrunk.Standards` is a Grid-wide MSBuild/standards package referenced by every project; placing the attribute there satisfies the invariant.

**Invariant 26 — Every .NET project references `HoneyDrunk.Standards` with `PrivateAssets: all`.** Means the attribute is transitively available to every migration-bearing Node without any new `PackageReference`. Zero per-Node integration work.

**Invariant 27 — One version across the solution.** The Standards solution bumps its minor version together; every non-test `.csproj` lands at the same new version in one commit.

**Invariant 12 — Per-package CHANGELOG for changed packages.** `HoneyDrunk.Standards` has a functional change (new public API); per-package CHANGELOG entry is warranted.

## Constraints
- **Standards is the home, not a per-Node package.** Shipping `RollbackAttribute` inside `HoneyDrunk.Notify.Data` (or any Node's data package) violates invariants 1/2. Standards is the lean placement because invariant 26 means every project already references it.
- **No runtime enforcement.** The attribute is informational; do not add a Roslyn analyzer in this packet enforcing presence on `Migration` subclasses. That is a deferred follow-up if and when the operator wants compile-time enforcement.
- **No dependency on `Microsoft.EntityFrameworkCore`.** The attribute uses only the BCL. Migration classes consume `[Rollback]` after they already depend on EF Core for their `Migration` base class; the attribute itself is provider-agnostic.
- **Public, sealed, single-target.** The attribute targets classes only, is sealed, and disallows multiple instances on the same class.
- **Minor bump.** New public API; SemVer minor. Patch is wrong; major would be wrong (no breaking change).
- **No analyzer.** Don't introduce a Roslyn analyzer in `HoneyDrunk.Standards.Analyzers` to enforce presence — that is out of scope for this packet (and possibly out of scope for ADR-0048 entirely; see ADR-0048's deferred follow-up list).

## Labels
`feature`, `tier-2`, `core`, `adr-0048`, `wave-3`

## Agent Handoff

**Objective:** Ship the `RollbackAttribute` and `RollbackStrategy` declarative types from `HoneyDrunk.Standards` so every Node already has access through its existing `HoneyDrunk.Standards` `PackageReference`.

**Target:** `HoneyDrunk.Standards`, branch from `main`.

**Context:**
- Goal: Provide the canonical Grid-wide home for the `[Rollback]` attribute named in ADR-0048 D10/D12 without violating invariants 1/2 (boundary) or burdening every migration-bearing Node with a new `PackageReference`.
- Feature: ADR-0048 Schema Evolution rollout, Wave 3.
- ADRs: ADR-0048 D10/D12/D13 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0048 must be Accepted so the attribute's purpose is policy-backed.

**Constraints:**
- Standards is the home; not a Node package.
- Informational only; no runtime enforcement, no Roslyn analyzer.
- Minor version bump; one version across the Standards solution per invariant 27.
- No new package dependencies.

**Key Files:**
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/Migrations/RollbackAttribute.cs` (new).
- `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/Migrations/RollbackStrategy.cs` (new).
- `HoneyDrunk.Standards/CHANGELOG.md` and `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards/CHANGELOG.md`.
- Every non-test `.csproj` in the Standards solution (minor bump).

**Contracts:**
- `RollbackAttribute` (new public type in `HoneyDrunk.Standards`) — sealed class with `Strategy` (enum), `Notes` (string?), `Reason` (string?) properties; `AttributeUsage(Class)`, not inheritable, not multiple.
- `RollbackStrategy` (new public enum in `HoneyDrunk.Standards`) — `ForwardMigration` (default), `NonRollback`.
