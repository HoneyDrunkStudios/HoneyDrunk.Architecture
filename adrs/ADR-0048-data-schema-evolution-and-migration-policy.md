# ADR-0048: Data Schema Evolution and Migration Policy

**Status:** Proposed
**Date:** 2026-05-22
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

The Grid has no formal schema-evolution policy. Today:

- **No Node has shipped a non-trivial production migration yet.** Notify carries an EF Core `DbContext` with one or two migrations generated at scaffold time; nothing has been deployed against a populated store with traffic on it. Pulse uses Cosmos and has been schemaless by accident rather than by decision. Vault's persistent store is Key Vault itself (not a relational schema). The first real "deployed-and-populated" migrations are imminent: Audit standup (ADR-0031), Memory and Knowledge standups (ADR-0021/0022), and the future Billing Node (ADR-0037) all introduce relational stores that will outlive any single deploy.
- **ADR-0036 (Disaster Recovery, Proposed) presumes migrations exist** — it talks about geo-redundant SQL backups, restore drills, and point-in-time recovery windows, all of which assume schema evolution happens *somehow*. Nothing names the somehow.
- **ADR-0042 (Idempotency Contract, Proposed) presumes a dedup-state table** with a specific shape (`IdempotencyKey → (FirstSeenAt, Outcome)`, partitioned by consumer-group, TTL'd). Adding new columns to that table mid-flight, or evolving its key shape, has zero defined process today.
- **ADR-0033 (Environment-Gated Deploy Trigger Model, Accepted) is silent on migration timing.** D1 commits push-to-`main`-to-`dev` and tag-to-`staging`/`prod` triggers; it says nothing about whether schema migrations run before, during, or after the code deploy that depends on them. The question is unavoidable but unanswered.
- **ADR-0015 (Container Hosting Platform, Accepted) D6 (Revision strategy)** commits Container Apps to `Multiple` revision mode with traffic splitting — meaning during any deploy, two code revisions are alive against the same database for a measurable window. The schema must be compatible with **both** code revisions for the duration of that window. Nothing names how.
- **ADR-0030 (Grid-Wide Audit Substrate, Accepted) mandates append-only-by-interface** for the Audit store. Migrations on that store carry stronger constraints than other Nodes — drops, renames, and type narrowing are interface-violating, not merely risky. The mechanics of safely evolving an append-only-by-interface store are nowhere documented.
- **ADR-0026 (Grid Multi-Tenant Primitives, Accepted) introduces `TenantId` everywhere.** The question of tenant-scoped vs Grid-wide migrations is open: Notify Cloud will eventually have per-tenant partitions; the migration story for "add a column to a tenant-scoped table across N tenant partitions" is materially different from "add a column to a single shared table."

The forcing functions for codifying this now:

- **Audit standup (ADR-0031) is the first Tier 0 Node that will live for years and accumulate migrations.** An append-only-by-interface store with no migration policy is the highest-cost place to invent one ad-hoc.
- **Memory and Knowledge standups (ADR-0021/0022)** introduce embedding stores and document indexes whose schemas will evolve as the AI sector matures. Each Node inventing its own pattern produces three incompatible migration stories before the AI sector has even shipped.
- **Billing standup (ADR-0037, Proposed)** will hold Stripe-reconciled tenant ledger data — wrong-schema or lost-data outcomes are commercially disqualifying. Migration policy must exist before Billing's first table.
- **Notify Cloud GA (PDR-0002 / ADR-0027)** is the first commercial product; per-tenant data will accumulate; the deploy cadence will pick up; the "two revisions alive at once" property from ADR-0015 D6 will be exercised every release. Schema-compatibility-across-revisions is no longer a future concern.
- **ADR-0042's `IIdempotencyStore` contract test** (now formalized as a Tier 2a contract test per ADR-0047 D4) exercises a real backing — meaning the migration that creates the dedup table is itself test-exercised in CI. The pattern that test follows is the de-facto pattern every other Node copies. Better to commit it deliberately.
- **ADR-0047 D4 commits Testcontainers** for Tier 2b integration tests against real Postgres. Migration round-trip testing now has a natural home; the testing surface exists, the policy on what to test there does not.
- **ADR-0044 D3 category 13 (Data and persistence integrity)** binds the `review` agent to a per-PR checklist on data changes. That checklist is meaningless without a committed migration policy to check against. ADR-0046's specialist `database` review agent is the same situation amplified.

This ADR commits to **EF Core Migrations** as the Grid-wide framework, the **expand → migrate code → contract** pattern as the zero-downtime mechanic, the **out-of-band migration job** as the timing model (compatible with ADR-0015 D6's multi-revision window), per-store backward-compatibility windows, append-only-by-interface migration constraints for Audit, tenant-scoped migration ordering, failure-handling and rollback policy, file/naming conventions, and the review surface (cross-cutting `database` specialist agent per ADR-0046).

## Decision

### D1 — Framework: EF Core Migrations

**EF Core Migrations** is the Grid-wide schema-evolution framework for all relational stores (Azure SQL, Postgres). The commitment is explicit:

- **One framework across the Grid.** Audit, Memory, Knowledge, Billing, Idempotency-store, future Notify Cloud tenant data — all use EF Core Migrations. Per-Node framework choice is **not** allowed.
- **EF Core 9.x** at the time of this ADR; the Grid tracks the latest LTS as ADR-0034 (NuGet policy) tracks runtime alignment. The framework version is a per-Node SemVer concern; the migration-tool surface (`dotnet ef migrations add`, `dotnet ef database update`) is stable across recent versions.
- **EF Core Migrations is used for schema only.** Reference-data seeding and feature-flag bootstraps are **not** EF migrations; they live in a separate startup-time seed path with its own idempotency. EF migrations carry DDL; nothing else.

The choice is justified on three grounds: (a) the Grid is already .NET, EF Core is the mainstream .NET ORM, and the migrations surface is well-understood; (b) C# migration scripts can be reviewed by the same agents and people who review the rest of the code (vs SQL-blob tools where review is a separate skill); (c) the `IModelDiff` plus generated SQL pattern means we can ship the same migration as either runtime code or an out-of-band SQL script (per D4), preserving optionality on timing without a framework rewrite.

**Cosmos / document stores are explicitly out of scope** for D1. EF Core has a Cosmos provider but its migrations story is materially weaker than the SQL story. Document-store Nodes (Pulse's signal history, Knowledge's vector store if it lands on a vector-native backing) follow a **schema-on-read** discipline per D7 instead. The migration policy applies to relational stores; document stores have their own evolution rules.

### D2 — The expand → migrate code → contract pattern

Every non-trivial schema change follows three deploys, never one:

| Phase | What changes | Code compatibility |
|-------|--------------|--------------------|
| **Expand** | Add the new shape (new column nullable, new table, new index). Old shape remains. | Old code keeps working; new code can read/write the new shape if present. |
| **Migrate code** | Deploy code that reads/writes the new shape. Old code may still be live (during ADR-0015 D6 traffic split). | Both old and new code coexist; both shapes are present in the schema. |
| **Contract** | Remove the old shape (drop column, drop table, drop index). Only after all consuming code has moved off the old shape. | New code reads/writes only the new shape; old code is gone. |

The window between Expand and Contract is the **backward-compatibility window** (D5); typically two to four deploys. Each phase is a separate PR, a separate migration file, a separate deploy.

**Forbidden in a single deploy:**

- Drop a column that the previous code revision reads or writes.
- Rename a column (semantically a drop + add; do as two phases — add new, migrate code, drop old).
- Narrow a column's type (e.g., `nvarchar(500)` → `nvarchar(100)`) without a paired-table migration if any row could exceed the new bound.
- Change a column's nullability from `NULL` to `NOT NULL` without first populating defaults and shipping code that writes the column.
- Drop a table that the previous code revision references.
- Add a `NOT NULL` column without a default (would fail on existing rows).

**Allowed in a single deploy:**

- Add a nullable column.
- Add a column with a server-side default.
- Add a new table.
- Add an index (concurrently per D6 on Postgres; with `ONLINE=ON` per D6 on Azure SQL).
- Add a new check constraint **as `NOCHECK`** initially, then validate in a later migration.

The expand/contract pattern is **non-negotiable for any Node holding production tenant data** (Audit, Memory, Knowledge, Billing, Notify Cloud). For internal Tier 2 Nodes (Pulse historical, Evals), the pattern is recommended but a single-deploy destructive change is permitted with explicit `[BreakingChange]` annotation on the migration class and a documented downtime window.

### D3 — Migration ordering vs code deploy: out-of-band job

The question is: when does the migration run relative to the code deploy that depends on it? Three options exist; the Grid picks one explicitly.

| Option | Mechanic | Verdict |
|--------|----------|---------|
| **In-process at app startup** | App calls `dbContext.Database.Migrate()` on boot. | **Rejected** — fights ADR-0015 D6 (two revisions racing the same migration); blocks app startup on DDL latency; failure surface is the app process. |
| **Init container / pre-deploy hook** | A sidecar container runs migrations before the new revision accepts traffic. | **Rejected** — still races D6 (two revisions, two init containers, last-write-wins); init container failure looks like deploy failure with poor signal. |
| **Out-of-band migration job, manually triggered, runs before the dependent code deploy** | Dedicated `migrate` GitHub Actions workflow per Node; cuts a SQL script from the migration assembly; applies via Azure SQL / Postgres connection; succeeds independently of the app deploy. | **Chosen.** Migrations are deliberate, observable, separable from code. |

**The committed pattern:**

1. **PR with the migration lands first** (Expand phase). The migration is in the source tree and the migration assembly is built into the Node's CI artifacts, but **no production migration runs yet**.
2. **Operator triggers the `migrate.yml` reusable workflow** (added to HoneyDrunk.Actions per D11) with `(environment, node)` inputs. The workflow uses `dotnet ef migrations script` to produce idempotent SQL from the migration assembly, then applies it via `sqlcmd` (Azure SQL) or `psql` (Postgres) using the GitHub OIDC credential model from ADR-0015. Output is the applied SQL plus the migration history table snapshot, stored as a workflow artifact for forensic value.
3. **Operator triggers the dependent code deploy** (per ADR-0033 D1 — tag for `staging`/`prod`, push for `dev`). The new code revision goes live against the already-migrated schema. During the ADR-0015 D6 traffic-split window, the old code revision also runs against the migrated schema — which is safe **because the migration is in Expand phase** (D2): the old shape is still present, the old code still works.
4. **After the deploy is stable and the old revision is fully drained**, a future PR (Contract phase) removes the old shape. That PR's migration runs through the same `migrate.yml` flow, followed by its own dependent code deploy if the contract phase requires code-side changes.

The out-of-band migration job is **not** an init container, not a pre-deploy hook, not a startup-time call. It is a **separate, deliberate, operator-triggered workflow** whose success is independent of the app deploy. This is the load-bearing decision that makes the rest of the pattern coherent.

**Failure-mode property:** because the migration runs before the code deploy, a migration that fails does **not** roll back the app — the app is still serving the old code against the old schema. The operator fixes the migration, re-runs `migrate.yml`, then proceeds with the code deploy. No partially-deployed state exists.

**Cost:** the operator carries a per-Node migration step in their release runbook. At Grid maturity with five or six migration-bearing Nodes, this is a measurable but tractable burden. Automation (auto-running `migrate.yml` against `dev` on every merge that touches `Migrations/`) is named as a follow-up.

### D4 — Multi-revision compatibility window (interaction with ADR-0015 D6)

ADR-0015 D6 commits Container Apps to `Multiple` revision mode: during any deploy, a new revision comes up at 0% traffic, the deploy workflow shifts traffic to 100% on health-probe success, and the old revision drains. For some window, **two code revisions run simultaneously against the same database**.

The expand/contract pattern (D2) makes this safe: at any point during the deploy, the schema is in a shape compatible with **both** the in-flight code revision and the new code revision.

| Deploy state | Schema state | Old code reads | New code reads |
|--------------|--------------|---------------|----------------|
| Pre-deploy | Original | Original shape | n/a |
| Migration applied (D3 step 2) | Expanded (old + new present) | Original shape — still works | Reads new shape preferentially, falls back to old |
| Both revisions live (ADR-0015 D6 traffic split) | Expanded | Original shape — still works | New shape |
| Old revision drained | Expanded | n/a | New shape |
| Contract PR migration applied (later deploy) | New shape only | n/a | New shape |

The migration is always **monotonically forward-compatible** with the older code revision; the contract phase only happens after the older revision is fully drained.

**Practical encoding:** the new code revision is written to tolerate the old shape's presence (it reads both columns, prefers the new). The old code revision is *not* aware of the new shape — and doesn't need to be, because the schema is additive at the moment the old code is running against it.

The traffic-split window is typically minutes; the backward-compatibility window across deploys is days to weeks (D5). The two are separate concerns; the expand/contract pattern handles both.

### D5 — Backward-compatibility window

A migration's Expand phase and its eventual Contract phase are bounded by a backward-compatibility window. The window defines "how many deploys of the consuming code must coexist with the old schema shape before Contract runs."

| Store class | Window | Rationale |
|-------------|--------|-----------|
| **Audit (per ADR-0030 append-only-by-interface)** | **Indefinite (≥ 730-day retention)** | Append-only stores never drop columns; the old shape lives as long as the rows that wrote it. Contract phase for Audit means "new writes use new shape; old rows retain old shape, queries handle both." See D8. |
| **Tier 0 / Tier 1 customer-facing stores (Notify Cloud, Memory, Knowledge, Billing)** | **Two stable deploys minimum**, or **14 days of uptime** between Expand and Contract, whichever is longer. | Allows a rollback window: if the post-Expand code is reverted, the schema still supports it. |
| **Tier 0 Vault and adjacent secret-state stores** | **N/A — Key Vault has no relational schema; secret-shape evolution is governed by ADR-0006, not this ADR.** | |
| **Tier 2 internal stores (Pulse history, Evals)** | **One stable deploy minimum** between Expand and Contract. | Best-effort posture; explicit downtime acceptable for destructive changes via `[BreakingChange]` annotation per D2. |
| **Idempotency stores (per ADR-0042)** | **Two stable deploys minimum**, or **30 days of uptime** (matching ADR-0042 D4's billing/audit TTL). | The dedup state must survive rollback of the consumer; old entries must remain legible to the old code revision. |

The window is **enforced by review** (ADR-0044 D3 category 13; ADR-0046 specialist `database` agent per D10) — a PR titled "Contract phase" that lands within the window of the corresponding Expand phase is a review block, not a CI block. The committed metadata path: each migration class declares `[ExpandPhase("MIG-2026-05-22-001-add-tenant-tier-column")]` or `[ContractPhase("MIG-2026-05-22-001-add-tenant-tier-column")]`; the `database` agent walks back from the Contract PR to find the matching Expand PR's merge timestamp and flags windows that are too short.

### D6 — Online DDL: index and constraint operations

Long-running DDL operations (index builds, constraint validations) must not lock the table against application traffic. The committed primitives:

- **Postgres**: `CREATE INDEX CONCURRENTLY`, `ALTER TABLE ... VALIDATE CONSTRAINT` after `ADD CONSTRAINT ... NOT VALID`.
- **Azure SQL**: `CREATE INDEX ... WITH (ONLINE = ON)`, `ALTER TABLE ... WITH CHECK CHECK CONSTRAINT` after `WITH NOCHECK ADD CONSTRAINT`.

EF Core 9's migration scaffolding can emit these via the `MigrationBuilder.Sql(...)` escape hatch and per-provider extensions; the standard fluent API does not always default to online operations and **the policy requires online operations explicitly** on tables ≥ 100k rows. Migrations that exceed this threshold without online primitives are a review block (ADR-0044 D3 category 13).

The 100k-row threshold is a heuristic; the per-Node `database` review walks the actual row counts via the Node's `dr-runbook.md` (ADR-0036 D9) or via a CI-side query against the `staging` snapshot.

### D7 — Document stores: schema-on-read

For Cosmos (and any future vector or document backing), the migration policy is **schema-on-read**:

- **New fields are added by writing them.** No DDL exists; the next write of a document carries the new field.
- **Reading code tolerates absence of any field that is not on every existing document.** Deserialization is permissive; missing fields default to their type's zero value.
- **Backfill of new fields onto existing documents** is an operator-triggered job (a one-off console app or Azure Function), recorded as a `Migrations/Backfill-YYYYMMDD-{description}.md` runbook in the Node's repo, executed against `staging` first, then `prod`. Backfill is **not** an EF migration.
- **Field removal** follows the same pattern as relational Contract phase — only after all reading code has dropped its reference to the field, and only after a window matching D5 for the store's tier.
- **Partition key changes are not possible in place** on Cosmos. A partition key change is a **container migration**: new container, dual-write window, backfill, dual-read window, cut over reads, drain old container, delete. This is the most expensive migration shape in the Grid; record it as a follow-up ADR if and when the first partition-key change is needed.

The `IIdempotencyStore` default backing per ADR-0042 D2 is Cosmos, which means the idempotency store follows D7, not D1. The dedup-state schema is documented in the Kernel's `Migrations/` folder as a Markdown doc with the document shape, partition key, and TTL policy — not as an EF migration.

### D8 — Audit table specifics (interaction with ADR-0030)

ADR-0030 D4 mandates that the Audit store is append-only-by-interface. Migrations on the Audit Node's `AuditEntry` table are constrained accordingly:

- **No column drops, ever.** A field that was once written remains in the schema for the life of the rows that wrote it (which is ≥ 730 days per ADR-0040 D3's Audit retention). Contract phase for Audit is **null** — the old shape is never removed.
- **No type narrowing, ever.** A column whose declared type was `nvarchar(2000)` cannot become `nvarchar(500)` even if no current value exceeds 500 chars; a future emitter may have written a longer value and the row must remain readable.
- **No `NOT NULL` additions to existing columns.** The Audit table's null-history is part of its forensic value; back-filling defaults to enforce `NOT NULL` is interface-violating.
- **New columns are nullable.** Always. Forever. Emitters that need the new column write it; queries that read the old rows handle null.
- **Paired-table pattern for breaking changes.** If the Audit interface itself evolves in a way that genuinely requires a new shape (e.g., a new emitter sector with semantically distinct entries), the resolution is **a new table** alongside the existing one, not a destructive migration. Queries that span both tables UNION across them.
- **Indexes may be added or dropped.** Index changes do not affect the row data; only query plans. Drop with care (a removed index that supported a forensic query path is recoverable by re-adding the index).

The append-only-by-interface property is a migration-time invariant, not just a runtime one. The `database` review agent (D10) enforces it on every Audit-touching migration PR.

### D9 — Tenant-scoped vs Grid-wide migrations

Per ADR-0026, the Grid has explicit multi-tenant primitives. Migration policy distinguishes:

- **Grid-wide tables** (e.g., `IdempotencyKey`, `AuditEntry`, internal config tables) are migrated **once per environment**. The `migrate.yml` workflow (D3) runs once and applies the DDL to the single shared schema. No tenant-scoping logic in the migration itself.
- **Tenant-scoped tables in a shared schema** (the default Notify Cloud pattern: one table, `TenantId` column on every row, shared connection) are also migrated **once per environment**. The DDL applies to the shared table; tenant data is just rows. The migration must not select-and-rewrite rows in a way that locks the table against active tenants — per D6, this means online primitives on any tenant-data table above the row-count threshold.
- **Per-tenant schemas (separate `Schema` per `TenantId`)** are **not adopted by default** in the Grid; if any Node ever moves to that posture (Notify Cloud per-tenant schemas have been mentioned as a future consideration), the migration story is "iterate the tenant list, apply per-tenant" via a runbook-driven `migrate.yml` variant. The migration ordering is per-tenant atomic: tenant N is fully migrated before tenant N+1 begins. Partial failure (tenant 50 of 200 fails) leaves tenants 1–49 migrated and tenants 51–200 not; recovery is resume-from-tenant-50, not roll-back-to-tenant-0. This is the most operationally complex migration shape and is the trigger for D12's specialist review.

The default for v1 is **shared-schema multi-tenancy**: one table, `TenantId` column, single migration. The per-tenant variant is recorded as a future-state consideration, governed by this D9 if and when adopted.

### D10 — Failure handling and rollback policy

A migration can fail mid-application. The policy:

1. **Forward-only by default.** EF Core's `Down()` method is generated automatically but **the Grid does not commit to running it in production**. Rollback is achieved by writing a new forward migration that reverses the unwanted change, not by running `Down()`.
2. **Transactional migrations where the database supports them.** Postgres supports transactional DDL; Azure SQL supports it for most operations. The migration script generated by `dotnet ef migrations script --idempotent` wraps DDL in a transaction; partial application is rolled back automatically by the database.
3. **Non-transactional operations** (online index builds on Postgres `CONCURRENTLY`, some Azure SQL `ONLINE` operations) are explicitly outside any transaction boundary. These operations are **resumable**: re-running the migration after a partial failure picks up where it left off (EF Core's migration history table records completed migrations atomically; the script is idempotent against the history table).
4. **Mid-migration failure procedure** (the runbook):
   - The migration history table records which migrations completed. Re-running `migrate.yml` re-applies only the un-applied DDL.
   - If a specific DDL statement fails (not a transient connection error), the operator triages: fix-forward (write a new migration that compensates) or roll-forward (re-run, often after a manual fix to the failing operation).
   - **Rolling back a deployed migration is not a tooling-level operation.** It is a forward migration written deliberately, reviewed deliberately, deployed deliberately. The cost of writing a compensating migration is paid; the speed of "just run `Down()`" is not.
5. **The migration job artifact carries the applied SQL.** `migrate.yml` retains the generated SQL script and the migration history table snapshot as workflow artifacts. Post-mortem forensics use these artifacts; they live in `generated/incidents/` per the existing post-mortem pattern if a migration produces an incident.
6. **The Node's `dr-runbook.md` (ADR-0036 D9) gains a Migration Failure section** documenting the per-Node failure recovery steps, the connection-string source (Vault path per ADR-0005), and the contact escalation. This is a required artifact per D11.

The "no production `Down()`" posture is a deliberate trade-off: it eliminates the temptation to "just roll back" a migration whose `Down()` may itself be untested, may itself fail mid-application, and may leave the schema in an even more degenerate state than the failed forward migration. Forward-only migrations are operationally boring and well-understood; this ADR commits to boring.

### D11 — Conventions: file location, naming, CI, and the `migrate.yml` workflow

**File location per Node:**

```
src/
  HoneyDrunk.<Node>.Data/
    Migrations/
      <YYYYMMDDHHmmss>_<DescriptiveName>.cs       # generated by `dotnet ef migrations add`
      <YYYYMMDDHHmmss>_<DescriptiveName>.Designer.cs
      <Node>DbContextModelSnapshot.cs
    Migrations/Backfill/
      <YYYYMMDD>-<description>.md                  # for non-DDL backfills per D7
    Migrations/README.md                            # per-Node migration history overview + caveats
tests/
  HoneyDrunk.<Node>.Tests.Integration.Containers/
    Migrations/
      <Node>MigrationRoundTripTests.cs            # per D12, required
```

**Naming convention:**

- Migration class name: `<Verb><Subject>` PascalCase, no spaces (e.g., `AddTenantTierColumn`, `BackfillAuditEmitterIndex`, `DropLegacyCorrelationId`).
- Migration class name carries `[ExpandPhase("...")]` or `[ContractPhase("...")]` per D5 when the migration is part of an expand/contract pair.
- Migration class name carries `[BreakingChange("reason")]` per D2 when the migration is destructive in a single deploy (Tier 2 stores only).
- File name follows EF Core's default `<timestamp>_<ClassName>.cs` pattern.

**The `migrate.yml` reusable workflow** (new, lands in HoneyDrunk.Actions per the ADR-0012 control-plane invariant):

- Inputs: `node` (the Node name), `environment` (`dev`/`staging`/`prod`), `target-migration` (optional; defaults to "latest").
- Trigger: `workflow_dispatch` only (operator-deliberate per D3).
- Steps:
  1. Check out the consumer repo at the SHA of the latest deployed code for the target environment (per ADR-0033's environment-to-ref mapping). This guarantees the migration assembly matches the running code.
  2. `dotnet ef migrations script --idempotent --output ./migrate.sql` against the Node's `DbContext`.
  3. Resolve the connection string from Vault per ADR-0005 using the Grid's OIDC credential model per ADR-0015.
  4. Apply via `sqlcmd` (Azure SQL) or `psql` (Postgres) wrapped in a transaction where the provider supports it.
  5. On success: upload `migrate.sql` and a post-migration `EFMigrationsHistory` snapshot as workflow artifacts.
  6. On failure: surface the offending DDL statement, the partial-application state of `EFMigrationsHistory`, and the operator-runbook link from D10.

The workflow is per-environment-gated using GitHub Environment protection rules (per ADR-0033 D7's posture: `staging`/`prod` are protected, `dev` is not).

### D12 — Test requirements

Every migration carries two mandatory test artifacts:

**Round-trip test (CI gate per ADR-0047 Tier 2b):**

A test in `HoneyDrunk.<Node>.Tests.Integration.Containers/Migrations/<Node>MigrationRoundTripTests.cs` that:

1. Spins up a Testcontainers Postgres (or appropriate provider) container.
2. Applies all migrations up to and including the new one.
3. Asserts the resulting schema matches the model snapshot.
4. Inserts representative test data shaped to the new schema.
5. Reads it back; asserts integrity.
6. For Expand phase migrations: also inserts data shaped to the **old** schema and reads it back with the **new** code (forward compatibility).
7. For Contract phase migrations: asserts the old shape is gone but old-shape data (if any) has been migrated to the new shape.

Round-trip tests are a CI gate per ADR-0047 D11's Tier 2b job; a failing round-trip test blocks merge.

**Rollback declaration:**

Every migration declares one of two postures via class-level attribute:

- `[Rollback(Strategy = RollbackStrategy.ForwardMigration, Notes = "...")]` — the default; a compensating forward migration is the rollback mechanism. The Notes field documents what the compensating migration would do (informational only at PR time; not executed).
- `[Rollback(Strategy = RollbackStrategy.NonRollback, Reason = "...")]` — explicitly declares the migration cannot be rolled back (e.g., a data-destructive migration on a Tier 2 store with `[BreakingChange]`). The Reason field is required and is reviewed by the `database` agent (D13) for adequacy.

The attribute is informational; it is not enforced at runtime. Its value is the **discipline of declaring intent** — a PR without a `[Rollback]` attribute is a review block.

**Backfill tests (D7):**

Document-store backfill jobs (D7) carry their own integration tests: spin up the document store, populate it with old-shape documents, run the backfill, assert new-shape documents present. Same Tier 2b harness, different test class.

### D13 — Review surface: specialist `database` agent

Per ADR-0046, the Grid commits to specialist review agents for high-risk surface areas. Schema evolution is one of them. The `database` agent (added to `.claude/agents/database.md` per ADR-0046's pattern) walks every PR that touches `Migrations/`, `Backfill/`, or any file referenced from a `DbContext`:

- **D2 conformance** — single-deploy destructive change present? `[BreakingChange]` annotation present? Tier appropriate?
- **D5 window adequacy** — Expand/Contract phase pairing detected? Window since the matching Expand large enough?
- **D6 online primitives** — table row count vs threshold; online primitives used?
- **D8 Audit constraints** — if `AuditEntry` is touched, any forbidden operation (column drop, type narrowing, `NOT NULL` add)?
- **D9 tenant scoping** — multi-tenant table touched? Migration scoped correctly?
- **D10 rollback declaration** — `[Rollback]` attribute present and adequate?
- **D12 tests present** — round-trip test added or updated for the new migration?
- **EF Core idiom** — using `MigrationBuilder.Sql(...)` where the fluent API doesn't emit the desired DDL? `--idempotent` flag would still produce a clean script?

The `database` agent is **required** on every PR that adds or modifies a migration file. The `review` agent's ADR-0044 D3 category 13 (Data and persistence integrity) yields the per-PR-review surface; this ADR commits the agent that owns the specialist depth.

The agent is also invoked **from the `scope` agent** when packets imply schema changes — the packet pre-flight check warns the operator that the work will trigger a migration review, so the packet author can sequence Expand and Contract correctly from the start.

### D14 — Phased rollout

- **Phase 1 (Week 1–2)** — Author the `database.md` agent in `.claude/agents/` (per ADR-0046's specialist pattern). Author `migrate.yml` reusable workflow in HoneyDrunk.Actions. Author the `Migrations/README.md` template for per-Node repos. Update `.claude/agents/review.md` D3 category 13 to delegate depth review to `database`.
- **Phase 2 (Week 2–4)** — Pilot on **HoneyDrunk.Kernel.Idempotency** (per ADR-0042). The idempotency store contract test (Tier 2a per ADR-0047 D4) gains the round-trip migration test in Tier 2b; the Cosmos backing follows D7's schema-on-read pattern. This pilot exercises the document-store side of the policy on a Node that already has a contract test.
- **Phase 3 (Week 4–6)** — Audit standup (ADR-0031) adopts the full pattern. Audit is the highest-stakes Node for the policy — Tier 0, append-only-by-interface, retention ≥ 730 days. Standup canary includes the round-trip test from day one; D8's constraints are baked into the `database` agent's Audit-specific rules.
- **Phase 4 (Month 2–3)** — Memory, Knowledge standup (ADR-0021/0022) consumes the pattern. Each Node's standup ADR amendment references this ADR for the migration story instead of inventing one.
- **Phase 5 (Month 3+)** — Billing standup (ADR-0037) consumes the pattern. Billing carries the strongest data-integrity requirements; the `database` agent is invoked on every Billing PR by default.
- **Phase 6 (Ongoing)** — Notify Cloud per-tenant data migrations as Notify Cloud GA approaches; the tenant-scoped variant of D9 if and when adopted.

Each phase is a discrete go/no-go.

## Consequences

### Affected Nodes

- **HoneyDrunk.Kernel** — `HoneyDrunk.Kernel.Idempotency.Cosmos` pilots the document-store side (D7). The idempotency store's schema documentation lives in the Kernel repo's `Migrations/README.md`.
- **HoneyDrunk.Data** — gains a `Migrations/` conventions page. Backings are per-consuming-Node, so Data itself doesn't ship migrations; it ships the pattern via Abstractions and tests.
- **HoneyDrunk.Audit** (Seed, ADR-0031) — adopts the pattern in full at standup. Tier 0; append-only-by-interface per D8; round-trip test from day one; `database` agent on every Audit-touching PR.
- **HoneyDrunk.Memory, HoneyDrunk.Knowledge** (Seed, ADR-0021/0022) — adopt the pattern at standup. Tier 1; expand/contract per D2 with the 14-day window per D5.
- **HoneyDrunk.Billing** (proposed by ADR-0037; not yet in `catalogs/nodes.json`) — adopts the pattern at standup with the 30-day window per D5 matching ADR-0042's billing TTL.
- **HoneyDrunk.Notify** — gains the per-Node `Migrations/README.md`; existing scaffold migrations are retroactively annotated. No data migration today.
- **HoneyDrunk.Notify.Cloud** (Seed, ADR-0027) — adopts shared-schema multi-tenancy per D9 by default. Future per-tenant variant would trigger this ADR's D9 second branch.
- **HoneyDrunk.Pulse** — Tier 2; permitted to use `[BreakingChange]` for the rare destructive schema change. Cosmos historical-signals store follows D7.
- **HoneyDrunk.Actions** — gains `migrate.yml` reusable workflow per D11. Existing reusable workflows (`job-deploy-container-app.yml` per ADR-0015) are unchanged; `migrate.yml` is a sibling workflow operator-triggered before code deploy.
- **HoneyDrunk.Architecture** — `catalogs/grid-health.json` gains a new `schema_evolution` field per state-holding Node (values: `ef-core-migrations`, `cosmos-schema-on-read`, `n/a`). `catalogs/contracts.json` is unchanged (no new public contract). `repos/{name}/integration-points.md` template gains a Migration Coordination line for Nodes where migration ordering matters across Nodes.
- **`.claude/agents/database.md`** — new file (per ADR-0046 pattern). Owns D2/D5/D6/D8/D9/D10/D12 checks.
- **`.claude/agents/review.md`** — D3 category 13 delegates depth to `database` per D13.
- **`.claude/agents/scope.md`** — packet pre-flight check gains a "this packet implies schema changes" detector that invokes `database` advisory.

### Invariants

Adds three:

- **Invariant: relational stores use EF Core Migrations.** Per-Node framework choice is not allowed; document-store schema-on-read (D7) is the only exception.
- **Invariant: production migrations run via the `migrate.yml` workflow, never at app startup, never via init container.** The out-of-band timing is non-negotiable; ADR-0015 D6's multi-revision window depends on it.
- **Invariant: every migration carries a `[Rollback]` attribute and a Tier 2b round-trip test.** Missing either is a CI gate failure for the round-trip test (per ADR-0047 D11) and a review block for the attribute (per ADR-0044 D3 category 13 / ADR-0046's `database` agent).

(Final invariant numbers assigned when the implementing work updates `constitution/invariants.md`; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **Per-deploy operator burden grows by one step** for migration-bearing Nodes: trigger `migrate.yml` before the dependent code deploy. At 5–6 migration-bearing Nodes and 1–4 deploys per Node per month, this is roughly 10–20 extra workflow invocations per month. Automation against `dev` is named as follow-up.
- **Backward-compatibility window forces schema discipline.** Developers cannot ship a rename in a single PR; the Expand-Migrate-Contract sequence is real work spread across deploys. This is the cost of safe online migrations; the alternative is downtime windows that the Grid has explicitly committed to avoiding.
- **Audit's "no Contract phase ever" property accumulates schema entropy.** Over 730+ days of retention, the `AuditEntry` table accumulates columns from every shape revision. Acceptable cost; the alternative (rewriting history) violates ADR-0030's append-only-by-interface invariant. Periodic schema review (annually, as part of the ADR-0036 Tier 0 restore drill) checks whether any dormant columns can be candidates for an `AuditEntryV2` paired-table split per D8.
- **`database` agent invocation adds ~30s–2min to PR review** for migration-touching PRs. Negligible at current PR volume; named as a cost factor if PR volume grows.
- **Per-tenant schema variant (D9 second branch) is not adopted today.** When and if the first Node moves to per-tenant schemas, this ADR's D9 is the migration story; the operational complexity of resume-from-tenant-N is the trigger for revisiting whether per-tenant schemas remain worth it.
- **EF Core 9 LTS alignment** means the framework version drifts as new LTSes land. The first cross-Grid framework bump (to EF Core 10 LTS) will be a coordinated multi-Node PR; recorded as a known upgrade burden, not a recurring cost.
- **Round-trip test cost in CI** is bounded by Testcontainers' per-test-class container reuse (per ADR-0047 D4). For a Node with 10 historical migrations, the round-trip test applies all 10 against a fresh container in single-digit seconds; tolerable.
- **The Vault bootstrap-recovery procedure (ADR-0036 D6) is unchanged.** Vault's persistent state is in Key Vault itself; no schema migrations exist for Vault. This ADR explicitly does not change ADR-0006 or ADR-0036 D6's posture on Vault.

### Follow-up Work

- Author `.claude/agents/database.md` per ADR-0046's specialist agent pattern, embedding the D2/D5/D6/D8/D9/D10/D12 checklists.
- Author `migrate.yml` reusable workflow in HoneyDrunk.Actions per D11.
- Author the `Migrations/README.md` template for per-Node repos.
- Update `.claude/agents/review.md` D3 category 13 to delegate depth to `database`.
- Update `.claude/agents/scope.md` packet pre-flight to detect schema-change-implying packets.
- Add the `schema_evolution` field to `catalogs/grid-health.json` (drift task per ADR-0014 `hive-sync`).
- Update `repos/{name}/integration-points.md` template with the Migration Coordination line.
- Update `repos/{name}/dr-runbook.md` (per ADR-0036 D9) template with the Migration Failure section (D10 step 6).
- Land the Kernel.Idempotency pilot (Phase 2) — round-trip test for the dedup store under Tier 2b; Cosmos schema-on-read documentation in the Kernel repo.
- Land Audit standup (Phase 3, ADR-0031) with the full pattern.
- Author a follow-up ADR if and when partition-key changes on Cosmos become necessary (D7's most expensive migration shape).
- Author a follow-up ADR if and when per-tenant schemas are adopted (D9's second branch).
- Evaluate automation of `migrate.yml` against `dev` after Phase 4 — the migration step at `dev` could safely run on every merge to `main` that touches `Migrations/`, since `dev` is unprotected per ADR-0033 D7. `staging`/`prod` remain operator-deliberate per D3.

## Alternatives Considered

### DbUp (or FluentMigrator) instead of EF Core Migrations

Considered. DbUp is a SQL-script-based migration runner with a simple model: a folder of `.sql` files, each executed once, tracked in a history table. FluentMigrator is a C# DSL similar in spirit to EF Core Migrations but framework-agnostic. Both have legitimate strengths:

- **DbUp's strength** is the SQL-script transparency: you can read exactly what will run, no ORM in the middle. For DBA-heavy shops this is decisive.
- **FluentMigrator's strength** is provider-agnosticism without EF Core's broader surface area; a Grid that didn't use EF Core would find FluentMigrator a cleaner fit.

**Rejected** for v1 on three grounds:

1. **Stack consistency.** The Grid is .NET, the consuming Nodes use EF Core for their query layer, the model snapshot is a useful artifact for round-trip testing per D12, and the same agent that reviews the rest of the C# code reviews the migration class. Adding a SQL-script tool means migration review is a separate skill (more SQL-DBA-shaped, less C#-shaped) — a non-trivial cost for a solo-dev shop.
2. **Migration script generation.** EF Core's `dotnet ef migrations script --idempotent` produces the same SQL-script transparency DbUp offers natively, **without** giving up the C# model-snapshot side. The `migrate.yml` workflow per D11 generates and archives the SQL for forensic value; the operator can read exactly what will run before pressing go.
3. **Solo-dev framework count.** Every framework added to the Grid is a stewardship cost (track its releases, watch for security advisories, train future contributors). EF Core is already in the Grid for the query layer; adding it to the migration layer costs nothing more. Adding DbUp costs a second framework.

DbUp returns as the v2 option **only if** EF Core's migration scaffolding produces SQL that the operator finds materially harder to read than hand-written SQL (which has not been the case in practice) or if EF Core's stewardship shifts in a way that makes its long-term path uncertain. Neither trigger is realistic today.

### "No policy — each Node decides"

Considered. Maximum per-Node flexibility; minimum cross-cutting decision cost.

**Rejected** for the same reasons every other cross-cutting ADR in this family rejects the "per Node decides" alternative:

- Three Nodes inventing three migration patterns produces three incompatible operator runbooks. Each one is reasonable in isolation; the combined operator burden is the cost of the lack-of-policy.
- The `database` review agent (D13) becomes useless — it cannot enforce a pattern that doesn't exist Grid-wide.
- The `scope` agent (per ADR-0008) cannot generate migration-bearing packets without a target pattern to scaffold against.
- Cross-Node migrations (the rare case where Memory and Knowledge both need a coordinated schema change to support a shared feature) become impossible to coordinate without a common framework.

The cost of committing the Grid to one framework is small; the cost of not committing it is recurring forever.

### Run migrations at app startup (`dbContext.Database.Migrate()`)

Considered. Simplest model; no extra workflow; the app self-migrates on every cold start. Many small .NET shops do this.

**Rejected** primarily because it fights ADR-0015 D6:

- Two revisions during traffic split, each calling `Migrate()` on startup, race for the migration lock. EF Core's migration lock prevents corruption but produces a deadlock-like wait where the second revision blocks on the first's startup.
- A migration failure at startup looks like an app deploy failure with poor signal. The operator sees "deploy failed"; the actual cause is "migration N+1 failed to apply." Diagnosis takes longer; recovery is murkier.
- App cold-start latency includes DDL execution time. For a long migration (index build on a large table), this can mean minutes of unavailable app on first revision boot — exactly when you want the app to come up cleanly.
- The principle "code deploy and schema migration are different operations with different rollback semantics" is collapsed. Per D10, schema migrations are forward-only; code revisions can roll back instantly via ADR-0015 D6 traffic shift. Coupling them at startup means a code rollback can re-run an already-applied migration (idempotent — fine) or, worse, leave a partially-applied migration to be detected only on the next deploy.

The out-of-band model (D3) costs one operator step per deploy and buys all of these properties back. The trade is correct.

### Init container / pre-deploy hook

Considered as a middle ground between startup migrations and out-of-band: a Kubernetes-style init container (or a Container Apps `initContainer`-equivalent post-deploy hook) runs the migration before the new revision accepts traffic.

**Rejected** because:

- Container Apps does not have a first-class init-container primitive comparable to Kubernetes; emulating it via a pre-traffic-shift hook in the deploy workflow is brittle.
- The two-revision race from ADR-0015 D6 reappears: both revisions' init containers fire, both compete for the migration lock, the second wastes startup time.
- Init-container failure looks like deploy failure with the same poor signal as startup migrations.
- The marginal benefit over D3's out-of-band workflow is "no extra operator click," at a cost of significantly weaker observability and recovery semantics. The click is cheap; the recovery story is not.

### Identical-artifact promotion of migrations (alongside the code identical-artifact promotion ADR-0033 D6 declines)

Considered. The migration assembly built at `dev` deploy time is promoted byte-identical to `staging` and `prod`. Symmetric with the deferred code-promotion option in ADR-0033 D6.

**Rejected** for the same reason ADR-0033 D6 declined identical-artifact for code: the Grid's reusable workflows build-on-deploy per ADR-0015, and the marginal benefit (deterministic identical bytes across environments) does not exceed the cost (artifact storage, promotion plumbing). The migration source is in the repo at a known SHA; `migrate.yml` checks out that SHA and generates the script fresh per environment. The script is deterministic from the same source against the same provider; environments are operationally identical for this purpose.

Reconsidered if a future scenario requires that the exact SQL string applied at `dev` be the exact SQL string applied at `prod` (perhaps for a compliance audit requirement). Not a current driver.

### Per-environment schema divergence (allow `dev` to have schema `staging`/`prod` doesn't)

Considered. `dev` is the disposable environment per ADR-0033 D7; allowing schema experiments at `dev` that don't make it to `staging`/`prod` would speed iteration.

**Rejected** because the round-trip test (D12) and the migration history table together commit to "the migration sequence at `dev` is the migration sequence at `staging` is the migration sequence at `prod`." Allowing divergence opens the door to "this worked at `dev` but failed at `prod`" — exactly the failure mode the policy exists to prevent. Experimentation happens locally (developer's machine + Testcontainers) or in a branch that doesn't merge until the migration is `staging`/`prod`-ready.

### Schema-on-read for everything (including relational stores)

Considered. Cosmos and document stores live with no DDL by design (D7); extending this to relational stores would simplify the migration story to "just deploy code that handles missing/extra columns."

**Rejected** because relational stores enforce constraints that schema-on-read can't honor: foreign keys, `NOT NULL`, type widths, indexes, check constraints. The value of using a relational store is precisely that the store rejects invalid data at write time. Abandoning DDL to avoid migration policy throws away the property that justifies the relational store in the first place.

For the cases where schema-on-read is genuinely the right model (Pulse's signal history, possibly some Memory layouts), Cosmos is the appropriate backing per D7. The choice of backing per Node already accounts for this; the migration policy follows the backing.

### Defer until first migration incident exposes a gap

Rejected. Audit standup (Phase 3, weeks away) is the first Tier 0 Node that will accumulate migrations under retention ≥ 730 days. Inventing the pattern after the first append-only-by-interface migration is applied is exactly the failure mode this ADR exists to prevent. Defer-and-discover is the worse option when the discovery is destructive.

Same argument as ADR-0042 (idempotency) defer-and-discover and ADR-0036 (DR) defer-until-first-paying-tenant rejections: cross-cutting infrastructure decisions are cheaper to make before the first painful exercise than after.

### Adopt Flyway or Liquibase

Considered. Both are mature, language-agnostic, widely-used in JVM-land and well-supported on .NET.

**Rejected** for the same stack-consistency argument that rejected DbUp: the Grid is .NET, EF Core is the .NET answer, adding a JVM-rooted tool (Flyway and Liquibase are both Java-historically) means a JVM runtime in the migration toolchain. The polyglot cost for a solo-dev shop is real. Both tools are excellent in their native habitats; the Grid is not their native habitat.

### Allow per-Node opt-out of the `database` agent review

Considered. Some Nodes (Tier 2 internal-only stores, Pulse historical) have lower stakes; requiring `database` review on every migration could feel heavy.

**Rejected** because the `database` agent's per-PR cost is small (D14 estimates ~30s–2min for a migration-touching PR), the stakes asymmetry argues *for* consistent review (it's the Tier 0 Audit migration that absolutely needs it; making the review optional means inconsistent application), and the Grid's broader posture per ADR-0046 is "specialist agents are cheap to run, expensive to skip." Same conclusion ADR-0046 reached for security and other specialist depths.
