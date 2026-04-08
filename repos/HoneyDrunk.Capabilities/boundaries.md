# HoneyDrunk.Capabilities — Boundaries

## What Capabilities Owns

- Tool definitions and schemas — what tools exist, parameters, return types
- Discovery and registration — agents query the registry at runtime
- Permissioning — which agents are authorized to invoke which tools
- Versioning — tool schemas evolve; consumers bind to specific versions
- Execution dispatch — route a tool invocation to its implementing Node

## What Capabilities Does NOT Own

- **Tool implementation** — Implementations live in the Node that owns the domain (Data, Vault, Knowledge, etc.).
- **Agent lifecycle** — How agents run and manage state belongs in HoneyDrunk.Agents.
- **Authorization policies** — Policy definitions belong in HoneyDrunk.Auth. Capabilities consumes Auth for permission checks.
- **Inference** — Model calls belong in HoneyDrunk.AI.
- **Safety controls** — Action limits and approval gates belong in HoneyDrunk.Operator.

## Boundary Decision Tests

Before adding something to Capabilities, ask:

1. Is this about **what tools exist** and **who can use them**? → Capabilities
2. Is this about **how a specific tool works**? → The owning Node (Data, Vault, etc.)
3. Is this about **how agents call tools**? → Agents defines the calling contract, Capabilities provides the resolution
4. Is this about **whether an action is allowed**? → Operator for safety, Auth for identity
