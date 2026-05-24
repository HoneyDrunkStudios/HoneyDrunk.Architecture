---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "meta", "docs", "adr-0048", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0048", "ADR-0046"]
wave: 2
initiative: adr-0048-schema-evolution
node: honeydrunk-architecture
---

# Author the `database` specialist review agent

## Summary
Create `.claude/agents/database.md` — the specialist review agent ADR-0048 D13 commits — embedding the D2/D5/D6/D8/D9/D10/D12 checklists. The agent walks every PR that touches `Migrations/`, `Backfill/`, or any file referenced from a `DbContext`, enforcing the schema-evolution policy ADR-0048 commits. Authored per ADR-0046's specialist-agent pattern.

## Context
ADR-0048 D13 commits the Grid to a specialist `database` review agent: "Per ADR-0046, the Grid commits to specialist review agents for high-risk surface areas. Schema evolution is one of them. The `database` agent (added to `.claude/agents/database.md` per ADR-0046's pattern) walks every PR that touches `Migrations/`, `Backfill/`, or any file referenced from a `DbContext`."

The agent is **required** on every PR that adds or modifies a migration file. ADR-0044 D3 category 13 (Data and persistence integrity) yields the per-PR review surface from the generalist `review` agent; ADR-0048 D13 commits the specialist agent that owns the depth.

ADR-0046's specialist-agent pattern (Proposed; the initiative `adr-0046-specialist-review-agents` is in flight in a sibling folder) names an initial roster of five specialist agents: `cfo`, `security`, `performance`, `ai-safety`, `a11y`. The `database` agent is **a sixth specialist** that ADR-0048 names — not in ADR-0046's initial roster. This is an intentional addition: ADR-0046's roster was named at the time ADR-0046 was authored; ADR-0048 was authored later and identifies a new high-risk surface (schema evolution) that warrants its own specialist. The pattern is the same; the roster is extended.

**Authoring per the ADR-0046 pattern.** Even though the `database` agent is outside ADR-0046's initial five, the **pattern** for authoring a specialist agent file is ADR-0046 D4's: a `.claude/agents/{name}.md` file with the agent's frontmatter, scope, invocation surface, and rubric. Read the sibling initiative's packets (especially the `cfo`/`security` agent packets in `active/adr-0046-specialist-review-agents/` once they land or are visible in draft) for the canonical layout. If those packets haven't merged when this packet executes, follow the file structure from existing `.claude/agents/*.md` files (e.g. `review.md`, `scope.md`) and the structural guidance in ADR-0046 D4.

**Manual invocation at v1 per ADR-0046 D3.** The specialist is invoked manually by the operator (via Claude Code or the cloud-wired review pipeline with the agent named explicitly). No CI trigger. ADR-0048 D13 says the `database` agent is "required on every migration-touching PR" — at v1 the *operator* enforces that by invoking the agent; later automation (a CI-triggered specialist invocation) is a deferred follow-up scoped under ADR-0046 D9 if and when that ADR's D9 is exercised.

**Scope: triggers on `Migrations/`, `Backfill/`, or any file referenced from a `DbContext`.** The agent's invocation surface includes: any `.cs` file under `*/Migrations/` (the EF Core migration class), any `.md` file under `*/Migrations/Backfill/` (the schema-on-read backfill runbook), any `.cs` file that is part of the `DbContext`'s model (entity types, `OnModelCreating` configuration, value-converter definitions). The agent does NOT trigger on application-layer changes that merely *use* the DbContext without modifying it.

This is a docs/agent-authoring packet. No code, no .NET project.

## Scope
- `.claude/agents/database.md` — new agent definition file.
- `constitution/agent-capability-matrix.md` — add the `database` agent row (if the matrix exists; if not, defer to a future hive-sync pass).
- No changes to `review.md`, `scope.md`, or any other agent file in this packet — those are packets 03 and 04.

## Proposed Implementation
1. **Author `.claude/agents/database.md`.** Structure follows the existing `.claude/agents/*.md` pattern. Required sections:

   **Frontmatter:**
   ```yaml
   ---
   name: database
   description: Specialist review agent for schema evolution, migrations, and persistence integrity per ADR-0048. Required on every PR that touches Migrations/, Backfill/, or any file referenced from a DbContext.
   model: opus
   tools: ["Read", "Grep", "Glob", "Bash"]
   ---
   ```

   **Body sections (match the format of `review.md` and the in-flight `cfo`/`security` agent files):**
   - **# Database Review** — agent introduction, scope, invocation surface.
   - **## Scope** — the agent reviews migration-touching PRs only; out-of-scope is application-layer DbContext usage that doesn't modify the model.
   - **## When to invoke** — manual invocation by the operator on any PR that adds or modifies a file matching the trigger surface (`*/Migrations/`, `*/Backfill/`, or any model file referenced from a DbContext). At v1, manual only per ADR-0046 D3.
   - **## Context to load** — `adrs/ADR-0048-data-schema-evolution-and-migration-policy.md`, `adrs/ADR-0030-grid-wide-audit-substrate.md`, `adrs/ADR-0046-specialist-review-agents.md`, `constitution/invariants.md`, the target Node's `repos/HoneyDrunk.<Node>/integration-points.md` Migration Coordination section, and `catalogs/grid-health.json` for the target Node's `schema_evolution` field.
   - **## Rubric** — the seven-category checklist from ADR-0048 D13, each category with explicit checks. See the rubric specification below.
   - **## Output format** — match the existing review-agent output convention (Markdown report on the PR thread, categorized findings, severity tags).
   - **## Severity scale** — adopt ADR-0044 D3's severity scale verbatim (blocking / strong / advisory) so the `review` and `database` agents speak the same language.
   - **## Constraints on the agent itself** — advisory per ADR-0046 D1 (specialists do not gate merge any more than the generalist `review` does). Findings carry a recommendation but the human is the final arbiter.

2. **Embed the seven-category rubric verbatim-in-substance from ADR-0048 D13:**

   - **D2 conformance — expand/contract pattern.** Is the change Expand, Migrate code, or Contract phase? Is it single-deploy destructive? If destructive, is the `[BreakingChange("reason")]` annotation present? Is the tier appropriate (only Tier 2 internal stores may use `[BreakingChange]`)? Check against the forbidden-in-a-single-deploy list (column drops, renames, narrows, nullability flips, `NOT NULL` add without default, table drops, `NOT NULL` column add without default).
   - **D5 window adequacy — Expand/Contract phase pairing.** If the migration declares `[ContractPhase("MIG-...")]`, walk back to find the matching `[ExpandPhase("...")]` PR's merge timestamp. Is the window between Expand and Contract within the store's tier window? Audit: indefinite (Contract never lands); Tier 0/1 customer-facing: 2 stable deploys or 14 days, whichever is longer; Tier 2 internal: 1 stable deploy; idempotency: 2 stable deploys or 30 days. Inadequate window is a blocking finding.
   - **D6 online primitives — index and constraint operations on large tables.** Identify the target tables. For tables ≥ 100k rows (read from the Node's `dr-runbook.md` per ADR-0036 D9 or query the staging snapshot), is the migration using online primitives? Postgres: `CREATE INDEX CONCURRENTLY`, `VALIDATE CONSTRAINT` after `ADD CONSTRAINT ... NOT VALID`. Azure SQL: `CREATE INDEX ... WITH (ONLINE = ON)`, `WITH CHECK CHECK CONSTRAINT` after `WITH NOCHECK ADD CONSTRAINT`. Missing online primitive on a large table is a blocking finding.
   - **D8 Audit constraints — if `AuditEntry` is touched.** Any column drop, type narrowing, `NOT NULL` add to an existing column, or non-nullable new column is a hard blocking finding. Suggest the paired-table pattern (`AuditEntryV2` alongside) for any case that genuinely needs a new shape. Audit's "no Contract phase ever" property is informational, not a blocker by itself.
   - **D9 tenant scoping — multi-tenant table touched.** If the target table carries a `TenantId` column, is the migration tenant-scoping-aware? Grid-wide tables (`IdempotencyKey`, `AuditEntry`, internal config) migrate once per environment without tenant logic. Tenant-scoped tables in a shared schema also migrate once; the DDL must use online primitives on any large-table migration. Per-tenant schemas (not adopted by default) trigger a deeper review and the D9 second-branch follow-up ADR check.
   - **D10 rollback declaration — `[Rollback]` attribute present and adequate.** Every migration class must carry `[Rollback(Strategy = RollbackStrategy.ForwardMigration, Notes = "...")]` (the default) or `[Rollback(Strategy = RollbackStrategy.NonRollback, Reason = "...")]`. Missing the attribute is a blocking finding. For `NonRollback`, is the `Reason` adequate (does it explain why the migration is data-destructive and unrecoverable)?
   - **D12 tests present — round-trip test added or updated.** Is there a corresponding test in `HoneyDrunk.<Node>.Tests.Integration.Containers/Migrations/<Node>MigrationRoundTripTests.cs` (or the per-Node convention)? Does the test apply all migrations up to and including the new one against a Testcontainers backing, insert representative data, read it back, and assert integrity? For Expand-phase migrations: does it also test old-shape data being read by new code (forward compatibility)? For Contract-phase migrations: does it assert the old shape is gone and any old-shape data has been migrated to the new shape? Missing or insufficient round-trip test is a blocking finding (also a CI gate failure per ADR-0047 D11 Tier 2b, but the `database` agent surfaces it during review for faster feedback).

   Plus the operational EF Core idiom check from D13:

   - **EF Core idiom — `MigrationBuilder.Sql(...)` and `--idempotent` cleanliness.** If the migration uses `MigrationBuilder.Sql(...)` (the SQL escape hatch), is it justified (the fluent API doesn't emit the desired DDL — typically the online-primitives case)? Does `dotnet ef migrations script --idempotent` still produce a clean idempotent script (the `migrate.yml` workflow per D11 runs `--idempotent`; a migration that breaks idempotency under that flag is a blocker)?

3. **Reference invariants 93/94/95 (or batch-shifted) inline.** The rubric references the three new schema-evolution invariants the acceptance packet (00) records. Include the invariant text inline in the rubric so the agent doesn't have to re-fetch `constitution/invariants.md` for the most common checks. Cite by number parenthetically.

4. **Match the existing severity scale and output format.** ADR-0044 D3 defines the severity scale used by the generalist `review` agent. The `database` agent uses the same scale and the same Markdown-report output format so a PR's combined feedback (generalist + specialist) is uniform.

5. **Capability matrix row (if matrix exists).** If `constitution/agent-capability-matrix.md` exists (per ADR-0046 D6 and the in-flight `adr-0046-specialist-review-agents/02-architecture-specialist-agent-pattern-and-roster-doc.md` packet), add a row for `database` with the same shape as the other specialist rows. If the matrix doesn't exist yet (ADR-0046 packet 02 hasn't landed), defer the row addition and note in the PR body that a future `hive-sync` pass picks it up.

## Affected Files
- `.claude/agents/database.md` — new file.
- `constitution/agent-capability-matrix.md` — conditional row addition if the matrix exists.

## NuGet Dependencies
None. This packet touches only Markdown agent-definition files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. `.claude/agents/` is governance content that lives in this repo.
- [x] No code change in any other repo.
- [x] The specialist-agent pattern is the ADR-0046-established surface; this packet extends it with a sixth specialist, consistent with ADR-0048 D13's explicit instruction.

## Acceptance Criteria
- [ ] `.claude/agents/database.md` exists with frontmatter (`name: database`, description, `model: opus`, tools list)
- [ ] The agent's scope section names the trigger surface: `*/Migrations/`, `*/Backfill/`, and any model file referenced from a `DbContext`
- [ ] The "When to invoke" section reflects manual invocation at v1 per ADR-0046 D3
- [ ] The Context to load section lists ADR-0048, ADR-0030, ADR-0046, `constitution/invariants.md`, the target Node's `integration-points.md` Migration Coordination section, and `catalogs/grid-health.json`
- [ ] The Rubric carries all seven categories from ADR-0048 D13: D2 conformance, D5 window adequacy, D6 online primitives, D8 Audit constraints, D9 tenant scoping, D10 rollback declaration, D12 tests present, plus the EF Core idiom check
- [ ] Each rubric category lists the explicit checks named in this packet (not a paraphrase)
- [ ] The three schema-evolution invariants (numbers 93/94/95 or batch-shifted) are inlined in the rubric where relevant, not just cited by number
- [ ] The severity scale matches ADR-0044 D3's scale used by the generalist `review` agent
- [ ] The output format is Markdown report on the PR thread, categorized findings, severity-tagged, consistent with `review.md`
- [ ] The agent is documented as advisory per ADR-0046 D1 — findings do not gate merge any more than the generalist `review` does
- [ ] If `constitution/agent-capability-matrix.md` exists, a `database` row is added matching the existing row shape; if not, the PR body notes the deferral to a future `hive-sync` pass

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0048 D13 — Specialist `database` agent.** Per ADR-0046, the Grid commits to specialist review agents for high-risk surface areas. Schema evolution is one of them. The agent walks every PR that touches `Migrations/`, `Backfill/`, or any file referenced from a `DbContext`. Checks: D2 conformance (single-deploy destructive change + `[BreakingChange]` annotation), D5 window adequacy (Expand/Contract phase pairing), D6 online primitives (row count vs 100k threshold), D8 Audit constraints (column drop / type narrowing / `NOT NULL` add forbidden on `AuditEntry`), D9 tenant scoping (multi-tenant table touched), D10 rollback declaration (`[Rollback]` attribute present and adequate), D12 tests present (round-trip test), EF Core idiom (`MigrationBuilder.Sql(...)` and `--idempotent` cleanliness). Required on every migration-touching PR. Invoked from `scope` agent when packets imply schema changes (packet 04 wires that).

**ADR-0046 D1 — Specialists complement, do not replace, the `review` agent.** The `review` agent remains the baseline reviewer with the full twenty-category rubric and runs on every PR; specialists run only when their lens specifically applies. Specialist findings do not gate merge any more than `review`'s do — the advisory posture of ADR-0011 D5 is preserved.

**ADR-0046 D3 — Manual invocation only at v1.** No CI triggers; the operator decides when a lens applies. ADR-0048 D13 says the `database` agent is "required on every migration-touching PR" — at v1 the operator enforces that by invocation; CI-triggered specialist invocation is a deferred follow-up scoped under ADR-0046 D9.

**ADR-0046 D4 — Specialist agent file structure.** The `.claude/agents/{name}.md` file carries frontmatter (`name`, `description`, `model`, `tools`), scope, invocation surface, context to load, rubric, severity scale (matched to ADR-0044), output format, and constraints. The `database` agent follows the same structure as `cfo`/`security`/`performance`/`ai-safety`/`a11y`.

**ADR-0044 D3 — The twenty-category review rubric and severity scale.** Category 13 (Data and persistence integrity) yields the per-PR review surface from the generalist `review`; ADR-0048 D13 (this packet) commits the specialist agent that owns the depth. The severity scale (blocking / strong / advisory) is reused by `database`.

**ADR-0030 D4 — Append-only-by-interface.** `IAuditLog` exposes no update and no delete method. The migration-time consequence is ADR-0048 D8: no column drops, no type narrowing, no `NOT NULL` additions on existing columns, new columns always nullable, paired-table pattern for breaking changes. The `database` agent enforces these at the migration-PR review surface.

## Constraints
- **Inline invariant text in the rubric.** Per the scope-agent self-containment rule and the issue-authoring rules, write the actual invariant text in the rubric, not just the number — the agent reading it must not need to re-fetch `constitution/invariants.md` for the most common checks.
- **Match the generalist `review` agent's severity scale and output format.** The `database` agent's findings appear in the same PR review thread alongside `review`'s; uniformity reduces operator cognitive load.
- **Advisory posture preserved.** Per ADR-0046 D1, the `database` agent does not gate merge. Its findings are advisory; the human is the final arbiter. Do not write language that implies blocking authority at runtime — write "blocking finding" to describe the *category* of severity, but the merge gate stays with the human and CI.
- **No edits to `review.md` or `scope.md` in this packet.** Those are packets 03 and 04. This packet only creates `database.md` (and optionally adds a capability-matrix row).
- **The `database` agent is a sixth specialist, outside ADR-0046's initial roster of five.** Note this in the agent file's introduction (a one-line explanation of why it's not in the original five). The pattern is identical to ADR-0046's; the roster is extended by ADR-0048.

## Labels
`feature`, `tier-3`, `meta`, `docs`, `adr-0048`, `wave-2`

## Agent Handoff

**Objective:** Create `.claude/agents/database.md` as a specialist review agent per ADR-0048 D13, embedding the seven-category schema-evolution rubric.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the Grid a specialist agent that enforces ADR-0048's schema-evolution policy on every migration-touching PR.
- Feature: ADR-0048 Schema Evolution rollout, Wave 2.
- ADRs: ADR-0048 D13 (primary), ADR-0046 D1/D3/D4 (pattern), ADR-0044 D3 (severity scale + output format), ADR-0030 D4 (Audit append-only-by-interface).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0048 must be Accepted so the agent's rubric can cite the three new schema-evolution invariants (93/94/95 or batch-shifted) as live rules.

**Constraints:**
- Inline invariant text in the rubric — do not cite by number alone.
- Match the `review` agent's severity scale and output format.
- Advisory posture per ADR-0046 D1.
- The `database` agent is the sixth specialist; ADR-0046's initial roster of five is extended, not replaced.

**Key Files:**
- `.claude/agents/database.md` — new file.
- `constitution/agent-capability-matrix.md` — conditional row addition.

**Contracts:** None changed.
