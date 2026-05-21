# HoneyDrunk.Observe — Invariants

## Connector credentials resolve through Vault

Observation connectors never store credentials directly. Webhook secrets, API tokens, and per-target connection secrets are resolved via `ISecretStore` when a connector establishes or refreshes a connection.

**Rationale:** Observe talks to systems outside the Grid. Keeping all credentials behind Vault preserves the same secret boundary used by the rest of the platform.

## Raw external payloads do not cross the boundary

Source-specific payloads such as GitHub webhook JSON, Azure alert schemas, or HTTP probe details are normalized into `IObservationEvent` before routing out of Observe.

**Rationale:** Downstream consumers should depend on a stable observation contract, not every external provider's wire format.
