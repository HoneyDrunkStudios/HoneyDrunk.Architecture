# HoneyDrunk.Lore — Integration Points

How Lore connects to the rest of the Grid. Every item here is **planned** — Lore is flat-file v1 and has no live integrations yet. Every row becomes a canary boundary once the corresponding upstream Node ships.

## Consumes (planned)

| Node | Contract | Purpose | Status |
|------|----------|---------|--------|
| **Knowledge** | `IDocumentIngester` | Replace flat-file ingest of `raw/` with a real document pipeline (parse, chunk, attribute) | Planned — `Knowledge` is Seed |
| **Knowledge** | `IRetrievalPipeline` | Replace keyword scan over `wiki/` with hybrid retrieval (BM25 + embeddings + graph) | Planned — `Knowledge` is Seed |
| **Knowledge** | `IKnowledgeStore` | Persist wiki content as a versioned knowledge store rather than raw markdown files | Planned — `Knowledge` is Seed |
| **Agents** | `IAgent`, `IAgentExecutionContext` | Run compile / lint / query as named, lifecycle-managed agents on the Agents runtime | Planned — `Agents` is Seed |
| **AI** | `IChatClient` | Inference for ingest synthesis, query answering, and lint reasoning | Planned — `AI` is Seed |
| **Flow** | `IWorkflowEngine` | Orchestrate multi-step compile passes (ingest → consolidate → resolve contradictions → rebuild indexes) as durable workflows | Planned — `Flow` is Seed |

Until those nodes exist, the operations defined in `HoneyDrunk.Lore/CLAUDE.md` are executed directly by Claude Code sessions and (eventually) a `CronCreate` scheduled trigger. There is no compile-time or runtime dependency on any Grid Node today.

## Exposes

Lore exposes no contracts. It is a leaf application — it consumes Nodes, it does not provide them.

## Canary Coverage Required (when delegations land)

- `Lore.Canary` → Knowledge: ingest a known source, verify a `wiki/` page is produced with attributable chunks
- `Lore.Canary` → AI: run a query, verify `IChatClient` returns content with token-count telemetry
- `Lore.Canary` → Agents: run a compile pass as a named agent, verify lifecycle hooks fire
- `Lore.Canary` → Flow: run a multi-step compile workflow, verify state persists across a simulated restart

## Conversion Plan

The flat-file v1 keeps working while delegation lands incrementally. Order is dictated by upstream readiness, not by Lore-side priority:

1. **AI Live** → swap inline LLM calls in agent prompts for `IChatClient` invocation
2. **Knowledge Live** → swap flat `raw/` directory walk for `IDocumentIngester`; swap `wiki/` keyword scan for `IRetrievalPipeline`
3. **Agents Live** → register compile / lint / query as `IAgent` implementations
4. **Flow Live** → wrap multi-step compile in `IWorkflowEngine` for durability and human-in-the-loop checkpoints

`CLAUDE.md` stays the single source of truth for operation semantics throughout. The verbs do not change.
