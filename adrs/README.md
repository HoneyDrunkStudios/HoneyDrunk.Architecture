# Architecture Decision Records

Index of all ADRs for the HoneyDrunk Grid.

For product-level strategic decisions, see [PDRs](../pdrs/README.md).

| ID | Title | Status | Date | Sector | Impact |
|----|-------|--------|------|--------|--------|
| [ADR-0001](ADR-0001-node-vs-service.md) | Node vs Service Distinction | Accepted | 2026-03-22 | Core | Clarified Node = library package, Service = deployable process. Split catalogs into `nodes.json` and `services.json`. |
| [ADR-0002](ADR-0002-honeyhub-command-center.md) | Architecture Repo as Agent Command Center | Accepted | 2026-03-22 | Meta | Established this repo as the centralized source of truth for all agentic workflows and cross-repo coordination. |
| [ADR-0003](ADR-0003-honeyhub-control-plane.md) | HoneyHub as Organizational Control Plane | Accepted (Phase 1) | 2026-03-30 | Meta | HoneyHub as a graph-driven orchestration system. Accepted Phase 1 (domain model + knowledge graph API). Phases 2–4 (orchestration, projections, UI) are future commitments. |
| [ADR-0004](ADR-0004-tool-agnostic-agent-definitions.md) | Tool-Agnostic Agent Definitions | Superseded by [ADR-0007](ADR-0007-claude-agents-as-source-of-truth.md) | 2026-04-08 | Meta | Agent definitions authored once in canonical format, generated into tool-specific formats for Claude Code, Copilot, and Codex. |
| [ADR-0005](ADR-0005-configuration-and-secrets-strategy.md) | Configuration and Secrets Strategy | Accepted | 2026-04-09 | Infrastructure | Defined per-Node per-environment Key Vault strategy, bootstrap env vars, App Configuration split, and RBAC/OIDC access model. |
| [ADR-0006](ADR-0006-secret-rotation-and-lifecycle.md) | Secret Rotation and Lifecycle | Accepted | 2026-04-09 | Infrastructure | Defined rotation SLAs, Azure-native and third-party rotation paths, event-driven cache invalidation, and audit/alert requirements. |
| [ADR-0007](ADR-0007-claude-agents-as-source-of-truth.md) | `.claude/agents/` as Single Source of Truth | Accepted | 2026-04-09 | Meta | Dropped canonical/generator layer. Agents live directly in `.claude/agents/`; Copilot discovers them there, Codex uses `AGENTS.md`. |
| [ADR-0008](ADR-0008-work-tracking-and-execution-flow.md) | Work Tracking and Execution Flow | Accepted | 2026-04-09 | Meta | Standardized packet-to-issue-to-board-to-PR lifecycle, org-level project schema, and cloud agent execution flow. **See Unresolved Consequences section for D4/D5/D6 gaps.** |
| [ADR-0009](ADR-0009-package-scanning-policy.md) | Package Scanning Policy | Accepted | 2026-04-09 | Meta | PR gate on High+ CVEs, nightly deep scans, no Dependabot. 8 rollout packets in flight. |
| [ADR-0010](ADR-0010-observation-layer.md) | Observation Layer and AI Routing | Accepted | 2026-04-12 | Meta | Defines HoneyDrunk.Observe + Connectors (external project visibility) and AI routing layer in HoneyDrunk.AI (policy-driven model selection). Adds invariants 28–30. |

## Statuses

- **Proposed** — Under discussion, not yet decided
- **Accepted** — Decision made, implementation in progress or complete
- **Superseded** — Replaced by a newer ADR (link to replacement)
- **Rejected** — Considered and explicitly declined

## Creating a New ADR

Use the `adr-composer` agent or create manually:

1. Copy the pattern from an existing ADR
2. Use the next sequential number: `ADR-{NNNN}-{kebab-case-title}.md`
3. Include: Status, Date, Deciders, Sector, Context, Decision, Consequences, Alternatives Considered
4. Add a row to this index
