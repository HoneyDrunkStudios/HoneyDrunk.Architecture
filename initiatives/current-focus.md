# Current Focus

What the team (human + agents) should prioritize right now.

**Last Updated:** 2026-04-09

## Primary Focus

### Configuration & Secrets Rollout (ADR-0005 / ADR-0006)

Execute the two-wave rollout that standardizes secret and configuration management across the Grid.

- **Wave 1 (in progress):** Vault env-driven wiring, App Configuration extension, event-driven cache invalidation, Vault.Rotation repo scaffold, portal walkthroughs, catalog registration, OIDC deploy workflow
- **Wave 2 (blocked on Wave 1 exit criteria):** Per-Node bootstrap migrations (Auth, Web.Rest, Data, Notify, Pulse, Studios) + Actions secret cleanup and deploy-gate SLA check
- **Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
- **Blocker:** Packet #04 (Vault.Rotation scaffold) requires creating the `HoneyDrunk.Vault.Rotation` repo on GitHub

**See:** `generated/issue-packets/active/adr-0005-0006-rollout/dispatch-plan.md`

### Deploy Notify and Pulse

Provision Azure infrastructure and get both services running in the development environment.

- **Notify:** Azure Function App (`func-hd-notify-dev`) — queue-triggered email/SMS dispatch
- **Pulse:** App Service container (`app-hd-pulse-dev`) — OTLP collector for observability

**Why now:** All Node packages are built and published. The deployment pipeline (HoneyDrunk.Actions) is ready. The Azure provisioning guide and naming conventions are documented. The only remaining work is creating the Azure resources, wiring OIDC, and running the first deploy.

**See:** `infrastructure/azure-provisioning-guide.md` for step-by-step instructions.

## On Deck

### Agent Kit

Stand up the Agent Kit Node — agent execution runtime, tool abstraction, and memory. This is the foundation for AI-powered workflows across the Grid.

### Grid v0.4 Alignment (Notify + Pulse)

Align Notify and Pulse with Kernel 0.4.0 patterns (same alignment the Core Nodes completed). Tracked in `active-initiatives.md`.

### Canary Test Coverage

Expand canary test coverage across all Node boundaries.
