# ADR-0001: Node vs Service Distinction

**Status:** Accepted  
**Date:** 2026-03-22  
**Deciders:** HoneyDrunk Studios  
**Sector:** Core

## Context

As the HoneyDrunk Grid grew, there was confusion between "Nodes" (NuGet packages/libraries composing the Grid) and "Services" (deployable processes like Pulse.Collector or Notify.Worker). We needed a clear distinction to guide repository structure, CI pipelines, and deployment.

## Decision

- **Node** = A library-level building block. One repo produces one or more Node packages (NuGet). Nodes are consumed by other Nodes or by Services. Examples: Kernel, Transport, Vault.
- **Service** = A deployable process (container, Azure Function, worker). Services compose Nodes and are the runtime entry points. Examples: Pulse.Collector, Notify.Worker, Notify.Functions.

A repo may contain both Nodes (library packages) and Services (deployable projects), but they serve different roles in the architecture.

## Consequences

- The `catalogs/nodes.json` tracks library packages. The `catalogs/services.json` tracks deployable services.
- CI workflows treat Nodes and Services differently — Nodes produce NuGet packages, Services produce container images or deployment artifacts.
- Documentation uses these terms consistently. The terminology is codified in `constitution/terminology.md`.

## Alternatives Considered

- **Treating everything as a "service"**: Rejected because NuGet packages are not services — they have no runtime identity, health endpoints, or deployment lifecycle.
- **Treating everything as a "node"**: Would conflate compile-time and runtime concerns.
