---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["bug", "tier-2", "ops", "pulse", "wave-3", "kernel-adoption"]
dependencies: ["packet:01", "packet:02"]
adrs: []
accepts: []
wave: 3
initiative: kernel-adoption-alignment
node: honeydrunk-pulse
---

# Align Pulse to Kernel canonical identity

## Summary
Update Pulse Collector to use Kernel well-known Pulse identity as the fallback while preserving deploy-time `HONEYDRUNK_NODE_ID` override.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Pulse`

## Context
Pulse had identity drift: deployment/App Configuration uses `honeydrunk-pulse`, while Collector previously used short `pulse` fallbacks. Kernel now owns canonical `WellKnownNodes.Ops.Pulse`; Pulse should consume that rather than hardcoding strings.

## Scope
- Update `Pulse.Collector` Kernel reference to the version from packet 01.
- Use `WellKnownNodes.Ops.Pulse.Value` as fallback/default Node ID.
- Preserve `HONEYDRUNK_NODE_ID` override.
- Align Transport package references if needed after packet 02.

## Proposed Implementation
1. Replace short/hardcoded Pulse Node ID fallback in Collector startup.
2. Ensure `options.NodeId` uses configured override first, Kernel well-known fallback second.
3. Add/keep smoke test verifying default Node ID is `honeydrunk-pulse`.
4. Run Collector and transport publishing tests.

## Affected Files
- `Pulse.Collector/Program.cs`
- `Pulse.Collector/HoneyDrunk.Pulse.Collector.csproj`
- `Pulse.Tests/Collector/CollectorSmokeTests.cs`
- Pulse changelogs

## NuGet Dependencies
Update `HoneyDrunk.Kernel` to the version from packet 01. Update Transport packages to the version from packet 02 if required to avoid Kernel context ABI mismatch.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Pulse` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] No runtime `"pulse"` Node ID fallback remains in Collector startup.
- [ ] Default Collector `INodeContext.NodeId` is `honeydrunk-pulse`.
- [ ] `HONEYDRUNK_NODE_ID` override still wins.
- [ ] Transport publishing tests still pass with aligned Kernel/Transport versions.
- [ ] Repo-level and affected per-package changelogs updated; all non-test package versions aligned if bumped.
- [ ] `dotnet restore`, `dotnet build`, and `dotnet test` pass.

## Human Prerequisites
None.

Actor=Agent.

## Dependencies
This packet is blocked by: packet:01, packet:02. Dependencies are mirrored in frontmatter for filing automation.

## Labels
`bug`, `tier-2`, `ops`, `pulse`, `wave-3`, `kernel-adoption`

## Agent Handoff

**Objective:** Update Pulse Collector to use Kernel well-known Pulse identity as the fallback while preserving deploy-time `HONEYDRUNK_NODE_ID` override.
**Target:** HoneyDrunk.Pulse, branch from `main`

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
- `Pulse.Collector/Program.cs`
- `Pulse.Collector/HoneyDrunk.Pulse.Collector.csproj`
- `Pulse.Tests/Collector/CollectorSmokeTests.cs`
- Pulse changelogs

**Contracts:**
No Pulse public contract change intended; runtime identity fallback changes.
