---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0045", "wave-4"]
dependencies: ["work-item:00"]
adrs: ["ADR-0045", "ADR-0044", "ADR-0040"]
accepts: ["ADR-0045"]
wave: 4
initiative: adr-0045-grid-wide-error-tracking
node: honeydrunk-architecture
---

# Add the D8 capture-vs-log mapping to review.md and document the D11 escalation triggers

## Summary
Two governance documentation tasks from ADR-0045's Follow-up Work: (1) extend the Observability category of `.claude/agents/review.md` with the ADR-0045 D8 capture-an-error-vs-log-a-line mapping so the review agent enforces it per Node, and (2) document the four D11 Sentry-escalation triggers in `business/context/` so the operator can recognize when v1 App Insights stops earning its keep.

## Context
ADR-0045's Follow-up Work names two doc tasks:
- "Update `.claude/agents/review.md` D3 Observability category with the D8 capture-vs-log mapping." ADR-0045 D8 says: "The detailed checklist per Node lives in `.claude/agents/review.md` per ADR-0044 D3's Observability category. This ADR binds the principle; the agent file binds the per-case mapping."
- "Document the D11 escalation triggers in `business/context/` so the operator can recognize them."

`.claude/agents/review.md` is the review-agent rubric established by ADR-0044 (the cloud-code-review initiative — see sibling folder `adr-0044-cloud-code-review/`, packets 04 and 09 which built and rolled out the D3 rubric). ADR-0044's D3 rubric has an Observability category; this packet adds the error-capture sub-rubric to it.

`business/context/` is where the Grid keeps operator-facing context notes (the ADR-0040 cost-ceiling tracking lives there per ADR-0040 packet 08). The D11 escalation triggers are operator-facing — the operator must recognize the symptom and know the response is "amend the ADR, move errors to Sentry."

**This is a docs/governance packet. No code, no .NET project.** It depends only on packet 00 (ADR-0045 Accepted) — independent of the Pulse/Notify/Actions implementation packets, so it can run in parallel with them in Wave 4.

## Scope
- `.claude/agents/review.md` — extend the Observability category with the D8 capture-vs-log error sub-rubric.
- A note in `business/context/` documenting the four D11 escalation triggers.

## Proposed Implementation
1. **`.claude/agents/review.md` — D8 error-capture sub-rubric.** Locate the Observability category in the D3 rubric (established by ADR-0044 packet 04, rolled out by packet 09). Add a sub-rubric the review agent applies to PRs touching error-handling code. The checklist, from ADR-0045 D8 verbatim-in-substance:
   - **Capture as an error (via `IErrorReporter`):** uncaught or programmatic exceptions in business logic; failed dependency calls (LLM provider 5xx, downstream Node call failures) the caller cannot recover from in-line; failed agent tool dispatch with no retry path remaining; failed billing meter-event push to Stripe after retries (ADR-0037); Audit write failures (ADR-0030 — also incidents).
   - **Log to Log Analytics at ERROR level only (do NOT capture as error):** recoverable errors retries handled successfully; inbound-request validation failures (the caller's problem); expected 4xx outcomes from external APIs; deserialization failures on poison messages (a dead-letter-queue concern per ADR-0028 — capture the DLQ event, not the deserialization).
   - **Both (capture as error AND log an ERROR line):** anything in the capture list also produces an ERROR log line — the log for the forensic timeline, the error capture for triage and trend; both carry the same `operation_id`.
   - The sub-rubric also checks: error capture goes through `IErrorReporter`, never a direct backend SDK call (the ADR-0045 error-flow invariant); prompt/completion content is not in a captured exception unless `evals.sensitive=true` (ADR-0045 D7 / ADR-0040 D9).
   - Match the existing rubric's format and severity-tagging convention — do not invent a parallel structure.
2. **`business/context/` — D11 escalation-trigger note.** Add (or extend, if a telemetry/observability operator note already exists from ADR-0040 packet 08) a note documenting the four D11 triggers, each with its symptom and the action:
   - **Error-triage workflow pain** — App Insights' Failures blade insufficient for the volume (estimated threshold: > 50 distinct problem IDs in any 7-day window) → move errors to Sentry; configure `trace_id` cross-link to App Insights traces.
   - **Release-triage workflow pain** — "this regressed in v0.4.2" is a regular need and App Insights' release-annotation UX is the bottleneck → move errors to Sentry; use Sentry's Releases/Suspect-Commits surface.
   - **Tenant-scoped error views needed (Notify Cloud)** — multi-tenant error triage at scale needs Sentry's tag-and-environment filtering → move errors to Sentry; preserve tenant-scoped App Insights traces for context.
   - **AI-sector tool-call breadcrumb depth** — agent-execution failures need the rich breadcrumb chain Sentry handles natively → move errors to Sentry; preserve App Insights for traces/metrics/logs.
   - State the escalation mechanics: `IErrorReporter` and `IErrorSink` stay, the existing `HoneyDrunk.Telemetry.Sink.Sentry` backing is activated as the error sink, the Pulse-level config swap moves errors to Sentry while traces/metrics/logs stay on App Insights. Combined cost at escalation: App Insights (~$30–100/month) + Sentry (free or Team $26/month), within ADR-0040's $100/month ceiling at low volume.
   - Note that D11 is reviewed at D10 Phase 4 (Month 3+) as a go/no-go.

## Affected Files
- `.claude/agents/review.md`
- A D11-escalation note in `business/context/` (new, or an extension of the ADR-0040 telemetry operator note).

## NuGet Dependencies
None. This packet touches only Markdown governance/agent files; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` — `.claude/agents/review.md` and `business/context/` both live here. Routing rule "architecture, ADR, agent, sector → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] The review-agent rubric is the ADR-0044-established surface; this packet extends it, consistent with ADR-0045 D8's explicit instruction.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` Observability category carries the D8 error-capture sub-rubric: the capture-as-error list, the log-only list, the both list, plus the `IErrorReporter`-not-direct-SDK and the `evals.sensitive` content checks
- [ ] The sub-rubric matches the existing rubric's format and severity-tagging convention (ADR-0044 D3)
- [ ] `business/context/` documents the four D11 escalation triggers, each with symptom + action, the escalation mechanics, the combined cost, and the D10 Phase 4 review point
- [ ] If an ADR-0040 telemetry operator note already exists in `business/context/`, the D11 triggers extend it rather than creating a parallel note
- [ ] No invariant change (the error-flow invariant lands in packet 00); no catalog change (catalogs land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0045 D8 — When to capture an error vs. log a line.** Capture-as-error, log-only, and both categories as listed in Proposed Implementation. The principle is ADR-bound; the per-case mapping lives in `.claude/agents/review.md`.

**ADR-0045 D11 — Escalation path: Sentry.** Four documented triggers (error-triage pain > 50 distinct problem IDs/7-day window; release-triage pain; tenant-scoped views for Notify Cloud; AI-sector breadcrumb depth). On any trigger, the next ADR amendment moves errors to Sentry; `IErrorReporter`/`IErrorSink` stay, the existing `HoneyDrunk.Telemetry.Sink.Sentry` backing is activated as the error sink, the swap is a Pulse-level config change. Reviewed at D10 Phase 4.

**ADR-0044 D3 — the review-agent rubric.** `.claude/agents/review.md` carries the multi-category review rubric, including an Observability category. ADR-0045 D8's mapping extends that category.

**ADR-0040 — cost ceiling and operator context.** `business/context/` holds the telemetry cost-ceiling tracking; the D11 cost figures sit within ADR-0040's $100/month ceiling.

## Constraints
- **Extend, do not fork, the review rubric.** The D8 sub-rubric joins the existing Observability category in `.claude/agents/review.md` — match the established format and severity tags (ADR-0044 D3).
- **Operator-facing language for the D11 note.** `business/context/` is read by the operator; the D11 note must let the operator recognize a trigger symptom and know the response.
- **No invariant or catalog change here.** Those land in packets 00 and 01.
- **Coordinate with `hive-sync`.** ADR-0045's invariant note says `hive-sync` reconciles the rubric drift per the ADR-0044 pattern — keep the rubric edit consistent with that mechanism (ADR-0044 packet 17 built the D3 drift detection).

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0045`, `wave-4`

## Agent Handoff

**Objective:** Add the ADR-0045 D8 capture-vs-log mapping to the review-agent rubric and document the four D11 Sentry-escalation triggers for the operator.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the D8 capture-vs-log policy enforceable by the review agent per Node, and make the D11 escalation triggers recognizable by the operator.
- Feature: ADR-0045 Grid-Wide Error Tracking rollout, Wave 4.
- ADRs: ADR-0045 D8/D11 (primary), ADR-0044 (the review-agent rubric this extends), ADR-0040 (operator-context location).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0045 should be Accepted before its policy is bound into the review rubric. Independent of packets 02–05 — can run in parallel.

**Constraints:**
- Extend the existing Observability category — do not fork the rubric.
- Operator-facing language for the D11 note.
- No invariant or catalog change here.

**Key Files:**
- `.claude/agents/review.md`
- `business/context/` (the D11-escalation note)

**Contracts:** None changed.
