---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "meta", "docs", "adr-0072", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0072", "ADR-0048", "ADR-0046"]
wave: 2
initiative: adr-0072-data-access-stance
node: honeydrunk-architecture
---

# Extend the `database` specialist agent rubric with ADR-0072 ORM-choice and query-discipline categories

## Summary
Extend the `.claude/agents/database.md` specialist review agent (authored under sibling initiative `adr-0048-schema-evolution` packet 02) with two new rubric categories: **ORM choice** (per ADR-0072 D1/D2 — is the implementation EF Core; if Dapper is used, is the evidence burden met?) and **query discipline** (per ADR-0072 D5 — deep checks for `AsNoTracking()` usage, projection adequacy, `Include` explicitness, N+1 patterns, compiled-query justification, raw-SQL parameterization). These are depth-level checks; the generalist `review` agent (packet 01) surfaces flags, and the specialist verifies the evidence.

## Context
ADR-0072 D2 commits Dapper as a **scoped exception with mandatory evidence**: every Dapper introduction's PR carries the EF-generated query, the hand-written Dapper replacement, benchmark numbers, and the workload context. ADR-0072 D5 commits a per-query discipline (`AsNoTracking()` / projections / explicit `Include` / lazy off / parameterized raw SQL).

ADR-0072's Follow-up Work names: "The `review` agent's checklist gains the Dapper-evidence and EF-discipline checks per D5." The generalist's checklist (packet 01 of this initiative) is the surface; the specialist's rubric is the depth. The depth checks live in the `database` specialist agent's rubric — the file authored under sibling initiative `adr-0048-schema-evolution` packet 02.

**Coupling with `adr-0048-schema-evolution` packet 02.** The `database` agent file at `.claude/agents/database.md` is created by `adr-0048-schema-evolution` packet 02. That packet establishes the seven-category rubric for schema-evolution depth review (D2 expand/contract, D5 window adequacy, D6 online primitives, D8 Audit constraints, D9 tenant scoping, D10 rollback declaration, D12 tests present, plus EF Core idiom). This packet **adds two additional categories** to the same rubric:

- **Category 8 (new) — ORM choice (per ADR-0072 D1/D2).** Is the relational data-layer change using EF Core (the default)? If Dapper is used, are the four evidence items present (EF query, Dapper query, benchmarks, workload context)? If Marten / RepoDb / raw ADO.NET / EF 6 is used, is there an explicit ADR amendment justifying the deviation?
- **Category 9 (new) — Query discipline (per ADR-0072 D5).** The depth-level review of EF query patterns — `AsNoTracking()` placement, projection adequacy (does the query genuinely need the full entity, or is a `Select` projection appropriate?), `Include` explicitness and `ThenInclude` chains, lazy-loading state (must be off), N+1 patterns at the runtime call site, compiled-query amortization (is the compile cost justified by the call frequency?), raw-SQL parameterization.

The two categories sit alongside the existing seven categories. The `database` agent's rubric grows from 7 to 9 categories total.

**Hard sequencing.** This packet edits a file authored by the sibling initiative `adr-0048-schema-evolution` packet 02. The sibling packet **must merge first**. This packet's `dependencies:` array does not (and cannot) wire a `work-item:NN` reference across initiatives — the filing pipeline's `work-item:NN` form only resolves within the current initiative folder. Instead, this packet is gated **textually** on the sibling: the executor MUST confirm `.claude/agents/database.md` exists on `main` before opening the PR. If the sibling has not merged, this packet's issue stays open but no PR is opened until the sibling lands. The executor records the sibling sequencing in the PR body. There is no "create a holding document" alternative — that path produces an artifact that `file-work-items` cannot route as a single appendable edit. The single canonical action is: append two rubric categories to the existing `.claude/agents/database.md`.

**Why depth-level review for ORM choice and query discipline matters.** The generalist surface check (packet 01) is pattern-based and fast — it flags introductions and obvious violations. The specialist depth review is contextual:

- For the **ORM choice** category — verifying Dapper evidence requires reading benchmark numbers and judging whether the EF-generated SQL is genuinely worse for the consuming workload. Pattern-matching can't do this; a specialist agent reading the PR body and the benchmark output can.
- For the **query discipline** category — the surface check flags missing `AsNoTracking()` on what looks like a read path. The depth check confirms it's *actually* a read path (the entity is genuinely not modified), confirms the projection shape is the narrowest one the consumer needs, confirms the `Include` chain doesn't pull in a navigation property that the projection doesn't use.

The two together compose the right review surface: fast surface check on every PR, deep evidence check on data-layer PRs flagged by the specialist's invocation.

This is a docs/agent-configuration packet. No code, no .NET project.

## Scope
- `.claude/agents/database.md` — append two new rubric categories (ORM choice, query discipline) to the existing seven-category rubric. **Sibling sequencing**: this file is authored by `adr-0048-schema-evolution` packet 02. That packet must merge first; this packet's executor confirms the file exists on `main` before opening the PR.
- No edit to `review.md` (packet 01 owns it).
- No edit to any other agent file.

## Proposed Implementation

### Step 1. Confirm sibling sequencing

Read `.claude/agents/database.md`. If the file exists with the seven-category rubric from `adr-0048-schema-evolution` packet 02, proceed to Step 2. If the file does not exist (sibling packet 02 has not merged), **do not open the PR**: leave the issue open and wait. Record the sibling-sequencing wait in a comment on the issue. The packet is hard-blocked on the sibling's merge; there is no proposed/holding-document fallback (that path produces an artifact `file-work-items` cannot route to a clean append edit).

### Step 2. Append two new rubric categories to the existing `database.md`

The existing rubric has seven categories (numbered, paraphrased from `adr-0048-schema-evolution` packet 02):

1. D2 expand/contract pattern conformance
2. D5 backward-compatibility window adequacy
3. D6 online primitives on tables ≥ 100k rows
4. D8 Audit `AuditEntry` append-only-by-interface constraints
5. D9 tenant scoping
6. D10 rollback declaration metadata
7. D12 round-trip test presence
8. (operational) SQL project idiom — object split, pre/post-deployment scripts, and DACPAC publish artifact review

Add the two new categories below the existing ones. They are not migration-scoped (the first eight are); they are ORM-scoped. They apply to **every PR touching data-layer code**, not only PRs touching `HoneyDrunk.<Node>.Database/` or `Backfill/`. The `database` agent's invocation surface (from the existing rubric) is "PRs touching `HoneyDrunk.<Node>.Database/`, `Backfill/`, or any file referenced from a `DbContext`" — that surface already encompasses the new categories' applicability.

#### Category 9 — ORM choice (per ADR-0072 D1/D2)

The depth review confirms that the data-layer change uses EF Core (the default per D1) and, if Dapper is introduced, that the evidence burden is met.

**Sub-checks:**

- **EF Core is the default.** If the data-layer change uses `Microsoft.EntityFrameworkCore.SqlServer` for SQL Server/Azure SQL, the default is satisfied. Npgsql/PostgreSQL usage requires a provider-specific schema-deployment ADR amendment or follow-up decision.
- **Marten / RepoDb / raw ADO.NET / EF 6 deviation.** If the change uses any of these, look for an explicit ADR amendment justifying the deviation. Without an amendment, this is a **Block** finding. ADR-0072 D1's negative form: "Dapper is not the default; Marten is not adopted; raw ADO.NET is not the default; Entity Framework 6 / Classic is forbidden for new work; RepoDb / Pomelo / freshly-released micro-ORMs are not adopted as defaults."
- **Dapper introduction — evidence burden.** If the change introduces Dapper (`using Dapper;` or `IDbConnection.Query<T>` / `QueryAsync<T>` calls), verify all four evidence items are present in the PR body or linked artifacts:
  - **(a) The EF-generated query.** Either pasted in the PR body (preferred) or described with enough specificity that the reviewer can verify the query shape against EF's `ToQueryString()` output. The expected EF query is the one the PR replaces.
  - **(b) The hand-written Dapper query.** The actual SQL the Dapper call sends. Present in code (Dapper string literal) plus an explanation of why the hand-written form is materially different from the EF-generated form.
  - **(c) Benchmark numbers.** BenchmarkDotNet output or profiler evidence comparing the EF path and the Dapper path on the consuming workload's representative shape. The benchmark must show a measurable, workload-relevant difference (e.g., 3× latency reduction on a path called 10k times per minute; not "Dapper is 5% faster on a query called once per hour").
  - **(d) Workload context.** The expected query frequency, the expected row volume, the consuming caller. The benchmark difference matters only at the consuming workload's scale; the workload context lets the reviewer judge whether the difference matters.
  Missing any of (a), (b), (c), or (d) is a **Block** finding. The introduction is rejected until evidence is supplied.
- **Dapper-write introduction.** If the change introduces a Dapper write path (`Execute`, `ExecuteAsync`), this is a **Block** finding regardless of evidence. ADR-0072 D2 scopes Dapper to read paths only; writes go through EF Core's DbContext. Recommendation: "If the write genuinely requires raw SQL, use `SQL project pre/post-deployment scripts` for schema changes or `DbContext.Database.ExecuteSqlInterpolated(...)` for runtime data-layer SQL that still wants EF's connection / transaction management."
- **Per-Node, per-query scope.** Verify that adopting Dapper for one query in a Node does not implicitly adopt it for the Node's other queries. The EF default still applies to everything else in the Node. If the PR introduces multiple Dapper queries at once, each one needs its own evidence — a blanket "we're using Dapper everywhere in this Node now" is rejected. ADR-0072 D2: "Per-Node, per-query."
- **`FromSqlRaw` vs Dapper.** ADR-0072 D2: "`FromSqlRaw` inside EF is the in-between answer. It is preferred over Dapper when the hand-written query still wants EF's change tracking or composition." If the Dapper introduction's query is one that could equally well use `FromSqlRaw` and stay inside EF's pipeline (it composes with other EF queries, it benefits from change tracking, the result type is an entity), the depth review's recommendation is: "Consider `FromSqlRaw` inside EF instead of Dapper. Provide the workload reasoning if Dapper is preferred." This is a **Request Changes** finding, not Block.

**Severity mapping** (Grid taxonomy Block / Request Changes / Suggest per `copilot/pr-review-rules.md`): **Block** for Marten/RepoDb/raw-ADO.NET/EF-6 without ADR amendment; **Block** for missing Dapper evidence; **Block** for Dapper-write introductions. **Request Changes** for `FromSqlRaw`-vs-Dapper preference. **Suggest** for blanket-Dapper-adoption flags.

#### Category 10 — Query discipline (per ADR-0072 D5)

The depth review confirms the per-query patterns. The generalist's surface check (packet 01 of this initiative) flags missing patterns; the specialist confirms the flagged sites are genuinely problematic.

**Sub-checks:**

- **`AsNoTracking()` on read-only queries — confirmed read-only?** The surface check looks for `_context.<DbSet>.Where(...).ToList()` without `AsNoTracking()`. The depth check confirms: is the resulting entity actually not modified in the consuming code? If the entity is read for display only and never has any setter called, `AsNoTracking()` is missing and should be added — **Request Changes** finding. If the entity is read and then modified and saved back, the missing `AsNoTracking()` is correct — no finding.
- **Projection adequacy.** The surface check looks for full-entity loads followed by mapping. The depth check confirms: does the consuming code actually use every column on the entity? If only three columns are touched downstream, the load should be a `Select` projection of those three columns — **Request Changes** finding. If the consumer genuinely uses every column, the full-entity load is correct.
- **`Include` chain audit.** Confirm that every `Include` and `ThenInclude` in the query corresponds to a navigation property the consumer actually uses. Unused `Include` chains are over-fetching and should be removed — **Request Changes** finding for a clearly-unused chain; **Suggest** for a chain that might be used in an edge case.
- **Lazy loading off.** Confirm that the DbContext composition does not enable lazy-loading proxies. A `UseLazyLoadingProxies()` call is a **Block** finding. The default DbContext composition has lazy loading off; this is a deviation that requires an explicit ADR amendment.
- **N+1 at the call site.** Confirm that the surface check's flagged N+1 site is genuinely an N+1 (the inner query is per-iteration with a varying parameter) and not a constant-parameter query that's loop-invariant. The fix is either an `Include` to eager-load the related entities, a `GroupBy` projection, or a `Join`. **Request Changes** finding.
- **Compiled query justification.** `EF.CompileQuery` is permitted for hot paths where the compile cost amortizes. Confirm the introduction's call site is genuinely hot (high frequency, low latency requirement). If the path is called once an hour, compiled queries are over-engineered — **Suggest** finding to remove. If the path is called thousands of times per minute, compiled queries are appropriate — no finding.
- **Raw SQL parameterization (depth check).** The surface check rejects string-interpolated `FromSqlRaw` as Block. The depth check confirms that the parameterized form is correctly parameterized (positional `{0}` / `{1}` placeholders match the parameter array order; `FromSqlInterpolated` is used where interpolation is desired). A subtly mis-parameterized `FromSqlRaw` is still a SQL injection risk — **Block** finding.
- **Tenant predicate presence.** For Nodes where the table has a `TenantId` column (per ADR-0026 multi-tenant primitives), confirm the query carries a tenant predicate or is run under a global query filter that injects one. A tenant-table query without a tenant predicate is a **Block** cross-tenant leakage finding (per the existing category 13 multi-tenant integrity check in `review.md`, but the specialist confirms at depth).

**Severity mapping** (Grid taxonomy Block / Request Changes / Suggest per `copilot/pr-review-rules.md`): **Block** for lazy-loading proxies, mis-parameterized raw SQL, missing tenant predicates on tenant tables. **Request Changes** for genuine missing `AsNoTracking()`, missing projections, unused `Include` chains, confirmed N+1. **Suggest** for over-engineered compiled queries.

### Step 3. Reference the generalist surface from the depth rubric

In both categories 9 and 10, add a brief note that the **generalist `review` agent (per ADR-0044 D3 category 13)** surfaces the introductions / patterns, and the specialist confirms at depth. The two surfaces compose. The phrasing should match the format used by the existing categories (which reference ADR-0048 D-decisions for each category).

### Step 4. Update the agent's invocation surface text

The existing invocation surface from `adr-0048-schema-evolution` packet 02 is: "PRs touching `HoneyDrunk.<Node>.Database/`, `Backfill/`, or any file referenced from a `DbContext`." Extend this to include: "PRs introducing Dapper (`using Dapper;` or `IDbConnection.Query<T>` / `Execute` / `ExecuteAsync`) or modifying EF query patterns (calls to `AsNoTracking()`, `Include`, `Select`, `FromSqlRaw`, `EF.CompileQuery`)." The expanded surface ensures the specialist is invoked on data-layer PRs even when no `HoneyDrunk.<Node>.Database/` or `Backfill/` file is touched.

If the existing agent file already documents the invocation surface elsewhere (e.g., a "When to invoke" section), update that text to include the ADR-0072 Dapper / EF-query trigger surface.

### Step 5. Severity scale consistency

The new categories inherit the Grid severity taxonomy from the existing seven categories (**Block / Request Changes / Suggest** per ADR-0044 D3 and `copilot/pr-review-rules.md`). No new severity is introduced. Each sub-check above is tagged with its severity in line with the existing rubric's tagging.

### Step 6. Reference ADR-0072 decisions inline

Per the self-containment rule (agent file consumers do not have access to ADR text), inline the relevant ADR-0072 D-decision text in each category's header. For category 9, the header text: "**Category 9 — ORM choice (per ADR-0072 D1/D2).** ADR-0072 D1 commits EF Core as the default ORM for every Node touching a relational store. D2 permits Dapper as the scoped exception for hot-path reads where (a) EF's generated SQL is measurably worse, (b) allocation profile matters, or (c) the query shape is awkward in LINQ — with mandatory evidence in the PR." Similar inlining for category 10.

## Affected Files
- `.claude/agents/database.md` (appended with categories 9 and 10).

## NuGet Dependencies
None. This packet touches only Markdown agent-rubric files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. `.claude/agents/` is governance content that lives in this repo.
- [x] No code change in any other repo.
- [x] The specialist-agent file is the ADR-0048-D13-committed surface authored by the sibling initiative; this packet extends its rubric consistent with ADR-0072's explicit D2/D5 commitments.

## Acceptance Criteria
- [ ] The PR body records that `.claude/agents/database.md` existed on `main` before the PR was opened (sibling `adr-0048-schema-evolution` packet 02 has merged)
- [ ] `.claude/agents/database.md` carries two new rubric categories (9 and 10) appended after the existing seven categories
- [ ] Category 9 (ORM choice per ADR-0072 D1/D2) carries the sub-checks: EF Core default; deviation justification; Dapper introduction evidence burden (a-d); Dapper-write rejection; per-Node-per-query scope; `FromSqlRaw`-vs-Dapper preference
- [ ] Category 10 (Query discipline per ADR-0072 D5) carries the sub-checks: `AsNoTracking()` confirmation; projection adequacy; `Include` chain audit; lazy-loading off; N+1 confirmation; compiled-query justification; raw-SQL parameterization depth check; tenant predicate presence
- [ ] The agent's invocation surface is extended to include Dapper introductions and EF query pattern modifications
- [ ] Each new category cites ADR-0072 D1/D2/D5 inline (not just by number)
- [ ] The severity scale matches the existing rubric (**Block / Request Changes / Suggest** per ADR-0044 D3 and `copilot/pr-review-rules.md`)
- [ ] The reference to the generalist surface (per ADR-0044 D3 category 13, established in packet 01 of this initiative) is present in both new categories
- [ ] No edit to `review.md` (packet 01 owns it) or any other agent file
- [ ] No invariant change (no edits to `constitution/invariants.md`)

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0072 D1 — EF Core as the default ORM.** Every Node touching a relational store uses EF Core. EF Core current LTS with `Microsoft.EntityFrameworkCore.SqlServer` for SQL Server/Azure SQL. Npgsql/PostgreSQL, Marten, RepoDb, raw ADO.NET, EF 6, and Pomelo are not v1 defaults; deviations require an explicit ADR amendment or provider-specific follow-up decision.

**ADR-0072 D2 — Dapper as the scoped exception with mandatory evidence.** Every Dapper introduction's PR carries (a) the EF-generated query, (b) the hand-written Dapper replacement, (c) benchmark numbers, (d) the workload context. Dapper is scoped to read paths; writes go through EF's DbContext. Per-Node, per-query. `FromSqlRaw` inside EF is the first option; Dapper is the second.

**ADR-0072 D5 — Query discipline.** `AsNoTracking()` on read-only queries. Projections preferred. `Include` explicit; lazy loading off. N+1 caught at review. Compiled queries permitted for hot paths. `FromSqlRaw` parameterized — never string-interpolated.

**ADR-0048 D13 — `database` specialist agent.** Authored under `.claude/agents/database.md` per ADR-0046's pattern. Walks every PR touching `HoneyDrunk.<Node>.Database/`, `Backfill/`, or any file referenced from a `DbContext`. Owns the seven-category depth rubric from D13 (D2/D5/D6/D8/D9/D10/D12 plus EF Core idiom). ADR-0072 extends this rubric with two additional categories (ORM choice, query discipline).

**ADR-0046 D1 — Specialists complement, do not replace, the `review` agent.** Specialist findings are advisory. The merge gate stays with the human.

**ADR-0046 D3 — Manual invocation at v1.** The operator invokes the specialist; no CI triggers at v1. ADR-0072's depth checks ride on the same manual-invocation surface.

**ADR-0044 D3 — Grid severity taxonomy (Block / Request Changes / Suggest, per `copilot/pr-review-rules.md`).** The new categories inherit the taxonomy.

**ADR-0026 (referenced) — Tenant predicate discipline.** Tenant-table queries without a tenant predicate are **Block** (cross-tenant leakage).

**Invariants 2 and 11 (referenced) — Same-layer dependency rule and one-repo-per-Node.** Cross-Node DbContext references force a runtime dependency between Nodes at the same layer (violating invariant 2) and imply two Nodes co-owning a deployable surface (violating invariant 11). Not a category-9 / category-10 check directly (the generalist surface in packet 01 catches it) but a referenced rule for context.

**`FromSqlRaw` parameterization (review-enforced).** No existing numbered invariant covers parameterized SQL — the rule lives in ADR-0072 D5 and is enforced by this category 10 raw-SQL parameterization sub-check. Mis-parameterized `FromSqlRaw` is a SQL injection risk; **Block** under category 10.

## Constraints
- **Hard sibling sequencing.** This packet is gated on `adr-0048-schema-evolution` packet 02 having merged. The filing pipeline's `work-item:NN` form only resolves intra-initiative; cross-initiative coupling is enforced **textually** here: the executor confirms `.claude/agents/database.md` exists on `main` before opening this packet's PR. If the sibling has not merged, the issue stays open with a wait comment; no PR is opened.
- **No holding-document fallback.** The earlier "Case B — create a proposed-form holding document" path is removed: it produces an artifact `file-work-items` cannot route, and dilutes the packet's single canonical action.
- **Additive, not replacing.** The existing seven rubric categories from `adr-0048-schema-evolution` packet 02 are kept; the two new categories are appended.
- **Match the existing rubric format.** Severity tags, category numbering, header style — match the file's established conventions established by the sibling initiative's packet 02.
- **No invariant change.** ADR-0072 explicitly does not add invariants; this packet does not edit `constitution/invariants.md`.
- **Advisory posture preserved.** Both surface (generalist) and depth (specialist) findings are advisory per ADR-0046 D1 / ADR-0011 D5.
- **Inline ADR decisions.** Per the self-containment rule, the new categories cite ADR-0072 D-decisions inline as full text, not just by number.

## Labels
`feature`, `tier-3`, `meta`, `docs`, `adr-0072`, `wave-2`

## Agent Handoff

**Objective:** Extend the `database` specialist agent's rubric with two new ORM-discipline categories from ADR-0072 (ORM choice per D1/D2 and query discipline per D5). **Hard-blocked on `adr-0048-schema-evolution` packet 02 having merged** — confirm `.claude/agents/database.md` exists on `main` before opening the PR. No holding-document fallback.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the ADR-0072 depth-level review categories in the `database` specialist agent's rubric, so Dapper introductions and EF query patterns get evidence-based depth review.
- Feature: ADR-0072 Data Access Stance rollout, Wave 2.
- ADRs: ADR-0072 D1/D2/D5 (primary), ADR-0048 D13 (specialist agent file), ADR-0046 D1/D3 (specialist pattern), ADR-0044 D3 (severity scale).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0072 must be Accepted so the rubric additions cite its decisions as live rules.
- **Sibling sequencing (textual, not in `dependencies:`)** — `adr-0048-schema-evolution` packet 02 must merge first; that packet creates `.claude/agents/database.md`. The filing pipeline does not support cross-initiative `work-item:NN` resolution, so this constraint is enforced by the executor at PR-open time.

**Constraints:**
- Confirm `.claude/agents/database.md` exists on `main` before opening the PR; otherwise the issue stays open with a wait comment.
- Additive — preserve the existing seven categories from `adr-0048-schema-evolution` packet 02.
- Inline ADR-0072 D1/D2/D5 decisions as full text per the self-containment rule.
- Severity taxonomy matches ADR-0044 D3 (**Block / Request Changes / Suggest** per `copilot/pr-review-rules.md`).
- No invariant change.
- Advisory posture preserved.

**Key Files:**
- `.claude/agents/database.md` (append categories 9 and 10).

**Contracts:** None changed.
