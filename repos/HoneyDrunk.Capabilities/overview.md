# HoneyDrunk.Capabilities — Overview

**Sector:** AI  
**Signal:** Planned  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Capabilities`

## Purpose

Tool registry, discovery, permissioning, and execution dispatch for Grid agents. Capabilities is the bridge between agents and the rest of the Grid — agents discover what tools exist, check permissions, and invoke them through Capabilities.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Capabilities.Abstractions` | Abstractions | Zero-dependency tool contracts |
| `HoneyDrunk.Capabilities` | Runtime | Registry, discovery, dispatch, permission enforcement |

## Key Interfaces

- `ICapabilityRegistry` — Register, discover, resolve tools
- `ICapabilityDescriptor` — Tool schema (name, parameters, return type, permissions)
- `ICapabilityInvoker` — Execute a tool invocation
- `ICapabilityGuard` — Permission check before invocation

## Design Notes

Follows the same pattern as Vault's provider slots but for agent tools. A tool is a capability descriptor (contract) + an implementation (provider in the owning Node). The registry is the discovery mechanism. Agents interact with tools through `IToolInvoker` (defined in Agents.Abstractions) which resolves tools through the Capabilities registry.

Tool implementations live in the Node that owns the domain — e.g., a "query database" tool is implemented by Data but registered in Capabilities.
