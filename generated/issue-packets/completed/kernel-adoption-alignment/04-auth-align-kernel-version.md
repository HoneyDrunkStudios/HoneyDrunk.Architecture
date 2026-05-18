---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Auth
labels: ["chore", "tier-2", "core", "auth", "wave-3", "kernel-adoption"]
dependencies: ["packet:01", "packet:03"]
adrs: []
accepts: []
wave: 3
initiative: kernel-adoption-alignment
node: honeydrunk-auth
---

# Align Auth to current Kernel packages

## Summary
Update Auth Kernel package references and verify Auth continues to consume Vault-backed secrets and Kernel context correctly.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Auth`

## Context
Auth adoption is functionally healthy but version-lagged. It should align after Kernel and Vault references are current so token validation, policy evaluation, startup validation, and Vault signing-key retrieval stay coherent.

## Scope
- Update Kernel references to the current version.
- Verify Auth still requires `AddHoneyDrunkNode()`/Kernel services and retrieves signing keys through Vault, not config/env secrets.
- Preserve Auth boundary: validate tokens, do not issue them.

## Proposed Implementation
1. Update package references to current Kernel/Vault versions as needed.
2. Run token validation, policy, startup validation, and Vault signing-key tests.
3. Update changelogs/version metadata per solution rules.

## Affected Files
- `HoneyDrunk.Auth*/**/*.csproj`
- Auth startup/DI validation files
- Vault signing-key retrieval code
- Auth tests/canaries
- `CHANGELOG.md` and per-package changelogs

## NuGet Dependencies
Update Kernel package references to the package version from packet 01; update Vault package reference only if required by packet 03.

## Boundary Check
- [x] Work is scoped to `HoneyDrunk.Auth` and stays inside that Node's ownership boundary.
- [x] Kernel-owned primitives remain in Kernel; downstream repos consume them rather than reimplementing context or identity rules.
- [x] No secrets are introduced into source, logs, traces, or test fixtures.

## Acceptance Criteria
- [ ] Auth builds/tests against current Kernel packages.
- [ ] JWT signing keys still resolve through Vault (`ISecretStore`), not direct env/config secret reads.
- [ ] Auth validates tokens only; no identity-provider/token-issuer behavior is added.
- [ ] Repo-level and affected per-package changelogs updated; all non-test package versions aligned if bumped.
- [ ] `dotnet restore`, `dotnet build`, and `dotnet test` pass.

## Human Prerequisites
None.

Actor=Agent.

## Dependencies
This packet is blocked by: packet:01, packet:03. Dependencies are mirrored in frontmatter for filing automation.

## Labels
`chore`, `tier-2`, `core`, `auth`, `wave-3`, `kernel-adoption`

## Agent Handoff

**Objective:** Update Auth Kernel package references and verify Auth continues to consume Vault-backed secrets and Kernel context correctly.
**Target:** HoneyDrunk.Auth, branch from `main`

**Context:**
- Initiative: `kernel-adoption-alignment`.
- Audit trigger: Kernel adoption audit found uneven use of Grid context, version drift, and avoidable runtime dependencies.
- ADRs: None specific; governed by Grid invariants inlined below.

**Acceptance Criteria:** As listed above.

**Dependencies:** packet:01, packet:03

**Constraints:**
- **Context invariant:** GridContext must be present in every scoped operation. Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null tenant value. CorrelationId is never null or empty, and tenant context defaults to `TenantId.Internal` for internal Grid work.
- **Dependency invariant:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages except permitted `Microsoft.Extensions.*` abstractions. Runtime packages consume upstream Abstractions whenever possible; avoid full runtime dependencies unless a host composition package explicitly needs runtime behavior.
- **Packaging invariant:** Semantic versioning with repo-level `CHANGELOG.md`; per-package changelogs only for packages with actual functional changes. All non-test projects in a solution move versions together when a package version bump is warranted.
- **Testing invariant:** Tests never depend on external services. Use in-memory/fake collaborators. No test code in runtime packages; tests live in dedicated `.Tests` or `.Canary` projects.


**Key Files:**
- `HoneyDrunk.Auth*/**/*.csproj`
- Auth startup/DI validation files
- Vault signing-key retrieval code
- Auth tests/canaries
- `CHANGELOG.md` and per-package changelogs

**Contracts:**
No Auth public contract change intended.
