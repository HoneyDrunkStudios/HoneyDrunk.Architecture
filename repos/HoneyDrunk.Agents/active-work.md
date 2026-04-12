# HoneyDrunk.Agents — Active Work

**Signal:** Seed — repo not yet scaffolded.

## Current Status

No active work. Agents Node is in design phase. The repo context documents (`overview.md`, `boundaries.md`, `invariants.md`) define the full architecture. No code exists yet.

## Prerequisites Before Bring-Up

The following must be true before Agents bring-up can start:

1. **HoneyDrunk.AI** must be scaffolded first — Agents depends on `IChatClient` and `IModelProvider` from AI. AI is the inference layer Agents calls into.
2. **HoneyDrunk.Capabilities** must be scaffolded — Agents depends on `ICapabilityRegistry` for tool resolution via `IToolInvoker`.
3. **HoneyDrunk.Operator** must have a design stub — the safety gate (`IApprovalGate`, `ICircuitBreaker`) that Agents calls before executing agent actions.

## On-Deck Work (not yet filed)

- Repo scaffolding: solution structure, `HoneyDrunk.Agents.Abstractions` + `HoneyDrunk.Agents` projects, `HoneyDrunk.Standards` wired
- Catalog registration: update `nodes.json`, `relationships.json`, `services.json`
- Contract implementation: `IAgent`, `IAgentExecutionContext`, `IAgentLifecycle`, `IToolInvoker`, `IAgentMemory`
- CI pipeline: build, test, NuGet publish workflow via `HoneyDrunk.Actions`
- Canary test project: validates integration with Kernel (`IAgentExecutionContext` extension), AI (`IChatClient` call), and Capabilities (`IToolInvoker` resolution)

## Blocking Initiative

Agents bring-up is part of the **AI Sector Bring-Up initiative** — not yet scoped. It is blocked on HoneyDrunk.AI bring-up completing first.
