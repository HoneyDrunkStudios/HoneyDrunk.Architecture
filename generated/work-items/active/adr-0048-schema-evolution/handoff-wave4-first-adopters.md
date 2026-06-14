# Handoff — Wave 4: First Adopters

**Initiative:** `adr-0048-schema-evolution`
**Wave transition:** Wave 3 (workflow + template) → Wave 4 (Notify retroactive annotation + Kernel.Idempotency Phase 2 pilot)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Waves 1–3 landed

- **Packet 00** — ADR-0048 flipped to **Accepted**. Three schema-evolution invariants added to `constitution/invariants.md` under a new `## Schema Evolution Invariants` section, numbered **93, 94, 95** (pre-reserved for ADR-0048 in the 12-ADR batch; current verified max prior to this initiative was 53):
  1. **93** — Relational stores use EF Core Migrations.
  2. **94** — Production migrations run via the `migrate.yml` workflow, never at app startup or via init container.
  3. **95** — Every migration carries a `[Rollback]` attribute and a Tier 2b round-trip test.
- **Packet 01** — `catalogs/grid-health.json` carries a `schema_evolution` field per Node (values: `ef-core-migrations`, `cosmos-schema-on-read`, `n/a`); `_meta.schema_version` bumped to `1.1`. Every existing `repos/{name}/integration-points.md` carries a `## Migration Coordination` section.
- **Packet 02** — `.claude/agents/database.md` exists with the seven-category D13 rubric (D2 conformance, D5 window adequacy, D6 online primitives, D8 Audit constraints, D9 tenant scoping, D10 rollback declaration, D12 tests present, plus EF Core idiom). Severity scale matches ADR-0044 D3 (blocking / strong / advisory). Advisory posture per ADR-0046 D1.
- **Packet 03** — `.claude/agents/review.md` D3 category 13 carries a delegation stanza naming the `database` specialist; surface-level checks preserved; manual invocation at v1 per ADR-0046 D3.
- **Packet 04** — `.claude/agents/scope.md` carries the schema-change pre-flight detector (triggers on `Migrations/`, `Backfill/`, DbContext modifications; six action steps when triggered); both `scope.md` and `review.md` context-loading lists include ADR-0048, the per-Node `integration-points.md` Migration Coordination section, and `catalogs/grid-health.json`'s `schema_evolution` field per invariant 33.
- **Packet 05** — `migrate.yml` reusable workflow exists in `HoneyDrunk.Actions/.github/workflows/`. Inputs `node`, `environment`, `target-migration?`, `db-provider`. `workflow_dispatch`-only via consumer-side caller. Runs `dotnet ef migrations script --idempotent`, applies via `sqlcmd` (Azure SQL) or `psql` (Postgres), retains `migrate.sql` + `__EFMigrationsHistory` snapshot as workflow artifacts. Per-environment-gated via GitHub Environment protection rules per ADR-0033 D7.
- **Packet 06** — The canonical `Migrations/README.md` template exists in `HoneyDrunk.Architecture` (path per repo convention; suggested `templates/per-node/Migrations-README.md`). Sections: Framework, File layout, Naming convention, Expand→Contract phase log, Backward-compatibility window, Online DDL caveats, Audit-specific constraints, Schema-on-read, Running migrations, Failure recovery, Tests, See also. Per-tier windows verbatim per ADR-0048 D5.

ADR-0048's foundation is live. The `database` agent will review Wave-4 PRs; the `migrate.yml` workflow is available for the first consumer caller; the per-Node template is ready to copy.

## What Wave 4 must deliver

Two parallel adopter packets — Notify (relational scaffold annotation) and Kernel.Idempotency (document-store schema-on-read pilot per D14 Phase 2). The packets are independent (different repos, different domains); either may merge first.

### Packet 07 — Notify retroactive scaffold-migration annotation

**Target:** `HoneyDrunk.Notify`. Bumps Notify's solution one patch version.

- Inventory existing scaffold migrations in `src/HoneyDrunk.Notify.Data/Migrations/`.
- Add `[Rollback(Strategy = RollbackStrategy.ForwardMigration, Notes = "...")]` to each migration class.
- If the `RollbackAttribute` type doesn't exist yet at the Grid level, define it minimally inside `HoneyDrunk.Notify.Data` (sealed class, `AttributeUsage(Class)`, `Strategy` + `Notes` + `Reason` properties; `RollbackStrategy` enum with `ForwardMigration` and `NonRollback`). Record the follow-up to consolidate the attribute into a Grid-level home in the PR body.
- Copy the canonical `Migrations/README.md` template from packet 06 into `src/HoneyDrunk.Notify.Data/Migrations/README.md`. Fill in Notify-specific values: Node name, EF Core version, provider, schema-evolution posture (`ef-core-migrations`), backward-compatibility window (14 days per Tier 0/1 customer-facing), scaffold-migration entries in the phase log.
- If `tests/HoneyDrunk.Notify.Tests.Integration.Containers/` exists (per ADR-0047 D11 roll-out), add `Migrations/NotifyMigrationRoundTripTests.cs` applying the scaffold migrations against a Testcontainers backing and asserting schema + data integrity. If the project does not exist, record the deferred test addition in the PR body.
- Per-package `HoneyDrunk.Notify.Data/CHANGELOG.md` entry; repo-level `CHANGELOG.md` entry; every non-test `.csproj` patch-bumped together per invariant 27.

### Packet 08 — Kernel idempotency Cosmos schema-on-read doc

**Target:** `HoneyDrunk.Kernel`. No version bump unless a release is in flight.

- Author `src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md` documenting the dedup-state Cosmos document shape: `id`, `consumerGroup` (partition key), `firstSeenAt`, `state`, `leaseExpiresAt`, `outcome` (with status + small optional payload), `ttl`. Partition key `/consumerGroup` per ADR-0042 D2; TTL ranges 7 days standard / 30 days billing-audit per ADR-0042 D4; 30-day backward-compatibility window per ADR-0048 D5.
- Create `src/HoneyDrunk.Kernel.Abstractions/Migrations/Backfill/.gitkeep` (empty file) so future backfill runbooks have a home.
- No new EF migration. No `[Rollback]` attribute (schema-on-read has no DDL). No code change to `HoneyDrunk.Kernel.Abstractions` or `HoneyDrunk.Kernel`.
- Partition-key changes are flagged as a deferred follow-up ADR per ADR-0048 D7.

**Path-placement note (operator decision before execution).** Default is Kernel.Abstractions (next to the contract); alternative is `HoneyDrunk.Data.Idempotency.Cosmos/Migrations/README.md` (next to the v1 backing). If the operator prefers the alternative, retarget packet 08's `target_repo` to `HoneyDrunk.Data` before execution.

## What does NOT change in Wave 4

- **No new contracts.** The `IIdempotencyStore` interface (ADR-0042 D2) is unchanged. No `relationships.json` edges added.
- **No code change in `HoneyDrunk.Kernel.Abstractions` or `HoneyDrunk.Kernel`.** Packet 08 is docs-only.
- **No new schema in `HoneyDrunk.Notify`.** Packet 07 is annotation-and-docs only; no `dotnet ef migrations add` invocation.
- **No consumer-side caller workflow for `migrate.yml` in Notify in this wave.** Adding a per-environment caller (`.github/workflows/migrate-dev.yml` in the Notify repo) is a Notify-side follow-up when Notify's first real migration lands — not in scope for packet 07.

## Invariants binding Wave 4

- **Invariant 93 (new from packet 00)** — relational stores use EF Core Migrations. Packet 07 is the first packet to land under this invariant; the Notify scaffold migrations are already EF Core Migrations, so compliance is automatic.
- **Invariant 94 (new from packet 00)** — production migrations run via `migrate.yml`, never at app startup. Packet 07 does NOT add a `dbContext.Database.Migrate()` call; packet 05's workflow is the path. The Notify scaffold migrations have never been run against a populated store with traffic on it (per ADR-0048 Context) — the first real Notify migration that runs against a populated dev/staging/prod store will use `migrate.yml`.
- **Invariant 95 (new from packet 00)** — every migration carries a `[Rollback]` attribute and a Tier 2b round-trip test. Packet 07 ships the `[Rollback]` attribute; the round-trip test is conditional on Notify's Tier 2b project existing. Packet 08 (schema-on-read) does NOT require the attribute or the round-trip test — D12 applies to EF migration classes, not schema-on-read docs; the equivalent gate is the ADR-0047 Tier 2a contract test for `IIdempotencyStore` (ADR-0047 packet 12, unparked by ADR-0042 packet 03).
- **Invariant 12 — Per-package CHANGELOG for changed packages only.** Notify packet 07 changes `HoneyDrunk.Notify.Data` (functional change: attribute decorations, possibly new `RollbackAttribute` type); other Notify packages get the alignment bump without per-package CHANGELOG entries.
- **Invariant 27 — One version across the solution.** Notify packet 07 patch-bumps every non-test `.csproj` in the Notify solution together. Kernel packet 08 is docs-only and does not require a version bump.
- **Invariant 33 — Review-agent and scope-agent context-loading symmetry.** Already maintained by packet 04; Wave 4 does not edit either context-loading list, so symmetry holds.
- **Invariant 51 — No `Thread.Sleep` in test code.** New round-trip tests in packet 07 use `TimeProvider` for any time-dependent waits.
- **Invariant 9 — Vault is the only source of secrets.** Packet 07 does not introduce any secret access; packet 08 documents that the Cosmos connection is resolved from injected configuration per ADR-0042 packet 03's implementation. Neither packet adds direct environment-variable reads.

## Acceptance gates for the wave

- **Packet 07** — Notify's `pr-core.yml` tier-1 gate passes. Annotation is present on every existing scaffold migration. The Notify `Migrations/README.md` exists with all sections filled in. Solution is patch-bumped consistently. The `database` agent (packet 02) reviewing the PR finds no D2/D5/D6/D8/D9/D10/D12 violations (the migrations are existing scaffolds, not new schema changes; D10 is the relevant check — `[Rollback]` attribute present and adequate).
- **Packet 08** — Kernel's `pr-core.yml` tier-1 gate passes. The `Migrations/README.md` exists with all eight sections (Framework, Canonical document shape, Partition key, TTL policy, Schema-on-read evolution, Backfill runbooks, Running schema-on-read changes, Tests, See also). The `Backfill/` directory exists (empty, with `.gitkeep`). No new compiled file is added to any `.csproj`.

## Next phases (after this wave)

ADR-0048 D14 Phases 3–6 are out of scope for this initiative. Each adopts the pattern this initiative ships in its own track:
- **Phase 3 (Week 4-6)** — Audit standup adopts the full pattern with D8's append-only-by-interface constraints baked in. Lives in the **ADR-0031 standup track**.
- **Phase 4 (Month 2-3)** — Memory and Knowledge standups consume the pattern. Live in **ADR-0021 / ADR-0022 standup tracks**.
- **Phase 5 (Month 3+)** — Billing standup consumes the pattern with the 30-day window per ADR-0048 D5 matching ADR-0042 D4's billing TTL. Lives in the **ADR-0037 standup track**.
- **Phase 6 (Ongoing)** — Notify Cloud per-tenant data migrations as Notify Cloud GA approaches; the tenant-scoped variant of D9 if and when adopted. Lives in the **ADR-0027 Notify Cloud track**.

Each phase is a discrete go/no-go per ADR-0048 D14. This initiative's exit is Wave 4 packets 07 and 08 merging; subsequent phases land in their own tracks consuming the foundation this initiative shipped.
