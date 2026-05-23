# ADR-0045: Grid-Wide Error Tracking

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

> **Amendment — 2026-05-22.** The original draft placed the error-reporting abstraction and the App Insights error backing in `HoneyDrunk.Observe`. That assignment was a boundary error: `repos/HoneyDrunk.Observe/boundaries.md` explicitly states outbound telemetry to external sinks belongs to **`HoneyDrunk.Pulse`** — Observe is the *inbound* external-system observation layer. `HoneyDrunk.Pulse` is the LIVE (v0.3.0) telemetry-export Node and already owns `ITraceSink`/`ILogSink`/`IMetricsSink`/`IAnalyticsSink`/**`IErrorSink`** plus the `HoneyDrunk.Telemetry.Sink.*` provider family (including `HoneyDrunk.Telemetry.Sink.AzureMonitor` and `HoneyDrunk.Telemetry.Sink.Sentry`). This ADR is corrected throughout to target **Pulse** for the error path, matching the same correction already applied to the companion ADR-0040. The error-reporting facade lives in `HoneyDrunk.Telemetry.Abstractions`; the App Insights error backing **extends the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package** — it does not create a new package and does not live in Observe. See D3 for the `IErrorReporter`/`IErrorSink` reconciliation.

## Context

ADR-0040 (Proposed) selects Azure Monitor + Application Insights as the unified backend for **traces, metrics, and logs**, with `HoneyDrunk.Pulse` as the telemetry-export boundary. That decision scopes itself to those three signal types; this ADR addresses **errors** as a distinct signal with first-class error-tracking semantics.

Today the error story is uneven:

- **`HoneyDrunk.Notify`** has Sentry wired in as a one-off; it predates this ADR family and is not governed by any decision. The Sentry account, the DSN configuration, and the release-tagging integration all exist for Notify alone.
- **No other Node** has error tracking. Errors surface only as `ERROR`-level log lines in App Insights' Log Analytics workspace (once ADR-0040 lands), or as exceptions in the local console during development.
- **Logs ≠ error tracking.** Logs-at-error-level capture *that* something failed; error tracking captures **the error as a structured event** — stack trace, release version, environment, fingerprint for "is this a new error or a recurrence." The two surfaces solve overlapping but materially different problems.
- **Cross-linking is currently absent.** Notify's Sentry errors have no link to the corresponding App Insights trace; an App Insights trace showing a failed span has no link to a Sentry issue. The "unified view" claim in ADR-0040 is incomplete because Notify's errors live in a separate, unconnected surface.

The forcing functions for deciding this now:

- **ADR-0040 just landed** and claims unified observability across traces/metrics/logs. The error gap makes the claim partially false; closing it preserves the unified-view property.
- **The AI-sector standup wave** (ADR-0016 through ADR-0025) introduces nine Nodes whose primary failure modes — LLM call errors, tool dispatch failures, agent execution errors, retrieval failures, eval target errors — are exactly the kind of signal error-tracking surfaces excel at. Problem grouping (novel vs recurring) and release tracking matter most when error volume is high enough to need triage.
- **Notify Cloud GA** (PDR-0002 / ADR-0027) carries an implicit "we know when errors happen on tenant traffic" expectation.
- **The existing Notify-Sentry setup needs governance.** Without an ADR, the Notify configuration drifts: account ownership, DSN rotation, sample-rate decisions, PII scrubbing rules all live in unrecorded form.

This ADR decides errors as a fourth Grid signal type, the v1 backend (**Application Insights' Failures + exception tracking**), the **Pulse-mediated** integration pattern (preserving the sink-provider reversibility Pulse already implements), the cross-link semantics, the per-Node opt-in mechanics, and the explicit **escalation path to Sentry** if v1 doesn't earn its keep.

## Decision

### D1 — Errors are a fourth Grid signal type

Add **errors** to the canonical Grid signal taxonomy alongside traces, metrics, and logs from ADR-0040:

| Signal | Backend (v1) | Purpose | Retention |
|--------|--------------|---------|-----------|
| Traces | App Insights | Distributed request flow | 90 days |
| Metrics | Azure Monitor / App Insights | Aggregate operational state | 93 days |
| Logs | Log Analytics | Append-only event stream (Audit 730 days, standard 90) | 90/730 days |
| **Errors** | **App Insights Failures** | **Structured exceptions with problem grouping, release, user/tenant context** | **90 days (same workspace)** |

Errors are **not** logs. A log entry is an event in a stream; an error is a fingerprinted issue with a problem ID, stack trace, release-bound trend, and affected-request count. App Insights' Failures blade implements this model natively — `customEvents` and `exceptions` tables in the Log Analytics workspace carry the structured shape, and the Failures UI groups them by problem ID.

### D2 — Backend (v1): Application Insights' Failures + exception tracking

Errors capture into the **same Application Insights resource** that holds traces/metrics/logs per ADR-0040. No separate vendor, no separate billing line. The Failures blade is the operator's error-triage surface; problem groups (≈ Sentry's fingerprints) cluster recurring exceptions; release tagging via the `application_Version` property surfaces "this error first appeared in v0.4.2"; trend graphs show occurrence frequency over time.

App Insights' Failures is acknowledged as **"Sentry-lite"** — the model and workflow are real, but lower polish than Sentry's dedicated error-tracking surface. The trade-off is recorded in D11; the v1 commitment is to App Insights, with Sentry as the documented escalation path when (and if) volume warrants the polish.

The architectural property that matters is preserved: **one backend, one unified-view surface, native cross-signal navigation** (D4). The error workflow is good enough for v1 Grid volume; the abstraction (D3) makes future migration cheap.

### D3 — Errors flow through Pulse; `IErrorReporter` is a thin facade over the existing `IErrorSink`

Errors flow through **`HoneyDrunk.Pulse`** — the Grid's telemetry-export Node — exactly as traces/metrics/logs do per ADR-0040. The App Insights connector for errors uses the **App Insights .NET SDK** (not raw OTLP) because App Insights' error model carries fields that are not OTLP primitives — `problem_id`, `application_Version`, custom dimensions for user/tenant scoping that participate in the Failures-blade grouping. The SDK is wrapped behind a sink so the substrate can survive a future backend swap (Sentry per D11, GlitchTip, Bugsnag, etc.).

**Reconciliation with Pulse's existing `IErrorSink`.** `HoneyDrunk.Pulse` (v0.3.0, LIVE) **already ships `IErrorSink`** in `HoneyDrunk.Telemetry.Abstractions` — a structured error-capture contract (`CaptureAsync(ErrorEvent)`, `CaptureExceptionAsync`, `CaptureMessageAsync`, `FlushAsync`) with an `ErrorEvent` model carrying exception, message, severity, `CorrelationId`/`OperationId`, `NodeId`, `UserId`, `Environment`, `Release`, and a tag/extra dictionary. The error *capture and fan-out* contract therefore **already exists** — this ADR does **not** create a parallel one.

`IErrorReporter` is kept as a **thin, Grid-facing convenience facade layered over `IErrorSink`** — it is explicitly **not** a duplicate of `IErrorSink`. The division of labour:

- **`IErrorSink`** (existing, unchanged) — the sink/fan-out contract. One of five Pulse sinks the Collector fans telemetry out to. It takes a fully-populated `ErrorEvent` and routes it to a backend. It has no notion of ambient request context, no breadcrumb/scope stack — those are caller-side concerns.
- **`IErrorReporter`** (new, the facade) — the application-facing ergonomic contract a Node consumes. It captures ambient context (the current `Activity`/`trace_id`, the Grid `TenantId`/`PrincipalId`, the deployable `Release`), maintains the breadcrumb/scope stack, builds an `ErrorEvent` from that context, and hands it to `IErrorSink`. It adds no new capture mechanism — it adds ambient-context capture and Sentry-style breadcrumb/scope ergonomics on top of the existing sink.

The `IErrorReporter` facade shape (added to `HoneyDrunk.Telemetry.Abstractions`, alongside `IErrorSink`):

```
ValueTask CaptureException(Exception ex, ErrorContext? context = null);
ValueTask CaptureMessage(string message, ErrorLevel level, ErrorContext? context = null);
IDisposable AddBreadcrumb(Breadcrumb crumb);
IDisposable PushScope(ErrorScope scope);
```

`ErrorContext` carries `trace_id` (linking automatically to App Insights traces), `tenant_id` (linking to ADR-0026's primitives — the dimension `IErrorSink`'s `ErrorEvent` does **not** carry, and the load-bearing reason the facade exists), `user_id`, `release` (= application version), and an arbitrary tag dictionary. The facade maps `ErrorContext` onto `ErrorEvent` fields (`OperationId`/`CorrelationId` ← `trace_id`; `UserId`; `Release`; tenant id and breadcrumbs ride on `ErrorEvent.Tags`/`ErrorEvent.Extra`). `Breadcrumb` and `ErrorScope` are modeled on Sentry's semantics — backend-portable concepts that App Insights expresses via custom events on the same `operation_id` and that Sentry consumes natively if D11 fires.

The v1 default error backing **extends the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package** — the same Pulse sink that ADR-0040 uses for traces/metrics/logs. Errors share the App Insights resource. **No new package is created.** A Sentry error backing already exists as `HoneyDrunk.Telemetry.Sink.Sentry`; it is the D11 escalation path — present in the repo, not the v1 default.

### D4 — Cross-link is native via `operation_id`

App Insights' Failures blade and Transactions blade share the same `operation_id` (≈ `trace_id`). The cross-signal navigation is built-in:

- **From Failures (errors) to Trace:** Click an error → "View all telemetry" → land on the end-to-end transaction view with the failed span highlighted.
- **From Trace to Failures:** A failed span in the transaction view links directly to the associated exception's problem group.
- **From either to Logs:** Same `operation_id` filters the Log Analytics workspace to surrounding log lines.

This is the **load-bearing piece** for the unified-view claim. ADR-0040 D4 (cross-link configuration) becomes redundant on the App Insights path — no Sentry-trace-tool-URL-template, no Grafana-Tempo-Sentry-integration to configure. The navigation works because everything shares storage.

If D11 ever fires (move to Sentry), cross-linking re-emerges as a configured integration via `trace_id` — same shape as the original draft of this ADR contemplated. The configuration cost is the trade-off accepted at escalation.

### D5 — Per-Node opt-in via Pulse configuration

Each Node enables error capture by configuring its consumption of `IErrorReporter` (which is part of the standard Pulse telemetry registration). All Nodes consuming Pulse get error reporting automatically once the error sink backing is wired; opt-out is per Node via the Pulse configuration if a Node has reason to suppress errors (rare; e.g., `HoneyDrunk.Architecture` itself, which does not run user-facing code).

`HoneyDrunk.Notify`'s existing Sentry configuration is **migrated** into this pattern. A source scan found **no Sentry SDK code in Notify** — only account/DSN configuration. So the migration is config-only: Notify audits its D8 error-capture sites, wires them to `IErrorReporter` via its Pulse telemetry dependency, and the Notify-specific Sentry account is archived. Errors flow to App Insights instead of Sentry. Because nothing in Notify emits to Sentry from code, there is **no parallel-output window** — the cutover is the moment `IErrorReporter` is wired. (If an execution-time scan unexpectedly finds SDK code, the SDK-replacement path with a parallel-run window is the fallback.)

This is the explicit reversal of the first draft of this ADR, which proposed adopting Sentry Grid-wide. The current decision adopts App Insights Grid-wide; Notify's existing Sentry usage is **removed**, not extended.

### D6 — Release tracking via `application_Version`

App Insights' release-tracking feature uses the `application_Version` property on captured telemetry. Wiring to the Grid's release flows:

- **Container Apps deployable Nodes** (Notify.Functions, Notify.Worker, Pulse.Collector, future Notify Cloud) — the `HoneyDrunk.Actions` reusable deploy workflows (per ADR-0015) are amended to set `application_Version` to the deployable's SemVer tag (per ADR-0033's tag→environment mapping) and to mark the deploy via the current supported release-annotation mechanism. Captured exceptions automatically carry this version.
- **Library / Abstractions packages** — not deployable, do not set a version. Errors caught in code consuming a library record the consuming application's version, not the library's package version.
- **Release annotations** — the deploy workflow marks the deploy moment on the App Insights Failures trend graph using the **current supported release-annotation mechanism** (`az monitor app-insights` / ARM). The legacy `aisvc.visualstudio.com` annotations endpoint is a fallback only if no supported equivalent applies. The Failures blade surfaces these annotations, making "this error first appeared in v0.4.2" visible.

The workflow quality is **lower than Sentry's** release surface (Sentry has a richer Issues/Releases UX with regression detection, suspect commits, suspect releases). Acceptable for v1 Grid volume; named as one of the D11 escalation triggers if error-triage volume grows.

### D7 — PII, tenant scoping, and sensitive-content carve-outs

Errors can leak PII, tenant data, and model content. The mechanism is `ITelemetryProcessor` (the App Insights-native filter pipeline — same mechanism as ADR-0040 D9 uses for traces/logs PII filtering):

- **`tenant_id` is allowed** as a custom dimension on exceptions; low cardinality bounded by tenant count. Load-bearing for multi-tenant triage. Not considered PII.
- **`user_id` is allowed but pseudonymous** — the Grid's internal opaque `PrincipalId` per ADR-0026, never an email or external identifier.
- **Prompt/completion text from AI Nodes** follows ADR-0040 D9: **forbidden by default**, allowed only behind the `evals.sensitive=true` carve-out. Exceptions thrown from agent execution paths must scrub the prompt/completion content before capture; the breadcrumb (capability invoked, model, cost) is allowed.
- **Common PII patterns** (emails, phone numbers, credit card patterns, API keys, JWT shapes) are stripped from exception messages and custom dimensions by the shared, mechanism-agnostic PII scrubber that ADR-0040 builds as a shared component; the error path in `HoneyDrunk.Telemetry.Sink.AzureMonitor` consumes that shared scrubber rather than re-implementing the regex set.
- **`HoneyDrunk.Audit`-emitted errors** are PII-bearing by design (recipient address on a notification failure, for instance). These flow to the dedicated Audit-tagged Log Analytics table with `sensitive=audit` and 730-day retention per ADR-0040 D3.

### D8 — When to capture an error vs. log a line

The boundary between "Sentry-style error capture" and "log a line at ERROR level" is the same regardless of backend; the policy applies to App Insights v1 just as it would to Sentry under D11:

- **Capture as an error:**
  - Uncaught or programmatic exceptions in business logic.
  - Failed dependency calls (LLM provider 5xx, downstream Node call failures) that the caller cannot recover from in-line.
  - Failed agent tool dispatch with no retry path remaining.
  - Failed billing meter-event push to Stripe after retries (per ADR-0037).
  - Audit write failures (per ADR-0030; these are also incidents).
- **Log to Log Analytics at ERROR level only (do not capture as error):**
  - Recoverable errors that retries handled successfully.
  - Validation failures of inbound requests (the caller's problem).
  - Expected 4xx outcomes from external APIs.
  - Deserialization failures on poison messages (already a dead-letter-queue concern per ADR-0028; capture the DLQ event, not the deserialization).
- **Both** (capture as error **and** log ERROR line):
  - Anything in the "Capture as an error" list also produces an ERROR log line. The log is for forensic timeline; the error capture is for triage and trend. Both records carry the same `operation_id` so they cross-reference.

The detailed checklist per Node lives in `.claude/agents/review.md` per ADR-0044 D3's Observability category. This ADR binds the principle; the agent file binds the per-case mapping.

### D9 — Cost model

App Insights billing is by data volume, not by separate "errors" SKU. Exception telemetry is part of the same workspace ingestion that ADR-0040 D10 already accounts for.

Realistic v1 cost contribution of errors specifically: **near-zero** at current Grid volume (single-digit errors/day across all Nodes). The combined observability budget (traces + metrics + logs + errors) sits under ADR-0040's $100/month ceiling.

Free Sentry-tier (5K errors/month, 1 user, 30-day retention) is what the Notify-Sentry one-off uses today — that account is **archived after migration** (D5), not retained as a parallel system. No double-spend.

### D10 — Phased rollout

- **Phase 1 (Week 1–2) — `IErrorReporter` facade + Notify migration.** Add the `IErrorReporter` facade and related types to `HoneyDrunk.Telemetry.Abstractions` (alongside the existing `IErrorSink`). Extend the App Insights error backing in `HoneyDrunk.Telemetry.Sink.AzureMonitor`. Migrate `HoneyDrunk.Notify` onto `IErrorReporter` — config-only (Notify has no Sentry SDK code); wire the D8 capture sites and archive the Notify-Sentry account. No parallel-output window is needed because nothing in Notify emits to Sentry from code.
- **Phase 2 (Week 3–6) — Rollout to deployable Nodes.** Notify.Functions, Notify.Worker, Pulse.Collector wire `IErrorReporter` via their existing Pulse telemetry dependency. Release tracking (D6) lands in the deploy workflows.
- **Phase 3 (Month 2–3) — AI-sector standup wave consumes the pattern.** Every Seed-sector AI Node, on standup, wires `IErrorReporter` from day one. The agent execution loop's breadcrumb usage (tool dispatched, model invoked, cost incurred) is the high-value error-tracking surface area for AI Nodes.
- **Phase 4 (Month 3+) — Escalation evaluation.** Review observed error volume, triage workflow pain points, and Notify Cloud GA error surfaces. Decide whether any D11 trigger has fired. If yes, the relevant escalation amendment lands. If no, hold on App Insights.

Each phase is a discrete go/no-go.

### D11 — Escalation path: Sentry

Application Insights' Failures + exception tracking is the v1 default chosen for cost and existing-relationship consolidation. It is **not** the best-in-class option. The Grid commits to the following **documented escalation triggers** — if any fires, the next ADR amendment moves errors to **Sentry** as a dedicated error-tracking backend.

| Trigger | Symptom | Action |
|---|---|---|
| Error-triage workflow pain | Operator finds App Insights' Failures blade insufficient for the volume of errors needing triage (estimated threshold: > 50 distinct problem IDs in any 7-day window). | Move errors to Sentry; configure `trace_id` cross-link to App Insights traces. |
| Release-triage workflow pain | Need to identify "this regressed in v0.4.2" workflow is happening regularly and App Insights' release-annotation UX is the bottleneck. | Move errors to Sentry; use Sentry's Releases/Suspect-Commits surface. |
| Tenant-scoped error views needed (Notify Cloud) | Multi-tenant error triage at scale needs Sentry's tag-and-environment filtering polish. | Move errors to Sentry; preserve tenant-scoped App Insights traces for context. |
| AI-sector tool-call breadcrumb depth | Agent-execution failures need the rich breadcrumb chain Sentry handles natively but App Insights expresses awkwardly via custom events. | Move errors to Sentry; preserve App Insights for traces/metrics/logs of the same execution. |

The escalation preserves the substrate: the `IErrorReporter` facade and `IErrorSink` contract stay, the existing `HoneyDrunk.Telemetry.Sink.Sentry` backing is activated as the error sink, the Pulse-level configuration swap moves errors to Sentry while traces/metrics/logs stay on App Insights. The result is the two-backend posture the first draft of this ADR committed to, **arrived at with evidence rather than speculation.**

Combined cost at escalation: App Insights (~$30–100/month for traces/metrics/logs) + Sentry (free or Team $26/month) = within ADR-0040's $100/month ceiling at low volume, growing to ~$150/month at meaningful Notify Cloud volume.

### D12 — Pulse is not an error source

Per ADR-0028, Pulse signals are explicitly **not** domain events. They are not errors either. Pulse's job is health/synthetic monitoring; a Pulse signal "the API returned 500 on a synthetic probe" produces a **metric** (App Insights) and a **log** (Log Analytics), not an exception. Errors come from application code paths catching exceptions, not from synthetic monitoring.

Recorded explicitly so the boundary doesn't blur: Pulse → metrics/logs; application code → exceptions (+ metrics + logs). The operator's mental model of "where do I look for X" is preserved.

### D13 — Relationship to ADR-0010, ADR-0040, and the existing Notify-Sentry setup

- **ADR-0010** — preserved. `HoneyDrunk.Observe` remains the inbound external-system observation layer; this ADR does **not** touch Observe. Outbound error telemetry is a Pulse concern per Observe's and Pulse's boundary docs.
- **ADR-0040** — extended. ADR-0040 covers traces/metrics/logs through Pulse into App Insights; this ADR covers errors through the same Pulse sink family into the same App Insights resource. The two are complementary; ADR-0040's "unified view" claim is completed by D4's native cross-link. ADR-0040 was likewise corrected to target Pulse — this ADR's correction is the matching companion change.
- **Existing Notify-Sentry setup** — **removed, not extended.** The first draft of this ADR proposed adopting Sentry Grid-wide; this revised decision instead migrates Notify off Sentry onto App Insights. The Notify-Sentry account is archived once `IErrorReporter` is wired (D5/Phase 1) — config-only, no parallel-run window, since Notify has no Sentry SDK code. Sentry returns only if D11 fires, via the existing `HoneyDrunk.Telemetry.Sink.Sentry` package.

## Consequences

### Affected Nodes

- **HoneyDrunk.Pulse** — primary affected Node. `HoneyDrunk.Telemetry.Abstractions` gains the `IErrorReporter` facade plus `ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel` — layered over the existing `IErrorSink`/`ErrorEvent`, not duplicating them. `HoneyDrunk.Telemetry.Sink.AzureMonitor` (the existing ADR-0040 sink) extends to handle error capture via the App Insights SDK. No new package.
- **HoneyDrunk.Notify** — Sentry config (no SDK code) migrates to `IErrorReporter`; Notify-Sentry account archived once wired.
- **HoneyDrunk.Notify.Functions, HoneyDrunk.Notify.Worker, HoneyDrunk.Pulse.Collector** — consume `IErrorReporter` via their existing Pulse telemetry dependency in Phase 2.
- **HoneyDrunk.Actions** — reusable deploy workflows amended to mark the deploy via the current supported App Insights release-annotation mechanism as a post-deploy step (D6).
- **HoneyDrunk.Vault** — App Insights connection string (from ADR-0040) is reused; no new secrets for the error path in v1. If D11 fires, Sentry DSNs join Vault.
- **HoneyDrunk.Architecture** — `catalogs/contracts.json` gains the `IErrorReporter` facade under the Pulse Node's published contracts.
- **AI-sector Seed Nodes (ADR-0016 through ADR-0025)** — each consumes `IErrorReporter` at standup; error capture is part of the standup canary.
- **HoneyDrunk.Audit** — emits errors with `sensitive=audit` tag and longer-retention requirements per ADR-0040 D3.
- **HoneyDrunk.Notify.Cloud** (future, ADR-0027) — multi-tenant error capture with `tenant_id` dimensions from day one.

### Invariants

Adds one:

- **Invariant: errors captured for the capture-eligible cases (D8) flow through `IErrorReporter`, never via a direct backend SDK call.** This preserves backend reversibility (D11 escalation) and the centralized PII-scrubbing surface. Secret values must never survive scrubbing into a captured exception — this invariant references, rather than restates, invariant 8 (secret values never appear in logs, traces, exceptions, or telemetry).

The reserved number for this invariant is **80** — pre-allocated as part of a 12-ADR batch. The implementing packet (packet 00) appends it to `constitution/invariants.md`; if any invariant above the file's verified current maximum (51) lands from outside this batch before merge, shift this one upward, never reuse a number.

### Operational Consequences

- **No new vendor relationship at v1.** Errors share the App Insights resource that ADR-0040 already provisioned. No new account ownership, no new billing line.
- **The Notify-Sentry migration is config-only.** A source scan found no Sentry SDK code in Notify — only account/DSN configuration. Phase 1 wires Notify's D8 capture sites to `IErrorReporter` and archives the Sentry account; there is no parallel-output window because nothing emits to Sentry from code. Low-friction; the SDK-replacement path with a parallel window is the fallback only if an execution-time scan unexpectedly finds SDK code.
- **App Insights' Failures-blade workflow is the v1 acceptance.** It is real but rougher than Sentry. The escalation triggers (D11) name the conditions under which it stops being acceptable.
- **Release tracking quality is "good enough" not "best."** Sentry's Releases UX with regression detection and suspect commits is recognized as superior; D11 names that as one of the escalation triggers.
- **PII-scrubbing rules apply equally** to errors as to traces/logs; the same `ITelemetryProcessor` mechanism (ADR-0040 D9) handles both. Reduces the surface area where a misconfigured scrubber could leak.
- **Cross-linking is free** in v1 (same `operation_id` everywhere). At escalation to Sentry, cross-linking re-emerges as a configured integration; the cost is the trade-off accepted by escalating.

### Follow-up Work

- Add the `IErrorReporter` facade, `ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel` to `HoneyDrunk.Telemetry.Abstractions`, layered over the existing `IErrorSink`.
- Extend `HoneyDrunk.Telemetry.Sink.AzureMonitor` with App-Insights-SDK-based error capture.
- Migrate Notify's Sentry config to `IErrorReporter` (config-only — no SDK code, no parallel-output window); archive the Sentry account.
- Amend HoneyDrunk.Actions deploy workflows to mark the deploy via the current supported App Insights release-annotation mechanism.
- Implement the PII-scrubbing canary for the error path (similar to ADR-0040 D9 canary for traces/logs).
- Wire `IErrorReporter` into each AI-sector standup ADR (0016–0025) as the standup canary surface.
- Update `.claude/agents/review.md` D3 Observability category with the D8 capture-vs-log mapping.
- Document the D11 escalation triggers in `business/context/` so the operator can recognize them.

## Alternatives Considered

### Adopt Sentry Grid-wide (the original v1 choice, now the D11 escalation path)

Considered as v1 default in the first draft of this ADR. Strong product: best-in-class fingerprinting, release workflow with suspect commits, breadcrumb depth, session tracking. **Rejected as v1** on three grounds:

- **Cost vs already-paid Azure relationship.** App Insights is part of the Azure footprint we already pay for. Sentry is a new vendor and billing line, even on the Team tier ($26/month).
- **Native cross-link.** App Insights delivers cross-signal navigation (errors → traces → logs → metrics) natively via `operation_id`. Sentry + App Insights would require configured cross-links.
- **Speculative escalation.** The first draft committed to Sentry's premium features before observing whether App Insights' Failures-blade actually fails the operator's needs. At single-digit-errors-per-day v1 volume, premium features sit unused.

Documented as the D11 escalation path with explicit triggers. Picked when real evidence shows App Insights' workflow is the bottleneck, not before.

### Use Log Analytics ERROR-level logs only (no error tracking)

Considered. Cheapest option. Rejected because logs don't deliver problem grouping, release-tagging, or trend graphs. The Failures blade gives the operator a recognizable error-tracking workflow at the same volume cost as the logs they already pay for. Worth the small SDK-integration effort.

### Adopt Datadog APM (includes error tracking)

Rejected at the ADR-0040 stage on cost (per-host pricing). Same argument applies here.

### Honeycomb errors

Considered. Strong on high-cardinality trace-driven error analysis. Rejected because Honeycomb was already declined at ADR-0040 for the trace/metrics/logs primary; adopting it just for errors would reintroduce the multi-vendor problem.

### Self-host GlitchTip (open-source Sentry-compatible)

Rejected on operational burden. Same conclusion as ADR-0040's self-hosting rejection.

### Direct backend SDK usage without a Pulse abstraction

Rejected. The `IErrorReporter` facade costs little (it builds an `ErrorEvent` and hands it to the existing `IErrorSink`) and buys backend reversibility (D11 escalation), centralized PII scrubbing, consistent `trace_id`/`tenant_id` tagging, and uniform semantics. The direct-SDK pattern is what Notify has today, and the Phase 1 migration is the explicit cost of fixing that.

### A parallel new error contract instead of reusing `IErrorSink`

Considered and rejected. `HoneyDrunk.Pulse` already ships `IErrorSink` and the `ErrorEvent` model for structured error capture and fan-out. Introducing a second, parallel error-capture contract would silently reinvent that surface and create two error models to keep in sync. `IErrorReporter` is instead a thin Grid-facing facade *over* `IErrorSink` — it adds ambient-context capture (`trace_id`, `tenant_id`, `release`) and Sentry-style breadcrumb/scope ergonomics, and maps onto the existing `ErrorEvent`. It does not duplicate the sink contract.

### Keep Notify on Sentry as a special case; adopt App Insights elsewhere

Rejected. The whole point of this ADR is making error tracking a Grid-wide governed concern. Leaving Notify as a special case continues the drift that prompted the ADR in the first place. Migrating Notify is real work but Phase 1 carries it explicitly with a parallel-run window to de-risk.

### Defer until first paying tenant exposes an error-triage workflow gap

Rejected. The AI-sector standup wave starts emitting error volume well before any paying tenant. Standup canaries require a working error-capture path. Defer-and-discover is the worse option.
