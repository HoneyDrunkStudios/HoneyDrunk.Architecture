# ADR-0045: Grid-Wide Error Tracking

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

## Context

ADR-0040 (Proposed) selects Azure Monitor + Application Insights as the unified backend for **traces, metrics, and logs**, with `HoneyDrunk.Observe` as the OTLP-only boundary. That decision scopes itself to those three signal types; this ADR addresses **errors** as a distinct signal with first-class error-tracking semantics.

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

This ADR decides errors as a fourth Grid signal type, the v1 backend (**Application Insights' Failures + exception tracking**), the **Observe-mediated** integration pattern (preserving ADR-0010's provider-slot reversibility), the cross-link semantics, the per-Node opt-in mechanics, and the explicit **escalation path to Sentry** if v1 doesn't earn its keep.

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

### D3 — Errors flow through Observe via `IErrorReporter`

The principle from ADR-0010 (Observe is the provider-slot connector layer) and ADR-0040 D2 (Observe is the OTLP-only boundary) extends to errors with a small carve-out: **errors flow through Observe**, but the App Insights connector for errors uses the **App Insights .NET SDK** wrapped behind an `IErrorReporter` interface in `HoneyDrunk.Observe.Abstractions`, not raw OTLP.

The carve-out exists because App Insights' error model carries fields that are not OTLP primitives — `problem_id`, `application_Version`, custom dimensions for user/tenant scoping that participate in the Failures-blade grouping. Routing errors as OTLP-generic would strip those features. Better to use the SDK behind an abstraction so the abstraction can survive a future backend swap (Sentry per D11, GlitchTip, Bugsnag, etc.).

The `IErrorReporter` shape (added to `HoneyDrunk.Observe.Abstractions`):

```
ValueTask CaptureException(Exception ex, ErrorContext? context = null);
ValueTask CaptureMessage(string message, ErrorLevel level, ErrorContext? context = null);
IDisposable AddBreadcrumb(Breadcrumb crumb);
IDisposable PushScope(ErrorScope scope);
```

`ErrorContext` carries `trace_id` (linking automatically to App Insights traces), `tenant_id` (linking to ADR-0026's primitives), `user_id`, `release` (= application version), and arbitrary tag dictionary. `Breadcrumb` and `ErrorScope` are modeled on Sentry's semantics — they're backend-portable concepts that App Insights can express via custom events on the same `operation_id`, and that Sentry would consume natively if D11 ever fires.

The v1 default backing is `HoneyDrunk.Observe.AzureMonitor` (the same backing per ADR-0040 — errors share the App Insights resource with traces/metrics/logs). A Sentry backing (`HoneyDrunk.Observe.Sentry`) is sketched as the D11 escalation path; not implemented at v1.

### D4 — Cross-link is native via `operation_id`

App Insights' Failures blade and Transactions blade share the same `operation_id` (≈ `trace_id`). The cross-signal navigation is built-in:

- **From Failures (errors) to Trace:** Click an error → "View all telemetry" → land on the end-to-end transaction view with the failed span highlighted.
- **From Trace to Failures:** A failed span in the transaction view links directly to the associated exception's problem group.
- **From either to Logs:** Same `operation_id` filters the Log Analytics workspace to surrounding log lines.

This is the **load-bearing piece** for the unified-view claim. ADR-0040 D4 (cross-link configuration) becomes redundant on the App Insights path — no Sentry-trace-tool-URL-template, no Grafana-Tempo-Sentry-integration to configure. The navigation works because everything shares storage.

If D11 ever fires (move to Sentry), cross-linking re-emerges as a configured integration via `trace_id` — same shape as the original draft of this ADR contemplated. The configuration cost is the trade-off accepted at escalation.

### D5 — Per-Node opt-in via Observe configuration

Each Node enables error capture by configuring its consumption of `IErrorReporter` (which is part of the standard Observe registration). All Nodes consuming Observe get error reporting automatically once the Observe backing is wired; opt-out is per Node via the Observe configuration if a Node has reason to suppress errors (rare; e.g., `HoneyDrunk.Architecture` itself, which does not run user-facing code).

`HoneyDrunk.Notify`'s existing Sentry configuration is **migrated** into this pattern. Notify drops its direct `SentrySdk.Init(dsn)` call; depends on `HoneyDrunk.Observe` (already does, via the broader Observe relationship); replaces every `SentrySdk.CaptureException(...)` call with `_errorReporter.CaptureException(...)`. Errors flow to App Insights instead of Sentry. The Notify-specific Sentry account is archived after a parallel-run window.

This is the explicit reversal of the first draft of this ADR, which proposed adopting Sentry Grid-wide. The current decision adopts App Insights Grid-wide; Notify's existing Sentry usage is **removed**, not extended.

### D6 — Release tracking via `application_Version`

App Insights' release-tracking feature uses the `application_Version` property on captured telemetry. Wiring to the Grid's release flows:

- **Container Apps deployable Nodes** (Notify.Functions, Notify.Worker, Pulse.Collector, future Notify Cloud) — the `HoneyDrunk.Actions` reusable deploy workflows (per ADR-0015) are amended to set `application_Version` to the deployable's SemVer tag (per ADR-0033's tag→environment mapping) via the App Insights resource's release annotations API. Captured exceptions automatically carry this version.
- **Library / Abstractions packages** — not deployable, do not set a version. Errors caught in code consuming a library record the consuming application's version, not the library's package version.
- **Release annotations** — App Insights' release annotations API (`https://aigs1.aisvc.visualstudio.com/applicationinsights/release/v2.0/api`) is called from the deploy workflow with the new version. The Failures blade surfaces these as annotations on the trend graph, making "this error first appeared in v0.4.2" visible.

The workflow quality is **lower than Sentry's** release surface (Sentry has a richer Issues/Releases UX with regression detection, suspect commits, suspect releases). Acceptable for v1 Grid volume; named as one of the D11 escalation triggers if error-triage volume grows.

### D7 — PII, tenant scoping, and sensitive-content carve-outs

Errors can leak PII, tenant data, and model content. The mechanism is `ITelemetryProcessor` (the App Insights-native filter pipeline — same mechanism as ADR-0040 D9 uses for traces/logs PII filtering):

- **`tenant_id` is allowed** as a custom dimension on exceptions; low cardinality bounded by tenant count. Load-bearing for multi-tenant triage. Not considered PII.
- **`user_id` is allowed but pseudonymous** — the Grid's internal opaque `PrincipalId` per ADR-0026, never an email or external identifier.
- **Prompt/completion text from AI Nodes** follows ADR-0040 D9: **forbidden by default**, allowed only behind the `evals.sensitive=true` carve-out. Exceptions thrown from agent execution paths must scrub the prompt/completion content before capture; the breadcrumb (capability invoked, model, cost) is allowed.
- **Common PII patterns** (emails, phone numbers, credit card patterns, API keys, JWT shapes) are stripped from exception messages and custom dimensions by a regex-based processor in `HoneyDrunk.Observe.AzureMonitor`.
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

- **Phase 1 (Week 1–2) — `IErrorReporter` abstraction + Notify migration.** Add `IErrorReporter` and related types to `HoneyDrunk.Observe.Abstractions`. Implement the App Insights backing in `HoneyDrunk.Observe.AzureMonitor`. Migrate `HoneyDrunk.Notify` from direct Sentry SDK to `IErrorReporter`; run in parallel-output mode for one week (errors go to both Sentry and App Insights for parity verification); cut over; archive the Notify-Sentry account.
- **Phase 2 (Week 3–6) — Rollout to deployable Nodes.** Notify.Functions, Notify.Worker, Pulse.Collector wire `IErrorReporter` via their existing Observe dependency. Release tracking (D6) lands in the deploy workflows.
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

The escalation preserves the substrate: `IErrorReporter` abstraction stays, `HoneyDrunk.Observe.Sentry` backing comes online, the Observe-level configuration swap moves errors to Sentry while traces/metrics/logs stay on App Insights. The result is the two-backend posture the first draft of this ADR committed to, **arrived at with evidence rather than speculation.**

Combined cost at escalation: App Insights (~$30–100/month for traces/metrics/logs) + Sentry (free or Team $26/month) = within ADR-0040's $100/month ceiling at low volume, growing to ~$150/month at meaningful Notify Cloud volume.

### D12 — Pulse is not an error source

Per ADR-0028, Pulse signals are explicitly **not** domain events. They are not errors either. Pulse's job is health/synthetic monitoring; a Pulse signal "the API returned 500 on a synthetic probe" produces a **metric** (App Insights) and a **log** (Log Analytics), not an exception. Errors come from application code paths catching exceptions, not from synthetic monitoring.

Recorded explicitly so the boundary doesn't blur: Pulse → metrics/logs; application code → exceptions (+ metrics + logs). The operator's mental model of "where do I look for X" is preserved.

### D13 — Relationship to ADR-0010, ADR-0040, and the existing Notify-Sentry setup

- **ADR-0010** — preserved. `HoneyDrunk.Observe` is the provider-slot connector layer. This ADR adds `IErrorReporter` to its abstractions surface alongside the existing OTLP-shaped surfaces.
- **ADR-0040** — extended. ADR-0040 covers traces/metrics/logs in App Insights; this ADR covers errors in the same App Insights resource. The two are complementary; ADR-0040's "unified view" claim is completed by D4's native cross-link.
- **Existing Notify-Sentry setup** — **removed, not extended.** The first draft of this ADR proposed adopting Sentry Grid-wide; this revised decision instead migrates Notify off Sentry onto App Insights. The Notify-Sentry account is archived after the parallel-run window (D5/Phase 1). Sentry returns only if D11 fires.

## Consequences

### Affected Nodes

- **HoneyDrunk.Observe** — primary affected Node. `HoneyDrunk.Observe.Abstractions` gains `IErrorReporter`, `ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel`. `HoneyDrunk.Observe.AzureMonitor` (the ADR-0040 backing) extends to handle error capture via the App Insights SDK.
- **HoneyDrunk.Notify** — direct-Sentry usage migrates to `IErrorReporter`; Notify-Sentry account archived after parallel-run cutover.
- **HoneyDrunk.Notify.Functions, HoneyDrunk.Notify.Worker, HoneyDrunk.Pulse.Collector** — consume `IErrorReporter` via their existing Observe dependency in Phase 2.
- **HoneyDrunk.Actions** — reusable deploy workflows amended to call the App Insights release annotations API as a post-deploy step (D6).
- **HoneyDrunk.Vault** — App Insights instrumentation keys (from ADR-0040) are reused; no new secrets for the error path in v1. If D11 fires, Sentry DSNs join Vault.
- **HoneyDrunk.Architecture** — `catalogs/contracts.json` gains `IErrorReporter` under the Observe Node's published contracts.
- **AI-sector Seed Nodes (ADR-0016 through ADR-0025)** — each consumes `IErrorReporter` at standup; error capture is part of the standup canary.
- **HoneyDrunk.Audit** — emits errors with `sensitive=audit` tag and longer-retention requirements per ADR-0040 D3.
- **HoneyDrunk.Notify.Cloud** (future, ADR-0027) — multi-tenant error capture with `tenant_id` dimensions from day one.

### Invariants

Adds one:

- **Invariant: errors captured for Sentry-eligible cases (D8) flow through `IErrorReporter`, never via direct backend SDK calls.** This preserves backend reversibility (D11 escalation) and the centralized PII-scrubbing surface.

(Final invariant number assigned when the implementing work updates `constitution/invariants.md`; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **No new vendor relationship at v1.** Errors share the App Insights resource that ADR-0040 already provisioned. No new account ownership, no new billing line.
- **The Notify-Sentry migration is the highest-friction step.** Phase 1 includes a parallel-output window where errors go to both Sentry and App Insights for verification; cut over after parity is confirmed; archive the Sentry account. ~1 week of operator attention.
- **App Insights' Failures-blade workflow is the v1 acceptance.** It is real but rougher than Sentry. The escalation triggers (D11) name the conditions under which it stops being acceptable.
- **Release tracking quality is "good enough" not "best."** Sentry's Releases UX with regression detection and suspect commits is recognized as superior; D11 names that as one of the escalation triggers.
- **PII-scrubbing rules apply equally** to errors as to traces/logs; the same `ITelemetryProcessor` mechanism (ADR-0040 D9) handles both. Reduces the surface area where a misconfigured scrubber could leak.
- **Cross-linking is free** in v1 (same `operation_id` everywhere). At escalation to Sentry, cross-linking re-emerges as a configured integration; the cost is the trade-off accepted by escalating.

### Follow-up Work

- Add `IErrorReporter`, `ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel` to `HoneyDrunk.Observe.Abstractions`.
- Extend `HoneyDrunk.Observe.AzureMonitor` with App-Insights-SDK-based error capture.
- Migrate Notify's direct-Sentry usage to `IErrorReporter`; parallel-output window; cutover; archive Sentry account.
- Amend HoneyDrunk.Actions deploy workflows to call App Insights release annotations API.
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

### Direct backend SDK usage without an Observe abstraction

Rejected. The `IErrorReporter` abstraction costs little (≤200 lines of code in the Observe.AzureMonitor backing) and buys backend reversibility (D11 escalation), centralized PII scrubbing, consistent `trace_id`/`tenant_id` tagging, and uniform semantics. The direct-SDK pattern is what Notify has today, and the Phase 1 migration is the explicit cost of fixing that.

### Keep Notify on Sentry as a special case; adopt App Insights elsewhere

Rejected. The whole point of this ADR is making error tracking a Grid-wide governed concern. Leaving Notify as a special case continues the drift that prompted the ADR in the first place. Migrating Notify is real work but Phase 1 carries it explicitly with a parallel-run window to de-risk.

### Defer until first paying tenant exposes an error-triage workflow gap

Rejected. The AI-sector standup wave starts emitting error volume well before any paying tenant. Standup canaries require a working error-capture path. Defer-and-discover is the worse option.
