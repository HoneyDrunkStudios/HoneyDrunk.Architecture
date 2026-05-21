---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "kernel", "wave-1", "kernel-adoption"]
dependencies: []
adrs: []
accepts: []
wave: 1
initiative: kernel-adoption-alignment
node: honeydrunk-kernel
---

# Align Kernel context bootstrap and well-known Node IDs

## Summary
Add the Kernel-side primitives needed for downstream Nodes to consume canonical Node identity and initialize Grid context without depending on concrete runtime internals.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Kernel`

## Context
The adoption audit found two Kernel-owned blockers: downstream Nodes need canonical `WellKnownNodes` values (`honeydrunk-*`) and Transport currently depends on full `HoneyDrunk.Kernel` because context initialization requires concrete `GridContext.Initialize()`. Kernel must provide the canonical source of truth so downstream repos do not duplicate identity strings or concrete initialization behavior.

## Scope
- Update `WellKnownNodes` to canonical `honeydrunk-*` values and include current Grid Nodes across Core/Ops/Meta/AI.
- Add an Abstractions-visible context bootstrap/factory seam sufficient for Transport and other downstream libraries to create/initialize valid Grid contexts without referencing the full Kernel runtime package.
- Preserve existing host composition APIs (`AddHoneyDrunkNode`, lifecycle, health/readiness) for app hosts.
- Update package versions/changelogs consistently across all non-test Kernel projects.

## Proposed Implementation
1. Pin canonical `WellKnownNodes` values in tests, including `honeydrunk-pulse`, `honeydrunk-notify`, `honeydrunk-vault-rotation`, `honeydrunk-audit`, and AI-sector IDs.
2. Introduce the minimal Abstractions seam for context initialization/factory behavior. Keep it cohesive; do not expose concrete runtime implementation details.
3. Update runtime implementation to satisfy the new seam.
4. Update README/package docs if public installation or API guidance changes.
5. Bump all non-test Kernel projects together and update repo-level + affected per-package changelogs.
6. Replace deprecated test packages if still present and verify no deprecated package output remains.

## Affected Files
- `HoneyDrunk.Kernel.Abstractions/**`
- `HoneyDrunk.Kernel/**`
- `HoneyDrunk.Kernel.Tests/**`
- `CHANGELOG.md` and per-package changelogs

## NuGet Dependencies
No new runtime packages expected. Test package cleanup may update `xunit.v3`, `Microsoft.NET.Test.Sdk`, `coverlet.collector`, and `FluentAssertions` as test-only dependencies.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Kernel` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] `WellKnownNodes` returns canonical `honeydrunk-*` IDs for all current Grid Nodes.
- [ ] Downstream libraries can create/initialize a valid Grid context through Abstractions-visible API without referencing concrete `HoneyDrunk.Kernel` types.
- [ ] New/updated tests cover canonical Node IDs, uniqueness, validity, and the context bootstrap seam.
- [ ] All non-test Kernel projects share the same new version.
- [ ] Repo-level `CHANGELOG.md` and affected per-package changelogs document the behavior/API changes.
- [ ] `dotnet restore`, `dotnet build`, `dotnet test`, and `dotnet list package --deprecated` pass for the solution.

## Human Prerequisites
None.

Actor=Agent.

## Dependencies
None.

## Labels
`feature`, `tier-2`, `core`, `kernel`, `wave-1`, `kernel-adoption`

## Agent Handoff

**Objective:** Add the Kernel-side primitives needed for downstream Nodes to consume canonical Node identity and initialize Grid context without depending on concrete runtime internals.
**Target:** HoneyDrunk.Kernel, branch from `main`

**Context:**
- Initiative: `kernel-adoption-alignment`.
- Audit trigger: Kernel adoption audit found uneven use of Grid context, version drift, and avoidable runtime dependencies.
- ADRs: None specific; governed by Grid invariants inlined below.

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- **Context invariant:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null tenant value. CorrelationId is never null or empty, and tenant context defaults to `TenantId.Internal` for internal Grid work.
- **Dependency invariant:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages except permitted `Microsoft.Extensions.*` abstractions. Runtime packages consume upstream Abstractions whenever possible; avoid full runtime dependencies unless a host composition package explicitly needs runtime behavior.
- **Packaging invariant:** Semantic versioning with repo-level `CHANGELOG.md`; per-package changelogs only for packages with actual functional changes. All non-test projects in a solution move versions together when a package version bump is warranted.
- **Testing invariant:** Tests never depend on external services. Use in-memory/fake collaborators. No test code in runtime packages; tests live in dedicated `.Tests` or `.Canary` projects.


**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/**`
- `HoneyDrunk.Kernel/**`
- `HoneyDrunk.Kernel.Tests/**`
- `CHANGELOG.md` and per-package changelogs

**Contracts:**
Kernel may add Abstractions-visible context bootstrap/factory contracts. Treat this as a minor or major version decision based on API compatibility; document any breaking behavior explicitly.
