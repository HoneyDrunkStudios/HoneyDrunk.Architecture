# HoneyDrunk.Architecture

**The command center for HoneyDrunk Studios' Grid architecture and agentic workflows.**

This repo is the central source of truth for the HoneyDrunk Grid — its topology, invariants, routing rules, and coordination artifacts. Agents and humans use it to plan, route, and execute work across all Grid repos.

## Structure

```
constitution/              Identity, terminology, invariants, sectors
├── manifesto.md           What HoneyDrunk Studios believes and builds
├── terminology.md         Canonical definitions for Grid terms
├── invariants.md          Rules that must never be violated
├── sectors.md             Logical groupings of Nodes
├── naming-conventions.md  Naming standards across the Grid
└── ai-sector-architecture.md  AI sector design

catalogs/                  Machine-readable registries (JSON)
├── nodes.json             All Nodes in the Grid
├── modules.json           All NuGet packages
├── services.json          Deployable services
├── relationships.json     Dependency graph between Nodes
├── signals.json           Cross-Node signal types
├── compatibility.json     Compatibility matrix
├── flow_config.json       Agentic flow definitions
└── flow_tiers.json        Execution tier classifications

adrs/                      Architecture Decision Records
├── ADR-0001-node-vs-service.md
├── ADR-0002-honeyhub-command-center.md
└── ADR-0003-honeyhub-control-plane.md

pdrs/                      Product Decision Records
└── PDR-0001-honeyhub-platform-observation-and-ai-routing.md

routing/                   Agent routing rules
├── request-types.md       How to classify incoming work
├── repo-discovery-rules.md  Which repo handles which work
├── execution-rules.md     How to execute work after routing
├── sdlc.md                Three-surface SDLC lifecycle
└── site-sync-rules.md     When and how to sync the website

initiatives/               Work tracking
├── active-initiatives.md  In-progress and planned initiatives
├── current-focus.md       What to prioritize right now
├── roadmap.md             High-level timeline
└── releases.md            Release history

infrastructure/            Azure and deployment context
├── azure-identity-and-secrets.md
├── azure-naming-conventions.md
├── azure-provisioning-guide.md
├── azure-resource-inventory.md
├── deployment-map.md
├── tech-stack.md
└── vendor-inventory.md

issues/templates/          Issue generation templates
├── architecture-decision.md
├── bug-fix.md
├── canary.md
├── ci-change.md
├── cross-repo-change.md
├── dependency-upgrade.md
├── repo-feature.md
└── site-sync.md

repos/                     Per-repo context
├── HoneyDrunk.Auth/
├── HoneyDrunk.Data/
├── HoneyDrunk.Kernel/
├── HoneyDrunk.Notify/
├── HoneyDrunk.Pulse/
├── HoneyDrunk.Transport/
├── HoneyDrunk.Vault/
├── HoneyDrunk.Web.Rest/
└── HoneyHub/

copilot/                   Agent behavior rules
├── global-instructions.md
├── issue-authoring-rules.md
├── pr-review-rules.md
├── setup-steps-guidance.md
└── agent-skills-map.md

.github/agents/            GitHub Copilot agent definitions
├── adr-composer.agent.md
├── netrunner.agent.md
├── pdr-composer.agent.md
├── refine.agent.md
├── review.agent.md
├── scope.agent.md
└── site-sync.agent.md

.claude/agents/            Claude Code agent definitions
├── adr-composer.md
├── netrunner.md
├── pdr-composer.md
├── refine.md
└── scope.md

generated/                 Output directory (ephemeral)
├── adr-drafts/            In-progress ADR drafts
├── dispatch-plans/        Multi-repo execution plans
├── handoffs/              Agent handoff artifacts
├── issue-packets/         Generated GitHub Issue artifacts
├── pdr-drafts/            In-progress PDR drafts
└── site-sync-packets/     Website content update artifacts

AGENTS.md                  Codex agent context
CLAUDE.md                  Claude Code agent context
```

## How It Works

1. **Discuss** an architecture question or feature with an agent
2. **Route** the work using routing rules to the correct repo(s)
3. **Generate** structured issue packets or ADR drafts
4. **Hand off** the artifacts to target repo agents or create GitHub Issues
5. **Execute** the work in the target repo(s)
6. **Sync** the website if public-facing changes were made

## Grid at a Glance

| Sector | Nodes |
|--------|-------|
| **Core** | Kernel, Transport, Vault, Auth, Web.Rest, Data |
| **Ops** | Pulse, Notify, Actions |
| **Meta** | Architecture, Studios |

## License

MIT