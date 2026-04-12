# ADR-0010: Observation Layer and AI Routing — HoneyDrunk.Observe and IModelRouter

**Status:** Proposed
**Date:** 2026-04-12
**Deciders:** HoneyDrunk Studios
**Sector:** Meta
**Follows from:** PDR-0001 (HoneyHub Platform — Observation and AI Routing layers)

## Open Questions (blocking acceptance)

Before this ADR can be accepted, the following must be resolved:

1. **Observe vs Pulse boundary** — Is `HoneyDrunk.Observe` a genuinely separate Node, or should external-system connectors live under Pulse? Pulse currently owns the internal telemetry pipeline (Grid → external sinks). Observe would own external system ingestion (external → Grid awareness). The directions are opposite and the contracts are different, but the question of whether that justifies a separate repo family for a solo developer is open. If folded into Pulse, this ADR's Node definitions change significantly.

2. **Sector assignment** — ADR-0010 places Observe in **Meta**; PDR-0001 originally placed it in **Ops**. This reassignment is intentional but should be confirmed before catalog entries are written.

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Add `honeydrunk-observe` and `honeydrunk-observe-connectors` to `catalogs/nodes.json` with full metadata
- [ ] Add entries to `catalogs/relationships.json` (consumed_by, exposes.contracts, consumes_detail)
- [ ] Add contract stubs for `IObservationTarget`, `IObservationConnector`, `IObservationEvent` to `catalogs/contracts.json`
- [ ] Add `honeydrunk-observe` and `honeydrunk-observe-connectors` to `catalogs/grid-health.json` (currently has stubs that should be removed until acceptance)
- [ ] Create `repos/HoneyDrunk.Observe/` and `repos/HoneyDrunk.Observe.Connectors/` context folders (overview, boundaries, invariants, active-work, integration-points)
- [ ] Update `constitution/sectors.md` Node table for whichever sector is confirmed (Meta or Ops)
- [ ] Update ADR index (ADRs/README.md) status from Proposed → Accepted
- [ ] Update `constitution/invariants.md` to add invariants 28–30 (currently added speculatively — revert if ADR is not accepted)

## Context

PDR-0001 introduced two new layers in the HoneyDrunk platform vision:

1. **Observation Layer** — External project visibility via `HoneyDrunk.Observe` and `HoneyDrunk.Observe.Connectors`. This allows the Grid to connect to and monitor external projects (non-HoneyDrunk repos, third-party services, customer codebases) the way Pulse monitors internal Nodes.

2. **AI Routing Layer** — Policy-driven model routing in `HoneyDrunk.AI`. This allows agents and applications to select models based on capability requirements, cost constraints, and context rather than hardcoded provider choices.

Both layers were accepted as part of PDR-0001 but were never translated into concrete architectural decisions, ADRs, or work packets. They exist only as principles. This ADR makes them architectural commitments with defined boundaries, so agents can reason about them and work can be scoped.

This ADR does **not** design the full implementation — that belongs in issue packets. It establishes: what each layer owns, what it does not own, its relationship to existing Nodes, and how bring-up will be phased.

## Decision

### Layer 1: Observation Layer

**Purpose:** Allow the Grid to monitor external projects — any codebase or service outside HoneyDrunk — with the same telemetry and health visibility that Pulse provides for internal Nodes.

**New Node: `HoneyDrunk.Observe`**

This is a new Node in the **Meta sector**. Its job is to define the contracts and runtime for observing external systems.

**Owns:**
- Observation context — what it means to "observe" an external project (connection info, health, event subscription)
- Observation contracts — `IObservationTarget`, `IObservationConnector`, `IObservationEvent`
- Event normalization — convert external events (GitHub webhooks, deployment notifications, error alerts) into a canonical Grid-compatible format
- Observation state — track whether an external project is healthy, degraded, or unreachable

**Does NOT own:**
- Connector implementations (that's HoneyDrunk.Observe.Connectors)
- Telemetry routing (that's Pulse)
- Plan adjustments based on observations (that's HoneyHub, when live)
- Internal Grid telemetry (that stays in Pulse)

**New Node: `HoneyDrunk.Observe.Connectors`**

This is a provider-slot package family (same pattern as Vault providers, Transport adapters). Each connector targets a specific external system.

**Owns:**
- Connector implementations for external systems:
  - `HoneyDrunk.Observe.Connectors.GitHub` — webhook receiver, repo health checks, PR/issue state
  - `HoneyDrunk.Observe.Connectors.Azure` — Azure Monitor alerts, deployment state, resource health
  - `HoneyDrunk.Observe.Connectors.Http` — generic HTTP health check connector
- Authentication per connector (delegates credential resolution to Vault)

**Does NOT own:**
- Observation contracts (that's HoneyDrunk.Observe)
- Routing observations to HoneyHub (that's an integration point, not a connector concern)

**Sector assignment:** Both Observe Nodes belong to **Meta** sector — they are about the Grid's self-awareness and visibility, not about Core runtime, Ops pipelines, or AI cognition.

> **Note:** PDR-0001 originally placed Observe and Observe.Connectors in the **Ops** sector. This ADR intentionally reassigns them to **Meta** because observation is a self-awareness concern (how the Grid perceives external systems), not an operational pipeline concern. PDR-0001's sector table should be updated to reflect this decision once accepted.

---

### Layer 2: AI Routing Layer

**Purpose:** Allow `HoneyDrunk.AI` to select models based on declared capability requirements, cost limits, and routing policies — rather than requiring callers to hardcode a provider or model name.

**Owned by: `HoneyDrunk.AI` (extends existing Node, not a new Node)**

This is not a new Node — it is an extension of HoneyDrunk.AI's existing responsibility. The AI Node already owns `IModelProvider` (provider slot). AI Routing adds:

**New contracts within HoneyDrunk.AI:**
- `IModelRouter` — given a request with declared capability requirements, select the appropriate model/provider
- `IRoutingPolicy` — pluggable policy interface (cost-first, capability-first, latency-first, compliance-first)
- `IModelCapabilityDeclaration` — machine-readable declaration of what a model can do (context window, modalities, function calling support, cost tier)

**Routing policy storage:**
- Policies live in Azure App Configuration (the shared config store from ADR-0005)
- Policies are loaded at startup via `IConfigProvider` (Vault Node)
- No policies are hardcoded in application code

**Does NOT own:**
- Model execution (still `IChatClient` / `IEmbeddingGenerator`)
- Safety controls (that's Operator)
- Evaluation results (that's Evals — though Evals outputs can inform routing policy configuration)

---

## Consequences

### New Invariants

The following invariants must be added to `constitution/invariants.md`:

28. **Application code must never hardcode a model name or provider.** All model selection goes through `IModelRouter` in HoneyDrunk.AI. Routing policies are stored in App Configuration and are operator-configurable without a redeploy.

29. **Observation connectors must delegate credential resolution to Vault.** No connector stores credentials directly. Connection secrets (webhook secrets, API tokens for external services) are resolved via `ISecretStore` at connection establishment.

30. **HoneyDrunk.Observe events must be normalized to the canonical observation format before routing to HoneyHub.** Raw external formats (GitHub webhook JSON, Azure alert schema) never cross the Observe boundary — only normalized `IObservationEvent` types.

### Positive

- PDR-0001's observation and routing layers are now architectural commitments with defined contracts, not just product principles.
- Agents can now reason about Observe and AI Routing when generating issue packets.
- The provider slot pattern from Vault and Transport is consistently applied to a third domain (observation connectors) and a fourth (model routing policies).
- External project visibility is decoupled from HoneyHub — Observe can ship before HoneyHub is live.

### Negative

- Two new Nodes (Observe, Observe.Connectors) means two new repos, CI pipelines, and versioning to maintain.
- AI Routing adds complexity to the inference path — a misconfigured policy could route all requests to an expensive model. Mitigation: policy validation at startup, cost monitoring via Pulse/Operator.

## Alternatives Considered

### Embed observation in HoneyHub

Rejected. HoneyHub is not yet live and conflating observation (data collection) with orchestration (planning and decision) repeats the mistake that PDR-0001 was written to avoid. Observe ships independently and feeds HoneyHub when it is live.

### Embed model routing in each calling agent

Rejected. Hardcoded model selection per call site is the status quo. It makes provider swaps, cost optimization, and compliance changes require touching every agent. Centralized routing via `IModelRouter` is the correct architectural boundary.

### Use a third-party model router (LiteLLM, etc.)

Rejected. Third-party routers introduce an external dependency in the inference critical path. HoneyDrunk.AI already has the provider slot pattern; routing is a natural extension of the same abstraction without adding a new system boundary.

## Phase Plan

### Phase 1 — Contracts and Stubs (Scope now)

- Define `IObservationTarget`, `IObservationConnector`, `IObservationEvent` in `HoneyDrunk.Observe.Abstractions`
- Define `IModelRouter`, `IRoutingPolicy`, `IModelCapabilityDeclaration` in `HoneyDrunk.AI.Abstractions`
- Create repo context folders (`repos/HoneyDrunk.Observe/`, `repos/HoneyDrunk.Observe.Connectors/`)
- Update `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json`

### Phase 2 — GitHub Connector + Cost-First Routing (First useful increment)

- Implement `HoneyDrunk.Observe.Connectors.GitHub` — GitHub webhook receiver and repo health checks
- Implement cost-first routing policy in `HoneyDrunk.AI`
- Wire policies to App Configuration

### Phase 3 — HoneyHub Integration (When HoneyHub Phase 1 is live)

- Route normalized `IObservationEvent` instances into HoneyHub's knowledge graph
- Allow HoneyHub to read routing policy outcomes as signals for plan adjustment

## Future Implications

- As HoneyHub's knowledge graph matures, observation events become an input stream for dynamic re-planning. Observe is the sensor layer; HoneyHub is the reasoning layer.
- The routing policy system in HoneyDrunk.AI may eventually incorporate Evals output — empirical model quality data that informs routing decisions. This is a future integration, not a current requirement.
- The HTTP health check connector (`HoneyDrunk.Observe.Connectors.Http`) is the simplest connector and can serve as the reference implementation for future connectors (Datadog, PagerDuty, Linear, etc.).
