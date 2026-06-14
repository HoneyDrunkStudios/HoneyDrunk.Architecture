---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0048", "wave-1"]
dependencies: []
adrs: ["ADR-0048"]
accepts: ["ADR-0048"]
wave: 1
initiative: adr-0048-schema-evolution
node: honeydrunk-architecture
---

# Accept ADR-0048 — flip status, add the three schema-evolution invariants, register the initiative

## Summary
Flip ADR-0048 (Data Schema Evolution and Migration Policy) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the three new schema-evolution invariants ADR-0048 commits in its Consequences/Invariants section to `constitution/invariants.md`, claim the invariant-number block in `constitution/invariant-reservations.md`, and register the `adr-0048-schema-evolution` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0048 commits the Grid's response to a missing schema-evolution policy: **EF Core Migrations** as the Grid-wide framework for relational stores (D1), the **expand → migrate code → contract** pattern as the zero-downtime mechanic (D2), the **out-of-band `migrate.yml` workflow** as the timing model — operator-triggered, separate from app deploy (D3), per-store backward-compatibility windows (D5), online DDL primitives on tables ≥ 100k rows (D6), schema-on-read for document stores (D7), append-only-by-interface migration constraints for Audit (D8), tenant-scoped vs Grid-wide ordering (D9), forward-only rollback (D10), file/naming conventions plus the `migrate.yml` reusable workflow (D11), round-trip tests + `[Rollback]` declaration as test requirements (D12), a specialist `database` review agent per ADR-0046 (D13), and a 6-phase rollout (D14).

ADR-0048 is a **policy / contract** ADR. The concrete code — the `database` specialist agent file, the `migrate.yml` reusable workflow in HoneyDrunk.Actions, the `Migrations/README.md` per-Node template, the `review`/`scope` agent updates, the `schema_evolution` catalog field, the retroactive Notify-scaffold annotation, the Cosmos schema-on-read documentation for the Kernel idempotency dedup store — lands in implementation packets 01–08. Catalog and template work lands as Architecture packets; the reusable workflow lands as an Actions packet; the document-store and retroactive-annotation work land as Kernel and Notify packets respectively.

The ADR decides:
- **D1** — EF Core Migrations is the Grid-wide schema-evolution framework for all relational stores (Azure SQL, Postgres); per-Node framework choice is not allowed. EF Core 9.x at the time of the ADR; framework version is a per-Node SemVer concern. Used for schema only; reference-data seeding lives elsewhere.
- **D2** — every non-trivial schema change is three deploys: **Expand** (add the new shape; old shape remains), **Migrate code** (deploy code that reads/writes the new shape; both shapes coexist), **Contract** (remove the old shape). Specific operations are forbidden in a single deploy (column drop, rename, narrow, nullability flip, `NOT NULL` add without default); specific operations are allowed (add nullable column, add table, add online index, etc.). Non-negotiable for Nodes holding production tenant data; permitted with `[BreakingChange]` annotation on Tier 2 internal stores.
- **D3** — migrations run via an **out-of-band, operator-triggered `migrate.yml` workflow** added to HoneyDrunk.Actions. NOT at app startup (rejected: races ADR-0015 D6's multi-revision window; blocks app boot on DDL latency). NOT via init container (rejected: same race; weaker observability). The chosen pattern: migration PR lands first (Expand); operator triggers `migrate.yml` with `(environment, node)` inputs — the workflow runs `dotnet ef migrations script --idempotent` and applies via `sqlcmd` (Azure SQL) or `psql` (Postgres) using the OIDC credential model from ADR-0015; operator then triggers the dependent code deploy per ADR-0033 D1. A failed migration does NOT roll back the app — the app stays on the old code against the old schema.
- **D4** — the expand/contract pattern (D2) is what makes ADR-0015 D6's two-revisions-against-the-same-DB window safe: the schema is monotonically forward-compatible with the older code revision; the Contract phase only happens after the older revision is fully drained.
- **D5** — per-store backward-compatibility window: **Audit (per ADR-0030 append-only-by-interface) — indefinite (≥ 730-day retention; no Contract phase ever, see D8)**; Tier 0/1 customer-facing stores (Notify Cloud, Memory, Knowledge, Billing) — two stable deploys or 14 days, whichever is longer; Tier 2 internal stores — one stable deploy minimum; idempotency stores — two stable deploys or 30 days (matching ADR-0042 D4 billing/audit TTL). Enforced by `database` agent review using `[ExpandPhase("MIG-...")]`/`[ContractPhase("MIG-...")]` attributes.
- **D6** — online DDL on tables ≥ 100k rows: Postgres `CREATE INDEX CONCURRENTLY` / `ALTER TABLE ... VALIDATE CONSTRAINT` after `ADD CONSTRAINT ... NOT VALID`; Azure SQL `CREATE INDEX ... WITH (ONLINE = ON)` / `WITH CHECK CHECK CONSTRAINT` after `WITH NOCHECK ADD CONSTRAINT`. Required explicitly above the row-count threshold; violation is a review block.
- **D7** — document stores (Cosmos and future vector/document backings) follow **schema-on-read**: new fields added by writing them; reading code tolerates absence; backfill is an operator-triggered job documented as `Migrations/Backfill-YYYYMMDD-{description}.md`, not an EF migration; field removal mirrors relational Contract phase. Partition key changes are a **container migration** (new container, dual-write, backfill, dual-read, cutover) — the most expensive shape; will trigger a follow-up ADR when first needed. The default Cosmos-backed `IIdempotencyStore` (per ADR-0042 D2) follows D7.
- **D8** — Audit `AuditEntry` table specifics (interacts with ADR-0030 append-only-by-interface): **no column drops, ever**; **no type narrowing, ever**; **no `NOT NULL` additions** to existing columns; **new columns are nullable, always**; **paired-table pattern for breaking changes** (`AuditEntryV2` alongside, UNION across); indexes may be added or dropped. Migration-time invariant, not just runtime.
- **D9** — Grid-wide tables (e.g., `IdempotencyKey`, `AuditEntry`, internal config) migrated **once per environment**, no tenant-scoping logic. Tenant-scoped tables in a shared schema (the default Notify Cloud pattern: one table, `TenantId` column) also migrated once per environment via online primitives. Per-tenant schemas not adopted by default; if adopted, "iterate the tenant list, apply per-tenant" via a runbook-driven `migrate.yml` variant; tenant N fully migrated before tenant N+1; partial failure is resume-from-tenant-N, not rollback. The per-tenant variant triggers a follow-up ADR if and when adopted.
- **D10** — failure handling: **forward-only by default** — EF Core `Down()` is generated but not committed to in production. Transactional DDL where the provider supports it. Non-transactional operations (online indexes) are resumable via the migration history table. Mid-failure: re-run `migrate.yml` to re-apply un-applied DDL, then fix-forward or roll-forward with a compensating migration. `migrate.yml` retains the applied SQL + history snapshot as workflow artifacts.
- **D11** — file conventions: migrations live in `src/HoneyDrunk.<Node>.Data/Migrations/<timestamp>_<DescriptiveName>.cs`; backfill docs in `Migrations/Backfill/`; per-Node `Migrations/README.md` overview. `migrate.yml` reusable workflow inputs (`node`, `environment`, optional `target-migration`); `workflow_dispatch` only; protected by GitHub Environment rules on `staging`/`prod`.
- **D12** — every migration carries **two mandatory test artifacts**: a round-trip test in `HoneyDrunk.<Node>.Tests.Integration.Containers/Migrations/<Node>MigrationRoundTripTests.cs` (CI gate per ADR-0047 Tier 2b) and a `[Rollback(Strategy = ..., Notes/Reason = "...")]` attribute declaration on the migration class (informational; review-enforced).
- **D13** — specialist `database` review agent (added per ADR-0046's pattern). Required on every migration-touching PR. Enforces D2/D5/D6/D8/D9/D10/D12. Invoked from `scope` agent when packets imply schema changes.
- **D14** — 6-phase rollout: Phase 1 (Week 1-2) author the agent + workflow + template; Phase 2 (Week 2-4) Kernel.Idempotency pilot (Cosmos schema-on-read); Phase 3 (Week 4-6) Audit standup full pattern; Phase 4 (Month 2-3) Memory/Knowledge consume; Phase 5 (Month 3+) Billing consumes; Phase 6 (ongoing) Notify Cloud per-tenant.

Every other packet in this initiative references ADR-0048's decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Invariant Numbering
ADR-0048 adds **three** invariants. Numbers are claimed at execution time from `constitution/invariant-reservations.md`, which is the source of truth for in-flight reservations across all Proposed ADRs.

**Procedure (executed by this packet, not pre-baked):**

1. Read `constitution/invariant-reservations.md`. Identify the current "next free" number (the file's header records it; today the file states **next free = 54**).
2. Read `constitution/invariants.md` and verify the highest accepted invariant number is consistent with the reservations file's "high-water mark on disk" (today: **53**). If the reservations file's high-water mark is stale because an unrelated invariant landed since the file was last touched, recompute next-free as `max(invariants.md) + 1`.
3. Claim a block of size **3** starting at the next-free number. Throughout this packet's edits, refer to the three claimed numbers as `{N1}`, `{N2}`, `{N3}` (where `{N2} = {N1} + 1` and `{N3} = {N1} + 2`).
4. In the same PR, add a row to the **Active Reservations** table in `constitution/invariant-reservations.md`:

   ```
   | {N1}–{N3} | ADR-0048 | Proposed→Accepted | Packet 00 of adr-0048-schema-evolution initiative |
   ```

5. Substitute `{N1}/{N2}/{N3}` throughout this packet's body, the new invariant rows in `constitution/invariants.md`, the `dispatch-plan.md` references, the `handoff-wave4-first-adopters.md` references, and any downstream packet that quotes the invariant numbers (today: 02 inlines the invariant text; 03 and others cite by reference). The substitution lands in the same commit; no `hive-sync` is needed.

**Collision handling.** If `git pull` produces a conflict on `constitution/invariant-reservations.md` (because another in-flight ADR's packet 00 merged first), follow the file's documented collision-resolution procedure: shift this block upward to the new next-free, update every `{N1}/{N2}/{N3}` substitution in the same rebase commit, and force-push the branch.

## Scope
- `adrs/ADR-0048-data-schema-evolution-and-migration-policy.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0048 row Status column to Accepted.
- `constitution/invariants.md` — add the three new schema-evolution invariants (see Proposed Implementation for exact text), numbered `{N1}`, `{N2}`, `{N3}` claimed per the Invariant Numbering procedure above.
- `constitution/invariant-reservations.md` — add an Active Reservations row claiming the block `{N1}–{N3}` for ADR-0048.
- `initiatives/active-initiatives.md` — register the `adr-0048-schema-evolution` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0048 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0048 index row in `adrs/README.md` to Accepted.
3. Claim the invariant-number block per the Invariant Numbering procedure: read `constitution/invariant-reservations.md` and `constitution/invariants.md`; compute `{N1}` = next free; substitute `{N1}/{N2}/{N3}` throughout the PR.
4. Add a row to the **Active Reservations** table in `constitution/invariant-reservations.md` claiming `{N1}–{N3}` for ADR-0048.
5. Add three new invariants to `constitution/invariants.md`, numbered `{N1}`, `{N2}`, `{N3}`. The text, taken verbatim-in-substance from ADR-0048's Consequences "Invariants" section:
   - **`{N1}` — Relational stores use EF Core Migrations.** Every relational store in the Grid (Azure SQL, Postgres) uses EF Core Migrations for schema evolution. Per-Node framework choice is not allowed. Document-store schema-on-read (per ADR-0048 D7) is the only exception — Cosmos and future vector/document backings have no DDL and evolve by writing new fields. See ADR-0048 D1, D7.
   - **`{N2}` — Production migrations run via the `migrate.yml` workflow, never at app startup, never via init container.** The out-of-band timing is non-negotiable; ADR-0015 D6's multi-revision traffic-split window depends on it. The workflow is operator-triggered (`workflow_dispatch` only), runs `dotnet ef migrations script --idempotent` against the Node's DbContext, applies via `sqlcmd` (Azure SQL) or `psql` (Postgres) using the OIDC credential model per ADR-0015, and is independent of the app deploy. A failed migration does NOT roll back the app. See ADR-0048 D3, D11.
   - **`{N3}` — Every migration carries a `[Rollback]` attribute and a Tier 2b round-trip test.** Each migration class declares `[Rollback(Strategy = RollbackStrategy.ForwardMigration, Notes = "...")]` or `[Rollback(Strategy = RollbackStrategy.NonRollback, Reason = "...")]`. Each migration also has a Tier 2b round-trip test in `HoneyDrunk.<Node>.Tests.Integration.Containers/Migrations/<Node>MigrationRoundTripTests.cs` that applies all migrations up to and including the new one against a Testcontainers backing, inserts representative data, reads it back, and asserts integrity. Missing the attribute is a review block (`database` agent per ADR-0048 D13); missing the round-trip test is a CI gate failure (ADR-0047 D11 Tier 2b job). See ADR-0048 D12.
   - Create a new `## Schema Evolution Invariants` section (the file's existing sectioning convention groups invariants by topic — Dependency, Context, Secrets, Packaging, Testing, AI, Audit, Idempotency, Multi-Tenant, Communications, etc.; schema evolution is a new cross-cutting topic and warrants its own section). Place it after the `## Audit Invariants` section. If the `## Idempotency Invariants` section from ADR-0042 has already landed, place `## Schema Evolution Invariants` after it (the file is topic-grouped, not strictly ordered by number — see the existing layout where invariants 50/51 sit beside the testing block).
6. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0048-data-schema-evolution-and-migration-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0048 header reads `**Status:** Accepted`
- [ ] The ADR-0048 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` carries a new row in the **Active Reservations** table claiming the block `{N1}–{N3}` for ADR-0048, citing this packet
- [ ] `constitution/invariants.md` carries the three new schema-evolution invariants (relational stores use EF Core Migrations; production migrations run via `migrate.yml` never at app startup; every migration carries a `[Rollback]` attribute and a Tier 2b round-trip test), numbered `{N1}/{N2}/{N3}` under a new `## Schema Evolution Invariants` section, each citing ADR-0048
- [ ] `initiatives/active-initiatives.md` registers the `adr-0048-schema-evolution` initiative with a packet checklist
- [ ] The PR body records the substituted values for `{N1}/{N2}/{N3}` (the actual integers claimed)
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None. The invariant-numbering procedure is fully mechanical: read `constitution/invariant-reservations.md`'s "next free" header, claim a block of 3 starting there, write the reservation row, and substitute `{N1}/{N2}/{N3}` everywhere. Collision handling at merge time is documented in the reservations file itself and is also mechanical.

## Referenced ADR Decisions

**ADR-0048 D1 — EF Core Migrations is the Grid-wide framework.** Azure SQL and Postgres relational stores all use EF Core Migrations; per-Node choice is not allowed. EF migrations carry DDL only; reference-data seeding lives in a separate startup-time path. The choice is justified on stack consistency (.NET + EF), reviewability (C# migration classes reviewed by the same agents that review the rest of the code), and the model-snapshot artifact for round-trip testing.

**ADR-0048 D3 — Migrations run via an out-of-band, operator-triggered `migrate.yml` workflow.** NOT at app startup (`dbContext.Database.Migrate()` is rejected), NOT via init container. The migration PR lands first; the operator triggers `migrate.yml` with `(environment, node)` inputs; the workflow runs `dotnet ef migrations script --idempotent` and applies via `sqlcmd` (Azure SQL) or `psql` (Postgres) using GitHub OIDC; the operator then triggers the dependent code deploy. A failed migration does NOT roll back the app — the app stays on the old code against the old schema.

**ADR-0048 D12 — Test requirements: round-trip test (CI gate) + `[Rollback]` declaration (review block).** Round-trip test in `HoneyDrunk.<Node>.Tests.Integration.Containers/Migrations/<Node>MigrationRoundTripTests.cs` per ADR-0047 D11 Tier 2b. `[Rollback(Strategy = RollbackStrategy.ForwardMigration | NonRollback, Notes/Reason = "...")]` attribute on every migration class.

**ADR-0048 Consequences — Invariants.** ADR-0048 adds exactly three invariants: (1) relational stores use EF Core Migrations; (2) production migrations run via `migrate.yml`, never at app startup or via init container; (3) every migration carries a `[Rollback]` attribute and a Tier 2b round-trip test. Numbers are claimed from `constitution/invariant-reservations.md` at execution time per the Invariant Numbering procedure (today's next free = 54).

## Constraints
- **Acceptance precedes flip.** ADR-0048 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers are claimed at execution time.** Read `constitution/invariant-reservations.md` for the current "next free" number, claim a block of 3 starting there, write the reservation row in the same PR, and substitute `{N1}/{N2}/{N3}` throughout. Do not hardcode numbers; do not renumber existing invariants. Collision handling (another ADR claims the same range first) is documented in the reservations file itself.
- **New section.** The three schema-evolution invariants are a new cross-cutting topic; create a `## Schema Evolution Invariants` section rather than appending to an unrelated section.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0048`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0048 to Accepted, add the three schema-evolution invariants to `constitution/invariants.md`, and register the schema-evolution initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0048 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0048 Data Schema Evolution and Migration Policy rollout, Wave 1.
- ADRs: ADR-0048 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0048 stays Proposed until this PR merges.
- Claim invariant numbers from `constitution/invariant-reservations.md` per the procedure in Invariant Numbering — block of 3 starting at the current "next free" (today: 54). Add the reservation row in the same PR. Substitute `{N1}/{N2}/{N3}` throughout. Do not renumber existing invariants. Collision handling is documented in the reservations file.

**Key Files:**
- `adrs/ADR-0048-data-schema-evolution-and-migration-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
