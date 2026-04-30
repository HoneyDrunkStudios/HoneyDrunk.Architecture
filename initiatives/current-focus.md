# Current Focus

What the team (human + agents) should prioritize right now.

**Last Updated:** 2026-04-30

## Primary Focus

### Deploy Notify and Pulse

Provision Azure infrastructure and get both services running in the development environment.

- **Notify:** Azure Function App (`func-hd-notify-dev`) — queue-triggered email/SMS dispatch
- **Notify.Worker:** Azure Container App (`ca-hd-notify-worker-dev`) — background worker on `cae-hd-dev` / `acrhdshareddev`
- **Pulse:** Azure Container App (`ca-hd-pulse-dev`) — OTLP collector for observability, on `cae-hd-dev` / `acrhdshareddev`
- **Status:** Infrastructure walkthroughs complete (Architecture#37 closed 2026-04-26). Container Apps deployment workflow ready (Actions#48 closed 2026-04-25). Per-service release workflows (Notify#3, Notify#4, Pulse#3) open and ready to execute.

**Why now:** ADR-0005/0006 configuration rollout complete (all 15 issues closed by 2026-04-26). All Node packages are built and published. The deployment pipeline (HoneyDrunk.Actions) is ready. The Azure provisioning guide and naming conventions are documented. The only remaining work is creating the Azure resources, wiring OIDC, and running the first deploy.

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
