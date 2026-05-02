# HoneyDrunk.Lore — Active Work

**Signal:** Seed — flat-file v1 in scaffold.

## Current Status

Active scaffolding under the `honeydrunk-lore-bringup` initiative. The repo exists at `HoneyDrunkStudios/HoneyDrunk.Lore` with directory layout (`raw/`, `wiki/`, `wiki/indexes/`, `output/`, `tools/`), `CLAUDE.md` schema doc, and `README.md`. No .NET code — Lore is flat-file-first by design.

## Active Issues

| Issue | Title | Status |
|-------|-------|--------|
| [HoneyDrunk.Lore#1](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/1) | Scaffold: directory structure + CLAUDE.md schema doc | In progress (PR #2) |
| [HoneyDrunk.Lore#2](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/2) | Obsidian vault setup (human-only) | Open |
| [HoneyDrunk.Lore#3](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/3) | Scheduled ingest: daily agent to auto-compile `raw/` sources | Open |
| [HoneyDrunk.Lore#4](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/4) | sourcing-playbook.md — content curation guide | Open |
| [HoneyDrunk.Lore#5](https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore/issues/5) | OpenClaw setup + Lore sourcing skill | Open |

## On-Deck Work (after scaffold lands)

- First real ingest pass — clip a handful of articles, let the agent compile, eyeball the output for style baseline
- Establish a wiki page style guide once a few real pages exist (so future ingests have an example to match)
- Wire scheduled ingest agent (HoneyDrunk.Lore#3) once Obsidian vault is producing daily input
- Lint-pass cadence: weekly initially, scale based on volume

## Initiative

Part of the **honeydrunk-lore-bringup** initiative. Sequencing: scaffold (#1) → catalog registration (this packet) → Obsidian (#2) → sourcing playbook (#4) → OpenClaw (#5) → scheduled ingest (#3).

## Conversion Path

Lore is flat-file v1. When `HoneyDrunk.Knowledge` and `HoneyDrunk.Agents` reach Live, ingest delegates to `IDocumentIngester`, retrieval delegates to `IRetrievalPipeline`, and `CLAUDE.md` becomes agent configuration rather than the implementation. No code rewrite required — the verbs (ingest, compile, query, lint) are stable.
