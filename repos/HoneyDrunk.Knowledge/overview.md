# HoneyDrunk.Knowledge — Overview

**Sector:** AI  
**Version:** TBD  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Knowledge`

## Purpose

External knowledge ingestion and retrieval for the Grid. Ingests documents, web content, API responses, and structured data, then makes them retrievable through RAG pipelines and structured knowledge surfaces.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Knowledge.Abstractions` | Abstractions | Zero-dependency knowledge contracts |
| `HoneyDrunk.Knowledge` | Runtime | Ingestion, chunking, retrieval orchestration |
| `HoneyDrunk.Knowledge.Providers.AzureAISearch` | Provider | Azure AI Search backend |
| `HoneyDrunk.Knowledge.Providers.PostgresVector` | Provider | PostgreSQL pgvector backend |
| `HoneyDrunk.Knowledge.Providers.InMemory` | Provider | In-memory backend for testing |

## Key Interfaces

- `IKnowledgeStore` — Ingest, query, delete sources
- `IDocumentIngester` — Parse and chunk documents
- `IRetrievalPipeline` — Query → ranked results with attribution
- `IKnowledgeSource` — Metadata about an ingested source (origin, version, last updated)

## Design Notes

Supports two retrieval paradigms: traditional RAG (chunk/embed/vector search) and structured knowledge surfaces (LLM-maintained markdown with auto-indexes, used by Lore). Source attribution is mandatory — every retrieved chunk traces back to its source document and version. Knowledge is versioned; retrieval reflects the current state of ingested sources.
