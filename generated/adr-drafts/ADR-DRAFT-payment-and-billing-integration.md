# ADR-DRAFT: Payment and Billing Integration

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

## Context

ADR-0026 promoted `IBillingEventEmitter` and `BillingEvent` into Kernel.Abstractions as Grid-wide multi-tenant primitives. `BillingEvent` describes a metered, attributable, idempotent unit of consumption (per its frozen shape). ADR-0027 (Notify Cloud) is the first consumer; PDR-0003 through PDR-0008 (six consumer-app PDRs) all anticipate paid tiers that will emit billing events through the same primitive.

What is missing: a decision about where billing events **terminate**. Today there is no payment-processor integration, no subscription model, no invoice surface, no tax handling, no customer-portal surface, and no SCA/3DS-handling code anywhere in the Grid. The Notify Cloud GA milestone requires all of these. The first paying tenant cannot be onboarded without them.

This is a one-way door. Picking a processor commits the Grid to its data model, its webhook shape, its tax engine, and its support obligations. Revisiting later costs a customer-data migration that touches Auth, Notify.Cloud, Audit, and (eventually) every revenue Node.

Two product shapes are simultaneously in scope:

- **B2B usage-metered (Notify Cloud)** — tenant has an API key, consumption is metered per channel/destination, invoicing is monthly arrears with tier-based base fees and usage overage.
- **B2C subscription (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0007 Arcadia, PDR-0008 Curiosities)** — end-user has an account, subscribes to a plan, monthly or annual recurring with proration.

The processor choice has to handle both. Connect-style platform models (used by marketplaces) are not in scope; the Studio is the merchant of record for every product.

## Decision

### D1 — Processor: Stripe (Billing + Tax)

The Grid adopts **Stripe** as its sole payment processor for all products, B2B and B2C. Specifically:

- **Stripe Billing** for subscription and usage-metered invoicing.
- **Stripe Tax** for sales-tax/VAT calculation and remittance (including nexus tracking — load-bearing as the Studio crosses state thresholds).
- **Stripe Checkout** as the default self-service signup surface (B2C) and the initial-payment surface for Notify Cloud.
- **Stripe Customer Portal** as the default tenant-self-service surface (cancel, update card, download invoices).
- **No Stripe Connect.** The Studio is merchant-of-record for every product.

Rationale recorded in Alternatives Considered. The short version: Stripe is the lowest-friction option that covers both shapes, has the best developer surface for usage-metered billing, includes tax-of-record handling, and has the broadest integration footprint for the consumer apps' future stores (Apple/Google IAP integrations notwithstanding — see D8).

### D2 — Billing-events flow: emitter → buffer → Stripe Meters

`IBillingEventEmitter` (Kernel.Abstractions, ADR-0026) is the source of all metered consumption events. The default implementation writes to an **append-only buffer Node** (a `HoneyDrunk.Billing` Node, scoped as a follow-up standup ADR). The buffer drains to **Stripe Meter Events** on a near-real-time cadence (≤60 seconds) via the Stripe `/v1/billing/meter_events` API.

Properties of the pipe:

- **Idempotent end-to-end.** Per ADR-0042 (Idempotency Contract), each `BillingEvent` carries an `IdempotencyKey`; the buffer dedupes on it; the Stripe push uses the same key as Stripe's `Idempotency-Key` header.
- **At-least-once into Stripe, exactly-once into the invoice.** Stripe Meters deduplicates by event ID; double-pushes are safe.
- **Buffered.** Stripe's API and the meter-events ingestion endpoint can be unavailable; the buffer absorbs outages without dropping events. Buffer durability tier is Tier 0 per ADR-0036.
- **Audit-emitting.** Every meter-event push is also an Audit emit per ADR-0030 (Auth was named the first emitter; Billing is the second).

`HoneyDrunk.Billing` is the new Node that owns this pipe. Its standup follows the AI-sector standup pattern (Abstractions-first, contract-shape canary, frozen interfaces). Standup ADR is a follow-up.

### D3 — Subscription model

- **Notify Cloud (B2B)** — Three tiers (Free/Pro/Scale) with monthly base fees and per-meter overage. Tier and overage prices are configured in Stripe, not in the Grid. The Grid stores only the Stripe `subscription_id` and `customer_id` per tenant.
- **Consumer apps (B2C)** — Single monthly and single annual price per product. Lifetime/one-time-purchase variants reserved for future PDR amendments, not at GA.
- **No free trials at v1** — A free tier with rate limits is offered for Notify Cloud (no card required); trials of paid tiers are deferred. Reduces fraud surface and simplifies the metering boundary.

### D4 — Webhooks: single handler per environment

A single **Stripe webhook endpoint per environment** (dev/staging/prod) lives in `HoneyDrunk.Billing.Webhooks` (a Function App in the Notify shape per ADR-0015). The handler validates the Stripe signature, persists the raw event in the buffer (D2), and emits a domain event (`SubscriptionStarted`, `InvoicePaymentFailed`, `CustomerCardExpiring`, etc.) onto the Service Bus default topic per ADR-0028.

Domain consumers (Notify Cloud's tenant gateway, the relevant consumer app's account service) subscribe to the topic. **No Node subscribes to Stripe directly.** This preserves the ADR-0028 broker-default rule and keeps Stripe out of every consumer's dependency surface.

### D5 — Identity binding: Stripe customer ↔ Grid tenant/principal

- For **B2B**, the canonical Notify Cloud tenant record holds `stripe_customer_id` and `stripe_subscription_id`. TenantId is generated in the Grid; the Stripe customer is created on first checkout. `TenantId` and Stripe customer are 1:1.
- For **B2C**, the consumer app's user record (homed in whichever consumer Node owns identity) holds `stripe_customer_id`. The user is the principal; there is no tenant.
- **Auth (ADR-0030 emitter)** does not hold Stripe identifiers. The boundary is: Auth owns principal identity, Billing owns the Stripe mapping, and the binding is via `PrincipalId` keys.

### D6 — Tax: Stripe Tax with nexus tracking; no manual rates

Stripe Tax is **on** from day one for every product. The Studio is registered for sales tax in Florida (entity state per BDR-0001); other US states and international jurisdictions are tracked via Stripe Tax's nexus-monitoring surface and registered when thresholds cross. No tax rates are hardcoded; no per-tier tax overrides. Tax is part of the price the customer pays at checkout, and tax-remittance reporting flows from Stripe Tax's reporting surface to the Studio's accounting system (current state: spreadsheet; future state: a BDR for accounting software).

### D7 — PCI scope: minimize via Stripe-hosted surfaces

The Grid never sees a card number. Card capture is **always** through Stripe Checkout or Stripe Elements (hosted iframes); the resulting `payment_method_id` is what the Grid persists. This puts the Studio at PCI-DSS SAQ A scope (the lowest), which is the only defensible scope at solo-developer headcount.

This rules out custom checkout forms that handle card data, custom in-app payment UI that touches PANs, and any "save card for later" flow that doesn't go through Stripe's APIs.

### D8 — Mobile in-app purchase carve-out

Apple App Store and Google Play Store mandate IAP for digital subscriptions sold inside mobile apps under most circumstances. The consumer-app PDRs (PDR-0003, PDR-0005, PDR-0006, PDR-0007, PDR-0008) all imply mobile distribution. The decision:

- **Mobile-purchased subscriptions use platform IAP** (Apple/Google). The store is the merchant; the Grid receives a server-to-server notification and grants entitlement.
- **Web-purchased subscriptions use Stripe.** Cross-platform entitlement is keyed off the Grid `PrincipalId`, not the purchase channel.
- **Notify Cloud is Stripe-only** (B2B, no app-store path).
- **Cross-grant** is one-way: a customer who bought on Stripe gets the entitlement on mobile; a customer who bought on IAP does **not** automatically appear in Stripe. (This is the standard pattern; some users will have two purchase records.)

The IAP integration is a follow-up ADR tied to the mobile-platform ADR (currently in backlog). This ADR commits the principle; the mechanism is downstream.

### D9 — `HoneyDrunk.Billing` Node placement

Sector: **Ops**, adjacent to Notify/Communications/Pulse. The Node holds:

- `HoneyDrunk.Billing.Abstractions` — `IBillingMeterPipe`, `IBillingCustomerStore`, `IStripeEventHandler`, `BillingMeterEvent`, `BillingCustomerBinding`. The Kernel-level `IBillingEventEmitter` is the **upstream** interface; this Node's interfaces are the **downstream** (Stripe-facing) surface.
- `HoneyDrunk.Billing.Stripe` — Stripe-specific implementation.
- `HoneyDrunk.Billing.Webhooks` — Function App per ADR-0015.

`HoneyDrunk.Billing.Cloud` (private per ADR-0027 D2) carries the multi-tenant gateway concerns specific to Notify Cloud's billing surfaces. Optional; may be folded into Notify.Cloud if the boundary doesn't justify a separate Node.

### D10 — Test mode and synthetic tenants

Stripe test mode is wired through `dev` and `staging` per environment-scoped Stripe API keys (managed in Vault per ADR-0005). The "synthetic tenant" pattern (TenantId.Internal, ADR-0026) is the test surface; canaries against the billing pipe use it. **Production never sees test-mode keys**; this is a hard CI gate.

## Consequences

### Affected Nodes

- **HoneyDrunk.Billing** (new) — full standup, Abstractions-first, parallel to AI-sector standup pattern.
- **HoneyDrunk.Kernel.Abstractions** — no change; `IBillingEventEmitter` shape is intact.
- **HoneyDrunk.Auth** — no Stripe coupling; the principal/customer mapping lives in Billing.
- **HoneyDrunk.Notify.Cloud** — depends on Billing for subscription state, meter ingestion, and webhook-driven tier changes.
- **HoneyDrunk.Vault** — holds Stripe API keys (per environment) and webhook signing secrets.
- **HoneyDrunk.Audit** — Billing becomes its second emitter (after Auth, ADR-0031).
- **Consumer-app Nodes** (designed, not yet scaffolded — PDR-0003, etc.) — depend on Billing for web subscriptions; depend on the future mobile-IAP ADR for in-app subscriptions.
- **catalogs/relationships.json** — gains edges: Billing→Vault, Billing→Audit, NotifyCloud→Billing, future consumer apps→Billing.

### Invariants

Adds three:

- **Invariant: card data never enters the Grid.** All card capture is Stripe-hosted; the Grid stores only Stripe identifiers and payment-method IDs. Maintains PCI SAQ A scope.
- **Invariant: no Node subscribes to Stripe webhooks directly.** Webhooks land in Billing.Webhooks; domain events flow on the Service Bus default topic per ADR-0028.
- **Invariant: Stripe test-mode keys never reach production.** CI gate on Vault key-environment binding.

### Operational Consequences

- Stripe fees (~2.9% + $0.30 per US card transaction at standard pricing, Stripe Tax 0.5% additive) are a permanent gross-margin reduction. Acceptable cost of doing business; not relitigated.
- Stripe Tax registration in additional states triggers as nexus thresholds cross. The Studio operator is responsible for completing the registration; Stripe Tax flags it but doesn't file it.
- Annual Stripe API version pinning: the Billing Node pins a Stripe API version explicitly (not "latest"); upgrades are a small, deliberate ADR amendment.
- Subscription lifecycle events (`canceled`, `paused`, `unpaid`) gate Notify Cloud tenant access. The webhook handler and the Notify Cloud gateway must agree on the entitlement view; eventual consistency on the order of seconds is acceptable, but the Audit log captures both sides.
- The buffer in D2 introduces a billing-relevant durable store; it lives in Tier 0 per ADR-0036.

### Follow-up Work

- Author the `HoneyDrunk.Billing` standup ADR (Abstractions-first, frozen contracts).
- Author the mobile-IAP ADR (D8); blocked on the mobile-platform ADR.
- Author the accounting-software BDR (D6, downstream of tax remittance reporting).
- Provision Stripe accounts (live + test) under the Studio entity; bind to Studio bank account per BDR-0001.
- Configure Stripe Tax for Florida and enable nexus monitoring.
- Define the three Notify Cloud tier products in Stripe (prices, meters) before GA.

## Alternatives Considered

### Paddle

Considered. Paddle is "merchant of record" for international tax/VAT, which is attractive at small scale (no nexus tracking on the Studio's side). Rejected for two reasons: (1) Paddle's usage-metering surface is weaker than Stripe Billing's; (2) Paddle takes a higher cut (~5%+) and the spread vs. Stripe + Stripe Tax becomes unfavorable as volume scales. Reconsidered if international becomes a substantial fraction of revenue before US thresholds are crossed.

### Lemon Squeezy

Considered. Similar profile to Paddle (MoR), slightly better developer experience, weaker B2B usage-metered story. Rejected on the same usage-metering grounds and on a smaller ecosystem of integration tooling.

### Stripe Connect / platform model

Rejected for current shape. Connect is for marketplaces; the Grid is not a marketplace at PDR-0002 scope. None of the consumer-app PDRs imply third-party seller flows. Reconsidered if a future PDR requires it.

### Build a billing system in-house

Rejected at this scale. Card-data PCI scope alone makes this a multi-quarter project at solo-developer headcount. Stripe-or-equivalent is a non-negotiable.

### Multiple processors (Stripe + Apple/Google IAP) from day one

Adopted in D8 but with explicit scope discipline: web is Stripe-only; mobile IAP is per-app-store; cross-grant is one-way (Stripe → mobile). The full IAP ADR is a follow-up; this ADR records the principle.

### Defer the entire decision until first commercial product is closer

Rejected. PDR-0002 / ADR-0027 is the first commercial product; its standup is in flight. The buffer/webhook plumbing is on the critical path for Notify Cloud GA, not parallelizable with it.
