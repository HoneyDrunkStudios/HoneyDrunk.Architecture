# ADR-DRAFT: Telemetry Backend and Retention

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

## Context

ADR-0010 (Accepted) stood up `HoneyDrunk.Observe` (Ops) as the observation layer with provider-slot connectors; ADR-0028 (Proposed) named OTLP as the telemetry shape on the event/messaging matrix. Neither named a **backend** — a concrete destination for traces, metrics, and logs. Today the Grid emits OTLP through the Observe layer to nowhere, which means:

- The 12 live Nodes' production telemetry is effectively black-holed.
- The AI-sector standup wave (9 Seed Nodes) will emit substantial volumes of traces (LLM provider spans, tool-call spans, agent-run spans, eval runs) starting at standup; no decision exists on where these land or for how long.
- Pulse signals (per ADR-0028 explicitly "not domain events") have a separate durability question that intersects this ADR.
- ADR-0036 (DR, Proposed) names retention windows for backups but not for telemetry — they're orthogonal but related signals.

The forcing function is the AI-sector standup pattern (ADR-0016 onward). Every AI Node emits trace events as a contract-shape canary; an Observe layer with no sink fails the canary by definition. The secondary forcing function is Notify Cloud GA: a paying tenant's "show me my last hour of API errors" question requires retained, queryable signals — not just live telemetry.

This ADR decides:

- The backend(s) for traces, metrics, and logs.
- Per-signal retention windows.
- Sampling policy.
- Tenant-scoped vs. Studio-scoped views.
- The contract between Observe and the backend (so backend choice remains reversible).

## Decision

### D1 — Backend: Grafana Cloud (single vendor across traces, metrics, logs)

The Grid adopts **Grafana Cloud** as the telemetry backend for all three signal types (traces via Tempo, metrics via Mimir/Prometheus, logs via Loki). One vendor, one auth surface, one Grafana frontend, one billing relationship.

Rationale recorded in Alternatives. The short version: Grafana Cloud has a usable free tier that absorbs the current and near-term Grid volume; pricing scales linearly and is predictable; OTLP ingest is first-class; the unified frontend reduces solo-operator context-switching across three tools.

Per-environment workspaces (`hd-dev`, `hd-staging`, `hd-prod`) keep dev noise out of prod dashboards. Workspaces are provisioned via Grafana Cloud's API; credentials live in Vault per ADR-0005.

### D2 — Observe is the OTLP-only boundary

`HoneyDrunk.Observe` exposes only the OTLP-shaped surface (per ADR-0010 and ADR-0028). The Grafana Cloud OTLP endpoint is configured as the default sink in the `dev`/`staging`/`prod` Observe configurations; the configuration is **the only place Grafana Cloud appears in the Grid**. Switching backends is a configuration change at one Node, not a 12-Node rollout.

This is the load-bearing reversibility principle: the backend pick is reversible because Observe never lets a vendor-specific shape leak.

### D3 — Three signal types, three retention windows

| Signal | Source | Retention | Reason |
|--------|--------|-----------|--------|
| **Traces** | OTLP from every Node | **14 days** | Debugging window; longer windows produce diminishing returns at exponential cost. |
| **Metrics** | OTLP from every Node + scraped Pulse signals | **13 months** | Year-over-year comparison + a month of buffer. |
| **Logs** | OTLP from every Node | **30 days** standard / **400 days** for Audit-sourced logs | Standard window for ops; Audit window matches forensic requirement (ADR-0030 Phase 1 floor). |

Retention is configured per-workspace in Grafana Cloud. Audit-sourced logs are a separate Loki stream with its own retention policy; the boundary is enforced by Audit emitter labeling (`source=hd-audit`).

**Audit retention is the load-bearing exception.** Standard log retention satisfies "what happened in the last month"; Audit retention satisfies "what happened to this tenant 9 months ago when they signed up." The two needs share a Loki backend but not a retention policy.

### D4 — Sampling: head-based at the emitter, with rules

Trace sampling is **head-based** (the decision is made at span creation), not tail-based (which would require a tail-sampler in front of Grafana Cloud). The default sample rate is **10% of normal traffic**, with rules that escalate:

- **100% sampling** for any span with `error=true`.
- **100% sampling** for any span attributed to `HoneyDrunk.Audit` (audit pipeline traces are first-class).
- **100% sampling** for any span attributed to a billing event emit (per ADR-0037; billing telemetry is high-value-per-span).
- **100% sampling** during canary runs (every standup canary trace is retained).
- **1% sampling** for high-volume background workloads (Pulse collector, Knowledge ingestion batch jobs).

Sampling is configured via the OpenTelemetry SDK's `ParentBased(TraceIdRatioBased)` sampler at the SDK level; rules above are implemented as a custom sampler in `HoneyDrunk.Observe.Sampling`. The custom sampler is a small, shipped component, not a per-Node configuration.

Metrics and logs are **not sampled** (sampling logs/metrics for cost is a false economy at Grid scale; either keep them or don't).

### D5 — Tenant scoping: tenant-id label on every signal, Grafana-level view isolation

Multi-tenant signals (per ADR-0026) carry `tenant.id` as an OTel resource attribute. This is not optional — Notify Cloud's request gateway sets it on every span, log line, and metric label. The Audit canary covers the negative case (a tenant-attributable signal that lacks the label is a canary failure).

Grafana Cloud's "view isolation" is configured per-tenant for Notify Cloud's eventual tenant-facing dashboards. Tenants do not receive Grafana Cloud accounts; instead, a future Notify Cloud feature renders a tenant-scoped view of their own signals behind the Notify Cloud auth surface. That feature is **deferred** to a follow-up ADR; this ADR records the label discipline that makes it possible.

### D6 — Cardinality discipline

The cardinality killer in metrics backends is high-cardinality labels (`user_id`, `message_id`, `tenant_id` on every metric). Policy:

- `tenant.id` is **allowed** as a label on metrics; cardinality bounded by tenant count.
- `user.id`, `message.id`, `request.id` are **forbidden** as metric labels. They belong on **traces** (where cardinality is not a billing factor) and on **logs**, not metrics.
- A canary in `HoneyDrunk.Observe` walks the metric registry and fails if a forbidden label is in use.

This is a small invariant with outsized cost impact at scale.

### D7 — Pulse intersection

Pulse signals are explicitly "not domain events" per ADR-0028. The Pulse Collector emits to its own durable store (Tier 2 per ADR-0036) and **also** emits a derived metric stream to Observe → Grafana Cloud. The two are not the same:

- **Pulse's own store** is the source of truth for historical signal values.
- **The Grafana Cloud metric stream** is the operational dashboard / alerting surface, retained 13 months.

This is a deliberate dual-write because Pulse signal values (e.g., "API latency p99 over 24h") need a longer-form analytical surface than Grafana metrics provide; meanwhile, the alerting surface lives where dashboards live.

### D8 — Alerting

Grafana Cloud's alerting (Grafana Alertmanager) is the alert evaluation surface. Alert routing terminates at:

- **Notify Cloud (eventually)** for tenant-facing alerts on tenant-owned signals. Deferred to the same Notify Cloud feature as D5.
- **A Studio-operator channel** for Grid-internal alerts: a single Slack-or-equivalent destination, configured in `business/context/` (not in the Grid catalogs, because the channel is operational).
- **PagerDuty / on-call** is **not** adopted at solo-developer scale. The Studio operator is the entire on-call rotation; the Slack-class channel is the queue.

### D9 — PII and sensitive-content carve-outs

Trace and log content can leak PII or model-output content. Policy:

- **OTel resource attributes** (`tenant.id`, `service.name`, etc.) are not PII; allowed.
- **Span events containing user-typed content or model outputs** are forbidden by default. Specifically excluded: prompt text, completion text, recipient email addresses, message bodies.
- **Exception:** `HoneyDrunk.Evals` is the deliberate carve-out per ADR-0023 — eval signals may carry prompts and outputs because that is what they are for. Eval-emitted spans/logs are labeled `evals.sensitive=true` and routed to a separate Loki stream with the same 30-day retention but tighter access control (Grafana folder/team scoped).
- **Audit emits** are PII-bearing by design (recipient email on a notification-sent audit entry, for example) and are governed by ADR-0030's append-only semantics; the 400-day retention in D3 accounts for this.

### D10 — Cost ceiling

Grafana Cloud has a free tier (10K series for metrics, 50GB logs, 50GB traces at posting). The Grid is expected to stay inside the free tier through the Notify Cloud GA milestone; the first paying tenant's volume is the trigger for upgrading. A monthly cost ceiling (initially $100/month) is recorded in `business/context/`; crossing it triggers a review (not an automatic upgrade). The review either accepts the new cost or reduces sampling / retention.

## Consequences

### Affected Nodes

- **HoneyDrunk.Observe** — primary affected Node; gains the OTLP-to-Grafana-Cloud configuration, the custom sampler (D4), the cardinality canary (D6), and the PII allow-list canary (D9).
- **HoneyDrunk.Pulse** — gains the derived-metric stream emit per D7.
- **HoneyDrunk.Evals** (Seed) — at standup, wires the `evals.sensitive=true` label and the separate Loki stream per D9.
- **HoneyDrunk.Audit** — emits to the Audit-scoped Loki stream with 400-day retention per D3.
- **HoneyDrunk.Vault** — stores Grafana Cloud API tokens per environment.
- **HoneyDrunk.Architecture** — `catalogs/grid-health.json` is the readout surface; alert routing list lives in `business/context/`.

### Invariants

Adds three:

- **Invariant: no Node references Grafana Cloud directly.** All telemetry routes through Observe; backend changes are a single Observe configuration change.
- **Invariant: high-cardinality identifiers are not metric labels.** Specifically `user.id`, `message.id`, `request.id` are trace/log dimensions, never metric dimensions.
- **Invariant: prompt/completion text appears in telemetry only behind the `evals.sensitive=true` label and Evals-restricted Loki stream.** Default-deny for content; explicit opt-in for evals.

### Operational Consequences

- The free tier is sufficient for the current Grid; upgrade cost begins at the first paying tenant's volume. Recorded as a known cost step in the Notify Cloud GA budget.
- Switching backends is a single Observe configuration change at the cost of re-creating dashboards in the new tool. Dashboards are checked into `repos/HoneyDrunk.Observe/dashboards/` as JSON (Grafana-compatible) and are part of what migrates if a switch happens.
- 14-day trace retention is shorter than some operators are used to. The trade-off is recorded: at exponential cost growth, the marginal trace older than 14 days is not pulling its weight.
- Audit's 400-day Loki retention is a meaningful cost line item; it is the deliberate price of ADR-0030's forensic posture.
- Cardinality canary failure at PR time is a developer interrupt; the canary fails fast so the metric never lands in production with a bad label.

### Follow-up Work

- Provision Grafana Cloud workspaces for `dev`/`staging`/`prod` (the staging/prod environments are still in flight per ADR-0033).
- Implement the custom sampler in `HoneyDrunk.Observe.Sampling`.
- Implement the cardinality canary and PII allow-list canary; wire into the standup-canary pattern.
- Author dashboards-as-code under `repos/HoneyDrunk.Observe/dashboards/`.
- Author the tenant-facing Notify Cloud telemetry feature (deferred, D5/D8) as a future ADR.
- Wire the Studio operator alert channel; record the channel id in `business/context/`.

## Alternatives Considered

### Honeycomb

Considered. Strong tracing UX; weaker metrics/logs story (Honeycomb is trace-first by design). Rejected on the unified-surface argument: the Studio is one operator and a single Grafana frontend across three signal types reduces context-switching cost more than Honeycomb's superior trace UX adds.

### Azure Monitor (Application Insights + Log Analytics)

Considered. Closest to the Grid's existing Azure footprint; minimal new-vendor onboarding. Rejected on cost trajectory: at Grid scale (especially with AI-sector trace volume), Azure Monitor's per-GB ingestion pricing crosses Grafana Cloud's pricing at modest volumes. Also weaker OTLP ergonomics historically; Microsoft has been closing the gap but not enough to overturn the unified-vendor argument.

### Self-hosted Tempo + Mimir + Loki

Rejected. The Studio is one operator; running a telemetry stack is a part-time job. Self-hosting cost (operator-time, not dollars) exceeds the SaaS subscription several times over.

### Datadog

Considered. Best-in-class UX, broadest integration surface. Rejected on cost — Datadog's per-host pricing is the strongest argument against it for a multi-Node Grid with potentially many small Container Apps. Reconsidered if a paying customer specifically requires the Datadog integration surface.

### Tail-based sampling

Considered. Higher trace fidelity for retained samples; lower trace-volume bills. Rejected on operational complexity: tail-based requires a sampler in front of Grafana Cloud (additional component to operate). Head-based with smart rules (D4) is the practical compromise for a single-operator Grid.

### Skip the policy until the Notify Cloud GA milestone

Rejected. The AI-sector standup wave starts emitting trace volume well before GA. Standup canaries require a working sink. Defer-and-suffer-canary-failures is the worse option.
