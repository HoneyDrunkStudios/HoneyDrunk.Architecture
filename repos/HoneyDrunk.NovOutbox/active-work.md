# HoneyDrunk.NovOutbox Active Work

## Current slice

Bootstrap the private product repo without a `src/` folder, register the node across Architecture catalogs, and prove the private-repo automation path before adding real customer workflows.

## First implementation slice

- Create the root-level solution and projects:
  - `HoneyDrunk.NovOutbox.Abstractions`
  - `HoneyDrunk.NovOutbox`
  - `HoneyDrunk.NovOutbox.Web`
  - `HoneyDrunk.NovOutbox.AppHost`
  - focused test projects beside the product projects
- Add minimal product contracts for notification submission, API-key issuance, tenant tier, and submit results.
- Add a runtime seam that resolves API-key/project context, applies a tenant limit decision, emits a billing event, and delegates to Communications behind interfaces or stubs.
- Add a skeletal customer console route that proves the private product repo contains the customer-facing app, not the public marketing site.
- Add CI/review workflow wiring using `HoneyDrunk.Actions`.
- Compose `HoneyDrunk.Payments.Abstractions` and `HoneyDrunk.Payments.Stripe` for payment-provider workflows instead of owning a NovOutbox-specific Stripe package.
- Run a private-repo smoke PR that verifies reusable workflow access, secrets, token permissions, review automation diff access, and package visibility assumptions.

## Deferred

- Public marketing/docs website.
- Product-specific Stripe subscription lifecycle composition beyond the shared Payments provider package.
- Production Azure Container Apps deployment.
- Customer onboarding polish beyond the first private repo smoke path.
