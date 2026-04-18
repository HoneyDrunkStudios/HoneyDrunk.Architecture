# ADR-0013: Communications Orchestration Layer — HoneyDrunk.Communications

**Status:** Proposed
**Date:** 2026-04-16
**Deciders:** HoneyDrunk Studios
**Sector:** Ops

## Context

HoneyDrunk.Notify exists as the Grid's delivery engine for outbound messages — it handles channel routing, provider adapters (Resend, SMTP, Twilio), template rendering, queue-backed delivery, retries, and delivery outcome tracking. It answers: *how do we send this message reliably?*

What Notify does not answer is: *should we send something, to whom, and as part of what workflow?*

Today, any Node that wants to send a notification calls `INotificationSender` directly. This works for one-shot messages, but as the Grid grows, several concerns have no home:

- **Message intent mapping** — translating a business event (user signed up, subscription expiring, agent completed a task) into a message decision
- **Recipient resolution** — determining who should receive based on context, not just a hardcoded address
- **User preferences** — opt-outs, channel preferences, quiet hours, suppression lists
- **Cadence control** — rate-limiting and spacing messages to prevent notification fatigue
- **Multi-step flows** — welcome sequences, drip campaigns, re-engagement, escalation chains
- **Decision audit** — recording why a message was sent or suppressed

Without a dedicated orchestration layer, these concerns will scatter across every Node that triggers communication, leading to duplicated preference checks, inconsistent cadence enforcement, and no single place to reason about a user's full communication lifecycle.

## Decision

### New Node: HoneyDrunk.Communications

**Sector:** Ops (alongside Notify, Pulse, and Actions)

Communications is the decision and orchestration layer for all outbound messaging. It sits above Notify and delegates all delivery mechanics to it.

**Communications owns:**
- Business-event-to-message-intent mapping — declare what happened, Communications decides what to send
- Recipient resolution — who should receive based on context, roles, and relationships
- User preference enforcement — opt-in/out, channel preferences, quiet hours, suppression
- Cadence policy — frequency and spacing rules per user to prevent notification fatigue
- Multi-step communication flows — welcome sequences, drip campaigns, escalation chains
- Decision audit log — every send-or-suppress decision is recorded with reasoning

**Communications does NOT own:**
- Template rendering (Notify)
- Provider adapters — SMTP, Resend, Twilio (Notify)
- Retry logic and dead-letter handling (Notify)
- Queue-backed delivery and worker processing (Notify)
- Delivery outcome tracking (Notify)
- Channel routing mechanics (Notify)

### Boundary Rule

> If the concern is **delivery mechanics**, it belongs in **Notify**.
> If the concern is **message logic or workflow**, it belongs in **Communications**.

### Contracts (seed — subject to refinement during implementation)

| Contract | Kind | Description |
|----------|------|-------------|
| `ICommunicationOrchestrator` | interface | Top-level entry point — given a business event, decides what messages to send, to whom, and when. Delegates delivery to Notify. |
| `IMessageIntent` | interface | Maps a business event to a message intent — captures the why and what of a communication. |
| `IRecipientResolver` | interface | Resolves the target audience for a message intent. |
| `IPreferenceStore` | interface | User communication preferences — opt-in/out, channel preferences, quiet hours, suppression lists. |
| `ICadencePolicy` | interface | Enforces message frequency and spacing rules per user. |

### Dependency Graph

```
Communications
    │
    ├─ consumes ──► Kernel (IGridContext, lifecycle, telemetry)
    ├─ consumes ──► Notify (INotificationSender — delivery delegation)
    │
    ├─ consumed_by_planned ──► Flow (multi-step workflow orchestration)
    │
    └─ emits telemetry ──► Pulse (orchestration decisions, latency)
```

### Interaction Example

A user signs up:

1. The originating Node fires a `UserSignedUp` event
2. **Communications** receives the event via `ICommunicationOrchestrator`
3. Communications maps it to a welcome-email intent (`IMessageIntent`)
4. Communications resolves the recipient (`IRecipientResolver`)
5. Communications checks preferences — user has not opted out (`IPreferenceStore`)
6. Communications checks cadence — user has not been messaged recently (`ICadencePolicy`)
7. Communications calls `INotificationSender` (Notify) to send the welcome email
8. Communications schedules a follow-up: if the user has not activated in 2 days, send a nudge
9. Communications logs the decision (sent welcome, scheduled follow-up)

**Notify** receives the `INotificationSender` call and:
1. Renders the email template
2. Calls Resend (or SMTP)
3. Retries on failure
4. Records the delivery result

## Consequences

### Catalog Changes (completed with this ADR)

- [x] Added `honeydrunk-communications` to `catalogs/nodes.json` (Seed, Ops sector)
- [x] Added to `catalogs/grid-health.json` (Seed, version 0.0.0, blocked: repo not yet scaffolded)
- [x] Added to `catalogs/relationships.json` (consumes Kernel + Notify, consumed_by_planned: Flow)
- [x] Added to `catalogs/contracts.json` (5 seed contracts)
- [x] Added to `catalogs/modules.json` (Communications.Abstractions + Communications runtime)
- [x] Updated Notify's `consumed_by` to include `honeydrunk-communications`
- [x] Updated `constitution/sector-interaction-map.md` (Ops section, Communications ↔ Notify split rule)
- [x] Updated `constitution/feature-flow-catalog.md` (Flow 2 renamed, Flow 2b added)

### Remaining Work (post-acceptance)

- [ ] Create `HoneyDrunk.Communications` GitHub repo (human-only step)
- [ ] Scaffold solution with Abstractions and Runtime projects
- [ ] Create `repos/HoneyDrunk.Communications/` context folder in Architecture repo (overview, boundaries, invariants, active-work, integration-points)
- [ ] Define CI workflows (validate-pr, publish, deploy) using HoneyDrunk.Actions shared workflows
- [ ] Implement first flow: welcome email sequence using Notify as delivery backend

### Positive

- Clear separation of concerns — Notify stays focused on reliable delivery, Communications owns the decision layer
- Nodes that trigger messages no longer need to implement preference checks, cadence rules, or workflow logic themselves
- Multi-step flows (welcome sequences, campaigns, escalation) have a dedicated home
- Decision audit trail enables debugging and compliance review of all outbound communication
- The pattern mirrors the Pulse ↔ Operator split: Pulse collects data, Operator reasons about it; Notify delivers messages, Communications reasons about them

### Negative

- One more repo to maintain for a solo developer. Mitigation: Communications is a lightweight orchestration layer, not a second delivery engine. It depends on Notify for all heavy lifting.
- Business events must be routed through Communications to benefit from preferences and cadence. Nodes that bypass Communications and call Notify directly will not get these protections. Mitigation: convention enforcement via architecture docs and agent instructions.

## Alternatives Considered

### Embed orchestration in Notify

Rejected. Notify is a delivery engine with a clear, stable contract surface (`INotificationSender`, `INotificationGateway`). Adding workflow state, preference storage, and cadence enforcement would bloat Notify's responsibility and couple delivery reliability to business logic changes. The same reasoning that separates Pulse (data pipeline) from Operator (meaning layer) applies here.

### Embed orchestration in each calling Node

Rejected. This is the current implicit state — each Node that calls `INotificationSender` is responsible for its own preference checks and workflow logic. This leads to duplication, inconsistency, and no central place to enforce cadence rules or audit communication decisions.

### Use Flow (AI sector) for communication orchestration

Rejected for now. Flow is a general-purpose multi-step orchestration engine in the AI sector. Communications is a domain-specific orchestration layer for outbound messaging. Communications may eventually consume Flow for complex campaign orchestration, but the domain-specific concerns (preferences, suppression, cadence) belong in a dedicated Node, not in a general-purpose workflow engine.

## Phase Plan

### Phase 1 — Contracts and Scaffold

- Create repo and solution structure
- Define `ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy` in `HoneyDrunk.Communications.Abstractions`
- Wire Kernel integration (IGridContext, lifecycle hooks)

### Phase 2 — Welcome Sequence (First useful increment)

- Implement welcome email flow: UserSignedUp → welcome email → 2-day follow-up if not activated
- In-memory preference store and cadence policy for initial development
- Integration with Notify's `INotificationSender`

### Phase 3 — Persistence and Production

- Persist preference state and flow state (likely via Data Node)
- Production deployment alongside Notify
- Telemetry emission to Pulse for communication decision metrics
