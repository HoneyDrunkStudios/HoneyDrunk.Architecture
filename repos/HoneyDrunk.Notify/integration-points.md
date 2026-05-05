# HoneyDrunk.Notify — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **Kernel** | `HoneyDrunk.Kernel.Abstractions` | Context propagation, lifecycle, health, telemetry. |

## Consumed By

| Node | Contract | Usage |
|------|----------|-------|
| **Communications** | `INotificationSender` | Communications delegates approved outbound messages to Notify for delivery. |

## Boundary Note

Notify exposes delivery contracts only. Preference, cadence, suppression, and lifecycle workflow decisions should cross through `HoneyDrunk.Communications` before Notify is called unless the caller is intentionally sending a one-shot transactional notification with no orchestration semantics.
