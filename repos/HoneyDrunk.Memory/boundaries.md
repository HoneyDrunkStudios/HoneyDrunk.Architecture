# HoneyDrunk.Memory — Boundaries

## What Memory Owns

- Short-term memory — conversation-scoped, cleared after agent execution completes
- Long-term memory — persists across executions, scoped by tenant/project/agent
- Memory storage and retrieval — write, read, search, forget
- Indexing and summarization — compress and index memories for efficient retrieval
- Scoped memory isolation — `TenantId`/`ProjectId`/`AgentId` boundaries enforced at storage level

## What Memory Does NOT Own

- **External knowledge ingestion** — Document ingestion and RAG belong in HoneyDrunk.Knowledge.
- **Embedding generation** — Embedding calls are delegated to HoneyDrunk.AI.
- **Agent lifecycle** — Execution context and identity belong in HoneyDrunk.Agents.
- **Persistence infrastructure** — Low-level database patterns (repositories, unit of work) belong in HoneyDrunk.Data. Memory uses Data's patterns.

## Boundary with Knowledge

Memory is agent-generated context (what the agent learned, decided, experienced). Knowledge is externally sourced information (documents, APIs, structured data). They may share embedding infrastructure via HoneyDrunk.AI but are semantically distinct stores.

## Boundary Decision Tests

Before adding something to Memory, ask:

1. Is this about **what an agent remembers** from its own executions? → Memory
2. Is this about **external documents or data sources**? → Knowledge
3. Is this about **generating embeddings**? → AI (Memory consumes AI for this)
4. Is this about **database infrastructure**? → Data (Memory consumes Data's patterns)
