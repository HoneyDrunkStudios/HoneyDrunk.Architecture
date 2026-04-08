# HoneyDrunk.Agents — Invariants

Agents-specific invariants (supplements `constitution/invariants.md`).

1. **Agents.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **Every agent execution has a scoped execution context.**
   `IAgentExecutionContext` is always available during execution. It carries GridContext, AgentId, and capability bindings.

3. **Agent lifecycle transitions are sequential and auditable.**
   An agent cannot skip lifecycle stages. Every transition is logged.

4. **Agents never call model providers directly.**
   All inference goes through `IChatClient` / `IEmbeddingGenerator` from HoneyDrunk.AI. No direct SDK calls.

5. **Tool invocations go through IToolInvoker.**
   Agents never call tool implementations directly. IToolInvoker resolves through Capabilities, which enforces permissions.

6. **AgentId is unique and immutable per agent registration.**
   Once assigned, an AgentId cannot change for the lifetime of that agent definition.

7. **GridContext is propagated from agent execution to all downstream calls.**
   Inference, tool invocations, and memory operations all carry the agent's CorrelationId and CausationId.
