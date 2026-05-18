---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Vault
labels: ["chore", "tier-2", "core", "vault", "wave-3", "kernel-adoption"]
dependencies: ["packet:01"]
adrs: []
accepts: []
wave: 3
initiative: kernel-adoption-alignment
node: honeydrunk-vault
---

# Align Vault to current Kernel packages

## Summary
Update Vault Kernel package references and canaries to the current Kernel version while preserving Vault as the secret boundary.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Vault`

## Context
Vault adoption is mostly healthy: it uses Kernel lifecycle/health/readiness and remains the Grid secret boundary. The remaining issue is version drift after Kernel alignment.

## Scope
- Update Kernel package references to the version produced by packet 01.
- Verify lifecycle, health/readiness, App Configuration, Key Vault bootstrap, and Event Grid invalidation still work.
- Do not move secret retrieval out of Vault or introduce direct secret reads in consumers.

## Proposed Implementation
1. Update `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` references as applicable.
2. Run and update canaries/tests that cover lifecycle, secret store, App Configuration, and event-driven invalidation.
3. Update changelogs/version metadata per solution rules.

## Affected Files
- `HoneyDrunk.Vault*/**/*.csproj`
- Vault registration/lifecycle/health files
- Vault tests/canaries
- `CHANGELOG.md` and per-package changelogs

## NuGet Dependencies
Update Kernel package references to the package version from packet 01. No new packages expected.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Vault` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] Vault builds/tests against the current Kernel package version.
- [ ] Existing Vault lifecycle/health/readiness behavior remains intact.
- [ ] No new direct secret logging or config-file secret reads are introduced.
- [ ] Repo-level and affected per-package changelogs updated; all non-test package versions aligned if bumped.
- [ ] `dotnet restore`, `dotnet build`, and `dotnet test` pass.

## Human Prerequisites
None.

Actor=Agent.

## Dependencies
This packet is blocked by: packet:01. Dependencies are mirrored in frontmatter for filing automation.

## Labels
`chore`, `tier-2`, `core`, `vault`, `wave-3`, `kernel-adoption`

## Agent Handoff

**Objective:** Update Vault Kernel package references and canaries to the current Kernel version while preserving Vault as the secret boundary.
**Target:** HoneyDrunk.Vault, branch from `main`

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
- `HoneyDrunk.Vault*/**/*.csproj`
- Vault registration/lifecycle/health files
- Vault tests/canaries
- `CHANGELOG.md` and per-package changelogs

**Contracts:**
No Vault public contract change intended.
