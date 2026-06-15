---
title: Reconcile historical ADR-0048 schema-deployment artifacts with DACPAC policy
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
wave: reactive
initiative: adr-0048-schema-evolution
node: honeydrunk-architecture
tier: 2
labels: ["docs", "tier-2", "meta", "adr-0048", "schema-deployment", "reactive"]
dependencies: []
adrs: ["ADR-0048", "ADR-0072", "ADR-0008"]
source: reactive
generator: codex
---

# Reconcile historical ADR-0048 schema-deployment artifacts with DACPAC policy

## Summary

ADR-0048 now commits SQL Server database projects and DACPAC deployment as the
production schema-deployment standard. Several ADR-0048 rollout packets were
filed before that correction and still describe EF migration scripts, rollback
attributes, or migration-runner work.

Do not rewrite those filed packet bodies or read-once handoff artifacts in place.
Reconcile them through issue comments, project-state updates, dispatch-plan notes,
or replacement packets so historical work tracking remains auditable.

## Context

Reactive packet for reconciling PR #631 schema-deployment feedback: already-filed
work items and historical handoff artifacts must remain immutable after
filing/emission, but their GitHub issue state must be made executor-safe before
execution resumes. The affected filed packet paths include:

- `generated/work-items/active/adr-0048-schema-evolution/05-actions-migrate-yml-reusable-workflow.md`
  mapped to HoneyDrunk.Actions issue #124.
- `generated/work-items/active/adr-0048-schema-evolution/07-notify-retroactive-migration-annotation.md`
  mapped to HoneyDrunk.Notify issue #35.
- `generated/work-items/active/adr-0048-schema-evolution/09-standards-rollback-attribute-grid-wide.md`
  mapped to HoneyDrunk.Standards issue #48.
- Other ADR-0048 and ADR-0072 filed packets that mention EF migration mechanics
  remain historical filed scope unless their owning issue is explicitly updated.

The current ADR text and living dispatch plan carry the corrected policy. This
packet exists to reconcile already-filed issue state and historical handoffs
without mutating their original text. This active packet must be filed by
`file-work-items.yml` from `main` before any superseded ADR-0048 or ADR-0072
issue is assigned for execution, unless the owning issue has already received an
explicit supersession comment linking to ADR-0048 D1/D3/D11 and the revised
dispatch plan.

## Scope

- Audit filed ADR-0048 and ADR-0072 issues whose packet bodies mention EF
  migration scripts, EF migration classes, rollback attributes, or startup-time
  schema migration as production paths.
- For issues that are now superseded by the DACPAC policy, update the GitHub
  issue or project state with a comment linking to ADR-0048 and this corrective
  packet, then close or relabel according to the current Hive workflow.
- For work that still needs implementation, file replacement packets that use:
  - Node-owned `HoneyDrunk.<Node>.Database` SQL projects.
  - SQL schema files as the physical schema source of truth.
  - DACPAC build/publish artifacts.
  - `database-deploy-dacpac.yml` reusable deployment plumbing in
    HoneyDrunk.Actions only.
  - PR-body `RollbackStrategy` metadata instead of a shared C# rollback
    attribute.
- Do not edit filed packet bodies or read-once handoff artifacts solely to
  change their historical scope.

## Acceptance Criteria

- Filed packet files mapped in `generated/work-items/filed-work-items.json`
  and historical `handoff-*.md` files are unchanged except for future lifecycle
  moves performed by the standard Hive workflow.
- Superseded ADR-0048 issue state is auditable from GitHub comments or project
  fields, not from rewritten packet text.
- Superseded ADR-0072 issue state is audited the same way if the issue body
  still presents EF migrations as a production schema-deployment path.
- Issues for ADR-0048 packet 05, packet 07, and packet 09 each have a
  supersession comment or are closed/replaced under the standard Hive workflow
  before executor assignment.
- PR #631 posted initial supersession comments on 2026-06-15 to
  HoneyDrunk.Actions#124, HoneyDrunk.Notify#35, and HoneyDrunk.Standards#48.
- The PR #631 supersession comments are tracked at:
  - HoneyDrunk.Actions#124:
    https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/issues/124#issuecomment-4710561956
  - HoneyDrunk.Notify#35:
    https://github.com/HoneyDrunkStudios/HoneyDrunk.Notify/issues/35#issuecomment-4710561966
  - HoneyDrunk.Standards#48:
    https://github.com/HoneyDrunkStudios/HoneyDrunk.Standards/issues/48#issuecomment-4710561974
- This packet is active under ADR-0048 packet 10, so `file-work-items.yml`
  files it from `main` as the machine-followable reconciliation anchor. The
  three issue comments above are the interim executor-visible guardrail until
  that filing workflow creates the Architecture issue.
- Any replacement implementation packet uses SQL project/DACPAC terminology and
  does not introduce `dotnet ef migrations script`, EF migration classes,
  startup-time `Database.Migrate()`, or `[Rollback]` attributes as production
  schema-deployment mechanisms.

## Notes

- Reactive-source packet (ADR-0043 D4): generated from PR #631 Grid Review
  feedback.
- This packet is active by operator direction in PR #631. Filing remains
  automated by `file-work-items.yml` on merge to `main`; do not manually create
  a duplicate Architecture issue unless that workflow fails.
