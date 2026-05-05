# HoneyDrunk.Communications - Active Work

**Last Updated:** 2026-05-05  
**Signal:** Live - v0.1.0 packages released; production durability and advanced workflows remain deferred.

## Completed Bring-Up

- GitHub repo created: `HoneyDrunkStudios/HoneyDrunk.Communications`.
- Scaffold landed with `HoneyDrunk.Communications.Abstractions`, `HoneyDrunk.Communications`, HoneyDrunk.Standards wiring, CI, and NuGet release workflow.
- Phase 1 contracts landed:
  - `ICommunicationOrchestrator`
  - `IMessageIntent` / `MessageIntent`
  - `IRecipientResolver`
  - `IPreferenceStore`
  - `ICadencePolicy`
  - `ICommunicationDecisionLog` / `CommunicationDecisionLogEntry`
- Phase 2 welcome-flow runtime landed and delegates approved sends to Notify.
- v0.1.0 released for both packages:
  - `HoneyDrunk.Communications.Abstractions`
  - `HoneyDrunk.Communications`
- Notify ADR-0019 boundary refactor completed in `HoneyDrunk.Notify` v0.2.0: policy evaluation moved out of Notify and intake folder naming is now delivery-oriented.

## Current Architecture Follow-Up

- Reconcile Architecture source-of-truth files against the shipped 0.1.0 Communications surface.
- Move stale ADR-0013-era tracking to ADR-0019 ownership as part of Architecture issue #82.

## Deferred Work

- Durable preference store.
- Durable cadence policy state.
- Durable decision-log storage.
- Durable follow-up scheduler / campaign orchestration.
- Separate `HoneyDrunk.Communications.Testing` package if downstream tests need reusable fixtures.
- Complex multi-step campaigns using Flow when the Flow Node exists.
