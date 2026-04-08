# HoneyDrunk.Operator — Boundaries

## What Operator Owns

- Approval gates — workflows and agent actions that require human sign-off
- Safety controls — content filtering, output validation, action scope limits
- Circuit breakers — kill switches for agent execution, inference calls, or entire workflows
- Cost controls — budget limits per agent, per workflow, per time window; halt when exceeded
- Incident intervention — emergency stop, manual override, forced workflow cancellation
- Audit trail — immutable log of every AI decision, tool invocation, and human override
- Decision authority — allow/deny/require-approval based on policy

## What Operator Does NOT Own

- **Inference execution** — Model calls belong in HoneyDrunk.AI.
- **Agent runtime** — Agent lifecycle belongs in HoneyDrunk.Agents.
- **Reasoning or planning logic** — What to do belongs in HoneyHub and agents.
- **Workflow execution** — Running workflows belongs in HoneyDrunk.Flow. Operator provides the gates Flow pauses at.
- **Authentication** — Identity verification belongs in HoneyDrunk.Auth. Operator consumes Auth for authorization.

## Boundary Decision Tests

Before adding something to Operator, ask:

1. Is this about **whether an AI action is safe or allowed**? → Operator
2. Is this about **executing the action itself**? → Agents, Flow, or AI
3. Is this about **who the user is**? → Auth
4. Is this about **recording what happened**? → Operator (audit trail)
5. Is this about **how much something costs**? → Operator (cost controls)
