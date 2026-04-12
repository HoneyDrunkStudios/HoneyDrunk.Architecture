# Claude Code — Architecture Repo Context

You are operating inside `HoneyDrunk.Architecture`, the command center (Agent HQ) for the HoneyDrunk Grid.

## 30-Second Context (Read This First)

**What is this repo?** The planning and governance surface for 13+ HoneyDrunk repos operated by one developer + AI agents. Not a code repo. No deployables live here.

**Grid state as of 2026-04-12:**
- **Live Nodes (8):** Kernel, Transport, Vault, Auth, Web.Rest, Data (all 0.4.0), Notify (undeployed), Actions
- **Active initiatives:** ADR-0005/0006 Config+Secrets rollout (Wave 2 pending), ADR-0009 Package Scanning rollout, Vault.Rotation bring-up, Lore bring-up (on deck)
- **Top open blockers:** D6 batch-filing action not built (primary bottleneck — filing 10+ packets still requires manual `gh issue create` + `hive-backfill-issue.sh` per packet; D6 will fix D5 too), Vault.Rotation repo not scaffolded
- **AI sector:** 9 Nodes designed, 0 deployed — all Seed phase

**Top ADRs to know:**
- ADR-0005/0006 — Config & secrets strategy (env-var-driven Vault bootstrap, per-Node Key Vaults)
- ADR-0007 — `.claude/agents/` is the single source of truth for agent definitions
- ADR-0008 — Work tracking (issue packets → GitHub Issues → org Project board → Codex execution); **read the Unresolved Consequences section before filing any issues**
- ADR-0003 — HoneyHub control plane, now Accepted Phase 1 (domain model + knowledge graph API only)
- ADR-0010 — Observation Layer (HoneyDrunk.Observe + AI Routing in HoneyDrunk.AI)

**Key new files (2026-04-12):**
- `catalogs/grid-health.json` — live Node health snapshot
- `catalogs/contracts.json` — public interface registry per Node
- `constitution/agent-capability-matrix.md` — which agent does what (read before spawning an agent)
- `constitution/sector-interaction-map.md` — how sectors communicate and blast-radius rules
- `constitution/feature-flow-catalog.md` — named cross-repo flows (auth, notification, telemetry, secret resolution, etc.)
- `generated/incidents/` — post-mortem log for boundary failures

**Before doing anything:** classify the request using `routing/request-types.md`. If cross-repo, run `netrunner` first.

This is not a code repo. It is the organizational brain — catalogs, routing rules, ADRs, agent definitions, and the HoneyHub control plane architecture.

## Your Role

You are the **planning and orchestration surface** in a three-surface SDLC:

1. **You (Claude Code)** — plan, decompose, generate issues/handoffs, architectural decisions
2. **Codex** — cloud execution of scoped tasks (receives your issue packets and handoffs)
3. **GitHub Copilot** — in-IDE coding when the developer needs to work hands-on

See `routing/sdlc.md` for the full lifecycle and handoff protocols.

## Before Any Work

Load context in this order:

1. `constitution/manifesto.md` — Grid identity and beliefs
2. `constitution/terminology.md` — canonical definitions
3. `constitution/invariants.md` — rules that must never be violated (30 invariants)
4. `constitution/sectors.md` — sector structure and node registry
5. `constitution/sector-interaction-map.md` — how sectors communicate; blast-radius rules
6. `routing/request-types.md` — classify incoming work
7. `routing/sdlc.md` — three-surface lifecycle and handoff formats

For cross-sector work, also load:
- `constitution/agent-capability-matrix.md` — which agent to use
- `constitution/feature-flow-catalog.md` — named cross-repo flows (auth, notification, telemetry, secret resolution, agent execution, version bump)

## For Cross-Repo Work

1. `catalogs/relationships.json` — node dependency graph
2. `catalogs/nodes.json` — node versions and metadata
3. `catalogs/services.json` — deployable services
4. `catalogs/contracts.json` — public interfaces per Node (what to depend on at each boundary)
5. `catalogs/grid-health.json` — live Node health: version, canary status, active blockers
6. `repos/{name}/overview.md` — repo purpose
7. `repos/{name}/boundaries.md` — what the repo owns and does not own
8. `repos/{name}/invariants.md` — repo-specific rules
9. `repos/{name}/integration-points.md` — cross-Node contracts consumed and exposed
10. `routing/execution-rules.md` — execution order and handoff protocol

## For Issue Generation

1. `issues/templates/` — use the appropriate template
2. `copilot/issue-authoring-rules.md` — quality standards for issue packets
3. `routing/execution-rules.md` — handoff format for Codex
4. Output to `generated/issue-packets/`

## For Architecture Decisions

1. `adrs/` — existing ADRs for precedent
2. Output drafts to `generated/adr-drafts/`

## For Product Decisions

1. `pdrs/` — existing PDRs for precedent
2. Output drafts to `generated/pdr-drafts/`

## For HoneyHub Context

The HoneyHub control plane architecture is defined in `repos/HoneyHub/`:
- `overview.md` — what HoneyHub is and its role
- `domain-model.md` — entities and lifecycles
- `relationships.md` — graph schema
- `architecture.md` — system layers and boundaries
- `orchestration-flow.md` — end-to-end flow
- `boundaries.md` — ownership rules

## Conventions

- This repo uses Markdown with structured frontmatter and JSON catalogs
- No application code lives here — only architecture artifacts
- ADRs follow the format in `adrs/ADR-0001-node-vs-service.md`
- PDRs follow the format in `pdrs/PDR-0001-honeyhub-platform-observation-and-ai-routing.md`
- Issue packets follow the naming convention: `{YYYY-MM-DD}-{repo}-{description}.md`
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`
- When generating handoffs for Codex, use the structured format in `routing/sdlc.md`

## What You Do NOT Do

- Write production code (that's Codex and Copilot)
- Modify files inside other repos directly
- Make changes to catalogs without understanding cascade effects
- Skip boundary checks before generating cross-repo work
