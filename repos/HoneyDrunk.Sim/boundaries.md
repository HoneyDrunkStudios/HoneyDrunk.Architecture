# HoneyDrunk.Sim — Boundaries

## What Sim Owns

- Scenario modeling — define hypothetical scenarios and simulate outcomes
- Plan evaluation — given a proposed workflow or agent action, estimate the result before executing
- Risk analysis — identify failure modes, cost exposure, and safety concerns
- Pre-execution validation — dry-run a workflow against simulated state

## What Sim Does NOT Own

- **Real execution** — Actually running agents and workflows belongs in Flow and Agents.
- **Real inference** — Sim may use HoneyDrunk.AI for simulation inference, but does not produce production outputs.
- **Safety enforcement** — Blocking dangerous actions belongs in HoneyDrunk.Operator. Sim advises; Operator enforces.
- **Knowledge storage** — Background context for scenarios comes from HoneyDrunk.Knowledge.

## Boundary Decision Tests

Before adding something to Sim, ask:

1. Is this about **previewing what would happen** before doing it? → Sim
2. Is this about **actually doing it**? → Agents, Flow
3. Is this about **blocking it from happening**? → Operator
4. Is this about **evaluating output quality after the fact**? → Evals
