# HoneyDrunk.Knowledge — Boundaries

## What Knowledge Owns

- Document ingestion — ingest files, web content, API responses, structured data
- Chunking and embedding — split documents into retrievable units, generate embeddings via HoneyDrunk.AI
- Retrieval pipelines (RAG) — given a query, find relevant knowledge chunks
- Source attribution — every retrieved chunk traces back to its source document and version
- Knowledge versioning — documents can be updated; retrieval reflects the current version
- Structured knowledge maintenance — support for LLM-maintained indexes and wiki surfaces

## What Knowledge Does NOT Own

- **Embedding generation** — Delegates to HoneyDrunk.AI for embedding calls.
- **Agent memory** — What agents remember from their executions belongs in HoneyDrunk.Memory.
- **Wiki compilation logic** — The LLM-driven compilation pipeline belongs in HoneyDrunk.Lore. Knowledge provides the infrastructure Lore builds on.
- **Agent lifecycle** — How agents run belongs in HoneyDrunk.Agents.
- **Persistence infrastructure** — Low-level database patterns belong in HoneyDrunk.Data.

## Boundary with Memory

Knowledge is externally sourced, objective information (documents, APIs, datasets). Memory is agent-generated, subjective context (what an agent learned or decided). They share embedding infrastructure through HoneyDrunk.AI but are semantically and operationally distinct.

## Boundary with Lore

Knowledge provides ingestion infrastructure, storage, and retrieval pipelines. Lore is an application that *uses* Knowledge to build a living, LLM-compiled wiki. Knowledge doesn't know about wikis or markdown compilation — it knows about documents, chunks, and queries.

## Boundary Decision Tests

Before adding something to Knowledge, ask:

1. Is this about **ingesting, storing, or retrieving external information**? → Knowledge
2. Is this about **what an agent remembers**? → Memory
3. Is this about **compiling a wiki from ingested data**? → Lore
4. Is this about **generating embeddings**? → AI (Knowledge delegates to AI)
