---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "meta", "docs", "adr-0072", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0072", "ADR-0044", "ADR-0048"]
wave: 2
initiative: adr-0072-data-access-stance
node: honeydrunk-architecture
---

# Extend review.md D3 category 13 with ADR-0072 EF Core discipline + Dapper evidence checks

## Summary
Extend `.claude/agents/review.md` D3 category 13 (Data and persistence integrity) with the ADR-0072 D5 query-discipline checks (`AsNoTracking()`, projections, explicit `Include`, lazy loading off, parameterized `FromSqlRaw`, N+1 detection) and the ADR-0072 D2 Dapper-evidence-burden check (Dapper introductions require the EF query, the hand-written replacement, and benchmark numbers in the PR). These are surface-level checks the generalist `review` agent performs on every PR touching data-layer code; depth review lives in the `database` specialist agent's rubric (packet 02).

## Context
ADR-0072's Consequences/Invariants section commits five conventions as review-enforced rather than as numbered invariants:

1. EF Core is the default for relational data access (D1).
2. Writes go through EF Core's DbContext; a Dapper-write path is a hard finding (D2).
3. `AsNoTracking()` on read-only queries; explicit `Include`; lazy loading off (D5).
4. DbContext is per-Node, never shared (D4).
5. Connection strings come from Vault (D4 / ADR-0005).

ADR-0072's Decision D2 also commits Dapper as a **scoped exception with mandatory evidence**: every Dapper introduction's PR carries the EF-generated query, the hand-written Dapper replacement, and benchmark numbers. Without the evidence the introduction is rejected at review.

`.claude/agents/review.md` D3 category 13 (Data and persistence integrity) is the home for the surface-level checks. Category 13 currently carries:

- Data correctness (referential integrity, precision and rounding, idempotency per ADR-0042).
- Migration safety (backfill, rollback, zero-downtime — extended by sibling initiative `adr-0048-schema-evolution` packet 03).
- Multi-tenant integrity (isolation per ADR-0026).

This packet appends:

- **EF Core query discipline** (D5 checks) as the per-query review surface.
- **Dapper-evidence burden** (D2 check) — the generalist flags Dapper introductions for the specialist's evidence review.

**Why surface-level and not depth-level.** The generalist `review` agent runs on every PR. Its category 13 check is a fast, pattern-based scan: "is there an EF query with no `AsNoTracking()` on a read path?", "is there a `FromSqlRaw` with string interpolation?", "is there a new `using Dapper` directive?". When the surface check flags a Dapper introduction, the rubric instructs the operator to invoke the `database` specialist agent for the depth review (the seven-category checklist from ADR-0048 D13 + the ADR-0072 D2/D5 ORM-choice and query-discipline categories from packet 02 of this initiative). The two surfaces compose:

- **Generalist (this packet)** — "Is this a data-layer change? Does it look like it follows the conventions? If not, flag for depth review."
- **Specialist (packet 02)** — "Is this Dapper introduction backed by evidence? Is the EF query genuinely worse? Are the benchmark numbers credible?"

**Coupling with sibling initiative `adr-0048-schema-evolution`.** ADR-0048's packet 03 also edits `review.md` D3 category 13 — to delegate depth review of migration-touching PRs to the `database` specialist. The two packets edit the same category but different sections of it:

- ADR-0048's packet 03 adds a delegation stanza at the end of category 13 ("for migration-touching PRs, delegate to `database`").
- This packet adds query-discipline checks alongside the existing data-correctness / migration-safety / multi-tenant-integrity bullets, and adds a Dapper-introduction surface check.

The two edits are additive and order-tolerant. If ADR-0048's packet 03 lands first, this packet's additions land alongside the existing delegation stanza. If this packet lands first, ADR-0048's packet 03 adds its delegation stanza below the query-discipline section. Neither replaces the other's content.

This is a docs/agent-configuration packet. No code, no .NET project.

## Scope
- `.claude/agents/review.md` — extend D3 category 13 (Data and persistence integrity) with the ADR-0072 D5 query-discipline checks and the D2 Dapper-evidence-burden surface check.
- No edit to `database.md` (packet 02 owns it).
- No edit to any other agent file.

## Proposed Implementation
1. **Locate D3 category 13** in `.claude/agents/review.md`. The categories were established by ADR-0044 packets 04 and 09 (rubric-roll-out); the rubric is a twenty-category list. Category 13 is titled **"Data and persistence integrity"** — confirm the exact title and capitalization at edit time.

2. **Add a new bulleted sub-section under category 13** titled **"EF Core query discipline (per ADR-0072 D5)"**, with the following checks. Match the file's existing bullet style and severity-tag conventions. Each check below is a per-bullet item:

   - **`AsNoTracking()` on read-only queries.** Read-only EF queries (returning a list or a single entity for display, not for modification) carry `AsNoTracking()` to opt out of change tracking. Reads without `AsNoTracking()` are allocation-heavy; the surface check looks for `_context.<DbSet>.Where(...).ToList()` patterns without `.AsNoTracking()` in the chain.
   - **Projections preferred for column-subset reads.** Where the consumer needs a subset of columns, `.Select(x => new ProjectionType { ... })` is preferred over loading the full entity. The surface check looks for full-entity loads followed by mapping to a smaller shape — that mapping should happen in SQL via `Select`, not in memory.
   - **`Include` is explicit; lazy loading is off.** Navigation properties are loaded via explicit `Include` calls. Lazy loading is disabled in the default DbContext composition; a `UseLazyLoadingProxies()` call is a **Block** finding. Explicit-loading via `context.Entry(...).Reference(...).Load()` is permitted but should be justified.
   - **N+1 queries are caught at review.** The `foreach (var item in list) { var related = ctx.Related.Where(r => r.ItemId == item.Id).ToList(); }` pattern is the classic N+1; rewrite as a single query with `Include` or projection. The surface check looks for `.ToList()` inside loops that themselves iterate over a `.ToList()` result.
   - **Compiled queries permitted for hot paths.** `EF.CompileQuery` is permitted where the compile cost amortizes (high-frequency read paths). The surface check does not block compiled queries; it flags them for the specialist's evidence check if introduced (the compile cost should be justified).
   - **Raw SQL via `FromSqlRaw` is parameterized.** `FromSqlRaw($"... {input}")` (string interpolation) is a hard **Block** finding — SQL injection risk (review-enforced secure-SQL discipline per ADR-0072 D5; no existing numbered invariant covers parameterized SQL). Use `FromSqlRaw("... {0}", input)` with parameter placeholders, or `FromSqlInterpolated` which parameterizes the interpolated values automatically.

3. **Add a new sub-section under category 13** titled **"Dapper-evidence burden (per ADR-0072 D2)"**, with the following surface checks. Match the file's existing format:

   - **Dapper introductions are flagged for specialist review.** A new `using Dapper;` directive or a new `IDbConnection.Query<T>` / `QueryAsync<T>` call invokes Dapper. The surface check detects this and notes: "Dapper introduction detected — depth review by the `database` specialist agent is required per ADR-0072 D2."
   - **Dapper-write paths are rejected at the surface.** Dapper writes (`Execute`, `ExecuteAsync`) are scoped out by ADR-0072 D2: writes go through EF Core's DbContext. The surface check rejects Dapper-write introductions as a **Block** finding with the recommendation: "Use EF Core's DbContext for writes; if a write genuinely requires raw SQL, use `MigrationBuilder.Sql(...)` (for schema changes) or `DbContext.Database.ExecuteSqlInterpolated(...)` (for runtime data-layer SQL that still wants EF's connection / transaction management)."
   - **The evidence-burden checklist is named.** The surface check reminds the operator: "Dapper introductions require (a) the EF-generated query (paste it in the PR body or describe it), (b) the hand-written Dapper replacement, (c) benchmark numbers (BenchmarkDotNet or profiler evidence), and (d) the workload context (expected query frequency, expected row volume, the consuming caller). The `database` specialist agent verifies all four. Missing evidence is a **Block** finding at the specialist's depth review; the generalist's surface check just flags the introduction."

4. **Add a brief connection-strings-from-Vault check** alongside the existing multi-tenant integrity sub-section, since both relate to the per-Node data-layer composition pattern (D4):

   - **Connection strings come from Vault (per ADR-0005 / ADR-0072 D4).** The surface check looks for `appsettings.json` entries with `Server=` / `Host=` / connection-string-shaped values (a regex on `Data Source=`, `Server=`, `Host=`, `Database=`, `User Id=`). A hardcoded connection string in `appsettings.json` or an `IConfiguration` value not routed through `ISecretStore` is a **Block** finding (invariant 9 — Vault is the only source of secrets).

5. **Add a brief per-Node DbContext check** alongside the existing checks:

   - **DbContext is per-Node, never shared (per ADR-0072 D4).** The surface check looks for `using HoneyDrunk.<OtherNode>.Data;` directives in a Node that should not depend on another Node's data layer. A cross-Node DbContext reference is a **Block** finding — under the Grid's boundary discipline (invariant 11 "one repo per Node" and invariant 2's same-layer rule), a cross-Node DbContext forces a runtime dependency between Nodes at the same layer; per ADR-0072 D4, each Node owns its own DbContext.

6. **Severity scale alignment.** Per ADR-0044 D3 / `copilot/pr-review-rules.md`, the rubric uses the Grid severity taxonomy: **Block / Request Changes / Suggest**. The new checks inherit the scale:
   - **Block**: string-interpolated `FromSqlRaw`, hardcoded connection strings, cross-Node DbContext references, Dapper-write introductions.
   - **Request Changes**: missing `AsNoTracking()` on a clearly read-only path, lazy-loading proxies enabled, an N+1 pattern.
   - **Suggest**: a column-subset read without projection, a compiled query without justification, a Dapper-read introduction (flagged for specialist evidence review — the introduction itself is not Block at the generalist surface; the specialist's depth check determines the outcome).

7. **Match the existing format and tone.** Severity tags, capitalization, list style — match the file's established conventions. ADR-0044 packets 04 and 09 set the format; do not invent a parallel structure.

8. **Update the category 13 "Execution detail" and "Severity mapping" paragraphs.** Category 13 currently has trailing paragraphs naming the inspection surface and the severity mapping (block / changes / suggest). Extend the existing text to include the new ORM-discipline surface:
   - **Execution detail** add-on: "Also inspect EF query patterns (`AsNoTracking()`, projections, `Include`, lazy-loading state, parameterized raw SQL), Dapper introductions (flag for specialist evidence review), connection-string sourcing (Vault per ADR-0005 / invariant 9), and per-Node DbContext boundary (no cross-Node DbContext references — grounded in invariants 2 and 11 per ADR-0072 D4)."
   - **Severity mapping** add-on (using the Grid severities Block / Request Changes / Suggest per `copilot/pr-review-rules.md`): "Block for string-interpolated `FromSqlRaw`, hardcoded connection strings, cross-Node DbContext references, and Dapper-write introductions. Request Changes for missing `AsNoTracking()` on read paths, lazy-loading proxies, or N+1 patterns. Suggest for unprojected column-subset reads and unjustified compiled queries. Flag Dapper-read introductions for the `database` specialist agent's depth evidence review (generalist itself does not block)."

## Affected Files
- `.claude/agents/review.md`

## NuGet Dependencies
None. This packet touches only a Markdown agent-rubric file; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. `.claude/agents/review.md` is governance content that lives in this repo.
- [x] No code change in any other repo.
- [x] The review-rubric is the ADR-0044-established surface; this packet extends category 13 with ORM-discipline checks consistent with ADR-0072 D2/D4/D5's explicit commitments.

## Acceptance Criteria
- [ ] `.claude/agents/review.md` D3 category 13 (Data and persistence integrity) carries a new sub-section titled "EF Core query discipline (per ADR-0072 D5)" with the six bullet checks: `AsNoTracking()`, projections preferred, explicit `Include` + lazy off, N+1, compiled queries, parameterized `FromSqlRaw`
- [ ] Category 13 carries a new sub-section titled "Dapper-evidence burden (per ADR-0072 D2)" with the three surface checks: Dapper introductions flagged, Dapper-writes rejected at surface, evidence-burden checklist named (EF query / Dapper query / benchmarks / workload context)
- [ ] Category 13 carries the connection-strings-from-Vault check and the per-Node DbContext check
- [ ] The "Execution detail" paragraph at the end of category 13 is extended to include the new ORM-discipline surface
- [ ] The "Severity mapping" paragraph is extended to include the new Block / Request Changes / Suggest mappings (matching the existing rubric's Grid severity taxonomy)
- [ ] Existing category-13 checks (data correctness, migration safety extended by `adr-0048-schema-evolution`, multi-tenant integrity) are preserved, not replaced
- [ ] If `adr-0048-schema-evolution` packet 03's delegation stanza has landed already, it remains intact alongside the new ADR-0072 additions
- [ ] The severity scale matches the existing rubric's scale (Block / Request Changes / Suggest per ADR-0044 D3 and `copilot/pr-review-rules.md`)
- [ ] No edits to `database.md` (packet 02 owns it) or `scope.md`
- [ ] No invariant change in this packet (no edits to `constitution/invariants.md`)

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0072 D2 — Dapper as the scoped exception with mandatory evidence.** Every Dapper introduction's PR includes (a) the EF-generated query, (b) the hand-written Dapper replacement, (c) benchmark numbers, (d) the workload context. Dapper is scoped to read paths only; writes go through EF's DbContext. `FromSqlRaw` inside EF is the first option; Dapper is the second. The generalist `review` agent's surface check flags Dapper introductions for the `database` specialist agent's depth evidence review (per packet 02).

**ADR-0072 D4 — Per-Node DbContext, scoped composition.** Each Node owns its own `DbContext`(s); sharing across Nodes is forbidden (grounded in invariants 2 and 11). Connection strings come from Vault per ADR-0005 via `ISecretStore` (invariant 9); `appsettings.json` connection-string-shaped values are **Block**.

**ADR-0072 D5 — Query discipline.** `AsNoTracking()` on every read-only query. Projections preferred. `Include` explicit; lazy loading off. N+1 caught at review. Compiled queries permitted for hot paths. `FromSqlRaw` parameterized — never string-interpolated.

**ADR-0044 D3 — Twenty-category review rubric and severity taxonomy.** Category 13 is "Data and persistence integrity." The rubric uses the Grid severity taxonomy (**Block / Request Changes / Suggest**, per `copilot/pr-review-rules.md` referenced from the rubric file) that the new ADR-0072 checks inherit. The generalist `review` agent owns the surface; depth lives with specialists per ADR-0046.

**ADR-0046 D1 — Specialists complement, do not replace, the `review` agent.** Specialist findings do not gate merge any more than the generalist's. The Dapper-evidence depth review under the `database` specialist (packet 02) is advisory; the merge gate stays with the human.

**ADR-0048 D13 — `database` specialist agent.** Owns the depth review for migration-touching PRs (the seven-category checklist from D13). Sibling initiative `adr-0048-schema-evolution` packet 02 authors the agent file; this initiative's packet 02 extends the rubric with ADR-0072's ORM-choice and query-discipline categories.

**Invariants 2 and 11 (referenced) — Same-layer dependency rule and one-repo-per-Node.** Cross-Node DbContext references force a runtime dependency between Nodes at the same layer (violating invariant 2) and imply two Nodes co-owning a deployable surface (violating invariant 11). The surface check rejects them as **Block**.

**`FromSqlRaw` parameterization (review-enforced).** No existing numbered invariant covers parameterized SQL. ADR-0072 D5 commits the rule as review-enforced; string-interpolated `FromSqlRaw` is a **Block** finding under category 13. Invariant 8 covers secret values in logs/traces — a distinct concern and not the home of this rule.

**ADR-0005 (referenced) — Connection strings come from Vault.** Hardcoded connection-string values in `appsettings.json` are **Block** (invariant 9 — Vault is the only source of secrets).

## Constraints
- **Additive, not replacing.** Existing category-13 surface checks (data correctness, migration safety, multi-tenant integrity) are kept. The new ORM-discipline sub-sections are appended; they do not delete or rewrite existing language.
- **Sibling-edit coexistence.** Sibling initiative `adr-0048-schema-evolution` packet 03 adds a delegation stanza to category 13. The two edits are additive and order-tolerant; preserve any delegation language already present, and add the new ADR-0072 sub-sections alongside.
- **Match the rubric's existing format.** Severity tags, capitalization, list style — match the file's established conventions. ADR-0044 packets 04 and 09 set the format; do not invent a parallel structure.
- **Severity discipline.** Use the Grid severities **Block / Request Changes / Suggest** per `copilot/pr-review-rules.md`. Block for string-interpolated `FromSqlRaw`, hardcoded connection strings, cross-Node DbContext references, Dapper-write introductions. Request Changes for missing `AsNoTracking()`, lazy-loading proxies, N+1. Suggest for unprojected column-subset reads, unjustified compiled queries, Dapper-read introductions (flagged for specialist evidence review).
- **No invariant change.** ADR-0072 explicitly does not add invariants; this packet does not edit `constitution/invariants.md`.
- **Advisory posture preserved.** Both the surface check (generalist) and the depth review (specialist) are advisory. The merge gate stays with the human and CI per ADR-0011 D5 / ADR-0046 D1.

## Labels
`feature`, `tier-3`, `meta`, `docs`, `adr-0072`, `wave-2`

## Agent Handoff

**Objective:** Extend `.claude/agents/review.md` D3 category 13 with the ADR-0072 D5 query-discipline checks and the D2 Dapper-evidence-burden surface check.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the ADR-0072 review-time conventions as surface checks in the generalist `review` agent's category 13 rubric.
- Feature: ADR-0072 Data Access Stance rollout, Wave 2.
- ADRs: ADR-0072 D2/D4/D5 (primary), ADR-0044 D3 (rubric format and Grid severity taxonomy Block / Request Changes / Suggest), ADR-0046 D1 (specialist pattern and advisory posture), ADR-0048 D13 (delegation to `database` specialist for depth review), ADR-0005 (connection strings from Vault).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0072 must be Accepted so the rubric additions cite its decisions as live rules.

**Constraints:**
- Additive — do not delete existing category-13 surface checks (data correctness, migration safety, multi-tenant integrity).
- Sibling-edit coexistence — preserve any `adr-0048-schema-evolution` packet 03 delegation language; add new sub-sections alongside.
- Match the rubric's existing format and Grid severity taxonomy (Block / Request Changes / Suggest).
- No invariant change.
- Advisory posture preserved.

**Key Files:**
- `.claude/agents/review.md` (specifically D3 category 13).

**Contracts:** None changed.
