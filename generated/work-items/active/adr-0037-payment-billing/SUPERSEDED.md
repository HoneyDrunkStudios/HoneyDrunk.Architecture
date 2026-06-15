# Superseded Work Items

**Superseded on:** 2026-06-14

This active work-item set used the earlier `HoneyDrunk.Billing` working name. PR #632 registers `HoneyDrunk.Payments` as the shared provider-neutral payment boundary and makes ADR-0037 the standup authority for that node.

Do not execute packets from this folder until they are replaced with Payments-scoped work items. Historical references remain for traceability only.

## Replacement Issue Trail

Replacement work is tracked through GitHub issues so the filed Billing packet files remain immutable and this PR does not promote agent-authored packets directly into `generated/work-items/active/`.

- Architecture node registration: https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/issues/633
- Actions repo-to-node mapping: https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/issues/205
- Payments repo scaffold and Stripe provider: https://github.com/HoneyDrunkStudios/HoneyDrunk.Payments/issues/2
