---
name: Operator Durable State + Atomic Cost Enforcement (D12)
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Operator
labels: ["feature", "tier-2", "ai", "operator", "data", "adr-0018", "safety", "concurrency", "follow-up"]
dependencies: ["packet:03"]
adrs: ["ADR-0018"]
wave: 4
initiative: adr-0018-operator-standup
node: honeydrunk-operator
gates: ai-sector-enforcement-adoption
---

# Feature: Durable approval/cost state + atomic cost enforcement via HoneyDrunk.Data (ADR-0018 D12)

## Summary

v0.1.0 accumulates approval and cost state **in process** (`ConcurrentDictionary`), with durable persistence carried as `TODO(data)` under *Deferred*. Two consequences are intentional v0.1.0 limitations and were flagged by the ADR-0086 Grid review verdict on Operator #13:

1. **State loss on restart** — pending approvals and accumulated spend do not survive a process restart.
2. **Non-atomic cost enforcement** — `ICostGuard` splits `CheckBudgetAsync` and `RecordAsync` across two calls (documented in `DefaultCostGuard` remarks), so concurrent callers can collectively exceed a hard cap.

This packet backs both with HoneyDrunk.Data's repository/unit-of-work surface (ADR-0018 D12) and makes hard cost enforcement atomic/transactional. **Must land before any AI-sector Node relies on Operator for hard budget caps or durable approvals.**

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Operator`

## Motivation

Operator is a safety/cost substrate; both failure modes above defeat its purpose under real load. A hard budget cap that can be overrun by parallel agents is not a cap; a pending approval that vanishes on restart is an evidence/continuity gap. ADR-0018 D12 designates HoneyDrunk.Data as the persistence edge.

## Proposed Implementation

- Take a runtime dependency on HoneyDrunk.Data's `IRepository` / `IUnitOfWork` abstractions (consume contracts; do not redefine — invariant 1).
- **Cost:** replace the in-process accumulator in `DefaultCostGuard` with a Data-backed store, and add an atomic reserve-or-deny path so check-and-record is a single transactional operation (e.g. conditional increment that fails when it would exceed the limit). Keep the existing `ICostGuard` shape if possible; if an atomic `TryReserveAsync` is needed, evolve the Abstractions contract under its own minor version and the API-compatibility canary.
- **Approval:** persist pending approvals and decisions (and expiry) in `DefaultApprovalGate` via Data; the expiry aging from v0.1.0 continues to work against the injected `TimeProvider`.
- Keep the `Testing` fixtures in-memory (no Data dependency) so downstream Nodes can compose Operator without a real store.

## Acceptance Criteria

- Concurrency test: N parallel reservations against a hard cap admit spend up to the cap and deny the remainder — total recorded spend never exceeds the limit.
- Pending approvals and accumulated spend survive a simulated process restart (state re-read from Data).
- Reported remaining budget stays clamped at zero at/over the cap (parity with v0.1.0 behavior already covered).
- `TODO(data)` removed from `DefaultCostGuard` / `DefaultApprovalGate`; CHANGELOG *Deferred* entries resolved; any contract change recorded in `catalogs/contracts.json`.

## Notes

- Atomic cost enforcement is **subsumed by** the durable transactional backing — it does not have a separate in-memory implementation; this is why v0.1.0 documented it as a limitation rather than shipping a partial fix.
- Depends on HoneyDrunk.Data's repository abstraction being published and on the Operator persistence schema. File the dependency edge in `catalogs/relationships.json`.
