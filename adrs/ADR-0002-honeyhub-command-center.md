# ADR-0002: Architecture Repo as Agent Command Center

**Status:** Accepted  
**Date:** 2026-03-22  
**Deciders:** HoneyDrunk Studios  
**Sector:** Meta

## Context

HoneyDrunk Studios uses AI agents extensively for code generation, issue creation, PR reviews, and cross-repo coordination. Without a centralized source of truth, agents lack context about:

- Which repos exist and what they own
- What invariants must be preserved
- How to route different types of work
- What the current priorities and active initiatives are

This leads to agents generating work that violates boundaries, duplicates effort, or targets the wrong repo.

## Decision

The `HoneyDrunk.Architecture` repository serves as the **command center** ("Agent HQ") for all agentic workflows. It contains:

1. **Constitution** — Immutable identity, terminology, invariants, and sector structure
2. **Catalogs** — Machine-readable JSON registries of Nodes, modules, services, relationships, and signals
3. **ADRs** — Architecture Decision Records for significant design choices
4. **Routing** — Rules that agents use to determine which repo handles which type of work
5. **Initiatives** — Current priorities, active work, and roadmap
6. **Issue Templates** — Structured templates for generating GitHub Issues
7. **Repo Context** — Per-repo overviews, boundaries, invariants, and integration points
8. **Copilot Instructions** — Global agent behavior rules
9. **Generated Artifacts** — Output directory for issue packets, site-sync packets, and ADR drafts

Agents read this repo as context before performing cross-repo operations.

## Consequences

- All cross-repo architectural decisions start as discussions in this repo
- Agents can be pointed at this repo to understand the full Grid topology
- Issue generation is templated and consistent across all repos
- Breaking changes are caught earlier because invariants are centralized
- The repo must be kept up-to-date — stale catalogs or routing rules degrade agent quality

## Alternatives Considered

- **Embedding context in each repo**: Each repo already has copilot-instructions.md, but these are repo-scoped. Cross-repo coordination needs a central view.
- **Using a database or API**: Over-engineered for the current scale. Flat files in a Git repo are version-controlled, diffable, and agent-readable.
- **Wiki-based approach**: Wikis lack structure and are harder for agents to parse. JSON catalogs and Markdown with frontmatter are more machine-friendly.
