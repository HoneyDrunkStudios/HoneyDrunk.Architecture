# Dispatch Plan: ADR-0005 & ADR-0006 Rollout

**Date:** 2026-04-09 (refactored 2026-04-10 to drop wave gating and consolidate packets)
**Trigger:** ADR-0005 (Configuration & Secrets Strategy) and ADR-0006 (Secret Rotation & Lifecycle) accepted
**Type:** Multi-repo
**Sector:** Core + Ops + Meta
**Site sync required:** No (internal infra)
**Rollback plan:** Wave 2 per-Node migrations consume a preview package of the Wave 1 Vault changes. To roll back, pin Nodes to the previous Vault minor version and revert the deploy; infra resources stay in place harmlessly.

## Summary

ADR-0005 decided the per-Node Key Vault + shared App Configuration + env-driven bootstrap model. ADR-0006 layered rotation, lifecycle, and audit on top — including a brand-new `HoneyDrunk.Vault.Rotation` sub-Node, event-driven cache invalidation in `HoneyDrunk.Vault`, and deploy-gate SLA checks in `HoneyDrunk.Actions`. This rollout touches 10 repos including one new repo that does not yet exist on GitHub.

## Packet Consolidation (2026-04-10)

The original rollout was scoped as 15 small packets. After reviewing with a "would I assign this as one sprint story to a human dev?" test, three pairs were consolidated:

- **`vault-bootstrap-extensions.md`** — merges the env-driven `AddVault` and `AddAppConfiguration` extension work. Both are sibling bootstrap extensions on the same API surface and ship in one PR.
- **`architecture-infra-setup.md`** — merges the six Azure Portal walkthroughs and the Vault.Rotation catalog registration. Both are pure docs/JSON edits in the same repo with no code changes.
- **`actions-oidc-and-secret-cleanup.md`** — merges the new reusable OIDC deploy workflow with the audit/removal of direct secret reads. Same repo, same thematic unit: establish the new pattern + retire the old one.

The Vault event-driven cache invalidation (`vault-event-driven-cache-invalidation.md`) stayed standalone because it's a distinct feature (event handling, different code path). The deploy-gate SLA composite (`actions-deploy-gate-sla-check.md`) stayed standalone because it's rotation-specific CI work thematically separate from the OIDC migration.

**Total:** 15 → 12 packets (11 fileable; `vault-rotation-scaffold.md` is blocked on repo creation).

## Execution Model

This initiative is the first to exercise the rollout path under ADR-0008. Execution is **manual on Codex Cloud** for the initial run (see ADR-0008 follow-up notes for the long-term event-driven Claude-in-Actions path). All issues are filed in one pass. The wave concept is preserved as **recommended execution order** for manual triggering on Codex Cloud — it is no longer a filing gate.

### Wave 1 — Foundation (recommended: run these on Codex Cloud first)

These packets establish the surfaces that Wave 2 consumes. Ideally run them in Codex Cloud, merge the PRs, and publish a preview Vault package before kicking off Wave 2 sessions. They have no runtime dependencies on each other and can be triggered in parallel.

- [ ] `HoneyDrunk.Vault`: env-driven `AddVault` + `AddAppConfiguration` bootstrap extensions — [`vault-bootstrap-extensions.md`](vault-bootstrap-extensions.md)
- [ ] `HoneyDrunk.Vault`: Event-driven cache invalidation on `SecretNewVersionCreated` — [`vault-event-driven-cache-invalidation.md`](vault-event-driven-cache-invalidation.md)
- [ ] `HoneyDrunk.Architecture`: Portal walkthroughs + Vault.Rotation catalog registration — [`architecture-infra-setup.md`](architecture-infra-setup.md)
- [ ] `HoneyDrunk.Actions`: Reusable OIDC workflow + direct-secret-read cleanup — [`actions-oidc-and-secret-cleanup.md`](actions-oidc-and-secret-cleanup.md)
- [ ] `HoneyDrunk.Architecture` (**human-only chore**): Create the `HoneyDrunk.Vault.Rotation` GitHub repo — [`create-vault-rotation-repo.md`](create-vault-rotation-repo.md)
  - `Actor=Human`, `human-only` label. 3-minute portal task. Root blocker for the scaffold packet below.
- [ ] `HoneyDrunk.Vault.Rotation` (**BLOCKED on chore above**): Scaffold new repo, solution, Function App skeleton, CI — [`vault-rotation-scaffold.md`](vault-rotation-scaffold.md)
  - **Blocked on:** `create-vault-rotation-repo` closing. File this packet after the chore is done, then uncomment the `gh issue create` block below.

**Wave 1 exit criteria (before starting Wave 2 on Codex Cloud):**
- Vault preview package published with bootstrap extensions + cache invalidator
- Portal walkthroughs merged to `main`
- Vault.Rotation catalog entries merged
- Reusable OIDC workflow merged and callable from other repos
- Direct `AZURE_CLIENT_SECRET` references removed from Actions repo

### Wave 2 — Per-Node Migration + CI Tightening (recommended: run after Wave 1 merges)

Per-Node migrations (no runtime coupling between them — parallel execution is safe on Codex Cloud):

- [ ] `HoneyDrunk.Auth`: Migrate bootstrap to env vars — [`auth-migrate-config-bootstrap.md`](auth-migrate-config-bootstrap.md)
- [ ] `HoneyDrunk.Web.Rest`: Migrate bootstrap to env vars — [`web-rest-migrate-config-bootstrap.md`](web-rest-migrate-config-bootstrap.md)
- [ ] `HoneyDrunk.Data`: Migrate bootstrap to env vars (Tier-1 SQL rotation gate) — [`data-migrate-config-bootstrap.md`](data-migrate-config-bootstrap.md)
- [ ] `HoneyDrunk.Notify`: Migrate bootstrap (also unblocks Azure Functions deployment) — [`notify-migrate-config-bootstrap.md`](notify-migrate-config-bootstrap.md)
- [ ] `HoneyDrunk.Pulse`: Migrate bootstrap (also unblocks production deployment of Pulse.Collector) — [`pulse-migrate-config-bootstrap.md`](pulse-migrate-config-bootstrap.md)
- [ ] `HoneyDrunk.Studios`: KV references via App Service config — [`studios-migrate-secrets-to-keyvault-references.md`](studios-migrate-secrets-to-keyvault-references.md)

Actions repo SLA gating (can run alongside per-Node migrations):

- [ ] `HoneyDrunk.Actions`: Deploy-gate SLA check composite action — [`actions-deploy-gate-sla-check.md`](actions-deploy-gate-sla-check.md)

**Wave 2 exit criteria:**
- Every deployable Node's `Program.cs` uses only env-driven extensions
- Zero direct env-var / appsettings secret reads across the Grid
- Every CI workflow OIDC-authenticated, zero client secrets
- Rotation SLA gate active on every deploy pipeline

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and the exit criteria above are met, the entire `active/adr-0005-0006-rollout/` folder is moved to `archive/adr-0005-0006-rollout/` in a single commit. Partial archival is forbidden.

## `gh` CLI Commands — File All Issues At Once

Paths are relative to the `HoneyDrunk.Architecture` repo root. Run from there. **All packets file in one pass**; the wave label is retained as informational metadata for the board's `Wave` field, not as a filing gate. The `vault-rotation-scaffold` packet is excluded until its target repo exists.

```bash
PACKETS="generated/issue-packets/active/adr-0005-0006-rollout"

# --- Wave 1: Foundation ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault \
  --title "Env-driven AddVault + AddAppConfiguration bootstrap extensions" \
  --body-file $PACKETS/vault-bootstrap-extensions.md \
  --label "feature,tier-2,adr-0005,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault \
  --title "Event-driven SecretCache invalidation via Event Grid" \
  --body-file $PACKETS/vault-event-driven-cache-invalidation.md \
  --label "feature,tier-2,adr-0006,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Infra setup: portal walkthroughs + Vault.Rotation catalog registration" \
  --body-file $PACKETS/architecture-infra-setup.md \
  --label "feature,tier-2,docs,adr-0005,adr-0006,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "OIDC federated-credential workflow + direct-secret-read cleanup" \
  --body-file $PACKETS/actions-oidc-and-secret-cleanup.md \
  --label "ci,tier-2,adr-0005,wave-1"

# Wave 1 human-only chore — create the HoneyDrunk.Vault.Rotation GitHub repo
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Create HoneyDrunk.Vault.Rotation GitHub repo (human-only, gates Vault.Rotation scaffold)" \
  --body-file $PACKETS/create-vault-rotation-repo.md \
  --label "chore,tier-1,meta,new-node,adr-0006,human-only,wave-1"

# --- Wave 2: Per-Node Migrations + SLA Gate ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Auth \
  --title "Migrate Auth config bootstrap to AZURE_KEYVAULT_URI + AZURE_APPCONFIG_ENDPOINT" \
  --body-file $PACKETS/auth-migrate-config-bootstrap.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Web.Rest \
  --title "Migrate Web.Rest config bootstrap to env vars" \
  --body-file $PACKETS/web-rest-migrate-config-bootstrap.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Data \
  --title "Migrate Data config bootstrap to env vars (Tier-1 rotation gate)" \
  --body-file $PACKETS/data-migrate-config-bootstrap.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Notify \
  --title "Migrate Notify config bootstrap to env vars" \
  --body-file $PACKETS/notify-migrate-config-bootstrap.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Pulse \
  --title "Migrate Pulse config bootstrap to env vars" \
  --body-file $PACKETS/pulse-migrate-config-bootstrap.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunkStudios \
  --title "Migrate Studios secrets to Key Vault references via App Service" \
  --body-file $PACKETS/studios-migrate-secrets-to-keyvault-references.md \
  --label "feature,tier-2,adr-0005,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Deploy-gate composite action for rotation SLA checks" \
  --body-file $PACKETS/actions-deploy-gate-sla-check.md \
  --label "ci,tier-2,adr-0006,wave-2"

# --- Blocked: file after the repo is created ---
# gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault.Rotation \
#   --title "Scaffold HoneyDrunk.Vault.Rotation repo, solution, and Function App" \
#   --body-file $PACKETS/vault-rotation-scaffold.md \
#   --label "feature,tier-3,new-node,adr-0006,wave-1"
```

## Notes

- **Wave field on the board:** the org Project board retains its `Wave` custom field per ADR-0008 D3. Labels above populate it via the board's workflow automation. When ADR-0008 Phase 2 lands (event-driven Claude-in-Actions execution with an `In Progress — Agent` status), waves will gain automated gating semantics — keeping the field now means no rework then.
- **Filing is un-gated.** Unlike the original plan, Wave 2 issues are filed in the same batch as Wave 1. Execution order is a manual decision on Codex Cloud, not enforced by the filing sequence.
- **Wave 1 / Wave 2 as execution guidance:** when triggering Codex Cloud sessions, run Wave 1 packets first and wait for the preview Vault package to publish before starting any Wave 2 per-Node migration. This is a manual discipline, not a mechanical gate.
