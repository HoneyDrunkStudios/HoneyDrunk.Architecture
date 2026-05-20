# HoneyDrunk.AI — Overview

**Sector:** AI  
**Version:** TBD  
**Framework:** .NET 10.0  
**Repo:** `HoneyDrunkStudios/HoneyDrunk.AI`

## Purpose

Model and provider abstraction layer for the Grid. Normalizes inference contracts (chat completion, embeddings, structured output) across providers so the rest of the AI sector never depends on a specific model vendor.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.AI.Abstractions` | Abstractions | Zero-dependency inference contracts |
| `HoneyDrunk.AI` | Runtime | Model routing, telemetry, provider orchestration |
| `HoneyDrunk.AI.Providers.OpenAI` | Provider | OpenAI adapter |
| `HoneyDrunk.AI.Providers.Anthropic` | Provider | Anthropic adapter |
| `HoneyDrunk.AI.Providers.AzureOpenAI` | Provider | Azure OpenAI adapter |
| `HoneyDrunk.AI.Providers.InMemory` | Provider | Deterministic test double for Evals and CI |

## Key Interfaces

- `IChatClient` — Chat completion (aligned with `Microsoft.Extensions.AI`)
- `IEmbeddingGenerator` — Embedding generation (aligned with `Microsoft.Extensions.AI`)
- `IModelProvider` — Provider slot interface for model backends
- `IModelRouter` — Capability-driven model selection
- `IRoutingPolicy` — Pluggable routing strategy
- `ModelCapabilityDeclaration` — Machine-readable capability metadata
- `ICostLedger` — Per-call token and cost accounting surface

## Design Notes

Provider adapters expose Grid-owned abstractions with runtime context enrichment, Pulse telemetry, and Vault-backed credential resolution. InMemory provides deterministic tests; external SDK adapters land in follow-up packets. When `Microsoft.Extensions.AI` reaches stable adoption (planned Q3 2026), HoneyDrunk.AI aligns with those abstractions rather than inventing competing ones.
