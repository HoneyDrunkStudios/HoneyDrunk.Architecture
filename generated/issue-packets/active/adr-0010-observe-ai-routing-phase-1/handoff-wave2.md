# Handoff: Wave 1 → Wave 2 — ADR-0010 Phase 1

**Date written:** 2026-04-18
**Read at:** Wave 1 → Wave 2 transition (after packets 01 and 02 have merged/closed)
**Audience:** The Codex Cloud / Claude Code agent starting work on `03-observe-abstractions-scaffold.md` or `04-ai-add-routing-contracts.md`

This handoff is a one-shot baton pass. It is read at the transition and then left alone — it is not a live tracker.

## Wave 1 completion state

Before starting Wave 2, confirm the following are true:

- [ ] Packet 01 PR merged to `HoneyDrunk.Architecture:main`
- [ ] ADR-0010 index row in `adrs/README.md` reads `Accepted`
- [ ] `ADR-0010-observation-layer.md` header reads `**Status:** Accepted`
- [ ] `catalogs/nodes.json` contains a `honeydrunk-observe` entry with `sector: "Ops"` and `signal: "Seed"`
- [ ] `catalogs/relationships.json` contains a `honeydrunk-observe` entry with `consumes: ["honeydrunk-kernel", "honeydrunk-vault"]`
- [ ] `catalogs/contracts.json` has three new observation interfaces under `honeydrunk-observe` and three new routing interfaces appended to `honeydrunk-ai`
- [ ] `catalogs/grid-health.json` has a `honeydrunk-observe` entry
- [ ] `repos/HoneyDrunk.Observe/` directory exists with five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`)
- [ ] `constitution/sectors.md` Ops section lists Observe
- [ ] `constitution/invariants.md` has added full text for invariants 29 and 30. Invariant 28 still carries its `(Proposed — this invariant takes effect when ADR-0010 is accepted)` qualifier — that qualifier stays intact until packet 04 ships, which is deferred to a future initiative gated on the HoneyDrunk.AI standup ADR.
- [ ] `initiatives/active-initiatives.md` has the Phase 1 initiative entry with Phase 2/3 pointers
- [ ] Packet 02 chore closed — `HoneyDrunkStudios/HoneyDrunk.Observe` exists on GitHub

If any box is unchecked, stop and resolve it before starting Wave 2. The scaffold packet's review agent reads these files as scope context; if they are missing, the review degrades and Wave 2 quality drops.

## Wave 2 packet (Observe only)

Only one packet in Wave 2 now. Packet 04 is deferred pending a HoneyDrunk.AI standup ADR — see the dispatch plan's Deferred section for context.

### Packet 03 — `03-observe-abstractions-scaffold.md` → target `HoneyDrunk.Observe`

Scaffolds the new repo with:
- `HoneyDrunk.Observe.slnx`
- `src/HoneyDrunk.Observe.Abstractions/` project with `.csproj`, three interface files, `README.md`, `CHANGELOG.md`
- Repo-root `README.md`, `CHANGELOG.md` (version 0.1.0), `.editorconfig`, `Directory.Build.props`
- `.github/workflows/pr-core.yml` consuming `HoneyDrunk.Actions`' reusable workflow

Contract surface (exact member shapes at executor discretion, subject to the constraints below):
- `IObservationTarget` — external-system declaration; carries a credential **reference** (Vault secret name), never a raw credential
- `IObservationConnector` — provider-slot interface for connector implementations
- `IObservationEvent` — canonical normalized observation event

Do not scaffold runtime or connector packages. Abstractions only.

## New package versions to reference

After Wave 2 merges:
- `HoneyDrunk.Observe.Abstractions` — `0.1.0` (preview or release, executor decides based on repo CI conventions)
- `HoneyDrunk.AI.Abstractions` — **not touched by this initiative.** The AI routing contracts packet (04) is deferred pending the HoneyDrunk.AI standup ADR + initiative.

## Invariants that kick in at Wave 2 completion

Wave 1 finalizes invariants 29 and 30 in `constitution/invariants.md`. Wave 2 ships `IObservationEvent` as the canonical normalization target:

- **Invariant 28** remains `(Proposed)` at Wave 2 completion. The qualifier flip is tied to `IModelRouter` shipping, which is deferred until the HoneyDrunk.AI standup ADR + initiative lands and packet 04 becomes fileable. Do not remove the qualifier in this initiative.
- **Invariant 29** applies to any connector package. Wave 2 ships no connectors (Phase 2 scope), so invariant 29 governs future work but is not exercised yet.
- **Invariant 30** is satisfied by `IObservationEvent` existing as the canonical normalization target. Any future connector that crosses raw external payloads out of the Observe boundary violates this.

## Out of scope for Wave 2

Reminder — do not attempt:
- GitHub, Azure, or HTTP connector implementations (Phase 2)
- AI routing contracts additions to `HoneyDrunk.AI.Abstractions` (deferred — HoneyDrunk.AI repo is empty; scaffolding requires its own standup ADR)
- `ModelRouter` runtime class (Phase 2, blocked further behind AI standup)
- Cost-first `IRoutingPolicy` implementation (Phase 2, blocked further behind AI standup)
- App Configuration loader for routing policies (Phase 2, blocked further behind AI standup)
- Observe → HoneyHub event routing (Phase 3, blocked on HoneyHub)
- Any `.Tests` or `.Canary` project content beyond directory placeholders

If scope feels small, that is intentional — Phase 1 exists specifically to ship contracts so Phase 2 implementations can parallelize against stable surface.

## On encountering divergence

If an executor discovers Wave 1 output has drifted from what this handoff describes — e.g., `catalogs/contracts.json` has a different shape than assumed, or `repos/HoneyDrunk.Observe/` is missing files — do not improvise. Stop, file a follow-up issue against `HoneyDrunk.Architecture` describing the drift, and wait for resolution. Silent improvisation at the boundary is how the review agent's scope check breaks.
