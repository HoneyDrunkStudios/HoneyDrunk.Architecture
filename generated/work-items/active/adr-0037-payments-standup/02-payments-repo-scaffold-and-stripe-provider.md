---
name: Node Scaffold
type: implementation
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Payments
labels: ["scaffold", "tier-2", "ops", "payments", "adr-0037", "wave-1"]
dependencies: ["work-item:00", "work-item:01"]
adrs: ["ADR-0037", "ADR-0034", "ADR-0035", "ADR-0082"]
wave: 1
initiative: adr-0037-payments-standup
node: honeydrunk-payments
supersedes:
  - generated/work-items/active/adr-0037-payment-billing/02-architecture-provision-stripe-accounts.md
  - generated/work-items/active/adr-0037-payment-billing/03-architecture-configure-stripe-tax-and-tier-products.md
---

# Scaffold HoneyDrunk.Payments Abstractions and Stripe Provider

## Summary

Stand up the `HoneyDrunk.Payments` repo with provider-neutral abstractions and a Stripe provider package. This replaces the earlier Billing-scoped Stripe account/product packets with a Payments-owned provider boundary.

## Context

Products should depend on `HoneyDrunk.Payments.Abstractions`. Provider SDKs and provider-specific object shapes stay inside provider packages such as `HoneyDrunk.Payments.Stripe`.

## Scope

- Add `HoneyDrunk.Payments.Abstractions` with provider-neutral checkout, subscription lifecycle, webhook normalization, and invoice reconciliation contracts.
- Add `HoneyDrunk.Payments.Stripe` as the first provider implementation.
- Add unit tests and a contract-shape canary for the abstractions package.
- Add package README and CHANGELOG files.
- Add PR, publish, nightly security, and dependency workflows following the HoneyDrunk.Actions reusable workflow pattern.

## Acceptance Criteria

- [ ] Product-facing contracts do not expose Stripe SDK types.
- [ ] Stripe.NET appears only in the Stripe provider package.
- [ ] Abstractions contract-shape canary passes.
- [ ] `dotnet test` passes for the solution.
- [ ] The repo has seeded review labels and is admitted by the local Grid Review runner.

## Constraints

- Do not recreate `HoneyDrunk.NovOutbox.Billing.Stripe`.
- Preserve idempotency for checkout/session creation and meter-event emission.
- Preserve original `BillingEvent.OccurredAtUtc` when emitting provider meter events.
