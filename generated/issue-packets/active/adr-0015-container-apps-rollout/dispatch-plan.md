# Dispatch Plan: ADR-0015 Container Apps Rollout

**Date:** 2026-04-18
**Trigger:** ADR-0015 (Container Hosting Platform) proposed — rolls the Grid's first non-NuGet deployables
**Type:** Multi-repo
**Sector:** Infrastructure + Ops
**Site sync required:** No
**Rollback plan:** Each Container App deploy creates a new revision at 0% traffic. Rollback is a traffic-shift back to the previous revision — no image republish. Infra resources (ACR, Container Apps Environment, Container Apps themselves) remain provisioned on rollback.

## Summary

ADR-0015 settles where containerized Nodes run in Azure (Container Apps), names the supporting resources (`cae-hd-{env}`, `acrhdshared{env}`, `ca-hd-{service}-{env}`), and commits to revision-based traffic splitting for deploys. This rollout lands the first three deployables on the Grid — `Notify.Functions` (Function App), `Notify.Worker` (Container App), and `Pulse.Collector` (Container App) — plus the reusable workflow and walkthroughs that every future deployable Node will reuse.

Five packets across three repos:

- 1 Architecture packet (portal walkthroughs)
- 1 Actions packet (new `job-deploy-container-app.yml` reusable workflow)
- 1 Notify packet for `Notify.Functions` release workflow
- 1 Notify packet for `Notify.Worker` release workflow
- 1 Pulse packet for `Pulse.Collector` release workflow

All three deployables are first-time Azure bring-ups, so each carries a Human Prerequisites section covering portal provisioning (resource group, vault, ACR/CAE if not yet created, Container App / Function App, OIDC federated credential, bootstrap env var seeding).

## Execution Model

Manual on Codex Cloud for this rollout. Filing is un-gated — all five packets file in one pass. Waves below are recommended execution order for manual triggering, not filing gates.

### Wave 1 — Foundation (run first on Codex Cloud)

These packets establish the walkthroughs and the reusable workflow that Wave 2 consumes. They can run in parallel.

- [ ] `HoneyDrunk.Architecture`: Portal walkthroughs for Function App, ACR, Container Apps Environment, and Container App — [`01-architecture-container-apps-walkthroughs.md`](01-architecture-container-apps-walkthroughs.md)
- [ ] `HoneyDrunk.Actions`: `job-deploy-container-app.yml` reusable workflow + `azure/deploy-container-app` composite action — [`02-actions-deploy-container-app-workflow.md`](02-actions-deploy-container-app-workflow.md)

**Wave 1 exit criteria:**
- Architecture walkthroughs merged and linked from `infrastructure/README.md`.
- `job-deploy-container-app.yml` merged on `main` in `HoneyDrunk.Actions`, with a consumer example in `examples/`.
- At least one environment has `acrhdshared{env}` and `cae-hd-{env}` provisioned per the new walkthroughs (Human Prereq on packet 01 — provisioning happens as the walkthroughs are authored, so the docs reflect real portal flows).

### Wave 2 — Per-Node Release Bring-up (run after Wave 1 merges)

Three independent bring-ups. Can run in parallel on Codex Cloud.

- [ ] `HoneyDrunk.Notify`: `Notify.Functions` release workflow + infra bring-up — [`03-notify-functions-release-workflow.md`](03-notify-functions-release-workflow.md)
- [ ] `HoneyDrunk.Notify`: `Notify.Worker` release workflow + infra bring-up — [`04-notify-worker-release-workflow.md`](04-notify-worker-release-workflow.md)
- [ ] `HoneyDrunk.Pulse`: `Pulse.Collector` release workflow + infra bring-up — [`05-pulse-collector-release-workflow.md`](05-pulse-collector-release-workflow.md)

**Wave 2 exit criteria:**
- Each deployable has a release workflow on `main` that successfully produces a deploy on tag push.
- Each deployable's production revision responds to a health probe.
- `acrhdshared{env}` contains at least one tagged image per containerized Node.
- Per-Node vault (`kv-hd-notify-{env}`, `kv-hd-pulse-{env}`) populated with required secrets.
- OIDC federated credentials exist for every `{repo, environment}` pair used.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and the Wave 2 exit criteria are met, the entire `active/adr-0015-container-apps-rollout/` folder is moved to `archive/adr-0015-container-apps-rollout/` in a single commit. Partial archival is forbidden.

## `gh` CLI Commands — File All Issues At Once

Paths are relative to the `HoneyDrunk.Architecture` repo root. Run from there.

```bash
PACKETS="generated/issue-packets/active/adr-0015-container-apps-rollout"

# --- Wave 1: Foundation ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Infra walkthroughs: Function App, ACR, Container Apps Environment, Container App" \
  --body-file $PACKETS/01-architecture-container-apps-walkthroughs.md \
  --label "feature,tier-2,docs,adr-0015,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Reusable workflow: job-deploy-container-app.yml for Azure Container Apps" \
  --body-file $PACKETS/02-actions-deploy-container-app-workflow.md \
  --label "ci,tier-2,adr-0015,wave-1"

# --- Wave 2: Per-Node Release Bring-up ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Notify \
  --title "Release workflow: deploy Notify.Functions to Azure Function App" \
  --body-file $PACKETS/03-notify-functions-release-workflow.md \
  --label "feature,tier-2,ops,infrastructure,adr-0015,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Notify \
  --title "Release workflow: deploy Notify.Worker to Azure Container Apps" \
  --body-file $PACKETS/04-notify-worker-release-workflow.md \
  --label "feature,tier-2,ops,infrastructure,adr-0015,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Pulse \
  --title "Release workflow: deploy Pulse.Collector to Azure Container Apps" \
  --body-file $PACKETS/05-pulse-collector-release-workflow.md \
  --label "feature,tier-2,ops,infrastructure,adr-0015,wave-2"
```

## Notes

- **First deployables on the Grid.** Until this initiative lands, HoneyDrunk has only shipped NuGet packages. These packets exercise the full deploy path (build → image/artifact → Azure resource → MI → Key Vault → traffic shift) end-to-end for the first time. Expect refinement of the walkthroughs and workflow from real-deploy feedback during Wave 2.
- **ADR-0015 starts Proposed.** Per the ADR acceptance workflow, the ADR flips to Accepted after its introducing PR merges — not on first draft. Wave 1 packets can still file and execute against a Proposed ADR; the constraints in the ADR are the working contract during rollout.
- **Invariants 34–36 are proposed alongside ADR-0015.** The Architecture packet in Wave 1 adds them to `constitution/invariants.md`.
- **Container Apps cost expectation.** At current scale, Consumption-plan billing is expected to stay inside the monthly free grant. Log Analytics ingestion is the non-trivial line — apply sampling and log-level discipline in the deployable Nodes.
