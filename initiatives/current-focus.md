# Current Focus

What the team (human + agents) should prioritize right now.

**Last Updated:** 2026-03-28

## Primary Focus

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
