# HoneyHub — System Architecture

The internal architecture of HoneyHub as a system. Defines layers, their responsibilities, and the boundaries between HoneyHub and every other system in the Grid.

---

## Architectural Layers

HoneyHub is composed of four layers. Each layer has a single responsibility and communicates with adjacent layers through defined interfaces.

```
┌──────────────────────────────────────────────────┐
│              Projection Layer                    │
│  (Views: roadmaps, PRDs, runbooks, dashboards)   │
├──────────────────────────────────────────────────┤
│            Orchestration Engine                   │
│  (Planning, sequencing, agent coordination)       │
├──────────────────────────────────────────────────┤
│             Knowledge Graph                       │
│  (Entities, relationships, state)                 │
├──────────────────────────────────────────────────┤
│            Integration Layer                      │
│  (GitHub, Pulse, Actions, Catalogs)               │
└──────────────────────────────────────────────────┘
```

---

### Layer 1: Integration Layer

The bottom layer. Handles all communication between HoneyHub and external systems. Every external interaction passes through an adapter in this layer.

**Adapters:**

| Adapter | External System | Direction | Data |
|---------|----------------|-----------|------|
| Catalog Adapter | Architecture repo (`/catalogs/`) | Inbound | Node registry, relationships, signals, services, modules |
| GitHub Adapter | GitHub API | Bidirectional | Issues (create/read), PRs (read status), webhooks (push, merge, CI status) |
| Pulse Adapter | Pulse telemetry pipeline | Inbound | Signal events (errors, latency, health, deployments) |
| Actions Adapter | HoneyDrunk.Actions | Inbound | Build results, deployment events, workflow status |
| ADR Adapter | Architecture repo (`/adrs/`) | Bidirectional | ADR metadata indexing, ADR draft packet generation |

**Responsibilities:**
- Normalize external data into HoneyHub's internal entity model
- Handle authentication, rate limiting, and retry logic for external APIs
- Emit internal events when external state changes (e.g., PR merged → Task state update)

**Does not:** Interpret data. The integration layer moves and normalizes — it does not decide what signals mean or what actions to take.

---

### Layer 2: Knowledge Graph

The data layer. Stores all entities and relationships defined in the domain model. This is HoneyHub's memory.

**Responsibilities:**
- Store entities (Project, Goal, Feature, Task, Agent, Repo, Node, ADR, Signal)
- Store typed edges between entities (see [relationships.md](relationships.md))
- Support graph traversal queries:
  - "What tasks remain for this goal?"
  - "Which nodes are affected by this feature?"
  - "What ADRs govern this repo?"
  - "Which goals are impacted by this signal?"
- Maintain entity lifecycle state transitions
- Enforce graph constraints (DAG for dependencies, cardinality rules)

**Storage model:** The knowledge graph persists as structured data. At early stages this may be JSON files in the Architecture repo (extending the existing catalog pattern). As complexity grows, it may migrate to a graph database. The storage mechanism is an implementation detail — the graph query interface is the contract.

**Does not:** Make decisions. The knowledge graph answers questions — it does not initiate action.

---

### Layer 3: Orchestration Engine

The decision layer. Takes intent (Goals) and the current state of the graph, and produces executable plans.

**Responsibilities:**

**Decomposition:**
- Accept a Goal and decompose it into Features based on affected repos and nodes
- Accept a Feature and decompose it into Tasks scoped to individual repos
- Determine task types (Implementation, Test, CI, Documentation, Investigation)
- Identify when a Feature requires an ADR (crosses node boundaries, modifies contracts)

**Sequencing:**
- Compute dependency order across Tasks
- Identify parallelizable work streams
- Detect blocked tasks and surface the blocking dependency

**Assignment:**
- Match Tasks to Agents based on capabilities and repo authorization
- Respect execution model constraints (Autonomous vs Human-in-the-Loop)
- Fall back to `human` assignment when no capable agent is registered

**Signal Response:**
- Receive correlated signals from the integration layer
- Evaluate signal impact against active Goals and Features
- Determine response: no action, alert, re-plan, or create investigation Task
- Threshold evaluation: distinguish noise from actionable degradation

**Plan Adjustment:**
- When execution state diverges from plan (task failed, signal indicates regression), re-evaluate the plan
- May cancel tasks, insert new tasks, or escalate to human decision

**Does not:** Execute tasks. The orchestration engine produces plans and task assignments — AgentKit and repo CI handle execution.

---

### Layer 4: Projection Layer

The output layer. Transforms the knowledge graph into views that humans and agents can consume.

**Projections:**

| Projection | Source Data | Output | Consumer |
|------------|------------|--------|----------|
| Roadmap | Projects, Goals, Features, status | Timeline view of planned and in-progress work | Developer, stakeholders |
| PRD (Product Requirements) | Goal, Features, SuccessCriteria | Structured requirements document | Developer, agents |
| Execution Plan | Tasks, dependencies, assignments | Ordered task list with parallelism annotations | Agents, developer |
| Impact Report | Signal, correlated Goals/Features | Assessment of runtime impact on product intent | Developer |
| Runbook | Node, Service, ADRs, known Signals | Operational context for a specific service | Oncall, agents |
| Progress Report | Goal, Features, Tasks, completion % | Status summary across active work | Developer |
| Dependency Map | Nodes, Repos, edges | Visual graph of what depends on what | Developer, agents |

**Responsibilities:**
- Read from the knowledge graph (never write)
- Apply formatting appropriate to the consumer (Markdown for humans, structured JSON for agents)
- Projections are stateless and re-derivable — they are views, not stored artifacts

**Does not:** Own data. If a projection is deleted, nothing is lost — it can be regenerated from the graph.

---

## Boundary Definitions

### What HoneyHub Owns

| Domain | Specifics |
|--------|-----------|
| Intent modeling | Projects, Goals, Features, success criteria |
| Work planning | Task decomposition, sequencing, dependency graphs |
| Agent coordination | Task assignment, capability matching, execution tracking |
| Signal interpretation | Correlating Pulse signals to goals and features |
| Graph state | All entities, edges, and lifecycle transitions |
| Projections | Roadmaps, PRDs, execution plans, impact reports |

### What HoneyHub Reads But Does Not Own

| Domain | Owner | How HoneyHub Accesses |
|--------|-------|-----------------------|
| Node registry | Architecture repo (`/catalogs/nodes.json`) | Catalog adapter reads on change |
| Node relationships | Architecture repo (`/catalogs/relationships.json`) | Catalog adapter reads on change |
| Service registry | Architecture repo (`/catalogs/services.json`) | Catalog adapter reads on change |
| ADR content | Architecture repo (`/adrs/`) | ADR adapter indexes metadata |
| Repo boundaries | Architecture repo (`/repos/*/boundaries.md`) | Catalog adapter reads on change |
| Telemetry data | Pulse pipeline | Pulse adapter subscribes to signal stream |
| Issue/PR state | GitHub | GitHub adapter polls or receives webhooks |
| CI results | HoneyDrunk.Actions | Actions adapter receives workflow events |

### What HoneyHub Does Not Touch

| Domain | Owner | Why Not |
|--------|-------|---------|
| Agent runtime | AgentKit | Separation of planning from execution |
| Telemetry collection | Pulse | HoneyHub interprets, Pulse collects |
| Secret management | Vault | Orthogonal concern |
| CI pipeline definitions | HoneyDrunk.Actions | Execution infrastructure, not planning |
| Code | Individual repos | HoneyHub plans work, repos implement it |
| Authentication/authorization | Auth | Runtime security, not orchestration |
| Transport messaging | Transport | Infrastructure, not planning |

---

## Data Flow

```
                    GitHub Webhooks
                         │
   Catalog Changes       │       Pulse Signals
        │                │            │
        ▼                ▼            ▼
   ┌─────────────────────────────────────┐
   │         Integration Layer           │
   │  (normalize, adapt, emit events)    │
   └──────────────┬──────────────────────┘
                  │ internal events
                  ▼
   ┌─────────────────────────────────────┐
   │          Knowledge Graph            │
   │  (store entities, serve queries)    │
   └──────────────┬──────────────────────┘
                  │ graph state
                  ▼
   ┌─────────────────────────────────────┐
   │       Orchestration Engine          │
   │  (plan, sequence, assign, react)    │
   └───────┬──────────────┬──────────────┘
           │              │
    task assignments    projections
           │              │
           ▼              ▼
   ┌──────────┐  ┌──────────────────┐
   │ AgentKit │  │ Projection Layer │
   │ / Human  │  │ (views, reports) │
   └──────────┘  └──────────────────┘
```

---

## Integration Points with Existing Grid Systems

### Architecture Repo → HoneyHub

The Architecture repo remains the **source of truth** for static Grid topology. HoneyHub consumes:
- `catalogs/nodes.json` — Node registry
- `catalogs/relationships.json` — Node dependency graph
- `catalogs/services.json` — Service registry
- `catalogs/signals.json` — Signal type definitions
- `catalogs/modules.json` — Package registry
- `repos/*/boundaries.md` — Repo ownership boundaries
- `adrs/*.md` — Architecture decision records

HoneyHub does not modify these files. It reads them and indexes the data into the knowledge graph. When HoneyHub determines that an ADR is needed, it generates an ADR draft packet into `generated/adr-drafts/` for the Architecture repo's review process.

### HoneyHub → GitHub

HoneyHub dispatches work to repos via GitHub Issues:
- Issue packets generated from task decomposition
- Issue body includes upstream context (Goal, Feature, ADRs)
- Issue labels encode task type and priority
- HoneyHub tracks issue state via webhooks or polling

HoneyHub reads PR state to determine task completion:
- PR merged + checks passing → Task moves to Done
- PR closed without merge → Task remains In Progress or escalates

### Pulse → HoneyHub

Pulse collects telemetry and routes it to sinks. HoneyHub is a **logical consumer** of Pulse signals — not a telemetry sink, but an interpreter.

- Pulse emits structured signal events (error rates, latency changes, health status, deployment markers)
- HoneyHub's Pulse adapter subscribes to relevant signal types
- The orchestration engine correlates signals to active Goals and Features via SignalBindings
- Correlation is based on NodeId, ServiceId, and time window alignment with active deployments

### HoneyHub → AgentKit

HoneyHub produces task assignments. AgentKit consumes them:
- Task assignment includes: TaskId, repo target, task description, upstream context, relevant ADRs
- AgentKit manages execution: tool access, memory, safety, context propagation
- Execution results flow back through GitHub (PR/Issue updates) which HoneyHub observes

HoneyHub and AgentKit never communicate directly at runtime. The interface is the task assignment artifact and the GitHub state that results from execution.
