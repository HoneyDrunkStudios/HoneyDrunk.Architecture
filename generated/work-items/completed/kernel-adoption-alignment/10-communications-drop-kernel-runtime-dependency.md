---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["chore", "tier-2", "ops", "communications", "wave-3", "kernel-adoption"]
dependencies: ["work-item:01"]
adrs: []
accepts: []
wave: 3
initiative: kernel-adoption-alignment
node: honeydrunk-communications
---

# Drop Communications runtime Kernel dependency

## Summary
Remove the unnecessary `HoneyDrunk.Kernel` runtime dependency from Communications when Abstractions-only references are sufficient.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Communications`

## Context
The audit found Communications conceptually propagates Grid context well through decisions and Notify envelopes, but its runtime package references both `HoneyDrunk.Kernel` and `HoneyDrunk.Kernel.Abstractions`. Source usage appears to need only Kernel abstractions (`IGridContextAccessor`, `IOperationContextAccessor`, lifecycle/health, telemetry factory).

## Scope
- Remove full `HoneyDrunk.Kernel` package reference if no concrete runtime types are used.
- Keep `HoneyDrunk.Kernel.Abstractions` and validate host-time prerequisites remain enforced by `AddCommunications()`.
- Preserve Communications boundary: decision logic lives in Communications; delivery remains Notify.

## Proposed Implementation
1. Remove `HoneyDrunk.Kernel` reference from runtime project.
2. Update `HoneyDrunk.Kernel.Abstractions` to the version from packet 01.
3. Build to identify any accidental concrete runtime usage; replace with abstractions or host prerequisites.
4. Keep/extend tests around `IGridContextAccessor` propagation into decision logs and `NotificationEnvelope`.

## Affected Files
- `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj`
- `src/HoneyDrunk.Communications/CommunicationsServiceCollectionExtensions.cs`
- `src/HoneyDrunk.Communications/Internal/CommunicationOrchestrator.cs`
- Communications tests
- changelogs

## NuGet Dependencies
Remove full `HoneyDrunk.Kernel`; update `HoneyDrunk.Kernel.Abstractions` to the package version from packet 01. No new packages expected.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Communications` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] `HoneyDrunk.Communications` runtime package has no full `HoneyDrunk.Kernel` dependency unless a concrete use is justified in the PR.
- [ ] `AddCommunications()` still validates required Kernel abstractions and Notify sender registration.
- [ ] Decision logs and Notify envelopes still carry correlation, node/environment, and tenant context.
- [ ] Repo-level and affected per-package changelogs updated; all non-test package versions aligned if bumped.
- [ ] `dotnet restore`, `dotnet build`, and `dotnet test` pass.

## Human Prerequisites
None.

Actor=Agent.

## Dependencies
This packet is blocked by: work-item:01. Dependencies are mirrored in frontmatter for filing automation.

## Labels
`chore`, `tier-2`, `ops`, `communications`, `wave-3`, `kernel-adoption`

## Agent Handoff

**Objective:** Remove the unnecessary `HoneyDrunk.Kernel` runtime dependency from Communications when Abstractions-only references are sufficient.
**Target:** HoneyDrunk.Communications, branch from `main`

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
- `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj`
- `src/HoneyDrunk.Communications/CommunicationsServiceCollectionExtensions.cs`
- `src/HoneyDrunk.Communications/Internal/CommunicationOrchestrator.cs`
- Communications tests
- changelogs

**Contracts:**
No Communications public contract change intended; dependency surface should shrink.
