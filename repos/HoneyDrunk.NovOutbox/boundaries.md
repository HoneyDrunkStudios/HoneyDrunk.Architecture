# HoneyDrunk.NovOutbox Boundaries

## Owns

- Hosted customer API for notification submission and product management.
- Customer console for projects, API keys, usage, logs, and billing state.
- Tenant/project model specific to the commercial product.
- API-key issuance, rotation, revocation, and tenant resolution.
- Tenant tier enforcement, quotas, and product rate limits.
- Billing event emission and product payment-provider integration.
- Product-level audit/log views surfaced to customers.
- Private repo automation smoke tests, branch protection, and package visibility validation.

## Does not own

- Public marketing website or public docs site.
- Low-level email/SMS provider dispatch mechanics; those belong to Notify.
- Recipient preference, cadence, suppression, and message decision policy; those belong to Communications.
- General HoneyDrunk auth primitives; those belong to Auth.
- General secret-store primitives; those belong to Vault.
- General response-envelope and exception conventions; those belong to Web.Rest.
- General telemetry substrate; that belongs to Pulse and Kernel telemetry primitives.
- Payment-provider SDKs and provider-neutral payment contracts; those belong to Payments.

## Naming

Use `NovOutbox` for customer-facing product language.

Use `HoneyDrunk.NovOutbox` for the private repo, solution, package family, namespaces, and internal technical identity.

Treat `HoneyDrunk.Notify.Cloud` as historical planning language only.
