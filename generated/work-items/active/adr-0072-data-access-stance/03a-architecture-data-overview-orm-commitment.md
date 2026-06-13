---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "core", "docs", "adr-0072", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0072"]
wave: 2
initiative: adr-0072-data-access-stance
node: honeydrunk-architecture
---

# Update `repos/HoneyDrunk.Data/overview.md` with the ORM Commitment section

## Summary
Single governance-doc task from ADR-0072's Follow-up Work: update `repos/HoneyDrunk.Data/overview.md` to record EF Core as the ratified ORM behind `IRepository<T>` / `IUnitOfWork` per ADR-0072 D1/D4. The implementation already exists in `HoneyDrunk.Data.EntityFramework`; this packet ratifies it in the per-Node overview. **The per-Node `integration-points.md` sweep is split out to packet 03b** (which depends on sibling `adr-0048-schema-evolution` packet 01 landing).

## Context
ADR-0072's Follow-up Work names: "`HoneyDrunk.Data` ratifies EF Core as the implementation behind `IRepository<T>` / `IUnitOfWork`. Existing implementations align (or already align) with this ADR."

`repos/HoneyDrunk.Data/overview.md` is the per-Node governance doc for the Data Node. It currently records the Node's purpose, key packages (including `HoneyDrunk.Data.EntityFramework` as the EF Core repository + unit-of-work implementation), and provider-level packages (`HoneyDrunk.Data.SqlServer`). The overview doc does not yet explicitly cite ADR-0072 — packet 04 of this initiative updates the **Data repo's own README** and CHANGELOG; this packet updates the **Architecture repo's per-Node governance overview** that mirrors the Data Node's posture.

**Why ratify in the Architecture repo and not just the Data repo.** The Architecture repo is the Grid's single source of truth for governance. `repos/HoneyDrunk.<Node>/overview.md` is the canonical "what does this Node do, what does it ship, what are its commitments?" doc — read by other Nodes' integration packets, by the `scope` agent during repo-discovery, and by any agent checking the Node's posture. Recording the ADR-0072 ratification here makes the EF Core commitment discoverable from the Grid's governance surface, not just from the Data repo's own README.

**Split rationale.** The original packet 03 bundled the Data overview update with a per-Node `integration-points.md` sweep across every existing Node. The two tasks have different sequencing: the overview update is purely intra-initiative (only depends on packet 00). The integration-points sweep edits a section that `adr-0048-schema-evolution` packet 01 introduces (`## Migration Coordination`) and therefore depends textually on that sibling packet. Splitting cleanly separates the standalone-actionable work (03a, this packet) from the sibling-sequenced work (03b).

This is a docs/governance packet. No code, no .NET project.

## Scope
- `repos/HoneyDrunk.Data/overview.md` — add an "ORM Commitment" section recording EF Core as the ratified ORM behind `IRepository<T>` / `IUnitOfWork` per ADR-0072 D1/D4.
- No edit to any `integration-points.md` file (deferred to packet 03b).
- No edit to `catalogs/grid-health.json`.
- No edit to any Node repo.

## Proposed Implementation

Read `repos/HoneyDrunk.Data/overview.md`. It carries:
- Purpose ("Persistence conventions, repository patterns, tenant-aware data access, and transactional outbox. Provides EF Core and SQL Server implementations.")
- Key Packages table including `HoneyDrunk.Data.Abstractions`, `HoneyDrunk.Data`, `HoneyDrunk.Data.EntityFramework`, `HoneyDrunk.Data.SqlServer`, `HoneyDrunk.Data.Outbox`, `HoneyDrunk.Data.Outbox.Dispatcher`.

Add a new section titled **"ORM Commitment"** (or "Data-Access Stance" — match the file's existing section-naming style at edit time). Content:

```markdown
## ORM Commitment

Per ADR-0072 (Data Access Stance), `HoneyDrunk.Data` ratifies **Entity Framework Core** as the implementation behind the `IRepository<T>` and `IUnitOfWork` contracts in `HoneyDrunk.Data.Abstractions`. The implementation lives in `HoneyDrunk.Data.EntityFramework`.

**Decisions:**

- **EF Core current LTS** tracks the .NET LTS cadence (.NET 8 / EF Core 8, .NET 10 / EF Core 10, .NET 12 / EF Core 12, etc.). Per-Node SemVer concerns.
- **Provider packages:** `HoneyDrunk.Data.SqlServer` for SQL Server backings; future `HoneyDrunk.Data.Npgsql` for Postgres if/when a Node chooses Postgres. Both are EF Core providers.
- **Dapper is the scoped exception** for hot-path read queries where EF generates poor SQL or where allocation matters. Per-Node, per-query. Evidence-burdened (EF query, Dapper query, benchmarks, workload context in the PR). Dapper writes are not permitted; writes go through EF Core's DbContext. See ADR-0072 D2.
- **Migration tool is EF Migrations** per ADR-0048. The migration discipline lives in the per-Node `Migrations/` folder (per ADR-0048 D11); the canonical migration runner is the `migrate.yml` workflow in HoneyDrunk.Actions.
- **Per-Node DbContext.** Each Node owns its own `DbContext`. Sharing across Nodes is forbidden under the Grid's existing boundary discipline (invariant 11 "one repo per Node"; invariant 2's same-layer rule). The per-Node `HoneyDrunk.<Node>.Data` project hosts the DbContext, entity classes, and EF model configurations.
- **Migration path away from EF Core** is bounded by the `IRepository<T>` / `IUnitOfWork` abstraction. Consumers depend on the contracts, not on `DbContext` directly. If EF Core's trajectory ever turns hostile (license change, hostile maintenance, Microsoft sunset), the migration path is per-Node mechanical rewriting of `HoneyDrunk.Data.EntityFramework` against a different ORM. See ADR-0072 D7.

**Negative form (per ADR-0072 D1 / Alternatives Considered):**

- **Dapper is not the default** — scoped exception only with evidence.
- **Marten is not adopted as a Grid-wide default** — over-fit for the Grid's CRUD-shaped data; permitted as a per-Node backing for a Node whose specific contract is event-sourcing-shaped, but no such Node exists today.
- **Raw ADO.NET is not the default** — re-derives change tracking, migration discipline, model composition per Node.
- **Entity Framework 6 / Classic is forbidden for new work** — maintenance mode, tied to .NET Framework.
- **RepoDb / Pomelo / freshly-released micro-ORMs are not adopted as defaults** — community / AI-assistance maturity not at Dapper's or EF Core's level in 2026.

**Query discipline (per ADR-0072 D5):** `AsNoTracking()` on read-only queries; projections preferred for column-subset reads; `Include` is explicit and lazy loading is off; N+1 queries are caught at review; compiled queries (`EF.CompileQuery`) are permitted for hot paths; raw SQL via `FromSqlRaw` is parameterized — never string-interpolated. Enforced by the generalist `review` agent's D3 category 13 surface check and the `database` specialist agent's depth rubric.

**Testing discipline (per ADR-0072 D6):** in-memory provider (`Microsoft.EntityFrameworkCore.InMemory`) for fast unit tests per ADR-0047 D2; Testcontainers per ADR-0047 D4 (Tier 2b) for integration tests where the actual SQL provider's behavior matters. Dapper code is tested via Testcontainers — the in-memory provider does not apply.
```

Place the new section after the existing Key Packages table and before any subsequent sections. Match the file's existing heading hierarchy (probably `##` for top-level Node sections).

## Affected Files
- `repos/HoneyDrunk.Data/overview.md`

## NuGet Dependencies
None. This packet touches only a Markdown governance file; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. `repos/{Node}/...` files are per-Node governance docs that live in the Architecture repo.
- [x] No code change in any other repo.
- [x] The per-Node overview is consistent with ADR-0072's D1/D4 commitments.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Data/overview.md` carries a new "ORM Commitment" (or "Data-Access Stance") section recording EF Core as the ratified ORM behind `IRepository<T>` / `IUnitOfWork` per ADR-0072 D1/D4
- [ ] The new section carries the negative form (Dapper not default, Marten not adopted, raw ADO.NET not default, EF 6 forbidden, RepoDb / Pomelo not adopted) per ADR-0072 D1
- [ ] The new section carries the query-discipline summary per ADR-0072 D5 and the testing-discipline summary per ADR-0072 D6
- [ ] The new section names the migration-path-away mechanism per ADR-0072 D7 (bounded by `IRepository<T>` / `IUnitOfWork` abstraction)
- [ ] No edit to any `integration-points.md` file (that work is packet 03b)
- [ ] No edit to `catalogs/grid-health.json`
- [ ] No edit to any Node repo
- [ ] No invariant change

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0072 D1 — EF Core as the default ORM.** Every Node touching a relational store uses EF Core. Marten / RepoDb / raw ADO.NET / EF 6 / Pomelo are not defaults.

**ADR-0072 D2 — Dapper as the scoped exception with mandatory evidence.** Per-Node, per-query. Scoped to read paths only.

**ADR-0072 D4 — Per-Node DbContext, scoped composition.** Each Node owns its own DbContext. `HoneyDrunk.<Node>.Data` hosts the DbContext, entity classes, EF model configurations. Connection strings come from Vault per ADR-0005.

**ADR-0072 D5 — Query discipline.** `AsNoTracking()` / projections / explicit `Include` / lazy off / parameterized raw SQL.

**ADR-0072 D6 — Testing discipline.** In-memory provider for unit; Testcontainers for integration.

**ADR-0072 D7 — Migration path away from EF Core is bounded.** Consumers depend on `IRepository<T>` / `IUnitOfWork`, not on `DbContext` directly. Swapping the implementation is a per-Node mechanical move.

**Invariants 2 and 11 (referenced) — Same-layer dependency rule and one-repo-per-Node.** Together cover the per-Node DbContext rule: a DbContext shared across Nodes forces a runtime dependency between Nodes at the same layer (violating invariant 2) and implies two Nodes co-owning a deployable surface (violating invariant 11).

## Constraints
- **Single-file packet.** Touches only `repos/HoneyDrunk.Data/overview.md`. The per-Node `integration-points.md` sweep is packet 03b.
- **Match existing `overview.md` styling.** Heading hierarchy, list style, link format — match the file's established conventions.
- **No invariant change.** ADR-0072 explicitly does not add invariants; this packet does not edit `constitution/invariants.md`.
- **Inline ADR-0072 D-decisions.** Per the self-containment rule, cite full text not just decision numbers in the per-Node documentation.

## Labels
`feature`, `tier-3`, `core`, `docs`, `adr-0072`, `wave-2`

## Agent Handoff

**Objective:** Update `repos/HoneyDrunk.Data/overview.md` to record EF Core as the ratified ORM behind `IRepository<T>` / `IUnitOfWork` per ADR-0072 D1/D4. No `integration-points.md` edits in this packet.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the ADR-0072 EF Core ratification discoverable from the Grid's governance surface (the Architecture repo's per-Node overview).
- Feature: ADR-0072 Data Access Stance rollout, Wave 2.
- ADRs: ADR-0072 D1/D2/D4/D5/D6/D7 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0072 must be Accepted so the overview update cites its decisions as live rules.

**Constraints:**
- Single-file packet — only `repos/HoneyDrunk.Data/overview.md`.
- Match existing file styling.
- No invariant change.
- Inline ADR-0072 D-decisions as full text.

**Key Files:**
- `repos/HoneyDrunk.Data/overview.md`

**Contracts:** None changed.
