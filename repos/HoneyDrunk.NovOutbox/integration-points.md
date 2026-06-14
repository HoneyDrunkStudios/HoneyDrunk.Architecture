# HoneyDrunk.NovOutbox Integration Points

## Consumes

- `HoneyDrunk.Kernel.Abstractions`: tenant identity, context accessors, telemetry factory, rate-limit and billing primitives.
- `HoneyDrunk.Auth`: API-key authentication and authorization boundary.
- `HoneyDrunk.Vault`: tenant/project secret resolution and payment-provider secret handles.
- `HoneyDrunk.Web.Rest`: response envelopes, correlation IDs, and exception mapping.
- `HoneyDrunk.Communications.Abstractions`: message intent orchestration and send/suppress/schedule decisions.
- `HoneyDrunk.Notify.Abstractions`: delivery smoke tests and diagnostics where direct delivery validation is necessary.
- `HoneyDrunk.Data.EntityFramework`, `HoneyDrunk.Data.Outbox`, and `HoneyDrunk.Data.Outbox.Dispatcher`: durable NovOutbox persistence, outbox writes, and committed-row dispatch.
- `HoneyDrunk.Transport`, `HoneyDrunk.Transport.AzureServiceBus`, and `HoneyDrunk.Transport.InMemory`: production Azure Service Bus dispatch and development/test in-memory dispatch for committed outbox work.
- `HoneyDrunk.Actions`: reusable CI, security, package, review, and deployment workflows.
- `HoneyDrunk.Infrastructure`: Azure Container Apps deployment templates once the product has a deployable shape.

## Exposes

- `HoneyDrunk.NovOutbox.Abstractions`: product contracts such as `INovOutboxGateway`, `INovOutboxApiKeyStore`, `NovOutboxTenantTier`, and API-key issuance/result types.
- `HoneyDrunk.NovOutbox`: runtime composition for tenant resolution, limits, billing events, and Communications delegation.
- `HoneyDrunk.NovOutbox.Web`: customer API and Blazor customer console.
- `HoneyDrunk.NovOutbox.Billing.Stripe`: Stripe billing adapter.
- `HoneyDrunk.NovOutbox.AppHost`: Aspire local-development host only.

## Private-repo checks

- Reusable workflows in `HoneyDrunk.Actions` must be callable from a private repository.
- Organization secrets must be available to private repositories, or repo-level fallbacks must be defined.
- Workflow `permissions:` must be explicit, especially for contents, packages, pull requests, security events, id tokens, and checks.
- Package publishing must confirm whether private/internal packages target NuGet, GitHub Packages, or both.
- Grid review, Codex, Claude, and any PR review automation must prove they can read private repo diffs before their output counts as a real review.
- Catalog and repo-to-node mapping must support `honeydrunk-novoutbox` without assuming public repository discovery.
