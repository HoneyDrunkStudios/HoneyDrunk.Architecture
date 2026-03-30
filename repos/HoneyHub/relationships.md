# HoneyHub — Relationships (Graph Schema)

Typed edges that connect entities in the HoneyHub knowledge graph. This is the schema definition — each edge type defines a directional relationship between two entity types with explicit semantics.

---

## Decomposition Edges

These edges represent how intent breaks down into executable work.

```
Project ──contains──────────→ Goal
Goal    ──decomposes_into───→ Feature
Feature ──implemented_by────→ Task
Task    ──depends_on────────→ Task
```

| Edge | From | To | Cardinality | Semantics |
|------|------|----|-------------|-----------|
| `contains` | Project | Goal | 1:N | A project groups goals under a shared identity |
| `decomposes_into` | Goal | Feature | 1:N | A goal is achieved through the delivery of its features |
| `implemented_by` | Feature | Task | 1:N | A feature is realized through one or more tasks |
| `depends_on` | Task | Task | N:M | A task cannot start until its dependencies complete |

**Constraint:** Decomposition edges form a DAG. Cycles are invalid. A Task cannot depend on itself or on a Task that transitively depends on it.

---

## Targeting Edges

These edges bind work to the systems that execute it.

```
Task    ──targets────────────→ Repo
Task    ──assigned_to────────→ Agent
Feature ──affects_repo───────→ Repo
Feature ──affects_node───────→ Node
Agent   ──operates_in────────→ Repo
```

| Edge | From | To | Cardinality | Semantics |
|------|------|----|-------------|-----------|
| `targets` | Task | Repo | N:1 | Every task executes within exactly one repo |
| `assigned_to` | Task | Agent | N:1 | A task is assigned to one agent (or `human`) |
| `affects_repo` | Feature | Repo | N:M | A feature may require changes across multiple repos |
| `affects_node` | Feature | Node | N:M | A feature may impact one or more runtime nodes |
| `operates_in` | Agent | Repo | N:M | An agent is authorized to work in specific repos |

**Constraint:** `targets` is mandatory — every Task must resolve to exactly one Repo. `assigned_to` may be unset during planning and resolved during orchestration.

---

## Production Edges

These edges map source artifacts to runtime entities.

```
Repo ──produces───→ Node
Node ──depends_on──→ Node
Node ──deploys_as──→ Service
```

| Edge | From | To | Cardinality | Semantics |
|------|------|----|-------------|-----------|
| `produces` | Repo | Node | 1:N | A repo publishes one or more Nodes (NuGet packages) |
| `depends_on` | Node | Node | N:M | Runtime dependency between Nodes (must form a DAG) |
| `deploys_as` | Node | Service | N:M | Nodes compose into deployable services |

**Constraint:** Node dependency graph mirrors the existing `relationships.json` catalog. HoneyHub reads this, does not define it. The `deploys_as` edge maps to `services.json`.

---

## Signal Edges

These edges close the feedback loop from runtime back to intent.

```
Node    ──emits──────→ Signal
Service ──emits──────→ Signal
Signal  ──impacts────→ Goal
Signal  ──impacts────→ Feature
Signal  ──indicates──→ Node
```

| Edge | From | To | Cardinality | Semantics |
|------|------|----|-------------|-----------|
| `emits` | Node / Service | Signal | 1:N | Runtime entities produce telemetry and events |
| `impacts` | Signal | Goal / Feature | N:M | A signal provides evidence about goal/feature health |
| `indicates` | Signal | Node | N:1 | A signal traces back to its originating node |

**Constraint:** `impacts` edges are established through SignalBindings on Goals and correlation rules on Features. They are not automatic — HoneyHub's interpretation layer determines which signals matter for which goals.

---

## Governance Edges

These edges enforce architectural decisions across the graph.

```
ADR ──governs_node──→ Node
ADR ──governs_repo──→ Repo
ADR ──governs_edge──→ Relationship
Feature ──triggers──→ ADR
```

| Edge | From | To | Cardinality | Semantics |
|------|------|----|-------------|-----------|
| `governs_node` | ADR | Node | N:M | An ADR constrains how a node behaves or evolves |
| `governs_repo` | ADR | Repo | N:M | An ADR constrains how a repo operates |
| `governs_edge` | ADR | Relationship | N:M | An ADR constrains a relationship type (e.g., dependency rules) |
| `triggers` | Feature | ADR | N:M | A feature that crosses boundaries may require a new ADR |

**Constraint:** Governance edges are bidirectionally queryable. Given a Node, you can find all ADRs that govern it. Given an ADR, you can find all entities it constrains.

---

## Execution State Edges

These edges track the materialization of plans into external systems.

```
Task ──materialized_as──→ GitHubIssue
Task ──resolved_by──────→ PullRequest
```

| Edge | From | To | Cardinality | Semantics |
|------|------|----|-------------|-----------|
| `materialized_as` | Task | GitHubIssue | 1:1 | The task has been dispatched as a GitHub Issue |
| `resolved_by` | Task | PullRequest | 1:N | The task was completed through one or more PRs |

**Constraint:** These edges are write-once for `materialized_as` (a task is dispatched exactly once) and append-only for `resolved_by` (a task may require multiple PRs, e.g., implementation + follow-up fix).

---

## Full Graph Visualization

```
Project
  │ contains
  ▼
Goal ◄──────────────── Signal (impacts)
  │ decomposes_into        ▲ emits
  ▼                        │
Feature ──affects────→ Node/Repo
  │ triggers               │ depends_on
  ▼                        ▼
ADR ──governs────────→ Node/Repo
  │
Feature
  │ implemented_by
  ▼
Task ──targets───────→ Repo
  │ assigned_to            │ produces
  ▼                        ▼
Agent ──operates_in──→ Repo → Node → Service
  │                                     │
  └─── (executes via AgentKit) ─────────┘
```

---

## Edge Index

| Edge | From | To | Direction | Category |
|------|------|----|-----------|----------|
| `contains` | Project | Goal | → | Decomposition |
| `decomposes_into` | Goal | Feature | → | Decomposition |
| `implemented_by` | Feature | Task | → | Decomposition |
| `depends_on` | Task | Task | → | Decomposition |
| `targets` | Task | Repo | → | Targeting |
| `assigned_to` | Task | Agent | → | Targeting |
| `affects_repo` | Feature | Repo | → | Targeting |
| `affects_node` | Feature | Node | → | Targeting |
| `operates_in` | Agent | Repo | → | Targeting |
| `produces` | Repo | Node | → | Production |
| `depends_on` | Node | Node | → | Production |
| `deploys_as` | Node | Service | → | Production |
| `emits` | Node/Service | Signal | → | Signal |
| `impacts` | Signal | Goal/Feature | → | Signal |
| `indicates` | Signal | Node | → | Signal |
| `governs_node` | ADR | Node | → | Governance |
| `governs_repo` | ADR | Repo | → | Governance |
| `governs_edge` | ADR | Relationship | → | Governance |
| `triggers` | Feature | ADR | → | Governance |
| `materialized_as` | Task | GitHubIssue | → | Execution |
| `resolved_by` | Task | PullRequest | → | Execution |
