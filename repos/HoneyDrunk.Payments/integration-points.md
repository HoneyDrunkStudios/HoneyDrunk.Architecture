# HoneyDrunk.Payments Integration Points

## Consumes

- `HoneyDrunk.Kernel.Abstractions`: `BillingEvent`, `IBillingEventEmitter`, and tenant identifiers for metered usage emission.
- `HoneyDrunk.Vault`: `ISecretStore` / Vault-backed secret resolution for provider API keys and webhook signing secrets.
- Stripe.NET: provider SDK used only inside `HoneyDrunk.Payments.Stripe`.
- `HoneyDrunk.Actions`: reusable CI, security, package, review, and deployment workflows.

## Exposes

- `HoneyDrunk.Payments.Abstractions`: provider-neutral contracts for checkout sessions, subscription lifecycle, webhook event normalization, and invoice reconciliation.
- `HoneyDrunk.Payments.Stripe`: Stripe.NET provider implementation plus Stripe-specific contracts for callers that need explicit Stripe identifiers or raw Stripe lifecycle operations.

## Consumers

- `HoneyDrunk.NovOutbox`: consumes Payments abstractions for hosted-product billing workflows and may compose the Stripe provider package for the first commercial slice.
- Future hosted product nodes: consume the same abstractions and select providers in composition.

## Provider posture

- Product nodes should not depend directly on Stripe.NET.
- Provider-specific webhook signature semantics stay in the provider package.
- Provider-neutral snapshots carry `Provider` plus provider object identifiers so products can persist links without knowing SDK object shapes.
