# ADR-0010: Observation Layer and AI Routing — HoneyDrunk.Observe and IModelRouter

**Status:** Accepted
**Date:** 2026-04-12
**Deciders:** HoneyDrunk Studios
**Sector:** Ops
**Follows from:** PDR-0001 (HoneyHub Platform — Observation and AI Routing layers)

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Add `honeydrunk-observe` to `catalogs/nodes.json` with full metadata (include package families: `HoneyDrunk.Observe.Abstractions`, `HoneyDrunk.Observe`, and the `HoneyDrunk.Observe.Connectors.*` provider slots)
- [ ] Add entries to `catalogs/relationships.json` (consumed_by, exposes.contracts, consumes_detail)
- [ ] Add contract stubs for `IObservationTarget`, `IObservationConnector`, `IObservationEvent` to `catalogs/contracts.json`
- [ ] Add `honeydrunk-observe` to `catalogs/grid-health.json` and remove any `honeydrunk-observe-connectors` stubs (connectors ship from the Observe repo, not a separate Node)
- [ ] Create `repos/HoneyDrunk.Observe/` context folder (overview, boundaries, invariants, active-work, integration-points)
- [ ] Update `constitution/sectors.md` Node table to add `HoneyDrunk.Observe` under the Ops sector
- [ ] Update ADR index (ADRs/README.md) status from Proposed → Accepted
- [ ] Update `constitution/invariants.md` to add invariants 28–30 (currently added speculatively — revert if ADR is not accepted)

## Context

PDR-0001 introduced two new layers in the HoneyDrunk platform vision:

1. **Observation Layer** — External project visibility via a new `HoneyDrunk.Observe` Node, whose package families include observation contracts and a `HoneyDrunk.Observe.Connectors.*` provider-slot family. This allows the Grid to connect to and monitor external projects (non-HoneyDrunk repos, third-party services, customer codebases) the way Pulse monitors internal Nodes.

2. **AI Routing Layer** — Policy-driven model routing in `HoneyDrunk.AI`. This allows agents and applications to select models based on capability requirements, cost constraints, and context rather than hardcoded provider choices.

Both layers were accepted as part of PDR-0001 but were never translated into concrete architectural decisions, ADRs, or work packets. They exist only as principles. This ADR makes them architectural commitments with defined boundaries, so agents can reason about them and work can be scoped.

This ADR does **not** design the full implementation — that belongs in issue packets. It establishes: what each layer owns, what it does not own, its relationship to existing Nodes, and how bring-up will be phased.

## Decision

### Layer 1: Observation Layer

**Purpose:** Allow the Grid to monitor external projects — any codebase or service outside HoneyDrunk — with the same telemetry and health visibility that Pulse provides for internal Nodes.

**New Node: `HoneyDrunk.Observe`**

One new Node that owns both the observation contracts and the per-system connector packages. This follows the same provider-slot pattern as Vault and Transport, where a single Node houses abstractions and provider packages in one repo family.

**Package families within the Observe Node:**

- `HoneyDrunk.Observe.Abstractions` — contracts (`IObservationTarget`, `IObservationConnector`, `IObservationEvent`) and the observation-state model.
- `HoneyDrunk.Observe` — runtime that composes connectors, normalizes events, and tracks observation state.
- `HoneyDrunk.Observe.Connectors.*` — provider-slot packages, one per external system. First-wave connectors:
  - `HoneyDrunk.Observe.Connectors.GitHub` — webhook receiver, repo health checks, PR/issue state
  - `HoneyDrunk.Observe.Connectors.Azure` — Azure Monitor alerts, deployment state, resource health
  - `HoneyDrunk.Observe.Connectors.Http` — generic HTTP health check connector

Each connector delegates credential resolution to Vault via `ISecretStore`.

**Owns:**
- Observation contracts and state model
- Event normalization — convert external events (GitHub webhooks, deployment notifications, error alerts) into a canonical Grid-compatible format
- Observation state — track whether an external project is healthy, degraded, or unreachable
- Connector implementations under `HoneyDrunk.Observe.Connectors.*`

**Does NOT own:**
- Telemetry routing to external sinks (that's Pulse — opposite direction)
- Plan adjustments based on observations (that's HoneyHub, when live)
- Internal Grid telemetry (that stays in Pulse)
- Routing observations to HoneyHub (that's an integration point, not a connector concern)

**Sector assignment:** Observe belongs to the **Ops sector**, matching Pulse. Pulse owns outbound telemetry (Grid → external sinks); Observe owns inbound event intake (external systems → Grid). Both are runtime pipelines, not governance — Ops is the consistent bucket. This confirms PDR-0001's original Ops classification.

---

### Layer 2: AI Routing Layer

**Purpose:** Allow `HoneyDrunk.AI` to select models based on declared capability requirements, cost limits, and routing policies — rather than requiring callers to hardcode a provider or model name.

**Owned by: `HoneyDrunk.AI` (extends existing Node, not a new Node)**

This is not a new Node — it is an extension of HoneyDrunk.AI's existing responsibility. The AI Node already owns `IModelProvider` (provider slot). AI Routing adds:

**New contracts within HoneyDrunk.AI:**
- `IModelRouter` — given a request with declared capability requirements, select the appropriate model/provider
- `IRoutingPolicy` — pluggable policy interface (cost-first, capability-first, latency-first, compliance-first)
- `ModelCapabilityDeclaration` — machine-readable declaration of what a model can do (context window, modalities, function calling support, cost tier)

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

- One new Node (Observe) means a new repo, CI pipeline, and versioning to maintain. Connector packages ship from the same repo following the Vault/Transport provider-slot pattern, avoiding the cost of a separate Node family.
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
- Define `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration` in `HoneyDrunk.AI.Abstractions`
- Create repo context folder (`repos/HoneyDrunk.Observe/`)
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
