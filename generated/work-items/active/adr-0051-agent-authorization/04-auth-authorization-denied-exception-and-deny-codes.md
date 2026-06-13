---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Auth
labels: ["feature", "tier-2", "ai", "adr-0051", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0051"]
wave: 2
initiative: adr-0051-agent-authorization
node: honeydrunk-auth
---

# Add AuthorizationDeniedException + extend AuthorizationDenyCode with the four agent-authz reasons

## Summary
Add `AuthorizationDeniedException` to `HoneyDrunk.Auth.Abstractions` — the single typed exception ADR-0051 D11 commits for agent authorization failures — and extend the existing `AuthorizationDenyCode` enum with four new members (`CapabilityMissing`, `ScopeMismatch`, `GrantExpired`, `PrincipalTypeMismatch`) matching ADR-0051 D10's `deny.reason` audit field values. This is the version-bumping packet for the `HoneyDrunk.Auth` solution.

## Context
ADR-0051 D11 says "`AuthorizationDeniedException` is the single exception type" thrown by `IToolInvoker` when an agent's authorization check fails. The exception carries `Reason`, `MissingCapability` (optional), `ToolName`, `AgentId` — and the `Reason` value comes from a set of four named reasons: `capability_missing`, `scope_mismatch`, `grant_expired`, `principal_type_mismatch` (D10's `deny.reason` field).

A `DenyReason` type already exists in `HoneyDrunk.Auth.Abstractions/DenyReason.cs` — a `readonly record struct` combining the existing `AuthorizationDenyCode` enum and a `string Message`. Per the dispatch plan's Cross-Cutting decision, this packet **reuses** the existing types rather than introducing a parallel `DenyReason` enum: the four new reasons join `AuthorizationDenyCode` as additive enum members, and `AuthorizationDeniedException` carries a full `DenyReason` (the existing struct) plus the ADR-0051-specific `MissingCapability` / `ToolName` / `AgentId` context.

`HoneyDrunk.Auth.Abstractions` currently houses `AuthenticatedIdentity`, `IAuthorizationPolicy`, `AuthorizationRequest`, `AuthorizationDecision`, `DenyReason`, `AuthorizationDenyCode`, `AuthScheme`, `AuthCredential`, `IAuthenticationProvider`, `AuthClaimTypes`, `AuthenticationFailureCode`, `AuthenticationResult` — a tight, well-shaped surface. The four new enum values and the one new exception type are additive minor changes; no existing public API moves or renames.

`HoneyDrunk.Auth` consumes `AgentId` from `HoneyDrunk.Kernel.Abstractions` `0.8.0` (packet 03). The exception's `AgentId` slot uses the Kernel type. This packet picks up `HoneyDrunk.Kernel.Abstractions` `0.8.0` as a `PackageReference` version bump on whichever project carries `AuthorizationDeniedException` (Abstractions).

## Scope

- `HoneyDrunk.Auth.Abstractions/AuthorizationDenyCode.cs` — add four new enum members:
  - `CapabilityMissing = 10` (the matched `deny.reason` for "no bundle grants the required capability")
  - `ScopeMismatch = 11` (tenant or on-behalf-of scope binding didn't satisfy the requirement)
  - `GrantExpired = 12` (`AgentPrincipal.NotAfter < DateTimeOffset.UtcNow`)
  - `PrincipalTypeMismatch = 13` (a non-agent principal invoked the agent-tool surface)
  - Pick the numeric values to fit the existing enum's numbering (the existing enum uses 0..8 with 99 reserved for `InternalError` — start the agent-authz reasons at 10 to leave room and keep them visually grouped). The executor must check the enum at execution time and pick concrete numbers that don't collide.
- `HoneyDrunk.Auth.Abstractions/AuthorizationDeniedException.cs` — new class:
  ```
  public sealed class AuthorizationDeniedException : Exception
  {
      public DenyReason Reason { get; }
      public string ToolName { get; }
      public AgentId AgentId { get; }
      public string? MissingCapability { get; }
      // constructors, XML doc
  }
  ```
  - Constructor takes `DenyReason reason, string toolName, AgentId agentId, string? missingCapability = null, Exception? inner = null`.
  - `Message` composes a one-line summary from the components for log readability (`"Authorization denied for agent {AgentId} invoking tool '{ToolName}': {Reason.Code} ({MissingCapability})"`).
  - Serializable per the framework defaults; the type is sealed and exposes only readable properties.
- `HoneyDrunk.Auth.Abstractions.csproj` — bump the `HoneyDrunk.Kernel.Abstractions` `PackageReference` to `0.8.0` (the packet 03 release; the version must be published before this packet's PR can build — see Human Prerequisites).
- Every non-test `.csproj` in the `HoneyDrunk.Auth` solution version-bumped one minor version (invariant 27). Confirm the current version at execution time.
- `HoneyDrunk.Auth.Abstractions/CHANGELOG.md` and `README.md` updated.
- Repo-level `CHANGELOG.md` new version entry.

## Proposed Implementation

1. **Extend `AuthorizationDenyCode`** — add the four new members with explicit numeric values that do not collide with the existing 0..8 + 99. Place them after `PolicyNotFound = 8` and before `InternalError = 99`, e.g. starting at 10. XML-doc each one in the existing style.

2. **Create `AuthorizationDeniedException`** — a sealed class deriving from `Exception`. Properties: `DenyReason Reason`, `string ToolName`, `AgentId AgentId`, `string? MissingCapability`. Default constructor not provided — every throw site supplies the required context.

3. **`AgentId` `using`** — the exception lives in `HoneyDrunk.Auth.Abstractions` and depends on `HoneyDrunk.Kernel.Abstractions/Agents/AgentId`. Add the `using HoneyDrunk.Kernel.Abstractions.Agents;` (or whichever namespace the type ships in per packet 03's chosen layout) and update the `.csproj` `PackageReference` to `HoneyDrunk.Kernel.Abstractions` `0.8.0`.

4. **Unit tests** — `AuthorizationDeniedException` construction with required + optional parameters; `Message` composition; property round-trip; serialization smoke test if the existing Auth.Abstractions test project verifies any other exception type's serialization. New `AuthorizationDenyCode` enum members compile and bind to `DenyReason` correctly. Place tests in the existing `HoneyDrunk.Auth.Tests` project.

5. **Versioning** — `HoneyDrunk.Auth.Abstractions` is the changed package (new enum members + new exception type). The runtime `HoneyDrunk.Auth` and `HoneyDrunk.Auth.AspNetCore` packages and the canary project receive the same version bump for solution alignment (invariant 27). Only `HoneyDrunk.Auth.Abstractions` gets a per-package CHANGELOG entry; the others are alignment bumps only (invariant 12/27). The repo-level `CHANGELOG.md` gets a new version entry covering the additive changes.

6. **README** — update `HoneyDrunk.Auth.Abstractions/README.md` to document the new `AuthorizationDeniedException` type and the four new `AuthorizationDenyCode` members in the public-API section.

## Affected Files
- `HoneyDrunk.Auth.Abstractions/AuthorizationDenyCode.cs` — four new enum members
- `HoneyDrunk.Auth.Abstractions/AuthorizationDeniedException.cs` — new file
- `HoneyDrunk.Auth.Abstractions/HoneyDrunk.Auth.Abstractions.csproj` — `HoneyDrunk.Kernel.Abstractions` `PackageReference` bumped to `0.8.0`; solution version bumped
- `HoneyDrunk.Auth/HoneyDrunk.Auth.csproj`, `HoneyDrunk.Auth.AspNetCore/HoneyDrunk.Auth.AspNetCore.csproj`, `HoneyDrunk.Auth.Canary/HoneyDrunk.Auth.Canary.csproj` — version alignment
- `HoneyDrunk.Auth.Abstractions/CHANGELOG.md`, `HoneyDrunk.Auth.Abstractions/README.md`
- Repo-level `CHANGELOG.md`
- `HoneyDrunk.Auth.Tests/` — new unit tests for the exception and enum members

## NuGet Dependencies
- **`HoneyDrunk.Auth.Abstractions`** — bump the existing `HoneyDrunk.Kernel.Abstractions` `PackageReference` to `0.8.0` (the version this initiative's packet 03 ships). No other new HoneyDrunk dependency. Per invariant 1, Auth.Abstractions stays zero-HoneyDrunk-runtime; Kernel.Abstractions is permitted because it is itself an Abstractions package.
- **`HoneyDrunk.Auth`**, **`HoneyDrunk.Auth.AspNetCore`**, **`HoneyDrunk.Auth.Canary`** — pick up `HoneyDrunk.Kernel.Abstractions` `0.8.0` transitively through `HoneyDrunk.Auth.Abstractions`; if any of them references `HoneyDrunk.Kernel.Abstractions` directly, update that reference too.
- The unit-test project follows the repo's existing test stack; no new packages introduced beyond what is already referenced.

## Boundary Check
- [x] `AuthorizationDeniedException` is the typed exception ADR-0051 D11 commits — it lives where `IAuthorizationPolicy` and related types live, which is `HoneyDrunk.Auth.Abstractions`.
- [x] `AuthorizationDenyCode` is an existing Auth-Abstractions enum; extending it is the additive correct path, not introducing a parallel `DenyReason` enum elsewhere.
- [x] No dependency on the Capabilities Node or any unreleased package — the exception carries an `AgentId` (Kernel.Abstractions, shipped by packet 03) but does NOT reference `CapabilityBundleRef`, `CapabilityRequirement`, or `IToolInvoker` (those types live in `HoneyDrunk.Capabilities.Abstractions`, shipped via the Capabilities standup, and are properly the responsibility of code that catches/handles `AuthorizationDeniedException` — Agents and Capabilities — not Auth itself).
- [x] No invariant 10 breach. Auth still validates, does not issue. This packet adds an exception type and enum values; the exception is thrown by `IToolInvoker` in Capabilities, not by anything in Auth.

## Acceptance Criteria
- [ ] `AuthorizationDenyCode` enum has four new members: `CapabilityMissing`, `ScopeMismatch`, `GrantExpired`, `PrincipalTypeMismatch`, each with XML doc matching the existing style and explicit numeric values that do not collide with the existing 0..8 or 99
- [ ] `AuthorizationDeniedException.cs` exists in `HoneyDrunk.Auth.Abstractions` as a `sealed class` deriving from `Exception`, carrying `DenyReason Reason`, `string ToolName`, `AgentId AgentId`, `string? MissingCapability`
- [ ] The exception's constructor takes `(DenyReason, string toolName, AgentId, string? missingCapability = null, Exception? inner = null)` and composes a human-readable `Message` from the components
- [ ] No parallel `DenyReason` enum is introduced — the existing `DenyReason` `readonly record struct` is reused; the new enum members are additive on `AuthorizationDenyCode`
- [ ] `HoneyDrunk.Auth.Abstractions.csproj` references `HoneyDrunk.Kernel.Abstractions` at version `0.8.0` (the version this initiative's packet 03 ships)
- [ ] All public types have XML documentation (invariant 13)
- [ ] Records drop the `I`; interfaces keep it. `AuthorizationDeniedException` is a class with no `I` prefix; the existing `IAuthenticationProvider`, `IAuthorizationPolicy` keep their `I`s
- [ ] Unit tests cover construction, message composition, property round-trip; the new enum members compile and bind to `DenyReason`
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new version entry describing the additive changes
- [ ] `HoneyDrunk.Auth.Abstractions/CHANGELOG.md` has a corresponding per-package entry; other packages get NO per-package entry (alignment bumps only, per invariant 12/27)
- [ ] `HoneyDrunk.Auth.Abstractions/README.md` documents the new exception type and the four new enum members
- [ ] The `pr-core.yml` tier-1 gate and the Auth contract-shape canary pass — the new members are additive paired with the version bump

## Human Prerequisites
- [ ] **`HoneyDrunk.Kernel.Abstractions` `0.8.0` must be published before this packet's PR can compile.** The exception's `AgentId` slot references `HoneyDrunk.Kernel.Abstractions.Agents.AgentId`, shipped by this initiative's packet 03. Agents never tag or publish — a human pushes the Kernel `0.8.0` git release tag after packet 03 merges (and after any concurrent ADR-0042 Kernel changes in `0.8.0` also merge, per the ADR-0042 dispatch plan's Wave 2→3 human-release boundary). This packet's CI build will fail if the Kernel `0.8.0` artifact is not on the package feed.
- [ ] **Tag/release `HoneyDrunk.Auth` after this packet merges so downstream consumers can compile against the new version.** The Capabilities standup track's `IToolInvoker` authz check (Phase 2 follow-up, not in this initiative) and the Agents standup track's execution loop (Phase 4 follow-up) both compile against `AuthorizationDeniedException` from the new Auth version. The Audit packet 05 in this initiative does NOT depend on the published Auth version (it consumes only the new `AuthorizationDenyCode` enum values for its event-shape registration, not the exception type at runtime); packet 05 can build against the in-repo source. But for the Capabilities/Operator/Agents downstream work, the Auth release is a hard prerequisite. Agents do not tag.

## Referenced ADR Decisions

**ADR-0051 D11 — Deny by default; typed exceptions.** `AuthorizationDeniedException` is the single exception type, with structured detail (`Reason`, `MissingCapability`, `ToolName`, `AgentId`). The Agents Node's execution loop catches it and surfaces to the LLM as a structured tool-result error (`{"error": "authorization_denied", "missing": "<capability>"}`).

**ADR-0051 D10 — Audit `deny.reason` field.** The audit record's `deny.reason` field takes one of `"capability_missing"` / `"scope_mismatch"` / `"grant_expired"` / `"principal_type_mismatch"`. These four named reasons are exactly the four new `AuthorizationDenyCode` enum members this packet adds — the enum is the in-process source of truth, and the audit string form is derived from the enum's name (lowercase + snake_case).

**ADR-0051 D3 — `IToolInvoker` six-step check.** The ordered failure modes:
1. Unknown tool → `ToolNotFoundException` (not an authz failure; surfaces distinctly).
2. Missing or non-agent principal → `AuthorizationDeniedException` with `Reason.Code = PrincipalTypeMismatch`.
3. `DateTimeOffset.UtcNow > AgentPrincipal.NotAfter` → `AuthorizationDeniedException` with `Reason.Code = GrantExpired`.
4. Effective set lacks the required capability → `AuthorizationDeniedException` with `Reason.Code = CapabilityMissing` (and the missing capability in `MissingCapability`).
5. Scope binding failed (tenant or OnBehalfOf scope didn't match) → `AuthorizationDeniedException` with `Reason.Code = ScopeMismatch`.
6. All requirements pass → dispatch and emit `tool.invoke.granted`.

The exception type and the four enum values fully cover the D3 failure surface.

**ADR-0051 D14 Phase 1 — `AuthorizationDeniedException` in `HoneyDrunk.Auth.Abstractions`.** "Add `AuthorizationDeniedException` to `HoneyDrunk.Auth.Abstractions`."

**ADR-0006 Invariant 10 — Auth validates, never issues.** This packet does NOT introduce token-issuance or principal-minting code in Auth. The exception type and the enum members are pure validation/decision surface — they describe outcomes, not credentials.

## Constraints

- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages, except other Abstractions.** `HoneyDrunk.Auth.Abstractions` may reference `HoneyDrunk.Kernel.Abstractions` (it already does, for context-type integration); this packet bumps that reference to `0.8.0`. No new non-Abstractions dependency.
- **Invariant 10 — Auth validates, never issues.** This packet adds outcome-describing types (an exception + four enum values). It does NOT introduce token issuance or principal minting; Operator owns that surface (ADR-0051 D8).
- **Invariant 13 — all public APIs have XML documentation.**
- **Invariant 27 — all projects in a solution share one version and move together.** Every non-test `.csproj` in the Auth solution bumps to the same new minor version in one commit. Partial bumps forbidden.
- **Invariant 12 — per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Auth.Abstractions` gets an entry; runtime / AspNetCore / Canary are alignment bumps with NO per-package CHANGELOG entry.
- **Records drop the `I`; interfaces keep it.** `AuthorizationDeniedException` is a class — no `I`. Existing `I`-prefixed interfaces (`IAuthenticationProvider`, `IAuthorizationPolicy`) keep their prefix.
- **No parallel `DenyReason` enum.** The existing `DenyReason` `readonly record struct` is the carrier; the four new reasons extend `AuthorizationDenyCode`. Introducing a parallel enum would fragment the deny surface and confuse consumers reading audit records.
- **Pick numeric enum values that do not collide with the existing 0..8 + 99.** Start the agent-authz reasons at 10 so they group visually and leave room. Verify the current enum at execution time.

## Labels
`feature`, `tier-2`, `ai`, `adr-0051`, `wave-2`

## Agent Handoff

**Objective:** Add `AuthorizationDeniedException` to `HoneyDrunk.Auth.Abstractions` and extend `AuthorizationDenyCode` with four new members covering ADR-0051's deny surface.

**Target:** `HoneyDrunk.Auth`, branch from `main`.

**Context:**
- Goal: Ship the typed exception and deny-code values every ADR-0051 consumer (Capabilities `IToolInvoker`, Agents execution loop, Audit event registry) compiles against.
- Feature: ADR-0051 AI Agent Authorization rollout, Wave 2 (abstractions in live Nodes).
- ADRs: ADR-0051 D3/D10/D11/D14 (primary), ADR-0006 (Auth contract surface this composes with), invariant 10 (Auth validates, never issues — preserved).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0051 Accepted before its decisions are built into the Auth surface.
- (Build-time, not a packet dependency) `HoneyDrunk.Kernel.Abstractions` `0.8.0` must be published before CI can compile this packet — surfaced in Human Prerequisites.

**Constraints:**
- Reuse the existing `DenyReason` `readonly record struct` and existing `AuthorizationDenyCode` enum; do not introduce a parallel enum.
- Pick numeric enum values that do not collide with the existing 0..8 + 99 (start at 10).
- The exception's `AgentId` slot references the Kernel-Abstractions type from this initiative's packet 03.
- All non-test `.csproj` files bump to the same new minor version in one commit (invariant 27).
- Only `HoneyDrunk.Auth.Abstractions` gets a per-package CHANGELOG entry; the others are alignment bumps with no entry (invariant 12).
- Auth does not issue agent identity (invariant 10); this packet adds outcome-describing types only.

**Key Files:**
- `HoneyDrunk.Auth.Abstractions/AuthorizationDenyCode.cs` — extend enum
- `HoneyDrunk.Auth.Abstractions/AuthorizationDeniedException.cs` — new file
- `HoneyDrunk.Auth.Abstractions/HoneyDrunk.Auth.Abstractions.csproj` — Kernel.Abstractions bump + solution version
- All other Auth `.csproj` files for version alignment
- `HoneyDrunk.Auth.Abstractions/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`

**Contracts:**
- `AuthorizationDeniedException` (new class) — the single typed authz-failure exception for the agent surface.
- `AuthorizationDenyCode` (existing enum, extended) — four new members: `CapabilityMissing`, `ScopeMismatch`, `GrantExpired`, `PrincipalTypeMismatch`.
