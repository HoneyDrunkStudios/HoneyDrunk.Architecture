# HoneyDrunk.Operator — Invariants

Operator-specific invariants (supplements `constitution/invariants.md`).

1. **Operator.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **The audit log is append-only.**
   Entries cannot be modified or deleted. The audit trail is the immutable record of all AI operations.

3. **Circuit breakers are independently deployable.**
   Operator can be updated and redeployed without touching Agents, AI, or Flow.

4. **Cost guards enforce hard limits.**
   When a budget is exceeded, execution halts. No soft warnings that can be ignored.

5. **Operator never participates in reasoning.**
   Operator observes and constrains. It never decides *what* to do, only *whether* something is allowed.

6. **Safety filter failures block output.**
   If `ISafetyFilter` rejects an output, it does not reach the consumer. No "log and continue" path.

7. **Every AI action is auditable.**
   Agent executions, tool invocations, inference calls, approval decisions, and cost events all produce audit entries.

8. **Decision policies are declarative.**
   `IDecisionPolicy` rules are data, not code. They can be updated without recompilation.
