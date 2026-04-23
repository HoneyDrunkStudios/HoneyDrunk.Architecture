# Current Focus

What the team (human + agents) should prioritize right now.

**Last Updated:** 2026-04-23

## Primary Focus

### Configuration & Secrets Rollout (ADR-0005 / ADR-0006)

Execute the two-wave rollout that standardizes secret and configuration management across the Grid.

- **Wave 1 (nearly complete):** Vault env-driven wiring ✓, App Configuration extension ✓, event-driven cache invalidation ✓, Vault.Rotation repo creation ✓, portal walkthroughs ✓, catalog registration ✓ — only OIDC deploy workflow (Actions#20) remains
- **Wave 2 (blocked on Wave 1 exit criteria):** Per-Node bootstrap migrations (Auth, Web.Rest, Data, Notify, Pulse, Studios) + Actions secret cleanup and deploy-gate SLA check
- **Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
- **Blocker resolved:** Architecture#8 (Create Vault.Rotation repo) closed 2026-04-11. Vault.Rotation scaffold is now unblocked. Vault.Rotation bring-up work (repo stubs, managed identity, rotation function) can proceed.
- **Remaining Wave 1 blocker:** Actions#20 (OIDC federated-credential workflow) — still open. This is the last gate before Wave 2.

**See:** `generated/issue-packets/active/adr-0005-0006-rollout/dispatch-plan.md`

### Deploy Notify and Pulse

Provision Azure infrastructure and get both services running in the development environment.

- **Notify:** Azure Function App (`func-hd-notify-dev`) — queue-triggered email/SMS dispatch
- **Pulse:** App Service container (`app-hd-pulse-dev`) — OTLP collector for observability

**Why now:** All Node packages are built and published. The deployment pipeline (HoneyDrunk.Actions) is ready. The Azure provisioning guide and naming conventions are documented. The only remaining work is creating the Azure resources, wiring OIDC, and running the first deploy.

**See:** `infrastructure/azure-provisioning-guide.md` for step-by-step instructions.

## On Deck

### HoneyDrunk.Lore Bring-Up

Stand up Lore as a flat-file LLM-compiled wiki. 6 issues scoped and on The Hive under initiative `honeydrunk-lore-bringup`. Start with Lore#1 (scaffold) and Architecture#9 (catalog registration) — they are independent and can run in parallel.

**See:** [active-initiatives.md](active-initiatives.md) → HoneyDrunk.Lore Bring-Up

### Agent Kit

Stand up the Agent Kit Node — agent execution runtime, tool abstraction, and memory. This is the foundation for AI-powered workflows across the Grid.

### Grid v0.4 Alignment (Notify + Pulse)

Align Notify and Pulse with Kernel 0.4.0 patterns (same alignment the Core Nodes completed). Tracked in `active-initiatives.md`.

### Canary Test Coverage

Expand canary test coverage across all Node boundaries.
