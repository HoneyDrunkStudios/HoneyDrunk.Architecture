---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0040", "wave-3"]
dependencies: ["work-item:03"]
adrs: ["ADR-0040"]
accepts: ["ADR-0040"]
wave: 3
initiative: adr-0040-telemetry-backend
node: honeydrunk-pulse
---

# Implement HoneyDrunk.Telemetry.Sampling — the adaptive sampler and the always-sample rules

## Summary
Create the `HoneyDrunk.Telemetry.Sampling` package in the `HoneyDrunk.Pulse` solution: an OpenTelemetry adaptive trace sampler plus the always-sample rule chain per ADR-0040 D4 — 100% sampling for errors, Audit telemetry, billing-event spans, and canary runs; base `ParentBased(TraceIdRatioBased)` for everything else; lower-rate sampling for high-volume background workloads. The composition plugs into the `TracerProvider` builder the packet-03 `Sink.AzureMonitor` extension exposes.

## Context
ADR-0040 D4 specifies sampling via **OpenTelemetry primitives** — a custom `Sampler` composed into the `TracerProvider` and `SpanProcessor` filters wired alongside. Classic App Insights SDK constructs (`ITelemetryProcessor`) are explicitly not used — they would undercut the D2 reversibility property. ADR-0040 (as amended 2026-05-22) names the package: it "becomes a new `HoneyDrunk.Telemetry.Sampling` package in the Pulse solution" — the original draft's `HoneyDrunk.Observe.Sampling` was corrected to Pulse because Pulse owns the outbound telemetry pipeline.

The base sampler is `ParentBased(TraceIdRatioBased)` targeting ~5 items/second per host, implemented as a small custom sampler wrapping `TraceIdRatioBased` with dynamic-rate behavior. Rules layered on top:

- **100% sampling** for any span with `success=false` or `error=true` — decided at end-of-span via tail-sampling-like behavior in a `SpanProcessor`.
- **100% sampling** for any telemetry attributed to `HoneyDrunk.Audit`.
- **100% sampling** for any span attributed to a billing-event emit (per ADR-0037).
- **100% sampling** during canary runs.
- **Lower-rate sampling** for high-volume background workloads (Pulse collector, Knowledge ingestion batch jobs) — a stricter `TraceIdRatioBased` under a `ParentBased` boundary keyed on `service.name`.

This packet appends to the `HoneyDrunk.Pulse` solution — packet 03 already bumped the version this initiative, so per invariant 27 this packet **does not bump again**; it appends to the CHANGELOG.

## Scope
- `HoneyDrunk.Telemetry.Sampling` (new project in the `HoneyDrunk.Pulse` solution) — the adaptive sampler, the rule chain, the `SpanProcessor` for end-of-span error promotion, and the `service.name`-keyed background-workload rate sampler.
- `HoneyDrunk.Telemetry.Sink.AzureMonitor` — wire the sampler composition into the `TracerProvider` builder via the seam packet 03 left.
- `HoneyDrunk.Telemetry.Sampling.Tests.Unit` (new) — unit tests for the sampling decisions.

## Proposed Implementation
1. **Adaptive base sampler** — a custom `Sampler` wrapping `TraceIdRatioBased` with dynamic-rate behavior, targeting ~5 items/second per host (App Insights' default expectation). The dynamic-rate logic adjusts the ratio toward the target rate.
2. **Rule composition** — the always-sample rules layered over the base sampler. Implement as a chained `Sampler` or a `SpanProcessor` filter per ADR-0040's note: "implemented as a chained `Sampler` or a `SpanProcessor` filter, depending on whether the decision must influence downstream span attribute drops." The error rule specifically is end-of-span (`success=false` / `error=true` is known only when the span closes) — a `SpanProcessor` with tail-sampling-like behavior. The Audit / billing / canary rules are decidable at span start — a chained `Sampler`. Implement each where the decision point dictates:
   - **Error spans** (`success=false` or `error=true`) → 100% — end-of-span `SpanProcessor`.
   - **`HoneyDrunk.Audit` telemetry** → 100% — keyed on `service.name` matching the Audit Node's canonical identity.
   - **Billing-event spans** (per ADR-0037) → 100% — keyed on a billing-event span attribute or span name; document the exact key.
   - **Canary runs** → 100% — keyed on a canary marker attribute; document the marker.
   - **High-volume background workloads** (Pulse collector, Knowledge ingestion batch jobs) → lower rate — a stricter `TraceIdRatioBased` under a `ParentBased` boundary keyed on the workload's `service.name`.
3. **`ParentBased` discipline** — the base and the background-workload sampler are `ParentBased` so a sampled parent keeps its children sampled (consistent traces).
4. **Wire into the sink.** `HoneyDrunk.Telemetry.Sink.AzureMonitor` composes the sampler into the `TracerProvider` builder via the seam packet 03 left. The Azure Monitor exporter respects the sampler decision and ships the sampled output onward without rewriting the decision (D4).
5. **Metrics and logs untouched.** D4 — metrics and logs are not sampled. This packet touches only the trace path.
6. **XML documentation** on every public member (invariant 13).
7. **Version.** Packet 03 already bumped the `HoneyDrunk.Pulse` solution version this initiative. Per invariant 27, this packet **does not bump again** — it appends to the repo-level `CHANGELOG.md` under the in-progress version entry. Create `HoneyDrunk.Telemetry.Sampling/CHANGELOG.md` and `README.md` from the first commit (invariant 12 — new package).

## Affected Files
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sampling/` (new project, with `CHANGELOG.md` and `README.md`)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sampling.Tests.Unit/` (new test project)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor/` — the sampler-composition wiring.
- The `HoneyDrunk.Pulse` `.slnx` — add the new projects.
- Repo-level `CHANGELOG.md` — append to the in-progress version entry (no new version, no bump).

## NuGet Dependencies
`HoneyDrunk.Telemetry.Sampling` (new project) `PackageReference` set:
- `OpenTelemetry` — the OTel SDK (`Sampler`, `SpanProcessor`, `TraceIdRatioBasedSampler`, `ParentBasedSampler` live here).
- `Microsoft.Extensions.DependencyInjection.Abstractions`, `Microsoft.Extensions.Options` — registration and options binding for the rate targets.
- `HoneyDrunk.Kernel.Abstractions` — for `WellKnownNodes` canonical identities (the Audit Node's `service.name`, the Pulse collector identity) used as sampler keys.
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26).

`HoneyDrunk.Telemetry.Sampling.Tests.Unit` (new project) `PackageReference` set:
- The Grid's standard test stack — match the other `HoneyDrunk.Pulse` test projects.
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all`.
- Project reference to `HoneyDrunk.Telemetry.Sampling`.

`HoneyDrunk.Telemetry.Sink.AzureMonitor` takes no new `PackageReference` — it gains a project reference to `HoneyDrunk.Telemetry.Sampling` for the composition wiring.

## Boundary Check
- [x] `HoneyDrunk.Pulse` is the correct repo — ADR-0040 D4 (as amended 2026-05-22) names `HoneyDrunk.Telemetry.Sampling` in the Pulse solution explicitly; Pulse owns the outbound telemetry pipeline.
- [x] Sampling is a Pulse-runtime concern — the OTel-native, backend-agnostic path (D2/D4), not an App Insights post-ingest concern.
- [x] `HoneyDrunk.Telemetry.Sampling` is a same-Node package composed into `HoneyDrunk.Telemetry.Sink.AzureMonitor` — no cross-Node boundary crossed.

## Acceptance Criteria
- [ ] `HoneyDrunk.Telemetry.Sampling` exists as a new project in the `HoneyDrunk.Pulse` solution
- [ ] An adaptive base sampler wraps `TraceIdRatioBased` with dynamic-rate behavior targeting ~5 items/s per host, under a `ParentBased` boundary
- [ ] Error spans (`success=false` / `error=true`) sample at 100% via an end-of-span `SpanProcessor`
- [ ] `HoneyDrunk.Audit` telemetry, billing-event spans, and canary runs sample at 100%, keyed on documented `service.name` / span attributes / markers
- [ ] High-volume background workloads (Pulse collector, Knowledge ingestion) sample at a stricter rate via a `service.name`-keyed `TraceIdRatioBased` under `ParentBased`
- [ ] The sampler composition is wired into the `HoneyDrunk.Telemetry.Sink.AzureMonitor` `TracerProvider` builder via the packet-03 seam
- [ ] Metrics and logs are untouched — only the trace path is sampled (D4)
- [ ] `HoneyDrunk.Telemetry.Sampling.Tests.Unit` covers each sampling rule's decision; tests use no external services (invariant 15) and no `Thread.Sleep` (invariant 51)
- [ ] Every new public member has XML documentation (invariant 13)
- [ ] No version bump — packet 03 already bumped the solution this initiative; this packet appends to the repo-level `CHANGELOG.md` in-progress version entry (invariant 27)
- [ ] `HoneyDrunk.Telemetry.Sampling` ships with `CHANGELOG.md` and `README.md` from the first commit (invariant 12)
- [ ] The solution builds; existing unit and canary tests pass

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0040 D4 — Sampling: OpenTelemetry samplers and processors, with rules.** Sampling is configured via OpenTelemetry primitives — a custom `Sampler` composed into the `TracerProvider` and `SpanProcessor` filters wired alongside. The Azure Monitor exporter respects whatever sampler the OTel SDK is configured with. Default sampler: `ParentBased(TraceIdRatioBased)` targeting ~5 items/second per host, implemented as a small custom sampler wrapping `TraceIdRatioBased` with dynamic-rate behavior, in a new `HoneyDrunk.Telemetry.Sampling` package in the Pulse solution. Rules: 100% for `success=false`/`error=true` spans (end-of-span `SpanProcessor`); 100% for `HoneyDrunk.Audit` telemetry; 100% for billing-event spans (ADR-0037); 100% during canary runs; lower-rate for high-volume background workloads (Pulse collector, Knowledge ingestion batch jobs) via a stricter `TraceIdRatioBased` under a `ParentBased` boundary keyed on `service.name`. Metrics and logs are not sampled. Classic App Insights SDK constructs like `ITelemetryProcessor` are not used.

**ADR-0040 D2 — Reversibility.** The sampling decisions are made by the OTel SDK, not the exporter or App Insights post-ingest — so a backend swap preserves the sampling logic unchanged.

## Constraints
> **Invariant 13 — All public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards`.

> **Invariant 15 — Unit tests never depend on external services.** The Sampling.Tests.Unit project exercises sampling decisions in-process with no live App Insights resource.

> **Invariant 27 — All projects in a solution share one version and move together.** Packet 03 already bumped the `HoneyDrunk.Pulse` solution this initiative. This packet does NOT bump again — it appends to the repo-level `CHANGELOG.md` under the existing in-progress version entry.

> **Invariant 51 — Test code contains no `Thread.Sleep`.** The adaptive-rate sampler's timing behavior is tested with controllable time abstractions or synchronously-completing fakes, never `Thread.Sleep`.

- **OTel-native only.** No `ITelemetryProcessor`, no classic App Insights SDK constructs — D4 forbids them; they undercut D2's reversibility.
- **Error sampling is end-of-span.** `success`/`error` is known only when the span closes — the error rule is a `SpanProcessor`, not a span-start `Sampler`.
- **No version bump.** Append to the CHANGELOG; do not bump.

## Labels
`feature`, `tier-2`, `ops`, `adr-0040`, `wave-3`

## Agent Handoff

**Objective:** Implement `HoneyDrunk.Telemetry.Sampling` — the adaptive trace sampler and the always-sample rule chain — and wire it into the `HoneyDrunk.Telemetry.Sink.AzureMonitor` `TracerProvider`.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Apply ADR-0040 D4's sampling policy — keep cost down without losing the signals that matter (errors, Audit, billing, canaries always sampled).
- Feature: ADR-0040 Telemetry Backend and Retention rollout, Wave 3.
- ADRs: ADR-0040 D4 (primary; amended 2026-05-22 — package lives in the Pulse solution), ADR-0037 (the billing-event spans the rule chain pins at 100%).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:03` — hard. The sampler composes into the `TracerProvider` builder seam `HoneyDrunk.Telemetry.Sink.AzureMonitor` exposes.

**Constraints:**
- OTel-native primitives only — no classic App Insights `ITelemetryProcessor`.
- Error sampling is end-of-span (`SpanProcessor`); Audit/billing/canary are span-start (chained `Sampler`).
- No version bump — packet 03 already bumped the solution; append to the CHANGELOG.
- Metrics and logs are not sampled — trace path only.
- Packet 05 also touches `Sink.AzureMonitor` — packet 05 is sequenced after this packet (it depends on `work-item:04`). Land this packet first; packet 05 rebases on it.

**Key Files:**
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sampling/` (new project + `CHANGELOG.md` + `README.md`)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sampling.Tests.Unit/` (new)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor/` — composition wiring
- Repo-level `CHANGELOG.md`; the `.slnx`

**Contracts:** None changed — internal sampler types composed into the OTel `TracerProvider`.
