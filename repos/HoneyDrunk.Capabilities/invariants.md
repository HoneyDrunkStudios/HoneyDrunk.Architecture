# HoneyDrunk.Capabilities — Invariants

Capabilities-specific invariants (supplements `constitution/invariants.md`).

1. **Capabilities.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **Every tool invocation passes through a permission check.**
   `ICapabilityGuard` is evaluated before dispatch. No bypass path exists.

3. **Tool schemas are versioned.**
   Breaking changes to a tool's parameter or return schema require a new version. Consumers bind to specific versions.

4. **Tool implementations never live in the Capabilities package.**
   Capabilities owns the registry and dispatch. Implementations live in their owning Nodes.

5. **Unregistered tool invocations fail fast.**
   Attempting to invoke a tool that is not registered returns a structured error, not an exception.

6. **GridContext is propagated through tool invocations.**
   The dispatch pipeline carries CorrelationId and CausationId from agent to tool implementation.
