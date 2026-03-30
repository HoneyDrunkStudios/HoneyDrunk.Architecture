# HoneyHub — Boundaries

## What HoneyHub Owns

### Intent Modeling
- Project and Goal lifecycle — defining what the Grid should achieve
- Feature decomposition — breaking goals into design-level capabilities
- Success criteria — observable conditions that prove goal completion
- Signal bindings — mapping telemetry types to goals they measure

### Work Planning
- Task decomposition — breaking features into repo-scoped, executable units
- Dependency resolution — computing execution order across tasks
- Parallelism identification — determining what can run concurrently
- Task dispatch — generating GitHub Issues from planned tasks

### Agent Coordination
- Agent registry — which agents exist, what they can do, where they operate
- Task assignment — matching tasks to agents by capability and repo authorization
- Execution tracking — observing task state through GitHub signals

### Signal Interpretation
- Correlating Pulse telemetry to Goals, Features, and Nodes
- Evaluating whether signals indicate progress, regression, or neutral state
- Triggering plan adjustments based on runtime evidence

### Knowledge Graph
- All entities: Project, Goal, Feature, Task, Agent, Repo, Node, ADR, Signal
- All typed relationships between entities
- Lifecycle state transitions for all entities

### Projections
- Roadmaps, PRDs, execution plans, impact reports, progress summaries
- All views are derived from the graph — stateless, re-derivable

## What HoneyHub Reads But Does Not Own

| Data | Owner | Access Pattern |
|------|-------|----------------|
| Node/service/module registries | Architecture repo catalogs | Read on change |
| Node dependency graph | Architecture repo `relationships.json` | Read on change |
| ADR content and metadata | Architecture repo `/adrs/` | Index metadata |
| Repo boundaries | Architecture repo `/repos/*/boundaries.md` | Read on change |
| Issue and PR state | GitHub | Webhooks / polling |
| CI/CD results | HoneyDrunk.Actions | Workflow event webhooks |
| Telemetry signals | Pulse pipeline | Subscribe to signal stream |

## What HoneyHub Does NOT Own

- **Agent runtime** — AgentKit owns execution: tool access, memory, safety, context propagation
- **Telemetry collection** — Pulse owns the pipeline from emission to sink routing
- **Code** — Individual repos own all application and library code
- **CI/CD pipelines** — HoneyDrunk.Actions owns workflow definitions
- **Secrets and configuration** — Vault owns secret storage and provider abstraction
- **Authentication** — Auth owns token validation and policy evaluation
- **Transport infrastructure** — Transport owns messaging, envelopes, brokers
- **Static Grid topology** — Architecture repo owns catalogs, invariants, routing rules
- **Repo-internal documentation** — Each repo owns its own docs
- **ADR authorship** — Architecture repo's review process governs ADR acceptance (HoneyHub may generate drafts)

## Boundary Rules

1. **HoneyHub plans. Repos execute.** A task created by HoneyHub becomes a GitHub Issue. From that point, the repo's development workflow governs.
2. **HoneyHub interprets. Pulse collects.** Pulse never reasons about intent. HoneyHub never touches raw telemetry.
3. **HoneyHub assigns. AgentKit runs.** HoneyHub produces task assignments. AgentKit manages agent execution. They communicate through GitHub artifacts, not runtime APIs.
4. **HoneyHub reads catalogs. Architecture repo writes them.** HoneyHub indexes catalog data into its knowledge graph but never modifies catalog files directly.
5. **HoneyHub suggests ADRs. Architecture repo accepts them.** When a feature crosses architectural boundaries, HoneyHub generates an ADR draft packet. The Architecture repo's review process decides acceptance.
