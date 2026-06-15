---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "ops", "infrastructure", "human-only", "adr-0037", "wave-3"]
dependencies: ["work-item:02"]
adrs: ["ADR-0037"]
wave: 3
initiative: adr-0037-payment-billing
node: honeydrunk-architecture
---

> **SUPERSEDED 2026-06-14:** Do not execute this packet from this folder. Recreate the Stripe Tax and product-configuration work as a Payments-scoped work item before assigning it.

# Configure Stripe Tax (Florida + nexus monitoring) and define the Notify Cloud tier products

## Summary
Enable Stripe Tax for the Studio account with the Florida sales-tax registration on and nexus monitoring active for all other jurisdictions (ADR-0037 D6), and define the three Notify Cloud tier products — Free / Pro / Scale — with their base prices and usage meters in the Stripe Dashboard (ADR-0037 D3). This is the Stripe-Dashboard configuration that makes the Stripe account usable for billing; it is human/portal work with no code artifact. Tracked against `HoneyDrunk.Architecture` — the only repo deliverable is a configuration record.

## Context
ADR-0037 commits two pieces of Stripe-Dashboard configuration that have no code representation in the Grid:

- **D6 — Tax.** Stripe Tax is on from day one for every product. The Studio is registered for sales tax in Florida (the entity's home state); every other US state and international jurisdiction is tracked via Stripe Tax's nexus-monitoring surface and registered when thresholds cross. No tax rates are hardcoded; no per-tier tax overrides. Tax is part of the price the customer pays at checkout. The Florida sales-tax registration with the FL Department of Revenue is an independent operator task — it is **not** gated on BDR-0001's iPostal1→VirtualPostMail principal-address change.
- **D3 — Subscription model.** Notify Cloud has three tiers: Free (rate-limited, no card required), Pro, and Scale, each with a monthly base fee and per-meter usage overage. ADR-0037 D3 is explicit that "Tier and overage prices are configured in Stripe, not in the Grid. The Grid stores only the Stripe `subscription_id` and `customer_id` per tenant." ADR-0037's Follow-up Work list states: "Define the three Notify Cloud tier products in Stripe (prices, meters) before GA."

This packet does the Stripe-side configuration. It does **not** touch any consumer-app (B2C) products — those are defined per-app when each consumer Node ships, and ADR-0037 D3 says the consumer apps each get a single monthly and single annual price. Only the Notify Cloud B2B tiers are in scope here, because Notify Cloud (ADR-0027) is the first commercial product and the only one whose standup is in flight.

**This packet is `Actor=Human`.** Enabling Stripe Tax, completing the Florida tax registration, configuring nexus monitoring, and creating products/prices/meters are all Stripe-Dashboard actions. There is no code artifact and nothing is delegable.

## Scope
- Stripe Dashboard — Tax settings: enable Stripe Tax, register Florida, enable nexus monitoring.
- Stripe Dashboard — Products: three Notify Cloud tier products (Free / Pro / Scale) with monthly base prices and usage meters.
- `business/context/` — a short configuration-record document capturing what was configured in Stripe (tier names, the meter names, the Florida registration date, nexus-monitoring status) so the Grid has an off-Stripe record of the Stripe-side shape. **No prices, no API keys, no tax-registration numbers** — names and structure only; the prices are deliberately Stripe-side per D3.

## Proposed Work (human-executed, Stripe Dashboard)
1. **Enable Stripe Tax** — Stripe Dashboard → Tax → enable. Stripe Tax has a small additive fee (~0.5% per transaction per ADR-0037's Operational Consequences) — this is the expected cost.
2. **Register Florida** — under Tax → Registrations, add the Florida sales-tax registration. This requires the Studio's Florida sales-tax registration details; the Studio operator completes the FL Department of Revenue registration if not already registered. This FL DoR registration is an independent operator task — it is **not** gated on BDR-0001's principal-address change. Stripe Tax flags the obligation but does not file it — the operator files.
3. **Enable nexus monitoring** — confirm Stripe Tax's threshold/nexus-monitoring surface is active so other US states and international jurisdictions are tracked. ADR-0037 D6 / Operational Consequences: "Stripe Tax registration in additional states triggers as nexus thresholds cross. The Studio operator is responsible for completing the registration; Stripe Tax flags it but doesn't file it."
4. **Create the Notify Cloud tier products** — Stripe Dashboard → Products. Three products: **Notify Cloud Free**, **Notify Cloud Pro**, **Notify Cloud Scale**. Per ADR-0037 D3: Free has no card required and rate limits (no recurring price, or a $0 price); Pro and Scale each have a monthly base fee. Set the monthly base prices (operator's commercial call — ADR-0037 deliberately leaves the dollar amounts to the operator).
5. **Create usage meters** — Stripe Billing Meters for the per-channel/per-destination metered consumption ADR-0037 D2 describes. The meter event names must match what the future `HoneyDrunk.Billing` Node will push to Stripe's `/v1/billing/meter_events` API — coordinate the meter naming with the Billing standup ADR (packet 04) so the names are consistent. Attach per-meter overage prices to Pro and Scale.
6. **No free trials** — per ADR-0037 D3, do not configure trial periods on Pro or Scale. The Free tier is the no-card entry point; paid-tier trials are deferred.
7. **Confirm everything is in live mode** and mirror the product/meter structure into test mode (test mode is a separate object space within the same account — the products must be re-created or copied there for `dev`/`staging` use per ADR-0037 D10).
8. **Record the configuration** in `business/context/` — a short Markdown record: the three tier product names, the meter names, the Florida registration date, nexus-monitoring on. No dollar amounts, no registration numbers, no keys.

## Affected Files
- `business/context/` — one new configuration-record Markdown file (e.g. `stripe-billing-configuration.md`).

## NuGet Dependencies
None. This packet has no .NET project — it is Stripe Dashboard configuration plus one Markdown record.

## Boundary Check
- [x] The only repo artifact is a configuration record in `business/context/`. Correct home — operator business-context data, not code.
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] Stripe Tax is enabled on the Studio Stripe account
- [ ] The Florida sales-tax registration is added under Stripe Tax → Registrations
- [ ] Stripe Tax nexus monitoring is active for other US states and international jurisdictions
- [ ] Three Notify Cloud products exist in Stripe — Free, Pro, Scale — with monthly base prices (Free at $0 / no card)
- [ ] Usage meters exist in Stripe Billing for the metered consumption, with overage prices attached to Pro and Scale; meter names are coordinated with the `HoneyDrunk.Billing` standup ADR (packet 04)
- [ ] No trial periods are configured on Pro or Scale (ADR-0037 D3 — no free trials at v1)
- [ ] The product / meter structure exists in test mode as well as live mode
- [ ] `business/context/` carries a configuration record listing the tier product names, meter names, Florida registration date, and nexus-monitoring status — with no dollar amounts, registration numbers, or keys
- [ ] No tax-registration number, API key, or other secret appears in the repo (invariant 8)
- [ ] No B2C / consumer-app products are created in this packet — Notify Cloud B2B tiers only

## Human Prerequisites
This entire packet is `Actor=Human`. The human-executed steps are the Proposed Work list above. Specifically:
- [ ] Packet 02 complete — a verified Stripe account must exist.
- [ ] The Studio's Florida sales-tax registration with the FL Department of Revenue — needed to complete the Stripe Tax Florida registration. This is an independent operator task and is **not** gated on BDR-0001's principal-address change; it can be completed at any time.
- [ ] The operator's commercial decision on the Pro and Scale monthly base prices and per-meter overage rates (ADR-0037 leaves the dollar amounts to the operator).
- [ ] The meter naming agreed with packet 04's `HoneyDrunk.Billing` standup ADR so the Stripe-side meter names match what the Billing Node will push.

## Referenced ADR Decisions
**ADR-0037 D6 — Tax: Stripe Tax with nexus tracking; no manual rates.** Stripe Tax is on from day one for every product. Registered for sales tax in Florida (the entity's home state); other jurisdictions tracked via nexus monitoring and registered when thresholds cross. No tax rates hardcoded, no per-tier overrides. Tax is part of the checkout price. The FL DoR sales-tax registration is independent of BDR-0001.

**ADR-0037 D3 — Subscription model.** Notify Cloud (B2B): three tiers Free / Pro / Scale, monthly base fees and per-meter overage. Tier and overage prices are configured in Stripe, not the Grid — the Grid stores only `subscription_id` and `customer_id`. No free trials at v1; the Free tier (rate-limited, no card) is the entry point.

**ADR-0037 D2 — Billing-events flow.** Metered consumption drains to Stripe Meter Events via the `/v1/billing/meter_events` API. The meters created here are the Stripe-side targets of that pipe — their event names must match what `HoneyDrunk.Billing` pushes.

**ADR-0037 D10 — Test mode.** Stripe test mode is wired through `dev` and `staging`; the product/meter structure must exist in test mode as well.

**ADR-0037 Operational Consequences.** Stripe Tax adds ~0.5% per transaction; nexus-threshold crossings trigger operator-filed registrations in new states.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** No tax-registration number, Stripe API key, or webhook secret in the `business/context/` record — names and structure only.

- **Prices live in Stripe, not the Grid.** ADR-0037 D3 is explicit. The `business/context/` record names the tiers and meters; it does not record dollar amounts (those change without an ADR).
- **Notify Cloud B2B tiers only.** Consumer-app B2C products are defined per-app at each consumer Node's ship; not in scope here.
- **Meter names are a coordination point.** They must match the future Billing Node's push payloads — agree them with packet 04 before creating them.

## Labels
`chore`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0037`, `wave-3`

## Agent Handoff

**Objective:** Enable Stripe Tax (Florida + nexus monitoring) and define the three Notify Cloud tier products with usage meters in the Stripe Dashboard, recording the configuration shape in `business/context/`.

**Target:** Tracked against `HoneyDrunk.Architecture`; the work is human-executed in the Stripe Dashboard. `Actor=Human` — `human-only` label set.

**Context:**
- Goal: Make the Stripe account usable for billing — tax calculation on, the Notify Cloud tiers defined — so the future Billing Node has live products and meters to push against.
- Feature: ADR-0037 Payment and Billing Integration rollout, Wave 3.
- ADRs: ADR-0037 D6 / D3 / D2 / D10 / Operational Consequences.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — hard. A verified Stripe account must exist before Tax and products can be configured.

**Constraints:**
- Prices live in Stripe, not the Grid (ADR-0037 D3).
- Notify Cloud B2B tiers only — no consumer-app products.
- Meter names coordinated with the packet-04 Billing standup ADR.
- No secrets / registration numbers in the repo (invariant 8).

**Key Files:**
- `business/context/` — one new configuration-record file.

**Contracts:** None — Stripe Dashboard configuration, no code.
