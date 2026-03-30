# Copilot / Codex — Architecture Repo Context

You are operating inside `HoneyDrunk.Architecture`, the command center (Agent HQ) for the HoneyDrunk Grid.

This is not a code repo. It contains architecture decisions, catalogs, routing rules, issue templates, and per-repo context. You should not be writing application code here.

## Your Role

You are one of two execution surfaces in a three-surface SDLC:

1. **Claude Code** — plans, decomposes, generates issues/handoffs (the brain)
2. **You (Codex)** — executes scoped tasks autonomously, opens PRs
3. **You (Copilot)** — assists the developer in-IDE for hands-on coding

See `routing/sdlc.md` for the full lifecycle and how work flows between surfaces.

## If You Are Codex (executing a task)

You received a task from Claude Code via a GitHub Issue or handoff prompt. Follow these steps:

1. Read the issue body for: task description, acceptance criteria, constraints, dependencies
2. Read `repos/{target-repo}/boundaries.md` to confirm the work belongs in the target repo
3. Read `repos/{target-repo}/invariants.md` for repo-specific rules
4. Read `constitution/invariants.md` for Grid-wide rules
5. Implement within the target repo, not in this repo
6. Open a PR with your implementation

## If You Are Copilot (assisting in IDE)

The developer is working directly in this repo. Help them with:
- Editing catalogs, ADRs, PDRs, routing rules, or repo context files
- Understanding the Grid topology (read `catalogs/` and `repos/`)
- Drafting ADRs, PDRs, or issue packets

## Context Files (Read Before Acting)

| File | What It Tells You |
|------|-------------------|
| `constitution/terminology.md` | Canonical definitions for Grid terms |
| `constitution/invariants.md` | Rules that must never be violated |
| `constitution/sectors.md` | Sector structure and node registry |
| `catalogs/relationships.json` | Node dependency graph |
| `catalogs/nodes.json` | Node versions and metadata |
| `routing/request-types.md` | How to classify work |
| `routing/execution-rules.md` | Execution order and handoff protocol |
| `pdrs/` | Product decision records |
| `copilot/global-instructions.md` | Agent behavior rules |
| `copilot/issue-authoring-rules.md` | Issue quality standards |
| `copilot/pr-review-rules.md` | PR review checklist |

## Agent Definitions

Custom agents are defined in `.github/agents/`. Each agent has a specific purpose:

| Agent | Purpose |
|-------|---------|
| `scope` | Decompose work into issue packets |
| `refine` | Challenge scoped work for gaps |
| `review` | Review PRs against boundaries and invariants |
| `adr-composer` | Facilitate architecture decisions |
| `pdr-composer` | Facilitate product decisions |
| `site-sync` | Sync website with architecture changes |
| `netrunner` | Navigate the Grid and surface what's next |

## Conventions

- Markdown with structured frontmatter, JSON catalogs
- No application code in this repo
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`
- Issue packet naming: `{YYYY-MM-DD}-{repo}-{description}.md`
- ADR format follows `adrs/ADR-0001-node-vs-service.md`
- PDR format follows `pdrs/PDR-0001-honeyhub-platform-observation-and-ai-routing.md`
