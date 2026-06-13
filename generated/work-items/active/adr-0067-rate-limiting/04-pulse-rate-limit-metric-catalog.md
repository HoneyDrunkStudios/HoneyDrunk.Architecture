---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "docs", "adr-0067", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0067"]
wave: 3
initiative: adr-0067-rate-limiting
node: honeydrunk-pulse
---

# Register rate_limit_rejection_count and rate_limit_remaining_ratio in HoneyDrunk.Pulse metric catalog

## Summary
Confirm and document the canonical shape of the two telemetry signals ADR-0067 D10 commits — the `rate_limit_rejection_count` counter and the `rate_limit_remaining_ratio` gauge — and the alarm threshold (≥50 rejections for a single `(tenant_id, endpoint)` over a 5-minute window pages on-call) in `HoneyDrunk.Pulse`'s docs. This is a docs-only work-item: no code change, no contract change, no version bump beyond an optional PATCH for docs. The two signals ride existing OpenTelemetry counter/gauge instruments through the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` and other Pulse sinks; this packet pins the metric names, tags, and alarm semantics so Notify Cloud (when its production `ITenantRateLimitPolicy` ships per ADR-0027 + the deferred follow-up packet 05) emits the right signals and operator dashboards / Azure Monitor Alerts know which series to chart and watch.

## Context
ADR-0067 D10 commits two telemetry signals from the rate-limiter substrate:

- **`rate_limit_rejection_count`** — counter metric. Tags: `tenant_id`, `endpoint`, `tier`, `outcome` (`outcome` distinguishes `rate-limit` from `quota-overage-billed`). `tenant_id` is a low-cardinality tag bounded by ADR-0027 D7's paying-tenant ceiling (tens at v1).
- **`rate_limit_remaining_ratio`** — gauge per tenant per endpoint. Records the current `RateLimit-Remaining / RateLimit-Limit` ratio. Operationally useful for surfacing "tenant X consistently runs at 95% of their tier ceiling" before they complain.
- **Alarm threshold** — a spike in `rate_limit_rejection_count` for a single `(tenant_id, endpoint)` pair over a 5-minute window (≥50 rejections) is a paging signal. Interpretation: tenant is being abused, tenant is mis-sized for their tier, or there is a misconfigured client. The on-call surface (per ADR-0054) decides which.

`HoneyDrunk.Pulse` is a live Node at v0.3.0. Per ADR-0040, telemetry flows through Pulse's OTLP boundary into Azure Monitor (and any other Pulse sinks). The two metrics here are emitted by the consuming Node's `ITenantRateLimitPolicy` implementation — for the GA path, that is Notify Cloud — using the standard `System.Diagnostics.Metrics` instruments (`Meter.CreateCounter<long>`, `Meter.CreateObservableGauge<double>` or equivalent). The Pulse pipeline carries them; this packet does **not** change the pipeline.

This packet pins the **metric names, tag set, and alarm threshold** in Pulse's docs (`README.md` or a new `docs/metric-catalog.md` — Pulse has a `docs/` folder already) so:

- Notify Cloud (and any future Node) emits the canonical name and tags verbatim.
- Operator dashboards (Azure Monitor workbooks, Grafana Mimir, any future surface) chart the right series.
- Azure Monitor Alerts (per ADR-0040 packet 08, when that lands) is configured against the documented signal name and threshold.

This packet **does not** add code, does not register a `Meter` or instrument, does not change `IMetricsSink` / any sink, and does not add an abstraction. The `System.Diagnostics.Metrics` instruments are created at emit-time by the consuming Node; Pulse only carries the OTLP signal downstream. Documentation is the canonical registration in Phase 1, mirroring how ADR-0040 packet 01 cataloged telemetry signals.

`HoneyDrunk.Pulse` is a docs-only target here — no `.csproj` edits, no version bump unless the repo's convention requires a PATCH for docs. Match the repo's existing CHANGELOG convention; do **not** introduce an `[Unreleased]` section (per the user's standing convention).

## Scope
- `HoneyDrunk.Pulse/README.md` — extend with a `## Rate-Limit Metric Catalog` section (or a new file `HoneyDrunk.Pulse/HoneyDrunk.Pulse/docs/rate-limit-metrics.md` if the executor judges the README is the wrong home; the existing `docs/` folder is in the inner solution directory).
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/CHANGELOG.md` (or the repo-level `CHANGELOG.md`, matching the repo's convention) — record the documentation addition under a dated version section. PATCH-bump if the repo's convention treats doc-only updates as version-noteworthy; otherwise append to the most recent dated entry. **No `[Unreleased]`.**
- No `.csproj` edits, no `Meter` registration, no instrument code.

## Proposed Implementation
1. Open `HoneyDrunk.Pulse/README.md` (or the repo's documentation home for telemetry signal catalogs — if there is a `docs/metric-catalog.md` or similar, append there; otherwise add to README as a new `## Rate-Limit Metric Catalog` section).
2. Add the canonical metric catalog (substance-verbatim — preserve names, tags, and threshold exactly so future Pulse-repo readers find one canonical source):

   ```
   ## Rate-Limit Metric Catalog

   The Grid emits two canonical telemetry signals from the rate-limiter substrate (ADR-0067 D10). Both are standard `System.Diagnostics.Metrics` instruments — a counter and an observable gauge — emitted by the consuming Node's `ITenantRateLimitPolicy` implementation (Notify Cloud at GA per ADR-0067; any future Node that opts into rate-limit auditing). Pulse carries them through the existing OTLP pipeline; no new abstraction is required.

   Producers must emit these names and tags verbatim so operator dashboards, alerts, and forensic queries find them.

   ### `rate_limit_rejection_count` (counter)

   Long counter — incremented on every hard 429 (rate-limit rejection) and on every quota-overage-billable event.

   - **Type:** `System.Diagnostics.Metrics.Counter<long>` (or the OTel-native equivalent).
   - **Unit:** `1` (count).
   - **Tags** (lower-case, snake_case):
     - `tenant_id` — the tenant identifier; `"anonymous"` for unauthenticated endpoints. Low cardinality: bounded by the paying-tenant ceiling (ADR-0027 D7 — tens at v1).
     - `endpoint` — the endpoint route. Low-to-medium cardinality: bounded by the number of routes in the Node.
     - `tier` — `"free"` / `"pro"` / `"scale"` for authenticated; `"anonymous"` for unauthenticated.
     - `outcome` — `"rate-limit"` for hard 429 rejections; `"quota-overage-billed"` for Pro/Scale tenants over monthly quota whose overage was billed (the request proceeded; ADR-0037 D2 Stripe meter incremented).

   ### `rate_limit_remaining_ratio` (gauge)

   Double observable gauge — the current `RateLimit-Remaining / RateLimit-Limit` ratio (the success-side header value per ADR-0067 D7) for a given tenant + endpoint, sampled at the cadence the metrics pipeline collects observable gauges.

   - **Type:** `System.Diagnostics.Metrics.ObservableGauge<double>` (or the OTel-native equivalent).
   - **Unit:** `1` (dimensionless ratio, 0.0–1.0).
   - **Tags** (lower-case, snake_case):
     - `tenant_id` — as above.
     - `endpoint` — as above.
     - `tier` — as above.

   Operational use: surfaces "tenant X consistently runs at 95% of their tier ceiling" before they complain. Suitable for an Azure Monitor dashboard tile or a Grafana panel.

   ## Alarm Threshold

   **Page on-call** when `rate_limit_rejection_count` for a single `(tenant_id, endpoint)` pair, with `outcome = "rate-limit"`, increments **≥ 50 times in any 5-minute window**.

   Interpretation: (a) the tenant is being abused (consider abuse-mitigation), (b) the tenant is mis-sized for their tier (consider tier upgrade or App Configuration override per ADR-0067 D2), or (c) there is a misconfigured client (developer-side error). The on-call surface (per ADR-0054 incident response) triages the cause.

   `outcome = "quota-overage-billed"` events do **not** trigger this alarm — those are expected, billable, and intentional. A separate dashboard tile is appropriate for tracking total quota-overage volume by tenant for billing-reconciliation purposes.

   ## Cross-references

   - **ADR-0067 D10** — rate-limit telemetry contract.
   - **ADR-0010** — observation layer.
   - **ADR-0040** — telemetry backend (Azure Monitor + Application Insights).
   - **ADR-0054** — incident response and on-call model.
   - **ADR-0037 D2** — Stripe meter overage (the `quota-overage-billed` outcome's billing path).
   - **Invariant 8** — secret values never appear in tags or metric values. The `tenant_id` tag is the tenant identifier (operator-visible per ADR-0049); the full API key never appears.
   ```

   Adjust prose to match the repo's existing tone if it differs noticeably; preserve metric names, tag names, units, the alarm threshold, and the cross-references verbatim.
3. Update `HoneyDrunk.Pulse`'s CHANGELOG matching the repo's existing convention. If the repo treats doc-only updates as version-noteworthy, create a new dated PATCH-bumped entry (e.g., `[0.3.1] - 2026-MM-DD`) and bump every non-test `.csproj` in the solution to `0.3.1` in one commit (invariant 27). Otherwise append a `## Documentation` note to the most recent dated entry. Do **not** use `[Unreleased]`. State the chosen path in the PR.
4. No code change. No `Meter` registration, no instrument file. The instruments are created at emit-time by the consuming Node; Pulse is the carrier.

## Affected Files
- `HoneyDrunk.Pulse/README.md` (or `HoneyDrunk.Pulse/HoneyDrunk.Pulse/docs/rate-limit-metrics.md` if the executor lifts the section out of README).
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/CHANGELOG.md` (and / or repo-level `CHANGELOG.md` per repo convention) — documentation note under a dated version.
- Optionally every non-test `.csproj` in the solution if Option B (PATCH-bump) is chosen — but only if the convention requires it.

## NuGet Dependencies
None. This packet touches only Markdown documentation and possibly a single `<Version>` bump.

## Boundary Check
- [x] All edits in `HoneyDrunk.Pulse`. Routing rule "telemetry, observability, OTel, signal, metrics, traces, logs → HoneyDrunk.Pulse" maps exactly.
- [x] No contract change. No `IMetricsSink`, `ITraceSink`, or `ILogSink` modification.
- [x] No `Meter`, no instrument, no emit-time code lands here. The consuming Node (Notify Cloud at GA) creates the instruments; Pulse carries them.
- [x] No new abstraction.

## Acceptance Criteria
- [ ] `HoneyDrunk.Pulse/README.md` (or `docs/rate-limit-metrics.md`) carries a Rate-Limit Metric Catalog section
- [ ] `rate_limit_rejection_count` is documented as a `Counter<long>` with tags `tenant_id`, `endpoint`, `tier`, `outcome` (outcome values `"rate-limit"` and `"quota-overage-billed"`)
- [ ] `rate_limit_remaining_ratio` is documented as an `ObservableGauge<double>` with tags `tenant_id`, `endpoint`, `tier`
- [ ] The alarm threshold (≥50 rejections over 5 minutes for a single `(tenant_id, endpoint)` pair, `outcome = "rate-limit"`) is documented as a paging signal with the three interpretation cases
- [ ] The `quota-overage-billed` outcome is explicitly excluded from the paging alarm
- [ ] Cross-references to ADR-0067 D10, ADR-0010, ADR-0040, ADR-0054, ADR-0037 D2, and invariant 8 are present
- [ ] `HoneyDrunk.Pulse`'s CHANGELOG records the documentation addition under a dated version section; `[Unreleased]` is NOT used
- [ ] No code change in any `.cs` file
- [ ] No `Meter` registration, no instrument file
- [ ] If a PATCH-bump is chosen, every non-test `.csproj` in the solution is at the same new PATCH version in a single commit (invariant 27)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0067 D10 — Observability.** "A counter metric `rate_limit_rejection_count` with tags `tenant_id`, `endpoint`, `tier`, `outcome` (the `outcome` distinguishes `rate-limit` from `quota-overage-billed`). `tenant_id` is a low-cardinality tag bounded by the ADR-0027 D7 paying-tenant ceiling (tens at v1). A gauge `rate_limit_remaining_ratio` per tenant per endpoint — the current `RateLimit-Remaining / RateLimit-Limit` ratio. **Alarm threshold:** a spike in `rate_limit_rejection_count` for a single `(tenant_id, endpoint)` pair over a 5-minute window (≥ 50 rejections) is a paging signal. The interpretation: either the tenant is being abused, the tenant is mis-sized for their tier, or there is a misconfigured client. The on-call surface (per ADR-0054) decides which."

**ADR-0010 (referenced) — Observation Layer.** The Grid's observability primitives (traces, metrics, logs) flow through `HoneyDrunk.Pulse`. New metrics ride existing sinks; no new sink or contract is required for these two.

**ADR-0040 (referenced) — Telemetry Backend.** Azure Monitor + Application Insights is the Phase-1 backend. The two metrics here flow through `HoneyDrunk.Telemetry.Sink.AzureMonitor` (and any other configured Pulse sink) per ADR-0040's reversibility property. Azure Monitor Alerts wiring is ADR-0040 packet 08's concern; this packet only documents the metric shape and threshold.

**ADR-0054 (referenced) — Incident Response.** The on-call surface for paging signals; the rate-limit-spike alarm pages through that surface.

**Invariant 8 — Secret values never appear in logs, traces, or metric tags.** The `tenant_id` tag is the tenant identifier (operator-visible per ADR-0049 data-classification). Full API keys never appear in any tag, metric value, or log line. The 8-character API-key display prefix is permitted in any non-secret display context but is not a metric tag here.

## Constraints
- **No code change.** This packet only documents canonical metric names, tags, and the alarm threshold; no `Meter`, no instrument file, no contract or runtime change.
- **No `[Unreleased]` CHANGELOG.** Per the user's standing convention, move directly to a dated version section. PATCH-bump or append-to-most-recent-dated-entry per the repo's existing convention.
- **No secret values in any tag or metric value.** Invariant 8 applies.
- **`outcome = "quota-overage-billed"` does NOT trigger the alarm.** Pro/Scale tenants over monthly quota are billable, not abnormal — the alarm threshold is for the `"rate-limit"` outcome only.
- **Notify Cloud is the first emitter, not this packet.** This packet documents the shape; Notify Cloud (when it stands up per ADR-0027 + the deferred follow-up packet 05 of this initiative) is the first Node that actually emits these metrics. No emit-side code lands here.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0067`, `wave-3`

## Agent Handoff

**Objective:** Document the canonical shape of the `rate_limit_rejection_count` counter and `rate_limit_remaining_ratio` gauge plus the alarm threshold in the `HoneyDrunk.Pulse` repo, so Notify Cloud (and any future Node) emits the right signals.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Pin the canonical metric names, tag sets, and alarm threshold for the two ADR-0067 D10 telemetry signals. No code change; documentation-only registration in the Pulse repo.
- Feature: ADR-0067 Inbound Rate Limiting and Quota Enforcement rollout, Wave 3.
- ADRs: ADR-0067 D10 (primary), ADR-0010 (observation layer), ADR-0040 (telemetry backend), ADR-0054 (on-call paging), ADR-0037 D2 (Stripe meter overage — the `quota-overage-billed` outcome's billing path).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0067 should be Accepted before its metric shapes are documented as canonical.

**Constraints:**
- No code change. No new `Meter`, no instrument file, no contract change.
- The two metrics ride standard `System.Diagnostics.Metrics` instruments emitted by the consuming Node; Pulse is the carrier.
- `[Unreleased]` is forbidden in `CHANGELOG.md`; use a dated version section.
- No secret material in any tag or metric value; invariant 8 applies.
- The `quota-overage-billed` outcome is excluded from the paging alarm — Pro/Scale overage is billable and intentional, not abnormal.

**Key Files:**
- `HoneyDrunk.Pulse/README.md` (or `HoneyDrunk.Pulse/HoneyDrunk.Pulse/docs/rate-limit-metrics.md`) — the new Rate-Limit Metric Catalog section.
- `HoneyDrunk.Pulse`'s CHANGELOG — documentation entry under a dated version.

**Contracts:** None changed. `IMetricsSink`, `ITraceSink`, `ILogSink` are unchanged.
