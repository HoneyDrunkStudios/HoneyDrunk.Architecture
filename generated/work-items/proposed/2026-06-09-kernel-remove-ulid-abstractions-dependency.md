---
title: Remove Ulid dependency from Kernel.Abstractions
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
node: HoneyDrunk.Kernel
type: chore
tier: tier-2
sector: Core
wave: standalone
initiative: tactical-node-audit
dependencies: []
labels: ["chore", "tier-2", "sector-core"]
adrs: ["ADR-0026", "ADR-0035", "ADR-0043"]
source: tactical
generator: node-audit
---

## Summary

Remove the direct `Ulid` package dependency from `HoneyDrunk.Kernel.Abstractions` so the contracts package complies with the Grid Abstractions dependency invariant.

## Context

The ADR-0043 tactical audit report at `generated/audits/HoneyDrunk.Kernel-2026-06-09.md` found that `HoneyDrunk.Kernel.Abstractions.csproj` references `Ulid` 1.4.1 directly. `dotnet list HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj package --include-transitive` confirms `Ulid` as a top-level package.

The same audit found public identity types and `GridContextSnapshot` using `Ulid` from the Abstractions package. That makes every downstream consumer inherit a third-party identity package pin from Kernel's contract surface.

## Scope

- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions/`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel/` only where runtime implementation must move ULID generation/parsing support
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Tests/`
- Package and repo changelogs
- READMEs if public identity API shape changes

## Proposed Implementation

Replace the contract package's dependency on the external `Ulid` package with a dependency-free Kernel-owned representation for ULID-shaped identity values. Keep string parse/format semantics stable where practical. If public members currently accepting or returning the external `Ulid` type must be removed, treat this as a breaking pre-1.0 Kernel release and document migration from `Ulid`-typed APIs to string-backed or Kernel-owned APIs.

## Acceptance Criteria

- [ ] `HoneyDrunk.Kernel.Abstractions.csproj` no longer contains a `PackageReference` to `Ulid`.
- [ ] Public Abstractions APIs no longer require consumers to reference the external `Ulid` type.
- [ ] Identity primitives still validate ULID-shaped string values and still provide `NewId`, `Parse`, `TryParse`, `ToString`, equality, and internal sentinel behavior where those APIs exist today.
- [ ] `TenantId.Internal` remains stable at the existing sentinel value.
- [ ] Unit tests cover successful parse, failed parse, generated ID validity, equality, and `TenantId.Internal`.
- [ ] If public API shape changes, both package versions move together per solution versioning rules and changelogs document the break.
- [ ] `dotnet test HoneyDrunk.Kernel/HoneyDrunk.Kernel.slnx --configuration Release` passes.
- [ ] README/package docs are updated if installation or public identity API usage changes.

## Human Prerequisites

None.

## Dependencies

None.

## NuGet Dependencies

Existing package references to keep unless the implementation proves they are unused:

- `HoneyDrunk.Standards` `0.2.9` with `PrivateAssets: all`
- `Microsoft.Extensions.Configuration.Abstractions` `10.0.5`
- `Microsoft.Extensions.DependencyInjection.Abstractions` `10.0.5`
- `Microsoft.Extensions.Hosting.Abstractions` `10.0.5`
- `Microsoft.CodeAnalysis.NetAnalyzers` `10.0.201` via `PackageReference Update`

Required dependency removal:

- Remove `Ulid` `1.4.1` from `HoneyDrunk.Kernel.Abstractions`.

Runtime package handling:

- `HoneyDrunk.Kernel` may keep or remove its own `Ulid` dependency based on implementation needs, but `HoneyDrunk.Kernel.Abstractions` must not expose or require it.

## Constraints

- Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.
- Kernel.Abstractions has zero HoneyDrunk dependencies. Only `Microsoft.Extensions.*` abstractions are allowed.
- Kernel owns identity grammar: strongly typed ID primitives, including `TenantId.Internal`.
- Kernel does not own BCL wrappers. No `IClock`, `IIdGenerator`, or `ILogSink`. Use BCL directly.
- All public APIs have XML documentation.
- All projects in a solution share one version and move together. When a version bump is warranted, every `.csproj` in the solution, excluding test projects, is updated to the same new version in a single commit. Partial bumps are forbidden.
- Semantic versioning with CHANGELOG and README. Breaking changes bump major. New features bump minor. Fixes bump patch. Repo-level `CHANGELOG.md` is mandatory and every version that ships must have an entry. Every package directory must also contain a `README.md` describing the package purpose, installation, and public API surface.

## Agent Handoff

**Objective:** Remove the third-party `Ulid` dependency from Kernel.Abstractions without losing ULID-shaped identity validation.
**Target:** HoneyDrunk.Kernel, branch from `main`
**Context:**
- Goal: ADR-0043 tactical node audit follow-up
- Feature: Kernel contract dependency hygiene
- ADRs: ADR-0026, ADR-0035, ADR-0043

**Acceptance Criteria:**
- [ ] `HoneyDrunk.Kernel.Abstractions` has no `Ulid` package reference or public `Ulid`-typed API requirement.
- [ ] Tests prove identity generation/parsing still works.
- [ ] Version and changelog handling follows Grid invariants.

**Dependencies:**
- None.

**Constraints:**
- Do not add another non-Microsoft third-party dependency to Abstractions.
- Do not move identity grammar out of Kernel.
- Treat any public API shape change as a documented breaking pre-1.0 release.

**Key Files:**
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions/Identity/*.cs`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions/Context/GridContextSnapshot.cs`
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Tests/Identity/`
- `HoneyDrunk.Kernel/CHANGELOG.md`

**Contracts:**
- `CorrelationId`
- `CausationId`
- `OperationId`
- `NodeId`
- `TenantId`
- `ProjectId`
- `RunId`
- `StudioId`
- `GridContextSnapshot`
