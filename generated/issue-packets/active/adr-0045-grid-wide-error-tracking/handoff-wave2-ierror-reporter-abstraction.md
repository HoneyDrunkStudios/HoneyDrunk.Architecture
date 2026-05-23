# Handoff — Wave 1 → Wave 2: the IErrorReporter facade

**Read once at the Wave 1 → Wave 2 transition. Immutable (invariant 24).**

## What Wave 1 produced

- **ADR-0045 is Accepted** (packet 00). Status flipped; `adrs/README.md` updated. One new error-flow invariant is in `constitution/invariants.md` as **invariant 80** — pre-reserved as part of a 12-ADR batch (the file's verified current maximum is 51; 52–80+ are reserved across the batch). The error-flow invariant: *errors captured for the D8 capture-eligible cases flow through `IErrorReporter`, never via a direct backend SDK call* — and it **references** invariant 8 (secret values never appear in logs, traces, exceptions, or telemetry) rather than restating it. The batch note is attached: if any invariant above 51 lands from outside the batch before merge, shift upward, never reuse.
- **The Grid catalogs record the `IErrorReporter` contract** (packet 01). `catalogs/contracts.json` registers the `IErrorReporter` facade under the `honeydrunk-pulse` Node, alongside the existing `IErrorSink`/`ITraceSink`/`ILogSink`/`IMetricsSink` — described as a facade over `IErrorSink`, not a duplicate (marked `planned` until packet 02 lands). `catalogs/grid-health.json` was **not** edited — its node-entry schema has no observability/error-tracking readout. The D8 capture-vs-log policy is recorded as a cross-cutting note. The Notify-Sentry decommission is tracked in the dispatch plan's deferred list, not a catalog.

## Wave 2 packet

One packet:

- **Packet 02 (`Actor=Agent`)** — add the `IErrorReporter` facade and the error-model types (`ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel`) to `HoneyDrunk.Telemetry.Abstractions` in `HoneyDrunk.Pulse`.

## Critical context for Wave 2 execution

- **Target is `HoneyDrunk.Pulse`, not `HoneyDrunk.Observe`.** Outbound error telemetry belongs to Pulse — Observe's `boundaries.md` states outbound telemetry to external sinks belongs to Pulse; Observe is the inbound observation layer. `HoneyDrunk.Pulse` (v0.3.0, LIVE) already owns the sink contracts including `IErrorSink`.
- **Reconcile with the existing `IErrorSink`.** `HoneyDrunk.Pulse` already ships `IErrorSink` in `HoneyDrunk.Telemetry.Abstractions/Abstractions/IErrorSink.cs` — `CaptureAsync(ErrorEvent)`, `CaptureExceptionAsync`, `CaptureMessageAsync`, `FlushAsync` — backed by the `ErrorEvent` model (exception, message, severity, `CorrelationId`, `OperationId`, `NodeId`, `UserId`, `Environment`, `Release`, `Tags`, `Extra`). **`IErrorReporter` is NOT a duplicate of `IErrorSink`.** `IErrorReporter` is the application-facing **facade**: it captures ambient context (the current `Activity`/`trace_id`, the Grid `TenantId`/`PrincipalId`, the deployable `Release`), maintains the breadcrumb/scope stack, builds an `ErrorEvent`, and routes it to `IErrorSink`. It adds no new capture mechanism. **Do not modify `IErrorSink` or `ErrorEvent` — the facade is purely additive.**
- **Cross-initiative dependency on ADR-0040 packet 03.** ADR-0040's Pulse work bumps the `HoneyDrunk.Pulse` solution version (invariant 27). ADR-0045's Pulse work (packets 02, 03) is sequenced *after* ADR-0040's Pulse waves so version-bump ownership is unambiguous. Packet 02's `dependencies:` carries a cross-initiative edge to ADR-0040 packet 03's issue (`Architecture#<n>`). **Do not start packet 02 until ADR-0040's Pulse waves have landed.**
- **Version-state check.** Per invariant 27, packet 02 checks the `HoneyDrunk.Pulse` solution's in-progress version state at edit time: if ADR-0040's Pulse packets all merged and the solution is at a released version, packet 02 bumps (minor — new public types in `HoneyDrunk.Telemetry.Abstractions`); if an ADR-0040 version bump is still unreleased, packet 02 appends to that entry. Record which case applied.
- **Abstraction-only — invariant 1.** `HoneyDrunk.Telemetry.Abstractions` takes only `Microsoft.Extensions.*` abstractions plus whatever HoneyDrunk abstraction package it already references. **No App Insights SDK, no Sentry SDK, no Azure type** in `IErrorReporter` or its model types. The SDK lives in packet 03's backing, never the abstraction.
- **The `IErrorReporter` shape is fixed by ADR-0045 D3 — four members, no more:**
  ```
  ValueTask CaptureException(Exception ex, ErrorContext? context = null);
  ValueTask CaptureMessage(string message, ErrorLevel level, ErrorContext? context = null);
  IDisposable AddBreadcrumb(Breadcrumb crumb);
  IDisposable PushScope(ErrorScope scope);
  ```
- **Grid naming rule.** `ErrorContext`, `ErrorScope`, `Breadcrumb` are **records** and drop the `I` prefix. `IErrorReporter` is an **interface** and keeps it. `ErrorLevel` is an enum — or reuse the existing `TelemetryEventSeverity` if it already covers the levels; document the choice.
- **`ErrorContext` fields (D3):** `TraceId`, `TenantId`, `UserId`, `Release`, `Tags`. Reuse the Kernel `TenantId`/`PrincipalId` types if they exist — `user_id` is the opaque `PrincipalId` per ADR-0026, never an email or external identifier. `TenantId` is the dimension the existing `ErrorEvent` does NOT carry — the load-bearing reason the facade exists; the facade carries it onto `ErrorEvent.Tags`. `Breadcrumb`/`ErrorScope` are modeled on Sentry's semantics — backend-portable concepts (App Insights expresses them via custom events; Sentry consumes them natively if D11 fires). The XML docs must state that portability intent.

## Wave 2 exit criteria

- `IErrorReporter` exists in `HoneyDrunk.Telemetry.Abstractions` with exactly the four-member D3 shape; its XML docs state it is a facade over the existing `IErrorSink`, not a duplicate.
- The existing `IErrorSink` and `ErrorEvent` are unchanged.
- `ErrorContext`/`ErrorScope`/`Breadcrumb` are records, `ErrorLevel` is an enum (or `TelemetryEventSeverity` reused).
- `HoneyDrunk.Telemetry.Abstractions` took no new HoneyDrunk runtime dependency and no Azure/Sentry SDK (invariant 1).
- Every new public member has XML documentation (invariant 13).
- The invariant-27 version-state check on the `HoneyDrunk.Pulse` solution was performed and the decision recorded.
- `HoneyDrunk.Telemetry.Abstractions/CHANGELOG.md` and the repo-level `CHANGELOG.md` are updated.
- The solution builds; model-type tests pass.
- The confirmed `IErrorReporter` shape is fed back to packet 01's `contracts.json` entry.
