# HoneyDrunk.Agents — Integration Points

How Agents connects to the rest of the Grid. Every item here represents a cross-Node boundary that requires a canary test.

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `IGridContext`, `INodeContext`, `IOperationContext` | Every agent execution runs inside a Grid context. CorrelationId flows through all agent actions. |
| **Kernel** | `IStartupHook`, `IShutdownHook` | Agent registry initialization and graceful shutdown of in-flight agents. |
| **Kernel** | `IAgentExecutionContext` | Agents extends this with AI-specific bindings (memory refs, capability bindings). |
| **AI** | `IChatClient` | Agents delegates all inference to AI through chat/routing abstractions. Agents never calls a model provider directly. |
| **Capabilities** | `ICapabilityRegistry` | Resolves tools by name/version when an agent invokes `IToolInvoker`. |
| **Memory** | `IMemoryStore`, `IMemoryScope` | Agents reads and writes memory through `IAgentMemory`, which is backed by Memory Node storage. |
| **Operator** | `IApprovalGate`, `ICircuitBreaker` | Safety gate checked before any agent action that requires human oversight or breaches a cost/risk threshold. |

## Exposes

| Contract | Consumer | Notes |
|----------|---------|-------|
| `IAgent` | HoneyHub (when live), Flow | HoneyHub assigns tasks to agents via IAgent. Flow coordinates multi-agent sequences. |
| `IAgentLifecycle` | HoneyDrunk.Actions (trigger workflow) | The cloud agent trigger (ADR-0008 D8) initializes an agent via IAgentLifecycle. |
| `IAgentExecutionContext` | HoneyDrunk.Flow | Flow passes execution context when coordinating multi-step agent pipelines. |

## Canary Coverage Required

Before any Agents code can be considered production-ready:

- `Agents.Canary` → Kernel: verifies `IAgentExecutionContext` extends correctly, GridContext flows through agent execution
- `Agents.Canary` → AI: verifies `IChatClient` is resolved through `IToolInvoker` mechanism, inference result is returned
- `Agents.Canary` → Capabilities: verifies a registered tool is discoverable and invocable from an agent
- `Agents.Canary` → Memory: verifies `IAgentMemory` can write and read scoped memories
- `Agents.Canary` → Operator: verifies `IApprovalGate` halts execution when configured as required

## Dependency Order for Bring-Up

Agents cannot be scaffolded until these Nodes have published their Abstractions packages:

1. Kernel (already Live — `HoneyDrunk.Kernel.Abstractions` stable)
2. AI (`HoneyDrunk.AI.Abstractions` — Seed, must ship first)
3. Capabilities (`HoneyDrunk.Capabilities.Abstractions` — Seed, must ship first)
4. Memory (`HoneyDrunk.Memory.Abstractions` — Seed, can follow Agents)
5. Operator (`HoneyDrunk.Operator.Abstractions` — Seed, can follow Agents)
