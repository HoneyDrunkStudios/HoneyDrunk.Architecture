# HoneyHub — Domain Model

Core entities (graph nodes) that HoneyHub manages. Each entity has a defined lifecycle, ownership boundary, and role within the knowledge graph.

---

## Project

The top-level organizational container. A Project groups related Goals under a shared identity and timeline.

**Attributes:**
- `ProjectId` — ULID, unique identifier
- `Name` — Human-readable project name
- `StudioId` — Owning studio tenant
- `Status` — Active | Paused | Archived
- `CreatedAt` — Timestamp
- `TargetDate` — Optional deadline

**Lifecycle:**
```
Proposed → Active → Paused → Archived
                 └──────────────┘
```

**Ownership:** HoneyHub. Projects exist only in the knowledge graph. They are not represented in individual repos.

**Boundary:** A Project does not dictate implementation. It frames intent. Repos never reference ProjectId — the relationship is maintained by the graph.

---

## Goal

A measurable outcome the Grid should achieve. Goals are the highest unit of product intent.

**Attributes:**
- `GoalId` — ULID
- `ProjectId` — Parent project
- `Title` — Declarative statement of desired outcome
- `Rationale` — Why this goal matters
- `SuccessCriteria` — Observable conditions that indicate completion
- `Status` — Defined | In Progress | Achieved | Abandoned
- `SignalBindings` — List of Signal types that indicate progress toward this goal

**Lifecycle:**
```
Defined → In Progress → Achieved
                     └→ Abandoned
```

**Ownership:** HoneyHub. Goals are defined and tracked exclusively within the control plane.

**Boundary:** Goals never appear in repo code. They influence work through decomposition into Features and Tasks. A Goal's success criteria reference observable system behaviors — not code artifacts.

---

## Feature

A discrete capability or behavioral change that contributes to a Goal. Features are the unit of design.

**Attributes:**
- `FeatureId` — ULID
- `GoalId` — Parent goal
- `Title` — What the feature enables
- `DesignNotes` — Architectural considerations, constraints
- `AffectedRepos` — List of RepoIds this feature touches
- `AffectedNodes` — List of NodeIds impacted
- `Status` — Proposed | Designed | In Progress | Delivered | Rejected
- `ADRs` — Related Architecture Decision Records

**Lifecycle:**
```
Proposed → Designed → In Progress → Delivered
                                 └→ Rejected
```

**Ownership:** HoneyHub owns the Feature definition. Individual repos own the implementation.

**Boundary:** A Feature may span multiple repos. HoneyHub tracks the cross-repo scope; each repo only sees the Tasks decomposed from the Feature. Features reference ADRs when the change crosses architectural boundaries.

---

## Task

The atomic unit of executable work. A Task is scoped to a single repo and is actionable by a human or an agent.

**Attributes:**
- `TaskId` — ULID
- `FeatureId` — Parent feature
- `RepoId` — Target repository
- `Title` — Imperative description of work
- `Type` — Implementation | Test | CI | Documentation | Investigation
- `DependsOn` — List of TaskIds that must complete first
- `AssignedTo` — Agent identifier or `human`
- `Status` — Pending | Blocked | In Progress | Done | Cancelled
- `GitHubIssueRef` — Optional link to generated GitHub Issue
- `PRRef` — Optional link to implementing PR

**Lifecycle:**
```
Pending → Blocked → In Progress → Done
                               └→ Cancelled
```

**Ownership:** HoneyHub owns Task planning and sequencing. The target repo owns execution.

**Boundary:** Tasks map 1:1 to GitHub Issues when dispatched. HoneyHub generates the issue packet; the repo's CI and review process govern execution. Task completion is determined by PR merge + passing checks, not by manual status update.

---

## Agent

A registered AI agent capable of executing Tasks or participating in orchestration.

**Attributes:**
- `AgentId` — ULID
- `Name` — Human-readable identifier (e.g., `netrunner`, `adr-composer`, `scope`)
- `Capabilities` — List of TaskTypes this agent can handle
- `BoundRepos` — Repos this agent is authorized to operate in
- `ExecutionModel` — Autonomous | Human-in-the-Loop | Advisory
- `Status` — Available | Busy | Offline

**Lifecycle:**
```
Registered → Available ↔ Busy → Decommissioned
                      └→ Offline
```

**Ownership:** HoneyHub owns agent registration and task assignment. AgentKit owns agent runtime execution.

**Boundary:** HoneyHub decides *what* an agent should do and *when*. AgentKit decides *how* the agent executes — tool access, memory, safety constraints, execution context. HoneyHub never invokes agent code directly; it produces task assignments that AgentKit consumes.

---

## Repo

A Git repository in the HoneyDrunkStudios organization that produces one or more Nodes.

**Attributes:**
- `RepoId` — Canonical identifier (e.g., `honeydrunk-kernel`)
- `Name` — Repository name (e.g., `HoneyDrunk.Kernel`)
- `Sector` — Owning sector (Core, Ops, Meta, etc.)
- `Nodes` — List of NodeIds produced by this repo
- `Signal` — Current signal phase (Seed | Awake | Wiring | Live | Echo)
- `Boundaries` — What this repo owns and does not own
- `IntegrationPoints` — How this repo connects to others

**Lifecycle:**
```
Planned → Scaffolded → Active → Mature → Deprecated
```

**Ownership:** Each repo is self-governing for its internal code and CI. HoneyHub references repos as targets for Task dispatch and as sources of execution state.

**Boundary:** HoneyHub reads repo metadata from the Architecture repo's catalogs. It does not manage repo internals — branching strategy, code style, and CI workflows belong to the repo and to HoneyDrunk.Actions.

---

## Node

A library-level building block (NuGet package) that participates in the Grid. The runtime unit.

**Attributes:**
- `NodeId` — Canonical identifier (e.g., `honeydrunk-transport`)
- `RepoId` — Source repository
- `Sector` — Grid sector
- `Version` — Current semantic version
- `Signal` — Signal phase
- `Contracts` — Exposed interfaces
- `Packages` — Published NuGet packages
- `Dependencies` — Other NodeIds this node consumes

**Lifecycle:**
```
Seed → Awake → Wiring → Live → Echo
```

Signal phases are defined by the Grid manifesto and reflect maturity, not deployment status.

**Ownership:** The owning repo. HoneyHub references Node metadata from catalogs and correlates Nodes to Features, Tasks, and Signals.

**Boundary:** HoneyHub never modifies Node state directly. Node version bumps, signal phase changes, and contract updates are repo-level events that flow into HoneyHub as catalog updates.

---

## ADR (Architecture Decision Record)

A recorded architectural decision that governs how Nodes, Repos, or the Grid itself behaves.

**Attributes:**
- `ADRId` — Sequential identifier (e.g., `ADR-0002`)
- `Title` — Decision title
- `Status` — Proposed | Accepted | Deprecated | Superseded
- `Sector` — Affected sector
- `AffectedNodes` — NodeIds governed by this decision
- `AffectedRepos` — RepoIds governed by this decision
- `SupersededBy` — ADRId if replaced

**Lifecycle:**
```
Proposed → Accepted → Deprecated
                   └→ Superseded (by newer ADR)
```

**Ownership:** Architecture repo owns ADR content. HoneyHub indexes ADRs in the knowledge graph and links them to the entities they govern.

**Boundary:** HoneyHub does not author ADRs. It may trigger ADR creation (e.g., when a Feature crosses architectural boundaries) by generating an ADR draft packet, but the Architecture repo's review process governs acceptance.

---

## Signal

A runtime observation from the Grid, typically originating from Pulse telemetry or GitHub event webhooks.

**Attributes:**
- `SignalId` — ULID, unique per signal event
- `Type` — Telemetry | Deployment | BuildResult | HealthCheck | SecurityAlert
- `Source` — NodeId, RepoId, or ServiceId that emitted the signal
- `Severity` — Info | Warning | Error | Critical
- `Timestamp` — When the signal was observed
- `Payload` — Signal-type-specific data (error rates, latency percentiles, build status, etc.)
- `CorrelationId` — Grid correlation ID linking to the originating operation

**Lifecycle:**
```
Emitted → Ingested → Correlated → Acted Upon | Archived
```

**Ownership:** Pulse owns signal collection and transport. HoneyHub owns signal interpretation — correlating signals to Goals, Features, and Nodes to determine meaning and trigger responses.

**Boundary:** HoneyHub does not collect telemetry. It subscribes to signal streams from Pulse and GitHub webhooks. The interpretation layer (signal → impact on goal) is exclusively HoneyHub's domain. Pulse never reasons about product intent.

---

## Entity Summary

| Entity | Owner | Graph Role | Primary Edges |
|--------|-------|------------|---------------|
| Project | HoneyHub | Container | contains → Goal |
| Goal | HoneyHub | Intent | decomposes_into → Feature, measured_by → Signal |
| Feature | HoneyHub | Design | implemented_by → Task, affects → Repo/Node, governed_by → ADR |
| Task | HoneyHub (plan) / Repo (exec) | Execution | targets → Repo, assigned_to → Agent, depends_on → Task |
| Agent | HoneyHub (registry) / AgentKit (runtime) | Executor | executes → Task, operates_in → Repo |
| Repo | Self-governing | Source | produces → Node, receives → Task |
| Node | Owning repo | Runtime | depends_on → Node, emits → Signal, governed_by → ADR |
| ADR | Architecture repo | Governance | governs → Node/Repo, triggered_by → Feature |
| Signal | Pulse (collect) / HoneyHub (interpret) | Feedback | emitted_by → Node, impacts → Goal/Feature |
