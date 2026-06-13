---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "core", "ci", "adr-0048", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0048", "ADR-0015", "ADR-0033", "ADR-0005"]
wave: 3
initiative: adr-0048-schema-evolution
node: honeydrunk-actions
---

# Author migrate.yml reusable workflow in HoneyDrunk.Actions

## Summary
Author `migrate.yml` — the new reusable GitHub Actions workflow ADR-0048 D3 and D11 commit. The workflow is operator-triggered (`workflow_dispatch` only), runs `dotnet ef migrations script --idempotent` against a Node's `DbContext` to produce an idempotent SQL script, then applies the script via `sqlcmd` (Azure SQL) or `psql` (Postgres) using the GitHub OIDC credential model from ADR-0015. Resolves connection strings from Vault per ADR-0005. Retains the applied SQL and the post-migration `EFMigrationsHistory` snapshot as workflow artifacts. Protected on `staging`/`prod` via GitHub Environment rules per ADR-0033 D7.

## Context
ADR-0048 D3 names the out-of-band migration workflow as the load-bearing decision that makes the rest of the schema-evolution policy coherent: "Out-of-band migration job, manually triggered, runs before the dependent code deploy — Dedicated `migrate` GitHub Actions workflow per Node; cuts a SQL script from the migration assembly; applies via Azure SQL / Postgres connection; succeeds independently of the app deploy."

ADR-0048 D11 specifies the workflow contract: "**The `migrate.yml` reusable workflow** (new, lands in HoneyDrunk.Actions per the ADR-0012 control-plane invariant):
- Inputs: `node` (the Node name), `environment` (`dev`/`staging`/`prod`), `target-migration` (optional; defaults to "latest").
- Trigger: `workflow_dispatch` only (operator-deliberate per D3).
- Steps:
  1. Check out the consumer repo at the SHA of the latest deployed code for the target environment (per ADR-0033's environment-to-ref mapping). This guarantees the migration assembly matches the running code.
  2. `dotnet ef migrations script --idempotent --output ./migrate.sql` against the Node's `DbContext`.
  3. Resolve the connection string from Vault per ADR-0005 using the Grid's OIDC credential model per ADR-0015.
  4. Apply via `sqlcmd` (Azure SQL) or `psql` (Postgres) wrapped in a transaction where the provider supports it.
  5. On success: upload `migrate.sql` and a post-migration `EFMigrationsHistory` snapshot as workflow artifacts.
  6. On failure: surface the offending DDL statement, the partial-application state of `EFMigrationsHistory`, and the operator-runbook link from D10.
The workflow is per-environment-gated using GitHub Environment protection rules (per ADR-0033 D7's posture: `staging`/`prod` are protected, `dev` is not)."

`HoneyDrunk.Actions` is the Grid's CI/CD control plane per ADR-0012 — all reusable workflows live here. The existing reusable workflows for deploy (`job-deploy-container-app.yml` per ADR-0015) are unchanged; `migrate.yml` is a **sibling** workflow operator-triggered before the dependent code deploy.

`HoneyDrunk.Actions` is not a versioned .NET solution; the change is a YAML workflow file plus any supporting composite actions if needed. CHANGELOG updated per the repo convention if it keeps one (most Actions repos do).

This is a workflow-authoring packet. Not a .NET project; no NuGet dependencies on the Actions side.

## Scope
- `.github/workflows/migrate.yml` (or per the repo's reusable-workflow directory convention — confirm at edit time; the existing reusable workflows in `.github/workflows/` like `job-deploy-container-app.yml` are the structural template).
- Supporting composite actions if needed (e.g. an action to resolve the consumer repo's deployed SHA per ADR-0033 — reuse the existing checkout-actions-repo or environment-resolution action if one exists; otherwise add a small composite action under `.github/actions/`).
- `CHANGELOG.md` for the Actions repo if the repo keeps one.

## Proposed Implementation

### 1. Workflow file structure (`migrate.yml`)

The workflow is a **reusable workflow** (`workflow_call`), triggered by an Actions caller in the consumer Node's repo. The consumer-side caller is a thin shim — operator runs `workflow_dispatch` on a per-Node caller workflow, which calls `migrate.yml`. This matches the existing pattern for `job-deploy-container-app.yml`.

```yaml
name: Migrate Node Schema

on:
  workflow_call:
    inputs:
      node:
        description: "Node name (matches catalogs/nodes.json id, e.g. honeydrunk-notify)"
        required: true
        type: string
      environment:
        description: "Target environment: dev, staging, or prod"
        required: true
        type: string
      target-migration:
        description: "Optional target migration name; defaults to latest"
        required: false
        type: string
        default: ""
      db-provider:
        description: "Database provider: azure-sql or postgres"
        required: true
        type: string
    secrets:
      AZURE_CLIENT_ID:
        required: true
      AZURE_TENANT_ID:
        required: true
      AZURE_SUBSCRIPTION_ID:
        required: true
```

**Environment-gating.** Set `environment: ${{ inputs.environment }}` at the job level so the `staging` and `prod` environments' protection rules apply per ADR-0033 D7. `dev` is unprotected; `staging`/`prod` require operator approval before the job starts.

### 2. Workflow steps

1. **Checkout the consumer repo at the deployed-code SHA.** Use the existing pattern from the deploy workflows: resolve the SHA from the environment's last successful deploy (per ADR-0033's environment-to-ref mapping). If a composite action exists for this (`actions/resolve-deployed-sha` or similar), reuse it; if not, add one.

2. **Set up .NET.** Use the existing `actions/dotnet/setup` composite action (path: `.github/actions/dotnet/setup/action.yml`).

3. **Authenticate to Azure via OIDC.** Use the existing OIDC login pattern from the deploy workflows. The Managed Identity must have:
   - `Key Vault Secrets User` on the per-Node Key Vault (to read the connection string).
   - Database-data-plane RBAC on the target store (`SQL DB Contributor`-equivalent on Azure SQL, or the Postgres-flexible-server-data-plane-equivalent).

4. **Resolve the connection string from Vault.** Read the per-Node Key Vault for a secret named (by convention) `db-connection-string-{environment}` or per the Node's existing convention. Reuse the existing `azure/keyvault-fetch` composite action.

5. **Run `dotnet ef migrations script --idempotent`.**
   ```bash
   dotnet ef migrations script \
     --idempotent \
     --project src/HoneyDrunk.<Node>.Data/HoneyDrunk.<Node>.Data.csproj \
     --startup-project src/HoneyDrunk.<Node>/HoneyDrunk.<Node>.csproj \
     --output ./migrate.sql \
     ${{ inputs.target-migration && format('--to {0}', inputs.target-migration) || '' }}
   ```
   - The `--idempotent` flag is **mandatory** (ADR-0048 D11 and the rollback/resumability discussion in D10). It produces a script that is safe to re-run after partial failure.
   - The project path is per-Node convention (`src/HoneyDrunk.<Node>.Data/`) — pass the `node` input value into the path. Use a simple parameter expansion or a small composite action that maps `node` → project path.
   - Upload `migrate.sql` as a build artifact **before** applying it. This guarantees the artifact exists even if the apply step fails.

6. **Apply the script.** Branch on `db-provider`:

   - **`azure-sql`**:
     ```bash
     sqlcmd -S "$server" -d "$database" -U "$username" -P "$password" -i ./migrate.sql -b
     ```
     - The `-b` flag tells `sqlcmd` to exit on the first error.
     - For Azure AD/Managed Identity auth (preferred per invariant 9 — no raw passwords), use the `-G` flag with `--authentication-method=ActiveDirectoryDefault` (recent `sqlcmd` versions support this). If the version available in the runner doesn't support AD-default, fall back to a connection-string approach where the connection string itself uses `Authentication=Active Directory Default;`.

   - **`postgres`**:
     ```bash
     psql "$connection_string" -v ON_ERROR_STOP=1 -f ./migrate.sql
     ```
     - `ON_ERROR_STOP=1` ensures the script halts on the first error (Postgres supports transactional DDL; the `--idempotent` script will wrap DDL in a transaction where possible, so partial application rolls back per ADR-0048 D10).
     - Postgres Managed Identity auth: the connection string includes the Azure AD token retrieved via OIDC (the `az account get-access-token --resource-type oss-rdbms` pattern).

7. **Snapshot `EFMigrationsHistory` post-apply.**
   ```bash
   # Azure SQL
   sqlcmd -S "$server" -d "$database" -G -q "SELECT * FROM [__EFMigrationsHistory]" -o ./migrations-history.txt
   # Postgres
   psql "$connection_string" -c 'SELECT * FROM "__EFMigrationsHistory"' -o ./migrations-history.txt
   ```
   Upload `migrations-history.txt` as a build artifact alongside `migrate.sql`.

8. **On failure: capture diagnostics.** Use `if: failure()` step to:
   - Capture stderr from `sqlcmd`/`psql` (already in the logs, but extract the offending DDL statement and the line number).
   - Snapshot `__EFMigrationsHistory` to see partial-apply state.
   - Upload both as artifacts.
   - Print a runbook reference (D10 step 6 names `repos/{node}/dr-runbook.md` for the Node-specific failure recovery; the workflow surfaces a link to that file in the consumer repo).

### 3. Caller-side documentation

Add a short README section under `.github/workflows/` (or the repo's reusable-workflow docs surface) documenting the caller-side pattern:

```yaml
# Consumer repo's .github/workflows/migrate-dev.yml
name: Migrate Dev

on:
  workflow_dispatch:

jobs:
  migrate:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/migrate.yml@main
    with:
      node: honeydrunk-notify
      environment: dev
      db-provider: azure-sql
    secrets: inherit
```

The consumer maintains one such caller per environment; `dev` is unprotected, `staging`/`prod` require operator approval.

### 4. CHANGELOG and docs

Update the Actions repo's CHANGELOG (if it keeps one) with an entry for the new `migrate.yml` reusable workflow.

## Affected Files
- `.github/workflows/migrate.yml` — new reusable workflow.
- Optionally: `.github/actions/resolve-deployed-sha/action.yml` or similar composite if no equivalent exists.
- `CHANGELOG.md` — append the workflow addition if the repo keeps one.
- `README.md` or workflow-index doc — document the new reusable workflow and its caller-side usage.

## NuGet Dependencies
None. `HoneyDrunk.Actions` is a YAML workflows repo; no .NET project is touched by this packet. The workflow does invoke `dotnet ef` and depends on the .NET runtime being available — that comes from the `actions/dotnet/setup` composite action already in the repo.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Routing rule "workflow, CI, GitHub Actions, pipeline, PR check, release → HoneyDrunk.Actions" maps exactly.
- [x] No code change in any other repo.
- [x] The reusable workflow is the ADR-0012-established control-plane surface; this packet adds a sibling workflow alongside the existing deploy workflows, consistent with ADR-0048 D3/D11's explicit instruction.

## Acceptance Criteria
- [ ] `.github/workflows/migrate.yml` exists as a reusable workflow (`workflow_call` trigger)
- [ ] Inputs: `node`, `environment`, `target-migration` (optional), `db-provider` (`azure-sql` or `postgres`)
- [ ] Secrets accept the standard OIDC client/tenant/subscription ID set used by the existing deploy workflows
- [ ] Job-level `environment: ${{ inputs.environment }}` is set so `staging`/`prod` Environment protection rules apply per ADR-0033 D7
- [ ] The workflow checks out the consumer repo at the deployed-code SHA for the target environment (matches the running code per ADR-0033's environment-to-ref mapping)
- [ ] `dotnet ef migrations script --idempotent` is run against the Node's `DbContext`; the resulting `migrate.sql` is uploaded as a workflow artifact BEFORE the apply step
- [ ] Connection string is resolved from per-Node Key Vault via the existing `azure/keyvault-fetch` composite action (invariant 9 — Vault is the only source of secrets)
- [ ] `azure-sql` provider applies via `sqlcmd` with `-b` (exit on error) and Managed Identity / AD authentication
- [ ] `postgres` provider applies via `psql` with `-v ON_ERROR_STOP=1` and Managed Identity / AD authentication
- [ ] Post-apply `__EFMigrationsHistory` snapshot is captured and uploaded as a workflow artifact
- [ ] On failure: `if: failure()` step captures stderr, `__EFMigrationsHistory` partial-apply snapshot, and a link to the consumer repo's `dr-runbook.md` Migration Failure section
- [ ] Caller-side example caller workflow YAML is documented in the workflow header comment, README, or workflow-index doc
- [ ] Workflow is operator-triggered only (`workflow_dispatch` from the caller) — no scheduled or push triggers
- [ ] Actions repo CHANGELOG (if kept) carries an entry for the new workflow

## Human Prerequisites
- [ ] **Grant the OIDC Managed Identity database-data-plane RBAC** on every Node's database per environment that adopts `migrate.yml`. For Azure SQL: `db_ddladmin` or equivalent contained-database role; for Postgres flexible server: the appropriate Azure AD admin or role membership. This is a per-Node, per-environment portal step (or a Bicep/IaC step if the Grid has IaC for DB roles). Not required to merge this packet — required before the first consumer Node invokes the workflow against `dev`/`staging`/`prod`.
- [ ] **Grant the OIDC Managed Identity `Key Vault Secrets User`** on every Node's Key Vault per environment. Likely already granted for the deploy workflows; re-verify per Node when `migrate.yml` is wired.
- [ ] **Configure GitHub Environment protection rules on `staging` and `prod`** if not already configured per ADR-0033 D7. `dev` stays unprotected. Required reviewers/wait-time per the operator's preference.
- [ ] **Seed `db-connection-string-{environment}` (or per-Node convention) into each Node's Key Vault** before that Node first invokes `migrate.yml` in that environment. The connection string must use AD/Managed-Identity authentication (no embedded password) per invariant 9.

## Referenced ADR Decisions

**ADR-0048 D3 — Out-of-band migration job, manually triggered.** Dedicated GitHub Actions workflow per Node; cuts a SQL script from the migration assembly; applies via Azure SQL/Postgres connection; succeeds independently of the app deploy. Migrations are deliberate, observable, separable from code. A failed migration does NOT roll back the app — the app stays on the old code against the old schema.

**ADR-0048 D11 — `migrate.yml` reusable workflow specification.** Inputs (`node`, `environment`, `target-migration`); `workflow_dispatch` only; six-step procedure (checkout-at-deployed-SHA; `dotnet ef migrations script --idempotent`; resolve connection from Vault; apply via `sqlcmd`/`psql`; upload artifacts on success; surface diagnostics on failure); per-environment-gated via GitHub Environment protection rules per ADR-0033 D7.

**ADR-0048 D10 — Forward-only by default; idempotent scripts; resumable on partial failure.** EF Core's `Down()` is generated but not committed to in production. The `--idempotent` flag produces a script that re-applies only un-applied DDL on re-run. `migrate.yml` retains the applied SQL and the `__EFMigrationsHistory` snapshot as workflow artifacts for forensic value.

**ADR-0015 — Container Hosting Platform and OIDC.** GitHub OIDC is the Grid's deploy credential model. The Managed Identity used by `migrate.yml` is the same OIDC identity used by the existing deploy workflows; this packet does not introduce a new credential model.

**ADR-0033 D1, D7 — Environment-gated deploy triggers; GitHub Environment protection rules.** `dev` is unprotected; `staging`/`prod` are protected. `migrate.yml` inherits this posture via the job-level `environment:` setting.

**ADR-0005 — Vault is the only source of secrets.** The connection string is resolved from per-Node Key Vault via the existing `azure/keyvault-fetch` composite action; the workflow never reads a connection string from a workflow secret directly or from a hardcoded environment variable.

**ADR-0012 — Actions is the CI/CD control plane.** All reusable workflows live in HoneyDrunk.Actions; `migrate.yml` is a sibling to the existing `job-deploy-container-app.yml`.

**Invariant 9 — Vault is the only source of secrets.** "No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`." For workflow-level secret access, the parallel rule is that connection strings come from Key Vault via the keyvault-fetch action, never from a workflow secret directly or a hardcoded environment variable.

## Constraints
- **`--idempotent` is mandatory.** ADR-0048 D11 and D10 both name it. Producing a non-idempotent script breaks the resumability property the workflow's failure handling depends on.
- **Operator-triggered only.** No `schedule:` trigger, no `push:` trigger. `workflow_dispatch` only (via the caller-side per-Node workflow). ADR-0048 D3 names this as load-bearing.
- **`dev` automation is out of scope.** ADR-0048 names "auto-running `migrate.yml` against `dev` on every merge that touches `Migrations/`" as a follow-up evaluated after Phase 4. This packet ships `workflow_dispatch`-only; the dev-automation evaluation is a deferred follow-up.
- **Failure does not roll back the app.** Per ADR-0048 D3: "because the migration runs before the code deploy, a migration that fails does NOT roll back the app — the app is still serving the old code against the old schema. The operator fixes the migration, re-runs `migrate.yml`, then proceeds with the code deploy." The failure-handling step surfaces diagnostics but does not invoke a rollback.
- **Artifacts retained for forensics.** Per ADR-0048 D10 step 5: "The migration job artifact carries the applied SQL. `migrate.yml` retains the generated SQL script and the migration history table snapshot as workflow artifacts. Post-mortem forensics use these artifacts." Use the standard `actions/upload-artifact@v4` (or the version pinned in the repo's existing workflows).
- **Two providers, one workflow.** `azure-sql` and `postgres` branches live in the same workflow file; do not split into two parallel workflows. The `db-provider` input drives the branch.
- **OIDC, not raw credentials.** Per invariant 9 and ADR-0015's OIDC model; no `azure/login` step that consumes a service-principal password.

## Labels
`feature`, `tier-2`, `core`, `ci`, `adr-0048`, `wave-3`

## Agent Handoff

**Objective:** Author the new `migrate.yml` reusable workflow in HoneyDrunk.Actions per ADR-0048 D3 and D11.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Give every migration-bearing Node a deliberate, observable, operator-triggered migration workflow separable from the code deploy.
- Feature: ADR-0048 Schema Evolution rollout, Wave 3.
- ADRs: ADR-0048 D3/D10/D11 (primary), ADR-0015 (OIDC credential model), ADR-0033 D7 (Environment protection rules), ADR-0005 (Vault as the only source of secrets), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0048 must be Accepted so the workflow's behavior can cite its decisions as live rules.

**Constraints:**
- `--idempotent` flag mandatory on `dotnet ef migrations script`.
- `workflow_dispatch` only — no schedule, no push.
- Failure does not roll back the app.
- Artifacts retained: `migrate.sql` + `__EFMigrationsHistory` snapshot.
- Both `azure-sql` and `postgres` providers in one workflow.
- OIDC + Managed Identity, not service-principal passwords.
- Connection string from Key Vault via existing `azure/keyvault-fetch` composite.

**Key Files:**
- `.github/workflows/migrate.yml` — new reusable workflow.
- Optionally: a small composite action under `.github/actions/` if no equivalent exists for resolving the consumer repo's deployed-code SHA.
- `CHANGELOG.md` for the Actions repo.

**Contracts:**
- `migrate.yml` reusable workflow (new) — Inputs `node`, `environment`, `target-migration?`, `db-provider`; Secrets the standard OIDC client/tenant/subscription set; `workflow_dispatch`-only via consumer-side caller.
