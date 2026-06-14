---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Data
labels: ["chore", "tier-3", "core", "docs", "adr-0072", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0072"]
wave: 2
initiative: adr-0072-data-access-stance
node: honeydrunk-data
---

# Ratify EF Core as the implementation behind HoneyDrunk.Data — README + CHANGELOG citations of ADR-0072

## Summary
Update the Data repo's own README and CHANGELOG to formally cite ADR-0072 as the governing ADR for the EF Core implementation behind `IRepository<T>` / `IUnitOfWork`. The implementation already exists in `HoneyDrunk.Data.EntityFramework`; this packet ratifies it explicitly in the repo's documentation so future maintainers (and AI agents) can trace the ORM commitment back to the governing ADR. No code change; docs-only.

## Context
ADR-0072's Follow-up Work names: "`HoneyDrunk.Data` ratifies EF Core as the implementation behind `IRepository<T>` / `IUnitOfWork`. Existing implementations align (or already align) with this ADR."

The `HoneyDrunk.Data` repo carries multiple packages:

- **`HoneyDrunk.Data.Abstractions`** — repository, unit-of-work, tenant contracts. The contract surface.
- **`HoneyDrunk.Data`** — provider-neutral orchestration.
- **`HoneyDrunk.Data.EntityFramework`** — EF Core repository + unit-of-work implementation. The committed default per ADR-0072 D1.
- **`HoneyDrunk.Data.SqlServer`** — SQL Server specialization (an EF Core provider package).
- **`HoneyDrunk.Data.Migrations`** — schema deployment standard support.
- **`HoneyDrunk.Data.Outbox`** / **`HoneyDrunk.Data.Outbox.Dispatcher`** — outbox pattern.

The repo's current README (at `HoneyDrunk.Data/README.md`) and per-package READMEs do not yet cite ADR-0072 by ID. This packet adds the citations so the EF Core commitment is discoverable from the repo's documentation surface.

**Why docs-only and not a code change.** The committed implementation (EF Core via `HoneyDrunk.Data.EntityFramework`) already exists. ADR-0072 ratifies the existing implementation rather than introducing a new one. The code change ADR-0072 implies — explicitly applying the per-Node DbContext composition, the connection-strings-from-Vault discipline, the query-discipline patterns (`AsNoTracking()` / projections / `Include` / lazy off) — happens **per consuming Node**, not in the `HoneyDrunk.Data` substrate Node itself. The substrate Node ships the abstractions and the EF Core provider; consumers compose against them.

**Per-package CHANGELOG entries vs repo-level CHANGELOG.** Per invariant 12, per-package CHANGELOG entries are added only for packages with actual functional changes. This packet is **citation-only docs work**:

- `HoneyDrunk.Data.Abstractions/README.md` — citation added (no functional change).
- `HoneyDrunk.Data.EntityFramework/README.md` — citation added (no functional change). This is the package where the EF Core implementation lives; the citation is the most load-bearing one.
- `HoneyDrunk.Data/README.md` — repo-level README, citation added.

Per-package CHANGELOG entries are warranted **only if the README citation counts as a functional change** worth recording. A pure ADR citation in a README is not a functional change per invariant 12's intent. Repo-level CHANGELOG entry **is warranted** as a record of the ratification — a single repo-level entry recording "ADR-0072 ratified; EF Core formally committed as the implementation behind `IRepository<T>` / `IUnitOfWork`." See the Scope section for the exact placement.

**No version bump.** Per invariants 12/27, no version bump for docs alone. The ADR-0072 citation does not change any public API surface, does not add a feature, does not fix a bug. If a Data release is already in flight for other reasons when this packet executes, the doc rides along; otherwise the doc lands without a version bump.

**No `Thread.Sleep` discipline check** (packet has no test code).

This is a docs/ratification packet in the Data repo. No code, no schema, no migration.

## Scope
- `HoneyDrunk.Data/README.md` — repo-level README, add an "ORM Commitment" section citing ADR-0072 (mirroring the section added to `repos/HoneyDrunk.Data/overview.md` in packet 03, adapted for the repo's own README format).
- `HoneyDrunk.Data.Abstractions/README.md` — add a one-paragraph note citing ADR-0072 as the governing ORM-stance ADR for consumers of `IRepository<T>` / `IUnitOfWork`.
- `HoneyDrunk.Data.EntityFramework/README.md` — add a one-paragraph note citing ADR-0072 as the governing ADR ratifying this package as the default implementation behind the abstractions.
- `HoneyDrunk.Data/CHANGELOG.md` (repo-level) — add a single ratification entry citing ADR-0072. No version bump.
- No edit to any `.cs`, `.csproj`, migration, or other code artifact.
- No edit to per-package CHANGELOG files (no functional change at the package level per invariant 12).
- **Confirm at execution time** whether a release is in flight in this repo. If yes, the docs ride along with the release's version bump. If no, the docs land without a bump (per invariant 12/27 — no bump for docs alone).

## Proposed Implementation

### 1. Update `HoneyDrunk.Data/README.md`

Read the current repo-level README to understand its structure. Add a new section titled **"ORM Commitment"** (or "Data-Access Stance" — match the file's existing section style). Content:

```markdown
## ORM Commitment

Per [ADR-0072 (Data Access Stance)](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md), `HoneyDrunk.Data` ratifies **Entity Framework Core** as the implementation behind the `IRepository<T>` and `IUnitOfWork` contracts in `HoneyDrunk.Data.Abstractions`. The implementation lives in `HoneyDrunk.Data.EntityFramework`.

**EF Core current LTS** tracks the .NET LTS cadence. Provider packages: `HoneyDrunk.Data.SqlServer` for SQL Server/Azure SQL backings. A future `HoneyDrunk.Data.Npgsql` requires a provider-specific schema-deployment ADR amendment or follow-up decision before adoption.

**Dapper is the scoped exception** for hot-path read queries where EF generates poor SQL or where allocation matters. Per-Node, per-query. Mandatory evidence in the PR (EF query, Dapper query, benchmarks, workload context). Writes go through EF Core's DbContext — Dapper-write paths are not permitted.

**Schema deployment standard is SQL project/DACPAC deployment** per [ADR-0048 (Schema Evolution)](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0048-data-schema-evolution-and-migration-policy.md). The per-Node `HoneyDrunk.<Node>.Database/` folder hosts schema-changing SQL project files; the canonical database deploy workflow is the `database-deploy-dacpac.yml` workflow in `HoneyDrunk.Actions`.

**Per-Node DbContext.** Each consuming Node owns its own `DbContext`. Sharing across Nodes is forbidden. Connection strings come from Vault via `ISecretStore` per [ADR-0005 (Configuration and Secrets)](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0005-configuration-and-secrets-strategy.md).

**Query discipline:** `AsNoTracking()` on read-only queries; projections preferred for column-subset reads; `Include` is explicit and lazy loading is off; N+1 queries are caught at review; raw SQL via `FromSqlRaw` is parameterized — never string-interpolated. See ADR-0072 D5.

**Testing discipline:** in-memory provider (`Microsoft.EntityFrameworkCore.InMemory`) for fast unit tests per [ADR-0047 (Testing Patterns)](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0047-testing-patterns-and-tooling.md) D2; Testcontainers (Tier 2b) for integration tests where the actual SQL provider's behavior matters. Dapper code is tested via Testcontainers — the in-memory provider does not apply.

**Migration path away from EF Core** (per ADR-0072 D7) is bounded by the `IRepository<T>` / `IUnitOfWork` abstraction. Consumers depend on the contracts, not on `DbContext` directly. If EF Core's trajectory ever turns hostile, the migration path is per-Node mechanical rewriting of `HoneyDrunk.Data.EntityFramework` against a different ORM; the contract surface stays stable.
```

Place the new section in a logical position in the README — likely after the introduction/purpose section and before the package-by-package documentation. Match the file's existing heading hierarchy.

### 2. Update `HoneyDrunk.Data.Abstractions/README.md`

Add a brief paragraph near the top of the file (before any contract reference documentation):

```markdown
## ORM Stance

This package defines the **provider-neutral contracts** (`IRepository<T>`, `IUnitOfWork`, tenant contracts) that consuming Nodes compose against. Per [ADR-0072 (Data Access Stance)](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md), the default implementation behind these contracts is **Entity Framework Core**, shipped in the sibling package `HoneyDrunk.Data.EntityFramework`. Consumers depend on the contracts here, not on `DbContext` directly — this preserves the migration-path-away option per ADR-0072 D7 (swapping the EF Core implementation to a different ORM is a per-Node mechanical move with stable contract surface).

**Dapper is the scoped exception** for hot-path read queries per ADR-0072 D2 — adopted per Node, per query, with mandatory evidence in the introducing PR.
```

### 3. Update `HoneyDrunk.Data.EntityFramework/README.md`

Add a brief paragraph near the top of the file (this is the load-bearing citation — `HoneyDrunk.Data.EntityFramework` is the package ADR-0072 D1 ratifies):

```markdown
## ADR-0072 Ratification

This package is the **default EF Core implementation** behind `IRepository<T>` and `IUnitOfWork` in `HoneyDrunk.Data.Abstractions`, ratified by [ADR-0072 (Data Access Stance)](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md) D1. EF Core is the Grid's default ORM for every Node touching a relational store; this package provides the implementation. Consumers compose against the contracts in `HoneyDrunk.Data.Abstractions`, not against `DbContext` directly.

**Provider packages** (the EF Core providers) ride this implementation:
- `HoneyDrunk.Data.SqlServer` — SQL Server backings via `Microsoft.EntityFrameworkCore.SqlServer`.
- (future) `HoneyDrunk.Data.Npgsql` — PostgreSQL backings via `Microsoft.EntityFrameworkCore.Npgsql`, only after a provider-specific schema-deployment ADR amendment or follow-up decision.

**SQL project/DACPAC deployment** is the schema deployment standard per [ADR-0048 (Schema Evolution)](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0048-data-schema-evolution-and-migration-policy.md). The physical schema source lives in the consuming Node's `HoneyDrunk.<Node>.Database/` folder; the canonical database deploy workflow is the `database-deploy-dacpac.yml` workflow in `HoneyDrunk.Actions`.
```

### 4. Update `HoneyDrunk.Data/CHANGELOG.md`

The repo-level CHANGELOG records the ratification. Per the user-memory note "No commits under CHANGELOG Unreleased — move to dated versioned section + SemVer bump before committing," this packet handles the entry as follows:

- **If a release is in flight** (a dated versioned section is being prepared for a new patch/minor/major), append a one-line entry under that section: `- Ratified EF Core as the implementation behind `IRepository<T>` / `IUnitOfWork` per [ADR-0072](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture/blob/main/adrs/ADR-0072-data-access-stance-ef-core-default-dapper-hot-path.md). Docs-only; no API change.`
- **If no release is in flight** (the docs land standalone), the entry goes in a new dated section with a patch bump. Per invariants 12/27, **docs-only changes do not warrant a version bump on their own**. However, the user-memory rule "No commits under CHANGELOG Unreleased" forces a choice:
  - Option (a) — **defer the CHANGELOG entry** until the next release-in-flight, and ship the README citations alone without a CHANGELOG line. This is the cleanest path; the README citations are self-contained and the CHANGELOG line rides the next release.
  - Option (b) — **bump patch + new dated section** for the docs entry. Bumps every non-test `.csproj` per invariant 27. Acceptable but over-engineered for citation-only docs work.

**Default: Option (a)** — README citations land without a CHANGELOG entry; the executor adds the CHANGELOG line during the next Data release that does require a version bump. Record this choice in the PR body. If the operator prefers Option (b), the PR includes the version bump and CHANGELOG entry; the executor records the reason.

### 5. Do not edit per-package CHANGELOGs

Per invariant 12 ("per-package CHANGELOG only for packages with functional changes"), this packet does not add per-package CHANGELOG entries. The README citations in `HoneyDrunk.Data.Abstractions/README.md` and `HoneyDrunk.Data.EntityFramework/README.md` are pure documentation; no functional change in any package's behavior. No per-package CHANGELOG.

### 6. Do not bump versions

Per invariants 12/27, no version bump for docs alone. Confirm at execution time whether a release is in flight; if yes, the docs ride along with that release's bump; if no, no bump.

## Affected Files
- `HoneyDrunk.Data/README.md` — repo-level README, new "ORM Commitment" section.
- `HoneyDrunk.Data.Abstractions/README.md` — new "ORM Stance" paragraph.
- `HoneyDrunk.Data.EntityFramework/README.md` — new "ADR-0072 Ratification" paragraph.
- `HoneyDrunk.Data/CHANGELOG.md` — conditional ratification entry per Step 4 above.

## NuGet Dependencies
None. This packet touches only Markdown documentation files; no .NET project file (`.csproj`), no `PackageReference`, no NuGet metadata change.

## Boundary Check
- [x] All edits in `HoneyDrunk.Data`. Routing rule "data, repository, persistence, EF Core, SQL Server, outbox → HoneyDrunk.Data" maps exactly.
- [x] No code change.
- [x] No `relationships.json` edge change (the Data Node's outgoing/incoming edges are unchanged).
- [x] No `contracts.json` interface change.

## Acceptance Criteria
- [ ] `HoneyDrunk.Data/README.md` carries an "ORM Commitment" (or equivalent) section citing ADR-0072 with the full content named in Proposed Implementation Step 1 — EF Core default, Dapper scoped exception, SQL project/DACPAC deployment, per-Node DbContext, query discipline, testing discipline, migration-path-away mechanism
- [ ] `HoneyDrunk.Data.Abstractions/README.md` carries an "ORM Stance" paragraph citing ADR-0072 D1/D7
- [ ] `HoneyDrunk.Data.EntityFramework/README.md` carries an "ADR-0072 Ratification" paragraph naming this package as the default implementation per ADR-0072 D1
- [ ] The CHANGELOG entry decision is recorded in the PR body (Option (a) = defer to next release; Option (b) = bump patch with new dated section); default is Option (a)
- [ ] If Option (b) is chosen, every non-test `.csproj` in the Data solution is at the same new patch version per invariant 27
- [ ] No per-package CHANGELOG entries added (no functional change per invariant 12)
- [ ] No code change in any `.cs` file
- [ ] No `.csproj` change unless Option (b) version bump
- [ ] No migration added
- [ ] All ADR-0072 D-decisions referenced in the docs are inlined with full text or linked to the ADR, not just cited by number
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0072 D1 — EF Core as the default ORM.** Every Node touching a relational store uses EF Core. `HoneyDrunk.Data.EntityFramework` is the ratified default implementation behind `IRepository<T>` / `IUnitOfWork`. `HoneyDrunk.Data.SqlServer` is the v1 provider package; future `HoneyDrunk.Data.Npgsql` requires a provider-specific schema-deployment decision.

**ADR-0072 D2 — Dapper as the scoped exception.** Per-Node, per-query. Read paths only. Mandatory evidence in the PR.

**ADR-0072 D4 — Per-Node DbContext.** Each consuming Node owns its own DbContext. The `HoneyDrunk.Data` substrate ships the abstractions and the EF Core provider; consumers compose against them. Connection strings come from Vault per ADR-0005.

**ADR-0072 D5 — Query discipline.** `AsNoTracking()` / projections / explicit `Include` / lazy off / parameterized raw SQL.

**ADR-0072 D6 — Testing discipline.** In-memory provider for unit; Testcontainers for integration.

**ADR-0072 D7 — Migration path away from EF Core is bounded.** Consumers depend on `IRepository<T>` / `IUnitOfWork` — swapping the EF Core implementation to a different ORM is a per-Node mechanical move with stable contract surface. SQL projects keep the production schema independently described, so the runtime ORM can change without moving the DACPAC deployment path.

**ADR-0048 (referenced) — SQL project/DACPAC deployment as the schema deployment standard.** The per-Node `HoneyDrunk.<Node>.Database/` folder; the `database-deploy-dacpac.yml` workflow in `HoneyDrunk.Actions`.

**ADR-0005 (referenced) — Connection strings come from Vault.** Per-Node connection strings live in the Node's Vault namespace and are resolved through `ISecretStore`.

**ADR-0047 (referenced) — Testing patterns.** In-memory provider per D2; Testcontainers per D4 (Tier 2b).

**Invariant 12 (referenced) — Per-package CHANGELOG only for packages with functional changes.** No per-package CHANGELOG entries in this packet; the README citations are pure documentation.

**Invariant 27 (referenced) — One version across the solution.** If Option (b) is chosen for the CHANGELOG entry, every non-test `.csproj` bumps to the same new patch version in one commit.

## Constraints
- **Docs only.** No code change in `.cs` files. No `.csproj` change unless Option (b) version bump. No migration added.
- **No per-package CHANGELOG entries.** Per invariant 12, citation-only README changes are not functional changes; per-package CHANGELOGs unchanged.
- **No version bump for docs alone.** Per invariants 12/27. Confirm at execution time whether a release is in flight; if not, default to Option (a) — defer the CHANGELOG line to the next release.
- **Inline ADR-0072 D-decisions.** Per the self-containment rule, cite full text in the README content or link to the ADR; not just decision numbers.
- **Match the existing README styling.** Heading hierarchy, link format, code block format — match the file's established conventions.
- **No `Thread.Sleep` discipline check applies** — this packet has no test code.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0072`, `wave-2`

## Agent Handoff

**Objective:** Update the Data repo's README files and (conditionally) the repo-level CHANGELOG to cite ADR-0072 as the governing ADR for the EF Core implementation behind `IRepository<T>` / `IUnitOfWork`. No code change.

**Target:** `HoneyDrunk.Data`, branch from `main`.

**Context:**
- Goal: Land the ADR-0072 ratification in the Data repo's own documentation surface, so the EF Core commitment is discoverable from the repo's READMEs.
- Feature: ADR-0072 Data Access Stance rollout, Wave 2.
- ADRs: ADR-0072 D1/D2/D4/D5/D6/D7 (primary), ADR-0048 (SQL project/DACPAC deployment), ADR-0005 (connection strings from Vault), ADR-0047 (testing patterns).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0072 must be Accepted so the README citations reference its decisions as live rules.

**Constraints:**
- Docs only — no `.cs` change, no `.csproj` change (unless Option (b) version bump), no migration.
- No per-package CHANGELOG entries (no functional change per invariant 12).
- No version bump for docs alone (default Option (a) — defer CHANGELOG line to next release).
- Inline ADR-0072 D-decisions as full text or link to the ADR.
- Match existing README styling.

**Key Files:**
- `HoneyDrunk.Data/README.md` (repo-level, new ORM Commitment section).
- `HoneyDrunk.Data.Abstractions/README.md` (new ORM Stance paragraph).
- `HoneyDrunk.Data.EntityFramework/README.md` (new ADR-0072 Ratification paragraph).
- `HoneyDrunk.Data/CHANGELOG.md` (conditional ratification entry — default Option (a) defers).

**Contracts:** None changed.
