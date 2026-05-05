# HoneyDrunk.Communications - Invariants

Communications-specific invariants supplement `constitution/invariants.md`.

1. **Communications owns outbound-message decisions, not delivery mechanics.**
   Preference, cadence, suppression, recipient resolution, and workflow decisions live here. Provider dispatch stays in Notify.

2. **Every send-or-suppress path records a decision.**
   `ICommunicationDecisionLog` is the audit boundary for Communications decisions. A caller must be able to explain why a message was sent, suppressed, scheduled, or failed.

3. **Tenant context gates preference and cadence state.**
   `IPreferenceStore` and `ICadencePolicy` are scoped by `TenantId` and recipient. Internal Grid traffic uses the internal tenant bypass explicitly rather than hidden global state.

4. **Delivery delegation goes through Notify abstractions.**
   The runtime delegates approved delivery via `INotificationSender`. Communications never references provider SDKs or Notify provider implementations.

5. **Business events cross the boundary as intents.**
   Downstream Nodes should pass `IMessageIntent`/intent-specific records into Communications, not construct provider envelopes directly when preference/cadence/workflow semantics matter.

6. **Correlation context survives the decision boundary.**
   Decisions and delegated Notify sends preserve correlation keys/ids so Pulse and logs can connect business event, decision, and delivery outcome.

7. **Default stores are safe but non-durable.**
   In-memory preference, cadence, decision-log, and follow-up scheduler implementations are acceptable for bring-up and tests only. Production durability must be explicit.

8. **Communications does not create a reverse dependency from safety-critical Nodes.**
   Operator/Auth-style approval or authorization paths emit events/intents for Communications to handle; they do not depend on Communications at runtime for enforcement.
