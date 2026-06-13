# Dispatch Plan — ADR-0041: AI Model Registry and Approval Workflow

**Initiative:** `adr-0041-model-registry`
**ADR:** ADR-0041 (Proposed → Accepted via packet 00)
**Sector:** AI
**Created:** 2026-05-22

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0041 decides the Grid gains a **declarative model registry** (`models.json` inside `HoneyDrunk.AI`, exposed via `IModelRegistry`), an **approval workflow** for adding models (`Preview` → 14-day window → `Approved`), a **capability-canary harness** that asserts declared capabilities against live provider reality, a **cost-aware default routing policy** with a per-call cost ceiling, and an **Audit emit on every dispatch** for forensic attribution.

This initiative delivers: the `IModelRegistry` contract surface and `models.json` loader; the initial model lineup (Anthropic, OpenAI, Azure OpenAI) and the nightly capability canary; the rewire of `DefaultModelRouter` onto the registry plus the cost-aware default policy and per-call ceiling; and the per-dispatch Audit emit plus the per-tenant cost-guard intersection.

**6 packets across 4 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.AI`). 6 `Actor=Agent`, 0 `Actor=Human`. Two packets (03, 05) carry Human Prerequisites (Vault key seeding, App Configuration values, GitHub environment secrets, cost acceptance) — but the *code* work is fully delegable, so they stay `Actor=Agent`.

## Trigger

ADR-0041 is Proposed with no scope. The forcing functions (from the ADR's Context): the AI-sector standup wave (ADR-0016 onward) is in flight and without a registry every standup hardcodes model identifiers and the retrofit becomes a cascade; the ADR-0010 routing reconciliation needs a registry to anchor; a provider outage degrades every dependent Node without a registered fallback. The ADR needs decomposition into actionable packets.

## Scope Detection

**Multi-repo, single-Node implementation.** All implementation lands in **`HoneyDrunk.AI`** — a fully-scaffolded, live Node at v0.1.0 (six provider packages, three test projects, all the routing/cost contracts shipped via ADR-0016 / AI PR #5). `HoneyDrunk.Architecture` carries the governance (acceptance, invariants) and catalog packets — packet 01 edits `catalogs/contracts.json` (the `honeydrunk-ai` block's `interfaces` array) and `catalogs/relationships.json` (the `honeydrunk-ai` entry's `exposes.contracts` array); `catalogs/nodes.json` is not touched (it has no `exposes` field).

**No new-Node scaffolding.** ADR-0041 D1 explicitly rejects a separate `HoneyDrunk.AI.Registry` Node ("Registry as a separate Node ... Rejected at this scale ... read-mostly, tightly coupled to `IRoutingPolicy`"). The registry is `models.json` data + `IModelRegistry` code *inside* the existing live `HoneyDrunk.AI` Node. No empty cataloged repo is touched; no standup ADR is needed.

**No contract cascade to downstream Nodes.** The new contracts (`IModelRegistry`, `ModelRegistration`, etc.) are *additive* to `HoneyDrunk.AI.Abstractions`. Downstream AI-sector Nodes (Agents, Memory, Knowledge, Evals, Sim, Lore) depend on `HoneyDrunk.AI.Abstractions` per invariant 44 — an additive change does not force them to update. They pick the registry up when they next recompose. The `api-compatibility.yml` contract-shape canary (invariant 46) gates the four hot-path abstractions; the new contracts are additions paired with packet 02's version bump, so the canary passes.

## Wave Diagram

> **Invariant numbering.** The true current maximum in `constitution/invariants.md` is invariant 51. ADR-0041's reserved block is invariants **72, 73, 74** — pre-reserved as part of a 12-ADR batch. Packet 00 adds them with those hard numbers. If any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number.

### Wave 1 (No Dependencies — governance + catalog)
- [ ] **00** — Architecture: Accept ADR-0041, add the three AI-registry invariants (72, 73, 74), register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: register the model-registry contract surface and the approval-workflow policy in the Grid catalogs. `Actor=Agent`. Blocked by: 00.

### Wave 2 (Depends on Wave 1 — the registry foundation)
- [ ] **02** — AI: add `IModelRegistry`, the registration records, and the `models.json` loader. `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.AI` (`0.1.0` → `0.2.0`).**

### Wave 3 (Depends on Wave 2 — canary + routing, parallel)
- [ ] **03** — AI: add the capability-canary harness and the initial model lineup. `Actor=Agent`. Blocked by: 02.
- [ ] **04** — AI: rewire `DefaultModelRouter` to the registry, add the cost-aware default policy and per-call ceiling. `Actor=Agent`. Blocked by: 02.

### Wave 4 (Depends on Wave 3 — audit + cost-guard)
- [ ] **05** — AI: emit an Audit entry on every dispatch, wire the per-tenant cost-guard intersection. `Actor=Agent`. Blocked by: 04.

Packets within a wave run in parallel. **Wave-3 packets 03 and 04 are independent of each other** — 03 adds model data + the canary project; 04 rewires the router. They have no logical dependency, but they share the `HoneyDrunk.AI` solution: coordinate the working branch (or land one then rebase the other), and note that both append to the in-progress `[0.2.0]` CHANGELOG entry packet 02 opened. Packet 05 is alone in Wave 4 because it wires into the per-call-rejection seam packet 04 leaves and emits its dispatch Audit entry against the same `IAuditLog` (`HoneyDrunk.Audit.Abstractions`) packet 03 binds the canary-flip emit to.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0041](./00-architecture-adr-0041-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Model-registry catalog + contracts](./01-architecture-model-registry-catalog-and-contracts.md) | Architecture | Agent | 1 | 00 |
| 02 | [Registry contracts + models.json loader](./02-ai-model-registry-contracts-and-loader.md) | AI | Agent | 2 | 00 |
| 03 | [Capability canary harness + model lineup](./03-ai-capability-canary-harness-and-model-lineup.md) | AI | Agent | 3 | 02 |
| 04 | [Cost-aware routing + per-call ceiling](./04-ai-cost-aware-routing-and-per-call-ceiling.md) | AI | Agent | 3 | 02 |
| 05 | [Dispatch Audit emit + cost-guard intersection](./05-ai-dispatch-audit-emit-and-cost-guard-intersection.md) | AI | Agent | 4 | 04 |

## Version Bumps

- **`HoneyDrunk.AI`** — packet 02 is the first packet on the solution; it bumps every non-test `.csproj` to the same new **minor** version `0.1.0` → `0.2.0` (new feature: the registry). Packets 03, 04, 05 append to the in-progress `[0.2.0]` CHANGELOG only (invariant 27). Per-package changelogs are updated only for packages with real changes (`HoneyDrunk.AI.Abstractions`, `HoneyDrunk.AI`) — provider packages bump to align but get no changelog noise.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; catalog/doc/governance edits only.

## Cross-Cutting Concerns

### `HoneyDrunk.Audit` is scaffolded — hard dependency; `HoneyDrunk.Operator` is unscaffolded — local seam

ADR-0041 D5/D6/D10 and its third new invariant require AI dispatch to emit Audit entries (via `HoneyDrunk.Audit`'s `IAuditLog`, ADR-0030) and the per-tenant cost ceiling to intersect with ADR-0018's `ICostGuard` (which lives in `HoneyDrunk.Operator`). The two Nodes are at different maturity, so the strategy differs per Node:

- **`HoneyDrunk.Audit` IS a scaffolded repo** with buildable `HoneyDrunk.Audit.Abstractions` (`IAuditLog`) + `HoneyDrunk.Audit.Data` projects. Packets 03 and 05 take `HoneyDrunk.Audit.Abstractions` as a **HARD dependency** for the Audit emit — `.Abstractions` only, never `HoneyDrunk.Audit.Data` (invariant 48). Verify the package is on the feed at execution time; if it is not yet published, treat that as a **blocker to resolve** (publish it), not a reason to ship a permanent local audit seam. There is no long-lived `IDispatchAuditSink` interface.
- **`HoneyDrunk.Operator` has no `src/` at all** — it is cataloged but unscaffolded, with no publishable `HoneyDrunk.Operator.Abstractions`. Packet 05's per-tenant cost-guard intersection uses a **local `ITenantCostGuard` seam** in `HoneyDrunk.AI.Abstractions`. This local-seam fallback is correct and intended **only for the Operator `ICostGuard` intersection** — reconciling `ITenantCostGuard` with ADR-0018's `ICostGuard` is a follow-up once `HoneyDrunk.Operator` is scaffolded.

This keeps ADR-0041's implementation un-blocked, consistent with invariant 44's principle (AI-sector Nodes proceed on Abstractions alone). The Audit emit is durable from day one; only the Operator cost-guard reconciliation waits on a sibling standup.

### `HoneyDrunk.Observe` provider-health tie-break — deferred seam

ADR-0041 D5's cost-aware policy tie-breaks by provider health, "a live availability signal from D3 canaries, surfaced through `HoneyDrunk.Observe`." `HoneyDrunk.Observe` is a Planned Node at v0.0.0. Packet 04 ships a local `IProviderHealthSignal` seam with an all-healthy default (the tie-break falls through to a deterministic ordinal ordering). The canary-driven health feed and the Observe surfacing are a noted follow-up — they do not block this initiative and do not change routing correctness, only the quality of the tie-break.

### `ModelCapabilityDeclaration` is frozen (ADR-0016)

`ModelRegistration` *composes* the frozen `ModelCapabilityDeclaration` record. No packet in this initiative modifies it. Its current shape is documented inline in packet 02. The `api-compatibility.yml` contract-shape canary (invariant 46) protects it.

### Self-hosted models — slot only, no models

ADR-0041 D2/D9 reserve `ProviderId=local` for future Ollama/vLLM endpoints; no self-hosted models are registered at v1. Packet 02 ships the `local` provider registration; packet 03's lineup deliberately leaves `local` empty. The future "register a self-hosted model" work is a separate standup ADR per ADR-0041's Follow-up Work — not in this initiative.

### Deferred follow-ups (explicitly out of scope)

- `catalogs/ai-models.json` — the optional Grid-wide mirror of `models.json` (ADR-0041 Consequences) — deferred; packet 01 explicitly does not create it.
- The "data-residency-aware routing" policy ADR (ADR-0041 D8 Follow-up) — the registry shape supports it (`DataEgressPolicy`, `RegionPolicy` on `ProviderRegistration`) but the routing implementation is a future ADR.
- `LatencyOptimized` / `QualityOptimized` named policies (ADR-0041 D5) — deferred to future ADRs; packet 04 ships only the cost-aware default and the explicit override seam.
- Self-hosted model standup ADR — when the first local model is introduced.

### Site sync

No site-sync flag. ADR-0041 is internal AI-sector infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; the three invariants and the catalog entries are removed. No runtime impact.
- **Packet 02 (registry foundation):** revert the PR; the `HoneyDrunk.AI` solution version rolls back from `0.2.0` to `0.1.0`. `IModelRegistry` and `models.json` are additive — no consuming Node depends on them at runtime until a host composes them, so the revert is contained to `HoneyDrunk.AI`.
- **Packet 03 (canary + lineup):** revert the PR; the model entries leave `models.json`, the Canaries project and the nightly workflow are removed. No runtime consumer is affected — the canary is a test/CI concern.
- **Packet 04 (routing rewire):** revert the PR; `DefaultModelRouter` returns to the `DeclaredCapabilities` candidate path. Because the registry is additive, the pre-04 router still functions — the revert is a behaviour rollback contained to `HoneyDrunk.AI`.
- **Packet 05 (audit + cost-guard):** revert the PR; the dispatch Audit emit and the per-tenant guard are removed. The router still dispatches; only the forensic-attribution and per-tenant-ceiling behaviour is dropped. The third ADR-0041 invariant is then unmet until re-applied — note this in the revert.
- **Backend escape hatch:** the registry is read-mostly declarative data — a bad `models.json` entry is fixed by a one-line packet flipping the offending model to `Deprecated` (it stays queryable for replay, rejected on new dispatch) rather than a full revert.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
