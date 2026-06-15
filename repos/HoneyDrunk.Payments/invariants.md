# HoneyDrunk.Payments Invariants

- Product nodes depend on `HoneyDrunk.Payments.Abstractions` for payment workflows.
- Provider SDKs stay inside provider packages such as `HoneyDrunk.Payments.Stripe`.
- Product nodes own product pricing, tenant/project binding, and subscription persistence.
- Payments owns provider transport, signature validation, normalized provider snapshots, and provider metadata mapping.
- Provider-neutral snapshots must include a provider name and provider object identifiers when a product may need to persist links.
- Raw webhook payloads must be validated before parsing or mutation.
- Payment-provider secrets must not be logged or stored in Payments package state.
