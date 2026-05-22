# Dispatch Plan — ADR-0040: Telemetry Backend and Retention

**Initiative:** `adr-0040-telemetry-backend`
**ADR:** ADR-0040 (Proposed → Accepted via packet 00)
**Sector:** Ops / cross-cutting
**Created:** 2026-05-22

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

> **Amendment 2026-05-22:** A refinement review found the original dispatch assigned outbound-telemetry export to `HoneyDrunk.Observe`. Corrected — Pulse owns outbound telemetry routing per the Observe/Pulse boundary docs. Packets 03/04/05/07 retarget to `HoneyDrunk.Pulse`; ADR-0040 was amended in step. Packet 03 now *extends* the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider rather than creating a package; the sampler becomes a new `HoneyDrunk.Telemetry.Sampling` package in the Pulse solution. Packet 03 is now the first/version-bumping packet on the Pulse solution; packets 04/05/07 append. The Observe-vs-Pulse boundary ambiguity is resolved and no longer needs an operator decision.

## Summary

ADR-0040 selects **Azure Monitor + Application Insights** as the Grid's telemetry backend for traces, metrics, and logs, with `HoneyDrunk.Pulse` as the OTLP-only telemetry boundary and the Azure Monitor OpenTelemetry Distro as the connector behind the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider. The ADR was revised in PR #164 to pivot from a Grafana Cloud + Sentry framing to the cheaper, already-paid Azure path (Grafana + Sentry become the documented D11 escalation path).

This initiative delivers: the per-environment App Insights resource provisioning (`dev` now, staging/prod deferred per ADR-0033), the extension of `HoneyDrunk.Telemetry.Sink.AzureMonitor` with the Azure Monitor OTel Distro backing, the new `HoneyDrunk.Telemetry.Sampling` adaptive sampler + rules, the PII redaction processors + shared scrubber + volume-discipline canary, the Log Analytics per-table retention (730-day Audit table), the Pulse derived-metric stream emit, and the Azure Monitor Alerts + operator channel.

**9 packets across 3 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Pulse`). 6 `Actor=Agent` (00, 01, 03, 04, 05, 07), 3 `Actor=Human` (02, 06, 08).

## Trigger

ADR-0040 is Proposed with no scope. The forcing functions (from the ADR's Context): the AI-sector standup wave emits trace volume against a Pulse sink layer with no concrete backend (fails the standup canary by definition); Notify Cloud GA needs retained, queryable signals. The ADR needs decomposition into actionable packets.

## Scope Detection

**Multi-repo.** ADR-0040 touches `HoneyDrunk.Pulse` (the OTLP telemetry boundary — extends the AzureMonitor sink, gains the `Telemetry.Sampling` package, the PII processors, the shared scrubber, and the D7 derived-metric emit) and `HoneyDrunk.Architecture` (catalogs, invariants, infra walkthroughs, `business/context/`). No contract cascade to downstream Nodes — Nodes emit OTLP through the existing Pulse sink surface; the backend is composed at the Pulse host (D2's reversibility property), so consuming Nodes need no change.

## Wave Diagram

### Wave 1 (No Dependencies — governance + provisioning kickoff)
- [ ] **00** — Architecture: Accept ADR-0040, add telemetry invariants 69/70/71, register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: record the telemetry backend, the `HoneyDrunk.Telemetry.Sampling` package, and the retention policy in the Grid catalogs and grid-health readout. `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: author the App Insights provisioning walkthrough and provision the `dev` telemetry resource. `Actor=Human`. Blocked by: 00.

### Wave 2 (Depends on Wave 1 — the core Pulse backing)
- [ ] **03** — Pulse: extend `HoneyDrunk.Telemetry.Sink.AzureMonitor` — the OTLP-to-App-Insights telemetry backing. `Actor=Agent`. Blocked by: 00, 02. First/version-bumping packet on the Pulse solution.

### Wave 3 (Depends on Wave 2 — sampling, PII, retention, Pulse-emit, alerting)
- [ ] **04** — Pulse: implement `HoneyDrunk.Telemetry.Sampling` — the adaptive sampler and always-sample rules. `Actor=Agent`. Blocked by: 03.
- [ ] **05** — Pulse: implement the PII span/log processors, the shared scrubber, and the volume-discipline canary. `Actor=Agent`. Blocked by: 03, **04**.
- [ ] **06** — Architecture: configure Log Analytics per-table retention — 730 days for the Audit table. `Actor=Human`. Blocked by: 02. (Soft coordination with 05 on table names.)
- [ ] **07** — Pulse: add the Pulse derived-metric stream emit per D7. `Actor=Agent`. Blocked by: 03.
- [ ] **08** — Architecture: wire Azure Monitor Alerts and the Studio operator alert channel. `Actor=Human`. Blocked by: 02.

Packets within a wave run in parallel **except 04 and 05**, which are serialized: both modify `HoneyDrunk.Telemetry.Sink.AzureMonitor`, so 05 is `Blocked by: 04` to avoid a merge conflict on the shared project — land 04 first, 05 rebases. Wave-3 packets 06, 07, 08 are independent of each other and of 04/05. Packet 07 is an intra-Pulse change (it consumes packet 03's extended sink); it can run alongside 04/05 since it touches the Collector path, not `Sink.AzureMonitor`.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0040](./00-architecture-adr-0040-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Telemetry catalog + grid-health readout](./01-architecture-telemetry-catalog-and-grid-health-readout.md) | Architecture | Agent | 1 | 00 |
| 02 | [App Insights provisioning walkthrough](./02-architecture-application-insights-provisioning-walkthrough.md) | Architecture | Human | 1 | 00 |
| 03 | [Extend Sink.AzureMonitor — OTel Distro backing](./03-pulse-azure-monitor-otel-distro-backing.md) | Pulse | Agent | 2 | 00, 02 |
| 04 | [Telemetry.Sampling package + rules](./04-pulse-sampling-package-and-rules.md) | Pulse | Agent | 3 | 03 |
| 05 | [PII processors + shared scrubber + canary](./05-pulse-pii-processors-and-volume-discipline-canary.md) | Pulse | Agent | 3 | 03, 04 |
| 06 | [Log Analytics retention + Audit table](./06-architecture-log-analytics-retention-and-audit-table.md) | Architecture | Human | 3 | 02 |
| 07 | [Pulse derived-metric stream](./07-pulse-derived-metric-stream.md) | Pulse | Agent | 3 | 03 |
| 08 | [Azure Monitor Alerts + operator channel](./08-architecture-azure-monitor-alerts-and-operator-channel.md) | Architecture | Human | 3 | 02 |

## Version Bumps

- **`HoneyDrunk.Pulse`** — packet 03 is the first packet on the solution this initiative; it bumps the version (minor — the `Sink.AzureMonitor` provider gains a real backend). Packets 04, 05, and 07 append to the CHANGELOG only (invariant 27) — they do NOT bump again.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance edits only.

## Invariant Numbering

Packet 00 adds invariants **69, 70, 71** — the pre-reserved block for ADR-0040 as part of a 12-ADR batch. The current highest invariant in `constitution/invariants.md` is 51. If any invariant above 51 lands from outside this batch before merge, shift this block upward — never reuse a number.

## Cross-Cutting Concerns

### Coordination with ADR-0045 (Grid-Wide Error Tracking) — IMPORTANT

ADR-0045 is a sibling observability ADR, pivoted to Azure Monitor in the same PR (#164), scoped immediately after this initiative. The two share infrastructure and must be coordinated:

- **Shared App Insights resource.** ADR-0045 D2 captures errors into **the same Application Insights resource** ADR-0040 provisions. ADR-0040 packet 02 is the single provisioning packet — ADR-0045 must NOT provision a second resource; its scope should depend on / reference ADR-0040 packet 02 (cross-initiative reference once filed: `Architecture#<packet-02-issue-number>`).
- **Shared package `HoneyDrunk.Telemetry.Sink.AzureMonitor`.** ADR-0045 D3 extends *this same Pulse provider* with App-Insights-SDK-based error capture (`IErrorReporter`). ADR-0040 packet 03 extends the provider with the OTel Distro backing; ADR-0045's error-backing packet builds further on it. **The version-bump rule (invariant 27) interacts:** if both initiatives land work on `HoneyDrunk.Pulse` close together, only the first packet on the solution bumps; the others append. Sequence ADR-0045's Pulse work *after* ADR-0040's Wave 2/3 so the bump ownership is unambiguous, OR have ADR-0045's first Pulse packet explicitly check the in-progress version state.
- **Shared PII scrubber — handled.** ADR-0045 D7 reuses the PII-scrubbing pipeline. ADR-0040 packet 05 now builds the regex scrubber as a **shared, mechanism-agnostic component in `HoneyDrunk.Telemetry.Sink.Shared`** — no OTel or App Insights type in its signature — precisely so ADR-0045's error path can consume it without refactoring packet 05's code. ADR-0040 packet 05's OTel `SpanProcessor`/`LogRecordProcessor` use the shared scrubber; ADR-0045's error-path processor (whether OTel-native or App-Insights-SDK `ITelemetryProcessor`, per its D7) will *also* use it. The processor *type* may legitimately differ between the OTLP path and the SDK error path — but the redaction logic is shared and not duplicated.
- **Shared invariant numbering.** ADR-0040 packet 00 adds invariants 69-71 (its pre-reserved block); ADR-0045 adds its own invariant from its own pre-reserved block. No collision — the 12-ADR batch pre-reserves disjoint ranges. Land ADR-0040 packet 00 before ADR-0045's acceptance packet to keep the file's append order clean.
- **Shared invariant text overlap.** ADR-0040's invariant 69 ("no Node references a backend directly") and ADR-0045's "errors flow through `IErrorReporter`, never via direct backend SDK calls" are the same principle for two signal types — they should read as complementary. ADR-0045 scoping should reference invariant 69 rather than restate it loosely.
- **Co-landing recommendation:** land ADR-0040 fully (or at least Waves 1–2) before ADR-0045's Pulse packets. The clean ordering is: ADR-0040 packet 00 + 02 + 03 → ADR-0045 can then build on the provisioned resource and the extended `Sink.AzureMonitor` provider.

### Site sync

No site-sync flag. ADR-0040 is internal Ops infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; invariants and catalog entries removed. No runtime impact.
- **Packet 02 (provisioning):** the `dev` App Insights resource and Log Analytics workspace can be deleted in the portal; the Vault secret revoked. Low cost, easily reversed.
- **Packets 03–05, 07 (Pulse code):** revert the PRs; the `HoneyDrunk.Pulse` solution version is rolled back. No consuming Node depends on the extended sink at runtime until a host composes it — so a revert is contained to Pulse.
- **Packet 06 (retention):** per-table retention is a portal setting — revert to the 90-day default; the Audit table can keep its data.
- **Packet 07 (Pulse derived-metric emit):** revert the PR; the emit is additive — Pulse's own durable store is untouched, so reverting drops only the App Insights metric stream.
- **Packet 08 (alerts):** delete the alert rules and action group in the portal; revert the `business/context/` edit.
- **Backend-level escape hatch:** ADR-0040 D11's escalation path (Grafana Cloud + Sentry) is the architectural rollback for the *backend choice itself* — a single Pulse-side configuration change, by design.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
