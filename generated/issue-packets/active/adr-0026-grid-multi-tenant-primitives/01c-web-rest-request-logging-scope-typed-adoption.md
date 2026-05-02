---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.Rest
labels: ["chore", "tier-2", "core", "adr-0026", "wave-1"]
dependencies: ["Kernel#NN — Grid multi-tenant primitives (packet 01)"]
adrs: ["ADR-0026"]
wave: 1
initiative: adr-0026-grid-multi-tenant-primitives
node: honeydrunk-web-rest
coordinated_with: ["HoneyDrunk.Kernel", "HoneyDrunk.Data", "HoneyDrunk.Transport", "HoneyDrunk.Pulse"]
---

# Chore: Adapt Web.Rest RequestLoggingScopeMiddleware to Kernel 0.5.0 typed IOperationContext.TenantId

## Summary
After the lead Kernel packet (#01) promotes `IOperationContext.TenantId` from `string?` to non-nullable typed `TenantId`, `HoneyDrunk.Web.Rest.AspNetCore/Middleware/RequestLoggingScopeMiddleware.cs` no longer compiles against published Kernel 0.5.0 (lines 97-99 use `string.IsNullOrWhiteSpace(operationContext.TenantId)`). This packet adapts the log-scope predicate to use the typed value and the `IsInternal` predicate. **Design decision surfaced for PR review:** internal-tenant requests still get a `tenant_id` log-scope entry (carrying the Internal sentinel ULID `00000000000000000000000000`) by default, OR the scope entry is omitted for internal requests via an `IsInternal` short-circuit. **This packet defaults to omit-when-Internal** — log-scope cardinality discipline is symmetric with Pulse's telemetry discipline (packet 03); flag for confirmation at PR review. Coordinated solution-wide minor bump on `HoneyDrunk.Web.Rest` (`0.3.0 → 0.4.0`).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Web.Rest`

## Motivation
ADR-0026 D2 promotes `IOperationContext.TenantId` from `string?` to non-nullable typed `TenantId`. The lead Kernel packet (#01) ships that promotion as part of Kernel 0.5.0. Web.Rest reads `IOperationContext.TenantId` in exactly one place — `RequestLoggingScopeMiddleware.EnrichWithKernelContext` (file `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/Middleware/RequestLoggingScopeMiddleware.cs`, lines 97-99) — to add a `TenantId` entry to the request's log scope.

Today's code:
```csharp
// Add tenant/project context
if (!string.IsNullOrWhiteSpace(operationContext.TenantId))
{
    scopeState[RestTelemetryTags.TenantId] = LogValueSanitizer.Sanitize(operationContext.TenantId);
}

if (!string.IsNullOrWhiteSpace(operationContext.ProjectId))
{
    scopeState["ProjectId"] = LogValueSanitizer.Sanitize(operationContext.ProjectId);
}
```

After Kernel 0.5.0:
- `operationContext.TenantId` is typed `TenantId` (non-nullable). The `string.IsNullOrWhiteSpace` check no longer compiles.
- `operationContext.ProjectId` stays `string?` per ADR-0026 Open Questions §1 (`ProjectId` promotion is a future ADR — out of scope here). The ProjectId block is unchanged.

**Design decision surfaced for human PR review** (the user requested this be explicit):

The post-promotion value is always present. Two design choices for the predicate:

1. **Always emit the scope entry** (no `IsInternal` short-circuit). Pros: a single uniform shape across log scopes — every request has a `TenantId` in its log context, including the Internal sentinel for Grid-internal traffic. Cons: every internal-traffic log line carries the Internal ULID literal as a property, which is noise in log search. The "is this an internal call?" question is answerable but with extra filter work.

2. **Omit-when-Internal short-circuit** (`if (!operationContext.TenantId.IsInternal)`). Pros: log scopes carry `TenantId` only for paying-customer / non-internal requests, symmetric with Pulse's telemetry discipline (packet 03's `ActivityEnricher` uses the same `IsInternal` short-circuit). The "is this an internal call?" question is answerable by the *absence* of the property, which matches the existing log-search convention "tenanted requests have a TenantId; internal requests don't." Cons: log search filters that previously checked `string.IsNullOrWhiteSpace` need to be inverted (now `is null` means internal, was null/empty means same).

**Packet recommendation: choice 2 (omit-when-Internal).** Reasons:
- Symmetric with Pulse's `IsInternal` short-circuit (packet 03) — the Grid speaks the same telemetry language across log scopes and trace tags.
- ADR-0026 D7's boundary invariant says core dispatch receives requests with tenancy already resolved or `Internal` defaulted — the log scope is at gateway-layer middleware (Web.Rest sits at the HTTP edge), where the IsInternal short-circuit is the canonical pattern.
- Existing log-search filters are minimal (it's a dev-time / ops aid, not a billed-on-cardinality concern); the migration cost is small.

The packet ships choice 2 by default. **The human (oleg@honeydrunkstudios.com) confirms or flips at PR review.** If choice 1 is preferred, the change is one line (`if (!operationContext.TenantId.IsInternal)` → unconditional emit of `LogValueSanitizer.Sanitize(operationContext.TenantId.ToString())`).

This packet ships the Web.Rest half of the coordinated Wave 1.

## Proposed Implementation

### A. Adapt `RequestLoggingScopeMiddleware.EnrichWithKernelContext`

`HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/Middleware/RequestLoggingScopeMiddleware.cs`:

The current code (lines 96-100):
```csharp
// Add tenant/project context
if (!string.IsNullOrWhiteSpace(operationContext.TenantId))
{
    scopeState[RestTelemetryTags.TenantId] = LogValueSanitizer.Sanitize(operationContext.TenantId);
}
```

The new code (default — omit-when-Internal):
```csharp
// Add tenant context for non-internal traffic (Internal-tenant requests
// omit the scope entry — symmetric with Pulse's IsInternal telemetry
// short-circuit and with ADR-0026 D7's gateway-layer cardinality discipline).
if (!operationContext.TenantId.IsInternal)
{
    scopeState[RestTelemetryTags.TenantId] = LogValueSanitizer.Sanitize(
        operationContext.TenantId.ToString());
}
```

The ProjectId block (lines 102-105) is **unchanged** — `IOperationContext.ProjectId` stays `string?` per ADR-0026 Open Questions §1.

Add `using HoneyDrunk.Kernel.Abstractions.Identity;` to the file's using block so `TenantId.IsInternal` resolves (the `IOperationContext.TenantId` property already returns the typed value after Kernel 0.5.0; the import gives the file access to the `TenantId` type's static and instance members).

**`LogValueSanitizer.Sanitize` is preserved** — even though ULIDs cannot contain control chars or formatting nasties, the sanitizer is the existing defense-in-depth wrapper for log-scope values; passing the typed value through `.ToString()` and then through `Sanitize` keeps the call shape identical to neighboring properties (CorrelationId, OperationId, etc.).

### B. Verify no other Kernel-context callsites in Web.Rest need adaptation

Run at execution: `rg "operationContext\.TenantId|gridContext\.TenantId|context\.TenantId" --type cs` across `HoneyDrunk.Web.Rest`. The packet authoring grep shows `RequestLoggingScopeMiddleware.cs` lines 97-99 as the only string-typed callsite. If new callsites have appeared since packet authoring, apply the same `IsInternal` short-circuit pattern (or escalate to PR review if a different policy is needed at that callsite).

### C. Coordinated version bump

Per Invariant 27, every project in the `HoneyDrunk.Web.Rest` solution moves to `0.4.0`:
- `HoneyDrunk.Web.Rest.AspNetCore` — actual change (this packet's adapter)
- `HoneyDrunk.Web.Rest.Abstractions` — alignment-only
- `HoneyDrunk.Web.Rest.Canary` — alignment-only / canary
- `HoneyDrunk.Web.Rest.Tests` — test project

Bump the `<Version>` in each `.csproj` from `0.3.0` to `0.4.0`. The current `HoneyDrunk.Web.Rest.AspNetCore.csproj` references:
- `HoneyDrunk.Kernel.Abstractions` Version `0.4.0` — bump to `0.5.0`
- `HoneyDrunk.Transport` Version `0.4.0` — bump to `0.5.0` (Wave 1 sister packet 01b ships Transport 0.5.0)
- `HoneyDrunk.Auth.AspNetCore` Version `0.3.0` — leave (Auth is not in this Wave)
- `HoneyDrunk.Vault.EventGrid` `0.3.0`, `HoneyDrunk.Vault.Providers.AppConfiguration` `0.3.0`, `HoneyDrunk.Vault.Providers.AzureKeyVault` `0.3.0` — leave at `0.3.0` (Vault is Wave 2; this packet doesn't move Vault references)

Per Invariant 12 — repo-level `CHANGELOG.md` gets a new `0.4.0` entry covering the typed-`TenantId` adoption + the omit-when-Internal log-scope policy. Per-package `CHANGELOG.md` updates ONLY for `HoneyDrunk.Web.Rest.AspNetCore/` (the package with actual change). `Abstractions`, `Canary`, `Tests` get NO per-package CHANGELOG entries (alignment-only — Invariant 12 prohibits noise entries).

### D. Tests

Update or add tests in `HoneyDrunk.Web.Rest.Tests/Middleware/RequestLoggingScopeMiddlewareTests.cs` (or wherever the existing middleware tests live — verify at execution; create the test file if it doesn't exist):

1. **Internal-tenant request omits the `TenantId` scope entry.** Construct an `IOperationContext` with `TenantId = TenantId.Internal`. Run the middleware. Assert the captured log scope state does NOT contain a `TenantId` key (`scopeState.ContainsKey(RestTelemetryTags.TenantId)` is false).

2. **Non-internal-tenant request includes the `TenantId` scope entry as the ULID string.** Construct an `IOperationContext` with `TenantId = TenantId.NewId()`. Run the middleware. Assert the captured log scope state contains a `TenantId` key whose value (after sanitizer round-trip) equals the ULID string form.

3. **ProjectId behavior unchanged (regression).** Set `ProjectId = "some-project"` on the operation context; assert it appears in the scope state. Set `ProjectId = null`; assert it doesn't. (Pin existing behavior so the parallel-typing decision on `ProjectId` doesn't accidentally drift.)

4. **Other scope properties unchanged (regression).** CorrelationId, OperationId, OperationName, CausationId, NodeId, StudioId, Environment all still emit per existing rules.

Existing tests that constructed contexts with `string?` TenantId need updating to construct with typed `Kernel.TenantId`.

### E. README touch-up

If `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/README.md` documents the request log scope, add a one-line note that the `TenantId` scope entry is emitted only for non-Internal requests (Internal-tenant requests rely on the absence of the property as the "is this internal traffic?" signal). Do NOT include the ADR ID.

## Affected Files

- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/Middleware/RequestLoggingScopeMiddleware.cs` (edit — lines 96-100; add `using HoneyDrunk.Kernel.Abstractions.Identity;`)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Tests/Middleware/RequestLoggingScopeMiddlewareTests.cs` (new or edit — four tests per section D)
- All `.csproj` files in the Web.Rest solution (version bump `0.3.0 → 0.4.0`)
- `HoneyDrunk.Kernel.Abstractions` PackageReference in `HoneyDrunk.Web.Rest.AspNetCore.csproj` — bump to `0.5.0`
- `HoneyDrunk.Transport` PackageReference in `HoneyDrunk.Web.Rest.AspNetCore.csproj` — bump to `0.5.0` (sister Wave 1 packet 01b ships Transport 0.5.0)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` (per-package — actual change)
- Repo-root `CHANGELOG.md` — new `0.4.0` entry
- Per-package `CHANGELOG.md` for `Abstractions`, `Canary`, `Tests` — NO entries (Invariant 12)
- Per-package `README.md` for `HoneyDrunk.Web.Rest.AspNetCore/` — one-line note about the omit-when-Internal log-scope behavior (only if README documents the request log scope)

## NuGet Dependencies

- `HoneyDrunk.Kernel.Abstractions` PackageReference: bump from `0.4.0` to `0.5.0` (Wave 1 packet 01).
- `HoneyDrunk.Transport` PackageReference: bump from `0.4.0` to `0.5.0` (Wave 1 packet 01b).

No new package additions. `HoneyDrunk.Auth.AspNetCore`, `HoneyDrunk.Vault.*`, and `HoneyDrunk.Standards` references are NOT moved by this packet (those packages are not in Wave 1).

## Boundary Check
- [x] All edits in `HoneyDrunk.Web.Rest`. Routing rule "REST, ASP.NET Core, middleware, exception mapping, response envelope, correlation" → `HoneyDrunk.Web.Rest` matches.
- [x] No change to `HoneyDrunk.Web.Rest.Abstractions` contract surface. `RestTelemetryTags`, `ICorrelationIdAccessor`, `IRestResponseFactory` etc. unchanged.
- [x] No change to `RestOptions` shape — `EnableRequestLoggingScope` predicate stays.
- [x] Honors Invariant 5 — middleware reads `IOperationContextAccessor` from request services as today.
- [x] No new transitive runtime dependencies (Invariant 2). Already depends on `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Transport`.

## Acceptance Criteria

- [ ] `RequestLoggingScopeMiddleware.EnrichWithKernelContext` compiles against published `HoneyDrunk.Kernel.Abstractions` 0.5.0.
- [ ] The `TenantId` scope-state addition uses `if (!operationContext.TenantId.IsInternal)` — Internal-tenant requests omit the scope entry.
- [ ] The `TenantId` scope value is set via `LogValueSanitizer.Sanitize(operationContext.TenantId.ToString())`.
- [ ] The `ProjectId` block (lines 102-105 area) is **unchanged** — `IOperationContext.ProjectId` stays `string?` per ADR-0026 Open Questions §1.
- [ ] Other scope properties (CorrelationId, OperationId, OperationName, CausationId, NodeId, StudioId, Environment) unchanged.
- [ ] Four new / updated tests pass: Internal omits TenantId; non-Internal emits ULID string; ProjectId regression; other scope properties regression.
- [ ] Existing tests that constructed contexts with `string?` TenantId are updated to construct with typed `Kernel.TenantId`.
- [ ] Every `.csproj` in the Web.Rest solution moves from `0.3.0` to `0.4.0` in a single commit (Invariant 27).
- [ ] `HoneyDrunk.Kernel.Abstractions` PackageReference bumped to `0.5.0` in every Web.Rest `.csproj` that references it.
- [ ] `HoneyDrunk.Transport` PackageReference bumped to `0.5.0` in every Web.Rest `.csproj` that references it.
- [ ] `HoneyDrunk.Auth.AspNetCore`, `HoneyDrunk.Vault.*`, `HoneyDrunk.Standards` references are NOT moved by this packet.
- [ ] Repo-level `CHANGELOG.md` has a new `0.4.0` entry covering Kernel 0.5.0 + Transport 0.5.0 adoption + the omit-when-Internal log-scope policy.
- [ ] Per-package `CHANGELOG.md` for `HoneyDrunk.Web.Rest.AspNetCore/` updated. No entries for `Abstractions`, `Canary`, `Tests` (alignment-only — Invariant 12).
- [ ] All canary tests green; full unit-test suite green.
- [ ] No public-API surface change to `HoneyDrunk.Web.Rest.Abstractions`. Verify with `git diff HoneyDrunk.Web.Rest.Abstractions/`.

## Human Prerequisites
- [ ] **Confirm the omit-when-Internal log-scope design at PR review.** This packet defaults to omitting the `TenantId` scope entry for Internal-tenant requests (symmetric with Pulse's telemetry discipline). The alternative — always emit the entry, including the Internal sentinel for Grid-internal traffic — is documented in the Motivation section. If you prefer that, the change is one line (remove the `IsInternal` short-circuit; emit unconditionally with `operationContext.TenantId.ToString()`). Acceptance Criteria flip the assertion in test #1 if you change the design.
- [ ] **Confirm packet 01 (Kernel) merged AND `HoneyDrunk.Kernel.Abstractions` 0.5.0 published.** Hard gate.
- [ ] **Confirm packet 01b (Transport) merged AND `HoneyDrunk.Transport` 0.5.0 published.** Hard gate — the `HoneyDrunk.Web.Rest.AspNetCore.csproj` references Transport, and the Transport reference must move at the same wave for the build to resolve coherent versions.
- [ ] **Coordinated merge in Wave 1.** This packet's PR merges within the same wave as Kernel 0.5.0 and Transport 0.5.0. Dispatch operator coordinates merge order: Kernel first, then Transport, then this packet (alongside Data and Pulse).
- [ ] No portal / Azure work. NuGet-only library packet.

## Dependencies
- **Kernel#NN — Grid multi-tenant primitives (packet 01).** Hard. Kernel 0.5.0 + Kernel.Abstractions 0.5.0 published before this PR builds green.
- **Transport#NN — GridContextFactory typed adoption (packet 01b).** Hard. Transport 0.5.0 published before this PR builds green (Web.Rest.AspNetCore PackageReferences Transport).

## Downstream Unblocks
- Wave 1 closure — once this packet merges (alongside the other Wave 1 sister packets), Kernel 0.5.0 has working consumers and Wave 2 (Vault) can begin.
- Notify Cloud and any future commercial Node hosting an HTTP edge inherit the omit-when-Internal log-scope discipline automatically.

## Referenced Invariants

> **Invariant 2 (Dependency):** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. **Why it matters here:** Only the existing Kernel.Abstractions and Transport reference versions move; no new package edges introduced.

> **Invariant 5 (Context):** GridContext must be present in every scoped operation. **Why it matters here:** Middleware reads `IOperationContextAccessor`; the typed `TenantId` is part of that contract, populated by Kernel's `GridContextMiddleware` upstream.

> **Invariant 8 (Secrets & Trust):** Secret values never appear in logs, traces, exceptions, or telemetry. **Why it matters here:** TenantIDs are not secret values, but the existing `LogValueSanitizer.Sanitize` wrapper is preserved as defense-in-depth.

> **Invariant 12 (Packaging):** Semantic versioning with CHANGELOG and README. Repo-level mandatory; per-package only when the package has functional changes. **Why it matters here:** Repo-level `CHANGELOG.md` gets a `0.4.0` entry; only `HoneyDrunk.Web.Rest.AspNetCore/` gets a per-package entry.

> **Invariant 13 (Packaging):** All public APIs have XML documentation. **Why it matters here:** No public API surface change; existing XML docs stand.

> **Invariant 26 (Work Tracking):** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section.

> **Invariant 27 (Versioning):** All projects in a solution share one version and move together.

> **Invariant 31 (Code Review):** Every PR traverses the tier-1 gate before merge.

> **Invariant 32 (Code Review):** Agent-authored PRs must link to their packet in the PR body.

## Referenced ADR Decisions

**ADR-0026 (Grid Multi-Tenant Primitives):**
- **D2 — `IGridContext.TenantId` is promoted from `string?` to `TenantId` (non-nullable).** This packet adapts Web.Rest's only consumer of the property (`RequestLoggingScopeMiddleware`).
- **D7 — Multi-tenant boundary invariant — gateway-layer middleware vs. core dispatch.** Web.Rest sits at the HTTP gateway layer; the omit-when-Internal log-scope short-circuit is the canonical gateway-layer cardinality discipline.
- **D9 — Coordinated Wave 1.** This packet is one of four downstream sister packets in Wave 1 (Data, Transport, Web.Rest, Pulse).
- **Negative consequences — blast radius inventory.** ADR-0026 names `Web.Rest.AspNetCore/Middleware/RequestLoggingScopeMiddleware.cs` lines 97-99 as one of the four file-level callsites that need adaptation.

**ADR-0026 Open Questions §1 — `ProjectId` promotion deferred.** This packet leaves the ProjectId block unchanged; `IOperationContext.ProjectId` stays `string?`.

## Constraints

- **Default to omit-when-Internal for the log-scope `TenantId` entry.** Symmetric with Pulse's telemetry discipline (packet 03). Confirm or flip at PR review.
- **Do NOT modify the ProjectId block.** ADR-0026 Open Questions §1 — `ProjectId` promotion is a future ADR. The block stays exactly as-is.
- **Preserve `LogValueSanitizer.Sanitize` wrapping.** Defense-in-depth wrapper — pass `operationContext.TenantId.ToString()` through it, same shape as neighboring properties.
- **Do NOT bump `HoneyDrunk.Auth.AspNetCore` or `HoneyDrunk.Vault.*` references.** Auth and Vault are not in Wave 1; their references stay at current versions.
- **No change to `HoneyDrunk.Web.Rest.Abstractions`.** Verify with `git diff HoneyDrunk.Web.Rest.Abstractions/`.
- **No new NuGet dependencies.** Only the existing Kernel.Abstractions and Transport reference versions move.
- **No ADR ID in code comments / README.**
- **Coordinated bump on every `.csproj`.** Per-package CHANGELOG only for `HoneyDrunk.Web.Rest.AspNetCore/`.

## Labels
`chore`, `tier-2`, `core`, `adr-0026`, `wave-1`

## Agent Handoff

**Objective:** Adapt `HoneyDrunk.Web.Rest.AspNetCore`'s single Kernel-tenant consumer (`RequestLoggingScopeMiddleware`) to Kernel 0.5.0's typed `IOperationContext.TenantId` with omit-when-Internal log-scope discipline. Coordinated solution-wide bump to `0.4.0`. Sister packet to lead Kernel packet (#01) in Wave 1.

**Target:** `HoneyDrunk.Web.Rest`, branch from `main`.

**Context:**
- Goal: Adapt log-scope predicate; align with Pulse's `IsInternal` cardinality discipline; surface design choice for human confirmation.
- Feature: ADR-0026 Grid Multi-Tenant Primitives, Wave 1 (coordinated multi-repo bump).
- ADRs: ADR-0026 (multi-tenant primitives, D2 + D7 + D9 + Negative Consequences blast radius + Open Questions §1).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Kernel#NN — Grid multi-tenant primitives (packet 01). Hard.
- Transport#NN — GridContextFactory typed adoption (packet 01b). Hard.

**Constraints:** Per Constraints section above. Specifically:
- Default omit-when-Internal log-scope discipline; confirm at PR review.
- ProjectId block unchanged.
- Preserve `LogValueSanitizer.Sanitize`.
- Don't bump Auth or Vault references.
- Web.Rest.Abstractions unchanged.
- Coordinated `0.3.0 → 0.4.0` bump on every Web.Rest `.csproj`. Per-package CHANGELOG only for `HoneyDrunk.Web.Rest.AspNetCore/`.
- No ADR ID in code / README.

**Inlined Invariant Text (for review without leaving the target repo):**

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer.

> **Invariant 5:** GridContext must be present in every scoped operation.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level mandatory; per-package only when the package has functional changes.

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section.

> **Invariant 27:** All projects in a solution share one version and move together.

> **Invariant 31:** Every PR traverses the tier-1 gate before merge.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

**Key Files:**
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/Middleware/RequestLoggingScopeMiddleware.cs`
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Tests/Middleware/RequestLoggingScopeMiddlewareTests.cs` (new or edit)
- All `.csproj` files in the Web.Rest solution
- Per-package `CHANGELOG.md` for `HoneyDrunk.Web.Rest.AspNetCore/` only
- Repo-root `CHANGELOG.md`

**Contracts:**
- No change to `HoneyDrunk.Web.Rest.Abstractions` (`RestTelemetryTags`, `ICorrelationIdAccessor`, `IRestResponseFactory`, etc.).
- No change to `RestOptions`.
- Internal: log-scope `TenantId` entry omitted for Internal tenants by default.
