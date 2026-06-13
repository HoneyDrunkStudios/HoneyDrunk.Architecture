---
name: Chore
type: chore
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta"]
dependencies: []
wave: 1
initiative: honeydrunk-lore-bringup
node: honeydrunk-architecture
---

# Chore: Catalog registration â€” HoneyDrunk.Lore

## Summary
Register `HoneyDrunk.Lore` in the Architecture catalogs and routing rules so the Grid is aware of it. The repo now exists (`HoneyDrunkStudios/HoneyDrunk.Lore`) and is being scaffolded. This registration makes it visible to agents doing routing, dependency walks, and graph queries.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
Until Lore is in the catalogs and routing rules, agents will not know it exists. Routing rules will miss it, the node graph will not include it, and future scope passes will have no machine-readable entry point. Registration is small, independent, and unblocks all downstream work.

## Proposed Implementation

### `catalogs/nodes.json`
Append a new entry matching the style of existing nodes:
```json
{
  "id": "honeydrunk-lore",
  "type": "application",
  "name": "HoneyDrunk.Lore",
  "public_name": "HoneyDrunk.Lore",
  "short": "LLM-compiled living knowledge wiki",
  "description": "Flat-file wiki maintained by LLMs. Ingests raw sources, compiles structured markdown, self-maintains indexes and backlinks, answers queries, and runs health checks. Consumed by agents and the solo developer as the ecosystem's compiled research surface.",
  "sector": "Meta",
  "signal": "Seed",
  "cluster": "knowledge",
  "tags": ["knowledge", "wiki", "lore", "ai", "flat-file", "obsidian"],
  "links": { "repo": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Lore" }
}
```
Note: type is `application` not `node` â€” Lore is an application that consumes nodes, per `repos/HoneyDrunk.Lore/boundaries.md`.

### `catalogs/relationships.json`
Add planned dependency edges (use `planned` status since the nodes don't exist yet):
- `honeydrunk-lore` â†’ `honeydrunk-knowledge` (planned: Lore will delegate ingestion/retrieval to Knowledge)
- `honeydrunk-lore` â†’ `honeydrunk-agents` (planned: Lore will run compile/lint agents on Agents runtime)
- `honeydrunk-lore` â†’ `honeydrunk-ai` (planned: Lore will delegate inference to AI)
- `honeydrunk-lore` â†’ `honeydrunk-flow` (planned: Lore will use Flow for multi-step compile workflows)

Check that `planned` edges are supported by the existing schema â€” if not, add a `status` field or use a comment convention that matches how other future edges are marked.

### `routing/repo-discovery-rules.md`
Add a keyword mapping row for Lore:
```
| lore, wiki, raw/, ingest, compile, lint, knowledge surface, living wiki | HoneyDrunk.Lore |
```

### `repos/HoneyDrunk.Lore/` stubs
The `repos/HoneyDrunk.Lore/` directory already exists in Architecture with `overview.md`, `boundaries.md`, and `invariants.md`. Verify they exist and are complete. Add any missing files to match the standard set:
- `active-work.md` â€” stub pointing at HoneyDrunk.Lore#1 (scaffold issue) as the active work
- `integration-points.md` â€” stub noting that integration points are planned (Knowledge, Agents, AI, Flow) but not yet wired

## Acceptance Criteria
- [ ] `catalogs/nodes.json` has a new entry for `honeydrunk-lore`, JSON valid, style matches existing entries
- [ ] `catalogs/relationships.json` has planned dependency edges for Knowledge, Agents, AI, and Flow
- [ ] `relationships.json` remains a valid DAG (invariant 4) â€” planned edges to not-yet-existing nodes are acceptable if marked as planned
- [ ] `routing/repo-discovery-rules.md` has the Lore keyword row
- [ ] `repos/HoneyDrunk.Lore/active-work.md` exists
- [ ] `repos/HoneyDrunk.Lore/integration-points.md` exists

## Affected Packages
None â€” catalog JSON and docs only.

## Boundary Check
- [x] Lore registered as `application` not `node` (per boundaries.md: Lore is an application, not infrastructure)
- [x] Planned edges are marked as planned â€” no false claims about current wiring
- [x] No code changes to any other repo

## Dependencies
None. Can be done in parallel with HoneyDrunk.Lore#1 (scaffold).

## Labels
`chore`, `tier-2`, `meta`

## Agent Handoff

**Objective:** Register HoneyDrunk.Lore in Architecture catalogs, routing rules, and repo stubs.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Architecture`, branch from `main`

**Context:**
- `HoneyDrunk.Lore` is a new flat-file wiki repo (just created, being scaffolded)
- It is an application that consumes nodes â€” not a node itself (see `repos/HoneyDrunk.Lore/boundaries.md`)
- Sector: Meta. Signal: Seed. Cluster: knowledge.
- The repo exists at `HoneyDrunkStudios/HoneyDrunk.Lore`
- Flat-file-first: no .NET code yet; will eventually delegate to Knowledge/Agents/AI/Flow

**Acceptance Criteria:**
- [ ] As listed above

**Constraints:**
- Match the JSON style of existing entries in `nodes.json` exactly
- Do not fabricate relationship edges beyond what `boundaries.md` supports (Knowledge, Agents, AI, Flow)
- Planned edges must be clearly marked as planned â€” do not imply current wiring
- `relationships.json` must remain a DAG after additions (invariant 4)

**Key Files:**
- `catalogs/nodes.json`
- `catalogs/relationships.json`
- `routing/repo-discovery-rules.md`
- `repos/HoneyDrunk.Lore/active-work.md` (new)
- `repos/HoneyDrunk.Lore/integration-points.md` (new)