# Claude Code — Architecture Repo Context

You are operating inside `HoneyDrunk.Architecture`, the command center (Agent HQ) for the HoneyDrunk Grid.

## 30-Second Context (Read This First)

**What is this repo?** The planning and governance surface for 13+ HoneyDrunk repos operated by one developer + AI agents. Not a code repo. No deployables live here.

**Grid state as of 2026-05-21:**
- **Live Nodes (12):** Kernel 0.7.0, Transport 0.6.0, Vault 0.5.0, Data 0.6.0, Web.Rest 0.5.0, Auth 0.4.0 (Core); Notify 0.3.0, Communications 0.2.0, Pulse 0.3.0, Actions (Ops); Architecture, Studios (Meta). All Core packages aligned to Kernel 0.7.0 / Transport 0.6.0 baseline (canaries passing).
- **Seed Nodes (13):** Vault.Rotation, Audit (Core); Lore (Meta); AI, Agents, Memory, Knowledge, Evals, Capabilities, Flow, Operator, Sim (AI). Vault.Rotation is scaffolded but holds no package/tag by decision; Audit is governed by ADR-0030 (Accepted) + ADR-0031 standup (Proposed). The nine AI-sector Nodes are designed but not scaffolded — see `constitution/ai-sector-architecture.md`.
- **Active initiatives:** Kernel Adoption Alignment (11/11 closed — exit review), ADR-0010 Observe & AI Routing Phase 1 (Observe#2 + AI routing reconciliation still open), ADR-0015 Container Apps Rollout (Notify/Pulse Azure bring-up still open), ADR-0030 Audit Substrate acceptance (2/2 closed — exit review), ADR-0032 PR Validation Policy (12/12 closed — packets do not declare `accepts:`, ADR stays Proposed until reconciled), ADR-0016 HoneyDrunk.AI standup. Multiple older rollouts (ADR-0005/0006, ADR-0009, ADR-0014, Lore) are 100% closed and queued for archive.
- **Top open blockers:** Notify.Functions / Notify.Worker / Pulse.Collector Azure Container Apps bring-up (Notify#3, Notify#4, Pulse#3); ADR-0010 manifest drift around HoneyDrunk.AI#1 vs #3 (superseded routing-contract packet); Pulse container image publication still gated on upstream Ubuntu `sed` CVE-2026-5958. See `initiatives/current-focus.md` for the live primary list.
- **AI sector:** 9 Nodes designed, 0 scaffolded — all Seed phase. HoneyDrunk.AI catalog/standup ADR-0016 Accepted; scaffold packets (Architecture#72, #73, AI#2) still open.

**Top ADRs to know:**
- ADR-0005/0006 — Config & secrets strategy (env-var-driven Vault bootstrap, per-Node Key Vaults). **Accepted.**
- ADR-0007 — `.claude/agents/` is the single source of truth for agent definitions. **Accepted.**
- ADR-0008 — Work tracking (issue packets → GitHub Issues → org Project board → Codex execution). **Accepted.** D4/D5/D6 gaps all RESOLVED (2026-04-12 / 2026-05-20); see the 2026-05-21 D10 amendment for the initiative-slug naming convention (ADR-driven vs PDR-driven vs BDR-driven slugs).
- ADR-0030 — Grid-Wide Audit Substrate (Audit Node, append-only-by-interface). **Accepted.** Standup governed by ADR-0031.
- ADR-0019 — HoneyDrunk.Communications boundary refactor (decision/orchestration vs Notify intake/delivery). **Accepted.**
- ADR-0010 — Observation Layer + AI Routing. **Accepted.** Phase 1 Observe-side scaffolding underway; AI routing parked on manifest reconciliation.
- ADR-0003 — HoneyHub control plane. **Accepted (Phase 1)** — domain model + knowledge graph API only.

**Top BDRs to know:**
- BDR-0001 — Mailbox Service Replacement (leave iPostal1 for VPM; Sunbiz amendment in flight before Oct 2026). **Accepted.** See `business/decisions/`.

**Key files added since 2026-04-12:**
- `catalogs/grid-health.json` — live Node health snapshot (updated 2026-05-18)
- `catalogs/contracts.json` — public interface registry per Node
- `constitution/agent-capability-matrix.md` — which agent does what (read before spawning an agent)
- `constitution/sector-interaction-map.md` — how sectors communicate and blast-radius rules
- `constitution/feature-flow-catalog.md` — named cross-repo flows (auth, notification, telemetry, secret resolution, etc.)
- `business/` — Business Decision Records (BDRs) and operational context (entity, banking, vendors). Parallel to `adrs/` and `pdrs/`; same record shape, different scope.
- `generated/incidents/` — post-mortem log for boundary failures
- `initiatives/board-items.md`, `proposed-adrs.md`, `drift-report.md` — hive-sync-generated current-state surfaces

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

## For Business Decisions

1. `business/decisions/` — existing BDRs (operations: entity, banking, vendors, contracts, insurance)
2. `business/context/` — current operational state (entity facts, vendor list, etc.)

BDRs are scoped to studio-level operations, not Grid architecture or product strategy. Same record shape as ADRs/PDRs; use them when the decision is about how the LLC operates (mail/address, registered agent, accounting, payroll, banking, insurance, signed contracts) rather than about how the Grid is built.

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
