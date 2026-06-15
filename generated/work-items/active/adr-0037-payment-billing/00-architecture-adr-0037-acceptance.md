---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0037", "wave-1"]
dependencies: []
adrs: ["ADR-0037"]
accepts: ["ADR-0037"]
wave: 1
initiative: adr-0037-payment-billing
node: honeydrunk-architecture
---

# Accept ADR-0037 — flip status, add the three billing invariants, register the initiative

## Summary
Flip ADR-0037 (Payment and Billing Integration) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the three new billing invariants ADR-0037 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0037-payment-billing` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0037 sets the Grid-wide payment-and-billing policy: Stripe as the sole processor for every product, B2B and B2C, covering Billing, Tax, Checkout, and Customer Portal with no Stripe Connect (D1); the billing-event flow `IBillingEventEmitter` → append-only buffer Node → Stripe Meter Events, idempotent end-to-end per ADR-0042 (D2); the subscription model — Notify Cloud Free/Pro/Scale tiers with usage overage, single monthly/annual prices per consumer app, no free trials at v1 (D3); a single Stripe webhook endpoint per environment in `HoneyDrunk.Billing.Webhooks` emitting domain events onto the Service Bus default topic per ADR-0028 (D4); the Stripe-customer ↔ Grid-tenant/principal identity binding (D5); Stripe Tax on from day one with nexus tracking and no hardcoded rates (D6); PCI scope minimized to SAQ A by never letting a card number enter the Grid (D7); the mobile in-app-purchase carve-out — platform IAP for app-store-mandated flows, Stripe for web (D8); the `HoneyDrunk.Billing` Node placement in the Ops sector with its package families (D9); and test-mode / synthetic-tenant handling (D10).

ADR-0037 is a **policy / decision** ADR. The concrete code — the `HoneyDrunk.Billing` Node itself, its Abstractions, the Stripe implementation, and the webhook Function App — is explicitly deferred by ADR-0037 itself (D2, D9, and the Follow-up Work list) to a **separate `HoneyDrunk.Billing` standup ADR**. This initiative lands the ADR-0037 policy decisions and the Grid-wide governance changes they commit; it does **not** scaffold the Billing Node. The standup-ADR-before-scaffold rule applies (an empty cataloged Node gets a standup ADR first).

Every other packet in this initiative references ADR-0037's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0037-payment-and-billing-integration.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0037 row Status column to Accepted.
- `constitution/invariants.md` — add the three new billing invariants ADR-0037 commits (see Proposed Implementation for exact text). They take the pre-reserved numbers **62, 63, 64**.
- `initiatives/active-initiatives.md` — register the `adr-0037-payment-billing` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0037 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0037 index row in `adrs/README.md` to Accepted.
3. Add three new invariants to `constitution/invariants.md` as numbers **62, 63, 64**. The text, taken verbatim-in-substance from ADR-0037's "Invariants" Consequences subsection:
   - **62. Card data never enters the Grid.** All card capture is through Stripe-hosted surfaces (Stripe Checkout or Stripe Elements). The Grid stores only Stripe identifiers and `payment_method_id` values — never a PAN, CVV, or raw card field. This maintains PCI-DSS SAQ A scope, the only defensible scope at solo-developer headcount. Custom checkout forms that handle card data, in-app payment UI that touches PANs, and any "save card" flow that does not go through Stripe's APIs are forbidden. See ADR-0037 D7.
   - **63. No Node subscribes to Stripe webhooks directly.** Stripe webhooks land in a single `HoneyDrunk.Billing.Webhooks` endpoint per environment; that handler validates the Stripe signature, persists the raw event, and emits a domain event onto the Service Bus default topic. Domain consumers subscribe to the topic, never to Stripe. This preserves the ADR-0028 broker-default rule and keeps Stripe out of every consumer Node's dependency surface. See ADR-0037 D4.
   - **64. Stripe test-mode keys never reach production.** Stripe test-mode API keys and webhook signing secrets are bound to `dev` and `staging` only; production resolves live-mode keys exclusively. This is a hard CI gate on the Vault key-environment binding. See ADR-0037 D10.
   - Add them under a new `## Billing Invariants` section, matching the file's current sectioning convention. Invariant numbers **62, 63, 64 are pre-reserved** as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0037-payment-and-billing-integration.md`
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
- [ ] ADR-0037 header reads `**Status:** Accepted`
- [ ] The ADR-0037 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the three new billing invariants (card data never enters the Grid; no Node subscribes to Stripe webhooks directly; Stripe test-mode keys never reach production), numbered 62, 63, 64, each citing ADR-0037
- [ ] `initiatives/active-initiatives.md` registers the `adr-0037-payment-billing` initiative with a packet checklist
- [ ] No catalog schema change in this packet (the `HoneyDrunk.Billing` Node catalog stubs are added in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0037 D4 — Webhooks: single handler per environment.** A single Stripe webhook endpoint per environment validates the signature, persists the raw event in the buffer, and emits a domain event (`SubscriptionStarted`, `InvoicePaymentFailed`, etc.) onto the Service Bus default topic per ADR-0028. No Node subscribes to Stripe directly.

**ADR-0037 D7 — PCI scope: minimize via Stripe-hosted surfaces.** The Grid never sees a card number; card capture is always through Stripe Checkout or Stripe Elements; the Grid persists only the resulting `payment_method_id`. SAQ A scope.

**ADR-0037 D10 — Test mode and synthetic tenants.** Stripe test mode is wired through `dev` and `staging` via environment-scoped Stripe API keys managed in Vault per ADR-0005. Production never sees test-mode keys — a hard CI gate.

**ADR-0037 Consequences — Invariants.** ADR-0037 adds exactly three invariants: (1) card data never enters the Grid; (2) no Node subscribes to Stripe webhooks directly; (3) Stripe test-mode keys never reach production.

## Constraints
- **Acceptance precedes flip.** ADR-0037 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers 62-64 are pre-reserved** as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number. Do not renumber existing invariants.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0037`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0037 to Accepted, add the three billing invariants to `constitution/invariants.md`, and register the payment-and-billing initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0037 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0037 Payment and Billing Integration rollout, Wave 1.
- ADRs: ADR-0037 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0037 stays Proposed until this PR merges.
- Add the three new invariants as numbers 62, 63, 64 (pre-reserved as part of a 12-ADR batch); if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number. Do not renumber existing invariants.

**Key Files:**
- `adrs/ADR-0037-payment-and-billing-integration.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
