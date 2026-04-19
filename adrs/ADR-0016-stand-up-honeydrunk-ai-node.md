# ADR-0016: Stand Up the HoneyDrunk.AI Node — Inference Substrate for the AI Sector

**Status:** Proposed
**Date:** 2026-04-19
**Deciders:** HoneyDrunk Studios
**Sector:** AI

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Add entries to `catalogs/contracts.json` for the seven exposed contracts: `IChatClient`, `IEmbeddingGenerator`, `IInferenceResult`, `IModelProvider`, `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`
- [ ] Add `honeydrunk-ai` Node entry and per-contract entries to `catalogs/grid-health.json`
- [ ] Tighten loose "depends on Pulse" phrasing in `catalogs/nodes.json` (HoneyDrunk.AI entry) and `constitution/ai-sector-architecture.md` (~line 114) to "emits telemetry consumed by Pulse; no runtime dependency"
- [ ] Wire the contract-shape canary into Actions (freezes `IChatClient`, `IEmbeddingGenerator`, `IInferenceResult`, `IModelProvider` shapes)
- [ ] File the HoneyDrunk.AI scaffold packet (repo bootstrap, solution structure, HoneyDrunk.Standards wiring, CI pipeline, InMemory provider)
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

`HoneyDrunk.AI` is cataloged in `catalogs/nodes.json` and carries a working tree on disk, but the repo is empty — no packages, no contracts, no providers, no CI. Every other Node in the AI sector (Capabilities, Operator, Agents, Memory, Knowledge, Evals) is currently blocked on AI because every one of them consumes inference at some point, and none of them can compile against a Node that does not yet expose stable abstractions.

ADR-0010 already committed to two things that live inside AI but were never stood up:

- `IModelProvider` — provider-slot abstraction for inference backends (OpenAI, Anthropic, Azure OpenAI, local).
- `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration` — capability-driven routing with policies sourced from App Configuration per ADR-0005.

Outside routing, the AI sector also needs a small number of cross-cutting primitives that have no natural home in any other Node: cost accounting, provider health surfacing, and the canonical chat/embedding request shape that every downstream consumer compiles against. Without these landing in one place, each dependent Node either invents its own or waits.

This ADR is the **stand-up decision** for the AI Node — what it owns, what it does not own, which contracts it exposes, and how downstream Nodes couple to it. It is not a scaffolding packet. Filing the repo, adding CI, wiring an InMemory provider, and producing the first shippable packages all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.AI is the AI sector's inference substrate

`HoneyDrunk.AI` is the single Node in the AI sector that owns **inference primitives** — the contracts, routing, cost accounting, and provider slot that every other AI-sector Node compiles against. It is a shared substrate, not an orchestrator. It does not decide *what* to think about; it owns the mechanics of *how* a thought is executed against a model.

### D2. Package families

The AI Node ships the following package families, mirroring the provider-slot shape used by Vault and Transport:

- `HoneyDrunk.AI.Abstractions` — all interfaces, request/response shapes, capability declarations, cost records. Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions.
- `HoneyDrunk.AI` — runtime composition: default `IModelRouter`, default `ICostLedger`, DI wiring, policy loader.
- `HoneyDrunk.AI.Providers.*` — provider-slot packages, one per inference backend. First-wave slot names (contents filed by later packets):
  - `HoneyDrunk.AI.Providers.OpenAI`
  - `HoneyDrunk.AI.Providers.Anthropic`
  - `HoneyDrunk.AI.Providers.AzureOpenAI`
  - `HoneyDrunk.AI.Providers.InMemory` — deterministic test double, no network, for Evals and CI.

### D3. Exposed contracts

Seven contracts form the AI Node's public boundary. These are the surfaces downstream Nodes are allowed to compile against:

| Contract | Kind | Purpose |
|---|---|---|
| `IChatClient` | interface | Canonical chat completion entry point. |
| `IEmbeddingGenerator` | interface | Canonical embedding entry point. |
| `IModelProvider` | provider slot | Inference backend adapter (ADR-0010). |
| `IModelRouter` | interface | Capability-driven model selection (ADR-0010). |
| `IRoutingPolicy` | interface | Pluggable routing strategy — cost-first, capability-first, latency-first, compliance-first (ADR-0010). |
| `ModelCapabilityDeclaration` | record | Machine-readable model capability metadata (ADR-0010). |
| `ICostLedger` | interface | Per-call token and cost accounting surface. |

`IChatClient` and `IEmbeddingGenerator` are **shape-compatible but distinct** from `Microsoft.Extensions.AI`'s same-named abstractions. See D6.

Records drop the `I` prefix; interfaces retain it. `ModelCapabilityDeclaration` is a record. The other six contracts listed above are interfaces.

### D4. Routing is in-scope for AI, governed by ADR-0010

Model routing lives inside `HoneyDrunk.AI`, not in a separate Node, as already committed in ADR-0010. This ADR does not re-open that decision — it records the fact that the router ships in the AI Node's first package wave and is a first-class exposed contract.

### D5. Routing policy source — App Configuration via Vault

Routing policies, cost-rate tables, and capability declarations all live in **Azure App Configuration** and are read through `IConfigProvider` from the Vault Node per ADR-0005. No policies or rate tables are hardcoded in application code. Rate-table refresh is operator-driven — change the config value, restart or hot-reload, no deploy required.

This applies in particular to the cost-rate table consumed by `ICostLedger`: token prices per model are operator-configurable, not compiled constants.

### D6. Relationship to `Microsoft.Extensions.AI`

`HoneyDrunk.AI.Abstractions` declares its own `IChatClient` and `IEmbeddingGenerator` with **shape compatibility** with `Microsoft.Extensions.AI`'s counterparts — same method signatures and argument shapes where practical — but they are **distinct types** under the `HoneyDrunk.AI.Abstractions` namespace. This preserves the Grid's control over the contract surface (versioning, capability extensions, telemetry hooks) while keeping a short glide path to interop.

A thin wrapper layer that adapts between the two is **deferred to Q3 2026**. It is not part of this stand-up and not part of the first useful increment. When filed, it lands as an optional `HoneyDrunk.AI.Interop.MEAI` package; downstream Nodes continue to compile only against `HoneyDrunk.AI.Abstractions`.

### D7. Telemetry emission — Pulse consumes, AI does not depend

AI emits telemetry for every inference call via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **AI has no runtime dependency on Pulse.** The direction is one-way by contract: AI emits, Pulse observes.

The Consequences section below flags existing doc-drift in `catalogs/nodes.json` and `architecture/ai-sector-architecture.md` that describes AI as "depends on Pulse" — that phrasing is wrong and needs tightening in a follow-up packet, but is not fixed in this ADR.

### D8. Contract-shape canary

A fifth canary is added to the AI Node's CI: a **contract-shape canary** that fails the build if any of the following four abstractions change shape (method signatures, parameter shapes, record members) without a corresponding version bump:

- `IChatClient`
- `IEmbeddingGenerator`
- `IModelProvider`
- `IModelRouter`

These four are the hot path for every downstream consumer. Accidental shape drift on any of them breaks every AI-sector Node simultaneously. The canary makes this a compile-time failure at AI's own CI, not a discovery at consumer sites.

The four existing canaries (build, test, provider-contract, security scan) remain. Contract-shape is additive.

### D9. Downstream coupling rule

Downstream AI-sector Nodes (Capabilities, Operator, Agents, Memory, Knowledge, Evals) compile **only** against `HoneyDrunk.AI.Abstractions`. They do not take a runtime dependency on `HoneyDrunk.AI` or any `HoneyDrunk.AI.Providers.*` package. Composition — which provider is active, which router policy is in force — is a host-time concern, resolved at application startup from App Configuration.

This is the same abstraction/runtime split already applied for Vault and Transport. It is re-stated here because it is the specific rule that allows the six blocked Nodes to proceed on `Abstractions` alone without waiting for provider packages.

## Consequences

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet that produces a first `Abstractions` release — unblocks every Node currently waiting on AI:

- **HoneyDrunk.Capabilities** — can declare capability surfaces against `ModelCapabilityDeclaration`.
- **HoneyDrunk.Operator** — can wire safety controls around `IChatClient` calls.
- **HoneyDrunk.Agents** — can compile against the canonical chat/embedding contracts.
- **HoneyDrunk.Memory** — can use `IEmbeddingGenerator` for vector recall paths.
- **HoneyDrunk.Knowledge** — same, for retrieval embedding.
- **HoneyDrunk.Evals** — can target `IModelProvider` and the `InMemory` provider as its deterministic fixture.

### New invariants (proposed for `constitution/invariants.md`)

These extend the AI-related invariants already proposed in ADR-0010 (28 on hardcoded model names). Numbering is tentative — scope agent finalizes at acceptance.

- **Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`.** Composition against `HoneyDrunk.AI` and any provider package is a host-time concern. See ADR-0016 D9.
- **Token cost rates, routing policies, and capability declarations are sourced from Azure App Configuration via Vault's `IConfigProvider`.** Hardcoded rates or policies in application code are forbidden. See ADR-0016 D5.
- **The AI Node CI must include a contract-shape canary for `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, and `IModelRouter`.** Shape drift on any of the four is a build failure, not a downstream discovery. See ADR-0016 D8.

### Contract-shape canary becomes a requirement

The contract-shape canary in D8 is a gating requirement on the AI Node's CI from the first scaffold. It is not a later hardening pass — the four frozen abstractions (`IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `IModelRouter`) are the hot path, and they must be protected from day one.

### Negative

- The provider-slot pattern in AI means a misconfigured routing policy could route every call to an expensive provider. Mitigation is the same path ADR-0010 already defined — startup validation of policy, cost monitoring through Pulse, and Operator-side safety controls.
- Declaring `IChatClient` / `IEmbeddingGenerator` as distinct from `Microsoft.Extensions.AI`'s same-named types adds a small cost of a future interop wrapper. That cost is paid in Q3 2026 per D6, not now.
- The contract-shape canary will occasionally flag intentional breaking changes; the expected workflow is a deliberate version bump, not bypassing the check.

## Alternatives Considered

### Split routing into a separate Node

Rejected. ADR-0010 already decided routing lives in AI. A standalone routing Node would create a second trust boundary in the inference hot path with no corresponding isolation benefit — routing reads the same App Configuration, runs in-process with the provider call, and has no independent deployment shape. Re-litigating this belongs in a later ADR if and when a reason emerges.

### Use `Microsoft.Extensions.AI` contracts directly (no HoneyDrunk-owned abstractions)

Rejected. Taking MEAI directly surrenders versioning control on the hottest contract surface in the Grid. Capability declarations, telemetry hooks, and cost accounting are things the Grid needs to evolve on its own cadence. Shape compatibility (D6) keeps the glide path short without ceding the boundary.

### Source rate tables and policies from code, not App Configuration

Rejected. Baking token prices, policy choices, or capability declarations into compiled code makes every rate change a redeploy. App Configuration was the chosen config boundary in ADR-0005 exactly so operator changes do not require ship events.

### Defer the AI stand-up and let each downstream Node define its own inference abstractions

Rejected. This is the current state, and it is the reason six Nodes are blocked. Each Node inventing its own `IChatClient` produces N incompatible contracts, duplicated provider glue, no shared cost accounting, and no place to land routing policy. The AI sector needs a shared substrate before its member Nodes can proceed.
