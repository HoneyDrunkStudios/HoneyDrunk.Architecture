# HoneyDrunk.Memory — Overview

**Sector:** AI  
**Version:** TBD  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Memory`

## Purpose

Persistent and contextual memory system for Grid agents. Provides short-term (conversation-scoped) and long-term (cross-execution) memory with scoped isolation, indexing, and automatic summarization.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Memory.Abstractions` | Abstractions | Zero-dependency memory contracts |
| `HoneyDrunk.Memory` | Runtime | Memory management, indexing, summarization |
| `HoneyDrunk.Memory.Providers.SqlServer` | Provider | SQL Server storage backend |
| `HoneyDrunk.Memory.Providers.CosmosDB` | Provider | Cosmos DB storage backend |
| `HoneyDrunk.Memory.Providers.InMemory` | Provider | In-memory backend for testing |

## Key Interfaces

- `IMemoryStore` — Write, read, search, delete memories
- `IMemoryScope` — Scoped memory access (agent sees only its authorized memories)
- `IMemorySummarizer` — Compress memories beyond a threshold

## Design Notes

Memory is agent-subjective — what *this agent* remembers from *its executions*. This is distinct from Knowledge (externally sourced, objective information). Access control differs: an agent's memory is private by default. Memory uses embeddings from HoneyDrunk.AI for similarity search but owns its own storage lifecycle (summarization, forgetting, compression).
