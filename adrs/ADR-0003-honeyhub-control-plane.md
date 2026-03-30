# ADR-0003: HoneyHub as Organizational Control Plane

**Status:** Proposed
**Date:** 2026-03-30
**Deciders:** HoneyDrunk Studios
**Sector:** Meta
**Supersedes:** Partially extends ADR-0002 (Architecture Repo as Agent Command Center)

## Context

ADR-0002 established the Architecture repo as the command center for agentic workflows — a centralized source of truth containing catalogs, routing rules, ADRs, and per-repo context. This solved the problem of agents lacking context when operating across repos.

But Agent HQ is static. It answers "what exists" and "what are the rules," but cannot answer:
- "What are we trying to achieve?"
- "What work is planned, in-flight, or blocked?"
- "How does this runtime signal relate to the goal that motivated the change?"
- "What should happen next?"

As the Grid grows beyond the Core sector and AI agents take on more autonomous roles, the gap between static context and dynamic orchestration becomes a bottleneck. Work is planned in the developer's head, tracked across disconnected GitHub Issues, and runtime feedback requires manual correlation.

A solo developer managing 11+ repos with AI agent collaborators needs a system that holds organizational state, not just architectural state.

## Decision

**HoneyHub is a control plane — not a documentation system, not a project tracker, not a dashboard.**

It is a graph-driven orchestration system with four layers:

1. **Integration layer** — adapters for GitHub, Pulse, Actions, and the Architecture repo's catalogs
2. **Knowledge graph** — entities (Projects, Goals, Features, Tasks, Agents, Repos, Nodes, ADRs, Signals) connected by typed relationships
3. **Orchestration engine** — decomposes goals into features and tasks, sequences work, assigns agents, interprets signals, adjusts plans
4. **Projection layer** — generates views (roadmaps, PRDs, execution plans, impact reports) from the graph

HoneyHub connects the full lifecycle:
```
Goal → Feature → Task → Code → Deployment → Signal → Goal
```

### Relationship to Architecture Repo

The Architecture repo remains the source of truth for static Grid topology — catalogs, ADRs, invariants, boundaries. HoneyHub consumes this data via the integration layer. It does not replace the Architecture repo; it adds a dynamic orchestration layer on top of it.

ADR-0002 is not superseded — it is extended. The Architecture repo continues to serve as Agent HQ for static context. HoneyHub adds planning, sequencing, signal interpretation, and feedback loops.

### Relationship to AgentKit

HoneyHub decides *what* to do and *when*. AgentKit decides *how*. HoneyHub produces task assignments. AgentKit executes them. They communicate indirectly through GitHub Issues and PRs, not through runtime APIs.

### Relationship to Pulse

Pulse collects and routes telemetry. HoneyHub interprets it. Pulse never reasons about product intent. HoneyHub never collects raw telemetry. The boundary is: Pulse owns the data pipeline, HoneyHub owns the meaning layer.

## Consequences

### Positive

- **Intent is explicit.** Goals and their decomposition are stored in a queryable graph, not in the developer's working memory.
- **Cross-repo orchestration is systematic.** Work is sequenced with dependency awareness, not ad-hoc.
- **Feedback loops close.** Runtime signals correlate to the goals that motivated the change, surfacing regressions against intent — not just against SLOs.
- **Agents gain planning context.** An agent receiving a task from HoneyHub knows which Goal it serves, which Feature it implements, and which ADRs constrain it.
- **Projections replace manual reporting.** Roadmaps, PRDs, and status reports are derived from the graph, not authored separately.

### Negative

- **Complexity.** HoneyHub is a non-trivial system. It requires its own development effort and maintenance.
- **Single point of planning.** If HoneyHub's graph state becomes corrupted or stale, orchestration degrades. Mitigation: the graph is reconstructible from GitHub state and catalogs.
- **Interpretation is opaque.** Signal-to-goal correlation involves judgment (thresholds, time windows). Misinterpretation could trigger unnecessary re-planning. Mitigation: human override at every decision point.

## Alternatives Considered

### Notion/Linear/Jira-style project management

These tools model work as flat lists, boards, or trees. They do not:
- Connect tasks to runtime telemetry
- Enforce architectural constraints (ADRs) during planning
- Decompose goals based on knowledge of the actual codebase graph
- Produce machine-readable task assignments for AI agents

They are consumer-facing productivity tools. HoneyHub is a system-level control plane. The difference is that HoneyHub's planning is informed by the topology of the Grid, not by human-curated card walls.

### Extending Architecture repo with more static files

Adding `goals.json`, `features.json`, `tasks.json` to the catalogs would provide storage but no orchestration. The Architecture repo is a knowledge base, not an engine. Sequencing, dependency resolution, signal correlation, and plan adjustment require active computation — not more flat files.

### Building orchestration into AgentKit

AgentKit's job is agent runtime: tool access, memory, safety, context. Adding orchestration to AgentKit would violate single responsibility and couple planning logic to execution logic. An agent should not decide what the organization needs — it should execute what the control plane assigns.

### No control plane (keep doing it manually)

This works while the Grid is small and the developer can hold the full state in memory. It does not scale to:
- Multiple active initiatives across sectors
- Agents operating autonomously across repos
- Runtime feedback that needs systematic correlation to intent

The cost of building HoneyHub now is less than the cost of coordination failures as the Grid grows.

## Future Implications

- HoneyHub's knowledge graph may become the authoritative source for Grid topology, absorbing what today lives in static catalogs. This evolution should be deliberate, not accidental — catalogs remain authoritative until explicitly migrated.
- Multi-agent coordination patterns (agent A's output feeds agent B's input) will be orchestrated through HoneyHub's task dependency graph.
- The projection layer opens the door to a developer-facing UI (the "HoneyHub dashboard") that visualizes the full Goal → Signal lifecycle. This is a future surface, not a current requirement.
- As the Grid expands into Creator, Market, and HoneyPlay sectors, HoneyHub's knowledge graph becomes the only system capable of reasoning about cross-sector impact.
