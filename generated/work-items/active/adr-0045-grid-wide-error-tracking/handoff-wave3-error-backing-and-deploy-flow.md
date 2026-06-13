# Handoff — Wave 2 → Wave 3: the App Insights error backing and the deploy-flow change

**Read once at the Wave 2 → Wave 3 transition. Immutable (invariant 24).**

## What Wave 2 produced

- **The `IErrorReporter` facade exists** (packet 02) in `HoneyDrunk.Telemetry.Abstractions`, with the fixed four-member D3 shape: `CaptureException`, `CaptureMessage`, `AddBreadcrumb`, `PushScope`. It is a facade over the existing `IErrorSink` — not a duplicate. The error-model types `ErrorContext` (record — `TraceId`/`TenantId`/`UserId`/`Release`/`Tags`), `ErrorScope` (record), `Breadcrumb` (record), and `ErrorLevel` (enum, or the reused `TelemetryEventSeverity`) ship alongside it. The existing `IErrorSink`/`ErrorEvent` are unchanged. The abstraction took no Azure/Sentry SDK (invariant 1). The packet recorded which invariant-27 version-state case applied — read the packet-02 PR for whether the `HoneyDrunk.Pulse` solution version was bumped or appended.

## Wave 3 packets

Two packets, runnable in parallel (different repos, no dependency between them):

- **Packet 03 (`Actor=Agent`, `HoneyDrunk.Pulse`)** — implement the App-Insights-SDK-based error backing + the `IErrorReporter` facade implementation + the error PII `ITelemetryProcessor` in the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package.
- **Packet 04 (`Actor=Agent`, `HoneyDrunk.Actions`)** — amend the reusable deploy workflows with the App Insights release-annotation step.

## Critical context for Packet 03 (the error backing)

- **Target is `HoneyDrunk.Pulse`, and the backing extends the EXISTING `HoneyDrunk.Telemetry.Sink.AzureMonitor` package.** It does not create a new package and does not live in `HoneyDrunk.Observe`. The work is two parts: (1) extend the AzureMonitor sink's error-capture path (`IErrorSink` backing → `TrackException`) and (2) implement the `IErrorReporter` facade — the class that builds an `ErrorEvent` from ambient context and routes it through `IErrorSink`. The facade does not reinvent `IErrorSink`.
- **Cross-initiative dependency on ADR-0040 packet 05.** ADR-0040 packet 05 builds the PII redaction processors **and the shared, mechanism-agnostic `PiiScrubber` as a shared component from the start** (ADR-0040 packet 05 was corrected to do so). Packet 03's `dependencies:` carries a cross-initiative edge to ADR-0040 packet 05's issue — a **plain hard dependency**. **Do not start packet 03 until ADR-0040 packet 05 has landed** — packet 03 **consumes** that shared scrubber; no refactor needed.
- **The PII processor — `ITelemetryProcessor` is correct.** ADR-0045 D7 names `ITelemetryProcessor`; ADR-0040 D9 is OTel-native. This is **not a contradiction**: the error path uses the App Insights SDK directly (D3's carve-out), and `ITelemetryProcessor` is the SDK's *only* filter hook. ADR-0040 D9's mechanism choice applies to the **OTLP path**, not the SDK path. Packet 03 **correctly** uses `ITelemetryProcessor` for the error path. The regex scrubbing rules are **not** re-implemented — the error `ITelemetryProcessor` consumes the shared `PiiScrubber` from ADR-0040 packet 05. One regex surface, no duplication, no drift.
- **No new App Insights resource, no new secret, no new package.** ADR-0045 D2 captures errors into the *same* App Insights resource as traces/metrics/logs. Packet 03 reuses the connection string ADR-0040 packet 02 seeded into the relevant `kv-hd-{service}-{env}` Key Vault, resolved via `ISecretStore` (invariant 9). This is a **Human Prerequisite** on packet 03 — the `dev` App Insights resource must exist (ADR-0040 packet 02); it is not a `dependencies:` edge because cross-initiative `work-item:NN` references do not resolve, and provisioning is a portal artifact.
- **The App Insights SDK goes in `HoneyDrunk.Telemetry.Sink.AzureMonitor` only.** `Microsoft.ApplicationInsights` is referenced by the sink package — never by `HoneyDrunk.Telemetry.Abstractions`, never by a consuming Node. Invariant 80 (the error-flow invariant from packet 00) enforces this.
- **`operation_id` cross-link (D4).** Map `ErrorContext.TraceId` to the telemetry's `operation_Id` so the App Insights Failures→Transactions→Logs navigation is native — no configured integration.
- **`evals.sensitive` / Audit carve-outs.** Telemetry with `evals.sensitive=true` is NOT scrubbed of prompt/completion content (ADR-0023/ADR-0040 D9 carve-out). `HoneyDrunk.Audit`-attributed errors are PII-bearing by design — pass through unredacted to the Audit-tagged table.
- **Version-state check (invariant 27).** Packet 03 appends to the in-progress `HoneyDrunk.Pulse` solution version if packet 02 bumped it; or bumps if packet 02 only appended to a since-released ADR-0040 entry. Read the packet-02 PR; record the decision.

## Critical context for Packet 04 (the deploy-flow change)

- **Independent of the Pulse packets.** Packet 04 depends only on packet 00 — it can run in parallel with packets 02/03, or even earlier. It is grouped into Wave 3 for tidy filing; the `dependencies:` frontmatter is the real signal.
- **The release-annotation step is never a deploy gate.** A failed or unconfigured annotation must not fail the deploy. The step is gated on the new optional inputs (`app-insights-release-annotation` default `false`, `app-insights-resource-id`); when off or empty, it logs one skipped line and exits 0.
- **No secret in the workflow.** The annotation call authenticates via the existing OIDC federation the deploy job already uses — no DSN, instrumentation key, or connection string is committed (invariant 8).
- **Use the current supported annotation mechanism.** `az monitor app-insights` / ARM is the default, supported mechanism — make that the acceptance criterion. The raw `https://aigs1.aisvc.visualstudio.com/...` endpoint is a legacy surface — fallback only if no supported equivalent applies. Research and document the choice.
- **No version bump.** `HoneyDrunk.Actions` is not a versioned .NET solution — packet 04 is a YAML change; the new inputs are optional and backward-compatible.

## Wave 3 exit criteria

- `HoneyDrunk.Telemetry.Sink.AzureMonitor` captures exceptions into App Insights via the .NET SDK; the `IErrorReporter` facade is implemented over the existing `IErrorSink`; `ErrorContext.TraceId` maps to `operation_Id`; `application_Version` is set; breadcrumbs/scopes work; the error PII `ITelemetryProcessor` scrubs the D7 set by consuming the shared `PiiScrubber`; the `evals.sensitive`/Audit carve-outs pass through; `IErrorReporter` is part of the standard Pulse telemetry registration.
- The error `ITelemetryProcessor` consumes ADR-0040 packet 05's shared `PiiScrubber` — no re-implementation, no refactor.
- The invariant-27 version-state check was performed for the `HoneyDrunk.Pulse` solution.
- The Actions reusable deploy workflows (`job-deploy-container-app.yml`, `job-deploy-function.yml`) carry the gated, default-off, OIDC-authenticated release-annotation step using the current supported mechanism; consumer docs updated.
- Both solutions build; tests pass; no external service in unit tests (invariant 15).
