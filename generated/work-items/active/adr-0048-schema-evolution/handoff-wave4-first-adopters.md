# Handoff — ADR-0048 Wave 4 First Adopters

ADR-0048 now uses SQL Server database projects and DACPAC deployments for SQL Server-backed relational stores. Node repos own their SQL projects and schema files; HoneyDrunk.Actions owns only the reusable `database-deploy-dacpac.yml` deployment workflow.

## Current Scope

- Packet 05: `HoneyDrunk.Actions` adds the reusable DACPAC deploy workflow.
- Packet 06: `HoneyDrunk.Architecture` adds the SQL project README template.
- Packet 08: `HoneyDrunk.Kernel` documents the idempotency-store schema-on-read shape under `Schema/README.md`.

## Superseded Work

- Packet 07, Notify retroactive EF migration annotation, is superseded. Notify should adopt ADR-0048 through a Node-owned `HoneyDrunk.Notify.Database` SQL project packet when Notify needs durable SQL schema deployment.
- Packet 09, Standards rollback attribute, is superseded. Rollback posture is PR-body `RollbackStrategy` metadata, not a shared C# attribute.

## Execution Notes

- Do not introduce `dotnet ef migrations script`, EF migration classes, `[Rollback]` attributes, or startup-time `Database.Migrate()` as production schema deployment paths.
- Schema-changing SQL project PRs declare `SchemaPhase`, `SchemaChangeId`, and `RollbackStrategy` in the PR body.
- SQL Server-backed Nodes add DACPAC round-trip tests under `Tests.Integration.Containers/Database`.
- Document-store backfills live under `Schema/Backfill/` or the Node-owned SQL project `Backfill/` folder, depending on the owning package.
