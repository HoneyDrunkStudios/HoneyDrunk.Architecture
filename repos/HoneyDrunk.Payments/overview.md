# HoneyDrunk.Payments Overview

`HoneyDrunk.Payments` owns the shared payment-provider boundary for HoneyDrunk hosted products.

Product nodes such as NovOutbox keep product-specific pricing, tenant binding, usage policy, and subscription-state persistence. Payments owns provider-neutral contracts plus provider packages so product repositories do not embed Stripe SDK code or fork billing transport logic.

## Core shape

- Repo/package family: `HoneyDrunk.Payments`.
- Product-facing contracts: `HoneyDrunk.Payments.Abstractions`.
- First provider package: `HoneyDrunk.Payments.Stripe`.
- Runtime path: product code depends on provider-neutral contracts -> composition selects a provider package -> provider implementation returns provider-neutral snapshots while retaining provider-specific details where needed.
- Initial provider: Stripe.NET for metered usage, Checkout subscriptions, signed webhook validation, subscription read/cancel, and invoice reconciliation.
- Provider secrets are resolved by provider composition interfaces (`IStripeApiKeyProvider`, `IStripeWebhookSecretProvider`) backed by Vault / `ISecretStore`; product contracts do not carry raw provider secret values.
