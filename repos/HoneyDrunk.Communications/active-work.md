# HoneyDrunk.Communications - Active Work

**Last Updated:** 2026-05-16  
**Signal:** Live - v0.1.0 packages released; production durability and advanced workflows remain deferred. One open compliance gap: the ADR-0019 D8 / Invariant 43 contract-shape canary is not wired (Communications#12).

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

## Open Compliance Gap

- **ADR-0019 D8 / Invariant 43 contract-shape canary is not wired.** Communications uses the shared `pr-core.yml` workflow, which has no api-compatibility job; the canary lives on the shared `pr-sdk.yml` path. ADR-0019's acceptance boxes for this were checked in error and have been corrected (see ADR-0019 "Post-Acceptance Correction"). Remediation tracked by `HoneyDrunkStudios/HoneyDrunk.Communications#12`.

## Resolved

- ADR-0013-era tracking fully retired: ADR-0013 superseded by ADR-0019, all six ADR-0013-derived issues closed, Architecture catalog reconciliation (#82) complete, Notify boundary refactor (Notify#9) complete. No dangling ADR-0013 work remains.

## Deferred Work

- Durable preference store.
- Durable cadence policy state.
- Durable decision-log storage.
- Durable follow-up scheduler / campaign orchestration.
- Separate `HoneyDrunk.Communications.Testing` package if downstream tests need reusable fixtures.
- Complex multi-step campaigns using Flow when the Flow Node exists.
