# Architecture Decision Records

Index of all ADRs for the HoneyDrunk Grid.

| ID | Title | Status | Date | Sector | Impact |
|----|-------|--------|------|--------|--------|
| [ADR-0001](ADR-0001-node-vs-service.md) | Node vs Service Distinction | Accepted | 2026-03-22 | Core | Clarified Node = library package, Service = deployable process. Split catalogs into `nodes.json` and `services.json`. |
| [ADR-0002](ADR-0002-honeyhub-command-center.md) | Architecture Repo as Agent Command Center | Accepted | 2026-03-22 | Meta | Established this repo as the centralized source of truth for all agentic workflows and cross-repo coordination. |

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
