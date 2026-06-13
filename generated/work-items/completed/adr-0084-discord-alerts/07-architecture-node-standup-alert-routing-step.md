---
name: Node-Standup Procedure — Alert-Routing Step
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0084", "wave-3"]
dependencies: ["work-item:01"]
external_dependencies: ["HoneyDrunkStudios/HoneyDrunk.Architecture#{adr-0083-packet-07-issue-number}"]
adrs: ["ADR-0084", "ADR-0082", "ADR-0083"]
wave: 3
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
source: strategic
generator: scope
---

<!-- Operator: fill in the real ADR-0083 packet 07 issue number in `external_dependencies` once ADR-0083 has been
     filed. This packet and ADR-0083 packet 07 both amend the SAME onboarding-hook section of
     `constitution/node-standup.md` (ADR-0084 D10's alert-routing step lands parallel to ADR-0083 D6's
     external-credential-onboarding step). ONE of the two packets must rebase against the other. Per the
     cross-initiative ordering constraint in the dispatch plan, ADR-0084 is promoted first; ADR-0083 packet 07
     then rebases against this packet's merged state and is updated to insert its step next to (not on top of)
     this step. -->


# Amend constitution/node-standup.md to add the ADR-0084 D10 operator-alert-routing step

## Summary
Add a new step to `constitution/node-standup.md` (the ADR-0082 canonical Node-standup procedure document) per ADR-0084 D10's onboarding-hook. The step requires that any Node standup introducing a new operational event surface (CI workflow, scheduled job, agent activity, or operational event emitter) registers a row in `constitution/alert-routing.md`, wires `channel` and `severity` inputs through `job-discord-notify.yml`, and declares a suppression rule per ADR-0084 D8 if projected volume exceeds 50 messages/day.

**Cross-initiative amendment coordination.** This packet and ADR-0083 packet 07 (the D6 sensitive-inventory onboarding-hook amendment) both amend the SAME onboarding-hook section of `constitution/node-standup.md`. Per the cross-initiative ordering constraint, ADR-0084 (this initiative) is promoted first; once this packet's PR merges, ADR-0083 packet 07 rebases against the merged state and inserts its own step adjacent to (not replacing) this one. The two steps live side-by-side in the standup procedure — one for operator-alert routing (this packet), one for external-credential onboarding (ADR-0083 packet 07).

## Context
ADR-0084 D10 specifies the exact step text to add (verbatim quoted below). The step attaches to the existing ADR-0082 procedure document parallel to ADR-0083 D6's external-credential-onboarding step — the two hooks share the same insertion pattern (new Node standup gets a "before the source enters any CI surface" gate that touches the relevant constitution/infrastructure documents).

The step is purely procedural — it does not change any existing standup work, it adds a new requirement for the subset of standup packets that introduce operational event surfaces. Most Node standups (Memory, Knowledge, Capabilities, Sim, Evals, Flow scaffolding) emit no operator-actionable events at first; they activate the new step only when their Node's CI / scheduled jobs / agent activity / operational event emitters come online.

## Scope
- `constitution/node-standup.md` — add a new step per ADR-0084 D10's verbatim language. Insert next to ADR-0083 D6's external-credential-onboarding step (or at the equivalent insertion point if the file's structure has evolved).

## Proposed Implementation
1. Open `constitution/node-standup.md`. Locate ADR-0083 D6's external-credential-onboarding step (the file should already have it; if it does not exist yet because ADR-0083 has not landed its own initiative, insert the new step at the equivalent structural position — likely the post-scaffolding/pre-CI gate section).
2. Add the new step using ADR-0084 D10's exact wording:

   > **Operator-alert routing.** If the Node's standup introduces a new operational alert source (a new CI workflow, scheduled job, agent activity, or operational event emitter) that the operator should see in chat, the standup packet must, before the source enters any CI surface:
   >
   > 1. Add a row to `constitution/alert-routing.md` per ADR-0084 D6.
   > 2. Pass `channel` and `severity` inputs through `job-discord-notify.yml` in HoneyDrunk.Actions per ADR-0084 D9.
   > 3. If the source's projected volume exceeds 50 messages per day, declare a suppression rule per ADR-0084 D8.

3. The step is positionally near (parallel to, not bundled with) ADR-0083 D6's external-credential-onboarding step. If the ADR-0083 step has not landed yet (its initiative has not been scoped or its packets have not merged), insert the new step at the equivalent structural position and add a comment noting that ADR-0083's parallel step will land alongside.

4. Cross-link from the new step to: ADR-0084 D10 (governing decision), ADR-0084 D6 (`constitution/alert-routing.md` format), ADR-0084 D9 (`job-discord-notify.yml` contract), ADR-0084 D8 (volume bounding / suppression rule).

## Affected Files
- `constitution/node-standup.md`

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.
- [x] Procedure document is governance; no Node contract change.

## Acceptance Criteria
- [ ] `constitution/node-standup.md` carries a new "Operator-alert routing" step with ADR-0084 D10's exact wording (the three-step nested list: row in `constitution/alert-routing.md`, `channel`+`severity` through `job-discord-notify.yml`, suppression rule above 50/day)
- [ ] The new step is positioned next to ADR-0083 D6's external-credential-onboarding step (or at the equivalent structural position if ADR-0083's step has not yet landed)
- [ ] The step cross-links to ADR-0084 D10 (governing decision), ADR-0084 D6 (`alert-routing.md` format), ADR-0084 D9 (`job-discord-notify.yml` contract), and ADR-0084 D8 (volume bounding)
- [ ] The step's preamble specifies the trigger condition exactly: *"introduces a new operational alert source (a new CI workflow, scheduled job, agent activity, or operational event emitter) that the operator should see in chat"* — verbatim from ADR-0084 D10
- [ ] No edit to ADR-0082 itself (the procedure document is the artifact ADR-0082 owns; amendments land in the document, not the ADR)
- [ ] No edit to `constitution/alert-routing.md` in this packet (that file's content is governed by ADR-0084 D6 and is edited by future onboarding packets, not by this procedure-amendment packet)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0084 D10 — Onboarding hook.** *"When a new alert source is introduced anywhere in the Grid (new CI job, new scheduled workflow, new Node emitting operational events, new agent firing a non-PR-comment signal), the packet introducing it must include: (1) A new row on the D6 alert-routing table (added to this ADR by amendment or, once the alert-routing.md companion document exists, edited in that document with a cross-reference here). (2) The specific `channel` and `severity` inputs the source will pass to `job-discord-notify.yml`. (3) A volume estimate (messages-per-day projection) and, if above 50/day, an explicit suppression rule per D8."* The onboarding hook attaches to the ADR-0082 procedure document `constitution/node-standup.md`. This packet IS that attachment.

**ADR-0084 D6 — Alert-routing table.** Lives canonically in `constitution/alert-routing.md` (landed by packet 01). New standup packets adding operator-alert emitters add a row to this file per the new step.

**ADR-0084 D9 — Implementation seam.** `job-discord-notify.yml` is the CI-side seam every emitter routes through. New standup packets pass `channel` and `severity` inputs through it.

**ADR-0084 D8 — Privacy and signal-hygiene rules / volume bounding.** *"Any new emitter that would meaningfully grow alert volume (defined as: any source projected to emit more than 50 messages per day on average) requires an entry on the table per the onboarding hook (D10) — including a per-source severity floor, a duplicate-suppression rule, or both."*

**ADR-0082 — Canonical Node-standup procedure.** The procedure document `constitution/node-standup.md` is the artifact ADR-0082 owns. Amendments land in the document, not the ADR itself.

**ADR-0083 D6 — External-credential-onboarding step.** Parallel onboarding hook in the same procedure document. ADR-0084's D10 step sits next to ADR-0083's D6 step structurally.

## Constraints
- **ADR-0084 D10 wording is verbatim.** Do not paraphrase, summarize, or restructure the three-step nested list. The exact wording is what makes the hook unambiguous for future standup-packet authors.
- **Insertion position is structural, not strictly adjacent.** If ADR-0083 D6's parallel step has not landed yet, position the new step at the equivalent structural slot and note that ADR-0083's step will land alongside.
- **No edit to ADR-0084 itself, no edit to `alert-routing.md`, no edit to ADR-0082 itself.** This packet edits one file: `constitution/node-standup.md`.
- **Strict PR body discipline.** `Authorship: agent`, `Work Item: <path>`.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0084`, `wave-3`

## Agent Handoff

**Objective:** Add the ADR-0084 D10 operator-alert-routing step to `constitution/node-standup.md`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the onboarding hook so future Node-standup packets that introduce operational event surfaces have a mandatory procedural gate before the source enters CI.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 3.
- ADRs: ADR-0084 (D10 — governing decision, D6 / D8 / D9 — referenced procedures), ADR-0082 (the procedure document this packet amends), ADR-0083 (D6 — parallel onboarding step that sits next to this one).

**Acceptance Criteria:** As listed above.

**Dependencies:** work-item:01 (`constitution/alert-routing.md` must exist before the new step references it as the row-addition target).

**Constraints:**
- ADR-0084 D10 wording is verbatim. Do not paraphrase the three-step nested list.
- Insertion position is structural, parallel to ADR-0083 D6's step.
- No edit to ADR-0084, no edit to `alert-routing.md`, no edit to ADR-0082 — this packet edits one file: `constitution/node-standup.md`.
- PR body: `Authorship: agent`, `Work Item: <path>`.

**Key Files:**
- `constitution/node-standup.md`
- `adrs/ADR-0084-discord-operator-alerts-surface.md` (read-only — D10 verbatim wording)

**Contracts:** None changed.
