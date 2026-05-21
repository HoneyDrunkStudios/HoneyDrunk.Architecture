# ADR-0045: Grid-Wide Error Tracking with Sentry

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

## Context

ADR-0040 (Proposed) selects Grafana Cloud as the unified backend for **traces, metrics, and logs**, with `HoneyDrunk.Observe` as the OTLP-only boundary. That decision deliberately scopes itself to those three signal types; it does not address **errors** as a distinct signal.

Today the error story is uneven:

- **`HoneyDrunk.Notify`** has Sentry wired in as a one-off; it predates this ADR family and is not governed by any decision. The Sentry account, the DSN configuration, and the release-tagging integration all exist for Notify alone.
- **No other Node** has error tracking. Errors surface only as `ERROR`-level log lines in Grafana Cloud's Loki stream (once ADR-0040 lands), or as exceptions in the local console during development.
- **Loki ≠ Sentry.** Logs-at-error-level capture *that* something failed; Sentry captures **the error as a structured event** — stack trace, breadcrumbs leading up to it, user/tenant context, release version, environment, fingerprint for "is this a new error or a recurrence." The two surfaces solve overlapping but materially different problems.
- **Cross-linking is absent.** A Sentry error in Notify has no link to the corresponding Grafana trace; a Grafana trace showing a failed span has no link to a Sentry issue. The "unified view" claim in ADR-0040 is incomplete because errors live in a separate, unconnected surface.

The forcing functions for deciding this now:

- **ADR-0040 just landed** and claims unified observability across traces/metrics/logs. The error gap makes the claim partially false; closing it preserves the unified-view property the user explicitly asked for.
- **The AI-sector standup wave** (ADR-0016 through ADR-0025) introduces nine Nodes whose primary failure modes — LLM call errors, tool dispatch failures, agent execution errors, retrieval failures, eval target errors — are exactly the kind of signal Sentry excels at. Fingerprinting (novel vs recurring), release tracking (was this introduced in version X?), and breadcrumbs (what tool was the agent calling when this happened?) are not effectively delivered by Loki alone.
- **Notify Cloud GA** (PDR-0002 / ADR-0027) carries an implicit "we know when errors happen on tenant traffic" expectation. A multi-tenant commercial product without unified error tracking is a regression on what the user reasonably expects.
- **The existing Notify-Sentry setup needs governance.** Without an ADR, the Notify configuration drifts: account ownership, DSN rotation, sample-rate decisions, PII scrubbing rules all live in unrecorded form.

This ADR decides errors as a fourth Grid signal type with **Sentry** as the backend, the **Observe-mediated** integration pattern (preserving ADR-0010's provider-slot reversibility), the **cross-link** to Grafana Cloud, and the per-Node opt-in mechanics.

## Decision

### D1 — Errors are a fourth Grid signal type

Add **errors** to the canonical Grid signal taxonomy. Per-signal characterization, complementing ADR-0040 D3:

| Signal | Backend | Purpose | Retention |
|--------|---------|---------|-----------|
| Traces | Grafana Cloud / Tempo | Distributed request flow | 14 days |
| Metrics | Grafana Cloud / Mimir | Aggregate operational state | 13 months |
| Logs | Grafana Cloud / Loki | Append-only event stream (Audit 400 days, standard 30) | 30/400 days |
| **Errors** | **Sentry** | **Structured exceptions with fingerprint, breadcrumbs, release, user/tenant context** | **90 days (Sentry default)** |

Errors are **not** logs. A log entry is an event in a stream; an error is a fingerprinted issue with state (new / regressed / resolved), assignment, and release-bound history. The two backends share OTLP-compatible context (`trace_id`, `tenant_id`) so the surfaces can cross-link, but the storage model and the UI affordances are different and warrant different tools.

### D2 — Sentry is the error-tracking backend

The Grid adopts **Sentry** as the error-tracking backend across all Nodes. Sentry sits in the same architectural position vis-à-vis errors as Grafana Cloud sits vis-à-vis traces/metrics/logs: a single managed vendor accessed via a single Sentry organization (`honeydrunkstudios`), with per-environment projects (`hd-dev`, `hd-staging`, `hd-prod`) and per-Node DSNs scoped within each project.

Rationale recorded in Alternatives Considered. The short version: Sentry's fingerprint + release tracking + breadcrumbs are best-in-class; pricing has a usable free tier; OpenTelemetry context propagation is supported; the SDK is mature for .NET; and the existing Notify usage means there's no net-new vendor relationship — this ADR is mostly making an existing relationship intentional and Grid-wide.

### D3 — Errors flow through Observe, not direct to Sentry

The principle from ADR-0010 (Observe is the provider-slot connector layer) and ADR-0040 D2 (Observe is the OTLP-only boundary) extends to errors with a small carve-out: **errors flow through Observe**, but the connector to Sentry is **not OTLP** — it is the Sentry .NET SDK wrapped behind an `IErrorReporter` interface in `HoneyDrunk.Observe.Abstractions`.

The carve-out exists because Sentry's value comes from features OTLP does not carry — breadcrumbs as a first-class concept, release/environment context with version-aware fingerprinting, user/tenant scoping that survives async context propagation, session tracking. Routing errors as OTLP would strip those features and reduce Sentry to a glorified log sink. Better to use the native SDK behind an abstraction.

The `IErrorReporter` shape (added to `HoneyDrunk.Observe.Abstractions`):

```
ValueTask CaptureException(Exception ex, ErrorContext? context = null);
ValueTask CaptureMessage(string message, ErrorLevel level, ErrorContext? context = null);
IDisposable AddBreadcrumb(Breadcrumb crumb);
IDisposable PushScope(ErrorScope scope);
```

`ErrorContext` carries `trace_id` (linking to Grafana Cloud), `tenant_id` (linking to ADR-0026's primitives), `user_id`, `release`, and arbitrary tag dictionary. `Breadcrumb` and `ErrorScope` are deliberately Sentry-shaped because that's the value being delivered; consumers wanting backend-portable error semantics use `CaptureException` / `CaptureMessage` only.

The default backing is `HoneyDrunk.Observe.Sentry`. The same pattern as ADR-0040 — backend swap is a single Observe-level configuration change, never a per-Node change.

### D4 — Cross-link Sentry ↔ Grafana Cloud via `trace_id`

Every error captured carries the active OpenTelemetry `trace_id` and `span_id` as Sentry tags (set automatically by the `IErrorReporter` default backing). This produces two-way navigation:

- **From Sentry to Grafana:** Sentry's "View in trace tool" link is configured (Sentry → Settings → Integrations → "Trace tool URL template") to deep-link into Grafana Cloud Tempo for the `trace_id`.
- **From Grafana to Sentry:** Grafana Cloud's Tempo→Sentry integration is enabled so a failed span surfaces its Sentry issue link in the trace view.

This is the load-bearing piece for the "unified view" claim. The operator's workflow is:

1. Alert fires (from Sentry on a new issue, or from Grafana Alertmanager on a metric threshold).
2. Land in the alerting surface's view of the event.
3. One click to cross-navigate to the corresponding trace/log/error in the other tool.

Without the cross-link, "unified observability" is two parallel tools the operator switches between manually. With it, the surfaces compose.

### D5 — Per-Node opt-in via Observe configuration

Each Node enables error tracking by configuring `HoneyDrunk.Observe.Sentry` with a Node-specific DSN. The DSN is stored in Vault per ADR-0005. Opt-in is binary per Node and per environment.

`HoneyDrunk.Notify`'s existing Sentry configuration is **adopted** into this pattern: the existing DSN is re-issued under the Grid Sentry organization, stored in Vault, and consumed via `IErrorReporter` rather than the direct Sentry SDK calls scattered through the codebase. The Notify migration is a discrete Phase 2 packet (D10).

Nodes not opting in receive **no** error tracking — errors fall through to Loki as ERROR-level log lines (per ADR-0040), and the operator does not get Sentry-grade error context for them. This is the deliberate fallback for low-value Nodes (e.g., `HoneyDrunk.Architecture` itself, which does not run user-facing code).

### D6 — Release tracking integration with ADR-0033 and ADR-0035

Sentry's release-tracking feature (associating errors with the deployed version) is wired to the Grid's release flows:

- **Container Apps deployable Nodes** (Notify.Functions, Notify.Worker, Pulse.Collector, future Notify Cloud) — the `HoneyDrunk.Actions` reusable deploy workflows (per ADR-0015) are amended to call Sentry's release-create API with the deployable's SemVer tag (per ADR-0033's tag→environment mapping). The `release` field on captured errors is set to the same SemVer.
- **Library / Abstractions packages** — not deployable, do not register Sentry releases. Errors caught in code consuming a library record the consuming application's release, not the library's package version.
- **Tag → release name format** — `<line>-v<semver>` (matching ADR-0033's tag shape).

This is what enables "this error first appeared in `notify-worker-v0.4.2`" — the central operational claim that distinguishes Sentry from logs.

### D7 — PII, tenant scoping, and sensitive-content carve-outs

Errors can leak PII, tenant data, and model content. Default-deny policy:

- **Sentry's data scrubbing** is configured at the project level: server-side scrubbing of common PII patterns (emails, phone numbers, credit card patterns, API keys, JWT shapes) is on. Client-side `BeforeSend` hooks in the SDK strip request bodies and response bodies by default.
- **`tenant_id` is allowed** as a Sentry tag (low cardinality bounded by tenant count); this is the load-bearing tag for multi-tenant triage. It is **not** considered PII.
- **`user_id` is allowed but pseudonymous** — the Grid's internal opaque `PrincipalId` per ADR-0026, never an email or external identifier.
- **Prompt/completion text from AI Nodes** follows the ADR-0040 D9 PII rule: **forbidden by default**, allowed only behind the `evals.sensitive=true` carve-out. Sentry errors from agent execution paths must scrub the prompt/completion content before capture; the breadcrumb (capability invoked, model, cost) is allowed.
- **`HoneyDrunk.Audit`-emitted errors** are PII-bearing by design (recipient address on a notification failure, for instance). These are sent to Sentry but with a `sensitive=audit` tag, and the project's data retention for tagged audit errors aligns with ADR-0036's Audit retention (400 days, exceeding Sentry's 90-day default — requires Sentry's extended retention tier on the project if/when Audit error volume warrants it).

### D8 — When to capture an error vs. log a line

The boundary between "this is a Sentry error" and "this is a Loki ERROR log line" needs explicit policy or both surfaces fill with overlapping noise:

- **Capture in Sentry:**
  - Uncaught or programmatic exceptions in business logic.
  - Failed dependency calls (LLM provider 5xx, downstream Node call failures) that the caller cannot recover from in-line.
  - Failed agent tool dispatch with no retry path remaining.
  - Failed billing meter-event push to Stripe after retries (per ADR-0037).
  - Audit write failures (per ADR-0030; these are also incidents).
- **Log to Loki at ERROR level (do not Sentry):**
  - Recoverable errors that retries handled successfully (the operator does not need to see them as issues; they should remain visible in logs for forensic purposes).
  - Validation failures of inbound requests (the caller's problem, not ours).
  - Expected 4xx outcomes from external APIs (auth failures the caller should fix).
  - Deserialization failures on poison messages (already a dead-letter-queue concern per ADR-0028; capture the DLQ event itself, not the deserialization).
- **Both** (Sentry **and** Loki):
  - Anything in the "Capture in Sentry" list also produces an ERROR log line. The log is for forensic timeline; the Sentry issue is for triage and trend. Both records carry the same `trace_id` so they cross-reference.

The detailed checklist per Node lives in `.claude/agents/review.md` per ADR-0044 D3's Observability category. This ADR binds the principle; the agent file binds the per-case mapping.

### D9 — Cost model

Sentry's pricing tiers as of this ADR's date:

- **Developer (free):** 5,000 errors/month, 1 user, 30-day retention.
- **Team ($26/mo):** 50,000 errors/month, unlimited users, 90-day retention.
- **Business ($80/mo):** 250,000+ errors/month, 90-day retention, advanced features.

Expected v1 volume: well within free-tier bounds (the Grid's current error volume is single-digit events per day across all Nodes). The free tier is the v1 commitment; upgrade triggers automatically on volume crossing 4,000 errors/month sustained over two consecutive months. The upgrade-decision review names whether to upgrade Sentry tier or to tighten capture rules (D8) to reduce volume.

Cost ceiling tracked in `business/context/` under observability-tooling cost, combined with ADR-0040's Grafana Cloud line. Combined ceiling for observability tools: $200/month before reconsideration. (Grafana Cloud is also free-tier at v1; combined v1 cost is $0.)

### D10 — Phased rollout

- **Phase 1 (Week 1–2) — Sentry organization and pilot.** Create the `honeydrunkstudios` Sentry organization, configure dev/staging/prod projects, set data-scrubbing defaults per D7. Author `HoneyDrunk.Observe.Sentry` package with the default `IErrorReporter` backing. Enable on `HoneyDrunk.Notify` (existing one-off Sentry usage migrates into the new pattern; existing DSN re-issued under the new org).
- **Phase 2 (Week 3–6) — Rollout to deployable Nodes.** `HoneyDrunk.Notify.Functions`, `HoneyDrunk.Notify.Worker`, `HoneyDrunk.Pulse.Collector` opt in via Observe configuration. Release tracking (D6) wires into the deploy workflows.
- **Phase 3 (Month 2–3) — Cross-link integration.** Grafana Cloud ↔ Sentry deep-link configuration (D4) lands. Sentry-side trace tool URL template configured against Grafana Cloud Tempo.
- **Phase 4 (Month 3+) — AI-sector standup wave consumes the pattern.** Every Seed-sector AI Node, on standup, wires `IErrorReporter` and consumes Sentry from day one. The agent execution loop's breadcrumb usage (tool dispatched, model invoked, cost incurred) is the high-value Sentry surface area for AI Nodes.

Each phase is a discrete go/no-go.

### D11 — Relationship to ADR-0010, ADR-0040, and the existing Notify-Sentry setup

- **ADR-0010** — preserved. `HoneyDrunk.Observe` is the provider-slot connector layer. This ADR adds `IErrorReporter` to its abstractions surface, alongside the existing OTLP-shaped surfaces. The provider-slot pattern is exactly the right fit.
- **ADR-0040** — extended. ADR-0040 covers traces/metrics/logs in Grafana Cloud; this ADR covers errors in Sentry. The two are complementary; ADR-0040's "unified view" claim is completed by D4's cross-link.
- **Existing Notify-Sentry setup** — **adopted, not replaced.** The DSN is re-issued under the new org during Phase 1; the direct Sentry SDK calls in Notify are migrated to `IErrorReporter` calls. Existing Sentry issue history is migrated via Sentry's org-merge tooling where possible; where not possible, the old project is archived with a pointer to the new one.

### D12 — Pulse is not an error source

Per ADR-0028, Pulse signals are explicitly **not** domain events. They are not errors either. Pulse's job is health/synthetic monitoring; a Pulse signal "the API returned 500 on a synthetic probe" produces a **metric** (Grafana Cloud) and a **log** (Loki), not a Sentry error. Errors in Sentry come from application code paths catching exceptions, not from synthetic monitoring.

Recorded explicitly so the boundary doesn't blur: Pulse → Grafana; application code → Sentry (and Grafana). The user's mental model of "where do I look for X" is preserved.

## Consequences

### Affected Nodes

- **HoneyDrunk.Observe** — primary affected Node. `HoneyDrunk.Observe.Abstractions` gains `IErrorReporter`, `ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel`. New backing package `HoneyDrunk.Observe.Sentry`.
- **HoneyDrunk.Notify** — existing direct-Sentry usage migrates to `IErrorReporter`; existing DSN re-issued under the new org.
- **HoneyDrunk.Notify.Functions, HoneyDrunk.Notify.Worker, HoneyDrunk.Pulse.Collector** — opt in via Observe config in Phase 2.
- **HoneyDrunk.Actions** — reusable deploy workflows (`job-deploy-function.yml`, `job-deploy-container-app.yml`) amended to call Sentry's release-create API as a post-deploy step.
- **HoneyDrunk.Vault** — stores Sentry DSNs per Node per environment; rotation per ADR-0006.
- **HoneyDrunk.Architecture** — `catalogs/contracts.json` gains `IErrorReporter` under the Observe Node's published contracts.
- **AI-sector Seed Nodes (ADR-0016 through ADR-0025)** — each consumes `IErrorReporter` at standup; Sentry usage is part of the standup canary.
- **HoneyDrunk.Audit** — emits errors with `sensitive=audit` tag and longer-retention requirements; coordinates with ADR-0036's Audit retention rules.
- **HoneyDrunk.Notify.Cloud** (future, ADR-0027) — multi-tenant Sentry usage with `tenant_id` tags from day one; tenant-scoped issue triage is a future Notify Cloud feature, deferred.

### Invariants

Adds one:

- **Invariant: errors captured for Sentry-eligible cases (D8) flow through `IErrorReporter`, never via direct Sentry SDK calls.** This preserves backend reversibility and the centralized PII-scrubbing surface. Direct `SentrySdk.CaptureException` calls outside the Observe backing are forbidden.

(Final invariant numbering assigned when the implementing work updates `constitution/invariants.md`; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **A Sentry organization becomes load-bearing CI/operational infrastructure.** Org ownership bound to the Studio's primary email (per BDR-0001 mail-of-record). 2FA required.
- **DSNs are now a class of secrets** managed by Vault per ADR-0005. Rotation per ADR-0006 (DSNs do not technically need rotation as often as API keys, but go through the same lifecycle for consistency).
- **The PII-scrubbing rules are load-bearing.** A misconfigured `BeforeSend` hook could leak prompt content to Sentry, which would be a real privacy regression. The Phase 1 work includes a Sentry-side scrubbing-test canary that submits known-PII errors in `dev` and asserts they arrive scrubbed.
- **Cross-link configuration is a one-time setup, not per-Node.** Once Grafana Cloud's Tempo→Sentry and Sentry's trace-tool URL template are configured, every Node benefits without per-Node work.
- **The Notify migration in Phase 1** is the highest-friction step because it's a real codebase change against running production. Phase 1 includes a parallel-run window where both the old direct-Sentry usage and the new `IErrorReporter` path send to Sentry, verifying parity before cutover.
- **Sentry release tracking adds a one-line API call to each deploy workflow.** Failure to register a release does not block the deploy (advisory call); it just means new errors in that deploy show as "release: unknown."

### Follow-up Work

- Create the `honeydrunkstudios` Sentry organization; configure dev/staging/prod projects.
- Author `HoneyDrunk.Observe.Sentry` package with the `IErrorReporter` default backing.
- Add `IErrorReporter`, `ErrorContext`, `ErrorScope`, `Breadcrumb`, `ErrorLevel` to `HoneyDrunk.Observe.Abstractions`.
- Migrate Notify's direct-Sentry usage to `IErrorReporter`; re-issue DSN; verify parity.
- Amend HoneyDrunk.Actions deploy workflows to register Sentry releases.
- Configure cross-link (D4) — Sentry trace tool URL template + Grafana Tempo→Sentry integration.
- Author the PII-scrubbing canary in `HoneyDrunk.Observe.Sentry.Tests.Canaries`.
- Wire `IErrorReporter` into each AI-sector standup ADR (0016–0025) as the standup canary surface.
- Update `.claude/agents/review.md` D3 Observability category with the D8 capture-vs-log mapping.
- Amend `repos/HoneyDrunk.Observe/` documentation with the new `IErrorReporter` surface.

## Alternatives Considered

### Use Grafana Cloud only (errors-as-ERROR-level-logs in Loki)

Considered. Cheapest option (zero net-new vendor). Rejected because Loki doesn't deliver the features that distinguish error tracking from log streaming: fingerprinting (is this a new error or a recurrence?), release tracking (was this introduced in version X?), breadcrumbs (what was the program doing in the seconds before the exception?), session tracking, issue state (new / regressed / resolved / muted). Logs answer "what happened"; errors answer "what's broken right now and why." Forcing Loki to do both produces a worse "what's broken" surface and adds noise to "what happened."

Grafana Cloud has been building an incident/error correlation product (`Grafana Incident`, `Grafana OnCall`) but it is not at feature parity with Sentry on the error-tracking specifics, and adopting it would also be a new vendor SKU at additional cost.

### Adopt Datadog for everything (traces, metrics, logs, AND errors)

Rejected at the ADR-0040 stage on cost grounds (per-host pricing). The same argument applies here. Datadog's error tracking is competitive with Sentry but bundling it doesn't change the per-host cost calculus.

### Honeycomb errors

Considered. Honeycomb's BubbleUp feature is genuinely strong for high-cardinality error analysis from traces. Rejected because Honeycomb was already declined at ADR-0040 for the trace/metrics/logs primary, and adopting it just for errors would reintroduce the multi-vendor problem ADR-0040 solved by picking Grafana Cloud.

### Self-host GlitchTip (open-source Sentry-compatible)

Rejected on operational burden. GlitchTip is API-compatible with the Sentry SDK and self-hostable, which is attractive in principle. In practice, hosting it means yet another database to back up (per ADR-0036), yet another service to monitor, yet another upgrade cadence to track. Sentry's free/Team tier is cheaper than the Studio operator's time to maintain a self-hosted equivalent.

### Direct Sentry SDK usage without an Observe abstraction

Rejected. The `IErrorReporter` abstraction costs little (≤200 lines of code in the Observe.Sentry backing) and buys: backend reversibility per ADR-0010 (swap Sentry for GlitchTip / Bugsnag / Rollbar with a single config change); centralized PII scrubbing (one `BeforeSend` to maintain, not N); consistent `trace_id`/`tenant_id` tagging (set once in the backing, not threaded through every catch block); and uniform breadcrumb / scope semantics that survive backend swaps. The direct-SDK pattern is what Notify has today, and the Phase 1 migration is the explicit cost of fixing that.

### Treat AI errors specially with a separate backend

Considered. The AI-sector standup wave's errors (LLM failures, tool dispatch, agent execution) are arguably a different shape from CRUD-application errors. Rejected because the differences are surface (breadcrumb content, tag values), not structural; the same `IErrorReporter` interface serves both. Specialized AI error analysis can live as a separate Sentry project or a separate dashboard view in the same backend, not as a separate vendor.

### Skip the Notify migration; keep Notify-Sentry standalone

Rejected. The whole point of this ADR is making error tracking a Grid-wide governed concern. Leaving Notify as a special case continues the drift that prompted the ADR in the first place. The migration is real work but Phase 1 carries it explicitly with a parallel-run window to de-risk.

### Defer until Notify Cloud GA

Rejected. The forcing functions (AI-sector standup wave, ADR-0040's unified-view claim, the existing Notify drift) are all present today. Deferring means Phase 1 lands under deadline pressure during the Notify Cloud GA push, which is the worst time to migrate a running production setup.
