# ADR-0041: AI Model Registry and Approval Workflow

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** AI

## Context

ADR-0010 (Accepted) established `IModelRouter` and `IRoutingPolicy` in `HoneyDrunk.AI.Abstractions` as Phase 1 of the observation and AI routing decision. ADR-0016 (Accepted) stood up the `HoneyDrunk.AI` Node and froze `ModelCapabilityDeclaration` as the record that describes a model's capabilities to the router. The router decides where a given inference request lands; the policy decides *how* it decides; the capability declaration is the *input* to the policy.

What is missing: a **registry** of which models exist, who provides them, what their declared capabilities are, and a **workflow** for adding new ones safely. Today:

- The Grid has no list of approved providers.
- A new model (OpenAI's latest, Anthropic's latest, a self-hosted variant) can be added by editing a config; nothing validates the capability declaration against reality.
- Cost ceilings per model do not exist; ADR-0018's `ICostGuard` enforces tenant-level cost ceilings but not "this model is too expensive to invoke by default."
- The provider-axis concern (which provider serves a model) and the model-axis concern (which model satisfies a request) are conflated in the absence of a registry.

The forcing functions:

- The AI-sector standup wave (ADR-0016 onward) is in flight; the first scaffold packets (Architecture#72, #73, AI#2) are still open. Without a registry, every standup will hardcode model identifiers and the registry retrofit will be a cascade.
- Per ADR-0010, the AI routing reconciliation is on the active blocker list (HoneyDrunk.AI#1 vs #3 manifest drift). Cleaning up routing without a registry to anchor it leaves the same shape of problem.
- Provider availability is operational reality: a major provider's outage today degrades every dependent Node without a registered fallback model.

This ADR decides the registry shape, who owns it, the approval workflow for new models, the capability-declaration validation step, and how cost guardrails attach to the registry.

## Decision

### D1 — Registry lives in `HoneyDrunk.AI`, declarative

The model registry is a **declarative JSON/YAML catalog** inside `HoneyDrunk.AI`, named `models.json`. It is loaded by the AI Node at startup and exposed via a new interface, `IModelRegistry`, in `HoneyDrunk.AI.Abstractions`:

```
IReadOnlyCollection<ModelRegistration> GetRegistered();
ModelRegistration? GetById(ModelId id);
IReadOnlyCollection<ModelRegistration> GetByCapability(CapabilityPredicate predicate);
```

The registration record (`ModelRegistration`, frozen) carries:

- `ModelId` — opaque stable identifier (e.g., `anthropic.claude-sonnet-4-6`).
- `ProviderId` — references a separate `ProviderRegistration` keyed in the same catalog.
- `ModelCapabilityDeclaration` — the frozen ADR-0016 record.
- `CostProfile` — per-token costs (input/output/cached) plus a `MaxBudgetPerCallUsd` ceiling.
- `ApprovalState` — `Approved` | `Preview` | `Deprecated`. Deprecated models stay queryable for replay but are rejected on new dispatch.
- `RoutingHints` — opaque hints consumed by `IRoutingPolicy` implementations (latency tier, geographic preference, etc.). Not part of `ModelCapabilityDeclaration` because hints are policy-axis, not capability-axis.

Provider registrations carry: provider name, transport (HTTPS endpoint or self-hosted), authentication method (Vault key reference per ADR-0005), default headers, and provider-axis quirks (request shaping, retry semantics).

The registry is **the source of truth**. Routers consume it; policies consume it; canaries consume it. No router instance reaches into raw configuration to find a model.

### D2 — Approved providers (initial list)

The initial approved provider set:

- **Anthropic** — Claude family (Opus, Sonnet, Haiku) via the Anthropic API.
- **OpenAI** — GPT-4 family, GPT-3.5 family, embedding models, via the OpenAI API.
- **Azure OpenAI** — same OpenAI models via Azure OpenAI Service (different provider, different transport, different SLA).
- **Local / self-hosted** — placeholder provider for future Ollama/vLLM-style endpoints; no models registered at v1.

Each provider has a `ProviderId` in the registry. Adding a provider is an **ADR amendment** to this ADR (or a successor); adding a *model* under an approved provider is a packet-level change (D4 below). The asymmetry is deliberate: new providers carry compliance and data-egress decisions (TOS review, data-residency review) that warrant ADR-level discussion; new models within a vetted provider are routine.

### D3 — Capability declaration is asserted by canary, not vouched for

`ModelCapabilityDeclaration` is the record per ADR-0016: what the model claims to support (function calling, vision, streaming, max context, JSON mode, etc.). The risk: a declaration drifts from reality (model deprecated, provider changed defaults, a feature was silently removed).

Policy: every registered model has a **capability canary** in `HoneyDrunk.AI.Tests.Canaries` that asserts each declared capability against a live (cheap) call. The canary:

- Runs nightly per environment (using minimal-cost calls; `MaxBudgetPerCallUsd` per-canary-call is set to `$0.01` ceiling).
- Marks `ApprovalState=Preview` if a canary fails for ≤24 hours.
- Marks `ApprovalState=Deprecated` if a canary fails for ≥7 days.
- Files a packet (per ADR-0008) when a status flip happens.

This is the contract-shape canary pattern (ADR-0016) applied to provider-axis reality rather than Grid-axis interface shape.

### D4 — Adding a model: packet workflow

Adding a new model to an existing approved provider is a packet (per ADR-0008) following this template:

1. The packet adds the `ModelRegistration` entry to `models.json` with `ApprovalState=Preview`.
2. The packet adds the capability canary for the model.
3. CI runs the canary in PR validation; the PR cannot merge until the canary passes.
4. The packet labels the new model as `Preview` for at least 14 days in production.
5. A follow-up packet flips the model to `Approved` after the 14-day window and after at least one Studio-internal consumer is pinned to it.

Removing a model: a packet that flips it to `Deprecated`; no immediate removal. Removal is a separate packet after 60 days at `Deprecated` and after no `IModelRouter` traffic has touched it in 30 days.

### D5 — Routing default: cost-aware with explicit policy overrides

The default `IRoutingPolicy` is **cost-aware with capability matching**: among models satisfying the request's required capabilities, pick the lowest `CostProfile` whose `RoutingHints` match the request's latency tier. Tie-break by provider health (live availability signal from D3 canaries, surfaced through `HoneyDrunk.Observe`).

Consumers may select an explicit policy override per call (`IRoutingPolicy.Override(ModelId)` or a named policy like `LatencyOptimized` or `QualityOptimized`). Overrides are recorded in the Audit emit for the call (per ADR-0030) so cost outliers are attributable.

This is the smallest possible default. Bigger policies (multi-model ensembling, fallback chains, A/B routing) are deferred to future ADRs; they all land downstream of this registry.

### D6 — Cost guard intersection

The `CostProfile.MaxBudgetPerCallUsd` is the **per-call ceiling** enforced by the router; ADR-0018's `ICostGuard` is the **per-tenant period ceiling** enforced upstream. Both are required:

- Per-call: a runaway prompt cannot blow through $X on a single call.
- Per-tenant: a runaway loop cannot blow through $X over a day.

The router checks the per-call ceiling **before** dispatching; the cost-guard layer checks the per-tenant ceiling **before** the router. Both checks emit Audit entries on rejection.

### D7 — Provider credentials and rotation

Provider API keys live in Vault per ADR-0005; the registry references them by Vault path, never inline. Rotation follows ADR-0006 (90-day standard, 24-hour emergency). The router has a hot-reload path for credential rotation that does not require a restart — provider keys are read per-request from the credentials cache, not at startup.

### D8 — Data egress and TOS posture

Each `ProviderRegistration` records:

- `DataEgressPolicy` — does the provider use customer data for training? (`Yes` / `No` / `OptOut`.)
- `RetentionDays` — provider-side retention for prompts/completions.
- `RegionPolicy` — provider-side data location, where relevant.

Tenants whose data-egress requirements are stricter than a provider's policy are routed via `IRoutingPolicy` away from that provider. This is the **data-residency-aware routing** primitive; the implementation lives in a follow-up policy ADR, but the registry shape supports it from day one.

The Anthropic, OpenAI, and Azure OpenAI policies are recorded as of this ADR's date; provider TOS changes are reviewed quarterly.

### D9 — Self-hosted model special case

Self-hosted models (Ollama, vLLM, etc.) register the same way but carry different concerns:

- `ProviderId=local` is reserved.
- Capability canaries run against the local endpoint, same shape.
- `CostProfile` is computed against compute cost, not provider list price — recorded as a flat per-call estimate, refined over time. This is intentionally approximate; the precision matters less than the bound.
- `DataEgressPolicy=None` is implicit.

No self-hosted models are registered at v1. The slot exists so the future ADR is "register these models" rather than "design the self-hosted model story."

### D10 — Registry is read-only at runtime

`models.json` is not edited by the running Grid; it is edited by humans through packets and reloaded on Node restart (or hot-reload via a versioned config-blob in Azure App Configuration per ADR-0005). The `ApprovalState` flips driven by the canary (D3) are the **only** runtime mutations; they go through a constrained `IApprovalStateWriter` interface that:

- Only changes `ApprovalState`.
- Cannot add or remove registrations.
- Records every flip in Audit per ADR-0030.

## Consequences

### Affected Nodes

- **HoneyDrunk.AI** — primary affected Node; gains `IModelRegistry`, `models.json`, the capability canary harness, and the cost-aware default policy.
- **HoneyDrunk.AI.Abstractions** — gains `IModelRegistry`, `ModelRegistration`, `ProviderRegistration`, `CostProfile`, `ApprovalState`, `RoutingHints`, `IApprovalStateWriter`.
- **HoneyDrunk.Operator** (Seed, ADR-0018) — `ICostGuard` becomes the per-tenant upstream check (D6); standup wiring updated.
- **HoneyDrunk.Audit** (Seed, ADR-0030/0031) — third emitter (after Auth and Billing-from-ADR-0037): model approval flips and routing overrides emit audit entries.
- **HoneyDrunk.Vault** — stores provider API keys; rotation per ADR-0006.
- **HoneyDrunk.Architecture** — `catalogs/contracts.json` registers the new AI Abstractions surface; `catalogs/ai-models.json` (optional mirror of `models.json` for cross-Grid discoverability) deferred to a follow-up.

### Invariants

Adds three:

- **Invariant: no AI dispatch happens against an unregistered model.** Hardcoded model identifiers in non-AI Nodes are forbidden; the router rejects them.
- **Invariant: every approved model has a passing capability canary in the last 24 hours.** A model whose canary fails past 24 hours is auto-flipped to `Preview`.
- **Invariant: every AI dispatch emits an Audit entry recording `(TenantId, ModelId, PolicyOverride?, CostUsd, Outcome)`.** Routing decisions are forensically attributable.

### Operational Consequences

- The canary harness incurs nightly provider cost — bounded by per-call $0.01 ceilings, across ~10 models × ~5 capabilities × per-environment runs = under $5/month at v1. Recorded as a known cost.
- Provider API key rotation is now a recurring task per ADR-0006; the registry's hot-reload path is the mitigation.
- Adding a new model is now a multi-step process (packet + canary + 14-day preview). This is friction against undisciplined experimentation; it is the intended friction. Internal experimentation can run against a `dev`-only registry entry without the preview window.
- The cost-aware default policy will sometimes route to a "good enough" cheaper model when the consumer expected the most capable one. Consumers who need a specific model use the policy override (D5) and accept the audit-trail visibility.
- A provider outage (e.g., Anthropic API down) flips affected models' canaries within minutes; cost-aware routing redirects to surviving providers. This is failover-by-default, recorded explicitly so it doesn't surprise consumers.

### Follow-up Work

- Implement `IModelRegistry` and `models.json` in `HoneyDrunk.AI`.
- Implement the capability canary harness.
- Populate `models.json` with the initial provider set (Anthropic, OpenAI, Azure OpenAI) and the current model lineup.
- Wire the cost-aware default policy.
- Wire the Audit emit on dispatch.
- Author the deferred "data-residency-aware routing" policy ADR (downstream of this ADR).
- Author the self-hosted-model standup ADR when the first local model is introduced.

## Alternatives Considered

### Registry inline in `IRoutingPolicy` implementations

Rejected. Smearing model knowledge across multiple policy implementations means a new model is added in N places. The registry is the single source.

### Registry as a separate Node

Considered. A `HoneyDrunk.AI.Registry` Node would sharpen the boundary. Rejected at this scale: the registry is small (dozens to low-hundreds of entries), read-mostly, and tightly coupled to `IRoutingPolicy`. Splitting it adds an inter-Node hop with no offsetting benefit. Revisited if the registry grows beyond a single team-of-one's capacity to maintain.

### No approval states; all registered models are equally valid

Rejected. The Preview/Approved/Deprecated lifecycle is the operational reality of provider-axis model availability; encoding it explicitly is cheaper than handling each case ad-hoc when it arises.

### Capability declarations as static config; no live canary

Rejected. Declarations drift. The canary (D3) is the only mechanism that catches "the provider silently changed something" before a Grid consumer hits the regression.

### Cost ceilings as a per-tenant ICostGuard concern only, not a per-call registry concern

Rejected. Per-tenant ceilings cannot catch single-call cost outliers in time. Per-call ceilings catch them; per-tenant ceilings catch the long tail. Both are needed (D6).

### Defer until after the AI-sector standup wave

Rejected. The standup wave consumes `IModelRouter` and `IRoutingPolicy` as Abstractions-level surfaces (ADR-0016 frozen contracts). The registry shape affects what those surfaces hand to consumers; deferring it forces a retrofit on every standup canary.
