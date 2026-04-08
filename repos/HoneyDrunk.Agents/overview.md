# HoneyDrunk.Agents — Overview

**Sector:** AI  
**Version:** TBD  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Agents`

## Purpose

Agent runtime and lifecycle system for the Grid. Manages the full agent lifecycle, provides scoped execution contexts, and defines the contracts for how agents invoke tools and access memory.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Agents.Abstractions` | Abstractions | Zero-dependency agent contracts |
| `HoneyDrunk.Agents` | Runtime | Agent lifecycle, execution engine, context management |

## Key Interfaces

- `IAgent` — Core agent interface
- `IAgentExecutionContext` — Extends Kernel's existing `IAgentExecutionContext` with AI-specific bindings
- `IAgentLifecycle` — Lifecycle hooks (register → initialize → execute → complete → decommission)
- `IToolInvoker` — How agents call tools (resolved through Capabilities)
- `IAgentMemory` — Memory read/write from agent perspective (backed by Memory Node)

## Design Notes

Agents is to the AI sector what Kernel is to Core — it provides the runtime skeleton that every agent builds on. Just as Kernel gives Nodes context, lifecycle, and identity, Agents gives AI agents execution context, tool access, and memory access. Agents never calls models directly — it delegates to AI for inference, Capabilities for tools, and Memory for state.
