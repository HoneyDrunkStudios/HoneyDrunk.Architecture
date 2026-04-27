# Current Focus

What the team (human + agents) should prioritize right now.

**Last Updated:** 2026-04-27

## Primary Focus

### Configuration & Secrets Rollout (ADR-0005 / ADR-0006) — **COMPLETE**

The two-wave rollout that standardizes secret and configuration management across the Grid is fully merged.

- **Wave 1 (complete):** Vault env-driven wiring ✓, App Configuration extension ✓, event-driven cache invalidation ✓, Vault.Rotation repo creation ✓, portal walkthroughs ✓, catalog registration ✓, OIDC deploy workflow (Actions#20) ✓
- **Wave 2 (complete):** All per-Node bootstrap migrations merged (Auth, Web.Rest, Data, Notify, Pulse, Studios) ✓. Actions secret cleanup (Actions#21) ✓. Deploy-gate SLA checks ✓. Release tags (Vault v0.3.0, Vault.Rotation v0.1.0) ✓
- **Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
- **Status:** All 15 issues merged 2026-04-11 through 2026-04-26. Initiative ready to archive.
- **Next:** Grid now running with env-driven config and per-Node Key Vault bootstrap. Focus shifts to Azure deployment (Notify, Pulse) and subsequent initiatives.

**See:** `generated/issue-packets/active/adr-0005-0006-rollout/dispatch-plan.md`

### Deploy Notify and Pulse

Provision Azure infrastructure and get both services running in the development environment.

- **Notify:** Azure Function App (`func-hd-notify-dev`) — queue-triggered email/SMS dispatch
- **Notify.Worker:** Azure Container App (`ca-hd-notify-worker-dev`) — background worker on `cae-hd-dev` / `acrhdshareddev`
- **Pulse:** Azure Container App (`ca-hd-pulse-dev`) — OTLP collector for observability, on `cae-hd-dev` / `acrhdshareddev`

**Why now:** All Node packages are built and published. The deployment pipeline (HoneyDrunk.Actions) is ready. The Azure provisioning guide and naming conventions are documented. The only remaining work is creating the Azure resources, wiring OIDC, and running the first deploy.

**See:** `infrastructure/azure-provisioning-guide.md` for step-by-step instructions.

## On Deck

### Deploy Notify and Pulse to Azure

Provision Azure infrastructure (Function App for Notify, Container Apps for Notify.Worker and Pulse.Collector) and run the first deployment. All Node packages are built and published; Actions workflows are ready. Infrastructure walkthroughs complete (Architecture#37, 2026-04-26).

**Key issues:**
- Notify#3: Release workflow and Azure bring-up for `Notify.Functions`
- Notify#4: Release workflow and Azure bring-up for `Notify.Worker` on Container Apps
- Pulse#3: Release workflow and Azure bring-up for `Pulse.Collector` on Container Apps

**See:** `infrastructure/azure-provisioning-guide.md`

### HoneyDrunk.Lore Bring-Up

Stand up Lore as a flat-file LLM-compiled wiki. 6 issues scoped and on The Hive under initiative `honeydrunk-lore-bringup`. Start with Lore#1 (scaffold) and Architecture#9 (catalog registration) — they are independent and can run in parallel.

**See:** [active-initiatives.md](active-initiatives.md) → HoneyDrunk.Lore Bring-Up

### Agent Kit

Stand up the Agent Kit Node — agent execution runtime, tool abstraction, and memory. This is the foundation for AI-powered workflows across the Grid.

### ADR-0010 Phase 1 (Observation Layer & AI Routing)

Accept ADR-0010 and ship Phase 1 contracts. Three issues in progress: Architecture#35, Architecture#36, AI#1. Observe repo creation is human-only; AI routing contracts deferred pending HoneyDrunk.AI standup ADR.

**See:** [active-initiatives.md](active-initiatives.md) → ADR-0010 Observation Layer & AI Routing — Phase 1
