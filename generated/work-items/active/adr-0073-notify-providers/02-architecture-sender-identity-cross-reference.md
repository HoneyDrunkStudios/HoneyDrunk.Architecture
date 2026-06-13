---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0073", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0073", "ADR-0038"]
wave: 3
initiative: adr-0073-notify-providers
node: honeydrunk-architecture
---

# Cross-reference ADR-0038 sender-identity discipline from Notify's repo overview

## Summary
Add a one-paragraph cross-reference to ADR-0038 (Outbound Sender Identity and Deliverability) inside `repos/HoneyDrunk.Notify/overview.md` so an operator looking at Notify's architecture context immediately sees where the DKIM / SPF / DMARC / From-address governance lives. **No new policy** — this packet just makes the existing ADR-0038 rules visible at the Notify Node's boundary. The Resend provider README cross-reference is authored in packet 01; this packet is the Architecture-side mirror.

## Context
ADR-0073 D1 commits Resend as the canonical default email provider but **explicitly defers** sender-identity discipline to ADR-0038:

> Sender identity discipline per ADR-0038 — DKIM, SPF, DMARC alignment for every sending domain; per-product From-address governance.

ADR-0073 D6 also names sender-identity policy as out-of-scope ("owned by ADR-0038"). The discipline is real — every send must respect it — but the rules are not in ADR-0073; they are in ADR-0038. Without a cross-reference at the Notify Node's overview, an operator looking at the Notify boundary doc has no signal that the discipline exists or where to find it.

ADR-0038 is currently **Proposed**. The discipline is committed in the ADR text even though it has not been implemented at the operational level (DKIM record creation, SPF record creation, DMARC policy authoring are the implementation packets that follow ADR-0038's acceptance — those are not gated here). This packet does **not** wait for ADR-0038's acceptance — the cross-reference points at the ADR file and is valid as soon as the file exists, which it does.

## Scope
- `repos/HoneyDrunk.Notify/overview.md` — add a short "Sender Identity" section near the existing ADR-0019 Boundary Cleanup section, pointing at ADR-0038.

## Out of Scope
- The Resend provider's own README cross-reference — authored in packet 01 (Notify side).
- Any actual DKIM / SPF / DMARC record-creation work — owned by ADR-0038's future implementation initiative.
- Twilio's sender-identity discipline (10DLC, A2P 10DLC) — that is per-PDR consumer-app concern per ADR-0073 D2, not a Notify-side discipline. No cross-reference for SMS sender-identity in this packet.

## Proposed Implementation
1. Open `repos/HoneyDrunk.Notify/overview.md`.
2. After the existing `## ADR-0019 Boundary Cleanup` section, add:

   ```markdown
   ## Sender Identity (ADR-0038)

   Outbound email sender identity — DKIM, SPF, DMARC alignment for every sending domain and per-product From-address governance — is owned by [ADR-0038](../../adrs/ADR-0038-outbound-sender-identity-and-deliverability.md), not by Notify itself. The Notify Node's responsibility is delivery mechanics; the deliverability discipline is the configuration-level posture documented in ADR-0038.

   Every email provider Notify wires (Resend per ADR-0073 D1, the existing SMTP provider, any future BYO-provider) operates inside ADR-0038's discipline. The provider package READMEs cross-reference ADR-0038 at the package boundary so an operator looking at a single provider can find the rules. SMS sender identity (10DLC registration, A2P 10DLC) is a per-PDR consumer-app concern per ADR-0073 D2 and is not enforced at the Notify provider layer.
   ```

3. Save. That's the whole packet.

## Affected Files
- `repos/HoneyDrunk.Notify/overview.md`

## NuGet Dependencies
None. This packet touches only Markdown context files; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any repo.
- [x] No new abstraction or cross-Node runtime dependency.
- [x] The cross-reference does not duplicate ADR-0038's content — it points at the ADR file.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Notify/overview.md` has a new `## Sender Identity (ADR-0038)` section
- [ ] The section explicitly names DKIM, SPF, DMARC, From-address governance, and the per-product discipline
- [ ] The section explicitly states SMS sender identity (10DLC) is a per-PDR concern per ADR-0073 D2, not enforced at the Notify provider layer
- [ ] The section links to `adrs/ADR-0038-outbound-sender-identity-and-deliverability.md` via the standard relative-path convention
- [ ] No edits to `constitution/invariants.md` (ADR-0073 adds no invariants; ADR-0038's invariants — if any are committed when ADR-0038 is Accepted — are handled in ADR-0038's own initiative)
- [ ] No edits to any `catalogs/` file

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0073 D1.** "Sender identity discipline per ADR-0038 — DKIM, SPF, DMARC alignment for every sending domain; per-product From-address governance. Pairs with ADR-0038."

**ADR-0073 D6 — Out of scope.** "Sender-identity policy — owned by ADR-0038. This ADR commits the provider; ADR-0038 commits the identity discipline (DKIM, SPF, DMARC, From-address governance)."

**ADR-0073 D2 — SMS provider.** "TCPA / SMS-marketing discipline is a per-PDR consumer-app concern; Notify does not enforce it at the provider layer." (Same shape — SMS sender-identity also lives outside the Notify boundary.)

## Constraints
- **Docs-only, no policy.** This packet adds a cross-reference; it does not author DKIM / SPF / DMARC records, does not pin domain names, does not configure Resend's domain-verification flow. Those are ADR-0038's implementation work.
- **No invariant text.** ADR-0073 adds no invariants. If ADR-0038's acceptance introduces invariants (e.g. "every outbound sending domain has a valid DMARC policy at staged-strict"), those are added in ADR-0038's acceptance packet, not here.
- **No relationships.json edit.** ADR-0038 does not introduce new Node-to-Node edges; no catalog update.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0073`, `wave-3`

## Agent Handoff

**Objective:** Add a one-paragraph ADR-0038 cross-reference to `repos/HoneyDrunk.Notify/overview.md` so the discipline is visible at the Notify Node's architectural boundary.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make ADR-0038 sender-identity discipline visible at the Notify Node's boundary doc.
- Feature: ADR-0073 Notify Default Providers rollout, Wave 3.
- ADRs: ADR-0073 D1 / D6 (defer to ADR-0038); ADR-0038 (the discipline, Proposed — referenced not modified).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0073 is Accepted before any consuming packet runs.

**Constraints:**
- Docs-only. No new policy. Do not edit the ADR text of either ADR-0073 or ADR-0038.
- Cross-reference uses relative paths (`../../adrs/ADR-0038-...`), matching the existing convention in `repos/HoneyDrunk.Notify/overview.md` for ADR links.

**Key Files:**
- `repos/HoneyDrunk.Notify/overview.md`

**Contracts:** None.
