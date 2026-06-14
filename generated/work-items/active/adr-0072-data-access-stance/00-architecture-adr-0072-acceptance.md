---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0072", "wave-1"]
dependencies: []
adrs: ["ADR-0072"]
accepts: ["ADR-0072"]
wave: 1
initiative: adr-0072-data-access-stance
node: honeydrunk-architecture
---

# Accept ADR-0072 — flip status, register the initiative (no new invariants)

## Summary
Flip ADR-0072 (Data Access Stance — EF Core Default, Dapper for Hot-Path Reads) from Proposed to Accepted: update the ADR header, add the row to the ADR index in `adrs/README.md`, and register the `adr-0072-data-access-stance` initiative in `initiatives/active-initiatives.md`. **No new invariants are added** — ADR-0072 explicitly commits its decisions as review-enforced conventions rather than numbered invariants.

## Context
ADR-0072 commits the Grid's data-access stance:

- **D1** — **EF Core is the default ORM** for every Node touching a relational store. EF Core current LTS (tracked to the .NET LTS cadence; LTS releases are the even-numbered .NET majors, e.g., .NET 8 / EF Core 8, .NET 10 / EF Core 10). `Microsoft.EntityFrameworkCore.SqlServer` for SQL Server backings; `Microsoft.EntityFrameworkCore.Npgsql` for Postgres backings. SQL project/DACPAC deployment is the canonical schema deployment standard per ADR-0048. The negative form: Dapper is not the default; Marten is not adopted; raw ADO.NET is not the default; Entity Framework 6 / Classic is forbidden for new work; RepoDb / Pomelo / freshly-released micro-ORMs are not adopted as defaults.
- **D2** — **Dapper is the scoped exception** for hot-path read queries where EF Core's generated SQL is measurably worse, allocation profile matters, or the query shape is awkward in LINQ. The evidence burden lives in the PR: the EF-generated query, the hand-written Dapper replacement, and benchmark numbers. Dapper is scoped to **read paths only**; writes go through EF Core's DbContext. Adopting Dapper for one query in a Node does not adopt it for the Node's other queries. `FromSqlRaw` inside EF is the first option when the query still wants EF's change tracking or composition; Dapper is the second.
- **D3** — **SQL project/DACPAC deployment is the schema deployment standard** per ADR-0048. ADR-0072 keeps EF Core as the runtime ORM while SQL projects own the physical schema. Per-Node database projects live alongside the Node's application solution and map back to the Node's DbContext model.
- **D4** — **Per-Node DbContext, scoped composition.** Each Node owns its own `DbContext`(s); sharing across Nodes is forbidden — the Grid's boundary discipline (one repo per Node per invariant 11; runtime packages depend on Abstractions, not other Nodes, per invariant 2) makes a cross-Node `DbContext` a runtime coupling violation. The `HoneyDrunk.<Node>.Data` project hosts the DbContext and entity classes. Connection strings come from Vault per ADR-0005 via `ISecretStore`. Per-tenant partitioning per ADR-0050 is per-Node policy. The repository pattern via `HoneyDrunk.Data` (`IRepository<T>`, `IUnitOfWork`) sits on top of the DbContext.
- **D5** — **Query discipline**: `AsNoTracking()` on every read-only query; projections (`Select`) preferred over full entity loads when only a subset of columns is needed; `Include` is explicit and lazy loading is off; N+1 queries are caught at review; compiled queries (`EF.CompileQuery`) are permitted for hot paths where the compile cost amortizes; raw SQL via `FromSqlRaw` is parameterized — never string-interpolated (secure-SQL discipline; no existing numbered invariant covers parameterized SQL — review-enforced per ADR-0072 D5).
- **D6** — **Testing discipline**: in-memory provider (`Microsoft.EntityFrameworkCore.InMemory`) for fast unit tests per ADR-0047 D2; Testcontainers per ADR-0047 D4 (Tier 2b) for integration tests where the actual SQL provider's behavior matters. Dapper code is tested via Testcontainers (Tier 2b) — the in-memory provider does not apply to Dapper.
- **D7** — **Migration path away from EF Core** is bounded by the `HoneyDrunk.Data` repository abstraction. Consumers depend on `IRepository<T>` / `IUnitOfWork`, not on `DbContext` directly. Swapping the implementation to a different ORM is a per-Node mechanical move; the contract surface stays stable.
- **D8** — **Out of scope**: specific database engine choice (per-Node decision); NoSQL data-access stance (per-backing SDKs apply); read-replica routing (per-Node); connection pooling and DbContext lifetime tuning (defaults apply); ORM-level data-classification implementation (per-Node enforcement); connection-resiliency policies (per-Node).

ADR-0072 is a **policy / ratification** ADR. The committed implementation (EF Core via `HoneyDrunk.Data.EntityFramework`) already exists in the Data repo; this initiative ratifies it explicitly, lands the discipline in the `review` agent's rubric and the `database` specialist agent's rubric, and updates the Data Node's README/overview. The remaining code-change work (the EF Core implementation itself, per-Node adoption packets, per-Node Dapper hot-path pilots) is deliberately deferred — see the dispatch plan's Cross-Cutting Concerns for the deferred-follow-ups list.

Every other packet in this initiative references ADR-0072's decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## No New Invariants

ADR-0072's Consequences/Invariants section explicitly states:

> No new Grid-wide invariants are introduced in `constitution/invariants.md`. The following are committed conventions enforced by the `review` agent's data-quality category per ADR-0044 D3:
> - EF Core is the default for relational data access.
> - Writes go through EF Core's DbContext.
> - `AsNoTracking()` on read-only queries; explicit `Include`; lazy loading off.
> - DbContext is per-Node, never shared.
> - Connection strings come from Vault.
>
> If the scope agent judges any of these invariant-class at acceptance time, numbering is added then.

The scope agent's judgment at acceptance time: **none of the five conventions is elevated to a numbered invariant in this packet.** The reasoning per convention:

1. **EF Core as the default ORM** — this is a strong commitment but enforced at PR review by the generalist `review` agent's category 13 (packet 01) and the `database` specialist agent's rubric (packet 02). Elevating it to an invariant would require a per-PR machine-check that "this code uses EF Core" — implementable but redundant with the review-time check.
2. **Writes go through EF Core's DbContext** — same posture: review-enforced. A Dapper-write path is a hard finding under the rubric; an explicit invariant would be a parallel surface with no new enforcement power.
3. **`AsNoTracking()` / explicit `Include` / lazy loading off** — these are *coding patterns* rather than architectural rules. They belong in the per-Node rubric, not in the constitution.
4. **DbContext per-Node, never shared** — this is already covered by the Grid's existing boundary discipline (invariant 11 "one repo per Node" and invariant 2 "runtime packages depend on Abstractions, never on other runtime packages at the same layer"). A `DbContext` shared across Nodes would force a runtime dependency from one Node onto another Node's data layer — a violation of invariant 2's same-layer rule. Adding a redundant invariant would be noise.
5. **Connection strings from Vault** — already covered by the existing Vault discipline and ADR-0005's commitments. No new invariant needed.

The five conventions live in:
- `.claude/agents/review.md` D3 category 13 (packet 01 of this initiative)
- `.claude/agents/database.md` (the `database` specialist agent — file created under sibling initiative `adr-0048-schema-evolution` packet 02; this initiative's packet 02 extends the rubric)
- `repos/HoneyDrunk.Data/overview.md` (packet 03 of this initiative)
- `HoneyDrunk.Data/README.md` (packet 04 of this initiative)

**If a future audit determines that any of these conventions needs invariant-level enforcement** (e.g. the `database` specialist agent has caught repeated violations and the review-time enforcement isn't sticking), a follow-up ADR amendment elevates the convention to a numbered invariant. That is not this packet's concern.

## Scope
- `adrs/ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — add a new row for ADR-0072 with Status `Accepted`, Date `2026-05-23`, Sector `Core / cross-cutting`, and an Impact summary.
- `initiatives/active-initiatives.md` — register the `adr-0072-data-access-stance` initiative with the packet checklist for this folder.
- **No edit to `constitution/invariants.md`.** Per the above, no invariants are added.

## Proposed Implementation
1. Edit the ADR-0072 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Add a new row for ADR-0072 to the table in `adrs/README.md`. The ADR is currently absent from the index. Insert the row in numerical order after ADR-0057 (the table's current last entry). Suggested Impact summary text (taken from the ADR's Decision section, distilled):
   > EF Core as the default ORM for every Node touching a relational store; **Dapper as the scoped exception** for hot-path reads with mandatory evidence (EF query, Dapper query, benchmark numbers) in the PR; writes always through EF Core's DbContext; `AsNoTracking()` / explicit `Include` / lazy loading off as query discipline; per-Node DbContext, scoped composition with `IRepository<T>` / `IUnitOfWork` on top; SQL project/DACPAC deployment is the schema deployment standard per ADR-0048; in-memory provider for unit tests, Testcontainers for integration; migration path away bounded by the `HoneyDrunk.Data` abstraction. **No new invariants** — committed as review-enforced conventions in `.claude/agents/review.md` category 13 and the `database` specialist agent's rubric. Marten / Dapper-as-default / raw ADO.NET-as-default / EF 6 explicitly rejected; the per-Node engine choice (Azure SQL vs Postgres vs Cosmos) and NoSQL access stay out of scope.
3. Register the initiative in `initiatives/active-initiatives.md` under the In Progress section. Add a block in the same format as the existing entries (see ADR-0044, ADR-0047). Include the wave structure and the per-packet checklist for this folder. The block should reference the dispatch plan at `generated/work-items/active/adr-0072-data-access-stance/dispatch-plan.md`.

## Affected Files
- `adrs/ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] No invariant change (ADR-0072 explicitly commits no new invariants — see No New Invariants section).

## Acceptance Criteria
- [ ] ADR-0072 header reads `**Status:** Accepted`
- [ ] A new row for ADR-0072 exists in `adrs/README.md` in numerical order after ADR-0057, with Status `Accepted`, Date `2026-05-23`, Sector `Core / cross-cutting`, and the Impact summary text recorded above
- [ ] `initiatives/active-initiatives.md` registers the `adr-0072-data-access-stance` initiative with a packet checklist matching this folder's contents
- [ ] `constitution/invariants.md` is **unchanged** by this packet
- [ ] No catalog schema change in this packet (any catalog updates are in packets 03)
- [ ] The PR body records the decision *not* to add invariants, with the per-convention reasoning summarized

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0072 D1 — EF Core as the default ORM.** Every Node in the Grid that reads from or writes to a relational database uses Entity Framework Core as the default data-access library. EF Core current LTS, tracked to the .NET LTS cadence. `Microsoft.EntityFrameworkCore.SqlServer` for SQL Server; `Microsoft.EntityFrameworkCore.Npgsql` for Postgres. The .NET ecosystem default; Microsoft's first-party ORM; broadest community familiarity; deepest documentation; most active maintenance; schema-evolution discipline (SQL project/DACPAC deployment) built in; model attributes enable cross-cutting policy (PII classification per ADR-0049); DbContext maps onto per-tenant partition strategy per ADR-0050; tooling depth; AI-assistance leverage.

**ADR-0072 D2 — Dapper as the scoped exception.** Permitted for hot-path read queries where (a) EF's generated SQL is measurably worse, (b) allocation profile matters, or (c) the query shape is awkward in LINQ. Evidence-burdened: every Dapper introduction's PR includes the EF-generated query, the hand-written Dapper replacement, and benchmark numbers. Scoped to read paths only; writes go through EF. `FromSqlRaw` inside EF is the first option; Dapper is the second.

**ADR-0072 D3 — SQL project/DACPAC deployment is the schema deployment standard per ADR-0048.** EF Core remains the runtime ORM; SQL projects are the production schema source of truth. CI per ADR-0012 builds the database project, and the out-of-band database deploy workflow publishes the DACPAC before dependent code deploys.

**ADR-0072 D4 — Per-Node DbContext, scoped composition.** Sharing a DbContext across Nodes is forbidden — a runtime coupling violation under the Grid's existing boundary discipline (invariant 11 "one repo per Node" and invariant 2's same-layer rule). `HoneyDrunk.<Node>.Data` hosts the DbContext, entity classes, configurations. `services.AddDbContext<TContext>(opts => ...)` is the standard registration. Connection strings come from Vault per ADR-0005. Per-tenant partitioning per ADR-0050. The repository pattern via `HoneyDrunk.Data` (`IRepository<T>` / `IUnitOfWork`) sits on top — consumers compose against `HoneyDrunk.Data`'s contracts, not against DbContext directly, preserving the migration option in D7.

**ADR-0072 D5 — Query discipline.** `AsNoTracking()` on every read-only query (change tracking is allocation-heavy and serves writes; reads opt out). Projections preferred (narrower SQL, lower allocation, no change-tracking cost). `Include` explicit; lazy loading off (disabled in default DbContext composition). N+1 queries caught at review. Compiled queries permitted for hot paths. Raw SQL via `FromSqlRaw` is parameterized — never string-interpolated (secure-SQL discipline — no existing numbered invariant covers parameterized SQL; the rule is review-enforced under ADR-0072 D5).

**ADR-0072 D6 — Testing discipline.** In-memory provider for unit (Tier 1 per ADR-0047 D2); Testcontainers for integration (Tier 2b per ADR-0047 D4). Dapper code is tested via Testcontainers — the in-memory provider does not apply.

**ADR-0072 D7 — Migration path away from EF Core is bounded.** Consumers depend on `IRepository<T>` / `IUnitOfWork`, not on `DbContext` directly. Swapping the implementation behind those contracts is a per-Node mechanical move. SQL projects keep the production schema independently described, so the runtime ORM can change without moving the DACPAC deployment path.

**ADR-0072 D8 — Out of scope.** Specific database engine choice (per-Node decision); NoSQL data-access stance (per-backing SDKs apply); read-replica routing (per-Node); connection pooling and DbContext lifetime tuning (defaults); ORM-level data-classification implementation (per-Node enforcement); connection-resiliency policies (per-Node defaults).

**ADR-0072 Consequences — No new invariants.** ADR-0072 commits its five conventions (EF Core default, writes through DbContext, AsNoTracking/Include/lazy-off, per-Node DbContext, connection strings from Vault) as review-enforced, not as numbered invariants. The scope agent's acceptance-time judgment: no convention is elevated. The conventions live in `.claude/agents/review.md` D3 category 13 (packet 01) and `.claude/agents/database.md` rubric (packet 02). See the No New Invariants section above for the per-convention reasoning.

**Invariants 2 and 11 (referenced) — Same-layer dependency rule and one-repo-per-Node.** Together cover the per-Node DbContext rule: a DbContext shared across Nodes would force a runtime dependency from one Node onto another Node's data layer at the same layer (a violation of invariant 2) and would imply two Nodes co-owning a deployable surface (a violation of invariant 11). No new invariant needed.

**`FromSqlRaw` parameterization (review-enforced, not codified as invariant).** No existing numbered invariant covers parameterized SQL. ADR-0072 D5 commits the rule as review-enforced; the generalist `review` agent's D3 category 13 (packet 01) and the `database` specialist agent's rubric (packet 02) carry it. Invariant 8 covers secret values in logs/traces/exceptions/telemetry — a distinct concern; that invariant is **not** the home of the parameterized-SQL rule.

## Constraints
- **Acceptance precedes flip.** ADR-0072 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **No invariants added.** Per the No New Invariants section, do not add any entry to `constitution/invariants.md`. Do not assume a "next free" number; the file is not edited in this packet.
- **ADR index row insertion.** `adrs/README.md` does not currently have a row for ADR-0072. Insert the row in numerical order after ADR-0057 (the current last row), preserving the table's column structure.
- **Initiative slug ≤ 39 chars.** `adr-0072-data-access-stance` is 27 chars — well within the limit.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0072`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0072 to Accepted, add the row to the ADR index, and register the data-access-stance initiative. Do NOT add any invariants.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0072 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0072 Data Access Stance rollout, Wave 1.
- ADRs: ADR-0072 (primary), ADR-0008 (initiative/packet conventions), ADR-0044 (review rubric — convention enforcement home).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0072 stays Proposed until this PR merges.
- **No new invariants.** Do not edit `constitution/invariants.md`. ADR-0072 explicitly commits its decisions as review-enforced conventions.
- Insert the ADR-0072 row in `adrs/README.md` in numerical order after ADR-0057, with the Impact summary text given in Proposed Implementation.
- Match the format of existing in-progress initiative entries in `active-initiatives.md`.

**Key Files:**
- `adrs/ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
