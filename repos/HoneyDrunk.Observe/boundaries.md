# HoneyDrunk.Observe — Boundaries

## What Observe Owns

- Observation contracts and the observation-state model
- Connector provider slots under `HoneyDrunk.Observe.Connectors.*`
- External event intake from supported systems such as GitHub, Azure, and HTTP health checks
- Normalization from source-specific payloads into canonical observation events
- Connector credential resolution through Vault-backed secret handles

## What Observe Does NOT Own

- Outbound telemetry routing to external sinks — that belongs to Pulse
- Internal Grid telemetry emitted by Nodes — that stays in Pulse
- Plan adjustment, prioritization, or task assignment — that belongs to HoneyHub when live
- Provider credentials themselves — those belong behind Vault contracts
- Arbitrary connector sprawl beyond the first-wave provider slots

## Boundary Decision Tests

- Is this inbound event intake from an external system? → Observe.
- Is this outbound telemetry from the Grid to a sink? → Pulse.
- Is this internal Node telemetry? → Pulse.
- Is this a plan adjustment or work-routing decision? → HoneyHub.
- Does this need a credential? → Observe asks Vault; it does not store the secret.
