---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0040", "wave-1"]
dependencies: []
adrs: ["ADR-0040"]
accepts: ["ADR-0040"]
wave: 1
initiative: adr-0040-telemetry-backend-and-retention
node: honeydrunk-architecture
---

# Accept ADR-0040 — flip status, add the three telemetry invariants, register the initiative

## Summary
Flip ADR-0040 (Telemetry Backend and Retention) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the three new telemetry invariants ADR-0040 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0040-telemetry-backend-and-retention` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0040 selects the Grid's telemetry backend and retention policy. It was authored 2026-05-21 in a batch of cross-cutting Grid-gap ADRs and revised in PR #164 to pivot from a Grafana Cloud + Sentry framing to **Azure Monitor + Application Insights** as the v1 backend. The ADR decides:

- **D1** — Azure Monitor + Application Insights as the single telemetry backend for traces, metrics, and logs (errors covered by ADR-0045). Per-environment App Insights resources (`hd-dev`, `hd-staging`, `hd-prod`); connection strings in Vault per ADR-0005.
- **D2** — `HoneyDrunk.Pulse` is the OTLP-only telemetry boundary; the Azure Monitor OpenTelemetry Distro is the connector behind the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider, living inside the Pulse runtime. Backend swaps are a single Pulse-side config change.
- **D3** — three signal types, three retention windows: traces 90 days, metrics 93 days, logs 90 days standard / **730 days for Audit-sourced logs** (one Log Analytics workspace, per-table retention policy).
- **D4** — sampling via OpenTelemetry samplers/processors: `ParentBased(TraceIdRatioBased)` base at ~5 items/s, with 100%-sampling rules for errors, Audit, billing-event spans, and canary runs.
- **D5** — tenant scoping via a `tenant.id` custom dimension on every multi-tenant signal.
- **D6** — volume discipline: high-cardinality ids belong on traces not metrics; no `Information`-level events in hot loops.
- **D7** — Pulse derived-metric stream: Pulse keeps its own durable store and *also* emits a derived metric stream through its Azure Monitor sink into App Insights (intra-Pulse change).
- **D8** — Azure Monitor Alerts with action groups; operator channel for Grid-internal alerts; no PagerDuty at solo scale.
- **D9** — PII carve-outs via OTel `SpanProcessor` / `LogRecordProcessor`; prompt/completion content forbidden except behind the `HoneyDrunk.Evals` `evals.sensitive=true` carve-out routed to a dedicated table.
- **D10** — $100/month cost ceiling; realistic v1 cost $0–30/month.
- **D11** — documented escalation path to Grafana Cloud + Sentry, signal-by-signal, with explicit triggers.

ADR-0040 is a **policy / decision** ADR. The concrete code — the Azure Monitor OTel Distro wiring, the sampling composition, the PII processors, and the Pulse derived-metric emit — lands in `HoneyDrunk.Pulse` in this initiative (packets 03–05, 07). The App Insights resource provisioning and the Audit-table retention configuration are human/portal work and land as `Actor=Human` packets (02, 06). Catalog and `business/context/` updates land as packets 01, 08.

Every other packet in this initiative references ADR-0040's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0040-telemetry-backend-and-retention.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0040 row Status column to Accepted.
- `constitution/invariants.md` — add the three new telemetry invariants ADR-0040 commits (see Proposed Implementation for exact text) as **invariants 69, 70, 71** — the pre-reserved block for this ADR.
- `initiatives/active-initiatives.md` — register the `adr-0040-telemetry-backend-and-retention` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0040 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0040 index row in `adrs/README.md` to Accepted.
3. Add three new invariants to `constitution/invariants.md` as **invariants 69, 70, 71**. The text, taken verbatim-in-substance from ADR-0040's Consequences "Invariants" subsection:
   - **69. No Node references Application Insights or any telemetry backend directly.** All telemetry routes through the `HoneyDrunk.Pulse` sink surface; backend changes (including the D11 escalations) are a single Pulse configuration change with zero Node-level work. See ADR-0040 D1, D2, D11.
   - **70. High-cardinality identifiers belong on traces and logs, never duplicated as custom dimensions on metrics.** Specifically `user.id`, `message.id`, and `request.id` are trace/log dimensions only — putting them on metrics inflates ingest volume for no analytical gain. See ADR-0040 D6.
   - **71. Prompt and completion text appears in telemetry only behind the `evals.sensitive=true` custom dimension and the dedicated Log Analytics table.** Telemetry is default-deny for user-typed content and model outputs; `HoneyDrunk.Evals` is the only opt-in carve-out. See ADR-0040 D9.
   - Add them under a new `## Telemetry Invariants` section, or the closest existing section, matching the file's current sectioning convention. Numbers 69, 70, 71 are pre-reserved for ADR-0040 as part of a 12-ADR batch; the file's current highest invariant is 51. **If any invariant above 51 lands from outside this batch before merge, shift this block upward — never reuse a number.**
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0040-telemetry-backend-and-retention.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0040 header reads `**Status:** Accepted`
- [ ] The ADR-0040 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the three new telemetry invariants as **invariants 69, 70, 71** (no Node references a backend directly; high-cardinality ids on traces/logs not metrics; prompt/completion content only behind `evals.sensitive=true`), each citing ADR-0040
- [ ] `initiatives/active-initiatives.md` registers the `adr-0040-telemetry-backend-and-retention` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0040 D1 — Backend: Azure Monitor + Application Insights.** Single vendor, already-paid Azure relationship. Per-environment App Insights resources (`hd-dev`, `hd-staging`, `hd-prod`); connection strings in Vault per ADR-0005.

**ADR-0040 D2 — Pulse is the OTLP-only telemetry boundary; the Azure Monitor OpenTelemetry Distro is the connector.** The exporter sits inside the Pulse Node's runtime (the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider), never in the consuming Node. Switching backends is a configuration change at Pulse only.

**ADR-0040 Consequences — Invariants.** ADR-0040 adds exactly three invariants, numbered 69-71 (pre-reserved): (69) no Node references App Insights or any backend directly; (70) high-cardinality identifiers belong on traces and logs, not duplicated as custom dimensions on metrics; (71) prompt/completion text appears in telemetry only behind the `evals.sensitive=true` dimension and the dedicated Log Analytics table.

## Constraints
- **Acceptance precedes flip.** ADR-0040 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Use invariants 69, 70, 71 — the pre-reserved block.** Do not renumber existing invariants; append. Numbers 69-71 are pre-reserved for ADR-0040 as part of a 12-ADR batch; the file's current highest invariant is 51. If any invariant above 51 lands from outside this batch before merge, shift this block upward — never reuse a number.
- **Coordinate with ADR-0045.** ADR-0045 (Grid-Wide Error Tracking) is a sibling observability ADR on the same Azure Monitor backend, scoped immediately after this initiative. It adds one more invariant (errors flow through `IErrorReporter`, never via a direct backend SDK call) from its own reserved block. Leave the file in a clean append-only state.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0040`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0040 to Accepted, add the three telemetry invariants to `constitution/invariants.md`, and register the telemetry-backend initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0040 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0040 Telemetry Backend and Retention rollout, Wave 1.
- ADRs: ADR-0040 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0040 stays Proposed until this PR merges.
- Add the three new invariants as **invariants 69, 70, 71** — the pre-reserved block for ADR-0040 (a 12-ADR batch; current highest invariant is 51). Do not renumber existing invariants. If any invariant above 51 lands from outside the batch before merge, shift this block upward — never reuse a number.

**Key Files:**
- `adrs/ADR-0040-telemetry-backend-and-retention.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
