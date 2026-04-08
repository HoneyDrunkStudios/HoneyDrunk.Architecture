# HoneyDrunk.Agents — Boundaries

## What Agents Owns

- Agent lifecycle management (register → initialize → execute → complete → decommission)
- Execution context — scoped per invocation with GridContext, agent identity, memory references, capability bindings
- Tool interfaces — `IToolInvoker` contract for how agents invoke capabilities
- Memory interfaces — `IAgentMemory`, `IMemoryScope` (contracts only, not storage implementations)
- Orchestration hooks — extension points for Flow to coordinate multi-agent sequences
- Agent identity — `AgentId`, capability declarations, authorization scope

## What Agents Does NOT Own

- **Model provider integrations** — Inference and model routing belong in HoneyDrunk.AI.
- **Tool/capability definitions** — Tool schemas, discovery, and permissioning belong in HoneyDrunk.Capabilities.
- **Memory storage** — Persistence, indexing, and summarization belong in HoneyDrunk.Memory.
- **Workflow sequencing** — Multi-step pipelines and compensation belong in HoneyDrunk.Flow.
- **Safety controls** — Approval gates, circuit breakers, and cost limits belong in HoneyDrunk.Operator.
- **Knowledge retrieval** — Document ingestion and RAG belong in HoneyDrunk.Knowledge.

## Boundary Decision Tests

Before adding something to Agents, ask:

1. Is this about **agent identity, lifecycle, or execution context**? → Agents
2. Is this about **calling a model**? → AI
3. Is this about **what tools exist or who can use them**? → Capabilities
4. Is this about **persisting what an agent learned**? → Memory
5. Is this about **coordinating multiple agents**? → Flow
6. Is this about **whether an agent is allowed to do something**? → Operator
