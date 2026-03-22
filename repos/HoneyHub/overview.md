# HoneyHub (HoneyDrunk.Architecture) — Overview

**Sector:** Meta  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Architecture`

## Purpose

The command center ("Agent HQ") for the HoneyDrunk Grid. Contains architecture decisions, catalogs, routing rules, issue templates, and per-repo context. This is not a code repo — it is a knowledge repo that agents and humans use for coordination.

## What It Contains

| Directory | Purpose |
|-----------|---------|
| `/constitution/` | Manifesto, terminology, invariants, sectors |
| `/catalogs/` | Machine-readable JSON registries |
| `/adrs/` | Architecture Decision Records |
| `/routing/` | Agent routing rules (request types, repo discovery, execution, site sync) |
| `/initiatives/` | Active work, current focus, roadmap |
| `/issues/templates/` | Structured templates for issue generation |
| `/repos/` | Per-repo context (overview, boundaries, invariants, integration points, active work) |
| `/copilot/` | Agent behavior rules |
| `/generated/` | Output directory for generated artifacts |

## How Agents Use It

1. Read `/constitution/` to understand the Grid's identity and rules
2. Query `/catalogs/` to find Nodes, packages, relationships
3. Follow `/routing/` to determine which repo handles a request
4. Load `/repos/{name}/` for repo-specific context before generating work
5. Use `/issues/templates/` to create structured issue packets
6. Write outputs to `/generated/`
