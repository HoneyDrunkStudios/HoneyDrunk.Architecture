# ADR-DRAFT: Idempotency Contract for Async Boundaries

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

ADR-0028 (Proposed) commits Azure Service Bus as the default broker for async work and pub/sub fanout. Service Bus delivery semantics are **at-least-once**: a message may be delivered more than once under retry, redelivery, dead-letter recovery, or failover. The Grid's response to this — today — is implicit. Each Node handles duplicates ad-hoc:

- Notify's delivery pipeline tolerates duplicates by virtue of provider-side dedup (most ESPs reject duplicate `Message-ID`s).
- Communications has no documented idempotency model.
- Pulse signals are explicitly non-domain-events per ADR-0028; their re-emit semantics are a Pulse concern, not a Grid concern.
- The Audit Node (ADR-0030/0031) at standup has no idempotency contract; double-emit on retry produces double-audit entries.
- The future Billing pipe (ADR-0037 D2) explicitly requires end-to-end idempotency, including into Stripe Meter Events.

This is a Grid-wide latent contract. Every consumer of the default broker has to solve the same problem in the same way; the absence of a Grid-level contract guarantees per-Node drift in how they solve it. The forcing functions:

- **ADR-0037 (Payment)** requires idempotency end-to-end; cites this ADR as a prerequisite.
- **ADR-0036 (DR)** depends on this ADR for the "T2 message loss on Service Bus forced failover is recoverable via consumer idempotency" claim.
- **AI-sector standup wave** introduces tool-call dispatch and agent execution; reissuing an agent step on retry must not double-execute side-effecting tools.
- **ADR-0030 Audit** is itself an emitter from many sources; duplicate audit entries cause forensic confusion.

This ADR decides: the idempotency key shape, where dedup state lives, the retention window for dedup state, the per-Node responsibilities at producer/consumer boundaries, and the canary that enforces the contract.

## Decision

### D1 — Every async boundary message carries an `IdempotencyKey`

Every message published on the default Service Bus topic (and every command published on a Service Bus queue per ADR-0028) carries a string-shaped `IdempotencyKey` in its user-properties. The key is:

- Mandatory. Messages without an `IdempotencyKey` are rejected at the consumer side (canary-enforced; production messages are dropped with a poison-letter trace).
- Produced **once at message origination**, never regenerated on retry. The producer's retry path reuses the same key; the consumer's redelivery sees the same key.
- Opaque to the broker. Service Bus's own `MessageId` is **separate** and is not used as the idempotency key (Service Bus dedup windows are limited and the semantics are message-level, not domain-level).
- A UUID v4 by default; producers may use a deterministic key when the message corresponds to a deterministic input (e.g., `notify-send:<tenant>:<external-id>`), but the key must still survive retries.

The key shape is exposed via `IGridMessageEnvelope.IdempotencyKey` in `HoneyDrunk.Kernel.Abstractions` (additive to the existing envelope). All async producers and consumers go through this envelope.

### D2 — Dedup state lives at the consumer, scoped per consumer-group

Each consumer (each Service Bus subscription, each queue receiver) maintains its own dedup state — a key-value store of `IdempotencyKey → (FirstSeenAt, Outcome)`. The store:

- Is **separate per consumer-group**. A subscription that delivered `key=X` to consumer A does not affect consumer B's view; B might be receiving for the first time. This is the standard pattern; broker-side dedup is insufficient because different consumers care about different idempotency boundaries.
- Is **durable** at Tier 1 per ADR-0036 (dedup state loss is a recoverable but customer-impacting event).
- Lives in `HoneyDrunk.Data` backing per consumer's choice (a small Cosmos container, Redis-class cache, or a Postgres table is acceptable). The interface is `IIdempotencyStore` in `HoneyDrunk.Kernel.Abstractions`:

```
ValueTask<IdempotencyClaim> TryClaim(IdempotencyKey key, TimeSpan ttl);
ValueTask<IdempotencyClaim?> Read(IdempotencyKey key);
ValueTask Complete(IdempotencyClaim claim, IdempotencyOutcome outcome);
```

The default backing is `HoneyDrunk.Kernel.Idempotency.Cosmos` (small Cosmos container, partition key = consumer-group); alternative backings are pluggable.

### D3 — Consumer pattern: claim, process, complete

Every consumer of an async message follows this pattern (encoded once in a shared `IdempotentMessageHandler<T>` base):

1. **Claim** the idempotency key for the current consumer-group with the configured TTL. If the key is already claimed and not yet completed, defer (return to broker for redelivery after the lease expires).
2. If the key is **already completed**, return the recorded outcome without re-executing side effects. This is the dedup payoff.
3. **Process** the message; any side effects (DB writes, HTTP calls, downstream message emits) happen here.
4. **Complete** the claim with the outcome (`Succeeded`, `Failed`, plus a small outcome record for any reply needed).

Side-effect ordering: if a consumer's processing **emits a downstream message**, the downstream message's `IdempotencyKey` is **deterministically derived from the inbound key** (`SHA256(inbound:relationship)`). This makes the entire chain idempotent — replaying message A leads to the same downstream message B (same key), which is dedup'd by B's consumers.

### D4 — TTL: 7 days standard, 30 days for billing/audit

The dedup-state TTL determines how long the system remembers a key. Tradeoffs: longer TTL = stronger replay protection but larger store + slower lookups.

- **Standard TTL: 7 days.** Covers ordinary retry storms, broker maintenance, and the ADR-0036 T1 RTO window with margin.
- **Billing TTL: 30 days.** Stripe Meter Events allows backfilling within ~30 days; the Billing pipe (ADR-0037) must remain idempotent across that window.
- **Audit TTL: 30 days.** Forensic completeness; matches the deliverability/feedback-loop window in ADR-0038.

TTLs are configured per consumer-group, not per message. The Kernel's default is 7 days; consumers override at registration.

### D5 — Producer responsibilities

Producers:

- Generate and attach the `IdempotencyKey` at the message-construction site. **Never** at the broker-publish site (which would regenerate on retry).
- Persist the key in the producer's local state if the producer needs to know whether its own publish succeeded (e.g., the "I sent the notification" record carries the same key).
- Use deterministic keys when possible (`notify-send:<tenant>:<external-id>`). Random keys are acceptable but deterministic keys make replay observable.

The Kernel ships an `IGridMessagePublisher` helper that handles publish-with-retry and never regenerates the key.

### D6 — Reply semantics

For request/reply patterns (synchronous over async), the reply message's `IdempotencyKey` is derived from the request's key (`SHA256(request:reply)`). This means a replayed request gets the same reply key, and the consumer of the reply can dedup on it.

### D7 — Non-domain-event carve-outs

Per ADR-0028, **Pulse signals are not domain events** and may safely re-emit. They do not require `IdempotencyKey` and are exempt from D1's mandatory-attribute rule. The Pulse signal envelope is a separate `IPulseSignalEnvelope`, not `IGridMessageEnvelope`; this is enforced at the type level.

Similarly, **telemetry signals** (OTLP traces, metrics, logs per ADR-0010 and the future telemetry-backend ADR) are not domain events and not bound by this contract.

The carve-out boundary is: **if a re-delivered message could cause a side effect a tenant or auditor would care about, it is a domain event and bound by this ADR.** If it is a fire-and-forget observation signal, it isn't.

### D8 — In-process events are exempt

In-process events (per ADR-0028's matrix) do not cross a broker; they are bound by stronger guarantees (single-process, in-memory). The idempotency contract does not extend to in-process events, but consumers that bridge from in-process to async **must** attach an `IdempotencyKey` at the bridge point.

### D9 — Canary

A canary in `HoneyDrunk.Kernel.Tests.Canaries`:

- Publishes a message twice with the same `IdempotencyKey` to a test consumer.
- Asserts the consumer's side effect happened exactly once.
- Asserts the dedup-store contains the key with the outcome.
- Replays the same key after the TTL window expires and asserts the side effect happens again (TTL is real, not infinite).

This canary runs in every environment per ADR-0033's deploy validation. Audit's standup canary (per ADR-0031) wires the same shape against its own dedup boundary.

### D10 — Backward compatibility

Existing async producers (Notify, Communications) are amended to emit `IdempotencyKey` in a rollout packet. During the rollout, consumers must tolerate messages without a key (treat as effectively-not-idempotent: process exactly as today, no dedup). The canary's mandatory-attribute check (D1) flips on after the rollout completes.

This is the only transitional accommodation; once the rollout closes, the canary enforces strict policy.

## Consequences

### Affected Nodes

- **HoneyDrunk.Kernel** — primary affected Node; gains `IGridMessageEnvelope.IdempotencyKey`, `IIdempotencyStore`, `IdempotentMessageHandler<T>`, `IGridMessagePublisher`. This is the first material addition to Kernel.Abstractions since ADR-0026's `TenantId` strict-typing.
- **HoneyDrunk.Data** — provides the default Cosmos-backed `IIdempotencyStore` implementation under `HoneyDrunk.Kernel.Idempotency.Cosmos` or similar; the boundary follows the existing `HoneyDrunk.Data.*` backing precedent.
- **HoneyDrunk.Notify, HoneyDrunk.Communications, HoneyDrunk.Pulse** — every async producer/consumer is amended to use the new envelope and helpers.
- **HoneyDrunk.Audit** (Seed) — at standup, wires `IdempotentMessageHandler<AuditEmit>`; TTL = 30 days.
- **HoneyDrunk.Billing** (future, ADR-0037) — depends on this ADR for end-to-end idempotency into Stripe.
- **HoneyDrunk.AI / Agents / Flow** (Seed) — tool dispatch and step execution are idempotent message handlers under the same pattern.

### Invariants

Adds three:

- **Invariant: every async domain-event message carries an `IdempotencyKey`.** Pulse and telemetry signals are explicit carve-outs.
- **Invariant: dedup state lives per consumer-group, with TTL.** Broker-side dedup is not a substitute.
- **Invariant: downstream message keys are deterministically derived from the originating key.** Idempotency is end-to-end, not per-hop.

### Operational Consequences

- The default Cosmos dedup container is a new Azure resource per environment per consumer-group. At Grid scale this is a small number; cost is minor (single-digit dollars/month in `dev`/`staging`/`prod` combined).
- Kernel.Abstractions gains new interfaces; per ADR-0035 this is an **additive minor bump** (additions on new interfaces, not on existing ones). No breaking change.
- The `IdempotentMessageHandler<T>` base introduces a small latency penalty per message (one extra round-trip to the dedup store). At Cosmos's single-digit-ms latency, this is acceptable for all current consumers.
- TTL expiry means a sufficiently delayed redelivery (>7 days) is processed as a new message. This is recorded as the design tradeoff: indefinite dedup is impractical; the window is operational.
- Pulse and telemetry exemptions (D7) keep the high-volume signal pipes off this contract; the cost story remains correct at scale.

### Follow-up Work

- Implement the Kernel additions (interfaces, helpers, base handler).
- Implement the default Cosmos dedup-store backing.
- Implement the canary in `HoneyDrunk.Kernel.Tests.Canaries`.
- Roll out the envelope amendment to existing async producers/consumers (Notify, Communications) per ADR-0035 cascade-procedure D7. Estimate: 3 packets.
- Wire the Audit standup against the new contract (per ADR-0031).
- Wire the Billing pipe (per ADR-0037) on top of this contract; explicit prerequisite.

## Alternatives Considered

### Use Service Bus's built-in dedup window (10 minutes default, up to 7 days)

Rejected. Broker-side dedup is message-id-scoped, not domain-key-scoped. A retry that publishes the same logical event with a new `MessageId` (which is the common case across producer crash-and-restart) is not caught. Broker dedup also doesn't extend to downstream messages emitted by consumers.

### Exactly-once delivery via Service Bus sessions and transactions

Considered. Service Bus offers some exactly-once-shaped primitives via sessions and transactions, but they constrain partitioning (one session at a time) and they are weak across cross-resource transactions (the Stripe meter-event call cannot participate in a Service Bus transaction). Net: insufficient for the end-to-end story; an additional consumer-side dedup layer is still required. Adopting both adds complexity for no clear benefit beyond what consumer-side dedup gives.

### Producer-side dedup only (consumer trusts the key but doesn't enforce)

Rejected. Producer-side dedup catches only producer-retry storms, not consumer-retry redeliveries. The redelivery is the more common case; consumer-side is the load-bearing half.

### Stronger guarantee per-message (require deterministic keys everywhere)

Rejected. Deterministic keys are great when they exist (`notify-send:<tenant>:<external-id>`) but many producers don't have a natural deterministic input (an internal agent step doesn't have an external id). Mandating deterministic keys forces producers to invent them; UUID v4 with retry-safe persistence is sufficient.

### Per-Node ad-hoc idempotency (no Grid-wide contract)

Rejected by the forcing functions. Audit, Billing, and the AI standup wave all need the same contract; the cost of writing it three times exceeds the cost of writing it once in Kernel.

### Skip until first duplicate-message incident

Rejected. The first duplicate-message incident at Notify Cloud GA would be a customer-data integrity issue (double-charged, double-notified, double-audited). Cheaper to land the contract before commercial volume.
