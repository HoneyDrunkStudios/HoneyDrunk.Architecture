---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "adr-0041", "wave-3"]
dependencies: ["packet:02"]
adrs: ["ADR-0041"]
accepts: ["ADR-0041"]
wave: 3
initiative: adr-0041-model-registry
node: honeydrunk-ai
---

# Rewire DefaultModelRouter to the registry and add the cost-aware default policy with per-call ceiling

## Summary
Rewire `DefaultModelRouter` to build candidates from `IModelRegistry` instead of iterating `IModelProvider.DeclaredCapabilities` directly; make the registry the source of truth for routing. Add the cost-aware default `IRoutingPolicy` (cost + capability matching + provider-health tie-break), enforce the `CostProfile.MaxBudgetPerCallUsd` per-call ceiling before dispatch, exclude `Deprecated` models from new dispatch, and add the explicit per-call policy override.

## Context
ADR-0041 D5 decides the default `IRoutingPolicy` is cost-aware with capability matching: among models satisfying the request's required capabilities, pick the lowest `CostProfile` whose `RoutingHints` match the request's latency tier, tie-broken by provider health. Consumers may select an explicit policy override per call. D6 decides `CostProfile.MaxBudgetPerCallUsd` is the per-call ceiling enforced by the router before dispatch. D1 decides the router consumes the registry — "no router instance reaches into raw configuration to find a model."

Today `DefaultModelRouter.RouteAsync` (in `src/HoneyDrunk.AI/Routing/DefaultModelRouter.cs`) builds candidates by `providers.SelectMany(p => p.DeclaredCapabilities...)` — it has no notion of a registry, approval state, or per-model cost ceiling. The existing `CostFirstRoutingPolicy` picks the lowest blended cost but does not consider `RoutingHints` latency tier or provider health. This packet makes the registry the routing source of truth.

Packet 02 shipped `IModelRegistry` and the records. This packet rewires the router and adds the policy. It lands on `HoneyDrunk.AI` after packet 02 — it **appends to the in-progress `[0.2.0]` CHANGELOG entry** and does NOT bump the version again (invariant 27).

This packet shares the `HoneyDrunk.AI` solution with packet 03 — coordinate the working branch with whoever runs 03 (they touch different seams: 03 adds canaries + model data, 04 rewires the router; they have no logical dependency but share the solution).

## Scope
- `src/HoneyDrunk.AI/Routing/DefaultModelRouter.cs` — rewire candidate construction to `IModelRegistry`.
- `src/HoneyDrunk.AI/Routing/` — new `CostAwareRoutingPolicy.cs` (the D5 default) and `PinnedModelRoutingPolicy.cs` (the per-call override); keep `CostFirstRoutingPolicy` (it can become the named `cost-first` policy or be folded into the new one — see Constraints).
- `src/HoneyDrunk.AI/Routing/` — provider-health signal seam for the tie-break.

`IRoutingPolicy` needs no shape change — its confirmed shape (`PolicyName` + `Choose(IReadOnlyList<ModelCandidate>, ChatRequestSummary)` returning `RoutingDecision`) already accommodates both new policies as plain implementations. This packet does not touch `src/HoneyDrunk.AI.Abstractions/IRoutingPolicy.cs`.
- `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs` — register the cost-aware policy as the default.
- `tests/HoneyDrunk.AI.Tests/` — routing and per-call-ceiling tests.
- CHANGELOG append (no version bump).

## Proposed Implementation

### Rewire `DefaultModelRouter`
- Inject `IModelRegistry`. Build candidates from `registry.GetRegistered()` rather than from `IModelProvider.DeclaredCapabilities`.
- **Exclude `ApprovalState.Deprecated` models from new dispatch** (D1 — "Deprecated models stay queryable for replay but are rejected on new dispatch"). `Preview` and `Approved` models are dispatch-eligible; `Deprecated` are filtered out.
- Keep the existing capability filtering (`MaxContextTokens` fit, required-capability match) — move it to operate over `ModelRegistration` instead of bare `ModelCapabilityDeclaration`.
- After the policy chooses a candidate, **enforce the per-call ceiling**: estimate the call cost from the chosen model's `CostProfile` and the `ChatRequestSummary` token estimate; if the estimate exceeds `CostProfile.MaxBudgetPerCallUsd`, reject the dispatch with a clear exception. ADR-0041 D6: "the router checks the per-call ceiling before dispatching." A rejection emits an Audit entry — that emit is packet 05's concern; this packet leaves a clear seam (`IDispatchCostGuard` or similar) or a callback so packet 05 wires the Audit emit without re-touching the router internals.

### Cost-aware default policy
- New `CostAwareRoutingPolicy : IRoutingPolicy`, `PolicyName = "cost-aware"`. D5 algorithm:
  1. Filter candidates to those satisfying the request's required capabilities (the router already does capability filtering — the policy receives a pre-filtered candidate list, consistent with the current `IRoutingPolicy.Choose(IReadOnlyList<ModelCandidate>, ChatRequestSummary)` contract).
  2. Among them, prefer candidates whose `RoutingHints` latency tier matches the request's latency tier.
  3. Pick the lowest `CostProfile` (blended cost).
  4. Tie-break by provider health — a live availability signal sourced from the D3 canaries, surfaced through `HoneyDrunk.Observe` (see provider-health seam below).
- This becomes the **default** policy registered in `AddHoneyDrunkAI`.
- ADR-0041 D5 also names `LatencyOptimized` and `QualityOptimized` as example named policies and the per-call `IRoutingPolicy.Override(ModelId)`. **v1 scope: ship the cost-aware default and the explicit `ModelId` override path. `LatencyOptimized`/`QualityOptimized` as fully-built named policies are NOT required at v1** — ADR-0041 D5 says "bigger policies are deferred to future ADRs." Provide the override seam; do not build the extra named policies.

### Explicit per-call override
- ADR-0041 D5: "Consumers may select an explicit policy override per call." Implement this as a `PinnedModelRoutingPolicy : IRoutingPolicy` — given a `ModelId`, it selects exactly that registered model (and fails if it is unregistered or `Deprecated`). The confirmed `IRoutingPolicy` shape (`PolicyName` + `Choose(IReadOnlyList<ModelCandidate>, ChatRequestSummary)` returning `RoutingDecision`) needs **no change** to support this — `PinnedModelRoutingPolicy` is a plain implementation, and `RouteAsync` already takes an `IRoutingPolicy` parameter. A consumer constructs `PinnedModelRoutingPolicy` and passes it to `RouteAsync`. Provide a static factory (e.g. `RoutingPolicies.Pinned(ModelId)`). This is a committed decision — implement `PinnedModelRoutingPolicy` against the existing `IRoutingPolicy`; do not extend or modify the interface.
- An override must be visible for audit attribution — the `RoutingDecision.Reason` should record that an override was used, and packet 05's Audit emit reads it. Ensure the routed result carries enough to populate `PolicyOverride?` in packet 05's audit entry.

### Provider-health tie-break seam
- The tie-break needs a provider-health signal (D5: "live availability signal from D3 canaries, surfaced through `HoneyDrunk.Observe`"). `HoneyDrunk.Observe` is a Planned Node at v0.0.0 — do NOT take a runtime dependency on it. Ship an `IProviderHealthSignal` seam in `HoneyDrunk.AI` with a default implementation that reports all providers healthy (a no-op tie-break that falls through to provider-id ordinal ordering, matching the current `CostFirstRoutingPolicy` deterministic tie-break). The canary-driven health feed (packet 03's canary results) and the Observe surfacing are a follow-up — note it. This keeps the policy correct and deterministic at v1 without blocking on Observe.

### Version
- Packet 02 bumped the solution to `0.2.0`. This packet **appends to the in-progress `[0.2.0]` entry** — no new version section (invariant 27).
- Update `HoneyDrunk.AI/README.md` if the routing public surface description changes.

## Affected Files
- `src/HoneyDrunk.AI/Routing/DefaultModelRouter.cs`
- `src/HoneyDrunk.AI/Routing/CostAwareRoutingPolicy.cs`, `PinnedModelRoutingPolicy.cs`, `RoutingPolicies.cs` (new)
- `src/HoneyDrunk.AI/Routing/IProviderHealthSignal.cs` + default implementation (new)
- `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs`
- `src/HoneyDrunk.AI/CHANGELOG.md` (append to `[0.2.0]`), repo-level `CHANGELOG.md` (append)
- `src/HoneyDrunk.AI/README.md` (if the routing surface description changes)
- `tests/HoneyDrunk.AI.Tests/` — routing tests

## NuGet Dependencies
No new `PackageReference` expected — all work is within existing `HoneyDrunk.AI` and `HoneyDrunk.AI.Abstractions` projects, against types shipped by packet 02. No new project is created; `IRoutingPolicy` is not modified. If against expectation a new project is created, it must reference `HoneyDrunk.Standards` (`PrivateAssets: all`).

## Boundary Check
- [x] All code in `HoneyDrunk.AI`. AI-sector routing work maps to the AI Node.
- [x] No runtime dependency on `HoneyDrunk.Observe` (Planned, v0.0.0) — the provider-health tie-break uses a local `IProviderHealthSignal` seam.
- [x] `IRoutingPolicy` is not modified — `PinnedModelRoutingPolicy` and `CostAwareRoutingPolicy` are plain implementations of the existing interface; no Abstractions shape change.

## Acceptance Criteria
- [ ] `DefaultModelRouter` builds candidates from `IModelRegistry`, not from `IModelProvider.DeclaredCapabilities` directly
- [ ] `Deprecated` models are excluded from new dispatch; `Preview` and `Approved` models remain dispatch-eligible
- [ ] The router enforces the `CostProfile.MaxBudgetPerCallUsd` per-call ceiling before dispatch and rejects an over-ceiling call with a clear exception, leaving a seam for packet 05's Audit emit on rejection
- [ ] `CostAwareRoutingPolicy` exists, is the registered default, and implements the D5 algorithm (capability match → latency-tier preference → lowest cost → provider-health tie-break)
- [ ] `PinnedModelRoutingPolicy : IRoutingPolicy` exists (plus a `RoutingPolicies.Pinned(ModelId)` factory), implemented against the existing unchanged `IRoutingPolicy`; it selects a specific registered `ModelId`, fails on an unregistered or `Deprecated` id, and the override is recorded in the routing decision for audit attribution
- [ ] Provider-health tie-break uses a local `IProviderHealthSignal` seam with an all-healthy default — no runtime dependency on `HoneyDrunk.Observe`
- [ ] Routing is deterministic — tie-breaks fall through to a stable ordinal ordering
- [ ] Unit tests cover: registry-sourced candidates, `Deprecated` exclusion, per-call ceiling rejection, cost-aware selection, latency-tier preference, the pinned override, and a deterministic tie-break; no `Thread.Sleep` (invariant 51)
- [ ] No version bump — repo-level and `HoneyDrunk.AI` per-package CHANGELOGs append to the in-progress `[0.2.0]` entry
- [ ] `HoneyDrunk.AI/README.md` updated if the routing surface description changed
- [ ] Solution builds; `pr.yml` tier-1 gate passes; the `api-compatibility.yml` contract-shape canary passes — `IRoutingPolicy` is unchanged, so the canary sees no shape delta on it

## Human Prerequisites
None. This packet rewires routing logic against contracts shipped by packet 02; no portal or manual action is required. (The provider keys remain a prerequisite for *live* dispatch, but they were covered by packets 02/03 — this packet's tests use the InMemory provider and the registry, no live calls.)

## Referenced ADR Decisions
**ADR-0041 D1 — Registry is the source of truth.** Routers consume the registry; no router instance reaches into raw configuration to find a model. `Deprecated` models stay queryable for replay but are rejected on new dispatch.

**ADR-0041 D5 — Routing default: cost-aware with explicit policy overrides.** The default `IRoutingPolicy` is cost-aware with capability matching: among models satisfying required capabilities, pick the lowest `CostProfile` whose `RoutingHints` match the request's latency tier; tie-break by provider health (live signal from D3 canaries, surfaced through `HoneyDrunk.Observe`). Consumers may select an explicit per-call override (`IRoutingPolicy.Override(ModelId)` or a named policy). Bigger policies (ensembling, fallback chains, A/B routing) are deferred to future ADRs.

**ADR-0041 D6 — Cost guard intersection.** `CostProfile.MaxBudgetPerCallUsd` is the per-call ceiling enforced by the router before dispatch — a runaway prompt cannot blow through $X on a single call. (ADR-0018's `ICostGuard` is the per-tenant period ceiling enforced upstream — that intersection is packet 05.)

**Invariant 28 (AI).** Application code must never hardcode a model name or provider; all model selection goes through `IModelRouter`. Routing policies are operator-configurable. The override path does not violate this — the consumer passes a `ModelId` that must be registered; an unregistered id is rejected.

## Constraints
- **Registry is the routing source of truth (D1).** The router must build candidates from `IModelRegistry`. Do not leave the old `IModelProvider.DeclaredCapabilities` candidate path as a parallel route.
- **`IRoutingPolicy` is not modified.** Its confirmed shape — `PolicyName` plus `Choose(IReadOnlyList<ModelCandidate>, ChatRequestSummary)` returning `RoutingDecision` — already accommodates `PinnedModelRoutingPolicy` and `CostAwareRoutingPolicy` as plain implementations. The override path is a new policy implementation (`PinnedModelRoutingPolicy`), not a new method on `IRoutingPolicy` — `RouteAsync` already accepts an `IRoutingPolicy`. Do not touch the interface.
- **No runtime dependency on `HoneyDrunk.Observe`.** It is a Planned Node at v0.0.0. The provider-health tie-break uses a local seam; the Observe-surfaced health feed is a follow-up.
- **Deterministic routing.** Tie-breaks must be stable (ordinal ordering) so tests and replay are reproducible — match the existing `CostFirstRoutingPolicy` `ThenBy(ProviderId, StringComparer.Ordinal).ThenBy(ModelId, StringComparer.Ordinal)` discipline.
- **No version bump (invariant 27).** Packet 02 is the bumping packet; this packet appends to `[0.2.0]`.
- **`LatencyOptimized`/`QualityOptimized` are out of v1 scope.** Ship the cost-aware default and the override seam only; ADR-0041 D5 defers bigger policies to future ADRs.
- **Per-call ceiling rejection leaves an Audit seam.** Do not inline the Audit emit — packet 05 wires it. Leave a clean callback/seam.

## Labels
`feature`, `tier-2`, `ai`, `adr-0041`, `wave-3`

## Agent Handoff

**Objective:** Make the registry the routing source of truth and add the cost-aware default policy with the per-call cost ceiling.

**Target:** `HoneyDrunk.AI`, branch from `main`.

**Context:**
- Goal: Route inference requests cost-aware against the registered model set, with a per-call cost ceiling and an explicit override path.
- Feature: ADR-0041 AI Model Registry and Approval Workflow rollout, Wave 3.
- ADRs: ADR-0041 D1/D5/D6 (primary), ADR-0016 (frozen abstractions), ADR-0018 (`ICostGuard` is per-tenant — out of this packet's scope, see packet 05).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — hard. `IModelRegistry`, `ModelRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints` must exist.
- Shares the `HoneyDrunk.AI` solution with packet 03 — coordinate the working branch; no logical dependency.

**Constraints:**
- Router builds candidates from `IModelRegistry`; no parallel `DeclaredCapabilities` path.
- `IRoutingPolicy` is not modified — the override is `PinnedModelRoutingPolicy`, a plain implementation of the existing interface.
- No runtime dependency on `HoneyDrunk.Observe` — local `IProviderHealthSignal` seam.
- Deterministic tie-breaks.
- No version bump — append to `[0.2.0]`.
- Per-call ceiling rejection leaves a clean Audit seam for packet 05.

**Key Files:**
- `src/HoneyDrunk.AI/Routing/DefaultModelRouter.cs`
- `src/HoneyDrunk.AI/Routing/CostAwareRoutingPolicy.cs` (new), `PinnedModelRoutingPolicy.cs` (new)
- `src/HoneyDrunk.AI/Routing/IProviderHealthSignal.cs` (new)
- `src/HoneyDrunk.AI/ServiceCollectionExtensions.cs`

**Contracts:**
- Consumes `IModelRegistry`, `ModelRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints` from packet 02.
- `IRoutingPolicy` — not modified; `CostAwareRoutingPolicy` and `PinnedModelRoutingPolicy` are new implementations of the existing interface.
- `IModelRouter` — no shape change; behaviour change only.
