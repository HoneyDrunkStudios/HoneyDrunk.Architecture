---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "ops", "infrastructure", "human-only", "adr-0037", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0037"]
wave: 2
initiative: adr-0037-payment-billing
node: honeydrunk-architecture
---

> **SUPERSEDED 2026-06-14:** Do not execute this packet from this folder. Recreate the Stripe-account work as a Payments-scoped work item before assigning it.

# Provision the Stripe account (live + test) under the Studio entity — HARD-GATED on BDR-0001

# > [!CAUTION]
# > **HARD PRECONDITION — BDR-0001.** A Stripe account is opened against a legal entity with a verified address and a bank account for payouts. BDR-0001 ("Mailbox Service Replacement") changes HoneyDrunk Studios LLC's **principal office address on file with Sunbiz** — the move from iPostal1 to VirtualPostMail is *in progress*, with a target of completing the Sunbiz amendment before October 2026. `business/context/entity.md` currently records the principal office address as "(currently iPostal1 — see BDR-0001, switch in progress)". **Do not open the live Stripe account against an address that is about to change.** See the "BDR-0001 gate" section below for the decision this packet forces.

## Summary
Create the Studio's Stripe account (live mode + test mode are the same account) under HoneyDrunk Studios LLC, complete Stripe's business-verification (KYC) flow, and bind it to the Studio's Chase business bank account for payouts. This is the human/portal foundation every other billing packet depends on — there is no code artifact and nothing is delegable to an agent. Tracked against `HoneyDrunk.Architecture` because the only repo deliverable is a record in `business/context/entity.md`; the substantive work is account creation in the Stripe Dashboard.

## Context
ADR-0037 D1 adopts Stripe as the Grid's sole payment processor. ADR-0037's Follow-up Work list states explicitly: "Provision Stripe accounts (live + test) under the Studio entity; bind to Studio bank account per BDR-0001."

Opening a Stripe account requires, at minimum: the legal business name, the business's registered/principal address, an EIN, a business representative's identity details, and a bank account for payouts. Stripe runs KYC verification on this data. **The address Stripe verifies must be the address that is actually on file for the entity** — a mismatch between the Stripe-registered address and the Sunbiz principal office address creates a verification and tax-registration discrepancy that is painful to unwind once Stripe Tax is configured (packet 03).

### BDR-0001 gate

BDR-0001 is **Accepted** and decides the Studio is moving its mailbox/principal address from iPostal1 to VirtualPostMail (VPM, Tampa), with a Sunbiz Articles-of-Amendment filing targeted before October 2026. Until that amendment is filed, the entity's address is in flux. This packet forces one of two operator decisions:

- **Option A (recommended) — wait for the BDR-0001 address to settle.** Complete the BDR-0001 action items far enough that the VPM address is the live principal address (VPM account active, USPS Form 1583 done, Sunbiz amendment filed), *then* open the Stripe account against the final VPM address. This avoids ever having to update the address inside a verified, tax-configured Stripe account. ADR-0037's billing pipe is **not** on the immediate critical path for any GA milestone that predates October 2026 — Notify Cloud's standup (ADR-0027) ships the billing-adapter as a *stub* per ADR-0027 D13, so there is slack to wait.
- **Option B — open Stripe now against the current iPostal1 address, update later.** Acceptable only if a billing milestone genuinely cannot wait. If chosen, the address update inside Stripe must be added to the BDR-0001 "Update vendor address book" action item (BDR-0001 already names "payment processors" in that item) and the Stripe Tax registration (packet 03) must be re-checked after the address change.

**This packet is `Actor=Human`.** The operator must pick Option A or Option B before executing. The dispatch plan recommends Option A and treats packet 02 as not-yet-startable until the BDR-0001 address is settled, unless the operator explicitly elects Option B and records the reason.

## Scope
- The Stripe account itself — created in the Stripe Dashboard (https://dashboard.stripe.com) under HoneyDrunk Studios LLC.
- `business/context/entity.md` — add a "Payment processing" entry under Banking recording that Stripe is the processor, the account is live, and the date; add Stripe to the Recurring Vendors table (Stripe has no flat annual fee — note it as "per-transaction, ~2.9% + $0.30").
- The Stripe API keys and webhook signing secrets are **out of scope for this packet** — they are seeded into Vault under the `HoneyDrunk.Billing` standup ADR's own packets, once there is a Billing Node and a Key Vault to hold them. This packet only proves the account exists.

## Proposed Work (human-executed, Stripe Dashboard)
1. **Resolve the BDR-0001 gate** — pick Option A or Option B above. If Option A, do not proceed until the VPM address is the live principal address. Record the choice in this packet's tracking issue.
2. **Create the Stripe account** at https://dashboard.stripe.com — sign up under a Studio-controlled email. Business type: Company / LLC. Legal business name: HoneyDrunk Studios LLC.
3. **Complete business verification (KYC):** enter the EIN (from `business/context/entity.md` — kept off-repo, do not paste it anywhere committed), the registered/principal business address (the final address per the BDR-0001 gate decision), and the business representative's identity details. Stripe verifies these.
4. **Bind the payout bank account:** connect the Chase business checking account as the payout destination. Stripe will run micro-deposit or instant verification.
5. **Confirm test mode:** Stripe accounts include a test-mode toggle in the Dashboard — confirm test mode is available (it is, by default, for every account). Test mode and live mode share one account; there is no separate test account to create.
6. **Do NOT yet** create products, prices, meters, or webhook endpoints, and do NOT yet generate or copy API keys into Vault — those are packet 03 (Tax + products) and the `HoneyDrunk.Billing` standup ADR's packets (keys → Vault). This packet stops at "the account exists, is verified, and can take payouts."
7. **Record in `business/context/entity.md`:** add the Banking "Payment processing" line and the Recurring Vendors row for Stripe, plus a Change Log entry. Record only that the account exists and its creation date — **no API keys, no account secret, no EIN** in the repo.

## Affected Files
- `business/context/entity.md` — Banking section + Recurring Vendors table + Change Log entry.

## NuGet Dependencies
None. This packet has no .NET project — it is Stripe Dashboard account creation plus one Markdown record.

## Boundary Check
- [x] The only repo artifact is a record in `business/context/entity.md` (the operator's business-context area in the Architecture repo). Correct home — this is entity/vendor data, not code.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] The BDR-0001 gate decision (Option A or B) is recorded in this packet's tracking issue with a one-line rationale
- [ ] A Stripe account exists under HoneyDrunk Studios LLC and has passed Stripe's business verification (KYC)
- [ ] The Chase business checking account is connected as the Stripe payout destination and verified
- [ ] Test mode is confirmed available in the Stripe Dashboard for the account
- [ ] `business/context/entity.md` records Stripe as the payment processor under Banking, adds a Recurring Vendors row, and has a Change Log entry
- [ ] No Stripe API key, account secret, webhook signing secret, or EIN appears anywhere in the repo (invariant 8 — secret values never appear in repos/logs/telemetry)
- [ ] No Stripe products, prices, meters, or webhook endpoints are created in this packet (those are packet 03 and the Billing standup)

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] **BDR-0001 must be far enough along that the entity's principal address is final** (Option A) — VPM account active, USPS Form 1583 complete, Sunbiz Articles of Amendment filed — OR the operator has explicitly elected Option B and recorded the reason. See [`business/decisions/BDR-0001-mailbox-service-replacement.md`](../../../../business/decisions/BDR-0001-mailbox-service-replacement.md).
- [ ] A Studio-controlled email address for the Stripe account owner.
- [ ] The Studio EIN on hand (kept off-repo).
- [ ] Chase business checking account details for payout binding.
- [ ] Business representative identity documents Stripe's KYC flow may request.

## Referenced ADR Decisions
**ADR-0037 D1 — Processor: Stripe.** The Grid adopts Stripe as its sole payment processor for all products, B2B and B2C: Stripe Billing, Stripe Tax, Stripe Checkout, Stripe Customer Portal. No Stripe Connect — the Studio is merchant-of-record for every product.

**ADR-0037 Follow-up Work.** "Provision Stripe accounts (live + test) under the Studio entity; bind to Studio bank account per BDR-0001." This packet executes that follow-up. ADR-0037 explicitly cross-references BDR-0001 in D6 as well ("the Studio is registered for sales tax in Florida, entity state per BDR-0001").

**ADR-0037 D10 — Test mode.** Stripe test mode is wired through `dev` and `staging`. Test and live mode are the same Stripe account — this packet confirms test mode is available; the environment-scoped key seeding into Vault happens under the Billing standup.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** No Stripe API key, secret key, restricted key, webhook signing secret, or the Studio EIN may be committed to the repo. `business/context/entity.md` records only that the account exists.

- **HARD GATE on BDR-0001.** Do not open the live Stripe account against an address that BDR-0001 is in the process of changing, unless Option B is explicitly elected and recorded.
- **Stop at account creation.** No products, no prices, no meters, no webhook endpoints, no API-key extraction. Packet 03 does Tax + products; the Billing standup ADR does keys-into-Vault.
- **The billing pipe is not on a pre-October-2026 critical path.** ADR-0027 D13 ships Notify Cloud's billing adapter as a stub; there is slack to take Option A and wait for the BDR-0001 address to settle.

## Labels
`chore`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0037`, `wave-2`

## Agent Handoff

**Objective:** Create and verify the Studio's Stripe account under HoneyDrunk Studios LLC, bind the Chase payout account, and record the account's existence in `business/context/entity.md` — gated on the BDR-0001 address being final.

**Target:** Tracked against `HoneyDrunk.Architecture`; the work is human-executed in the Stripe Dashboard. `Actor=Human` — `human-only` label set.

**Context:**
- Goal: Stand up the Stripe account that ADR-0037 D1 commits the Grid to, so packet 03 (Tax + products) and the future Billing standup (keys → Vault) have an account to configure.
- Feature: ADR-0037 Payment and Billing Integration rollout, Wave 2.
- ADRs: ADR-0037 D1 / D10 / Follow-up Work; BDR-0001 (the address gate).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0037 should be Accepted before the account is provisioned against its decisions.
- **BDR-0001** — hard real-world precondition (not a packet dependency — BDR-0001 is Accepted and has its own action-item track). The Stripe account's registered address must be the final BDR-0001 address. This is enforced by the Human Prerequisites checklist, not the `dependencies:` array.

**Constraints:**
- Hard gate on BDR-0001 — see the CAUTION block at the top of the packet.
- No secrets in the repo (invariant 8).
- Stop at account creation — no products/prices/meters/webhooks/keys.

**Key Files:**
- `business/context/entity.md` — the only repo artifact.

**Contracts:** None — Stripe Dashboard account creation, no code.
