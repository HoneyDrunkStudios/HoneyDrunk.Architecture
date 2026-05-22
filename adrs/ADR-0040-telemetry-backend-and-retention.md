# ADR-0040: Telemetry Backend and Retention

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

> **Amendment 2026-05-22:** The original draft assigned outbound-telemetry export and the new exporter/sampler packages to `HoneyDrunk.Observe`. This was corrected to `HoneyDrunk.Pulse` to match the `HoneyDrunk.Observe` and `HoneyDrunk.Pulse` boundary documents — Observe is the *inbound* observation layer for external systems; Pulse owns *outbound* telemetry routing to sinks (`ITraceSink`/`ILogSink`/`IMetricsSink` and the `HoneyDrunk.Telemetry.Sink.*` provider family, which already includes a `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider). All D2/D4/Follow-up-Work references and package names below reflect the correction. Status is unchanged (Proposed).

## Context

ADR-0010 (Accepted) established `HoneyDrunk.Observe` (Ops) as the observation layer with provider-slot connectors; ADR-0028 (Proposed) named OTLP as the telemetry shape on the event/messaging matrix. Neither named a **backend** — a concrete destination for traces, metrics, and logs. Today the Grid emits OTLP through the Observe layer to nowhere, which means:

- The 12 live Nodes' production telemetry is effectively black-holed.
- The AI-sector standup wave (9 Seed Nodes) will emit substantial volumes of traces (LLM provider spans, tool-call spans, agent-run spans, eval runs) starting at standup; no decision exists on where these land or for how long.
- Pulse signals (per ADR-0028 explicitly "not domain events") have a separate durability question that intersects this ADR.

The forcing function is the AI-sector standup pattern (ADR-0016 onward). Every AI Node emits trace events as a contract-shape canary; a Pulse sink layer with no concrete backend fails the canary by definition. The secondary forcing function is Notify Cloud GA: a paying tenant's "show me my last hour of API errors" question requires retained, queryable signals — not just live telemetry.

This ADR decides:

- The backend(s) for traces, metrics, and logs.
- Per-signal retention windows.
- Sampling policy.
- Tenant-scoped vs. Studio-scoped views.
- The contract between the Pulse sink layer and the backend (so backend choice remains reversible).

## Decision

### D1 — Backend: Azure Monitor + Application Insights (single vendor, already-paid relationship)

The Grid adopts **Azure Monitor + Application Insights** as the telemetry backend across all three signal types (traces, metrics, logs) plus errors (per ADR-0045). One vendor, one portal, one billing relationship — and that relationship is **already established** by ADR-0015 (Container Apps), ADR-0005 (Key Vault), and the broader Azure footprint. No net-new vendor onboarding.

The unified-view surface is the **Application Insights resource in the Azure Portal**, which exposes:

- **Application Map** — service topology with health and error rates per Node. Closest thing to "see the whole Grid at once" on any platform; native to App Insights.
- **Failures** — exception/error tracking with problem-ID grouping (per ADR-0045).
- **Performance** — request/dependency duration breakdowns.
- **Transaction Search / End-to-end details** — trace viewer with all spans.
- **Logs (Log Analytics)** — KQL across traces, exceptions, dependencies, custom logs.
- **Metrics explorer** — both App-Insights-emitted metrics and Azure platform metrics (Container Apps CPU, Service Bus queue depth, Cosmos RU consumption, etc.) in one query surface.

The cross-signal navigation is native: same `operation_id` (≈ `trace_id`) flows automatically across blades. Click a Failures-blade error → see the failed trace → see surrounding logs → see metrics around that time window. The unified-view property is delivered by the storage model, not by configured cross-links.

Per-environment App Insights resources (`hd-dev`, `hd-staging`, `hd-prod`) keep dev noise out of prod dashboards. Resources are provisioned via the Azure Portal; connection strings live in Vault per ADR-0005. (Azure has retired classic instrumentation keys — the connection string is the modern credential.)

### D2 — Pulse is the OTLP-only telemetry boundary; the Azure Monitor sink is the connector

`HoneyDrunk.Pulse` exposes only the OTLP-shaped sink surface (`ITraceSink`/`ILogSink`/`IMetricsSink`, per ADR-0028). The **Azure Monitor OpenTelemetry Distro** (the Microsoft-maintained Azure Monitor Exporter for OpenTelemetry) is the connector behind that boundary — Nodes emit OTLP, the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider translates to App Insights' wire protocol and ships to the Azure Monitor backend. The exporter sits inside the Pulse Node's runtime, never in the consuming Node.

This is the load-bearing reversibility property. Switching backends (to Grafana Cloud + Sentry per D11, or to Datadog, or to any future option) is a configuration change at the Pulse Node only — zero Node-level changes elsewhere. Pulse already ships a `HoneyDrunk.Telemetry.Sink.*` provider family (Loki, Mimir, Tempo, Sentry, PostHog, AzureMonitor) precisely to deliver this property.

### D3 — Three signal types, three retention windows

App Insights' realistic retention bounds and the chosen Grid policy:

| Signal | Source | Default retention | Grid policy | Cost note |
|--------|--------|-------------------|-------------|-----------|
| **Traces** | OTLP from every Node | 90 days (Log Analytics workspace) | 90 days | Within Azure free quota for v1 volume |
| **Metrics** | OTLP + Azure platform metrics | 93 days (App Insights metrics) | 93 days | Free for platform metrics; custom metrics billed per-metric |
| **Logs** | OTLP from every Node + Audit | 90 days standard / **2 years for Audit-sourced logs** | 90/730 days | Audit extended retention pays per-GB-month above the free quota |

App Insights' native retention is meaningfully longer than Grafana Cloud's free tier (which is 14 days for metrics) — this is one of the operational arguments for the Azure Monitor path. The Audit 2-year retention satisfies ADR-0030 Phase 1's forensic completeness floor without separate-workspace complexity (one Log Analytics workspace with a custom table for Audit-sourced logs and a long retention policy on that table).

**Audit retention is the load-bearing exception.** Standard log retention satisfies "what happened in the last quarter"; Audit retention satisfies "what happened to this tenant last year." Same workspace, different per-table retention policy. The boundary is enforced by Audit emitter labeling (`source=hd-audit` custom dimension).

### D4 — Sampling: OpenTelemetry samplers and processors, with rules

Consistent with D2's OTLP-only-boundary commitment, sampling is configured via **OpenTelemetry primitives** — a custom `Sampler` composed into the `TracerProvider` and `SpanProcessor` filters wired alongside. The Azure Monitor OpenTelemetry Distro respects whatever sampler the OTel SDK is configured with; the Azure Monitor exporter sends the sampled output onward to App Insights without rewriting the sampling decision. This is the OTel-native path; classic App Insights SDK constructs like `ITelemetryProcessor` are not used (they'd undercut the reversibility property D2 buys).

Default sampler: **`ParentBased(TraceIdRatioBased)`** targeting ~5 items/second per host (matching App Insights' default expectation), implemented as a small custom sampler that wraps `TraceIdRatioBased` with dynamic-rate behavior. Lives in a new `HoneyDrunk.Telemetry.Sampling` package in the Pulse solution.

Rules layered on top of the base sampler (implemented as a chained `Sampler` or a `SpanProcessor` filter, depending on whether the decision must influence downstream span attribute drops):

- **100% sampling** for any span with `success=false` or `error=true` (decided at end-of-span via tail-sampling-like behavior in a `SpanProcessor`).
- **100% sampling** for any telemetry attributed to `HoneyDrunk.Audit`.
- **100% sampling** for any span attributed to a billing event emit (per ADR-0037).
- **100% sampling** during canary runs.
- **Lower-rate sampling** for high-volume background workloads (Pulse collector, Knowledge ingestion batch jobs) — composed as a stricter `TraceIdRatioBased` under a `ParentBased` boundary keyed on the workload's `service.name`.

The composition is wired into the Pulse telemetry pipeline alongside the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider. The Azure Monitor exporter is the connector behind the OTel SDK; the sampling decisions are made by the OTel SDK, not by the exporter or by App Insights post-ingest.

Metrics and logs are **not sampled** at ingestion (same principle as the original ADR — sampling logs/metrics for cost is a false economy; either keep them or don't, and at our volume keeping is cheap). Metric views and log filters, if any, are also OTel-native (`View`s for metrics; `LogRecordProcessor`s for logs).

### D5 — Tenant scoping: tenant-id as a custom dimension

Multi-tenant signals (per ADR-0026) carry `tenant.id` as an App Insights **custom dimension** on every telemetry item. The Notify Cloud request gateway sets it on every request, trace, log line, and metric label. The Audit canary covers the negative case (a tenant-attributable signal that lacks the dimension is a canary failure).

App Insights' Workbook surface is the mechanism for tenant-facing dashboards once Notify Cloud needs them. That feature is **deferred** to a follow-up; this ADR records the dimension discipline that makes it possible.

### D6 — Volume discipline

App Insights bills primarily by **data volume** (GB ingested + GB retained beyond the included quota), not by series cardinality the way Mimir does. The cardinality-killer concern from a Prometheus-style backend doesn't apply directly, but volume discipline still matters:

- **`user.id`, `message.id`, `request.id`** belong on **traces** (where cardinality drives no extra cost in App Insights, since they're per-event), not duplicated into every log line as redundant context.
- **High-frequency events** in tight loops are forbidden as `Information`-level emissions — they multiply ingest volume without information gain. Telemetry inside loops requires explicit sampling or aggregation.
- A canary in the `HoneyDrunk.Pulse` test surface walks Node-level telemetry emission and asserts no `Information`-level events inside identified hot paths (heuristic — flagged for review, not auto-blocked).

The original cardinality-as-billing-factor concern is named here so it doesn't get re-introduced if the backend ever switches back to a Prometheus-class store (D11 escalation path).

### D7 — Pulse derived-metric stream

Pulse signals are explicitly "not domain events" per ADR-0028. The Pulse Collector emits to its own durable store (Tier 2 per ADR-0036) and **also** emits a derived metric stream through the Pulse Azure Monitor sink into App Insights. The two are not the same:

- **Pulse's own store** is the source of truth for historical signal values.
- **The App Insights metric stream** is the operational dashboard / alerting surface, retained 93 days.

This is a deliberate dual-write because Pulse signal values (e.g., "API latency p99 over 24h") need a longer-form analytical surface than App Insights metrics provide; meanwhile, the alerting surface lives where dashboards live. Because Pulse owns the Azure Monitor sink (D2), this is an intra-Pulse change — no Node boundary is crossed.

### D8 — Alerting

**Azure Monitor Alerts** is the alert evaluation surface, with action groups routing notifications. Alert rules are defined as KQL queries (log alerts) or metric alerts on the relevant signals. Routing terminates at:

- **A Studio-operator channel** for Grid-internal alerts (single Slack-or-equivalent destination, configured in `business/context/`).
- **Notify Cloud (eventually)** for tenant-facing alerts on tenant-owned signals. Deferred to a future Notify Cloud feature.
- **PagerDuty / on-call** is **not** adopted at solo-developer scale. The operator-channel is the queue.

### D9 — PII and sensitive-content carve-outs

Trace and log content can leak PII or model-output content. Mechanism is **OpenTelemetry `Processor`s** — a `SpanProcessor` for traces and a `LogRecordProcessor` for logs that filter or redact attributes before the Azure Monitor exporter ships them onward. Consistent with D2 (OTel-native primitives, not classic App Insights SDK constructs):

- **Custom dimensions** (`tenant.id`, `service.name`, etc.) are not PII; allowed.
- **Telemetry containing user-typed content or model outputs** is forbidden by default. Specifically excluded: prompt text, completion text, recipient email addresses, message bodies.
- **Exception:** `HoneyDrunk.Evals` is the deliberate carve-out per ADR-0023 — eval signals may carry prompts and outputs because that is what they are for. Eval-emitted signals are labeled `evals.sensitive=true` (custom dimension), filtered to a dedicated Log Analytics table with the same 90-day retention and tighter access control (Azure AD role-scoped).
- **Audit emits** are PII-bearing by design (recipient email on a notification-sent audit entry, for example) and are governed by ADR-0030's append-only semantics; the 730-day retention in D3 accounts for this.

### D10 — Cost ceiling and v1 reality

Realistic v1 cost: **$0–30/month** at current Grid volume (12 live Nodes, low traffic, single dev). App Insights' included free quota (5GB ingest/month, 31 days retention on the free tier — but the paid tier we'll be on for the longer-retention guarantee starts around the same volume) is sufficient for current production.

The bill grows with:

- **AI-sector standup wave volume** — LLM call spans, tool dispatch spans, agent run traces. Plausible $30–80/month once the wave is mature.
- **Notify Cloud GA volume** — multi-tenant message-send telemetry. Linear with tenant count.
- **Audit retention** — 730-day retention on Audit-sourced logs incurs per-GB-month storage cost beyond the included quota. Bounded by Audit volume, not unbounded.

**Cost ceiling: $100/month** before reconsideration. (Halved from the original $200 because realistic v1 cost is materially lower than Grafana+Sentry would have been, and a lower ceiling forces tighter discipline.) Tracked in `business/context/`. Breaching the ceiling for two consecutive months triggers an ADR amendment — choose between accepting the new cost, tightening sampling/retention, or escalating to D11.

### D11 — Escalation path: Grafana Cloud + Sentry

Azure Monitor + App Insights is the v1 default chosen on cost discipline and existing-relationship grounds. It is **not** the best-in-class option for every dimension. The Grid commits to the following **documented escalation triggers** — if any fires, the next ADR amendment moves the relevant signal type to a specialized vendor.

| Escalation | Trigger | Target | Trade-off accepted |
|---|---|---|---|
| Move traces to Grafana Cloud Tempo | App Insights' trace UX becomes the operator's actual pain point in real diagnostic work | Grafana Cloud (free tier or Pro) | Two-tool unified view via configured cross-links; +$0–50/month |
| Move errors to Sentry | App Insights' Failures-blade workflow stops being adequate for release-triage at real user volume | Sentry (free tier or Team) | Separate error surface; +$0–26/month; cross-link to App Insights traces via `trace_id` (per ADR-0045 D11) |
| Move metrics to Grafana Cloud Mimir | Need for advanced metric features (e.g., recording rules, alerting expression language) exceeds Azure Monitor Alerts | Grafana Cloud | Multi-vendor metrics; +$0–50/month |
| Move logs to Grafana Cloud Loki | Loki-specific features (e.g., LogQL ergonomics, log streaming) materially improve operator workflow | Grafana Cloud | Multi-tool logs; +$0–50/month |
| Full switch to Grafana Cloud + Sentry | Two or more of the above fire within the same quarter | Both | Two managed-vendor relationships; $50–150/month combined |

The escalation is preserved by the Pulse sink boundary (D2). Switching any signal type's backing is a single Pulse-side configuration change — no Node-level work, no breaking change to consumers.

This is the discipline the v1 cost-conservative choice is asking for: **commit to the cheaper, already-paid option now, observe whether its UX/feature gaps actually hurt, and escalate signal-by-signal with concrete evidence.** Speculative escalation up-front is rejected (the original Grafana Cloud + Sentry framing in the first draft of this ADR).

## Consequences

### Affected Nodes

- **HoneyDrunk.Pulse** — primary affected Node; extends its existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider with the OTLP-to-App-Insights configuration via the Azure Monitor OpenTelemetry Distro, gains the new `HoneyDrunk.Telemetry.Sampling` package for the adaptive-sampling + rules processor (D4), the volume-discipline canary (D6), the PII filter processor (D9), and the derived-metric stream emit (D7).
- **HoneyDrunk.Observe** — not affected by this ADR. Observe is the *inbound* observation layer for external systems; outbound telemetry export is Pulse's boundary.
- **HoneyDrunk.Evals** (Seed) — at standup, wires the `evals.sensitive=true` dimension and the dedicated Log Analytics table per D9.
- **HoneyDrunk.Audit** — emits to the Audit-tagged Log Analytics table with 730-day retention per D3.
- **HoneyDrunk.Vault** — stores App Insights connection strings per environment.
- **HoneyDrunk.Architecture** — `catalogs/grid-health.json` is the readout surface; alert routing list lives in `business/context/`.

### Invariants

Adds three. Numbers **69, 70, 71** are pre-reserved for this ADR as part of a 12-ADR batch; the current highest invariant in `constitution/invariants.md` is 51.

- **Invariant 69: no Node references App Insights (or any backend) directly.** All telemetry routes through the `HoneyDrunk.Pulse` sink surface; backend changes (including escalations per D11) are a single Pulse configuration change.
- **Invariant 70: high-cardinality identifiers belong on traces and logs, not duplicated as custom dimensions on metrics where they'd inflate volume.** Specifically `user.id`, `message.id`, `request.id` are trace/log dimensions, never metric dimensions.
- **Invariant 71: prompt/completion text appears in telemetry only behind the `evals.sensitive=true` dimension and the dedicated Log Analytics table.** Default-deny for content; explicit opt-in for evals.

### Operational Consequences

- App Insights is part of the existing Azure footprint; no new vendor relationship, no new billing line beyond the Azure subscription.
- The App Insights resources need provisioning per environment (Azure Portal); a one-time setup, then Vault-stored connection strings.
- Realistic v1 cost is $0–30/month. The $100/month ceiling is the trigger for reconsideration, not the expected steady-state.
- Switching any signal-type backend (D11) is a configuration change at Pulse; dashboards land in the new tool's format and migrate via export/import. App Insights Workbooks and Grafana dashboards both support JSON-as-code, so dashboard migration is bounded.
- 90-day standard retention is meaningfully longer than Grafana Cloud's free tier (14 days for metrics); this is one of the practical advantages of the Azure Monitor path.
- The Azure Portal UI is the operator's primary surface. Workbook construction is required if a single-page combined view is desired (the App Insights default blades are signal-type-specialized).
- KQL has a learning curve compared to PromQL/LogQL; the trade-off is recorded as part of the v1 commitment.
- The Audit 730-day retention requires explicit Log Analytics table configuration (per-table retention policies) and incurs storage cost beyond the included quota.

### Follow-up Work

- Provision App Insights resources for `dev`/`staging`/`prod` (the staging/prod environments are still in flight per ADR-0033).
- Extend the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider in the Pulse solution with the Azure Monitor OpenTelemetry Distro wired through the Pulse sink contracts (`ITraceSink`/`ILogSink`/`IMetricsSink`).
- Implement the OpenTelemetry samplers (in a new `HoneyDrunk.Telemetry.Sampling` package in the Pulse solution) and PII `SpanProcessor` / `LogRecordProcessor`s; wire into the OTel `TracerProvider` and `LoggerProvider` builders in the Pulse telemetry pipeline.
- Implement the volume-discipline canary.
- Author Workbooks-as-code under `repos/HoneyDrunk.Pulse/workbooks/` for the most common operational views.
- Configure per-table Log Analytics retention for the Audit table (730 days).
- Author the tenant-facing Notify Cloud telemetry feature (deferred, D5/D8) as a future ADR.
- Wire the Studio operator alert channel; record the channel id in `business/context/`.

## Alternatives Considered

### Grafana Cloud (the original v1 choice, now the D11 escalation path)

Considered as v1 default in the first draft of this ADR. Strong tooling: Tempo for traces, Mimir for metrics, Loki for logs, unified Grafana frontend. **Rejected as v1** on three grounds:

- **Cost vs already-paid Azure relationship.** The Grid is already on Azure (ADR-0015). Adopting Grafana Cloud is a new vendor relationship and a new billing line. App Insights leverages a sunk cost.
- **Free-tier retention reality.** The original draft of this ADR claimed 13-month metrics retention on Grafana Cloud, but the free tier only delivers 14-day metrics retention; the longer window requires Pro tier from day one. This was a bug. App Insights' free/included tier gives 90-day retention out of the box.
- **Cross-link complexity.** Grafana Cloud + Sentry requires configured cross-links (Sentry trace-tool URL template + Grafana Tempo→Sentry integration) to deliver the unified view. App Insights delivers the same property natively via `operation_id`.

Documented as the D11 escalation path with explicit triggers — picked when its specific advantages (Grafana frontend polish, advanced trace UX, recording rules, LogQL) outweigh the cost and complexity. Not before.

### Honeycomb

Considered. Strong tracing UX; weaker metrics/logs story. Rejected on the unified-surface argument (App Insights covers more signal types in one place) and on cost (new vendor).

### Self-hosted Tempo + Mimir + Loki

Rejected. Studio is one operator; running a telemetry stack is a part-time job. Self-hosting cost (operator-time) exceeds the SaaS subscription several times over. Same conclusion as the original draft.

### Datadog

Considered. Best-in-class UX, broadest integration surface. Rejected on per-host pricing at multi-Node scale.

### SigNoz or HyperDX (self-hostable unified observability)

Considered. Genuine open-source alternatives to App Insights with OTLP-native ingestion. Rejected on the same self-host operator-burden grounds as Tempo/Mimir/Loki — patching, upgrading, backups (per ADR-0036), database management for the underlying ClickHouse/Postgres are not solo-dev-friendly. Reconsidered if the Grid ever grows operator headcount.

### Tail-based sampling instead of adaptive

App Insights doesn't natively support tail-based sampling. Adaptive sampling (D4) is the trade-off — head-based with dynamic rate adjustment. If trace fidelity becomes a pain point, the escalation to Grafana Cloud Tempo (D11) opens the door to tail-based via an OTel Collector in front.

### Skip the policy until the Notify Cloud GA milestone

Rejected. The AI-sector standup wave starts emitting trace volume well before GA. Standup canaries require a working sink. Defer-and-suffer-canary-failures is the worse option.

### Speculative escalation to Grafana Cloud + Sentry up-front

Rejected (this is the change from the first draft). The original framing committed to two best-in-class vendors before observing whether the cheaper already-paid path's UX actually hurts in practice. Cost-conservative discipline says: commit to the existing relationship, observe the gaps, escalate with evidence. D11 makes the escalation triggers explicit so this isn't permanent under-commitment.
