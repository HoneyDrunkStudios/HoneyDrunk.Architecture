# HoneyDrunk.Evals — Boundaries

## What Evals Owns

- Prompt evaluation — run a prompt against a model and score the output
- Regression testing — detect when model upgrades or prompt changes degrade quality
- Model comparison — run the same evaluation set against multiple models/providers
- Output quality scoring — structured rubrics (factuality, relevance, safety, format compliance)
- Evaluation datasets — versioned sets of inputs + expected outputs + scoring criteria

## What Evals Does NOT Own

- **Inference execution** — Delegates to HoneyDrunk.AI for running prompts against models.
- **Agent behavior rules** — Runtime safety belongs in HoneyDrunk.Operator. Agent lifecycle belongs in HoneyDrunk.Agents.
- **Prompt authoring** — Evals tests prompts; it doesn't write them.
- **Telemetry infrastructure** — Pulse owns the telemetry pipeline. Evals emits signals into it.

## Boundary Decision Tests

Before adding something to Evals, ask:

1. Is this about **measuring AI output quality**? → Evals
2. Is this about **making the inference call**? → AI
3. Is this about **preventing bad outputs in production**? → Operator (safety filters)
4. Is this about **observing system health**? → Pulse
