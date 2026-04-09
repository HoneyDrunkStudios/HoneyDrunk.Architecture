# Dispatch Plan: ADR-0005 & ADR-0006 Rollout

**Date:** 2026-04-09
**Trigger:** ADR-0005 (Configuration & Secrets Strategy) and ADR-0006 (Secret Rotation & Lifecycle) accepted
**Type:** Multi-repo
**Sector:** Core + Ops + Meta
**Site sync required:** No (internal infra)
**Rollback plan:** All Wave 2 per-Node migrations are behind preview package versions from Wave 1 Vault releases. To roll back, pin Nodes to the previous Vault minor version and revert the deploy; infra resources stay in place harmlessly.
**Execution blocker:** Per ADR-0008, org Project v2 must be configured (six custom fields, `repo:HoneyDrunkStudios/*` auto-add filter) before any issue in this rollout is filed. Otherwise issues land without proper board fields and have to be backfilled.

## Summary

ADR-0005 decided the per-Node Key Vault + shared App Configuration + env-driven bootstrap model. ADR-0006 layered rotation, lifecycle, and audit on top — including a brand-new `HoneyDrunk.Vault.Rotation` sub-Node, event-driven cache invalidation in `HoneyDrunk.Vault`, and deploy-gate SLA checks in `HoneyDrunk.Actions`. This rollout touches 10 repos including one new repo.

## Wave Diagram

### Wave 1 — Foundation (no dependencies, can run in parallel)

- [ ] `HoneyDrunk.Vault`: env-driven `AddVault` wiring — [`01-vault-env-driven-add-vault-wiring.md`](01-vault-env-driven-add-vault-wiring.md)
- [ ] `HoneyDrunk.Vault`: `AddAppConfiguration` builder extension — [`02-vault-add-app-configuration-extension.md`](02-vault-add-app-configuration-extension.md)
- [ ] `HoneyDrunk.Vault`: Event-driven cache invalidation on `SecretNewVersionCreated` — [`03-vault-event-driven-cache-invalidation.md`](03-vault-event-driven-cache-invalidation.md)
- [ ] `HoneyDrunk.Vault.Rotation` (new repo): Scaffold repo, solution, Function App skeleton, CI — [`04-vault-rotation-scaffold-new-subnode.md`](04-vault-rotation-scaffold-new-subnode.md)
- [ ] `HoneyDrunk.Architecture`: Portal walkthroughs for KV / RBAC / OIDC / App Config / Event Grid / Log Analytics — [`05-architecture-infra-portal-walkthroughs.md`](05-architecture-infra-portal-walkthroughs.md)
- [ ] `HoneyDrunk.Architecture`: Register `HoneyDrunk.Vault.Rotation` in catalogs + routing + repo-docs stubs — [`06-architecture-catalogs-register-vault-rotation.md`](06-architecture-catalogs-register-vault-rotation.md)
- [ ] `HoneyDrunk.Actions`: Reusable OIDC federated-credential deploy workflow + composite actions — [`07-actions-oidc-federated-credentials-workflow.md`](07-actions-oidc-federated-credentials-workflow.md)

**Wave 1 exit criteria:**
- Vault preview packages published with new extensions + invalidator
- Portal walkthroughs merged
- Catalogs updated
- Rotation repo exists with green CI
- Reusable OIDC workflow merged and callable from other repos

### Wave 2 — Per-Node Migration + CI Tightening (depends on Wave 1)

See [`handoff-wave2-core-nodes-bootstrap-migration.md`](handoff-wave2-core-nodes-bootstrap-migration.md) for the public surface Wave 2 may assume from Wave 1.

Per-Node migrations (parallel once Wave 1 exits):

- [ ] `HoneyDrunk.Auth`: Migrate bootstrap to env vars — [`08-auth-migrate-config-bootstrap-to-env-vars.md`](08-auth-migrate-config-bootstrap-to-env-vars.md)
- [ ] `HoneyDrunk.Web.Rest`: Migrate bootstrap to env vars — [`09-web-rest-migrate-config-bootstrap-to-env-vars.md`](09-web-rest-migrate-config-bootstrap-to-env-vars.md)
- [ ] `HoneyDrunk.Data`: Migrate bootstrap to env vars (Tier-1 SQL rotation gate) — [`10-data-migrate-config-bootstrap-to-env-vars.md`](10-data-migrate-config-bootstrap-to-env-vars.md)
- [ ] `HoneyDrunk.Notify`: Migrate bootstrap (also unblocks Azure Functions deployment) — [`11-notify-migrate-config-bootstrap-to-env-vars.md`](11-notify-migrate-config-bootstrap-to-env-vars.md)
- [ ] `HoneyDrunk.Pulse`: Migrate bootstrap (also unblocks production deployment of Pulse.Collector) — [`12-pulse-migrate-config-bootstrap-to-env-vars.md`](12-pulse-migrate-config-bootstrap-to-env-vars.md)
- [ ] `HoneyDrunk.Studios`: KV references via App Service config — [`13-studios-migrate-secrets-to-keyvault-references.md`](13-studios-migrate-secrets-to-keyvault-references.md)

Actions repo cleanup + gating (parallel with per-Node migrations):

- [ ] `HoneyDrunk.Actions`: Audit/remove direct secret reads in workflows — [`14-actions-remove-direct-secret-reads-in-workflows.md`](14-actions-remove-direct-secret-reads-in-workflows.md)
- [ ] `HoneyDrunk.Actions`: Deploy-gate SLA check composite action — [`15-actions-deploy-gate-sla-check.md`](15-actions-deploy-gate-sla-check.md)

**Wave 2 exit criteria:**
- Every deployable Node's `Program.cs` uses only env-driven extensions
- Zero direct env-var / appsettings secret reads across the Grid
- Every CI workflow OIDC-authenticated, zero client secrets
- Rotation SLA gate active on every deploy pipeline

## Archival

Per ADR-0008 D10, when every packet in both waves reaches `Done` on the org Project board and the exit criteria above are met, the entire `active/adr-0005-0006-rollout/` folder is moved to `archive/adr-0005-0006-rollout/` in a single commit. Partial archival is forbidden.

## `gh` CLI Commands

Paths are relative to the `HoneyDrunk.Architecture` repo root. Run from there.

```bash
PACKETS="generated/issue-packets/active/adr-0005-0006-rollout"

# Wave 1
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault \
  --title "Env-driven AddVault wiring for AZURE_KEYVAULT_URI" \
  --body-file $PACKETS/01-vault-env-driven-add-vault-wiring.md \
  --label "feature,tier-2,adr-0005,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault \
  --title "Add AddAppConfiguration builder extension" \
  --body-file $PACKETS/02-vault-add-app-configuration-extension.md \
  --label "feature,tier-2,adr-0005,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault \
  --title "Event-driven SecretCache invalidation via Event Grid" \
  --body-file $PACKETS/03-vault-event-driven-cache-invalidation.md \
  --label "feature,tier-2,adr-0006,wave-1"

# HoneyDrunk.Vault.Rotation repo must be created in the GitHub org before this
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault.Rotation \
  --title "Scaffold HoneyDrunk.Vault.Rotation repo, solution, and Function App" \
  --body-file $PACKETS/04-vault-rotation-scaffold-new-subnode.md \
  --label "feature,tier-3,new-node,adr-0006,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Portal walkthroughs for KV, App Config, Event Grid, OIDC, Log Analytics" \
  --body-file $PACKETS/05-architecture-infra-portal-walkthroughs.md \
  --label "feature,tier-2,docs,adr-0005,adr-0006,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Register HoneyDrunk.Vault.Rotation in catalogs and routing" \
  --body-file $PACKETS/06-architecture-catalogs-register-vault-rotation.md \
  --label "chore,tier-1,adr-0006,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Reusable OIDC federated-credential deploy workflow" \
  --body-file $PACKETS/07-actions-oidc-federated-credentials-workflow.md \
  --label "ci,tier-2,adr-0005,wave-1"

# Wave 2 — do NOT file until Wave 1 exit criteria are met
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Auth \
  --title "Migrate Auth config bootstrap to AZURE_KEYVAULT_URI + AZURE_APPCONFIG_ENDPOINT" \
  --body-file $PACKETS/08-auth-migrate-config-bootstrap-to-env-vars.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Web.Rest \
  --title "Migrate Web.Rest config bootstrap to env vars" \
  --body-file $PACKETS/09-web-rest-migrate-config-bootstrap-to-env-vars.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Data \
  --title "Migrate Data config bootstrap to env vars (Tier-1 rotation gate)" \
  --body-file $PACKETS/10-data-migrate-config-bootstrap-to-env-vars.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Notify \
  --title "Migrate Notify config bootstrap to env vars" \
  --body-file $PACKETS/11-notify-migrate-config-bootstrap-to-env-vars.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Pulse \
  --title "Migrate Pulse config bootstrap to env vars" \
  --body-file $PACKETS/12-pulse-migrate-config-bootstrap-to-env-vars.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Studios \
  --title "Migrate Studios secrets to Key Vault references via App Service" \
  --body-file $PACKETS/13-studios-migrate-secrets-to-keyvault-references.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Audit and remove direct secret reads from workflows" \
  --body-file $PACKETS/14-actions-remove-direct-secret-reads-in-workflows.md \
  --label "ci,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Deploy-gate composite action for rotation SLA checks" \
  --body-file $PACKETS/15-actions-deploy-gate-sla-check.md \
  --label "ci,tier-2,adr-0006,wave-2"
```
