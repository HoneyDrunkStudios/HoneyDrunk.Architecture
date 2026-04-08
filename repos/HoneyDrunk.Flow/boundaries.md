# HoneyDrunk.Flow — Boundaries

## What Flow Owns

- Multi-step workflow definitions — sequences, branches, parallel execution
- Long-running process management — workflows that span minutes, hours, or days
- Retry and compensation — when a step fails, retry with backoff or execute compensation logic
- Agent chaining — output of one agent feeds as input to the next
- State persistence — workflow state survives process restarts
- Checkpoint and resume — workflows can pause for human approval (via Operator) and resume

## What Flow Does NOT Own

- **Agent execution** — How agents run belongs in HoneyDrunk.Agents. Flow triggers agents but doesn't own their runtime.
- **Inference** — Model calls belong in HoneyDrunk.AI.
- **Planning and decomposition** — Deciding what workflows to run belongs in HoneyHub.
- **Approval authority** — Whether a checkpoint is approved belongs in HoneyDrunk.Operator.
- **Message transport** — Async coordination uses HoneyDrunk.Transport, not Flow's own transport.

## Boundary with HoneyHub

HoneyHub plans work at the organizational level (Goals → Features → Tasks). Flow executes work at the runtime level (workflow steps, retries, compensation). HoneyHub decides *what* workflows to run. Flow runs them.

## Boundary Decision Tests

Before adding something to Flow, ask:

1. Is this about **executing a multi-step process** with state, retries, and compensation? → Flow
2. Is this about **what work to do** at an organizational level? → HoneyHub
3. Is this about **running a single agent**? → Agents (Flow is for multi-step coordination)
4. Is this about **whether a step is allowed to proceed**? → Operator
