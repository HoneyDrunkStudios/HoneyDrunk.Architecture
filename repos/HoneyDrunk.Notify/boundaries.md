# HoneyDrunk.Notify - Boundaries

## What Notify Owns
- Channel-agnostic notification intake and delivery contracts
- Structural validation of notification requests/envelopes
- Queue-backed async dispatch and delivery workers/functions
- Provider dispatch mechanics for email/SMS and future channels
- Template/rendering mechanics and provider payload mapping
- Retry classification, delivery result handling, and delivery observability

## What Notify Does NOT Own
- **Recipient preferences** - Communications owns opt-outs, suppressed intent kinds, quiet hours, and preferred-channel decisions.
- **Cadence/suppression policy** - Communications decides whether a recipient should receive a message now, later, or never.
- **Lifecycle communication workflows** - Communications owns welcome sequences, re-engagement, escalation chains, and business-event-to-message-intent mapping.
- **Transport messaging** - Notify uses its own intake/delivery queue shape unless a future Architecture decision routes it through Transport.
- **Push notifications** - Not yet supported (future provider slot).

## Boundary Decision Test

If the concern is **how to deliver a structurally valid notification**, it belongs in Notify. If the concern is **whether a recipient should receive a message, when, or as part of what workflow**, it belongs in Communications.
