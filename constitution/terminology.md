# Terminology

Canonical definitions for terms used across HoneyDrunk.OS.

## Grid Topology

| Term | Definition |
|------|-----------|
| **Grid** | The full distributed system composed of all Nodes. Synonym: "the Hive." |
| **Node** | A library-level building block (NuGet package) that participates in the Grid. Each repo produces one or more Nodes. |
| **Service** | A deployable process that hosts one or more Nodes and runs in the Grid (e.g., Pulse.Collector, Notify.Functions). See `catalogs/services.json`. |
| **Studio** | The organizational tenant. `StudioId` scopes configuration, secrets, and telemetry. |
| **Sector** | A narrative grouping of related Nodes (e.g., Core, Ops, Meta, HoneyNet, Creator, Market, AI). |
| **Cluster** | A sub-grouping within a Sector (e.g., Core → foundation, security). |
| **Slot** | A pluggable capability within a Node (e.g., Vault has a Provider Slot for Azure/AWS/File). |

## Context Model

| Term | Definition |
|------|-----------|
| **GridContext** | Distributed context that flows across Node boundaries. Carries `CorrelationId`, `CausationId`, `NodeId`, `StudioId`, `Environment`, and baggage. |
| **NodeContext** | Static metadata about the current Node instance. Registered as singleton. |
| **OperationContext** | Scoped per logical operation (HTTP request, message handler, job). Links Grid + Node context. |
| **CorrelationId** | ULID-based identifier that ties all operations in a distributed flow together. |
| **CausationId** | The ID of the operation that directly caused the current operation. |

## Architecture Patterns

| Term | Definition |
|------|-----------|
| **Abstractions Package** | A contracts-only NuGet package with zero runtime dependencies. Suffix: `.Abstractions`. |
| **Provider Slot** | A pattern where a Node defines an interface (e.g., `ISecretProvider`) and provider packages implement it (e.g., `Vault.Providers.AzureKeyVault`). |
| **Canary Test** | A test project that validates cross-Node boundary invariants. Suffix: `.Canary`. |
| **Envelope** | A transport wrapper around a message payload that carries Grid context, headers, and routing metadata. |
| **Outbox** | The transactional outbox pattern — messages are saved to a database within the same transaction as business data, then dispatched asynchronously. |

## CI / Workflow

| Term | Definition |
|------|-----------|
| **PR Workflow** | A GitHub Actions workflow triggered on pull requests. Must be fast. |
| **Scheduled Workflow** | A GitHub Actions workflow on a cron schedule. Allowed to be slow and thorough. |
| **Release Workflow** | Triggered on version tags. Produces shippable artifacts with full validation. |
| **HoneyDrunk.Standards** | Shared analyzer package enforcing code style and conventions across all repos. |

## Agent / Agentic Flow

| Term | Definition |
|------|-----------|
| **Agent HQ** | This architecture repo — the command center for agentic workflows. |
| **Issue Packet** | A machine-readable artifact (Markdown + frontmatter) that an agent can use to create a GitHub Issue in a target repo. |
| **Site Sync Packet** | An artifact describing changes needed on the HoneyDrunk Studios website to reflect architecture changes. |
| **ADR Draft** | A partially completed Architecture Decision Record generated from a discussion with an agent. |
| **Handoff** | The act of passing a structured work artifact from one agent (or human) to another for execution. |
| **Routing Rule** | A rule that determines which repo, workflow, or agent handles a given type of request. |
