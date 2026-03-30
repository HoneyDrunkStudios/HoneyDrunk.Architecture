# PDR-0001: HoneyHub Platform — Observation and AI Routing Layers

**Status:** Accepted  
**Date:** 2026-03-30  
**Deciders:** HoneyDrunk Studios  
**Sector:** Meta / AI  
**Extends:** [ADR-0003](../adrs/ADR-0003-honeyhub-control-plane.md) (HoneyHub as Organizational Control Plane)

---

## Context

ADR-0003 established HoneyHub as a graph-driven orchestration system — a control plane that connects product intent to engineering execution to runtime signals. That decision assumed the Grid is defined by HoneyDrunk-native infrastructure: Kernel context propagation, Transport envelopes, Pulse telemetry, and the strongly-typed identity primitives that flow through every Node.

This works for internal HoneyDrunk operations. It does not work for the rest of the world.

Two strategic realities force a platform evolution:

### External adoption requires external visibility

Most teams will not build on HoneyDrunk.Kernel, HoneyDrunk.Transport, or HoneyDrunk.Data. They have existing codebases, existing CI pipelines, and existing telemetry. If HoneyHub can only reason about systems that emit native Grid context, its addressable market is exactly one organization — HoneyDrunk Studios.

For HoneyHub to become a platform, it needs a way to observe and reason about projects it did not build.

### AI model selection does not belong to users

Current and near-future product thinking assumes users (or agents) explicitly select AI models and providers. This creates:

- **Cognitive overhead** — users must understand model capabilities, pricing, and availability
- **Inconsistency** — different features or agents use different models for no principled reason
- **Governance gaps** — no centralized control over cost, quality, or compliance
- **Vendor lock-in** — direct provider coupling throughout the product surface

Model selection is an infrastructure concern. It should be abstracted, policy-driven, and transparent — not a per-call decision scattered across the application surface.

---

## Problem Statement

### 1. External Visibility Gap

HoneyHub cannot provide meaningful value to projects not built on HoneyDrunk-native infrastructure. The current integration model requires:

- GridContext propagation (Kernel)
- Transport envelopes (Transport)
- Native Pulse instrumentation
- Strongly-typed IDs (CorrelationId, NodeId, StudioId)

External projects have none of this. Without a normalization layer, HoneyHub is a closed system.

### 2. AI Provider Complexity Gap

As the AI sector grows (9 planned Nodes per `constitution/ai-sector-architecture.md`), every Node that invokes a model needs to answer: which provider, which model, at what cost, under what compliance constraints. Without centralization, these decisions fragment across:

- HoneyDrunk.AI (provider abstraction)
- HoneyDrunk.Agents (agent execution)
- HoneyDrunk.Flow (orchestration workflows)
- HoneyDrunk.Operator (autonomous execution)

Each would independently solve model selection, creating inconsistency and duplication.

---

## Decision

### A. Observation Layer — New Domain

HoneyHub must support **observed projects**: external repositories, CI pipelines, and systems that are not built on HoneyDrunk infrastructure.

A dedicated **Observation domain** is introduced, responsible for:

1. **Ingesting external signals** — GitHub webhooks, CI events, issue state changes, deployment notifications
2. **Normalizing into Grid-compatible structures** — converting external events into `ObservedEvent` records that HoneyHub's knowledge graph can consume
3. **Maintaining fidelity metadata** — every observed signal carries an explicit fidelity tier so downstream consumers know how much to trust it
4. **Feeding HoneyHub and Pulse** — normalized signals flow into HoneyHub for interpretation and into Pulse for aggregation, using the same signal interfaces that native telemetry uses

The Observation layer does not pollute core runtime Nodes. External connector logic is isolated from Kernel, Transport, and Data.

#### New Nodes

| Node | Responsibility |
|------|---------------|
| **HoneyDrunk.Observe** | Core normalization engine. Defines `ObservedEvent`, fidelity tiers, and the normalization pipeline. Converts raw external signals into Grid-compatible structures. |
| **HoneyDrunk.Observe.Connectors** | Provider-slot pattern for external systems. Each connector (GitHub, Azure DevOps, GitLab, CI systems) implements a standard ingestion interface. Connectors are isolated — adding a new source does not modify core Observe. |

#### Grid definition shift

The Grid is no longer limited to Nodes running HoneyDrunk runtime infrastructure. Externally:

> **The Grid is any project HoneyHub can observe and reason about.**

Internally, the strongly-typed context model (GridContext, NodeContext, OperationContext) remains unchanged. The distinction is formalized as **fidelity tiers**:

| Tier | Source | Fidelity | Example |
|------|--------|----------|---------|
| **Native** | HoneyDrunk-native instrumentation (Kernel, Pulse, Transport) | Full | GridContext with CorrelationId, structured traces, typed envelopes |
| **Observed** | External systems via Observation layer | Partial | GitHub webhook events, CI pipeline results, issue state changes |

HoneyDrunk-native integration becomes a **higher-fidelity upgrade path**, not a prerequisite for using HoneyHub.

---

### B. AI Routing Layer — New Domain

A dedicated **AI routing and provider orchestration layer** is introduced, centralizing model selection behind policy-driven routing.

This layer abstracts model and provider selection from all consumers (Agents, Flow, Operator, and any future AI-consuming Node) behind:

1. **Task classification** — incoming requests are classified by task type (generation, analysis, embedding, code, vision, etc.)
2. **Policy-driven routing** — organization-level policies determine which model serves each task type, based on constraints: cost ceiling, latency target, quality tier, compliance requirements, provider allowlist
3. **Model registry** — a managed catalog of available models, their capabilities, pricing characteristics, and current availability
4. **Execution and fallback** — the router executes against the selected model with automatic fallback when a provider is unavailable
5. **Telemetry** — every routing decision is logged with the policy that drove it, the model selected, and the outcome (latency, token usage, success/failure)

#### Default experience

The default user experience is **"Auto" model selection**. The system makes the decision. Users see the result. Advanced users and organizations can define policies to constrain or override routing, but the default is always "the system picks the right model for the task."

#### Placement within AI Sector

Per `constitution/ai-sector-architecture.md`, the AI sector already defines **HoneyDrunk.AI** as the provider abstraction layer with contracts including `IModelProvider`, `IModelRegistry`, and `ICompletionService`. The AI routing layer extends this existing Node's responsibility to include:

- `IRoutingPolicy` — rules that map task classifications to model constraints
- `ITaskClassifier` — categorizes incoming requests by capability requirement
- `IRoutingDecision` — immutable record of why a specific model was selected
- `IModelRouter` — top-level orchestrator that composes classification → policy evaluation → provider selection → execution

This does not require a new Node. It deepens **HoneyDrunk.AI** to own routing as a first-class concern alongside provider abstraction.

---

### C. Platform Positioning Shift

HoneyHub is repositioned from an internal HoneyDrunk control plane to a **platform that can serve external organizations and projects**.

| Before | After |
|--------|-------|
| HoneyHub requires HoneyDrunk-native stacks | HoneyHub works with any observable project |
| Users select AI models directly | The system selects models via policies |
| Value is tied to Grid instrumentation depth | Value scales from basic (observed) to advanced (native) |
| HoneyHub is a dev tool | HoneyHub is a project/company operating system |

---

## Options Evaluated

### Option 1: Keep HoneyHub internal-first and HoneyDrunk-native

**Description:** HoneyHub remains tightly coupled to Grid-native instrumentation. External projects are not supported.

**Pros:**
- Simplest implementation — no normalization layer needed
- Highest fidelity for all data
- No new domain complexity

**Cons:**
- Market of one (HoneyDrunk Studios)
- No path to external adoption
- HoneyHub cannot justify its development cost without broader applicability

**Verdict:** Rejected. A control plane that can only control one system is an overengineered internal tool.

### Option 2: Add integrations directly into HoneyHub

**Description:** Build GitHub, CI, and external system connectors directly into HoneyHub's integration layer.

**Pros:**
- No new Nodes — fewer moving parts
- HoneyHub already has an integration layer (per ADR-0003)

**Cons:**
- Violates single responsibility — HoneyHub becomes both orchestrator and ingestion engine
- Connector sprawl inside HoneyHub makes it harder to maintain
- Other consumers (Pulse) cannot reuse the normalization logic
- HoneyHub's boundaries (per `repos/HoneyHub/boundaries.md`) explicitly state it does not own telemetry collection

**Verdict:** Rejected. The integration layer in HoneyHub is for reading existing Grid data, not for ingesting and normalizing external systems.

### Option 3: Add integrations into Pulse

**Description:** Pulse gains external connectors that normalize non-OTEL signals into its pipeline.

**Pros:**
- Pulse already handles telemetry from multiple sources
- Pulse has a collector architecture that could accommodate new inputs

**Cons:**
- Pulse is a telemetry pipeline, not an event normalization engine — the domain models are different
- GitHub issues and CI pipeline results are not telemetry — they are organizational signals
- Violates Pulse's boundary: "Pulse owns the data pipeline, HoneyHub owns the meaning layer"
- Would couple Pulse to GitHub/CI APIs, which is outside its domain

**Verdict:** Rejected. Pulse collects and routes telemetry. Organizational signals from external systems are a different domain.

### Option 4: Introduce Observation layer only

**Description:** Add the Observation domain (HoneyDrunk.Observe + Connectors) but defer AI routing.

**Pros:**
- Addresses the external visibility gap
- Smaller scope, faster delivery
- AI routing can follow independently

**Cons:**
- AI provider complexity continues to fragment across Nodes
- Misses the opportunity to establish centralized model governance early
- The two decisions are independent — deferring one does not simplify the other

**Verdict:** Viable but incomplete. Both gaps are strategic. Addressing only one leaves the other accumulating debt.

### Option 5: Introduce AI routing layer only

**Description:** Centralize model selection and routing but defer external observation.

**Pros:**
- Addresses AI governance immediately
- Beneficial even for internal-only usage
- Smaller initial scope

**Cons:**
- HoneyHub remains a closed system — no external adoption path
- The platform positioning shift cannot happen without observation

**Verdict:** Viable but incomplete. Same reasoning as Option 4.

### Option 6: Introduce both Observation and AI Routing layers as first-class domains *(Selected)*

**Description:** Add Observation domain (HoneyDrunk.Observe + Connectors) and deepen HoneyDrunk.AI to include policy-driven routing. Both are first-class concerns with defined contracts, boundaries, and phased rollout.

**Pros:**
- Closes both strategic gaps simultaneously
- Enables the full platform positioning shift
- Each domain is independent — they can be built in parallel
- Aligns with existing AI sector architecture (HoneyDrunk.AI already planned)
- Establishes governance patterns early when the system is still small

**Cons:**
- More upfront design work
- Two new domain surfaces to maintain
- Increased system complexity
- Requires careful contract design to avoid premature abstraction

**Verdict:** Selected. The two domains are independent, so complexity does not compound. The platform cannot exist without both. Building them in parallel is efficient because they share no dependencies.

---

## Tradeoffs

| Tradeoff | Favors | Rationale |
|----------|--------|-----------|
| Added system complexity vs. platform flexibility | Flexibility | The Grid is designed to grow. Two well-bounded domains are manageable. A closed system is not a platform. |
| Lower fidelity for observed systems vs. broader adoption | Adoption | Fidelity tiers make the tradeoff explicit. Observed data is useful even at partial fidelity. Perfect-or-nothing is not a product strategy. |
| Centralized AI routing vs. reduced user control | Centralization | Users who need control get policies. Users who do not need control get "Auto." The default should be invisible infrastructure, not a selection screen. |
| Need for policy systems vs. simplicity of direct provider usage | Policies | Direct provider usage does not scale past a handful of features. Governance requirements (cost, compliance) are inevitable. Building the abstraction now avoids a painful retrofit. |
| New contract surface area vs. stability | New contracts | The AI sector architecture already defines 9 Nodes and their contracts. Observation adds one new domain. The contract cost is bounded. |

---

## Architecture Implications

### New domains and nodes

#### Observation Domain

| Node | Sector | Responsibility |
|------|--------|---------------|
| **HoneyDrunk.Observe** | Ops | Core normalization engine. Defines `ObservedEvent`, fidelity tiers, normalization pipeline. Does not know about specific external systems. |
| **HoneyDrunk.Observe.Connectors** | Ops | Provider-slot pattern. Each connector (GitHub, Azure DevOps, GitLab, Jenkins, etc.) implements a standard ingestion interface. Isolated from core Observe. |

**Data flow:**

```
External System → Connector → ObservedEvent → Observe Core → HoneyHub Knowledge Graph
                                                           → Pulse Signal Stream
```

**Key contracts (to be defined):**

- `ObservedEvent` — normalized event structure with source, type, timestamp, fidelity tier, and payload
- `IEventConnector` — interface for external system adapters
- `FidelityTier` — enum: Native, Observed, Inferred
- `IObservationPipeline` — normalization and enrichment pipeline

#### AI Routing (within HoneyDrunk.AI)

| Node | Sector | Responsibility |
|------|--------|---------------|
| **HoneyDrunk.AI** (extended) | AI | Provider abstraction + model registry + task classification + policy-driven routing + execution + fallback + telemetry |

**Data flow:**

```
Consumer (Agent, Flow, etc.) → IModelRouter → TaskClassifier → PolicyEvaluator → ModelSelector → Provider → Result
                                                                                                          → RoutingDecision (telemetry)
```

**Key contracts (to be defined):**

- `IModelRouter` — top-level routing orchestrator
- `IRoutingPolicy` — declarative rules mapping task types to model constraints
- `ITaskClassifier` — categorizes requests by capability requirement
- `RoutingDecision` — immutable record: task classification, policy applied, model selected, provider used, rationale
- `ModelCapability` — describes what a model can do (generation, embedding, vision, code, etc.)

### Existing nodes — must remain clean

The following Nodes are not modified by this decision:

| Node | Boundary | Reason |
|------|----------|--------|
| **HoneyDrunk.Kernel** | Runtime context and identity | Observation and AI routing are higher-level concerns. Kernel owns GridContext, lifecycle, and identity primitives. |
| **HoneyDrunk.Transport** | Messaging backbone | Transport moves envelopes between Nodes. Observation signals are not transport messages — they are domain events. |
| **HoneyDrunk.Data** | Persistence patterns | Data owns repository pattern, unit of work, and transactional outbox. Observation and AI routing have their own storage needs. |
| **HoneyDrunk.Auth** | Authentication and authorization | Auth validates tokens and evaluates policies. AI routing policies are domain-specific, not auth policies. |

### Pulse evolution

Pulse gains a second input mode:

| Input | Source | Fidelity | Integration |
|-------|--------|----------|-------------|
| **Native telemetry** | Kernel / OTEL / Transport | Full | Existing — structured traces, metrics, logs |
| **Observed signals** | Observation layer | Partial | New — normalized `ObservedEvent` records |

Pulse does **not** own external connectors. It receives already-normalized signals from the Observation layer. Pulse's role remains: collect, route, aggregate. The Observation layer owns: ingest, normalize, enrich.

### HoneyHub evolution

HoneyHub's role narrows and clarifies:

| Responsibility | Before | After |
|----------------|--------|-------|
| **Data ingestion** | Directly consumed GitHub/Pulse/Architecture catalogs | Consumes normalized signals from Observation + native signals from Pulse + static context from Architecture |
| **AI model selection** | Not explicitly addressed | Delegates to HoneyDrunk.AI routing layer |
| **Project scope** | HoneyDrunk-native projects only | Any observable project |

HoneyHub becomes the **interface for project truth and execution intelligence**. It does not ingest raw external data. It does not select AI models. It consumes normalized inputs and produces orchestrated outputs.

---

## Node and Boundary Flow

```
┌─────────────────────────────────────────────────────────┐
│                    External World                       │
│  GitHub · Azure DevOps · GitLab · Jenkins · CI Systems  │
└───────────────────────┬─────────────────────────────────┘
                        │ raw events
                        ▼
┌─────────────────────────────────────────────────────────┐
│              HoneyDrunk.Observe.Connectors              │
│              (provider-slot per source)                  │
└───────────────────────┬─────────────────────────────────┘
                        │ ObservedEvent
                        ▼
┌─────────────────────────────────────────────────────────┐
│                  HoneyDrunk.Observe                     │
│          (normalization + enrichment pipeline)           │
└────────────┬──────────────────────────┬─────────────────┘
             │                          │
             ▼                          ▼
┌────────────────────┐      ┌────────────────────┐
│     HoneyHub       │      │      Pulse         │
│  (Knowledge Graph  │      │  (Telemetry        │
│   + Orchestration) │      │   Aggregation)     │
└────────┬───────────┘      └────────────────────┘
         │ task assignments
         ▼
┌─────────────────────────────────────────────────────────┐
│                  HoneyDrunk.AI                          │
│    (model routing + provider abstraction + execution)   │
└─────────────────────────────────────────────────────────┘
         │ model responses
         ▼
┌─────────────────────────────────────────────────────────┐
│              Grid Nodes (Agents, Flow, etc.)            │
│              AI consumers use IModelRouter              │
└─────────────────────────────────────────────────────────┘

         ┌───────────────────────────────────────┐
         │          Unchanged Foundations         │
         │  Kernel · Transport · Data · Auth     │
         │  (runtime context, messaging,         │
         │   persistence, authorization)         │
         └───────────────────────────────────────┘
```

### Separation of concerns

| Layer | Owns | Does NOT own |
|-------|------|-------------|
| **Observe (Ingestion)** | External signal intake, normalization, fidelity classification | Interpretation, orchestration, model execution |
| **AI (Routing + Execution)** | Model selection, policy evaluation, provider abstraction, execution | Signal ingestion, project planning, telemetry aggregation |
| **Kernel (Runtime)** | GridContext, lifecycle, identity, configuration | External signals, AI routing, project orchestration |
| **HoneyHub (Orchestration)** | Knowledge graph, planning, signal interpretation, projections | Raw ingestion, AI execution, telemetry collection |
| **Pulse (Telemetry)** | Collection, routing, aggregation, sink management | Signal normalization, external connectors, AI routing |

---

## What Does NOT Change

- **Core Grid runtime model** — GridContext, NodeContext, OperationContext remain the internal backbone
- **Strongly-typed context and identity** — CorrelationId, NodeId, StudioId, TenantId are unchanged
- **Internal Node boundaries** — Kernel, Transport, Data, Auth, Web.Rest, Vault boundaries are preserved
- **Pulse as unified telemetry layer** — Pulse's architecture is unchanged; it gains a new input source, not a new responsibility
- **Dependency invariants** — Abstractions packages remain dependency-free; the DAG is maintained
- **Packaging and versioning** — Semantic versioning, CHANGELOG, NuGet packaging continue as-is
- **Agent execution model** — AgentKit owns agent runtime; HoneyHub assigns work; this separation persists

---

## Product Implications

### Tiered value proposition

| Tier | Integration Level | Value |
|------|-------------------|-------|
| **Basic (Observed)** | Connect external repos/CI via Observation connectors | Project visibility, cross-repo tracking, basic signal correlation, planning support |
| **Standard (Instrumented)** | Add Pulse telemetry (OTEL) to existing projects | Runtime signal correlation, health monitoring, SLO tracking against goals |
| **Advanced (Grid-Native)** | Build on HoneyDrunk Kernel/Transport/Data | Full context propagation, distributed tracing, typed identity, envelope-based messaging, maximum fidelity |

### External onboarding path

1. User connects their GitHub org → Observation layer ingests repo, issue, PR, CI signals
2. HoneyHub creates project entities in its knowledge graph from observed data
3. User gets visibility: what repos exist, what's shipping, what's breaking, where work is stuck
4. User optionally adds Pulse instrumentation for runtime telemetry → fidelity increases
5. User optionally adopts HoneyDrunk Nodes for full Grid-native integration → maximum fidelity

Each step increases value without requiring the previous step's technology stack.

### AI governance

- Cost visibility — every AI invocation is traced to the policy that authorized it and the cost incurred
- Compliance — organizations define model allowlists; the routing layer enforces them
- Quality — routing policies can specify quality tiers; the system selects models accordingly
- Transparency — every routing decision is logged and auditable

### Platform positioning

HoneyHub shifts from "dev tool for HoneyDrunk projects" to "operating system for any software project." The AI routing layer makes model selection a platform capability, not a user burden. The Observation layer makes project visibility a universal feature, not a Grid-native exclusive.

---

## Risks

| Risk | Severity | Description |
|------|----------|-------------|
| **Observation layer becomes a dumping ground** | High | Without strict contracts, every external signal format gets its own ad-hoc normalization path. ObservedEvent must remain a disciplined, minimal contract. |
| **AI routing becomes opaque** | Medium | Users cannot understand why a specific model was selected. Routing decisions must be logged, auditable, and explainable at every level. |
| **Over-abstraction reduces debuggability** | Medium | Adding normalization and routing layers between raw data and action creates indirection. Each layer must provide clear observability into its own behavior. |
| **Increased latency from routing and normalization** | Medium | Normalization adds a processing step before signals reach HoneyHub. AI routing adds a classification step before model invocation. Both must be designed for low overhead. |
| **Connector sprawl** | Medium | Each external system requires a connector. Without governance, connectors proliferate and maintenance burden grows. The provider-slot pattern and strict connector interfaces mitigate this. |
| **Premature AI policy complexity** | Low | Building a rich policy system before understanding real usage patterns could produce unused infrastructure. V1 should be deterministic and rule-based. |

---

## Mitigations

| Risk | Mitigation |
|------|-----------|
| Observation layer becoming a dumping ground | Strict `ObservedEvent` contract with mandatory fields. Connectors transform to the contract — they do not extend it ad-hoc. Schema evolution follows the same versioning discipline as Abstractions packages. |
| Opaque AI routing | Every `RoutingDecision` is an immutable record: task classification, policy matched, model selected, provider used, rationale string. Decisions are emitted as telemetry via Pulse. |
| Over-abstraction | Each layer (Observe, AI Routing) instruments its own behavior via Pulse. Correlation IDs flow through normalization and routing so end-to-end tracing is possible. |
| Increased latency | Normalization is a pipeline — not a queue. AI routing V1 is rule-based lookup, not ML inference. Latency budgets are defined in contracts. |
| Connector sprawl | Provider-slot pattern limits connector scope. Each connector implements `IEventConnector` and nothing else. New connectors require a boundary review. |
| Premature policy complexity | V1 routing is deterministic: task type → model mapping, configured per organization. Adaptive/ML-driven routing is Phase 5 — not V1. |

---

## Consequences

### Short-term

- **Domain design work** — ObservedEvent, FidelityTier, IEventConnector, IRoutingPolicy, ITaskClassifier, RoutingDecision contracts must be designed
- **New nodes** — HoneyDrunk.Observe and HoneyDrunk.Observe.Connectors are created in the Ops sector
- **HoneyDrunk.AI extended** — routing contracts added to the existing AI Node design
- **Catalog updates** — `nodes.json`, `relationships.json`, `sectors.md` updated
- **ADR cascade** — at least two ADRs follow from this PDR (Observation boundaries, AI routing design)

### Long-term

- **Platform flexibility** — HoneyHub can serve any organization, not just HoneyDrunk Studios
- **Provider-agnostic AI strategy** — no vendor lock-in at the application layer
- **Scalable onboarding** — new projects connect via observation; native integration is an upgrade, not a prerequisite
- **Governance infrastructure** — cost, compliance, and quality controls are architectural, not ad-hoc
- **Ecosystem expansion** — Observation connectors and AI provider integrations can be contributed by the community

---

## Rollout — Phased Approach

### Phase 1: Contract Definition

- Define `ObservedEvent` schema and `FidelityTier` enum
- Define `IEventConnector` interface for the Observation provider-slot pattern
- Define `IRoutingPolicy`, `ITaskClassifier`, `RoutingDecision` contracts for AI routing
- Define `ModelCapability` and `IModelRegistry` extensions
- Publish contracts as Abstractions packages
- **Exit criteria:** Contracts reviewed and accepted via ADRs

### Phase 2: Minimal Viable Observation + Rule-Based Routing

- Implement GitHub connector (repos, issues, PRs, CI status)
- Implement `ObservedEvent` normalization pipeline in HoneyDrunk.Observe
- Implement deterministic AI routing: task type → model mapping, static configuration
- Integrate observed signals into HoneyHub knowledge graph
- **Exit criteria:** External GitHub repos appear in HoneyHub; AI routing serves a single consumer

### Phase 3: HoneyHub Integration

- HoneyHub consumes observed signals alongside native signals
- HoneyHub uses AI routing for any model invocations in its orchestration engine
- Project entities support both native and observed fidelity tiers
- **Exit criteria:** HoneyHub can plan and track work for an observed (non-HoneyDrunk) project

### Phase 4: Connector and Policy Expansion

- Add Azure DevOps, GitLab, and additional CI connectors
- Add organization-level routing policies (cost ceiling, model allowlist, compliance constraints)
- Add policy management surface (API / HoneyHub UI)
- **Exit criteria:** Multiple external systems supported; routing policies are configurable per organization

### Phase 5: Adaptive Routing and Deep Pulse Integration

- Introduce model performance tracking and feedback loops
- Explore adaptive routing based on observed model quality
- Deeper Pulse integration: observed signals participate in Pulse dashboards and alerting
- **Exit criteria:** Routing decisions improve over time based on outcome data

---

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| How rich should `ObservedEvent` be vs. minimal viable signal? | Architecture | Open — risk of over-specifying vs. under-delivering. Start minimal, extend via versioned schema evolution. |
| Where are routing policies stored and managed? | Architecture / AI | Open — candidates: configuration files, database, HoneyHub knowledge graph. |
| How are AI routing decisions exposed to users? | Product / AI | Open — options: audit log, per-response metadata, dashboard. |
| How does AI usage map to subscription/pricing tiers? | Product | Open — requires pricing and packaging decision record. |
| Should Observation connectors be in-process or deployed as separate services? | Architecture / Ops | Open — in-process is simpler; separate services scale independently. |
| How does the Observation layer handle connector authentication and secrets? | Architecture / Vault | Open — likely via Vault, but connector-specific credential management needs design. |
| What is the SLA for observed signal ingestion latency? | Ops | Open — depends on connector type and deployment model. |

---

## Recommended Follow-Up Artifacts

| Artifact | Type | Purpose |
|----------|------|---------|
| Observation domain boundaries and contracts | ADR | Define what HoneyDrunk.Observe owns, its contracts, and its relationship to Pulse and HoneyHub |
| AI routing / provider orchestration design | ADR | Define IModelRouter, IRoutingPolicy, ITaskClassifier contracts and their placement within HoneyDrunk.AI |
| ObservedEvent domain model | Design doc | Schema definition for `ObservedEvent`, `FidelityTier`, and enrichment pipeline |
| AIRoutingPolicy / ModelCapability domain model | Design doc | Schema definition for routing policies, model capabilities, and the RoutingDecision record |
| HoneyHub capability tier definition | PDR | Formalize Basic / Standard / Advanced tiers and their feature boundaries |
| Pricing and packaging decision record | PDR | Map capability tiers to pricing, AI usage metering, and subscription structure |
| Connector strategy | Design doc | Prioritized list of connectors, authentication patterns, deployment model, and community contribution guidelines |
| Pulse input model clarification | ADR | Formalize how Pulse accepts observed signals alongside native telemetry without blurring its boundaries |
| Sectors and catalog updates | Chore | Add Observe Nodes to `constitution/sectors.md`, `catalogs/nodes.json`, and `catalogs/relationships.json` |
