# Dispatch Plan: Payment and Billing Integration (ADR-0037)

**Date:** 2026-05-22 (initial scope — drafted ahead of ADR-0037 acceptance).
**Trigger:** ADR-0037 (Payment and Billing Integration) — Proposed 2026-05-21, part of the 2026-05-21 batch of cross-cutting Grid-gap ADRs. Scoped now so the packet set is ready when the ADR lands. The forcing function per ADR-0037's Context is the Notify Cloud GA milestone — the first paying tenant cannot be onboarded without a payment processor, a subscription model, an invoice surface, tax handling, and a customer portal, none of which exist in the Grid today.
**Type:** Multi-repo in classification, but every packet's `target_repo` is `HoneyDrunk.Architecture`. ADR-0037 is a *policy/decision* ADR — it chooses Stripe and commits Grid-wide rules, but the actual billing code is explicitly deferred by ADR-0037 itself (D2, D9, Follow-up Work) to a **separate `HoneyDrunk.Billing` standup ADR**. This initiative lands the policy, the Grid-governance changes, the planned-Node registration, the human Stripe-account work, and authors that follow-up standup ADR. It does **not** scaffold the Billing Node.
**Sector:** Ops / cross-cutting.
**Site sync required:** No. Payment-processor choice, tier structure, and Stripe configuration are operational/commercial artifacts, not public-facing Studios marketing content. Re-evaluate only when a consumer app or Notify Cloud publishes a public pricing page — that would be a separate site-sync packet sourced from the Stripe-side product definitions, not from this ADR.

**Rollback plan:**
- Packets 00, 01, 04 are docs/catalog/ADR edits in `HoneyDrunk.Architecture` — they `git revert` cleanly. Reverting packet 00 un-flips ADR-0037 and removes the three invariants; reverting packet 01 removes the `HoneyDrunk.Billing` planned-Node catalog/context entry; reverting packet 04 removes the new standup ADR. None has a runtime consumer.
- Packets 02 and 03 are `Actor=Human` Stripe-Dashboard work. "Reverting" packet 02 means closing the Stripe account — not advisable once verified, and pointless if no billing has occurred. "Reverting" packet 03 means disabling Stripe Tax and deleting products — also forward-only operational state. Treat 02 and 03 as forward-only; if not yet done, the steady state is simply "Stripe not yet provisioned," which is the pre-ADR baseline.
- The one genuinely irreversible step is opening the live Stripe account against a *wrong* address (packet 02) — which is exactly why packet 02 is hard-gated on BDR-0001. Do the gate right and there is nothing to roll back.

## Summary

ADR-0037 decides where billing events terminate: **Stripe** as the Grid's sole payment processor for every product, B2B and B2C — Stripe Billing, Stripe Tax, Stripe Checkout, Stripe Customer Portal, no Stripe Connect (D1). It defines the billing-event flow `IBillingEventEmitter` → append-only buffer Node → Stripe Meter Events, idempotent end-to-end (D2); the subscription model — Notify Cloud Free/Pro/Scale with usage overage, single monthly/annual prices per consumer app, no free trials at v1 (D3); a single webhook endpoint per environment emitting domain events onto the Service Bus default topic (D4); the Stripe-customer ↔ Grid-tenant/principal binding (D5); Stripe Tax on from day one with nexus tracking (D6); PCI SAQ A scope via Stripe-hosted card capture (D7); the mobile in-app-purchase carve-out (D8); the `HoneyDrunk.Billing` Node placement in Ops (D9); and test-mode handling (D10).

**ADR-0037 is policy, not code.** The actual `HoneyDrunk.Billing` Node — its solution, Abstractions, Stripe implementation, and webhook Function App — is deferred by ADR-0037's own text (D2: "Standup ADR is a follow-up"; D9; Follow-up Work item 1) to a separate standup ADR. The Grid convention is that an empty cataloged Node gets a dedicated standup ADR before any scaffold packets; bundling a Node standup into a feature initiative is an anti-pattern. So this initiative authors that standup ADR (packet 04) and stops there — the Billing Node scaffold is the new ADR's own follow-up initiative, scoped separately once it is Accepted.

This initiative ships **5 packets** (`00`–`04`) across **three waves**:

- **Wave 1** — governance: ADR-0037 acceptance + the three billing invariants + initiative registration (00).
- **Wave 2** — the planned-Node registration (01, Agent) and the Stripe-account provisioning (02, Human, hard-gated on BDR-0001). Independent of each other; run in parallel.
- **Wave 3** — the Stripe Tax + tier-product configuration (03, Human) and the `HoneyDrunk.Billing` standup ADR (04, Agent). Independent of each other; run in parallel.

## Important constraints (from ADR-0037 and the Grid conventions)

- **This initiative does NOT scaffold the Billing Node.** ADR-0037 D2/D9 defer the Node's code to a follow-up standup ADR. Packet 04 authors that ADR as Proposed; the scaffold is its own follow-up initiative. An empty cataloged Node gets its standup ADR first.
- **Packet 02 is hard-gated on BDR-0001.** A Stripe account is opened against a legal entity with a verified address. BDR-0001 (Accepted) is moving HoneyDrunk Studios LLC's principal office address from iPostal1 to VirtualPostMail, with a Sunbiz amendment targeted before October 2026. `business/context/entity.md` still records the address as in-flux. Do not open the live Stripe account against an address that is about to change — packet 02 forces an explicit operator decision (wait for the address to settle, recommended; or open now and update later, only if a milestone genuinely cannot wait). The billing pipe is *not* on a pre-October-2026 critical path — ADR-0027 D13 ships Notify Cloud's billing adapter as a stub — so there is slack to wait.
- **Card data never enters the Grid.** ADR-0037 D7 / new invariant. All card capture is Stripe-hosted (Checkout / Elements); the Grid stores only Stripe identifiers and `payment_method_id`. PCI SAQ A scope.
- **No Node subscribes to Stripe webhooks directly.** ADR-0037 D4 / new invariant. Webhooks land in `HoneyDrunk.Billing.Webhooks`; domain events flow on the Service Bus default topic per ADR-0028.
- **Stripe test-mode keys never reach production.** ADR-0037 D10 / new invariant. A hard CI gate on the Vault key-environment binding.
- **`IBillingEventEmitter` / `BillingEvent` are Kernel-owned.** Per ADR-0026 they live in `HoneyDrunk.Kernel.Abstractions.Tenancy`. The Billing Node provides the first *real* (non-noop) emitter but does not own the contract. Packet 01 and packet 04 both say so explicitly.
- **Prices live in Stripe, not the Grid.** ADR-0037 D3. The Grid stores only `subscription_id` / `customer_id`. The `business/context/` records in packets 02/03 name the tiers and meters but record no dollar amounts.
- **No secrets in the repo.** ADR-0037's keys (Stripe API keys, webhook signing secrets) are seeded into Vault under the Billing standup ADR's own packets — never committed. The human packets 02/03 record only that the account/config exists (invariant 8).

## Wave Diagram

### Wave 1 — Governance

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0037** — flip status, add the three billing invariants, register the initiative — [`00-architecture-adr-0037-acceptance.md`](00-architecture-adr-0037-acceptance.md)
  - Blocked by: nothing.

**Wave 1 exit criteria:**
- ADR-0037 reads `**Status:** Accepted`; the three billing invariants (card data never enters the Grid; no Node subscribes to Stripe webhooks directly; Stripe test-mode keys never reach production) are in `constitution/invariants.md` as numbers **62, 63, 64**; the initiative is registered.

**Invariant numbering:** Invariant numbers **62, 63, 64 are pre-reserved** as ADR-0037's block within a 12-ADR batch. If any invariant above 51 lands from outside this batch before packet 00 merges, shift this block upward — never reuse a number.

### Wave 2 — Planned-Node registration + Stripe account (parallel)

Packets 01 and 02 are independent and run in parallel. 01 is `Actor=Agent`; 02 is `Actor=Human` and hard-gated on BDR-0001.

- [ ] `HoneyDrunk.Architecture`: Register the `HoneyDrunk.Billing` Node — context folder, sector map, planned catalog edges — [`01-architecture-billing-node-catalog-and-context.md`](01-architecture-billing-node-catalog-and-context.md)
  - Blocked by: Wave 1 — `00` (soft — the context folder's `invariants.md` cross-references the packet-00 invariant numbers).
- [ ] `HoneyDrunk.Architecture`: Provision the Stripe account (live + test) under the Studio entity — [`02-architecture-provision-stripe-accounts.md`](02-architecture-provision-stripe-accounts.md)
  - Blocked by: Wave 1 — `00` (soft — ADR-0037 should be Accepted before provisioning against it).
  - **`Actor=Human` — `human-only` label set.** Stripe-Dashboard account creation and KYC. **HARD real-world precondition: BDR-0001** — the entity's principal address must be final (or the operator explicitly elects to open-now-and-update-later). This precondition is enforced by the packet's Human Prerequisites checklist, not the `dependencies:` array, because BDR-0001 is a business decision record with its own action-item track, not a packet.

**Wave 2 exit criteria:**
- `repos/HoneyDrunk.Billing/` exists with the five context files; `constitution/sectors.md` lists Billing in Ops; `catalogs/nodes.json` carries the `honeydrunk-billing` descriptor entry; `catalogs/relationships.json` carries the `honeydrunk-billing` dependency entry with `consumes` edges to Vault and Audit and the reciprocal `consumed_by_planned` edges on Vault and Audit.
- A verified Stripe account exists under HoneyDrunk Studios LLC with the Chase payout account bound; `business/context/entity.md` records it; no secrets in the repo.

### Wave 3 — Stripe configuration + Billing standup ADR (parallel)

Packets 03 and 04 are independent and run in parallel. 03 is `Actor=Human`; 04 is `Actor=Agent`.

- [ ] `HoneyDrunk.Architecture`: Configure Stripe Tax (Florida + nexus monitoring) and define the Notify Cloud tier products — [`03-architecture-configure-stripe-tax-and-tier-products.md`](03-architecture-configure-stripe-tax-and-tier-products.md)
  - Blocked by: Wave 2 — `02` (hard — a verified Stripe account must exist before Tax and products can be configured).
  - **`Actor=Human` — `human-only` label set.** Stripe-Dashboard Tax enablement, Florida registration, and product/meter creation.
- [ ] `HoneyDrunk.Architecture`: Author the `HoneyDrunk.Billing` standup ADR (Proposed) — [`04-architecture-billing-node-standup-adr.md`](04-architecture-billing-node-standup-adr.md)
  - Blocked by: Wave 1 — `00` (soft); Wave 2 — `01` (soft — the standup ADR references the registered planned Node).

**Wave 3 exit criteria:**
- Stripe Tax is on with the Florida registration and nexus monitoring active; the three Notify Cloud tier products and their usage meters exist in both live and test mode; `business/context/` records the configuration shape.
- A new `HoneyDrunk.Billing` standup ADR exists as Proposed, with its `adrs/README.md` index row, deciding the package families, frozen contracts, buffer store, webhook design, canary, and first-PR scaffold checklist.

## Out-of-scope / deferred items

- **The `HoneyDrunk.Billing` Node scaffold.** The solution, the four-or-more projects (`HoneyDrunk.Billing.Abstractions`, `.Stripe`, `.Webhooks`, possibly `.Cloud`), the frozen contract surface (`IBillingMeterPipe`, `IBillingCustomerStore`, `IStripeEventHandler`, `BillingMeterEvent`, `BillingCustomerBinding`), the append-only buffer store, the contract-shape canary, and the Container Apps / Function App wiring are all deferred to the **`HoneyDrunk.Billing` standup ADR's own follow-up initiative** (the ADR is authored by packet 04 of this initiative). Bundling a Node standup into a feature initiative is an anti-pattern; the standup ADR comes first. Recorded here so the gap is not silently assumed closed.
- **Creating the `HoneyDrunk.Billing` GitHub repo.** A human-only org-admin chore — belongs to the standup ADR's follow-up initiative, where the public-vs-private visibility decision (the standup ADR makes the call) is acted on.
- **Seeding Stripe API keys and webhook signing secrets into Vault.** Per ADR-0037 D10 and the Affected-Nodes list, Vault holds the Stripe keys per environment. Seeding them is a human/portal step that belongs to the Billing standup initiative — there is no Billing Key Vault to hold them until the Node exists.
- **The Stripe billing-adapter implementation in `HoneyDrunk.Notify.Cloud`.** ADR-0027 D13 ships `HoneyDrunk.Notify.Cloud.Billing.Stripe 0.1.0` as a *stub*. Wiring it to the real Billing pipe is downstream of the Billing Node standup — tracked by the Notify Cloud initiative / the Billing standup, not here.
- **The mobile in-app-purchase ADR (ADR-0037 D8).** ADR-0037 commits the principle (mobile-purchased subscriptions use platform IAP; web uses Stripe; cross-grant is one-way Stripe→mobile) but explicitly defers the mechanism to a follow-up ADR tied to the still-backlogged mobile-platform ADR. Not a packet here.
- **The accounting-software BDR (ADR-0037 D6).** ADR-0037 says tax-remittance reporting currently flows to a spreadsheet and a future BDR will pick accounting software. Deferred by ADR-0037 itself; not a packet here.
- **Consumer-app (B2C) products in Stripe.** Packet 03 defines only the Notify Cloud B2B Free/Pro/Scale tiers. Each consumer app (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0007 Arcadia, PDR-0008 Curiosities) gets its single monthly/annual price defined when that Node ships — those Nodes are not scaffolded.
- **`catalogs/grid-health.json` / `contracts.json` / `modules.json` entries for Billing.** Packet 01 registers Billing in `nodes.json` (a descriptor entry, matching the `honeydrunk-observe` precedent) and `relationships.json` (the dependency edges). The DR-tier assignment, the shipped-contract registry, and the package list reconcile via `hive-sync` once the Node is actually scaffolded under its standup ADR.

## After filing — board fields and blocking relationships

The `file-packets` pipeline sets Status, Wave, Node, Tier, Actor, Initiative, and ADR fields from frontmatter and wires `addBlockedBy` automatically from each packet's `dependencies:` array. For reference, the blocking graph:

- `01` blocked-by `00` (soft)
- `02` blocked-by `00` (soft)
- `03` blocked-by `02` (hard)
- `04` blocked-by `00` (soft), `01` (soft)

BDR-0001 is **not** in any `dependencies:` array — it is a business decision record with its own action-item track, not a packet, and it has no `filed-packets.json` entry to resolve against. Packet 02's hard dependency on the BDR-0001 address being final is enforced by packet 02's Human Prerequisites checklist and the CAUTION block at the top of that packet.

**Actor:** packets 00, 01, 04 are `Actor=Agent` (ADR flip + invariants, planned-Node catalog/context registration, ADR authoring — all delegable). **Packets 02 and 03 are `Actor=Human`** — they carry the `human-only` label because Stripe-Dashboard account creation, KYC, bank binding, Tax enablement, and product/meter configuration are the *entire* work item, with no code artifact, and nothing is delegable to an agent.

Verify a wave landed by checking The Hive for the new items + their blocked-by chains, not by inspecting the workflow log.

## Notes

- **Acceptance precedes flip.** ADR-0037 stays Proposed until packet 00's PR merges.
- **The three new invariants land in packet 00**, not a separate `constitution/invariants.md` packet — (1) card data never enters the Grid; (2) no Node subscribes to Stripe webhooks directly; (3) Stripe test-mode keys never reach production. They take the pre-reserved numbers **62, 63, 64** (ADR-0037's block within a 12-ADR batch). If any invariant above 51 lands from outside the batch before packet 00 merges, shift the block upward — never reuse a number.
- **No new repo, no scaffold, no new runtime contract in this initiative.** This initiative ships an ADR flip + three invariants, one planned-Node catalog/context registration, two human Stripe-Dashboard packets, and one new Proposed standup ADR. `catalogs/contracts.json` is untouched — the Billing contracts are *proposed* by packet 04's ADR, not implemented.
- **BDR-0001 is the load-bearing gate.** The single most important sequencing fact in this initiative: do not open the live Stripe account against an address BDR-0001 is changing. Packet 02 forces the operator decision explicitly and recommends waiting for the BDR-0001 address to settle. The billing pipe has slack — ADR-0027 D13's stub means no GA milestone before October 2026 depends on it.
- **No Azure resources are provisioned by this initiative.** The Stripe work is all in the Stripe Dashboard; the Vault key-seeding and the webhook Function App / Container App belong to the Billing standup initiative. The Stripe-Dashboard steps in packets 02/03 are written as Dashboard walkthroughs per the operator's portal-over-CLI preference.
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as a historical record; packet bodies are immutable post-filing (invariant 24).

## Open questions for the operator

1. **BDR-0001 timing vs. the billing pipe.** The recommendation is Option A — wait for the BDR-0001 VPM address / Sunbiz amendment to be final before opening the Stripe account (packet 02). This is a real schedule call: if the operator wants the Stripe account open sooner, Option B is available but adds a later in-Stripe address update. Confirm the preference, or leave packet 02 not-yet-started until BDR-0001's address settles.
2. **`HoneyDrunk.Billing` repo visibility.** Packet 04's standup ADR must decide public vs private. The Grid is public-by-default; Notify.Cloud went private as customer-data-adjacent. Billing handles payment-adjacent infrastructure and Stripe identifiers — the likely call is private, but the standup ADR makes it explicitly. Flagged because it interacts with the public-default policy and may warrant operator input at ADR-review time.
3. **Notify Cloud as a `relationships.json` entry.** ADR-0037's Consequences lists a `NotifyCloud→Billing` edge, but `honeydrunk-notify-cloud` is not yet a `relationships.json` node (ADR-0027 is Proposed, the repo does not exist). Packet 01 omits that edge and leaves a one-line PR note; `hive-sync` adds it when Notify Cloud is registered. Confirm that is acceptable, or whether Notify Cloud should be pre-registered as a planned Node first.

## Archival

Per ADR-0008 D10, when every filed and in-scope packet in this initiative reaches `Done` on the org Project board and the wave exit criteria are met, the entire `active/adr-0037-payment-billing/` folder moves to `archive/adr-0037-payment-billing/` in a single commit. Partial archival is forbidden.

The two `Actor=Human` Stripe packets (02, 03) are in-scope and not exempt from the archival gate. Note that packet 02 may legitimately sit in a not-yet-started state for an extended period if the operator elects to wait for BDR-0001 — the initiative's archival waits for it.

## Revision history

- **2026-05-22 initial scope** — 5 packets across three waves. Drafted ahead of ADR-0037 acceptance; packets are pending-acceptance drafts, not yet filed as GitHub Issues. The `HoneyDrunk.Billing` Node scaffold, the Billing GitHub repo, Vault key-seeding, the mobile-IAP ADR, the accounting-software BDR, and consumer-app B2C products are recorded as out-of-scope / deferred follow-ups. Packet 02 is hard-gated on BDR-0001.
