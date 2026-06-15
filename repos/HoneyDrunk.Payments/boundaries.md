# HoneyDrunk.Payments Boundaries

## Owns

- Provider-neutral payment contracts for checkout, subscription lifecycle, signed webhook normalization, and invoice reconciliation.
- Provider packages such as `HoneyDrunk.Payments.Stripe`.
- Stripe.NET integration for meter events, Checkout subscriptions, webhook validation, subscription lifecycle, and invoice reconciliation.
- Provider identifier normalization and provider-specific metadata mapping into product-safe snapshots.
- Payment-provider package tests and repo automation.

## Does not own

- Product pricing strategy, commercial tier definitions, or plan names.
- Product tenant/project binding policy.
- Product-specific subscription persistence tables.
- Customer-console UX.
- General money representation; that remains governed by Kernel/Architecture money decisions.
- Provider secrets storage; provider secrets must be resolved only through HoneyDrunk.Vault / `ISecretStore`. Deploy-time configuration may carry Vault secret names, secret references, environment names, or non-secret provider identifiers, but not provider secret values.

## Naming

Use `HoneyDrunk.Payments.Abstractions` for product-facing dependencies.

Use `HoneyDrunk.Payments.Stripe` only where Stripe is intentionally selected as the provider implementation.

Do not create product-owned provider packages such as `HoneyDrunk.NovOutbox.Billing.Stripe`.
