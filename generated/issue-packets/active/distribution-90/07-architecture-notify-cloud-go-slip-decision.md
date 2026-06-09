---
name: Notify Cloud Go/Slip Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "distribution-90", "human-only"]
dependencies: []
adrs: ["PDR-0002", "ADR-0027"]
source: human
generator: scope
wave: 2
initiative: distribution-90
node: honeydrunk-architecture
actor: human
---

# Decision: Notify Cloud 2026-09-15 — commit or slip (PDR-0002), by 2026-06-23

## Summary
Make the explicit go/slip decision on PDR-0002's Notify Cloud public-launch target (2026-09-15) by end of week 2 (2026-06-23). Either **commit** — multi-tenant scaffolding scoping starts in parallel with the remaining ADR-0077 operator setup, and a Notify landing/waitlist page goes up — or **slip** to Q4 with a new date recorded as a PDR-0002 amendment. The one forbidden outcome is the default: letting the date fail silently by sequencing.

## Context (PDR-0002 decisions inline — the deadline math)
- **"Public launch target: 2026-09-15. This is the date the 90-day decision-point evaluation window (§K) starts."** Soft launch (waitlist, no payment) was planned at +3 months, public launch (Stripe, Free + Starter + Pro live) at +4 months.
- **Waitlist mitigation (PDR-0002 risk table):** "Pre-launch waitlist (soft launch at +3 months) to validate signal before Stripe is live. If waitlist is below 50 sign-ups, delay public launch and re-evaluate the wedge before spending Stripe-integration time."
- **Hard prerequisite:** "ADR-0019 must be Accepted (both halves landed) before Notify Cloud public launch. Notify Cloud soft launch can ship with the in-memory decision log; public launch requires a persistent decision log backend."
- **Acknowledged slip risk:** "The dependency chain (Actions#20 → ADR-0015 deploy → ADR-0019 → Notify 1.0 → Notify Cloud) is long. Any single dependency slipping pushes Notify Cloud launch past the 2026-09-15 target."
- **Charter framing:** kill clocks are out, decision points are in. Slipping deliberately with a recorded new date is a fully valid outcome; PDR-0002 is "a product trial, not a stake-the-studio bet." What the charter does not license is undated drift.

As of 2026-06-09 it is ~14 weeks to 2026-09-15. The honest inputs to weigh: remaining ADR-0077 operator Azure setup (OIDC vars, Environments, RBAC, branch protection), Notify dev deployment state, ADR-0019 status, multi-tenant scaffolding (not started), Stripe work (ADR-0037 still Proposed), and that Distribution 90's HoneyHub launch (packets 06–11) competes for the same solo-operator attention.

## The decision (one of two)
**(a) COMMIT to 2026-09-15:**
- Delegate to the scope agent to packet the multi-tenant scaffolding start (under the existing `adr-0027-notify-cloud-standup` initiative, not Distribution 90).
- A Notify landing/waitlist page goes up on honeydrunkstudios.com (a sibling of packet 05's page; scoped as a follow-up packet at commit time, target ~1 day).
- Record the commitment + dated milestone checkpoints in `initiatives/active-initiatives.md` (Distribution 90 entry cross-references it).

**(b) SLIP to Q4 2026:**
- Amend PDR-0002 with the new public-launch target date and a one-paragraph rationale (the PDR's own amendment convention; no new PDR needed).
- The new date inherits the same go/slip discipline: it gets its own decision checkpoint ~12 weeks ahead of it.

## Human Prerequisites
- [ ] This entire packet is the human work: review the inputs, decide (a) or (b), and record the outcome. Target ≤ half a day including the amendment text if slipping.

## Acceptance Criteria
- [ ] A decision — commit or slip — is recorded by 2026-06-23.
- [ ] If commit: scope-agent delegation issued for multi-tenant scaffolding + Notify landing-page packet; checkpoints recorded in `initiatives/active-initiatives.md`.
- [ ] If slip: PDR-0002 carries a dated amendment section with the new target and rationale; `initiatives/active-initiatives.md` and `initiatives/roadmap.md` references to 2026-09-15 are updated to match.
- [ ] Either way: the Distribution 90 metrics log week-entry for that week notes the decision (one line).

## Dependencies
None. Deliberately independent of the HoneyHub packets — the decision must not wait on launch work.

## Agent Handoff
**Objective:** Not delegable — `Actor=Human`. The decision is the operator's. If the outcome is "commit," the operator delegates follow-up scoping to the scope agent under `adr-0027-notify-cloud-standup`; if "slip," the operator (or a directed agent edit) writes the PDR-0002 amendment.
**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main` (for the amendment/tracking edits).
**Constraints:**
- PDR-0002 is Accepted; changes go through its amendment convention (dated amendment section), never a rewrite of the original decision text.
- No new ADR/PDR — both outcomes are expressible within PDR-0002 and existing initiatives.
**Key Files:**
- `pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md`
- `initiatives/active-initiatives.md`, `initiatives/roadmap.md`
**Contracts:** None.
