# HoneyDrunk.Pulse — Invariants

1. **Per-sink failure isolation.** One sink failing does not block other sinks.
2. **Grid context enrichment is automatic.** All traces/logs include NodeId, StudioId, CorrelationId when available.
3. **Self-telemetry via dedicated ActivitySource.** Pulse.Collector traces its own operations.
