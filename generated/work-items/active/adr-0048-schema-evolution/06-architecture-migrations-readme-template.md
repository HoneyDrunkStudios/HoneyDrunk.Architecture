---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "core", "docs", "adr-0048", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0048"]
wave: 3
initiative: adr-0048-schema-evolution
node: honeydrunk-architecture
---

# Author the per-Node SQL project README template

## Summary
Author a canonical README template for Node-owned `HoneyDrunk.<Node>.Database` SQL Server database projects. Architecture owns the template; each Node repo owns its actual `.sqlproj`, schema files, DACPAC build source, and project README.

## Context
ADR-0048 D1/D11 standardizes production SQL Server schema deployment on SQL projects and DACPACs. The SQL project lives with the Node because the Node owns the schema and release cadence. HoneyDrunk.Actions owns only the reusable deployment workflow.

## Scope
- Add a template file in Architecture, suggested path: `templates/per-node/SqlProject-README.md`.
- Add a pointer from the appropriate Architecture index if one exists.
- Do not edit any Node repo in this packet.

## Template Sections
The template should include:

- `# HoneyDrunk.<Node>.Database`
- Ownership: Node-owned SQL project; Architecture owns only the template; Actions owns deployment plumbing.
- Framework: SQL Server database project producing a DACPAC; EF Core is runtime ORM only.
- File layout:
  - `HoneyDrunk.<Node>.Database.sqlproj`
  - `Schemas/<schema>.sql`
  - `Tables/<schema>.<Table>.sql`
  - optional `Scripts/PreDeployment.sql`
  - optional `Scripts/PostDeployment.sql`
  - optional `Backfill/<YYYYMMDD>-<description>.md`
  - `README.md`
- Naming conventions:
  - product tables use unprefixed names inside a bounded-context schema
  - every product table has an `Id` primary key
  - public/business identifiers are alternate unique columns where needed
- Expand -> migrate code -> contract notes:
  - `SchemaPhase`
  - `SchemaChangeId`
  - paired Expand/Contract references
  - backward-compatibility window
- Rollback declaration:
  - `RollbackStrategy: ForwardSchemaChange`
  - `RollbackStrategy: NonRollback`
- Online DDL caveats for Azure SQL tables at or above the ADR-0048 row threshold.
- Audit-specific constraints for Audit-owned SQL projects.
- Schema-on-read notes for document-store pieces, including `Backfill/` runbooks.
- Running deployments:
  - build the Node SQL project
  - publish DACPAC through `HoneyDrunk.Actions/.github/workflows/database-deploy-dacpac.yml`
  - deploy before dependent app code
  - never run schema deployment at app startup or init container
- Failure recovery:
  - forward-only by default
  - use DACPAC publish artifacts and the Node `dr-runbook.md` Schema Deployment Failure section
- Tests:
  - `HoneyDrunk.<Node>.Tests.Integration.Containers/Database/<Node>DatabaseRoundTripTests.cs`
  - publish DACPAC to Testcontainers SQL Server
  - assert EF model/SQL project contract alignment
  - insert/read representative data

## Acceptance Criteria
- [ ] Template exists at a discoverable Architecture path
- [ ] Template says Node repos own `.sqlproj`, schema files, and DACPAC source
- [ ] Template says HoneyDrunk.Actions owns reusable deployment plumbing only
- [ ] Template includes SQL project file layout and naming conventions from ADR-0048 D11
- [ ] Template includes PR-body schema metadata: `SchemaPhase`, `SchemaChangeId`, and `RollbackStrategy`
- [ ] Template points deployments to `database-deploy-dacpac.yml`
- [ ] Template points tests to a DACPAC round-trip test under `Tests.Integration.Containers/Database`
- [ ] No EF migration runner, migration class, `[Rollback]` attribute, or `dotnet ef migrations script` workflow is introduced

## Referenced ADR Decisions
**ADR-0048 D1/D11** — SQL Server database projects and DACPACs are the production schema deployment standard for SQL Server-backed Nodes.

**ADR-0048 D3/D10** — deployments are out-of-band and forward-only by default.

**ADR-0048 D12** — schema-changing PRs carry rollback metadata and DACPAC round-trip tests.
