# HoneyDrunk.Flow — Invariants

Flow-specific invariants (supplements `constitution/invariants.md`).

1. **Flow.Abstractions has zero HoneyDrunk dependencies.**
   Only `Microsoft.Extensions.*` abstractions are allowed.

2. **Workflow state survives process restarts.**
   All workflow state is persisted via Data. An in-flight workflow resumes from its last checkpoint after restart.

3. **Failed steps execute compensation before the workflow fails.**
   If a step has registered compensation logic, it runs before the workflow transitions to a failed state.

4. **Workflows are cancellable at any point.**
   `IWorkflowEngine.Cancel()` can be called at any time. Compensation runs for completed steps.

5. **Checkpoint/resume respects Operator approval gates.**
   When a workflow pauses for human approval, it remains paused until Operator's `IApprovalGate` returns a decision. No timeout-based auto-approval.

6. **GridContext is propagated across workflow steps.**
   Each step inherits the workflow's CorrelationId. CausationId chains step-to-step.

7. **Parallel steps execute independently.**
   Failure of one parallel branch does not automatically cancel sibling branches unless the workflow definition specifies it.
