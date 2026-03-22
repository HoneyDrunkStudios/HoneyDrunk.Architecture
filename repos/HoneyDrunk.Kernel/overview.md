# HoneyDrunk.Kernel — Overview

**Sector:** Core  
**Version:** 0.4.0  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Kernel`

## Purpose

The semantic OS layer for HoneyDrunk.OS. Kernel defines the grammar all Nodes speak — context propagation, lifecycle orchestration, configuration scoping, identity primitives, and telemetry hooks.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Kernel.Abstractions` | Abstractions | Zero-dependency contracts |
| `HoneyDrunk.Kernel` | Runtime | GridContext, NodeContext, OperationContext implementations |

## Key Interfaces

- `IGridContext` / `IGridContextAccessor` — Distributed context with correlation, causation, baggage
- `INodeContext` — Static Node-scoped metadata (singleton)
- `IOperationContext` — Scoped per logical operation
- `IStartupHook` / `IShutdownHook` — Lifecycle extension points
- `IHealthContributor` / `IReadinessContributor` — Health aggregation
- `IConfigScope` — Hierarchical configuration access
- `ITraceEnricher` — OpenTelemetry enrichment
- `IAgentExecutionContext` — LLM agent context

## Identity Primitives

`CorrelationId`, `NodeId`, `TenantId`, `ProjectId`, `RunId`, `StudioId` — all ULID-based, strongly-typed.
