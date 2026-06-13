---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0045", "wave-2"]
dependencies: ["work-item:00", "Architecture#ADR0040-PACKET03"]
adrs: ["ADR-0045", "ADR-0040", "ADR-0026"]
accepts: ["ADR-0045"]
wave: 2
initiative: adr-0045-grid-wide-error-tracking
node: honeydrunk-pulse
---

# Add the IErrorReporter facade and its types to HoneyDrunk.Telemetry.Abstractions

## Summary
Add the `IErrorReporter` facade interface and the error-model types (`ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel`) to `HoneyDrunk.Telemetry.Abstractions` per ADR-0045 D3 — the Grid-facing error-reporting facade layered over Pulse's **existing `IErrorSink`**. This is the contract-only packet; no backend code lands here.

## Context
ADR-0045 D3 makes errors flow through `HoneyDrunk.Pulse`, the Grid's telemetry-export Node, via a new `IErrorReporter` **facade**. The facade is the Grid-facing convenience layer: it captures ambient request context, maintains breadcrumb/scope state, builds an `ErrorEvent`, and hands it to `IErrorSink`. The breadcrumb/scope shape is deliberately modeled on Sentry's semantics because those are backend-portable concepts — App Insights expresses them via custom events on the same `operation_id`, and Sentry would consume them natively if D11 ever fires.

**Reconcile with Pulse's existing `IErrorSink` — read first.** `HoneyDrunk.Pulse` (v0.3.0, LIVE) **already ships `IErrorSink`** in `HoneyDrunk.Telemetry.Abstractions` (`HoneyDrunk.Telemetry.Abstractions/Abstractions/IErrorSink.cs`) — a structured error-capture contract: `CaptureAsync(ErrorEvent)`, `CaptureExceptionAsync(Exception, IDictionary<string,string>?)`, `CaptureMessageAsync(string, TelemetryEventSeverity)`, `FlushAsync()`. It is backed by the `ErrorEvent` model (`Models/ErrorEvent.cs`), which carries `Exception`, `Message`, `Severity`, `Timestamp`, `CorrelationId`, `OperationId`, `NodeId`, `UserId`, `Environment`, `Release`, `Tags`, `Extra`.

ADR-0045 D3 names a new `IErrorReporter`. **`IErrorReporter` does not duplicate `IErrorSink`.** The reconciliation, fixed by ADR-0045 D3:
- **`IErrorSink`** (existing, unchanged) — the sink/fan-out contract. Takes a fully-populated `ErrorEvent` and routes it to a backend. No ambient context, no breadcrumb/scope stack.
- **`IErrorReporter`** (new — this packet) — the application-facing **facade**. It captures ambient context (the current `Activity`/`trace_id`, the Grid `TenantId`/`PrincipalId`, the deployable `Release`), maintains the breadcrumb/scope stack, builds an `ErrorEvent`, and routes it to `IErrorSink`. It adds **no new capture mechanism** — only ambient-context capture and breadcrumb/scope ergonomics.

This packet adds the facade interface and its three model types — `ErrorContext`, `Breadcrumb`, `ErrorScope` — plus the `ErrorLevel` enum, alongside the existing `IErrorSink`/`ErrorEvent`. **Do not modify `IErrorSink` or `ErrorEvent`.** `ErrorContext` is the facade's per-call input; the facade implementation (packet 03) maps it onto `ErrorEvent`.

ADR-0045 D3 specifies the `IErrorReporter` shape exactly:

```
ValueTask CaptureException(Exception ex, ErrorContext? context = null);
ValueTask CaptureMessage(string message, ErrorLevel level, ErrorContext? context = null);
IDisposable AddBreadcrumb(Breadcrumb crumb);
IDisposable PushScope(ErrorScope scope);
```

`ErrorContext` carries `trace_id` (links automatically to App Insights traces, maps to `ErrorEvent.OperationId`/`CorrelationId`), `tenant_id` (links to ADR-0026's primitives — the dimension `ErrorEvent` does **not** carry, and the load-bearing reason the facade exists; the facade carries it onto `ErrorEvent.Tags`), `user_id`, `release` (= application version), and an arbitrary tag dictionary. `Breadcrumb` and `ErrorScope` are modeled on Sentry's semantics.

**Cross-initiative dependency — read first.** This packet's `dependencies:` references ADR-0040 packet 03 (`Architecture#<issue-number>` once filed — replace the `Architecture#ADR0040-PACKET03` placeholder before this folder is pushed). ADR-0040's Pulse work touches the `HoneyDrunk.Pulse` solution; ADR-0045's Pulse work is sequenced after it so version-bump ownership is unambiguous. Per invariant 27, check the `HoneyDrunk.Pulse` solution's in-progress version state at edit time:
- If ADR-0040's Pulse packets have all merged and the solution is at a released version, **this packet bumps** (minor — new public types in `HoneyDrunk.Telemetry.Abstractions`).
- If an ADR-0040 Pulse version bump is still in-progress (unreleased), **this packet appends** to that in-progress version entry and does not bump again.
Record which case applied in the PR.

**Repo-state note.** `HoneyDrunk.Pulse` is a LIVE Node (v0.3.0). `HoneyDrunk.Telemetry.Abstractions` already exists and ships `IErrorSink`/`ErrorEvent`. This packet adds new types to an existing package — no scaffolding concern.

This packet adds only public abstraction types. No App Insights SDK, no backend code — that is packet 03.

## Scope
- `HoneyDrunk.Telemetry.Abstractions` — add `IErrorReporter`, `ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel`, alongside the existing `IErrorSink`/`ErrorEvent` (which are not modified).
- The `HoneyDrunk.Telemetry.Abstractions` unit-test project (or the existing Pulse abstractions test project) — record-equality / construction tests for the new model types.

## Proposed Implementation
1. **`ErrorLevel`** — an enum for `CaptureMessage` severity. Model on Sentry's levels: `Debug`, `Info`, `Warning`, `Error`, `Fatal` (or the subset the Grid needs — pick and document). Plain enum, no behavior. If the existing `TelemetryEventSeverity` enum already covers these levels, the facade may reuse it instead — check at edit time and document the choice (do not create a redundant enum if `TelemetryEventSeverity` already serves).
2. **`ErrorContext`** — the per-capture context record. Per the Grid naming rule (records drop the `I` prefix and are records, not interfaces), this is a `record` named `ErrorContext`, not `IErrorContext`. Fields per ADR-0045 D3:
   - `TraceId` — links to the App Insights trace (`operation_id`); the facade maps it onto `ErrorEvent.OperationId`/`CorrelationId`.
   - `TenantId` — the multi-tenant scoping dimension `ErrorEvent` does not carry; ADR-0026's tenant primitive type if one exists, otherwise a string. Reconcile against `HoneyDrunk.Kernel.Abstractions` — if Kernel exposes a `TenantId` type the Grid already uses, use it (invariant 1 allows the Kernel.Abstractions contract reference).
   - `UserId` — the opaque `PrincipalId` per ADR-0026, never an email or external identifier. Use the Kernel/Auth `PrincipalId` type if one exists; otherwise a string with an XML-doc note that it must be the opaque id.
   - `Release` — the application version string (set by the deployable per packet 04).
   - `Tags` — an arbitrary `IReadOnlyDictionary<string, string>`.
   All fields optional/nullable where D3 shows `ErrorContext?` is itself optional.
3. **`Breadcrumb`** — a `record` capturing a navigational/diagnostic crumb (timestamp, category, message, level, optional data dictionary). Modeled on Sentry's breadcrumb; backend-portable.
4. **`ErrorScope`** — a `record` carrying scoped tags/context pushed onto a stack via `PushScope` and popped when the returned `IDisposable` is disposed.
5. **`IErrorReporter`** — the facade interface, exactly the four-member D3 shape. `IErrorReporter` keeps the `I` prefix (it is an interface, per the Grid naming rule). `AddBreadcrumb` and `PushScope` return `IDisposable` (the breadcrumb/scope is active until disposed). The XML docs must state that it is a facade over `IErrorSink` — it builds an `ErrorEvent` from ambient context and routes to the sink; it does not duplicate `IErrorSink`.
6. **Do not modify `IErrorSink` or `ErrorEvent`.** They are existing, LIVE contracts. The facade is purely additive.
7. **XML documentation** on every public member (invariant 13 — enforced by `HoneyDrunk.Standards`). The XML docs must state the backend-portability intent: these types are modeled to survive a backend swap (App Insights → Sentry per D11).
8. **No new dependencies.** Per invariant 1, `HoneyDrunk.Telemetry.Abstractions` takes only `Microsoft.Extensions.*` abstractions plus whatever HoneyDrunk abstraction package it already references. No App Insights SDK, no Sentry SDK, no Azure type in this package.
9. **Version.** See the cross-initiative version-state check in Context. Either this packet bumps the `HoneyDrunk.Pulse` solution (minor — new public types) or appends to an in-progress ADR-0040 version entry. Record which.
10. **CHANGELOG.** Repo-level `CHANGELOG.md` entry (new version entry if bumping, append if not). Per-package `HoneyDrunk.Telemetry.Abstractions/CHANGELOG.md` entry — this package has an actual change. Update `HoneyDrunk.Telemetry.Abstractions/README.md` if it documents the public contract surface.

## Affected Files
- `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Abstractions/Abstractions/IErrorReporter.cs` (new — alongside the existing `IErrorSink.cs`)
- `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Abstractions/Models/ErrorContext.cs` (new)
- `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Abstractions/Models/ErrorScope.cs` (new)
- `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Abstractions/Models/Breadcrumb.cs` (new)
- `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Abstractions/Models/ErrorLevel.cs` (new — only if `TelemetryEventSeverity` is not reused)
- The `HoneyDrunk.Telemetry.Abstractions` unit-test project — model-type tests.
- Repo-level `CHANGELOG.md`; `HoneyDrunk.Telemetry.Abstractions/CHANGELOG.md`; possibly every non-test `.csproj` (if this packet bumps the solution version).

## NuGet Dependencies
`HoneyDrunk.Telemetry.Abstractions` takes **no new `PackageReference`** — invariant 1: Abstractions packages take only `Microsoft.Extensions.*` abstractions plus whatever HoneyDrunk abstraction package it already references. No App Insights SDK, no Sentry SDK, no Azure type in this package.

The `HoneyDrunk.Telemetry.Abstractions` unit-test project (if a new project is needed):
- The Grid's standard test stack — match the other `HoneyDrunk.Pulse` test projects.
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26).
- Project reference to `HoneyDrunk.Telemetry.Abstractions`.

## Boundary Check
- [x] `HoneyDrunk.Pulse` is the correct repo — outbound error telemetry belongs to Pulse per `repos/HoneyDrunk.Observe/boundaries.md` and `repos/HoneyDrunk.Pulse/boundaries.md`; Pulse already owns `IErrorSink`. ADR-0045 (amended 2026-05-22) places `IErrorReporter` in `HoneyDrunk.Telemetry.Abstractions`.
- [x] Abstraction-only — no backend SDK in `Telemetry.Abstractions` (invariant 1). The App Insights implementation is packet 03.
- [x] `IErrorReporter` is a facade over the existing `IErrorSink` — it does not duplicate it; it is purely additive to the package.
- [x] `IErrorReporter` is a published Pulse contract — provider packages and consuming Nodes depend on it, not on internals (invariant 3).

## Acceptance Criteria
- [ ] `IErrorReporter` exists in `HoneyDrunk.Telemetry.Abstractions` with exactly the four-member D3 shape: `CaptureException`, `CaptureMessage`, `AddBreadcrumb`, `PushScope`
- [ ] `IErrorReporter`'s XML docs state it is a facade over the existing `IErrorSink` — it builds an `ErrorEvent` from ambient context and routes to the sink; it does not duplicate `IErrorSink`
- [ ] The existing `IErrorSink` and `ErrorEvent` are **not** modified — the facade is purely additive
- [ ] `ErrorContext`, `ErrorScope`, `Breadcrumb` are records (not interfaces) per the Grid naming rule; `ErrorLevel` is an enum (or the existing `TelemetryEventSeverity` is reused — decision recorded)
- [ ] `ErrorContext` carries `TraceId`, `TenantId`, `UserId` (the opaque `PrincipalId`), `Release`, and a `Tags` dictionary; the Kernel `TenantId`/`PrincipalId` types are reused if they exist
- [ ] `HoneyDrunk.Telemetry.Abstractions` takes no new HoneyDrunk runtime dependency and no Azure/Sentry SDK (invariant 1)
- [ ] Every new public member has XML documentation stating the backend-portability intent (invariant 13)
- [ ] Model-type tests cover record equality and construction; tests use no external services (invariant 15), no `Thread.Sleep` (invariant 51)
- [ ] The version-state check is performed: the `HoneyDrunk.Pulse` solution either bumps or appends to an in-progress ADR-0040 version entry — the decision recorded in the PR (invariant 27)
- [ ] `HoneyDrunk.Telemetry.Abstractions/CHANGELOG.md` has an entry; repo-level `CHANGELOG.md` updated
- [ ] The solution builds; existing unit tests pass

## Human Prerequisites
None. This packet is pure abstraction code — no Azure resource, no portal step.

## Referenced ADR Decisions
**ADR-0045 D3 — Errors flow through Pulse; `IErrorReporter` is a facade over `IErrorSink`.** The facade interface and its types (`ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel`) are added to `HoneyDrunk.Telemetry.Abstractions`, alongside the existing `IErrorSink`/`ErrorEvent`. The four-member shape is fixed. `IErrorReporter` does **not** duplicate `IErrorSink` — it captures ambient context (`trace_id`, `tenant_id`, `release`) and breadcrumb/scope state, builds an `ErrorEvent`, and routes to `IErrorSink`. `ErrorContext` carries `trace_id`, `tenant_id`, `user_id`, `release`, and a tag dictionary. `Breadcrumb`/`ErrorScope` are modeled on Sentry's semantics — backend-portable.

**ADR-0045 — amendment 2026-05-22.** The error path targets `HoneyDrunk.Pulse`, not `HoneyDrunk.Observe`. Observe's `boundaries.md` states outbound telemetry to external sinks belongs to Pulse; Pulse already owns `IErrorSink` and the `HoneyDrunk.Telemetry.Sink.*` provider family.

**ADR-0026 — Tenant/principal primitives.** `tenant_id` links to ADR-0026's tenant primitive; `user_id` is the opaque `PrincipalId`, never an email or external identifier.

**ADR-0040 — Pulse is the telemetry-export boundary.** ADR-0045 D3 is a small carve-out from ADR-0040's OTLP path: errors flow through Pulse but the *backing* uses the App Insights SDK (packet 03), not OTLP. The *abstraction* this packet adds is SDK-free.

## Constraints
> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** `HoneyDrunk.Telemetry.Abstractions` takes only `Microsoft.Extensions.*` abstractions plus whatever HoneyDrunk abstraction package it already references. No App Insights SDK, no Sentry SDK, no Azure type in `IErrorReporter` or its model types.

> **Invariant 3 — Provider packages depend on their parent Node's contracts, not internals.** `IErrorReporter` is a published Pulse contract; the App Insights backing (packet 03) and every consuming Node depend on this abstraction, never on Pulse internals.

> **Invariant 13 — All public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards`.

> **Invariant 15 — Unit tests never depend on external services.** Model-type tests run in-process.

> **Invariant 26 — Work items for .NET code work include a `## NuGet Dependencies` section; `HoneyDrunk.Standards` is on every new .NET project** (analyzers, `PrivateAssets: all`).

> **Invariant 27 — All projects in a solution share one version and move together.** Perform the in-progress version-state check (see Context): either this packet bumps the `HoneyDrunk.Pulse` solution or appends to an unreleased ADR-0040 version entry. Record the decision.

- **Grid naming rule.** `ErrorContext`, `ErrorScope`, `Breadcrumb` are records and drop the `I` prefix. `IErrorReporter` is an interface and keeps it.
- **No invented members.** `IErrorReporter` is the four-member D3 shape — do not add or rename.
- **Facade, not duplicate.** `IErrorReporter` layers over the existing `IErrorSink` — do not modify `IErrorSink` or `ErrorEvent`, and do not create a parallel error model.
- **Abstraction-only.** No App Insights SDK reference in this packet — packet 03 owns the backend code.

## Labels
`feature`, `tier-2`, `ops`, `adr-0045`, `wave-2`

## Agent Handoff

**Objective:** Add the `IErrorReporter` facade and the error-model types (`ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel`) to `HoneyDrunk.Telemetry.Abstractions`, layered over the existing `IErrorSink`.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Establish the Grid-facing error-reporting facade every Node consumes — built over Pulse's existing `IErrorSink` (App Insights now, Sentry under D11, both behind the same sink).
- Feature: ADR-0045 Grid-Wide Error Tracking rollout, Wave 2.
- ADRs: ADR-0045 D3 (primary), ADR-0026 (tenant/principal primitives), ADR-0040 (the OTLP carve-out and the version-bump coordination).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0045 should be Accepted before its contracts land.
- ADR-0040 packet 03 (cross-initiative) — ADR-0045's Pulse work sequences after ADR-0040's Pulse work so version-bump ownership is unambiguous. Express as `Architecture#<issue-number>` once filed.

**Constraints:**
- Abstraction-only — no App Insights/Sentry SDK in `Telemetry.Abstractions` (invariant 1).
- `IErrorReporter` is the fixed four-member D3 shape — no invented members.
- `IErrorReporter` is a facade over the existing `IErrorSink` — do not modify `IErrorSink`/`ErrorEvent`, do not create a parallel error model.
- `ErrorContext`/`ErrorScope`/`Breadcrumb` are records (drop `I`); `IErrorReporter` is an interface (keeps `I`).
- Perform the invariant-27 version-state check on the `HoneyDrunk.Pulse` solution — bump or append; record the decision.

**Key Files:**
- `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Abstractions/Abstractions/IErrorReporter.cs` (new, alongside `IErrorSink.cs`)
- `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Abstractions/Models/ErrorContext.cs`, `ErrorScope.cs`, `Breadcrumb.cs`, `ErrorLevel.cs` (new)
- `HoneyDrunk.Telemetry.Abstractions/CHANGELOG.md`; repo-level `CHANGELOG.md`

**Contracts:**
- `IErrorReporter` — the new error-reporting facade. Feed the confirmed final shape back to packet 01's `contracts.json` entry.
