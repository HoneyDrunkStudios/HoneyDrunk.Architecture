---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["bug", "tier-2", "ops", "notify", "wave-3", "kernel-adoption", "adr-0005", "adr-0006"]
dependencies: ["work-item:01", "work-item:03"]
adrs: ["ADR-0005", "ADR-0006"]
accepts: []
wave: 3
initiative: kernel-adoption-alignment
node: honeydrunk-notify
---

# Align Notify Kernel identity and queue secret boundary

## Summary
Update Notify to use Kernel canonical Notify identity and remove direct queue connection secret/config reads from runtime bootstrap paths.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Notify`

## Context
The audit found Notify hardcodes `HONEYDRUNK_NODE_ID = "honeydrunk-notify"` in Worker/Functions and reads `NotifyQueueConnection` directly for Azure Storage Queue wiring. Notify should use Kernel well-known identity fallback while preserving env override, and queue credentials should follow the Grid Vault/App Configuration bootstrap model.

## Scope
- Replace hardcoded Notify Node ID fallback with `WellKnownNodes.Ops.Notify` once Kernel version supports it.
- Preserve deploy-time `HONEYDRUNK_NODE_ID` override; do not overwrite an existing env/config value.
- Move queue credential resolution away from direct config secret reads toward Vault/managed identity/App Configuration bootstrap semantics.
- Review Azure Functions `QueueTrigger(Connection=...)` constraints; if Functions runtime requires an app setting name, document the boundary and ensure the value is populated via deployment/bootstrap rather than committed config.

## Proposed Implementation
1. Update Worker and Functions startup identity fallback to Kernel well-known Notify ID.
2. Replace direct `builder.Configuration["NotifyQueueConnection"]` use where possible with `ISecretStore` or managed identity-capable queue client wiring.
3. For Functions trigger binding, document/implement the deployment-safe pattern for the connection setting without exposing secret values in source/logs.
4. Add tests for env override, default Node ID, and queue option resolution behavior.

## Affected Files
- `HoneyDrunk.Notify.Worker/Program.cs`
- `HoneyDrunk.Notify.Functions/Program.cs`
- `HoneyDrunk.Notify.Functions/NotifyDispatcherFunction.cs`
- `HoneyDrunk.Notify.Queue.AzureStorage/**`
- Notify tests/canaries
- `.csproj` package references and changelogs

## NuGet Dependencies
Update Kernel package references to the version from packet 01 and Vault package references to the version from packet 03 where needed. No new queue SDK expected unless moving to identity-based Azure Queue client construction requires it.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Notify` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] Notify Worker and Functions default to `WellKnownNodes.Ops.Notify.Value` and do not overwrite an existing `HONEYDRUNK_NODE_ID` override.
- [ ] Queue connection secret is not read directly as an application secret in runtime code except for an unavoidable Functions binding setting documented as deployment-provided.
- [ ] No secret values are logged/traced; only secret names/identifiers appear in diagnostics.
- [ ] Tests cover default identity, env override, and queue credential resolution/failure behavior.
- [ ] Repo-level and affected per-package changelogs updated; all non-test package versions aligned if bumped.
- [ ] `dotnet restore`, `dotnet build`, and `dotnet test` pass.

## Human Prerequisites
- [ ] If the final Functions binding still requires an app setting, ensure deploy/runtime configuration provides `NotifyQueueConnection` or the replacement setting from Vault/App Configuration without committing secret values.

Actor=Agent.

## Dependencies
This packet is blocked by: work-item:01, work-item:03. Dependencies are mirrored in frontmatter for filing automation.

## Labels
`bug`, `tier-2`, `ops`, `notify`, `wave-3`, `kernel-adoption`, `adr-0005`, `adr-0006`

## Agent Handoff

**Objective:** Update Notify to use Kernel canonical Notify identity and remove direct queue connection secret/config reads from runtime bootstrap paths.
**Target:** HoneyDrunk.Notify, branch from `main`

**Context:**
- Initiative: `kernel-adoption-alignment`.
- Audit trigger: Kernel adoption audit found uneven use of Grid context, version drift, and avoidable runtime dependencies.
- ADRs: ADR-0005, ADR-0006

**Acceptance Criteria:** As listed above.

**Dependencies:** work-item:01, work-item:03

**Constraints:**
- **Context invariant:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null tenant value. CorrelationId is never null or empty, and tenant context defaults to `TenantId.Internal` for internal Grid work.
- **Dependency invariant:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages except permitted `Microsoft.Extensions.*` abstractions. Runtime packages consume upstream Abstractions whenever possible; avoid full runtime dependencies unless a host composition package explicitly needs runtime behavior.
- **Packaging invariant:** Semantic versioning with repo-level `CHANGELOG.md`; per-package changelogs only for packages with actual functional changes. All non-test projects in a solution move versions together when a package version bump is warranted.
- **Testing invariant:** Tests never depend on external services. Use in-memory/fake collaborators. No test code in runtime packages; tests live in dedicated `.Tests` or `.Canary` projects.


**Key Files:**
- `HoneyDrunk.Notify.Worker/Program.cs`
- `HoneyDrunk.Notify.Functions/Program.cs`
- `HoneyDrunk.Notify.Functions/NotifyDispatcherFunction.cs`
- `HoneyDrunk.Notify.Queue.AzureStorage/**`
- Notify tests/canaries
- `.csproj` package references and changelogs

**Contracts:**
No Notify public notification contract change intended. Runtime bootstrap behavior changes; document in release notes.
