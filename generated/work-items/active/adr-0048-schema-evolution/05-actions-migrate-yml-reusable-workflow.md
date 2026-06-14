---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "actions", "database", "dacpac", "adr-0048", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0048", "ADR-0015", "ADR-0033", "ADR-0005"]
wave: 3
initiative: adr-0048-schema-evolution
node: honeydrunk-actions
---

# Author the DACPAC database deploy reusable workflow

## Summary
Author `database-deploy-dacpac.yml`, the reusable GitHub Actions workflow ADR-0048 D3/D11 commits for production schema deployment. The workflow builds a Node SQL Server database project, publishes the DACPAC artifact, generates a publish script/report, deploys to Azure SQL using the Grid OIDC credential model, and retains deployment artifacts for review and incident forensics.

## Context
ADR-0048 rejects startup-time `Database.Migrate()` and init-container schema changes. Production schema deployment is a separate, operator-triggered workflow that runs before the dependent code deploy.

The workflow deploys SQL Server database projects, not EF Core migrations. EF Core remains the runtime ORM per ADR-0072; the SQL project is the physical schema source of truth.

## Scope
- `.github/workflows/database-deploy-dacpac.yml` in `HoneyDrunk.Actions`.
- Optional supporting scripts/composite-action updates if the Actions repo convention already centralizes Azure SQL publish behavior.
- CHANGELOG update if `HoneyDrunk.Actions` requires one for workflow additions.

## Proposed Implementation
1. Add a reusable workflow with `workflow_call` inputs:
   - `node`: logical Node name, for logs and artifact naming.
   - `environment`: `dev`, `staging`, or `prod`.
   - `sql_project_path`: path to `HoneyDrunk.<Node>.Database.sqlproj`.
   - Optional `database_name`, `sql_server_name`, and publish profile overrides when a consumer repo needs them.
2. Use GitHub Environment protection rules for the selected environment. `staging` and `prod` remain protected per ADR-0033; `dev` can be unprotected.
3. Check out the consumer repo at the requested SHA.
4. Build the SQL project and produce a DACPAC artifact.
5. Resolve the Azure SQL target and credentials through the existing OIDC/Vault posture from ADR-0005/ADR-0015.
6. Generate the DACPAC publish script/report before applying changes.
7. Publish the DACPAC to Azure SQL.
8. Upload the DACPAC, publish script/report, and deployment output as workflow artifacts.
9. On failure, surface the failing publish step, partial-application state if available, artifact links, and the Node runbook location for Schema Deployment Failure handling.

## Acceptance Criteria
- [ ] Workflow file exists and is named `database-deploy-dacpac.yml`
- [ ] Workflow builds a supplied SQL project and uploads the DACPAC before deployment
- [ ] Workflow generates and uploads a publish script/report before applying the change
- [ ] Workflow publishes the DACPAC to Azure SQL through the Grid OIDC/Vault credential model
- [ ] Workflow is callable by consumer repos and can be operator-triggered through a consumer-side dispatch workflow
- [ ] `staging` and `prod` use GitHub Environment protection
- [ ] Failure output includes enough detail for ADR-0048 D10 Schema Deployment Failure triage
- [ ] No `dotnet ef database update`, `dotnet ef migrations script`, `Database.Migrate()`, or app-startup migration path is introduced

## Referenced ADR Decisions
**ADR-0048 D1/D3/D11** — SQL Server database projects build DACPACs; production schema deployment runs out-of-band through a deliberate database deploy workflow before dependent code deploys.

**ADR-0048 D10** — rollback is forward-only by default; failed deployments are fixed by a new reviewed SQL project change or a safe rerun after triage.

**ADR-0015** — Azure credentialing uses the Grid OIDC model, and the workflow must remain compatible with multi-revision app deploys.

**ADR-0033** — environment protection rules apply to `staging` and `prod`.
