---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "ai", "adr-0051", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0051"]
wave: 2
initiative: adr-0051-agent-authorization
node: honeydrunk-kernel
---

# Add AgentPrincipal + AgentId + AgentRunId to Kernel.Abstractions and extend IOperationContext

## Summary
Add the ADR-0051 agent-principal contract surface to `HoneyDrunk.Kernel.Abstractions`: the `AgentPrincipal` record (Operator-issued, run-bound, optionally delegating), the `AgentId` and `AgentRunId` identity records, and an additive `AgentPrincipal? Agent { get; }` slot on `IOperationContext` so the principal flows through the per-operation context every consumer already plumbs. Pure contracts — zero HoneyDrunk runtime dependencies. This is the version-bumping packet for the `HoneyDrunk.Kernel` solution (unless ADR-0042's packet 02 has already bumped it; see Constraints).

## Context
ADR-0051 D1 commits a third principal type and says it "flows through `RequestContext`." The Grid does not have a type named `RequestContext`; the actual context contracts are `IGridContext` (Grid-level, longer-lived) and `IOperationContext` (per-operation, short-lived) in `HoneyDrunk.Kernel.Abstractions/Context/`. Per the dispatch plan's Cross-Cutting decision, the `AgentPrincipal` slot lives on `IOperationContext` because `AgentRunId` is per-invocation and matches `IOperationContext`'s lifetime — `IGridContext` carries Grid-level identity (Node, Sector, Environment) and is the wrong layer.

The named `UserPrincipal` / `ServicePrincipal` / `Principal` base also do not exist today; the Auth surface uses `AuthenticatedIdentity` and the authorization-request shape. This packet **does not** introduce a `Principal` base class — that rename is a future Auth amendment and is out of scope. `AgentPrincipal` ships as a standalone record. The `OnBehalfOf` slot is typed loosely (an `object?` or a small dedicated `IDelegatedPrincipal` interface or simply `string?` carrying a pseudonymous principal id; see the Proposed Implementation note for the chosen shape).

`HoneyDrunk.Kernel.Abstractions` today contains the subfolders `Configuration/`, `Context/`, `DI/`, `Diagnostics/`, `Errors/`, `Health/`, `Hosting/`, `Identity/`, `Lifecycle/`, `Telemetry/`, `Tenancy/`, `Transport/` — **there is no `Agents/` subfolder**. This packet creates `HoneyDrunk.Kernel.Abstractions/Agents/` and lands the new types there. The `IOperationContext` slot lives in the existing `Context/IOperationContext.cs`.

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (.NET 10.0), two packages: `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel`. Per the dispatch plan, ADR-0042's packet 02 may have already bumped the solution `0.7.0` → `0.8.0`. The executor must check the solution's current version at execution time. If already at `0.8.0`, this packet appends to the in-progress `[0.8.0]` CHANGELOG and does NOT bump. If still at `0.7.0`, this packet is the bumping packet (`0.7.0` → `0.8.0`).

## Scope

- `HoneyDrunk.Kernel.Abstractions/Agents/` — **create this subfolder** (not present today; siblings under `HoneyDrunk.Kernel.Abstractions/` are `Configuration/`, `Context/`, `DI/`, `Diagnostics/`, `Errors/`, `Health/`, `Hosting/`, `Identity/`, `Lifecycle/`, `Telemetry/`, `Tenancy/`, `Transport/`). Add the new contract types:
  - `AgentId` — record wrapping a stable kebab-case agent identifier (e.g., `lately-content-publisher`). Validate non-empty + kebab-case-compatible at construction; align with the existing `KebabCaseIdentity` base used in `Identity/`.
  - `AgentRunId` — record wrapping a `Guid` per invocation. **Deliberate divergence from `Identity/RunId.cs`:** the existing `RunId` is a ULID-backed `readonly record struct` (Crockford-base32, sortable, 128-bit time-prefixed). `AgentRunId` is `Guid`-backed because (a) ADR-0051 D1 explicitly specifies `Guid` for agent invocations, (b) `AgentRunId` is minted by the Operator Node and propagated through the audit shape (ADR-0051 D10's `agent.runId`) where `Guid` is the lingua franca for callers that haven't adopted ULID identity, and (c) the time-sorted property ULID provides is not load-bearing for agent runs — uniqueness is. The two types coexist: `RunId` continues to identify operation runs in the existing carrier; `AgentRunId` rides on `AgentPrincipal` for agent-issued invocations. This packet documents the divergence in the `AgentRunId` XML `<remarks>` block so a future reader doesn't unify them by reflex.
  - `AgentPrincipal` — record carrying `AgentId Id`, `AgentRunId RunId`, an optional `OnBehalfOf` slot (see Proposed Implementation for the chosen shape), a `IReadOnlyList<string> BundleRefs` slot for the granted bundle references (string form `bundle:<name>@v<n>` — the strongly-typed `CapabilityBundleRef` ships in `HoneyDrunk.Capabilities.Abstractions` via the `adr-0017-capabilities-standup` track, not here), and `DateTimeOffset NotAfter`.
- `HoneyDrunk.Kernel.Abstractions/Context/IOperationContext.cs` — additive `AgentPrincipal? Agent { get; }` member. Default implementations on existing snapshot/factory types return `null`.
- Default-implementation updates on the runtime side (e.g., `OperationContext` concrete in `HoneyDrunk.Kernel`) if any concrete type already exists — add the property returning `null` by default and a `with`-style builder/setter consistent with the rest of the context surface.
- Both `.csproj` files in the solution version-aligned (invariant 27). Possibly bump or possibly append to in-progress `0.8.0` per the version-bump note above.
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` and `README.md` updated.
- Repo-level `CHANGELOG.md` entry — new `[0.8.0]` if this is the bumping packet, or appended to existing `[0.8.0]` if not.

## Proposed Implementation

1. **`AgentId`** — `public sealed record AgentId(string Value)`. Validate non-empty and that `Value` matches the kebab-case identifier shape used elsewhere in `Identity/` (`KebabCaseIdentity` pattern). If a base class or factory helper exists in `Identity/`, reuse it; otherwise hand-roll the validation. Provide a `ToString()` returning the value.

2. **`AgentRunId`** — `public sealed record AgentRunId(Guid Value)`. The ADR specifies `Guid` explicitly (D1: "`AgentRunId` is a `Guid` per invocation"); do **not** unify with the existing ULID-backed `RunId` (`HoneyDrunk.Kernel.Abstractions/Identity/RunId.cs`, `readonly record struct RunId` over `Ulid`). Provide a `NewRandom()` factory using `Guid.NewGuid()`. **XML doc requirement:** the type's `<remarks>` block must include a paragraph explaining the deliberate departure from the repo's ULID-typed-id convention (Operator-issued, ADR-0051 D1 contract, audit-shape interop), so a future reader does not collapse the two types by reflex. If a type named `AgentRunId` already exists anywhere in the repo, halt and surface the collision rather than silently reusing it.

3. **`AgentPrincipal`** — `public sealed record AgentPrincipal(AgentId Id, AgentRunId RunId, OnBehalfOfPrincipal? OnBehalfOf, IReadOnlyList<string> BundleRefs, DateTimeOffset NotAfter)`.
   - For the `OnBehalfOf` slot: the ADR names `Principal? OnBehalfOf` and references `UserPrincipal` / `ServicePrincipal` — types that do not exist in `HoneyDrunk.Auth.Abstractions` today. **This packet does not introduce the `Principal` base / `UserPrincipal` / `ServicePrincipal` sibling types** (that work is deferred to a future Auth amendment, not this initiative). To carry the delegation information ADR-0051 D10's audit shape needs without expanding scope, this packet ships a **scoped, time-bound placeholder record**:
     ```
     public sealed record OnBehalfOfPrincipal(
         string Kind,     // "user" or "service" — string-typed because the named Principal base does not exist yet
         string Id,       // pseudonymous principal id per ADR-0045 D7 PII rules
         string? TenantId // optional, when the delegating principal is tenant-scoped
     );
     ```
     **Placeholder discipline:**
     - The type carries **only** the two fields ADR-0051 D10's audit record consumes (`onBehalfOf.type` ← `Kind`; `onBehalfOf.id` ← `Id`), plus `TenantId` for ADR-0026 composition. Do not extend the surface with claims, roles, scopes, or anything else without amending ADR-0051.
     - The XML `<remarks>` block on the type **must** state, verbatim in substance: "Placeholder shape pending the named `Principal` base, `UserPrincipal`, and `ServicePrincipal` types in a future `HoneyDrunk.Auth.Abstractions` amendment. Consumers MUST treat this as opaque, MUST NOT reflect over the type, and MUST be prepared for the slot to be replaced by `Principal? OnBehalfOf` referencing the named siblings without prior deprecation."
     - The placeholder's existence is acknowledged in Packet 00's "Acceptance Notes — Implementation Deviations" — accepting Packet 00 implicitly accepts this scoped deviation.
     - When the named `Principal` base lands, the rename is a separate ADR-amendment + packet pair; that work removes `OnBehalfOfPrincipal` (or repurposes it as a thin shim) and is **out of scope** here.
   - `BundleRefs` is `IReadOnlyList<string>` carrying string references (e.g., `"bundle:lately-content-publisher@v3"`). The strongly-typed `CapabilityBundleRef` lands in `HoneyDrunk.Capabilities.Abstractions` via the Capabilities standup; from Kernel's perspective the references are opaque strings (Kernel.Abstractions has zero HoneyDrunk dependencies — invariant 1).
   - `NotAfter` carries the grant expiry (ADR-0051 D6). The `IToolInvoker` check (Capabilities-side) compares against `DateTimeOffset.UtcNow`.

4. **`IOperationContext.Agent` slot** — add `AgentPrincipal? Agent { get; }` to `IOperationContext`. The property is additive and nullable; existing implementations that do not yet populate it return `null`. Update `GridContextSnapshot.cs` if it carries operation-context fields, or the corresponding operation-context snapshot type — match whatever exists in `Context/`. Update `IOperationContextFactory` if its construction surface needs the slot.

5. **Concrete-implementation audit (mandatory before adding the interface member).** Adding a member to `IOperationContext` is a contract change; every concrete implementation in the solution must be updated in the same commit or the build breaks. Before adding the `Agent` slot, the executor enumerates and updates each of the following (verified to exist in the repo today):
   - `HoneyDrunk.Kernel.Abstractions/Context/IOperationContext.cs` — the interface itself (the additive `AgentPrincipal? Agent { get; }` member).
   - `HoneyDrunk.Kernel.Abstractions/Context/IOperationContextAccessor.cs` — verify the accessor surface does not need a parallel slot; if it surfaces a snapshot type, that type may need the property.
   - `HoneyDrunk.Kernel.Abstractions/Context/IOperationContextFactory.cs` — if the factory's `Create*` signature needs to accept an optional `AgentPrincipal?` to construct contexts with the populated slot, extend the signature additively (overload, or optional parameter at the end — choose to preserve binary compat where possible).
   - `HoneyDrunk.Kernel/Context/OperationContext.cs` — the concrete implementation; add the property (default `null` for non-agent invocations) and the corresponding `with`-style builder/setter if the type exposes one.
   - `HoneyDrunk.Kernel/Context/OperationContextAccessor.cs` — verify no change needed unless it composes the snapshot.
   - `HoneyDrunk.Kernel/Context/OperationContextFactory.cs` — wire the factory to the new optional parameter / overload; default-null populates correctly.
   - `HoneyDrunk.Kernel.Tests/Context/OperationContextTests.cs` — add tests that the default `Agent` slot is `null` and that a populated `AgentPrincipal` round-trips through the concrete type.

   Each file in the list above must either be updated in this packet's commit **or** explicitly recorded (with a one-line reason) as "no change needed" in the PR description, so a reviewer can verify no concrete type was missed and the contract change is complete.

6. **Default implementations XML doc** — the concrete `OperationContext.Agent` property's XML doc states `null` is the default for non-agent invocations and points readers at `AgentPrincipal` for the populated case.

7. **Unit tests** — `AgentId` non-empty validation; `AgentRunId.NewRandom()` returns distinct values; `AgentPrincipal` construction succeeds with `OnBehalfOf=null` (autonomous case) and with `OnBehalfOf` populated; an `IOperationContext` test double exposes `Agent=null` by default and a populated `AgentPrincipal` when set. Place tests in the repo's existing Abstractions unit-test project.

8. **Versioning** — see Context. If the solution is already at `0.8.0` (ADR-0042 packet 02 landed first), append to the in-progress `[0.8.0]` repo CHANGELOG entry and add a `[0.8.0]` per-package entry to `HoneyDrunk.Kernel.Abstractions`. If the solution is still at `0.7.0`, bump every non-test `.csproj` to `0.8.0` in one commit (invariant 27), create the `[0.8.0]` repo CHANGELOG entry, and add the per-package entry. Either way, the `HoneyDrunk.Kernel` runtime package gets no per-package CHANGELOG entry (no functional change here — alignment bump only, per invariant 12/27).

9. Update `HoneyDrunk.Kernel.Abstractions/README.md` — the public API surface gained `AgentPrincipal`, `AgentId`, `AgentRunId`, `OnBehalfOfPrincipal`, and the `IOperationContext.Agent` slot. Document them in the API-surface section.

## Affected Files

**New files (create the `Agents/` subfolder):**
- `HoneyDrunk.Kernel.Abstractions/Agents/AgentId.cs`
- `HoneyDrunk.Kernel.Abstractions/Agents/AgentRunId.cs`
- `HoneyDrunk.Kernel.Abstractions/Agents/AgentPrincipal.cs`
- `HoneyDrunk.Kernel.Abstractions/Agents/OnBehalfOfPrincipal.cs`

**Interface contract changes (Abstractions):**
- `HoneyDrunk.Kernel.Abstractions/Context/IOperationContext.cs` — additive `AgentPrincipal? Agent { get; }` member
- `HoneyDrunk.Kernel.Abstractions/Context/IOperationContextAccessor.cs` — audit: verify if any surface needs a parallel slot; update only if needed
- `HoneyDrunk.Kernel.Abstractions/Context/IOperationContextFactory.cs` — audit: extend `Create*` signature additively (optional `AgentPrincipal?` parameter or overload) if needed
- `HoneyDrunk.Kernel.Abstractions/Context/GridContextSnapshot.cs` — verify whether it carries operation-context fields; update only if needed

**Concrete implementation updates (runtime package):**
- `HoneyDrunk.Kernel/Context/OperationContext.cs` — add the `Agent` property; default `null`
- `HoneyDrunk.Kernel/Context/OperationContextAccessor.cs` — audit: verify no change needed unless the accessor composes a snapshot
- `HoneyDrunk.Kernel/Context/OperationContextFactory.cs` — wire the additive parameter / overload to the concrete constructor

**Versioning and metadata:**
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — version bump if the bumping packet, alignment otherwise
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` — version alignment
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `HoneyDrunk.Kernel.Abstractions/README.md`
- Repo-level `CHANGELOG.md`

**Tests:**
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Abstractions.Tests/` (or the existing Abstractions unit-test project) — new tests for the new types
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.Tests/Context/OperationContextTests.cs` — extend with the `Agent`-slot default-null and populated cases

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Abstractions`** — no new `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` abstractions. `AgentId` validation uses BCL primitives. No package needed. `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`).
- **`HoneyDrunk.Kernel`** — no new `PackageReference` in this packet.
- The unit-test project follows the repo's existing test stack (ADR-0047: xUnit v2 + NSubstitute + AwesomeAssertions + coverlet); no new packages introduced beyond what the test project already references.

## Boundary Check
- [x] `AgentPrincipal` and the `IOperationContext.Agent` slot are Kernel-Abstractions contracts per ADR-0051 D1 and the dispatch plan's Cross-Cutting decision (the per-operation context is the right carrier).
- [x] No dependency on any other HoneyDrunk runtime package (invariant 1). `BundleRefs` is `IReadOnlyList<string>` — the strongly-typed `CapabilityBundleRef` stays in `HoneyDrunk.Capabilities.Abstractions` (shipped by the Capabilities standup track).
- [x] Contracts only; the runtime `IToolInvoker` authz check (Capabilities Node) is a separate initiative.
- [x] Records drop the `I`; interfaces keep it. `AgentPrincipal`, `AgentId`, `AgentRunId`, `OnBehalfOfPrincipal` are records. `IOperationContext` is an existing interface.

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Abstractions/Agents/AgentId.cs` ships a record wrapping a non-empty kebab-case-compatible string
- [ ] `HoneyDrunk.Kernel.Abstractions/Agents/AgentRunId.cs` ships a record wrapping a `Guid`; `NewRandom()` returns a fresh `Guid.NewGuid()`; the XML `<remarks>` block documents the deliberate departure from the repo's ULID-typed-id convention (cross-references `Identity/RunId.cs`, cites ADR-0051 D1, names Operator issuance + audit interop as the rationale)
- [ ] `HoneyDrunk.Kernel.Abstractions/Agents/AgentPrincipal.cs` ships a record carrying `Id`, `RunId`, `OnBehalfOf` (nullable), `BundleRefs`, `NotAfter`
- [ ] `HoneyDrunk.Kernel.Abstractions/Agents/OnBehalfOfPrincipal.cs` ships a small record (`Kind`, `Id`, `TenantId?`) as a **scoped, time-bound placeholder** until the named `Principal` base lands in a future Auth amendment; the XML `<remarks>` block explicitly labels it a placeholder, names the deferred rename, and forbids consumers from reflecting over the type. The deviation is acknowledged in Packet 00's Acceptance Notes.
- [ ] The `Agents/` subfolder is **newly created** under `HoneyDrunk.Kernel.Abstractions/` (it does not exist today; sibling subfolders are `Configuration/`, `Context/`, `DI/`, `Diagnostics/`, `Errors/`, `Health/`, `Hosting/`, `Identity/`, `Lifecycle/`, `Telemetry/`, `Tenancy/`, `Transport/`)
- [ ] Every concrete `IOperationContext` implementation in the solution is updated in the same commit: `HoneyDrunk.Kernel/Context/OperationContext.cs` carries the new property; `HoneyDrunk.Kernel/Context/OperationContextAccessor.cs` and `HoneyDrunk.Kernel/Context/OperationContextFactory.cs` are either updated or explicitly recorded "no change needed" in the PR description; the `IOperationContextAccessor` and `IOperationContextFactory` interface signatures are extended additively if needed (overload, default parameter, or noted as no-change)
- [ ] `HoneyDrunk.Kernel.Tests/Context/OperationContextTests.cs` is extended with default-null and populated `Agent` slot cases on the concrete `OperationContext` type
- [ ] `IOperationContext` exposes an additive `AgentPrincipal? Agent { get; }` member; existing implementations return `null` by default
- [ ] All new public types have XML documentation (invariant 13)
- [ ] `HoneyDrunk.Kernel.Abstractions` has zero runtime `PackageReference` on any HoneyDrunk package (invariant 1)
- [ ] Records drop the `I`; the new types do not carry an `I` prefix; `IOperationContext` keeps its existing `I` (it's an interface)
- [ ] Unit tests cover `AgentId` non-empty validation, `AgentRunId.NewRandom()` distinctness, `AgentPrincipal` autonomous-vs-delegated construction, and `IOperationContext.Agent` default-null + populated cases
- [ ] Both non-test `.csproj` files are at the same version (`0.8.0`) in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a `[0.8.0]` entry covering the new types — either newly created (if this is the bumping packet) or extended (if ADR-0042 packet 02 already bumped)
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` has a `[0.8.0]` entry describing the agent-principal types and the `IOperationContext.Agent` slot
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` gets NO entry (no functional change in this packet — alignment bump only, per invariant 12/27)
- [ ] `HoneyDrunk.Kernel.Abstractions/README.md` documents the new types in the public-API section
- [ ] The `pr-core.yml` tier-1 gate and the Kernel contract-shape canary pass — the new types are additive
- [ ] No `Principal` / `UserPrincipal` / `ServicePrincipal` base or sibling types are introduced in this packet (deferred to a future Auth amendment)

## Human Prerequisites
- [ ] **Tag/release `HoneyDrunk.Kernel` after this packet merges so downstream consumers can compile against `0.8.0`.** Agents never tag or publish. The Capabilities, Operator, Agents, and Audit standup tracks (and Audit packet 05 in this initiative) reference `AgentPrincipal` from `HoneyDrunk.Kernel.Abstractions` `0.8.0`; that artifact reaches the package feed only after a human pushes a git release tag. If ADR-0042's packet 02 also lands in the same `0.8.0` release, coordinate so both sets of changes are in a single tag/release. The code work in this packet does not require the live published package; the downstream dependency does.

## Referenced ADR Decisions

**ADR-0051 D1 — `AgentPrincipal` shape.** `AgentPrincipal(AgentId Id, AgentRunId RunId, Principal? OnBehalfOf, CapabilityBundleRef[] Bundles, DateTimeOffset NotAfter)`. `AgentId` is stable across runs; `AgentRunId` is a `Guid` per invocation; `OnBehalfOf` is null for autonomous agents. Flows through the per-operation context. Orthogonal to but composable with `TenantId` (ADR-0026). **This packet's adaptation:** `Bundles` is `IReadOnlyList<string>` carrying `bundle:<name>@v<n>` references (the strongly-typed form ships in `HoneyDrunk.Capabilities.Abstractions` via the Capabilities standup, not Kernel); `OnBehalfOf` is a small dedicated record because the named `Principal`/`UserPrincipal`/`ServicePrincipal` base does not exist in the Grid today.

**ADR-0051 D6 — `NotAfter`.** Every grant carries an expiry. `IToolInvoker.InvokeAsync`'s first capability check is `DateTimeOffset.UtcNow > AgentPrincipal.NotAfter` — short-circuits to `AuthorizationDeniedException` with reason `grant_expired`.

**ADR-0051 D14 Phase 1 — Abstractions.** "Add `AgentPrincipal`, `AgentId`, `AgentRunId`, `CapabilityBundle`, `Capability`, `CapabilityRequirement`, `ScopeBindingMode`, `AuthorizationDeniedException` to `HoneyDrunk.Auth.Abstractions` and `HoneyDrunk.Capabilities.Abstractions`. Update `RequestContext` to carry `AgentPrincipal`. No behavior changes; abstractions only." **This packet's allocation:** ships the `AgentPrincipal` family in Kernel.Abstractions (because the Grid uses `IOperationContext`, not `RequestContext`, as the per-operation carrier — see dispatch plan). The `CapabilityBundle` / `Capability` / `CapabilityRequirement` / `ScopeBindingMode` types ship in Capabilities.Abstractions via the `adr-0017-capabilities-standup` packet 04 scaffold. `AuthorizationDeniedException` ships in Auth.Abstractions via packet 04 of this initiative.

## Constraints

- **Invariant 1 — Abstractions have zero runtime dependencies on other HoneyDrunk packages.** Only `Microsoft.Extensions.*` abstractions permitted. `BundleRefs` is `IReadOnlyList<string>` for this reason — the strongly-typed `CapabilityBundleRef` would force a `HoneyDrunk.Capabilities.Abstractions` reference, which Kernel.Abstractions cannot take.
- **Invariant 4 — DAG; Kernel is at the root.** Nothing in this packet depends on a downstream HoneyDrunk package.
- **Invariant 13 — all public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards` analyzers.
- **Invariant 27 — all projects in a solution share one version and move together.** Both `.csproj` files end this packet at the same version. If ADR-0042 packet 02 has already bumped to `0.8.0`, this packet does NOT bump again — it appends to the in-progress `[0.8.0]` CHANGELOG. Verify the current solution version before bumping.
- **Invariant 12 — per-package CHANGELOGs are updated only for packages with functional changes.** `HoneyDrunk.Kernel.Abstractions` gets an entry; `HoneyDrunk.Kernel` (alignment bump only) gets none.
- **Records drop the `I`; interfaces keep it.** `AgentId`, `AgentRunId`, `AgentPrincipal`, `OnBehalfOfPrincipal` are records and carry no `I` prefix. `IOperationContext` keeps its prefix.
- **`AgentRunId` is `Guid`-backed, not ULID-backed.** ADR-0051 D1 specifies `Guid`. Do not align with the existing ULID-based `RunId` in `Identity/`; the two types coexist and serve different purposes.
- **No `Principal` base class.** The named base, `UserPrincipal`, and `ServicePrincipal` are deferred. `OnBehalfOf` is a small dedicated record carrying only what the audit shape needs.

## Labels
`feature`, `tier-2`, `ai`, `adr-0051`, `wave-2`

## Agent Handoff

**Objective:** Add `AgentPrincipal`, `AgentId`, `AgentRunId`, and `OnBehalfOfPrincipal` to `HoneyDrunk.Kernel.Abstractions/Agents/`, and extend `IOperationContext` with an additive `AgentPrincipal? Agent { get; }` slot.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the agent-principal carriers every other ADR-0051 consumer (Audit, Capabilities, Operator, Agents) compiles against.
- Feature: ADR-0051 AI Agent Authorization rollout, Wave 2 (abstractions in live Nodes).
- ADRs: ADR-0051 D1/D6/D14 (primary), ADR-0035 (additive minor-bump policy), ADR-0008 (packet conventions). The ADR-0006 Auth principal-typing story stays unchanged at v1; this packet does NOT rename `AuthenticatedIdentity` and does NOT introduce a `Principal` base.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0051 Accepted and its four invariants live before the agent-principal contracts are built against them.

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency (invariant 1). `BundleRefs` is `IReadOnlyList<string>`, not a typed `CapabilityBundleRef` array.
- The slot lives on `IOperationContext` (per-operation), not on `IGridContext` (Grid-level) — `AgentRunId` matches `IOperationContext`'s lifetime.
- `AgentRunId` is `Guid`-backed per ADR-0051 D1. Do not align with the existing ULID-based `RunId`.
- Records drop the `I`; `IOperationContext` keeps its prefix.
- No `Principal` base class in this packet.
- Verify the solution's current version: if ADR-0042's packet 02 has already bumped to `0.8.0`, append to the in-progress `[0.8.0]` CHANGELOG and do NOT bump again (invariant 27). Otherwise, this is the bumping packet (`0.7.0` → `0.8.0`).

**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/Agents/AgentId.cs`, `AgentRunId.cs`, `AgentPrincipal.cs`, `OnBehalfOfPrincipal.cs`
- `HoneyDrunk.Kernel.Abstractions/Context/IOperationContext.cs` — additive member
- Concrete `OperationContext` runtime type — default-implementation update
- Both `.csproj` files for version alignment
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`

**Contracts:**
- `AgentId` (new record) — stable kebab-case agent identifier.
- `AgentRunId` (new record) — `Guid` per invocation.
- `AgentPrincipal` (new record) — Operator-issued, run-bound, optionally delegating.
- `OnBehalfOfPrincipal` (new record) — small placeholder for the delegated principal until the named `Principal` base arrives.
- `IOperationContext.Agent` (additive member) — `AgentPrincipal?` slot.
