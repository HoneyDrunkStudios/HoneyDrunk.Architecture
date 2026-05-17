---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.Rest
labels: ["bug", "tier-2", "core", "web-rest", "wave-3", "kernel-adoption"]
dependencies: ["packet:01"]
adrs: []
accepts: []
wave: 3
initiative: kernel-adoption-alignment
node: honeydrunk-web-rest
---

# Require Kernel context in Web.Rest request pipeline

## Summary
Ensure Web.Rest HTTP middleware consumes or establishes live Kernel request context instead of silently falling back to ad-hoc correlation values.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Web.Rest`

## Context
The audit found `CorrelationMiddleware` can process a request with no current Operation/Grid context, falling back to headers or generated GUIDs. That masks host misconfiguration and permits HTTP scoped operations without full Grid context/tenant.

## Scope
- Update Web.Rest ASP.NET Core middleware/registration so request handling requires or establishes Kernel context.
- Keep Web.Rest boundary focused on HTTP response shaping, exception mapping, correlation headers, and REST conventions; do not move Kernel hosting ownership into Web.Rest beyond explicit middleware integration.
- Add tests for missing/misordered Kernel context registration.

## Proposed Implementation
1. Inspect current `CorrelationMiddleware` and service registration.
2. Decide the smallest safe behavior: fail fast on missing Kernel context, or establish context via the Kernel-provided request middleware/factory before Web.Rest correlation processing.
3. Add tests for correctly wired host, missing Kernel context, and correlation mismatch behavior.
4. Update docs/README if host setup order changes.

## Affected Files
- `HoneyDrunk.Web.Rest.AspNetCore/Middleware/CorrelationMiddleware.cs`
- `HoneyDrunk.Web.Rest.AspNetCore/Extensions/ServiceCollectionExtensions.cs`
- Web.Rest tests/canaries
- README/changelogs

## NuGet Dependencies
Update Kernel package references to the package version from packet 01. No new packages expected.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Web.Rest` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] Every Web.Rest HTTP request path either has a populated Kernel `IGridContext`/`IOperationContext` or fails with an actionable configuration error.
- [ ] No request is processed with only an ad-hoc header/generated correlation ID and no tenant context.
- [ ] Middleware ordering/registration guidance is documented if changed.
- [ ] Repo-level and affected per-package changelogs updated; all non-test package versions aligned if bumped.
- [ ] `dotnet restore`, `dotnet build`, and `dotnet test` pass.

## Human Prerequisites
None.

Actor=Agent.

## Dependencies
This packet is blocked by: packet:01. Dependencies are mirrored in frontmatter for filing automation.

## Labels
`bug`, `tier-2`, `core`, `web-rest`, `wave-3`, `kernel-adoption`

## Agent Handoff

**Objective:** Ensure Web.Rest HTTP middleware consumes or establishes live Kernel request context instead of silently falling back to ad-hoc correlation values.
**Target:** HoneyDrunk.Web.Rest, branch from `main`

**Context:**
- Initiative: `kernel-adoption-alignment`.
- Audit trigger: Kernel adoption audit found uneven use of Grid context, version drift, and avoidable runtime dependencies.
- ADRs: None specific; governed by Grid invariants inlined below.

**Acceptance Criteria:** As listed above.

**Dependencies:** packet:01

**Constraints:**
- **Context invariant:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null tenant value. CorrelationId is never null or empty, and tenant context defaults to `TenantId.Internal` for internal Grid work.
- **Dependency invariant:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages except permitted `Microsoft.Extensions.*` abstractions. Runtime packages consume upstream Abstractions whenever possible; avoid full runtime dependencies unless a host composition package explicitly needs runtime behavior.
- **Packaging invariant:** Semantic versioning with repo-level `CHANGELOG.md`; per-package changelogs only for packages with actual functional changes. All non-test projects in a solution move versions together when a package version bump is warranted.
- **Testing invariant:** Tests never depend on external services. Use in-memory/fake collaborators. No test code in runtime packages; tests live in dedicated `.Tests` or `.Canary` projects.


**Key Files:**
- `HoneyDrunk.Web.Rest.AspNetCore/Middleware/CorrelationMiddleware.cs`
- `HoneyDrunk.Web.Rest.AspNetCore/Extensions/ServiceCollectionExtensions.cs`
- Web.Rest tests/canaries
- README/changelogs

**Contracts:**
No REST response contract change intended unless fail-fast errors are public; document any externally visible behavior.
