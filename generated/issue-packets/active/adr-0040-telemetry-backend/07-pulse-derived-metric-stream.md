---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0040", "wave-3"]
dependencies: ["packet:03"]
adrs: ["ADR-0040", "ADR-0028", "ADR-0036"]
accepts: ["ADR-0040"]
wave: 3
initiative: adr-0040-telemetry-backend
node: honeydrunk-pulse
---

# Add the Pulse derived-metric stream emit per ADR-0040 D7

## Summary
Add the derived-metric stream emit to `HoneyDrunk.Pulse` per ADR-0040 D7: alongside writing signal values to its own durable store, the Pulse Collector emits a derived metric stream through the Pulse Azure Monitor sink so Pulse signals land in App Insights as the operational dashboard / alerting surface. This is an intra-Pulse change — no Node boundary is crossed.

## Context
ADR-0040 D7 addresses the Pulse derived-metric stream. Pulse signals are explicitly "not domain events" per ADR-0028. D7's decision: the Pulse Collector emits to its own durable store (Tier 2 per ADR-0036) **and also** emits a derived metric stream through the Pulse Azure Monitor sink into App Insights. The two are deliberately not the same:

- **Pulse's own store** is the source of truth for historical signal values — the longer-form analytical surface (e.g. "API latency p99 over 24h").
- **The App Insights metric stream** is the operational dashboard / alerting surface, retained 93 days.

This is a deliberate dual-write. ADR-0040's Affected Nodes (as amended 2026-05-22): "`HoneyDrunk.Pulse` — ... and the derived-metric stream emit (D7)."

> **ADR-0040 amendment 2026-05-22.** The original ADR draft routed this emit "into Observe → App Insights" and the original packet flagged an Observe-vs-Pulse boundary ambiguity needing an operator decision. That ambiguity is resolved: outbound telemetry export belongs to Pulse, per the `HoneyDrunk.Observe`/`HoneyDrunk.Pulse` boundary docs. The Azure Monitor exporter lives in `HoneyDrunk.Telemetry.Sink.AzureMonitor` (extended by packet 03), inside the Pulse runtime. The D7 emit therefore stays entirely within Pulse — the Collector feeds the derived metric stream into the same Pulse telemetry pipeline that the AzureMonitor sink consumes. There is no cross-Node hop, no path reconciliation needed, and `HoneyDrunk.Telemetry.Sink.AzureMonitor` is **not** redundant — it is the intended exporter.

**Repo-state note.** `HoneyDrunk.Pulse` is a live Node at version 0.3.0 with the established `HoneyDrunk.Telemetry.Sink.*` provider family and the deployable `Pulse.Collector`. This packet adds the derived-metric computation and emit to the Collector pipeline; the AzureMonitor sink (packet 03) carries it to App Insights.

## Scope
- `HoneyDrunk.Pulse` — the Collector's derived-metric emit path: alongside the existing durable-store write, compute and emit a derived OTLP metric stream into the Pulse telemetry pipeline.
- `HoneyDrunk.Pulse.Collector` (if the emit lives in the deployable Collector) — the dual-write wiring.
- The relevant Pulse test project — coverage for the dual-write (store write + derived metric emit both happen).

## Proposed Implementation
1. **Derived-metric computation** — D7's example is "API latency p99 over 24h": Pulse computes derived metric values from its raw signals. The derived stream is metric-shaped (OTLP metrics), not raw signal values. Implement the derivation alongside the existing Collector pipeline.
2. **Dual-write** — the Collector writes signal values to its own durable store (unchanged — source of truth) **and** emits the derived metric stream into the Pulse telemetry pipeline. The two writes are independent; a failure in one must not silently drop the other (per-sink failure isolation is already a Pulse boundary property — "Multi-backend fan-out with per-sink failure isolation").
3. **Emit through the Pulse pipeline** — the derived metric stream is OTLP metrics flowing into the Pulse telemetry pipeline that the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider (packet 03) consumes. The metrics land in App Insights via that sink, retained 93 days. Pulse does not reference App Insights or the Azure Monitor exporter from outside the sink — the sink is the single exporter (invariant 69: no Node references a backend directly; the AzureMonitor sink *is* Pulse's compliant route).
4. **Tests** — cover the dual-write: a signal produces both a durable-store write and a derived metric emit. Tests use no external services (invariant 15), no `Thread.Sleep` (invariant 51).
5. **Version.** This packet appends to the `HoneyDrunk.Pulse` solution — packet 03 already bumped the version this initiative. Per invariant 27 this packet **does not bump again**; it appends to the repo-level `CHANGELOG.md` in-progress version entry.
6. **CHANGELOG / README.** Append to the repo-level `CHANGELOG.md` in-progress version entry. Per-package `CHANGELOG.md` entry for the package(s) with the actual change (the Collector / the telemetry runtime package — not alignment-bumped packages). Update the README if the public surface or the Collector's documented behavior changes.

## Affected Files
- `HoneyDrunk.Pulse/` — the Collector derived-metric emit path (exact projects per the repo layout — likely `HoneyDrunk.Telemetry.OpenTelemetry` and/or the `Pulse.Collector` deployable).
- The relevant Pulse test project — dual-write coverage.
- Repo-level `CHANGELOG.md` (append to the in-progress entry — no bump); per-package `CHANGELOG.md` for the changed package(s); README if behavior is documented there.

## NuGet Dependencies
Likely no new `PackageReference` entries — `HoneyDrunk.Pulse` already has OpenTelemetry integration (`HoneyDrunk.Telemetry.OpenTelemetry`) and the OTLP machinery, and the emit stays within the existing Pulse pipeline (no cross-Node dependency). Confirm the OTel metrics packages needed for the derived-metric stream are already referenced; if a metrics-specific OTel package is missing, add it and list it here. `HoneyDrunk.Standards` is already on the Pulse projects (existing repo) — confirm, add nothing new unless the metrics path requires it.

## Boundary Check
- [x] `HoneyDrunk.Pulse` is the correct repo — ADR-0040 D7 names Pulse explicitly; the emit, the pipeline, and the AzureMonitor sink are all Pulse-owned.
- [x] The emit flows through the Pulse telemetry pipeline into the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider — an intra-Pulse path; Pulse does not reference App Insights from outside the sink (invariant 69).
- [x] Pulse's own durable store is unchanged — D7 keeps it as the source of truth.
- [x] No cross-Node boundary crossed — the Observe-vs-Pulse boundary ambiguity is resolved (ADR-0040 amendment 2026-05-22): Pulse owns outbound telemetry export.

## Acceptance Criteria
- [ ] The Pulse Collector computes derived metric values from raw signals and emits them as an OTLP metric stream into the Pulse telemetry pipeline
- [ ] The dual-write is in place — a signal produces both a durable-store write (source of truth, unchanged) and a derived metric emit
- [ ] A failure in one write does not silently drop the other (per-sink failure isolation preserved)
- [ ] The derived metric stream reaches App Insights via the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider (packet 03) — Pulse does not reference App Insights or the Azure Monitor exporter from outside that sink (invariant 69)
- [ ] Tests cover the dual-write; tests use no external services (invariant 15), no `Thread.Sleep` (invariant 51)
- [ ] No version bump — packet 03 already bumped the `HoneyDrunk.Pulse` solution this initiative; this packet appends to the repo-level `CHANGELOG.md` in-progress version entry (invariant 27)
- [ ] Per-package `CHANGELOG.md` updated only for packages with actual changes (no alignment-noise entries)
- [ ] README updated if the Collector's documented behavior changes
- [ ] The solution builds; existing unit and canary tests pass

## Human Prerequisites
None for the code. (A live end-to-end check that derived metrics land in App Insights needs the `dev` resource from packet 02 — but that is a verification convenience, not a code prerequisite.)

## Referenced ADR Decisions
**ADR-0040 D7 — Pulse derived-metric stream.** Pulse signals are explicitly "not domain events" per ADR-0028. The Pulse Collector emits to its own durable store (Tier 2 per ADR-0036) and **also** emits a derived metric stream through the Pulse Azure Monitor sink into App Insights. Pulse's own store is the source of truth for historical signal values; the App Insights metric stream is the operational dashboard / alerting surface, retained 93 days. A deliberate dual-write — Pulse signal values need a longer-form analytical surface than App Insights metrics provide, while the alerting surface lives where dashboards live. Because Pulse owns the Azure Monitor sink, this is an intra-Pulse change.

**ADR-0040 D2 — Pulse is the OTLP-only telemetry boundary.** All telemetry routes through the Pulse sink surface; no Node references the backend directly. The `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider is Pulse's compliant route to App Insights.

**ADR-0028 — Pulse signals are not domain events.** Pulse does health/synthetic monitoring; its signals are a separate category from Transport domain events.

**ADR-0036 — Pulse durable store.** The Pulse Collector's own store is a Tier 2 durable store.

## Constraints
> **Invariant 69 (added by ADR-0040 packet 00) — no Node references Application Insights or any telemetry backend directly.** Pulse emits the derived metric stream into its own telemetry pipeline; the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider (the single exporter) carries it to App Insights. The Collector does not call the Azure Monitor exporter or App Insights from outside the sink.

> **Invariant 15 — Unit tests never depend on external services.** The dual-write tests run in-process.

> **Invariant 27 — All projects in a solution share one version and move together.** Packet 03 already bumped the `HoneyDrunk.Pulse` solution this initiative. This packet does NOT bump again — it appends to the repo-level `CHANGELOG.md` in-progress version entry.

> **Invariant 51 — Test code contains no `Thread.Sleep`.**

- **Intra-Pulse change.** The emit, the pipeline, and the AzureMonitor sink are all Pulse-owned — no cross-Node hop, no path reconciliation. The Observe-vs-Pulse boundary ambiguity is resolved (ADR-0040 amendment 2026-05-22).
- **Keep Pulse's own store as the source of truth.** D7 — the durable store is unchanged; the derived-metric emit is additive.
- **The derived stream is metric-shaped.** D7's example is p99 latency — computed/aggregated values, not raw signal dumps.

## Labels
`feature`, `tier-2`, `ops`, `adr-0040`, `wave-3`

## Agent Handoff

**Objective:** Add the Pulse derived-metric stream emit per ADR-0040 D7 — a dual-write where Pulse keeps its own durable store and also emits derived metrics through the Pulse Azure Monitor sink into App Insights.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Make Pulse signals visible on the App Insights operational dashboard / alerting surface (93-day retention) while keeping Pulse's own store as the analytical source of truth.
- Feature: ADR-0040 Telemetry Backend and Retention rollout, Wave 3.
- ADRs: ADR-0040 D7/D2 (primary; amended 2026-05-22 — Pulse owns the export), ADR-0028 (Pulse signals are not domain events), ADR-0036 (the Pulse durable store).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — hard. The derived metric stream is carried to App Insights by the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider that packet 03 extends.

**Constraints:**
- Intra-Pulse change — no cross-Node hop, no path reconciliation. The Observe-vs-Pulse boundary ambiguity is resolved (ADR-0040 amendment).
- Pulse's own durable store is the source of truth, unchanged — the emit is additive (dual-write).
- The AzureMonitor sink is the single exporter — the Collector does not reach App Insights from outside it (invariant 69).
- No version bump — packet 03 already bumped the Pulse solution this initiative; append to the CHANGELOG.

**Key Files:**
- `HoneyDrunk.Pulse/` — the Collector derived-metric emit path
- The relevant Pulse test project
- Repo-level + per-package `CHANGELOG.md`

**Contracts:** None changed in this packet — the emit uses existing OTLP metric shapes flowing into the Pulse telemetry pipeline.
