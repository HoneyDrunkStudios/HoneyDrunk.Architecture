# HoneyDrunk.Communications - Boundaries

## What Communications Owns

- Business-event-to-message-intent mapping.
- Recipient resolution for communication workflows.
- Tenant-scoped recipient preferences, opt-outs, suppression, and quiet-hours decisions.
- Cadence decisions: send now, suppress, or defer.
- Multi-step communication workflow intent, starting with the welcome-email/follow-up slice.
- Append-only decision logging for every send-or-suppress outcome.
- Delegating approved delivery to Notify through `INotificationSender` from `HoneyDrunk.Notify.Abstractions`.
- Consuming Grid/Operation context through `HoneyDrunk.Kernel.Abstractions` without taking a full Kernel runtime dependency.

## What Communications Does NOT Own

- **Provider adapters** - SMTP, Resend, Twilio, and future delivery providers belong in Notify.
- **Template rendering** - template keys, rendering mechanics, and provider payload mapping belong in Notify.
- **Queue-backed intake/delivery mechanics** - enqueueing, retry classification, workers, and dead-letter handling belong in Notify.
- **Structural notification validation** - malformed delivery envelopes are rejected by Notify.
- **Telemetry storage/visualization** - Communications emits decision telemetry; Pulse observes and stores telemetry.
- **Durable workflow engine primitives** - Flow owns generalized workflow orchestration when Communications needs a durable multi-step engine.
- **Authorization and human-policy gates** - Auth and Operator own identity/authorization/approval decisions. Communications only owns message-delivery preference/cadence decisions.

## Boundary Decision Tests

Before adding behavior to Communications, ask:

1. Does it decide **whether this recipient should receive this message now**? Communications.
2. Does it map a business event into **intent, audience, cadence, or suppression**? Communications.
3. Does it render, enqueue, retry, classify provider errors, or call provider SDKs? Notify.
4. Does it decide whether an action is authorized or requires human approval? Auth/Operator.
5. Does it persist or query generalized application data? Data.
6. Does it coordinate arbitrary long-running workflows beyond messaging semantics? Flow.

## Kernel Split Rule

Communications may require Kernel abstractions (`IGridContextAccessor`, `IOperationContextAccessor`, telemetry activity factory, typed tenant IDs), but must not bring in the full Kernel runtime package unless a future ADR explicitly changes the boundary.

## Notify Split Rule

Notify may still be called directly for exceptional one-shot transactional delivery with no preference, cadence, or workflow requirement. User-facing lifecycle messages should enter through Communications so preferences, cadence, and decision logs stay centralized.
