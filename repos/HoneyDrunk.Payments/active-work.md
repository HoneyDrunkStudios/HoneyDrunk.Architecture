# HoneyDrunk.Payments Active Work

## Current slice

Stand up the new Payments repository, move reusable Stripe integration out of NovOutbox, and register the node across Architecture catalogs and Grid Review admission.

## First implementation slice

- Create root-level solution and projects:
  - `HoneyDrunk.Payments.Abstractions`
  - `HoneyDrunk.Payments.Stripe`
  - focused Stripe tests
- Define provider-neutral checkout, subscription lifecycle, webhook, and invoice reconciliation contracts.
- Make the Stripe implementation implement the provider-neutral contracts while retaining Stripe-specific interfaces for intentional provider-level use.
- Configure standard Actions workflows, PR review wiring, labels, and Grid Review allowlist admission.
- Update NovOutbox to stop owning a product-specific Stripe package.

## Deferred

- Package publishing.
- Production provider secret onboarding and sensitive-inventory rows.
- Customer portal flows.
- Additional payment providers.
- Full money/currency representation beyond provider snapshots.
