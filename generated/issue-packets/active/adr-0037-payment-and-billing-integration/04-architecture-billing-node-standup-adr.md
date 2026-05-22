---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0037", "wave-3"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0037"]
wave: 3
initiative: adr-0037-payment-and-billing-integration
node: honeydrunk-architecture
---

# Author the HoneyDrunk.Billing standup ADR (Proposed) — the follow-up ADR-0037 defers code work to

## Summary
Author a new standup ADR for the `HoneyDrunk.Billing` Node and add it to the Grid as **Proposed**. ADR-0037 D2, D9, and its Follow-up Work list explicitly defer the actual Billing Node — its solution, Abstractions, Stripe implementation, and webhook Function App — to a separate standup ADR. This packet writes that ADR. It does **not** scaffold the Node and does **not** flip the new ADR to Accepted; the standup work and the new ADR's acceptance belong to that ADR's own follow-up initiative.

## Context
ADR-0037 is a policy/decision ADR. It chooses Stripe (D1), defines the billing-event flow (D2), the subscription model (D3), the webhook design (D4), the identity binding (D5), the tax stance (D6), the PCI scope (D7), the mobile carve-out (D8), and the Node placement (D9). But ADR-0037 D2 says "`HoneyDrunk.Billing` is the new Node that owns this pipe. Its standup follows the AI-sector standup pattern (Abstractions-first, contract-shape canary, frozen interfaces). **Standup ADR is a follow-up.**" D9 repeats this, and the Follow-up Work list's first item is "Author the `HoneyDrunk.Billing` standup ADR (Abstractions-first, frozen contracts)."

The Grid convention is that an empty cataloged Node gets a dedicated standup ADR before any scaffold packets are written — bundling a Node standup into a feature initiative is an anti-pattern. ADR-0027 (Notify Cloud), ADR-0031 (Audit), and the AI-sector standup ADRs (0016/0017/0018/etc.) are all precedents: each is a standup ADR that decides the Node's package families, frozen contracts, CI canary, boundary rules, and first-PR scaffold checklist, and each then gets its own follow-up scaffold initiative.

Packet 01 of this initiative registers `HoneyDrunk.Billing` as a *planned* Node in the catalogs and context surface. This packet writes the ADR that will govern its actual standup. The scaffold itself — solution layout, the four-or-more projects, the frozen contract surface, the contract-shape canary, the Container Apps wiring for the webhook Function App, the keys-into-Vault work — is the new ADR's follow-up initiative, scoped separately once that ADR is Accepted.

## Scope
- `adrs/ADR-NNNN-stand-up-honeydrunk-billing-node.md` — a new ADR, **Status: Proposed**, where `NNNN` is the next free ADR number at authoring time.
- `adrs/README.md` — add the index row for the new ADR.
- `initiatives/proposed-adrs.md` — register the new ADR under the `## Awaiting (no accepts-declaring packets yet)` section. The new standup ADR has no implementing packets yet (its scaffold initiative is scoped separately, later), so "Awaiting" is the correct section.

## Proposed Implementation
1. **Determine the next free ADR number.** Scan `adrs/` and `adrs/README.md`; the current highest is in the 0040s. Several Proposed-batch ADRs landed 2026-05-21 (through ADR-0047). Claim the next free integer at edit time.
2. **Author the standup ADR.** It must decide, at minimum, drawing its constraints from ADR-0037:
   - **Package families** (ADR-0037 D9): `HoneyDrunk.Billing.Abstractions`, `HoneyDrunk.Billing.Stripe`, `HoneyDrunk.Billing.Webhooks` (a Function App in the Notify shape per ADR-0015). Decide whether `HoneyDrunk.Billing.Cloud` is a separate package or folds into Notify.Cloud.
   - **Frozen contracts** (ADR-0037 D9): `IBillingMeterPipe`, `IBillingCustomerStore`, `IStripeEventHandler` (interfaces — keep the `I`), `BillingMeterEvent`, `BillingCustomerBinding` (records — drop the `I`, use `init` members per the Grid naming and ADR-0035 record rules). These are the *downstream*, Stripe-facing surface; the *upstream* `IBillingEventEmitter` / `BillingEvent` are owned by `HoneyDrunk.Kernel.Abstractions.Tenancy` per ADR-0026 and are **consumed, not redefined**.
   - **The append-only buffer Node / store** (ADR-0037 D2): the buffer that `IBillingEventEmitter`'s default implementation writes to and that drains to Stripe Meter Events on a ≤60-second cadence. Decide its backing store; it is a Tier 0 durable store per ADR-0036.
   - **Idempotency** (ADR-0037 D2, ADR-0042): each `BillingEvent` carries an `IdempotencyKey`; the buffer dedupes on it; the Stripe push reuses it as Stripe's `Idempotency-Key` header. ADR-0042 (Idempotency Contract) is a hard prerequisite — note its status and gate the standup on it.
   - **The webhook handler** (ADR-0037 D4): a single `HoneyDrunk.Billing.Webhooks` endpoint per environment, validating the Stripe signature, persisting the raw event, emitting domain events (`SubscriptionStarted`, `InvoicePaymentFailed`, `CustomerCardExpiring`, etc.) onto the Service Bus default topic per ADR-0028.
   - **Audit emission** (ADR-0037 D2): Billing is Audit's second emitter (after Auth per ADR-0031); every meter-event push emits an Audit record per ADR-0030.
   - **Contract-shape canary** (ADR-0037 D2, the AI-sector pattern): a canary scoped to `HoneyDrunk.Billing.Abstractions`, same shape as ADR-0016/0017/0019/0031 D8.
   - **Stripe API version pinning** (ADR-0037 Operational Consequences): the Node pins an explicit Stripe API version; upgrades are a small ADR amendment.
   - **Vault dependency** (ADR-0037 Affected Nodes): Vault holds Stripe API keys (per environment) and webhook signing secrets; the standup's follow-up initiative seeds them. Stripe test-mode keys never reach production (the invariant packet 00 lands).
   - **Repo visibility**: ADR-0037 implies Billing handles customer/payment-adjacent infrastructure. Decide public vs private against the Grid's public-by-default policy and its revenue/compliance carve-out — Notify.Cloud went private as customer-data-adjacent; Billing should likely follow the same reasoning, but the ADR makes the call explicitly.
   - **First-PR scaffold checklist** (the ADR-0027 D13 / ADR-0031 pattern).
3. **Add the `adrs/README.md` index row.** Status Proposed.
4. **Register in `initiatives/proposed-adrs.md`** — add the new standup ADR under the `## Awaiting (no accepts-declaring packets yet)` section. It belongs in "Awaiting" because no implementing/`accepts:`-declaring packets exist for it yet; its scaffold initiative is scoped separately after the ADR is reviewed.
5. **Do not flip the new ADR to Accepted** and do not author scaffold packets — both belong to the new ADR's own follow-up initiative.

## Affected Files
- `adrs/ADR-NNNN-stand-up-honeydrunk-billing-node.md` (new)
- `adrs/README.md`
- `initiatives/proposed-adrs.md`

## NuGet Dependencies
None. This packet authors a Markdown ADR; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency — this is an ADR, not code.

## Acceptance Criteria
- [ ] A new `ADR-NNNN-stand-up-honeydrunk-billing-node.md` exists with `**Status:** Proposed`, using the next free ADR number
- [ ] The ADR decides package families, the frozen downstream contract surface, the buffer store, idempotency handling, the webhook design, Audit emission, the contract-shape canary, Stripe API version pinning, the Vault dependency, repo visibility, and a first-PR scaffold checklist — all consistent with ADR-0037's D-decisions
- [ ] The ADR is explicit that `IBillingEventEmitter` / `BillingEvent` are Kernel-owned (ADR-0026) and consumed, not redefined
- [ ] The ADR notes ADR-0042 (Idempotency Contract) as a hard prerequisite and its current status
- [ ] `adrs/README.md` carries the new ADR's index row, Status Proposed
- [ ] `initiatives/proposed-adrs.md` registers the new ADR under the `## Awaiting (no accepts-declaring packets yet)` section
- [ ] The new ADR is NOT flipped to Accepted and NO scaffold packets are authored in this packet

## Human Prerequisites
None. (The new ADR's eventual acceptance is a future scope-agent step after its content is reviewed; that is not a prerequisite of *this* packet.)

## Referenced ADR Decisions
**ADR-0037 D2 — Billing-events flow.** `IBillingEventEmitter` → append-only buffer Node → Stripe Meter Events (≤60s cadence). Idempotent end-to-end per ADR-0042. Buffer is Tier 0 per ADR-0036. Audit-emitting per ADR-0030. "`HoneyDrunk.Billing` is the new Node that owns this pipe. Its standup follows the AI-sector standup pattern. **Standup ADR is a follow-up.**"

**ADR-0037 D9 — `HoneyDrunk.Billing` Node placement.** Ops sector. `HoneyDrunk.Billing.Abstractions` (`IBillingMeterPipe`, `IBillingCustomerStore`, `IStripeEventHandler`, `BillingMeterEvent`, `BillingCustomerBinding`), `HoneyDrunk.Billing.Stripe`, `HoneyDrunk.Billing.Webhooks` (Function App per ADR-0015). The Kernel-level `IBillingEventEmitter` is upstream; this Node's interfaces are the downstream Stripe-facing surface.

**ADR-0037 D4 — Webhooks.** Single endpoint per environment, signature validation, raw-event persistence, domain events onto the Service Bus default topic per ADR-0028.

**ADR-0037 Follow-up Work.** First item: "Author the `HoneyDrunk.Billing` standup ADR (Abstractions-first, frozen contracts)." This packet executes that follow-up.

**ADR-0026 — `IBillingEventEmitter` / `BillingEvent`** live in `HoneyDrunk.Kernel.Abstractions.Tenancy` with a `NoopBillingEventEmitter` default; real emitters ship in consumer-Node provider packages. The Billing Node provides a real emitter but does not own the contract.

## Constraints
- **Author Proposed, not Accepted.** The new ADR lands as Proposed. Its acceptance and its scaffold initiative are out of scope for this packet — they follow once the ADR content is reviewed. This mirrors how ADR-0027 / ADR-0031 / the AI-sector standup ADRs were handled.
- **No scaffold packets in this initiative.** The `HoneyDrunk.Billing` solution, projects, contracts, canary, and Container Apps wiring belong to the new ADR's own follow-up initiative — scoped separately. An empty cataloged Node gets its standup ADR first; scaffold does not get bundled into a feature initiative.
- **Claim the next free ADR number at edit time.** Several Proposed-batch ADRs landed 2026-05-21; scan `adrs/` and `adrs/README.md` and take whatever the next free integer is.
- **Kernel owns the upstream emitter.** The ADR must not propose redefining `IBillingEventEmitter` / `BillingEvent` in `HoneyDrunk.Billing.Abstractions` — they are Kernel.Abstractions.Tenancy contracts per ADR-0026.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0037`, `wave-3`

## Agent Handoff

**Objective:** Author the `HoneyDrunk.Billing` standup ADR as Proposed — the follow-up ADR-0037 D2/D9 defer the Node's code work to — and add its `adrs/README.md` index row.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Produce the standup ADR that will govern the actual `HoneyDrunk.Billing` Node, so the Node's scaffold can be scoped as that ADR's own follow-up initiative rather than bundled here.
- Feature: ADR-0037 Payment and Billing Integration rollout, Wave 3.
- ADRs: ADR-0037 D2 / D4 / D9 / Follow-up Work (the deferral); ADR-0026 (Kernel-owned emitter); ADR-0042 (idempotency prerequisite); ADR-0015 (Function App / Container Apps hosting); ADR-0028 (Service Bus default topic); ADR-0036 (Tier 0 buffer); ADR-0030/0031 (Audit emission).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0037 should be Accepted so the new standup ADR references it as a live decision.
- `packet:01` — soft. The `HoneyDrunk.Billing` planned-Node catalog/context registration should exist so the standup ADR references a registered Node.

**Constraints:**
- New ADR is authored Proposed, not Accepted.
- No scaffold packets — the Node standup is the new ADR's own follow-up initiative.
- Claim the next free ADR number at edit time.
- The new ADR must treat `IBillingEventEmitter` / `BillingEvent` as Kernel-owned (ADR-0026), not redefined.

**Key Files:**
- `adrs/ADR-NNNN-stand-up-honeydrunk-billing-node.md` (new)
- `adrs/README.md`
- `initiatives/proposed-adrs.md` — register under `## Awaiting (no accepts-declaring packets yet)`

**Contracts:** None changed — this ADR *proposes* a future contract surface; nothing is implemented.
