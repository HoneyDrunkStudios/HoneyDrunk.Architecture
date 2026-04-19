# HoneyDrunk.AI — Integration Points

How AI connects to the rest of the Grid. Every item here represents a cross-Node boundary that requires a canary test.

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `IGridContext`, `IOperationContext` | Every inference call runs inside a Grid context. CorrelationId traces through model calls. |
| **Kernel** | `ITelemetryActivityFactory` | Creates spans for inference calls. Emits token counts, latency, model ID, cost as span attributes. |
| **Kernel** | `IStartupHook`, `IHealthContributor` | Validates provider connectivity at startup. Contributes health check (can reach model endpoint). |
| **Vault** | `ISecretStore` | Resolves model API keys (OpenAI key, Anthropic key, Azure OpenAI key) at startup. Never hardcoded. |
| **Pulse** | _(none — no runtime dependency)_ | AI emits OTel traces via Kernel's `ITelemetryActivityFactory`. When Pulse is deployed, its collectors consume these spans. AI never depends on Pulse at compile or runtime. |

## Exposes

| Contract | Consumer | Notes |
|----------|---------|-------|
| `IChatClient` | Agents, Knowledge, Evals, Sim | Primary inference interface. Aligned with Microsoft.Extensions.AI. |
| `IEmbeddingGenerator` | Memory, Knowledge | Embedding generation for similarity search and RAG pipelines. |
| `IModelProvider` | AI (internal, provider slot) | Each provider adapter implements this. Not consumed externally. |
| `IInferenceResult` | Agents, Evals | Normalized response envelope — callers inspect tokens, cost, model ID. |
| `IModelRouter` | Agents, HoneyHub (future) | Policy-driven model selection. Agents don't hardcode a model — they declare requirements, Router selects. |
| `IRoutingPolicy` | App Configuration (policy storage) | Policies are loaded from shared App Config and applied by `IModelRouter`. |
| `ModelCapabilityDeclaration` | Agents, HoneyHub (future), provider adapters | Declares required/available model capabilities used by routing to match workloads to compatible models. |

## Canary Coverage Required

- `AI.Canary` → Kernel: verifies GridContext flows through inference calls, CorrelationId appears in span
- `AI.Canary` → Vault: verifies API key is resolved via `ISecretStore`, not hardcoded or env-var fallback
- `AI.Canary` → InMemory provider: verifies `IChatClient` returns `IInferenceResult` with required metadata fields
- `AI.Canary` → Router: verifies `IModelRouter` selects correct provider given a routing policy

## Note on Microsoft.Extensions.AI Alignment

`IChatClient` and `IEmbeddingGenerator` will align with `Microsoft.Extensions.AI` abstractions when adopted (planned Q3 2026). HoneyDrunk.AI's provider adapters will wrap `Microsoft.Extensions.AI` implementations with:
- Vault-backed credential resolution
- GridContext propagation into request headers
- Pulse telemetry enrichment (token counts, cost, latency)

Until Microsoft.Extensions.AI is adopted, HoneyDrunk.AI defines its own contracts that are shape-compatible with the planned abstractions.
