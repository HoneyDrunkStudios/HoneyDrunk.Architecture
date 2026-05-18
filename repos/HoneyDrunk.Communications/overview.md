# HoneyDrunk.Communications - Overview

**Sector:** Ops  
**Version:** 0.2.0
**Framework:** .NET 10.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Communications`

## Purpose

Outbound-messaging orchestration substrate above Notify. Communications decides whether a message should be sent, to whom, when, and why; Notify owns delivery mechanics.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Communications.Abstractions` | Abstractions | Public contracts for intents, recipient resolution, preferences, cadence, orchestration decisions, and decision logs. |
| `HoneyDrunk.Communications` | Runtime | Default orchestrator, in-memory preference/cadence/decision-log implementations, welcome-flow intents, health/startup hooks, and DI wiring. |

## Key Contracts

- `ICommunicationOrchestrator` - evaluates and sends message intents through the Communications decision layer.
- `IMessageIntent` / `MessageIntent` - interface and simple immutable value shape for business-event message intents.
- `IRecipientResolver` - resolves one or more recipients for an intent.
- `IPreferenceStore` - tenant-scoped recipient preference store.
- `ICadencePolicy` - tenant-scoped cadence/suppression policy.
- `ICommunicationDecisionLog` / `CommunicationDecisionLogEntry` - append-only audit surface for send-or-suppress decisions.
- `MessageDecision`, `MessageDecisionOutcome`, `RecipientHandle`, `RecipientPreferences`, `CadenceVerdict`, and `CadenceOutcome` - public decision and policy value shapes.

## Current Runtime Shape

As of v0.2.0, Communications consumes Kernel through `HoneyDrunk.Kernel.Abstractions` only; it does not depend on the full Kernel runtime package. Delivery remains delegated through `HoneyDrunk.Notify.Abstractions`.

The first runtime slice ships the welcome-email path:

1. A caller passes a `WelcomeEmailIntent` or another `IMessageIntent` to `ICommunicationOrchestrator`.
2. Communications resolves tenant-scoped preferences and cadence.
3. Communications records the decision.
4. If allowed, Communications delegates delivery to Notify through `INotificationSender`.
5. The runtime may schedule a follow-up intent via the in-memory follow-up scheduler.

## Deferred Surfaces

- A separate `HoneyDrunk.Communications.Testing` package from ADR-0019 is intentionally deferred; test fixtures currently live in the runtime/test project.
- Durable preference, cadence, follow-up, and decision-log stores are deferred. The current runtime uses in-memory implementations.
- Complex campaign/flow orchestration is deferred. The current slice proves the boundary through welcome-email orchestration.
