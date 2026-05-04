# Agent Skills Map

Maps agent capabilities to the types of work they can perform in the Grid.

## Core Skills

### Architecture Analysis
**Capability:** Read catalogs, routing rules, and repo context to answer questions about the Grid topology, dependencies, and boundaries.
**Input:** Natural language question about architecture
**Output:** Structured answer with file references

### Issue Packet Generation
**Capability:** Generate structured GitHub Issue packets from a description of work. Automatically detects single-repo vs multi-repo scope.
**Input:** Description of feature, bug, change, or initiative
**Output:** Issue packets in `/generated/issue-packets/`, dispatch plans and handoff prompts in `/generated/` for multi-repo work

### Issue Filing
**Capability:** File packet files as GitHub issues and wire them fully into The Hive. Handles the entire mechanical pipeline so nothing is missed.
**Input:** Initiative slug or path to packet files
**Output:** GitHub issues created, added to The Hive with all fields set (Status, Wave, Node, Tier, Actor, Initiative), blocking relationships wired

### ADR Draft Generation
**Capability:** Facilitate an architecture discussion and produce an ADR draft.
**Input:** Design question or proposal
**Output:** Markdown file in `/generated/adr-drafts/` following ADR format

### Site Sync Packet Generation
**Capability:** Generate content update packets for the Studios website.
**Input:** Architecture change (new Node, version release, ADR)
**Output:** Markdown file in `/generated/site-sync-packets/`

### Dependency Impact Analysis
**Capability:** Given a proposed change to a Node, trace downstream impact through the dependency graph.
**Input:** Node name + proposed change description
**Output:** List of affected Nodes with impact assessment

### PR Review
**Capability:** Review a pull request against boundary rules, invariants, and code conventions.
**Input:** PR diff or file changes
**Output:** Review comments with severity levels

## Skill Routing

| Request Pattern | Primary Skill |
|----------------|---------------|
| "What repos are affected by..." | Dependency Impact Analysis |
| "Create an issue for..." | Issue Packet Generation |
| "Should we..." / "What if..." | ADR Draft Generation |
| "Plan the changes for..." | Issue Packet Generation |
| "Update the website for..." | Site Sync Packet Generation |
| "Review this PR" | PR Review |
| "How does X connect to Y" | Architecture Analysis |
| "Break this into issues" | Issue Packet Generation |
| "Scope this work" | Issue Packet Generation |
| "Hand off X to Y repo" | Issue Packet Generation |
| "File these issues" | Issue Filing |
| "Create the issues for..." | Issue Filing |
| "Push these packets to GitHub" | Issue Filing |

## AI Surfaces

Work flows through three AI surfaces. See `/routing/sdlc.md` for the full lifecycle.

| Surface | Role | Operates On | Strength |
|---------|------|-------------|----------|
| **Claude Code** | Plan, orchestrate, hand off | Architecture repo + workspace | Cross-repo reasoning, decomposition, issue generation |
| **Codex** | Execute tasks autonomously in the cloud | Single repo per task | Autonomous implementation from well-scoped issues |
| **GitHub Copilot** | In-IDE coding, debugging, exploration | Single repo (open in editor) | Line-by-line precision, interactive iteration |

OpenClaw is an operator/runtime surface around these workflows. It does not load `.claude/agents/*.md` as native named agents, but it can read them as instruction sources and delegate work through OpenClaw sub-sessions. For repeatable Architecture workflows, pair the Claude/Copilot agent with an OpenClaw skill instead of relying on ad hoc prompt copying.

## Agent Inventory (Claude Code Surface)

Agents that run within the Claude Code / Architecture repo context:

| Agent | Purpose | Invokes | OpenClaw skill |
|-------|---------|---------|----------------|
| **adr-composer** | Facilitate architecture decisions, produce ADRs | — | `honeydrunk-adr-composer` |
| **pdr-composer** | Facilitate product decisions, produce PDRs | — | `honeydrunk-pdr-composer` |
| **product-strategist** | Product strategy, positioning, roadmap, and commercialization analysis | — | `honeydrunk-product-strategist` |
| **site-sync** | Sync website with architecture changes | — | `honeydrunk-site-sync` |
| **scope** | Scope work into issues — auto-detects single or multi-repo, generates issue packets, dispatch plans, and handoff prompts | adr-composer, site-sync | `honeydrunk-scope` |
| **file-issues** | File packet files as GitHub issues — creates issues, adds to The Hive, sets all project fields, wires blocking relationships | — | `honeydrunk-file-issues` |
| **refine** | Challenge scoped work before execution — finds gaps, missed dependencies, boundary violations, invariant risks | — | `honeydrunk-refine` |
| **review** | Review PRs against boundary rules, invariants, contract safety, and code conventions | — | `honeydrunk-review` |
| **netrunner** | Research and investigation across the Grid | — | `honeydrunk-netrunner` |
| **node-audit** | Audit Node boundary, invariant, catalog, and release-hygiene alignment | — | `honeydrunk-node-audit` |
| **hive-sync** | Reconcile Architecture repo state with The Hive and initiative tracking | — | `honeydrunk-hive-sync` |

## OpenClaw Skill Pairing Rule

When adding a new Architecture agent under `.claude/agents/`, also add or update the corresponding OpenClaw skill if OpenClaw should invoke that workflow repeatedly.

The OpenClaw skill should preserve:

- Routing intent: when the workflow should trigger.
- Required context files and research order.
- Decision boundaries and stop/ask conditions.
- Output contract: ADR draft, PDR draft, issue packets, review notes, filed issues, etc.
- Delegation expectations, translated to OpenClaw primitives such as sub-sessions rather than Claude-specific `Agent` tool language.

Do not create a new canonical agent directory or generator for this. ADR-0007 keeps `.claude/agents/` as the source of truth for Claude/Copilot; OpenClaw compatibility is maintained through paired skills documented here.

## Codex Execution Model

Codex receives work as either:
- A GitHub Issue with structured body (generated by Claude Code via issue templates)
- A handoff prompt with explicit context (see `/routing/sdlc.md` for handoff format)

Codex operates autonomously within a single repo. It does not make architectural decisions or cross repo boundaries.

## Copilot Execution Model

GitHub Copilot assists the developer directly in the IDE. No structured handoff — the developer drives. Used for:
- Reviewing and adjusting Codex PRs
- Debugging and exploratory coding
- Implementation too nuanced for autonomous execution
- Emergency hotfixes
