---
title: Reconcile PDR-0001 observed-signal boundary with Pulse
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
wave: 1
initiative: pdr-0001-honeyhub-platform
node: honeydrunk-architecture
tier: 2
labels: ["chore", "tier-2", "meta", "pdr-0001", "adr-0010", "pulse", "strategic"]
dependencies: []
adrs: ["PDR-0001", "ADR-0003", "ADR-0010"]
source: strategic
generator: scope
---

# Reconcile PDR-0001 observed-signal boundary with Pulse

## Summary

Resolve the documentation and decision-boundary drift around whether normalized observed signals flow from `HoneyDrunk.Observe` into Pulse, HoneyHub, or both.

## Context

The PDR-0001 implementation coverage map found one concrete gap that should not be papered over as traceability-only drift:

- PDR-0001 says the Observation layer feeds HoneyHub and Pulse.
- ADR-0010 says Pulse gains a second input mode for observed signals from the Observation layer.
- `repos/HoneyDrunk.Observe/integration-points.md` says Observe and Pulse do not integrate directly.
- ADR-0003 says Pulse collects telemetry while HoneyHub interprets signal meaning.

Those statements may be reconcilable, but today the repo does not say which one is authoritative. This matters before any ADR-0010 Phase 2 runtime packet implements a GitHub connector or observation pipeline, because the wrong interpretation would blur either the Observe/Pulse boundary or the Pulse/HoneyHub boundary.

This packet is Architecture-only. It does not implement Pulse, Observe, or HoneyHub runtime behavior.

## Scope

- Read PDR-0001, ADR-0003, ADR-0010, and the `repos/HoneyDrunk.Observe/`, `repos/HoneyDrunk.Pulse/`, and `repos/HoneyHub/` context folders.
- Decide whether the intended boundary is:
  - Observe emits normalized organizational observations only to HoneyHub, and Pulse sees only derived telemetry/health from HoneyHub or Node emissions.
  - Observe emits a narrow telemetry-shaped projection to Pulse, while HoneyHub receives the full normalized observation event.
  - A new Pulse input-model ADR is required before implementation can proceed.
- Update the smallest set of Architecture docs needed to remove the contradiction.
- If a new ADR is required, create a proposed ADR draft or proposed issue packet for that ADR, rather than silently choosing a runtime boundary.

## Acceptance Criteria

- [ ] The coverage map's observed-signal gap is resolved or explicitly escalated to a follow-up ADR.
- [ ] ADR-0010, PDR-0001, and repo context docs no longer contradict each other on Observe -> Pulse / Observe -> HoneyHub flow.
- [ ] The result preserves ADR-0003's boundary: Pulse collects/routes telemetry; HoneyHub interprets meaning and plans work.
- [ ] The result preserves ADR-0010's boundary: Observe owns external signal intake, credential resolution, normalization, and observation state.
- [ ] If runtime implementation remains deferred, the trigger for ADR-0010 Phase 2 remains clear and no implementation packet is created.
- [ ] No secret values, customer PII, webhook URLs, tokens, or full stack traces are copied into generated packets, reports, PR bodies, or comments.

## Human Prerequisites

None.

## Dependencies

None.

## Labels

- chore
- tier-2
- meta
- pdr-0001
- adr-0010
- pulse
- strategic

## Agent Handoff

**Objective:** Reconcile the observed-signal boundary between Observe, Pulse, and HoneyHub before ADR-0010 Phase 2 implementation is generated.

**Target:** HoneyDrunkStudios/HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: PDR-0001 HoneyHub platform traceability and boundary cleanup.
- Feature: Observation layer output routing semantics.
- ADRs/PDRs: PDR-0001, ADR-0003, ADR-0010.

**Constraints:**
- Do not implement runtime behavior.
- Do not create a Pulse or Observe target-repo packet unless the Architecture decision is already settled.
- Do not directly amend an Accepted ADR with a new decision unless the existing ADR's amendment convention permits it; otherwise create a proposed ADR/amendment packet.
- Keep HoneyHub as interpreter/planner, Pulse as telemetry pipeline, and Observe as external-signal normalizer.

**Key Files:**
- `generated/coverage-maps/2026-06-05-pdr-0001-implementation-coverage.md`
- `pdrs/PDR-0001-honeyhub-platform-observation-and-ai-routing.md`
- `adrs/ADR-0003-honeyhub-control-plane.md`
- `adrs/ADR-0010-observation-layer.md`
- `repos/HoneyDrunk.Observe/integration-points.md`
- `repos/HoneyDrunk.Observe/boundaries.md`
- `repos/HoneyDrunk.Pulse/`
- `repos/HoneyHub/`

**Contracts:**
- No public code contract changes are expected.
