---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Lore
labels: ["feature", "tier-1", "scaffold"]
dependencies: []
adrs: []
wave: 1
initiative: honeydrunk-lore-bringup
node: honeydrunk-lore
---

# Feature: Lore repo scaffold â€” directory structure + CLAUDE.md schema doc

## Summary
Stand up the foundational structure of `HoneyDrunk.Lore` as a flat-file wiki following the Karpathy LLM-wiki pattern. The repo becomes a living, agent-maintained knowledge surface: humans drop raw sources in, LLMs compile and maintain the wiki, Obsidian visualizes it.

This issue covers everything needed to make the repo operational as a flat-file wiki:
1. **Directory scaffold** â€” `raw/`, `wiki/`, `output/`, `tools/`
2. **CLAUDE.md schema doc** â€” defines the four operations (ingest, compile, query, lint) as instructions the LLM follows when working in this repo
3. **README.md update** â€” explains the repo purpose and how to use it

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Lore`

## Motivation
Lore is the living knowledge surface for The Grid â€” compiled research, external information, and accumulated understanding that agents and the solo developer can query. The flat-file-first implementation lets the wiki be useful immediately without depending on `HoneyDrunk.Knowledge` or `HoneyDrunk.Agents` nodes that do not yet exist.

The CLAUDE.md is the most important artifact: it defines what the LLM does when operating on this wiki. Without it, the repo is just files. With it, any Claude Code session pointed at this repo knows how to ingest a source, compile a wiki page, run a lint pass, or answer a query.

The directory structure mirrors Karpathy's validated pattern and matches `HoneyDrunk.Architecture/repos/HoneyDrunk.Lore/overview.md`:
- `raw/` â€” immutable source documents (articles, papers, repos, notes, clips)
- `wiki/` â€” LLM-compiled structured markdown
- `output/` â€” query results (rendered markdown, visualizations)
- `tools/` â€” CLI helpers for search and maintenance

## Proposed Implementation

### Directory structure
```
HoneyDrunk.Lore/
â”œâ”€â”€ raw/
â”‚   â””â”€â”€ .gitkeep
â”œâ”€â”€ wiki/
â”‚   â”œâ”€â”€ indexes/
â”‚   â”‚   â””â”€â”€ .gitkeep
â”‚   â””â”€â”€ .gitkeep
â”œâ”€â”€ output/
â”‚   â””â”€â”€ .gitkeep
â”œâ”€â”€ tools/
â”‚   â””â”€â”€ .gitkeep
â”œâ”€â”€ CLAUDE.md
â””â”€â”€ README.md
```

### CLAUDE.md â€” schema doc
The CLAUDE.md defines the four operations the LLM performs in this repo. It is the only configuration the wiki needs. Structure:

#### Identity
- What Lore is: the compiled research knowledge surface for HoneyDrunk Studios
- What it is NOT: agent memory, architecture governance, or code documentation

#### Directory contract
- `raw/` â€” never edit; source of truth for input documents
- `wiki/` â€” LLM-maintained; structured markdown articles, concept pages, entity pages
- `wiki/indexes/` â€” LLM-maintained auto-indexes (topic index, source index, entity index)
- `output/` â€” query results filed here; these feed back into `wiki/` on the next compile pass
- `tools/` â€” shell scripts for search; thin wrappers, no business logic

#### Operation: Ingest
Triggered when a new file appears in `raw/`. Steps:
1. Read the source fully
2. Identify key concepts, entities, and claims
3. For each concept: check if a `wiki/` page exists; create or update it
4. Add a source entry to `wiki/indexes/sources.md`
5. Update topic backlinks in `wiki/indexes/topics.md`
6. Do not delete or overwrite existing wiki content â€” always extend and reconcile

#### Operation: Compile
Triggered on demand or on a scheduled basis. Steps:
1. Scan `raw/` for sources not yet reflected in `wiki/`
2. Run Ingest for each unprocessed source
3. Identify concept pages that reference the same entity â€” merge into a canonical article
4. Rebuild `wiki/indexes/` from current wiki state

#### Operation: Query
Triggered when asked a question. Steps:
1. Search `wiki/` for relevant pages (keyword + semantic scan)
2. Synthesize an answer from wiki content, citing source pages
3. Identify gaps (questions the wiki cannot answer) â€” append them to `wiki/indexes/gaps.md`
4. File the query result in `output/` as a dated markdown file

#### Operation: Lint
Triggered on demand. Checks:
1. Orphan pages â€” wiki pages with no backlinks or source attribution
2. Contradictions â€” claims across wiki pages that conflict
3. Stale sources â€” `raw/` files processed more than 90 days ago (flag for re-ingest)
4. Gaps â€” entries in `wiki/indexes/gaps.md` that have no corresponding wiki page
5. Output a lint report in `output/lint-YYYY-MM-DD.md`

#### Conversion note (for future agents)
The flat-file implementation is intentional and temporary. When `HoneyDrunk.Knowledge` and `HoneyDrunk.Agents` exist:
- Ingest delegates to `IDocumentIngester`
- Retrieval delegates to `IRetrievalPipeline`
- Compile agents run on `HoneyDrunk.Agents` runtime
- This CLAUDE.md becomes the agent configuration, not the implementation

### README.md update
Replace the default README with:
- Purpose: what Lore is (one paragraph)
- How to use: how to drop a source in `raw/` and trigger ingest, how to query, how to lint
- Obsidian: note that `wiki/` is an Obsidian vault â€” open with Obsidian for graph view
- Architecture context: link to `HoneyDrunk.Architecture/repos/HoneyDrunk.Lore/overview.md`

## Acceptance Criteria
- [ ] `raw/`, `wiki/`, `wiki/indexes/`, `output/`, `tools/` directories exist with `.gitkeep`
- [ ] `CLAUDE.md` defines Identity, Directory contract, and all four operations (Ingest, Compile, Query, Lint)
- [ ] Conversion note is present in `CLAUDE.md` explaining the flat-file-first approach
- [ ] `README.md` explains purpose, how to use each operation, Obsidian vault note, and Architecture link
- [ ] No `.NET` code, no NuGet references, no project files â€” flat files only
- [ ] `wiki/indexes/` contains stub files: `sources.md`, `topics.md`, `gaps.md` (empty but with headings)

## Affected Packages
None â€” flat files only.

## Boundary Check
- [x] No infrastructure code â€” flat-file-first per design decision
- [x] CLAUDE.md operations use the same verbs as the future Knowledge/Agents contracts (ingest, compile, query, lint)
- [x] `wiki/` directory is Obsidian-compatible (plain markdown, no special format)
- [x] Conversion path is documented in CLAUDE.md

## Dependencies
None. Foundational â€” unblocks Obsidian vault setup and all future wiki work.

## Labels
`feature`, `tier-1`, `scaffold`

## Agent Handoff

**Objective:** Create the directory scaffold and write CLAUDE.md + README.md for HoneyDrunk.Lore.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Lore`, branch from `main`

**Context:**
- Lore is the living knowledge surface for The Grid â€” a flat-file wiki maintained by LLMs
- Inspired by the Karpathy LLM-wiki pattern (raw sources â†’ LLM-compiled wiki â†’ query/lint)
- Flat-file-first: no .NET, no NuGet, no infrastructure dependencies yet
- `wiki/` will be opened as an Obsidian vault for visualization
- Architecture context: `HoneyDrunk.Architecture/repos/HoneyDrunk.Lore/overview.md` and `boundaries.md`

**Acceptance Criteria:**
- [ ] As listed above

**Constraints:**
- No .NET code, project files, or NuGet references
- CLAUDE.md must use the verbs: ingest, compile, query, lint â€” these will become the future contract method names
- Do not invent wiki structure beyond what is specified â€” `wiki/indexes/` with three stubs is sufficient
- The conversion note in CLAUDE.md must be present â€” it is a deliberate signal to future agents

**Key Files:**
- `CLAUDE.md` (new)
- `README.md` (update)
- `raw/.gitkeep` (new)
- `wiki/.gitkeep` (new)
- `wiki/indexes/sources.md` (new stub)
- `wiki/indexes/topics.md` (new stub)
- `wiki/indexes/gaps.md` (new stub)
- `output/.gitkeep` (new)
- `tools/.gitkeep` (new)