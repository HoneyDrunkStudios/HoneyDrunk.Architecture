# HoneyHub — Orchestration Flow

End-to-end flow from product intent through execution to feedback. This describes the system-level sequence of operations, not user-facing workflows.

---

## The Full Cycle

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   ① Define    ② Decompose   ③ Plan   ④ Dispatch   ⑤ Execute │
│   Goal ──────→ Features ───→ Tasks ──→ Issues ────→ Code     │
│                                                      │       │
│   ⑧ Adjust   ⑦ Interpret   ⑥ Observe               │       │
│   Plan ◄────── Signals ◄──── Telemetry ◄─────────────┘       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Goal Definition

**Actor:** Developer (or agent in advisory mode)
**System:** HoneyHub — Orchestration Engine

The developer defines a Goal with:
- A declarative outcome statement
- Rationale for why it matters
- Success criteria expressed as observable system behaviors
- Optional signal bindings (what telemetry indicates progress)

**What happens in the graph:**
- New `Goal` node created, linked to a `Project` via `contains` edge
- Goal enters `Defined` state

**Example:**
```
Goal: "All Core sector nodes emit structured telemetry through Pulse"
Success criteria:
  - Every Node in Core sector has Pulse.Contracts dependency
  - Telemetry sinks receive traces with GridContext enrichment
  - Error rate telemetry emitted for all Transport message handlers
Signal bindings: [telemetry-emitted, health-reported]
```

---

## Phase 2: Feature Decomposition

**Actor:** Orchestration Engine (with developer approval)
**Input:** Goal + Knowledge Graph (repos, nodes, boundaries, ADRs)

The orchestration engine analyzes the goal against the current graph state:

1. **Identify affected nodes** — Query the graph for nodes matching the goal's scope (e.g., all nodes in Core sector)
2. **Identify affected repos** — Resolve nodes to their owning repos
3. **Check architectural constraints** — Query governing ADRs for affected nodes
4. **Decompose into features** — Each discrete capability change becomes a Feature

**What happens in the graph:**
- New `Feature` nodes created, linked to `Goal` via `decomposes_into`
- `affects_repo` and `affects_node` edges established
- If a feature crosses node boundaries or modifies contracts → `triggers` edge to a new ADR draft

**Example decomposition:**
```
Goal: "All Core nodes emit telemetry through Pulse"
  ├─ Feature: "Add Pulse.Contracts dependency to Kernel"
  │    affects: honeydrunk-kernel
  ├─ Feature: "Instrument Transport message pipeline with trace spans"
  │    affects: honeydrunk-transport
  ├─ Feature: "Add telemetry sink configuration to Vault provider operations"
  │    affects: honeydrunk-vault
  └─ Feature: "Define telemetry enrichment contract in Kernel.Abstractions"
       affects: honeydrunk-kernel
       triggers: ADR (new contract in abstractions package)
```

---

## Phase 3: Task Planning

**Actor:** Orchestration Engine
**Input:** Features + repo boundaries + agent capabilities

Each Feature is broken into Tasks. Every Task targets exactly one repo.

1. **Determine task types** — Implementation, test, CI, documentation
2. **Compute dependencies** — Tasks within a feature may depend on each other (e.g., contract first, then implementation). Tasks across features may also have dependencies (e.g., Kernel contract must exist before Transport can consume it).
3. **Identify parallelism** — Tasks with no dependency edges can execute concurrently
4. **Match to agents** — Based on registered agent capabilities and repo authorization

**What happens in the graph:**
- New `Task` nodes created, linked to `Feature` via `implemented_by`
- `targets` edges to repos, `depends_on` edges between tasks
- `assigned_to` edges to agents (or `human`)
- Tasks enter `Pending` state; those with unsatisfied dependencies enter `Blocked`

**Example task plan:**
```
Feature: "Define telemetry enrichment contract in Kernel.Abstractions"
  ├─ Task 1: "Add ITelemetryEnricher interface to Kernel.Abstractions"
  │    repo: HoneyDrunk.Kernel, type: Implementation, depends_on: []
  ├─ Task 2: "Add unit tests for ITelemetryEnricher contract"
  │    repo: HoneyDrunk.Kernel, type: Test, depends_on: [Task 1]
  └─ Task 3: "Update Kernel CHANGELOG and bump minor version"
       repo: HoneyDrunk.Kernel, type: Documentation, depends_on: [Task 2]

Feature: "Instrument Transport message pipeline"
  ├─ Task 4: "Add trace span to MessageDispatcher"
  │    repo: HoneyDrunk.Transport, type: Implementation, depends_on: [Task 1]
  │    (cross-feature dependency: needs the contract from Kernel)
  └─ Task 5: "Add canary test for Transport → Kernel telemetry contract"
       repo: HoneyDrunk.Transport, type: Test, depends_on: [Task 4]
```

**Dependency graph:**
```
Task 1 → Task 2 → Task 3
   └───→ Task 4 → Task 5
```
Tasks 1 executes first. Tasks 2 and 4 can run in parallel after Task 1 completes.

---

## Phase 4: Dispatch

**Actor:** Orchestration Engine → GitHub Adapter
**Input:** Planned tasks ready for execution (no unresolved dependencies)

For each task transitioning from `Blocked` to `Pending` (dependencies satisfied):

1. **Generate issue packet** — Structured GitHub Issue body containing:
   - Task description
   - Upstream context: which Goal and Feature this serves
   - Governing ADRs
   - Acceptance criteria derived from the Feature
   - Dependencies completed (with links to merged PRs)
2. **Create GitHub Issue** — Via GitHub adapter in the target repo
3. **Record materialization** — `materialized_as` edge from Task to GitHubIssue
4. **Notify assignee** — If assigned to an agent, the task assignment is available for AgentKit consumption

**What happens in the graph:**
- Task state: `Pending` → `In Progress`
- `materialized_as` edge created

**Dispatch is incremental.** Tasks are dispatched as their dependencies clear, not all at once. This allows the plan to adjust between phases.

---

## Phase 5: Execution

**Actor:** Agent (via AgentKit) or Developer
**System:** Target repo's CI/CD pipeline

Execution happens entirely outside HoneyHub. The repo owns the process:

1. **Agent/developer reads the GitHub Issue** — Full context is embedded in the issue body
2. **Branch, implement, test** — Standard development workflow
3. **Open PR** — CI runs via HoneyDrunk.Actions workflows
4. **Review and merge** — Repo's review process applies
5. **Version bump** — If applicable, semantic version is updated

**What HoneyHub observes (but does not control):**
- PR opened → Task confirmed `In Progress`
- CI passing/failing → Signals ingested
- PR merged → Task candidate for `Done`
- PR closed without merge → Investigate (may re-plan)

---

## Phase 6: Observation

**Actor:** Integration Layer (GitHub Adapter + Pulse Adapter)
**Input:** GitHub webhooks, Pulse signal stream

Two types of observations flow into HoneyHub:

**Execution signals (from GitHub):**
- Issue closed → check if linked PR was merged
- PR merged → candidate for task completion
- CI failure → signal ingested, correlated to task and feature
- New release tag → version bump signal, catalog update expected

**Runtime signals (from Pulse):**
- Telemetry events correlated by NodeId and time window
- Error rate changes, latency shifts, health check transitions
- Deployment markers that align with specific task completions

**What happens in the graph:**
- New `Signal` nodes created via integration layer
- `emitted_by` edges linked to source Node/Service
- Signals queued for interpretation

---

## Phase 7: Signal Interpretation

**Actor:** Orchestration Engine
**Input:** Correlated signals + Knowledge Graph state

The orchestration engine evaluates signals against active goals and features:

1. **Correlate signal to source** — Which Node/Service emitted this? (`indicates` edge)
2. **Trace to features** — Which active Features affect this Node? (`affects_node` edge, traversed in reverse)
3. **Trace to goals** — Which Goals have SignalBindings matching this signal type? (`measured_by` edge)
4. **Evaluate impact** — Does this signal indicate progress, regression, or neutral state?

**Signal classification:**

| Signal Pattern | Interpretation | Response |
|---------------|---------------|----------|
| Error rate decreased after deployment | Positive — feature improving stability | Update goal progress |
| Latency increased after deployment | Regression — deployment degraded performance | Alert, create investigation task |
| Health check failing for node | Critical — node unhealthy | Escalate, may pause related tasks |
| Build failing in repo | Blocking — execution impediment | Mark task blocked, surface to developer |
| Telemetry appearing for newly instrumented node | Positive — feature delivering expected behavior | Update feature status toward Delivered |

**What happens in the graph:**
- `impacts` edges created between Signal and Goal/Feature
- Feature/Goal status may transition based on accumulated signal evidence
- Investigation tasks may be created if signals indicate regression

---

## Phase 8: Plan Adjustment

**Actor:** Orchestration Engine
**Input:** Interpreted signals + current plan state

Based on signal interpretation and execution state, the orchestration engine adjusts:

**Positive path (things going well):**
- Tasks completing → unblock downstream tasks → dispatch next wave
- Positive signals → update goal progress metrics
- All features delivered + success criteria met → Goal transitions to `Achieved`

**Negative path (regression or failure):**
- CI failure → insert investigation task, block downstream work
- Runtime regression → create investigation task, link to suspected feature
- Task cancelled → re-evaluate feature feasibility, may adjust decomposition
- Repeated failures in a repo → escalate to developer, pause automation

**Re-planning triggers:**
- A new ADR is accepted that changes constraints on in-flight work
- A Node dependency changes (catalog update) that affects task sequencing
- Developer manually adjusts priorities (Goal reordering, Feature rejection)

**What happens in the graph:**
- New tasks inserted, existing tasks cancelled or re-sequenced
- `depends_on` edges updated to reflect new ordering
- Goal/Feature status transitions based on accumulated evidence

---

## Concrete Example: End-to-End

**Scenario:** Developer defines a goal to add outbox-based telemetry to Data node.

```
① Goal: "Data node emits outbox dispatch telemetry through Pulse"
   Success criteria: Outbox dispatcher emits trace spans with GridContext

② Decomposition:
   Feature A: "Add trace instrumentation to OutboxDispatcher"
     affects: honeydrunk-data
   Feature B: "Add Pulse.Contracts dependency to Data"
     affects: honeydrunk-data
   Feature C: "Verify outbox telemetry in Data.Canary"
     affects: honeydrunk-data

③ Task Plan:
   T1: Add Pulse.Contracts package reference (B) → no deps
   T2: Instrument OutboxDispatcher with trace spans (A) → depends on T1
   T3: Add canary test verifying telemetry emission (C) → depends on T2
   T4: Update CHANGELOG, bump Data minor version → depends on T3

④ Dispatch:
   T1 dispatched as GitHub Issue in HoneyDrunk.Data
   Agent `netrunner` assigned

⑤ Execution:
   netrunner opens PR, adds package reference, CI passes, PR merged

⑥ Observation:
   GitHub webhook: PR merged for T1
   T2 unblocked, dispatched

⑦–⑧ Continue until T4 completes:
   After T4 merges, new Data version deployed
   Pulse signals: trace spans appearing from OutboxDispatcher
   Signal correlated to Goal → success criteria partially met
   If all criteria met → Goal: Achieved
```

---

## Flow Invariants

1. **Tasks are always scoped to one repo.** Cross-repo coordination happens through task dependencies, not through multi-repo tasks.
2. **Dispatch is incremental.** Only tasks with satisfied dependencies are dispatched. The plan can adjust between dispatch waves.
3. **HoneyHub never executes code.** It plans, dispatches, observes, and adjusts. Execution belongs to repos and agents.
4. **Signals close the loop.** Every deployed change produces observable signals. HoneyHub correlates these back to the intent that motivated the change.
5. **Human override is always available.** The developer can reject a decomposition, re-prioritize goals, cancel tasks, or override agent assignments at any point.
