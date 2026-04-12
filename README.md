# HoneyDrunk.Architecture

**The command center for HoneyDrunk Studios' Grid architecture and agentic workflows.**

This repo is the central source of truth for the HoneyDrunk Grid — its topology, invariants, routing rules, and coordination artifacts. No application code lives here. Instead, it holds the decisions, catalogs, and agent definitions that govern how work is planned, routed, and executed across every repo in the Grid.

Three AI surfaces share responsibility for the full development lifecycle, and this repo is where it all starts:

| Surface | Role | Entry Point |
|---------|------|-------------|
| **Claude Code** | Plan, decompose, generate issues and ADRs | `CLAUDE.md` |
| **Codex** | Execute scoped tasks, open PRs | `AGENTS.md` |
| **GitHub Copilot** | In-IDE coding assist | `.github/copilot-instructions.md` |

## How Work Moves Through the Grid

```
Intent → Classify → Scope → Issue Packets → GitHub Issues → Execute → PR → Merge → Site Sync
```

1. **Classify** — Every request is typed (`repo-feature`, `cross-repo-change`, `architecture-decision`, `bug-fix`, `ci-change`, `dependency-upgrade`, `canary`, `site-sync`) and assigned a tier using `routing/request-types.md`.

2. **Route** — `routing/repo-discovery-rules.md` determines which repo(s) own the work. For cross-repo changes, `catalogs/relationships.json` reveals the dependency graph and cascade order.

3. **Scope** — The `scope` agent decomposes work into issue packets grouped by initiative under `generated/issue-packets/active/{initiative}/`. Multi-repo work gets a dispatch plan and wave diagram. The `refine` agent challenges the plan before execution.

4. **File** — Issue packets become GitHub Issues via `scripts/file-packets.ps1`. Each issue lands on **The Hive** project board with Status, Wave, Node, Tier, Actor, and Initiative fields. Blocking relationships are wired via GraphQL.

5. **Execute** — Codex picks up issues and opens PRs in target repos. The `review` agent validates PRs against invariants and boundaries.

6. **Sync** — When changes affect the public Grid (new Node, version bump, signal change), the `site-sync` agent updates the Studios website.

### Execution Tiers

| Tier | Flow | Examples |
|------|------|----------|
| **Tier 1** | Auto-execute | Doc fixes, version bumps, changelog updates |
| **Tier 2** | Plan → Review → Execute | Single-repo features, new providers, CI changes |
| **Tier 3** | Architecture discussion → ADR → Decompose → Execute | New contracts, new Nodes, boundary changes |

## What Makes It Work

**Invariants** — 30 rules that must never be violated across the Grid. Contracts over frameworks. Context flows everywhere. Small surface, strong contracts. Every agent reads `constitution/invariants.md` before acting.

**Catalogs** — Machine-readable JSON registries (`catalogs/`) that describe every Node, package, service, dependency, contract, and health status. Agents query these to understand the Grid topology. The Studios website renders them into the live Grid map.

**Per-Repo Context** — Every Node has a folder under `repos/` with its boundaries, invariants, integration points, and overview. Agents read these before touching a repo to confirm work belongs there.

**Agent Definitions** — Custom agents under `.claude/agents/` handle specialized tasks (scoping, refining, reviewing, ADR authoring, site syncing, issue filing). Each agent has a defined purpose, tool access, and execution protocol.

**ADRs and PDRs** — Architecture and product decisions are versioned records under `adrs/` and `pdrs/`. They govern how the Grid evolves and are referenced by issue packets so executors understand the "why" behind the work.

## Directory Overview

| Directory | Purpose |
|-----------|---------|
| `constitution/` | Grid identity, terminology, invariants, sectors, naming conventions, agent capabilities, feature flows |
| `catalogs/` | JSON registries — nodes, packages, services, relationships, contracts, health, signals, compatibility |
| `adrs/` | Architecture Decision Records governing Grid design |
| `pdrs/` | Product Decision Records governing platform strategy |
| `routing/` | Request classification, repo discovery, execution rules, SDLC lifecycle, site sync triggers |
| `repos/` | Per-Node context — boundaries, invariants, overview, integration points for every Grid repo |
| `initiatives/` | Active initiatives, current focus, roadmap, release history |
| `infrastructure/` | Azure provisioning guides, naming conventions, resource inventory, deployment maps |
| `issues/templates/` | Issue packet templates by type (feature, bug, cross-repo, CI, canary, etc.) |
| `generated/` | Output directory for issue packets, ADR drafts, PDR drafts, site sync packets, incident logs |
| `copilot/` | Agent behavior rules — issue authoring standards, PR review checklists, global instructions |
| `.claude/agents/` | Claude Code agent definitions (scope, refine, review, adr-composer, pdr-composer, netrunner, site-sync, file-issues) |
| `scripts/` | Automation scripts for issue filing and board management |

## The Grid

| Sector | Signal | Nodes |
|--------|--------|-------|
| **Core** | Live | Kernel, Transport, Vault, Auth, Web.Rest, Data |
| **Ops** | Mixed | Pulse (Seed), Notify (Live), Actions (Live) |
| **Meta** | Mixed | Architecture (Live), Studios (Live), Lore (Seed) |
| **AI** | Seed | Agents, AI, Memory, Knowledge, Evals, Capabilities, Flow, Operator, Sim |
| **HoneyNet** | Planned | — |
| **Creator** | Planned | — |
| **Market** | Planned | — |
| **HoneyPlay** | Planned | — |
| **Cyberware** | Planned | — |

### Core Node Dependency Order

```
Kernel → Transport → Vault → Auth → Web.Rest → Data
```

This is the canonical sequencing for cross-repo changes. Upstream merges before downstream.

## License

MIT