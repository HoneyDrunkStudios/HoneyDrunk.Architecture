# HoneyDrunk.Communications - Integration Points

How Communications connects to the rest of the Grid. Every cross-Node boundary needs canary coverage when the implementation changes shape.

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `TenantId` | Tenant-scoped preference and cadence decisions; internal tenant bypass semantics. |
| **Kernel** | Grid context / correlation primitives | Correlates the business event, Communications decision, and Notify delivery attempt. |
| **Kernel** | lifecycle/health abstractions | Runtime startup hook and health contributor registration. |
| **Notify** | `INotificationSender` | Approved communication decisions delegate delivery to Notify. |

## Exposes

| Contract | Consumer | Notes |
|----------|----------|-------|
| `ICommunicationOrchestrator` | Product Nodes, Operator event handlers, future lifecycle workflows | Main send/evaluate entry point. |
| `IMessageIntent` / `MessageIntent` | Product Nodes | Intent boundary for business-event-driven communications. |
| `IRecipientResolver` | Runtime composition and custom host integrations | Recipient resolution slot. |
| `IPreferenceStore` | Runtime composition and future durable implementations | Tenant-scoped preference slot. |
| `ICadencePolicy` | Runtime composition and future durable implementations | Tenant-scoped cadence/suppression slot. |
| `ICommunicationDecisionLog` | Runtime composition and audit/observability integrations | Append-only decision log slot. |

## Observed By

| Node | Signal | Notes |
|------|--------|-------|
| **Pulse** | traces/logs/metrics | Communications emits decision telemetry; Pulse observes it. Communications has no runtime dependency on Pulse. |

## Deferred / Planned Edges

- **Data** - likely future durable backend for preferences, cadence, follow-up state, and decision logs.
- **Flow** - likely future durable engine for complex campaigns and long-running sequences.
- **Transport** - possible future ingress/event-out mechanism for business events and approval notifications.

## Canary Coverage Required

- Contract-shape canary for `ICommunicationOrchestrator`, `IMessageIntent`/`MessageIntent`, `IPreferenceStore`, `ICadencePolicy`, `IRecipientResolver`, and `ICommunicationDecisionLog` value surfaces.
- Boundary canary proving the welcome-email path delegates through Notify's `INotificationSender` without taking provider dependencies.
- Correlation canary proving the decision log and Notify envelope carry the same operation correlation.
