# Dispatch Plan — ADR-0022 HoneyDrunk.Memory Standup

**Initiative:** `adr-0022-memory-standup`
**Sector:** AI
**Governing ADR:** [ADR-0022 — Stand Up the HoneyDrunk.Memory Node](../../../../adrs/ADR-0022-stand-up-honeydrunk-memory-node.md) (Proposed 2026-04-19; flips to Accepted after merge).
**Trigger:** ADR-0022 in the Proposed queue. Agents (default `IAgentMemory` via ADR-0020 D6), Flow, Sim, Lore, HoneyHub when live, Evals all need agent-memory primitives.
**Type:** Multi-repo (2 repos: `HoneyDrunk.Architecture` + `HoneyDrunk.Memory`)
**Site sync required:** No.
**Rollback plan:** Pre-tag revert; post-tag fix-forward.

## Summary

ADR-0022 is the standup ADR for `HoneyDrunk.Memory`. Owns agent-memory primitives — `IMemoryStore`, `IMemoryScope`, `IMemorySummarizer`. Three packages (`Abstractions`, runtime, `Providers.InMemory`). Composes AI's `IEmbeddingGenerator` (similarity) and `IChatClient` (summarization) per D5. Auth-gated scope escalation per D6. Operator-`IApprovalGate`-mediated bulk operational reads per D6. Content NEVER in telemetry per D9. Embedding-model coherence rule per D10 (level b — `MemoryEntry` records ingest-time model identifier). Right-to-erasure principle pinned, bulk-delete API surface deferred to scaffold per D11. Canary on all three surfaces per D12.

Two prose-correction items: `repos/HoneyDrunk.Memory/overview.md` and `repos/HoneyDrunk.Memory/boundaries.md` previously describe Memory as owning short-term memory; ADR-0022 D4/D7 (Position A) and ADR-0020 D8 fix that — short-term lives on `IAgentExecutionContext`, Memory owns long-term only.

Four packets land the work:

1. **Architecture catalog registration + integration-points + short-term-memory ownership fix** — verify three-interface contract surface in `contracts.json`; widen Memory→AI `consumes_detail` to include `IChatClient` per D5; add `honeydrunk-agents` to `consumed_by_planned`; refresh `grid-health.json` and `nodes.json`; fix the short-term-memory ownership drift in `repos/HoneyDrunk.Memory/overview.md`, `boundaries.md`, `constitution/ai-sector-architecture.md` (Position A); add `integration-points.md` and `active-work.md`.
2. **Constitution invariants** — seven new invariants from D2, D7+ADR-0020 D8, D8, D10, D9, D6, D12.
2b. **Verify `HoneyDrunk.Memory` repo + local clone (human-only)**.
3. **HoneyDrunk.Memory scaffold** — empty repo to first-shippable. Solution, three packages (`Abstractions`, runtime, `Providers.InMemory`), three interfaces in Abstractions, default runtime implementations composing AI + Auth, Providers.InMemory backend, five CI workflow files with canary scoped to Abstractions.

## Wave Diagram

```
Wave 1: Architecture catalog + constitution updates (parallel)
   ├─ Architecture: 01-architecture-memory-catalog-registration
   └─ Architecture: 02-architecture-memory-invariants
       Blocked by: 01

Wave 2: Verify repo + clone (human)
   └─ Architecture: 02b-architecture-verify-memory-repo
       Blocked by: 01

Wave 3: Memory repo scaffold
   └─ HoneyDrunk.Memory: 03-memory-node-scaffold
       Blocked by: 01, 02, 02b
```

## Packet List

| # | Packet | Repo | Wave | Actor | Depends On |
|---|--------|------|------|-------|------------|
| 01 | [Catalog registration + short-term-memory ownership fix + integration-points](./01-architecture-memory-catalog-registration.md) | Architecture | 1 | Agent | — |
| 02 | [Add seven new invariants for D2 / D7+D8 / D8 / D10 / D9 / D6 / D12](./02-architecture-memory-invariants.md) | Architecture | 1 | Agent | 01 |
| 02b | [Verify HoneyDrunk.Memory repo + clone (human-only)](./02b-architecture-verify-memory-repo.md) | Architecture | 2 | Human | 01 |
| 03 | [Stand up `HoneyDrunk.Memory` — solution, three packages, contracts, CI, InMemory provider](./03-memory-node-scaffold.md) | HoneyDrunk.Memory | 3 | Agent | 01, 02, 02b |

## What This Initiative Does **NOT** Deliver

- Downstream consumer Nodes not delivered.
- `Providers.SqlServer` and `Providers.CosmosDB` deferred to follow-up packets.
- The bulk-delete API surface (right-to-erasure) is principle-pinned but **API-shape deferred** per D11.
- The bulk-read API surface (operator-mediated reads gated by Operator's `IApprovalGate` per D6) is principle-pinned but **API-shape deferred** alongside bulk-delete — both human-policy-gated paths land together in the follow-up ADR.
- Level (c) router-level embedding-model pinning deferred to ADR-0010.
- Pulse signal ingress into Memory deferred (emit-only per D9).
- Cross-host shared scope-resolution registry deferred.
- No separate `HoneyDrunk.Memory.Testing` package — `Providers.InMemory` plays that role per D2.
- No strong-typed `AgentId` — Memory uses `string AgentId` at scaffold; follow-up packet rotates to a Kernel-side `AgentId` strong type once it ships (parallel to ADR-0026's `TenantId` / `ProjectId` shape).

## AI-sector standup wave sequencing

Memory requires `HoneyDrunk.AI.Abstractions` (for `IEmbeddingGenerator` + `IChatClient`) and `HoneyDrunk.Auth.Abstractions` (for `IAuthorizationPolicy` in scope escalation per D6). Recommended order: AI → Capabilities → Operator → **Memory** + Knowledge (parallel) → Agents (depends on Memory) → Evals + Flow + Sim.

## Status flip

ADR-0022 stays Proposed for duration.

## Filing

`file-work-items.yml` auto-files.

## Archival

Per ADR-0008 D10, archive to `archive/adr-0022-memory-standup/` post-completion.
