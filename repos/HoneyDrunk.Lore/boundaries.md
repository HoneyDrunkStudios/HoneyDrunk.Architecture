# HoneyDrunk.Lore — Boundaries

## What Lore Owns

- Raw source collection and organization (`raw/` directory)
- LLM-compiled wiki surface (`wiki/` directory) — concept articles, summaries, indexes, backlinks
- Query workflows — ask questions, receive rendered outputs (markdown, slides, visualizations)
- Wiki health checks — consistency linting, gap detection, connection discovery
- Output filing — query results fed back into wiki for compound knowledge growth
- CLI tools for search, ingestion, and maintenance

## What Lore Does NOT Own

- **Knowledge infrastructure** — Ingestion pipelines, chunking, embeddings, and RAG belong in HoneyDrunk.Knowledge. Lore is a consumer.
- **Agent runtime** — Agent lifecycle and execution belong in HoneyDrunk.Agents. Lore defines agents that run on that runtime.
- **Inference** — Model calls belong in HoneyDrunk.AI.
- **Workflow execution** — Multi-step compilation pipelines use HoneyDrunk.Flow.
- **Architecture governance** — ADRs, boundaries, invariants, routing rules belong in Architecture.
- **Public website content** — Website data belongs in Studios.

## Boundary with Architecture

Architecture holds **governance** — ADRs, boundaries, invariants, catalogs, routing rules. These are prescriptive documents that constrain how the Grid evolves.

Lore holds **knowledge** — compiled research, external information, accumulated understanding. These are descriptive documents that capture what has been learned.

Architecture tells the Grid what to do. Lore tells the Grid what it knows.

## Boundary Decision Tests

Before adding something to Lore, ask:

1. Is this **compiled knowledge from external sources**? → Lore
2. Is this an **architecture decision or constraint**? → Architecture
3. Is this **public-facing content**? → Studios
4. Is this **ingestion infrastructure** (chunking, embedding, retrieval)? → Knowledge
