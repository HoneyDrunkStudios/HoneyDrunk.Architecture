# Program: Curiosities

**Governing PDR:** [PDR-0008: Curiosities - Discovery-First City App](../../pdrs/PDR-0008-curiosities-discovery-first-city-app.md) - Proposed
**Status:** Forming
**Roadmap thread:** [Curiosities](../roadmap.md) (Q2-Q4 2026, discovery-first city-app lane) · **Current-focus row:** #10
**Kill criteria / gates:** PDR-0008 Kill Criteria 1-4, especially Phase 0 content cost/quality viability
**Last updated:** 2026-06-13

Context: Curiosities is now one of the three active planning lanes, even though its implementation shape is still lighter than HoneyHub and Notify Cloud. ADR-0089 originally deferred a Curiosities program tracker until PDR-0008 spawned multiple ADRs; this file is intentionally a lane tracker first and a full multi-ADR program tracker later. It exists so priorities, roadmap work, and active initiatives have a single place to point instead of treating Curiosities as a loose Future bullet.

## Phase Roadmap

| Phase | Goal | Decisions in phase | State |
|-------|------|--------------------|-------|
| P0 - Content spike + loop prototype | Pick one district, build a small reviewed POI set, and test the embodied unlock loop before mobile investment | PDR-0008; content safety policy; lightweight prototype packet | Current priority |
| P1 - Launch-district v1 | Expand to 50-100 reviewed POIs, wire walk-memory backbone, atlas surface, and paid-pack test | Future ADR only if backend/content/editorial pipeline is accepted for build | Planned |
| P2 - Pipeline + Atlas season | Repeatable district-pack build process, editorial queue, first Yearly Atlas season | Future content-pipeline and print/POD decisions if Phase 1 earns them | Watch |
| P3 - Expansion | Additional districts/cities, trusted-curator suggestions, optional partner packs | Separate decisions required | Watch |

## Dependency Map

| Decision / Work | Status | Depends on | Unblocks | Phase |
|-----------------|--------|------------|----------|-------|
| **PDR-0008** Curiosities direction | Proposed | none | Phase 0 content spike and prototype | P0 |
| **Launch district selection** | needed | PDR-0008 lane activation | source audit, POI review, prototype map bounds | P0 |
| **Content safety + licensing policy** | needed | launch district selection | reviewed POI publishing, prototype data set | P0 |
| **Phase 0 content spike** | needed | launch district selection; safety/licensing rules | viability decision for Phase 1 | P0 |
| **Lightweight unlock-loop prototype** | needed | Phase 0 POI set | embodied-loop test and Phase 1 go/no-go | P0 |
| **Backend/content/editorial ADR** | gated | Phase 0 proves content can be produced | durable content storage and editorial workflow | P1/P2 |

## Child Initiatives

No child initiative exists yet. The first child should be the Phase 0 content spike/prototype packet set if the operator accepts PDR-0008 for active execution.

| Initiative | Governing decision | active-initiatives link | Hive |
|------------|--------------------|-------------------------|------|
| _(none yet)_ | PDR-0008 | - | - |

## Status Rollup

Curiosities is now a first-class lane, but it is still at the **risk-testing** stage. The next work is not app scaffolding. The next work is to choose one dense launch district, assemble about 25 reviewed POIs from open/public sources plus AI-assisted enrichment, record the real per-POI production cost, and prove that question-mark unlocks feel worth leaving the house for. If Phase 0 fails PDR-0008 Kill Criterion 1, the lane should stop before it consumes mobile-build capacity.

**Next action:** scope the Phase 0 content spike, including launch district, source/licensing checklist, safety review rubric, and the minimal prototype surface.
