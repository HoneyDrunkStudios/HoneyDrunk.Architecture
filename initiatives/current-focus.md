# Current Focus

What the team (human + agents) should prioritize right now.

**Last Updated:** 2026-05-18

## Primary Focus

### Deploy Notify and Pulse

Provision Azure infrastructure and get both services running in the development environment.

- **Notify.Functions:** `Notify#3` remains open for release workflow and Azure bring-up, despite the v0.2.0 release notes showing the Functions deploy workflow path has progressed.
- **Notify.Worker:** `Notify#4` remains open for the Azure Container App (`ca-hd-notify-worker-dev`) on `cae-hd-dev` / `acrhdshareddev`.
- **Pulse:** `Pulse#3` remains open for the `Pulse.Collector` Azure Container App (`ca-hd-pulse-dev`) on `cae-hd-dev` / `acrhdshareddev`.

**Why now:** ADR-0015 is still 2/5 closed. The Architecture walkthroughs and shared Actions deploy workflow are done; the remaining work is service-specific Azure/release execution.

**See:** `infrastructure/walkthroughs/azure-provisioning-guide.md` and `generated/issue-packets/active/adr-0015-container-apps-rollout/dispatch-plan.md`.

### HoneyDrunk.AI Stand-Up

Finish the initial HoneyDrunk.AI stand-up lane so ADR-0010's parked AI routing work can be unblocked deliberately.

- `Architecture#72`: catalog registration packet open
- `Architecture#73`: invariant packet open
- `HoneyDrunk.AI#2`: solution/packages/contracts/CI/InMemory provider packet open

**Why now:** ADR-0010 packet 04 is parked behind HoneyDrunk.AI stand-up. Keep this as an explicit focus item rather than slipping routing contracts into the empty repo without the ADR-0016 scaffold decisions.

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

### Grid v0.4 Alignment (Notify + Pulse)

Align Notify and Pulse with Kernel 0.4.0 patterns where still needed. Notify has moved through the ADR-0019/v0.2.0 boundary release; Pulse production deployment and dashboard work remain.

### Canary Test Coverage

Expand canary test coverage across all Node boundaries.
