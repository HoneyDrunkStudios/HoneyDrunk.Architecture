# HoneyDrunk.AI — Active Work

**Signal:** Seed — repo not yet scaffolded.

## Current Status

No active work. AI Node is in design phase. The repo context documents (`overview.md`, `boundaries.md`, `invariants.md`) define the full architecture. No code exists yet.

## Prerequisites Before Bring-Up

AI has the fewest upstream dependencies in the AI sector — it depends on Core Nodes (Kernel, Vault) which are Live, and emits telemetry consumed by Pulse without taking a runtime dependency. AI can be the **first AI sector Node to scaffold**.

1. **Kernel** — `IGridContext`, `IOperationContext`, `ITelemetryActivityFactory` (all Live at 0.4.0) ✅
2. **Vault** — `ISecretStore` for model API key resolution (Live at 0.4.0) ✅
3. **Pulse** (Ops, Seed) — AI emits inference telemetry via Kernel's `ITelemetryActivityFactory` and OTel SDK directly. No runtime dependency on Pulse. ✅ (unblocked)

## On-Deck Work (not yet filed)

- Repo scaffolding: solution structure, `HoneyDrunk.AI.Abstractions` + `HoneyDrunk.AI` projects, `HoneyDrunk.Standards` wired
- Contract definition: `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration`, `ICostLedger`
  - Align with `Microsoft.Extensions.AI` abstractions (planned Q3 2026 adoption)
- Provider adapters: OpenAI, Anthropic, Azure OpenAI, InMemory (each as separate package, provider slot pattern)
  - `HoneyDrunk.AI.Providers.OpenAI`
  - `HoneyDrunk.AI.Providers.Anthropic`
  - `HoneyDrunk.AI.Providers.AzureOpenAI`
  - `HoneyDrunk.AI.Providers.InMemory` (deterministic test double for Evals and CI)
- AI Routing: `IModelRouter`, `IRoutingPolicy`, `ModelCapabilityDeclaration` (from ADR-0010)
  - Cost-first routing policy as the first implementation
  - Policy storage via App Configuration (ADR-0005)
- Telemetry: every inference call emits a Pulse span with tokens in/out, latency, model ID, cost estimate
- Catalog registration: update `nodes.json`, `relationships.json`, `services.json`, `contracts.json`
- CI pipeline: build, test, NuGet publish via `HoneyDrunk.Actions`
- Canary: validates Vault secret resolution (API key retrieval), model invocation round-trip via InMemory provider

## Initiative

AI bring-up is the **highest-priority AI sector Node** because AI is a prerequisite for Agents, Memory, Knowledge, and Evals. It should be the first packet filed in the AI Sector Bring-Up initiative.
