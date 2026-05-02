# HoneyDrunk.Lore — Overview

**Sector:** Meta  
**Version:** TBD  
**Framework:** Markdown (flat-file v1; delegates to Grid Nodes when they ship — Lore itself never adds .NET code)  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Lore`

## Purpose

The Hive's living knowledge surface. An LLM-compiled wiki that ingests raw sources, compiles them into structured markdown, self-maintains indexes and backlinks, runs health checks, and answers complex queries. The human rarely edits the wiki directly — it is the domain of the LLM.

## Structure

| Directory | Purpose |
|-----------|---------|
| `raw/` | Source documents — articles, papers, repos, datasets, images |
| `wiki/` | LLM-compiled structured markdown — concept articles, summaries, indexes |
| `output/` | Query results — rendered markdown, slide shows (Marp), visualizations |
| `tools/` | CLI tools for search, ingestion, and wiki maintenance |

## How It Works

1. **Ingest** — Raw sources are collected into `raw/` (web clipper, manual drops, API pulls)
2. **Compile** — An LLM agent reads `raw/` and incrementally compiles `wiki/` with summaries, concept articles, backlinks, and auto-maintained indexes
3. **Query** — Ask the LLM complex questions; it researches across the wiki and returns rendered outputs
4. **Lint** — Health check agents find inconsistencies, impute missing data, suggest new article candidates
5. **Grow** — Query outputs are filed back into the wiki, compounding knowledge with every interaction

## Design Notes

Lore is an **application** that consumes AI sector Nodes — it is not infrastructure itself. It uses Knowledge for ingestion/retrieval, Agents for compilation and Q&A, AI for inference, and Flow for multi-step compilation workflows. Viewable in Obsidian as a living, navigable knowledge surface.

Unlike Architecture (which holds governance artifacts like ADRs and boundaries), Lore holds compiled research knowledge — everything the ecosystem has learned from external sources and internal exploration.
