# Handoff — Wave 2 → Wave 3: sampling, PII, retention, Pulse-emit, alerting

**Read once at the Wave 2 → Wave 3 transition. Immutable (invariant 24).**

> **Note:** packets 03/04/05/07 target `HoneyDrunk.Pulse` (ADR-0040 amendment 2026-05-22 — Pulse owns outbound telemetry export, not Observe).

## What Wave 2 produced

- **`HoneyDrunk.Telemetry.Sink.AzureMonitor` is extended** (packet 03) — the existing Pulse provider now wires the Azure Monitor OpenTelemetry Distro behind the Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`); traces/metrics/logs ship to the `dev` App Insights resource via a Vault-resolved connection string. No new package, no new abstraction.
- **Composition seams exist.** Packet 03 left builder hooks / DI extension points on the `TracerProvider` (for the sampler), and on the `TracerProvider` + `LoggerProvider` (for the PII processors). Wave-3 packets 04 and 05 plug into these.
- **The `HoneyDrunk.Pulse` solution version was bumped** (minor) by packet 03. Wave-3 packets 04, 05, and 07 do NOT bump again — they append to the repo-level `CHANGELOG.md` in-progress version entry (invariant 27).

## Wave 3 packets

Five packets:

- **Packet 04 (`Actor=Agent`, Pulse)** — `HoneyDrunk.Telemetry.Sampling` (a new package in the Pulse solution): the adaptive `ParentBased(TraceIdRatioBased)` base sampler + the always-sample rule chain (errors, Audit, billing-event spans, canary runs at 100%; high-volume background workloads at a stricter rate).
- **Packet 05 (`Actor=Agent`, Pulse)** — the PII `SpanProcessor`/`LogRecordProcessor` (default-deny for prompt/completion/email/message-body content) built on a **shared, mechanism-agnostic regex scrubber** in `HoneyDrunk.Telemetry.Sink.Shared`, the `evals.sensitive=true` carve-out routing, and the volume-discipline canary.
- **Packet 06 (`Actor=Human`, Architecture)** — Log Analytics per-table retention: 730 days for the Audit table, 90 standard, the access-controlled `evals.sensitive` table.
- **Packet 07 (`Actor=Agent`, Pulse)** — the Pulse derived-metric stream emit per D7 (dual-write: Pulse's own store + a derived OTLP metric stream through the Pulse pipeline into the AzureMonitor sink).
- **Packet 08 (`Actor=Human`, Architecture)** — Azure Monitor Alerts + the Studio operator alert channel.

## Critical context for Wave 3 execution

### Packets 04 and 05 are serialized

- Both touch `HoneyDrunk.Telemetry.Sink.AzureMonitor`. **Packet 05 is `Blocked by: 04`** — land 04 first, 05 rebases. They have no logical dependency (04's sampler and 05's processors plug into independent seams packet 03 left), but the serialization avoids a merge conflict on the shared project. **Neither bumps the version** — packet 03 already bumped it this initiative; both append to the in-progress repo-level `CHANGELOG.md` entry (invariant 27).

### Packet 04 (sampling)

- The package is `HoneyDrunk.Telemetry.Sampling`, new in the **`HoneyDrunk.Pulse`** solution.
- **OTel-native only** — `Sampler`, `SpanProcessor`, `TraceIdRatioBasedSampler`, `ParentBasedSampler` from the `OpenTelemetry` package. No classic App Insights `ITelemetryProcessor` — D4 forbids it; it undercuts D2's reversibility.
- **The error rule is end-of-span.** `success=false`/`error=true` is known only when the span closes — implement it as a `SpanProcessor` with tail-sampling-like behavior, not a span-start `Sampler`. The Audit / billing / canary rules ARE span-start — a chained `Sampler`.
- Audit, billing-event (ADR-0037), and canary spans sample at 100%, keyed on `service.name` / span attributes / markers — document each key.
- High-volume background workloads (Pulse collector, Knowledge ingestion) get a stricter `TraceIdRatioBased` under a `ParentBased` boundary keyed on `service.name`.
- Wire the sampler into the `HoneyDrunk.Telemetry.Sink.AzureMonitor` `TracerProvider` builder via the packet-03 seam.

### Packet 05 (PII processors + canary)

- **OTel-native `SpanProcessor`/`LogRecordProcessor`** — same rule as packet 04, no `ITelemetryProcessor`.
- **The PII regex scrubber is a shared, mechanism-agnostic component** in `HoneyDrunk.Telemetry.Sink.Shared` — no OTel or App Insights type in its signature. ADR-0045's error path reuses it as-is; building it shared from the start saves ADR-0045 a refactor. The OTel processors in this packet *call* the shared scrubber.
- Default-deny for prompt text, completion text, recipient email addresses, message bodies. Custom dimensions (`tenant.id`, `service.name`, opaque `user.id`) pass through.
- **Two carve-outs that are NOT redacted:** `HoneyDrunk.Evals` telemetry labeled `evals.sensitive=true` (routed to a dedicated Log Analytics table) and `HoneyDrunk.Audit`-attributed telemetry (PII-bearing by design, routed to the Audit table). The processors recognize both by `service.name` / custom dimension and pass them through.
- **The volume-discipline canary is a heuristic — it flags for review, it does NOT fail the build.** D6 is explicit on this. It lands in the Pulse test/canary surface.
- **Coordinate table names with packet 06.** Packet 05's exporter routes `evals.sensitive` telemetry to a named table; packet 06 creates that exact table. The Audit table likewise. The names must agree — exchange them between the two packets.

### Packet 06 (retention)

- **One workspace, per-table retention.** D3 — do NOT create a separate workspace for Audit logs. The Audit table gets a per-table 730-day retention policy overriding the 90-day workspace default. The `evals.sensitive` table gets 90 days + Azure-AD-role-scoped access.
- Append the steps to `infrastructure/walkthroughs/application-insights-provisioning.md` (the packet-02 walkthrough). Portal-only. `dev` only.
- Coordinate the table names with packet 05.

### Packet 07 (Pulse derived-metric emit)

- **Intra-Pulse change — no boundary ambiguity.** ADR-0040's earlier Observe-vs-Pulse ambiguity is resolved (amendment 2026-05-22): Pulse owns outbound telemetry export. The Collector feeds the derived metric stream into the same Pulse telemetry pipeline the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider (packet 03) consumes. No cross-Node hop, no path reconciliation, and the AzureMonitor sink is the intended exporter (not redundant).
- The emit is a **dual-write** — Pulse's own durable store stays the source of truth (unchanged); the derived OTLP metric stream is additive. A failure in one write must not silently drop the other.
- **No version bump** — packet 03 already bumped the `HoneyDrunk.Pulse` solution this initiative; packet 07 appends to the CHANGELOG.
- The Collector reaches App Insights only via the AzureMonitor sink — never directly (invariant 69).

### Packet 08 (alerting)

- **No PagerDuty, no on-call rotation** — D8 is explicit; the single Studio-operator channel is the queue at solo-developer scale.
- Webhook secrets (e.g. a Slack webhook URL with a token) go in Vault — only a non-sensitive channel identifier goes in `business/context/` (invariant 8).
- **Metric alerts are conditional on their target resources existing.** Container Apps (ADR-0015) and Service Bus may not be provisioned in `dev` — a metric alert cannot target a non-existent resource. Create those only if the resources exist; otherwise document them as a deferred starter set. The App-Insights log alerts have no such dependency.
- Cross-reference the existing `log-analytics-workspace-and-alerts.md` for generic alert-rule mechanics — do not duplicate them. Keep the starter rule set minimal (per-rule evaluation cost, D10).

## Wave 3 exit criteria

- `HoneyDrunk.Telemetry.Sampling` exists; the adaptive sampler + always-sample rules are wired into the `Sink.AzureMonitor` `TracerProvider`.
- The PII `SpanProcessor`/`LogRecordProcessor` redact prompt/completion/PII content via the shared `Sink.Shared` scrubber; the `evals.sensitive` and Audit carve-outs pass through; the volume-discipline canary flags (does not block).
- The `dev` Log Analytics workspace has the Audit table at 730-day retention and the access-controlled `evals.sensitive` table at 90 days; the table names match packet 05's routing.
- Pulse emits the derived metric stream through the Pulse pipeline into the AzureMonitor sink (dual-write); Pulse's own store is unchanged.
- Azure Monitor Alerts route to the Studio operator action group; the channel id is recorded in `business/context/`; metric alerts conditional on Container Apps / Service Bus existing.
- The `HoneyDrunk.Pulse` solution builds with packets 03–05, 07 all merged; no second version bump (invariant 27).
- Cross-check ADR-0045 coordination (see dispatch plan) before ADR-0045's Pulse packets start.
