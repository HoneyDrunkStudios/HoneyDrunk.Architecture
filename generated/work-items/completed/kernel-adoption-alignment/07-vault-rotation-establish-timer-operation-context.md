---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault.Rotation
labels: ["bug", "tier-2", "core", "vault-rotation", "wave-3", "kernel-adoption"]
dependencies: ["work-item:01", "work-item:03"]
adrs: []
accepts: []
wave: 3
initiative: kernel-adoption-alignment
node: honeydrunk-vault-rotation
---

# Establish Kernel context for rotation timer jobs

## Summary
Ensure every Vault.Rotation timer execution creates a populated Kernel Grid/Operation context with correlation and tenant values.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault.Rotation`

## Context
The audit found the timer-triggered rotation function runs without injecting or initializing live `IGridContext`/`IOperationContext`; `RotationContext.CorrelationId` is nullable. Background jobs are scoped operations and must carry Grid context.

## Scope
- Add per-run context creation/initialization for timer-triggered rotation execution.
- Use canonical `WellKnownNodes.Core.VaultRotation` for Node identity when Kernel version supports it, while preserving deploy-time `HONEYDRUNK_NODE_ID` override if the host supports override.
- Ensure `RotationContext` has non-empty correlation and internal tenant/default context values.

## Proposed Implementation
1. Update Function startup/DI to register current Kernel context services.
2. At timer entry, create or scope a new operation context with correlation ID, `TenantId.Internal`, node ID, studio ID, and environment.
3. Flow that context into rotation orchestration and logging.
4. Add unit/integration tests for timer entry context creation and `RotationContext` correlation non-null behavior.

## Affected Files
- `HoneyDrunk.Vault.Rotation/Program.cs`
- `HoneyDrunk.Vault.Rotation/RotateThirdPartySecretsFunction.cs`
- `HoneyDrunk.Vault.Rotation.Abstractions/RotationContext.cs`
- Vault.Rotation tests
- `.csproj` package references and changelogs

## NuGet Dependencies
Update Kernel and Vault package references to versions from packets 01 and 03. No new external packages expected.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Vault.Rotation` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] Each timer execution has populated `IGridContext` and `IOperationContext` before rotation work begins.
- [ ] `RotationContext.CorrelationId` is non-null/non-empty for live rotations.
- [ ] Tenant context defaults to internal sentinel for system rotation work.
- [ ] Node identity uses Kernel well-known Vault.Rotation fallback while preserving env override semantics.
- [ ] Repo-level and affected per-package changelogs updated; all non-test package versions aligned if bumped.
- [ ] `dotnet restore`, `dotnet build`, and `dotnet test` pass.

## Human Prerequisites
None.

Actor=Agent.

## Dependencies
This packet is blocked by: work-item:01, work-item:03. Dependencies are mirrored in frontmatter for filing automation.

## Labels
`bug`, `tier-2`, `core`, `vault-rotation`, `wave-3`, `kernel-adoption`

## Agent Handoff

**Objective:** Ensure every Vault.Rotation timer execution creates a populated Kernel Grid/Operation context with correlation and tenant values.
**Target:** HoneyDrunk.Vault.Rotation, branch from `main`

**Context:**
- Initiative: `kernel-adoption-alignment`.
- Audit trigger: Kernel adoption audit found uneven use of Grid context, version drift, and avoidable runtime dependencies.
- ADRs: None specific; governed by Grid invariants inlined below.

**Acceptance Criteria:** As listed above.

**Dependencies:** work-item:01, work-item:03

**Constraints:**
- **Context invariant:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null tenant value. CorrelationId is never null or empty, and tenant context defaults to `TenantId.Internal` for internal Grid work.
- **Dependency invariant:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages except permitted `Microsoft.Extensions.*` abstractions. Runtime packages consume upstream Abstractions whenever possible; avoid full runtime dependencies unless a host composition package explicitly needs runtime behavior.
- **Packaging invariant:** Semantic versioning with repo-level `CHANGELOG.md`; per-package changelogs only for packages with actual functional changes. All non-test projects in a solution move versions together when a package version bump is warranted.
- **Testing invariant:** Tests never depend on external services. Use in-memory/fake collaborators. No test code in runtime packages; tests live in dedicated `.Tests` or `.Canary` projects.


**Key Files:**
- `HoneyDrunk.Vault.Rotation/Program.cs`
- `HoneyDrunk.Vault.Rotation/RotateThirdPartySecretsFunction.cs`
- `HoneyDrunk.Vault.Rotation.Abstractions/RotationContext.cs`
- Vault.Rotation tests
- `.csproj` package references and changelogs

**Contracts:**
Potential Abstractions behavior tightening: `RotationContext.CorrelationId` should become required/non-null if source-compatible. If breaking, bump version and document migration.
