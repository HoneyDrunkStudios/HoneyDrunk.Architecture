---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Data
labels: ["bug", "tier-2", "core", "data", "wave-3", "kernel-adoption"]
dependencies: ["packet:01", "packet:02"]
adrs: []
accepts: []
wave: 3
initiative: kernel-adoption-alignment
node: honeydrunk-data
---

# Require context for Data outbox enrichment

## Summary
Make Data outbox context enrichment fail fast when configured but no current Kernel operation context exists.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Data`

## Context
The audit found `EfOutboxWriter` silently emits outbox messages without correlation/tenant when `IOperationContextAccessor.Current` is null. That drops Grid context across async/message boundaries and makes downstream diagnostics unreliable.

## Scope
- Update outbox write path to require current operation/grid context when `AutoPopulateFromContext` is enabled.
- Preserve explicit override paths for tests or deliberate system messages only if they still produce valid correlation/tenant context.
- Update package references after Kernel/Transport alignment.

## Proposed Implementation
1. Inspect `EfOutboxWriter` context enrichment branch.
2. Add fail-fast validation when autopopulation is enabled and operation/grid context is missing or incomplete.
3. Add tests for populated context, missing context fail-fast, explicit metadata override, and tenant propagation.
4. Verify Transport outbox integration still passes after packet 02.

## Affected Files
- `HoneyDrunk.Data.Outbox/Persistence/EfOutboxWriter.cs`
- `HoneyDrunk.Data/Registration/ServiceCollectionExtensions.cs`
- Data outbox tests/canaries
- `.csproj` package references
- `CHANGELOG.md` and per-package changelogs

## NuGet Dependencies
Update Kernel package references to the package version from packet 01 and Transport references to the version from packet 02 where applicable.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Data` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] Outbox messages produced with autopopulation enabled always include correlation and tenant context.
- [ ] Missing operation/grid context fails fast with a clear exception instead of silently publishing partial metadata.
- [ ] Tests cover success/failure paths and tenant propagation.
- [ ] Repo-level and affected per-package changelogs updated; all non-test package versions aligned if bumped.
- [ ] `dotnet restore`, `dotnet build`, and `dotnet test` pass.

## Human Prerequisites
None.

Actor=Agent.

## Dependencies
This packet is blocked by: packet:01, packet:02. Dependencies are mirrored in frontmatter for filing automation.

## Labels
`bug`, `tier-2`, `core`, `data`, `wave-3`, `kernel-adoption`

## Agent Handoff

**Objective:** Make Data outbox context enrichment fail fast when configured but no current Kernel operation context exists.
**Target:** HoneyDrunk.Data, branch from `main`

**Context:**
- Initiative: `kernel-adoption-alignment`.
- Audit trigger: Kernel adoption audit found uneven use of Grid context, version drift, and avoidable runtime dependencies.
- ADRs: None specific; governed by Grid invariants inlined below.

**Acceptance Criteria:** As listed above.

**Dependencies:** packet:01, packet:02

**Constraints:**
- **Context invariant:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null tenant value. CorrelationId is never null or empty, and tenant context defaults to `TenantId.Internal` for internal Grid work.
- **Dependency invariant:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages except permitted `Microsoft.Extensions.*` abstractions. Runtime packages consume upstream Abstractions whenever possible; avoid full runtime dependencies unless a host composition package explicitly needs runtime behavior.
- **Packaging invariant:** Semantic versioning with repo-level `CHANGELOG.md`; per-package changelogs only for packages with actual functional changes. All non-test projects in a solution move versions together when a package version bump is warranted.
- **Testing invariant:** Tests never depend on external services. Use in-memory/fake collaborators. No test code in runtime packages; tests live in dedicated `.Tests` or `.Canary` projects.


**Key Files:**
- `HoneyDrunk.Data.Outbox/Persistence/EfOutboxWriter.cs`
- `HoneyDrunk.Data/Registration/ServiceCollectionExtensions.cs`
- Data outbox tests/canaries
- `.csproj` package references
- `CHANGELOG.md` and per-package changelogs

**Contracts:**
Behavioral contract change: missing context with autopopulation enabled becomes an error. Document in changelog/README if public.
