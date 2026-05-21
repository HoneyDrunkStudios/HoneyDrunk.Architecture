# Current Focus

What the team (human + agents) should prioritize right now.

**Last Updated:** 2026-05-21

## Primary Focus

### Deploy Notify and Pulse

Provision Azure infrastructure and get both services running in the development environment.

- **Notify.Functions:** `Notify#3` remains open for release workflow and Azure bring-up, despite the v0.2.0 release notes showing the Functions deploy workflow path has progressed.
- **Notify.Worker:** `Notify#4` remains open for the Azure Container App (`ca-hd-notify-worker-dev`) on `cae-hd-dev` / `acrhdshareddev`.
- **Pulse:** `Pulse#3` remains open for the `Pulse.Collector` Azure Container App (`ca-hd-pulse-dev`) on `cae-hd-dev` / `acrhdshareddev`.

**Why now:** ADR-0015 is still 2/5 closed. The Architecture walkthroughs and shared Actions deploy workflow are done; the remaining work is service-specific Azure/release execution.

**See:** `infrastructure/walkthroughs/azure-provisioning-guide.md` and `generated/issue-packets/active/adr-0015-container-apps-rollout/dispatch-plan.md`.

### ADR-0010 Observe / AI Routing Cleanup

ADR-0010's Observe side and AI routing handoff still need deliberate cleanup now that the main HoneyDrunk.AI scaffold packet has closed.

- `Architecture#35`: ADR-0010 acceptance packet remains open.
- `Observe#2`: Observe Abstractions scaffold remains open.
- `Architecture#95`: human-only HoneyDrunk.AI repo verification remains open.
- `HoneyDrunk.AI#1`: original routing-contract packet is still open, but its manifest path is missing and a superseded packet exists as `HoneyDrunk.AI#3`.

**Why now:** HoneyDrunk.AI scaffold work closed, but ADR-0010 still has manifest drift. Reconcile the duplicate/superseded AI routing issue before executing routing work.

## On Deck

### Archive / Exit-Criteria Review

Several rollouts have all packet issues closed and should be reviewed for archival instead of staying in active focus:

- Configuration & Secrets Rollout (ADR-0005 / ADR-0006): 15/15 packet issues closed; release verification notes remain in `initiatives/releases.md`.
- Hive Sync Rollout (ADR-0014): 6/6 issues closed; OpenClaw cron runtime is active.
- Package Scanning Rollout (ADR-0009): 8/8 issues closed.
- HoneyDrunk.Lore Bring-Up: 6/6 issues closed.
- Vault.Rotation Bring-Up: scaffold/release issues closed; verify operational exit criteria before archive.

### Agent Kit

Stand up the Agent Kit Node — agent execution runtime, tool abstraction, and memory. This is the foundation for AI-powered workflows across the Grid.

### Kernel Adoption Alignment Cleanup

Kernel Adoption Alignment is now 11/11 closed and its remaining packets moved to `completed/`. Human exit-criteria review/archive is the only remaining action.

### Canary Test Coverage

Expand canary test coverage across all Node boundaries.
