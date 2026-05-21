# HoneyDrunk.Observe — Integration Points

## Consumes

### HoneyDrunk.Kernel

Observe uses Kernel for Grid context, operation context, lifecycle hooks, and consistent Node identity.

### HoneyDrunk.Vault

Observe uses `ISecretStore` for connector credential resolution. Connectors receive handles or names; Vault owns secret retrieval and provider-specific storage.

## Consumed By

### HoneyHub — future

When the planning surface is live, normalized observation events can become inputs to the knowledge graph and planning loop. That integration is future work, not a current runtime edge.

## Does Not Integrate Directly With

### Pulse

Observe and Pulse are sibling Ops pipelines. Pulse owns outbound telemetry; Observe owns inbound external observation. Neither is a subordinate of the other.
