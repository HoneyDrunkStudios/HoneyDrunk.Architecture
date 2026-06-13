---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0070", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0070", "ADR-0027"]
accepts: ["ADR-0070"]
wave: 3
initiative: adr-0070-frontend-stack
node: honeydrunk-architecture
---

# Re-check the Notify Cloud admin surface against ADR-0070 D2's "simple enough" threshold

## Summary
ADR-0070 D2 names the Notify Cloud tenant-operator admin (ADR-0027) as the first concrete Blazor consumer and asserts its surface meets the "simple enough" test (~15 distinct views, ~30 interactive components, CRUD-shaped, internal/operator audience). That assertion is **not verified** at ADR-0070 acceptance time — the count is asserted, not measured. This packet re-counts Notify Cloud admin's view/component surface from the current ADR-0027 and PDR-0002 sources and either confirms the surface is within D2 or, if it exceeds the threshold, records the divergence and triggers either an ADR-0070 D2 amendment (raise the threshold or widen the carve-out) or a Notify Cloud admin stack switch (Blazor → React) before the scaffold lands.

This is a docs/governance re-check, not a code edit. The Notify Cloud admin scaffold packet (ADR-0027 initiative, packet 06) has already committed Blazor Server — and per ADR-0070 D2's "simple admin only" rule, that scaffold's commitment is binding *iff* the surface remains within D2. If the count exceeds D2, the scaffold is the surface that needs reconsideration, not ADR-0070.

## Context
ADR-0070 D2 (Accepted via packet 00):

> Blazor is permitted for admin sites only when the admin surface is simple — fewer than ~15 distinct views, fewer than ~30 interactive components, CRUD-shaped, internal/operator-facing.

ADR-0070's "First concrete Blazor consumer is the Notify Cloud tenant-operator admin per ADR-0027" claim is in the ADR body; it is the ADR's own example of an in-policy Blazor adoption. But ADR-0070 was authored without a count — the assertion was made by the ADR author at authoring time, not measured against the live ADR-0027 / PDR-0002 spec.

Two scenarios this packet rules out:

1. **The Notify Cloud admin actually exceeds D2.** If a current count of views + interactive components from ADR-0027's UI spec and PDR-0002's GA scope yields >15 views or >30 interactive components, then ADR-0070 D2's "First concrete Blazor consumer" example is **itself out of policy** at acceptance time. That is a substrate consistency failure: the policy ADR cites an out-of-policy example as its proof case. The resolution paths are the same as packet 04's Path A/B/C, scaled down: amend ADR-0070 D2 thresholds, switch Notify Cloud admin to React, or annotate a per-surface exception.
2. **The count is borderline.** A close-to-threshold count (say 13 views, 28 components) makes the policy ride on an unstable empirical claim. Per the D2 tie-breaker added to the scope/review rubric in packets 01–02 ("when ambiguous, default to React"), a borderline Notify Cloud admin is itself ambiguous — but the ADR-0070 author already picked Blazor before the tie-breaker existed. This packet's job is to either confirm the surface is comfortably within thresholds (e.g., ≤10 views, ≤20 components — a clear margin) or to surface the borderline status and let the operator decide whether to switch.

Either outcome is recorded. If the surface is comfortably within D2, this packet closes with a documented count and no further action. If the surface is at-or-over D2, this packet triggers either a follow-up `Actor=Human` decision packet (mirroring packet 04's structure, scaled to a single surface) or a direct Notify Cloud admin scaffold revision.

## Scope
- Count Notify Cloud admin views and interactive components from `adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md` (UI sections) and `pdrs/PDR-0002-notify-cloud-tenant-operator-admin.md` (GA scope sections, if PDR-0002 names the surface this way — otherwise the corresponding PDR for Notify Cloud admin).
- Record the count in this packet's closure comment / a follow-up doc.
- If within D2: no edits. Close the packet.
- If at-or-over D2: file a follow-up `Actor=Human` packet that mirrors packet 04's three-paths shape (amend D2; switch Notify Cloud to React; per-surface exception note). The follow-up packet is filed separately, not in this initiative folder.

## Proposed Implementation

### Part A — The count

Read ADR-0027's UI-related sections and PDR-0002's GA-scope sections (or whichever PDR carries the Notify Cloud admin spec — confirm by checking `pdrs/README.md`). Enumerate:

1. **Distinct views.** A "view" is a top-level page/route — tenant list, tenant detail, channel config, send log, audit feed, etc. Count routes / top-level navigation entries, not modals or panels-within-a-page.
2. **Interactive components.** An "interactive component" is a form field, button, toggle, table row action, filter dropdown, etc. — anything the operator actively clicks or types into. Count instances, not types (three "search box" instances on three different pages = 3, not 1).

Record both counts with the source line / section in ADR-0027 and PDR-0002 where each was derived.

### Part B — The disposition

Three outcomes:

1. **Comfortably within D2** (≤12 views and ≤25 components — a ~20% margin under the ~15 / ~30 thresholds). Close the packet with the recorded counts. No further action.
2. **Borderline** (13–15 views, 26–30 components — at-or-just-under D2). Record the count, escalate to the operator with a one-paragraph summary and a "stay-with-Blazor / switch-to-React" recommendation. The operator decides; the decision is recorded; the packet closes.
3. **Over D2** (>15 views or >30 components). File a follow-up `Actor=Human` packet that mirrors packet 04's three-paths shape:
   - Path A: amend ADR-0070 D2's threshold to accommodate Notify Cloud (e.g., raise to ~20 views, ~40 components).
   - Path B: switch the Notify Cloud admin scaffold from Blazor Server to React (which requires editing the ADR-0027 packet 06 commitment).
   - Path C: per-surface exception note (Notify Cloud is the named carve-out in ADR-0070 D2; no other admin surface gets to claim the precedent without its own carve-out).

### Part C — Optional follow-on: a sentinel test

If the count is borderline, consider proposing (as a separate future packet, not this one) a sentinel that re-runs the count at each Notify Cloud admin scaffold expansion. The sentinel is out of scope here — flag the idea in the closing note if useful.

## Affected Files

None by default. If the count is over D2 and the operator picks Path A, the affected file is `adrs/ADR-0070-frontend-platform-stack.md` (D2 amendment) — but that edit lives in the follow-up packet, not this one.

## NuGet Dependencies
None.

## Boundary Check
- [x] All work in `HoneyDrunk.Architecture`. ADR-0027 and PDR-0002 both live here; ADR-0070 lives here.
- [x] No code change in any other repo.
- [x] No catalog change.

## Acceptance Criteria
- [ ] The Notify Cloud admin view count is recorded with the source ADR-0027 section / PDR-0002 section for each view
- [ ] The Notify Cloud admin interactive-component count is recorded with the same sourcing
- [ ] The disposition is recorded — within D2 (close), borderline (operator decision), or over D2 (follow-up packet filed)
- [ ] If a follow-up packet is needed, its filing reference (issue number) is recorded in this packet's closure comment
- [ ] No edit to ADR-0070 in this packet — any D2 amendment lives in the follow-up packet
- [ ] No edit to the Notify Cloud admin scaffold packet (ADR-0027 initiative packet 06) in this packet — any stack switch lives in the follow-up packet

## Human Prerequisites

None for the count itself. If the count lands borderline or over D2, the operator's decision is required — captured by the follow-up `Actor=Human` packet, not by this one.

## Referenced ADR Decisions

**ADR-0070 D2 — Blazor for simple admin only.** "Blazor is permitted for admin sites only when the admin surface is simple — fewer than ~15 distinct views, fewer than ~30 interactive components, CRUD-shaped, internal/operator-facing. The first concrete Blazor consumer is the Notify Cloud tenant-operator admin per ADR-0027."

**ADR-0070 D2 tie-breaker (per packets 01 + 02 of this initiative).** When the thresholds are ambiguous or borderline, the default is React. This re-check exists because the Notify Cloud admin example was named at ADR-0070 authoring time without an explicit count.

**ADR-0027 — Notify Cloud Node standup.** Names Blazor Server for the tenant-operator admin. Packet 06 of that initiative carries the scaffold commitment. If the count is over D2, that commitment is the surface that needs revision.

## Constraints
- **Count, don't edit.** This packet records the count and triggers a follow-up if needed. It does not amend ADR-0070, does not edit the ADR-0027 packet 06 scaffold, and does not commit any stack switch.
- **Honest disposition.** A borderline count is not "comfortably within" — record it as borderline and surface to the operator. A borderline pass that gets recorded as "within" is the failure mode this packet exists to prevent.
- **One surface, this packet.** This packet re-checks Notify Cloud admin only. Other admin surfaces (none currently committed to Blazor — Notify Cloud is the first) get their own checks at their own scaffolding time, per the scope-agent rubric updated in packet 01.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0070`, `wave-3`

## Agent Handoff

**Objective:** Re-count Notify Cloud admin's view/component surface against ADR-0070 D2 and either confirm the surface is comfortably within thresholds or surface a divergence for explicit operator resolution.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Convert the asserted "Notify Cloud admin is within D2" claim into a measured one. If the measurement diverges, surface honestly rather than silently retaining the assertion.
- Feature: ADR-0070 Frontend Platform Stack rollout, Wave 3 (mini-check).
- ADRs: ADR-0070 (primary), ADR-0027 (Notify Cloud Node standup — the surface being counted).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0070 must be Accepted before its D2 example is checked against the policy.

**Constraints:**
- Count, don't edit.
- Borderline counts get escalated, not auto-passed.
- Any divergence triggers a follow-up `Actor=Human` packet — not silent acceptance.

**Key Files:**
- `adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md`
- `pdrs/PDR-0002-notify-cloud-tenant-operator-admin.md` (or whichever PDR carries the Notify Cloud admin spec — verify via `pdrs/README.md`)
- `adrs/ADR-0070-frontend-platform-stack.md` (D2 reference only — no edits here)

**Contracts:** None.
