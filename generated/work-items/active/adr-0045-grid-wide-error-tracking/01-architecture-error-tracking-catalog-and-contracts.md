---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0045", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0045", "ADR-0040"]
accepts: ["ADR-0045"]
wave: 1
initiative: adr-0045-grid-wide-error-tracking
node: honeydrunk-architecture
---

# Record the IErrorReporter contract and the D8 capture policy in the Grid catalogs

## Summary
Record ADR-0045's decisions as catalog data: register the `IErrorReporter` facade contract in `catalogs/contracts.json` under the **Pulse** Node (alongside the existing `IErrorSink`), and document the D8 capture-vs-log policy where the Grid keeps cross-cutting policy notes.

## Context
ADR-0045 D1 adds **errors** to the canonical Grid signal taxonomy and D3 adds the `IErrorReporter` facade — layered over Pulse's **existing `IErrorSink`** in `HoneyDrunk.Telemetry.Abstractions`. Pulse (v0.3.0, LIVE) already ships `IErrorSink`/`ErrorEvent`; this packet registers the new facade contract alongside it.

ADR-0045's Affected Nodes: "`HoneyDrunk.Architecture` — `catalogs/contracts.json` gains the `IErrorReporter` facade under the Pulse Node's published contracts."

**Catalog schema ground truth — read before editing.**
- `catalogs/contracts.json` has the shape `{_meta, contracts:[{node, node_name, package, status, interfaces:[...]}]}`. The `honeydrunk-pulse` entry already exists (package `HoneyDrunk.Pulse.Contracts`, status `seed`, listing `ITraceSink`/`ILogSink`/`IMetricsSink` and the `TelemetryTagKeys` type). The `IErrorReporter` facade is added to that Pulse entry's `interfaces` list (or, if the catalog convention separates packages, a `HoneyDrunk.Telemetry.Abstractions` Pulse entry — match the existing convention).
- `catalogs/grid-health.json` node entries carry **only** `signal`/`version`/`canary_status`/`last_release`/`active_blockers`/`notes` (plus a top-level `_meta` and `summary`). There is **no** observability/telemetry/error-tracking readout in `grid-health.json`, and **no place** for a Notify-Sentry decommission item. **Do not edit `grid-health.json` in this packet** — there is no observability section there to extend (an earlier draft of this packet referenced one created by "ADR-0040 packet 01"; that section does not exist — it was a phantom).
- `catalogs/nodes.json` has no `exposes` field; node exposure lives in `relationships.json`. This packet does not touch either.

**No new App Insights resource.** ADR-0045 D2 captures errors into the *same* App Insights resource ADR-0040 provisions — no resource entry is added anywhere.

**Notify-Sentry decommission tracking.** The Notify-Sentry account decommission is *not* tracked in `grid-health.json` (no schema slot for it). It is tracked in the dispatch plan's "Notify-Sentry account decommission" deferred note and surfaces as packet 05's Human Prerequisite. This packet adds no catalog field for it.

This is a catalog/docs packet. No code, no .NET project.

## Scope
- `catalogs/contracts.json` — register the `IErrorReporter` facade under the `honeydrunk-pulse` Node's contracts, alongside the existing `IErrorSink`/`ITraceSink`/`ILogSink`/`IMetricsSink` surface.
- A cross-cutting policy note for the D8 capture-vs-log boundary — placed where the Grid keeps such notes (match the existing convention for cross-cutting policy notes).

## Proposed Implementation
1. **`catalogs/contracts.json`** — add the `IErrorReporter` facade to the `honeydrunk-pulse` Node's `interfaces` list. The contract lives in `HoneyDrunk.Telemetry.Abstractions` (packet 02 creates it). Mark its kind `interface`; describe it as the Grid-facing error-reporting facade layered over the existing `IErrorSink` — it captures ambient context (`trace_id`, `tenant_id`, `release`) and breadcrumb/scope state and routes to `IErrorSink`. Do not invent member names beyond what ADR-0045 D3 specifies (`CaptureException`, `CaptureMessage`, `AddBreadcrumb`, `PushScope`). If the catalog tracks per-interface status, mark it `planned` until packet 02 lands. Note in the description that it does **not** duplicate `IErrorSink`.
2. **No `grid-health.json` edit.** That file's node entries have no observability/error-tracking readout — see the schema note. Skip it entirely.
3. **D8 capture-vs-log policy note** — record the D8 boundary (when to `CaptureException` vs when to log an ERROR line vs when to do both) as a cross-cutting policy note in the Grid's established location for such notes. This note is the human-readable companion to the per-case mapping that packet 06 adds to `.claude/agents/review.md`.

## Affected Files
- `catalogs/contracts.json`
- A capture-vs-log policy note in the established cross-cutting-notes location.

## NuGet Dependencies
None. This packet touches only catalog JSON and Markdown; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Catalog data only — the `IErrorReporter` code lands in packet 02.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` registers the `IErrorReporter` facade under the `honeydrunk-pulse` Node, alongside the existing `IErrorSink`/`ITraceSink`/`ILogSink`/`IMetricsSink`, with the four-member shape summary (`CaptureException`, `CaptureMessage`, `AddBreadcrumb`, `PushScope`) and a description stating it is a facade over `IErrorSink`, not a duplicate; marked `planned` if the catalog tracks per-interface status
- [ ] `catalogs/grid-health.json` is **not** edited — its node-entry schema (`signal`/`version`/`canary_status`/`last_release`/`active_blockers`/`notes`) has no observability/error-tracking readout to extend
- [ ] The Notify-Sentry decommission is **not** added as a `grid-health.json` field (no schema slot) — it is tracked in the dispatch plan's deferred note and packet 05's Human Prerequisites
- [ ] The D8 capture-vs-log policy is recorded as a cross-cutting policy note in the Grid's established location for such notes
- [ ] No invariant change in this packet (the error-flow invariant lands in packet 00)
- [ ] No new App Insights resource — errors reuse the ADR-0040-provisioned resources

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0045 D1 — Errors are a fourth Grid signal type.** Errors join traces/metrics/logs in the Grid signal taxonomy. Backend v1 App Insights Failures; 90-day retention in the same workspace.

**ADR-0045 D2 — Backend v1: App Insights Failures + exception tracking.** Errors capture into the *same* App Insights resource that holds traces/metrics/logs per ADR-0040, via the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package. No separate vendor, no separate billing line, no new package.

**ADR-0045 D3 — `IErrorReporter` facade.** A new facade added to `HoneyDrunk.Telemetry.Abstractions`, layered over Pulse's existing `IErrorSink` — it does not duplicate `IErrorSink`. Shape: `CaptureException(Exception, ErrorContext?)`, `CaptureMessage(string, ErrorLevel, ErrorContext?)`, `AddBreadcrumb(Breadcrumb)`, `PushScope(ErrorScope)`.

**ADR-0045 D8 — Capture-vs-log policy.** Capture-as-error: uncaught/programmatic exceptions, unrecoverable failed dependency calls, failed agent tool dispatch, failed Stripe meter-event push, Audit write failures. Log-only at ERROR: retries that succeeded, inbound-validation failures, expected 4xx, poison-message deserialization. Both: anything in the capture list also produces an ERROR log line carrying the same `operation_id`.

**ADR-0045 D5 — Notify-Sentry migration.** Notify's Sentry config is migrated to `IErrorReporter`; the Notify-Sentry account is archived once wired (config-only — no parallel-run window).

## Constraints
- **No new App Insights resource.** Errors share the ADR-0040-provisioned resource (D2).
- **No invented contract members.** The `IErrorReporter` shape is fixed by ADR-0045 D3 — four members. Do not add or rename.
- **`IErrorReporter` is a facade, not a duplicate.** The catalog description must state it layers over the existing `IErrorSink` and adds ambient-context + breadcrumb/scope ergonomics — it does not reinvent error capture.
- **Do not edit `grid-health.json`.** Its node-entry schema has no observability/error-tracking readout. Editing it to add a signal type or a decommission item would invent a field that does not exist.
- **Match existing catalog shape.** The `IErrorReporter` entry mirrors the existing `interfaces[]` entries on the `honeydrunk-pulse` `contracts.json` record.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0045`, `wave-1`

## Agent Handoff

**Objective:** Register the `IErrorReporter` facade in `catalogs/contracts.json` under the Pulse Node, and record the D8 capture policy as a cross-cutting note.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Register `IErrorReporter` as a published Pulse contract and record the D8 policy.
- Feature: ADR-0045 Grid-Wide Error Tracking rollout, Wave 1.
- ADRs: ADR-0045 D1/D2/D3/D5/D8 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0045 should be Accepted before its decisions are recorded as catalog data.

**Constraints:**
- Register `IErrorReporter` under `honeydrunk-pulse` in `contracts.json`, alongside the existing `IErrorSink` — describe it as a facade over `IErrorSink`, not a duplicate.
- No invented contract members — `IErrorReporter` is the four-member shape from D3.
- Do **not** edit `grid-health.json` — its node-entry schema has no observability/error-tracking readout (no phantom field).
- The Notify-Sentry decommission is tracked in the dispatch plan / packet 05 Human Prerequisites, not in any catalog.

**Key Files:**
- `catalogs/contracts.json`

**Contracts:** `IErrorReporter` facade registered as catalog metadata under the Pulse Node (the code is packet 02).
