# HoneyDrunk.AI — Boundaries

## What AI Owns

- Normalized inference contracts (chat completion, text completion, embeddings, structured output)
- Provider adapters (OpenAI, Anthropic, Azure OpenAI, local models)
- Request/response normalization — uniform types regardless of provider
- Token and latency telemetry — every inference call emits Pulse traces
- Model selection and routing based on capability requirements
- Cost estimation per inference call

## What AI Does NOT Own

- **Agent lifecycle** — Agent runtime, execution context, and identity belong in HoneyDrunk.Agents.
- **Orchestration logic** — Multi-step workflows belong in HoneyDrunk.Flow.
- **Prompt management or evaluation** — Quality scoring and regression testing belong in HoneyDrunk.Evals.
- **Memory** — Agent memory storage and retrieval belong in HoneyDrunk.Memory.
- **Knowledge retrieval** — Document ingestion and RAG belong in HoneyDrunk.Knowledge.
- **API key storage** — Secrets management belongs in HoneyDrunk.Vault. AI consumes Vault for credentials.
- **Safety controls** — Content filtering and action limits belong in HoneyDrunk.Operator.

## Boundary Decision Tests

Before adding something to AI, ask:

1. Is this about **making an inference call** to a model? → AI
2. Is this about **what an agent does** with an inference result? → Agents
3. Is this about **evaluating** inference quality? → Evals
4. Is this about **storing or retrieving** information? → Memory or Knowledge
5. Is this about **controlling** what models can be used? → Operator
