---
name: Notify Runbook Cross-Link — Operator vs Tenant Boundary
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0084", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0084", "ADR-0054"]
wave: 3
initiative: adr-0084-discord-alerts
node: honeydrunk-architecture
source: strategic
generator: scope
---

# Cross-link ADR-0084 from the Notify runbook (operator-internal vs tenant-facing boundary)

## Summary
Edit `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (per ADR-0054 D10 — the Notify-side runbook for alert routing) to add a cross-link to ADR-0084 making the operator-internal-Discord vs tenant-facing-Notify+PagerDuty boundary explicit. The two surfaces are siblings; the runbook should state that explicitly so a future on-call reader does not conflate them.

## Context
ADR-0084's Follow-up Work explicitly names this packet: *"Cross-reference this ADR from `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (ADR-0054 D10 lives there) — Notify Cloud's tenant-facing alert routing and this ADR's operator-internal Discord routing are sibling surfaces; the runbook should make the boundary explicit."*

ADR-0054 D4 pins Notify + PagerDuty for paying-tenant SEV-1/SEV-2 pages. ADR-0084 D6 pins Discord for operator-internal CI / agent / security / hive / release / audit signals. The two are sibling surfaces — they coexist, they may mirror specific high-severity alerts (per ADR-0084 D6's Critical-severity rows that route to multiple channels), but neither substitutes for the other. The runbook is the load-bearing on-call reference; the boundary needs to be unambiguous in the document a paged operator reads at 3am.

This is a citation-only edit. No decisions in the Notify runbook change; the cross-link is wording-only.

## Scope
- `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` — add a cross-link section to ADR-0084 with the operator-vs-tenant boundary statement. If the runbook does not exist yet (ADR-0054 D10 has not been fully scoped), this packet creates a stub that documents the boundary; the full content of the runbook lands separately per ADR-0054 D10's owner.

## Proposed Implementation
1. Check whether `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` exists.
   - **If it exists** (ADR-0054 D10's runbook is in place): add a new section near the top — after the runbook's preamble, before its routing-table content — with the operator-vs-tenant boundary statement and the ADR-0084 cross-link.
   - **If it does not exist** (ADR-0054 D10's runbook has not been authored yet): create a stub at the expected path with the operator-vs-tenant boundary statement, the ADR-0084 cross-link, and a placeholder pointing at ADR-0054 D10 as the canonical owner of the full runbook content (which lands separately).

2. The boundary statement (exact wording to insert):

   > **This runbook covers tenant-facing alert routing.** Operator-internal alerts (CI failures, agent activity, security signals, hive-sync drift, deploy events, NuGet publishes, credential-rotation escalations, budget alerts, internal-Grid error spikes) flow via Discord per [ADR-0084](../../../adrs/ADR-0084-discord-operator-alerts-surface.md), not via Notify + PagerDuty. The two surfaces are siblings:
   >
   > - **Notify + PagerDuty** (this runbook): paying-tenant SEV-1 / SEV-2 incident escalation per [ADR-0054](../../../adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md) D4. Phone + SMS + push to the on-call operator.
   > - **Discord** ([ADR-0084](../../../adrs/ADR-0084-discord-operator-alerts-surface.md)): operator-internal day-to-day operational pager. Glanceable, categorized, mobile-and-desktop, shared-timeline.
   >
   > High-severity events MAY mirror across both surfaces — ADR-0084 D6 specifies which Critical-severity rows post to multiple channels including `#audit-sensitive`. The Notify + PagerDuty path is NOT replaced by Discord; both are mandatory for their respective scope. If a tenant-facing event is observed only in Discord and not in PagerDuty, that is a routing bug per the runbook in this repo, not a redirection of the canonical surface.

3. Adjust the relative-link depth (`../../../adrs/...`) at packet-09 execution time to match the actual runbook depth in the Architecture repo's `repos/HoneyDrunk.Notify/runbooks/` directory tree. The path above assumes the runbook is three levels deep; verify and adjust if needed.

4. No edit to ADR-0054 itself, no edit to ADR-0084 itself. The cross-link goes in the runbook only.

## Affected Files
- `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (NEW or APPEND, depending on ADR-0054 D10 runbook landing order)

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` (the runbook file lives under `repos/HoneyDrunk.Notify/runbooks/` which is the Architecture repo's `repos/` convention for per-Node documentation, not the Notify repo itself).
- [x] No code change in any repo.
- [x] Runbook is governance documentation; no Node contract change.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` exists and carries a new section (near the top, after preamble, before routing-table content) with the operator-vs-tenant boundary statement
- [ ] The section text is verbatim from Proposed Implementation §2 — the boundary statement that names Notify + PagerDuty as paying-tenant SEV-1/SEV-2 surface and Discord as operator-internal day-to-day surface
- [ ] The section cross-links to ADR-0084 (operator-internal Discord) and ADR-0054 D4 (tenant-facing Notify + PagerDuty) using correct relative paths
- [ ] The section explicitly notes that high-severity events MAY mirror across both surfaces per ADR-0084 D6's multi-channel Critical-severity rows, but Discord does NOT replace the Notify + PagerDuty path
- [ ] If the runbook did not exist before this packet, the new file is a minimal stub: the boundary statement, the ADR-0084 cross-link, and a placeholder noting ADR-0054 D10 as the canonical owner of the full runbook content
- [ ] If the runbook did exist before this packet, the boundary statement is inserted near the top without disturbing existing content
- [ ] Relative-link paths (`../../../adrs/...`) are correct for the actual runbook depth in `repos/HoneyDrunk.Notify/runbooks/`
- [ ] No edit to ADR-0054 itself, no edit to ADR-0084 itself

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0084 D1 — Role and scope.** Discord is the canonical operator-alerts surface, nothing more. NOT a Communications concern, NOT a Notify concern, NOT a Notify Cloud concern. Operator alerts and tenant-facing notifications are categorically different substrates.

**ADR-0084 D6 — Alert-routing table.** Tenant-facing incident pages (ADR-0054 D4) continue to route via Notify + PagerDuty. *"Discord may receive a mirror of the same alert via the App Insights or Grid-Health rows in the table above (so the operator sees the page land in two surfaces), but Discord is not a substitute for the PagerDuty escalation path for paying-tenant SEV-1/SEV-2 events. ADR-0054 is the canonical surface for tenant-facing incidents; this ADR is the canonical surface for operator-internal day-to-day."*

**ADR-0084 Follow-up Work — Notify runbook cross-link.** *"Cross-reference this ADR from `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (ADR-0054 D10 lives there) — Notify Cloud's tenant-facing alert routing and this ADR's operator-internal Discord routing are sibling surfaces; the runbook should make the boundary explicit."* This packet is the execution.

**ADR-0054 D4 — Tenant-facing alert routing.** Notify + PagerDuty for paying-tenant SEV-1/SEV-2 pages. The on-call operator gets phone + SMS + push for tenant-impacting incidents.

**ADR-0054 D10 — Per-deployable-Node runbook discipline.** Each deployable Node has a minimum runbook set; `alert-routing.md` is one of those per the ADR-0054 D10 inventory. The full runbook content is owned by ADR-0054 D10's scope; this packet adds one section to it.

## Constraints
- **Citation-only edit.** No decisions change in the Notify runbook; the boundary statement is wording.
- **Boundary statement is verbatim from Proposed Implementation §2.** Do not paraphrase — the wording is what makes the boundary unambiguous for a 3am-paged on-call operator.
- **Relative-link paths must be correct at packet execution time.** Verify the depth from `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` to `adrs/`.
- **No edit to ADR-0054 itself, no edit to ADR-0084 itself.** The cross-link goes in the runbook only.
- **Branching by file existence.** Create a stub if the runbook does not exist (ADR-0054 D10 has not yet scoped it); add the section if it does.
- **Strict PR body discipline.** `Authorship: agent`, `Packet: <path>`.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0084`, `wave-3`

## Agent Handoff

**Objective:** Add the operator-vs-tenant boundary statement to `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` with a cross-link to ADR-0084.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the operator-internal-Discord vs tenant-facing-Notify+PagerDuty boundary unambiguous in the runbook a paged on-call operator reads at 3am.
- Feature: ADR-0084 Discord operator-alerts rollout, Wave 3.
- ADRs: ADR-0084 (D1 boundary, D6 multi-channel Critical rows, Follow-up Work for this packet), ADR-0054 (D4 tenant-facing routing, D10 runbook discipline).

**Acceptance Criteria:** As listed above.

**Dependencies:** packet:00 (ADR-0084 must be Accepted before the runbook cross-links it as a governing decision).

**Constraints:**
- Citation-only edit. No decisions change.
- Boundary statement is verbatim. Do not paraphrase.
- Relative-link paths must be correct for the actual runbook depth.
- No edit to ADR-0054 or ADR-0084 themselves.
- Branching by file existence: create stub if runbook does not exist; add section if it does.
- PR body: `Authorship: agent`, `Packet: <path>`.

**Key Files:**
- `repos/HoneyDrunk.Notify/runbooks/alert-routing.md` (NEW or APPEND)
- `adrs/ADR-0084-discord-operator-alerts-surface.md` (read-only — D1 boundary, D6 multi-channel rules, Follow-up Work)
- `adrs/ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md` (read-only — D4 + D10 reference)

**Contracts:** None changed.
