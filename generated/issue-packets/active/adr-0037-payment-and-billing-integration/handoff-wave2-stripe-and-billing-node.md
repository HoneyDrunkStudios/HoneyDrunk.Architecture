# Handoff — ADR-0037 Wave 2: Planned-Node Registration + Stripe Account

**Read this once at the Wave 1 → Wave 2 transition.** Ephemeral baton pass — not a live tracker. Immutable per invariant 24.

## What landed in Wave 1

Packet 00 merged. As a result:

- **ADR-0037 is Accepted.** `adrs/ADR-0037-payment-and-billing-integration.md` reads `**Status:** Accepted`; the `adrs/README.md` row reflects it. ADR-0037's D-decisions are now live Grid rules.
- **Three new billing invariants** are in `constitution/invariants.md` as numbers **62, 63, 64** (pre-reserved as ADR-0037's block within a 12-ADR batch; if anything above 51 landed from outside the batch first, the block was shifted upward — read the file for the actual numbers):
  1. **Card data never enters the Grid.** All card capture is Stripe-hosted (Checkout / Elements); the Grid stores only Stripe identifiers and `payment_method_id`. PCI SAQ A scope. Custom card-handling UI is forbidden.
  2. **No Node subscribes to Stripe webhooks directly.** Webhooks land in a single `HoneyDrunk.Billing.Webhooks` endpoint per environment; domain events flow on the Service Bus default topic per ADR-0028.
  3. **Stripe test-mode keys never reach production.** Test-mode keys bind to `dev`/`staging` only; a hard CI gate on the Vault key-environment binding.
- The `adr-0037-payment-and-billing-integration` initiative is registered in `initiatives/active-initiatives.md`.

## Wave 2 — two packets, parallel, independent

### Packet 01 — Register the `HoneyDrunk.Billing` planned Node (`Actor=Agent`)

Create the `repos/HoneyDrunk.Billing/` context folder (five files), add the Ops-sector row in `constitution/sectors.md`, add the `honeydrunk-billing` *descriptor* entry to `catalogs/nodes.json`, and add the `honeydrunk-billing` dependency entry to `catalogs/relationships.json` with edges to Vault and Audit.

Key facts the executing agent needs:
- This is **planned-Node registration only** — no GitHub repo, no solution scaffold. The actual Billing Node standup is governed by the separate standup ADR that packet 04 authors.
- The Billing Node will own three package families per ADR-0037 D9: `HoneyDrunk.Billing.Abstractions` (downstream Stripe-facing contracts), `HoneyDrunk.Billing.Stripe`, `HoneyDrunk.Billing.Webhooks` (a Function App per ADR-0015).
- `IBillingEventEmitter` / `BillingEvent` are **Kernel-owned** (`HoneyDrunk.Kernel.Abstractions.Tenancy`, per ADR-0026) — the context folder records them as *consumed*, not redefined.
- **Two distinct catalog files.** `catalogs/nodes.json` is the descriptor catalog — identity/presentation fields only (`id`, `type`, `name`, `sector`, `signal`, etc.); it has **no** `consumes`/`consumed_by`/`consumed_by_planned`/`exposes`/`blocked_by` fields. `catalogs/relationships.json` is the dependency graph (top-level key `nodes`) — its entries carry `consumes`, `consumed_by`, `consumed_by_planned`, `blocked_by`, `exposes`, `consumes_detail`. The Billing dependency edges go in `relationships.json` only. Add `honeydrunk-billing` to `relationships.json` with `consumes: ["honeydrunk-vault", "honeydrunk-audit"]`, and add `"honeydrunk-billing"` to the `consumed_by_planned` arrays of the `honeydrunk-vault` and `honeydrunk-audit` entries. Match the JSON shape of `honeydrunk-observe` (nodes.json) and an existing `relationships.json` entry.
- `grid-health.json` / `contracts.json` / `modules.json` reconcile via `hive-sync` at standup.
- The `NotifyCloud→Billing` edge is omitted — `honeydrunk-notify-cloud` is not yet a `relationships.json` node; leave a one-line PR note; `hive-sync` wires it when Notify Cloud is registered.

### Packet 02 — Provision the Stripe account (`Actor=Human` — `human-only`)

Create and verify the Studio's Stripe account under HoneyDrunk Studios LLC, bind the Chase payout account, record the account's existence in `business/context/entity.md`.

**The load-bearing fact: packet 02 is HARD-GATED on BDR-0001.**

- A Stripe account is opened against a legal entity with a verified address. BDR-0001 (Accepted) is moving HoneyDrunk Studios LLC's principal office address from iPostal1 to VirtualPostMail (VPM, Tampa), with a Sunbiz Articles-of-Amendment filing targeted before October 2026.
- `business/context/entity.md` currently records the principal office address as "(currently iPostal1 — see BDR-0001, switch in progress)" — i.e. the address is *in flux*.
- **Do not open the live Stripe account against an address that is about to change.** The operator must decide:
  - **Option A (recommended):** wait until the BDR-0001 VPM address is the live principal address (VPM account active, USPS Form 1583 done, Sunbiz amendment filed), then open Stripe against the final address.
  - **Option B:** open Stripe now against the iPostal1 address and update it later — only if a billing milestone genuinely cannot wait. Adds an in-Stripe address update to the BDR-0001 vendor-update action item.
- The billing pipe has **slack**: ADR-0027 D13 ships Notify Cloud's billing adapter as a *stub*, so no GA milestone before October 2026 depends on the Stripe account being live. Option A is the recommended call.
- Packet 02 stops at "the account exists, is verified, can take payouts." No products, no prices, no meters, no webhook endpoints, no API-key extraction — those are Wave 3 (packet 03) and the Billing standup initiative.
- **No secrets in the repo** — invariant 8. `business/context/entity.md` records only that the account exists.

## Wave 2 → Wave 3 gate

Wave 3 starts when:
- Packet 01 has merged (`repos/HoneyDrunk.Billing/` + sector map + `nodes.json` descriptor entry + `relationships.json` dependency entry exist), and
- Packet 02 is complete (a verified Stripe account exists) — Wave 3's packet 03 (Stripe Tax + tier products) hard-depends on packet 02.

Packet 04 (the Billing standup ADR) depends only softly on 00 and 01, so it can begin as soon as packet 01 has merged — it does not wait on the human Stripe work.

## What Wave 2 explicitly does NOT do

- Does not create the `HoneyDrunk.Billing` GitHub repo or scaffold any solution.
- Does not seed Stripe API keys or webhook signing secrets into Vault.
- Does not configure Stripe Tax or create any Stripe products (that is Wave 3, packet 03).
- Does not author the Billing standup ADR (that is Wave 3, packet 04).
