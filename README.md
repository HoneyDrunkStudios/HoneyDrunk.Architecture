# HoneyDrunk.Architecture

**The command center for HoneyDrunk Studios' Grid architecture and agentic workflows.**

This repo is the central source of truth for the HoneyDrunk Grid — its topology, invariants, routing rules, and coordination artifacts. Agents and humans use it to plan, route, and execute work across all Grid repos.

## Structure

```
constitution/          Identity, terminology, invariants, sectors
├── manifesto.md       What HoneyDrunk Studios believes and builds
├── terminology.md     Canonical definitions for Grid terms
├── invariants.md      Rules that must never be violated
└── sectors.md         Logical groupings of Nodes

catalogs/              Machine-readable registries (JSON)
├── nodes.json         All Nodes in the Grid
├── modules.json       All NuGet packages
├── services.json      Deployable services
├── relationships.json Dependency graph between Nodes
├── signals.json       Cross-Node signal types
├── flow_config.json   Agentic flow definitions
└── flow_tiers.json    Execution tier classifications

adrs/                  Architecture Decision Records
├── ADR-0001-*.md
└── ADR-0002-*.md

routing/               Agent routing rules
├── request-types.md   How to classify incoming work
├── repo-discovery-rules.md  Which repo handles which work
├── execution-rules.md How to execute work after routing
└── site-sync-rules.md When and how to sync the website

initiatives/           Work tracking
├── active-initiatives.md  In-progress and planned initiatives
├── current-focus.md   What to prioritize right now
└── roadmap.md         High-level timeline

issues/templates/      Issue generation templates
├── architecture-decision.md
├── repo-feature.md
├── cross-repo-change.md
├── site-sync.md
└── canary.md

repos/                 Per-repo context
├── HoneyDrunk.Kernel/
├── HoneyDrunk.Transport/
├── HoneyDrunk.Vault/
├── HoneyDrunk.Auth/
├── HoneyDrunk.Web.Rest/
├── HoneyDrunk.Pulse/
├── HoneyDrunk.Data/
├── HoneyDrunk.Notify/
└── HoneyHub/          (this repo, self-reference)

copilot/               Agent behavior rules
├── global-instructions.md
├── issue-authoring-rules.md
├── pr-review-rules.md
├── setup-steps-guidance.md
└── agent-skills-map.md

generated/             Output directory (ephemeral)
├── issue-packets/     Generated GitHub Issue artifacts
├── site-sync-packets/ Website content update artifacts
└── adr-drafts/        In-progress ADR drafts
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