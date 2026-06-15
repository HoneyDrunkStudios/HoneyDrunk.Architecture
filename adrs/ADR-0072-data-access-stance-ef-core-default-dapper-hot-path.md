# ADR-0072: Data Access Stance — EF Core Default, Dapper for Hot-Path Reads

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

The Grid has [`HoneyDrunk.Data`](../repos/HoneyDrunk.Data/overview.md) Live in the Core sector — repository pattern, unit of work, tenant-aware data, transactional outbox. What `HoneyDrunk.Data` does **not** commit is **which ORM or data-access library** sits underneath. Today:

- **Most Nodes that touch relational data are scaffolded but not yet in production**, so the question has not been forced at scale. The few that have data access today (Vault's secret cache backing, AI's cost-rate cache, Communications's pre-implementation preference store) all use ad-hoc compositions.
- **[ADR-0048](./ADR-0048-data-schema-evolution-and-migration-policy.md) (Schema Evolution)** commits **SQL Server database projects and DACPAC deployment** as the canonical production schema path. EF Core remains the runtime ORM decision, not the production schema deployment mechanism.
- **[ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) (PII Handling)** introduced data-classification attributes on entity models. The classification mechanism assumed an ORM with model-attribute support — EF Core fits that shape natively; raw ADO.NET does not.
- **No drift has happened yet**, but every queued Node that touches data (Notify Cloud's tenant store, Identity's `IdentityMap`, Audit's primary write path, Communications's preference store) is about to pick independently. The choice will be made implicitly by the first packet that lands, and the precedent will be near-permanent.

The forcing functions converging now:

- **[ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md)** stands up the Identity Node with `IdentityMap`, `UserRecord`, `UserProfile`, `ExternalSubjectMap` — four tables, all needing EF-model-attribute support for PII classification per ADR-0049.
- **[ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md)** introduces the Files Node with a blob-metadata table.
- **[ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) / [ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md)** Audit Node's primary write path is append-only-by-interface; the underlying table is high-write, query-light, and one of the candidates that might be argued as a "Dapper-only" exception. Settling the default before Audit ships its production-grade backing matters.
- **[ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md)** introduces per-tenant data partitions. The partition mechanic (per-tenant connection string, per-tenant schema, per-tenant DbContext) leans heavily on EF Core's DbContext model.

This ADR commits the **default** (EF Core), the **scoped exception** (Dapper for hot-path reads where EF generates poor SQL or where allocation matters), and the **non-options** (no Marten, no raw ADO.NET default, no alternative ORMs).

The charter framing ([`constitution/charter.md`](../constitution/charter.md) §"Why we build this way" item 1):

> Building things well — at a level a serious engineer would respect — is satisfying in itself. The substrate gets to be enterprise-grade because that's the point, not because anyone is paying for it.

The data-access stance is enterprise-grade-substrate-shaped: pick the boring, well-understood default; permit the scoped exception where the default doesn't earn its keep; commit to both with discipline.

## Decision

### D1 — EF Core is the default ORM for every Node touching a relational store

Every Node in the Grid that reads from or writes to a relational database uses **Entity Framework Core** as the default data-access library. The committed shape:

- **EF Core current LTS** (tracked to the .NET LTS cadence per the Grid's general framework discipline; LTS releases are the even-numbered .NET majors, e.g., .NET 8 / EF Core 8, .NET 10 / EF Core 10, etc.).
- **`Microsoft.EntityFrameworkCore.SqlServer`** for SQL Server backings (Azure SQL is the Grid's default per the existing Azure-first posture).
- **PostgreSQL is not a v1 production schema-deployment target under ADR-0048.** If a future Node chooses PostgreSQL, that Node needs an explicit ADR amendment or follow-up decision that defines the provider-specific schema deployment standard. EF Core remains compatible with Npgsql at runtime, but Npgsql is not adopted as a production deployment path here.
- **SQL projects/DACPACs** as the canonical production schema deployment path per [ADR-0048](./ADR-0048-data-schema-evolution-and-migration-policy.md). EF Core maps to that schema at runtime.

**Why EF Core as the default:**

- **It is the .NET default.** Microsoft's first-party ORM, broadest community familiarity, deepest documentation, most active maintenance. A solo dev plus AI agents working in .NET have the most leverage on EF Core of any data-access option.
- **Schema-evolution discipline remains explicit.** EF Core Fluent API maps runtime entities to the SQL project model, while the DACPAC carries production DDL per [ADR-0048](./ADR-0048-data-schema-evolution-and-migration-policy.md). The mapper and deploy artifact have different jobs.
- **Model attributes enable cross-cutting policy.** [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md)'s PII classification attaches naturally to EF model classes via attributes or Fluent API. Cross-cutting concerns (PII detection, encryption at rest hints, soft-delete patterns) compose into the EF model layer cleanly. Raw ADO.NET or micro-ORMs lose this.
- **DbContext maps onto per-tenant partition strategy.** [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md)'s per-tenant partition mechanic uses DbContext-per-tenant or schema-per-tenant approaches that are first-class in EF Core. Dapper or raw ADO.NET would re-derive the partition mechanic per Node.
- **Tooling depth.** EF Core has scaffolding, change tracking, query analysis, second-level cache integration (which the Grid does not adopt today but might revisit), and a mature .editorconfig / Roslyn-analyzer story.
- **AI-assistance leverage.** Claude, Codex, and Copilot have deep pattern recognition on EF Core in 2026. EF Core idioms (LINQ projections, `Include` for navigation properties, raw-SQL escape hatches via `FromSqlRaw`) are well-known territory.
- **Long support runway.** Microsoft has shipped EF Core continuously since 2016; the .NET LTS cadence underwrites long-term viability. The many-decade horizon ([`constitution/charter.md`](../constitution/charter.md)) favors options with the longest survivability.

The negative form: Dapper is **not** the default; Marten is not adopted; raw ADO.NET is not the default; Entity Framework 6 / Classic is forbidden for new work; RepoDb / Pomelo / freshly-released micro-ORMs are not adopted.

### D2 — Dapper is permitted for hot-path read queries where EF generates poor SQL or where allocation matters

**Dapper** is the **scoped exception**, permitted for specific read paths where:

- **EF Core's generated SQL is measurably worse** than a hand-written query, and the measurable difference matters at the consuming workload's scale. "Measurably worse" is a query-plan-explored, profiler-confirmed determination — not a vibe. The packet that introduces a Dapper query includes the EF-generated query, the hand-written replacement, and the benchmark evidence in the PR.
- **Allocation profile matters** — high-frequency reads where EF's change-tracking overhead and entity hydration cost dominates. Dapper's "map row to POCO and drop the row" model wins decisively on read-only, high-frequency paths. Same evidence discipline applies.
- **The query shape is awkward in LINQ** — complex window functions, recursive CTEs, hierarchical queries, vendor-specific features that EF does not surface idiomatically. Falling back to `FromSqlRaw` inside EF is the first option; Dapper is the second.

The committed posture:

- **When in doubt, EF Core.** The default carries no justification burden; the exception does.
- **Dapper is scoped to read paths.** Writes go through EF Core's DbContext so the change-tracking / outbox / unit-of-work story is preserved. A Dapper-write path would diverge from `HoneyDrunk.Data`'s repository / unit-of-work pattern and is not permitted by default.
- **Per-Node, per-query.** Adopting Dapper for one query in a Node does not adopt it for the Node's other queries; the EF default still applies to everything else.
- **Justification lives in the PR.** Every Dapper introduction is reviewed for evidence (EF query, Dapper query, benchmark numbers, workload context). The `review` agent's data-quality category per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 gains a check: "is this Dapper introduction evidence-backed?"

**Why Dapper for the exception (not `FromSqlRaw` inside EF):**

- **Dapper is honest about what it is.** A micro-ORM that maps rows to POCOs. No change tracking, no lazy loading, no implicit hidden behavior. When a query needs to be hand-written, the surrounding code wants to be honest about that too.
- **`FromSqlRaw` inside EF is the in-between answer.** It is preferred over Dapper when the hand-written query still wants EF's change tracking or composition. The two coexist: `FromSqlRaw` for queries that compose with EF's pipeline; Dapper for queries that escape EF's pipeline entirely. The decision lives at the per-query review.
- **Dapper has a similar long-runway as EF Core.** Stack Overflow's micro-ORM, in continuous use since 2011, governed by a small stable team. The many-decade horizon ([`constitution/charter.md`](../constitution/charter.md)) is not threatened.

### D3 — SQL projects and DACPACs own production schema deployment per ADR-0048

[ADR-0048](./ADR-0048-data-schema-evolution-and-migration-policy.md) commits SQL Server database projects and DACPAC deployment as the production schema-evolution tool. This ADR keeps EF Core in its runtime role: mapping entities, coordinating writes, and composing with HoneyDrunk.Data. EF Core migrations are not the production schema deployment path.

**Per-Node SQL projects live alongside the Node solution.** A schema-bearing Node hosts `HoneyDrunk.<Node>.Database` in the solution. The runtime project hosts the `DbContext`, entity classes, and Fluent API configurations that map to that SQL project schema. CI builds both, and the database deploy workflow publishes the DACPAC before the app rollout.

**Cross-Node schema concerns** (e.g., Identity's `IdentityMap` and Audit's pseudonymization-token store both touching the user-identity domain per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) D3) follow per-Node SQL project discipline; the Grid does not have a cross-Node schema coordinator and does not intend to. Per-Node schemas interlock through contract versioning per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md), not through a shared migration runtime.

### D4 — Per-Node DbContext, scoped composition

Each Node that touches data owns its own `DbContext`(s). Sharing a DbContext across Nodes is forbidden — it would break the Grid's boundary discipline (a runtime coupling violation under [invariant 2](../constitution/invariants.md) "Runtime packages depend on Abstractions, never on other runtime packages at the same layer" and [invariant 11](../constitution/invariants.md) "One repo per Node") and produce hidden coupling across deployable surfaces.

The composition shape:

- **`HoneyDrunk.<Node>.Data` project** hosts the DbContext, the entity classes, and the entity configurations.
- **`HoneyDrunk.<Node>` runtime composition** registers the DbContext in DI per the standard ASP.NET Core pattern: `services.AddDbContext<TContext>(opts => ...)`.
- **Connection strings come from Vault** per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) — the Node's per-environment connection string lives in its Vault namespace and is resolved through `ISecretStore`. No connection strings in `appsettings.json` or environment variables directly.
- **Per-tenant partitioning** per [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) is per-Node policy — most Nodes use the default-tenant-per-database pattern; the Notify Cloud tenant store uses per-tenant partitions (schema-per-tenant or database-per-tenant per ADR-0050's commitment).
- **The repository pattern via `HoneyDrunk.Data`** sits on top of the DbContext. `IRepository<T>` and `IUnitOfWork` are EF Core implementations; consumers compose against `HoneyDrunk.Data`'s contracts, not against DbContext directly. This preserves the option (D7) of swapping the implementation later if EF Core ever becomes untenable.

### D5 — Query discipline

Default EF query patterns, applied at code review per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 category 11 (Data quality):

- **`AsNoTracking()` on every read-only query.** Change tracking is allocation-heavy and serves writes; read paths should explicitly opt out.
- **Projections (`Select`) preferred over full entity loads** when the consumer needs a subset of columns. `Select` produces narrower SQL, lower allocation, and removes the change-tracking cost.
- **`Include` is explicit; lazy loading is off.** EF Core's lazy loading is disabled in the default DbContext composition. Eager-loading via `Include` is the only navigation-property mechanism; explicit-loading is permitted where it earns its keep.
- **N+1 queries are caught at review.** The `review` agent's data-quality category checks for the `foreach (var item in list) { var related = ctx.Related.Where(...).ToList(); }` pattern.
- **Compiled queries (`EF.CompileQuery`)** are permitted for hot-path reads where the compile cost amortizes — these are the boundary cases where Dapper might also be considered. Compiled query is the EF-side first option; Dapper is the EF-side-escape.
- **Raw SQL via `FromSqlRaw` is parameterized** — never string-interpolated. Standard secure-SQL discipline; no existing numbered invariant covers parameterized SQL, so this rule is review-enforced via D5 here, with surface checks in `.claude/agents/review.md` D3 category 13 and depth checks in `.claude/agents/database.md`. ([Invariant 8](../constitution/invariants.md) covers secret values in logs/traces — a distinct concern, not parameterized SQL.)

### D6 — Testing discipline

EF Core is testable with two well-known patterns:

- **In-memory provider (`Microsoft.EntityFrameworkCore.InMemory`)** for fast unit tests where the SQL provider's specific behavior is not under test. Per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D2's unit-tier scope.
- **Testcontainers per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D4 (Tier 2b)** for integration tests where the actual SQL provider's behavior matters (DACPAC publish, indexes/constraints, vendor-specific SQL features). The in-memory provider does not implement full SQL Server semantics; Testcontainers is the way to validate against the real engine.

Dapper code is tested via Testcontainers (Tier 2b) — the in-memory provider does not apply to Dapper. A Dapper hot-path read introduced per D2 requires a Tier 2b integration test that exercises the actual query against a real database engine.

### D7 — Migration path away from EF Core

The Grid commits to EF Core today. If EF Core's trajectory ever turns hostile (license change, hostile maintenance, Microsoft sunset), the migration path is bounded by the `HoneyDrunk.Data` repository abstraction:

- **`IRepository<T>` and `IUnitOfWork`** are the consumer contracts. Consumers do not depend on `DbContext` directly. Swapping the implementation behind those contracts to a different ORM is a per-Node mechanical move.
- **The migration cost per Node is the rewriting of the `HoneyDrunk.Data.EF` implementation against a different ORM**. The contract surface stays stable; the consumer code compiles unchanged.
- **Schema deployment is already decoupled.** Moving away from EF Core would not require moving production schema deployment, because SQL projects/DACPACs already own that path. The painful work is remapping runtime persistence to a new ORM or data-access layer.

The escape valve is not exercised today; it is documented to be transparent about the lock-in cost. EF Core is healthy and aligned with the Grid; the migration path exists in case that changes.

### D8 — Out of scope

The following are explicitly **not** decided by this ADR:

- **Specific database engine outside SQL Server/Azure SQL.** SQL Server/Azure SQL is the v1 relational deployment target per ADR-0048. A future PostgreSQL or other relational backing requires a provider-specific ADR amendment or follow-up decision that defines schema deployment, testing, and operations. Cosmos and other document stores follow their own SDK/schema-on-read posture.
- **NoSQL data-access stance.** The Audit Node may use Cosmos DB per [ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md); the Cache Node may use Redis per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md). NoSQL backings have their own SDKs (Azure.Storage.Blobs, Microsoft.Azure.Cosmos, StackExchange.Redis); EF Core's Cosmos provider is permitted but not required. This ADR's scope is relational data.
- **Read-replica routing.** When a Node needs read replicas for scale, the routing mechanism (EF Core interceptor, application-level routing, connection-string switching) is a per-Node decision.
- **Connection pooling and DbContext lifetime tuning.** Standard ASP.NET Core defaults apply; per-Node tuning is permitted but not committed here.
- **ORM-level data-classification implementation.** [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) commits the classification taxonomy and the attribute / Fluent API discipline; the per-Node enforcement (e.g., audit-on-read for Restricted columns, automatic masking in logs) is per-Node work, not this ADR's scope.
- **Connection-resiliency policies (Polly + EF's `EnableRetryOnFailure`).** Per-Node defaults apply; the precise retry policy is per-Node.

## Consequences

### Affected Nodes

- **[`HoneyDrunk.Data`](../repos/HoneyDrunk.Data/overview.md)** — primary affected Node. The `IRepository<T>` / `IUnitOfWork` implementations land as EF Core implementations. Already-stood-up; this ADR ratifies the implicit ORM and adds the Dapper-exception discipline.
- **[ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) (Identity)** — `IdentityMap`, `UserRecord`, `UserProfile`, `ExternalSubjectMap` are EF Core models with PII classification attributes per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md).
- **[ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md) (Files)** — blob-metadata table is an EF Core model.
- **[ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) / [ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md) (Audit)** — primary write path is EF Core (the append-only-by-interface discipline is preserved at the contract layer; the underlying writes are EF Core inserts). The audit-query surface may use Dapper for hot-path read queries (forensic queries with complex temporal filters) per D2.
- **[ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) (Notify Cloud)** — tenant-data partitions use per-tenant DbContext composition per [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md). Send-history queries are a candidate for Dapper hot-path optimization once the workload data exists.
- **[ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) (Communications)** — preference store and decision-log are EF Core models.
- **Consumer-app PDRs** ([PDR-0003](../pdrs/PDR-0003-lately-currents-based-connection-app.md), [PDR-0005](../pdrs/PDR-0005-hearth-personal-growth-as-a-living-town.md), [PDR-0006](../pdrs/PDR-0006-currents-social-suggestions-and-quests.md), [PDR-0008](../pdrs/PDR-0008-curiosities-discovery-first-city-app.md)) — each consumes EF Core for relational data when it uses a relational backing. SQL Server/Azure SQL is the v1 production schema deployment path; any PostgreSQL choice needs the D8 follow-up decision.

### Invariants

No new Grid-wide invariants are introduced in `constitution/invariants.md`. The following are committed conventions enforced by the `review` agent's data-quality category per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3:

- **EF Core is the default for relational data access.** Adopting Dapper for a query requires evidence per D2.
- **Writes go through EF Core's DbContext.** Dapper-write paths require an ADR amendment.
- **`AsNoTracking()` on read-only queries; explicit `Include`; lazy loading off.** Per D5.
- **DbContext is per-Node, never shared.** Per D4.
- **Connection strings come from Vault.** Per D4 / [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md).

If the scope agent judges any of these invariant-class at acceptance time, numbering is added then.

### Operational Consequences

- **The Grid carries one ORM (EF Core) plus one scoped micro-ORM (Dapper).** Both have long support runways; both are well-known; both have deep AI-assistance coverage. The operational footprint is bounded.
- **The Dapper-exception discipline depends on evidence in PRs.** A lazy Dapper introduction (no benchmark, no EF query comparison, no workload context) is rejected at review. The review agent's checklist enforces it.
- **SQL projects/DACPACs are the canonical production schema path.** Per-Node database projects are mechanical; the database deploy workflow scales to N SQL Server-backed Nodes without coupling schema deployment to app startup.
- **In-memory provider speeds unit tests; Testcontainers covers integration semantics.** Per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md). Solo-dev velocity benefits.
- **Per-Node DbContext preserves boundary discipline.** No cross-Node DbContext sharing means no hidden coupling, even when two Nodes touch related domain concepts.
- **The EF Core lock-in is real but bounded.** Per D7, the `IRepository<T>` abstraction means migration cost is rewriting one implementation per Node, not rewriting consumer code. The lock-in cost is acknowledged.

### Follow-up Work

- `HoneyDrunk.Data` ratifies EF Core as the implementation behind `IRepository<T>` / `IUnitOfWork`. Existing implementations align (or already align) with this ADR.
- Each new data-touching Node packet (Identity, Files, Notify Cloud tenant store, Communications preference store, consumer-app PDRs) cites this ADR's EF Core default in its scaffolding.
- The `review` agent's checklist gains the Dapper-evidence and EF-discipline checks per D5.
- A per-Node tutorial / template for "how to add a new entity, add the SQL project table/index files, map it with Fluent API, and ship the DACPAC in CI" lands as part of the DX-baseline ADR (per the [charter-aware draft cluster 4.1](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md)).
- Watch list: EF Core's stewardship continues; Dapper's continues; the migration-path escape valve (D7) stays dormant unless triggered.

## Alternatives Considered

### Dapper as the default, EF Core for the exception

Considered. The argument: micro-ORM is fast, predictable, no hidden behavior; ORM-shaped magic (change tracking, lazy loading, navigation properties) is a known source of pain.

Rejected. The Grid's data-access discipline benefits more from EF Core's broader feature set (model-attribute composition, per-tenant DbContext patterns, change tracking when wanted, navigation properties when useful) than from Dapper's narrower contract. Most Grid data access is CRUD-shaped — EF Core wins decisively on developer velocity for CRUD. The hot-path read scenarios where Dapper wins are real but minority. Defaulting to the minority case taxes the majority for the benefit of the few.

### Marten (PostgreSQL-event-sourcing-first)

Considered. Marten is a mature, well-stewarded library that turns PostgreSQL into a document database + event store. The argument: event sourcing is good architectural discipline; Marten makes it cheap; the Grid's audit substrate per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) is event-sourcing-shaped.

Rejected as a default. Marten is **over-fit** for the Grid's general data needs. The Grid is mostly CRUD-shaped data (user records, tenant configs, preferences) with selective event-sourcing in specific places (audit, perhaps the AI-sector's conversation history). Defaulting to Marten would force every Node onto an event-sourcing model when most Nodes do not need it. The selective use of Marten in specific Nodes (a future Audit-backing decision; a future event-store-shaped Node) is not foreclosed by this ADR — Marten could be the backing implementation for one Node's specific contract — but the Grid-wide default stays EF Core.

### Raw ADO.NET as the default

Considered. The argument: zero abstraction overhead, maximum control, no hidden behavior.

Rejected. The Grid does not have the operational scale where ADO.NET's overhead-zero pays for the cognitive cost. EF Core's higher-level abstraction is the right trade for solo-dev productivity; ADO.NET as a default would re-derive change tracking, unit-of-work behavior, and model composition per Node — at which point we have N partial ORM implementations. Raw ADO.NET is permitted where Dapper is permitted (D2's evidence-backed hot-path scenario), but the default is EF Core.

### Entity Framework 6 / Classic (the .NET-Framework-era EF)

Considered briefly for completeness. The argument: feature-mature, well-known.

Rejected. EF 6 is in maintenance mode and tied to .NET Framework. The Grid is on .NET (Core) per its existing posture. EF 6 would be a regression on every dimension that matters — async support, performance, active development, AI-assistance coverage.

### Pomelo (community-maintained MySQL provider for EF)

Considered in the context of "would Pomelo + MySQL be a credible default." Pomelo is a community EF Core provider, not an ORM in itself.

Not adopted because MySQL is not a v1 Grid relational deployment target. SQL Server/Azure SQL is the committed v1 path per ADR-0048, and any future MySQL or PostgreSQL adoption requires a provider-specific ADR amendment or follow-up decision. If one ever does choose MySQL, Pomelo is the relevant EF Core provider, but that is outside this ADR's v1 commitment.

### RepoDb or other micro-ORM alternatives to Dapper

Considered. RepoDb is a newer micro-ORM with EF-like ergonomics on top of micro-ORM performance.

Rejected as immature relative to Dapper. RepoDb's community size, AI-assistance coverage, and ecosystem maturity in 2026 are markedly behind Dapper. The Dapper choice for the scoped exception (D2) is the boring, well-understood default — exactly the kind of choice the charter favors. If RepoDb's trajectory closes the gap meaningfully in 2027–2028, this ADR is revisable; today Dapper is the right exception.

### Adopt EF Core's `IModelInterceptor` and `ISaveChangesInterceptor` for cross-cutting concerns (PII redaction, audit emission, soft-delete) as a Grid invariant

Considered. The argument: EF Core's interceptor model is powerful; codifying its use Grid-wide ensures cross-cutting concerns compose into the data layer consistently.

Deferred, not rejected. Interceptors are powerful and the Grid will likely use them (PII handling per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md), audit emission per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md)), but the per-Node enforcement pattern is per-Node work — the scope of this ADR is the ORM choice. A follow-up ADR or amendment may commit a Grid-wide interceptor discipline once the patterns settle in production.

### Multiple ORMs per Node (use whichever fits the query)

Considered. The argument: a Node could use EF Core for its CRUD writes and Dapper for its reads as a routine pattern, with no per-query justification.

Rejected per D2. The evidence-burden on Dapper introductions is the discipline that keeps the Grid out of "two ORMs everywhere, neither fully understood" territory. The per-Node, per-query justification keeps Dapper scoped to the cases where it earns its keep. Routine Dapper-for-reads without evidence is exactly the slide this ADR exists to prevent.

### Skip the ADR and let Nodes pick per-packet

Considered. The argument: ORM choice is a tactical concern; let each Node's first data packet pick.

Rejected. Without an ADR, each Node re-derives the choice and the Grid ends up with EF Core in some, Dapper in others, Marten in a third, and the cross-Node patterns (classification attribution, per-tenant partitioning, unit-of-work behavior) become per-Node ad-hoc. The cost of letting drift accumulate is N rewrites later when the Grid forces consolidation. Pinning the default now is the cheapest substrate posture.

## References

- [`constitution/charter.md`](../constitution/charter.md) — enterprise-grade-substrate framing, many-decade horizon, boring-defaults preference
- [`constitution/invariants.md`](../constitution/invariants.md) — invariant 2 (runtime packages depend on Abstractions; same-layer rule) and invariant 11 (one repo per Node), together covering the per-Node DbContext rule; invariant 8 (secret values never in logs/traces) covers a distinct concern from parameterized SQL — the `FromSqlRaw` rule is review-enforced under ADR-0072 D5 with no existing numbered invariant home
- [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) — connection strings via Vault
- [ADR-0012](./ADR-0012-grid-cicd-control-plane.md) — CI/deploy workflow control plane
- [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) / [ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md) — Audit Node (primary write path is EF Core; hot-path forensic queries are Dapper-candidates)
- [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) — contract-versioning discipline applied to data-layer interfaces
- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 category 11 — data-quality review checks (Dapper evidence, EF discipline)
- [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) — testing pyramid (in-memory provider for unit, Testcontainers for integration)
- [ADR-0048](./ADR-0048-data-schema-evolution-and-migration-policy.md) — SQL projects and DACPACs as the production schema deployment path
- [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) — PII classification via EF model attributes
- [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) — per-tenant DbContext composition
- [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md) — Identity Node entities (EF models per this ADR)
- [ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md) — Files Node blob-metadata table
- [repos/HoneyDrunk.Data/overview.md](../repos/HoneyDrunk.Data/overview.md) — `HoneyDrunk.Data` boundary (this ADR ratifies the ORM behind it)
