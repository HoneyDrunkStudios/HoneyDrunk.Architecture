---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0045", "wave-4"]
dependencies: ["work-item:00"]
adrs: ["ADR-0045", "ADR-0015"]
accepts: ["ADR-0045"]
wave: 4
initiative: adr-0045-grid-wide-error-tracking
node: honeydrunk-architecture
---

# Author the deployable-Node error-wiring playbook for Phase 2/3 rollout

## Summary
Author a short, reusable playbook (in `infrastructure/` or the Grid's established standup-doc location) that tells any deployable Node — Notify.Functions, Notify.Worker, Pulse.Collector now (D10 Phase 2), and every AI-sector Seed Node at standup (D10 Phase 3) — exactly how to wire `IErrorReporter` via its existing Pulse telemetry dependency. This packet does not modify any Node; it produces the canonical wiring instructions so Phase 2/3 rollout does not need a separate scope pass per Node.

## Context
ADR-0045 D10 stages the rollout:
- **Phase 2** — Notify.Functions, Notify.Worker, Pulse.Collector wire `IErrorReporter` via their existing Pulse telemetry dependency.
- **Phase 3** — every AI-sector Seed Node (ADR-0016 through ADR-0025) wires `IErrorReporter` from day one at standup; error capture is part of the standup canary.

The per-Node wiring is mechanically identical: depend on Pulse's telemetry packages, register the AzureMonitor sink backing in the host composition, inject `IErrorReporter`, route capture-eligible failures (per D8) through it. Writing a separate scoped packet for each of Notify.Functions / Notify.Worker / Pulse.Collector — and pre-writing packets for nine AI Nodes that are not yet stood up — would be premature decomposition (the AI-sector Nodes get their own standup ADRs/initiatives per the Grid's New-Node-scaffold convention; bundling error-wiring into a not-yet-existing repo is wrong).

Instead, this packet produces **one canonical playbook**. Phase 2's three deployable wirings are then small, near-mechanical changes a future packet (or the operator directly) applies by following the playbook; each AI-Node standup ADR references the playbook as a standup-canary step. This keeps the ADR-0045 initiative focused on the substrate (the facade, the backing, the Notify migration, the deploy-flow change, the governance docs) and defers the repetitive per-Node application to where it belongs — the Node's own work.

**Why not wire Notify.Functions/Worker and Pulse.Collector in this initiative directly?** Notify.Functions and Notify.Worker are part of the `HoneyDrunk.Notify` solution — packet 05 already migrates Notify and bumps that solution; a separate later packet touching the same solution would collide on the version-bump rule (invariant 27). The cleanest path is: packet 05 wires the Notify *core* error path, and the playbook covers any host-composition follow-up so it lands in the same Notify solution version or a clearly-sequenced later one. Pulse.Collector is part of the `HoneyDrunk.Pulse` solution — packets 02 and 03 already bump that solution; Pulse.Collector's own host-composition wiring follows the playbook as a near-mechanical change.

**This is a docs packet. No code, no .NET project.**

## Scope
- A deployable-Node error-wiring playbook doc, in the Grid's established location for cross-Node standup/wiring guidance (check `infrastructure/`, a `standards/`-style doc, or wherever the Pulse-telemetry-consumption guidance lives — match the existing convention; do not invent a location).

## Proposed Implementation
Author the playbook covering, concisely:
1. **Dependency** — the Node depends on Pulse's telemetry packages; `IErrorReporter` comes from `HoneyDrunk.Telemetry.Abstractions` transitively.
2. **Host registration** — the deployable's host composition registers the `HoneyDrunk.Telemetry.Sink.AzureMonitor` backing (the same registration that wires traces/metrics/logs per ADR-0040 also wires `IErrorReporter` per ADR-0045 D5 — one Pulse telemetry registration covers all four signal types). The App Insights connection string is Vault-resolved by the backing; the Node itself touches no telemetry secret.
3. **Injection** — inject `IErrorReporter` where errors are captured.
4. **The D8 capture decision** — route only capture-eligible failures (per the D8 mapping — cross-reference packet 06's `review.md` sub-rubric) through `IErrorReporter`; recoverable retries and inbound-validation failures stay log-only.
5. **`ErrorContext` population** — `TraceId` from the ambient `Activity`, `TenantId`/`UserId` (opaque `PrincipalId`) from the Grid context, `Release` from the deployable version.
6. **Release annotation** — the deployable's release workflow opts into the App Insights release-annotation step (packet 04's new workflow inputs) so captured exceptions' `application_Version` lines up with a trend-graph annotation.
7. **Standup canary (Phase 3)** — for an AI-sector Node, error capture is part of the standup canary: the canary throws a controlled exception and asserts it lands in App Insights Failures. Reference this as a standup-ADR checklist item.
8. **Per-Node opt-out** — the rare case (D5): a Node configures Pulse telemetry to suppress error reporting (e.g. `HoneyDrunk.Architecture` itself runs no user-facing code). Document the opt-out config.

The playbook explicitly lists the Phase 2 deployables (Notify.Functions, Notify.Worker, Pulse.Collector).

## Affected Files
- A deployable-Node error-wiring playbook doc in the established cross-Node-guidance location.

## NuGet Dependencies
None. This packet is a documentation deliverable; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` — cross-Node standup/wiring guidance lives here.
- [x] No code change in any Node — the playbook is instructions; the application is each Node's own work.
- [x] Deliberately does not pre-scope per-Node packets — AI-sector Nodes get error-wiring as a standup-ADR checklist item, not a pre-written packet against a non-existent repo.

## Acceptance Criteria
- [ ] A deployable-Node error-wiring playbook exists in the Grid's established cross-Node-guidance location, covering: the Pulse telemetry dependency, host registration, `IErrorReporter` injection, the D8 capture decision, `ErrorContext` population, the release-annotation opt-in, the Phase 3 standup canary, and per-Node opt-out
- [ ] The playbook lists the Phase 2 deployables (Notify.Functions, Notify.Worker, Pulse.Collector)
- [ ] The playbook cross-references packet 06's D8 `review.md` sub-rubric and packet 04's release-annotation workflow inputs
- [ ] The playbook is concise — it is a wiring checklist, not a tutorial
- [ ] No code change, no per-Node packet pre-written for not-yet-stood-up AI Nodes

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0045 D10 Phase 2 — Rollout to deployable Nodes.** Notify.Functions, Notify.Worker, Pulse.Collector wire `IErrorReporter` via their existing Pulse telemetry dependency.

**ADR-0045 D10 Phase 3 — AI-sector standup wave.** Every Seed-sector AI Node wires `IErrorReporter` from day one at standup; error capture is part of the standup canary; the agent-execution-loop breadcrumb usage is the high-value error-tracking surface.

**ADR-0045 D5 — Per-Node opt-in via Pulse configuration.** All Nodes consuming Pulse get error reporting once the backing is wired; opt-out is per Node via configuration (rare — e.g. `HoneyDrunk.Architecture`).

**ADR-0045 D6 — Release tracking.** Captured exceptions carry `application_Version`; the deploy workflow's release-annotation step (packet 04) marks the trend graph.

**ADR-0015 — Container hosting.** The Phase 2 deployables run on Azure Container Apps.

## Constraints
- **Playbook, not per-Node packets.** Do not pre-write error-wiring packets for AI-sector Nodes that are not yet scaffolded — a New-Node scaffold is its own ADR/initiative. The playbook is referenced by each Node's standup ADR.
- **Concise.** A wiring checklist, not a tutorial — match the length and tone of the Grid's existing standup/wiring docs.
- **One Pulse telemetry registration, four signal types.** The playbook makes clear that the ADR-0040 Pulse telemetry registration and the ADR-0045 `IErrorReporter` registration are the same registration call — traces/metrics/logs/errors all wired together.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0045`, `wave-4`

## Agent Handoff

**Objective:** Author the canonical deployable-Node error-wiring playbook so Phase 2/3 `IErrorReporter` rollout is a mechanical per-Node application, not a fresh scope pass.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Capture the mechanically-identical `IErrorReporter` wiring once, so Phase 2 deployables and Phase 3 AI-Node standups apply it from a checklist.
- Feature: ADR-0045 Grid-Wide Error Tracking rollout, Wave 4.
- ADRs: ADR-0045 D5/D6/D10 (primary), ADR-0015 (Container Apps deployables).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0045 should be Accepted before its rollout playbook lands. Independent of packets 02–06 — can run in parallel.

**Constraints:**
- Playbook only — no per-Node packets pre-written for non-existent AI repos.
- Concise wiring checklist; one Pulse telemetry registration covers all four signal types.

**Key Files:**
- A deployable-Node error-wiring playbook in the established cross-Node-guidance location.

**Contracts:** None changed.
