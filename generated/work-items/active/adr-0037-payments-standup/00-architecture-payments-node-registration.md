---
name: Architecture Decision
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "ops", "docs", "adr-0037", "payments", "wave-1"]
dependencies: []
adrs: ["ADR-0037", "ADR-0082", "ADR-0012"]
accepts: ["ADR-0037"]
wave: 1
initiative: adr-0037-payments-standup
node: honeydrunk-architecture
supersedes:
  - generated/work-items/active/adr-0037-payment-billing/00-architecture-adr-0037-acceptance.md
  - generated/work-items/active/adr-0037-payment-billing/01-architecture-billing-node-catalog-and-context.md
  - generated/work-items/active/adr-0037-payment-billing/04-architecture-billing-node-standup-adr.md
---

# Register the HoneyDrunk.Payments Node

## Summary

Register `HoneyDrunk.Payments` as the ADR-0037 payment-provider boundary. This replaces the earlier `HoneyDrunk.Billing` working-name packets without mutating those filed packet files.

## Context

ADR-0037 originally named a future Billing Node. PR #632 pivots that boundary to `HoneyDrunk.Payments` so product Nodes consume provider-neutral payment contracts while provider packages, starting with Stripe, keep provider SDK semantics out of product repos.

This work item is the canonical Architecture replacement for the filed Billing-scoped issues #222, #223, and #226.

## Scope

- Register `HoneyDrunk.Payments` in Node, module, relationship, health, compatibility, and contract catalogs.
- Add the standard `repos/HoneyDrunk.Payments/` context folder.
- Update ADR-0037 / dependent ADR wording so Payments is the canonical provider boundary and NovOutbox is a consumer.
- Preserve Vault-only secret-source wording for provider API keys and webhook signing secrets.
- Keep filed Billing packet files immutable; supersession lives in this replacement work item and linked GitHub issues.

## Acceptance Criteria

- [ ] `catalogs/nodes.json` contains `honeydrunk-payments`.
- [ ] `catalogs/relationships.json` models Payments consuming Kernel and Vault, and NovOutbox consuming Payments.
- [ ] `repos/HoneyDrunk.Payments/` exists with standard context files.
- [ ] ADR-0037 / dependent ADR references no longer direct new work to `HoneyDrunk.Billing` as the canonical boundary.
- [ ] The superseded Billing issues link to this replacement work item.

## Constraints

- Do not edit the filed packet files under `generated/work-items/active/adr-0037-payment-billing/`.
- Product Nodes must not depend directly on Stripe.NET.
- Provider secrets must resolve only through HoneyDrunk.Vault / `ISecretStore`; deploy-time configuration may carry only secret references or non-secret provider identifiers.
