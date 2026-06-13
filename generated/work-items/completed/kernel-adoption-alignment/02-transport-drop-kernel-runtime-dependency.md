---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Transport
labels: ["chore", "tier-2", "core", "transport", "wave-2", "kernel-adoption"]
dependencies: ["work-item:01"]
adrs: []
accepts: []
wave: 2
initiative: kernel-adoption-alignment
node: honeydrunk-transport
---

# Drop Transport dependency on Kernel runtime

## Summary
Update Transport to consume Kernel Abstractions for context creation/propagation instead of depending on full `HoneyDrunk.Kernel` runtime internals.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Transport`

## Context
Architecture compatibility already records Transport's runtime Kernel dependency as an invariant violation. The audit confirmed `GridContextFactory` casts to concrete Kernel `GridContext` to call `Initialize()`. Once Kernel exposes the needed Abstractions seam, Transport should move back to the intended dependency shape.

## Scope
- Replace direct `HoneyDrunk.Kernel` package references with the new `HoneyDrunk.Kernel.Abstractions` version where possible.
- Refactor context factory/propagation middleware to use the Kernel Abstractions seam from packet 01.
- Keep provider packages consuming only exported contracts.
- Update canaries/tests around message context propagation.

## Proposed Implementation
1. Update package references to the Kernel version produced by packet 01.
2. Refactor `Context/GridContextFactory.cs` and any middleware/helpers that require concrete `GridContext`.
3. Verify envelopes/messages still propagate correlation, causation, tenant, node, studio, and environment correctly.
4. Remove obsolete comments that describe the known invariant violation once fixed.

## Affected Files
- `HoneyDrunk.Transport/HoneyDrunk.Transport.csproj`
- `HoneyDrunk.Transport/Context/GridContextFactory.cs`
- `HoneyDrunk.Transport*/**/*Context*`
- `HoneyDrunk.Transport.Tests/**`
- `CHANGELOG.md` and per-package changelogs

## NuGet Dependencies
Update `HoneyDrunk.Kernel.Abstractions` to the package version from packet 01. Remove full `HoneyDrunk.Kernel` where no longer required.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Transport` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] `HoneyDrunk.Transport` no longer references full `HoneyDrunk.Kernel` unless a host-only composition project explicitly needs runtime hosting behavior.
- [ ] Context propagation tests/canaries pass and cover tenant/correlation preservation.
- [ ] No provider package consumes internal Transport or Kernel runtime implementation details.
- [ ] Repo-level and affected per-package changelogs updated; all non-test package versions aligned if bumped.
- [ ] `dotnet restore`, `dotnet build`, and `dotnet test` pass.

## Human Prerequisites
None.

Actor=Agent.

## Dependencies
This packet is blocked by: work-item:01. Dependencies are mirrored in frontmatter for filing automation.

## Labels
`chore`, `tier-2`, `core`, `transport`, `wave-2`, `kernel-adoption`

## Agent Handoff

**Objective:** Update Transport to consume Kernel Abstractions for context creation/propagation instead of depending on full `HoneyDrunk.Kernel` runtime internals.
**Target:** HoneyDrunk.Transport, branch from `main`

**Context:**
- Initiative: `kernel-adoption-alignment`.
- Audit trigger: Kernel adoption audit found uneven use of Grid context, version drift, and avoidable runtime dependencies.
- ADRs: None specific; governed by Grid invariants inlined below.

**Acceptance Criteria:** As listed above.

**Dependencies:** work-item:01

**Constraints:**
- **Context invariant:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null tenant value. CorrelationId is never null or empty, and tenant context defaults to `TenantId.Internal` for internal Grid work.
- **Dependency invariant:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages except permitted `Microsoft.Extensions.*` abstractions. Runtime packages consume upstream Abstractions whenever possible; avoid full runtime dependencies unless a host composition package explicitly needs runtime behavior.
- **Packaging invariant:** Semantic versioning with repo-level `CHANGELOG.md`; per-package changelogs only for packages with actual functional changes. All non-test projects in a solution move versions together when a package version bump is warranted.
- **Testing invariant:** Tests never depend on external services. Use in-memory/fake collaborators. No test code in runtime packages; tests live in dedicated `.Tests` or `.Canary` projects.


**Key Files:**
- `HoneyDrunk.Transport/HoneyDrunk.Transport.csproj`
- `HoneyDrunk.Transport/Context/GridContextFactory.cs`
- `HoneyDrunk.Transport*/**/*Context*`
- `HoneyDrunk.Transport.Tests/**`
- `CHANGELOG.md` and per-package changelogs

**Contracts:**
No Transport public contract change intended; dependency surface should shrink.
