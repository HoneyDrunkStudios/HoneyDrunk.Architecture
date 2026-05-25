---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0054", "wave-4"]
dependencies: ["packet:04", "packet:06", "packet:08", "packet:09"]
adrs: ["ADR-0054", "ADR-0036", "ADR-0027", "ADR-0052", "ADR-0037"]
accepts: ["ADR-0054"]
wave: 4
initiative: adr-0054-incident-response
node: honeydrunk-architecture
---

# Author the game-day discipline doc, schedule the first exercise, and update Notify Cloud's draft SLA language

## Summary
Author three closely-related operator-facing artifacts that close ADR-0054's process loop: (1) the **game-day discipline doc** at `business/context/game-day-discipline.md` per ADR-0054 D11 covering the scenario rotation, the 1-week-advance discipline, the post-exercise review process, and the 30-day fix deadline; (2) **the first scheduled game day** dated 30 days after ADR-0054 acceptance per D11, with a chosen scenario; (3) the **Notify Cloud draft SLA language update** per D2 ensuring published SLA reflects 09:00-21:00 ET coverage / 99.5% / 99.0%, the 15-min / best-effort ack split, and the D13 honesty constraint as a sales-conversation rail.

## Context
ADR-0054 commits two operator-facing artifacts that sit at the **end** of the rollout:

- **D11 — Game days.** "Quarterly chaos exercise. The operator manually triggers a known failure mode in a non-production environment (or in production within a coordinated window when the failure mode is safe to trigger) and runs through the incident process end-to-end. First game day target: 30 days after this ADR accepts."
- **D2 — Operator availability windows and SLA implications.** "Published SLA: 99.5% monthly uptime within coverage hours; 99.0% monthly uptime overall. Acknowledgment SLA: 15 min within coverage, best-effort outside. Resolution SLA: commitment varies by severity, with explicit out-of-hours carve-outs. ADR-0027 is a blocker for any tighter SLA than this; revising the SLA upward requires revising this ADR (D13)."

This packet packages both, plus the **D13 honesty-constraint sales-rail** ("Sales conversations referencing tighter SLAs flag this ADR. The operator does not commit to tighter terms verbally or in contract drafts without ADR amendment"), into a single end-of-initiative governance landing.

**Game-day discipline doc.** Lives at `business/context/game-day-discipline.md` (alongside the cost-discipline and other operator-context notes). Covers:

- The seven scenarios from D11 (kill a Container App revision mid-traffic; expire a Vault secret without rotation; OOM a worker process; pull the network from a downstream dependency; simulate a runaway cost incident; simulate an Audit write-path outage; simulate a Stripe webhook failure).
- Discipline:
  - Scenario chosen and documented 1 week in advance.
  - Exercise runs the full D6 lifecycle (page fires → ack → investigate → mitigate → resolve → post-mortem).
  - Post-game-day post-mortem (per D8) identifies process gaps, runbook gaps, tooling gaps.
  - Findings either fixed within 30 days or filed as ADR amendments / issue packets.
- Coordination with ADR-0036 DR drills: "DR drills exercise data recovery; game days exercise process. Some scenarios qualify as both."
- The exercise calendar — quarterly, with a fixed 4-8 hour budget per quarter ("calendared as a fixed obligation, not optional" per D11's Operational Consequences).
- First exercise: dated **30 days after ADR-0054 acceptance** per D11. Pick one of the seven scenarios. **Recommendation: "Kill a Container App revision mid-traffic"** — the lowest-friction first scenario; exercises packet 04 (Notify paging path), packet 06 (Pulse synthetic probe), packet 09 (Azure Monitor alert routing), and packet 08 (incident-record generator) end-to-end without requiring production data risk. The actual exercise is **executed by the human** at the scheduled date (this packet schedules it but does not run it — the run is the Human Prerequisite, with the post-game-day post-mortem authored after).

**Notify Cloud draft SLA language.** Lives wherever the Notify Cloud SLA draft currently lives. Per ADR-0027 (Notify Cloud Standup), Notify Cloud is a Seed Node; its public SLA is being drafted. The draft must reflect ADR-0054 D2's commitments **before** Notify Cloud GA (PDR-0002). The SLA language update covers:

- The 09:00–21:00 ET 7-day coverage window — published, in tenant agreements.
- The 99.5% within-coverage / 99.0% overall monthly uptime targets.
- The 15-min within-coverage / best-effort outside-coverage ack split.
- The resolution SLA carve-outs per severity.
- D13's sales-conversation rail: "Sales conversations referencing tighter SLAs flag this ADR. The operator does not commit to tighter terms verbally or in contract drafts without ADR amendment." This is a process commitment, not customer-visible language — but it lives in the same Notify Cloud SLA / commercial-terms doc as a footer note.
- The D12 forward-looking note: "Tenants requiring 24/7 coverage are not in our addressable market in 2026; the SLA cannot honestly be offered until a second human gains prod credentials." This is a footer / commercial-context note.

**Coordination — Notify Cloud is Seed.** The actual Notify Cloud SLA artifact may not yet exist (ADR-0027 is the standup ADR, which may itself still be in early phases). The packet handles both cases:

- If a Notify Cloud SLA draft exists at edit time, update it.
- If no draft exists, create one at `business/context/notify-cloud-sla-draft.md` (or the equivalent location ADR-0027 establishes) with the D2 commitments as the v1 content. The draft is **internal until Notify Cloud GA**.

**This packet sits at the end of the initiative** because the game-day exercise validates the entire paging substrate built by packets 04-09. The first game day's PR (executed by the human at the scheduled date) is itself a post-mortem-style record of the exercise per D8 / D11.

**This is a docs/governance + scheduling packet.** No code, no .NET project. The first game-day exercise itself is a **Human Prerequisite** (the human runs the exercise on the scheduled date and authors the post-mortem); the packet's deliverable is the doc + the scheduled date + the SLA language.

## Scope
- `business/context/game-day-discipline.md` (new) — the game-day discipline doc covering scenarios, discipline, calendar, and the first exercise.
- The first game-day scheduled date (30 days post-ADR-0054 acceptance) + chosen scenario, recorded in the discipline doc and on the operator's calendar (human prerequisite).
- The Notify Cloud SLA language — update the existing draft if it exists, or create `business/context/notify-cloud-sla-draft.md` if it does not.
- A small sales-conversation rail note (per D13) in the Notify Cloud SLA / commercial-terms doc.

## Proposed Implementation
1. **`business/context/game-day-discipline.md`.** Author the doc covering:
   - **Cadence:** quarterly, 4-8 hours per quarter, calendared as fixed obligation.
   - **The seven scenarios** verbatim from D11.
   - **Discipline:** 1-week-advance scenario announcement; the full D6 lifecycle (page → ack → investigate → mitigate → resolve → post-mortem); the post-game-day post-mortem; the 30-day fix deadline or file-as-amendment.
   - **Coordination with ADR-0036 DR drills.** DR drills exercise data recovery; game days exercise process. The doc lists which scenarios overlap (e.g., "restore a Cosmos DB from backup" is both).
   - **First exercise:** dated 30 days after ADR-0054 acceptance. Scenario: **"Kill a Container App revision mid-traffic"** (recommended — exercises Notify paging path, Pulse synthetic probe, Azure Monitor alert routing, incident-record generator). The scheduled date is computed at packet 00 acceptance time (acceptance date + 30 days) and recorded in the doc. The operator adds the date to the operator calendar (Human Prerequisite).
   - **Subsequent exercises:** quarterly cadence, scenario rotation starting from the first.
   - **Post-exercise post-mortem template.** Cross-link packet 02's blameless post-mortem template; the game-day post-mortem follows the same structure (D8).
2. **Notify Cloud SLA language.** Locate the existing Notify Cloud SLA draft. If it exists, update with the D2 commitments. If it does not exist, create `business/context/notify-cloud-sla-draft.md` with the D2 content as v1:
   - **Coverage:** 09:00–21:00 ET, 7 days a week, paying-tenant SEV-1/2.
   - **Uptime targets:** 99.5% within coverage; 99.0% overall, monthly.
   - **Ack SLA:** 15 min within coverage; best-effort outside coverage.
   - **Resolution SLA:** varies by severity with explicit out-of-hours carve-outs (cross-link the D1 severity table).
   - **D12 forward-looking note:** tenants requiring 24/7 coverage are not in the 2026 addressable market.
   - **D13 sales-conversation rail (footer / commercial-context):** "Sales conversations referencing SLAs tighter than the published commitments flag ADR-0054. The operator does not commit to tighter terms verbally or in contract drafts without ADR amendment. The order is: amend ADR → contract human #2 (D12 trigger) → publish the tighter SLA. Not: publish the SLA → hope to backfill."
3. **D13 honesty-constraint rail.** A small note (or appendix in the Notify Cloud SLA doc) bound to the sales-conversation process. The agent does not edit sales templates or contract templates directly (those are operator-internal commercial documents); the note exists as a reminder. Cross-link to ADR-0054 D13.
4. **Cross-link the game-day discipline doc from the operator-agent prompt (if appropriate).** The operator agent (per packet 11) consults runbooks during incidents; the game-day discipline doc is operator-facing context, not agent-facing. No additional agent-prompt amendment needed — but cross-link the discipline doc from `business/context/`'s index / TOC if one exists.
5. **The first game-day exercise itself is a Human Prerequisite.** This packet schedules it; the human executes it on the scheduled date, authoring the post-mortem at `generated/incidents/post-mortems/<scheduled-date>-game-day-1.md`. The post-mortem PR closes packet 12 in spirit but **not as a packet** — the post-mortem is its own artifact.

## Affected Files
- `business/context/game-day-discipline.md` (new)
- `business/context/notify-cloud-sla-draft.md` (new, or update if existing) — Notify Cloud SLA language
- A cross-link in `business/context/`'s index / TOC if one exists

## NuGet Dependencies
None. This packet creates only markdown governance / context files; no .NET project.

## Boundary Check
- [x] All files in `HoneyDrunk.Architecture/business/context/` — correct home for operator-facing context.
- [x] No code change in any other repo.
- [x] The Notify Cloud SLA draft is operator-internal until Notify Cloud GA; this packet does not edit public-facing customer documents.
- [x] The first game-day exercise is a Human Prerequisite — this packet does not run it.

## Acceptance Criteria
- [ ] `business/context/game-day-discipline.md` exists and covers: quarterly cadence with 4-8 hour budget; the seven D11 scenarios; the discipline (1-week-advance, full D6 lifecycle, post-exercise post-mortem per D8, 30-day fix deadline); coordination with ADR-0036 DR drills; the first exercise scheduled 30 days after ADR-0054 acceptance with scenario "Kill a Container App revision mid-traffic" (recommended); the post-exercise post-mortem template cross-link to packet 02
- [ ] The Notify Cloud SLA draft exists (updated if previously existing; created at `business/context/notify-cloud-sla-draft.md` if not) and reflects: 09:00–21:00 ET 7-day coverage; 99.5% within / 99.0% overall monthly uptime; 15-min / best-effort ack split; per-severity resolution SLA with out-of-hours carve-outs; D12 forward-looking note; D13 sales-conversation rail footer
- [ ] The D13 honesty-constraint rail is recorded in the Notify Cloud SLA / commercial-context doc — "amend ADR → contract human #2 → publish tighter SLA; not: publish → backfill"
- [ ] If a `business/context/` index / TOC exists, it cross-links the game-day discipline doc
- [ ] The first game-day exercise itself is recorded as a Human Prerequisite (the human runs it on the scheduled date and authors the post-mortem); the packet does not run the exercise
- [ ] The first game-day's scheduled date is concrete: `ADR-0054 acceptance date + 30 days`. Compute from the actual ADR acceptance date at edit time and record in the doc

## Human Prerequisites
- [ ] **Execute the first game day on the scheduled date.** ~4-8 hours total: prep, exercise (full D6 lifecycle), post-mortem authoring. The agent cannot kill a Container App revision in mid-traffic (or whatever scenario is chosen); the operator runs the exercise.
- [ ] **Add the scheduled date to the operator calendar.** Block 4-8 hours, marked as a fixed obligation per D11.
- [ ] **Decide whether the Notify Cloud SLA draft is updated or created from scratch.** If ADR-0027's Notify Cloud standup has produced a draft, locate it and update; otherwise create new.
- [ ] **No live customer SLA edit.** Notify Cloud is Seed; no paying tenants yet; the SLA draft is operator-internal until Notify Cloud GA. The agent does not edit any live customer-facing legal document.

## Referenced ADR Decisions
**ADR-0054 D11 — Game days.** Quarterly chaos exercise. Seven scenarios listed verbatim. Discipline: 1-week-advance scenario announcement; exercise runs the full D6 lifecycle; post-exercise post-mortem identifies gaps; findings fixed within 30 days or filed as ADR amendments / issue packets. First game-day target: 30 days after ADR-0054 acceptance. Pairs with ADR-0036 DR drills: DR drills exercise data recovery; game days exercise process; some scenarios qualify as both.

**ADR-0054 D2 — Notify Cloud SLA implications.** Published SLA: 99.5% within-coverage / 99.0% overall monthly uptime. Acknowledgment SLA: 15 min within coverage / best-effort outside. Resolution SLA: per-severity with explicit out-of-hours carve-outs. ADR-0027 is a blocker for any tighter SLA; revising upward requires revising this ADR.

**ADR-0054 D12 — On-call hand-off (forward-looking).** Tenants requiring 24/7 coverage are not in the 2026 addressable market. The trigger: second human with prod credentials + signed contract + PagerDuty onboarding. SLA cannot honestly be offered until that trigger fires.

**ADR-0054 D13 — Honesty about limits.** Published commitments must reflect what one human + AI agents can actually deliver. Sales conversations referencing tighter SLAs flag this ADR; operator does not commit to tighter terms without ADR amendment. The order: amend ADR → contract human #2 → publish tighter SLA. Not: publish → backfill.

**ADR-0054 D6 / D8 — Lifecycle + post-mortem.** The game-day exercise runs the full D6 lifecycle and produces a D8 post-mortem at completion.

**ADR-0036 — DR drills coordination.** DR drills exercise data recovery (restore from backup, fail over); game days exercise process. Some scenarios qualify as both.

**ADR-0027 — Notify Cloud (Seed).** Notify Cloud SLA draft is operator-internal until Notify Cloud GA. This packet updates / creates the draft.

**ADR-0052 — Cost discipline / runaway-cost scenario.** One of the seven game-day scenarios is "simulate a runaway cost incident" — burn budget rapidly to exercise the cost-alert path.

**ADR-0037 — Stripe webhook failure scenario.** One of the seven scenarios — exercises the Stripe-webhook failure path wired in packet 09.

## Constraints
- **First game day scheduled, not executed.** The exercise itself is the Human Prerequisite. The packet's deliverable is the scheduled date + chosen scenario + the doc.
- **Notify Cloud SLA is operator-internal.** No live customer SLA edit; the draft is operator-internal until Notify Cloud GA.
- **D13 sales-conversation rail is a process commitment**, not customer-visible language. The agent does not edit sales templates or contract templates directly — those are operator-internal commercial documents.
- **The scheduled date is concrete.** `ADR-0054 acceptance date + 30 days` — compute from the actual acceptance date.
- **Quarterly cadence is binding.** Subsequent exercises follow at 90-day intervals from the first.
- **30-day fix deadline.** Game-day post-mortem findings fixed within 30 days or filed as ADR amendments / issue packets — record this discipline in the doc.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0054`, `wave-4`

## Agent Handoff

**Objective:** Author the game-day discipline doc, schedule the first exercise 30 days after ADR-0054 acceptance with a recommended scenario, update Notify Cloud's draft SLA language to reflect D2 commitments, and record the D13 sales-conversation rail as a commercial-context footer.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Close the ADR-0054 rollout loop by setting up the recurring exercise that validates the paging substrate, the SLA language that publishes the honest coverage commitments, and the sales-conversation rail that protects D13.
- Feature: ADR-0054 Incident Response rollout, Wave 4 (final packet).
- ADRs: ADR-0054 D11 / D2 / D12 / D13 (primary), ADR-0036 (DR drills coordination), ADR-0027 (Notify Cloud SLA draft), ADR-0052 / ADR-0037 (game-day scenario sources).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:04` — hard. The game-day exercise exercises the Notify paging path.
- `packet:06` — hard. The game-day exercise exercises the Pulse synthetic probe.
- `packet:08` — hard. The game-day exercise uses the incident-record generator.
- `packet:09` — hard. The game-day exercise exercises the alert-routing wiring.

**Constraints:**
- First game day scheduled, not executed (Human Prerequisite).
- Notify Cloud SLA is operator-internal until Notify Cloud GA.
- D13 sales-conversation rail is a process commitment, not customer-visible language.
- Scheduled date concrete: ADR-0054 acceptance + 30 days.
- Quarterly cadence binding for subsequent exercises.

**Key Files:**
- `business/context/game-day-discipline.md` (new)
- `business/context/notify-cloud-sla-draft.md` (new, or update if existing)
- `business/context/` index / TOC cross-link if one exists

**Contracts:** None changed.
