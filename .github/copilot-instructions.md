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
6. Commit using Conventional Commit format (see **Commit Format** below)
7. Open a PR with your implementation

## If You Are Copilot (assisting in IDE)

The developer is working directly in this repo. Help them with:
- Editing catalogs, ADRs, PDRs, routing rules, or repo context files
- Understanding the Grid topology (read `catalogs/` and `repos/`)
- Drafting ADRs, PDRs, or work items

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
| `scope` | Decompose work into work items |
| `refine` | Challenge scoped work for gaps |
| `review` | Review PRs against boundaries and invariants |
| `adr-composer` | Facilitate architecture decisions |
| `pdr-composer` | Facilitate product decisions |
| `site-sync` | Sync website with architecture changes |
| `netrunner` | Navigate the Grid and surface what's next |

## ADR-0044 D3/D6 Authoring Discipline

ADR-0044 D3 makes the review rubric an upstream authoring standard for Copilot-assisted work too. Before accepting or shaping a diff, help the developer apply the checklist rather than leaving those concerns for review.

Apply the brief ADR-0044 D3 authoring checklist before producing a diff:

- **1. Correctness and functional integrity** — the change satisfies the packet/intent and handles edge cases.
- **3. Maintainability** — the implementation is readable and locally understandable.
- **5. SOLID and design principles** — responsibilities stay cohesive; no speculative abstraction.
- **4. Reuse and ecosystem cohesion** — reuse existing Grid patterns; avoid duplicate helpers/policy.
- **9. Security** — no secret leakage, auth bypass, or widened blast radius.
- **6. Performance and scalability** — no avoidable hot-path, cost, or unbounded-work risk.
- **11. Testing quality** — verification is meaningful and covers the changed behavior.
- **18. AI and agent-specific concerns** — authorship, idempotency, context, and replay risks are explicit.
- **20. Human factors** — PRs are easy for Oleg to review and do not hide operational trade-offs.

The remaining D3 categories are still in scope by reference through `.claude/agents/review.md`; do not treat this short list as exhaustive.

Per ADR-0044 D6, Copilot-assisted accepted PRs must declare authorship. Because Copilot does not autonomously open the PR, direct the human to choose the accurate D6 class:

- Use `Authorship: agent-copilot` when the accepted implementation was materially Copilot-assisted.
- Use `Authorship: mixed` when meaningful work came from multiple surfaces or substantial human + agent co-authoring.
- Use `Authorship: human` when Copilot only supplied trivial autocomplete or non-material suggestions.

Include the same class in the PR body line and commit trailer. Use only the five D6 classes: `human`, `agent-codex`, `agent-copilot`, `agent-claude-code`, or `mixed`.

## Commit Format

All commits — in this repo and in any target repo you execute against — **must** follow [Conventional Commits](https://www.conventionalcommits.org/) 1.0.0:

```
<type>(<optional scope>): <description>

<optional body>

<optional footer>
```

- **type** is required and must be one of: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `build`, `ci`, `perf`, `style`, `revert`
- **scope** is optional; use the affected node or area (e.g. `feat(notify):`, `docs(adr):`)
- **description** is lowercase, imperative mood, no trailing period, ≤ 72 chars on the subject line
- Breaking changes: append `!` after the type/scope (e.g. `feat(auth)!:`) **and** add a `BREAKING CHANGE:` footer explaining the impact
- Reference issues in the footer: `Refs: #123` or `Closes: #123`

Examples:

```
feat(communications): add cadence preference resolver
fix(vault): handle null rotation window on first provision
docs(adr): accept ADR-0030 audit substrate
chore: bump nightly-deps group
```

Squash-merge PR titles must also be a valid Conventional Commit — the title becomes the commit on the default branch.

## Conventions

- Markdown with structured frontmatter, JSON catalogs
- No application code in this repo
- Commits follow Conventional Commits — see **Commit Format** above
- Work item naming: `{YYYY-MM-DD}-{repo}-{description}.md`
- ADR format follows `adrs/ADR-0001-node-vs-service.md`
- PDR format follows `pdrs/PDR-0001-honeyhub-platform-observation-and-ai-routing.md`
