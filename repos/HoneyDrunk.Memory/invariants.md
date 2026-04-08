# HoneyDrunk.Memory — Invariants

Memory-specific invariants (supplements `constitution/invariants.md`).

1. **Memory.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **Memory scoping is mandatory.**
   Every memory operation is scoped by at least `AgentId`. Cross-agent memory access requires explicit authorization.

3. **Short-term memory is cleared after execution completes.**
   When an agent execution context is disposed, short-term memories for that execution are purged.

4. **Long-term memory is append-only from the agent's perspective.**
   Agents can write and read memories. Deletion and summarization are system operations, not agent-initiated.

5. **Memory contents never appear in logs or telemetry.**
   Memory payloads may contain sensitive information. Only metadata (timestamps, scope, size) is emitted to Pulse.

6. **Summarization preserves semantic content.**
   When memories are compressed, the summarized version must be retrievable by the same queries that would find the originals.
